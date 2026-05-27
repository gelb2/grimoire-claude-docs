# 작업 계획: CC-2b — 선물·환불 결제 적립 연동 (CRITICAL-2 최종 조각) (writing-plans)

> 작성: 2026-05-20 / grimoire-planner (Initializer 패턴) / **계획 수립 전용 — 코드 변경 0건**
> 근거 정본: `reports/CREDIT_CORE_DIAGNOSIS.md` §1-B(T4 선물) + §1-C(T7 환불) + §8 Sprint 분할표 CC-2 행 + §10 미확인
>           + `.claude/state/sprint-cc2a-charge-wiring-plan-draft.md` (트랜잭션 패턴 §2-2 案 1 + §10-4 "CC-2b 이월 범위")
>           + `.claude/state/sprint-credit-overhaul-s-phase-draft.md` §8-4(적립 로직) + §8-6(선물 단위) + `.claude/shared-contracts.md` §30 CreditOverhaul
> 적용 양식: `.claude/skills/writing-plans/SKILL.md` (2~5분 sub-task / [MUST]·[SHOULD]·[NICE] / 위험도 🔴🟡🟢 / 의존 / rollback / 검증 게이트)
> 구조 정본: `.claude/state/sprint-cc1-pay-s1-plan-draft.md` + `sprint-cc2a-charge-wiring-plan-draft.md` (CC-1/CC-2a 계획과 동일 섹션 구조·포맷)
> 범위: **CC-2b만** (선물 T4 + 환불 T7 + 이중 외상 통합). **CC-3(이월/원장) / CC-4(마이그레이션) / CC-5(PAY-P1-4)는 범위 외** — 착수 직전 상세화 원칙.

---

## 0. 진행 순서 + 의존 개요

```
CC-1 (적립 비결제 — 완료·qa검증) ──선행 완료──┐
CC-2a (충전 결제 적립 — 완료·qa검증) ─────────┼──> CC-2b (선물·환불 결제 적립 연동)
                                              │      │
   PAY-S1 (로컬 DB — credit_overhaul_i_phase) ─┘      ├─ S0 선행: §10 미확인 + 선물·환불 경로 6건 Read 해소
                                                      │
                          T4 transfer 신설 (案 1 패턴 재사용) ─┐
                          T7 환불 신 경로 + 이중 외상 통합 ─────┴─> 통합 spec → CRITICAL-2 전체 해소 증명
```

- **CC-1·CC-2a가 선행 완료** — CC-1(비결제 적립 5경로 + 통합 spec)·CC-2a(충전 T3 + `completePaymentWithPoints` 案 1 패턴 + C-6 해소)가 종료·qa검증됨(shared-contracts §30 변경 이력 `2026-05-19`/`2026-05-20` 박제). CC-2b는 그 위에 선물·환불을 얹어 **적립 8경로(T1~T8)를 전부 신 시스템으로 이행 — CRITICAL-2 완전 종결**.
- **PAY-S1 로컬 DB 동기화가 DB 전제** — CC-2b 통합 spec이 신 스키마(`credit_ledgers`/`Author.deficitPoints`/`Author.pointsGift`)를 전제. PAY-S1 P3~P5(로컬 apply) 완료 = CC-2b 진입의 DB 전제(CC-2a와 동일 — 이미 충족됐을 것).
- **S0 선행 게이트** — 진단 §10 미확인 + §1-B/§1-C가 지목한 선물·환불 경로 6건(`credit.usecase.gift` / `creditRepo.giftTransfer` / `refundPaymentAtomically` / `RefundLog` 스키마 / payment.usecase cancel 분기 / CC-2a `completePaymentWithPoints` 패턴 + `computeChargeLedgerEntries`)을 **S0 sub-task에서 Read로 해소**한 뒤 본 작업 진입.
- **CC-2b는 CC-2a가 확립한 案 1 패턴(도메인 헬퍼 + Repository 단일 `$transaction`)을 그대로 재사용** — 신 트랜잭션 설계를 처음부터 짜는 것이 아니라 검증된 패턴의 적용. 단 선물(양측 작가)·환불(이중 외상)은 케이스 특성상 추가 설계가 필요(§2·§3).

### 예상 총 시간

- CC-2b: **규모 M~L** — 본 계획 sub-task 합산 ~5~7.5h.
- sub-task 총 **26개** (S0 6 + T4 선물 설계결정 1 + transfer 포트·구현 5 + gift 재배선 3 + T7 환불 설계결정 1 + 환불 신 경로 5 + 통합 spec 4 + 마무리 6).
- **분할 근거**: ≥30분 + **돈 직결 도메인**(결제 원자성 — CLAUDE.md §9 절대 규칙) + CRITICAL-2 선물·환불 미연동(적립 8경로 中 마지막 2경로) + T4는 **양측 작가 동시 이동**(데드락 위험), T7은 **이중 외상 통합**(구 `RefundLog.deficitCredits` ↔ 신 `Author.deficitPoints`) — 1줄 실수가 "돈은 환불됐는데 외상 장부 분열" / "선물 보냈는데 한쪽만 반영"으로 직결 → sub-task 단위 검증 게이트 + git commit 단위 rollback 필수.

---

## 1. S0 — 선행: §10 미확인 + 선물·환불 경로 현행 해소 (착수 게이트)

> CREDIT_CORE_DIAGNOSIS §10 + §1-B/§1-C — 추정 금지. §1-B/§1-C가 file:line만 제시 → 본 sub-task로 선물·환불 경로 현행을 Read 해소한 뒤 설계 결정(C2a·C5a) 진입.
> ⚠️ 본 계획은 진단 리포트(2026-05-18 `658b7d9`) 기반 file:line을 인용하나, CC-1·CC-2a 머지로 코드가 이동했을 수 있음 → S0가 **현행 재실측**. (본 계획 작성 중 실제 Read한 항목은 §12에 "확인" 표기 — S0는 그 현행 재확인.)

