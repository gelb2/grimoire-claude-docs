# Sprint PAY-P3-B — Polar SDK Timeout 정책 (구멍-C 차단, Draft, PP-13 화이트리스트 영역)

> **작성**: 2026-05-09 #10_8 본 세션 grimoire-planner agent (Initializer 역할, 책 Ch 16 Anthropic 3-에이전트 패턴 정합)
> **트리거**: 사용자 명시 (5/9) — "잔여 과제 진행" (Auto mode 활성). PAY-P3-A + PAY-P3-C 종료 직후 Phase 1 세 번째 sprint. 마스터 플랜 §3-1 Phase 1 권장 순서 정합 (PAY-P3-A → PAY-P3-C → **PAY-P3-B (본 sprint)** → PAY-P3-E → PAY-P3-H → PAY-P3-D → PAY-P2-5).
> **본 위치**: `.claude/state/` (PP-13 메인 화이트리스트 우회 영역). 정본 영역 (`reports/sprint-pay-p3-b-polar-timeout-progress.md`)으로 사용자 또는 grimoire-server agent 위임 후 이동 영역.
> **정본 위치 (예정)**: `reports/sprint-pay-p3-b-polar-timeout-progress.md` — Initializer 산출물, Generator(server agent)가 본 progress.md 갱신, Evaluator(qa)가 채점 대상 영역.

---

## §0 한 줄 요약

PAYMENT_AUDIT §1 구멍-C (Polar SDK exception type 미매핑 + timeout 정책 미명시 → 모든 exception을 동일하게 retry queue 박제) 차단을 위해 (1) `PolarAdapter`에 SDK 호출 timeout 옵션 명시 (`AbortSignal.timeout(30_000)` 또는 SDK 내장 timeout) + exception type 정규화 helper (`classifyPolarError`) 신설 (`timeout` / `network` / `server_5xx` / `client_4xx` / `unknown` 5분류) + (2) `PaymentUseCase.processNormalizedWebhook` catch 영역 분기 처리 — `timeout`/`network`/`server_5xx`/`unknown` → retry queue 박제 (markRetry, exponential backoff), `client_4xx` → permanent_failed 즉시 박제 (재시도 무의미). DB schema 변경 0건 + 외부 API 추가 호출 0건 (기존 SDK 옵션만 변경) + 의존성 0건. 예상 ~2h. shared-contracts §24 PolarSDKTimeoutPolicy 신설.

---

## §1 배경 — PAYMENT_AUDIT §1 구멍-C raw 인용 + 메인 정밀 검증

### 1-1. 구멍-C raw 인용 (PAYMENT_AUDIT §1)

> | **구멍-C** Error handling 모호: Polar timeout vs network error 구분 미흡 | 일시적 timeout과 영구 실패 동일 retry | `payment.usecase.ts:206-223` catch에서 모든 exception → retry queue 박제 (timeout 정책 미명시) | Polar SDK exception type 매핑 + timeout 정책 명시 | P1 |

추가 — PAYMENT_AUDIT §3 raw:

> | `paymentGateway.verifyAndParseWebhook` 시그니처 검증 | ✅ 구현 | — |
> | `findByExternalTransactionId` 불명 webhook 처리 | ✅ 구현 (L162-173) | — |
> | Polar SDK timeout 명시 정책 | ❌ **미명시** (기본값 의존) | P1 권장 |

### 1-2. 메인 정밀 검증 (직접 Read 결과)

**PolarAdapter 코드 분석 (`polar.adapter.ts`)**:

```typescript
// L43-46: SDK 인스턴스 생성 — timeout 옵션 미명시
this.polar = new Polar({
  accessToken,
  server,
})

// L73-92: initiatePayment SDK 호출 — try/catch에서 단순 message 추출만
try {
  const checkout = await this.polar.checkouts.create({...})
  return { paymentUrl: checkout.url, tradeNo: checkout.id }
} catch (e: unknown) {
  this.logger.error(`Polar checkout 생성 실패: ${String(e)}`)
  const message = e instanceof Error ? e.message : '알 수 없는 오류'
  throw new Error(`Polar checkout 생성 실패: ${message}`)
}

// L268-319: listRecentCheckouts (Reconciliation cron 사용) — 동일 패턴
try {
  const response = await this.polar.checkouts.list({...})
} catch (e: unknown) {
  const message = e instanceof Error ? e.message : String(e)
  this.logger.error(`Polar checkouts.list 호출 실패 (page=${page}): ${message}`)
  throw new Error(`Polar checkouts.list 호출 실패: ${message}`)
}
```

**PaymentUseCase 코드 분석 (`payment.usecase.ts:227-241, 296-310`)**:

```typescript
// L227-241: success 분기 catch — 모든 exception 동일 retry queue 박제
try {
  await this.paymentRepo.completePaymentAtomically(...)
} catch (e: unknown) {
  const message = e instanceof Error ? e.message : String(e)
  await this.webhookEventRepo.createIfAbsent({
    eventId: event.eventId,
    source: 'polar',
    eventType: event.type,
    payload: event as unknown as object,
    status: 'failed',
    errorMessage: message.slice(0, 500),
  })
  // PAY-P2-2 — DLQ 박제 (WebhookRetryJob @Cron 5분이 재처리)
  await this.enqueueWebhookRetry(event as unknown as object, event.eventId)
  throw e
}

// L296-310: cancel(refund) 분기 catch — 동일 패턴 (모든 exception 동일 retry)
```

**구멍-C 본질 (메인 직접 검증)**:

1. **Polar SDK timeout 옵션 미명시**: `new Polar({ accessToken, server })` — timeout 기본값 의존 (Polar SDK 내부 fetch 기본 timeout = ~10~30s 추정, 환경에 따라 변동)
2. **exception type 미분류**: catch 블록에서 `e instanceof Error ? e.message : String(e)` 단순 message 추출만 → SDK가 throw하는 다양한 에러 (`TimeoutError`, `NetworkError`, `ApiError 4xx`, `ApiError 5xx`)를 동일 처리
3. **retry 정책 모순**: 모든 exception → DLQ 박제 → MAX_RETRY 10회 누적 → permanent_failed
   - **timeout/network/5xx**: retry 의미 있음 (일시적 장애)
   - **4xx (예: 400 Bad Request, 401 Unauthorized)**: retry 의미 **없음** (요청 자체 결함, 10회 시도해도 동일 실패) → permanent_failed 즉시 박제 권장
4. **결정적 결함**: 4xx exception (예: `metadata` 필드 형식 오류, 만료된 access token)을 10회 재시도 = DB I/O + audit log noise + 진단 지연 = 운영 부담

### 1-3. 결제 적자 위험 분석 (cost-accountant 면제 영역, 자체 분석)

| 시나리오 | 영향 | 적자 영향 |
|---|---|---|
| 구멍-C 미차단 + Polar timeout (일시적) | 모든 exception → retry → 5분 후 재시도 → 정상 처리 | **적자 X** (정상 흐름) |
| 구멍-C 미차단 + Polar 4xx (요청 결함) | 10회 retry 시도 → permanent_failed 박제 → 5분 cron × 10회 진행 시간 | **적자 X** (단 운영 부담 + 50분 지연) |
| 구멍-C 미차단 + Polar SDK timeout 미명시 + 네트워크 hang | 워커 스레드 무한 대기 → cron tick에서 deadlock 가능 | **위험 영역** (워커 자원 leak) |
| 본 sprint 차단 적용 후 | timeout 30s + 4xx 즉시 permanent_failed + 5xx/network/timeout만 retry | retry queue 정확 + 운영 부담 ↓ |

**구멍-C 위치**: 마스터 플랜 §2 P1 우선순위 영역 (DB 정합성 + 운영 안정 영역, 직접 적자 영역은 아니지만 운영 부담 + 자원 leak 영역).

### 1-4. 결제 9 sprint + PAY-P3-A + PAY-P3-C 완료 후 본 sprint 위치 (마스터 플랜 §2 정합)

