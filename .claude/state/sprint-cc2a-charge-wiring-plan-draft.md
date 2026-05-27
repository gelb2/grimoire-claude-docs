# 작업 계획: CC-2a — 충전 결제 적립 연동 + 트랜잭션 패턴 확립 (writing-plans)

> 작성: 2026-05-19 / grimoire-planner (Initializer 패턴) / **계획 수립 전용 — 코드 변경 0건**
> 근거 정본: `reports/CREDIT_CORE_DIAGNOSIS.md` §1-A(T3 충전) + §6(settleDeficit / C-6) + §8 Sprint 분할표 CC-2 행 + §5-D + §10 미확인
>           + `.claude/state/sprint-credit-overhaul-s-phase-draft.md` §1-3·§8-4·§8-5 + `.claude/shared-contracts.md` §30 CreditOverhaul
> 적용 양식: `.claude/skills/writing-plans/SKILL.md` (2~5분 sub-task / [MUST]·[SHOULD]·[NICE] / 위험도 🔴🟡🟢 / 의존 / rollback / 검증 게이트)
> 구조 정본: `.claude/state/sprint-cc1-pay-s1-plan-draft.md` (CC-1 계획과 동일 섹션 구조·포맷)
> 범위: **CC-2a만** (충전 T3 + 트랜잭션 패턴 확립 + C-6 해소 + MEDIUM-1/MEDIUM-4 + `CREDIT_PRODUCTS` 디노미 4종). **CC-2b(선물 T4 / 환불 T7)는 범위 외** — CC-2a가 패턴 확립 후 별도 상세화(착수 직전 상세화 원칙).

---

## 0. 진행 순서 + 의존 개요

```
CC-1 (적립 비결제 연동 — 완료·qa검증) ──선행 완료──> CC-2a (충전 결제 적립 연동)
                                                       │
   PAY-S1 (로컬 DB 동기화 — credit_overhaul_i_phase) ──DB 전제──┤
                                                       │
                                                       └─ S0 선행: §10 미확인 + 충전 경로 4건 Read 해소
                                                                  │
                                          트랜잭션 통합 설계 결정(§1-A 2案) ─> 구현
```

- **CC-1이 선행 완료** — 적립 시스템(`GrantPointsUseCase` DI 패턴 + 통합 spec)이 안정화된 위에 충전 적립을 얹는다. CC-2a는 그 패턴을 결제 도메인으로 확장.
- **PAY-S1 로컬 DB 동기화가 DB 전제** — CC-2a 통합 spec이 신 스키마(`credit_ledgers`/`Author.deficitPoints`/`Author.pointsCharged`)를 전제하므로, 로컬에 `20260517_credit_overhaul_i_phase`가 적용돼야 통합 테스트 실행 가능. PAY-S1 P3~P5(로컬 apply) 완료 = CC-2a 진입의 DB 전제.
- **S0 선행 게이트** — 진단 §10 미확인 + §1-A가 "단순 호출 교체 불가"로 지목한 충전 경로 4건(`payment.usecase` 충전 success 분기 / `completePaymentAtomically` 트랜잭션 구조 / `grantCharge`·`settleDeficit` 시그니처 / `CREDIT_PRODUCTS` 현행)을 **S0 sub-task에서 Read로 해소**한 뒤 본 작업 진입.
- **트랜잭션 통합 설계 결정**이 CC-2a의 단일 최대 난점 — §1-A가 제시한 2案 중 권고案을 S0 직후 명문화(C2a)하고, 그 결정 위에 구현.

### 예상 총 시간

- CC-2a: **규모 L** — 본 계획 sub-task 합산 ~5.5~8.5h.
- sub-task 총 **28개** (S0 5 + 트랜잭션 설계결정 1 + Repository 통합메서드 4 + payment.usecase 재배선 4 + CREDIT_PRODUCTS 디노미 4 + C-6/MEDIUM 3 + 통합 spec 4 + 마무리 3).
- **분할 근거**: ≥30분 + **돈 직결 도메인**(결제 원자성 — CLAUDE.md §9 절대 규칙) + CRITICAL-2 충전 미연동 + C-6(충전해도 채팅 영구 차단) 동시 해소 + 트랜잭션 경계 재설계는 1줄 실수가 "돈은 냈는데 포인트 없음"으로 직결 → sub-task 단위 검증 게이트 + git commit 단위 rollback 필수.

---

## 1. S0 — 선행: §10 미확인 + 충전 경로 현행 해소 (착수 게이트)

> CREDIT_CORE_DIAGNOSIS §10 + §1-A — 추정 금지. §1-A가 "단순 교체 불가, 트랜잭션 재설계 필수"로 지목 → 본 sub-task로 충전 경로 현행을 Read 해소한 뒤 트랜잭션 설계 결정(C2a) 진입.
> ⚠️ 본 계획은 진단 리포트 기반 file:line을 인용하나, 진단(2026-05-18 `658b7d9`) 이후 CC-1 머지로 코드가 이동했을 수 있음 → S0가 **현행 재실측**.

