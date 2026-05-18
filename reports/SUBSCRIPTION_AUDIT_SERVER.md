# 크레딧 개편 — 구독제(membership) server 구현 Audit

> 작성: 2026-05-18 / grimoire-server 개발자 에이전트 / **순수 audit — 코드 변경 0건**
> 대상 커밋: `1c99123`→`376ee04` (I Phase) + `1ba8c9f`→`9d0d2b7` (HTTP 노출 follow-up), `develop` 브랜치
> 설계 정본: `research/CREDIT_PRICING_OVERHAUL_PLAN.md` §8(v6) + `.claude/state/sprint-credit-overhaul-s-phase-draft.md`
> 검증 방식: 실제 파일 Read + `npm run build` + `npx jest`(크레딧/멤버십 관련 269 it). 추정 0건.

---

## 0. 종합 판정

| 영역 | 판정 |
|---|---|
| `MembershipPlan` 모델 (게이트 4-C) | ✅ 설계 일치 — 9 필드 전건 반영 |
| 월 포인트 풀 이월 금지 | ⚠️ **부분 보장** — ledger `expire` row는 박지만 `getBalance`는 캐시 단순 합산 (CRITICAL-1) |
| 월간 풀 리셋 cron | ✅ 존재 + 등록 + 작동 (`ResetMonthlyPoolJob`, `@Cron('0 0 4 * * *')`) |
| 채팅 4구간 차감 | ✅ 도메인/usecase 구현 정확 (3구간 회귀 없음) |
| 소진 우선순위 | ✅ 정확 (`credit-consumption-policy.ts`) |
| **신규 적립 경로 연동** | 🔴 **미연동** — `GrantPointsUseCase` 어디서도 호출 안 됨 (CRITICAL-2) |
| `Author.plan` vs `MembershipPlan` 이중 출처 | 🟠 정리 안 됨 — 둘 다 살아 있음 (HIGH-1, S Phase가 "I Phase 결정 항목"으로 명시) |
| 빌드 / 테스트 | ✅ `npm run build` 무에러 / 크레딧·멤버십 spec 269 it PASS |

**결론**: 스키마·도메인·차감 로직은 설계 정본에 충실하게 구현됨. 그러나 **I Phase는 "기능 완결" 상태가 아니다.** 신규 포인트 시스템(`CreditLedger`/`MembershipPlan`)이 스키마·차감 경로는 살아 있지만 **적립 경로(가입 보너스/충전/선물/구독 풀 초기 부여)가 런타임에 한 번도 호출되지 않는다.** 마이그레이션 초기 row를 제외하면 신규 작가는 포인트가 영원히 0이고, 채팅·분석·테마는 즉시 deficit(외상)에 빠진다. V Phase dev migration 전에 CRITICAL 2건 + HIGH 3건을 해소하거나, 최소한 "I Phase 미완 — 적립 연동은 후속 sprint" 임을 명시적으로 박제해야 한다.

---

## 1. CRITICAL

### CRITICAL-1 — 월 포인트 풀 이월 금지가 `getBalance`에서 구조적으로 보장되지 않는다

**근거**

게이트 4-C 설계 정본(S Phase draft §4 게이트 4):
> "`CreditLedger` row의 `expiresAt`이 곧 리셋 — **만료 row는 잔액 집계에서 제외** → 이월이 구조적으로 불가능."

§8-8 CRITICAL #2: "풀 이월 금지 — 무제한 이월 시 §0이 0.14×로 붕괴."

그러나 실제 잔액 집계 코드는 ledger의 `expiresAt`을 **전혀 보지 않는다**:

`grimoire-server/src/adapter/outbound/persistence/prisma-credit-ledger.repository.ts:193-220` (`getBalance`)
```ts
const author = await this.prisma.author.findUnique({
  where: { id: authorId },
  select: { pointsFree, pointsSubscription, pointsGift, pointsCharged, deficitPoints },
})
const total = author.pointsFree + author.pointsSubscription + author.pointsGift + author.pointsCharged
```

→ `getBalance`는 `Author` **캐시 4 필드의 단순 합산**이다. `CreditLedger`의 `expiresAt < now()` 필터링 SELECT가 코드 어디에도 없다 (grep `expiresAt`/`expires_at` 결과: ledger repo는 `earn` 시 INSERT, `findByAuthor` 시 단순 select뿐 — 만료 필터 0건).

