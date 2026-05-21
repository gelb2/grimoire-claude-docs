# 작업 계획: CC-4 Phase 2 — `Payment.credits` → `points` 컬럼 물리 rename + RefundLog 컬럼 의미 박제 (writing-plans)

> 작성: 2026-05-21 / grimoire-planner (Initializer 패턴) / **계획 수립 전용 — 코드 변경 0건**
> 근거 정본: `reports/CREDIT_CORE_DIAGNOSIS.md` MEDIUM-4 + §2-3 폐기 의존 그래프 + `reports/sprint-cc4-postcleanup-phase1-progress.md` §1 S0c (Phase 2 입력값) + §7 Phase 2 이월 항목
>           + `.claude/state/sprint-cc4-postcleanup-plan-draft.md` §4 Phase 2 골격(P2a~P2g) — 본 계획이 상세화
>           + `.claude/state/sprint-cc{1-pay-s1,cc2a-charge-wiring,cc2b-gift-refund-wiring,cc3-rollover-source-ledger}-plan-draft.md` — 동일 섹션 구조·포맷
>           + `.claude/shared-contracts.md` §13 RefundPaymentAtomically(line 2380~) / §30 CreditOverhaul(line 2391~)
>           + `reports/sprint-cc4-postcleanup-phase1-progress.md` (CC-4 Phase 1 종결 박제 — 본 sprint 진입의 정본 입력)
> 적용 양식: `.claude/skills/writing-plans/SKILL.md` (2~5분 sub-task / [MUST]·[SHOULD]·[NICE] / 위험도 🔴🟡🟢 / 의존 / rollback / 검증 게이트)
> 구조 정본: CC-1·CC-2a·CC-2b·CC-3·CC-4 Phase 1 계획과 동일 섹션 구조·포맷.
> 범위: **CC-4 Phase 2만** — ① `Payment.credits` Int → `points` Int 물리 rename (ALTER TABLE RENAME COLUMN 1건). ② 코드 모든 참조 `Payment.credits` → `Payment.points` 일괄 변경. ③ `RefundLog.credits`/`RefundLog.deficitCredits` 컬럼 처리 결정(권고 = 보존 + 의미 박제 강화). ④ 마이그레이션 dev/prod apply + 사후 검증. **Phase 3(`Author.credits` DROP + `CreditLog` 폐기) 범위 외** — 별도 sprint(Phase 2 머지 + ≥1 sprint 후, Cursor 반면교사). **HIGH-1 案 B 범위 외** — Case C(별도 sprint, CC-4 범위 외) 사용자 결정(2026-05-21) 박제.

---

## 0. 진행 순서 + 의존 개요

```
CC-1 (적립 비결제 — 완료·qa검증)        ──선행 완료──┐
CC-2a (충전 결제 — 완료·qa검증)         ──선행 완료──┤
CC-2b (선물·환불 결제 — 완료·qa검증)    ──선행 완료──┤
CC-3 (이월 + 원장 단일화 — 완료·qa검증) ──선행 완료──┤
V Phase 마이그레이션 dev/prod apply ──선행 완료(5/21)┤
CC-4 Phase 1 (구 메서드 제거 + admin/discovery 분열 해소 — 완료·qa검증·push develop `1760e96`, 5/21) ──선행 완료──┤
                                                       │
                                                       ↓
                                  CC-4 Phase 2 (Payment.credits 물리 rename + RefundLog 처리)
                                  ├─ S0: 사용처 grep 현행 재실측 (Phase 1 진행 박제 5/21 기준)
                                  ├─ 결정: RefundLog 처리 (권고 = 보존, §2 결정 게이트)
                                  ├─ 마이그레이션 SQL 작성 + Prisma schema 갱신
                                  ├─ 코드 일괄 rename (~20곳, payment.usecase / repository / spec)
                                  ├─ 사용자 키워드 게이트(2026-05-21 통과: "크레딧개편 Phase 2 prod migration + 배포 진행")
                                  ├─ dev migration apply + 사후 검증 SQL
                                  └─ prod migration apply (코드+마이그레이션 단일 deploy 묶음) + 사후 검증
                                                       │
                                                       ↓
                                  Phase 3 (Author.credits DROP + CreditLog 폐기) — 별도 sprint, ≥1 sprint 유예 후
```

- **CC-1·CC-2a·CC-2b·CC-3·CC-4 Phase 1 완전 종결** — 적립 8경로(T1~T8) 전부 신 `CreditLedger` 이행 + 구 메서드(`CreditUseCase.grant`/`.deduct`/`.getBalance` + `CreditRepositoryPort.adjustCredits`/`giftTransfer`/`sumNegativeAmounts` + `PaymentRepositoryPort.completePaymentAtomically`/`refundPaymentAtomically`) 시그니처 + 본문 제거 + admin·discovery 신·구 분열 해소. CC-4 Phase 1 progress (`reports/sprint-cc4-postcleanup-phase1-progress.md`)의 §7(Phase 2 이월 항목) — 본 sprint 진입의 정본 입력.
- **S0c 박제(Phase 1 progress 진행)**: `Payment.credits` Int 의미는 이미 CC-2a 박제로 "패키지 수량"→"pt 단위"로 재해석 완료 (코드 주석 + shared-contracts §30 박제). **본 Phase 2는 컬럼명 자체를 정합** — 의미 변경 0건.
- **사용자 키워드 게이트 통과 (2026-05-21 박제)**: "크레딧개편 Phase 2 prod migration + 배포 진행" — Phase 2 prod migration + 배포 사전 승인. Phase 3 키워드도 사전 명시 — 검증 PASS 시 Phase 3 연속 진행 가능.
- **HIGH-1 案 B = Case C 별도 sprint 이월 (사용자 결정 5/21 박제)** — Phase 2에서 미시행. `Author.plan` 정본 + `MembershipPlan.tier` 미러는 CC-3 案 A 양측 동기로 안정화 완료(ADR-014) — Phase 2와 무관.
- **S0 선행 게이트** — Phase 1 진행 박제(`sprint-cc4-postcleanup-phase1-progress.md` §1 S0c)에서 식별된 `Payment.credits`/`RefundLog.credits`/`deficitCredits` 사용처 + Phase 1 머지 후 변동 가능성 → S0 sub-task에서 grep 재실측으로 해소한 뒤 본 작업 진입.

### 0-1. 예상 총 시간

