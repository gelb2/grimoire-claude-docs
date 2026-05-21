# Sprint CC-4 Phase 2 Progress — `Payment.credits → Payment.points` 물리 rename + RefundLog 案 Y 보존

> 작성: 2026-05-21 / grimoire-server (Generator) / **Phase 2 종결 박제**
> 계획 정본: `.claude/state/sprint-cc4-phase2-rename-plan-draft.md` (案 Y 권고 채택)
> 범위: Phase 2만 (코드 + spec + 마이그레이션 1건 + 문서). Phase 3(`Author.credits` DROP + `CreditLog` 폐기) = 별도 sprint.

---

## 0. 종합 판정

- **PASS** — Phase 2 완료 게이트 5개 + Payment.points 정합 종결 증명 4건 전부 통과.
- jest 1063 → 1063 (변동 0 — assertion 키만 변경, 신설 it 0) / build PASS / tsc PASS / 커버리지 61.74%/63.33%(lines) ≥60% 게이트 충족.
- 로컬 dev DB migration apply PASS + 사후 검증 SQL 4건 PASS.
- 코드 변경 + 마이그레이션 + 문서 동기화 = 단일 feature 브랜치(`feature/cc4-phase2-payment-credits-rename`)

## 1. S0 — 현행 재실측 결과

### S0a — `Payment.credits` / `payment.credits` 사용처 (Phase 1 머지 후 grep)

```
src/adapter/outbound/persistence/prisma-payment.repository.ts:285-287   # 주석
src/application/payment/refund-payment.usecase.ts:55                    # JSDoc
src/application/payment/payment.usecase.spec.ts:539                     # 주석
src/application/payment/payment-reconciliation.job.ts:201,206,218,225,255  # 코드 본문 5건
src/domain/model/config.ts:40-41                                        # 주석
src/application/payment/payment.usecase.ts:199,351,357,404,431-432,438,444 # 코드 본문 8건
```

코드 본문 ~13건 + 주석/JSDoc ~7건 + spec PaymentRecord mock 다수.

### S0b — `RefundLog.credits` / `RefundLog.deficitCredits` 사용처

```
src/adapter/outbound/persistence/prisma-payment.repository.ts:223,369-376   # 본문 + 주석 (보존)
src/adapter/outbound/sms/null-sms.adapter.spec.ts:24,31,54                  # notification payload field
src/adapter/outbound/email/null-email.adapter.spec.ts:65,67                 # notification payload field
src/adapter/outbound/persistence/prisma-payment.repository.spec.ts:419-454  # RefundLog mock
src/application/credit/credit-gift-refund-integration.spec.ts:341,720-757,851  # 통합 검증
src/application/payment/payment.usecase.ts:256,273,479                      # 응답 키 (보존)
src/application/payment/payment.usecase.spec.ts:534-597                     # assertion
src/domain/port/outbound/payment-repository.port.ts:119,121                 # JSDoc
src/domain/port/outbound/email-service.port.ts:58                           # notification payload field
src/domain/port/outbound/sms-service.port.ts:40                             # notification payload field
src/domain/policy/credit-consumption-policy.ts:188,212                      # JSDoc
prisma/schema.prisma:535-536                                                # 모델 정의 (보존, 案 Y)
```

→ 案 Y 채택 — DDL 변경 0건. 의미 박제 강화로만 정합.

### S0c — Payment 모델 정의 + 마이그레이션 history

- `prisma/schema.prisma:260-274` `Payment` 모델, `credits Int` 정의 박제됨
- 가장 최근 마이그레이션 = `20260517_credit_overhaul_i_phase` (V Phase, 5/21 prod apply 완료)
- Phase 2 신 마이그레이션 = `20260521_payment_credits_rename_phase2`

### S0d — 로컬 dev DB `payments` row 카운트

```
row_count | sum_credits | min_credits | max_credits
----------+-------------+-------------+-------------
        0 |           0 |           0 |           0
```

로컬 dev DB의 `payments` 0 row (개발 환경 baseline). rename 데이터 손실 위험 0건.

## 2. Prisma schema + 마이그레이션 SQL (M1)

