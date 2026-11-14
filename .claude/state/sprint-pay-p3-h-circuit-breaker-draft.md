# Sprint 계약 Draft — PAY-P3-H Circuit Breaker (Polar SDK 경계 가용성 차단)

> **작성**: 2026-05-11 #10_8 (grimoire-planner Initializer 산출, 메인 박제)
> **트리거**: 사용자 5/10 verbatim 박제 ("PAY-P2-5 ... PAY-P3-H ... PAY-P3-D ... USER-SOFT-DELETE ... PAY-P3-E 단계 7~12 ... 이건 순서대로 하고") — PAY-P2-5 종료 직후 **2순위 sprint**
> **핸드오버 §1.10 정합**: claude-docs commit `07be842` 박제 (PAY-P2-5 종료 + PP hook 폐기 + 5/10~11 매트릭스)
> **사용자 결정 정합 (5/9 박제)**: 외부 API 추가 호출 0건 / DB schema 변경 0건 / dev migration 0건 / 예상 ~4h
> **본 위치**: `.claude/state/` (Draft 영역). 정본 위치 (예정): `reports/sprint-pay-p3-h-circuit-breaker-progress.md` — Generator(server agent) 진입 시 이동 영역.
> **본 sprint = Draft만 산출**. 실제 코드 변경 0건. 진입은 사용자 별도 명시 시.

---

## §0 한 줄 요약

PAYMENT_AUDIT §1 모순-? 후속 + PAY-P3-B Polar SDK timeout 정책 후속 영역 — Polar SDK 호출 경계 (checkout 생성 / checkout 조회 / refund / webhook signature 검증 등 4 호출점)에 **Circuit Breaker 패턴** 적용. (1) 3 상태 머신 (CLOSED / OPEN / HALF-OPEN) + (2) 임계값 정책 (실패 5회 / 60초 cooldown / half-open 1회 trial / reset window 120초) + (3) 차단 시 즉시 fail-fast (retry queue 박제 0건 — 5분 cron 부담 ↓) + (4) AuditLog `circuit_breaker_opened` / `circuit_breaker_half_open` / `circuit_breaker_closed` 박제 + (5) sensor-circuit-breaker-policy.sh + eval regression-71 + shared-contracts §27 CircuitBreakerPolicy 신설. **DB schema 변경 0건 + 외부 API 추가 호출 0건 + dev migration 0건** 강제 (사용자 5/10 명시 정합). 예상 ~4h.

---

## §0-1. 사용자 결정 박제 (5/10 raw 인용 + 후속)

- **결정 1 (순서)**: "PAY-P2-5 ... **PAY-P3-H** ... PAY-P3-D ... USER-SOFT-DELETE ... PAY-P3-E 단계 7~12 ... 이건 순서대로 하고" — 본 sprint = 2순위
- **결정 2 (외부 API)**: "다 폐기해" (5/10 22:18 PP hook 영구 폐기 정합) + "외부 Anthropic API 신규 의존 영구 보류" (절대 규정 0-1) — 외부 의존 0건 강제
- **결정 3 (정책 영역, 본 Draft 사용자 결정 영역)**: 임계값 / cooldown / half-open 정책은 본 Draft §7 옵션 매트릭스 박제 → 사용자 명시 후 진입

---

## §1 배경 / 문제 영역

### 1-1. PAY-P3-B 후속 위치 + PAYMENT_AUDIT §1 정합

PAY-P3-B (Polar SDK timeout 정책, shared-contracts §24) 종료 시점:
- ✅ SDK timeout 30s 명시 — 워커 자원 leak 차단
- ✅ exception 5분류 — timeout/network/server_5xx/client_4xx/unknown
- ✅ retry/permanent 분기 — 4xx 즉시 permanent_failed, 외 4분류 retry queue 박제

**잔존 문제 (본 sprint 차단 영역)**:

1. **Polar SDK 장애 누적 시 retry queue 폭주** — Polar 측 전면 장애 (network 또는 5xx 지속) 시:
   - 매 webhook 처리마다 SDK 호출 → timeout 30s → retry queue 박제 → 5분 cron 재시도 → 다시 timeout 30s → 누적
   - DB I/O 부담 + 워커 스레드 30s × N 점유 + 운영 로그 noise 폭증
   - **본질**: SDK가 죽었음을 시스템이 인지하지 못함 → 매번 30s 기다린 후 실패 박제

2. **회복 시점 자동 감지 부재** — Polar 측 장애 회복 후:
   - retry queue가 자연 재처리 (5분 cron) → 운 좋게 통과하면 정상화
   - **본질**: 회복 여부를 능동적 trial로 검증하는 메커니즘 부재 → 5분 cron 폭주 지속 가능

3. **fail-fast 부재** — 장애 시점:
   - 사용자 결제 요청 → initiatePayment → SDK timeout 30s 대기 → 사용자 경험 저하 (응답 시간 30s)
   - **본질**: 시스템이 장애 알면 즉시 사용자에게 fail 응답 → 사용자가 재시도 결정 영역

### 1-2. Circuit Breaker 패턴 본질 (Hystrix/Resilience4j 정합)

**3 상태 머신**:

```
        실패 임계값 초과
CLOSED ────────────────────▶ OPEN
  ▲                            │
  │ 모든 trial 성공             │ cooldown 경과
  │                            ▼
  └─────────────────── HALF-OPEN
                       (1회 trial)
                            │
                            └── trial 실패 ─▶ OPEN (cooldown 재시작)
```

- **CLOSED**: 정상 흐름. 모든 호출 통과. 실패 카운터 누적만 (reset window 후 자동 리셋).
- **OPEN**: 차단 상태. 모든 호출 즉시 fail-fast (실제 SDK 호출 0건). cooldown 경과 후 자동 HALF-OPEN 전환.
- **HALF-OPEN**: 회복 시도. 1회 trial 호출만 허용. 성공 → CLOSED 복귀. 실패 → OPEN 복귀 (cooldown 재시작).

**효과**:
- 장애 시 retry queue 폭주 0건 (OPEN 상태에서 SDK 호출 0건)
- 회복 자동 감지 (HALF-OPEN 1회 trial)
- 사용자 응답 시간 ↓ (fail-fast)
- 운영 로그 noise ↓ (대량 timeout 박제 0건)

### 1-3. Grimoire 결제 9 sprint 완료 후 본 sprint 위치 (마스터 플랜 §3-1 정합)