이월 금지가 실제로 의존하는 것은 **`ResetMonthlyPoolJob` cron이 매월 `pointsSubscription`을 `monthlyPoolPoints`로 덮어쓰는 것**뿐이다 (`prisma-membership-plan.repository.ts:98-101`). 즉 설계가 "스키마가 강제 → cron 버그로도 이월 불가"라고 한 4-C의 핵심 안전성이 **실제로는 4-A/4-B 수준(cron 의존)으로 격하**되었다.

cron이 누락·실패·`MONTHLY_POOL_RESET_DISABLED=1`로 꺼지면 → `pointsSubscription` 캐시가 리셋 안 됨 → 풀이 무한 이월 → §8-8 CRITICAL #2 위반 → §0 0.14× 붕괴.

`CreditLedger`의 `expire` row(`prisma-membership-plan.repository.ts:62-72`)는 **회계 기록용으로만 박히고**, 잔액 계산에는 쓰이지 않는다. ledger 정본과 캐시가 어긋나도 잡아낼 SELECT 경로가 없다.

**심각도 CRITICAL 사유**: §8-8 CRITICAL #2 직격. S Phase draft §15가 "게이트 4-C 채택 시 이월이 코드 버그로도 불가능"이라고 명시한 것과 실제 구현이 불일치. 게다가 S Phase §10이 신설하기로 한 `sensor-subscription-pool-no-rollover.sh`("`expiresAt` 만료 row 잔액 집계 제외 검증")도 부재 — 회귀 차단 장치까지 없다.

**권고** (택1):
- (A) `getBalance`에서 `pointsSubscription` 부분만 `CreditLedger`의 `source='subscription' AND (expiresAt IS NULL OR expiresAt > now())` 합산으로 대체 → 설계 4-C 원래 의도(스키마 강제) 복원. 단 캐시-원장 정합 cron 필요.
- (B) 현 캐시 방식 유지를 공식 결정으로 받되, ① S Phase draft §4 게이트 4 / §15 매트릭스를 "이월 금지는 cron 의존(lazy 미구현)"으로 정정 ② `sensor-subscription-pool-no-rollover.sh` 신설 ③ cron 실패 알람 강화. ADR-012에 "4-C 변형 — 캐시 기반 리셋" 박제.
- 어느 쪽이든 **`ResetMonthlyPoolJob`의 lazy 안전망**(코드 주석이 "조회 시점 lazy 리셋 — I Phase 후속"이라 명시, `reset-monthly-pool.job.ts:18`)이 미구현임을 인지하고 V Phase 전 보강 권고.

---

### CRITICAL-2 — `GrantPointsUseCase`가 어디서도 호출되지 않는다 — 신규 포인트 적립 경로 전체 미연동

**근거**

`GrantPointsUseCase`(`grimoire-server/src/application/credit/grant-points.usecase.ts`)는 가입 보너스(`grantSignupBonus` 3,000pt), 첫 작품(`grantFirstWorkBonus` 2,000pt), 충전(`grantCharge` — Polar deficit 상계 포함), 선물 수령(`grantGift`), 운영자 수동(`grantManual`) — 5개 적립 메서드를 완비하고 있다.

그러나 grep 결과:
```
grep -rn "GrantPointsUseCase|grantSignupBonus|grantCharge|grantFirstWork" src/ (spec 제외)
→ src/app.module.ts:20  import ...
→ src/app.module.ts:143 GrantPointsUseCase,   ← provider 등록만
```

**`GrantPointsUseCase`는 app.module provider 배열에 등록만 되고, 어떤 usecase/controller도 주입·호출하지 않는다.** 다음이 전부 구 정수 `credits` 경로에 머물러 있다:

1. **가입 보너스** — `auth.usecase.ts`가 `grantSignupBonus`를 호출하지 않음. (가입 시 신규 작가는 `pointsFree=0`)
2. **첫 작품 보너스** — `work-management.usecase.ts`가 `grantFirstWorkBonus`를 호출하지 않음.
3. **충전 적립** — `payment.usecase.ts`는 여전히 `completePaymentAtomically(payment.id, authorId, payment.credits, ...)` 구 정수 경로만 사용 (`payment.usecase.ts:334`). `grantCharge`를 호출하지 않음 → **결제해도 `pointsCharged`가 안 늘어난다.** §8-4 "충전 시 deficit 우선 상계"도 작동 안 함.
4. **응원 선물** — `credit.usecase.ts:74` `gift()`는 `creditRepo.giftTransfer()` 구 정수 경로만 사용. `grantGift`(`source='gift'`) 호출 0건.

