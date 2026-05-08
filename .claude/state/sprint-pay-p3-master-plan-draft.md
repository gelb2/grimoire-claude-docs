# Sprint PAY-P3 — 결제 고도화 마스터 플랜 (Draft, 메인 화이트리스트 우회 박제 영역)

> **작성**: 2026-05-08 #10_8 본 세션 grimoire-planner agent 박제
> **트리거**: 사용자 명시 — "결제 고도화 계획부터 세우고 시작해" (Auto mode 활성)
> **본 위치**: `.claude/state/` (PP-13 메인 화이트리스트 통과 영역). 정본 영역 (`reports/sprint-pay-p3-master-plan.md`)으로 사용자 또는 grimoire-server agent 위임 후 이동 영역.
> **정본 위치 (예정)**: `reports/sprint-pay-p3-master-plan.md` — PAY-P3 sprint 마스터 플랜 정본. PAYMENT_AUDIT-2026-05-07.md (갭 인벤토리) + PAYMENT_SYSTEM_PLAN.md (P0~P3 우선순위) + HANDOVER §1.5/§1.6 (트랙 + 인프라 회고) cross-reference.

---

## §0 요약 (1단락)

본 sprint 마스터 플랜은 결제 9 sprint (PAY-P0-1/2/3 + PAY-P1-1/3 + PAY-P2-1/2/3/4) 완료 직후 잔여 갭 (PAYMENT_AUDIT 6 구멍 + 4 영수증 + 10 고도화)을 PAY-P3-A~H 8 sprint + PAY-P2-5 (audit retention) + PAY-P1-2/4 (잔여 의존)로 분해, **외부 API 0건 즉시 진행 가능 영역 (Phase 1, ~21h 합)** 우선 진입을 권고합니다. 외부 SaaS 결정 영역 (이메일 / Sentry / SMS, **사용자 결정 영역**)은 Phase 2로 분리하여 메인 자율 진행 금지. 첫 진입 sprint 권장 = **PAY-P3-A (Race condition 해소, ~5h, 구멍 A/B 동시 차단, 의존성 0)** — 결제 적자 위험 영역 (구멍-A는 환불 누락 / 구멍-B는 잔액 중복 차감) 우선 박제.

---

## §1 배경 — 결제 9 sprint 완료 후 잔여 갭

### 1-1. 완료 sprint 인벤토리 (PAYMENT_AUDIT §6 정합)

| Sprint | 완료 일자 | 핵심 산출물 |
|---|---|---|
| PAY-P0-1 webhook event_id 멱등성 | 2026-05-03 | WebhookEvent + L1/L2/L3 3중 방어 |
| PAY-P0-2 PG↔DB 정합성 cron 10분 | 2026-05-03 | PaymentReconciliationJob + dev 작동 직접 검증 16:10 |
| PAY-P0-3 운영자 수동 크레딧 UI | 2026-05-03 | admin/credits/grant + audit |
| PAY-P1-1 Refund 4분기 처리 | 2026-05-03 | refund_normal/deficit/partial/partial_deficit |
| PAY-P1-3 결제 실패 retry + cleanup cron | 2026-05-04 | 24h pending 재사용 + payment-cleanup.job 새벽 4시 |
| PAY-P2-1 부분 환불 비율 + 4 action | 2026-05-05 (다른 세션) | proportionalCredits 계산 |
| PAY-P2-2 Webhook DLQ + WebhookRetryJob | 2026-05-05 (다른 세션) | webhook_retry_queues + 5분 cron + dev 작동 직접 검증 16:05 |
| PAY-P2-3 SmsServicePort 캡슐화 | 2026-05-05 (다른 세션) | SMS Hexagonal Port + NullSmsAdapter |
| PAY-P2-4 AdminAuditLog 정밀화 | 2026-05-07 | beforeState/afterState 6-arg BACKWARD COMPATIBLE |

### 1-2. 시스템 인벤토리 (본 sprint 진입 직전)

- jest server **625** / vitest web **151** / sensor **39** / shared-contracts **§1~21** / regression **65**
- DB 모델: Payment / CreditLog / RefundLog / AdminAuditLog / WebhookEvent / WebhookRetryQueue (6개)
- Cron Job: PaymentReconciliationJob (10분) + WebhookRetryJob (5분) + PaymentCleanupJob (새벽 4시 KST)
- Hexagonal Port: PaymentGatewayPort / PaymentRepositoryPort / CreditRepositoryPort / AuditLogRepositoryPort / EmailServicePort / SmsServicePort