### 1-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C1a | `credit.usecase.ts` `gift()` Read — 현행 `creditRepo.giftTransfer(senderId, receiverId, amount, 'gift_sent:..', 'gift_received:..')` 호출 형태 + 사전 검증(자기 선물 차단 / sender 잔액 검증) 확정 | [MUST] | 🟢 | 4분 | PAY-S1 P5 | `gift()` 현행 코드 박제 (재배선 diff 입력) |
| C1b | `prisma-credit.repository.ts` `giftTransfer` Read — `$transaction` 구조(데드락 방지 `senderId < receiverId` 정렬 lock + `SELECT ... IN ($1,$2) ORDER BY id FOR UPDATE` + sender/receiver `credits` 갱신 + `creditLog.createMany` 2건) 확정. **신 `transfer`가 재사용할 lock 패턴** | [MUST] | 🟢 | 5분 | - | `giftTransfer` $transaction 본문 + lock 순서 패턴 박제 |
| C1c | `refund-payment.usecase.ts` + `prisma-payment.repository.ts` `refundPaymentAtomically` Read — 환불 `$transaction` 11단계(payment 조회 → 비율 계산 → `Author.credits` CAS decrement → `CreditLog` 음수 → `RefundLog` 박제) + `refundedAmount/payment.amount` 비례 계산(PAY-P2-1) + CAS 패턴(PAY-P3-A) 확정 | [MUST] | 🟢 | 6분 | - | `refundPaymentAtomically` 11단계 + 비례·CAS 로직 박제 (환불 신 경로 diff 입력) |
| C1d | `RefundLog` 스키마 + `Author` 스키마 Read — `RefundLog.credits Int`(실 환수)·`deficitCredits Int @default(0)`(구 외상) + `Author.credits`(`[DEPRECATED]`)·`deficitPoints`(신 외상)·`pointsGift` 확정. **이중 외상 통합 설계 입력** | [MUST] | 🟢 | 4분 | - | `RefundLog`/`Author` 현행 컬럼 의미 박제 + 이중 외상 위치 2곳 명시 |
| C1e | CC-2a `completePaymentWithPoints` + `computeChargeLedgerEntries` Read — 案 1 패턴(단일 `$transaction`: authors FOR UPDATE + Payment 갱신 + deficit 상계 + earn ledger + Author 캐시) + 도메인 헬퍼 추출 방식 확정. **CC-2b transfer·환불이 재사용할 정본 패턴** | [MUST] | 🟢 | 5분 | - | 案 1 패턴 + `computeChargeLedgerEntries` 시그니처 박제 (C3·C6 설계 입력) |
| C1f | `CreditLedgerPort` + `GrantPointsUseCase.grantGift` Read — port의 `earn`/`spend`/`settleDeficit` 시그니처 + `grantGift(receiverId, points, relatedId?)` 현행(CC-1 신설, 호출처 0건) 확정. `payment.usecase` cancel 분기(`refundPaymentUseCase.execute` 호출 + webhook 멱등성) 형태 Read | [MUST] | 🟢 | 5분 | - | `CreditLedgerPort` + `grantGift` 시그니처 + cancel 분기 현행 박제 |

**S0 게이트**: C1a~C1f [MUST] 6건 완료 = §10 미확인 + 선물·환불 경로 현행 해소 → 설계 결정(C2a·C5a) 진입 허가. 미확인 잔존 시 본 작업 착수 금지.

> 진단 §10 미확인 항목 중 CC-2b 직접 관련은 없음(테마 차감 구 경로 = CC-1 종료 / dev plan 분포 = CC-4 / sensor hook = harness / `theme-slot.usecase` Author.plan = CC-3 / Polar KYC = CC-5). CC-2b의 미확인은 **선물·환불 경로 코드 현행**(C1a~C1f) — 진단 §1-B/§1-C가 file:line만 제시하고 트랜잭션 본문은 본 계획이 직접 확인.

---

## 2. T4 선물 — `CreditLedgerPort.transfer` 트랜잭션 설계 결정

> CREDIT_CORE_DIAGNOSIS §1-B — `credit.usecase.gift()`가 `creditRepo.giftTransfer()` 구 정수 경로(sender `Author.credits` 차감 + receiver 가산 + `CreditLog` 2건을 1 `$transaction`). 신 시스템엔 "1 트랜잭션 양측 이동" 메서드가 없음 — `ChargePointsUseCase`(sender 소진)와 `GrantPointsUseCase.grantGift`(receiver 적립)가 분리. **선물은 돈 직결**이라 원자성 필수.

### 2-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C2a | T4 선물 `transfer` 트랜잭션 설계 결정 명문화 — §1-B 권장案(단일 `$transaction` 메서드)을 본 계획 §2-2에 박제. 데드락 방지 lock 순서 + sender 소진 우선순위 적용 + receiver `source='gift'` 적립을 한 트랜잭션에 묶는 구조 확정. ADR-012 보강안 1줄 작성(실제 ADR 수정은 구현 sub-task) | [MUST] | 🟢 | 6분 | S0 게이트 | §2-2 설계 결정 명문화 (구현 C3의 설계 입력) |

### 2-2. T4 선물 트랜잭션 설계 (planner 결정 — C2a 산출)

**§1-B 제시 — "1 트랜잭션 양측 이동" 메서드 신설** (분리 후 보상 트랜잭션은 §1-B가 "선물은 돈 직결이라 원자성 필수 → 단일 트랜잭션 메서드 권장"으로 명시 후순위). 따라서 **신설 위치만 결정**하면 됨:

| 案 | 신설 위치 | 장점 | 단점 |
|---|---|---|---|
| **案 G1** `CreditLedgerPort`에 `transfer(senderId, receiverId, amount, relatedId?)` 단일 `$transaction` 메서드 신설 | 진단 §1-B가 명시 지목한 위치. sender/receiver 양측 작가 + 두 ledger row(sender spend 출처별 + receiver `gift` earn)를 1 `$transaction`으로 묶음 | 선물은 "포인트 원장 내부 이동"이라 `CreditLedgerPort`가 도메인상 정확한 소유자. `earn`/`spend`/`settleDeficit`와 동일 port에 응집 | sender 소진 우선순위 계산(`planConsumption`) + receiver `earn` 캐시 갱신 로직이 기존 `spend`/`earn`과 중복 위험 → 도메인 헬퍼 재사용으로 해소 |
| 案 G2 `PaymentRepositoryPort`에 신설 (CC-2a `completePaymentWithPoints` 위치 차용) | CC-2a 案 1과 같은 Repository | 선물은 Payment 도메인이 아님(`Payment` row 무관 — 독자↔작가 포인트 이동) → `PaymentRepository`에 두면 단일책임 위반. **부정합** |

**권고 — 案 G1 (`CreditLedgerPort.transfer` 단일 `$transaction` 메서드 신설)**. 사유:

1. **진단 §1-B가 명시 지목** — "`CreditLedgerPort`에 `transfer(senderId, receiverId, amount)` 단일 `$transaction` 메서드 신설"을 본문에 직접 권장. CC-2 행도 "`CreditLedgerPort.transfer`(선물 원자) 신설"을 포함 작업으로 명시.
2. **도메인 정합** — 선물은 Payment(결제)가 아니라 **포인트 원장 내부 이동**(독자 charged/gift → 작가 gift). `CreditLedger` 원장이 정본인 자원의 이동이므로 `CreditLedgerPort`가 정확한 소유자. CC-2a의 `completePaymentWithPoints`는 "결제 완료 + 적립"이라 `PaymentRepository`였던 것 — 선물은 결제 무관이라 위치가 다름.
3. **CC-2a 案 1 패턴 재사용** — `transfer`도 CC-2a와 동일하게 ① 양측 `authors` row FOR UPDATE ② 도메인 순수 함수로 금액 계산 ③ ledger row 박제 + Author 캐시 갱신을 단일 `$transaction`으로. 패턴은 검증됨 — 적용 위치만 `CreditLedgerPort`.

**`transfer` 트랜잭션 내부 설계 (案 G1 — C3 구현 입력)**:

```
transfer(senderId, receiverId, amount, relatedId?):
  $transaction:
   ① 데드락 방지 — sender/receiver 두 authors row 를 FOR UPDATE.
      lock 순서: 기존 giftTransfer(prisma-credit.repository.ts) 와 동일 —
      `[firstId, secondId] = senderId < receiverId ? [senderId, receiverId] : [receiverId, senderId]`
      → `SELECT ... FROM authors WHERE id IN ($1,$2) ORDER BY id FOR UPDATE`
      (항상 작은 id 먼저 lock — 두 선물이 교차해도 데드락 불가. C1b 가 이 패턴 확인)
   ② sender 소진 — `planConsumption`(소진 우선순위 무료→구독→선물→충전) 으로 sender 4 출처에서 amount 차감.
      ⚠️ 선물 차감은 deficit 금지 — sender 잔액 부족 시 throw (외상으로 선물 불가).
        sender available < amount 면 트랜잭션 진입 전 또는 진입 직후 throw.
      sender 출처별 `CreditLedger` spend row(type='spend') 박제 + Author 4 캐시 차감.
   ③ receiver 적립 — `source='gift'` earn row(type='earn', amount 양수) 박제 + Author.pointsGift 캐시 가산.
      receiver balanceAfter = receiver 4 출처 합 + amount.
   ④ 반환 — { senderSpentBySource, receiverGiftBalance } 류 (web 표시용).
```