**연쇄 효과 (런타임 붕괴 시나리오)**:
- 마이그레이션 초기 row(`migration.sql` [B])를 제외하면, **마이그레이션 이후 신규 가입 작가는 `pointsFree/Subscription/Gift/Charged` 4 필드가 전부 0.**
- 채팅 차감(`ChargePointsUseCase.chargeChatTurn`)은 `ledger.spend()`로 흐름 → `planConsumption`이 4 출처 전부 0 → 전액 `deficitIncurred` → 첫 채팅부터 deficit 누적.
- deficit가 10,000pt(`DEFAULT_DEFICIT_LIMIT`) 도달 → `isChatBlocked` true → **충전으로만 해소 가능한데 충전해도(`grantCharge` 미호출) `pointsCharged`가 안 늘어 deficit 영구.** 채팅 영구 차단.
- 분석/테마(`chargeAnalysis`/`chargeTheme`)는 `balance.available < COST` → 즉시 `BadRequestException` → **신규 작가는 분석·테마 AI를 한 번도 못 씀** (구 무료 적립 3+2 크레딧도 신규 경로엔 안 들어옴).

**심각도 CRITICAL 사유**: §0 마진 문제가 아니라 **시스템이 작동 불가**다. 차감(spend)은 신규 ledger 경로, 적립(earn)은 구 `credits` 경로 — 두 시스템이 분리 운영되어 신규 작가의 포인트 잔액이 영구 0. V Phase dev migration을 이 상태로 적용하면 마이그레이션 직후 가입자부터 전 AI 기능 마비.

S Phase draft §9 jest 매트릭스가 `grant-points.usecase.spec.ts ≥8 it`을 요구했고 실제 11 it PASS — **usecase 단위 테스트는 통과하지만, 호출하는 쪽(auth/work/payment usecase)과의 통합이 0건.** 단위 PASS가 "연동 완료"를 의미하지 않는 전형 사례.

**권고**:
- V Phase 전 필수 — `auth.usecase`(가입), `work-management.usecase`(첫 작품), `payment.usecase`(충전 — `processWebhook` `$transaction` 내), `credit.usecase.gift`(선물 수령)에 `GrantPointsUseCase` 연동.
- 충전 연동 시 주의: `payment.usecase`의 `completePaymentAtomically`는 자체 `$transaction`을 가짐 — `grantCharge`(내부 `settleDeficit` + `earn` 각각 별도 `$transaction`)와 원자성 경계가 어긋난다. 결제 원자성(CLAUDE.md §9)을 깨지 않도록 트랜잭션 통합 설계 필요.
- 또는 본 audit 결과를 받아 "I Phase는 차감 경로만 — 적립 연동은 별도 sprint" 임을 명시적으로 박제하고 V Phase 범위를 차감 검증으로 한정. 단 그 경우 마이그레이션 후 신규 가입 차단 등 운영 가드가 선행돼야 함.

---

## 2. HIGH

### HIGH-1 — `Author.plan` vs `MembershipPlan.tier` 이중 출처 미정리 (둘 다 살아 있음)

**근거**: `schema.prisma:34` `Author.plan String @default("free")` + `planExpireAt` 가 그대로 살아 있고, 신설 `MembershipPlan.tier`(`schema.prisma:584`)도 별개 정본으로 존재.

- `Author.plan`은 `[DEPRECATED]` 표기 없음 (스키마 L23-25의 deprecated 주석은 `credits` 필드 전용 — `plan`엔 없음).
- `migration.sql` (c)는 `Author.plan` → `MembershipPlan.tier`를 **복사**할 뿐, `Author.plan`을 비우거나 동기 트리거를 두지 않음.
- `theme-slot.usecase` / `plan.usecase` 등 기존 코드는 여전히 `Author.plan`을 읽을 가능성 — `MembershipPlan.tier`와 어긋나면 테마 슬롯·일일 무료 횟수가 불일치.

S Phase draft가 §16-3에서 "`Author.plan`/`planExpireAt` — `MembershipPlan` 정본화 후 deprecated vs 미러 — **I Phase 결정 항목**"으로 명시했으나, I Phase 코드에 이 결정·구현 흔적이 없다. 즉 미해소 채로 I Phase 종료.

**심각도 HIGH 사유**: CLAUDE.md §0 ZERO-TOLERANCE "정책 무시·누락 금지" + 즉각적 데이터 불일치 위험. CRITICAL은 아님 — 구독 결제 연동(`MembershipPlan.tier` 갱신)이 별도 sprint라 현 시점 `tier`는 마이그레이션 초기값에 고정, 당장 불일치가 발생하진 않음.

