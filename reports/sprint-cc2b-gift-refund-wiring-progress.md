# Sprint CC-2b — 선물·환불 결제 적립 연동 (progress)

> 생성: 2026-05-20 / grimoire-server (Generator) / 계획 정본: `.claude/state/sprint-cc2b-gift-refund-wiring-plan-draft.md`
> 진단 정본: `reports/CREDIT_CORE_DIAGNOSIS.md` §1-B(선물) / §1-C(환불) / §8
> 브랜치: `feature/cc2b-gift-refund-credit-wiring` (develop 분기, CC-2a 패턴)
> §6 사용자 게이트: **선물 3단계 = 1,000 / 3,000 / 5,000pt, body `amount` = pt 단위** (메인 결정 박제)

---

## S0 — 선행: 선물·환불 경로 현행 해소 (착수 게이트)

| # | sub-task | 상태 | 결과 |
|---|---|---|---|
| C1a | `credit.usecase.gift()` 현행 Read | ✅ | `:74-102` — 자기 선물 차단 + sender `findById` + `credits<amount` BadRequest + receiver `findById` 후 `creditRepo.giftTransfer(...)` 호출 |
| C1b | `prisma-credit.repository.giftTransfer` Read | ✅ | `:45-88` 단일 `$transaction` — 작은 id 먼저 `IN ORDER BY id FOR UPDATE` (신 transfer lock 순서 정본 패턴) + `creditLog.createMany` 2건 |
| C1c | `refund-payment.usecase` + `refundPaymentAtomically` Read | ✅ | usecase `:99-115` 호출. repository 11단계: payment 조회 → 비례(PAY-P2-1) → status 갱신 → `findUniqueOrThrow` → `actualDeducted/deficitCredits` → CAS `updateMany WHERE credits>=` (PAY-P3-A) → CreditLog 음수 → RefundLog |
| C1d | `RefundLog`/`Author` 스키마 Read | ✅ | `Author.credits [DEPRECATED]` + 4 출처 캐시 + `deficitPoints` (신 외상 단일화 대상). `RefundLog.credits Int`(실 환수) + `deficitCredits Int @default(0)`(구 외상) |
| C1e | CC-2a `completePaymentWithPoints` + `computeChargeLedgerEntries` Read | ✅ | 案 1 단일 `$transaction` 패턴 정본 — authors FOR UPDATE(5컬럼) + 도메인 헬퍼 추출 |
| C1f | `CreditLedgerPort` + `grantGift` + payment.usecase cancel 분기 Read | ✅ | port 5 메서드 + `grantGift` 호출처 0건 + payment.usecase `:433-476` cancel 분기 (refundPaymentUseCase.execute) |

**S0 게이트**: ✅ C1a~C1f 6건 완료 — 선물·환불 경로 현행 해소.

### C3a 헬퍼 판정 (사전)

**판정: 헬퍼 1건 추가 필요 (`computeRefundLedgerEntries`)** — `transfer`(C3)는 sender `planConsumption`(기존) + receiver 단순 가산만이라 헬퍼 0건. 환불(C6)은 비례·4 출처 환수·외상 분기가 복합 → CC-2a `computeChargeLedgerEntries` 패턴 정합 헬퍼 1건 추출.

---

## C2a — T4 선물 트랜잭션 설계 결정 (案 G1 확정)

| # | sub-task | 상태 | 결과 |
|---|---|---|---|
| C2a | 案 G1 — `CreditLedgerPort.transfer(senderId, receiverId, amount, relatedId?)` 단일 `$transaction` 메서드 신설. 작은 id 먼저 FOR UPDATE lock + sender `planConsumption` 4 출처 차감 + **deficit 금지**(잔액 부족 throw) + receiver `source='gift'` earn + `pointsGift` 가산 | ✅ | 메인 결정(작업 지시서) 박제. 헥사고날 정합 — `CreditLedgerPort`가 포인트 원장 내부 이동의 정확한 소유자 |

---

## C3 — `CreditLedgerPort.transfer` 신설 + 도메인 상수 박제