- CC-4 Phase 2 전체: **규모 S~M** — sub-task 합산 ~3.5~5h (rename은 의미 변경이 아닌 컬럼명 정합이라 회귀 위험 작음).
- sub-task 총 **18개** (S0 4 + 마이그레이션 SQL 작성 3 + Prisma schema + 코드 일괄 rename 5 + RefundLog 처리 2 + 마이그레이션 apply + 사후 검증 2 + 마무리 2 = 18).
- **분할 근거**: ≥30분 + **마이그레이션 + 코드 단일 deploy 묶음**(`payment.credits` 사용 코드가 ALTER 후 컬럼 부재로 깨짐 → 코드+마이그레이션 동시 배포 필수) + rename은 작은 변경이지만 ~20곳 코드 + spec 영향 + Prisma client 타입 갱신 + 사후 검증 SQL 필수 → 1줄 실수가 "Prisma client 타입 미반영으로 컴파일 깨짐" / "prod 배포 후 컬럼명 정합 불일치"로 직결 → sub-task 단위 검증 게이트 + git commit 단위 rollback.

---

## 1. S0 — 선행: Phase 1 진행 박제 + Payment.credits/RefundLog 사용처 현행 재실측 (착수 게이트)

> CC-4 Phase 1 진행 박제(`reports/sprint-cc4-postcleanup-phase1-progress.md` §1 S0c) + 본 계획 작성 중 grep으로 Phase 2 입력값을 식별했으나, Phase 1 머지 후 변동 가능성 + 누락 가능성 → S0가 **현행 재실측**.
> ⚠️ Phase 1 (커밋 `1760e96`, 2026-05-21 develop) 머지 후 코드가 추가 변경됐을 수 있음 → S0가 grep 박제로 변경 범위 확정.

### 1-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| S0a | `Payment.credits` / `payment.credits` 사용처 전수 grep 재실측 — `grep -rn "Payment\.credits\|payment\.credits" grimoire-server/src grimoire-server/prisma` 결과의 file:line 표 박제. 본 계획 작성 중 grep 결과(2026-05-21): ① `prisma/schema.prisma:266` 모델 정의 ② `domain/model/config.ts:40-41` 주석(MEDIUM-4 재해석) ③ `application/payment/payment.usecase.ts:199,351,357,404,431-432,438,444` 다수(prisma write + read + return) ④ `application/payment/payment-reconciliation.job.ts:201,206,218,225,255` ⑤ `application/payment/refund-payment.usecase.ts:55` 주석 + 124-125 `author.credits` (이건 Author 도메인 — Phase 3) ⑥ `application/payment/payment.usecase.spec.ts:428,491,509,525,539,568,643,673` 다수 ⑦ `adapter/outbound/persistence/prisma-payment.repository.ts:285-287` 주석. **본 Phase 2 일괄 변경 대상 = ① 모델 정의 + ② 주석 + ③·④ 코드 본문 + ⑥ spec + ⑦ 주석** (⑤ 124-125 author.credits 는 Phase 3 영역 — 본 sprint 미접촉). 호출처 파일 ~7~8 파일 + 변경 line ~25~30곳 추정 | [MUST] | 🟢 | 7분 | CC-4 Phase 1 머지 완료(5/21 `1760e96`) | `Payment.credits`/`payment.credits` 사용처 file:line 표 확정 (Phase 2 일괄 변경 범위 입력) |
| S0b | `RefundLog.credits` / `RefundLog.deficitCredits` 사용처 전수 grep 재실측 — `grep -rn "RefundLog\.credits\|deficitCredits\|deficit_credits" grimoire-server/src grimoire-server/prisma` 결과의 file:line 표 박제. 본 계획 작성 중 grep 결과(2026-05-21): ① `prisma/schema.prisma:535-536` 모델 정의 (`credits Int // 실제 환수 크레딧`/`deficitCredits Int @default(0) @map("deficit_credits") // 잔액 부족분 (외상)`) ② `domain/policy/credit-consumption-policy.ts:188,212` 주석(`RefundLog.deficitCredits` 의미 재해석) ③ `domain/port/outbound/payment-repository.port.ts:119,121` 주석(이중 외상 통합 박제) ④ `adapter/outbound/persistence/prisma-payment.repository.ts:223,369-376` 주석 + 코드(`deficitCredits: deficitIncurred` 박제) ⑤ `domain/port/outbound/email-service.port.ts:58` + `sms-service.port.ts:40` 인터페이스 주석(`deficitCredits` notification 필드) ⑥ `adapter/outbound/{email,sms}/{null,polar}.adapter.spec.ts` mock(`deficitCredits: 0` 등) ⑦ `application/payment/payment.usecase.ts:256,273,479` 반환 타입(`deficitCredits?: number`) + 응답 매핑 ⑧ `application/payment/payment.usecase.spec.ts:534-597` 통합 검증(`deficitCredits` 응답) ⑨ `application/credit/credit-gift-refund-integration.spec.ts:341,720-721,743,757,851` 통합 spec(이중 외상 통합 박제). **§2 결정 게이트 입력값 + §6 결정에 따라 rename 또는 보존** | [MUST] | 🟢 | 7분 | - | `RefundLog.credits`·`deficitCredits` 사용처 file:line 표 확정 (§2 결정 입력) |
| S0c | `Payment` 모델 + 마이그레이션 history grep — `grep -n "model Payment\|credits Int" grimoire-server/prisma/schema.prisma` + `ls grimoire-server/prisma/migrations/ | tail -3` (현재 가장 최근 마이그레이션 박제). 본 계획 작성 중 schema.prisma:266 `credits Int` (line 260~274) + 가장 최근 마이그레이션 = 2026-05-17 `credit_overhaul_i_phase` (V Phase 5/21 prod 적용 완료). Phase 2 마이그레이션은 새 timestamp(예: `20260521_payment_credits_rename_phase2`)로 추가. Prisma migration history와의 정합 + `@map("credits")` 추가 시 컬럼-필드 분리 가능성 (단 Postgres ALTER 권고 = 컬럼명 자체 rename) | [MUST] | 🟢 | 5분 | - | Payment 모델 정의 + 마이그레이션 history + 새 마이그레이션 timestamp 결정 |
| S0d | `dev DB row 수 + prod 트래픽 상태` 박제 — Phase 1 진행 박제(`sprint-cc4-postcleanup-phase1-progress.md`)는 코드 한정이라 DB 상태 미박제. `SELECT COUNT(*), SUM(credits), MIN(credits), MAX(credits) FROM payments`(dev/prod) 측정 권고 — 마이그레이션 시간 추정 + 사후 검증 SQL의 기준값 박제. prod 트래픽 ~0 가정(소수 작가 운영, 결제 빈도 ~일 단위)이라 ALTER 락은 즉시 끝남 추정 — 단 측정 없이 진행 금지(§0 추정 금지). dev 실측은 server agent가 sprint 진입 시 1회 (`make psql-dev` 류) | [MUST] | 🟢 | 5분 | S0c | dev/prod `payments` row 수 + sum 박제 (마이그레이션 시간 + 사후 검증 기준값 입력) |

**S0 게이트**: S0a~S0d [MUST] 4건 완료 = Phase 1 머지 후 현행 사용처 + DB 상태 박제 완료 → §2 결정 게이트 진입 허가. 미확인 잔존 시 본 작업 착수 금지.