**권고**: V Phase 전 결정 — (A) `Author.plan`을 정본 유지하고 `MembershipPlan.tier`를 미러로 + 동기 / (B) `MembershipPlan.tier`를 정본화하고 `Author.plan` `[DEPRECATED]` 박제 + 읽기 경로 이행. ADR-012에 명문화. `membership-tier.ts`에 이미 `MEMBERSHIP_THEME_SLOTS`/`MEMBERSHIP_DAILY_FREE_THEME`가 있어 (B)로의 이행 기반은 마련됨.

### HIGH-2 — 마이그레이션 (d) — `AnalysisReport.creditsCharged` 비례 환산이 데이터 손상 위험

**근거**: `migration.sql:172-175`
```sql
UPDATE "analysis_reports" SET "credits_charged" = 2440 WHERE "credits_charged" = 4;
UPDATE "analysis_reports" SET "credits_charged" = 1830 WHERE "credits_charged" = 3;
UPDATE "analysis_reports" SET "credits_charged" = "credits_charged" * 610
  WHERE "credits_charged" NOT IN (4, 3, 2440, 1830) AND "credits_charged" < 100;
```

문제점:
1. **재실행 비멱등**: 3번째 UPDATE는 `< 100` 범위 전부에 `×610`. 만약 과거 row에 `creditsCharged=4`가 아닌 다른 정수(예: 운영 중 변경된 값 5)가 있으면 `5×610=3050`. 그런데 prisma migration은 1회성이므로 재실행 위험은 낮으나, **이 UPDATE 자체가 "가정"에 의존** — `< 100`이면 정수 크레딧, `>= 100`이면 이미 pt라는 가정. `AnalysisReport`에 우연히 50~99 사이 pt 값(거의 없겠지만)이 있으면 오염.
2. **`creditsCharged=0` row**: `0`은 `4,3,2440,1830`에 없고 `< 100` → `0×610=0` (무해, 다행).
3. S Phase draft §7 단계 4는 (d)를 "`AnalysisReport.creditsCharged` 단위 정정"이라고만 했고, 비례 환산 `×610` 규칙은 마이그레이션 작성자가 추가한 것 — 정본에 없는 휴리스틱.

**심각도 HIGH 사유**: 작가 본문이 아닌 메타데이터라 §0 LETHAL은 아니나, 돈 직결 회계 컬럼. dev migration 전 실측 필요. S Phase draft §7 단계 1 dev 측정값(`authors 12 / chat_messages 22`)에는 `analysis_reports`의 `creditsCharged` 분포가 없음 — **미측정**.

**권고**: V Phase dev migration 전 `SELECT DISTINCT credits_charged, COUNT(*) FROM analysis_reports` 실측 → 4/3 외 값이 있으면 비례 환산 대신 명시적 매핑. 실측 0건이면 (d)의 3번째 UPDATE는 사실상 dead code → 단순화 권고.

### HIGH-3 — 신규 적립·차감 경로에 audit/CreditLog 박제 누락 (회계 단절)

**근거**: 구 시스템은 `CreditLog`(`schema.prisma:150`) + `AdminAuditLog`에 크레딧 이동을 박제. 신규 시스템은 `CreditLedger`에 박제. 그러나:
- `ChargePointsUseCase`/`GrantPointsUseCase`/`PrismaCreditLedgerRepository`는 `CreditLog`를 쓰지 않음 — `CreditLedger`만.
- 구 `CreditUseCase.deduct/grant/gift`는 `CreditLog`만 씀 — `CreditLedger` 안 씀.
- 즉 마이그레이션 이후 두 원장(`credit_logs` / `credit_ledgers`)이 **상호 단절** — 어느 한쪽만 봐서는 작가의 전체 크레딧 이력이 안 나옴.

CRITICAL-2가 해소되면(적립이 전부 신규 경로로) `CreditLog`는 자연히 빈 테이블이 되지만, **그 전까지는 적립=`CreditLog`, 차감=`CreditLedger`로 분리** → 분쟁 시 회계 역추적 불가.

**심각도 HIGH 사유**: §8-2 "분리 회계" 정본의 목적(CAC/COGS 분리, 분쟁 역추적)을 부분적으로 무력화. CRITICAL-2와 같은 뿌리(적립 미연동)지만, 해소 전 과도기 회계 일관성 문제로 별도 분류.

**권고**: CRITICAL-2 연동 시 `CreditLog` 사용 코드 정리 — (A) `CreditLog` deprecated 박제 후 `CreditLedger` 단일화 / (B) `CreditLedger` 작성 시 `CreditLog`도 미러. shared-contracts §30에 결정 박제.

---

## 3. MEDIUM