> **로직 중복 해소** — `transfer`의 sender 측은 기존 `spend`의 `planConsumption` 계산을, receiver 측은 `earn`의 캐시 가산을 그대로 쓴다. **신규 도메인 헬퍼는 불필요할 수 있음** — `planConsumption`(이미 순수 함수)가 sender 계산을 커버. C3a에서 "헬퍼 추가 여부"를 Read 결과로 판정(선물 전용 계산이 `planConsumption` + 단순 가산뿐이면 헬퍼 0건, `transfer` 메서드가 직접 조합). CC-2a처럼 별도 `computeXxx` 헬퍼가 필요한 건 deficit 상계 같은 복합 계산이 있을 때 — 선물은 그게 없음.

> **sender 소진 우선순위 정책 — §1-B 정합**: 진단 §1-B "sender 차감 = `ChargePointsUseCase`(소진 우선순위)". 즉 선물 보낼 때 sender의 무료적립부터 빠진다. 이것이 `planConsumption` 정본 동작. **단 deficit는 금지** — `planConsumption`은 잔액 부족 시 `deficitIncurred`를 반환하므로, `transfer`는 `deficitIncurred > 0`이면 throw(외상 선물 불가). 일반 `spend`(채팅 사후 차감)는 deficit 허용이지만 선물은 불허 — 이 차이가 `transfer`를 `spend` 재사용이 아닌 별도 메서드로 두는 이유.

> **사용자 결정 불요(트랜잭션 구조)** — 案 G1은 진단 §1-B 명시 권장 + 헥사고날 정본 + CC-2a 패턴이 일치하는 기술 결정. 단 **선물 단위(pt 환산값)는 사용자 결정 게이트** — §6 참조.

---

## 3. `CreditLedgerPort.transfer` 신설 + gift 재배선 (T4 구현)

> 案 G1 — `CreditLedgerPort`에 `transfer` 단일 `$transaction` 메서드 신설 + `credit.usecase.gift`를 구 `giftTransfer` → 신 `transfer`로 재배선. receiver 측은 `source='gift'` earn(현 `grantGift`와 동일 회계 — `transfer`가 내부에서 직접 수행).

### 3-1. sub-task 표 — `transfer` 신설

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C3a | 헬퍼 필요 여부 판정 + (필요 시) 도메인 순수 함수 추가 — `credit-consumption-policy.ts` Read 후 `planConsumption`만으로 sender 계산이 충분한지 판정. 충분하면 헬퍼 0건(§2-2 주). 선물 전용 계산(예: sender 출처별 + receiver 가산 묶음)이 가독성상 필요하면 `computeGiftLedgerEntries` 류 추가 | [MUST] | 🟡 | 5분 | C2a | 판정 1줄 명문화. 헬퍼 추가 시 `npx tsc --noEmit` PASS |
| C3b | `credit-consumption-policy.spec.ts` 갱신 — C3a에서 헬퍼 추가한 경우만. 선물 sender 차감(잔액 충분 / 4 출처 분산 / 잔액 부족 시 deficitIncurred>0) 단위 검증 | [SHOULD] | 🟡 | 4분 | C3a | 헬퍼 추가 시 `npm test credit-consumption-policy.spec` PASS / 미추가 시 skip |
| C3c | `CreditLedgerPort`에 `transfer(senderId, receiverId, amount, relatedId?)` 메서드 시그니처 추가 — 반환 `{ senderSpentBySource: Record<CreditSource,number>; receiverGiftBalance: number }` 류. shared-contracts §30 정합 인터페이스 확정 | [MUST] | 🟡 | 5분 | C2a | tsc PASS |
| C3d | `prisma-credit-ledger.repository.ts` `transfer` 구현 — §2-2 설계대로 단일 `$transaction`: ① 양측 authors FOR UPDATE(작은 id 먼저) ② sender `planConsumption` 차감 + 출처별 spend ledger + Author 4 캐시 차감, `deficitIncurred>0` 시 throw ③ receiver `source='gift'` earn ledger + `Author.pointsGift` 가산. 자기 선물(senderId===receiverId) 차단 | [MUST] | 🔴 | 9분 | C3c,C3a,C1b | tsc PASS + 단일 `$transaction` 블록 grep 확인 |
| C3e | `prisma-credit-ledger.repository.spec.ts` `transfer` 단위 검증 — 정상 선물(sender 차감 + receiver 가산) / sender 잔액 부족 throw(외상 선물 불가) / 자기 선물 throw / sender 4 출처 분산 차감(무료→구독→선물→충전 순) | [MUST] | 🟡 | 6분 | C3d | `npm test prisma-credit-ledger.repository.spec` PASS |

### 3-2. sub-task 표 — `credit.usecase.gift` 재배선

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C4a | `CreditUseCase`에 `CreditLedgerPort` 활용 정합 — `ledger`는 이미 `@Optional() @Inject('CreditLedgerPort')`로 주입됨(`credit.usecase.ts:17-19`, `getPointBalance`가 사용). `gift`도 이 `ledger.transfer`를 쓰도록 — 단 `gift`가 ledger 미주입 시 어떻게 할지 결정: CC-2b는 적립 완결 sprint이므로 **`ledger` 필수화** 권고(Optional 제거) 또는 미주입 시 throw. C0f Read 결과로 분기 | [MUST] | 🟡 | 5분 | C1f,C3c | tsc PASS |
| C4b | `credit.usecase.ts` `gift()` 재배선 — 구 `creditRepo.giftTransfer(senderId, receiverId, amount, 'gift_sent:..', 'gift_received:..')` → `ledger.transfer(senderId, receiverId, amountPt, relatedId?)`. 사전 검증(자기 선물 차단 / sender 존재)은 유지하되 sender 잔액 검증은 `transfer` 내부 `planConsumption`이 수행하므로 정합 정리. `amount`(크레딧/pt 단위)는 §6 결정 종속 | [MUST] | 🟡 | 6분 | C4a,§6 게이트 | tsc PASS + 구 `giftTransfer` 호출 grep 0건 |
| C4c | `credit.usecase.spec.ts` 갱신 — `gift` 시 `ledger.transfer` 호출 mock 검증(구 `giftTransfer` mock 제거) + 자기 선물 throw + sender 잔액 부족 throw 회귀 보존 | [MUST] | 🟡 | 6분 | C4b | `npm test credit.usecase.spec` PASS |

> **web 계약 영향 플래그** — `credit.controller.ts:19` `gift` body `{ receiverId: string; amount: number }`. CC-2b에서 `amount`가 **크레딧 단위(1·3·5)인지 pt 단위(1,000·3,000·5,000)인지** 결정 필요(§6). web `gift` 호출부가 보내는 값과 server 해석이 어긋나면 선물액이 1,000배 틀어짐 → **shared-contracts §30 변경 이력에 명시 + web 핸드오프 1건**(§10-3). 권고: server가 body `amount`를 pt로 받고(디노미 정합 — CC-2a `Payment.credits`도 pt 통일과 일관), web이 선물 버튼 UI에서 1,000·3,000·5,000pt를 표시. 단 사용자가 "독자에겐 1·3·5 크레딧으로 보이게" 결정하면 controller가 ×1,000 환산 — §6에서 확정.