> 진단 §10 미확인 항목 중 CC-4 Phase 2 직접 관련 = S0a(Payment.credits 사용처)·S0b(RefundLog 사용처). 나머지(`Author.credits` 잔존·`CreditLog` 사용처)는 Phase 3 영역.

---

## 2. RefundLog 컬럼 처리 결정 게이트 — 권고案 + 근거

> CC-4 Phase 1 진행 박제(`sprint-cc4-postcleanup-phase1-progress.md` §7 Phase 2 이월) — "`RefundLog.credits`·`deficitCredits` 컬럼 의미 박제 강화 (rename 은 명명 충돌 우려로 보존 권고)". 본 §2 = 그 권고를 근거 + 案 비교로 확정.

### 2-1. 결정 대상 (3 컬럼)

| 컬럼 | 현행 의미 | 의미 재해석 (CC-2b 박제) | 결정 대상 |
|---|---|---|---|
| `Payment.credits Int` | 구: "패키지 수량"(5/20/50) | 신: "충전 총 pt"(MEDIUM-4 — CC-2a) | (a) `points` 물리 rename / (b) 의미 재해석 유지 |
| `RefundLog.credits Int` | 구: "실제 환수 크레딧"(actualDeducted) | 신: "실 환수 pt"(actualRefunded) | (a) `recoveredPoints`/`refundedPoints` rename / (b) 보존 + 의미 박제 강화 |
| `RefundLog.deficitCredits Int` | 구: "잔액 부족분(외상)" | 신: "이 환불 1건이 유발한 외상 pt 기여분" — 감사 추적용, `Author.deficitPoints`와 의미 다름 (CC-2b §10-4 박제) | (a) `deficitPoints` rename / (b) 보존 + 의미 박제 강화 |

### 2-2. 案 비교 + 권고

| 案 | Payment | RefundLog.credits | RefundLog.deficitCredits | 회귀 위험 | 마이그레이션 규모 | 권고 |
|---|---|---|---|---|---|---|
| 案 X (전체 rename) | `points` | `recoveredPoints` | `deficitPoints` | 코드 영향 ~40~50곳 + email/sms notification payload 필드명 변경 + web 영향 검증 필요 | ALTER 3건 | ❌ 비권고 — 회귀 위험 ↑ + `Author.deficitPoints`와 명명 충돌 가능 |
| **案 Y (Payment만 rename, RefundLog 보존) — 권고** | `points` | (보존, 의미 박제 강화) | (보존, 의미 박제 강화) | 코드 영향 Payment 한정 ~25~30곳, RefundLog 영향 0 | ALTER 1건 | ✅ 권고 — Phase 1 progress 권고와 정합 |
| 案 Z (전부 보존, 의미 박제만) | (보존, 의미 박제 강화) | (보존, 의미 박제 강화) | (보존, 의미 박제 강화) | 코드 영향 0 (주석만) | ALTER 0건 | 차선 — Phase 2 본질(컬럼 정합) 미수행 |

**권고 — 案 Y (Payment만 rename, RefundLog 보존)**. 사유:

1. **Phase 1 progress 권고와 정합** — `sprint-cc4-postcleanup-phase1-progress.md` §7 Phase 2 이월 명시 — "rename 은 명명 충돌 우려로 보존 권고".
2. **명명 충돌 회피** — `RefundLog.deficitCredits`를 `deficitPoints`로 rename 시 `Author.deficitPoints`(외상 잔액 정본)와 의미 충돌. CC-2b가 박은 의미 재해석("이 환불 1건이 유발한 외상 pt 기여분" — 감사 추적용)을 컬럼명으로 표현 시 같은 이름 다른 의미 → 회계 혼선 위험. 보존 + 주석 강화가 안전.
3. **회귀 범위 최소화** — `RefundLog` rename은 prisma-payment.repository + email/sms adapter(`payment_refunded` notification payload `deficitCredits` 필드) + spec 다수에 영향 → 회귀 범위 ↑. **외부 노출 영향 없음** (RefundLog는 admin/audit 전용, web HTTP 미노출) — 보존해도 사용자 영향 0건.
4. **`Payment.credits` rename은 가독성 직결** — `Payment.credits Int = 패키지 수량`이라는 의미가 CC-2a에서 "충전 총 pt"로 재해석된 상태가 컬럼명에 미반영 → 신규 개발자 혼선 위험. 코드 주석은 임시 정합, **컬럼명 자체가 정본**. `payment.points`가 명확.
5. **`Payment.credits`는 HTTP 응답에 영향 0건** — `GET /payments/products` 응답은 이미 `points`(CC-2a, shared-contracts §30 line 2477) / `GET /payments/credits` 응답은 `bySource.charged`(CC-2b/CC-3) — `Payment.credits` 컬럼은 내부 DB 표현 한정. rename은 코드 내부 정합만 영향, web 영향 0.

> ⚠️ **메인 결정 = 案 Y 권고 채택**. 사용자 결정 추가 필요 없음 — Phase 1 progress 권고와 정합 + 사용자 키워드 게이트("크레딧개편 Phase 2 prod migration + 배포 진행")가 Phase 2 본질(Payment rename)을 사전 승인.

### 2-3. RefundLog 의미 박제 강화 (案 Y 채택 시 후속 sub-task)

案 Y 채택 시 RefundLog 컬럼은 보존하되 다음 박제를 강화:

- `schema.prisma:535-536` 주석을 더 명확하게 — `credits Int // [CC-2b 재해석] 실 환수 pt (actualRefunded), 단위 = 디노미 1:1,000 pt` / `deficitCredits Int // [CC-2b 재해석] 이 환불 1건이 유발한 외상 pt 기여분 (감사 추적용, Author.deficitPoints 와 의미 다름 — 외상 잔액 정본 X)`.
- `shared-contracts.md` §13 RefundPaymentAtomically(line 2380~) — RefundLog 컬럼 의미 재해석 명시(이미 CC-2b 박제, Phase 2 변경 이력 추가).
- `docs/data-model.md` RefundLog 섹션 — 컬럼 의미 박제(CC-2b §10-4 정합).

본 박제는 R1·R2 sub-task로 분해.

---

## 3. Phase 2 — Payment.credits 물리 rename + 마이그레이션 + 코드 일괄 변경

> 범위: ① 마이그레이션 SQL 작성(`ALTER TABLE payments RENAME COLUMN credits TO points`) ② Prisma schema 갱신(`Payment.credits Int` → `Payment.points Int`) ③ 코드 일괄 rename(~25~30곳, payment.usecase / payment-reconciliation.job / prisma-payment.repository / spec 다수) ④ RefundLog 의미 박제 강화 ⑤ 마이그레이션 dev/prod apply + 사후 검증.