### M1a — 마이그레이션 파일 작성

- 경로: `prisma/migrations/20260521_payment_credits_rename_phase2/migration.sql`
- 내용: `ALTER TABLE "payments" RENAME COLUMN "credits" TO "points";` (1줄 + 박제 주석 14줄)
- Postgres native ALTER — 메타데이터 한정 락, 무손실, 즉시 완료. 인덱스/제약/FK 무영향.

### M1b — Prisma schema 갱신

- `prisma/schema.prisma:260-274` — `model Payment { ... credits Int ... }` → `model Payment { ... points Int ... }` 변경
- 모델 박제 주석 강화 (CC-4 Phase 2 rename 박제 + 의미 일관성 + 마이그레이션 파일 참조)
- `npx prisma format` PASS / `npx prisma generate` PASS — Prisma client 타입 `Payment.points` 박제

### M1c — 마이그레이션 안전성 분석

| 영역 | 분석 결과 |
|---|---|
| 락 시간 | 메타데이터 한정 (ACCESS EXCLUSIVE 짧음) — 데이터 미터치, 즉시 |
| 데이터 영향 | 0건 — 컬럼명만 변경 |
| 인덱스/제약 | 무영향 — `credits` 컬럼 인덱스 미부여, `externalTransactionId` UNIQUE만 |
| FK | 무영향 — `refundLogs.paymentId` FK는 `credits` 무관 |
| 롤백 | 비파괴 — `ALTER TABLE payments RENAME COLUMN points TO credits` 역방향 즉시 |
| pg_dump 백업 | dev 불요(rows 0) / prod는 마이그레이션 직전 1회 |

## 3. 코드 일괄 rename (R1)

### R1a — `payment.usecase.ts`

- L199 `payment.create({..., credits: product.points })` → `points: product.points`
- L351 주석 `payment.credits` → `payment.points` 박제 갱신
- L357 `payment.credits` → `payment.points` (`completePaymentWithPoints` totalPoints 인자)
- L404 `totalPoints: payment.credits` → `payment.points` (audit meta)
- L432 응답 `{ credits: payment.credits }` → `{ credits: payment.points }` — **응답 키 `credits` 보존** (외부 호환성), 값만 신 컬럼
- L438 주석 갱신
- L444 `refundPt: payment.credits` → `payment.points`

### R1b — `payment-reconciliation.job.ts`

- L201,206,218,225,255 `payment.credits` → `payment.points` (handleBoost + handleRefundMismatch)
- L255 audit meta 키 `credits: payment.credits` → `points: payment.points` (모니터링 정합)

### R1c — `prisma-payment.repository.ts`

- L15 `create()` 입력 시그니처 `credits: number` → `points: number`
- L223 RefundLog 박제 주석 갱신
- L267 `tx.payment.findUnique({ select: { amount, credits, status }})` → `select: { amount, points, status }`
- L285-287 주석 갱신 (`payment.points` + 案 Y 박제)
- L369-376 주석 갱신 (案 Y RefundLog 보존 박제)

### R1d — `payment.usecase.spec.ts` (응답 키 보존 결정 적용)

- L17 `mockPayment.credits` → `points` (PaymentRecord mock)
- L196, L302 `expect.objectContaining({..., credits: 25000 })` → `points: 25000` (paymentRepo.create 인자 검증)
- L234 `reusablePayment.credits` → `points`
- L1118, L1137 PaymentRecord mock `credits: 5` → `points: 5`
- **L428, L491, L509, L525, L568, L643, L673 `result.credits` assertion = 응답 키 보존**(보존 결정 — webhook 응답 schema 외부 호환성), 미변경

### R1e — 잔존 코드 본문 grep 재검증

```
$ grep -rn "payment\.credits\|Payment\.credits" src --include="*.ts" --exclude="*.spec.ts"
src/adapter/outbound/persistence/prisma-payment.repository.ts:370   # 주석 (rename 박제 이력)
src/domain/model/config.ts:41                                        # 주석 (rename 박제 이력)
```

→ **코드 본문 호출 0건** (주석 매치만). R1e gate PASS.

### 도메인 PaymentRecord 인터페이스 변경