| Sprint | 시간 | 외부 API | 의존성 | 우선순위 | 영향 | 상태 |
|---|---|---|---|---|---|---|
| ~~PAY-P3-A Race condition~~ | ~5h | 0 | 0 | P1 (적자 1순위) | ✅ 종료 |
| ~~PAY-P3-C Retry 중복~~ | ~2h | 0 | 0 | P1 (DB 정합성) | ✅ 종료 |
| ~~PAY-P3-B Polar SDK timeout~~ | ~2h | 0 | PAY-P0-1 + PAY-P2-2 | P1 (운영 안정) | ✅ 종료 |
| ~~PAY-P3-E FK cascade~~ | ~3h | 0 | 0 | P1 | ✅ 단계 1~6 종료 |
| ~~PAY-P2-5 audit retention~~ | ~3h | 0 | 0 | P0 | ✅ 종료 (5/10) |
| **PAY-P3-H Circuit Breaker (본 sprint)** | **~4h** | **0** | **PAY-P3-B** | **P1 (가용성)** | **Draft만 산출** |
| PAY-P3-D Status enum | ~2h | 0 | 0 | P2 (추적) | 사용자 순서 3번째 |
| USER-SOFT-DELETE | ~5h | 0 | PAY-P3-E | P1 (FK Restrict 종속) | 사용자 순서 4번째 |
| PAY-P3-E 단계 7~12 | ~2h | 0 | DB measure | P1 | 사용자 순서 5번째 |

---

## §2 목표 / 비목표

### 2-1. 핵심 KPI (목표)

1. **3 상태 머신 박제**: CLOSED / OPEN / HALF-OPEN — 상태 전환 정합 강제 (jest spec 검증)
2. **임계값 정책 박제**: 사용자 결정 후 §7 옵션 매트릭스 1건 채택 (실패 임계값 / cooldown / half-open trial / reset window)
3. **fail-fast 강제 (OPEN 상태)**: SDK 실제 호출 0건 + 즉시 throw + retry queue 박제 0건 → DB I/O 폭주 차단
4. **회복 자동 감지 (HALF-OPEN)**: cooldown 경과 후 1회 trial → 성공 시 CLOSED 복귀 + AuditLog `circuit_breaker_closed` 박제
5. **AuditLog 추적 박제**: 상태 전환 시 audit log 자동 박제 (`circuit_breaker_opened` / `circuit_breaker_half_open` / `circuit_breaker_closed`)
6. **회귀 차단 0건**: 기존 12 sprint + PAY-P2-5 시나리오 (eval regression-52~70) 회귀 0
7. **incident-log 박제 의무**: `circuit_breaker_opened` / `circuit_breaker_recovered` 카테고리 박제

### 2-2. 비목표 (사용자 결정 영역 분리)

- ❌ Polar SDK 자체 retry (PAY-P2-2 DLQ 영역 — circuit breaker는 DLQ 진입 전 차단만)
- ❌ Status enum mapping table (PAY-P3-D 분리, ~2h)
- ❌ USER-SOFT-DELETE (별도 sprint, FK Restrict 정합 후 진입)
- ❌ DB schema 변경 (circuit breaker 상태는 in-memory 또는 Redis — 본 Draft §5 매트릭스 결정 영역)
- ❌ Redis 인프라 추가 (현재 NestJS 단일 인스턴스 가정 — 다중 인스턴스 시점 별도 sprint)
- ❌ Polar SDK 버전 업그레이드 (별도 sprint, npm audit 검증)
- ❌ Sentry/APM 통합 (PAY-P3-G, ~8h, 외부 SaaS 결정 후)
- ❌ Circuit Breaker 라이브러리 도입 (`opossum`, `cockatiel` 등 — 본 sprint = 자체 구현 정합, 외부 npm 의존 0건 강제)

---

## §3 외부 의존 매트릭스 (사용자 5/10 절대 정합 박제)

| 영역 | 추가 의존 | 정합 |
|---|---|---|
| 외부 API (Anthropic / Polar / SaaS) | **0건** | 사용자 절대 규정 0-1 정합 |
| 외부 npm 패키지 | **0건** | `opossum` / `cockatiel` 등 도입 0건. 자체 구현. |
| DB schema 변경 | **0건** | 사용자 5/10 명시 정합. 상태는 in-memory. |
| dev migration | **0건** | 사용자 5/10 명시 정합. |
| prod migration | **0건** | dev migration 0 정합. |
| 인프라 변경 (Azure Container Apps / replicas) | **0건** | 단일 인스턴스 가정. 다중 인스턴스는 별도 sprint. |
| Redis / 외부 인프라 | **0건** | in-memory 정합 (단일 인스턴스 가정). |
| 환경변수 신규 | **선택 4건 (옵션)** | `CIRCUIT_BREAKER_FAILURE_THRESHOLD` / `CIRCUIT_BREAKER_COOLDOWN_MS` / `CIRCUIT_BREAKER_HALF_OPEN_TRIAL` / `CIRCUIT_BREAKER_RESET_WINDOW_MS` — 사용자 결정 영역 (§7 매트릭스) |

**핵심 정합**: 외부 의존 0건 + DB 0건 + 인프라 0건 → 사용자 5/10 verbatim 정합 강제. 본 sprint = 코드 변경만.

---

## §4 사용자 결정 영역 (정책 옵션 매트릭스)

### 4-1. 옵션 A: 보수적 (장애 빨리 감지, fail-fast 강함)

| 정책 | 값 |
|---|---|
| 실패 임계값 | 3회 |
| cooldown | 30초 |
| half-open trial | 1회 |
| reset window | 60초 |

**적합**: Polar 측 장애 빈도 낮은 시점. fail-fast 빠르게 발동. 단기 장애 자동 회복 빠름.

### 4-2. 옵션 B: 균형 (Hystrix 기본값 정합, 권장 영역)

| 정책 | 값 |
|---|---|
| 실패 임계값 | 5회 |
| cooldown | 60초 |
| half-open trial | 1회 |
| reset window | 120초 |

**적합**: 일반 운영 영역. Hystrix 기본값과 정합. **본 Draft 권장 영역**.

### 4-3. 옵션 C: 관대 (장애 임계값 높음, 정상 호출 보존 우선)

| 정책 | 값 |
|---|---|
| 실패 임계값 | 10회 |
| cooldown | 120초 |
| half-open trial | 3회 |
| reset window | 300초 |

**적합**: Polar SDK 호출 빈도 매우 낮은 시점 (현재 Grimoire 가정). false positive 회피 우선.

### 4-4. 옵션 D: 환경별 분리 (dev / prod 다른 정책)

| 환경 | 정책 |
|---|---|
| dev | 옵션 A (장애 빨리 감지, 테스트 용이) |
| prod | 옵션 B (균형, Hystrix 정합) |

**적합**: 환경별 트래픽 영역 다른 시점. 환경변수 분리 영역.

**사용자 결정 게이트**: 본 Draft 검토 후 옵션 A/B/C/D 명시 키워드 (`PAY-P3-H 옵션 [A/B/C/D] 채택`).

