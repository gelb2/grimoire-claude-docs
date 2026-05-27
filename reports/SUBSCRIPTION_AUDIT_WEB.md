# 구독제(membership) web 구현 Audit — SUBSCRIPTION_AUDIT_WEB

> **작성**: 2026-05-18 — grimoire-web 에이전트 (순수 audit, 코드 수정 0건)
> **대상**: 크레딧 개편 I Phase web 구독제 부분 (`develop` 브랜치, web 커밋 `3e9bb06`→`20ee379`)
> **정본 종속**: `research/CREDIT_PRICING_OVERHAUL_PLAN.md` §8-3 + `.claude/state/sprint-credit-overhaul-s-phase-draft.md` + `.claude/shared-contracts.md` §30
> **방법**: 실제 파일 Read + grep 실측 + vitest 실행. 추정 항목은 "미확인" 명시.

---

## 0. 한 줄 요약

구독제 web 구현은 **표시 전용 UI로 명시적으로 설계**되어 있으며, 그 경계(`MembershipPlans` 주석·`MembershipPage` 안내·`onSelect` 미전달)는 정직하게 지켜진다. 데이터는 전량 하드코딩(`MEMBERSHIP_PLANS` 상수)이나 server `§30` 정본 수치와 **정확히 일치**한다. **CRITICAL 0건 / HIGH 0건**. 핵심 갭은 (1) "현재 플랜" 배지가 server에 tier 노출이 없어 **영구 dead path**라는 점, (2) `dashboard/page.tsx`의 구(舊) `CreditsSection`이 디노미 미전환 채 잔존해 **같은 사용자에게 두 단위(크레딧/포인트)가 동시 노출**되는 점 — 둘 다 MEDIUM.

---

## 1. 반드시 답할 질문 — 직답

### Q1. `MembershipPlans.tsx`는 플랜 데이터를 API에서 받는가, 하드코딩인가? server 정본과 일치하는가?

**하드코딩(상수)이다. 그리고 server §30 정본과 정확히 일치한다.**

- `MembershipPlans.tsx:16` → `import { MEMBERSHIP_PLANS } from './credit-overhaul'`. API 호출 0건.
- `credit-overhaul.ts:105-141` `MEMBERSHIP_PLANS` 상수가 `MEMBERSHIP_MONTHLY_POOL`(L81-85)·`MEMBERSHIP_PRICE_KRW`(L88-92)를 참조해 구성됨.
- **수치 대조 (web 상수 vs `shared-contracts.md` §30 / 정본 §8-3)**:

  | 항목 | web `credit-overhaul.ts` | §30 / §8-3 정본 | 일치 |
  |---|---|---|---|
  | Pro 가격 | `pro: 9900` (L90) | ₩9,900 | ✅ |
  | Premium 가격 | `premium: 19900` (L91) | ₩19,900 | ✅ |
  | Pro 월 풀 | `pro: 93000` (L83) | 93,000pt | ✅ |
  | Premium 월 풀 | `premium: 191500` (L84) | 191,500pt | ✅ |
  | Free 풀 | `free: 0` (L82) | 없음 | ✅ |

- drift 위험: **존재하나 부분적으로 방어됨**. `credit-overhaul.test.ts:45-60`이 `MEMBERSHIP_MONTHLY_POOL`·`MEMBERSHIP_PRICE_KRW`·`MEMBERSHIP_PLANS` 3개를 정확한 리터럴(`{ free: 0, pro: 93000, premium: 191500 }` 등)로 검증 → web 내부 회귀는 차단. **단 server가 §30 수치를 바꿔도 web 테스트는 통과** — server↔web 간 drift는 `shared-contracts §30` "동시 갱신" 규칙(문서 규약)에만 의존하고 자동 게이트가 없다. 이는 web 단독 audit 범위로는 LOW (M-3 참조).

### Q2. 구독 가입/업그레이드/해지 버튼·액션이 있는가? 동작하는가, dead UI인가?

**사실상 없다. 그리고 dead UI가 아니다 — "표시 전용"으로 명시적·정직하게 설계됨.**