### 1-3. 잔여 갭 매트릭스 (PAYMENT_AUDIT §1 + §2 + §4)

| 카테고리 | 갭 수 | 핵심 영역 |
|---|---|---|
| 결제 도메인 구멍 | 6 | race A/B + Polar timeout C + retry 중복 D + status enum E + FK cascade F |
| 영수증 갭 | 4 | PDF / 세금계산서 / 환율 / 부분 환불 시점 |
| 고도화 권장 | 10+ | 영수증 PDF / 운영자 대시보드 / Sentry / 사용자 알림 / Circuit breaker / Bull Queue / KYC 게이트 / Webhook 비동기화 / A/B 테스트 / SMS |

---

## §2 PAY-P3 옵션 매트릭스 (8 sprint A~H + 잔여)

| Sprint | 시간 | 외부 API | 의존성 | 우선순위 | 즉시 진행 | 출처 |
|---|---|---|---|---|---|---|
| **PAY-P2-5** audit retention 정책 | ~3h | 0 (cleanup cron만) | 0 | P0 | 가능 | PAYMENT_AUDIT §4 |
| **PAY-P3-A** Race condition 해소 (구멍 A/B) | ~5h | 0 | 0 | P1 | 가능 | PAYMENT_AUDIT §1 |
| **PAY-P3-B** Polar SDK timeout 정책 (구멍 C) | ~2h | 0 (Polar SDK 옵션만) | 0 | P1 | 가능 | PAYMENT_AUDIT §1 + §3 |
| **PAY-P3-C** retry 중복 해소 (모순 D) | ~2h | 0 | 0 | P1 | 가능 | PAYMENT_AUDIT §1 |
| **PAY-P3-D** Status enum 정합 (모순 E) | ~2h | 0 | 0 | P2 | 가능 | PAYMENT_AUDIT §1 |
| **PAY-P3-E** FK cascade 정책 (모순 F) | ~3h | 0 (DB 마이그레이션) | 0 | P1 | 가능 | PAYMENT_AUDIT §1 |
| **PAY-P3-H** Circuit breaker | ~4h | 0 | 0 | P1 | 가능 | PAYMENT_AUDIT §3 + §4 |
| **PAY-P3-F** 영수증 PDF + 이메일 | ~16h | EMAIL-P1-3 + puppeteer | EMAIL-P1-1 + 외부 API 결정 | P0 | 보류 | PAYMENT_AUDIT §4 + EMAIL_INTEGRITY_PLAN §2-2 |
| **PAY-P3-G** Sentry/APM 통합 | ~8h | Sentry SaaS | cost-accountant 마진 검증 | P1 | 보류 | PAYMENT_AUDIT §4 |
| **PAY-P1-2** 결제 알림 (이메일) | ~16~20h | EMAIL-P1-1 + 이메일 SaaS | EMAIL-P1-1 선행 + 사용자 절대 규정 0-1 해제 | P1 | 보류 | EMAIL_INTEGRITY_PLAN §2-2 |
| **PAY-P1-4** Polar Subscription Product (작업 A) | ~5~8h | Polar Subscription | 작업 A 기획 단계 (구독제) | P1 | 작업 A 결합 | PAYMENT_SYSTEM_PLAN §3-2 |
| **PAY-P2-4 SMS 알림** (PAY-P2-3 후속) | ~3h | KISA + Toast/Aligo SaaS | 사용자 절대 규정 + KISA 발신번호 | P2 | 보류 | PAYMENT_SYSTEM_PLAN §3-3 |

### Phase 1 합계 (외부 API 0)

PAY-P2-5 + PAY-P3-A + PAY-P3-B + PAY-P3-C + PAY-P3-D + PAY-P3-E + PAY-P3-H = **~21h** (메인 자율 진행 가능)

### Phase 2 합계 (외부 SaaS 결정 후)

PAY-P3-F + PAY-P3-G + PAY-P1-2 + PAY-P1-4 + PAY-P2-4(SMS) = **~48~55h** (사용자 결정 영역, 메인 자율 금지)

---

## §3 진행 권장 순서

### Phase 1 (외부 API 0건, 즉시 진행 — ~21h 합)

**진행 순서 권고** (의존성 + 영향도 + 적자 위험 기준):