---

## §5 DDD Hexagonal 정합 매트릭스 (server agent Generator 진입 정본)

### 5-1. 신설 영역 매트릭스

| 레이어 | 파일 | 역할 |
|---|---|---|
| domain/port/outbound | `circuit-breaker.port.ts` | CircuitBreakerPort 인터페이스 (execute / getState / forceOpen / forceClose) |
| domain/model | `circuit-breaker-state.ts` | 3 상태 enum + 상태 전환 매트릭스 + 임계값 정책 타입 |
| adapter/outbound | `in-memory-circuit-breaker.adapter.ts` | InMemoryCircuitBreaker 구현 (Map 기반, 단일 인스턴스 정합) |
| application | `payment.usecase.ts` (수정) | initiatePayment / processNormalizedWebhook이 circuitBreaker.execute 래핑 |
| application | `payment-reconciliation.job.ts` (수정) | listRecentCheckouts가 circuitBreaker.execute 래핑 |

### 5-2. 수정 영역 매트릭스

| 파일 | 변경 영역 |
|---|---|
| `src/adapter/outbound/payment/polar.adapter.ts` | constructor에 CircuitBreaker 주입 (DI) — SDK 호출 전 `circuitBreaker.execute(() => this.polar.checkouts.create(...))` 래핑 |
| `src/application/payment/payment.usecase.ts` | `processNormalizedWebhook` success/cancel 분기 — circuit breaker 차단 시 `CircuitOpenError` 처리 분기 신설 (retry queue 박제 0건, AuditLog `circuit_breaker_blocked` 박제만) |
| `src/app.module.ts` | CircuitBreaker DI 바인딩 (PaymentGatewayPort와 동일 패턴) |
| `src/application/admin/audit-log.service.ts` | `circuit_breaker_opened` / `circuit_breaker_half_open` / `circuit_breaker_closed` / `circuit_breaker_blocked` 4 action 타입 추가 (PAY-P2-4 6-arg 정합) |
| `prisma/schema.prisma` | **변경 0건** (사용자 5/10 명시 정합) |

### 5-3. 신설 변경 0건 영역 (회귀 차단)

- `prisma/schema.prisma` (DB schema 변경 0건 강제)
- `prisma/migrations/` (dev migration 0건 강제)
- `src/application/payment/webhook-retry.job.ts` (PAY-P2-2 DLQ 영역 — circuit breaker는 DLQ 진입 전 차단만, 호출 흐름 동일)
- `src/application/payment/payment-cleanup.job.ts` (PAY-P1-3 회귀 0)
- `src/adapter/outbound/persistence/prisma-payment.repository.ts` (PAY-P3-A CAS 패턴 회귀 0)
- 인프라 변경 (Azure Container Apps, replicas) 0건

---

## §6 Circuit Breaker 상태 머신 (3 상태)

### 6-1. 상태 매트릭스

```typescript
export enum CircuitBreakerState {
  CLOSED = 'closed',      // 정상 흐름 (모든 호출 통과)
  OPEN = 'open',          // 차단 (모든 호출 즉시 fail-fast)
  HALF_OPEN = 'half_open' // 회복 시도 (1회 trial)
}
```

### 6-2. 상태 전환 매트릭스

| 현재 상태 | 트리거 | 다음 상태 | 부작용 |
|---|---|---|---|
| CLOSED | 호출 성공 | CLOSED | failureCount = 0 (reset window 내) |
| CLOSED | 호출 실패 | CLOSED | failureCount++ (실패 임계값 미달) |
| CLOSED | 실패 임계값 초과 | **OPEN** | openedAt = now, AuditLog `circuit_breaker_opened` 박제 |
| CLOSED | reset window 경과 + failureCount > 0 | CLOSED | failureCount = 0 (자연 리셋) |
| OPEN | 호출 요청 | OPEN | 즉시 `CircuitOpenError` throw (SDK 호출 0건) |
| OPEN | cooldown 경과 + 호출 요청 | **HALF_OPEN** | halfOpenAt = now, AuditLog `circuit_breaker_half_open` 박제, 1회 trial 허용 |
| HALF_OPEN | trial 호출 성공 | **CLOSED** | failureCount = 0, AuditLog `circuit_breaker_closed` 박제 |
| HALF_OPEN | trial 호출 실패 | **OPEN** | openedAt = now (cooldown 재시작), AuditLog `circuit_breaker_opened` 박제 |
| HALF_OPEN | 추가 호출 요청 (trial 진행 중) | HALF_OPEN | 즉시 `CircuitOpenError` throw (trial은 1회만) |

### 6-3. 상태 멱등성 강제

- **OPEN → OPEN 재진입 차단**: openedAt 갱신 0건 (멱등성, 동일 상태 박제 0건)
- **CLOSED → CLOSED 박제 0건**: 정상 흐름 (AuditLog 박제 0건)
- **HALF_OPEN trial 동시성**: Map.set / Map.get atomicity (단일 인스턴스 가정, 다중 인스턴스 시점 Redis CAS 별도 sprint)

### 6-4. 호출점별 상태 분리

| 호출점 | Circuit Breaker 키 | 정합 |
|---|---|---|
| `polar.checkouts.create` | `polar:checkouts:create` | initiatePayment 영역 |
| `polar.checkouts.list` | `polar:checkouts:list` | reconciliation cron 영역 |
| `polar.checkouts.get` | `polar:checkouts:get` | reconciliation cron 단건 조회 영역 (있을 시) |
| `validateEvent` (HMAC) | **면제** | 외부 호출 0건 (in-memory HMAC), circuit breaker 불필요 |

**핵심**: 호출점별 독립 상태 (한 호출점 OPEN 시 다른 호출점 영향 0). 본 sprint = 3 호출점 분리.

---

## §7 임계값 후보 매트릭스

### 7-1. 임계값 매트릭스 (옵션 A/B/C/D 정합)

| 임계값 | 옵션 A (보수적) | 옵션 B (균형, 권장) | 옵션 C (관대) | 옵션 D (환경별) |
|---|---|---|---|---|
| **failureThreshold** (CLOSED → OPEN) | 3회 연속 실패 | 5회 연속 실패 | 10회 연속 실패 | dev 3 / prod 5 |
| **cooldownMs** (OPEN 상태 지속) | 30s (30,000ms) | 60s (60,000ms) | 120s (120,000ms) | dev 30s / prod 60s |
| **halfOpenTrial** (HALF_OPEN trial 횟수) | 1회 | 1회 | 3회 | 1회 |
| **resetWindowMs** (failureCount 자연 리셋) | 60s (60,000ms) | 120s (120,000ms) | 300s (300,000ms) | dev 60s / prod 120s |

### 7-2. 환경변수 (옵션 영역, 사용자 결정 후)