### MEDIUM-1 — `settleDeficit` + `grantCharge`의 deficit 이중 상계 가능성 (트랜잭션 경계 분리)

**근거**: `GrantPointsUseCase.grantCharge`(`grant-points.usecase.ts:66-100`):
```ts
const settledDeficit = await this.ledger.settleDeficit(authorId, totalPoints)   // $transaction #1
const { remainingCharge } = settleDeficitOnCharge(totalPoints, settledDeficit)  // 순수 계산
if (remainingCharge > 0) { await this.ledger.earn({ ..., amount: remainingCharge }) }  // $transaction #2
```

`settleDeficit`(repo, `prisma-credit-ledger.repository.ts:222`)와 `earn`이 **각각 별도 `$transaction`**. 두 트랜잭션 사이에 다른 요청(또 다른 충전, 또는 채팅 차감)이 끼면:
- `settleDeficit` 후 `earn` 전, 동시에 채팅 차감이 deficit를 늘림 → `remainingCharge` 계산이 이미 stale → 외상이 새로 생긴 만큼 `earn`이 과다 적립될 수 있음.
- `grantCharge`가 동시 2회 호출되면 `settleDeficit`가 각각 FOR UPDATE로 직렬화는 되나, 사이의 `earn`까지 한 단위로 묶이지 않아 중간 상태 노출.

CRITICAL-2 때문에 `grantCharge`가 현재 호출 안 되므로 **지금 당장 발생하진 않음** → MEDIUM. CRITICAL-2 해소 시 같이 처리 필요.

**권고**: `grantCharge` 전체(`settleDeficit` + `earn`)를 단일 `$transaction`으로 묶거나, `CreditLedgerPort`에 "충전 = 상계+적립 원자 처리" 단일 메서드 신설.

### MEDIUM-2 — `chargeAnalysis`/`chargeTheme`의 사전 잔액 검증과 `spend`가 별도 트랜잭션 — TOCTOU

**근거**: `charge-points.usecase.ts:132-152` (`chargeAnalysis`):
```ts
const balance = await this.ledger.getBalance(authorId)        // 읽기 (트랜잭션 밖)
if (balance.available < ANALYSIS_POINT_COST) throw ...
const result = await this.ledger.spend({ ... })               // $transaction
```

`getBalance`(검증)와 `spend`(차감)가 분리 → Time-Of-Check-To-Time-Of-Use 갭. 두 호출 사이 다른 차감이 끼면 검증 통과해도 `spend`에서 deficit 발생. 코드 주석(`:145-151`)도 "동시성으로 발생 가능 시 방어적 로그"라고 인지하고는 있음 — `spend`는 어차피 `planConsumption`이 부족분을 deficit로 처리하므로 데이터 깨짐은 없음. 다만 "사전 차감 → 잔액 부족 시 거부"라는 §8-4 설계 의도(분석은 deficit 불가)가 동시성 하에 깨져 deficit가 생길 수 있음.

**심각도 MEDIUM 사유**: 데이터 정합은 유지(ledger가 deficit 흡수). 설계 의도(분석 deficit 0)와의 미세 불일치 + 동시성 희귀 케이스.

**권고**: `spend`에 "deficit 허용 안 함 → 부족 시 throw" 모드 파라미터 추가, 또는 `spend` `$transaction` 내 FOR UPDATE 직후 `available` 재검증.

### MEDIUM-3 — `MembershipPlanPort.getPlan` 시그니처 — draft 문서 ↔ 코드 불일치 (코드가 정답)

**근거**: S Phase draft §11 §30 코드 블록은 `getPlan(authorId): Promise<MembershipPlanState>` (non-null). 실제 `membership-plan.port.ts:35` + `prisma-membership-plan.repository.ts:29`는 둘 다 `Promise<MembershipPlanState | null>`. **port와 adapter는 서로 일치** — 문제는 draft 문서가 stale. 

`getPlan`이 `null`을 반환할 수 있는데(마이그레이션 누락 작가) 이를 호출하는 코드가 현재 없음 — `plan.controller`는 `PlanUseCase.getPlanInfo`(별개)를 씀. `MembershipPlanPort.getPlan`은 **호출처 0건** (사실상 미사용 — `findPlansToReset`/`resetMonthlyPool`/`changeTier`만 cron이 사용).

**심각도 MEDIUM 사유**: 코드는 정합. shared-contracts/draft 문서 동기화 누락 — 책 Ch 16 인터페이스 불일치 리스크.