1. **PAY-P3-A (Race condition 해소, ~5h)** — 구멍 A/B 동시 차단, 결제 적자 위험 영역 (환불 누락 + 잔액 중복 차감) 최우선
2. **PAY-P3-C (retry 중복 해소, ~2h)** — 모순 D, payment.status='completed' 체크 추가만 (가장 단순)
3. **PAY-P3-B (Polar SDK timeout 정책, ~2h)** — 구멍 C, 일시적 timeout 영구 실패 구분
4. **PAY-P3-E (FK cascade 정책, ~3h)** — 모순 F, EMAIL-P0-2 백필 충돌 영역, DB 스키마 안정화
5. **PAY-P3-H (Circuit breaker, ~4h)** — Polar API 5xx 연속 시 결제 routes 임시 차단
6. **PAY-P3-D (Status enum 정합, ~2h)** — 모순 E, mapping table 박제만 (낮은 우선순위)
7. **PAY-P2-5 (audit retention, ~3h)** — 90일/180일 정책 + 인덱스 전략

### Phase 2 (외부 SaaS 결정 후, ~48~55h)

**진행 순서 권고**:

1. **PAY-P3-G (Sentry/APM, ~8h)** — Sentry SaaS 결정 후 (cost-accountant 마진 영향 검증)
2. **EMAIL-P1-1 (이메일 인증 시스템, ~12~16h)** — 선행 의존성
3. **PAY-P3-F = EMAIL-P1-3 (영수증 PDF + 결제 이메일, ~16~20h)** — EMAIL-P1-1 종료 후
4. **작업 A + PAY-P1-4 (구독제 + Polar Subscription, ~5~8h)** — 기획 단계 선행 (researcher + cost-accountant + planner)
5. **PAY-P2-4 SMS, ~3h** — KISA 발신번호 사용자 영역 후

---

## §4 첫 진입 sprint 권장 (Phase 1 첫 sprint)

### 4-1. 권장: **PAY-P3-A (Race condition 해소 — 구멍 A/B 동시 차단)**

**선정 사유**:
1. **결제 적자 위험 영역 1순위** — 구멍-A (환불 누락 가능) + 구멍-B (잔액 중복 차감 가능) 모두 직접 금전 손실 영역
2. **외부 API 0건** — 즉시 진행 가능 (사용자 결정 대기 0)
3. **의존성 0** — 다른 sprint 선행 불필요
4. **기존 인프라 재사용 가능** — `$transaction` + `findUniqueOrThrow + updateMany` 패턴 (Prisma 표준)
5. **회귀 차단 명확** — sensor + jest spec + eval task 신설 가능 (재현 시나리오 mock 가능)

### 4-2. PAY-P3-A 산출물 미리 박제 (server agent 위임 영역)

**파일 변경 영역** (예상):
- `application/payment/payment.usecase.ts:147-160` `processNormalizedWebhook` — existing.status='processed' OR payment.status='completed' 동시 체크
- `adapter/outbound/persistence/prisma-payment.repository.ts:144-199` `refundPaymentAtomically` — `findUniqueOrThrow + updateMany` 원자 재구성 (또는 `SELECT ... FOR UPDATE`)
- jest spec — 같은 eventId 동시 환불 시나리오 + Author.findUnique race 시나리오 (각 4 it+)
- `application/payment/payment.usecase.spec.ts` 갱신
- `adapter/outbound/persistence/prisma-payment.repository.spec.ts` 갱신
- `.claude/scripts/sensor-payment-race-condition.sh` 신설
- `eval/tasks/regression-66-payment-race-condition.json` 신설
- `.claude/shared-contracts.md §22` PaymentRaceCondition 인터페이스 정본 박제

**검증 게이트**:
- jest spec PASS (구멍-A + 구멍-B 각 시나리오)
- sensor-payment-race-condition PASS
- eval regression-66 PASS
- sensor-adversarial-pre-commit P16 (결제 원자성) PASS
- visual-canon-keeper 면제 (UI 변경 0)
- cost-accountant 면제 (외부 API 0)

**예상 시간**: ~5h (구현 ~3h + spec ~1h + sensor + shared-contracts + eval ~1h)

---

## §5 dev 작동 검증 박제 (PAYMENT_AUDIT §7 정합)

### 5-1. 9 sprint dev 작동 logs 매트릭스

