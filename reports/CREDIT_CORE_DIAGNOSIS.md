# 크레딧 개편 코어 — 정밀진단 (V Phase 적용 안전 + 기능 완결 작업 산출)

> 작성: 2026-05-18 / grimoire-server 개발자 에이전트 / **순수 진단 — 코드 변경 0건**
> 대상: `develop` 브랜치, 커밋 `658b7d9` 시점. 크레딧 개편 I Phase (`20260517_credit_overhaul_i_phase`)
> 출발점: `reports/SUBSCRIPTION_AUDIT_SERVER.md` (직전 audit — 재조사 아닌 확장)
> 검증 방식: 실제 파일 Read + grep + `prisma migrate status`. 추정 0건. 미확인은 "미확인" 명시.
> 목적: 직전 audit이 "결함이 있다"를 밝혔다면, 본 진단은 **"고치려면 정확히 무엇을, 얼마나"**를 산출 — 메인의 sprint 분할 재추산 입력.

---

## 0. 진단 종합 — 한눈에

| 항목 | 직전 audit | 본 진단 추가 발견 | 작업 규모 |
|---|---|---|---|
| 적립 트리거 (8경로) | CRITICAL-2 (GrantPointsUseCase 미연동) | 8경로 전수 매핑 + 트리거별 작업량 + 충전 트랜잭션 경계 충돌 정밀화 | **L** (2 sprint) |
| 구·신 시스템 배선도 | — | 구 `CreditUseCase`/`Author.credits`/`CreditLog` 호출처 전수 + 폐기 경로 | **M** (배선 정리) |
| 마이그레이션 안전성 | HIGH-2 (×610) | (c-2) row 수 오산 + dev plan 분포 미측정 + (d) 휴리스틱 + 엣지케이스 5종 정밀화 | **M** (측정 + SQL 수정) |
| CRITICAL-1 (getBalance 만료 미반영) | CRITICAL-1 | 수정 범위 2案 + lazy 안전망 작업 분해 | **M** |
| HIGH (이중 출처 / 원장 분리) | HIGH-1, HIGH-3 | ADR 결정 + 코드 작업 분해 | **M** |
| deficit / settleDeficit | MEDIUM-1 | 흐름 완결성 검증 — **로직 완결, 호출처 0건** | **S** (CRITICAL-2에 흡수) |
| PAY-P1-4 (Polar 구독 연동) | 범위 외 | **미착수 확정** — `subscription.*` webhook 명시적 무시 | **L** (신규 sprint) |

**핵심 결론**: I Phase의 스키마·도메인·**차감(spend)** 경로는 설계 정본에 충실. 그러나 **적립(earn) 경로 전체와 구독 결제 연동이 런타임에 한 번도 작동하지 않는다.** 차감은 신규 ledger 경로(`ChargePointsUseCase`가 chat/analysis에 실제 연동됨), 적립은 구 `Author.credits` 경로 — 두 시스템이 분리 운영. V Phase 마이그레이션을 현 상태로 적용하면 마이그레이션 직후 신규 가입자부터 전 AI 기능이 마비된다. 크레딧 개편 코어를 완결하려면 **5개 sprint**가 필요하다 (§8).

---

## 1. 적립 트리거 전수 매핑 (진단 항목 1)

크레딧/포인트가 **늘어나는** 모든 경로. 각 트리거의 현재 구현 + 신 4-출처 시스템 재배선 작업 + 규모.

> 매핑 방식: `grep -rn "adjustCredits\|grant\|giftTransfer\|completePaymentAtomically\|refundPayment" src/` (spec 제외) + 각 호출처 파일 Read.

| # | 트리거 | 현재 무엇에 쓰는가 | 코드 위치 (확인) | 신 시스템 재배선 | 규모 |
|---|---|---|---|---|---|
| T1 | 가입 보너스 (3 크레딧) | 구 `CreditUseCase.grant(id, 3, 'signup_bonus')` → `Author.credits` Int | `auth.usecase.ts:55` (email) + `:149` (Google) — **2 호출처** | `GrantPointsUseCase.grantSignupBonus(id)` (`source='free'`, 3,000pt). `AuthUseCase`에 DI 추가 + 2 호출처 교체 | S |
| T2 | 첫 작품 등록 보너스 (2 크레딧) | 구 `CreditUseCase.grant(id, 2, FIRST_WORK_BONUS)` → `Author.credits` | `work-management.usecase.ts:213` (`updateEpisodeStatus`, upload→public 최초 전환) — **1 호출처** | `GrantPointsUseCase.grantFirstWorkBonus(id)` (`source='free'`, 2,000pt). `WorkManagementUseCase`에 DI 추가 + 1 호출처 교체 | S |
| T3 | Polar 충전 완료 | 구 `paymentRepo.completePaymentAtomically(id, authorId, payment.credits, productId)` — `Payment.credits` Int(패키지 수량)를 `Author.credits`에 가산 | `payment.usecase.ts:334` (`processNormalizedWebhook` success 분기) | **재배선 + 트랜잭션 재설계 필수** — 아래 §1-A 상세. 단순 호출 교체 불가 | **L** |
| T4 | 응원 선물 수령 (1·3·5 크레딧) | 구 `creditRepo.giftTransfer(senderId, receiverId, ...)` — sender `Author.credits` 차감 + receiver 가산을 1 `$transaction` | `credit.usecase.ts:95` (`gift`), 컨트롤러 `credit.controller.ts:20` | sender 차감 = `ChargePointsUseCase`(소진 우선순위) / receiver 적립 = `GrantPointsUseCase.grantGift`(`source='gift'`). **양측 모두 재배선** — 아래 §1-B 상세 | **M** |
| T5 | 관리자 수동 지급 | 구 `CreditUseCase.grant(id, amount, 'admin_grant:...')` → `Author.credits` | `admin.usecase.ts:109` (`grantCredits`) | `GrantPointsUseCase.grantManual(id, source, points, adminId)`. `AdminUseCase` DI + 호출 교체. **출처 파라미터** 운영자가 명시(보통 'charged'). AdminAuditLog 박제는 유지 | S |
| T6 | 관리자 수동 차감 | 구 `CreditUseCase.deduct(id, amount, 'admin_deduct:...')` → `Author.credits` | `admin.usecase.ts:128` (`deductCredits`) | `ChargePointsUseCase` 또는 `CreditLedgerPort.spend` 직접. 단 관리자 차감은 "음수 deficit 불가"라 spend의 deficit 분기를 어떻게 다룰지 결정 필요 (관리자 차감은 잔액 부족 시 throw가 맞음 — MEDIUM-2의 "deficit 불가 모드"와 같은 뿌리) | S |
| T7 | 환불 시 크레딧 복원 (역적립) | 구 `refundPaymentAtomically` — `RefundLog` + `Author.credits` 환수(차감), 부족 시 `RefundLog.deficitCredits` 외상 | `refund-payment.usecase.ts` (`payment.usecase.ts:401` `processNormalizedWebhook` cancel 분기에서 호출) | 환불은 **적립이 아니라 차감(환수)** — `Payment.credits` pt 단위 정합 후 `CreditLedgerPort.spend`로 환수. 기존 `RefundLog.deficitCredits` 외상과 신 `Author.deficitPoints` 외상의 **이중 외상 시스템 통합** 필요 — 아래 §1-C 상세 | **M** |
| T8 | 분석 실패 환불 | I Phase 신규 — `ChargePointsUseCase.refundAnalysis(id)` (`source='charged'`, 2,440pt earn) | `novel-analysis.usecase.ts:148` (구 경로) / `:146` 부근 (`chargePoints` 주입 시 신 경로) | **이미 신 시스템.** 단 `refundAnalysis`가 `earn(source='charged')`로 환불 — 원래 차감이 무료적립/구독풀에서 나갔어도 충전 출처로 복원됨 → 출처 회계 부정확 (MEDIUM 신규 — §5-D) | S |
| T9 | 구독 월 풀 초기 부여 / 매월 리셋 | I Phase 신규 — `PrismaMembershipPlanRepository.resetMonthlyPool` (`source='subscription'` earn) | `reset-monthly-pool.job.ts` cron + `prisma-membership-plan.repository.ts:37` | **cron은 신 시스템·작동.** 단 ① 초기 부여 = 마이그레이션 (c-2) row에만 의존 → 마이그레이션 후 신규 구독자는 풀 0 (PAY-P1-4 미연동) ② cron이 이월 금지의 유일 안전장치 (CRITICAL-1) | — (CRITICAL-1·PAY-P1-4) |
| T10 | reconciliation boost | **해당 없음 (미확인→확인 완료)** — `prisma-reconciliation-checkpoint.repository.ts`는 PAY-P0-2 결제 정합 체크포인트. 크레딧/포인트를 늘리는 "boost" 적립 경로는 코드에 **0건**. 질문의 "reconciliation boost"는 현 코드베이스에 미존재 | grep 결과 0건 | 없음 |