- `MembershipPlans.tsx`는 `onSelect` prop이 주어질 때만 `<button>`을 렌더(L73-84), 없으면 `<div>`(L86-90).
- **실제 사용처는 단 1곳** — `dashboard/membership/page.tsx:45` `<MembershipPlans />` — `onSelect` **미전달**. grep 실측(`grep -rn "MembershipPlans" src/app/`)으로 호출처 1건 확인, `onSelect` 전달 0건.
- 따라서 운영 화면에는 **클릭 가능한 버튼 자체가 렌더되지 않는다** → "클릭했는데 백엔드가 없다"는 dead UI 상황이 아예 발생 불가.
- `MembershipPage`는 안내 문구로 경계를 정직하게 고지: `page.tsx:53` "멤버십 구독 결제는 준비 중입니다. 현재는 포인트 충전으로 이용해 주세요." + `MembershipPlans.tsx:9-11` 주석 "Polar 구독 결제 연동은 I Phase 외 ... 실 결제 호출 없음."
- **결론**: 가입/업그레이드/해지 액션은 의도적으로 미구현. server에 구독 결제·tier 변경 엔드포인트가 없는 현실(`PAY-P1-4` 별도 sprint)과 web UI가 **정합**하다. 위험 아님.

### Q3. 4-source 잔액 표시(`/credits/balance`)가 정확하고 BFF 프록시를 경유하는가?

**정확하고, BFF 프록시를 경유한다. 백엔드 직접 호출 위반 0건.**

- `CreditsPage`(`dashboard/credits/page.tsx:87`) → `api.getPointBalance()` → `api.ts:461-464` → `this.fetch('/credits/balance')`.
- `api/client.ts:3-8` `getApiBase()` — `typeof window` 분기: 브라우저면 `'/api'`(상대경로 → BFF 프록시), 서버면 `process.env.API_URL`. **`NEXT_PUBLIC_API_URL` 미사용** 확인.
- `CreditsPage`는 `"use client"`(L1) 클라이언트 컴포넌트 → `getApiBase()`가 `'/api'` 반환 → `/api/[...path]/route.ts`(BFF 프록시) 경유. 백엔드 URL 직접 노출 0건.
- 4-source 정확성: server `§30 CreditBalanceResponseDto`(`available/total/deficit/bySource`)를 `point-balance.ts normalizePointBalance`(L39-72)가 3형태(bySource / available / 정수 credits)로 분기 정규화. `CreditBalanceCard.tsx:80` `{bySource && ...}` — server가 `bySource`를 줄 때만 4출처 분해, 안 주면 미표시(없는 값 추정 금지 — CLAUDE.md §0 정합). `point-balance.test.ts` 11건이 3형태 + 음수 클램프 + null 방어를 검증.
- server `§30 follow-up`(`1ba8c9f`→`9d0d2b7`)으로 `/credits/balance`가 이미 `bySource` 4출처를 반환 → web의 4출처 분해 표시가 실제 활성. 정합 확인.

### Q4. 사용자가 UI에서 백엔드가 못 받는 작업을 하게 되는 위험 지점이 있는가?

**구독 도메인에서는 없다.** 위에서 본 대로 멤버십은 표시 전용·버튼 미렌더. 단 인접 영역에 1건:

- `MembershipPlans`의 `currentTier` prop(L19, "현재 플랜" 배지)은 **호출처에서 절대 채워지지 않는다** — `AuthUser` 타입(`src/types/api.ts:3-11`)에 `plan`/`tier` 필드가 **없고**, server에 사용자 tier를 주는 엔드포인트도 없다(M-1 참조). 백엔드가 못 받는 "작업"은 아니나, **영구히 죽은 표시 경로**다.
- 충전 패키지(`CreditsPage`)는 구독 범위 외이나 audit 중 발견 → M-4 참조(구 3패키지 폴백이 §8-5 신 4패키지와 불일치).

### Q5. 디노미네이션 큰 숫자(93,000pt 등) 표시 처리가 됐는가?

**됐다. 천단위 구분 + 축약 2단계 + `tabular-nums` 정렬까지 처리.**