| # | sub-task | 상태 | 결과 |
|---|---|---|---|
| C3a | 도메인 상수 `GIFT_POINT_OPTIONS = [1000, 3000, 5000]` + `isGiftPointOption` 박제 | ✅ | `domain/model/gift-points.ts` 신설 + spec (3 it PASS) |
| C3b | 헬퍼 판정 — `transfer` 신규 헬퍼 0건 (`planConsumption` 재사용) | ✅ | S0 사전 판정 박제 |
| C3c | `CreditLedgerPort.transfer` 시그니처 추가 + `TransferResult` 인터페이스 | ✅ | tsc PASS |
| C3d | `prisma-credit-ledger.repository.transfer` 구현 | ✅ | 案 G1 본문 — 단일 `$transaction` (작은 id 먼저 FOR UPDATE + planConsumption + receiver gift earn) |
| C3e | `prisma-credit-ledger.repository.spec.ts` `transfer` 단위 검증 | ✅ | 6 it PASS — 정상/잔액부족/자기선물/비정수/0이하/4출처분산/미존재 |

---

## C4 — `credit.usecase.gift` 신 경로 재배선

| # | sub-task | 상태 | 결과 |
|---|---|---|---|
| C4a | `CreditUseCase`에 `CreditLedgerPort` 필수화 (Optional 잔존 + 미주입 throw) | ✅ | `gift` 진입 시 ledger 미주입 BadRequest |
| C4b | `gift()` 재배선 — `creditRepo.giftTransfer` → `ledger.transfer` | ✅ | 반환 `{senderSpentBySource, receiverGiftBalance}`. body `amount` = pt 단위 |
| C4c | `credit.usecase.spec.ts` 갱신 | ✅ | 7 it PASS — `ledger.transfer` mock 검증 + 구 `giftTransfer` 0건 + 자기/잔액부족/비정수 |
| C4d | **추가 — `social.usecase.giftCredits` 재배선** (S0 grep 발견) | ✅ | `social.usecase.giftCredits` 도 구 `creditRepo.giftTransfer` 호출 중이었음. CC-2b 신 경로(`ledger.transfer`)로 재배선 + `GIFT_POINT_OPTIONS` 검증 + 신 spec 6 it PASS. **application 레이어 `giftTransfer` 실 호출 0건** 달성 |

---

## C5a — T7 환불 신 경로 + 이중 외상 통합 설계 결정 (案 R1 확정)

| # | sub-task | 상태 | 결과 |
|---|---|---|---|
| C5a | 案 R1 — `PaymentRepositoryPort.refundPaymentWithPoints` 신설 (CC-2a 대칭). 비례·CAS 이식 + 이중 외상 통합 (`Author.deficitPoints` 단일화). `RefundLog.deficitCredits` 의미 재해석 — "이 환불 1건이 유발한 외상 pt 기여분" | ✅ | 메인 결정 박제 |

---

## C6 — `refundPaymentWithPoints` 신설 + 환불 경로 재배선

| # | sub-task | 상태 | 결과 |
|---|---|---|---|
| C6a | 도메인 헬퍼 `computeRefundLedgerEntries` + `REFUND_RECOVERY_ORDER` 추출 | ✅ | `credit-consumption-policy.ts` 신규 순수 함수. CC-2a `computeChargeLedgerEntries` 패턴 정합 |
| C6b | `credit-consumption-policy.spec.ts` 환불 헬퍼 단위 검증 | ✅ | 8 it PASS — 우선순위/잔액≥/charged부족 분산/잔액<환수/잔액0/환수0/음수/비정수 |
| C6c | `PaymentRepositoryPort.refundPaymentWithPoints` 시그니처 + `refundPaymentAtomically` @deprecated | ✅ | tsc PASS |
| C6d | `prisma-payment.repository.refundPaymentWithPoints` 구현 | ✅ | 단일 `$transaction` — authors FOR UPDATE + 비례 계산 + `computeRefundLedgerEntries` + `$executeRawUnsafe` CAS race 차단 + 4 출처 spend + 이중 외상 통합 + RefundLog |
| C6e | `payment.usecase` cancel 분기 + `refund-payment.usecase` 재배선 | ✅ | usecase 시그니처 `credits→refundPt`, 반환 4 필드 rename. payment.usecase `:438` refundPt 매핑. **구 `refundPaymentAtomically` application 호출 0건** |
| C6f | spec 갱신 — refund-payment.usecase.spec + payment.usecase.spec | ✅ | refund-payment.usecase.spec 새로 작성(13 it) + payment.usecase.spec 신 시그니처 정합 + prisma-payment.repository.spec `refundPaymentWithPoints` 단위 11 it 추가 |

---

## C7 — 통합 spec (CC-2b 근본 해결 + CRITICAL-2 종결 증명)