| Sprint | dev 작동 | logs 박제 raw |
|---|---|---|
| PAY-P0-1 webhook event_id 멱등성 | 간접 검증 (webhook 201 응답) | — |
| PAY-P0-2 Reconciliation @Cron 10분 | 실 작동 | `16:10:00 [PaymentReconciliationJob] 시작 since=15:20:00 / 16:10:01 완료 processed=0 boost=0 mismatch=0 expire=0` |
| PAY-P0-3 admin/credits/grant route | 401 정상 | (curl 직접) |
| PAY-P1-1 RefundPaymentUseCase | 코드 spec PASS만 (webhook 시뮬 미수행) | — |
| PAY-P1-3 PaymentCleanupJob @Cron 새벽 4시 | 시간대 외 (KST 4시 / UTC 19시) | — |
| **PAY-P2-2 WebhookRetryJob @Cron 5분** | **실 작동** | `16:05:00 / 16:10:00 [WebhookRetryJob] 시작/완료 due=0 success=0 retry=0 permanent=0` |
| PAY-P2-2 webhook_retry_queues 테이블 | 간접 검증 (cron 정상 작동 = 테이블 존재 정합) | — |
| PAY-P2-1 부분 환불 4 action | 코드 spec PASS만 | — |
| PAY-P2-3 SmsServicePort | 코드 spec PASS만 (NullSmsAdapter logger.warn) | — |
| PAY-P2-4 AdminAuditLog beforeState/afterState | 코드 spec PASS만 (admin grant API 호출 시 6-arg) | — |

### 5-2. PAY-P3 sprint별 dev 작동 검증 의무

각 sprint 진행 시 **logs 박제 raw 또는 curl 직접 명령 출력 동반** 강제 (HANDOVER §1.4 거짓 검증 차단 규정 정합).

---

## §6 사용자 결정 영역 분리 (메인 자율 진행 금지 영역)

### 6-1. 외부 SaaS 결정 영역 (사용자 절대 규정 0-1 영향)

| 영역 | 결정 게이트 | 의존 sprint |
|---|---|---|
| **이메일 SaaS** (AWS SES / Resend / SendGrid / Postmark) | EMAIL_INTEGRITY_PLAN §11 결정 게이트 | EMAIL-P1-1 + PAY-P3-F + PAY-P1-2 |
| **Sentry/APM SaaS** (Sentry / Datadog / New Relic) | cost-accountant 마진 검증 후 사용자 명시 | PAY-P3-G |
| **SMS SaaS** (Toast / NHN / Aligo) | KISA 발신번호 등록 + 사용자 명시 | PAY-P2-4 (SMS 후속) |

### 6-2. main 머지 영역 (per-repo 명시 승인 필수)

- `.githooks/AGENTS.md §1` 정합: 3 레포 모두 develop → main 머지는 사용자 per-repo 명시 승인 필요
- 명시 형식: "claude-docs main 머지" / "server main 머지" / "web main 머지"
- 본 PAY-P3 sprint 진행 중 develop push만 자동, main 머지는 사용자 명시 후

### 6-3. dev curl 직접 검증 영역 (자격증명 영역)

- POST /payments/webhook valid signature mock — Polar dashboard 또는 HMAC 생성 (사용자 명시 영역)
- DLQ retry 의도적 시뮬 (webhook fail) — 테스트 결제 + exception throw (사용자 명시 영역)
- prod 영역 변경 (보안 마이그레이션 + EMAIL-P0-2 + main 머지) — dev 24h 안정성 박제 후 (사용자 명시 영역)

### 6-4. 기획 변동 영역 (PLANNING_GRIMOIRE.md 직접 수정 금지)

- 작업 A 구독제 요금제 — 가격대 + 등급 구조 (Free / Plus / Pro / Enterprise) 사용자 결정
- AI 채팅 1턴 크레딧 비용 — cost-accountant 시뮬 후 사용자 승인
- Polar Subscription Product 도입 여부 (현재 일회성만)
- 기존 일회성 결제 사용자 마이그레이션 정책

---

## §7 멀티에이전트 위임 매트릭스 (각 sprint 별 위임 패턴)

### 7-1. 표준 패턴 (책 Ch 16 Anthropic 3-에이전트 + GMP v2.2 정합)