---

## 4. T7 환불 — 신 경로 + 이중 외상 통합 설계 결정

> CREDIT_CORE_DIAGNOSIS §1-C — 현재 환불은 `refundPaymentAtomically`(`RefundLog` 박제 + `Author.credits` 환수, 부족 시 `RefundLog.deficitCredits Int` 외상). 신 경로로: `CreditLedgerPort` 환수 + **이중 외상 시스템 통합** — 구 `RefundLog.deficitCredits` 외상과 신 `Author.deficitPoints` 외상을 `Author.deficitPoints` 하나로 통합. `RefundLog.credits`/`deficitCredits` pt 단위 정합.

### 4-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C5a | T7 환불 신 경로 + 이중 외상 통합 설계 결정 명문화 — §4-2 권고案(`refundPaymentAtomically` 확장 vs 신 메서드)을 본 계획에 박제. 이중 외상 통합 방식(`RefundLog.deficitCredits` 의미 재정의) 확정. ADR-012 보강안 1줄 작성 | [MUST] | 🟢 | 7분 | S0 게이트 | §4-2 설계 결정 명문화 (구현 C6의 설계 입력) |

### 4-2. T7 환불 신 경로 설계 (planner 결정 — C5a 산출)

**문제 A — 환불 환수 트랜잭션의 위치 (`refundPaymentAtomically` 확장 vs 신 메서드)**:

| 案 | 구조 | 장점 | 단점 |
|---|---|---|---|
| **案 R1** `PaymentRepositoryPort`에 `refundPaymentWithPoints` 신 메서드 신설 (CC-2a `completePaymentWithPoints` 패턴 정합) | 환불 신 경로 = 단일 `$transaction`: Payment status 갱신 + 비례 계산(PAY-P2-1) + **신 포인트 환수**(`CreditLedger` spend) + Author 4 캐시 차감 + 부족분 `deficitPoints` 가산 + `RefundLog` 박제. 구 `refundPaymentAtomically`는 `@deprecated` | CC-2a 案 1과 **완전 대칭** — `completePaymentWithPoints`(충전)↔`refundPaymentWithPoints`(환불). 구 메서드 보존 → C6 교체 실패 시 즉시 원복. CC-2a가 이미 이 패턴을 박제 | 신 메서드 1개 추가 (단 CC-2a가 같은 결정을 함 — 일관) |
| 案 R2 `refundPaymentAtomically` 내부를 신 포인트 경로로 직접 교체 | 메서드 1개 유지 | PAY-P1-1/P2-1/P3-A가 쌓아온 11단계 로직(비례·CAS·RefundLog)을 신 경로로 한 번에 갈아끼움 → 회귀 위험 폭. 실패 시 즉시 원복 불가. 구 spec 전수 재작성 | 회귀 안전망 0 — CC-2a가 案 1에서 `completePaymentAtomically` 보존을 택한 사유와 정면 배치 |

**권고 — 案 R1 (`PaymentRepositoryPort.refundPaymentWithPoints` 신 메서드 신설)**. 사유:

1. **CC-2a 案 1과 대칭** — CC-2a가 충전을 `completePaymentAtomically`(구) 보존 + `completePaymentWithPoints`(신) 신설로 했다. 환불도 동일하게 `refundPaymentAtomically`(구) 보존 + `refundPaymentWithPoints`(신) 신설 → 패턴 일관. 충전↔환불이 같은 구조라 server 가독성·유지보수 정합.
2. **회귀 안전망** — PAY-P1-1(전액 환불 원자성) + PAY-P2-1(부분 환불 비례) + PAY-P3-A(CAS race 차단)가 `refundPaymentAtomically` 11단계에 누적돼 있다. 신 메서드로 분리하면 구 메서드 + 구 spec이 그대로 살아 회귀 기준선 보존 — C6 교체 실패 시 cancel 분기를 구 메서드로 즉시 원복(1줄).
3. **비례·CAS 로직 이식** — 신 메서드는 PAY-P2-1 비례 계산(`ratio = refundedAmount / payment.amount`, `Math.floor`)과 PAY-P3-A CAS 패턴을 **그대로 이식**하되 대상이 `Author.credits` Int → `CreditLedger` spend(4 출처)로 바뀜. CC-2a `computeChargeLedgerEntries`처럼 환불 환수 계산을 도메인 순수 함수(`computeRefundLedgerEntries` 류)로 추출해 비례·외상 계산을 테스트 가능하게.

**문제 B — 이중 외상 통합 (§1-C 핵심)**:

현재 외상이 두 곳에 분열:
- 구: `RefundLog.deficitCredits Int @default(0)` (`schema.prisma:532`) — 환불 시 `Author.credits` 부족분.
- 신: `Author.deficitPoints Int @default(0)` (`schema.prisma:33`) — 채팅 사후 차감 잔액 부족분. CC-2a로 충전(`completePaymentWithPoints`)이 이를 상계.

**통합 설계 — `Author.deficitPoints` 하나로 단일화**:

| 항목 | CC-2b 통합 후 |
|---|---|
| 환불 시 작가 포인트가 환수액보다 부족 | 부족분을 `Author.deficitPoints`에 **가산** (구 `RefundLog.deficitCredits`에만 적던 것을 신 외상 장부로 이전). `CreditLedger`에 `type='deficit_incur'` row 박제(reason=`refund_deficit:..`) — 채팅 deficit와 동일 회계 |
| `RefundLog.deficitCredits` 컬럼 | **존속하되 의미 = "이 환불이 유발한 외상 pt"** (감사 추적용 — 환불 1건이 얼마 외상 냈는지 RefundLog로 조회 가능). 단 **외상의 정본은 `Author.deficitPoints`** — `RefundLog.deficitCredits`는 그 환불 건의 기여분 기록일 뿐. 즉 외상 잔액 = `Author.deficitPoints` (단일), `RefundLog.deficitCredits` = 명세 row |
| 다음 충전 시 상계 | CC-2a `completePaymentWithPoints`가 `Author.deficitPoints`를 상계 → 환불 외상도 충전으로 자동 회수(구 시스템은 `RefundLog.deficitCredits`를 아무도 상계 안 함 → 영구 외상이었음. 통합으로 해소) |
| `RefundLog.credits`/`deficitCredits` 단위 | pt 단위로 정합 (MEDIUM-4 — `Payment.credits`가 CC-2a에서 pt로 재해석됨 → 환불 비례 계산도 pt 기준. `RefundLog.credits`=실 환수 pt, `deficitCredits`=외상 발생 pt) |

> **이중 외상 통합의 핵심 효과** — 구 시스템은 `RefundLog.deficitCredits`에 적힌 외상을 **상계하는 코드가 0건**(진단 §1-C). 환불로 외상이 생겨도 영구히 안 갚힘. CC-2b가 환불 외상을 `Author.deficitPoints`로 보내면 CC-2a `completePaymentWithPoints`의 deficit 상계 로직이 **환불 외상까지 자동 회수** — 외상 장부 단일화 + 회수 경로 일원화. 이것이 §1-C "이중 외상 시스템 통합"의 실질.