### 3-1. 마이그레이션 SQL 작성 + Prisma schema 갱신 (sub-task 표)

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| M1a | Prisma 마이그레이션 SQL 작성 — `npx prisma migrate dev --name payment_credits_rename_phase2 --create-only` 로 빈 마이그레이션 생성 후 `ALTER TABLE "payments" RENAME COLUMN "credits" TO "points";` 1줄 추가. Postgres native ALTER — DDL 락 짧음(metadata-only, 무손실, 즉시). 마이그레이션 timestamp = sprint 진입 시점(예: `20260521_payment_credits_rename_phase2`). 본 sub-task는 `--create-only`라 DB apply 0건 — SQL 파일만 생성 | [MUST] | 🟡 | 5분 | S0 게이트 + §2 결정 (案 Y) | `prisma/migrations/20260521*payment_credits_rename_phase2/migration.sql` 파일 생성 + ALTER 1줄 정합 |
| M1b | Prisma schema 갱신 — `prisma/schema.prisma:266` `credits Int` → `points Int` 변경. `@map` 사용 여부 결정: (a) 컬럼명 자체 rename(`points Int @map("points")` 권고 — 명시적) / (b) `points Int` 단독 — Prisma 기본 매핑(`@@map("payments")` table 매핑은 그대로). 권고 = (b) `points Int` 단독 (Postgres 컬럼명 = Prisma 필드명 = `points` 일치, `@map` 불필요). schema.prisma 변경 후 `npx prisma generate` 로 Prisma client 타입 갱신 — 본 sub-task에서 client 타입까지 갱신 | [MUST] | 🟡 | 5분 | M1a | `schema.prisma:266` `points Int` + `prisma generate` 실행 + 생성된 `node_modules/.prisma/client/index.d.ts` 에 `Payment.points` 타입 박제 |
| M1c | 마이그레이션 안전성 사전 검증 — Postgres `ALTER TABLE RENAME COLUMN` 락 분석: ① **메타데이터 한정 락**(ACCESS EXCLUSIVE 잠깐, 데이터 미터치 — 무손실) ② **데이터 이동 0건**(컬럼명만 변경 — 즉시 완료) ③ **인덱스/제약 무영향**(payments 모델은 `@unique externalTransactionId`만, credits 컬럼은 인덱스 미부여 — schema.prisma:267) ④ FK 무영향(refundLogs 관계는 paymentId FK, credits 무관). **dev row 수 = S0d 박제값**(예: ~수십~수백 row) → 락 시간 ~밀리초. **prod 트래픽 ~0 가정**(소수 작가, 결제 빈도 일 단위) → 락 시간 영향 없음. **롤백 = `ALTER TABLE payments RENAME COLUMN points TO credits` 역방향** — 비파괴(반대 ALTER로 즉시 복원). pg_dump 백업 권고(prod migration 직전, 1분 이내) | [MUST] | 🟢 | 5분 | M1b | 마이그레이션 안전성 분석 박제 (락 시간 추정 + 롤백 단위 + 백업 정책) |

### 3-2. 코드 일괄 rename (sub-task 표)

> S0a 박제 기준 ~25~30곳 — payment.usecase + payment-reconciliation.job + prisma-payment.repository + spec 다수. `npx prisma generate` 후 TypeScript 컴파일러가 `payment.credits` 잔존을 자동 감지(Prisma client 타입에 `credits` 없음 → 컴파일 에러로 누락 방지).

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| R1a | `payment.usecase.ts` 일괄 변경 — `payment.credits` → `payment.points` (8건 추정 — L199 `credits: product.points` 저장 시점 + L351 `(payment.credits, ...)` totalPoints 인자 + L357 `payment.credits` 비례 환수 입력 + L404 `totalPoints: payment.credits` + L431-432 응답 매핑 + L438 주석 + L444 `refundPt: payment.credits`). `initiatePayment`(L199 `credits: product.points` 저장) → `payments.points: product.points` 의미 일관 (저장도 `points`). **주석 정리** — L199·L351·L438 의 `MEDIUM-4`/`CC-2a` 주석을 `Phase 2 rename 후 컬럼명 정합`으로 갱신 | [MUST] | 🟡 | 8분 | M1b | tsc PASS + `grep "payment\.credits" src/application/payment/payment.usecase.ts` 결과 0건 |
| R1b | `payment-reconciliation.job.ts` 일괄 변경 — `payment.credits` → `payment.points` (5건 — L201,206,218,225,255). Reconciliation cron이 충전 success 후 보정 호출 시 `payment.points` 전달 | [MUST] | 🟡 | 5분 | R1a | tsc PASS + `grep "payment\.credits" src/application/payment/payment-reconciliation.job.ts` 결과 0건 |
| R1c | `prisma-payment.repository.ts` 주석 + 코드 정리 — L285-287 주석(`payment.credits`/`MEDIUM-4` 의미 박제) 갱신: `payment.points`/`Phase 2 rename 후 컬럼명 정합`. 본문 코드는 Prisma client 타입 자동 변경(`credits`→`points`)으로 컴파일러가 강제 — 본 sub-task는 주석 갱신 중심 | [MUST] | 🟡 | 4분 | R1b | tsc PASS + 주석 박제 정합 |
| R1d | `payment.usecase.spec.ts` 일괄 변경 — `result.credits` → `result.points` (8건 — L428,491,509,525,539,568,643,673). 그러나 **응답 키 `credits` 는 외부 노출 응답이 아니라 내부 결과 객체** — `processNormalizedWebhook` 반환 `{ processed: true, credits: payment.credits }` (payment.usecase.ts:432) — Phase 2에서 응답 키도 `points`로 통일 vs 응답 키는 `credits` 유지(외부 호환). **권고 = 응답 키도 `points`로 통일** (내부 메서드 반환, HTTP 미노출). 단 spec assertion 도 `result.points` 로 일괄 변경 + `payment.usecase.ts:432` 반환 `{ processed: true, points: payment.points }` 변경 + L479 `return { processed: true, credits: 0, deficitCredits: deficitIncurred }` → `{ processed: true, points: 0, deficitCredits: deficitIncurred }` 변경 | [MUST] | 🟡 | 7분 | R1c | tsc PASS + `npm test payment.usecase.spec` PASS + `grep "\.credits" src/application/payment/payment.usecase.spec.ts` 결과 0건(주석 제외) |
| R1e | 잔존 사용처 grep 재검증 — `grep -rn "payment\.credits\|Payment\.credits" grimoire-server/src --include="*.ts"` 결과 = 주석 매치만(코드 본문 0건). 누락 시 본 sub-task에서 추가 수정. ⚠️ `Payment` 도메인 모델(`domain/model/payment.ts`)에 `credits` 필드가 있는지 별도 grep — 있으면 `points` rename. `prisma-payment.repository.ts` mapping 함수(`mapPrismaToPayment` 류)도 갱신 | [MUST] | 🟡 | 5분 | R1d | grep 코드 본문 0건 + tsc PASS + `npm test` 전체 PASS |