```
[Step 1] orchestration-decision skill → 위임 가치 매트릭스 (메인 직접 vs subagent)
[Step 2] planner (Initializer) → reports/sprint-{name}-progress.md 신설 (Sprint 계약 + AC BDD)
[Step 3] (필요 시) cost-accountant → 마진 ≥3배 검증 (외부 API 영향 시)
[Step 4] (필요 시) visual-canon-keeper → 사슴악마 정본 검수 (UI 변경 시)
[Step 5] server agent (Generator) + web agent (Generator) → 병렬 위임
[Step 6] verification-before-completion skill + sensor 회귀 검증
[Step 7] socratic-self-critique skill (14 질문 + Ambiguity ≤ 0.2)
[Step 8] requesting-code-review skill (12 항목 체크리스트)
[Step 9] sensor-adversarial-pre-commit (19 principles, FAIL 0건 강제)
[Step 10] qa (Evaluator) → reports/QA_REPORT.md (Sprint 계약 채점)
[Step 11] commit + 머지 (메인 직접, 화이트리스트 hook 통과)
[Step 12] memory 박제 (Stop hook 강제 + incident-log)
```

### 7-2. PAY-P3 sprint별 위임 매트릭스

| Sprint | planner | cost-accountant | VCK | server | web | qa | 메인 직접 |
|---|---|---|---|---|---|---|---|
| PAY-P3-A | O | 면제 (외부 0) | 면제 (UI 0) | O | 면제 | O | commit/push |
| PAY-P3-B | O | 면제 | 면제 | O | 면제 | O | commit/push |
| PAY-P3-C | O | 면제 | 면제 | O | 면제 | O | commit/push |
| PAY-P3-D | O | 면제 | 면제 | O | 면제 | O | commit/push |
| PAY-P3-E | O | 면제 | 면제 | O | 면제 (DB 마이그레이션 영향만) | O | commit/push + 마이그레이션 |
| PAY-P3-H | O | 면제 | 면제 | O | 면제 | O | commit/push |
| PAY-P2-5 | O | 면제 | 면제 | O | admin UI 일부 (audit retention 화면) | O | commit/push |
| PAY-P3-F | O | 마진 검증 | 영수증 UI 검수 | O | 영수증 페이지 | O | commit/push (외부 API 결정 후) |
| PAY-P3-G | O | Sentry 비용 | 면제 | O | 클라이언트 Sentry SDK 일부 | O | commit/push (외부 API 결정 후) |
| PAY-P1-2 | O | 이메일 비용 | 이메일 템플릿 | O | 결제 페이지 알림 | O | commit/push (외부 API 결정 후) |

### 7-3. infrastructure agent 결합 (HANDOVER §1.6 정합)

- DB 마이그레이션 sprint (PAY-P3-E + 작업 A) — `grimoire-infrastructure` agent 위임
- mutation 직전 health snapshot + 변경 후 3-stage polling (skill: `infra-mutation-guard`)
- rollback skill (`rollback-revision`) 사전 박제

---

## §8 sprint 계약 표준 패턴 (AC BDD 형식)

### 8-1. 각 sprint마다 적용할 8 AC 양식

```yaml
# AC-1: 정상 케이스 (functional)
GIVEN [전제 조건 — 도메인 상태 박제]
WHEN [트리거 — 사용자 행위 또는 시스템 이벤트]
THEN [기대 결과 — DB 상태 + API 응답 + side effect]

# AC-2: 경계 케이스 (boundary)
GIVEN [경계 조건 — 0 / 1 / N / max]
WHEN [트리거]
THEN [기대 결과]

# AC-3: 실패 케이스 (failure)
GIVEN [실패 트리거 조건]
WHEN [실패 행위]
THEN [실패 응답 + rollback + audit log 박제]

# AC-4: 멱등성 (idempotency)
GIVEN [동일 입력 N회 호출]
WHEN [동시 호출 또는 순차 N회]
THEN [결과 동일 + side effect 1회만 (멱등성 보장)]

# AC-5: 회귀 차단 (regression)
GIVEN [기존 sprint 정합 시나리오]
WHEN [본 sprint 변경 후 동일 시나리오]
THEN [결과 동일 (회귀 0건)]

# AC-6: 보안 (security)
GIVEN [악의적 입력 — injection / replay / unauthorized]
WHEN [입력 처리]
THEN [차단 + audit log 박제 + 응답 4xx]

# AC-7: 성능 (performance)
GIVEN [N건 동시 처리 시나리오]
WHEN [동시 처리]
THEN [응답 < threshold (예: 500ms) + 자원 leak 0]

# AC-8: 운영 (operational)
GIVEN [운영자 또는 cron 트리거]
WHEN [운영 행위]
THEN [logs 박제 + audit log + 알림 (선택)]
```