> **컬럼 의미 변경 — 스키마 물리 변경 0건**: `RefundLog.deficitCredits`/`credits`는 컬럼 그대로(`Int`), **의미만 재해석**(크레딧 부족분 → pt 외상 기여분). CC-2a가 `Payment.credits`를 같은 방식(물리 rename 없이 의미 재해석)으로 처리한 선례 정합. 컬럼 물리 rename(`deficitCredits`→`deficitPoints` 등)은 마이그레이션 동반 → **CC-2b 범위 외, CC-4 위임**. C6 구현 시 컬럼 의미를 코드 주석 + shared-contracts §13/§30에 박제.

> **사용자 결정 불요(환불 구조)** — 案 R1 + 이중 외상 통합은 진단 §1-C 명시 권장 + CC-2a 案 1 대칭 + 회귀 안전망의 기술 결정. cost-accountant 게이트도 불요(§8 참조 — 환불은 신규 AI 기능 0건, 가격 무관).

---

## 5. `refundPaymentWithPoints` 신설 + 환불 경로 재배선 (T7 구현)

> 案 R1 — `PaymentRepositoryPort`에 `refundPaymentWithPoints` 단일 `$transaction` 메서드 신설 + `payment.usecase` cancel 분기·`refund-payment.usecase`를 신 경로로 재배선. 이중 외상은 `Author.deficitPoints`로 통합.

### 5-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C6a | 도메인 헬퍼 추출 — `credit-consumption-policy.ts`에 환불 환수 계산 순수 함수 `computeRefundLedgerEntries(refundPt, currentSourceBalances)` 류 추가: 비례 환수액 기준 4 출처에서 환수 가능액 + 부족분(=외상 가산분) + Author 캐시 델타 반환. CC-2a `computeChargeLedgerEntries` 패턴 정합 | [MUST] | 🟡 | 6분 | C5a | `npx tsc --noEmit` PASS |
| C6b | `credit-consumption-policy.spec.ts` 갱신 — 환불 환수 헬퍼 단위 검증(잔액 ≥ 환수액 정상 / 잔액 < 환수액 → 외상 발생 / 잔액 0 → 전액 외상 / 4 출처 분산 환수) | [MUST] | 🟡 | 5분 | C6a | `npm test credit-consumption-policy.spec` PASS |
| C6c | `PaymentRepositoryPort`에 `refundPaymentWithPoints` 메서드 시그니처 추가 — 입력 `{paymentId, authorId, refundPt, refundedAmount, reason, source}` / 반환 `{actualRefunded, deficitIncurred, proportionalPt, isPartial}` 류. `refundPaymentAtomically`는 `@deprecated` 주석(즉시 제거 X — CC-4/회귀 안전) | [MUST] | 🟡 | 5분 | C5a | tsc PASS |
| C6d | `prisma-payment.repository.ts` `refundPaymentWithPoints` 구현 — 단일 `$transaction`: ① authors FOR UPDATE ② Payment 조회 + 비례 계산(PAY-P2-1 `ratio`/`Math.floor` 이식) + status='refunded'/'partial_refunded' ③ `computeRefundLedgerEntries`로 환수액·외상분 계산 ④ 출처별 `CreditLedger` spend row + Author 4 캐시 차감 ⑤ 부족분 → `Author.deficitPoints` 가산 + `deficit_incur` ledger(reason=`refund_deficit:..`) ⑥ `RefundLog` 박제(`credits`=실 환수 pt, `deficitCredits`=외상 발생 pt). PAY-P3-A CAS race 차단 이식 | [MUST] | 🔴 | 9분 | C6c,C6a,C1c,C1d | tsc PASS + 단일 `$transaction` + CAS 로직 grep 확인 |
| C6e | `payment.usecase` cancel 분기 + `refund-payment.usecase` 재배선 — `refundPaymentUseCase.execute`가 `paymentRepo.refundPaymentAtomically` → `refundPaymentWithPoints` 호출하도록 교체. `payment.usecase.ts:438` cancel 분기는 `execute` 호출 형태 유지(내부만 신 경로). webhook 멱등성(L1 eventId / L3 RefundLog) 회귀 보존. `balanceBefore`/`auditLog` 박제를 pt 단위로 정정 | [MUST] | 🟡 | 7분 | C6d,C1f | tsc PASS + 구 `refundPaymentAtomically` 호출 grep 0건 |
| C6f | `refund-payment.usecase.spec.ts` + `payment.usecase.spec.ts` 갱신 — 환불 시 `refundPaymentWithPoints` 호출 mock 검증(구 mock 제거) + 정상 환수 / deficit 환수(`Author.deficitPoints` 가산) / 부분 환불 비례 / 멱등성 회귀 보존 | [MUST] | 🟡 | 7분 | C6e | `npm test refund-payment.usecase.spec payment.usecase.spec` PASS |

> C3d·C6d는 🔴 — DB 쓰기 트랜잭션 로직. 단 코드 변경이며 마이그레이션은 아님(스키마 불변 — `CreditLedger`/`authors`/`refund_logs`/`payments` 기존 테이블만 사용, 신규 컬럼 0건). 실패 시 commit revert로 롤백.

> **이중 외상 통합 검증 접근** — C6d ⑤가 환불 부족분을 `Author.deficitPoints`(채팅 deficit와 동일 컬럼)에 가산하면 외상 장부가 단일화된다. C6f가 "환불 → `Author.deficitPoints` 가산" 단위 검증, C7d가 "환불 외상 → 충전 시 `completePaymentWithPoints` 상계"를 통합 검증(구 시스템에선 불가능했던 환불 외상 회수가 통합 후 작동함을 박제).

---

## 6. 사용자 결정 게이트 — 응원 선물 단위 (pt 환산값)

> S Phase draft §8-6 — "응원 선물: 현 1·3·5크레딧 → 1,000·3,000·5,000pt 환산 (적정성 S Phase 재검토)". §0-1도 "§8-6 응원 선물 단위 적정성"을 "미확정 (사용자 결정 대기)"로 명시. `credit.controller.ts:19` `gift` body `amount` 단위가 무엇인지 web과 계약 재합의 필요(진단 §1-B).

### 6-1. 게이트 내용

- **결정 대상 ①** — 선물 단위 pt 환산값: 현 1·3·5크레딧을 디노미 1:1,000 그대로 **1,000·3,000·5,000pt**로 갈지, 채팅 시대 단위 적정성을 재검토해 다른 값(예: 채팅 1턴 normal=810pt 대비 선물 최소단위 조정)으로 갈지.
- **결정 대상 ②** — `gift` body `amount` 단위 계약: web→server `POST /credits/gift` body `amount`가 **pt 단위(1,000·3,000·5,000)**인지 **크레딧 단위(1·3·5, controller가 ×1,000 환산)**인지. 독자에게 보이는 표면 단위와 직결.
- **현 상태**: S Phase draft가 "1,000·3,000·5,000pt 환산 유지하되 적정성 재검토"로 **잠정값**만 둠 — cost-accountant 승인 영역 아님(선물은 충전 패키지처럼 §0 마진 검증 대상이 아니라 독자↔작가 포인트 이동, 매출 0). 순수 **UX/사업 결정**.

### 6-2. 게이트 판정