- `formatPoints`(`credit-overhaul.ts:156-158`) — `toLocaleString('ko-KR')` 천단위 콤마. `MembershipPlans.tsx:57` `월 {formatPoints(plan.monthlyPool)} pt` → "월 93,000 pt".
- `abbreviatePoints`(L167-178) — 1만↑ "9.3만", 1억↑ "1.2억". `CreditBalanceCard.tsx:66` 잔액 헤드라인은 축약, `title`·하단에 `formatPoints` 정확값 동반 표시(L66·69).
- `MembershipPlans.tsx:56`·`CreditBalanceCard.tsx:52`·`ChatChargeGuide.tsx:29` 모두 `tabular-nums` 클래스 → 숫자 폭 고정.
- `credit-overhaul.test.ts:75-110` `formatPoints`/`abbreviatePoints` 경계값(0·소수·1만·5만·1억) 검증. `§8-1` "표시 큰 숫자는 천단위 구분·축약 UI로 완화" 요구를 충족.
- 사소 관찰: `MembershipPlans` 카드의 월 풀 표시는 `formatPoints`(축약 안 함) → "93,000 pt" / "191,500 pt"가 그대로 노출. §8-1은 축약을 "완화"로 권하나 카드 컨텍스트에서 정확값 노출은 합리적 — 위반 아님(L-2 참조).

### Q6. vitest 커버리지 갭 — 구독/멤버십 관련.

**핵심 경로는 커버됨. 갭은 "선택 동작 경로"와 "통합(페이지) 렌더" 2건.**

- 실행 결과(`npx vitest run src/features/credits/ src/app/admin/tabs/CreditsTab.test.tsx`): **6 파일 / 52 테스트 전부 PASS**.
- `MembershipPlans.test.tsx` 8건 — 3등급 라벨·가격·월 풀·배지·`onSelect` 버튼/콜백 검증. 양호.
- 갭: ① `MembershipPlans`에 `selectedTier`를 준 "선택 강조" 상태(`stateClass` `isSelected` 분기, `MembershipPlans.tsx:37-39`)는 미검증 — 단 운영에서 `onSelect` 미사용이라 실해(實害) 낮음. ② `dashboard/membership/page.tsx`(MembershipPage) 자체의 렌더·미인증 리다이렉트·안내 문구는 테스트 0건 — 페이지 레벨 vitest/E2E 부재(M-5 참조).

### Q7. 명백한 시각 정본(사슴악마) 불일치 — 명백한 것만.

- `MembershipPlans`/`CreditBalanceCard`/`ChatChargeGuide` 전부 `neutral-*` 스코핑 + `#f5f5f5`/`#e53e3e` — 플랫폼 페이지 정본 톤. `dashboard/credits/page.tsx`의 기존 디자인과 동일 팔레트. **명백한 불일치 발견 0건**.
- **단 임의 hex 색상 직접 사용 다수** — `MembershipPlans.tsx:39,49`·`CreditBalanceCard.tsx:66,73`·`ChatChargeGuide.tsx:38,53` 등에서 `bg-[#f5f5f5]`·`text-[#e53e3e]`. 메모리 `feedback_no_design_tokens.md`("globals.css 디자인 토큰 금지")상 hex 인라인이 이 프로젝트의 합의된 방식이며 기존 `dashboard/credits/page.tsx`와 일관 → 정본 불일치로 보지 않음. 상세 시각 검수는 VCK 영역.

---

## 2. 발견 사항 (심각도별)

### CRITICAL — 0건

없음.

### HIGH — 0건

없음. (BFF 프록시 위반·localStorage 토큰·백엔드 직접 호출·dead 결제 버튼 — 전부 해당 없음)

### MEDIUM

#### M-1. "현재 플랜" 배지가 server tier 미노출로 영구 dead path