- `domain/port/outbound/payment-repository.port.ts:1-11` — `PaymentRecord.credits` → `points` (JSDoc 박제 강화)
- `domain/model/config.ts:40-41` 주석 갱신 (`Payment.points` 정합)
- `application/payment/refund-payment.usecase.ts:55` JSDoc 1건 갱신

## 4. RefundLog 의미 박제 강화 (R2 — 案 Y)

### R2a — `schema.prisma:529-542`

- `RefundLog` doc-comment 헤더 갱신 (`CC-4 Phase 2 보존 2026-05-21` 명시)
- `credits Int` 주석 — `[CC-2b 재해석 / CC-4 Phase 2 보존] 실 환수 pt (actualRefunded). Payment.points 와 단위 일관.`
- `deficitCredits Int` 주석 — `[CC-2b 재해석 / CC-4 Phase 2 보존] 이 환불 1건이 유발한 외상 pt 기여분 (감사 추적용 — Author.deficitPoints 와 의미 다름).`
- 컬럼 자체 DDL 변경 0건

### R2b — shared-contracts §13/§30 + 변경 이력

- §13 RefundPaymentAtomically 변경 이력 1줄 추가 (CC-4 Phase 2 Payment.points rename + RefundLog 案 Y 보존)
- §30 CreditOverhaul 변경 이력 1줄 추가 (Payment.points + 案 Y + 응답 키 보존 + 마이그레이션 + 종결 증명)

## 5. 마이그레이션 apply + 사후 검증 (F1a — 로컬 dev DB)

### F1a — apply

```
$ npx prisma migrate deploy
Applying migration `20260521_payment_credits_rename_phase2`
All migrations have been successfully applied.
```

### 사후 검증 SQL 4건 (전부 PASS)

```
① payments 컬럼 정합:
   column_name | data_type
   ------------+-----------
   points      | integer
   (credits 컬럼 0건 — rename 성공)

② payments row 보존:
   post_count | sum_points
   -----------+------------
            0 |          0
   (rename 전후 일치)

③ refund_logs 보존 (案 Y):
   column_name     | data_type
   ----------------+-----------
   credits         | integer
   deficit_credits | integer
   (보존 정합)

④ prisma migrate status: "Database schema is up to date!"
```

### F1b — prod migration apply

본 progress 박제 시점 = 로컬 dev DB 한정. prod migration apply = grimoire-infrastructure agent / 사용자 키워드 게이트 통과 후 별도 단계 (`make deploy-prod` 또는 `RUN_MIGRATION=true` 컨테이너 부팅 자동 적용).

## 6. 빌드 / jest / 커버리지 (F2a~b)

- `npx tsc --noEmit` — 무에러
- `npm run build` (`nest build`) — 통과
- `npm test` — **75 suites / 1063 tests PASS** (Phase 1과 동일 — assertion 키만 변경, 신설 it 0)
- `npm test -- --coverage`:
  - Statements: 61.74% (3197/5178)
  - Lines: 63.33% (2950/4658)
  - 게이트 ≥60% 충족

## 7. 문서 동기화 (F2c~d)

- `.claude/shared-contracts.md` §13 + §30 변경 이력 추가
- `grimoire-server/TECH_STATUS.md` — CC-4 Phase 2 박제 추가 + 표 행 추가
- `grimoire-server/docs/data-model.md` — `payments.points` 컬럼 박제 + `refund_logs` 案 Y 보존 박제
- `grimoire-server/SCHEMA.md` — payments 표 `points` 갱신 + refund_logs 案 Y 보존 박제

## 8. Payment.points 정합 종결 증명