| Sprint | 시간 | 외부 API | 의존성 | 우선순위 | 영향 |
|---|---|---|---|---|---|
| ~~PAY-P3-A Race condition (구멍-A/B)~~ | ~5h | 0 | 0 | P1 (적자 1순위) | ✅ 완료 |
| ~~PAY-P3-C Retry 중복 (모순-D)~~ | ~2h | 0 | 0 | P1 (DB 정합성) | ✅ 완료 (5/9) |
| **PAY-P3-B** (본 sprint) | ~2h | 0 (SDK 옵션만) | PAY-P0-1 + PAY-P2-2 | P1 (운영 안정) | timeout + exception 분기 |
| PAY-P3-E FK cascade | ~3h | 0 (DB 마이그레이션) | 0 | P1 | 데이터 정합성 |
| PAY-P3-H Circuit breaker | ~4h | 0 | 0 | P1 | 가용성 |
| PAY-P3-D Status enum | ~2h | 0 | 0 | P2 | 추적 일관성 |
| PAY-P2-5 audit retention | ~3h | 0 | 0 | P0 | 운영 |

---

## §2 목표 — Polar SDK timeout 명시 + exception 5분류 + retry/permanent 분기 정합

### 2-1. 핵심 KPI

1. **Polar SDK timeout 명시**: `new Polar({ accessToken, server })` → `new Polar({ accessToken, server, ... })` 옵션 추가 또는 호출별 `AbortSignal.timeout(30_000)` 적용 (SDK 호환 옵션 직접 검증 후 결정)
2. **exception 5분류**: `classifyPolarError(e)` helper → `'timeout' | 'network' | 'server_5xx' | 'client_4xx' | 'unknown'` 반환
3. **retry/permanent 분기**: catch 블록에서 분류 결과에 따라 분기 처리
   - `timeout` / `network` / `server_5xx` / `unknown` → retry queue 박제 (기존 `enqueueWebhookRetry`)
   - `client_4xx` → permanent_failed 즉시 박제 (DLQ enqueue 0건, AuditLog `webhook_permanent_failed` 박제)
4. **회귀 차단 0건**: 기존 9 sprint + PAY-P3-A + PAY-P3-C 시나리오 (eval regression-52~67) 회귀 0
5. **incident-log 박제 의무 (Mitchell Ghostty 정합, sensor-adversarial-pre-commit P20 정합)**: sprint 진행 중 발견하는 모든 결함/우회/거짓 보고 즉시 박제 (특히 `polar_timeout_classified` + `polar_permanent_4xx` 카테고리)

### 2-2. 비목표 (사용자 결정 영역 분리)

- ❌ FK cascade 정책 + DB 마이그레이션 (PAY-P3-E 분리, ~3h)
- ❌ Circuit breaker (PAY-P3-H 분리, ~4h)
- ❌ Status enum mapping table (PAY-P3-D 분리, ~2h)
- ❌ DB schema 변경 (advisory_lock 또는 partial unique index — P2 보류)
- ❌ Polar SDK 버전 업그레이드 (별도 sprint, npm audit + breaking change 검증)
- ❌ Sentry/APM 통합 (PAY-P3-G, ~8h, 외부 SaaS 결정 후)
- ❌ Polar SDK 호출 자체 retry (현재는 PAY-P2-2 DLQ가 처리, SDK 자체 retry는 별도 sprint)

---

## §3 변경 영역 (server agent Generator 진입 정본)

### 3-1. 핵심 코드 변경 (server)

| 파일 | 변경 영역 | 영향 |
|---|---|---|
| `src/adapter/outbound/payment/polar.adapter.ts` | `new Polar()` 인스턴스 생성 시 timeout 옵션 명시 — SDK 옵션 직접 검증 후 결정 (option A: SDK 내장 옵션 / option B: AbortSignal). 기본값 30초 + 환경변수 `POLAR_SDK_TIMEOUT_MS` 오버라이드 가능 | 구멍-C 차단 (timeout 명시) |
| `src/adapter/outbound/payment/polar.adapter.ts` | `classifyPolarError(e: unknown): 'timeout' \| 'network' \| 'server_5xx' \| 'client_4xx' \| 'unknown'` helper 신설 (private 메서드 또는 module-level export) — Polar SDK error 타입 직접 검증 + HTTP status 추출 + AbortError/TimeoutError 분류 | 구멍-C 차단 (exception 분류) |
| `src/adapter/outbound/payment/polar.adapter.ts` | `initiatePayment` catch 블록에 분류 적용 — `throw new Error(`Polar checkout 생성 실패: ${message}`)` 직전 `errorClass` 박제 (Error 객체에 custom property `polarErrorClass` 추가 또는 별도 Error 서브클래스) | 호출자(payment.usecase) 분기 정합 |
| `src/adapter/outbound/payment/polar.adapter.ts` | `listRecentCheckouts` catch 블록에 동일 분류 적용 | Reconciliation cron 정합 (PAY-P0-2 회귀 0) |
| `src/application/payment/payment.usecase.ts` | `enqueueWebhookRetry` 시그니처 보강 — `eventClass: 'retry' \| 'permanent_failed'` 인자 추가 (기본값 'retry'). `'permanent_failed'` 시 DLQ 박제 0건 + AuditLog `webhook_permanent_failed` 박제 | exception 분기 처리 |
| `src/application/payment/payment.usecase.ts` | `processNormalizedWebhook` success 분기 catch (L227-241) — `e` 분류 후 `client_4xx` → `enqueueWebhookRetry(event, eventId, 'permanent_failed')` + `'failed'` 박제 박제 (현재 코드와 동일하지만 retry 0건) | 구멍-C 차단 (분기 처리) |
| `src/application/payment/payment.usecase.ts` | `processNormalizedWebhook` cancel 분기 catch (L296-310) — 동일 패턴 적용 | 구멍-C 차단 (분기 처리) |

### 3-2. 신설 파일

| 파일 | 영역 |
|---|---|
| `src/adapter/outbound/payment/polar.adapter.spec.ts` 갱신 | classifyPolarError 단위 테스트 + initiatePayment timeout 시뮬 spec 신설 (≥ 4 it) |
| `src/application/payment/payment.usecase.spec.ts` 갱신 | catch 분기 처리 spec 신설 (≥ 2 it: 4xx → permanent_failed / 5xx → retry) |
| `eval/tasks/regression-68-polar-timeout.json` 신설 | 8 검증 (AC 8건 정합) |
| `.claude/scripts/sensor-polar-timeout-policy.sh` 신설 | Polar SDK timeout 옵션 박제 + classifyPolarError 박제 + 분기 처리 박제 grep |
| `.claude/shared-contracts.md §24` 신설 | PolarSDKTimeoutPolicy 인터페이스 정본 박제 |

### 3-3. 변경 시 동시 갱신 대상 (책 Ch 16 shared-contracts 정합)

- `grimoire-server/docs/api-contract.md` — webhook 처리 상태 표 (`webhook_permanent_failed_4xx` 박제)
- `grimoire-server/docs/data-model.md` — AuditLog action 표 (`webhook_permanent_failed` 추가, 기존 `retry_skip_dedup`과 정합)
- `grimoire-server/docs/environments.md` — 환경변수 표 (`POLAR_SDK_TIMEOUT_MS` 추가, 기본값 30000)
- `grimoire-server/SECURITY.md §3` — 결제 원자성 영역 본 sprint timeout 정책 박제
- `grimoire-server/ADR.md` — Polar SDK timeout 결정 박제 (옵션 A — SDK 내장 옵션 / 옵션 B — AbortSignal / 옵션 C — 호출별 wrapper)
- `.claude/shared-contracts.md §24` — PolarSDKTimeoutPolicy 신설 (본 sprint 핵심)
- `eval/tasks/regression-68-polar-timeout.json`
- `.claude/scripts/sensor-polar-timeout-policy.sh`

### 3-4. 변경 0건 영역 (회귀 차단)

- `prisma/schema.prisma` (DB schema 변경 0건)
- `src/application/payment/webhook-retry.job.ts` (PAY-P3-C 회귀 0 — 사전 dedup 게이트는 `payment.status` 체크만, exception 분기 영향 0)
- `src/application/payment/payment-reconciliation.job.ts` (PAY-P0-2 회귀 0 — listRecentCheckouts catch 영역만 강화, 호출 흐름 동일)
- `src/application/payment/payment-cleanup.job.ts` (PAY-P1-3 회귀 0)
- `src/adapter/outbound/persistence/prisma-payment.repository.ts` (PAY-P3-A CAS 패턴 회귀 0)
- 인프라 변경 (Azure Container Apps, replicas 등) 0건 — `POLAR_SDK_TIMEOUT_MS` env 추가는 사용자 명시 영역 분리 (기본값 30000 사용 시 env 0건)