| 시나리오 | 처리 |
|---|---|
| 사용자가 S Phase draft §8-6 잠정값(1·3·5크레딧 → **1,000·3,000·5,000pt**) **그대로 승인** + body `amount` 단위 결정 | C4b/C3d 즉시 진행. 환산 상수를 `domain/model`(예: `GIFT_POINT_OPTIONS = [1000, 3000, 5000]`)에 박제 |
| 사용자가 선물 pt 값 **변경 요청** | CC-2b 선물 부분(C3·C4) 일시 보류 → 변경값 확정 → 그 값으로 C3d/C4b 재개. **cost-accountant 게이트 불요**(선물은 §0 마진 대상 아님) |

> **사용자 결정이 필요한 항목** = 본 §6 (선물 단위 pt 환산값 + body `amount` 단위 계약) — **2건**. 트랜잭션 구조(§2·§4)·이중 외상 통합(§4-2)은 전부 기술 결정으로 planner 권고 충분. CC-2b 착수 전 사용자에게 §6 게이트만 확인받으면 됨.
> ⚠️ §6은 CC-2a §6(충전액·보너스율)과 성격이 다름 — CC-2a는 가격이라 cost-accountant 재검증 분기가 있었으나, **선물은 매출 0이라 cost-accountant 무관**. 순수 UX 결정.

---

## 7. 통합 spec 신설 (CC-2b 근본 해결 + CRITICAL-2 종결 증명)

> CREDIT_CORE_DIAGNOSIS §8 — CRITICAL-2가 "unit PASS인데 미연동"으로 가려진 근본 원인. CC-1(비결제)·CC-2a(충전)가 통합 spec을 신설했듯, CC-2b는 **선물이 양측 `CreditLedger`에 박히고, 환불이 신 경로로 환수+외상 통합되는지** 통합 검증 + **적립 8경로 전부 신 시스템 이행을 종결 증명**.

### 7-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C7a | 통합 spec 파일 신설 — `application/credit/credit-gift-refund-integration.spec.ts` 류. CC-1/CC-2a 통합 spec 패턴 차용 — 실 `CreditUseCase`/`PaymentUseCase` + 인메모리 `CreditLedgerPort` fake(도메인 헬퍼 실호출) 기반, mock 최소화 | [MUST] | 🟡 | 8분 | C4c,C6f | 파일 생성 + tsc PASS |
| C7b | T4 선물 통합 케이스 — `CreditUseCase.gift` 실행 → ① sender `CreditLedger`에 출처별 `type='spend'` row + Author 4 캐시 차감 ② receiver `CreditLedger`에 `source='gift'`·`type='earn'` row + `Author.pointsGift` 가산. **구 `giftTransfer` 경로면 FAIL**(미연동 RED 재현) | [MUST] | 🟡 | 6분 | C7a | 해당 it PASS, 미연동 시 RED 재현 확인 |
| C7c | T7 환불 통합 케이스 — 환불 webhook 처리 → ① `Author` 4 출처 캐시에서 환수 + `CreditLedger` `type='spend'` row ② `RefundLog` 박제(`credits`/`deficitCredits` pt) ③ 잔액 부족 시 `Author.deficitPoints` 가산 + `deficit_incur` ledger. 구 `refundPaymentAtomically`(`Author.credits`) 경로면 FAIL | [MUST] | 🟡 | 6분 | C7a | 해당 it PASS, 미연동 시 RED 재현 확인 |
| C7d | 이중 외상 통합 + CRITICAL-2 종결 통합 케이스 — ① 환불로 `Author.deficitPoints` 외상 발생 → 충전 webhook(`completePaymentWithPoints`) → 환불 외상이 충전으로 상계됨(구 시스템에선 불가능했던 회수 박제) ② **CRITICAL-2 종결 증명**: 적립 8경로(T1~T8)가 전부 신 `CreditLedger` 경로임을 grep + 통합으로 확인 (§11 종결 게이트와 연동) | [MUST] | 🟡 | 7분 | C7a | 해당 it PASS — 이중 외상 통합 + CRITICAL-2 종결 증명 |

> **통합 spec이 CC-2b 핵심** — CC-1/CC-2a와 동일 철학: 단위 테스트 PASS여도 `gift`/환불 경로가 신 메서드를 실제 호출하지 않으면 CRITICAL-2 선물·환불분 미해소. C7b/C7c가 미연동 시 RED를 재현하도록 작성 → 회귀 방어. C7d가 이중 외상 통합(환불 외상 → 충전 상계)을 통합 경로로 박제 + 적립 8경로 종결을 증명.

---

## 8. CC-2b 마무리 — 빌드·문서·sensor + 원가 게이트

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C8a | 전체 빌드 — `npm run build` 무에러 | [MUST] | 🟢 | 3분 | C7d | 종료코드 0 |
| C8b | 전체 테스트 — `npm test` 통과, server 커버리지 **≥60%** 유지 | [MUST] | 🟢 | 5분 | C8a | jest 전체 PASS, 커버리지 게이트 통과 |
| C8c | `shared-contracts.md` §30 + §13 갱신 — §30 CreditOverhaul에 `CreditLedgerPort.transfer` 신설 + §13 RefundPaymentAtomically에 `refundPaymentWithPoints` 신설 + 이중 외상 통합(`Author.deficitPoints` 단일화 / `RefundLog.deficitCredits` 의미 재정의) + 변경 이력 1줄씩 박제. ⚠️ §30/§13이 인터페이스 정본 → 미갱신 시 다른 agent 통합 단계 깨짐 | [MUST] | 🟡 | 6분 | C8b | `.claude/scripts/sensor-shared-contracts.sh` silent |
| C8d | `grimoire-server/TECH_STATUS.md` + `docs/data-model.md`/`SCHEMA.md`(`RefundLog.deficitCredits`/`credits` 컬럼 의미 변경 주석) + `docs/api-contract.md`(`POST /credits/gift` body `amount` 단위 변경) 갱신 — CC-2b 완료(선물·환불 적립 연동 + 이중 외상 통합 + CRITICAL-2 종결) 박제. `docs-sync` drift sensor 확인 | [MUST] | 🟡 | 5분 | C8c | drift sensor silent |
| C8e | sensor 일괄 — `sensor-shared-contracts` / `-instruction-degradation` / `-agent-priority-labels` / `-agent-interaction` + `sensor-credit-source-accounting.sh`·`sensor-credit-denomination.sh`(존재 시) 실행 | [SHOULD] | 🟢 | 3분 | C8d | sensor 전부 silent/PASS |
| C8f | `eval/scripts/eval-runner.sh` regression 회귀 — 결제·환불 관련 regression(`regression-55-refund-atomicity` / `regression-61-partial-refund` / `regression-74~77` 존재 시) 실행. 신 경로 전환 후 회귀 PASS 확인 | [SHOULD] | 🟢 | 4분 | C8e | regression 전부 PASS / 실패 시 회고 |

> **원가 게이트 판정 (C8 단계 박제)**: CC-2b는 **신규 AI 기능 추가 0건** — 선물·환불 경로의 신 시스템 재배선. 선물은 독자↔작가 포인트 이동(매출 0, §0 마진 무관), 환불은 기존 결제의 역방향(가격 정의 무변경). `CREDIT_PRODUCTS`·차감 N·구독 풀 등 §0 직결값을 **건드리지 않음**. 따라서 **cost-accountant 마진 검증 게이트 불요** — CC-1과 동일(CC-2a는 디노미 패키지 4종 때문에 조건부였으나 CC-2b는 패키지 무관). 선물 단위(§6)도 매출 0이라 cost-accountant 아닌 사용자 UX 결정.

---

## 9. rollback 단위