### 3-3. RefundLog 의미 박제 강화 (案 Y 후속 — sub-task 표)

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| R2a | `schema.prisma:535-536` 주석 강화 — `credits Int // [CC-2b 재해석 / Phase 2 보존] 실 환수 pt (actualRefunded), 단위 = 디노미 1:1,000 pt. Payment.points 와 단위 일관` / `deficitCredits Int @default(0) @map("deficit_credits") // [CC-2b 재해석 / Phase 2 보존] 이 환불 1건이 유발한 외상 pt 기여분 (감사 추적용 — Author.deficitPoints 와 의미 다름. 외상 잔액 정본은 Author.deficitPoints)`. **컬럼 자체는 변경 0건** (DDL 영향 없음) — schema 주석만 갱신 | [MUST] | 🟢 | 4분 | R1e | `schema.prisma:535-536` 주석 정합 + `prisma format` PASS |
| R2b | `shared-contracts.md` §13 + §30 RefundLog 컬럼 의미 박제 — §13 RefundPaymentAtomically(line 2380~) + §30 변경 이력 추가(`2026-05-21 #크레딧개편 CC-4 Phase 2 — Payment.credits → points rename + RefundLog 보존 + 의미 박제 강화`). ⚠️ §13/§30 인터페이스 정본 → 미갱신 시 다른 agent 통합 단계 깨짐 (책 Ch 16 충돌 2번 해결책) | [MUST] | 🟡 | 5분 | R2a | `.claude/scripts/sensor-shared-contracts.sh` silent |

### 3-4. 마이그레이션 apply + 사후 검증 + Phase 2 마무리 (sub-task 표)

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| F1a | dev 마이그레이션 apply — `npx prisma migrate deploy`(dev 환경, develop 브랜치 push 후 GitHub Actions 또는 `make deploy-dev`). 컨테이너 부팅 시 `docker-entrypoint.sh:11`이 `NODE_ENV=development` 확인 후 `migrate deploy` 자동 실행 — **코드 변경(Payment.points 사용)과 마이그레이션은 같은 deploy 묶음** (기존 코드 `Payment.credits` 는 마이그레이션 후 컬럼 부재로 깨짐, 신 코드 + 신 마이그레이션이 한 묶음으로 배포돼야 함). 사후 검증 SQL — `SELECT points FROM payments LIMIT 1`(컬럼 존재 확인) + `SELECT COUNT(*) FROM payments`(row 보존 확인 = S0d 박제값 일치) + `SELECT COUNT(*) FROM information_schema.columns WHERE table_name='payments' AND column_name='credits'`(구 컬럼 0건 확인) | [MUST] | 🔴 | 10분 | R2b + 빌드/테스트 PASS | dev migration apply 정합 + 사후 검증 SQL 3건 PASS |
| F1b | prod 마이그레이션 apply (사용자 키워드 게이트 통과 = 2026-05-21 사전 박제) — `develop → main` 머지 + `make deploy-prod` 또는 `RUN_MIGRATION=true` 컨테이너 부팅. **사용자 키워드** "크레딧개편 Phase 2 prod migration + 배포 진행" 이미 통과(2026-05-21) — 추가 승인 불요. **pg_dump 백업 직전 1회**(prod DB) + dev 박제 정합 확인 후 진행. 사후 검증 SQL — F1a와 동일 3건 + `SELECT COUNT(*), SUM(points), MIN(points), MAX(points) FROM payments` 비교(rename 전 sum/min/max 보존 = S0d prod 박제값 일치) | [MUST] | 🔴 | 12분 | F1a + dev 박제 정합 확인 | prod migration apply 정합 + 사후 검증 SQL 4건 PASS + pg_dump 백업 보존 |

### 3-5. 빌드 / 테스트 / 문서 / sensor (sub-task 표)

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| F2a | 전체 빌드 — `npm run build` 무에러 | [MUST] | 🟢 | 3분 | R1e | 종료코드 0 |
| F2b | 전체 테스트 — `npm test` 통과 + server 커버리지 **≥60%** 유지. **rename 회귀 spec**: `payment.usecase.spec` / `payment-reconciliation.job.spec`(존재 시) / `prisma-payment.repository.spec` 의 `Payment.points` 단위 검증 PASS. **rename은 의미 변경 아닌 컬럼명 정합** — 테스트 결과 jest 개수 변동 ~0 (assertion 키만 변경, 테스트 case 신설 0) | [MUST] | 🟢 | 5분 | F2a | jest 1063→1063 PASS (변동 0) + 커버리지 게이트 통과 |
| F2c | `shared-contracts.md` §13 + §30 변경 이력 + `Payment.points` 인터페이스 박제 — R2b가 §13 + §30 의미 박제 갱신, 본 sub-task는 변경 이력 1줄 추가(`2026-05-21 #크레딧개편 CC-4 Phase 2: Payment.credits → Payment.points 물리 rename (마이그레이션 1건, ALTER TABLE RENAME COLUMN). RefundLog.credits/deficitCredits 보존 + 의미 박제 강화. 案 Y 권고 채택 (사용자 결정 추가 불요 — Phase 1 progress 권고 정합). 코드 ~25~30곳 일괄 rename. jest 1063→1063 PASS, 커버리지 ≥60% 충족. `Payment.points` HTTP 응답 영향 0건 (CC-2a 이후 응답 키 이미 `points`/`pricePerPoint` 박제). 정본: `.claude/state/sprint-cc4-phase2-rename-plan-draft.md`. CC-4 Phase 3(`Author.credits` DROP + `CreditLog` 폐기) 이월 — 별도 sprint(Phase 2 머지 + ≥1 sprint 후, Cursor 반면교사).`) | [MUST] | 🟡 | 5분 | F2b | sensor-shared-contracts silent + 변경 이력 박제 |
| F2d | `grimoire-server/TECH_STATUS.md` + `docs/data-model.md`(Payment 모델 `credits Int` → `points Int` 박제 + RefundLog 컬럼 의미 박제) + `docs/api-contract.md`(`GET /payments/credits` 응답은 CC-3 박제와 동일 — 본 Phase 2는 내부 컬럼 한정, 응답 영향 0) + `SCHEMA.md` 갱신 — Phase 2 완료(Payment.points rename + RefundLog 보존) 박제. drift sensor silent | [MUST] | 🟡 | 6분 | F2c | drift sensor silent + docs 박제 정합 |
| F2e | sensor 일괄 — `sensor-shared-contracts` / `-instruction-degradation` / `-agent-priority-labels` / `-agent-interaction` + `sensor-credit-source-accounting.sh` / `-credit-overhaul-recalc.sh`(존재 시) 실행. CC-4 Phase 1과 동일 정합 | [SHOULD] | 🟢 | 3분 | F2d | sensor 전부 silent/PASS |