### 8-2. PAY-P3-A AC BDD 예시 (첫 진입 sprint)

```yaml
# AC-1: 정상 결제 webhook 처리
GIVEN payment.status='pending' + WebhookEvent 0건
WHEN Polar webhook order.succeeded 수신
THEN payment.status='completed' + Author.credits += credits + CreditLog 1건 + WebhookEvent 1건

# AC-2: 같은 eventId 두 번 처리 (구멍-A 차단)
GIVEN payment.status='completed' + WebhookEvent eventId='evt_123' status='processed'
WHEN 같은 eventId='evt_123' 두 번째 webhook
THEN 두 번째 호출 즉시 200 + skip (DB 변경 0건)

# AC-3: 다른 type webhook 처리 (구멍-A 핵심)
GIVEN payment.status='completed' + WebhookEvent succeeded eventId='evt_123' status='processed'
WHEN order.refunded eventId='evt_456' 수신 (다른 eventId)
THEN existing.status='processed' OR payment.status='completed' 동시 체크 → 환불 처리 정상 진행

# AC-4: 동시 환불 race (구멍-B 차단)
GIVEN payment.status='completed' + Author.credits=10
WHEN 같은 paymentId 동시 환불 webhook 2회 (race)
THEN findUniqueOrThrow + updateMany → 1회만 처리 (Author.credits 1회만 decrement)

# AC-5: 회귀 차단
GIVEN PAY-P0-1/P1-1/P2-1 시나리오 (8 it)
WHEN 본 sprint 변경 후 동일 시나리오
THEN 결과 동일 (회귀 0건)

# AC-6: 보안 (eventId injection)
GIVEN 악의적 eventId='; DROP TABLE webhook_events;--'
WHEN webhook 처리
THEN Prisma parameterized query 차단 + audit log

# AC-7: 성능 (동시 환불 100건)
GIVEN payment.status='completed' 100건 동시 환불
WHEN 100 webhook 동시 처리
THEN $transaction 정합 + Author.credits 정확 + 응답 < 5s

# AC-8: 운영 (logger.warn audit)
GIVEN 구멍-A 시도 발생 (같은 eventId 다른 type 시도)
WHEN webhook 처리
THEN logger.warn `[PaymentRaceCondition] dup eventId=evt_123` + AuditLog operator='system_payment'
```

---

## §9 shared-contracts §22+ 신설 영역 (인터페이스 정본)

### 9-1. PAY-P3 sprint별 신설 인터페이스

| Sprint | shared-contracts 신설 | 정본 위치 |
|---|---|---|
| PAY-P3-A | §22 PaymentRaceCondition | existing.status OR payment.status='completed' 동시 체크 + findUniqueOrThrow + updateMany |
| PAY-P3-B | §23 PolarTimeoutPolicy | Polar SDK timeout 옵션 + exception type 매핑 |
| PAY-P3-C | §24 RetryDeduplication | retry job 진입 시 payment.status='completed' 체크 |
| PAY-P3-D | §25 PaymentStatusEnum | Payment 7가지 + WebhookEvent 4가지 (permanent_failed 추가) mapping table |
| PAY-P3-E | §26 PaymentFkCascade | Author 삭제 시 Payment/CreditLog onDelete: Cascade 또는 Restrict 정책 |
| PAY-P3-H | §27 CircuitBreaker | Polar 5xx 연속 N회 시 결제 routes 임시 차단 + graceful degradation |
| PAY-P2-5 | §28 AuditRetention | 90일/180일/영구 retention + 인덱스 전략 + cleanup cron |
| PAY-P3-F | §29 ReceiptPdf + EmailNotification | puppeteer + EmailServicePort.sendPaymentNotification |
| PAY-P3-G | §30 SentryAPM | Sentry SDK init + breadcrumb + error boundary |
| PAY-P1-2 | §29 EmailNotification (PAY-P3-F 결합) | EmailServicePort 확장 |

### 9-2. shared-contracts.md 박제 규칙 (책 Ch 16 정합)

본 agent가 인터페이스 변경 시:
- **반드시 `.claude/shared-contracts.md` 해당 섹션 즉시 갱신**
- 변경 이력 1줄 박제 (date — agent — 변경 요약)
- 본 파일 미갱신 시 다른 agent가 통합 단계에서 인터페이스 불일치로 깨짐

---

## §10 sensor 신설 매트릭스 (회귀 차단 자동화)

### 10-1. PAY-P3 sprint별 sensor 신설