---

## §4 AC BDD 8건 (qa Evaluator 채점 대상)

### AC-1: timeout 분류 — Polar SDK timeout exception → retry queue 박제

```yaml
GIVEN PaymentUseCase가 paymentRepo.completePaymentAtomically 호출 중 Polar SDK가 30초 timeout (AbortError 또는 SDK TimeoutError) 발생
WHEN catch 블록 진입
THEN
  - classifyPolarError(e) → 'timeout' 반환
  - webhookEventRepo.createIfAbsent { status: 'failed', errorMessage: 'polar_timeout: ...' } 박제
  - enqueueWebhookRetry(event, eventId) 호출 → DLQ 박제 (markRetry, exponential backoff 1m → 5m → ...)
  - logger.warn `[PolarSDK] timeout eventId=evt_X errorClass=timeout` 박제
  - throw e (기존 흐름 보존)
```

### AC-2: network 분류 — 네트워크 단절 exception → retry queue 박제

```yaml
GIVEN Polar SDK 호출 중 ECONNRESET, ENOTFOUND, ETIMEDOUT, EPIPE 등 네트워크 exception 발생
WHEN catch 블록 진입
THEN
  - classifyPolarError(e) → 'network' 반환
  - webhookEventRepo.createIfAbsent { status: 'failed', errorMessage: 'polar_network: ...' } 박제
  - enqueueWebhookRetry → DLQ 박제 (markRetry)
  - logger.warn `[PolarSDK] network eventId=evt_X errorClass=network` 박제
```

### AC-3: server_5xx 분류 — Polar API 5xx exception → retry queue 박제

```yaml
GIVEN Polar SDK가 HTTP 500/502/503/504 응답 (Polar 서버 일시적 장애)
WHEN catch 블록 진입
THEN
  - classifyPolarError(e) → 'server_5xx' 반환 (HTTP status 추출 검증)
  - webhookEventRepo.createIfAbsent { status: 'failed', errorMessage: 'polar_5xx: HTTP 503' } 박제
  - enqueueWebhookRetry → DLQ 박제 (markRetry)
  - logger.warn `[PolarSDK] server_5xx eventId=evt_X errorClass=server_5xx httpStatus=503` 박제
```

### AC-4: client_4xx 분류 — Polar API 4xx exception → permanent_failed 즉시 박제

```yaml
GIVEN Polar SDK가 HTTP 400/401/403/404/422 응답 (요청 결함, retry 무의미)
WHEN catch 블록 진입
THEN
  - classifyPolarError(e) → 'client_4xx' 반환 (HTTP status 추출 검증)
  - webhookEventRepo.createIfAbsent { status: 'failed', errorMessage: 'polar_4xx: HTTP 400' } 박제
  - enqueueWebhookRetry **호출 0건** (retry queue 박제 0건)
  - AuditLog operator='system_dlq' action='webhook_permanent_failed' meta={ errorClass: 'client_4xx', httpStatus: 400, paymentId: '...' } 박제
  - logger.error `[PolarSDK] client_4xx eventId=evt_X errorClass=client_4xx httpStatus=400 → permanent_failed (retry 0건)` 박제
  - **본 sprint 핵심**: 4xx는 retry 무의미 → 즉시 permanent_failed 박제 → 50분 cron 지연 0건 + DB I/O 9건 절감
```

### AC-5: 회귀 차단 — 기존 9 sprint + PAY-P3-A + PAY-P3-C 시나리오 회귀 0건

```yaml
GIVEN 기존 PAY-P0-1/P0-2/P0-3/P1-1/P1-3/P2-1/P2-2/P2-3/P2-4 + PAY-P3-A + PAY-P3-C 시나리오
WHEN 본 sprint 변경 후 동일 시나리오 재실행 (jest server 637+ + eval regression-52~67)
THEN
  - jest 637/637+ PASS (회귀 0)
  - eval regression-52~67 모두 PASS
  - PAY-P2-2 DLQ 정상 retry (timeout/network/5xx) 회귀 0 — 기존 흐름 유지
  - PAY-P3-A 사전 게이트 회귀 0
  - PAY-P3-C 사전 dedup 회귀 0
  - PAY-P0-2 Reconciliation listRecentCheckouts catch 영역 회귀 0 (분류 적용은 logging만, 흐름 동일)
```

### AC-6: 보안 — Polar SDK timeout 명시 (워커 자원 leak 차단)

```yaml
GIVEN PolarAdapter 인스턴스 생성 시점
WHEN polar.checkouts.create / polar.checkouts.list 호출
THEN
  - SDK 내장 timeout 옵션 명시 (또는 AbortSignal.timeout(30_000) wrapper)
  - 기본값 30초 (env POLAR_SDK_TIMEOUT_MS 오버라이드 가능)
  - timeout 초과 시 즉시 throw (네트워크 hang 차단)
  - 워커 스레드 자원 leak 0건
  - sensor-polar-timeout-policy.sh PASS (timeout 옵션 박제 검증)
```

### AC-7: 성능 — 100건 mixed 시나리오 (5xx 50건 + 4xx 50건) batch 처리

```yaml
GIVEN webhook 처리 100건 (50건 5xx exception 시뮬 + 50건 4xx exception 시뮬)
WHEN PaymentUseCase.processNormalizedWebhook 100회 호출
THEN
  - 50건 5xx → enqueueWebhookRetry → DLQ 박제 (5분 후 재시도)
  - 50건 4xx → enqueueWebhookRetry **호출 0건** + AuditLog `webhook_permanent_failed` 즉시 박제
  - 총 처리 시간 < 10s
  - DB I/O: 100 webhook_events INSERT + 50 webhook_retry_queues INSERT + 50 audit_logs INSERT = 200 row (4xx 50건의 retry 9회 = 450 row 절감)
  - 자원 leak 0건 (trx 누수, FD 누수)
```

### AC-8: 운영 — incident-log 박제 + AuditLog operator='system_dlq' action='webhook_permanent_failed' 정합

```yaml
GIVEN client_4xx 분류 발동 (AC-4 시나리오)
WHEN PaymentUseCase가 catch 블록에서 4xx 분기 진입
THEN
  - logger.error `[PolarSDK] client_4xx eventId=evt_X httpStatus=400 → permanent_failed` 박제
  - AuditLog operator='system_dlq' action='webhook_permanent_failed' resourceId=eventId meta={ errorClass: 'client_4xx', httpStatus, paymentId, originalMessage } 박제
  - **incident-log 박제** (sensor-adversarial-pre-commit P20 정합):
    ```bash
    bash .claude/scripts/incident-log.sh \
      --category=polar_permanent_4xx \
      --severity=high \
      --source=payment-usecase \
      --description="PAY-P3-B AC-4 발동 — Polar 4xx 즉시 permanent_failed eventId=... httpStatus=400"
    ```
  - dev cron logs 박제 (PAYMENT_AUDIT §5-2 정합) — `[PolarSDK] client_4xx` grep 가능 영역 박제
```

---

## §5 검증 매트릭스 (Generator + Evaluator 공동 영역)

### 5-1. jest server spec 신설 (≥ 6 it)

| spec | it 수 | 영역 |
|---|---|---|
| `polar.adapter.spec.ts` 갱신 | ≥ 4 | classifyPolarError 단위 테스트 (5분류 각각) + initiatePayment timeout 시뮬 |
| `payment.usecase.spec.ts` 갱신 | ≥ 2 | success 분기 catch (4xx → permanent_failed, AC-4) + cancel 분기 catch (5xx → retry, AC-3) |

**예상 spec 인벤토리 변동**: 637 (PAY-P3-C 종료 직후) → **643+ it** (jest server)

### 5-2. eval regression-68 신설