**권고**: `.claude/state/sprint-credit-overhaul-s-phase-draft.md` §11 §30의 `getPlan` 시그니처를 `| null`로 정정 (또는 shared-contracts.md §30이 이미 정합이면 draft만). `changeTier`도 §30 블록에 누락 — 추가 권고.

### MEDIUM-4 — `Payment.credits` / `RefundLog.credits`/`deficitCredits` pt 단위 미정합

**근거**: `schema.prisma:262` `Payment.credits Int`, `:531-532` `RefundLog.credits/deficitCredits Int` — 전부 구 정수 크레딧 의미 그대로. S Phase draft §6 #9·#10 + §16-3이 "pt 단위 정합 검토 — I Phase 결정 항목"으로 명시했으나 I Phase 미반영. `payment.usecase`가 구 경로라(CRITICAL-2) 현재 일관은 하나, CRITICAL-2 해소 시 `Payment.credits`(정수 패키지 수량?)와 `pointsCharged`(pt) 단위가 충돌.

**권고**: CRITICAL-2 충전 연동과 함께 결정 — `Payment.credits`를 pt로 재해석할지, 별도 `points` 컬럼을 둘지. `RefundLog`도 환불 시 pt 차감 정합 필요.

---

## 4. LOW

### LOW-1 — `sensor-credit-overhaul-recalc.sh` 등 S Phase §10 sensor 5종 부재

S Phase draft §10이 신설 설계한 sensor 5종(`sensor-credit-overhaul-recalc` / `-denomination` / `-source-accounting` / `-subscription-pool-no-rollover` / `-chat-charge-tier`)이 I Phase에 작성되지 않았다. §8-8 CRITICAL #5("재산정 트리거 sensor 반드시 연동")와 직결 — 특히 `-subscription-pool-no-rollover`는 CRITICAL-1 회귀 차단 장치. draft가 "sensor 작성은 I Phase(harness/server)"라 했으므로 I Phase 범위였으나 누락. **심각도 LOW로 둔 이유**: 기능 동작엔 영향 없음(검증 자동화 부재일 뿐). 단 CRITICAL-1과 묶어 보면 우선순위 상향 여지.

### LOW-2 — `regression-74~77` eval task 부재

S Phase draft §13이 설계한 크레딧 개편 eval regression 4종 미작성. category `cost_zero` (EDD threshold 0.95+). I Phase 범위였음. 기능 영향 없음 — 회귀 검증 공백.

### LOW-3 — `credit.usecase.ts`의 구 메서드와 신규 시스템 혼재 — 명명 혼선

`CreditUseCase`(구 정수 `deduct`/`grant`/`gift`/`getBalance`)와 `ChargePointsUseCase`/`GrantPointsUseCase`(신규 pt)가 공존. `CreditUseCase.getBalance`는 `author.credits`(구 정수) 반환, `getPointBalance`는 `CreditBalance`(신규) 반환 — 같은 클래스 안에 두 단위. CRITICAL-2 해소 후 구 메서드 deprecated 정리 필요. 현재는 동작 영향 없음.

### LOW-4 — 현행 `Subscription`(팔로우) ↔ `MembershipPlan` 코드 혼선 — **없음 (양호)**

질문 8 확인 결과: `Subscription`(독자→작가 팔로우)과 `MembershipPlan`(멤버십)이 코드에서 교차 참조되거나 혼동된 흔적 **0건**. `MembershipPlan` 신규 코드는 전부 `membership` 명명, `Subscription`은 reader/social 도메인에 격리. `schema.prisma:571` 주석도 명시적으로 구분. 명명 분리 결정(`MembershipPlan`)이 의도대로 작동 — 설계 성공 사례로 기록.

---

## 5. 질문별 직접 답변