### 1-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C1a | `payment.usecase.ts` 충전 success 분기 Read — `processNormalizedWebhook`의 `NORMALIZED_WEBHOOK_STATUS.SUCCESS` 분기(진단 §1-A `:334` 부근) 현행 코드 + `balanceBefore`/`auditLog` 박제 흐름 확정 | [MUST] | 🟢 | 5분 | PAY-S1 P5 | 충전 success 분기 현행 코드 박제 (재배선 diff 입력) |
| C1b | `prisma-payment.repository.ts` `completePaymentAtomically` Read — `$transaction` 3건(Payment update + Author.credits increment + CreditLog create) 구조 확정. 진단 §1-A "자체 $transaction" 사실 재확인 | [MUST] | 🟢 | 4분 | - | `completePaymentAtomically` $transaction 본문 박제 |
| C1c | `grant-points.usecase.ts` `grantCharge` + `credit-ledger.port.ts` `earn`/`settleDeficit` 시그니처 Read — `grantCharge(authorId, totalPoints, relatedId?)` 반환 `{settledDeficit, chargedPoints}` + 내부 `settleDeficit`($tx#1) + `earn`($tx#2) 2 트랜잭션 사실 재확인 (MEDIUM-1 입력) | [MUST] | 🟢 | 5분 | - | `grantCharge`/`earn`/`settleDeficit` 시그니처 표 + 2 트랜잭션 경계 박제 |
| C1d | `config.ts` `CREDIT_PRODUCTS` 현행 Read — 구 3종(credit-5/20/50, `credits` Int = 패키지 수량 5/20/50, `price`/`priceUsd`/`providerProductIdEnv`) + `Product` 타입 + `getProducts()`(`pricePerCredit` 계산) 확정 | [MUST] | 🟢 | 4분 | - | 구 3종 구조 + `getProducts` 현행 박제 (디노미 4종 개편 diff 입력) |
| C1e | `Payment` 모델 `credits` 컬럼 현행 의미 Read — `schema.prisma` `Payment.credits Int` + 진단 MEDIUM-4("패키지 수량 의미") 재확인. `RefundLog.credits`/`deficitCredits`는 CC-2b 범위라 **읽기만**(CC-2b 핸드오프 입력) | [MUST] | 🟢 | 4분 | - | `Payment.credits` 현행 의미 박제 + MEDIUM-4 처리 범위 확정 |

**S0 게이트**: C1a~C1e [MUST] 5건 완료 = §10 미확인 + 충전 경로 현행 해소 → 트랜잭션 설계 결정(C2a) 진입 허가. 미확인 잔존 시 본 작업 착수 금지.

> 진단 §10 미확인 항목 중 CC-2a 직접 관련은 없음(테마 차감 구 경로 = CC-1 종료 / dev plan 분포 = CC-4 / sensor hook = harness). CC-2a의 미확인은 **충전 경로 코드 현행**(C1a~C1e) — 진단 §1-A가 file:line만 제시하고 트랜잭션 본문은 본 계획이 직접 확인.

---

## 2. 트랜잭션 통합 설계 결정 (CC-2a 핵심 난점)

> CREDIT_CORE_DIAGNOSIS §1-A — 충전 success는 `completePaymentAtomically`가 **자체 `$transaction`**으로 (Payment 상태 + Author.credits 증가 + CreditLog 박제) 3건 원자 처리(CLAUDE.md §9 결제 원자성 절대 규칙). `grantCharge`는 내부 `settleDeficit`($tx#1) + `earn`($tx#2) **별도 2 트랜잭션**. 합치면 경계 어긋남 — "돈은 냈는데 포인트 없음"은 §0·§9상 절대 불가.

### 2-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C2a | 트랜잭션 통합 설계 결정 명문화 — §1-A 2案 중 **권고案 + 근거**를 본 계획 §2-2에 박제. ADR-012 보강안 1줄 작성(실제 ADR 수정은 구현 sub-task에서) | [MUST] | 🟢 | 6분 | S0 게이트 | §2-2 권고案 + 근거 명문화 (구현 C3·C4의 설계 입력) |

### 2-2. 권고案 + 근거 (planner 결정 — C2a 산출)

**§1-A 제시 2案**:

| 案 | 구조 | 장점 | 단점 |
|---|---|---|---|
| **案 1** `PaymentRepositoryPort`에 단일 `$transaction` 메서드 신설 | `completePaymentWithPoints(paymentId, authorId, totalPoints, productId)` — Payment 상태 + deficit 상계 + 충전 적립(`CreditLedger` earn) + Author 캐시 갱신을 **1 `$transaction`**으로 묶음 | 결제 원자성 보존(돈+포인트 동시 commit/rollback). 헥사고날 DIP 유지 — port는 도메인 의미("결제완료+포인트적립")만 노출, Prisma `tx` 미노출 | `CreditLedger` insert + `Author` 4 출처 캐시 갱신 로직이 `PaymentRepository`와 `PrismaCreditLedgerRepository` 양쪽에 중복될 위험 → 공용 헬퍼로 추출 필요 |
| **案 2** `CreditLedgerPort`에 외부 `tx` 핸들 오버로드 추가 | `earn`/`settleDeficit`가 외부 Prisma `tx` 인자를 받는 오버로드 → `payment.usecase`가 결제 `$transaction` 안에서 `grantCharge` 호출 | 적립 로직 재사용(중복 0건) | **헥사고날 DIP 위반** — `CreditLedgerPort`(도메인 port)가 Prisma `Prisma.TransactionClient`를 시그니처에 노출 → application/domain이 ORM 구현에 결합. 진단이 "신중"으로 명시 경계 |

**권고 — 案 1 (`PaymentRepositoryPort` 단일 `$transaction` 메서드 신설)**. 사유:

1. **헥사고날 DIP 보존이 결정적** — 案 2는 `CreditLedgerPort` 시그니처에 Prisma `TransactionClient`를 노출, application/domain 레이어가 ORM에 결합된다. CLAUDE.md §5 헥사고날 규칙·진단 §1-A "DIP 위반이라 신중" 경계와 정면 충돌. 案 2는 port 추상화의 의미를 무너뜨림.
2. **진단이 案 1에 무게** — §1-A 본문이 案 1(`completePaymentWithPoints` 등 신설)을 먼저 제시하고 案 2를 "신중" 단서로 후순위 배치. CC-2 행도 "`PaymentRepositoryPort`에 ... 단일 `$transaction` 메서드 신설"을 포함 작업으로 명시.
3. **기존 패턴과 정합** — `completePaymentAtomically`(현행)·`refundPaymentAtomically`(PAY-P1-1)가 이미 "결제 도메인 다건 원자 처리"를 `PaymentRepository` 단일 `$transaction` 메서드로 캡슐화하는 패턴. 案 1은 그 패턴을 자연 확장 — `completePaymentAtomically` → `completePaymentWithPoints`로 진화.
4. **案 1의 단점(로직 중복)은 해소 가능** — `CreditLedger` earn row 박제 + `Author` 4 출처 캐시 갱신 + `deficit` 상계 로직을 **순수 함수 / 도메인 헬퍼**로 추출(`credit-consumption-policy.ts`에 `settleDeficitOnCharge`가 이미 도메인 정책으로 존재 — 같은 위치에 ledger row 계산 헬퍼 추가)하면 `PaymentRepository`와 `PrismaCreditLedgerRepository`가 동일 헬퍼를 호출. `tx` 핸들만 양쪽이 각자 전달 → 중복 0건. **이 헬퍼 추출이 C3의 핵심**.
5. **트레이드오프 인정** — 案 1은 `PaymentRepository`가 `CreditLedger`/`Author` 캐시까지 건드려 단일책임이 다소 넓어진다. 단 "결제 완료 = 포인트 적립"이 §9상 원자 1단위이므로 같은 트랜잭션 메서드에 두는 것이 도메인 정합. 案 2의 DIP 위반 대가가 훨씬 큼.

> **트랜잭션 패턴 확립** = 案 1이 CC-2a 산출물. CC-2b(선물 T4 — `CreditLedgerPort.transfer` 단일 $tx / 환불 T7 — 이중 외상 통합)가 이 패턴(도메인 헬퍼 추출 + Repository 단일 $tx)을 그대로 재사용 → CC-2a가 패턴을 확립하는 sprint인 이유.

> **사용자 결정 불요** — 案 1은 진단 권고 + 헥사고날 정본 + 기존 패턴이 모두 일치하는 기술 결정. 게이트가 아닌 planner 권고로 충분. (사용자 결정이 필요한 항목은 §6 — `CREDIT_PRODUCTS` 충전액/보너스율 확정뿐.)

---

## 3. Repository 통합 트랜잭션 메서드 신설 (案 1 구현)

> 案 1 — `PaymentRepositoryPort`에 "결제완료 + deficit 상계 + 충전 적립 + Author 캐시 갱신"을 단일 `$transaction`으로 묶는 신 메서드. 도메인 헬퍼 추출로 `PrismaCreditLedgerRepository`와 로직 중복 0건.

### 3-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C3a | 도메인 헬퍼 추출 — `credit-consumption-policy.ts`에 충전 적립 계산 순수 함수 추가(`computeChargeLedgerEntries(totalPoints, currentDeficit, currentChargedCache)` 류: deficit 상계분 + charged earn 금액 + balanceAfter + Author 캐시 델타 반환). `settleDeficitOnCharge` 재사용 | [MUST] | 🟡 | 6분 | C2a | `npx tsc --noEmit` PASS |
| C3b | `credit-consumption-policy.spec.ts` 갱신 — 충전 적립 헬퍼 단위 검증(deficit < 충전액 / deficit ≥ 충전액 / deficit 0 / charged 캐시 가산) | [MUST] | 🟡 | 5분 | C3a | `npm test credit-consumption-policy.spec` PASS |
| C3c | `PaymentRepositoryPort`에 `completePaymentWithPoints(paymentId, authorId, totalPoints, productId, relatedId?)` 메서드 시그니처 추가 — 반환 `{settledDeficit, chargedPoints}`. `completePaymentAtomically`는 **즉시 제거하지 않고 deprecated 주석**(CC-2b/회귀 안전) | [MUST] | 🟡 | 5분 | C2a | tsc PASS |
| C3d | `prisma-payment.repository.ts` `completePaymentWithPoints` 구현 — 단일 `$transaction`: ① Payment status='completed' ② `CreditLedger` earn row(`source='charged'`, type='earn') + deficit 상계 시 `deficit_settle` row ③ `Author` `pointsCharged` 캐시 가산 + `deficitPoints` 차감. C3a 헬퍼로 금액 계산. ⚠️ 구 `CreditLog` 박제 유지 여부 = HIGH-3 종속 → **CC-1에서 적립이 `CreditLedger`로 이행됐으면 `CreditLog` 박제 제거**, 아니면 병행 1줄 박제(C1b Read 결과로 분기) | [MUST] | 🔴 | 8분 | C3c,C3a,C1b | tsc PASS + `$transaction` 단일 블록 grep 확인 |

> C3d는 🔴 — DB 쓰기 트랜잭션 로직. 단 코드 변경이며 마이그레이션은 아님(스키마 불변). 실패 시 commit revert로 롤백.

---

## 4. payment.usecase 충전 경로 재배선 (T3 — C-6 해소)

> CREDIT_CORE_DIAGNOSIS §1-A T3 + §6-2 C-6 — `payment.usecase` 충전 success 분기가 구 `completePaymentAtomically` → 신 `completePaymentWithPoints`로 교체. 이로써 `settleDeficit`가 실 충전 경로에 **처음으로 연결**돼 C-6(충전해도 deficit 미상계 → 채팅 영구 차단) 해소.

### 4-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C4a | `payment.usecase.ts` 충전 success 분기 교체 — `completePaymentAtomically(id, authorId, payment.credits, productId)` → `completePaymentWithPoints(id, authorId, totalPoints, productId, id)`. `totalPoints` = `CREDIT_PRODUCTS`에서 `productId`로 룩업한 신 4종 `points` 값(C5 디노미 개편 후 — 의존) | [MUST] | 🟡 | 5분 | C3d,C5b,C1a | tsc PASS + 구 `completePaymentAtomically` 호출 grep 0건 |
| C4b | `balanceBefore`/`auditLog` 박제 흐름 디노미 정합 — 충전 success의 `auditLog` 박제(`balanceBefore + payment.credits` 류)를 pt 단위(`pointsCharged` 기준 + `settledDeficit`/`chargedPoints` 메타)로 정정. C1a Read 결과 기반 | [MUST] | 🟡 | 5분 | C4a | tsc PASS |
| C4c | `payment.usecase.spec.ts` 갱신 — 충전 success 시 `completePaymentWithPoints` 호출 mock 검증(구 `completePaymentAtomically` mock 제거) + 멱등성(`webhookEventRepo` race) 회귀 보존 검증 | [MUST] | 🟡 | 6분 | C4b | `npm test payment.usecase.spec` PASS |
| C4d | C-6 해소 단위 검증 spec — `completePaymentWithPoints` 실행 시 `deficitPoints>0` 작가의 deficit가 충전액으로 상계됨을 검증(`prisma-payment.repository` spec 또는 통합 spec C7d에서). "deficit 10,000pt 작가 → 충전 → deficit 감소 → `isChatBlocked=false`" 경로 명시 | [MUST] | 🟡 | 6분 | C4c | 해당 spec PASS — C-6 해소 증명 |

> **C-6 해소 접근**: C-6은 별도 작업이 아니라 **T3 충전 연동에 완전 흡수**(진단 §6-2 "T3 완료 시 자동 완결"). C4a가 충전 경로를 `completePaymentWithPoints`로 바꾸면 그 메서드 내부 `$transaction`이 `settleDeficit` 상계를 수행 → `settleDeficit`가 실 충전 경로에 처음 연결됨. C4d가 이를 명시 검증(단위) + C7d가 통합 검증. "충전 → deficit 상계 → 채팅 차단 해제" 전 경로가 spec으로 박제됨.

---

## 5. `CREDIT_PRODUCTS` 디노미 4종 개편 (§8-5 / MEDIUM-4)

> S Phase draft §8-5 + ai-cost-table.md §2 — 구 3종(credit-5/20/50, `credits` Int=수량) → 신 4종(입문/기본/인기/베스트, `points` Int=pt). MEDIUM-4(`Payment.credits` Int → pt 단위 재해석)를 동반.

### 5-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C5a | `CREDIT_PRODUCTS` 신 4종 값 확정 — §8-5 + ai-cost-table.md §2 표 인용: 입문 ₩3,000/25,000pt / 기본 ₩5,000/41,667pt / 인기 ₩10,000/91,667pt(+10%) / 베스트 ₩30,000/287,500pt(+15%). **§6 사용자 확정 게이트 통과가 선행** — 미통과 시 본 sub-task 보류 | [MUST] | 🟢 | 4분 | §6 게이트 | 신 4종 값 표 확정 (ai-cost-table.md §2와 1:1 정합) |
| C5b | `config.ts` `CREDIT_PRODUCTS` 개편 — 구 3종 → 신 4종. 필드: `id`(credit-starter 등) / `name` / `points`(신 — 총 pt) / `price`(KRW) / `priceUsd` / `providerProductIdEnv` / `bonusRate`. 구 `credits` 필드명 → `points` 의미 명확화. `Product` 타입 자동 갱신 | [MUST] | 🟡 | 6분 | C5a | tsc PASS |
| C5c | `getProducts()` pt 기준 재작성 — `pricePerCredit` → `pricePerPoint`(또는 표면 단가 노출). `payment.usecase`·`polar.adapter`(`resolvePolarProductId`/`convertToKrw`의 `CREDIT_PRODUCTS` 참조 4곳) 정합 — `priceUsd` 매핑 유지, `credits`→`points` 필드명 변경 전파 | [MUST] | 🟡 | 6분 | C5b | tsc PASS + `grep -rn "\.credits" polar.adapter.ts` 잔존 0건 |
| C5d | MEDIUM-4 — `Payment.credits` Int 의미 정정. `Payment` 모델 `credits` 컬럼을 pt 단위로 재해석(스키마 컬럼 rename은 마이그레이션 동반 → **CC-2a 범위 외, 컬럼 의미만 코드 주석 + `completePaymentWithPoints`가 `totalPoints` pt를 직접 받게 설계**). `Payment.credits`에 pt를 저장하도록 `initiatePayment`/webhook 경로 정합 | [MUST] | 🟡 | 6분 | C5c,C1e | tsc PASS + `Payment.credits` 사용처 pt 정합 grep |
| C5e | `payment.usecase.spec.ts` `getProducts` 케이스 갱신 — "3개 상품 반환" → "4개 상품" / 가격 검증을 신 4종으로 / 기존 §0 마진 검증 it(`pricePerCredit / AI_COST_PER_THEME_KRW ≥ 5`)을 pt 기준 + ai-cost-table.md §2 실효 순단가 ≥ ₩0.09856로 재작성 | [MUST] | 🟡 | 6분 | C5d | `npm test payment.usecase.spec` PASS |

> **MEDIUM-4 처리 범위 명시**: `Payment.credits` 컬럼 **rename**(`credits` → `points`)은 스키마 변경 → 마이그레이션 동반이므로 CC-2a 범위 외(컬럼 의미 재해석 + 코드 정합만). 컬럼 물리 rename은 CC-4(마이그레이션 sprint) 또는 별도 후속에 위임. CC-2a는 "`Payment.credits` Int에 pt를 담는다"로 의미만 통일하고 `completePaymentWithPoints`가 pt를 직접 다루게 설계 — 진단 §1-A "Payment.credits를 pt로 재해석" 권고와 정합. 이를 C5d 주석 + CC-2b 핸드오프에 박제.

---

## 6. 사용자 결정 게이트 — `CREDIT_PRODUCTS` 충전액·보너스율 확정

> ai-cost-table.md §11 — "충전액 ₩3,000~₩30,000 4종 / 보너스율(인기 +10%·베스트 +15%)은 cost-accountant **'가정' 표기** — planner/사용자 결정 영역." S Phase draft §0-1·§2-2도 §8-5 패키지를 "사용자 결정 대기"로 명시.

### 6-1. 게이트 내용

- **결정 대상**: `CREDIT_PRODUCTS` 신 4종의 (a) 충전액 4가격(₩3,000 / ₩5,000 / ₩10,000 / ₩30,000) (b) 보너스율(입문·기본 0% / 인기 +10% / 베스트 +15%).
- **현 상태**: ai-cost-table.md §2가 cost-accountant 승인 `786b0f3`으로 신 4종을 박제하고 **전 패키지 §0 PASS 판정**(§7 검증표 — 입문 ₩0.09856 ~ 베스트 ₩0.09976, 전부 §0 최악 기준 ≥). 즉 **수치 자체는 §0 통과 검증 완료** — 남은 것은 "가격대 사업 결정"뿐.
- **게이트 성격**: §0 마진은 이미 검증됨 → **재마진검증이 아니라 가격 정책 확정**. 사용자가 ai-cost-table.md §2 값을 그대로 채택하면 C5a 즉시 진행. 사용자가 충전액/보너스율을 바꾸려 하면 → §8 cost-accountant 재검증 게이트 발동.

### 6-2. 게이트 판정

| 시나리오 | 처리 |
|---|---|
| 사용자가 ai-cost-table.md §2 신 4종(₩3,000~₩30,000 / 0·0·+10·+15%) **그대로 승인** | C5a~C5e 즉시 진행. cost-accountant 추가 검증 **불요**(§8 참조 — 이미 `786b0f3` 승인) |
| 사용자가 충전액 또는 보너스율 **변경 요청** | **CC-2a 일시 중단** → cost-accountant에 변경값 §0 재검증 의뢰 → 마진 ≥3배(실효 순단가 ≥ ₩0.09856) 확인 후 ai-cost-table.md §2 갱신 → 그 값으로 C5a 재개 |

> **사용자 결정이 필요한 유일 항목** = 본 §6 (충전액·보너스율 채택 여부). 트랜잭션 통합(§2)·C-6(§4)·MEDIUM(§5)은 전부 기술 결정으로 planner 권고 충분. CC-2a 착수 전 사용자에게 §6 게이트 1건만 확인받으면 됨.

---

## 7. 통합 spec 신설 (CC-2a 근본 해결 + 패턴 확립)

> CREDIT_CORE_DIAGNOSIS §8 — CRITICAL-2가 "unit PASS인데 미연동"으로 가려진 근본 원인. CC-1이 적립 비결제 경로에 통합 spec을 신설했듯, CC-2a는 **충전 webhook이 `CreditLedger`에 `source='charged'` earn row를 실제로 박고 deficit를 상계하는지** 통합 검증.

### 7-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C7a | 통합 spec 파일 신설 — `application/payment/payment-charge-credit-integration.spec.ts` 류. CC-1 통합 spec 패턴 차용 — DI 컨테이너 실제 wiring 기반(mock 최소화), `PaymentUseCase` + `completePaymentWithPoints` 실 경로 | [MUST] | 🟡 | 8분 | C4d,C5e | 파일 생성 + tsc PASS |
| C7b | 충전 적립 통합 케이스 — 충전 success webhook 처리 → `CreditLedger`에 `source='charged'`·`type='earn'` row 박힘 + `Author.pointsCharged` 캐시 가산 검증. **구 `completePaymentAtomically` 경로면 FAIL**(미연동 RED 재현) | [MUST] | 🟡 | 6분 | C7a | 해당 it PASS, 미연동 시 RED 재현 확인 |
| C7c | 디노미 충전액 통합 케이스 — `productId='credit-starter'`(입문) 충전 → `CreditLedger` earn `amount=25,000pt` 검증(신 4종 `points` 값 정합). `getProducts` 4종 반환 검증 | [MUST] | 🟡 | 5분 | C7a | 해당 it PASS |
| C7d | C-6 해소 통합 케이스 — `deficitPoints=10,000` 작가 → 충전 webhook → ① `CreditLedger`에 `deficit_settle` row ② `Author.deficitPoints` 감소 ③ `isChatBlocked` 재평가 시 `false`. **충전해도 채팅 영구 차단 결함이 사라졌음을 통합 증명** | [MUST] | 🟡 | 6분 | C7a | 해당 it PASS — C-6 해소 통합 증명 |

> **통합 spec이 CC-2a 핵심** — CC-1과 동일 철학: 단위 테스트가 PASS여도 "충전 경로가 `completePaymentWithPoints`를 실제 호출"하지 않으면 CRITICAL-2 충전분이 미해소. C7b가 미연동 시 RED를 재현하도록 작성 → 회귀 방어. C7d가 C-6(충전→채팅 차단 해제)을 통합 경로로 박제.

---

## 8. CC-2a 마무리 — 빌드·문서·sensor + 원가 게이트

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C8a | 전체 빌드 — `npm run build` 무에러 | [MUST] | 🟢 | 3분 | C7d | 종료코드 0 |
| C8b | 전체 테스트 — `npm test` 통과, server 커버리지 **≥60%** 유지 | [MUST] | 🟢 | 5분 | C8a | jest 전체 PASS, 커버리지 게이트 통과 |
| C8c | `shared-contracts.md` §30 CreditOverhaul 갱신 — `PaymentRepositoryPort.completePaymentWithPoints` 신설 + `CREDIT_PRODUCTS` 신 4종 + 변경 이력 1줄 박제. ⚠️ §30이 인터페이스 정본 → 미갱신 시 다른 agent 통합 단계 깨짐 | [MUST] | 🟡 | 5분 | C8b | `.claude/scripts/sensor-shared-contracts.sh` silent |
| C8d | `grimoire-server/TECH_STATUS.md` + `docs/data-model.md`/`SCHEMA.md`(컬럼 의미 변경 시) + `docs/api-contract.md`(`GET /payments/products` 4종 변경) 갱신 — CC-2a 완료(충전 적립 연동 + C-6 해소 + 디노미 4종) 박제. `docs-sync` drift sensor 확인 | [MUST] | 🟡 | 5분 | C8c | drift sensor silent |
| C8e | sensor 일괄 — `sensor-shared-contracts` / `-instruction-degradation` / `-agent-priority-labels` / `-agent-interaction` + `sensor-credit-source-accounting.sh`·`sensor-credit-denomination.sh`(존재 시) 실행 | [SHOULD] | 🟢 | 3분 | C8d | sensor 전부 silent/PASS |

> **원가 게이트 판정 (C8 단계 박제)**: `CREDIT_PRODUCTS` 신 4종은 ai-cost-table.md §2 + §7 검증표가 cost-accountant 승인 `786b0f3`으로 이미 §0 PASS 판정(입문 실효 순단가 ₩0.09856 = §0 최악 기준, 베스트 ₩0.09976 ≥ 기준). **CC-2a가 §6 게이트에서 사용자가 §2 값을 그대로 채택하면 새 마진 검증 불요** — 기존 승인 코드 소비. 사용자가 충전액/보너스율을 변경한 경우에만 cost-accountant 재검증 필수(§6-2 표). CC-2a는 신규 AI 기능 추가 0건 — 기존 충전 경로의 신 시스템 재배선 + 디노미 환산이므로, §2 값 채택 시 원가 게이트는 "기존 승인 확인"으로 통과.

---

## 9. rollback 단위

- 각 sub-task는 git commit 단위 — C3·C4·C5·C7 별 commit 권장. 실패 시 해당 commit revert.
- C3c(`completePaymentWithPoints` 신설)는 `completePaymentAtomically`를 **즉시 제거하지 않음**(deprecated 주석만) → C4a 교체 실패 시 구 메서드로 즉시 원복 가능. CC-2b 종료 후 별도 정리.
- 코드 변경만(🟡/🔴 C3d) — **DB 스키마 비변경**(`completePaymentWithPoints`는 기존 `credit_ledgers`/`authors`/`payments` 테이블만 사용, 신규 컬럼 0건). PAY-S1과 달리 백업 불요. tsc/jest 실패 = 즉시 해당 commit 단위 롤백.
- C5b(`CREDIT_PRODUCTS` 개편)는 `polar.adapter` 4곳 참조 전파 동반 — revert 시 `polar.adapter` 정합도 함께 원복.
- ⚠️ C3d 트랜잭션 로직은 🔴 — 운영 배포 전 통합 spec(C7) 전건 PASS가 게이트. dev 배포는 CC-4(마이그레이션 sprint) 또는 별도 — CC-2a 자체는 코드 머지까지.

---

## 10. 핸드오프

### 10-1. 담당 + 산출물 위치

| 영역 | 담당 | 산출물 위치 | 다음 단계 진입 조건 |
|---|---|---|---|
| §6 사용자 게이트 | **사용자** (planner 경유 확인) | 충전액·보너스율 채택 여부 결정 | 채택 = C5a 진행 / 변경 = cost-accountant 재검증 |
| CC-2a S0 | grimoire-server | §10 미확인 + 충전 경로 현행 해소 결과 박제 (progress.md) | C1a~C1e 완료 = 트랜잭션 설계 결정 진입 |
| CC-2a C2a 설계 결정 | grimoire-server (또는 planner 재확인) | 본 계획 §2-2 권고案 채택 박제 | C2a 완료 = 구현 진입 |
| CC-2a C3~C8 구현 | grimoire-server (Generator) | Repository/usecase/config 코드 + spec + progress.md 갱신 | C8 마무리 |
| CC-2a 채점 | grimoire-qa (Evaluator) | `QA_REPORT.md` — sprint-progress 통과율 박제 | — |

### 10-2. Initializer 산출물 (planner)

- 본 계획 = `.claude/state/sprint-cc2a-charge-wiring-plan-draft.md`.
- **`reports/sprint-cc2a-charge-wiring-progress.md` 생성 권고** — 본 계획의 sub-task 28건 체크리스트 + 완료 기준을 progress.md로 박제 → server(Generator)가 Read 후 갱신, qa(Evaluator)가 채점 (책 Ch 16 Initializer→Generator→Evaluator 패턴).
- server / qa에게 본 계획 + progress.md Read 후 작업 핸드오프.

### 10-3. 원가 영향 플래그

- CC-2a는 **신규 AI 기능 추가 0건** — 기존 충전 경로의 신 시스템 재배선 + 디노미 환산. cost-accountant 마진 검증 게이트는 **조건부**: §6에서 사용자가 ai-cost-table.md §2 신 4종을 그대로 채택하면 **불요**(`786b0f3` 기존 승인 소비), 충전액/보너스율 변경 시 **필수**.
- 시각 검수(visual-canon-keeper) **불요** — CC-2a는 server 도메인 한정, UI 변경 0건. 단 `GET /payments/products`가 3종→4종으로 바뀌면 web 충전 패키지 UI가 4종을 받게 됨 → **web 핸드오프 1건**(별도 sprint, shared-contracts §30 변경 이력에 "`CREDIT_PRODUCTS` 4종 갱신 시 패키지 자동 반영" 후속 명시되어 있음).

### 10-4. CC-2b로 이월되는 범위 (CC-2a 범위 외 — 명시)

| 항목 | 진단 근거 | CC-2b 이월 사유 |
|---|---|---|
| T4 응원 선물 적립 | §1-B — `CreditLedgerPort.transfer` 단일 `$transaction`(sender FOR UPDATE + receiver FOR UPDATE, id 정렬 lock) 신설 / `grantGift` receiver 측 연동 / 선물 단위 web 계약 재합의 | CC-2a가 확립한 案 1 패턴(도메인 헬퍼 + Repository 단일 $tx) 재사용 — 패턴 확립 후 별도 상세화 |
| T7 환불 크레딧 환수 | §1-C — 환불 신 경로 + **이중 외상 통합**(`RefundLog.deficitCredits` ↔ `Author.deficitPoints` 하나로) / `RefundLog.credits`·`deficitCredits` pt 단위 정합 | 이중 외상 통합은 CC-2a 충전 deficit 상계가 안정화된 뒤라야 설계 가능 |
| `Payment.credits` 컬럼 물리 rename | MEDIUM-4 — `credits`→`points` 컬럼명 변경(스키마·마이그레이션 동반) | CC-2a는 컬럼 의미 재해석 + 코드 정합만. 물리 rename은 CC-4 마이그레이션 sprint |
| `completePaymentAtomically` 구 메서드 제거 | C3c deprecated 처리 | CC-2b(선물·환불)까지 회귀 안전 확보 후 일괄 제거 |

> CC-2a 완료 ≠ CRITICAL-2 전체 해소 — 충전(T3)만 해소. 선물(T4)·환불(T7)은 CC-2b. 그리고 CC-1+CC-2(a+b)+CC-3 전부 완결 후라야 CC-4(V Phase 마이그레이션 적용) 가능 (CREDIT_CORE_DIAGNOSIS §8 가장 중요한 결론).

---

## 11. 종합 게이트 — CC-2a 완료 선언 조건

### CC-2a 완료 선언

- **§6 사용자 게이트**: 충전액·보너스율 채택 결정 완료 (변경 시 cost-accountant 재검증 통과).
- **S0 게이트**: C1a~C1e [MUST] 5건 완료 (§10 미확인 + 충전 경로 현행 해소).
- **C2a 설계 결정**: §2-2 案 1 권고 채택 명문화.
- **본 작업 [MUST]**: C3a~d / C4a~d / C5a~e / C7a~d / C8a~d — 전부 통과.
- **검증 게이트** (writing-plans Gate 1·2·3):
  - Gate 1 (빌드): C8a `npm run build` 무에러.
  - Gate 2 (테스트): C8b `npm test` 전체 PASS + 커버리지 ≥60%. **통합 spec(C7)이 핵심** — 충전 webhook이 `CreditLedger`에 `source='charged'` earn row를 박고 deficit를 상계함을 통합 테스트로 증명.
  - Gate 3 (문서/sensor): C8c~e — shared-contracts §30 + TECH_STATUS + data-model/api-contract 갱신 + sensor silent.
- **[SHOULD]** C8e(sensor 일괄) 실패는 회고만.
- **CRITICAL-2 충전 해소 증명**: `grep -rn "completePaymentWithPoints" src/application/payment` 호출처 ≥1건 + 구 `completePaymentAtomically` 충전 success 분기 호출 0건 + 통합 spec C7b PASS = "충전 결제 적립 신 시스템 연동 완료" 선언.
- **C-6 해소 증명**: 통합 spec C7d PASS = "충전 시 deficit 상계 작동 → 충전해도 채팅 영구 차단 결함 소멸" 선언.

### CC-2a 미해소 잔존 (범위 외 — 명시)

- T4 선물 / T7 환불 = **CC-2b 범위** — CC-2a 완료 후에도 선물·환불 적립/환수는 구 경로 잔존.
- `Payment.credits` 컬럼 물리 rename / `completePaymentAtomically` 구 메서드 제거 = CC-2b 종료 후 또는 CC-4.
- CC-2a 완료 ≠ V Phase 마이그레이션 적용 가능 — CC-4는 CC-1·CC-2(a+b)·CC-3 전부 완결 후.

---

## 12. 미확인 / 추정 금지 명시

| 항목 | 상태 | 해소 시점 |
|---|---|---|
| `payment.usecase` 충전 success 분기 현행 코드 | **부분 확인** — 본 계획 작성 중 `:300~395` Read(구 `completePaymentAtomically` 호출 + auditLog 박제 확인). CC-1 머지 후 변동 가능성은 S0가 재실측 | C1a |
| `completePaymentAtomically` 트랜잭션 본문 | **확인** — 본 계획 작성 중 Read($transaction 3건: Payment update + Author.credits increment + CreditLog create). S0가 현행 재확인 | C1b |
| `grantCharge`/`settleDeficit`/`earn` 시그니처 | **확인** — `grantCharge(authorId, totalPoints, relatedId?)` → `{settledDeficit, chargedPoints}`, 내부 `settleDeficit`+`earn` 2 트랜잭션. S0가 현행 재확인 | C1c |
| `CREDIT_PRODUCTS` 현행 | **확인** — 구 3종(credit-5/20/50, `credits` Int=수량). 신 4종은 ai-cost-table.md §2 + S Phase §8-5 | C1d |
| `Payment.credits` 컬럼 현행 의미 | **부분 확인** — 진단 MEDIUM-4 "패키지 수량 의미". `schema.prisma` 직접 Read는 S0(C1e) | C1e |
| `CREDIT_PRODUCTS` 충전액·보너스율 최종 확정 | **사용자 결정 대기** — ai-cost-table.md §11이 "가정" 표기. §0 마진은 §2/§7이 `786b0f3` 승인으로 PASS 검증 완료 | §6 게이트 (CC-2a 착수 전 사용자 확인) |
| `CreditLog` 박제 병행 여부 (C3d) | **HIGH-3 종속** — CC-1이 적립을 `CreditLedger`로 이행 완료했으면 충전도 `CreditLog` 박제 제거. CC-1 종료 상태 기준 C1b/C3d에서 분기 | C1b → C3d |
| sub-task 시간 추산 | 상대 추산 — 실측 아님. 본 계획은 분해 단위, 실제 시간은 server 실행 시 확정 | — |

> 본 계획은 코드 변경 0건 — 순수 계획 수립. 모든 file:line은 CREDIT_CORE_DIAGNOSIS 진단 리포트 + 본 계획 작성 중 실제 Read(`payment.usecase`/`prisma-payment.repository`/`grant-points.usecase`/`config.ts`/`shared-contracts.md §30`/`ai-cost-table.md`) 기반. 미확인은 §12에 명시 — 추정 0건.

---

## 13. 변경 이력

- 2026-05-19: 본 계획 신설. CC-2a(S0 5 + 트랜잭션 설계결정 1 + Repository 통합메서드 4 + payment.usecase 재배선 4 + CREDIT_PRODUCTS 디노미 4 + 통합 spec 4 + 마무리 5 = 28 sub-task) writing-plans 양식 분해. 트랜잭션 통합 권고 = 案 1(`PaymentRepositoryPort.completePaymentWithPoints` 단일 $transaction). C-6 = T3 충전 연동 흡수. 사용자 결정 게이트 1건(§6 충전액·보너스율). 코드 변경 0건 — 계획 수립 전용.