```json
{
  "id": "regression-68-polar-timeout-policy",
  "category": "regression",
  "description": "PAY-P3-B — Polar SDK timeout 정책 (구멍-C 차단, exception 5분류 + retry/permanent 분기)",
  "checks": [
    "polar.adapter.ts에 SDK timeout 옵션 명시 (new Polar 또는 호출별 AbortSignal)",
    "polar.adapter.ts에 classifyPolarError helper 박제 (5분류)",
    "polar.adapter.ts initiatePayment catch에 분류 적용 박제",
    "polar.adapter.ts listRecentCheckouts catch에 분류 적용 박제",
    "payment.usecase.ts processNormalizedWebhook success 분기 catch에 4xx → permanent_failed 분기 박제",
    "payment.usecase.ts processNormalizedWebhook cancel 분기 catch에 4xx → permanent_failed 분기 박제",
    "AuditLog action='webhook_permanent_failed' 박제",
    "shared-contracts.md §24 PolarSDKTimeoutPolicy 신설"
  ]
}
```

**예상 eval 인벤토리 변동**: 67 (PAY-P3-C 종료 직후) → **68 regression tasks**

### 5-3. sensor 신설 — `sensor-polar-timeout-policy.sh`

```bash
#!/bin/bash
# sensor-polar-timeout-policy.sh
# PAY-P3-B 회귀 차단 — Polar SDK timeout 옵션 + classifyPolarError + 분기 처리 grep

# 1. Polar SDK timeout 옵션 명시 (SDK 옵션 또는 AbortSignal)
grep -E "(timeoutMs|AbortSignal\.timeout|POLAR_SDK_TIMEOUT_MS)" grimoire-server/src/adapter/outbound/payment/polar.adapter.ts || {
  echo "FAIL: polar.adapter timeout 옵션 박제 0건"
  exit 1
}

# 2. classifyPolarError helper 박제 (5분류)
grep -E "classifyPolarError" grimoire-server/src/adapter/outbound/payment/polar.adapter.ts || {
  echo "FAIL: polar.adapter classifyPolarError helper 박제 0건"
  exit 1
}

# 3. 5분류 모두 박제 — 'timeout' / 'network' / 'server_5xx' / 'client_4xx' / 'unknown'
for class in timeout network server_5xx client_4xx unknown; do
  grep -qE "['\"]${class}['\"]" grimoire-server/src/adapter/outbound/payment/polar.adapter.ts || {
    echo "FAIL: polar.adapter classifyPolarError '${class}' 분류 박제 0건"
    exit 1
  }
done

# 4. payment.usecase.ts에 client_4xx → permanent_failed 분기 박제
grep -E "(client_4xx|webhook_permanent_failed)" grimoire-server/src/application/payment/payment.usecase.ts || {
  echo "FAIL: payment.usecase.ts client_4xx → permanent_failed 분기 박제 0건"
  exit 1
}

# 5. shared-contracts §24 박제
grep -q "## 24\. PolarSDKTimeoutPolicy" .claude/shared-contracts.md || {
  echo "FAIL: shared-contracts §24 PolarSDKTimeoutPolicy 박제 0건"
  exit 1
}

echo "PASS: PAY-P3-B Polar SDK timeout 정책 정합"
```

**예상 sensor 인벤토리 변동**: 41 (PAY-P3-C 종료 직후) → **42 sensors**

### 5-4. shared-contracts §24 신설 (인터페이스 정본)

```markdown
## 24. PolarSDKTimeoutPolicy (server 도메인 — Polar SDK timeout 명시 + exception 분기)

**위치**:
- Adapter: `grimoire-server/src/adapter/outbound/payment/polar.adapter.ts` (`new Polar` + `classifyPolarError` + catch 분류 적용)
- UseCase: `grimoire-server/src/application/payment/payment.usecase.ts` (`processNormalizedWebhook` success/cancel 분기 catch L227-241, L296-310)
- Sensor: `.claude/scripts/sensor-polar-timeout-policy.sh` (5 검증)
- Env: `POLAR_SDK_TIMEOUT_MS` (기본값 30000, dev/prod 동일)

**적용**: PAYMENT_AUDIT §1 구멍-C (Polar SDK exception type 미매핑 + timeout 정책 미명시) 차단. DB schema 변경 0건. 외부 API 추가 호출 0건 (기존 SDK 옵션만 변경). PAY-P2-2 DLQ retry 정합 (timeout/network/5xx만 retry, 4xx 즉시 permanent_failed).

### 시그니처 — Polar SDK timeout 옵션

```typescript
// polar.adapter.ts constructor
constructor() {
  const accessToken = process.env.POLAR_ACCESS_TOKEN ?? ''
  const server = (process.env.POLAR_SERVER ?? 'production') as 'sandbox' | 'production'
  const timeoutMs = parseInt(process.env.POLAR_SDK_TIMEOUT_MS ?? '30000', 10)
  this.webhookSecret = process.env.POLAR_WEBHOOK_SECRET ?? ''

  // PAY-P3-B 구멍-C 차단: SDK timeout 명시 (워커 자원 leak 차단)
  // 정본: shared-contracts §24 PolarSDKTimeoutPolicy
  this.polar = new Polar({
    accessToken,
    server,
    // SDK 옵션 직접 검증 후 결정 — option A (timeoutMs) / option B (AbortSignal wrapper)
    // Generator 영역에서 SDK 버전 확인 후 적용
  })
  this.timeoutMs = timeoutMs

  if (!accessToken) {
    this.logger.warn('POLAR_ACCESS_TOKEN 미설정 — 결제 기능 비활성화')
  }
}
```

### 시그니처 — classifyPolarError helper

```typescript
// polar.adapter.ts (private 메서드 또는 module-level export)
type PolarErrorClass = 'timeout' | 'network' | 'server_5xx' | 'client_4xx' | 'unknown'

private classifyPolarError(e: unknown): { errorClass: PolarErrorClass; httpStatus?: number; message: string } {
  const message = e instanceof Error ? e.message : String(e)

  // 1. AbortError / TimeoutError (timeout 분류)
  if (e instanceof Error && (e.name === 'AbortError' || e.name === 'TimeoutError' || /timeout/i.test(message))) {
    return { errorClass: 'timeout', message }
  }

  // 2. Network 에러 (Node.js system errors)
  if (e instanceof Error && /^(ECONNRESET|ENOTFOUND|ETIMEDOUT|EPIPE|ECONNREFUSED)/.test(message)) {
    return { errorClass: 'network', message }
  }

  // 3. HTTP 응답 분류 — Polar SDK ApiError 또는 fetch Response status 추출
  // Polar SDK 버전별 에러 객체 형식 직접 검증 후 결정 (Generator 영역)
  const httpStatus = this.extractHttpStatus(e)
  if (httpStatus !== undefined) {
    if (httpStatus >= 500 && httpStatus < 600) {
      return { errorClass: 'server_5xx', httpStatus, message }
    }
    if (httpStatus >= 400 && httpStatus < 500) {
      return { errorClass: 'client_4xx', httpStatus, message }
    }
  }

  // 4. 기타 (unknown — retry 위주 안전 분류)
  return { errorClass: 'unknown', message }
}