| # | 질문 | 답변 |
|---|------|------|
| 1 | `MembershipPlan`이 게이트 4-C 설계와 일치? | ✅ **일치.** 9 필드(`authorId/tier/monthlyPoolPoints/poolBalance/poolResetAt/startedAt/expiresAt/polarSubscriptionId?/status`) 전건 반영 (`schema.prisma:580-599`). 누락·이름변경 없음. 인덱스 3종(`authorId`/`poolResetAt`/`status`) + FK Restrict도 §6 매트릭스 일치. |
| 2 | 월 풀이 `CreditLedger`(`source='subscription'`+`expiresAt`) 방식인가, `poolBalance`로 deviate? | **혼합 — 부분 deviate.** ledger에 `source='subscription'` + `expiresAt` row는 박는다(`prisma-membership-plan.repository.ts:75-87`). 그러나 **실제 잔액 집계(`getBalance`)는 `Author.pointsSubscription` 캐시 단순 합산** — ledger `expiresAt`을 안 봄. → 이월 금지 보장이 cron 의존으로 격하. **CRITICAL-1.** |
| 3 | 월간 풀 리셋 cron이 존재·등록·작동? | ✅ **존재 + 등록 + 작동.** `ResetMonthlyPoolJob` (`reset-monthly-pool.job.ts`), `@Cron('0 0 4 * * *')` 매일 4시. `app.module.ts:107` `ScheduleModule.forRoot()` + `:144` provider 등록. `findPlansToReset`(poolResetAt 경과 + active + pro/premium)로 대상 선별, `resetMonthlyPool` 호출. spec 7 it PASS(동시실행 차단/실패 격리/disabled 게이트 검증). **cron 자체는 CRITICAL 아님.** 단 cron이 이월 금지의 *유일한* 안전장치라는 점이 CRITICAL-1. lazy 안전망은 미구현(주석상 "I Phase 후속"). |
| 4 | 이월 금지가 코드/스키마로 강제? 만료 row가 잔액 SELECT에서 제외? | 🔴 **아니오.** `getBalance`는 캐시 합산 — `expiresAt` 만료 row 제외 SELECT 없음. 이월 금지는 cron의 캐시 덮어쓰기에만 의존. **CRITICAL-1.** |
| 5 | 소진 우선순위(무료적립→구독풀→응원선물→충전)가 구현·정확? | ✅ **정확.** `credit-source.ts:32` `CREDIT_CONSUMPTION_ORDER = ['free','subscription','gift','charged']`. `credit-consumption-policy.ts:54` `planConsumption`이 이 순서로 차감, 부족분 `deficitIncurred`. 충전 시 deficit 우선 상계(`settleDeficitOnCharge`)도 §8-4 일치. spec 21 it PASS. |
| 6 | `MembershipPlanPort`가 HTTP로 노출? | **노출 안 됨 (추정대로).** 멤버십 전용 컨트롤러/엔드포인트 0건. `credit.controller.ts`는 `gift`/`ranking`/`balance`/`logs`만 — 멤버십 등급 조회/변경 엔드포인트 없음. `MembershipPlanPort.getPlan` 호출처도 0건(MEDIUM-3). **영향 평가**: 구독 결제 연동이 별도 sprint(PAY-P1-4)이므로 I Phase 시점엔 정상 — 사용자가 멤버십을 조회·변경할 HTTP 경로가 아직 불필요. 단 web이 구독 플랜 페이지를 만들려면(S Phase §14 web Generator 범위) 멤버십 조회 엔드포인트가 후속 필요. |
| 7 | `Author.plan` vs `MembershipPlan` 이중 출처 정리? | 🟠 **정리 안 됨 — 둘 다 살아 있음.** `Author.plan`에 `[DEPRECATED]` 표기 없음, 동기 트리거 없음. S Phase가 "I Phase 결정 항목"이라 했으나 미반영. **HIGH-1.** 당장 불일치는 없음(구독 결제 연동 전이라 `tier` 고정). |
| 8 | `Subscription`(팔로우)와 `MembershipPlan` 코드 혼선? | ✅ **혼선 없음.** 교차 참조 0건. 명명 분리(`MembershipPlan`)가 의도대로 작동. **LOW-4 (양호).** |
| 9 | 마이그레이션 `20260517_credit_overhaul_i_phase` 위험 요소? | `WHERE credits > 0` 분기는 정상(잔액 없는 작가 skip). 음수 크레딧 처리: 구 `credits`가 음수일 일은 없으나 `WHERE credits > 0`이라 음수면 skip — 안전. 비가역 DDL: `ADD COLUMN` only, DROP 없음 — 롤백 가능. **위험은 (d) `AnalysisReport.creditsCharged` 비례 환산 `×610`** (정본에 없는 휴리스틱, dev 미측정) — **HIGH-2.** `Author.credits` 컬럼은 보존(deprecated) — §7 단계 정합. 데이터 손실: (a)~(c)는 무손실, (d)만 주의. |
| 10 | 구독 풀 차감 트랜잭션 안전성? | `PrismaCreditLedgerRepository.spend`/`earn`/`settleDeficit`는 전부 `$transaction` + `SELECT ... FOR UPDATE`로 같은 작가 row 직렬화 — **단일 작가 동시 차감은 안전.** 정수 오버/언더플로우: 포인트가 Int(32bit, ~21억) — 정상 운영 범위 안전. null 처리: `getBalance`가 `findUnique` null 시 throw. **위험은 `grantCharge`의 트랜잭션 경계 분리(MEDIUM-1)** + `chargeAnalysis`/`chargeTheme`의 TOCTOU(MEDIUM-2) — 둘 다 데이터 깨짐은 없고 설계 의도 미세 불일치 수준. `spend` 자체의 race condition 없음. |
| 11 | jest spec 커버리지 — 누락 영역? | 크레딧·멤버십 spec **269 it 전부 PASS** (도메인 13~23 it/파일, charge-points 16, grant-points 11, reset-monthly-pool 7, ledger repo 11, membership repo 8 등). chat.usecase는 4구간 차감 연동 it 보유. **누락 영역**: ① **통합 테스트 0건** — `GrantPointsUseCase`가 auth/work/payment usecase와 연동되는 spec 없음(CRITICAL-2가 단위 PASS에 가려진 이유) ② 이월 금지를 `getBalance` 레벨에서 검증하는 spec 없음(CRITICAL-1) ③ 마이그레이션 검증 spec(§9 매트릭스 "≥4 it") — `credit-migration.spec.ts` 11 it 존재하나 실DB 마이그레이션 정합(`SUM(points_charged)=SUM(credits)×1000`)은 V Phase dev 검증 영역. |