- 각 sub-task는 git commit 단위 — C3·C4·C6·C7 별 commit 권장. 실패 시 해당 commit revert.
- C3c(`transfer` 신설)·C6c(`refundPaymentWithPoints` 신설)는 구 메서드(`giftTransfer`/`refundPaymentAtomically`)를 **즉시 제거하지 않음**(deprecated 주석만) → C4b/C6e 교체 실패 시 구 경로로 즉시 원복 가능. CC-3/CC-4 또는 별도 후속에서 일괄 정리.
- 코드 변경만(🟡/🔴 C3d·C6d) — **DB 스키마 비변경**(`transfer`/`refundPaymentWithPoints`는 기존 `credit_ledgers`/`authors`/`refund_logs`/`payments` 테이블만 사용, 신규 컬럼 0건). PAY-S1과 달리 백업 불요. tsc/jest 실패 = 즉시 해당 commit 단위 롤백.
- ⚠️ C3d·C6d 트랜잭션 로직은 🔴 — 운영 배포 전 통합 spec(C7) 전건 PASS가 게이트. dev 배포는 CC-4(마이그레이션 sprint) 또는 별도 — CC-2b 자체는 코드 머지까지.
- `RefundLog.deficitCredits`/`credits` 컬럼 의미 재해석은 코드 주석 + 문서만 — 물리 변경 0건이라 revert는 코드 commit revert로 완결.

---

## 10. 핸드오프

### 10-1. 담당 + 산출물 위치

| 영역 | 담당 | 산출물 위치 | 다음 단계 진입 조건 |
|---|---|---|---|
| §6 사용자 게이트 | **사용자** (planner 경유 확인) | 선물 단위 pt 환산값 + body `amount` 단위 결정 | 승인 = C3d/C4b 진행 / 변경 = 변경값 확정 후 재개 |
| CC-2b S0 | grimoire-server | §10 미확인 + 선물·환불 경로 현행 해소 결과 박제 (progress.md) | C1a~C1f 완료 = 설계 결정 진입 |
| CC-2b C2a/C5a 설계 결정 | grimoire-server (또는 planner 재확인) | 본 계획 §2-2/§4-2 권고案 채택 박제 | C2a·C5a 완료 = 구현 진입 |
| CC-2b C3~C8 구현 | grimoire-server (Generator) | Port/usecase/repository 코드 + spec + progress.md 갱신 | C8 마무리 |
| CC-2b 채점 | grimoire-qa (Evaluator) | `QA_REPORT.md` — sprint-progress 통과율 박제 + **CRITICAL-2 종결 통과율 박제** | — |

### 10-2. Initializer 산출물 (planner)

- 본 계획 = `.claude/state/sprint-cc2b-gift-refund-wiring-plan-draft.md`.
- **`reports/sprint-cc2b-gift-refund-wiring-progress.md` 생성 권고** — 본 계획의 sub-task 26건 체크리스트 + 완료 기준 + **CRITICAL-2 종결 증명 항목**을 progress.md로 박제 → server(Generator)가 Read 후 갱신, qa(Evaluator)가 채점 (책 Ch 16 Initializer→Generator→Evaluator 패턴).
- server / qa에게 본 계획 + progress.md Read 후 작업 핸드오프.

### 10-3. 원가 영향 플래그

- CC-2b는 **신규 AI 기능 추가 0건** — 선물·환불 경로의 신 시스템 재배선. cost-accountant 마진 검증 게이트 **불요**(선물=매출 0, 환불=기존 결제 역방향, 가격값 무변경 — CC-1과 동일. CC-2a의 디노미 패키지 같은 조건부 게이트 없음).
- 시각 검수(visual-canon-keeper) **불요** — CC-2b는 server 도메인 한정, UI 변경 0건.
- **web 핸드오프 1건** — `POST /credits/gift` body `amount` 단위가 §6에서 pt 단위로 확정되면(또는 표면 크레딧 단위 유지 결정) web 선물 버튼 UI가 그에 맞춰야 함 → shared-contracts §30 변경 이력에 "`gift` body `amount` 단위 = pt(또는 크레딧)" 명시 + web Generator 후속 sprint 핸드오프.

### 10-4. CC-3~CC-5로 이월되는 범위 (CC-2b 범위 외 — 명시)

| 항목 | 진단 근거 | 이월 sprint |
|---|---|---|
| CRITICAL-1 (`getBalance` 만료 미반영) + lazy 안전망 | §4 案 B | CC-3 |
| HIGH-1 (`Author.plan`↔`MembershipPlan.tier` 이중 출처) | §5-A | CC-3 |
| HIGH-3 (`getGiftRanking`/`getLogs` `CreditLedger` 재작성) — 선물 적립이 CC-2b로 `CreditLedger`에 가면 `getGiftRanking`(구 `CreditLog` 집계)이 신·구 분열 | §5-B / §2-3 | CC-3 |
| V Phase 마이그레이션 안전화 + dev/prod apply | §3 | CC-4 (CC-1·2·3 완결 후) |
| `Payment.credits`/`RefundLog.deficitCredits`·`credits` 컬럼 물리 rename | MEDIUM-4 | CC-4 |
| 구 `giftTransfer`/`refundPaymentAtomically`/`completePaymentAtomically`/`CreditUseCase` 구 메서드·`Author.credits` DROP | §2-3 폐기 의존 그래프 | CC-3/CC-4 후속 |
| PAY-P1-4 Polar 구독 연동 | §7 | CC-5 |

> ⚠️ **CC-2b가 `getGiftRanking` 분열을 유발** — 선물 적립을 `CreditLedger`(`source='gift'` earn)로 옮기면 구 `getGiftRanking`(`CreditLog` `reason='gift_received'` 집계)이 신·구 데이터 분열. CC-2b는 이를 **인지·핸드오프만** 하고 해소는 CC-3(HIGH-3). CC-2b progress.md + C8c shared-contracts 변경 이력에 "`getGiftRanking`/`getLogs` `CreditLedger` 재작성 = CC-3 필수" 명시. (CC-2b 범위에서 같이 하면 sprint 비대 — 진단 §8이 HIGH-3을 CC-3로 배치.)

---

## 11. 종합 게이트 — CC-2b 완료 선언 조건 + CRITICAL-2 전체 해소 증명

### CC-2b 완료 선언

- **§6 사용자 게이트**: 선물 단위 pt 환산값 + body `amount` 단위 결정 완료.
- **S0 게이트**: C1a~C1f [MUST] 6건 완료 (§10 미확인 + 선물·환불 경로 현행 해소).
- **C2a/C5a 설계 결정**: §2-2 案 G1 + §4-2 案 R1 + 이중 외상 통합 권고 채택 명문화.
- **본 작업 [MUST]**: C3a/c/d/e + C4a~c + C6a/c/d/e/f + C7a~d + C8a~d — 전부 통과. ([SHOULD] C3b/C8e/C8f 실패는 회고만.)
- **검증 게이트** (writing-plans Gate 1·2·3):
  - Gate 1 (빌드): C8a `npm run build` 무에러.
  - Gate 2 (테스트): C8b `npm test` 전체 PASS + 커버리지 ≥60%. **통합 spec(C7)이 핵심** — 선물이 양측 `CreditLedger`에 박히고 환불이 신 경로로 환수+외상 통합됨을 통합 테스트로 증명.
  - Gate 3 (문서/sensor): C8c~e — shared-contracts §30/§13 + TECH_STATUS + data-model/SCHEMA/api-contract 갱신 + sensor silent.