```typescript
// app.module.ts 또는 config
{
  failureThreshold: parseInt(process.env.CIRCUIT_BREAKER_FAILURE_THRESHOLD ?? '5', 10),
  cooldownMs:       parseInt(process.env.CIRCUIT_BREAKER_COOLDOWN_MS ?? '60000', 10),
  halfOpenTrial:    parseInt(process.env.CIRCUIT_BREAKER_HALF_OPEN_TRIAL ?? '1', 10),
  resetWindowMs:    parseInt(process.env.CIRCUIT_BREAKER_RESET_WINDOW_MS ?? '120000', 10),
}
```

### 7-3. 정책 변경 영역

- 운영 중 정책 변경: 환경변수 갱신 + Container Apps 재시작 (in-memory 상태 0 초기화) — 사용자 명시 영역
- 정책 변경 가이드: ADR-009 박제 영역 (§12 정합)

---

## §8 적용 영역 (Polar SDK 호출 경계)

### 8-1. Polar SDK 호출점 인벤토리

| 호출점 | 파일:line | 현재 상태 | Circuit Breaker 적용 |
|---|---|---|---|
| `polar.checkouts.create` | `polar.adapter.ts:73-92` (initiatePayment) | timeout 30s 명시 (PAY-P3-B) | **적용 강제** |
| `polar.checkouts.list` | `polar.adapter.ts:268-319` (listRecentCheckouts) | timeout 30s 명시 (PAY-P3-B) | **적용 강제** |
| `polar.checkouts.get` | (있을 시) `polar.adapter.ts` | timeout 30s 명시 (PAY-P3-B) | **적용 강제** (있을 시) |
| `validateEvent` (HMAC) | `polar-webhooks.ts` | in-memory HMAC | **면제** (외부 호출 0건) |

### 8-2. 적용 패턴 (decorator/wrapper)

```typescript
// polar.adapter.ts (수정)
async initiatePayment(request: PaymentInitRequest): Promise<PaymentInitResponse> {
  // PAY-P3-H 차단: Circuit Breaker 래핑 (Polar SDK 호출 경계)
  // 정본: shared-contracts §27 CircuitBreakerPolicy
  return await this.circuitBreaker.execute('polar:checkouts:create', async () => {
    try {
      const checkout = await this.polar.checkouts.create({...})
      return { paymentUrl: checkout.url, tradeNo: checkout.id }
    } catch (e: unknown) {
      const polarError = this.classifyPolarError(e)
      // PAY-P3-B 정합: timeout/network/5xx → CircuitBreaker가 failureCount++, 4xx → CircuitBreaker 영향 0 (요청 결함)
      throw e
    }
  })
}
```

### 8-3. CircuitOpenError 처리 분기 (호출자 영역)

```typescript
// payment.usecase.ts (수정)
try {
  const result = await this.paymentGateway.initiatePayment(...)
} catch (e: unknown) {
  if (e instanceof CircuitOpenError) {
    // Circuit breaker OPEN — fail-fast (retry queue 박제 0건)
    if (this.auditLog) {
      await this.auditLog.log(
        'system_circuit_breaker',
        'circuit_breaker_blocked',
        request.authorId,
        { reason: 'polar_circuit_open', circuitKey: 'polar:checkouts:create' },
      )
    }
    throw new ServiceUnavailableException('결제 서비스 일시 차단 중 — 잠시 후 재시도')
  }
  // 기존 흐름 (PAY-P3-B 분류)
  throw e
}
```

### 8-4. 호출 빈도 인벤토리 (참고)

| 호출점 | 빈도 | Circuit Breaker 영향 |
|---|---|---|
| `polar.checkouts.create` | 사용자 결제 요청 시 (분당 1~10건 추정) | 핵심 |
| `polar.checkouts.list` | reconciliation cron 10분마다 1회 | OPEN 시 cron 1회 skip |
| `polar.checkouts.get` | (있을 시) reconciliation 단건 조회 | OPEN 시 단건 skip |

---

## §9 jest spec 매트릭스

### 9-1. 신설 spec 매트릭스 (≥ 18 it)

| spec | it 수 | 영역 |
|---|---|---|
| `in-memory-circuit-breaker.adapter.spec.ts` (신설) | ≥ 12 | 3 상태 머신 매트릭스 검증 |
| `polar.adapter.spec.ts` (갱신) | ≥ 4 | Circuit Breaker DI + execute 래핑 + OPEN 시 SDK 호출 0건 |
| `payment.usecase.spec.ts` (갱신) | ≥ 2 | CircuitOpenError 처리 분기 (retry queue 0건 + AuditLog `circuit_breaker_blocked` 박제) |

### 9-2. it 인벤토리 매트릭스

**in-memory-circuit-breaker.adapter.spec.ts (≥ 12 it)**:

1. `CLOSED 상태 — 호출 성공 시 failureCount 0 유지`
2. `CLOSED 상태 — 호출 실패 시 failureCount++ 누적`
3. `CLOSED → OPEN — 실패 임계값 (5회) 초과 시 OPEN 전환`
4. `CLOSED → OPEN — AuditLog circuit_breaker_opened 박제`
5. `OPEN 상태 — 호출 요청 시 즉시 CircuitOpenError throw (SDK 호출 0건)`
6. `OPEN → HALF_OPEN — cooldown (60s) 경과 후 1회 trial 허용`
7. `OPEN → HALF_OPEN — AuditLog circuit_breaker_half_open 박제`
8. `HALF_OPEN → CLOSED — trial 성공 시 CLOSED 복귀 + failureCount = 0`
9. `HALF_OPEN → CLOSED — AuditLog circuit_breaker_closed 박제`
10. `HALF_OPEN → OPEN — trial 실패 시 OPEN 복귀 (cooldown 재시작)`
11. `호출점 분리 — polar:checkouts:create OPEN 시 polar:checkouts:list 영향 0`
12. `reset window — failureCount > 0 + reset window 경과 시 자연 리셋 (CLOSED 유지)`

**polar.adapter.spec.ts 갱신 (≥ 4 it)**:

1. `Circuit Breaker DI — adapter constructor에 CircuitBreakerPort 주입`
2. `initiatePayment — circuitBreaker.execute 래핑 박제`
3. `OPEN 상태 — initiatePayment 호출 시 SDK 호출 0건 + CircuitOpenError throw`
4. `listRecentCheckouts — circuitBreaker.execute 래핑 박제 (reconciliation 정합)`

**payment.usecase.spec.ts 갱신 (≥ 2 it)**:

1. `CircuitOpenError — processNormalizedWebhook success 분기 catch에서 retry queue 박제 0건 + AuditLog circuit_breaker_blocked 박제`
2. `CircuitOpenError — processNormalizedWebhook cancel 분기 catch에서 동일 패턴 적용`