- **위치**: `MembershipPlans.tsx:19` (`currentTier?` prop), `:31` (`isCurrent` 계산), `:45-47` (배지 렌더) / 호출처 `dashboard/membership/page.tsx:45`.
- **근거**: `MembershipPlans`는 `currentTier`를 받아 "현재 플랜" 배지를 그릴 수 있게 설계됐으나, 유일 호출처가 `currentTier`를 **미전달**. 전달하려 해도 source가 없다 — `AuthUser` 타입(`src/types/api.ts:3-11`)에 `plan`/`tier` 필드 부재, server에 사용자 멤버십 tier를 반환하는 엔드포인트 부재(`grep -rn "@Controller" controller/` 실측 — `membership` 컨트롤러 0건; `MembershipPlanPort`는 `domain/port` + `prisma-membership-plan.repository`만 존재, HTTP adapter 없음). `shared-contracts §30` 변경이력(L2488-2489)도 "`MembershipPlanPort` HTTP 노출"을 **잔여 후속 과제**로 명시.
- **영향**: 사용자는 멤버십 화면에서 자신이 현재 어느 등급인지 web상 확인 불가. 기능 결손이며, 코드에 "쓰이지 않는 prop 경로"가 잔존.
- **권고**: I Phase 범위로는 수용 가능(설계 경계와 정합). 단 `MembershipPlanPort` HTTP 노출 sprint 착수 시 ① `GET /plan` 또는 신설 멤버십 엔드포인트가 tier 반환 ② `AuthUser`에 `tier` 추가 또는 별도 훅 ③ `MembershipPage`가 `currentTier` 전달 — 3건을 동반 과제로 묶을 것. 그 전까지 `MembershipPage`에 "현재 등급 표시는 준비 중" 한 줄을 두는 것도 정직성 측면에서 고려 가능.

#### M-2. 구 `CreditsSection`이 디노미 미전환 — 같은 사용자에게 크레딧·포인트 단위 동시 노출

- **위치**: `src/app/dashboard/_components/CreditsSection.tsx` 전체 / 사용처 `src/app/dashboard/page.tsx:90`.
- **근거**: `CreditsSection`은 크레딧 개편 I Phase web 커밋(`3e9bb06`→`20ee379`)의 diff 대상에 **포함되지 않음**(`git diff --stat` 실측 — 22개 변경 파일에 `CreditsSection.tsx` 없음). 내용도 구(舊) 정수 크레딧 그대로: `:22` `{credits}` 정수 출력, `:23` "잔여 크레딧", `:26` "테마 AI 생성: 1 크레딧". 반면 같은 사용자가 진입하는 `dashboard/credits/page.tsx`는 디노미 전환 완료 — 포인트(pt) 단위, "테마 AI 생성: 590 pt"(`THEME_POINT_COST`).
- **영향**: `/dashboard`(대시보드 메인)에서는 "N 크레딧 / 테마 1 크레딧", `/dashboard/credits`에서는 "590 pt"가 노출된다. **동일 재화가 두 단위·두 수치로 보임** → 사용자 혼란. 디노미네이션 개편의 핵심 UX 리스크(§8-1 "표시 혼란")가 실제 발생.
- **권고**: `CreditsSection`을 디노미 전환(`creditsToPoints(credits)` + `formatPoints` + "잔여 포인트" + 테마/분석 차감 pt 표기) 하거나, 또는 대시보드 메인에서는 잔액 요약을 `creditsToPoints`로만 환산 표시하고 차감 단가 문구를 제거. **별도 sprint 권장** — 본 audit는 코드 수정 금지. (이 항목은 "구독" 직접 범위는 아니나 멤버십 화면이 `dashboard/credits` ↔ `dashboard/membership` 동선 안에 있어 같은 단위 일관성 문제로 보고.)

#### M-3. server↔web §30 수치 drift 자동 게이트 부재

- **위치**: `credit-overhaul.ts:80-141` (`MEMBERSHIP_MONTHLY_POOL`/`MEMBERSHIP_PRICE_KRW`/`MEMBERSHIP_PLANS` 하드코딩) / `credit-overhaul.test.ts:45-60`.
- **근거**: web 멤버십 수치는 server `§30` 도메인 정본(`grimoire-server/src/domain/model/membership-tier.ts`)을 **수기 미러**. `credit-overhaul.ts:10-11` 주석이 "수치 재산정 금지 — §30 변경 시 동시 갱신"을 명시하나, 이는 **사람·문서 규약**일 뿐. `credit-overhaul.test.ts`는 web 리터럴을 web 리터럴로 검증 → server가 §8-3 가격/풀을 바꿔도 web 테스트는 그대로 PASS. drift는 `shared-contracts §30` "동시 갱신" 절차에만 의존.
- **영향**: 현재 시점 수치는 일치(Q1 표). 위험은 미래 — server `MembershipPlan` HTTP 노출 sprint나 가격 조정 시 web 미러 갱신 누락 가능.
- **권고**: `MembershipPlanPort` HTTP 노출 시 web이 플랜 데이터를 API에서 받도록 전환(하드코딩 제거 — 근본 해소). 그 전까지 임시로는 sensor(`sensor-credit-*` 5종 중 `credit-denomination`/신설)에 server↔web 멤버십 수치 대조를 1줄 추가하는 것을 검토. 본 audit는 sensor 수정도 하지 않음 — 권고만.

