# Sprint PAY-P3-A — Race Condition 해소 진행 보고 (Draft)

> **작성**: 2026-05-09 #10_8 본 세션 grimoire-server agent (Generator 영역, PP-13 비활성 상태에서 진입)
> **계약 정본**: `.claude/state/sprint-pay-p3-a-race-condition-draft.md` (planner agent 13 섹션 + AC BDD 8건)
> **Generator 작업 영역**: 본 파일이 server agent 산출물 박제 영역 (Draft 영역, 정본 reports/* 이동은 후속 단계)

---

## §0 한 줄 요약

PAYMENT_AUDIT §1 구멍-A (eventId 다른 type 동시 처리 누락) + 구멍-B (transaction race) 동시 차단 진행.
- 구멍-A 차단: `payment.usecase.ts` `processNormalizedWebhook` 진입에 `payment.status='refunded' OR partial_refunded` 사전 게이트 추가
- 구멍-B 차단: `prisma-payment.repository.ts` `refundPaymentAtomically` $transaction 내부 `findUniqueOrThrow + updateMany WHERE credits >= actualDeducted` Postgres atomic CAS 패턴 적용
- DB schema 변경 0건 + 외부 API 0건 + 의존성 0건

---

## §1 변경 영역 (server agent Generator)

### 1-1. payment.usecase.ts (구멍-A 차단)

L186 약식 게이트 (`payment.status === 'completed'`) 다음에 사전 게이트 추가:
- `payment.status === 'refunded'` → skip + `webhookEventRepo.createIfAbsent { status:'skipped', errorMessage:'already_refunded' }` + return
- `payment.status === 'partial_refunded'` → skip + `errorMessage:'already_partial_refunded'` + return
- incident-log 박제 (`race_condition_blocked` 카테고리)

### 1-2. prisma-payment.repository.ts (구멍-B 차단)

L179-198 영역 race 차단:
- 기존: `tx.author.findUnique → update decrement`
- 신규: `tx.author.findUniqueOrThrow + updateMany WHERE credits >= actualDeducted`
- 0 row 갱신 시 → `throw new Error('CAS_MISMATCH ...')`
- 호출자 (`refund-payment.usecase`) catch → `webhookEventRepo.markStatus 'failed'` + DLQ enqueue 위임

### 1-3. spec 신설 (≥ 6 it)

- `payment.usecase.spec.ts`: AC-1/AC-2/AC-6 (3 it)
- `refund-payment.usecase.spec.ts`: AC-3/AC-4 (2 it)
- `prisma-payment.repository.spec.ts` 또는 통합: AC-7 race 시뮬 (1 it)

### 1-4. 신설 sensor

`.claude/scripts/sensor-race-condition-lock.sh` — CAS 패턴 grep + 사전 게이트 grep 8 검증.

### 1-5. 신설 eval task

`eval/tasks/regression-66-race-condition.json` — 8 검증 (AC BDD 8건 정합).

### 1-6. shared-contracts §22 신설

`PaymentRaceCondition` 인터페이스 정본 박제.

---

## §2 검증 결과 (본 progress 갱신)

- jest server: TBD (목표 ≥ 631)
- eval regression: TBD (목표 66)
- sensor: TBD (목표 40)
- shared-contracts: TBD (§1~22 박제 검증)
- incident-log race_condition_blocked 카테고리: TBD

---

## §3 변경 이력

- 2026-05-09 #10_8 server agent (Generator 진입) — Draft progress 박제
