# Sprint PAY-P3-A — Race Condition 해소 (Generator 영역 진행 보고)

> **위치**: `reports/sprint-pay-p3-a-race-condition-progress.md` (정본 영역, Initializer Draft에서 인계)
> **Generator**: grimoire-server agent (5/9 본 세션 #10_8 PP-7 라우팅 정정 후 재진입)
> **Initializer Draft**: `.claude/state/sprint-pay-p3-a-race-condition-draft.md` (planner 박제, 668 line, 13 섹션)
> **상태**: ✅ Generator 영역 종료 — qa Evaluator 인계

---

## §0 한 줄 요약

PAYMENT_AUDIT §1 구멍-A (eventId 다른 type 동시 처리 누락) + 구멍-B (transaction race) 동시 차단 완료. payment.usecase.ts 사전 게이트 (refunded + partial_refunded) + prisma-payment.repository.ts CAS 패턴 (`findUniqueOrThrow + updateMany WHERE credits >= actualDeducted`) 적용. DB schema 변경 0건 + 외부 API 0건. shared-contracts §22 PaymentRaceCondition 신설.

---

## §1 변경 매트릭스 (line + 영향)

| 파일 | 변경 line | 영역 | 영향 |
|---|---|---|---|
| `grimoire-server/src/application/payment/payment.usecase.ts` | +18 line (L186-203) | 사전 게이트 신설 | 구멍-A 차단 |
| `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts` | +13 line (L178-198) / -10 line | findUniqueOrThrow + CAS 패턴 적용 | 구멍-B 차단 |
| `grimoire-server/src/application/payment/payment.usecase.spec.ts` | +127 line (4 it) | PAY-P3-A describe 신설 | AC-1, AC-2, AC-3, AC-6 검증 |
| `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.spec.ts` | +130 line (5 it) | refundPaymentAtomically describe 신설 | AC-4(a/b/c), AC-7 시뮬, edge case |
| `.claude/scripts/sensor-payment-race-condition.sh` | +110 line | 신설 (8 검증) | sensor 회귀 차단 |
| `eval/tasks/regression-66-payment-race-condition.json` | +20 line | 신설 (11 검증) | eval 회귀 차단 |
| `.claude/shared-contracts.md §22` | +75 line | 신설 PaymentRaceCondition | 인터페이스 정본 |

---

## §2 검증 결과 (qa Evaluator 채점 정본)

### 2-1. jest server 회귀

```
Test Suites: 47 passed, 47 total
Tests:       634 passed, 634 total
```

- **이전**: 625 it (Sprint 진입 직전)
- **이후**: 634 it (+9 신규)
- **목표**: ≥ 631 it ✅ 충족 (+3 초과 달성)
- **회귀**: 0건 (47 spec suite 전부 PASS)

### 2-2. sensor-payment-race-condition.sh

```
=== sensor-payment-race-condition (02:07:01) ===
  [PASS] payment.usecase: payment.status='refunded' 사전 게이트 박제
  [PASS] payment.usecase: payment.status='partial_refunded' 사전 게이트 박제
  [PASS] payment.usecase: [PaymentRaceCondition] logger.warn 박제
  [PASS] payment.usecase: already_refunded / already_partial_refunded reason 박제
  [PASS] prisma-payment.repository: findUniqueOrThrow 박제 (구멍-B 진입 명시)
  [PASS] prisma-payment.repository: updateMany WHERE credits gte CAS 패턴 박제 (구멍-B 차단)
  [PASS] prisma-payment.repository: CAS_MISMATCH throw 박제 (DLQ retry 위임)
  [PASS] shared-contracts §22 PaymentRaceCondition 박제

PASS: 8 / FAIL: 0
[RESULT] PASS — race condition 차단 패턴 (구멍-A 사전 게이트 + 구멍-B CAS) 모두 박제
```

### 2-3. eval regression-66

```
▶ [regression-66-payment-race-condition]
  ✅ PASS (11/11 criteria)

PASS: 1 / TOTAL: 1 / FAIL: 0
통과율: 1.0
```

### 2-4. eval 전체 회귀

- **65 task 실행** → **64 PASS / 1 FAIL** (regression-006 inventory drift만)
- **regression-66 신설** → 11/11 PASS
- regression-006 FAIL = sensor 카운트 문서(43) vs 실측(44) drift = **본 sprint sensor 신설의 자연 결과 (incident-log doc/warn 박제)**
- 결제 회귀 0건: regression-52~65 전부 PASS 보존

---

## §3 AC BDD 8건 매핑 (qa Evaluator 채점 정본)

| AC | spec 위치 | 결과 |
|---|---|---|
| **AC-1** payment.status='refunded' 시 succeeded webhook skip | `payment.usecase.spec.ts` PAY-P3-A describe `'AC-1: payment.status=refunded ...'` | ✅ PASS |
| **AC-2** payment.status='partial_refunded' 시 추가 환불 webhook skip | `payment.usecase.spec.ts` PAY-P3-A describe `'AC-2: payment.status=partial_refunded ...'` | ✅ PASS |
| **AC-3** 동시 환불 race 시뮬 — 첫 commit 후 두 번째 차단 | `payment.usecase.spec.ts` PAY-P3-A describe `'AC-3 시뮬: 동시 환불 webhook 2건 race ...'` | ✅ PASS |
| **AC-4** CAS mismatch throw + 호출자 retry 위임 | `prisma-payment.repository.spec.ts` `'AC-4(a) CAS 패턴 ...'` + `'AC-4(b) CAS mismatch ...'` + `'AC-4(c) deficit 분기 ...'` | ✅ PASS (3 it) |
| **AC-5** 회귀 차단 (eval regression-52~65 회귀 0건) | `npx jest` 47 spec suite 전부 PASS + eval regression-52~65 PASS | ✅ PASS |
| **AC-6** 보안 — 게이트 우회 불가 + CAS_MISMATCH 시 webhook event failed 박제 | `payment.usecase.spec.ts` PAY-P3-A describe `'AC-6: completePaymentAtomically 트랜잭션 실패 ...'` | ✅ PASS |
| **AC-7** 100 동시 환불 시뮬 race window 검증 | `prisma-payment.repository.spec.ts` `'AC-7 시뮬: 100 동시 환불 호출 ...'` (Promise.all 100건) | ✅ PASS |
| **AC-8** incident-log 박제 + AuditLog 정합 | `incident-log.jsonl` 본 sprint 진행 중 race_condition_blocked 카테고리 1건 박제 (workflow/info) + drift 1건 박제 (doc/warn) | ✅ PASS |

---

## §4 Definition of Done 체크리스트

### 4-1. 정량 KPI (10-1 정합)

- [x] jest server **634 PASS** (목표 ≥ 631 — +3 초과 달성)
- [x] eval regression **66 PASS** (regression-66 11/11)
- [x] sensor-payment-race-condition.sh **8/8 PASS**
- [x] shared-contracts **§22 박제** (PaymentRaceCondition)
- [x] AC BDD **8건 매핑 완료** (qa 독립 재실행 시 검증)
- [x] incident-log **2건 박제** (race_condition_blocked + drift)

### 4-2. 정성 검증 (10-2 정합)

- [x] payment.usecase.ts payment.status='refunded' OR 'partial_refunded' 사전 게이트 박제
- [x] prisma-payment.repository.ts CAS 패턴 박제 (`findUniqueOrThrow + updateMany WHERE credits >= actualDeducted`)
- [x] CAS_MISMATCH throw + 호출자 retry 위임 정합
- [x] PAY-P2-2 DLQ 패턴 정합 (CAS_MISMATCH → webhookEventRepo 'failed' + DLQ enqueue 영역, 기존 webhook-retry.job.ts 회귀 보존)
- [x] sensor-adversarial-pre-commit P16 (결제 원자성) 영역 회귀 보존

### 4-3. 산출물 박제 (10-3 정합)

- [x] Initializer Draft (planner): `.claude/state/sprint-pay-p3-a-race-condition-draft.md` (668 line)
- [x] Generator progress: `reports/sprint-pay-p3-a-race-condition-progress.md` (본 파일)
- [ ] qa Evaluator: `reports/QA_REPORT.md` (CONDITIONAL PASS 또는 PASS — qa 인계 후 영역)

### 4-4. 회귀 차단 (10-4 정합)

- [x] PAY-P0-1 webhook event_id 멱등성 회귀 0
- [x] PAY-P0-2 PG↔DB 정합성 cron 회귀 0
- [x] PAY-P0-3 운영자 수동 크레딧 UI 회귀 0
- [x] PAY-P1-1 Refund 4분기 처리 회귀 0 (PAY-P3-A CAS 강화)
- [x] PAY-P1-3 결제 실패 retry + cleanup cron 회귀 0
- [x] PAY-P2-1 부분 환불 비율 회귀 0 (PAY-P3-A partial_refunded 사전 게이트 강화)
- [x] PAY-P2-2 Webhook DLQ + retry 회귀 0
- [x] PAY-P2-3 SmsServicePort 캡슐화 회귀 0
- [x] PAY-P2-4 AdminAuditLog beforeState/afterState 회귀 0

---

## §5 Generator 결정 기록

### 5-1. CAS 패턴 적용 영역 (sprint draft 정본 정합)

- `refundPaymentAtomically` $transaction 내부에서 `tx.author.findUnique` → `tx.author.findUniqueOrThrow + tx.author.updateMany WHERE credits >= actualDeducted`로 정정
- 0 row 갱신 시 `throw new Error('CAS_MISMATCH ...')` → 호출자(refund-payment.usecase) 자체 catch 또는 payment.usecase의 cancel 분기 catch가 webhook event 'failed' + DLQ enqueue 진행

### 5-2. completePaymentAtomically 보강 보류 (Draft §3-1 선택 영역)

- `completePaymentAtomically`는 `tx.author.update` (race window 작은 increment)이므로 본 sprint 보강 영역에서 **보류** (선택 영역, AC-7 영향 0건)
- 결제 increment race window는 음수 잔액 0 fix와 무관 + Postgres atomic increment는 race-safe (decrement는 잔액 검증 필수이므로 CAS 필요)
- 향후 별도 sprint에서 검토 영역

### 5-3. AC-3 spec 시뮬 정합 보강

- 첫 호출 status='completed'으로 작성 시 기존 약식 게이트(L186)가 우선 차단 → cancel 분기 미진입 → first PASS만 남고 second 검증 0건
- **수정**: 첫 호출 status='pending'로 정정 (정상 cancel webhook 시나리오) → 첫 호출 환불 처리 → 두 번째 호출 status='refunded' (시뮬) → 사전 게이트 차단

### 5-4. 인벤토리 drift 별도 sprint 위임

- regression-006 inventory drift 1건 검출: 문서 sensor 43 vs 실측 44
- 본 sprint sensor 1건 신설(sensor-payment-race-condition.sh)의 자연 결과
- HARNESS §14.4 카운트 갱신은 **grimoire-harness agent 책임 영역** — 본 sprint 책임 외 (incident-log doc/warn 박제 완료)

---

## §6 다음 단계

### 6-1. qa Evaluator 인계

- `reports/QA_REPORT.md` 박제 (AC 8건 채점 + 거짓말 차단 영역)
- 독립 재실행: `cd grimoire-server && npx jest` + `bash .claude/scripts/sensor-payment-race-condition.sh` + `bash eval/scripts/eval-runner.sh tasks/regression-66-payment-race-condition.json`
- 직접 Read: `payment.usecase.ts`, `prisma-payment.repository.ts`, spec 파일들 (의미 있는 assertion 검증)

### 6-2. 메인 commit + push develop

- 본 progress 박제 후 메인이 commit + push develop (PP-13 화이트리스트 통과 영역)
- 3 레포 develop branch (server + claude-docs)

### 6-3. main 머지 영역 (사용자 결정)

- dev 24h 안정성 박제 후 사용자 명시 필요 — `server main 머지 진행`
- 본 sprint 영역은 **dev 배포만 자동** (PAY-P3-A 정본 §9 정합)

---

## §7 변경 이력

- **2026-05-09 #10_8 (PP-7 라우팅 정정 후 server agent 첫 재진입)** — 본 progress 박제. Initializer Draft 13 섹션 + AC BDD 8건 정합 100% 적용. CAS 패턴 + 사전 게이트 + spec 9 it + sensor 8 검증 + eval 11 검증 + shared-contracts §22 박제. 외부 API 0 + DB schema 0. jest 625→634 (+9), sensor 39→40, eval 65→66, shared-contracts §1~21→§1~22.

---

## 참조

- **Initializer Draft**: `.claude/state/sprint-pay-p3-a-race-condition-draft.md`
- **shared-contracts §22**: `.claude/shared-contracts.md`
- **sensor**: `.claude/scripts/sensor-payment-race-condition.sh`
- **eval**: `eval/tasks/regression-66-payment-race-condition.json`
- **인접 sprint progress**:
  - `reports/sprint-pay-p1-1-refund-atomicity-progress.md`
  - `reports/sprint-pay-p2-1-partial-refund-progress.md`
  - `reports/sprint-pay-p2-2-webhook-dlq-progress.md`
  - `reports/sprint-pay-p2-4-audit-strengthening-progress.md`

**상태**: ✅ Generator 영역 종료 — **qa Evaluator 인계 영역**.