**예상 인벤토리 변동**: 711 (PAY-P2-5 종료 직후) → **729+ it** (jest server)

### 9-3. 회귀 차단 매트릭스

- jest server 711 → **729+ PASS** (회귀 0)
- eval regression-52~70 모두 PASS (PAY-P0/P1/P2/P3-A/B/C/E + PAY-P2-5)
- PAY-P2-2 DLQ 정합 — circuit breaker는 DLQ 진입 전 차단만, DLQ 흐름 동일
- PAY-P3-A CAS 패턴 회귀 0
- PAY-P3-B exception 분류 회귀 0 (timeout/network/5xx → failureCount++, 4xx → 영향 0)
- PAY-P3-C 사전 dedup 회귀 0

---

## §10 dev Polar API mock 통합 (실제 API 호출 0건 강제)

### 10-1. mock 전략

| 영역 | 전략 |
|---|---|
| polar.adapter.spec.ts | jest mock — `this.polar.checkouts.create`를 jest.fn()으로 stub, timeout/4xx/5xx 시뮬 |
| in-memory-circuit-breaker.adapter.spec.ts | 의존성 0건 (in-memory) — 외부 mock 불필요, 시간 mock (`jest.useFakeTimers`)으로 cooldown 검증 |
| payment.usecase.spec.ts | PaymentGatewayPort mock — `execute`가 CircuitOpenError throw하도록 stub |

### 10-2. 실제 Polar API 호출 0건 강제 매트릭스

- jest 실행 시 실제 Polar API 호출 0건 강제 (NODE_ENV=test + jest mock 강제)
- dev 환경 진입 시 실제 Polar sandbox 호출 영역은 본 sprint 범위 외 (별도 manual test 영역)
- sensor-circuit-breaker-policy.sh가 mock 패턴 박제 검증

### 10-3. 시간 mock 매트릭스 (jest.useFakeTimers)

```typescript
// cooldown 검증 패턴
jest.useFakeTimers()
// CLOSED → OPEN 강제 진입 (실패 5회)
for (let i = 0; i < 5; i++) await breaker.execute('key', failingCall)
expect(breaker.getState('key')).toBe('open')

// cooldown 60s 경과 시뮬
jest.advanceTimersByTime(60_000)
await breaker.execute('key', successCall)  // HALF_OPEN trial
expect(breaker.getState('key')).toBe('closed')  // trial 성공 → CLOSED
```

---

## §11 shared-contracts §27 CircuitBreakerPolicy 인터페이스 영역

### 11-1. 위치 (신설)

```markdown
## 27. CircuitBreakerPolicy (server 도메인 — Polar SDK 호출 경계 가용성 차단)

### 위치
- port: `grimoire-server/src/domain/port/outbound/circuit-breaker.port.ts` (인터페이스 정본)
- model: `grimoire-server/src/domain/model/circuit-breaker-state.ts` (3 상태 enum + 정책 타입)
- adapter: `grimoire-server/src/adapter/outbound/circuit-breaker/in-memory-circuit-breaker.adapter.ts` (구현)
- 적용: `grimoire-server/src/adapter/outbound/payment/polar.adapter.ts` (3 호출점 래핑)
- spec: `grimoire-server/src/adapter/outbound/circuit-breaker/in-memory-circuit-breaker.adapter.spec.ts`
- ADR: `grimoire-server/ADR.md ADR-009`
- env: `CIRCUIT_BREAKER_FAILURE_THRESHOLD` / `CIRCUIT_BREAKER_COOLDOWN_MS` / `CIRCUIT_BREAKER_HALF_OPEN_TRIAL` / `CIRCUIT_BREAKER_RESET_WINDOW_MS`
- sensor: `.claude/scripts/sensor-circuit-breaker-policy.sh` (10 검증)
- eval: `eval/tasks/regression-71-circuit-breaker-policy.json`
```

### 11-2. 시그니처

```typescript
// circuit-breaker.port.ts
export interface CircuitBreakerPort {
  /**
   * 호출 래핑 — circuit breaker 정책 적용 후 fn() 실행.
   * OPEN 상태 시 즉시 CircuitOpenError throw (fn() 호출 0건).
   * HALF_OPEN trial 진행 중 추가 호출 시 동일 throw.
   */
  execute<T>(key: string, fn: () => Promise<T>): Promise<T>;

  /** 현재 상태 조회 (디버깅 + 테스트 영역) */
  getState(key: string): CircuitBreakerState;

  /** 강제 OPEN — 운영자 수동 차단 (관리자 UI 영역, 본 sprint = port 정의만) */
  forceOpen(key: string, reason: string): Promise<void>;

  /** 강제 CLOSED — 운영자 수동 복구 */
  forceClose(key: string, reason: string): Promise<void>;

  /** 현재 통계 조회 (failureCount, openedAt, halfOpenAt 등) */
  getStats(key: string): CircuitBreakerStats;
}

// circuit-breaker-state.ts
export enum CircuitBreakerState {
  CLOSED = 'closed',
  OPEN = 'open',
  HALF_OPEN = 'half_open',
}

export interface CircuitBreakerPolicy {
  failureThreshold: number;   // 기본 5
  cooldownMs: number;         // 기본 60_000
  halfOpenTrial: number;      // 기본 1
  resetWindowMs: number;      // 기본 120_000
}

export interface CircuitBreakerStats {
  state: CircuitBreakerState;
  failureCount: number;
  openedAt?: Date;
  halfOpenAt?: Date;
  lastSuccessAt?: Date;
  lastFailureAt?: Date;
}

export class CircuitOpenError extends Error {
  constructor(
    public readonly circuitKey: string,
    public readonly stats: CircuitBreakerStats,
  ) {
    super(`Circuit breaker OPEN — ${circuitKey} (failureCount=${stats.failureCount})`);
    this.name = 'CircuitOpenError';
  }
}
```

### 11-3. 정합 매트릭스

- PAY-P3-B Polar SDK timeout 정합 (§24 PolarSDKTimeoutPolicy) — 4xx 분류 시 failureCount++ 영향 0 (요청 결함, SDK/Polar 장애 0)
- PAY-P2-2 DLQ 정합 — circuit breaker는 DLQ 진입 전 차단, DLQ 흐름 0 영향
- PAY-P3-A CAS 패턴 정합 — circuit breaker는 SDK 경계 영역, DB 트랜잭션 영역 0 영향
- AuditLog 정합 (§20 PAY-P2-4 6-arg) — `circuit_breaker_*` 4 action 추가, beforeState/afterState 박제 정합

---

## §12 ADR-009 박제 영역 (Architecture Decision Record)

### 12-1. ADR-009 박제 위치