#### M-4. 충전 패키지 미연결 폴백이 §8-5 신 4패키지와 불일치 (구독 인접 — 참고)

- **위치**: `dashboard/credits/page.tsx:79-86` (`api.getProducts()` catch 폴백).
- **근거**: server 미연결 시 폴백이 구 3패키지(`credit-5`/`credit-20`/`credit-50`, ₩2,000/₩3,000/₩5,000). 정본 §8-5는 신 4패키지(입문 ₩3,000 / 기본 ₩5,000 / 인기 ₩10,000 +10% / 베스트 ₩30,000 +15%). `shared-contracts §30`(L2489)도 "`CREDIT_PRODUCTS` #7 4종 갱신"을 잔여 과제로 명시 — server `CREDIT_PRODUCTS`가 아직 구 3종이라 폴백도 구 3종으로 둔 것은 server 현실과 정합이나, **정본 §8-5와는 불일치**.
- **영향**: server 정상 연결 시에는 server 응답을 쓰므로 실해는 server 미연결 케이스 한정. 단 사용자가 보는 패키지가 정본과 다를 수 있음.
- **권고**: server `CREDIT_PRODUCTS` 4종 갱신 sprint와 동시에 web 폴백도 4종으로 갱신. 구독 직접 범위 아님 — 참고용 보고.

### LOW

#### L-1. `MembershipPlans` `onSelect`/`selectedTier` 경로 무테스트 + 운영 미사용 — 미사용 코드 잠재

- **위치**: `MembershipPlans.tsx:21-24,33,37-39,73-84`.
- **근거**: `onSelect`·`selectedTier` prop과 버튼 분기는 구현·테스트(`MembershipPlans.test.tsx:61-70`)되어 있으나 운영 호출처 0건. `selectedTier` 강조 상태는 테스트조차 없음.
- **권고**: 결제 연동 sprint 전까지는 "미래 대비 스캐폴딩"으로 수용 가능. 단 그 sprint가 무기한 밀리면 미사용 코드. 결제 sprint 시 `selectedTier` 경로 테스트 보강 + 실연결 권고.

#### L-2. `MembershipPlans` 카드 월 풀이 축약 미적용 — 6자리 그대로 노출

- **위치**: `MembershipPlans.tsx:57` (`formatPoints(plan.monthlyPool)`).
- **근거**: 카드에 "191,500 pt"가 천단위 콤마로만 노출(6자리). §8-1은 "큰 숫자는 축약 UI로 완화" 권장.
- **권고**: 카드 컨텍스트에서 정확한 풀 크기 노출은 구매 판단에 유익 → 현 구현 합리적, **변경 불필요**. abbreviate는 잔액 헤드라인(`CreditBalanceCard`)처럼 좁은 공간에만 적용하면 충분. 관찰 기록 목적.

#### L-3. `MembershipPage`가 PlatformNav 단독 — 대시보드 동선 일관성 (미확인 가능성)

- **위치**: `dashboard/membership/page.tsx:31` `<PlatformNav />`.
- **근거**: `MembershipPage`/`CreditsPage` 모두 `PlatformNav` 사용 — `grimoire-web/CLAUDE.md §2`("플랫폼 페이지에서만 PlatformNav") 정합. dashboard 하위 페이지의 네비 일관성은 정상.
- **미확인**: dashboard 하위 페이지들이 공통 사이드/탭 네비를 갖는지는 본 audit 범위 밖 — `dashboard/credits`와 동일 패턴이므로 일관성 위반 아님으로 판단하나, 대시보드 IA 전반은 미검증.
- **권고**: 없음(정합). 기록 목적.