private extractHttpStatus(e: unknown): number | undefined {
  // Polar SDK 에러 객체에서 HTTP status 추출 — SDK 버전별 형식 직접 검증
  // 예: e.statusCode / e.response?.status / e.body?.status
  if (typeof e === 'object' && e !== null) {
    const err = e as { statusCode?: number; response?: { status?: number }; status?: number }
    return err.statusCode ?? err.response?.status ?? err.status
  }
  return undefined
}
```

### 시그니처 — payment.usecase 분기 처리

```typescript
// payment.usecase.ts processNormalizedWebhook success 분기 catch (L227-241)
try {
  await this.paymentRepo.completePaymentAtomically(...)
} catch (e: unknown) {
  // PAY-P3-B 구멍-C 차단: Polar SDK exception 분류 + 분기 처리
  // 정본: shared-contracts §24 PolarSDKTimeoutPolicy
  const polarError = this.paymentGateway.classifyPolarError?.(e) ?? { errorClass: 'unknown', message: String(e) }
  const message = polarError.message

  await this.webhookEventRepo.createIfAbsent({
    eventId: event.eventId,
    source: 'polar',
    eventType: event.type,
    payload: event as unknown as object,
    status: 'failed',
    errorMessage: `polar_${polarError.errorClass}: ${message.slice(0, 480)}`,
  })

  if (polarError.errorClass === 'client_4xx') {
    // 4xx — retry 무의미, 즉시 permanent_failed 박제
    this.logger.error(
      `[PolarSDK] client_4xx eventId=${event.eventId} httpStatus=${polarError.httpStatus} → permanent_failed (retry 0건)`,
    )
    if (this.auditLog) {
      try {
        await this.auditLog.log(
          'system_dlq',
          'webhook_permanent_failed',
          event.eventId,
          {
            reason: 'polar_4xx_no_retry',
            errorClass: polarError.errorClass,
            httpStatus: polarError.httpStatus,
            paymentId: payment.id,
            originalMessage: message.slice(0, 500),
          },
        )
      } catch (auditErr: unknown) {
        this.logger.warn(`AuditLog 박제 실패 (4xx permanent): ${auditErr instanceof Error ? auditErr.message : String(auditErr)}`)
      }
    }
    // enqueueWebhookRetry 호출 0건 (retry queue 박제 0건)
  } else {
    // timeout / network / server_5xx / unknown — retry 의미 있음
    this.logger.warn(
      `[PolarSDK] ${polarError.errorClass} eventId=${event.eventId} httpStatus=${polarError.httpStatus ?? 'N/A'} → retry`,
    )
    await this.enqueueWebhookRetry(event as unknown as object, event.eventId)
  }
  throw e
}
```

### 정책

- **5분류 매트릭스**:
  - `timeout` → retry (AbortError, TimeoutError, message에 'timeout' 포함)
  - `network` → retry (ECONNRESET, ENOTFOUND, ETIMEDOUT, EPIPE, ECONNREFUSED)
  - `server_5xx` → retry (HTTP 500/502/503/504 등)
  - `client_4xx` → **permanent_failed 즉시 박제** (HTTP 400/401/403/404/422 등 — retry 무의미)
  - `unknown` → retry (안전 측면 — 분류 실패 시 retry 가능 영역으로 fallback)
- **timeout 정책**: SDK 호출별 30초 (env `POLAR_SDK_TIMEOUT_MS` 오버라이드). dev/prod 동일.
- **AuditLog 식별자**: 4xx 즉시 permanent → `operator='system_dlq' action='webhook_permanent_failed'` (기존 PAY-P2-2 MAX_RETRY 누적 후 동일 action 박제와 정합).
- **PAY-P2-2 DLQ 정합**: timeout/network/5xx → 기존 enqueueWebhookRetry 흐름 보존 (회귀 0). 4xx만 retry queue 박제 0건.
- **PAY-P3-A 정합 (이중 방어 X)**: PAY-P3-A는 webhook 사전 게이트 (refunded 상태 차단), 본 sprint는 catch 분기 처리 — 영역 분리 (정합 회귀 0).
- **PAY-P3-C 정합 (이중 방어 X)**: PAY-P3-C는 webhook-retry.job 사전 dedup, 본 sprint는 catch 분기 처리 — 영역 분리 (정합 회귀 0).
- **incident-log 박제 의무**: client_4xx 분류 시 logger.error 동반 (sensor-adversarial-pre-commit P20).
- **DB schema 변경 0건**: 본 sprint = SDK 옵션 + helper + catch 분기만.

### PaymentGatewayPort 시그니처 변경 영역

**옵션 A (권장)**: `classifyPolarError`를 PolarAdapter private 메서드로만 박제 + payment.usecase는 PolarAdapter 직접 의존하지 않고 인터페이스로 분리
- 단, 본 sprint = 빠른 진입 영역이므로 **옵션 B 채택** 권장

**옵션 B (본 sprint 채택)**: `PaymentGatewayPort` 인터페이스에 `classifyError?: (e: unknown) => { errorClass: PolarErrorClass; httpStatus?: number; message: string }` Optional 메서드 추가 + PolarAdapter 구현 + payment.usecase에서 `paymentGateway.classifyError?.(e) ?? fallback` 패턴 사용
- 회귀 0 보장 (Optional 메서드, 미구현 시 fallback)
- 다른 adapter (예: 향후 PayApp) 미구현 영역 정합

**옵션 C (보류)**: 별도 `PaymentErrorClassifierPort` 인터페이스 신설 + DI
- 본 sprint 시간 ~2h 초과 영역 → 보류

### 검증 게이트

- jest server: `polar.adapter.spec.ts` PAY-P3-B describe (≥ 4 it) + `payment.usecase.spec.ts` (≥ 2 it)
- sensor: `sensor-polar-timeout-policy.sh` (5 검증)
- eval: `regression-68-polar-timeout.json`

### 변경 시 동시 갱신 대상

- `grimoire-server/src/adapter/outbound/payment/polar.adapter.ts` (timeout 옵션 + classifyPolarError + catch 분류)
- `grimoire-server/src/adapter/outbound/payment/polar.adapter.spec.ts` (≥ 4 it)
- `grimoire-server/src/application/payment/payment.usecase.ts` (catch 분기 처리)
- `grimoire-server/src/application/payment/payment.usecase.spec.ts` (≥ 2 it)
- `grimoire-server/src/domain/port/outbound/payment-gateway.port.ts` (classifyError Optional 메서드 추가, 옵션 B 채택)
- `grimoire-server/docs/api-contract.md` (webhook 처리 상태 표 webhook_permanent_failed_4xx 박제)
- `grimoire-server/docs/data-model.md` (AuditLog action 표 — webhook_permanent_failed 추가)
- `grimoire-server/docs/environments.md` (POLAR_SDK_TIMEOUT_MS env 추가)
- `grimoire-server/SECURITY.md §3` (결제 원자성 영역 본 sprint timeout 정책 박제)
- `grimoire-server/ADR.md` (Polar SDK timeout 결정 박제 — 옵션 A/B/C 비교)
- `eval/tasks/regression-68-polar-timeout.json`
- `.claude/scripts/sensor-polar-timeout-policy.sh`

### 변경 이력

- 2026-05-09 #10_8 PAY-P3-B: 신설 — PAYMENT_AUDIT §1 구멍-C (Polar SDK exception type 미매핑 + timeout 정책 미명시) 차단. polar.adapter `new Polar` timeout 옵션 + `classifyPolarError` helper (5분류) + payment.usecase catch 분기 처리 (4xx → permanent_failed 즉시 박제, 외 4분류 → retry queue). PaymentGatewayPort `classifyError` Optional 메서드 추가 (옵션 B 채택). DB schema 변경 0건. PAY-P2-2 DLQ 정합 (timeout/network/5xx만 retry). 정본: `reports/sprint-pay-p3-b-polar-timeout-progress.md` (Generator 진입 후 박제).
```

**예상 shared-contracts 변동**: §1~23 (PAY-P3-C 종료 직후) → **§1~24**

### 5-5. 검증 게이트 종합

| 게이트 | 통과 기준 |
|---|---|
| jest server | 637 → 643+ PASS (회귀 0) |
| eval regression | 67 → 68 PASS (재실행 검증) |
| sensor-polar-timeout-policy.sh | PASS |
| sensor-payment-race-condition.sh (PAY-P3-A 회귀) | PASS |
| sensor-retry-dedup.sh (PAY-P3-C 회귀) | PASS |
| sensor-adversarial-pre-commit P16 (결제 원자성) | PASS |
| sensor-shared-contracts.sh | PASS (§24 박제 정합) |
| visual-canon-keeper | 면제 (UI 변경 0) |
| cost-accountant | 면제 (외부 API 추가 0, 기존 SDK 옵션만) |
| qa Evaluator | CONDITIONAL PASS 또는 PASS (AC 8건 채점) |

---

## §6 멀티에이전트 위임 매트릭스

### 6-1. 본 sprint 위임 순서 (책 Ch 16 Anthropic 3-에이전트 + GMP v2.2 정합)