### 1-A. T3 충전 적립 — 단순 교체 불가, 트랜잭션 재설계 필수 (L)

`payment.usecase.ts:334`의 `completePaymentAtomically(payment.id, payment.authorId, payment.credits, payment.productId)`는 `PaymentRepositoryPort`가 **자체 `$transaction`**으로 (Payment 상태 + Author.credits 증가 + CreditLog 박제) 3건을 원자 처리한다 (CLAUDE.md §9 결제 원자성 절대 규칙).

`GrantPointsUseCase.grantCharge`는 내부적으로 `settleDeficit`(`$transaction` #1) + `earn`(`$transaction` #2) — **2개 별도 트랜잭션**(`grant-points.usecase.ts:76,83`). 이를 `payment.usecase`의 결제 트랜잭션과 합치면 트랜잭션 경계가 어긋난다. 결제 원자성(돈은 냈는데 포인트 없음 = 절대 불가)을 깨지 않으려면:

- **필요 작업**: `PaymentRepositoryPort`에 "결제 완료 + deficit 상계 + 포인트 적립"을 단일 `$transaction`으로 묶는 신 메서드(`completePaymentWithPoints` 등) 신설. 또는 `CreditLedgerPort`에 외부 `tx` 핸들을 받는 오버로드 추가(헥사고날 port가 Prisma `tx`를 노출하면 DIP 위반 — 신중). 
- `Payment.credits` Int를 pt로 재해석할지(MEDIUM-4) 결정 선행 — 현재 `Payment.credits`는 패키지 "수량"(5/20/50) 의미. 디노미 후 충전 패키지는 §8-5 4종(25,000/41,667/91,667/287,500 pt) → `payment.usecase`의 `CREDIT_PRODUCTS`와 `Payment.credits` 컬럼 의미를 pt로 통일해야 `grantCharge(totalPoints)`에 넘길 값이 정해진다.
- `getProducts()`(`payment.usecase.ts:158`)의 `pricePerCredit` 계산도 pt 기준 재작성.
- **규모 L** — 결제 도메인 핵심 트랜잭션 재설계 + `CREDIT_PRODUCTS` 디노미 개편(§8-5 4종) + spec 재작성. §0 결제 원자성 직격이라 신중도 최상.

### 1-B. T4 응원 선물 — 양측 재배선 (M)

`credit.usecase.ts:74` `gift()`는 `creditRepo.giftTransfer(senderId, receiverId, amount, ...)` 한 번으로 sender 차감 + receiver 적립을 원자 처리. 신 시스템엔 "1 트랜잭션 양측 이동" 메서드가 없다 — `ChargePointsUseCase`(sender 소진)와 `GrantPointsUseCase.grantGift`(receiver 적립)가 분리.

- **필요 작업**: `CreditLedgerPort`에 `transfer(senderId, receiverId, amount)` 단일 `$transaction` 메서드 신설(sender FOR UPDATE + receiver FOR UPDATE — 데드락 방지 위해 id 정렬 lock 순서) — 또는 sender 소진 + receiver 적립을 별도 트랜잭션으로 분리하되 보상 트랜잭션 설계. **선물은 돈 직결**이라 원자성 필수 → 단일 트랜잭션 메서드 권장.
- 선물 단위 정합: §8-6이 "현 1·3·5크레딧 → 1,000·3,000·5,000pt 환산 유지하되 채팅 시대 단위 적정성 S Phase 재검토" — `credit.controller.ts`의 `gift` body `amount`가 무엇 단위인지(크레딧? pt?) web과 계약 재합의 필요.
- **규모 M.**

### 1-C. T7 환불 — 이중 외상 시스템 통합 (M)

현재 외상이 **두 곳**에 따로 있다:
- 구: `RefundLog.deficitCredits Int` (`schema.prisma:531`) — 환불 시 `Author.credits`가 부족하면 못 갚은 만큼 외상.
- 신: `Author.deficitPoints Int` (`schema.prisma:38`) — 채팅 사후 차감 잔액 부족분.

CRITICAL-2 해소로 충전이 신 경로가 되면 `grantCharge`가 `Author.deficitPoints`를 상계한다. 그러나 환불(T7)이 구 경로면 `RefundLog.deficitCredits`를 별도로 본다 → **외상이 두 장부에 쪼개진다.** 환불을 신 경로로 옮기면서 두 외상 개념을 `Author.deficitPoints` 하나로 통합해야 한다. `RefundLog.credits`/`deficitCredits`의 pt 단위 정합(MEDIUM-4)도 같이.
- **규모 M.**

### 1-D. 트리거별 작업량 합계

| 규모 | 트리거 |
|---|---|
| S (단순 DI + 호출 교체, spec 보강) | T1, T2, T5, T6, T8 — 5건 |
| M (트랜잭션/포트 메서드 신설) | T4, T7 — 2건 |
| L (도메인 핵심 재설계) | T3 — 1건 |

---

## 2. 구 `CreditUseCase` vs 신 시스템 전체 배선도 (진단 항목 2)

### 2-1. 구 `CreditUseCase` 호출처 전수 (grep 확인)

| 메서드 | 호출처 (확인) | 단위 |
|---|---|---|
| `grant` | `auth.usecase.ts:55`, `:149` (가입) / `work-management.usecase.ts:213` (첫 작품) / `admin.usecase.ts:109` (관리자) | `Author.credits` Int |
| `deduct` | `admin.usecase.ts:128` (관리자 차감) | `Author.credits` Int |
| `gift` | `credit.controller.ts:20` → `credit.usecase.ts:74` | `Author.credits` Int (`giftTransfer`) |
| `getBalance` | **호출처 0건** (코드에서 미사용 — `getPointBalance`로 대체됨) | — |
| `getPointBalance` | `credit.controller.ts:33` (`/credits/balance`), `payment.controller.ts:57` (`/payments/credits`) | **신** `CreditBalance` (`ledger.getBalance` 위임) |
| `getGiftRanking` | `credit.controller.ts:26` (`/credits/ranking`) | `CreditLog` 집계 |
| `getLogs` | `credit.controller.ts:40` (`/credits/logs`) | `CreditLog` 조회 |

→ `CreditUseCase`는 **한 클래스 안에 구(`grant`/`deduct`/`gift`/`getBalance`=`Author.credits`) + 신(`getPointBalance`=`CreditLedger`) 단위가 혼재** (LOW-3). `getPointBalance`만 이미 신 경로로 이행됨 — HTTP `/credits/balance`·`/payments/credits`는 4 출처를 노출 중(shared-contracts §30 HTTP follow-up 커밋 `9d0d2b7`). 즉 **잔액 조회는 신, 적립·선물·차감은 구.**

### 2-2. 신 시스템 호출처 전수 (grep 확인)

| 신 컴포넌트 | 호출처 | 상태 |
|---|---|---|
| `ChargePointsUseCase.chargeChatTurn` | `chat.usecase.ts:162` | ✅ **연동됨** (chat usecase가 `Optional` 주입) |
| `ChargePointsUseCase.isChatBlocked` | `chat.usecase.ts:71` | ✅ 연동됨 |
| `ChargePointsUseCase.chargeAnalysis` | `novel-analysis.usecase.ts:125` | ✅ 연동됨 (`Optional` 주입) |
| `ChargePointsUseCase.chargeTheme` | **호출처 0건** | 🔴 미연동 — 테마 생성 usecase가 호출 안 함 |
| `ChargePointsUseCase.refundAnalysis` | `novel-analysis.usecase.ts:146` 부근 | ✅ 연동됨 |
| `GrantPointsUseCase.*` (5 메서드 전부) | **호출처 0건** — `app.module.ts:143` provider 등록만 | 🔴 **전면 미연동 (CRITICAL-2)** |
| `MembershipPlanPort.getPlan` | **호출처 0건** | 🔴 미사용 (cron도 `findFirst` 직접) |
| `MembershipPlanPort.changeTier` | **호출처 0건** | 🔴 미연동 (PAY-P1-4 — §7) |
| `MembershipPlanPort.resetMonthlyPool`/`findPlansToReset` | `reset-monthly-pool.job.ts` | ✅ cron 연동 |

> **신규 발견 (직전 audit 누락)**: `ChargePointsUseCase.chargeTheme`도 **호출처 0건**이다. 직전 audit은 차감 경로를 "연동됨"으로 봤으나, 테마 차감은 미연동이다. 테마 생성 usecase(`theme.usecase` 계열)가 `chargeTheme`를 부르지 않는다 → 디노미 후 테마 일일 무료 초과분이 차감되지 않음. 단 테마는 구 경로(`credits` 1 차감)가 살아 있는지 별도 확인 필요 — **본 진단 시간 내 테마 차감 구 경로 미확인** (theme usecase 파일 미열람). §8 sprint 범위에 "테마 차감 연동 + 구 경로 확인" 포함.

### 2-3. 구 `CreditUseCase`·`Author.credits`·`CreditLog` 폐기 경로

| 대상 | 현 상태 | 폐기 경로 |
|---|---|---|
| `Author.credits` Int | `[DEPRECATED]` 주석 명시 (`schema.prisma:23-25`). 마이그레이션이 DROP 안 함 (1 sprint 유예 — §8-6 Cursor 반면교사) | CRITICAL-2 적립 연동 완료 → `credits` 읽기/쓰기 0건 확인 → **별도 후속 sprint**에서 `DROP COLUMN` |
| `CreditUseCase.grant/deduct/gift/getBalance` | 구 4 메서드 살아 있음 | 적립 연동(T1·T2·T5·T6·T4) 완료 시 호출처 0건 → 메서드 삭제. `getPointBalance`/`getGiftRanking`/`getLogs`만 남김 (또는 클래스 분리) |
| `CreditLog` 테이블 | `Author.creditLogs` 관계 + `credit.usecase.getLogs`/`getGiftRanking`이 사용 | **HIGH-3 — 즉시 폐기 불가.** `getGiftRanking`/`getLogs`가 `CreditLog` 집계에 의존. 신 `CreditLedger`로 이행하려면 `getGiftRanking`(선물 랭킹)·`getLogs`를 `CreditLedger` 기반으로 재작성 필요. 그 전엔 적립=`CreditLog`(구)·차감=`CreditLedger`(신) 분리 → 회계 단절 (HIGH-3) |
| `CreditReason` enum (`config.ts`) | `SIGNUP_BONUS`/`FIRST_WORK_BONUS`/`NOVEL_ANALYSIS` 등 | 신 시스템은 `reason` 문자열 직접 사용 — `CreditReason` enum과 신 `reason` 문자열 정합 정리 |

**폐기 의존 그래프**: `Author.credits` DROP ← (모든 적립·차감 신 경로 + 테마 차감 연동) ← `CreditLog` 폐기 ← (`getGiftRanking`/`getLogs` `CreditLedger` 재작성). → **DROP은 가장 마지막, 별도 sprint.**

---

## 3. V Phase 마이그레이션 `20260517_credit_overhaul_i_phase` 안전성 전수 (진단 항목 3)

> `prisma migrate status` 실측 (2026-05-18): localhost DB에 미적용 — `20260517_credit_overhaul_i_phase` 포함 5개 마이그레이션이 "not yet been applied". 즉 **dev/prod 어디에도 미적용** (S Phase §7 단계 6 dev migration이 다음 1순위라는 핸드오버와 정합).

### 3-1. [A] 스키마 변경 — 안전 (롤백 가능)

- `ALTER TABLE ADD COLUMN` (authors 5 / chat_messages 5) — 전부 `DEFAULT` 有 또는 nullable. 기존 row 안전.
- `CREATE TABLE` (credit_ledgers / membership_plans) + 인덱스 7 + FK 2 (Restrict) — 신규 테이블, 무손실.
- `ALTER COLUMN credits_charged SET DEFAULT 2440` — 기존 row 미변경(default만), 안전.
- DROP/비가역 DDL **0건** → 스키마 변경은 롤백 가능.

### 3-2. [B] 데이터 마이그레이션 — 결함 3건 + 검증 기준 오류 1건

#### 3-2-A. 🔴 검증 기준 결함 — 주석의 "credit_ledgers row=10"이 (b)만 셈, (c-2) 누락

`migration.sql:19` 주석:
```
→ 마이그레이션 후 기대: SUM(points_charged)=100000 / credit_ledgers row=10
```

이 "row=10"은 (b) INSERT(`credits > 0` 작가 1건씩 = dev 10건)만 센 값이다. 그러나 **(c-2) INSERT가 추가로 행을 박는다**:
```sql
-- (c-2) — pro/premium 작가마다 source='subscription' ledger 행 1건 추가
INSERT INTO "credit_ledgers" (...) SELECT ... FROM "authors" a WHERE a."plan" IN ('pro', 'premium');
```
→ 실제 `credit_ledgers` row = **(credits>0 작가 수) + (pro/premium 작가 수)**. dev에 pro/premium 작가가 1명이라도 있으면 10이 아니다. 검증 SQL을 이대로 돌리면 "10이어야 하는데 11" → **정상인데 롤백을 유발**하거나, 반대로 검증을 통과시키려 (c-2)를 빠뜨릴 위험.

**핵심 미측정**: `migration.sql:18`의 dev 측정값은 `authors 12 / SUM(credits)=100 / credits>0 작가=10`뿐 — **dev의 `Author.plan` 분포(free/pro/premium 각 몇 명)가 측정되지 않았다.** (c)·(c-2)·(c-3)가 전부 `plan` 분포에 의존하는데 그 입력이 없다.
- **필요 작업** (V Phase 단계 1 — dev migration 전 필수):
  ```sql
  SELECT plan, COUNT(*) FROM authors GROUP BY plan;
  SELECT DISTINCT credits_charged, COUNT(*) FROM analysis_reports GROUP BY credits_charged;
  ```
  → 측정 후 `migration.sql:16-19` 검증 주석을 `credit_ledgers row = (credits>0 작가) + (pro+premium 작가)`로 정정. 검증 SQL도 그에 맞게.
- **규모 S** (측정 + 주석 수정) — 단 측정 없이 dev migration 진행 금지 (§0 상태 추정 금지).

#### 3-2-B. 🟠 (d) `×610` 휴리스틱 — 정본에 없는 가정 (HIGH-2 확장)

`migration.sql:174-175`:
```sql
UPDATE "analysis_reports" SET "credits_charged" = "credits_charged" * 610
  WHERE "credits_charged" NOT IN (4, 3, 2440, 1830) AND "credits_charged" < 100;
```
- `×610`은 S Phase 정본(§7 단계 4 "단위 정정")에 **없는** 마이그레이션 작성자 휴리스틱. `2440/4 = 610`에서 역산한 값.
- 가정: `< 100`이면 정수 크레딧, `>= 100`이면 이미 pt. `analysis_reports`에 우연히 50~99 pt 값이 있으면 오염. `creditsCharged=0` row는 `0×610=0` (무해).
- **`migration.sql:18` dev 측정값에 `analysis_reports.creditsCharged` 분포 없음 → 미측정.**
- **필요 작업**: 3-2-A의 `SELECT DISTINCT credits_charged` 실측 → 4/3 외 값이 0건이면 (d) 3번째 UPDATE는 dead code → 삭제(단순화). 4/3 외 값이 있으면 명시적 매핑으로 교체.
- **규모 S** (측정 결과에 따라 SQL 1줄 삭제 또는 명시 매핑).

#### 3-2-C. 🟡 멱등성 — prisma migration은 1회성이나 (a)/(c-2) 자체가 비멱등

- (a) `UPDATE points_charged = credits * 1000 WHERE credits > 0` — 재실행 시 `points_charged`를 다시 `credits*1000`으로 덮음(누적 아님) → 사실상 멱등. 단 (a) 실행 후 신규 적립이 `points_charged`를 늘린 뒤 (a) 재실행하면 그 적립분이 날아감. **prisma `migrate deploy`는 1회만 적용**하므로 실무상 안전하나, 수동 재실행 절대 금지.
- (b)/(c)/(c-2) INSERT — 재실행 시 row 중복 생성(멱등 아님). 마찬가지로 prisma가 1회 보장.
- **결론**: prisma migration 프레임워크가 1회성을 보장하므로 운영상 안전. 단 "검증 실패 → 수동 SQL 재실행" 시 데이터 오염 → **롤백은 백업 복원으로만** (수동 UPDATE 재실행 금지) 운영 가드에 명시.

#### 3-2-D. 🟡 엣지케이스 — 5종 점검

| 엣지케이스 | 마이그레이션 동작 | 판정 |
|---|---|---|
| 음수 `credits` | `(a)`/`(b)` `WHERE credits > 0` → skip. 음수 작가는 `points_charged=0` | ✅ 안전 (구 `credits`가 음수일 일은 정상 운영상 없음) |
| `credits = 0` | `WHERE credits > 0` → skip. `points_charged=0` (DEFAULT) | ✅ 안전 |
| `plan` = null | `(c)` `CASE WHEN plan IN (...) ELSE 'free'` — null은 `IN` 매칭 실패 → 'free' 폴백. `(c-2)`/`(c-3)` `WHERE plan IN ('pro','premium')` → null skip | ✅ 안전 (폴백 정상) |
| `plan` = 예외값 (예: 'enterprise') | `(c)` ELSE 'free' 폴백 / `(c-2)`/`(c-3)` skip | ✅ 안전 — 단 의도적 폴백이므로 측정 시 예외 plan 존재하면 로그 권고 |
| 작가 0명 (빈 테이블) | 모든 UPDATE/INSERT 0 row 영향 | ✅ 안전 |
| `analysis_reports` 본문 컬럼 | (d)는 `credits_charged`만 — `results` Json(분석 결과)·작가 본문 무관 | ✅ 작가 본문 미접촉 |

→ 엣지케이스는 전반 안전. **유일한 실측 공백은 3-2-A(plan 분포) + 3-2-B(creditsCharged 분포).**

### 3-3. 마이그레이션 정합성 검증 — V Phase 단계 6 직후

`migration.sql:16-17`의 검증 SQL은 유지하되 3-2-A 반영:
```sql
SELECT SUM(points_charged) FROM authors;        -- = SUM(credits)*1000 (마이그레이션 전 스냅샷 대비)
SELECT COUNT(*) FROM credit_ledgers;            -- = (credits>0 작가) + (pro+premium 작가)  ← 정정
SELECT SUM(points_subscription) FROM authors;   -- = Σ(pro 93000 + premium 191500)          ← 추가 권고
```

### 3-4. 마이그레이션 안전성 종합

| 영역 | 판정 |
|---|---|
| [A] 스키마 (ADD COLUMN/CREATE TABLE/인덱스/FK) | ✅ 안전, 롤백 가능 (DROP 0건) |
| (a) credits×1000 환산 | ✅ 안전 (WHERE credits>0, 음수/0 skip) |
| (b) credit_ledgers 초기 row | ✅ 안전 |
| (c)/(c-2)/(c-3) MembershipPlan + 구독풀 | ⚠️ 동작은 정상, 단 **검증 주석 row 수 오산** + dev plan 분포 미측정 |
| (d) AnalysisReport 단위 정정 | 🟠 `×610` 휴리스틱 (정본 외) + dev 미측정 |
| 데이터 손실 위험 | (a)~(c)는 무손실. (d)만 미측정 데이터에 휴리스틱 적용 위험 |
| 롤백 | 백업(pg_dump) 복원으로만 — 수동 UPDATE 재실행 금지 (운영 가드 명문화 필요) |

---

## 4. CRITICAL-1 수정 범위 (진단 항목 4)

**문제 재확인** (`prisma-credit-ledger.repository.ts:193-220`): `getBalance`는 `Author` 4 캐시 필드 단순 합산. `CreditLedger.expiresAt < now()` 만료 row를 잔액에서 제외하는 SELECT 0건. 이월 금지가 `ResetMonthlyPoolJob` cron의 캐시 덮어쓰기에만 의존 → 설계 4-C("스키마가 강제, cron 버그로도 이월 불가")가 실제로는 4-A/4-B(cron 의존) 수준.

### 4-A. 수정 案 A — `getBalance`에서 만료 반영 (설계 4-C 복원)

`getBalance`의 `subscription` 부분을 캐시 대신 ledger 집계로:
```
pointsSubscription 대체 ← SELECT SUM(amount) FROM credit_ledgers
  WHERE author_id=$1 AND source='subscription'
  AND (expires_at IS NULL OR expires_at > now())
```
- **작업**: `getBalance`에 ledger 집계 쿼리 추가 (free/gift/charged는 캐시 유지, subscription만 ledger). `@@index([authorId, source])` + `@@index([expiresAt])` 이미 존재 → 인덱스 추가 불요.
- **부작용**: 캐시(`Author.pointsSubscription`)와 ledger 집계가 어긋날 수 있음 → 캐시-원장 정합 cron(`ReconciliationCheckpoint` 패턴) 필요. `spend`/`earn`이 `pointsSubscription` 캐시를 쓰는 부분과의 정합도 재검토(소진 우선순위 계산이 캐시 기반 — §1 `spend` `planConsumption`이 캐시 4필드 입력).
- **규모 M~L** — `getBalance`만이 아니라 `spend`의 `planConsumption` 입력(subscription 부분)도 만료 반영해야 일관. 그러지 않으면 "잔액 조회는 만료 반영, 차감은 캐시" 불일치.

### 4-B. 수정 案 B — 캐시 방식 공식화 + 안전망 강화

현 캐시 방식을 공식 결정으로 받되:
1. S Phase draft §4 게이트 4 / §15 매트릭스를 "이월 금지는 cron 의존(lazy 미구현)"으로 정정.
2. `reset-monthly-pool.job.ts:18` 주석이 "lazy 리셋은 I Phase 후속"이라 명시 — **lazy 안전망 구현**: `getBalance`/`getPlan` 호출 시 `poolResetAt < now()`면 즉시 `resetMonthlyPool` 호출. `MembershipPlanPort.getPlan`이 현재 호출처 0건이라, lazy 훅을 어디에 둘지 결정 필요(잔액 조회 경로 `CreditUseCase.getPointBalance`가 유력).
3. `sensor-subscription-pool-no-rollover.sh`는 **이미 존재**(`.claude/scripts/`) — 단 본 진단에서 sensor 등록(hook/settings.json) 확인 결과 **등록 grep 0건** → sensor가 작성만 되고 PostToolUse/pre-commit hook에 연결됐는지 미확인. harness 영역 — server sprint 외.
4. cron 실패 알람 강화 — `MONTHLY_POOL_RESET_DISABLED=1` 또는 cron 예외 시 알림.
- **규모 M** — lazy 안전망 구현이 핵심 작업.

### 4-C. CRITICAL-1 권고

案 B(cron + lazy 이중 안전망)가 S Phase draft §8-6 "cron + lazy 이중 안전망" 원래 설계와 정합 — draft가 이미 lazy를 설계했고 I Phase가 "후속"으로 미룬 것뿐. **案 B로 lazy 안전망 구현 + ADR-012에 "4-C 변형 — 캐시 + cron + lazy" 박제** 권고. 案 A(getBalance ledger 집계)는 `spend`까지 연쇄 수정이라 규모가 크고 캐시-원장 이중화의 정합 부담이 큼.
- **규모 M** (案 B 기준).

---

## 5. HIGH 항목 수정 범위 (진단 항목 5)

### 5-A. HIGH-1 — `Author.plan` ↔ `MembershipPlan.tier` 이중 출처

**근거 재확인**: `Author.plan String @default("free")` + `planExpireAt` 살아 있음(`schema.prisma:33-34`), `[DEPRECATED]` 표기 **없음**(L23-25 deprecated 주석은 `credits` 전용). `MembershipPlan.tier`도 별개 정본. 마이그레이션 (c)는 `Author.plan` → `tier` **복사**만, 동기 트리거·비움 없음.

- **현 호출처 미확인 → 부분 확인**: `theme-slot.usecase`/`plan.usecase`가 `Author.plan`을 읽는지 본 진단 시간 내 미열람. `membership-tier.ts`에 `MEMBERSHIP_THEME_SLOTS`/`MEMBERSHIP_DAILY_FREE_THEME`가 이미 있어 `tier` 정본화 기반은 마련됨.
- **수정 작업** (案 택1):
  - 案 (A): `Author.plan` 정본 유지, `MembershipPlan.tier` 미러 + 동기 트리거. — `changeTier` 시 `Author.plan`도 갱신. 기존 `Author.plan` 읽기 코드 무변경.
  - 案 (B): `MembershipPlan.tier` 정본화, `Author.plan` `[DEPRECATED]` + 읽기 경로(`theme-slot`/`plan` usecase)를 `MembershipPlanPort.getPlan` 경유로 이행.
- **선행 작업**: `grep -rn "\.plan\b" src/application src/adapter` 로 `Author.plan` 읽기 전수 → 案 결정. ADR-012 명문화.
- **규모 M** (案 B는 읽기 경로 이행 포함 → M 상단).

### 5-B. HIGH-3 — 적립=`CreditLog` / 차감=`CreditLedger` 원장 분리

**근거 재확인**: `ChargePointsUseCase`/`GrantPointsUseCase`/`PrismaCreditLedgerRepository`는 `CreditLedger`만 박제. 구 `CreditUseCase.grant/deduct/gift`는 `CreditLog`만(`adjustCredits` 내부). → 마이그레이션 후 적립(아직 구 경로)은 `credit_logs`, 차감(신 경로)은 `credit_ledgers`로 분리 → 작가 전체 이력을 한 테이블로 못 봄.

- **수정 작업**: CRITICAL-2 적립 연동(§1 T1·T2·T5·T4)이 완료되면 적립도 `CreditLedger`로 가므로 `CreditLog`는 자연히 빈 테이블화. **단 §2-3 지적대로 `getGiftRanking`/`getLogs`가 `CreditLog`에 의존** → 이 둘을 `CreditLedger` 기반으로 재작성해야 `CreditLog` 완전 폐기 가능.
  - `getLogs` → `CreditLedger.findByAuthor`로 교체 (이미 port에 `findByAuthor` 존재).
  - `getGiftRanking` → `CreditLedger`에서 `source='gift' AND type='earn'` 집계로 재작성.
- **규모 M** (적립 연동에 흡수되나 `getGiftRanking`/`getLogs` 재작성이 별도 작업).

### 5-C. HIGH-2 — 마이그레이션 (d) — §3-2-B에서 다룸 (규모 S).

### 5-D. 🟡 신규 MEDIUM — `refundAnalysis` 출처 오귀속

`charge-points.usecase.ts:155` `refundAnalysis`는 `earn({ source: 'charged', amount: 2440 })`로 환불. 그러나 원래 `chargeAnalysis`의 차감은 소진 우선순위상 무료적립→구독풀→응원선물→충전 순으로 나간다. 무료적립/구독풀에서 2,440pt가 나갔는데 환불은 전액 `charged`로 복원 → **출처 회계가 부정확**(무료적립이 충전으로 둔갑, CAC/COGS 분리 왜곡). 직전 audit 미발견 항목.
- **수정**: `spend`가 `spentBySource`를 반환하므로(이미 `SpendResult`에 있음), 분석 차감 시 `spentBySource`를 저장해 두고 환불 시 출처별 복원. 또는 `refundAnalysis`에 출처 인자 추가.
- **규모 S** — CRITICAL-2/MEDIUM 일괄 처리에 흡수.

---

## 6. `deficitPoints` 사후차감 / `settleDeficit` 흐름 완결성 (진단 항목 6)

### 6-1. 흐름 검증 — 로직은 완결, 호출처가 없음

| 단계 | 코드 | 판정 |
|---|---|---|
| 채팅 사후 차감 시 잔액 부족 → deficit 발생 | `spend` → `planConsumption.deficitIncurred` → `Author.deficitPoints += 부족분` + `CreditLedger(type='deficit_incur')` (`prisma-credit-ledger.repository.ts:164-183`) | ✅ 구현 정확 |
| deficit 상한 도달 시 신규 채팅 차단 | `isChatBlocked` → `isChatBlockedByDeficit(deficit, 10000)` (`charge-points.usecase.ts:116`, `chat.usecase.ts:71`) | ✅ 구현 + 연동 (chat usecase가 호출) |
| 충전 시 deficit 우선 상계 | `settleDeficit` → `settleDeficitOnCharge` → `Author.deficitPoints` 차감 + `CreditLedger(type='deficit_settle')` (`prisma-credit-ledger.repository.ts:222-262`) | ✅ 로직 정확 |
| `grantCharge`가 `settleDeficit` 호출 | `grant-points.usecase.ts:76` | ✅ usecase 내부 정확 |

### 6-2. 🔴 결정적 결함 — `settleDeficit`가 실제 충전 경로에서 호출되지 않음

`settleDeficit`를 부르는 유일한 코드는 `GrantPointsUseCase.grantCharge`(`grant-points.usecase.ts:76`). 그런데 **`grantCharge`는 호출처 0건**(CRITICAL-2). 실제 충전 경로 `payment.usecase.ts:334`는 구 `completePaymentAtomically`만 호출 → `grantCharge` 미경유 → `settleDeficit` 미경유.

**결론**: deficit 발생(채팅 차감)은 작동하나, **상계(충전)는 작동하지 않는다.** 시나리오:
1. 신규 작가 채팅 → 잔액 0 → `deficitPoints` 누적 → 10,000pt 도달 → `isChatBlocked=true` → 채팅 차단.
2. 작가가 충전 → `payment.usecase`가 구 경로 → `Author.credits`만 증가, `deficitPoints`·`pointsCharged` 불변.
3. `isChatBlocked`은 여전히 `deficitPoints >= 10000` → **충전해도 채팅 영구 차단.**

→ `settleDeficit` 흐름은 **미완결**. 완결 조건 = CRITICAL-2의 T3(충전 연동, §1-A) 해소. **별도 작업이 아니라 CRITICAL-2 T3에 완전히 흡수됨** — T3 완료 시 자동 완결.
- **규모**: 독립 S, 단 T3(L)에 흡수 → 추가 작업량 0.

### 6-3. MEDIUM-1 재확인 — `grantCharge` 트랜잭션 경계

`settleDeficit`($transaction #1) + `earn`($transaction #2) 분리 → 두 트랜잭션 사이 동시 차감이 끼면 `remainingCharge` stale. §1-A의 트랜잭션 재설계와 같은 작업 — T3에서 단일 `$transaction`으로 묶으면 동시 해소.

---

## 7. PAY-P1-4 (Polar 정기결제 → MembershipPlan 연동) (진단 항목 7)

### 7-1. 미착수 확정 (추정 아님 — 코드 실측)

| 확인 항목 | 결과 |
|---|---|
| Polar webhook이 `subscription.*` 이벤트 처리하는가? | 🔴 **명시적으로 무시.** `polar.adapter.ts:294-316`의 webhook type 화이트리스트 = `order.paid` / `order.updated` / `order.refunded` / `checkout.updated`만. `polar.adapter.spec.ts:328`에 **"처리 대상이 아닌 이벤트(subscription.created 등)는 null 반환"** 테스트가 명시적으로 존재 → 구독 webhook은 의도적으로 미처리. |
| `MembershipPlan.polarSubscriptionId` 사용처 | 🔴 필드만 존재(`schema.prisma:589` + `@unique`). `polarSubscriptionId`를 읽거나 쓰는 코드 0건 (grep). |
| `MembershipPlanPort.changeTier` 호출처 | 🔴 0건 — 구독 가입/변경/해지를 트리거하는 코드 없음. cron(`resetMonthlyPool`)만 `MembershipPlan`을 건드림. |
| 구독 결제 상품 (`CREDIT_PRODUCTS`) | 충전 패키지만. 구독(Pro ₩9,900/Premium ₩19,900) 상품 정의 0건. |

→ **PAY-P1-4는 미착수.** I Phase는 `MembershipPlan` 스키마 + 월 풀 cron만 만들었고, "사용자가 Pro 구독을 결제 → `MembershipPlan.tier='pro'` 생성/갱신 → 해지 시 'cancelled'" 연동은 전혀 없다. 마이그레이션 (c)가 `Author.plan` 초기값을 `tier`로 복사하므로 마이그레이션 시점 분포는 고정되나, **그 이후 누구도 구독을 시작/변경/해지할 수 없다.**

### 7-2. 필요 작업 추산

1. **Polar 구독 상품 등록** — Polar 대시보드에 Pro/Premium 구독 상품 생성 (Polar KYC/test mode 상태 종속 — infrastructure/사용자 영역).
2. **`polar.adapter.ts` webhook 확장** — `subscription.created`/`subscription.updated`/`subscription.canceled`/`subscription.revoked` 이벤트를 `NormalizedWebhookEvent`로 파싱. 화이트리스트 + spec(`polar.adapter.spec.ts:328`이 현재 "무시"를 테스트 → 수정 필요).
3. **구독 webhook usecase** — 신 메서드(`processSubscriptionWebhook` 등): `subscription.created`/`updated` → `MembershipPlanPort.changeTier(authorId, tier, now)` / `canceled`/`revoked` → `status='cancelled'` 또는 free 다운그레이드. `polarSubscriptionId` 매핑 저장.
4. **구독 시작 엔드포인트** — 작가가 Pro 구독을 시작하는 `POST /subscriptions/checkout` 류 (Polar Checkout — 정기결제 모드). `@UseGuards(JwtAuthGuard)` + `@Throttle`.
5. **멤버십 조회 엔드포인트** — `MembershipPlanPort.getPlan`을 HTTP 노출(`GET /membership` 등) — web 구독 플랜 페이지(S Phase §14 web Generator)가 의존. 현재 `getPlan` 호출처 0건.
6. **`changeTier` ↔ HIGH-1** — `changeTier`가 `Author.plan`도 동기화할지(HIGH-1 案 결정 종속).
7. **멱등성/원자성** — 구독 webhook도 `WebhookEvent` 멱등성 게이트 + `MembershipPlan` 변경 원자성. 정기결제 갱신(매월 Polar가 `order.paid` 재발행)과 `resetMonthlyPool` cron의 관계 정리 — 결제 갱신일과 풀 리셋일 정합.

- **규모 L** — 신규 엔드포인트 2개 + webhook 4 이벤트 + usecase 신설 + Polar 상품 등록 의존. 결제 도메인이라 보안 검토(`SECURITY.md` §3) 필수. **독립 sprint.**

### 7-3. PAY-P1-4 ↔ CRITICAL-1 상호작용

PAY-P1-4 미착수라 현재 신규 구독자가 0 → `MembershipPlan`은 마이그레이션 초기 row만 → cron 리셋 대상도 그 초기 분포 고정. CRITICAL-1(이월 금지 cron 의존)의 위험은 **PAY-P1-4 착수로 실제 구독자가 생기면 즉시 현실화**된다. 즉 PAY-P1-4와 CRITICAL-1은 같은 시점에 위험이 켜진다 → sprint 의존성: CRITICAL-1 수정이 PAY-P1-4보다 먼저거나 동시.

---

## 8. 종합 — 크레딧 개편 코어 완결 sprint 분할 (진단 항목 8)

크레딧 개편 코어를 "V Phase 적용 안전 + 기능 완결" 상태로 만드는 전체 작업을 논리적 sprint로 분할. 규모는 S(반나절)/M(1~2일)/L(3일+) 상대 추산.

### Sprint 분할

| Sprint | 범위 | 포함 작업 | 규모 | 선행 의존 |
|---|---|---|---|---|
| **CC-1** 적립 비결제 연동 | T1 가입 / T2 첫작품 / T5·T6 관리자 / T8·5-D 분석환불 출처 / 테마 차감 연동(§2-2) | `GrantPointsUseCase`를 `auth`/`work-management`/`admin` usecase에 DI + 호출 교체. 테마 차감 `chargeTheme` 연동 + 구 테마 차감 경로 확인. `refundAnalysis` 출처 정합. 각 spec 보강 + **통합 spec 신설**(CRITICAL-2가 단위 PASS에 가려진 근본 원인 — auth/work usecase가 `GrantPointsUseCase`를 부르는 통합 테스트) | **L** (트리거 5 + 테마 + 통합 spec) | 없음 (즉시 착수 가능) |
| **CC-2** 충전·선물·환불 결제 연동 | T3 충전(§1-A) / T4 선물(§1-B) / T7 환불(§1-C) / MEDIUM-1 `grantCharge` 트랜잭션 / MEDIUM-4 `Payment`·`RefundLog` pt 단위 / `settleDeficit` 완결(§6-2) | `PaymentRepositoryPort`에 "결제완료+deficit상계+적립" 단일 `$transaction` 메서드 신설. `CREDIT_PRODUCTS` 디노미 4종(§8-5) 개편. `CreditLedgerPort.transfer`(선물 원자) 신설. 환불 신 경로 + 이중 외상(`RefundLog.deficitCredits`↔`Author.deficitPoints`) 통합. 결제 보안 검토 | **L** | **CC-1** (적립 시스템이 먼저 안정화돼야 충전 적립을 그 위에 얹음). CC-1과 부분 병렬 가능하나 트랜잭션 통합은 CC-1 후 |
| **CC-3** 이월 금지 + 원장 단일화 | CRITICAL-1(§4 案 B lazy 안전망) / HIGH-1 이중 출처 ADR + 案 / HIGH-3 `getGiftRanking`·`getLogs` `CreditLedger` 재작성 / `Author.plan` 읽기 경로 이행 | lazy 리셋 훅(`getPointBalance` 경로). `Author.plan` 읽기 전수 grep → 案 결정 → ADR-012. `CreditLog` 의존 2 메서드 재작성 | **M** | CC-1 (적립이 `CreditLedger`로 가야 `CreditLog` 폐기 의미) |
| **CC-4** V Phase 마이그레이션 안전화 + 적용 | §3-2-A dev plan/creditsCharged 분포 측정 / §3-2-B (d) `×610` 단순화 또는 명시 매핑 / 검증 주석 정정 / dev migration apply + 검증 | dev `SELECT plan, COUNT(*)` + `SELECT DISTINCT credits_charged` 실측 → `migration.sql` 검증 주석·(d) 수정 → `크레딧개편 dev migration 진행` → 정합성 검증 SQL → dev 차감/적립 curl 검증 | **M** | **CC-1·CC-2·CC-3** (적립·차감·이월이 완결돼야 마이그레이션 후 시스템이 작동. 마이그레이션을 코드 완결 전 적용하면 신규 가입자 마비) |
| **CC-5** PAY-P1-4 Polar 구독 연동 | §7-2 1~7 — Polar 구독 상품 / `subscription.*` webhook / 구독 usecase / 구독 시작·멤버십 조회 엔드포인트 / 멱등성·원자성 | `polar.adapter` webhook 확장 + spec 수정. 구독 webhook usecase. `POST /subscriptions/checkout` + `GET /membership`. `MembershipPlanPort.changeTier` 연동 | **L** | **CC-3** (HIGH-1 `Author.plan`↔`tier` 정본 결정이 `changeTier` 동기화 설계의 선행). CC-4와 병렬 가능 |

### Sprint 의존 그래프

```
CC-1 (적립 비결제) ──┬──> CC-2 (결제 연동) ──┐
                     │                       ├──> CC-4 (마이그레이션 적용)
                     └──> CC-3 (이월+원장) ──┤
                                  │          
                                  └────────> CC-5 (PAY-P1-4 구독)   [CC-4와 병렬]
```

- **CC-1이 모든 것의 출발점** — 적립이 신 경로로 가야 나머지가 의미를 가짐. 즉시 착수 가능(외부 의존 0).
- **CC-4(마이그레이션 적용)는 반드시 CC-1·CC-2·CC-3 이후** — 코드가 완결되기 전 V Phase 마이그레이션을 적용하면 직전 audit CRITICAL-2 시나리오(신규 가입자 전 AI 마비)가 그대로 현실화. **이것이 본 진단의 가장 중요한 결론.**
- **CC-5(PAY-P1-4)는 CC-3 이후, CC-4와 병렬 가능** — 단 §7-3대로 CRITICAL-1(CC-3)이 PAY-P1-4보다 먼저거나 동시여야 실구독자 발생 시 이월 사고 차단.

### 대안 — 마이그레이션 범위 축소 (메인 판단용)

CC-1~CC-3 완결 전 V Phase 마이그레이션을 먼저 적용해야 한다면, S Phase draft §7도 언급한 "I Phase는 차감 전용 — 적립은 후속" 명시 박제 + **운영 가드 선행**이 필요:
- 마이그레이션 후 ~ CC-1 완료 전까지 **신규 가입 일시 차단** 또는 가입 시 구 `credits` 적립 유지(마이그레이션이 `credits` 컬럼 보존하므로 가능).
- 단 이는 "구·신 혼재"를 연장하는 것 → **권장하지 않음.** CC-1~CC-3 완결 후 CC-4 적용이 정공법.

---

## 9. 발견 심각도별 정리

| 심각도 | # | 발견 | 수정 sprint |
|---|---|---|---|
| 🔴 CRITICAL | C-2 | 적립 5경로(T1·T2·T5·T6·T4) + 테마 차감(T-신규) 신 시스템 미연동 — 마이그레이션 후 신규 가입자 전 AI 마비 | CC-1 + CC-2 |
| 🔴 CRITICAL | C-1 | `getBalance` 만료 미반영 — 이월 금지 cron 단일 의존 | CC-3 |
| 🔴 CRITICAL | C-6 | `settleDeficit` 실 충전 경로 미경유 → 충전해도 deficit 영구 → 채팅 영구 차단 (CRITICAL-2 T3에 흡수) | CC-2 |
| 🟠 HIGH | H-1 | `Author.plan`↔`MembershipPlan.tier` 이중 출처, `[DEPRECATED]` 미표기 | CC-3 |
| 🟠 HIGH | H-2 | 마이그레이션 (d) `×610` 휴리스틱 (정본 외) + dev 미측정 | CC-4 |
| 🟠 HIGH | H-3 | 적립=`CreditLog`/차감=`CreditLedger` 원장 분리 — `getGiftRanking`/`getLogs` 재작성 필요 | CC-1 + CC-3 |
| 🟠 HIGH | H-신규 | 마이그레이션 검증 주석 `credit_ledgers row=10` 오산 ((c-2) 누락) + dev plan 분포 미측정 | CC-4 |
| 🟡 MEDIUM | M-1 | `grantCharge` 트랜잭션 경계 분리 (settleDeficit/earn 별도 $transaction) | CC-2 |
| 🟡 MEDIUM | M-2 | `chargeAnalysis`/`chargeTheme` 사전검증↔spend TOCTOU + 관리자 차감 "deficit 불가 모드" 부재 | CC-1/CC-2 |
| 🟡 MEDIUM | M-4 | `Payment.credits`/`RefundLog.credits`·`deficitCredits` pt 단위 미정합 | CC-2 |
| 🟡 MEDIUM | M-신규 | `refundAnalysis` 출처 오귀속 (무료적립 차감분이 charged로 복원 → CAC/COGS 왜곡) | CC-1 |
| 🟢 LOW | L-1 | sensor 5종 — **파일은 존재**(`.claude/scripts/`), 단 hook 등록 미확인 (harness 영역) | harness 별도 |
| 🟢 LOW | L-3 | `CreditUseCase` 구·신 메서드 혼재 — 명명 혼선 | CC-1 후 정리 |

> 직전 audit LOW-1("sensor 5종 부재")은 **부분 정정**: sensor 5종(`sensor-credit-overhaul-recalc`/`-denomination`/`-source-accounting`/`-subscription-pool-no-rollover`/`-chat-charge-tier`)은 `.claude/scripts/`에 **이미 작성돼 존재**한다. 다만 PostToolUse/pre-commit hook에 등록됐는지는 본 진단 grep으로 0건 — harness 영역이라 server sprint 범위 외, "미확인"으로 표기.

---

## 10. 미확인 / 추가 측정 필요 (추정 금지 — 명시)

| 항목 | 미확인 사유 | 누가/언제 |
|---|---|---|
| dev `Author.plan` 분포 (free/pro/premium 각 수) | 본 진단은 코드 진단 — DB 미접속. (c)/(c-2)/(c-3) 검증의 필수 입력 | CC-4 — `SELECT plan, COUNT(*)` |
| dev `analysis_reports.credits_charged` 분포 | 동일 — (d) `×610` dead code 여부 판정 입력 | CC-4 — `SELECT DISTINCT credits_charged` |
| 테마 차감 구 경로 (`credits` 1 차감) 존재 여부 | `theme.usecase` 계열 파일 미열람 (`chargeTheme` 호출처 0건만 확인) | CC-1 착수 시 theme usecase Read |
| `theme-slot.usecase`/`plan.usecase`의 `Author.plan` 읽기 | HIGH-1 案 결정 입력 — 본 진단 시간 내 미열람 | CC-3 — `grep -rn "\.plan\b"` |
| sensor 5종 hook 등록 상태 | `.claude/scripts/`에 파일 존재 확인, settings.json/hook grep 0건 — harness 영역 | harness agent |
| Polar KYC / test mode 상태 | PAY-P1-4 구독 상품 등록 가부 종속 — 인프라/사용자 영역 | CC-5 착수 전 |

---

> 본 리포트는 순수 진단 — 코드 변경 0건, 빌드/테스트 미실행(직전 audit이 `npm run build` 무에러 + 269 it PASS 검증 완료). 작가 소설 본문 미접촉. `prisma migrate status`만 실측(읽기 전용). 모든 발견은 실제 파일 Read + grep 확인 기반, 미확인은 §10에 명시.