| Sprint | Sensor | 검증 내용 |
|---|---|---|
| PAY-P3-A | `sensor-payment-race-condition.sh` | existing.status OR payment.status='completed' 동시 체크 패턴 + findUniqueOrThrow 사용 |
| PAY-P3-B | `sensor-polar-timeout-policy.sh` | Polar SDK timeout 옵션 박제 + exception type 매핑 |
| PAY-P3-C | `sensor-retry-dedupe.sh` | webhook-retry.job + payment-reconciliation.job payment.status 사전 체크 |
| PAY-P3-D | `sensor-payment-status-enum.sh` | Payment + WebhookEvent enum 정합 + mapping table 박제 |
| PAY-P3-E | `sensor-fk-cascade.sh` | Author + Payment + CreditLog FK onDelete directive 박제 |
| PAY-P3-H | `sensor-circuit-breaker.sh` | Polar 호출 wrapper에 circuit breaker 패턴 박제 |
| PAY-P2-5 | `sensor-audit-retention.sh` | AdminAuditLog cleanup cron + retention 정책 박제 |
| PAY-P3-F | `sensor-receipt-pdf.sh` | puppeteer 또는 react-pdf 의존 + 이메일 발송 패턴 |
| PAY-P3-G | `sensor-sentry-init.sh` | Sentry SDK init + DSN 환경변수 |
| PAY-P1-2 | `sensor-payment-email-notification.sh` | EmailServicePort.sendPaymentNotification 호출 패턴 |

### 10-2. sensor 인벤토리 변동 (예상)

- 현재: **39 sensors** (본 sprint 진입 직전)
- Phase 1 종료: **+7 = 46 sensors** (PAY-P3-A/B/C/D/E/H + PAY-P2-5)
- Phase 2 종료: **+3 = 49 sensors** (PAY-P3-F/G + PAY-P1-2)

---

## §11 eval regression 신설 매트릭스

### 11-1. PAY-P3 sprint별 regression task

| Sprint | regression task | 검증 시나리오 |
|---|---|---|
| PAY-P3-A | `regression-66-payment-race-condition` | 같은 eventId 다른 type + 동시 환불 race 차단 |
| PAY-P3-B | `regression-67-polar-timeout-policy` | Polar timeout 분기 + retry 정책 |
| PAY-P3-C | `regression-68-retry-dedupe` | retry job + reconciliation job 중복 방지 |
| PAY-P3-D | `regression-69-payment-status-enum` | enum 정합 + mapping table |
| PAY-P3-E | `regression-70-fk-cascade` | Author 삭제 시 Payment/CreditLog onDelete 정책 |
| PAY-P3-H | `regression-71-circuit-breaker` | Polar 5xx 연속 시 routes 차단 |
| PAY-P2-5 | `regression-72-audit-retention` | AdminAuditLog cleanup + retention |
| PAY-P3-F | `regression-73-receipt-pdf` | PDF 생성 + 이메일 발송 |
| PAY-P3-G | `regression-74-sentry-init` | Sentry SDK init + breadcrumb |
| PAY-P1-2 | `regression-75-payment-email-notification` | EmailServicePort.sendPaymentNotification |

### 11-2. eval 인벤토리 변동 (예상)

- 현재: **65 regression tasks** (본 sprint 진입 직전)
- Phase 1 종료: **+7 = 72 regression tasks**
- Phase 2 종료: **+3 = 75 regression tasks**

---

## §12 incident-log 박제 의무 (Mitchell Ghostty 패턴)

### 12-1. sprint별 incident-log 박제 영역

각 sprint 진행 시 **반드시 박제** (Constitution Principle 20 + sensor-adversarial-pre-commit P20):

| 카테고리 | 박제 시점 | 예시 |
|---|---|---|
| skill_failure | skill 발동 실패 시 | infra-mutation-guard 발동 누락 |
| agent_failure | agent 위임 실패 시 | server agent commit/push 0건인데 자율 시도 |
| documentation_gap | 문서 누락 발견 시 | shared-contracts §22 누락 |
| race_condition_found | race 발견 시 | 구멍-A/B 시나리오 reproduction |
| guard_bypass_attempt | 가드 우회 시도 시 | main push 직접 시도 |
| dev_verification_skip | dev 검증 누락 시 | code spec PASS만 박제 후 운영 영향 0 보고 |
| false_report_caught | 거짓 보고 사슬 발견 시 | sensor 결함 + 추정 보고 패턴 |