### CRITICAL-2 전체 해소 증명 (CC-2b 종결 게이트 — 가장 중요)

CC-2b는 CRITICAL-2의 마지막 조각 — 완료 시 **적립 8경로(T1~T8)가 전부 신 `CreditLedger` 시스템**임을 다음으로 증명:

| 경로 | 신 시스템 이행 sprint | 종결 증명 방법 |
|---|---|---|
| T1 가입 / T2 첫작품 | CC-1 | `grep -rn "GrantPointsUseCase" src/application/{auth,work-management}` ≥2 (CC-1 완료) |
| T5 관리자 지급 / T6 관리자 차감 | CC-1 | `grep -rn "grantManual\|CreditLedgerPort" src/application/admin` (CC-1 완료) |
| 테마 차감 | CC-1 | `grep -rn "chargeTheme" src/application` ≥1 (CC-1 완료) |
| T8 분석 환불 | CC-1 / I Phase | `refundAnalysis` 출처별 복원 (CC-1 §5-D 완료) |
| T3 충전 | CC-2a | `grep -rn "completePaymentWithPoints" src/application/payment` ≥1 (CC-2a 완료) |
| **T4 선물** | **CC-2b** | `grep -rn "ledger.transfer\|CreditLedgerPort.*transfer" src` ≥1 + 구 `giftTransfer` 호출 grep **0건** + 통합 spec C7b PASS |
| **T7 환불** | **CC-2b** | `grep -rn "refundPaymentWithPoints" src/application/payment` ≥1 + 구 `refundPaymentAtomically` 호출 grep **0건** + 통합 spec C7c PASS |

→ **CRITICAL-2 종결 선언 조건**: 위 8경로 전부 신 시스템 + 구 `giftTransfer`·`refundPaymentAtomically` 호출처 0건 + 통합 spec C7b/C7c/C7d PASS = "적립 8경로 전부 신 시스템 이행 완료 — CRITICAL-2 완전 종결". C7d가 이를 통합으로 박제, qa(Evaluator)가 QA_REPORT.md에 종결 통과율 박제.

### CC-2b 미해소 잔존 (범위 외 — 명시)

- CRITICAL-1 / HIGH-1 / HIGH-3(`getGiftRanking` 재작성) = **CC-3 범위** — CC-2b 완료 후에도 이월 금지 만료 반영·이중 출처·원장 단일화는 미해소.
- ⚠️ CC-2b가 `getGiftRanking` 신·구 분열을 **유발** — CC-3에서 `CreditLedger` 기반 재작성 필수(§10-4).
- 구 메서드(`giftTransfer`/`refundPaymentAtomically`/`completePaymentAtomically`) 제거 + `Author.credits` DROP + 컬럼 물리 rename = CC-3/CC-4 후속.
- CC-2b 완료 ≠ V Phase 마이그레이션 적용 가능 — CC-4는 CC-1·CC-2(a+b)·CC-3 전부 완결 후 (CREDIT_CORE_DIAGNOSIS §8 가장 중요한 결론).
- **단 CC-2b 완료 = CRITICAL-2(적립 미연동) 완전 종결** — CRITICAL-2 자체는 CC-2b가 마지막. 잔존 CRITICAL-1은 별개 결함(이월 금지).

---

## 12. 미확인 / 추정 금지 명시

| 항목 | 상태 | 해소 시점 |
|---|---|---|
| `credit.usecase.gift()` 현행 코드 | **확인** — 본 계획 작성 중 Read(`creditRepo.giftTransfer` 호출 + 자기 선물 차단 + sender 잔액 검증). S0가 현행 재실측 | C1a |
| `giftTransfer` $transaction 본문 + lock 순서 | **확인** — 본 계획 작성 중 Read(`senderId < receiverId` 정렬 lock + `IN ($1,$2) ORDER BY id FOR UPDATE` + `creditLog.createMany` 2건). S0 재확인 | C1b |
| `refundPaymentAtomically` 11단계 + 비례·CAS | **확인** — 본 계획 작성 중 Read(payment 조회 → `ratio`/`Math.floor` 비례 → CAS `updateMany WHERE credits>=` → `CreditLog` 음수 → `RefundLog`). S0 재확인 | C1c |
| `RefundLog`/`Author` 스키마 | **확인** — 본 계획 작성 중 Read(`RefundLog.credits`/`deficitCredits Int@default(0)` + `Author.credits`(DEPRECATED)/`deficitPoints`/`pointsGift`). S0 재확인 | C1d |
| CC-2a `completePaymentWithPoints` + `computeChargeLedgerEntries` | **확인** — 본 계획 작성 중 Read(案 1 단일 `$transaction` + 도메인 헬퍼 추출). S0 재확인 | C1e |
| `CreditLedgerPort` + `grantGift` + cancel 분기 | **확인** — 본 계획 작성 중 Read(`earn`/`spend`/`settleDeficit` 시그니처 + `grantGift(receiverId,points,relatedId?)` 호출처 0건 + `payment.usecase:438` cancel 분기). S0 재확인 | C1f |
| 선물 전용 도메인 헬퍼 필요 여부 | **미확인** — `planConsumption`만으로 sender 계산 충분한지 C3a Read 후 판정 | C3a |
| 선물 단위 pt 환산값 + body `amount` 단위 | **사용자 결정 대기** — S Phase draft §8-6 잠정값(1,000·3,000·5,000pt). 매출 0이라 cost-accountant 무관, 순수 UX 결정 | §6 게이트 (CC-2b 착수 전 사용자 확인) |
| sub-task 시간 추산 | 상대 추산 — 실측 아님. 본 계획은 분해 단위, 실제 시간은 server 실행 시 확정 | — |

> 본 계획은 코드 변경 0건 — 순수 계획 수립. 모든 file:line은 CREDIT_CORE_DIAGNOSIS 진단 리포트 + 본 계획 작성 중 실제 Read(`credit.usecase`/`prisma-credit.repository`/`refund-payment.usecase`/`prisma-payment.repository`/`schema.prisma`/`credit-ledger.port`/`grant-points.usecase`/`credit-consumption-policy`/`credit.controller`/`payment.usecase`/`shared-contracts §30/§13`) 기반. 미확인은 §12에 명시 — 추정 0건.

---

## 13. 변경 이력

- 2026-05-20: 본 계획 신설. CC-2b(S0 6 + T4 설계결정 1 + transfer 포트·구현 5 + gift 재배선 3 + T7 설계결정 1 + 환불 신경로 5 + 통합 spec 4 + 마무리 6 = 26 sub-task) writing-plans 양식 분해. T4 선물 권고 = 案 G1(`CreditLedgerPort.transfer` 단일 `$transaction` — sender `planConsumption` 차감 + receiver `gift` earn, 데드락 방지 lock 순서 = 작은 id 먼저 `IN ORDER BY id FOR UPDATE`). T7 환불 권고 = 案 R1(`PaymentRepositoryPort.refundPaymentWithPoints` 신설 — CC-2a `completePaymentWithPoints` 대칭) + 이중 외상 통합(`RefundLog.deficitCredits` 외상을 `Author.deficitPoints`로 일원화, 충전 시 자동 상계). 사용자 결정 게이트 2건(§6 선물 단위 pt + body `amount` 단위 — 매출 0이라 cost-accountant 무관). CC-2b 완료 = CRITICAL-2(적립 8경로 미연동) 완전 종결. 코드 변경 0건 — 계획 수립 전용.