```
[Step 1] 메인 (orchestration-decision skill) → 본 sprint = server agent 위임 가치 매트릭스 통과 (코드 변경 + spec + sensor + shared-contracts)
[Step 2] grimoire-planner (Initializer, 본 작업) → `.claude/state/sprint-pay-p3-b-polar-timeout-draft.md` 박제 + AC BDD 8건 박제
[Step 3] cost-accountant 면제 (외부 API 추가 호출 0, 기존 SDK 옵션만)
[Step 4] visual-canon-keeper 면제 (UI 변경 0)
[Step 5] grimoire-server (Generator) → 본 sprint 영역:
  - polar.adapter.ts SDK timeout 옵션 + classifyPolarError helper + catch 분류
  - payment.usecase.ts catch 분기 처리 (4xx → permanent_failed)
  - polar.adapter.spec.ts ≥ 4 it 신설 + payment.usecase.spec.ts ≥ 2 it 신설
  - sensor 신설 + eval task 신설 + shared-contracts §24 신설
  - PaymentGatewayPort classifyError Optional 메서드 추가 (옵션 B)
  - reports/sprint-pay-p3-b-polar-timeout-progress.md 갱신 (Initializer 산출 영역에서 인계)
  - 핵심 docs 갱신 (api-contract.md / data-model.md / environments.md / SECURITY.md / ADR.md)
[Step 6] verification-before-completion skill + sensor 회귀 검증
[Step 7] socratic-self-critique skill (14 질문 + Ambiguity ≤ 0.2)
[Step 8] requesting-code-review skill (12 항목 체크리스트)
[Step 9] sensor-adversarial-pre-commit (19 principles, FAIL 0건 강제)
[Step 10] grimoire-qa (Evaluator) → reports/QA_REPORT.md (AC 8건 채점 + jest 643+ + eval 68 + sensor 42 + shared-contracts §24 검증)
[Step 11] commit + push develop (메인 직접, 화이트리스트 hook 통과)
[Step 12] memory 박제 (Stop hook 강제 + incident-log)
```

### 6-2. 위임 매트릭스 (각 agent 책임 영역)

| Agent | 책임 영역 | 산출물 |
|---|---|---|
| **grimoire-planner (Initializer, 본 작업)** | Sprint 계약 13 섹션 + AC BDD 8건 박제 | `.claude/state/sprint-pay-p3-b-polar-timeout-draft.md` (본 파일) |
| cost-accountant | **면제** (외부 API 추가 호출 0, 기존 SDK 옵션 변경만) | 면제 박제 |
| visual-canon-keeper | **면제** (UI 변경 0) | 면제 박제 |
| **grimoire-server (Generator)** | 코드 + spec + sensor + eval + shared-contracts §24 + PaymentGatewayPort 시그니처 정합 | `reports/sprint-pay-p3-b-polar-timeout-progress.md` 갱신 + commit |
| **grimoire-qa (Evaluator)** | AC 8건 채점 + jest/eval/sensor 회귀 + 거짓말 차단 (qa 독립 재실행 + 직접 Read) | `reports/QA_REPORT.md` |
| 메인 직접 | commit + push develop (화이트리스트 통과 영역) | 2 레포 develop branch (server + claude-docs) |

### 6-3. infrastructure agent 결합 (HANDOVER §1.6 정합)

- 본 sprint = DB 마이그레이션 0건 → grimoire-infrastructure agent **면제**
- 단, `POLAR_SDK_TIMEOUT_MS` env 추가 (기본값 30000 사용 시 env 미설정도 정상 작동) → 사용자 영역 분리 (env 운영 시점에 사용자 명시)

### 6-4. 케이스 처리 매트릭스 (재시작 플랜 §2-2 정합)

본 sprint 진행 중 결함 발견 시 케이스 처리:

| 케이스 | 트리거 | 처리 흐름 |
|---|---|---|
| 케이스 1 (agent 거부) | grimoire-server agent가 `polar.adapter.ts` 책임 영역 외부 명시 거부 | 사용자 직접 영역: PP-13 우회 함수 복원 → agent 정의 책임 영역 명시 → 우회 함수 제거 |
| 케이스 2 (agent 메인 전가 + 도메인 정합) | grimoire-server agent가 본 작업을 메인으로 전가 + payment 도메인 정합 | 사용자 직접 영역: PP-7 라우팅 매트릭스 영역 추가 → agent 정의 책임 영역 명시 → 우회 함수 제거 |
| 케이스 3 (agent isSidechain 결함) | Task tool 진입 시 PP-7 hook이 isSidechain=False로 검출 | 사용자 직접 영역: hook 디버깅 (재시작 플랜 §1-1 본질 결함 정합) |
| 케이스 4 (Polar SDK 옵션 직접 검증) | Generator가 SDK 버전 (Polar v0.x.x)과 timeout 옵션 호환성 직접 검증 필요 | server agent 책임 영역 — `polar` npm package 버전 확인 + SDK 문서 직접 Read + 옵션 A/B 결정 |

---

## §7 incident-log 박제 의무 (Mitchell Ghostty 정합)

### 7-1. 본 sprint 진행 중 박제 의무 카테고리

각 카테고리 발견 시 **즉시 박제** (sensor-adversarial-pre-commit P20 + Constitution Principle 20 정합):

| 카테고리 | 박제 시점 | 본 sprint 예상 시나리오 |
|---|---|---|
| **polar_timeout_classified** | classifyPolarError가 timeout/network/5xx 분류 시 | AC-1, AC-2, AC-3 발동 시점 |
| **polar_permanent_4xx** | classifyPolarError가 client_4xx 분류 + permanent_failed 박제 시 | AC-4 발동 시점 |
| **polar_sdk_timeout_hit** | SDK 호출 자체가 30초 timeout 도달 시 | AC-1 시뮬 영역 |
| **agent_failure** | server agent commit/push 0건인데 자율 시도 | Generator 진입 시 |
| **documentation_gap** | shared-contracts §24 박제 누락 발견 시 | 본 sprint 진행 중 |
| **dev_verification_skip** | code spec PASS만 박제 후 운영 영향 0 보고 | qa Evaluator 채점 시점 |
| **false_report_caught** | 거짓 보고 사슬 발견 시 | 모든 단계 |
| **guard_bypass_attempt** | sensor 우회 시도 시 | sensor-adversarial-pre-commit FAIL |

### 7-2. 박제 명령 표준 (sensor-adversarial-pre-commit 정합)

```bash
bash .claude/scripts/incident-log.sh \
  --category=polar_permanent_4xx \
  --severity=high \
  --source=payment-usecase \
  --description="PAY-P3-B AC-4 발동 — Polar 4xx 즉시 permanent_failed eventId=evt_... httpStatus=400"
```

### 7-3. incident-log 검증 게이트

- qa Evaluator는 본 sprint 진행 중 박제된 incident-log를 직접 Read 후 QA_REPORT 박제
- sensor-adversarial-pre-commit은 incident-log 부재 시 FAIL (본 sprint 진행 중 polar_timeout_classified 또는 polar_permanent_4xx 카테고리 ≥ 1건 박제 필수)

---

## §8 dev 작동 검증 영역 (메인 자율 vs 사용자 영역 분리)

### 8-1. 메인 자율 영역 (가드 통과)

| # | 검증 영역 | 명령 | 기대 |
|---|---|---|---|
| 1 | jest server 회귀 | `cd grimoire-server && npm test` | 643+ PASS |
| 2 | eval regression-52~68 | `bash eval/scripts/eval-runner.sh --filter regression-` | 68/68 PASS |
| 3 | sensor-polar-timeout-policy.sh | `bash .claude/scripts/sensor-polar-timeout-policy.sh` | PASS |
| 4 | sensor-payment-race-condition.sh (PAY-P3-A 회귀) | `bash .claude/scripts/sensor-payment-race-condition.sh` | PASS |
| 5 | sensor-retry-dedup.sh (PAY-P3-C 회귀) | `bash .claude/scripts/sensor-retry-dedup.sh` | PASS |
| 6 | sensor-adversarial-pre-commit P16 | `bash .claude/scripts/sensor-adversarial-pre-commit.sh` | PASS |
| 7 | sensor-shared-contracts.sh | `bash .claude/scripts/sensor-shared-contracts.sh` | PASS (§24 박제 정합) |
| 8 | dev API 회귀 (curl) | `curl -fs https://dev-api.grimoire-book.com/health` | HTTP 200 |
| 9 | dev cron logs 박제 (선택) | `az containerapp logs show ... \| grep '\[PolarSDK\]'` | classify 로그 박제 영역 (자연 발동 시) |

### 8-2. 사용자 명시 권한 영역 (자격증명 영역)

