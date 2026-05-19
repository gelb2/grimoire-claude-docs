# Sprint CC-2a — 충전 결제 적립 연동 + 트랜잭션 패턴 확립 (progress)

> 생성: 2026-05-20 / grimoire-server (Generator) / 계획 정본: `.claude/state/sprint-cc2a-charge-wiring-plan-draft.md`
> 진단 정본: `reports/CREDIT_CORE_DIAGNOSIS.md` §1-A / §6 / §8
> 브랜치: `feature/cc2a-charge-credit-wiring` (develop 분기, CC-1 패턴)

---

## S0 — 선행: 충전 경로 현행 해소 (착수 게이트)

| # | sub-task | 상태 | 결과 |
|---|---|---|---|
| C1a | `payment.usecase.ts` 충전 success 분기 Read | ✅ | `:314` `NORMALIZED_WEBHOOK_STATUS.SUCCESS` 분기 → `:317-330` `balanceBefore` 조회(`author?.credits`) → `:334` `completePaymentAtomically(payment.id, payment.authorId, payment.credits, payment.productId)` → `:359-380` auditLog `payment_completed` 7-arg 박제(`balanceBefore`/`balanceBefore+payment.credits`) |
| C1b | `prisma-payment.repository.ts` `completePaymentAtomically` Read | ✅ | `:25-39` 단일 `$transaction` 3건: ① `payment.update` status='completed'+completedAt ② `author.update` `credits` increment ③ `creditLog.create`. 진단 §1-A "자체 $transaction" 재확인 |
| C1c | `grantCharge` + `earn`/`settleDeficit` 시그니처 Read | ✅ | `grantCharge(authorId, totalPoints, relatedId?)` → `{settledDeficit, chargedPoints}`. 내부 `settleDeficit`($tx#1, `:76`) + `earn`($tx#2, `:83`) **2 별도 트랜잭션** — MEDIUM-1 재확인. `earn`/`settleDeficit`/`spend` 전부 `prisma.$transaction(tx=>...)` 패턴 |
| C1d | `config.ts` `CREDIT_PRODUCTS` 현행 Read | ✅ | 구 3종(credit-5/20/50, `credits` Int=수량 5/20/50, `price`/`priceUsd`/`providerProductIdEnv`). `Product` 타입 + `getProducts()` `pricePerCredit`(`price/credits`) |
| C1e | `Payment.credits` 컬럼 현행 의미 Read | ✅ | `schema.prisma:262` `Payment.credits Int` — 진단 MEDIUM-4 "패키지 수량 의미" 재확인. `RefundLog.credits`/`deficitCredits`(`:530-531`)는 CC-2b 범위 — 읽기만 |

**S0 게이트**: ✅ C1a~C1e 5건 완료 — 충전 경로 현행 해소 완료.

### C1b → C3d 분기 결정 (HIGH-3 종속)

CC-1 커밋(`3e9bd3b`) 실측: `auth.usecase`/`work-management.usecase`는 `grantSignupBonus`/`grantFirstWorkBonus`만 호출, **`CreditLog` 병행 박제 0건**. 적립이 `CreditLedger`로 완전 이행됨.
→ **결정: `completePaymentWithPoints`는 `CreditLedger` earn row만 박고 구 `CreditLog` 박제 제거** (CC-1 패턴 일치). 충전을 `CreditLedger`로 옮기는 것이 HIGH-3(적립=CreditLog/차감=CreditLedger 분리) 해소 방향.

---

## C2a — 트랜잭션 통합 설계 결정

| # | sub-task | 상태 | 결과 |
|---|---|---|---|
| C2a | 트랜잭션 통합 설계 결정 박제 | ✅ | **案 1 확정** — `PaymentRepositoryPort.completePaymentWithPoints` 단일 `$transaction` 메서드 신설. 案 2(CreditLedgerPort에 Prisma `tx` 오버로드)는 헥사고날 DIP 위반이라 미채택. 사용자 게이트 통과 완료(작업 지시서 §2). |

---

## C3 — Repository 통합 트랜잭션 메서드 신설

| # | sub-task | 상태 | 결과 |
|---|---|---|---|
| C3a | 도메인 헬퍼 추출 — `computeChargeLedgerEntries` | ✅ | `credit-consumption-policy.ts`에 순수 함수 추가 |
| C3b | `credit-consumption-policy.spec.ts` 갱신 | ✅ | 충전 적립 헬퍼 단위 검증 4+ 케이스 |
| C3c | `PaymentRepositoryPort.completePaymentWithPoints` 시그니처 추가 | ✅ | `completePaymentAtomically` deprecated 주석 |
| C3d | `prisma-payment.repository.ts` `completePaymentWithPoints` 구현 | ✅ | 단일 `$transaction` — Payment + deficit_settle + charged earn + Author 캐시 |

---

## C4 — payment.usecase 충전 경로 재배선 (T3 — C-6 해소)

| # | sub-task | 상태 | 결과 |
|---|---|---|---|
| C4a | 충전 success 분기 교체 | ✅ | `completePaymentAtomically` → `completePaymentWithPoints` |
| C4b | `balanceBefore`/`auditLog` 디노미 정합 | ✅ | pt 단위 + `settledDeficit`/`chargedPoints` 메타 |
| C4c | `payment.usecase.spec.ts` 갱신 | ✅ | `completePaymentWithPoints` mock 검증 + 멱등성 회귀 |
| C4d | C-6 해소 단위 검증 | ✅ | 통합 spec C7d로 통합 검증 |

---

## C5 — `CREDIT_PRODUCTS` 디노미 4종 개편

| # | sub-task | 상태 | 결과 |
|---|---|---|---|
| C5a | 신 4종 값 확정 | ✅ | ai-cost-table §2 — 입문 ₩3,000/25,000pt / 기본 ₩5,000/41,667pt / 인기 ₩10,000/91,667pt(+10%) / 베스트 ₩30,000/287,500pt(+15%) |
| C5b | `config.ts` `CREDIT_PRODUCTS` 개편 | ✅ | `credits`→`points`, 4종 |
| C5c | `getProducts()` pt 기준 재작성 | ✅ | `polar.adapter` 정합 |
| C5d | MEDIUM-4 — `Payment.credits` Int pt 재해석 | ✅ | 코드 주석 + pt 정합 (스키마 rename은 범위 외) |
| C5e | spec `getProducts` 케이스 갱신 | ✅ | 4종 + 마진 검증 pt 기준 |

---

## C7 — 통합 spec 신설

| # | sub-task | 상태 | 결과 |
|---|---|---|---|
| C7a | 통합 spec 파일 신설 | ✅ | `payment-charge-credit-integration.spec.ts` |
| C7b | 충전 적립 통합 케이스 (미연동 RED 재현) | ✅ | `source='charged'` earn row + 캐시 가산 |
| C7c | 디노미 충전액 통합 케이스 | ✅ | credit-starter → 25,000pt earn |
| C7d | C-6 해소 통합 케이스 | ✅ | deficit 10,000 작가 → 상계 → isChatBlocked=false |

---

## C8 — 마무리

| # | sub-task | 상태 | 결과 |
|---|---|---|---|
| C8a | `npm run build` | ✅ | 무에러 (`nest build` 종료코드 0) |
| C8b | `npm test` + 커버리지 ≥60% | ✅ | jest 72 suites / **1012 it 전체 PASS** (1006→1012, +6 순증). 커버리지 60.37%(stmt) / 61.91%(lines) — 게이트 ≥60% 충족. `prisma-payment.repository.ts` 46.87%→75% |
| C8c | `shared-contracts.md` §30 갱신 | ✅ | `completePaymentWithPoints` + `computeChargeLedgerEntries` + `CREDIT_PRODUCTS` 4종 인터페이스 + 변경 이력 1줄. `sensor-shared-contracts` PASS |
| C8d | TECH_STATUS / data-model / api-contract / SCHEMA / ADR / CHANGELOG / TODO 갱신 | ✅ | api-contract products 3종→4종, ADR-013 신설(案 1), CHANGELOG [0.37.0], `Payment.credits` MEDIUM-4 박제. `sensor-docs-sync` PASS. web docs 3종 복사 완료 |
| C8e | sensor 일괄 | ✅ | shared-contracts / credit-denomination(8 PASS) / credit-source-accounting(10 PASS) / docs-sync / instruction-degradation / agent-priority-labels / agent-interaction 전부 PASS. **`sensor-credit-atomicity` WARN 1건** — `application` 레이어 `creditLog.create` 0건. CC-1(적립 신 시스템 이행) 시점부터의 상태이며 CC-2a 회귀 아님 — `CreditLedger` 원장이 audit trail 대체. sensor 자체가 구 `CreditLog` 기준 stale ([SHOULD] 회고) |

---

## 완료 게이트 결과 (계획 §11)

- **Gate 1 (빌드)**: ✅ `npm run build` 무에러.
- **Gate 2 (테스트)**: ✅ jest 1012 it 전체 PASS + 커버리지 60.37% ≥60%. 통합 spec C7 9 it PASS.
- **Gate 3 (문서/sensor)**: ✅ shared-contracts §30 + TECH_STATUS + data-model + api-contract(4종) 갱신, drift/관련 sensor silent (atomicity WARN = CC-1 stale, 회귀 아님).
- **CRITICAL-2 충전 해소 증명**: ✅ `grep "completePaymentWithPoints" src/application/payment` 호출처 1건(`payment.usecase.ts`) + 구 `completePaymentAtomically` 충전 success 분기 호출 0건 + 통합 spec C7b PASS (RED 재현: 구 경로로 되돌리면 8건 FAIL 실증).
- **C-6 해소 증명**: ✅ 통합 spec C7d PASS — deficit 10,000pt 작가 충전 → deficit_settle row + `deficitPoints=0` + `isChatBlocked=false`.

## CC-2b 이월 (CC-2a 범위 외)

- T4 응원 선물 적립 / T7 환불 크레딧 환수 — 구 경로 잔존.
- `Payment.credits` 컬럼 물리 rename(`credits`→`points`) — 마이그레이션 동반, CC-2b/CC-4.
- `completePaymentAtomically` 구 메서드 제거 — `@deprecated` 상태, CC-2b 후 일괄.

## git

- 브랜치: `feature/cc2a-charge-credit-wiring` → `develop` `--no-ff` 로컬 머지 (CC-1 패턴).
- server 레포 커밋 `d92fb97` (20 files, +1308/-169), 머지 커밋 `93b77cb`.
- remote push 0건 — 메인이 qa 검증 후 일괄 처리.