> **원가 게이트 판정 (F2 단계 박제)**: Phase 2는 **신규 AI 기능 추가 0건** — 컬럼 물리 rename 한정. AI 모델 호출 0건, `CREDIT_PRODUCTS` 무변경, 차감 N 무변경. §0 직결값을 건드리지 않음. **cost-accountant 마진 검증 게이트 불요** — CC-1·CC-2·CC-3·CC-4 Phase 1과 동일.

> **visual-canon-keeper 게이트 판정**: Phase 2는 **UI 변경 0건** — server 도메인 한정 + HTTP 응답 영향 0(CC-2a 이후 응답은 이미 `points`/`pricePerPoint`). visual-canon-keeper 검수 **불요**.

---

## 4. 마이그레이션-코드 배포 묶음 순서 권고

### 4-1. 단일 deploy 묶음 (필수)

코드 변경(`Payment.points` 사용)과 마이그레이션(`ALTER TABLE payments RENAME COLUMN credits TO points`)은 **반드시 같은 deploy에 묶여야 함**:

```
시점 t=0: prod 컨테이너 부팅 (기존 코드 + 기존 스키마, credits 컬럼 사용)
시점 t=1: develop → main 머지 + `make deploy-prod` 실행
시점 t=2: 신 컨테이너 빌드 (Payment.points 사용 코드 포함)
시점 t=3: 신 컨테이너 부팅 시 docker-entrypoint.sh:11 `NODE_ENV=production` + `RUN_MIGRATION=true` 확인 후 `npx prisma migrate deploy` 실행 → ALTER TABLE 1건 적용 (컬럼 rename 즉시)
시점 t=4: 마이그레이션 완료 후 신 코드(Payment.points 사용) 시작 — 정합 100%
```

**왜 단일 deploy인가?**:

- 시점 t=1 직후 ~ t=3 직전 (마이그레이션 적용 전): 신 컨테이너의 신 코드가 부팅 직후 `Payment.points` 조회 시도 → 구 스키마(`credits` 컬럼)에 `points` 컬럼 부재 → Prisma 에러 → 서비스 마비.
- **단일 deploy 묶음**(`make deploy-prod`이 컨테이너 부팅 → 마이그레이션 자동 적용 → 그 후 서비스 시작)으로 시점 t=2~t=3 구간 0초 — 즉시 정합.
- 컨테이너 부팅 시 `docker-entrypoint.sh:11`이 `RUN_MIGRATION=true` 확인 후 `migrate deploy` 자동 실행 → Nest.js 부팅 전에 마이그레이션 완료 → 서비스 시작 시 신 스키마 정합.

### 4-2. 롤백 시나리오

| 시나리오 | 롤백 단위 |
|---|---|
| 코드 변경 후 빌드 실패 (t=0 직후) | git revert (코드 변경만, 마이그레이션 미적용) |
| dev 마이그레이션 적용 실패 (F1a) | `ALTER TABLE payments RENAME COLUMN points TO credits` 역방향 실행 (Postgres 즉시) — pg_dump 복원 불요 |
| prod 마이그레이션 적용 실패 (F1b) | 1차 = 역방향 ALTER 즉시 / 2차 = pg_dump 복원(F1b 직전 백업) |
| 마이그레이션 성공 후 코드 회귀 (t=4 이후) | git revert + 역방향 ALTER + redeploy |

**롤백 안전성**: ALTER TABLE RENAME COLUMN은 **비파괴** — 컬럼 데이터 100% 보존, 메타데이터만 변경. 역방향 ALTER로 즉시 복원 가능. pg_dump 백업은 안전망(0.1% 만약의 사고용).

---

## 5. 사용자 결정 게이트 요약 — 추가 결정 불요

본 Phase 2의 사용자 결정 게이트는 **0건**:

| 게이트 | 결정 대상 | 결과 |
|---|---|---|
| §2 RefundLog 처리 | 案 X/Y/Z 중 선택 | **권고 案 Y 채택** — Phase 1 progress 권고와 정합, 사용자 추가 결정 불요 |
| Prod migration | 사용자 키워드 게이트 | **통과 (2026-05-21)** — "크레딧개편 Phase 2 prod migration + 배포 진행" 사전 박제 |
| HIGH-1 案 B | Phase 2 포함 여부 | **Case C (별도 sprint, CC-4 범위 외) 사용자 결정 5/21 박제** — Phase 2에서 미시행 |

> 사용자 결정 추가 필요 없음 — 모든 결정 사전 박제 완료. 본 Phase 2는 즉시 진행 가능.

---

## 6. cost-accountant / visual-canon-keeper 게이트

### 6-1. cost-accountant 게이트 — **불요**

CC-4 Phase 2는 **신규 AI 기능 추가 0건**. 컬럼 물리 rename + 코드 일괄 변경 + 문서 박제 한정. AI 모델 호출 0건, `CREDIT_PRODUCTS` 무변경, 차감 N 무변경. §0 직결값을 건드리지 않음 — CC-1·CC-2·CC-3·CC-4 Phase 1과 동일 판정.

### 6-2. visual-canon-keeper 게이트 — **불요**

Phase 2는 **server 도메인 한정** — UI 변경 0건. 시각 정본(사슴악마) 영향 0건. **HTTP 응답 영향도 0건** (CC-2a 이후 응답은 이미 `points`/`pricePerPoint` 박제, 본 Phase 2는 내부 컬럼명 정합 한정).

---

## 7. 핸드오프

### 7-1. 담당 + 산출물 위치

| 영역 | 담당 | 산출물 위치 | 다음 단계 진입 조건 |
|---|---|---|---|
| CC-4 Phase 2 S0 | grimoire-server | `Payment.credits`/`RefundLog` 사용처 + dev/prod DB 상태 박제 (progress.md) | S0a~S0d 완료 = Phase 2 구현 진입 |
| CC-4 Phase 2 구현 (M1·R1·R2·F1·F2) | grimoire-server (Generator) | Prisma schema + migration + 코드 일괄 rename + spec + docs + progress.md 갱신 | F2e 마무리 (sensor silent) |
| dev/prod migration apply | grimoire-server + 사용자(키워드 게이트 통과 박제) | dev `make deploy-dev` + prod `make deploy-prod` | dev 사후 검증 PASS → prod 진행 |
| Phase 2 채점 | grimoire-qa (Evaluator) | `QA_REPORT.md` — sprint-progress 통과율 박제 + Payment.points 정합 검증 + RefundLog 의미 박제 검증 | Phase 2 머지 |
| Phase 3 (별도 sprint) | 착수 직전 상세화 | Phase 2 머지 + 운영 박제 ≥1 sprint 후 |
| HIGH-1 案 B 별도 sprint (Case C — 사용자 결정 박제) | grimoire-server / planner | 별도 sprint(예: `HIGH-1-CASE-B`) — CC-5와 병렬 또는 후속 | Phase 2 후 또는 병렬 |