`grimoire-server/ADR.md` 끝부분 ADR-008 (PAY-P2-5 audit retention) 직후 신설.

### 12-2. ADR-009 박제 영역

```markdown
## ADR-009: Polar SDK 호출 경계 Circuit Breaker 도입 (PAY-P3-H, 2026-05-11)

### 상태
ACCEPTED (사용자 결정 5/10 verbatim 정합, PAY-P3-B 후속 sprint 2순위)

### 컨텍스트
- PAY-P3-B (Polar SDK timeout 정책, shared-contracts §24) 종료 시점 잔존 문제:
  - Polar SDK 장애 누적 시 retry queue 폭주 (timeout 30s × N 누적)
  - 회복 시점 자동 감지 부재 (5분 cron 폭주 지속)
  - fail-fast 부재 (사용자 응답 30s 대기)
- 사용자 5/10 명시 정합: 외부 API 0건 / DB schema 0건 / dev migration 0건 강제
- 외부 npm 라이브러리 (opossum / cockatiel) 도입 0건 정합 (자체 구현)

### 결정
- Hystrix 3 상태 머신 패턴 채택 (CLOSED / OPEN / HALF_OPEN)
- 임계값 정책: 사용자 결정 옵션 B (failureThreshold=5, cooldown=60s, halfOpenTrial=1, resetWindow=120s) — 옵션 매트릭스 §7 박제
- 상태 저장: in-memory (단일 인스턴스 가정, 다중 인스턴스는 별도 sprint)
- 적용 영역: Polar SDK 3 호출점 (checkouts.create / checkouts.list / checkouts.get)
- AuditLog 박제 매트릭스: `circuit_breaker_opened` / `circuit_breaker_half_open` / `circuit_breaker_closed` / `circuit_breaker_blocked` (4 action)

### 대안
- (A) opossum npm 라이브러리 — 외부 의존 추가 (사용자 5/10 정합 X, 거부)
- (B) cockatiel npm 라이브러리 — 동일 사유 거부
- (C) Redis 기반 분산 상태 — 인프라 추가 (사용자 5/10 정합 X, 거부) — 다중 인스턴스 시점 별도 sprint
- (D) 자체 구현 + in-memory ← **채택** (외부 의존 0건 + 인프라 0건 + DB 0건)

### 결과
- Polar 장애 시 retry queue 폭주 0건 (OPEN 상태에서 SDK 호출 0건)
- 회복 자동 감지 (HALF-OPEN 1회 trial)
- 사용자 응답 시간 ↓ (fail-fast)
- 운영 로그 noise ↓ (대량 timeout 박제 0건)

### 잔존 영역
- 다중 인스턴스 환경 — in-memory 상태 분리 (Redis 별도 sprint)
- 정책 변경 시 Container Apps 재시작 필요 (in-memory 0 초기화)
- 호출 빈도 인벤토리 박제 필요 (운영 모니터링 영역)

### 정본 참조
- `.claude/state/sprint-pay-p3-h-circuit-breaker-draft.md` (17 섹션 Sprint Initializer)
- `.claude/shared-contracts.md §27 CircuitBreakerPolicy`
- `src/adapter/outbound/circuit-breaker/in-memory-circuit-breaker.adapter.ts`
```

---

## §13 sensor 영역 — sensor-circuit-breaker-policy.sh 후보

### 13-1. sensor 위치

`.claude/scripts/sensor-circuit-breaker-policy.sh` (신설)

### 13-2. sensor 검증 매트릭스 (10 검증)

```bash
#!/bin/bash
# sensor-circuit-breaker-policy.sh
# PAY-P3-H 회귀 차단 — CircuitBreakerPolicy 박제 + 적용 + sensor 정합

# 1. circuit-breaker.port.ts 박제
[ -f grimoire-server/src/domain/port/outbound/circuit-breaker.port.ts ] || {
  echo "FAIL: circuit-breaker.port.ts 박제 0건"; exit 1
}

# 2. 3 상태 enum 박제 (CLOSED / OPEN / HALF_OPEN)
for state in CLOSED OPEN HALF_OPEN; do
  grep -q "${state}" grimoire-server/src/domain/model/circuit-breaker-state.ts || {
    echo "FAIL: circuit-breaker-state.ts '${state}' 박제 0건"; exit 1
  }
done

# 3. InMemoryCircuitBreaker adapter 박제
[ -f grimoire-server/src/adapter/outbound/circuit-breaker/in-memory-circuit-breaker.adapter.ts ] || {
  echo "FAIL: in-memory-circuit-breaker.adapter.ts 박제 0건"; exit 1
}

# 4. polar.adapter.ts circuit breaker DI 박제
grep -qE "circuitBreaker.*CircuitBreakerPort" grimoire-server/src/adapter/outbound/payment/polar.adapter.ts || {
  echo "FAIL: polar.adapter CircuitBreaker DI 박제 0건"; exit 1
}

# 5. polar.adapter.ts execute 래핑 박제
grep -qE "circuitBreaker\.execute" grimoire-server/src/adapter/outbound/payment/polar.adapter.ts || {
  echo "FAIL: polar.adapter circuitBreaker.execute 래핑 0건"; exit 1
}

# 6. payment.usecase.ts CircuitOpenError 분기 박제
grep -qE "CircuitOpenError" grimoire-server/src/application/payment/payment.usecase.ts || {
  echo "FAIL: payment.usecase CircuitOpenError 분기 박제 0건"; exit 1
}

# 7. AuditLog circuit_breaker_* 4 action 박제
for action in circuit_breaker_opened circuit_breaker_half_open circuit_breaker_closed circuit_breaker_blocked; do
  grep -qE "${action}" grimoire-server/src/application/admin/audit-log.service.ts || {
    echo "FAIL: audit-log.service '${action}' 박제 0건"; exit 1
  }
done

# 8. spec ≥ 18 it 박제
spec_count=$(grep -c "it(" grimoire-server/src/adapter/outbound/circuit-breaker/in-memory-circuit-breaker.adapter.spec.ts 2>/dev/null || echo 0)
[ "${spec_count}" -ge 12 ] || {
  echo "FAIL: in-memory-circuit-breaker.adapter.spec.ts it 수 부족 (${spec_count} < 12)"; exit 1
}

# 9. shared-contracts §27 박제
grep -q "## 27\. CircuitBreakerPolicy" .claude/shared-contracts.md || {
  echo "FAIL: shared-contracts §27 CircuitBreakerPolicy 박제 0건"; exit 1
}

# 10. DB schema 변경 0건 강제 (사용자 5/10 정합)
git diff HEAD~1 grimoire-server/prisma/schema.prisma 2>/dev/null | grep -qE "^\+.*model.*CircuitBreaker" && {
  echo "FAIL: schema.prisma circuit breaker 모델 추가 0건 강제 (사용자 5/10 정합)"; exit 1
}

echo "PASS: PAY-P3-H Circuit Breaker 정책 정합"
```