| 결함 | 증명 방법 | 결과 |
|---|---|---|
| Payment.credits 코드 잔존 0건 | `grep "payment\.credits\|Payment\.credits" src --exclude="*.spec.ts"` | **주석 매치 2건만** (rename 박제 이력 자체) — 코드 본문 호출 **0건** |
| 마이그레이션 dev apply 정합 | `prisma migrate status` + 사후 검증 SQL 4건 | PASS — `payments.points` 컬럼 존재 + `credits` 컬럼 0건 + status up-to-date |
| RefundLog 案 Y 보존 + 의미 박제 강화 | `refund_logs.credits`/`deficit_credits` Postgres 컬럼 보존 박제 + schema.prisma 주석 강화 + shared-contracts §13/§30 박제 | PASS — DDL 변경 0건, 의미 박제 강화 정합 |
| HTTP 응답 영향 0건 | `GET /payments/products`(CC-2a `points`/`pricePerPoint`) / `GET /payments/credits`(CC-3 `bySource.charged`) | PASS — web 변경 불요, 응답 schema 무변경 |
| 응답 키 보존 (외부 호환성) | `processNormalizedWebhook` 반환 `{ credits, deficitCredits? }` 유지 | PASS — webhook payload 외부 호환성 보존 |
| jest 회귀 0 | 1063 → 1063 (assertion 키 변경, 신설 it 0) | PASS |
| 커버리지 게이트 ≥60% | 61.74%/63.33%(lines) | PASS |

## 9. 발견 사항 / Phase 3 이월 항목

### 9-1. 명시적 Phase 3 이월 (Phase 2 범위 외)

| 항목 | 이월 sprint |
|---|---|
| `Author.credits` Int 컬럼 DROP + `prisma-author.repository.ts:248,299,344` 매핑 정리 | Phase 3 |
| `CreditLog` 테이블 + `prisma-credit.repository.ts:findLogsByAuthorId/getGiftRanking` 잔존 2 메서드 제거 | Phase 3 |
| `auth.controller:48` 응답 `author.credits` 필드 제거 (web 핸드오프 1건) | Phase 3 |
| `refund-payment.usecase:124-125` `author.credits ?? 0` 폴백 정리 | Phase 3 |
| `credit-migration.ts:54,58,84-85` 디노미 환산 도구 정리 | Phase 3 |
| HIGH-1 案 B 이행 (`Author.plan` → `MembershipPlan.tier` 정본화) | Case C 별도 sprint (사용자 결정 5/21) |

### 9-2. 본 sprint 진행 중 발견

- **응답 키 보존 결정 박제 (계획 §3-2 R1d 보다 보수적 선택)**: `processNormalizedWebhook`/`processWebhook` 반환 `{ processed, credits, deficitCredits? }` — webhook 응답 schema는 외부 호환성 관점이 있어 응답 키만 keep + 내부 컬럼만 rename. 응답 키 일관성 정합은 Phase 3에서 web `auth/me` 응답 영향과 함께 일괄 결정 권고.
- **추가 발견 0건** — 마이그레이션 + 코드 + spec 모두 컴파일러가 Prisma client 타입 기반으로 누락 강제 → 잔존 누락 위험 자동 차단.

### 9-3. cost-accountant / visual-canon-keeper 게이트

- cost-accountant: **불요** (신규 AI 기능 추가 0건, `CREDIT_PRODUCTS` 무변경, 차감 N 무변경)
- visual-canon-keeper: **불요** (server 도메인 한정, HTTP 응답 영향 0)

## 10. 최종 통계

- jest: 75 suites / 1063 tests PASS (CC-4 Phase 1과 동일)
- 커버리지: Statements 61.74% / Lines 63.33% — 게이트 ≥60% 충족
- 마이그레이션: 1건 (`20260521_payment_credits_rename_phase2`) — 로컬 dev DB apply PASS
- 코드 변경: ~30곳 rename + 주석 ~10건 갱신 (Prisma client 타입 자동 정합)
- spec 변경: 7 파일 (PaymentRecord mock + tx.payment.findUnique mock 일괄)
- 문서 변경: shared-contracts §13/§30 + TECH_STATUS + data-model + SCHEMA
- 작가 본문 접촉: **0건**

---

**Phase 2 완료 선언**: `Payment.credits → Payment.points` 물리 rename + 코드 일괄 정합 + RefundLog 案 Y 보존 + 의미 박제 강화 = 컬럼 정합 100% 달성. 신규 개발자 혼선 위험 해소.

**Phase 3 진입 조건**: Phase 2 머지 + 운영 박제 ≥1 sprint 후 별도 sprint 착수 직전 상세화.