### 12-2. 박제 명령

```bash
bash .claude/scripts/incident-log.sh \
  --category=race_condition_found \
  --severity=high \
  --source=server-agent \
  --description="PAY-P3-A 구멍-A 시나리오 재현 — eventId 다른 type 동시 처리"
```

---

## §13 변경 이력

- **2026-05-08 #10_8 본 세션** — 본 마스터 플랜 신설 (`.claude/state/` Draft 박제 영역, PP-13 화이트리스트 우회). 입력 자료 5건 (PAYMENT_AUDIT-2026-05-07.md + PAYMENT_SYSTEM_PLAN.md + HANDOVER §1.5/§1.6 + EMAIL_INTEGRITY_PLAN §11) 직접 Read 후 Phase 1 (~21h, 외부 API 0) + Phase 2 (~48~55h, 외부 SaaS 결정 후) 분리 + 첫 진입 sprint = PAY-P3-A 권장 + 13 섹션 정본 패턴 박제. 사용자 결정 영역 (외부 SaaS / main 머지 / dev curl 자격증명 / 기획 변동) 명시 분리. shared-contracts §22~30 신설 영역 + sensor +10 + regression +10 + incident-log 박제 의무 박제.

---

## 참조 (file:line)

### 정본 문서
- `research/PAYMENT_AUDIT-2026-05-07.md` — 결제 시스템 전수 조사 (8 섹션)
- `research/PAYMENT_SYSTEM_PLAN.md` — PAY 마스터 플랜 (12 섹션, P0~P3)
- `HANDOVER_NEXT_SESSION.md §1.5` — 다음 트랙 11 옵션
- `HANDOVER_NEXT_SESSION.md §1.6` — INFRA-1 회고 + grimoire-infrastructure agent
- `research/EMAIL_INTEGRITY_PLAN.md §11` — 이메일 SaaS 결정 게이트
- `.claude/shared-contracts.md §1~21` — 결제 인터페이스 규약 (현재)

### 핵심 코드 (server)
- `application/payment/payment.usecase.ts:106-113, 147-160, 162-173, 206-223`
- `application/payment/refund-payment.usecase.ts:75-170`
- `application/payment/payment-cleanup.job.ts:45`
- `application/payment/payment-reconciliation.job.ts:59, 118-122`
- `application/payment/webhook-retry.job.ts:39, 55, 82, 130-139`
- `application/admin/audit-log.service.ts:22-49` (PAY-P2-4 시그니처)
- `adapter/outbound/persistence/prisma-payment.repository.ts:144-199`
- `prisma/schema.prisma:11-29 (Author), 97-105 (CreditLog), 192-203 (Payment), 212-223 (WebhookEvent)`

### Sprint progress 박제 영역 (본 sprint 신설 후 영역)
- `reports/sprint-pay-p3-a-race-condition-progress.md` (첫 진입 sprint)
- `reports/sprint-pay-p3-b-polar-timeout-progress.md`
- `reports/sprint-pay-p3-c-retry-dedupe-progress.md`
- `reports/sprint-pay-p3-d-status-enum-progress.md`
- `reports/sprint-pay-p3-e-fk-cascade-progress.md`
- `reports/sprint-pay-p3-h-circuit-breaker-progress.md`
- `reports/sprint-pay-p2-5-audit-retention-progress.md`
- (Phase 2) `reports/sprint-pay-p3-f-receipt-pdf-progress.md` + `reports/sprint-pay-p3-g-sentry-progress.md` + `reports/sprint-pay-p1-2-email-notification-progress.md`

### 관련 sprint progress (완료)
- `reports/sprint-pay-p0-1/2/3-progress.md`
- `reports/sprint-pay-p1-1/3-*.md`
- `reports/sprint-pay-p2-1/2/3/4-*.md`
- `reports/sprint-infra-1-mutation-guard-progress.md`

---

**상태**: 마스터 플랜 Draft 박제 완료 (`.claude/state/` 영역, PP-13 화이트리스트 통과). **첫 진입 sprint = PAY-P3-A (Race condition 해소, ~5h, 외부 API 0)** 사용자 승인 대기. 사용자 결정 후 정본 영역 (`reports/sprint-pay-p3-master-plan.md`) 이전은 사용자 직접 또는 grimoire-server agent 위임 영역. 사용자 명시 후 즉시 planner Initializer 위임 → server agent (Generator) 위임 → qa Evaluator 위임 진행.
