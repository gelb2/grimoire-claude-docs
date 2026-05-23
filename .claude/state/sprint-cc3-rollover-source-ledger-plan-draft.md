# 작업 계획: CC-3 — 이월 금지 안전망 + Author.plan 이중 출처 + 원장 단일화 (writing-plans)

> 작성: 2026-05-20 / grimoire-planner (Initializer 패턴) / **계획 수립 전용 — 코드 변경 0건**
> 근거 정본: `reports/CREDIT_CORE_DIAGNOSIS.md` §4 (CRITICAL-1 案 A/B), §5-A (HIGH-1 案 A/B), §5-B (HIGH-3), §8 Sprint 분할표 CC-3 행, §10 미확인 + LOW-1 sensor hook
>           + `.claude/state/sprint-cc2b-gift-refund-wiring-plan-draft.md` §10-4 (CC-3 핸드오프) + §11 종결 게이트
>           + `.claude/state/sprint-credit-overhaul-s-phase-draft.md` 게이트 4 (이월 금지) / §15 매트릭스 / §16-3
>           + `.claude/shared-contracts.md` §30 CreditOverhaul (line 2391~)
> 적용 양식: `.claude/skills/writing-plans/SKILL.md` (2~5분 sub-task / [MUST]·[SHOULD]·[NICE] / 위험도 🔴🟡🟢 / 의존 / rollback / 검증 게이트)
> 구조 정본: `.claude/state/sprint-cc1-pay-s1-plan-draft.md` + `sprint-cc2a-charge-wiring-plan-draft.md` + `sprint-cc2b-gift-refund-wiring-plan-draft.md` — 동일 섹션 구조·포맷
> 범위: **CC-3만** (CRITICAL-1 lazy 안전망 + HIGH-1 Author.plan 정리 + HIGH-3 getGiftRanking/getLogs 원장 단일화). **CC-4 V Phase 마이그레이션 / CC-5 PAY-P1-4 Polar 구독은 범위 외** — 착수 직전 상세화 원칙.

---

## 0. 진행 순서 + 의존 개요

```
CC-1 (적립 비결제 — 완료·qa검증) ──선행 완료──┐
CC-2a (충전 결제 — 완료·qa검증) ───────────────┤
CC-2b (선물·환불 결제 — 완료·qa검증) ──────────┼──> CC-3 (이월 금지 + 출처 원장 단일화)
                                              │      │
   PAY-S1 (로컬 DB — credit_overhaul_i_phase) ─┘      ├─ S0 선행: §10 미확인 + CC-3 직접 코드 5건 Read 해소
                                                      │
              CRITICAL-1 lazy 안전망 (cron + lazy) ─┐
              HIGH-1 Author.plan ↔ tier 정리 ───────┤
              HIGH-3 getGiftRanking/getLogs 원장 ──┴─> 통합 spec → CC-3 종결 + CC-4 마이그레이션 진입 자격
```

- **CC-1·CC-2a·CC-2b 선행 완료** — CRITICAL-2(적립 8경로 미연동) 완전 종결. CC-3는 잔존 결함 3건(CRITICAL-1·HIGH-1·HIGH-3) 해소가 목적.
- **CC-2b가 직접 유발한 HIGH-3가 CC-3의 1순위 해소 대상** — CC-2b가 선물 적립을 `CreditLedger` `source='gift'`로 이행하면서 구 `getGiftRanking`(`CreditLog` `reason: { startsWith: 'gift_received' }` groupBy)이 신 선물을 못 본다. CC-2b §10-4가 이를 명시 핸드오프 → CC-3 필수.
- **CRITICAL-1 lazy 안전망**이 CC-3의 단일 최대 안전성 게이트 — `getBalance`가 `Author.pointsSubscription` 캐시 단순 합산이라 만료 row 미반영. S Phase draft §4 게이트 4-C 원안("스키마가 강제, cron 버그로도 이월 불가")으로 복원하려면 lazy 리셋 훅 필수.
- **HIGH-1 Author.plan**은 案 결정 + S0 grep 결과에 의해 案 A(plan 정본 유지) 또는 案 B(tier 정본화) 분기 — 영향 범위가 사용자 결정 수준이면 §6 게이트로 회부.
- **PAY-S1 로컬 DB 동기화는 DB 전제** — CC-1/CC-2a/CC-2b 진입 시점에 이미 충족. CC-3 통합 spec이 신 스키마 + ledger expire 시뮬레이션을 전제.
- **S0 선행 게이트** — 진단 §10 + 본 sprint 직접 관련 5건(① `Author.plan` 읽기 grep ② `MembershipPlanPort.getPlan` 호출처 ③ `credit.usecase.getGiftRanking/getLogs` + `prisma-credit.repository` 의존 ④ `reset-monthly-pool.job` lazy 안전망 부재 주석 ⑤ sensor 5종 파일 + hook 등록)을 **S0 sub-task에서 Read로 해소**한 뒤 본 작업 진입.

### 예상 총 시간