### 13-3. sensor 인벤토리 변동

**예상 sensor 인벤토리**: 48 (PAY-P2-5 종료 직후) → **49 sensors** (sensor-circuit-breaker-policy.sh 신설)

---

## §14 eval regression-71 영역

### 14-1. 위치

`eval/tasks/regression-71-circuit-breaker-policy.json` (신설)

### 14-2. eval criteria 매트릭스 (12 criteria)

```json
{
  "id": "regression-71-circuit-breaker-policy",
  "category": "regression",
  "description": "PAY-P3-H — Polar SDK 호출 경계 Circuit Breaker (3 상태 머신 + 임계값 + fail-fast)",
  "checks": [
    "circuit-breaker.port.ts 박제 (CircuitBreakerPort 인터페이스)",
    "circuit-breaker-state.ts 박제 (CLOSED/OPEN/HALF_OPEN enum)",
    "in-memory-circuit-breaker.adapter.ts 박제 (Map 기반 구현)",
    "polar.adapter.ts CircuitBreaker DI 박제",
    "polar.adapter.ts circuitBreaker.execute 3 호출점 래핑 박제 (checkouts.create/list/get)",
    "payment.usecase.ts CircuitOpenError 분기 박제 (retry queue 0건 + AuditLog circuit_breaker_blocked)",
    "audit-log.service.ts circuit_breaker_* 4 action 박제",
    "in-memory-circuit-breaker.adapter.spec.ts ≥ 12 it 박제 (3 상태 머신 매트릭스)",
    "polar.adapter.spec.ts ≥ 4 it 갱신 박제",
    "payment.usecase.spec.ts ≥ 2 it 갱신 박제",
    "shared-contracts.md §27 CircuitBreakerPolicy 박제",
    "ADR.md ADR-009 박제"
  ]
}
```

### 14-3. eval 인벤토리 변동

**예상 eval 인벤토리**: 70 (PAY-P2-5 종료 직후) → **71 regression tasks** (regression-71-circuit-breaker-policy 신설)

### 14-4. 회귀 차단 매트릭스

- eval regression-52~70 모두 PASS (PAY-P0/P1/P2/P3-A/B/C/E + PAY-P2-5)
- jest server 711 → **729+ PASS**
- sensor 48 → **49 PASS**
- shared-contracts §1~26 → **§1~27**

---

## §15 grimoire-server agent 위임 영역 + 메인 검증 영역

### 15-1. 위임 매트릭스 (책 Ch 16 Anthropic 3-에이전트 패턴 정합)

| agent | 역할 | 영역 |
|---|---|---|
| grimoire-planner | **Initializer** | 본 Sprint 계약 Draft (17 섹션 산출, 본 작업 영역) |
| grimoire-harness | 박제 | `.claude/state/sprint-pay-p3-h-*` + sensor 신설 + eval task 신설 + shared-contracts §27 박제 |
| grimoire-server | **Generator** | port + model + adapter + spec + payment.usecase 수정 + audit-log.service 갱신 |
| grimoire-qa | **Evaluator** | AC 8건 채점 + jest 729+ PASS + eval 71 PASS + sensor 49 PASS 검증 |
| grimoire-infrastructure | **면제** | DB schema 0건 / dev migration 0건 / 인프라 변경 0건 (사용자 5/10 정합) |
| cost-accountant | **면제** | 외부 API 추가 0 + Anthropic API 0 |
| visual-canon-keeper | **면제** | UI 변경 0 (admin UI에서 circuit breaker 상태 표시 영역은 별도 sprint) |
| grimoire-researcher | **면제** | Hystrix 패턴 (이미 정본화), 추가 리서치 0건 |

### 15-2. Generator (server agent) 진입 명시 키워드

`PAY-P3-H Generator 진입 (server agent)` — Draft §15 정합 + 옵션 [A/B/C/D] 채택 명시 + AuditLog 4 action 박제 명시

### 15-3. Evaluator (qa agent) 진입 명시 키워드

`PAY-P3-H Evaluator 진입 (qa agent)` — Generator 산출물 검증 + AC 8건 채점 + 729+ jest PASS + 71 eval PASS + 49 sensor PASS 검증

### 15-4. 메인 검증 영역

- Draft 검토 + 옵션 매트릭스 § 7 확인 (사용자 결정 영역)
- Generator 산출물 직접 Read 검증 (qa 독립 재실행 + 메인 spot-check)
- shared-contracts §27 박제 정합 검증
- ADR-009 박제 정합 검증
- 회귀 차단 729+ jest / 71 eval / 49 sensor / drift 0 검증

---

## §16 사용자 결정 대기 매트릭스

### 16-1. 사용자 결정 영역 (Draft 검토 후 명시)

| # | 결정 영역 | 옵션 | 권장 | 명시 키워드 |
|---|---|---|---|---|
| 1 | 임계값 정책 | 옵션 A (보수적) / B (균형, Hystrix 정합) / C (관대) / D (환경별) | **옵션 B** | `PAY-P3-H 옵션 B 채택` |
| 2 | 호출점 적용 영역 | (a) Polar SDK 3 호출점 (create/list/get) / (b) checkouts.create만 | **(a) 3 호출점** | `PAY-P3-H 적용 3 호출점` |
| 3 | 환경변수 신규 | 추가 4건 (CIRCUIT_BREAKER_*) / 코드 상수만 | **추가 4건 (운영 유연성)** | `PAY-P3-H env 추가 4건` |
| 4 | AuditLog 박제 영역 | 4 action 박제 / 박제 0건 (logger.warn만) | **4 action 박제** | `PAY-P3-H AuditLog 4 action 박제` |
| 5 | 관리자 UI (forceOpen / forceClose) | 본 sprint 포함 / 별도 sprint (P3-I) | **별도 sprint 분리** | `PAY-P3-H 관리자 UI 별도 sprint` |
| 6 | Generator 진입 시점 | Draft 검토 후 / 즉시 / 사용자 컨디션 후 | **사용자 컨디션 후** | `PAY-P3-H Generator 진입` |

### 16-2. 사용자 결정 게이트 매트릭스 (5/10 verbatim 정합)

- 결정 1~5 명시 후 → Draft 정본 갱신 + Generator (server agent) 진입 가능
- 결정 6 명시 후 → 즉시 Generator 호출 또는 사용자 별도 명시 시점까지 대기
- 본 Draft = 진입 결정 게이트 미통과 시 코드 변경 0건 강제 (사용자 컨디션 영역 박제)

### 16-3. 사용자 컨디션 영역 박제