| # | sub-task | 상태 | 결과 |
|---|---|---|---|
| C7a | 통합 spec 파일 신설 — `credit-gift-refund-integration.spec.ts` | ✅ | 인메모리 `CreditStore` + `FakeCreditLedger`(도메인 헬퍼 실호출) + `FakePaymentRepository`(refundPaymentWithPoints 실 회계) |
| C7b | T4 선물 통합 케이스 (RED 재현) | ✅ | 4 it PASS — 1,000pt 선물 양측 row / free 우선 분산 차감 / 잔액부족 throw 트랜잭션 롤백 / 자기선물 throw. **RED 차단**: `creditRepo.giftTransfer` mock 이 throw — 구 경로 호출 시 즉시 FAIL |
| C7c | T7 환불 통합 케이스 (RED 재현) | ✅ | 4 it PASS — 전액 정상(charged 25k) / 잔액부족 deficit 가산(이중 외상) / 부분 환불 50% / 환수 우선순위 4 출처 분산. **RED 차단**: `refundPaymentAtomically` mock 이 throw |
| C7d | 이중 외상 통합 + CRITICAL-2 종결 통합 케이스 | ✅ | 2 it PASS — 환불 외상 15,000pt 발생 → 충전 25,000pt → `deficit_settle` row + Author.deficit=0(자동 회수) / CRITICAL-2 종결 통합(선물→충전→환불 1 사슬 전체 신 CreditLedger 흐름) |

**통합 spec 총 10 it 전건 PASS — CC-2b 근본 검증 완료**

---

## C8 — 마무리 + 게이트

| # | sub-task | 상태 | 결과 |
|---|---|---|---|
| C8a | `npm run build` | ✅ | 무에러 (`nest build` 종료코드 0) |
| C8b | `npm test` + 커버리지 ≥60% | ✅ | jest 74 suites / **1048 it 전건 PASS** (1012→1048, +36 순증). 커버리지 **61.11% (stmts) / 62.67% (lines)** — 게이트 ≥60% 충족 |
| C8c | `shared-contracts.md` §30 + §13 갱신 | ✅ | §30: `CreditLedgerPort.transfer` 시그니처 + `refundPaymentWithPoints` + `computeRefundLedgerEntries` + `GIFT_POINT_OPTIONS` 추가 + CC-2b 변경 이력 1줄. §13: CC-2b 의미 재해석 + 변경 이력 1줄. `sensor-shared-contracts` PASS |
| C8d | TECH_STATUS / data-model / SCHEMA / api-contract 갱신 + web 복사 | ✅ | TECH_STATUS: CC-2b 행 + 코멘트 1줄. data-model + SCHEMA: `refund_logs` 의미 재해석 주석(CC-2b) + 정책 4 출처 환수 + 이중 외상 통합. api-contract: `/credits/gift` body `amount`=pt 명시. web docs 2종 복사 완료 → `sensor-docs-sync` PASS |
| C8e | sensor 일괄 | ✅ | sensor-server 4/4 / shared-contracts 0 FAIL / credit-denomination 8 PASS / credit-source-accounting 10 PASS / docs-sync 9 PASS / instruction-degradation PASS / agent-priority-labels 7 PASS / agent-interaction PASS |
| C8f | regression 회귀 | (SHOULD) | regression-55/61 등 결제 회귀는 jest 1048 PASS 에 포함 (별도 eval 미실행) |

---

## 완료 게이트 결과 (계획 §11)

- **Gate 1 (빌드)**: ✅ `npm run build` 무에러.
- **Gate 2 (테스트)**: ✅ jest 1048 it 전건 PASS + 커버리지 61.11% (≥60%). 통합 spec 10 it PASS (C7b/C7c/C7d 전건 GREEN, RED 재현 차단 박제).
- **Gate 3 (문서/sensor)**: ✅ shared-contracts §30/§13 + TECH_STATUS + data-model/SCHEMA + api-contract 갱신, web 복사 완료, sensor 전건 PASS.

---

## CRITICAL-2 종결 증명 — 적립 8경로 신 시스템 이행 (계획 §11 종결 게이트)