---

## 3. 잘 된 점 (audit 긍정 소견)

- **설계 경계의 정직성**: "표시 전용"이 주석(`MembershipPlans.tsx:9-11`)·페이지 안내(`MembershipPage:53`)·실제 코드(`onSelect` 미전달 → 버튼 미렌더)에서 **3중으로 일관**. 사용자를 "결제될 것처럼" 오도하지 않음.
- **추정 금지(§0) 준수**: `point-balance.ts`·`CreditBalanceCard.tsx:80`·`ChatChargeBadge.tsx:24` 모두 "server가 안 준 값은 만들지 않는다"를 코드로 구현. backward-compatible 3형태 분기(`normalizePointBalance`)도 견고.
- **BFF·보안**: 백엔드 직접 호출 0건, `NEXT_PUBLIC_API_URL` 미사용, localStorage 토큰 0건. 전 호출 `/api` 상대경로 → BFF 프록시.
- **디노미 표시**: 천단위+축약 2단계 + `tabular-nums`. `credit-overhaul.test.ts`가 경계값 회귀 차단.
- **테스트**: 신설 `features/credits/` 슬라이스 6파일 52테스트 전부 PASS. 핵심 도메인 상수·정규화 로직은 잘 커버.

---

## 4. 검증 로그 (실측 증거)

```
$ npx vitest run src/features/credits/ src/app/admin/tabs/CreditsTab.test.tsx
 Test Files  6 passed (6)
      Tests  52 passed (52)

$ grep -rn "MembershipPlans" src/app/
src/app/dashboard/membership/page.tsx:8:import { MembershipPlans } from '@/features/credits'
src/app/dashboard/membership/page.tsx:45:        <MembershipPlans />
  → onSelect 전달 0건 확인 (dead 결제 버튼 없음)

$ grep -rn "@Controller" grimoire-server/src/adapter/inbound/http/controller/ (--exclude spec)
  → 'membership' 컨트롤러 0건. credits/plan 컨트롤러에 tier 반환 엔드포인트 없음.

$ git diff --stat 3e9bb06~1 20ee379
  → 22 files. CreditsSection.tsx 미포함 (디노미 미전환 잔존 확인 — M-2)

$ AuthUser 타입 (src/types/api.ts:3-11)
  → plan/tier 필드 없음 (currentTier 배지 dead path 확인 — M-1)
```

server 측 §30 정본 대조: `shared-contracts.md` §30 L2422 `MEMBERSHIP_MONTHLY_POOL = { free: 0, pro: 93000, premium: 191500 }` ↔ web `credit-overhaul.ts:81-85` 동일. `§8-3` 가격 ₩9,900/₩19,900 ↔ web `MEMBERSHIP_PRICE_KRW` 동일.

---

## 5. 종합 권고 우선순위

| # | 심각도 | 항목 | 권고 시점 |
|---|---|---|---|
| M-2 | MEDIUM | `CreditsSection` 디노미 전환 (크레딧↔포인트 단위 혼재 해소) | 별도 sprint — 디노미 UX 일관성, 우선순위 높음 |
| M-1 | MEDIUM | "현재 플랜" 배지 — `MembershipPlanPort` HTTP 노출 sprint와 `AuthUser.tier`/배지 전달 동반 | `MembershipPlanPort` HTTP 노출 sprint와 묶음 |
| M-4 | MEDIUM | 충전 패키지 폴백 4종 갱신 | server `CREDIT_PRODUCTS` 4종 갱신 sprint와 동시 |
| M-3 | MEDIUM | server↔web §30 수치 drift 자동 게이트 (sensor 또는 API화) | M-1과 함께 — HTTP 노출 시 web 하드코딩 제거로 근본 해소 |
| L-1 | LOW | `MembershipPlans` 선택 경로 테스트 + 실연결 | 결제 연동 sprint(PAY-P1-4) |

**코드 수정 0건 — 본 문서는 순수 audit. 수정은 별도 sprint에서 수행.**