### 7-2. Initializer 산출물 (planner)

- 본 계획 = `.claude/state/sprint-cc4-phase2-rename-plan-draft.md`.
- **`reports/sprint-cc4-phase2-rename-progress.md` 생성 권고** — Phase 2 sub-task 18건 체크리스트 + 완료 기준 + **Payment.points rename 정합 박제 항목**(grep 0건 / migration apply 정합 / 사후 검증 SQL PASS)을 progress.md로 박제 → server(Generator)가 Read 후 갱신, qa(Evaluator)가 채점 (책 Ch 16 Initializer→Generator→Evaluator 패턴).
- Phase 3 progress는 별도 sprint 착수 직전 별도 생성.
- server / qa에게 본 계획 + Phase 1 progress(`reports/sprint-cc4-postcleanup-phase1-progress.md`) Read 후 작업 핸드오프.

### 7-3. 원가 영향 + 시각 검수 + web 핸드오프 플래그

- Phase 2는 **신규 AI 기능 추가 0건** — cost-accountant 마진 검증 게이트 **불요** (§6-1).
- 시각 검수(visual-canon-keeper) **불요** — server 도메인 한정 + HTTP 응답 영향 0 (§6-2).
- **web 핸드오프 0건** — HTTP 응답 영향 0 (CC-2a 박제 응답 키 이미 `points`/`pricePerPoint`). web docs sync 0건 (api-contract.md 응답 모델 무변경). Phase 3 후 web `auth/me` 응답 (`credits` 필드 제거)가 web 핸드오프 1건이지만 Phase 3 범위.

### 7-4. Phase 3로 이월되는 입력값 (Phase 2 범위 외 — 명시)

| 항목 | 진단 근거 | 이월 sprint |
|---|---|---|
| `auth.controller:48` 응답에서 `author.credits` 제거 (`/auth/me` 응답 변경 — web 핸드오프 1건) | Phase 1 progress §1 S0d | Phase 3 (`Author.credits` DROP + web auth/me 응답 변경 동시) |
| `refund-payment.usecase:124-125` `author.credits ?? 0` 폴백 (charged 슬롯 박제) | Phase 1 progress §1 S0d + 본 Phase 2 미접촉 (Author 도메인 한정) | Phase 3 (`Author.credits` DROP 직전 정리) |
| `credit-migration.ts:54,58,84-85` `author.credits` 환산 로직 (디노미 V Phase 마이그레이션 도구) | Phase 1 progress §1 S0d + 본 Phase 2 미접촉 | Phase 3 (`Author.credits` DROP 후 dead code 제거) |
| `prisma-author.repository.ts:248,299,344` `credits: row.credits` 매핑 (Author 도메인 모델 직렬화) | 본 계획 작성 중 grep — Author 도메인 한정 | Phase 3 (`Author.credits` DROP 후 매핑 제거) |
| `Author.credits` Int 컬럼 DROP + `CreditLog` 테이블 폐기 | Phase 1 progress §7 Phase 3 이월 | Phase 3 (큰 마이그레이션, ≥1 sprint 유예 후) |
| `prisma-credit.repository.ts` 잔존 메서드 2종(`findLogsByAuthorId`/`getGiftRanking`) + port + DI 제거 | Phase 1 progress §8 발견 사항 | Phase 3 |
| HIGH-1 案 B (별도 sprint) | Case C 사용자 결정 5/21 | 별도 sprint (CC-5 병렬 또는 후속) |

> ⚠️ **Phase 2 완료 후 잔존 결함 (Phase 3 범위)**: `Author.credits` 컬럼 잔존 + `CreditLog` 테이블 잔존 + `prisma-credit.repository` 메서드 잔존 + `auth.controller:48` 응답 `credits` 필드 잔존 + `refund-payment.usecase:124-125` 폴백 잔존 + `credit-migration.ts` 디노미 도구 잔존. **Phase 2 단독 머지 시점에서도 운영 안전성 100% 확보** (`Payment.points` 정합 완료) — Phase 3는 정합·청결 보강.

---

## 8. 종합 게이트 — CC-4 Phase 2 완료 선언 조건 + Payment.points 정합 종결 증명

### Phase 2 완료 선언

- **§2 결정**: 案 Y(Payment만 rename, RefundLog 보존) 권고 채택 — 사용자 추가 결정 불요(Phase 1 progress 권고 정합).
- **S0 게이트**: S0a~S0d [MUST] 4건 완료 (Phase 1 머지 후 현행 사용처 + DB 상태 박제).
- **본 작업 [MUST]**: M1a~M1c + R1a~R1e + R2a~R2b + F1a~F1b + F2a~F2d — 전부 통과. ([SHOULD] F2e 실패는 회고만.)
- **검증 게이트** (writing-plans Gate 1·2·3):
  - Gate 1 (빌드): F2a `npm run build` 무에러.
  - Gate 2 (테스트): F2b `npm test` 전체 PASS + 커버리지 ≥60%. **Prisma client 타입 변경**(`credits`→`points`)으로 컴파일러가 누락 grep 강제 — 빌드 PASS = 코드 일괄 rename 정합 자동 박제.
  - Gate 3 (문서/sensor): F2c~e — shared-contracts §13/§30 변경 이력 + TECH_STATUS + api-contract + data-model + SCHEMA 갱신 + sensor silent.

### Payment.points 정합 종결 증명 (Phase 2 종결 게이트 — 가장 중요)

Phase 2는 컬럼 물리 rename — 완료 시 다음 박제:

| 결함 | 증명 방법 |
|---|---|
| **Payment.credits 코드 잔존 0건** | ① `grep -rn "payment\.credits\|Payment\.credits" grimoire-server/src --include="*.ts" --exclude="*.spec.ts"` **0건** (주석 매치만) ② tsc PASS + Prisma client 타입(`node_modules/.prisma/client/index.d.ts`)에 `Payment.points` 박제 |
| **마이그레이션 dev/prod apply 정합** | ① dev `prisma migrate status` — 5/21 V Phase + `payment_credits_rename_phase2` 적용 박제 ② prod 동일 박제 ③ 사후 검증 SQL — `SELECT points FROM payments LIMIT 1` PASS / `SELECT COUNT(*) FROM payments` rename 전후 일치 / `SELECT COUNT(*) FROM information_schema.columns WHERE table_name='payments' AND column_name='credits'` = 0 |
| **RefundLog 보존 + 의미 박제 강화** | ① `schema.prisma:535-536` 주석 강화 박제 ② shared-contracts §13/§30 변경 이력 박제 ③ docs/data-model.md RefundLog 섹션 박제 ④ `RefundLog.credits`/`deficitCredits` 컬럼 DDL 변경 0건 (마이그레이션 SQL에 RefundLog 미언급) |
| **HTTP 응답 영향 0건** | ① `GET /payments/products` 응답 키 = `points`/`pricePerPoint` (CC-2a 박제) — 본 Phase 2 미변경 ② `GET /payments/credits` 응답 = `bySource.charged` (CC-3 박제) — 본 Phase 2 미변경 ③ web 영향 검증 0건 (FE 코드 변경 불요) |