- CC-3: **규모 M** — 본 계획 sub-task 합산 ~5~7h.
- sub-task 총 **27개** (S0 5 + CRITICAL-1 lazy 설계결정 1 + lazy 구현 5 + HIGH-1 설계결정 1 + HIGH-1 案 A 구현 4 (案 B 시 +3) + HIGH-3 재작성 4 + 통합 spec 3 + sensor 등록 권고 1 + 마무리 4).
- **분할 근거**: ≥30분 + **회계 정합 + 이월 금지 안전성**(§8-8 CRITICAL #2 "이월 금지" + §0 0.14× 붕괴 방어) + HIGH-3는 CC-2b가 유발한 신·구 분열을 해소(`CreditLog` 폐기 직전 단계) + HIGH-1은 `Author.plan` 읽기 7곳(theme-slot/plan/admin/generate-theme/get-theme/theme-slot.spec/plan.spec)의 정합 — 1줄 실수가 "이월 무한 발생" / "선물 랭킹 누락" / "tier-plan 불일치 → 풀 크기 오류"로 직결 → sub-task 단위 검증 게이트 + git commit 단위 rollback.

---

## 1. S0 — 선행: §10 미확인 + CC-3 직접 코드 현행 해소 (착수 게이트)

> CREDIT_CORE_DIAGNOSIS §10 + §4·§5 — 추정 금지. §4·§5가 file:line만 제시 → 본 sub-task로 코드 현행을 Read 해소한 뒤 설계 결정(L1a·H1a) 진입.
> ⚠️ 본 계획은 진단 리포트(2026-05-18 `658b7d9`) + 본 계획 작성 중 grep 결과(2026-05-20)를 인용하나, CC-2b 머지 후 변동 가능성 존재 → S0가 **현행 재실측**.

### 1-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| S0a | `Author.plan` 읽기 전수 grep 재실측 — `grep -rn "author\.plan\|\.plan\b" src/application src/adapter` 결과의 호출처 7곳(theme-slot.usecase 5건 + generate-theme.usecase 3건 + get-theme.usecase 2건 + plan.usecase 2건 + admin.usecase + theme/spec 2건) 확정. HIGH-1 案 B 채택 시 이행 대상 목록 = S0a 결과 | [MUST] | 🟢 | 5분 | PAY-S1 P5 + CC-2b 완료 | `Author.plan` 읽기 호출처 file:line 표 확정 (H1a 분기 입력) |
| S0b | `MembershipPlanPort.getPlan` 호출처 grep 재실측 — `grep -rn "MembershipPlanPort\|membershipRepo\.getPlan\|getPlan" src` 결과. 현재 진단 §2-2 "호출처 0건". HIGH-1 案 B 시 신설할 진입점 후보(theme-slot/plan usecase 읽기 경로) 명시 | [MUST] | 🟢 | 5분 | - | `getPlan` 호출처 0건 또는 N건 박제 + 案 B 진입점 후보 명시 |
| S0c | `credit.usecase.getGiftRanking`/`getLogs` + `prisma-credit.repository` 현행 Read — `getGiftRanking`(`CreditLog.groupBy {reason: {startsWith: 'gift_received'}, _sum: amount}`) + `findLogsByAuthorId`(`CreditLog.findMany orderBy: createdAt desc`) 본문 + 반환 타입(`{authorId, totalGifted}[]` / `CreditLog[]`) 확정. **HIGH-3 재작성 시 동등성 게이트** | [MUST] | 🟢 | 5분 | - | `getGiftRanking`/`findLogsByAuthorId` 본문 + 반환 타입 박제 (H3 재작성 입력) |
| S0d | `reset-monthly-pool.job.ts` + `prisma-membership-plan.repository` Read — cron 본문(L40 `@Cron('0 0 4 * * *')` + L42 `MONTHLY_POOL_RESET_DISABLED` 게이트 + L82 `findPlansToReset` 후 `resetMonthlyPool` 순회) + `resetMonthlyPool` 트랜잭션 내부($transaction: ledger expire + 신규 earn + plan `poolBalance`/`poolResetAt` + Author 캐시) 확정. **lazy 안전망 진입점이 cron과 동일 메서드 재호출이 되는지 검증** | [MUST] | 🟢 | 6분 | - | cron + `resetMonthlyPool` 본문 박제 (L1a 설계 입력) |
| S0e | sensor 5종 파일 + hook 등록 상태 재실측 — `ls .claude/scripts/sensor-credit-*.sh sensor-subscription-pool-*.sh sensor-chat-charge-tier.sh` 존재 확인 + `grep -rn "sensor-subscription-pool\|sensor-credit-overhaul" .claude/settings.json .claude/agents .claude/skills` 등록 grep. 본 계획 작성 중 grep 결과: 파일은 `.claude/scripts/`에 **2건 존재** 확인(`sensor-subscription-pool-no-rollover.sh` + `sensor-credit-overhaul-recalc.sh`), settings.json 등록 **0건** — harness 영역이라 server sprint 외이나, CC-3 lazy 구현 후 sensor 등록 권고는 §10에 명시 | [MUST] | 🟢 | 4분 | - | sensor 5종 파일 존재 여부 + hook 등록 여부 박제 (§10 LOW-1 권고 입력) |

**S0 게이트**: S0a~S0e [MUST] 5건 완료 = §10 미확인 + CC-3 직접 코드 현행 해소 → 설계 결정(L1a·H1a) 진입 허가. 미확인 잔존 시 본 작업 착수 금지.

> 진단 §10 미확인 중 CC-3 직접 관련 = S0a(theme-slot/plan usecase Author.plan) + S0e(sensor hook 등록). 나머지(테마 차감 구 경로=CC-1 완료 / dev plan 분포=CC-4 / Polar KYC=CC-5)는 범위 외.

---

## 2. CRITICAL-1 — lazy 안전망 설계 결정 (案 B 권고)

> CREDIT_CORE_DIAGNOSIS §4 — `getBalance`(`prisma-credit-ledger.repository.ts:194-221`)가 `Author` 5 캐시 필드 단순 합산. `CreditLedger.expiresAt < now()` 만료 row를 잔액에서 제외하는 SELECT **0건**. 이월 금지가 `ResetMonthlyPoolJob` cron(`reset-monthly-pool.job.ts:40 @Cron('0 0 4 * * *')`)의 캐시 덮어쓰기에만 의존. cron 실패 시 풀 무한 이월 → §8-8 CRITICAL #2 위반 → §0 0.14× 붕괴.

### 2-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| L1a | CRITICAL-1 lazy 안전망 설계 결정 명문화 — §4 案 B(cron + lazy 이중 안전망)를 본 계획 §2-2에 박제. 진입점(`getPointBalance` 경로 + 옵션으로 `getPlan` 직접) + lazy 호출 조건(`MembershipPlan.poolResetAt < now()` AND `tier !== 'free'` AND `status === 'active'`) + cron 변경 없음(보존) 확정. ADR-012 보강안 1줄 작성(실제 ADR 수정은 L2g) | [MUST] | 🟢 | 7분 | S0 게이트 | §2-2 설계 결정 명문화 (구현 L2의 설계 입력) |

### 2-2. CRITICAL-1 lazy 안전망 설계 (planner 결정 — L1a 산출)

**§4 案 A vs 案 B 재정리**:

| 案 | 구조 | 장점 | 단점 |
|---|---|---|---|
| 案 A | `getBalance`에 ledger 집계 쿼리 추가(`subscription` 부분을 `SUM(amount) WHERE source='subscription' AND (expires_at IS NULL OR expires_at > now())`로 대체) | 잔액 조회가 만료를 즉시 반영 — 캐시 stale 위험 0건 | `spend`의 `planConsumption` 입력(subscription 부분)도 만료 반영해야 일관 → `spend`까지 연쇄 수정. 캐시-원장 정합 cron 필요(`ReconciliationCheckpoint` 패턴). 규모 M~L |
| **案 B (권고)** cron(현행 유지) + lazy 안전망(getBalance/getPlan 호출 시 poolResetAt 경과면 즉시 resetMonthlyPool) | cron이 1차 안전망, lazy가 2차 백업 — cron 실패해도 잔액 조회 시점에 자동 리셋. S Phase draft §8-6 원래 설계와 정합("cron + lazy 이중 안전망"). `reset-monthly-pool.job.ts:18` 주석이 "lazy 리셋은 I Phase 후속" 명시 — I Phase가 유예한 부분을 CC-3가 완결 | lazy 진입점이 호출 경로(`getPointBalance`/`getPlan`)에 추가됨 — 호출 빈도 높은 곳이라 성능 영향 검증 필요. resetMonthlyPool 트랜잭션이 모든 잔액 조회에 끼이면 안 됨 → 조건부 호출 + 동시성 가드 필수 |

**권고 — 案 B (cron + lazy 이중 안전망)**. 사유:

1. **S Phase draft §4 게이트 4-C 원안 복원** — draft가 "cron + lazy 이중 안전망"을 명시 + `reset-monthly-pool.job.ts:18` 주석이 "lazy 리셋은 I Phase 후속"으로 미뤘음을 박제. CC-3가 그 후속 — 원래 설계 미완성 부분 마무리.
2. **§8-8 CRITICAL #2 "이월 금지" 안전성 회복** — cron 단일 의존(현 상태)은 cron 1회 실패만으로 풀 이월 → §0 0.14× 붕괴. lazy 안전망이 있으면 cron 실패 시점에 다음 잔액 조회가 즉시 보정. 4-C 원안의 "스키마가 강제" 수준 안전성을 lazy로 코드 강제로 변환.
3. **연쇄 수정 회피** — 案 A는 `spend`의 `planConsumption` 입력까지 영향 → `ChargePointsUseCase.chargeChatTurn`/`chargeAnalysis`/`chargeTheme` 차감 경로 전부 재검증 필요. 案 B는 진입점 1~2곳(`getPointBalance` + 옵션 `getPlan`)만 수정 — 범위 작고 회귀 위험 낮음.
4. **호출 비용 최적화 가능** — lazy 호출 조건을 `MembershipPlan.poolResetAt < now()` AND `tier !== 'free'` AND `status === 'active'`로 좁히면 free 작가는 영향 0건. pro/premium도 한 달에 1회만 트리거 — 평소 잔액 조회는 무영향.

**lazy 안전망 내부 설계 (案 B — L2 구현 입력)**:

```
getPointBalance(authorId) 진입 시:
  1. 기존: authorRepo.findById(authorId) — 작가 존재 확인.
  2. 추가: ledger.checkAndResetExpiredPool(authorId, now) — lazy 안전망 진입점.
     a. MembershipPlanPort.getPlan(authorId) 호출 — plan 없거나 tier='free' 또는 status!='active' → no-op return.
     b. plan.poolResetAt > now → no-op return (만료 안 됨).
     c. plan.poolResetAt < now → MembershipPlanPort.resetMonthlyPool(authorId, now) 호출
        (cron과 동일 메서드 — 트랜잭션 내부 idempotent, 동시 호출 시 FOR UPDATE로 직렬화).
     d. 호출 후 caller(getPointBalance)는 정상 진행 — getBalance는 새 캐시값을 읽음.
  3. 기존: ledger.getBalance(authorId) — 캐시 4 필드 단순 합산.

진입점 위치:
  - 1차: getPointBalance — 가장 자주 호출(잔액 조회 HTTP /credits/balance, /payments/credits).
  - 2차 (옵션): MembershipPlanPort.getPlan — 호출처 0건이나 향후 HTTP 노출 시(§5) 필수.
  - 차감/적립 경로(spend/earn/transfer): 호출하지 않음 — 차감 시 트랜잭션 안에서 추가 트랜잭션은 데드락 위험. 차감 직전 잔액 조회가 getBalance를 거치므로 충분.
```

> **동시성 가드** — lazy 호출 중 같은 plan을 두 잔액 조회가 동시에 트리거하면 `resetMonthlyPool` 이중 실행 위험. 해소: `resetMonthlyPool` 내부 트랜잭션이 이미 `MembershipPlan` FOR UPDATE를 잡고 idempotent하게 작동(2번째 호출은 첫 트랜잭션 완료 후 poolResetAt이 갱신돼 no-op). S0d Read 결과로 idempotency 재확인 필수.

> **호출 비용** — `getPlan` 1회 + 조건 만족 시 `resetMonthlyPool` 1회. 평소(plan 미만료/free) 추가 비용 = `getPlan` 1 SELECT(인덱스 hit). pro/premium 작가의 풀 리셋 시점에만 reset 비용 발생.

> **사용자 결정 불요** — 案 B는 진단 §4-C 권고 + S Phase draft 원안 + I Phase가 명시 유예한 후속이라는 기술 결정.

---

## 3. CRITICAL-1 lazy 안전망 구현

> 案 B — `CreditLedgerPort`(또는 `MembershipPlanPort`) 진입점에 lazy 훅 추가 + `getPointBalance` 경로에 통합 + ADR-012 보강 + sensor 등록 권고.

### 3-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| L2a | lazy 진입점 메서드 위치 결정 명문화 — 案 (i) `MembershipPlanPort`에 `checkAndResetExpiredPool(authorId, now)` 신설(getPlan 호출 + 조건 만족 시 resetMonthlyPool) vs 案 (ii) `CreditUseCase.getPointBalance` 내부에 직접 인라인. 권고 = **案 (i)** — port 추상화 + 재사용성 + spec 단순화. ADR-012 보강 1줄 | [MUST] | 🟢 | 5분 | L1a | 진입점 위치 결정 명문화 |
| L2b | `MembershipPlanPort`에 `checkAndResetExpiredPool(authorId, now)` 시그니처 추가 — 반환 `{reset: boolean, plan: MembershipPlanState | null}` 류. 헥사고날 — domain layer. shared-contracts §30 정합 인터페이스 확정 | [MUST] | 🟡 | 5분 | L2a | `npx tsc --noEmit` PASS |
| L2c | `prisma-membership-plan.repository.ts` `checkAndResetExpiredPool` 구현 — 본문: ① `getPlan(authorId)` 호출 ② plan null 또는 tier='free' 또는 status!='active' → `{reset: false, plan}` return ③ `plan.poolResetAt > now` → `{reset: false, plan}` return ④ `resetMonthlyPool(authorId, now)` 호출 후 `{reset: true, plan: 재조회}` return. **resetMonthlyPool 트랜잭션은 idempotent — 동시 호출 시 두 번째는 이미 갱신된 poolResetAt로 no-op** (S0d 검증 결과 박제) | [MUST] | 🟡 | 7분 | L2b,S0d | tsc PASS + idempotent 단위 spec 통과 |
| L2d | `prisma-membership-plan.repository.spec.ts` 갱신 — `checkAndResetExpiredPool` 단위 검증 ① tier='free' no-op ② status!='active' no-op ③ poolResetAt > now no-op ④ poolResetAt < now 시 resetMonthlyPool 호출됨 ⑤ 동시 2회 호출 시 두 번째는 no-op(idempotent) | [MUST] | 🟡 | 6분 | L2c | `npm test prisma-membership-plan.repository.spec` PASS |
| L2e | `credit.usecase.getPointBalance` 갱신 — `ledger.getBalance(authorId)` 호출 직전에 `membershipRepo.checkAndResetExpiredPool(authorId, new Date())` 호출 추가. `MembershipPlanPort` Optional DI(현재 `credit.usecase`는 `CreditLedgerPort` Optional만 주입 → `MembershipPlanPort` 추가 필요). lazy 실패는 silent log + 본 잔액 조회 진행(잔액 조회 자체 실패 방지 — fallback 안전망) | [MUST] | 🟡 | 7분 | L2d | tsc PASS + `getPointBalance` mock spec PASS |
| L2f | `credit.usecase.spec.ts` 갱신 — `getPointBalance` 호출 시 `checkAndResetExpiredPool` mock 호출 검증. lazy 실패 시(membershipRepo throw) 잔액 조회 진행 확인 | [MUST] | 🟡 | 6분 | L2e | `npm test credit.usecase.spec` PASS |

> L2c는 🟡 — DB 쓰기 트랜잭션이지만 `resetMonthlyPool` 재호출일 뿐 신규 트랜잭션 설계 X. 코드 변경이며 마이그레이션 0건. 실패 시 commit revert.

> **L2 핵심 효과** — `getPointBalance` 호출 = 잔액 조회 1회 + (조건부) 풀 리셋 1회. cron 실패해도 작가가 잔액을 본 순간 자동 보정 → §8-8 #2 "이월 금지"가 코드 강제로 회복. 4-C 원안의 "스키마가 강제" 수준 안전성을 lazy로 확보.

---

## 4. HIGH-1 — `Author.plan` ↔ `MembershipPlan.tier` 이중 출처 설계 결정

> CREDIT_CORE_DIAGNOSIS §5-A — `Author.plan String @default("free")` + `planExpireAt` 살아 있음, `[DEPRECATED]` 표기 **없음**. `MembershipPlan.tier`도 별개 정본. 마이그레이션 (c)가 `plan` → `tier` 복사만, 동기 트리거·비움 없음. `theme-slot.usecase`/`plan.usecase`가 `Author.plan`을 읽으면 `tier`와 불일치 위험.

### 4-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| H1a | HIGH-1 案 결정 명문화 — S0a grep 결과(`Author.plan` 읽기 7곳: theme-slot 5건 + generate-theme 3건 + get-theme 2건 + plan 2건 + admin + spec 2건)로 案 A(plan 정본 유지 + tier 미러 동기) vs 案 B(tier 정본화 + plan deprecated + 읽기 경로 이행)를 §4-2에 박제. 권고 = **案 A** (영향 범위 작음, ADR-012 보강). 案 B는 §6 사용자 게이트로 회부 | [MUST] | 🟢 | 7분 | S0 게이트 + S0a | §4-2 설계 결정 명문화 (구현 H2의 설계 입력) |

### 4-2. HIGH-1 案 결정 (planner 권고 — H1a 산출)

**S0a grep 결과 기반 案 A vs 案 B**:

| 案 | 구조 | 장점 | 단점 | 범위 |
|---|---|---|---|---|
| **案 A (권고)** `Author.plan` 정본 유지 + `MembershipPlan.tier` 미러 + `changeTier` 시 양측 동기 | `Author.plan` 읽기 7곳 무변경. `MembershipPlan.changeTier` 호출 시 `Author.plan`도 갱신(트랜잭션 내). `MembershipPlan.tier`는 풀 크기·구독 메타 전용 | 기존 코드 영향 0건(spec 무변경). 案 B의 큰 리팩토링 회피. 마이그레이션 (c)가 이미 plan→tier 복사하므로 초기값 정합. 案 B로 향후 이행 가능(점진) | `MembershipPlan` 정본이 명확하지 않음 — 두 출처 병존 + 동기 트리거에 의존. 동기 실패 시 불일치 위험(but tier 자체가 changeTier로만 변경) | **M (소)** — `changeTier` 트랜잭션 + spec, ADR-012 보강 + `[DEPRECATED]` 미부착 + 동기 트리거 spec |
| 案 B | `MembershipPlan.tier` 정본화. `Author.plan` `[DEPRECATED]` 주석 + 읽기 경로(theme-slot/plan/generate-theme/get-theme/admin) → `MembershipPlanPort.getPlan` 경유 이행. `MEMBERSHIP_THEME_SLOTS`/`MEMBERSHIP_DAILY_FREE_THEME` 상수(이미 `membership-tier.ts`에 존재)를 정본으로 사용 | 단일 정본(`tier`) — 회계 정합. `MembershipPlanPort.getPlan` 호출처 0건 문제 해소 | 읽기 경로 7곳 + spec 7곳 + DI(theme-slot/plan/generate-theme/get-theme/admin usecase에 `MembershipPlanPort` 추가) + 마이그레이션 후 `Author.plan` 동기 보존 또는 비움 결정. **큰 리팩토링** — CC-3 sprint 비대 위험 | **L (대)** — `Author.plan` 읽기 경로 7곳 + DI 5건 + spec 7건 + `MembershipPlanPort` HTTP 노출(§5) + `Author.plan` deprecated 정책 |

**권고 — 案 A (Author.plan 정본 유지 + tier 미러 동기)**. 사유:

1. **CC-3 sprint 비대 회피** — 案 B는 읽기 경로 7곳 + DI 5건 + spec 7건 추가 → CC-3 sub-task 27 → 50+ 증대. CC-3 본질(이월 금지 + 원장 단일화) 외 부담. 案 A는 `changeTier` 트랜잭션만 — 작업량 1/3.
2. **`changeTier` 호출처 0건(진단 §2-2) — 案 A의 위험 ZERO** — 案 A는 "`changeTier` 시 양측 동기"인데 `changeTier` 자체가 현재 호출처 0건(PAY-P1-4 미착수). 즉 案 A는 **CC-5에서 `changeTier`가 활성화될 때 동기 트리거가 처음 작동** — CC-3에서 동기 spec만 박제하면 향후 활성화 시 자동 정합.
3. **마이그레이션 (c) 정합** — 마이그레이션이 이미 `Author.plan` → `MembershipPlan.tier` 복사함. 초기값 동기됨 — 그 후 변경 경로(`changeTier`)에서 양측 갱신만 보장하면 정합 유지.
4. **점진 이행 가능** — 案 A로 CC-3에서 안정화 후 CC-5(PAY-P1-4) 또는 별도 후속 sprint에서 案 B로 이행하는 옵션 보존. 案 B는 "1회 큰 리팩토링" 부담 후 회수 불가.
5. **案 B의 잠재 부담** — `MembershipPlanPort.getPlan` HTTP 노출 + web 멤버십 페이지 web 핸드오프 + theme-slot/plan/generate-theme/get-theme usecase의 plan 읽기 5곳 DI + spec — 案 B 전체가 별도 sprint급. CC-5와 묶거나 CC-3 후속 sprint로 분리하는 게 정합.

**案 A 구현 내부 설계 (H2 입력)**:

```
MembershipPlanPort.changeTier(authorId, tier, now):
  현재 (S0d Read 기준):
    $transaction:
      ① MembershipPlan 갱신 (tier, monthlyPoolPoints, poolBalance, poolResetAt)
      ② Author.pointsSubscription 캐시 동기

  案 A 추가:
    $transaction 안에 ③ Author.plan = tier (planExpireAt = poolResetAt 또는 별도 정책) 추가.

ADR-012 보강:
  - `Author.plan`은 정본 유지 (1 sprint 유예 후 案 B로 이행 옵션).
  - `MembershipPlan.tier`는 미러 + 구독 메타 전용.
  - changeTier 호출 시 양측 동기 (트랜잭션 강제).
  - 읽기는 `Author.plan` (테마 slot/플랜 만기 등 기존 7곳 무변경).
```

> **사용자 결정 게이트 — §6 (HIGH-1 案 B 채택 여부)**: 案 A 권고이나, 사용자가 案 B를 채택하려면 "Author.plan 읽기 7곳 이행 + DI 5건 + spec 7건 = CC-3 sprint 1.5~2배 확장 동의" 필요. **권고 = 案 A 즉시 진행 / 案 B 채택 시 CC-3 분할** (案 B 별도 sub-sprint).

---

## 5. HIGH-1 案 A 구현 (changeTier 양측 동기 + ADR-012 보강)

> 案 A — `MembershipPlanPort.changeTier` 트랜잭션에 `Author.plan` 동기 + ADR-012 명문화 + spec.

### 5-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| H2a | `prisma-membership-plan.repository.ts` `changeTier` 갱신 — 기존 `$transaction` 안에 `tx.author.update({ where: {id: authorId}, data: { plan: tier, planExpireAt: <정책 결정> }})` 추가. `planExpireAt`은 `MembershipPlan.expiresAt` 또는 `poolResetAt` 중 어느 것을 미러할지 결정(권고: free→null / pro·premium→1년 유예 또는 plan.expiresAt 미러). H2a-결정 1줄 박제 | [MUST] | 🟡 | 6분 | H1a,S0d | tsc PASS |
| H2b | `prisma-membership-plan.repository.spec.ts` 갱신 — `changeTier` 시 ① `MembershipPlan.tier` 갱신 ② `Author.plan` 동기 ③ `Author.planExpireAt` 정책 정합 ④ free 전환 시 planExpireAt=null 단위 검증 | [MUST] | 🟡 | 6분 | H2a | `npm test prisma-membership-plan.repository.spec` PASS |
| H2c | ADR-012 (`grimoire-server/ADR.md` 또는 `docs/`) 보강 — "HIGH-1 案 A 채택 — Author.plan 정본 유지 + MembershipPlan.tier 미러, changeTier 시 양측 동기. CC-5 또는 후속 sprint에서 案 B 이행 옵션 보존" 1~2 단락 박제. 4-C 변형("캐시 + cron + lazy")도 함께 박제 | [MUST] | 🟡 | 5분 | H2b,L2a | ADR-012 갱신 + drift sensor silent |
| H2d | `MembershipPlanState` 도메인 모델 주석 갱신 — `tier` 필드 옆에 "Author.plan 미러 — changeTier 시 양측 동기" 박제. `Author.plan` 컬럼은 `schema.prisma` 또는 `SCHEMA.md`에 "案 A 정본 — MembershipPlan.tier로 미러" 주석 | [MUST] | 🟡 | 4분 | H2c | tsc PASS + 주석 grep 확인 |

> H2a `planExpireAt` 정책 = "MembershipPlan.expiresAt 미러 / free → null". 현 `plan.usecase.activatePlan` 로직과 정합. CC-5(PAY-P1-4) 시점에 구독 결제 갱신과 정합 재확인.

> **案 A 한계 명시** — `Author.plan` 직접 SQL UPDATE(테스트/관리자 수동)가 발생하면 양측 불일치 가능. ADR-012에 "수동 SQL UPDATE 금지 — `changeTier` 경유 강제" 명문화. 案 B로 이행 시 이 한계 해소.

> **案 B 채택 시 (§6 사용자 게이트 통과 시) sub-task 추가** — H2e~H2g 추가:
> - H2e: `theme-slot/plan/generate-theme/get-theme/admin usecase`에 `MembershipPlanPort` DI 추가 + `Author.plan` → `getPlan(authorId).tier` 이행 (7곳).
> - H2f: 각 spec 갱신 (7건 mock 수정).
> - H2g: `Author.plan` `[DEPRECATED]` 주석 + 마이그레이션에서 비움 정책(CC-4 위임).

---

## 6. HIGH-3 — `getGiftRanking`/`getLogs` `CreditLedger` 기반 재작성

> CREDIT_CORE_DIAGNOSIS §5-B + §2-3 — 적립=`CreditLedger`(신, CC-2b 완료) / 차감=`CreditLedger`(신) vs 구 `getGiftRanking`/`getLogs`가 `CreditLog` 의존 → **CC-2b가 선물 적립을 `CreditLedger` `source='gift'`로 이행하면서 신·구 분열 유발**. 신 선물은 `CreditLog` 박제 0건이라 `getGiftRanking`(구 `reason: {startsWith: 'gift_received'}` groupBy)이 신 선물을 못 봄.

### 6-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| H3a | `getGiftRanking` 재작성 — `prisma-credit-ledger.repository.ts`에 `getGiftRanking(limit)` 메서드 신설. 본문: `creditLedger.groupBy({ by: ['authorId'], where: { source: 'gift', type: 'earn' }, _sum: { amount }, orderBy: { _sum: { amount: 'desc' } }, take: limit })` → 반환 `{authorId, totalGifted}[]`. **S0c 동등성 게이트** — 구 반환과 동일 타입 + 동일 정렬 | [MUST] | 🟡 | 6분 | S0c | tsc PASS + 반환 타입 정합 grep |
| H3b | `CreditLedgerPort`에 `getGiftRanking(limit): Promise<{authorId, totalGifted}[]>` 시그니처 추가 — shared-contracts §30 정합 | [MUST] | 🟡 | 4분 | H3a | tsc PASS |
| H3c | `credit.usecase.getGiftRanking`/`getLogs` 재배선 — `getGiftRanking` → `ledger.getGiftRanking(limit)` 위임 (구 `creditRepo.getGiftRanking` 호출 제거). `getLogs` → `ledger.findByAuthor(authorId, 100)` 위임 (`CreditLedgerPort.findByAuthor` 이미 존재, S0c 확인 시그니처 — `CreditLedgerEntry[]` 반환). **반환 타입 변경 발생** (`CreditLog[]` → `CreditLedgerEntry[]`) → controller 응답 형태 변경 확인 필수 | [MUST] | 🟡 | 7분 | H3b | tsc PASS + 구 `creditRepo.getGiftRanking`/`findLogsByAuthorId` 호출 grep 0건 |
| H3d | `credit.usecase.spec.ts` + `prisma-credit-ledger.repository.spec.ts` 갱신 — `getGiftRanking` 신 ledger 호출 mock + 신 선물(`source='gift', type='earn'`)만 집계 + 동일 limit/정렬 검증. `getLogs` `findByAuthor` 위임 + 반환 형태 검증 | [MUST] | 🟡 | 7분 | H3c | `npm test credit.usecase.spec prisma-credit-ledger.repository.spec` PASS |

> **반환 타입 변경 핸드오프** — `getLogs` 반환이 `CreditLog[]` → `CreditLedgerEntry[]`. `credit.controller.ts:40` `GET /credits/logs` 응답 스키마 변경. **shared-contracts §30 + api-contract.md 갱신 필수** (H6c) + **web 핸드오프 1건**(§10-3) — web 로그 페이지가 신 형태 수용.

> **`CreditLog` 자체 폐기는 CC-3 범위 외** — H3는 사용처 2건(`getGiftRanking`/`getLogs`)을 `CreditLedger`로 이행. `CreditLog` 테이블 + `prisma-credit.repository`의 다른 메서드(`adjustCredits`/`findLogsByAuthorId`/`getGiftRanking`/`sumNegativeAmounts`) 잔존. 완전 폐기 = §2-3 폐기 의존 그래프 — `Author.credits` DROP과 함께 별도 후속 sprint(CC-4 후속).

> **CC-2b 분열 해소 증명** — CC-2b 후 dev/prod에 `CreditLedger source='gift'` 박제 신 선물 + `CreditLog reason='gift_received'` 박제 구 선물(마이그레이션 이전)이 공존 가능. H3a 신 `getGiftRanking`은 신 선물만 집계 → 마이그레이션 시점 이전 구 선물 누락 가능성. **CC-4 마이그레이션 (b)가 구 `CreditLog`를 `CreditLedger` 초기 row로 이전했으면 모두 신에 통합 가능** — 마이그레이션 SQL 재확인은 CC-4. CC-3는 현 시점 신·구 분열 해소(신 선물 정확 집계)에 집중.

---

## 7. `MembershipPlanPort.getPlan` HTTP 노출 (선택 — CC-3 vs CC-5 결정)

> CREDIT_CORE_DIAGNOSIS §10 + CC-2b §10-3 web 핸드오프 — `MembershipPlanPort.getPlan` 호출처 0건. HIGH-1 案 B 채택 시 web 멤버십 페이지가 tier를 받으려면 HTTP 엔드포인트(`GET /membership` 등) 신설 필요.

### 7-1. CC-3 포함 여부 결정

| 옵션 | 처리 | 권고 |
|---|---|---|
| **(A) CC-3 포함** | `GET /membership` 엔드포인트 신설(`MembershipController` + `MembershipPlanPort.getPlan` 위임) + DTO + api-contract.md 갱신 + spec 3~4건. 案 A 권고와 함께 도구 갖춰두기 | 案 B로 향후 이행 시 즉시 활용 가능. 단 案 A 채택 시 사용처 0건 — 데드 코드 위험 |
| **(B) CC-5 이월 (권고)** | PAY-P1-4 Polar 구독 연동 sprint에 묶음. `GET /membership` + 구독 시작 엔드포인트 + `subscription.*` webhook이 한 sprint에 모임 — 도메인 응집 | CC-3는 안전성(lazy)·정합성(원장) 본질에 집중. CC-5는 구독 도메인 전체 |

**권고 — (B) CC-5 이월**. 사유:
- 案 A 권고(HIGH-1) 시 `getPlan` HTTP 노출 사용처 부재 — CC-3에서 추가 시 데드 코드.
- CC-5(PAY-P1-4)는 구독 도메인 sprint — `GET /membership` + `POST /subscriptions/checkout` + `subscription.*` webhook이 같은 sprint에 응집(진단 §7-2 1~7).
- CC-3 sprint 비대 회피 — sub-task 27 → 30+ 회피.

> **CC-3 §10-3 핸드오프에 명시** — `MembershipPlanPort.getPlan` HTTP 노출 = CC-5 PAY-P1-4 sub-task 신설 (현재 진단 §7-2 #5에 포함됨 확인).

---

## 8. 통합 spec 신설 (CC-3 근본 해결 + 결함 3건 종결 증명)

> CREDIT_CORE_DIAGNOSIS §8 — CC-1/CC-2a/CC-2b가 통합 spec을 신설했듯, CC-3는 **lazy 안전망 작동 + Author.plan 동기 + getGiftRanking 신 ledger 집계** 통합 검증 + **결함 3건 종결 증명**.

### 8-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| I1a | 통합 spec 파일 신설 — `application/credit/credit-rollover-source-ledger-integration.spec.ts` 류. CC-2b 통합 spec 패턴 차용 — 실 `CreditUseCase`/`MembershipPlanPort` + 인메모리 `MembershipPlan`/`CreditLedger` fake 기반 | [MUST] | 🟡 | 8분 | L2f,H2b,H3d | 파일 생성 + tsc PASS |
| I1b | CRITICAL-1 lazy 안전망 통합 케이스 — ① pro 작가 `poolResetAt < now` 상태 ② `CreditUseCase.getPointBalance` 호출 ③ `MembershipPlanPort.checkAndResetExpiredPool` 자동 실행 검증 ④ `CreditLedger` expire row + 신규 earn row 박제 ⑤ `MembershipPlan.poolBalance = monthlyPoolPoints` 재설정. **cron 실행 안 했는데 lazy로 보정됨을 통합 증명**. free 작가 / poolResetAt > now / status='cancelled' no-op 케이스 함께 | [MUST] | 🟡 | 8분 | I1a | 해당 it PASS — CRITICAL-1 해소 통합 증명 |
| I1c | HIGH-1 案 A 동기 + HIGH-3 신 ledger 집계 통합 케이스 — ① `changeTier(authorId, 'pro', now)` → `MembershipPlan.tier='pro'` + `Author.plan='pro'` 양측 동기 검증 ② CC-2b 선물 적립(`source='gift', type='earn'`) 직후 `getGiftRanking(10)` 호출 → 신 선물 집계됨(구 `CreditLog` 경로면 누락) ③ `getLogs` → `CreditLedger` 기반 반환 형태 검증. **HIGH-1·HIGH-3 동시 해소 증명** | [MUST] | 🟡 | 7분 | I1a | 해당 it PASS — HIGH-1·HIGH-3 해소 통합 증명 |

> **통합 spec이 CC-3 핵심** — CC-1/CC-2a/CC-2b 철학 정합: 단위 PASS여도 lazy 진입점이 실호출되지 않으면 CRITICAL-1 미해소. I1b가 미연동 시 RED를 재현하도록 작성 → 회귀 방어. I1c가 HIGH-1 동기 + HIGH-3 신·구 분열 해소를 통합으로 박제.

---

## 9. sensor 등록 권고 (LOW-1 — harness 영역 권고 핸드오프)

> CREDIT_CORE_DIAGNOSIS §10 LOW-1 — sensor 5종(`sensor-credit-overhaul-recalc`/`-denomination`/`-source-accounting`/`-subscription-pool-no-rollover`/`-chat-charge-tier`) 파일은 `.claude/scripts/`에 **2건 존재** 확인(S0e). settings.json 등록 0건 — harness 영역(server sprint 외).

### 9-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| S1a | sensor 등록 권고를 CC-3 보고서·핸드오프에 박제 — `sensor-subscription-pool-no-rollover.sh`는 CC-3 lazy 안전망(L2) 완료 시점에 PostToolUse 또는 pre-commit hook 등록이 적절. `sensor-credit-overhaul-recalc.sh`는 cost-accountant 영역. **CC-3는 등록 자체를 수행하지 않으나 harness agent에 권고 핸드오프 박제** | [SHOULD] | 🟢 | 3분 | S0e | reports/PLANNER_REPORT.md 또는 본 계획 §10-3에 권고 명시 |

> sensor 등록은 harness 영역이라 server sprint 외. CC-3는 **권고 핸드오프**만 — `reports/PLANNER_REPORT.md`에 "sensor 2종 hook 등록 권고 → harness agent" 명시.

---

## 10. CC-3 마무리 — 빌드·문서·sensor + 원가 게이트

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| F1a | 전체 빌드 — `npm run build` 무에러 | [MUST] | 🟢 | 3분 | I1c | 종료코드 0 |
| F1b | 전체 테스트 — `npm test` 통과, server 커버리지 **≥60%** 유지 | [MUST] | 🟢 | 5분 | F1a | jest 전체 PASS, 커버리지 게이트 통과 |
| F1c | `shared-contracts.md` §30 갱신 — `MembershipPlanPort.checkAndResetExpiredPool` 신설 + `CreditLedgerPort.getGiftRanking` 신설 + HIGH-1 案 A 박제(`Author.plan` 정본 + `tier` 미러 동기) + `GET /credits/logs` 응답 형태 변경(`CreditLog[]` → `CreditLedgerEntry[]`) + 변경 이력 1줄씩 박제. ⚠️ §30이 인터페이스 정본 → 미갱신 시 다른 agent 통합 단계 깨짐 | [MUST] | 🟡 | 7분 | F1b | `.claude/scripts/sensor-shared-contracts.sh` silent |
| F1d | `grimoire-server/TECH_STATUS.md` + `ADR.md`(ADR-012 보강) + `docs/api-contract.md`(GET /credits/logs 응답 변경) + `docs/data-model.md`(`Author.plan` 案 A 주석) + `SCHEMA.md` 갱신 — CC-3 완료(CRITICAL-1 lazy 안전망 + HIGH-1 案 A + HIGH-3 원장 단일화) 박제. `docs-sync` drift sensor 확인 | [MUST] | 🟡 | 6분 | F1c | drift sensor silent |
| F1e | sensor 일괄 — `sensor-shared-contracts` / `-instruction-degradation` / `-agent-priority-labels` / `-agent-interaction` + `sensor-subscription-pool-no-rollover.sh`/`sensor-credit-source-accounting.sh`(존재 시) 실행 | [SHOULD] | 🟢 | 3분 | F1d | sensor 전부 silent/PASS |

> **원가 게이트 판정 (F1 단계 박제)**: CC-3는 **신규 AI 기능 추가 0건** — lazy 안전망(잔액 조회 시 풀 리셋) + plan 동기 + 원장 단일화. AI 모델 호출 0건, `CREDIT_PRODUCTS` 무변경, 차감 N 무변경. §0 직결값을 건드리지 않음. **cost-accountant 마진 검증 게이트 불요** — CC-1·CC-2b와 동일. 案 B 채택 시(§6 게이트) HTTP 노출 + DI 5건 추가뿐 — 여전히 cost-accountant 무관.

---

## 11. rollback 단위

- 각 sub-task는 git commit 단위 — L2·H2·H3·I1 별 commit 권장. 실패 시 해당 commit revert.
- L2b(`checkAndResetExpiredPool` 신설)는 port 메서드 추가 + 진입점 1곳(`getPointBalance`)만 호출. L2e 실패 시 L2b만 살리고 호출 제거(`getPointBalance`가 lazy 미사용 — 현재 동작과 동일).
- H2a(`changeTier` 양측 동기)는 `changeTier` 호출처 0건(CC-5 PAY-P1-4 미착수)이라 운영 영향 0건 — revert 안전.
- H3c(`getGiftRanking`/`getLogs` 재배선)는 반환 형태 변경 동반 — controller 응답 형태가 web 영향. revert 시 구 `creditRepo` 호출로 즉시 원복(구 메서드 잔존).
- 코드 변경만(🟡) — **DB 스키마 비변경**(lazy/plan 동기/getGiftRanking은 기존 테이블만 사용, 신규 컬럼 0건). PAY-S1과 달리 백업 불요. tsc/jest 실패 = 즉시 해당 commit 단위 롤백.
- ⚠️ I1 통합 spec은 dev 배포 게이트 — CC-4(마이그레이션 sprint) 또는 별도. CC-3 자체는 코드 머지까지.

---

## 12. 핸드오프

### 12-1. 담당 + 산출물 위치

| 영역 | 담당 | 산출물 위치 | 다음 단계 진입 조건 |
|---|---|---|---|
| §6 사용자 게이트 (HIGH-1 案 B 채택 여부) | **사용자** (planner 경유 확인) | 案 A 즉시 진행 / 案 B 채택 시 CC-3 분할 결정 | 案 A 승인 = H2a 즉시 진행 / 案 B 채택 = sub-sprint 분할 |
| CC-3 S0 | grimoire-server | §10 미확인 + CC-3 직접 코드 현행 해소 결과 박제 (progress.md) | S0a~S0e 완료 = 설계 결정 진입 |
| CC-3 L1a/H1a 설계 결정 | grimoire-server (또는 planner 재확인) | 본 계획 §2-2 案 B + §4-2 案 A 권고 채택 박제 | L1a·H1a 완료 = 구현 진입 |
| CC-3 L2~F1 구현 | grimoire-server (Generator) | Port/usecase/repository 코드 + spec + progress.md 갱신 | F1 마무리 |
| CC-3 채점 | grimoire-qa (Evaluator) | `QA_REPORT.md` — sprint-progress 통과율 박제 + **CRITICAL-1·HIGH-1·HIGH-3 종결 통과율 박제** | — |
| sensor 등록 권고 | grimoire-harness agent (별도) | sensor 2종 hook 등록 | CC-3 머지 후 |

### 12-2. Initializer 산출물 (planner)

- 본 계획 = `.claude/state/sprint-cc3-rollover-source-ledger-plan-draft.md`.
- **`reports/sprint-cc3-rollover-source-ledger-progress.md` 생성 권고** — 본 계획의 sub-task 27건 체크리스트 + 완료 기준 + **CRITICAL-1·HIGH-1·HIGH-3 종결 증명 항목**을 progress.md로 박제 → server(Generator)가 Read 후 갱신, qa(Evaluator)가 채점 (책 Ch 16 Initializer→Generator→Evaluator 패턴).
- server / qa에게 본 계획 + progress.md Read 후 작업 핸드오프.

### 12-3. 원가 영향 + 시각 검수 + web 핸드오프 플래그

- CC-3는 **신규 AI 기능 추가 0건** — lazy 안전망 + plan 동기 + 원장 단일화. cost-accountant 마진 검증 게이트 **불요**(CC-1·CC-2b와 동일. CC-2a의 디노미 패키지 같은 조건부 게이트 없음).
- 시각 검수(visual-canon-keeper) **불요** — CC-3는 server 도메인 한정, UI 변경 0건.
- **web 핸드오프 1건** — `GET /credits/logs` 응답 형태 변경(`CreditLog[]` → `CreditLedgerEntry[]`). web 크레딧 로그 페이지가 신 형태 수용 필요. shared-contracts §30 변경 이력에 "GET /credits/logs 응답 = CreditLedgerEntry[] (CC-3)" 명시 + web Generator 후속 sprint 핸드오프.
- **harness 핸드오프 1건** — sensor 2종(`sensor-subscription-pool-no-rollover.sh` + `sensor-credit-overhaul-recalc.sh`) settings.json hook 등록 권고.

### 12-4. CC-4·CC-5로 이월되는 범위 (CC-3 범위 외 — 명시)

| 항목 | 진단 근거 | 이월 sprint |
|---|---|---|
| HIGH-1 案 B 이행 (`Author.plan` 읽기 경로 7곳 → `MembershipPlanPort.getPlan`) | §5-A 案 B | CC-5 또는 후속 sprint (사용자 §6 결정 종속) |
| `MembershipPlanPort.getPlan` HTTP 노출 (`GET /membership` 등) | §7 + 진단 §10 | CC-5 PAY-P1-4 (구독 도메인 응집) |
| V Phase 마이그레이션 안전화 + dev/prod apply | §3 | CC-4 (CC-1·CC-2·CC-3 완결 후) |
| `Payment.credits` / `RefundLog.deficitCredits`·`credits` 컬럼 물리 rename | MEDIUM-4 | CC-4 |
| 구 `CreditLog` 테이블 폐기 + `Author.credits` DROP + 구 `CreditUseCase.grant/deduct/gift/getBalance` 제거 + `prisma-credit.repository`(구) 메서드 제거 | §2-3 폐기 의존 그래프 | CC-4 후속 |
| PAY-P1-4 Polar 구독 연동 (subscription.* webhook + changeTier 활성화) | §7 | CC-5 |
| sensor 5종 hook 등록 | LOW-1 / §10 | harness agent |
| Author.plan 컬럼 DEPRECATED 주석 부착 시점 | 案 A vs 案 B 종속 | 案 B 채택 시 / 案 A 유지 시 別 후속 |

> ⚠️ **CC-3 완료 후 잔존 결함**: HIGH-1 案 B 미적용 시 `Author.plan` 정본 의존 코드 7곳 잔존 (案 A로 안전 동기). HIGH-3 `CreditLog` 테이블 자체 잔존 (`adjustCredits`·`sumNegativeAmounts` 등 다른 메서드 호출처 확인 필요 — CC-4 후속). lazy 안전망은 `getPointBalance` 경로만 — 직접 `findFirst` 호출(cron 외)이 발생하면 미보정. **lazy 진입점 확장은 CC-5에서 `getPlan` HTTP 추가 시 함께**.

---

## 13. 종합 게이트 — CC-3 완료 선언 조건 + 결함 3건 종결 증명

### CC-3 완료 선언

- **§6 사용자 게이트**: HIGH-1 案 결정 완료 (案 A 권고 승인 또는 案 B 채택 후 분할).
- **S0 게이트**: S0a~S0e [MUST] 5건 완료 (§10 미확인 + CC-3 직접 코드 해소).
- **L1a/H1a 설계 결정**: §2-2 案 B(cron + lazy) + §4-2 案 A(plan 정본 + tier 미러) 권고 채택 명문화.
- **본 작업 [MUST]**: L2a~f + H2a~d + H3a~d + I1a~c + F1a~d — 전부 통과. ([SHOULD] S1a/F1e 실패는 회고만.)
- **검증 게이트** (writing-plans Gate 1·2·3):
  - Gate 1 (빌드): F1a `npm run build` 무에러.
  - Gate 2 (테스트): F1b `npm test` 전체 PASS + 커버리지 ≥60%. **통합 spec(I1)이 핵심** — lazy 안전망 작동 + plan 동기 + 신 ledger 집계를 통합 테스트로 증명.
  - Gate 3 (문서/sensor): F1c~e — shared-contracts §30 + TECH_STATUS + ADR-012 + api-contract + data-model + SCHEMA 갱신 + sensor silent.

### 결함 3건 종결 증명 (CC-3 종결 게이트 — 가장 중요)

CC-3는 CRITICAL-2 외 잔존 결함 3건의 마지막 sprint — 완료 시 다음 박제:

| 결함 | 증명 방법 |
|---|---|
| **CRITICAL-1** (`getBalance` 만료 미반영, 이월 금지 cron 단일 의존) | ① `grep -rn "checkAndResetExpiredPool" src` ≥1건(L2c 구현) + `getPointBalance` 진입에 호출 ② 통합 spec I1b PASS — cron 미실행 상태에서 lazy가 자동 보정 박제 ③ ADR-012에 "4-C 변형 — 캐시 + cron + lazy" 박제(H2c) |
| **HIGH-1** (`Author.plan`↔`MembershipPlan.tier` 이중 출처) | ① `changeTier` `$transaction`에 `Author.plan` 동기 추가(H2a) ② 통합 spec I1c PASS — `changeTier` 호출 시 양측 동기 박제 ③ ADR-012 案 A 박제(H2c) |
| **HIGH-3** (`getGiftRanking`/`getLogs` `CreditLog` 의존, 신·구 분열) | ① `grep -rn "creditRepo\.getGiftRanking\|creditRepo\.findLogsByAuthorId" src/application` **0건**(H3c 재배선) + ledger 신 `getGiftRanking` 호출처 ≥1건 ② 통합 spec I1c PASS — CC-2b 신 선물(`source='gift'`)이 `getGiftRanking`에 집계됨 박제 ③ shared-contracts §30 변경 이력에 "getGiftRanking·getLogs CreditLedger 이행" 박제 |

→ **결함 3건 종결 선언 조건**: 위 3건 전부 증명 + 통합 spec I1b/I1c PASS = "CC-3 — 이월 금지 안전망 + Author.plan 정합 + 원장 단일화 완료. CRITICAL-1·HIGH-1·HIGH-3 해소". qa(Evaluator)가 QA_REPORT.md에 종결 통과율 박제.

### CC-3 미해소 잔존 (범위 외 — 명시)

- HIGH-1 案 B 이행 / `getPlan` HTTP 노출 / `CreditLog` 테이블 폐기 / `Author.credits` DROP / V Phase 마이그레이션 = **CC-4/CC-5 범위**.
- lazy 안전망은 `getPointBalance` 경로만 — `getPlan` 직접 HTTP 노출 시 lazy 추가 진입점 필요(CC-5 핸드오프).
- CC-3 완료 = V Phase 마이그레이션 적용 가능 자격 충족 (CC-1·CC-2·CC-3 전부 완결 — CREDIT_CORE_DIAGNOSIS §8 가장 중요한 결론).
- **단 CC-3 완료 = 적립/차감/원장/이월 전 영역 안정화 — CC-4(V Phase 마이그레이션 적용) + CC-5(Polar 구독 연동)만 잔존**.

---

## 14. 미확인 / 추정 금지 명시

| 항목 | 상태 | 해소 시점 |
|---|---|---|
| `Author.plan` 읽기 호출처 grep 결과 | **확인** — 본 계획 작성 중 grep(theme-slot 5건 + generate-theme 3건 + get-theme 2건 + plan 2건 + admin + spec 2건 = 7곳). S0a 현행 재실측 | S0a |
| `MembershipPlanPort.getPlan` 호출처 | **확인** — 본 계획 작성 중 grep(application 호출처 0건, port 정의만 존재). S0b 현행 재실측 | S0b |
| `credit.usecase.getGiftRanking`/`getLogs` + `prisma-credit.repository` 본문 | **확인** — 본 계획 작성 중 Read(`getGiftRanking`: `CreditLog.groupBy {reason: {startsWith: 'gift_received'}}, _sum: amount` / `findLogsByAuthorId`: `CreditLog.findMany orderBy: createdAt desc`). S0c 현행 재실측 | S0c |
| `reset-monthly-pool.job.ts` lazy 안전망 부재 주석 | **확인** — L18 "lazy 리셋은 I Phase 후속" 명시 박제. S0d 현행 재확인 | S0d |
| sensor 5종 파일 + hook 등록 상태 | **부분 확인** — 본 계획 작성 중 grep으로 2건 파일 존재(`sensor-subscription-pool-no-rollover.sh` + `sensor-credit-overhaul-recalc.sh`), settings.json 등록 0건. 나머지 3종(`sensor-credit-denomination`/`-source-accounting`/`-chat-charge-tier`) 파일 존재 여부 미확인 — S0e가 ls로 재확인 | S0e |
| `resetMonthlyPool` 트랜잭션 idempotency | **부분 확인** — port 시그니처 + cron 호출 형태 확인. 내부 `$transaction` 본문(FOR UPDATE idempotency)은 S0d Read로 재확인 | S0d |
| HIGH-1 案 B 영향 범위 (사용자 결정 입력) | **확인** — 본 계획 §4-2: 案 A 영향 1곳(changeTier 트랜잭션) vs 案 B 영향 7곳(읽기 경로) + DI 5건 + spec 7건 + HTTP 노출. 사용자 §6 게이트 | §6 게이트 |
| `Author.planExpireAt` 案 A 동기 정책 | **미확인** — `MembershipPlan.expiresAt` 미러 / `poolResetAt` 미러 / 별도 정책 결정 필요. H2a 결정 | H2a |
| `CreditLog` 다른 메서드 호출처 (`adjustCredits`/`sumNegativeAmounts`) | **미확인** — CC-3 범위 외(`getGiftRanking`/`getLogs`만 이행). CC-4 후속 sprint 입력 | CC-4 후속 |
| `MembershipPlanPort` 진입점 위치 (案 (i) port vs (ii) usecase 인라인) | **결정 — 案 (i)** — port에 신설(L2a 권고). L2b 구현 | L2b |
| sub-task 시간 추산 | 상대 추산 — 실측 아님. 본 계획은 분해 단위, 실제 시간은 server 실행 시 확정 | — |

> 본 계획은 코드 변경 0건 — 순수 계획 수립. 모든 file:line은 CREDIT_CORE_DIAGNOSIS 진단 리포트 + 본 계획 작성 중 실제 Read(`prisma-credit-ledger.repository.ts`/`reset-monthly-pool.job.ts`/`membership-plan.port.ts`/`credit.usecase.ts`/`prisma-credit.repository.ts`/`plan.usecase.ts`/`theme-slot.usecase.ts`/`shared-contracts.md §30`) + grep(`Author.plan`/`getGiftRanking`/`sensor-`) 기반. 미확인은 §14에 명시 — 추정 0건.

---

## 15. 변경 이력

- 2026-05-20: 본 계획 신설. CC-3(S0 5 + L1a 설계결정 1 + lazy 구현 6 + H1a 설계결정 1 + 案 A 구현 4 + HIGH-3 재작성 4 + 통합 spec 3 + sensor 권고 1 + 마무리 5 = 30 sub-task — 案 B 채택 시 H2e~H2g 추가) writing-plans 양식 분해. CRITICAL-1 권고 = 案 B(cron + lazy 이중 안전망 — `MembershipPlanPort.checkAndResetExpiredPool` 신설, `getPointBalance` 진입). HIGH-1 권고 = 案 A(`Author.plan` 정본 유지 + `MembershipPlan.tier` 미러, `changeTier` 양측 동기). 案 B는 §6 사용자 게이트로 회부 — 영향 범위 7곳 + DI 5건 큰 리팩토링이라 CC-3 분할 결정 필요. HIGH-3 권고 = `getGiftRanking`/`getLogs` `CreditLedger` 기반 재작성(`CreditLedgerPort.getGiftRanking` 신설 + `findByAuthor` 위임). `MembershipPlanPort.getPlan` HTTP 노출 = CC-5 PAY-P1-4 이월(권고). 사용자 결정 게이트 1건(§6 案 A vs 案 B). CC-3 완료 = CRITICAL-1·HIGH-1·HIGH-3 해소 + V Phase 마이그레이션 자격 충족. 코드 변경 0건 — 계획 수립 전용.