---

## 6. 검증 실행 결과 (raw)

### 6-1. `npm run build`
```
> grimoire-server@0.1.0 build
> nest build
```
→ 무에러 (exit 0).

### 6-2. `npx jest` — 크레딧/멤버십 관련
```
PASS src/adapter/outbound/persistence/prisma-credit-ledger.repository.spec.ts
PASS src/domain/policy/credit-consumption-policy.spec.ts
PASS src/domain/model/credit-point.spec.ts
PASS src/domain/model/membership-tier.spec.ts
PASS src/domain/model/credit-migration.spec.ts
PASS src/domain/model/chat-charge-tier.spec.ts
PASS src/domain/model/credit-system-setting.spec.ts
PASS src/application/credit/grant-points.usecase.spec.ts
PASS src/domain/model/credit-source.spec.ts
PASS src/application/credit/charge-points.usecase.spec.ts
PASS src/adapter/outbound/persistence/prisma-membership-plan.repository.spec.ts
PASS src/application/subscription/reset-monthly-pool.job.spec.ts
PASS src/application/credit/credit.usecase.spec.ts
PASS src/adapter/inbound/http/controller/credit.controller.spec.ts

Test Suites: 14 passed, 14 total
Tests:       163 passed, 163 total
```
+ chat.usecase / novel-analysis / payment.usecase:
```
Test Suites: 4 passed, 4 total
Tests:       106 passed, 106 total
```
→ 크레딧 개편 관련 합계 **269 it PASS, 0 fail.**

### 6-3. 핵심 grep
```
GrantPointsUseCase 사용처 (spec 제외): app.module.ts (import + provider 등록) 2건 — 호출 0건
ChargePointsUseCase 사용처: chat.usecase / novel-analysis.usecase / app.module — 연동됨
getBalance expiresAt 필터: 0건 (ledger repo는 earn 시 INSERT만)
Subscription ↔ MembershipPlan 교차참조: 0건
```

---

## 7. V Phase 진입 전 권고 (우선순위)

1. **CRITICAL-2** — `GrantPointsUseCase` 적립 연동(가입/첫작품/충전/선물). 미해소 시 V Phase dev migration 직후 신규 가입자 전 AI 기능 마비. 또는 "I Phase 차감 전용 — 적립은 후속 sprint" 명시 박제 + 신규 가입 가드.
2. **CRITICAL-1** — 이월 금지를 `getBalance`에서 강제하거나(설계 4-C 복원), cron 의존을 공식 결정으로 받고 문서 정정 + `sensor-subscription-pool-no-rollover.sh` 신설 + lazy 안전망 구현.
3. **HIGH-1** — `Author.plan` vs `MembershipPlan.tier` 정본 결정 + ADR-012 박제.
4. **HIGH-2** — `analysis_reports.credits_charged` dev 실측 → 마이그레이션 (d) 비례 환산 단순화/명시화.
5. **HIGH-3 / MEDIUM-1·2·4** — CRITICAL-2 적립 연동과 함께 일괄 처리(회계 단절, 트랜잭션 경계, Payment 단위).
6. **MEDIUM-3 / LOW-1·2** — 문서 동기화(draft §11 §30) + sensor/eval 신설.

> 본 리포트는 순수 audit — 코드 변경 0건. 빌드·테스트는 audit 대상 코드의 현 상태 검증 목적으로만 실행(파일 수정 없음).