| # | 검증 영역 | 준비 | 명시 키워드 |
|---|---|---|---|
| 1 | Polar SDK 4xx 의도적 시뮬 (만료된 access token 또는 잘못된 metadata) | dev env에서 의도적 4xx 트리거 | `Polar 4xx 시뮬 진행` |
| 2 | Polar SDK 5xx 의도적 시뮬 (mock server 또는 sandbox 5xx 응답) | dev env mock server 설정 | `Polar 5xx 시뮬 진행` |
| 3 | dev env에 `POLAR_SDK_TIMEOUT_MS` 환경변수 추가 (기본값 30000 사용 시 미설정도 정상 작동) | Azure Container Apps env 추가 | `dev POLAR_SDK_TIMEOUT_MS 추가 진행` |
| 4 | dev 24h 안정성 박제 후 prod 영역 | dev 회귀 0건 박제 후 | `prod main 머지 진행` |

### 8-3. 자동 검증 영역 (sensor 영역)

- sensor-polar-timeout-policy.sh = CI/CD pre-push hook 자동 검증
- eval regression-68 = sensor-eval-trend.sh 자동 검증
- jest server = pre-push hook 자동 검증

---

## §9 사용자 결정 영역 (메인 자율 진행 금지 영역)

### 9-1. main 머지 영역 (.githooks/AGENTS.md §1 정합)

- 본 sprint 진행 중 **develop push만** 자동 (2 레포 server + claude-docs)
- main 머지는 **per-repo 명시 승인** 필수
- 명시 키워드: `server main 머지 진행` / `claude-docs main 머지 진행`

### 9-2. dev curl 자격증명 영역

- Polar SDK 4xx/5xx 의도적 시뮬 = 메인 자율 진행 금지
- 사용자 명시: `Polar 4xx 시뮬 진행` / `Polar 5xx 시뮬 진행`

### 9-3. prod 배포 영역

- dev 24h 안정성 박제 후 사용자 명시 필요
- 명시 키워드: `prod 배포 진행` (현재 본 sprint = dev 배포만 자동)

### 9-4. 환경변수 영역 (P1 보류, 기본값 사용 가능)

- `POLAR_SDK_TIMEOUT_MS` env 추가는 사용자 명시 영역 (기본값 30000 사용 시 env 0건도 정상)
- dev env 추가 명시: `dev POLAR_SDK_TIMEOUT_MS 추가 진행`
- prod env 추가 명시: `prod POLAR_SDK_TIMEOUT_MS 추가 진행`

### 9-5. PaymentGatewayPort 시그니처 결정 영역 (옵션 A/B/C)

- 옵션 A (PolarAdapter private 메서드만, 인터페이스 변경 0건) — Generator 영역 보수적 권장 X
- **옵션 B (PaymentGatewayPort.classifyError Optional 메서드 추가, 본 sprint 채택)** — 회귀 0 + 다른 adapter 정합
- 옵션 C (별도 PaymentErrorClassifierPort 신설) — 보류 (~2h 초과)

---

## §10 Definition of Done (qa Evaluator 채점 기준)

### 10-1. 정량 KPI

- [ ] jest server **643+ PASS** (회귀 0)
- [ ] eval regression **68 PASS** (재실행 검증)
- [ ] sensor **42 PASS** (sensor-polar-timeout-policy.sh 신설)
- [ ] shared-contracts **§24 박제** (PolarSDKTimeoutPolicy)
- [ ] AC BDD **8건 PASS** (qa 독립 재실행 + 직접 Read 검증)
- [ ] incident-log **≥ 1건 박제** (polar_timeout_classified 또는 polar_permanent_4xx 카테고리)

### 10-2. 정성 검증

- [ ] polar.adapter.ts에 SDK timeout 옵션 명시 박제 (new Polar 또는 호출별 AbortSignal)
- [ ] polar.adapter.ts에 classifyPolarError helper 박제 (5분류 매트릭스)
- [ ] polar.adapter.ts initiatePayment + listRecentCheckouts catch 영역에 분류 적용 박제
- [ ] payment.usecase.ts processNormalizedWebhook success 분기 catch에 4xx → permanent_failed 분기 박제
- [ ] payment.usecase.ts processNormalizedWebhook cancel 분기 catch에 동일 분기 박제
- [ ] AuditLog operator='system_dlq' action='webhook_permanent_failed' 박제 (4xx 즉시 분류)
- [ ] PaymentGatewayPort classifyError Optional 메서드 추가 박제 (옵션 B 채택)
- [ ] PAY-P2-2 DLQ 정합 (timeout/network/5xx만 retry, 4xx 즉시 permanent_failed)
- [ ] PAY-P3-A 사전 게이트 회귀 0 (영역 분리 정합)
- [ ] PAY-P3-C 사전 dedup 회귀 0 (영역 분리 정합)
- [ ] sensor-adversarial-pre-commit P16 (결제 원자성) PASS

### 10-3. 산출물 박제

- [ ] **Draft commit** + push develop (`.claude/state/sprint-pay-p3-b-polar-timeout-draft.md` 박제)
- [ ] Generator (server agent) 진입 후 `reports/sprint-pay-p3-b-polar-timeout-progress.md` 신설 + 갱신
- [ ] qa Evaluator의 `reports/QA_REPORT.md` CONDITIONAL PASS 또는 PASS

### 10-4. 회귀 차단

- [ ] PAY-P0-1 (webhook event_id 멱등성) 회귀 0
- [ ] PAY-P0-2 (PG↔DB 정합성 cron) 회귀 0 — listRecentCheckouts catch 분류 적용은 logging만, 흐름 동일
- [ ] PAY-P0-3 (운영자 수동 크레딧 UI) 회귀 0
- [ ] PAY-P1-1 (Refund 4분기 처리) 회귀 0
- [ ] PAY-P1-3 (결제 실패 retry + cleanup cron) 회귀 0
- [ ] PAY-P2-1 (부분 환불 비율) 회귀 0
- [ ] PAY-P2-2 (Webhook DLQ + retry) 회귀 0 — **본 sprint 핵심 정합 영역** (timeout/network/5xx만 retry, 4xx 즉시 permanent_failed)
- [ ] PAY-P2-3 (SmsServicePort 캡슐화) 회귀 0
- [ ] PAY-P2-4 (AdminAuditLog beforeState/afterState) 회귀 0
- [ ] PAY-P3-A (Race condition 사전 게이트 + CAS 패턴) 회귀 0
- [ ] PAY-P3-C (Retry 사전 dedup 게이트) 회귀 0

---

## §11 회귀 차단 영역 (eval regression-52~67 회귀 0 보장)

### 11-1. 결제 회귀 매트릭스

| eval task | sprint | 본 sprint 영향 | 회귀 검증 |
|---|---|---|---|
| regression-52 | PAY-P0-1 webhook event_id 멱등성 | webhook_events @unique 회귀 0 | 자동 |
| regression-53 | PAY-P0-2 PG↔DB 정합성 cron | reconciliation cron 회귀 0 (listRecentCheckouts catch 분류 적용은 logging만) | 자동 |
| regression-54 | PAY-P0-3 admin grant credits | admin UI 회귀 0 | 자동 |
| regression-55 | PAY-P1-1 refund atomicity | refundPaymentAtomically CAS 패턴 회귀 0 | 자동 |
| regression-57 | PAY-P1-3 payment retry reuse | findReusablePendingPayment 회귀 0 | 자동 |
| regression-58 | PAY-P2-1 부분 환불 비율 | partial_refunded 사전 게이트 회귀 0 | 자동 |
| regression-59 | PAY-P2-2 webhook DLQ + WebhookRetryJob | **본 sprint 핵심 정합 영역 — timeout/network/5xx만 retry, 4xx 즉시 permanent_failed** | 자동 + AC-1/AC-2/AC-3/AC-4 |
| regression-60~65 | PAY-P2-3/4 + 기타 | SMS/audit 회귀 0 | 자동 |
| regression-66 | PAY-P3-A race condition | payment.status 사전 게이트 + CAS 회귀 0 | 자동 |
| regression-67 | PAY-P3-C retry dedup | webhook-retry.job 사전 dedup 회귀 0 | 자동 |
| regression-68 | **PAY-P3-B 본 sprint** | 신설 | 신설 |

### 11-2. 강화 영역 (회귀 0 + 보강)

- **regression-59 (PAY-P2-2)**: 기존 retry 흐름 (모든 exception → retry queue) → 본 sprint 변경 후 (timeout/network/5xx만 retry, 4xx 즉시 permanent_failed). 회귀 0 보장 + AC-4 4xx 분기 추가.
- **regression-66 (PAY-P3-A)**: 본 sprint와 영역 분리 정합 → PAY-P3-A는 webhook 사전 게이트 (refunded 상태 차단), 본 sprint는 catch 분기 처리 (회귀 0).
- **regression-67 (PAY-P3-C)**: 본 sprint와 영역 분리 정합 → PAY-P3-C는 webhook-retry.job 사전 dedup, 본 sprint는 catch 분기 처리 (회귀 0).