→ **Payment.points 정합 종결 선언 조건**: 위 4건 전부 증명 + F1a/F1b 마이그레이션 apply 정합 = "CC-4 Phase 2 — Payment.credits → Payment.points 물리 rename 완료. RefundLog 보존 + 의미 박제 강화. 컬럼 정합 100% 달성". qa(Evaluator)가 QA_REPORT.md에 종결 통과율 박제.

### CC-4 Phase 2 미해소 잔존 (범위 외 — 명시)

- `Author.credits` 컬럼 DROP = Phase 3 (별도 sprint).
- `CreditLog` 테이블 폐기 = Phase 3 (별도 sprint).
- `prisma-credit.repository` 잔존 메서드 2종 제거 = Phase 3.
- HIGH-1 案 B 이행 = 별도 sprint (Case C, 사용자 결정 5/21).
- CC-5 PAY-P1-4 Polar 구독 연동 = 별도 sprint.
- sensor 7종 hook 등록 = harness 영역.
- **CC-4 Phase 2 완료 = 컬럼 정합 즉시 위험 0건** — Payment.points 정합 완료, 신규 개발자 혼선 위험 해소. Phase 3는 Author 도메인 정리.

---

## 9. rollback 단위

- 각 sub-task는 git commit 단위 — M1·R1·R2·F1·F2 별 commit 권장. 실패 시 해당 commit revert.
- **M1·R1·R2** (코드 + schema 변경만, 마이그레이션 미적용): tsc/jest 실패 = 즉시 해당 commit 단위 롤백. DB 스키마 비변경 → 백업 불요. `prisma migrate dev --create-only` 결과 SQL 파일도 git revert로 즉시 제거.
- **F1a** (dev migration apply): 실패 시 즉시 역방향 ALTER (`ALTER TABLE payments RENAME COLUMN points TO credits`) 또는 pg_dump 복원. dev는 회복 부담 작음.
- **F1b** (prod migration apply): 직전 pg_dump 백업 필수. 실패 시 1차 = 역방향 ALTER 즉시 / 2차 = pg_dump 복원. 코드 git revert + 역방향 ALTER + redeploy로 t=0 상태 복원.
- **F2a~F2e** (빌드/테스트/문서): 실패 시 commit revert + 다시 작업.

---

## 10. 변경 이력

- 2026-05-21: 본 계획 신설. CC-4 Phase 2 폐기 정리(S0 4 + 마이그레이션 SQL/schema 3 + 코드 일괄 rename 5 + RefundLog 의미 박제 2 + 마이그레이션 apply 2 + 마무리 4 = 총 **20 sub-task**, 권고 案 Y `Payment.credits → points` rename + `RefundLog.credits`/`deficitCredits` 보존+의미 박제 강화) writing-plans 양식 분해. **사용자 결정 추가 불요** — Phase 1 progress 권고 案 Y 정합 + 사용자 키워드 게이트("크레딧개편 Phase 2 prod migration + 배포 진행") 사전 박제(2026-05-21) + HIGH-1 案 B = Case C 별도 sprint 사용자 결정(5/21). cost-accountant 게이트 불요 (신규 AI 0건). visual-canon-keeper 불요 (server 한정, HTTP 응답 영향 0). web 핸드오프 0건 (CC-2a 박제 응답 키 이미 `points`). 마이그레이션 안전성 — Postgres ALTER TABLE RENAME COLUMN은 메타데이터 한정 락(무손실, 즉시) + 역방향 ALTER로 비파괴 롤백 가능 + pg_dump 백업 안전망. 마이그레이션-코드 단일 deploy 묶음 필수 (docker-entrypoint.sh:11 `RUN_MIGRATION=true` 부팅 시 자동 적용). Phase 3 이월 = `Author.credits` DROP + `CreditLog` 폐기 + `auth.controller:48`/`refund-payment.usecase:124-125`/`credit-migration.ts:54,58,84-85`/`prisma-author.repository.ts:248,299,344` 잔존 정리. 코드 변경 0건 — 계획 수립 전용.

---

## 11. 미확인 / 추정 금지 명시

| 항목 | 상태 | 해소 시점 |
|---|---|---|
| `Payment.credits` / `payment.credits` 사용처 file:line | **부분 확인** — Phase 1 progress §1 S0c + 본 계획 작성 중 grep 결과(~25~30곳 추정). S0a 현행 재실측 | S0a |
| `RefundLog.credits` / `RefundLog.deficitCredits` 사용처 file:line | **부분 확인** — Phase 1 progress §1 S0c + 본 계획 작성 중 grep 결과(~15~20곳, schema + policy 주석 + port 주석 + repository + email/sms adapter spec + integration spec). S0b 현행 재실측 | S0b |
| `Payment` 모델 정의 현행 + 마이그레이션 history | **확인** — 본 계획 작성 중 schema.prisma:260~274 Read 박제. S0c 재확인 | S0c |
| dev/prod `payments` row 수 + sum 박제 | **미확인** — 본 진단은 코드 한정, DB 미접속. S0d 실측 | S0d |
| RefundLog 처리 案 (X/Y/Z) | **권고 확정** — 案 Y(Payment만 rename, RefundLog 보존) — Phase 1 progress 권고 정합 + §2 근거 5건 박제 | §2 결정 게이트 통과 (사용자 추가 결정 불요) |
| Phase 2 prod migration 사용자 승인 | **확인** — 사용자 키워드 게이트 "크레딧개편 Phase 2 prod migration + 배포 진행" 사전 박제(2026-05-21) | 본 계획 §5 박제 |
| HIGH-1 案 B 처리 | **확인** — Case C(별도 sprint, CC-4 범위 외) 사용자 결정 5/21 박제 | 본 계획 §5 박제 |
| Phase 3 ≥1 sprint 운영 박제 기간 | **미확정** — Phase 2 머지 후 회귀 박제 기간은 메인 판단 | Phase 3 착수 직전 |
| sub-task 시간 추산 | 상대 추산 — 실측 아님. 본 계획은 분해 단위, 실제 시간은 server 실행 시 확정 | — |

> 본 계획은 코드 변경 0건 — 순수 계획 수립. 모든 file:line은 Phase 1 progress 박제 + 본 계획 작성 중 실제 Read(`schema.prisma`/Phase 1 progress) + grep(`Payment\.credits` / `payment\.credits` / `deficitCredits`) + shared-contracts §13/§30 박제 기반. 미확인은 §11에 명시 — 추정 0건.