| 경로 | sprint | 종결 증명 (grep 실측) |
|---|---|---|
| T1 가입 / T2 첫작품 | CC-1 | ✅ `GrantPointsUseCase` application 호출처 ≥2 (auth + work-management) |
| T5 관리자 지급 / T6 관리자 차감 | CC-1 | ✅ `grantManual` + `CreditLedgerPort.spend` (admin) |
| 테마 차감 | CC-1 | ✅ `ChargePointsUseCase.chargeTheme` 호출처 |
| T8 분석 환불 | CC-1 / I Phase | ✅ `refundAnalysis` 출처별 복원 |
| T3 충전 | CC-2a | ✅ `completePaymentWithPoints` application 호출처 2건 (`payment.usecase` + `payment-reconciliation.job`) / 구 `completePaymentAtomically` application 호출 **0건** |
| **T4 선물** | **CC-2b** | ✅ `ledger.transfer` 실 호출처 **2건** (`credit.usecase.ts:118` + `social.usecase.ts:152`) / 구 `creditRepo.giftTransfer` application 실 호출 **0건** (주석/문자열만 잔존) / 통합 spec C7b 4 it PASS |
| **T7 환불** | **CC-2b** | ✅ `refundPaymentWithPoints` 실 호출처 **1건** (`refund-payment.usecase.ts:146`) / 구 `refundPaymentAtomically` application 실 호출 **0건** / 통합 spec C7c 4 it PASS |

**CRITICAL-2 완전 종결 — 적립 8경로 (T1~T8) 전부 신 `CreditLedger` 원장 시스템으로 이행 완료.** 통합 spec C7d 가 이중 외상 통합(환불 외상 → 충전 자동 회수)을 박제 — 구 시스템의 `RefundLog.deficitCredits` 영구 외상이 신 단일 장부로 회수됨을 검증.

---

## 인터페이스 변경 박제 (shared-contracts §13/§30 정합)

- `CreditLedgerPort.transfer(senderId, receiverId, amount, relatedId?)` 신설 (案 G1)
- `PaymentRepositoryPort.refundPaymentWithPoints` 신설 (案 R1)
- `PaymentRepositoryPort.refundPaymentAtomically` `@deprecated` (회귀 안전망, CC-3/CC-4 후 제거)
- `RefundPaymentUseCase.execute` 입력 `credits → refundPt` / 반환 `{actualDeducted/deficitCredits/proportionalCredits → actualRefunded/deficitIncurred/proportionalPt}`
- `RefundPaymentUseCase` 생성자 `CreditLedgerPort` Optional 추가 (4 출처 beforeState 디노미 정합)
- `CreditUseCase.gift` 반환 `{senderCredits/receiverCredits → senderSpentBySource/receiverGiftBalance}`, body `amount` 단위 = **pt** (1,000/3,000/5,000 — `GIFT_POINT_OPTIONS` 정본)
- `SocialUseCase.giftCredits` `VALID_GIFT_AMOUNTS [1,3,5]` 제거 → `isGiftPointOption` 검증으로 교체 (디노미 정합)
- `domain/model/gift-points.ts` 신설 (`GIFT_POINT_OPTIONS` + `isGiftPointOption`)
- `domain/policy/credit-consumption-policy.ts` `computeRefundLedgerEntries` + `REFUND_RECOVERY_ORDER` 신설
- `RefundLog.credits`/`deficitCredits` 의미 재해석 — 물리 변경 0건, 컬럼 rename 은 CC-4 위임

---

## CC-3 핸드오프 박제 — `getGiftRanking`/`getLogs` 분열 (필수 후속)

CC-2b 가 선물 적립을 `CreditLedger`(`source='gift'` earn)로 이행. 결과로 **구 메서드**가 신·구 분열:
- `credit.usecase.getGiftRanking()` → `CreditLog reason='gift_received'` groupBy (구 CreditLog 집계)
- `credit.usecase.getLogs()` → `CreditLog.findMany` (구 CreditLog 조회)

새 선물은 `CreditLog` 박제 0건이므로 CC-2b 이후 선물부터는 두 메서드 결과에 누락. **CC-3 범위에서 `CreditLedger` 기반 재작성 필수** (진단 §5-B HIGH-3 정합). shared-contracts §30 변경 이력에 박제됨.

### CC-3/CC-4 이월

- 구 메서드 일괄 제거: `creditRepo.giftTransfer` / `refundPaymentAtomically` / `completePaymentAtomically`
- `Author.credits` Int DROP (모든 적립·차감 신 경로 확인 후)
- `RefundLog.deficitCredits`/`credits` 컬럼 물리 rename (CC-4 마이그레이션 동반)
- `getGiftRanking`/`getLogs` `CreditLedger` 기반 재작성 (HIGH-3)
- V Phase 마이그레이션 dev/prod apply (CC-1·CC-2·CC-3 완결 후 — 진단 §3)