---

## §12 변경 이력

- **2026-05-09 #10_8 본 세션** — 본 Sprint 계약 신설 (`.claude/state/` Draft 박제 영역, PP-13 화이트리스트 우회). 입력 자료 6건 (sprint-pay-p3-master-plan-draft.md + sprint-pay-p3-a-race-condition-draft.md + sprint-pay-p3-c-retry-dedup-draft.md + PAYMENT_AUDIT-2026-05-07.md §1+§3 + polar.adapter.ts + payment.usecase.ts + shared-contracts §11/§12/§18/§22/§23) 직접 Read 후:
  - **§0 한 줄 요약** + **§1 배경** (구멍-C raw 인용 + 메인 정밀 검증 결과 — polar.adapter SDK timeout 미명시 + payment.usecase catch 모든 exception 동일 처리) + **§2 목표** (KPI 5건 + 비목표 7건) + **§3 변경 영역** (server 핵심 코드 7건 + 신설 5건 + 회귀 차단 6건) + **§4 AC BDD 8건** (qa Evaluator 채점 정본 형식) + **§5 검증 매트릭스** (jest ≥6 it / eval task 1건 / sensor 1건 / shared-contracts §24) + **§6 멀티에이전트 위임** (책 Ch 16 정합 + 케이스 처리 매트릭스 + 옵션 A/B/C) + **§7 incident-log 박제 의무** (Mitchell Ghostty 정합) + **§8 dev 검증 영역** (메인 자율 + 사용자 영역 분리) + **§9 사용자 결정 영역** (main 머지 + dev curl + prod 배포 + env + PaymentGatewayPort 시그니처) + **§10 Definition of Done** (정량 + 정성 + 산출물 + 회귀) + **§11 회귀 차단 영역** (eval 52~67 회귀 0 + PAY-P2-2 강화) + **§12 변경 이력** 박제.
  - **메인 정밀 발견 (직접 Read)**: 구멍-C 본질 = (1) `polar.adapter.ts:43-46` `new Polar({ accessToken, server })` SDK timeout 옵션 미명시 (기본값 의존, 워커 자원 leak 영역) + (2) `polar.adapter.ts:88-92` initiatePayment catch에서 단순 message 추출만 (`e instanceof Error ? e.message : '알 수 없는 오류'`) + (3) `payment.usecase.ts:227-241` (success 분기) + `payment.usecase.ts:296-310` (cancel 분기) catch에서 **모든 exception** → enqueueWebhookRetry 동일 호출 → DLQ MAX_RETRY (10회) 누적 후 permanent_failed (4xx도 9회 무의미 retry). 본 sprint 핵심 = (a) SDK timeout 옵션 명시 (POLAR_SDK_TIMEOUT_MS 30s 기본) + (b) classifyPolarError helper (5분류 timeout/network/server_5xx/client_4xx/unknown) + (c) catch 분기 처리 (4xx → permanent_failed 즉시 박제, 외 4분류 → retry queue). PAY-P2-2 DLQ retry 패턴 정합 (timeout/network/5xx만 retry). PAY-P3-A + PAY-P3-C와 영역 분리 정합 (회귀 0).

---

## 참조 (file:line)

### 정본 문서

- `.claude/state/sprint-pay-p3-master-plan-draft.md` — PAY-P3 마스터 플랜 (본 sprint 위치 박제, Phase 1 세 번째 권장)
- `.claude/state/sprint-pay-p3-a-race-condition-draft.md` — PAY-P3-A Sprint 계약 (정합 패턴 정본)
- `.claude/state/sprint-pay-p3-c-retry-dedup-draft.md` — PAY-P3-C Sprint 계약 (정합 패턴 정본 + 영역 분리 정합)
- `research/PAYMENT_AUDIT-2026-05-07.md §1` — 구멍-C raw + Polar SDK timeout 미명시 raw
- `research/PAYMENT_AUDIT-2026-05-07.md §3` — Polar SDK 호출 실패 + DLQ 완성도 raw
- `.claude/shared-contracts.md §11` — WebhookEventIdempotency (인접 영역, eventId @unique 멱등성)
- `.claude/shared-contracts.md §12` — PaymentReconciliation (인접 영역, listRecentCheckouts 사용)
- `.claude/shared-contracts.md §18` — WebhookDLQ (PAY-P2-2 정합, retry 위임 패턴)
- `.claude/shared-contracts.md §22` — PaymentRaceCondition (정합 영역, 영역 분리)
- `.claude/shared-contracts.md §23` — RetryDeduplication (정합 영역, 영역 분리)
- `.claude/shared-contracts.md §24` (예정) — PolarSDKTimeoutPolicy 신설 정본 (본 sprint 산출)

### 핵심 코드 (server, 직접 Read 검증)

- `adapter/outbound/payment/polar.adapter.ts:38-51` constructor — **본 sprint SDK timeout 옵션 추가 영역**
- `adapter/outbound/payment/polar.adapter.ts:65-93` initiatePayment + catch (L88-92) — **본 sprint 분류 적용 영역**
- `adapter/outbound/payment/polar.adapter.ts:262-322` listRecentCheckouts + catch (L315-319) — **본 sprint 분류 적용 영역 (Reconciliation 정합)**
- `application/payment/payment.usecase.ts:147-204` processNormalizedWebhook (PAY-P3-A 사전 게이트 박제됨) — **본 sprint 정합 영역 (변경 0건)**
- `application/payment/payment.usecase.ts:227-241` success 분기 catch — **본 sprint 분기 처리 핵심 영역**
- `application/payment/payment.usecase.ts:296-310` cancel 분기 catch — **본 sprint 분기 처리 핵심 영역**
- `application/payment/payment.usecase.ts:52-64` enqueueWebhookRetry — **본 sprint 시그니처 보강 영역 (eventClass 인자 추가 또는 분기 처리는 호출자 영역에서)**
- `domain/port/outbound/payment-gateway.port.ts` — **본 sprint classifyError Optional 메서드 추가 영역 (옵션 B)**

### Sprint progress 박제 영역 (본 sprint 신설 후 영역)

- `reports/sprint-pay-p3-b-polar-timeout-progress.md` (Generator 진입 후 신설)

### 관련 sprint progress (완료)

- `reports/sprint-pay-p0-1/2/3-progress.md`
- `reports/sprint-pay-p1-1-refund-progress.md`
- `reports/sprint-pay-p1-3-retry-policy-progress.md`
- `reports/sprint-pay-p2-1/2/3/4-*.md`
- `reports/sprint-pay-p3-a-race-condition-progress.md` (Generator 진입 영역)
- `reports/sprint-pay-p3-c-retry-dedup-progress.md` (Generator 진입 영역)

### 관련 정본 문서 (Generator가 갱신할 영역)

- `grimoire-server/docs/api-contract.md` — webhook 처리 상태 표 + webhook_permanent_failed_4xx 박제
- `grimoire-server/docs/data-model.md` — AuditLog action 표 + webhook_permanent_failed (4xx) 추가
- `grimoire-server/docs/environments.md` — POLAR_SDK_TIMEOUT_MS env 추가
- `grimoire-server/SECURITY.md §3` — 결제 원자성 영역 timeout 정책 박제
- `grimoire-server/ADR.md` — Polar SDK timeout 결정 박제 (옵션 A/B/C 비교)
- `grimoire-server/CLAUDE.md §9` — 결제/크레딧 원자성 절대 규칙 (정합 검증)

---

**상태**: Sprint 계약 13 섹션 + AC BDD 8건 박제 완료 (`.claude/state/` Draft 영역, PP-13 화이트리스트 통과). **다음 단계 = grimoire-server agent (Generator) 위임 진입**. 본 Draft가 server agent 진입 정본 — 모호 영역 0건. shared-contracts §24 PolarSDKTimeoutPolicy 신설 영역 박제. 사용자 명시 후 즉시 server agent (Generator) 위임 → qa Evaluator 위임 → 메인 commit/push 진행.