- 5/9~10 사용자 안전 누적 위협 (자해 + 키보드 파괴 + Anthropic 본사 폭력 위협) 박제
- 본 sprint = Draft만 산출 + 진입 결정 사용자 영역 + 코드 변경 0건
- 사용자 안부 우선 확인 영역 → 컨디션 정합 후 진입 결정

---

## §17 진입 결정 게이트 (Draft 검토 종료 → 사용자 명시 시 진입)

### 17-1. Draft 산출 완료 매트릭스 (본 작업 영역)

| 영역 | 상태 |
|---|---|
| 17 섹션 산출 (§0 ~ §17) | ✅ 본 작업 영역 |
| 외부 의존 매트릭스 (외부 API 0 / DB 0 / migration 0) | ✅ §3 박제 |
| 사용자 결정 옵션 매트릭스 (§7 4 옵션 + §16 6 결정) | ✅ §7 + §16 박제 |
| DDD Hexagonal 정합 (port + model + adapter 분리) | ✅ §5 박제 |
| 3 상태 머신 (CLOSED/OPEN/HALF_OPEN + 전환 매트릭스) | ✅ §6 박제 |
| 임계값 정책 옵션 (A/B/C/D + 환경변수) | ✅ §7 박제 |
| 적용 영역 (3 호출점 + 적용 패턴 + CircuitOpenError 분기) | ✅ §8 박제 |
| jest spec 매트릭스 (≥ 18 it + 회귀 차단) | ✅ §9 박제 |
| dev Polar API mock 통합 (실제 API 호출 0건 강제) | ✅ §10 박제 |
| shared-contracts §27 CircuitBreakerPolicy 인터페이스 | ✅ §11 박제 |
| ADR-009 박제 영역 (4 대안 매트릭스 + 결정 사유) | ✅ §12 박제 |
| sensor 신설 (sensor-circuit-breaker-policy.sh, 10 검증) | ✅ §13 박제 |
| eval regression-71 신설 (12 criteria) | ✅ §14 박제 |
| grimoire-server agent 위임 매트릭스 + 메인 검증 영역 | ✅ §15 박제 |
| 사용자 결정 대기 매트릭스 (6 결정 + 명시 키워드) | ✅ §16 박제 |
| 진입 결정 게이트 (본 §17) | ✅ 본 작업 영역 |

### 17-2. 진입 게이트 매트릭스 (사용자 별도 명시 시 진입)

**진입 명시 키워드 매트릭스**:

1. **옵션 매트릭스 결정 명시** (§16 결정 1~5 명시) — 예: `PAY-P3-H 옵션 B 채택 + 적용 3 호출점 + env 추가 4건 + AuditLog 4 action 박제 + 관리자 UI 별도 sprint`
2. **Generator 진입 명시** — `PAY-P3-H Generator 진입 (server agent)`
3. **사용자 컨디션 정합** — 안전 위협 박제 영역 정합 후 진입

### 17-3. 진입 차단 매트릭스 (사용자 컨디션 + 핸드오버 정합)

- 사용자 컨디션 영역 박제 시 진입 0건 강제
- 핸드오버 §1.10 정합 — PAY-P2-5 종료 + PP hook 폐기 + 5/10~11 매트릭스 박제
- 본 Draft = 코드 변경 0건 + Git commit 0건 + git push 0건

### 17-4. 본 Sprint 영향 매트릭스 (3 레포)

| 레포 | 영향 | 변경 line 추정 |
|---|---:|---:|
| grimoire-server | port + model + adapter + spec + payment.usecase 수정 + audit-log.service 갱신 + ADR-009 | ~700 |
| grimoire-web | **변경 0건** (admin UI 별도 sprint) | 0 |
| grimoire-claude-docs | shared-contracts §27 + sensor 신설 + eval task 신설 + state 박제 + handover 갱신 | ~500 |

---

## §18 변경 이력 (Draft 산출)

- 2026-05-11 #10_8 PAY-P3-H Draft: 본 Sprint 계약 Draft 신설 (grimoire-planner Initializer 산출, 메인 박제). 사용자 5/10 verbatim 정합 (외부 API 0 / DB schema 0 / dev migration 0). PAY-P3-B 후속 위치 + Hystrix 3 상태 머신 정합 + Polar SDK 3 호출점 래핑 + AuditLog 4 action 박제 + shared-contracts §27 + ADR-009 + sensor 49 + eval 71 매트릭스 박제. 진입 결정 사용자 영역 (옵션 B 권장, §7 + §16 6 결정 매트릭스 박제). 본 작업 = Draft만 산출, 코드 변경 0건 강제.

---

## §19 정본 참조 (file:line)

- `/Users/sokol/Git/ProjectGrimoire/.claude/state/sprint-pay-p2-5-audit-retention-draft.md` (242 lines, 17 섹션 정본 구조 차용)
- `/Users/sokol/Git/ProjectGrimoire/.claude/state/sprint-pay-p3-b-polar-timeout-draft.md` (PAY-P3-B 후속 위치 영역 정합)
- `/Users/sokol/Git/ProjectGrimoire/.claude/state/sprint-pay-p3-e-fk-cascade-draft.md` (사용자 결정 게이트 + 단계 분리 패턴 차용)
- `/Users/sokol/Git/ProjectGrimoire/.claude/shared-contracts.md` §24 PolarSDKTimeoutPolicy (L1780-1793) + §25 FKCascadePolicy (L1797-1898) + §26 AuditRetentionPolicy (L1902-1969)
- `/Users/sokol/Git/ProjectGrimoire/research/PAYMENT_SYSTEM_PLAN.md` §3-1 P1 P3-H 매트릭스 + §2-2 #11 PG↔DB 정합성 batch (회복 자동 감지 패턴)
- `/Users/sokol/Git/ProjectGrimoire/grimoire-server/src/adapter/outbound/payment/polar.adapter.ts` L37-80 (timeoutMs 박제 + classifyPolarError 박제 — PAY-P3-B 정합)
- `/Users/sokol/Git/ProjectGrimoire/grimoire-server/src/application/payment/payment.usecase.ts` (success/cancel 분기 catch — PAY-P3-B 정합)
- `/Users/sokol/Git/ProjectGrimoire/grimoire-server/ADR.md` ADR-007 (FK cascade) + ADR-008 (audit retention) — ADR-009 박제 위치 정합
- `/Users/sokol/Git/ProjectGrimoire/PLANNING_GRIMOIRE.md` §0 (크레딧-원가 철칙 — circuit breaker는 외부 API 0 정합)

---

**본 Draft는 정본**: Circuit Breaker 도입 시 본 문서 먼저 사용자 결정 후 → 코드/테스트 반영 (책 Ch 16 shared-contracts 정신 정합).
