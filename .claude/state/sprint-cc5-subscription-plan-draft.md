# 작업 계획: CC-5 — PAY-P1-4 Polar 구독 정기결제 연동 + HIGH-1 案 B (writing-plans)

> 작성: 2026-05-22 / grimoire-planner (Initializer 패턴) / **계획 수립 전용 — 코드 변경 0건**
> 근거 정본: `reports/CREDIT_CORE_DIAGNOSIS.md` §7(PAY-P1-4 7항) + §5-A(HIGH-1 案 A/B) + §8 Sprint 분할표 CC-5 행
>           + `research/CREDIT_PRICING_OVERHAUL_PLAN.md` §8-3(멤버십 가격/풀) + §8-7(S Phase 선행)
>           + `grimoire-server/docs/ai-cost-table.md` §4·§7-5(멤버십 §0 검증) + `.claude/shared-contracts.md` §30
>           + `reports/SUBSCRIPTION_AUDIT_SERVER.md`(HIGH-1·MEDIUM-3) + `reports/SUBSCRIPTION_AUDIT_WEB.md`(M-1)
> 적용 양식: `.claude/skills/writing-plans/SKILL.md` (2~5분 sub-task / [MUST]·[SHOULD]·[NICE] / 위험도 🔴🟡🟢 / 의존 / rollback / 검증 게이트)
> 구조 정본: `.claude/state/sprint-cc2a-charge-wiring-plan-draft.md` (CC-2a 계획과 동일 섹션 구조·포맷)
> 범위: **CC-5 (PAY-P1-4 Polar 구독 연동, 규모 L) + HIGH-1 案 B (`MembershipPlan.tier` 정본화, 규모 M)** 묶음 sprint. §2 sprint 분할 권고 = Phase 분할 (A·B·C 3 Phase, 단일 sprint 유지).

---

## 0. 진행 순서 + 의존 개요

```
CC-1·CC-2(a+b)·CC-3 (적립·충전·선물·환불·이월·원장 — 완료) ──선행 완료──> CC-5
                                                                  │
   PAY-S1 (로컬 DB 동기화 — credit_overhaul_i_phase) ──DB 전제──────┤
                                                                  │
                          ┌── S0 선행: §1 미확인 7건 Read 해소 ────┘
                          │
        ┌─────────────────┴──────────────────┬───────────────────┐
   Phase A — 案 B 선행          Phase B — Polar 구독 webhook    Phase C — HTTP·통합·web 핸드오프
   (Author.plan deprecated      (subscription.* 4 이벤트 +      (POST /subscriptions/checkout +
    + 읽기 13곳 이행)            usecase + changeTier 연동)       GET /membership + 통합 spec)
        │                              │                              │
        └──────────────────────────────┴──────────────────────────────┘
                          Polar 구독 상품 등록 (메인 API 등록 — §3, 코드와 병렬)
```

- **CC-1~CC-3 선행 완료** — 적립 8경로 신 `CreditLedger` 시스템 + 구 시스템 폐기 (prod rev 105). CC-5는 그 위에 구독 결제 연동을 얹는 마지막 큰 미연동 기능.
- **PAY-S1 로컬 DB 동기화가 DB 전제** — CC-5 통합 spec이 신 스키마(`membership_plans`/`credit_ledgers`/`Author.plan`)를 전제. 로컬에 `20260517_credit_overhaul_i_phase`가 적용돼야 통합 테스트 실행 가능.
- **S0 선행 게이트** — 진단 §7 + §5-A가 file:line만 제시 → S0 sub-task에서 7건 현행을 Read로 해소한 뒤 본 작업 진입. 특히 **진단(2026-05-18 `658b7d9`) 이후 CC-1~CC-3 머지로 코드가 이동** — `changeTier`가 이미 `Author.plan` 동기 갱신(案 A, ADR-014), webhook 화이트리스트 현행 등은 S0가 재실측.
- **Phase 분할 (§2 권고)** — CC-5(L)+案 B(M)를 **단일 sprint·3 Phase**로 진행. Phase A(案 B)가 선행 — `Author.plan` 읽기 경로를 `MembershipPlanPort.getPlan` 경유로 이행해 두면 Phase B의 `changeTier` 정본화가 자연 정합. Phase B·C는 Phase A 완료 후.
- **graceful 설계가 CC-5의 단일 최대 설계 결정** — env(`POLAR_PRODUCT_SUBSCRIPTION_PRO/_PREMIUM`) 미설정 시 구독 checkout만 비활성, 나머지(webhook 수신·`GET /membership`·기존 충전·테마·분석) 전부 정상. §4가 상세.

### 예상 총 시간

- CC-5: **규모 L+M** — 본 계획 sub-task 합산 ~9.5~14h.
- sub-task 총 **38개** (S0 7 + Phase A 案 B 9 + Phase B webhook 11 + Phase C HTTP·통합 8 + 마무리 3).
- **분할 근거**: ≥30분 + **돈 직결 도메인**(정기결제 — CLAUDE.md §9 결제 원자성 절대 규칙) + 마지막 큰 미연동 기능(PAY-P1-4 미착수 확정) + 案 B `Author.plan` 읽기 13곳 이행은 1곳 누락 시 테마 슬롯·일일 무료 불일치 직결 + Polar webhook 4 이벤트 멱등성/원자성 → sub-task 단위 검증 게이트 + git commit 단위 rollback 필수.

---

## 1. S0 — 선행: 진단 §7·§5-A 미확인 7건 현행 해소 (착수 게이트)

> CREDIT_CORE_DIAGNOSIS §7 + §5-A — 추정 금지. 진단 file:line은 `658b7d9`(2026-05-18) 시점 → CC-1~CC-3 머지로 이동했을 수 있음 → 본 sub-task가 **현행 재실측**.
> ⚠️ 본 계획 작성 중 일부는 이미 Read 확인(§12 표) — S0는 server 착수 시점 현행 재확인.

### 1-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C1a | `polar.adapter.ts` webhook 화이트리스트 현행 Read — `verifyAndParseWebhook` `switch (event.type)` 현행 case 목록(`order.paid`/`order.updated`/`order.refunded`/`checkout.updated` + `default: return null`) + `NormalizedWebhookEvent` 파싱 구조 확정 | [MUST] | 🟢 | 5분 | PAY-S1 P5 | 화이트리스트 현행 case 박제 (webhook 확장 diff 입력) |
| C1b | `payment-gateway.port.ts` `NormalizedWebhookEvent` 시그니처 Read — `status: 'success'\|'fail'\|'cancel'` 3값 확정. **구독 생명주기(created/updated/canceled/revoked)는 이 3값에 안 맞음** → §5가 신 필드/타입 설계 | [MUST] | 🟢 | 4분 | - | `NormalizedWebhookEvent` 현행 + 구독 표현 부적합 박제 |
| C1c | `membership-plan.port.ts` `MembershipPlanPort` 현 시그니처 Read — `getPlan`/`changeTier`/`resetMonthlyPool`/`findPlansToReset`/`checkAndResetExpiredPool` 5 메서드 + `MembershipPlanState`(`polarSubscriptionId` 필드 포함) 확정 | [MUST] | 🟢 | 4분 | - | `MembershipPlanPort` 5 메서드 시그니처 표 박제 |
| C1d | `prisma-membership-plan.repository.ts` `changeTier` 현행 Read — **CC-3가 案 A(ADR-014)로 `Author.plan`+`planExpireAt` 동기 갱신 중**임을 재확인. `changeTier`가 `polarSubscriptionId`를 받지/쓰지 않음 확인 → §6이 구독 매핑 저장 설계 | [MUST] | 🟢 | 5분 | - | `changeTier` 현행 $transaction 본문 박제 (案 B 전환 + polarSubscriptionId 입력) |
| C1e | `Author.plan` 읽기 전수 grep + Read — `grep -rn "\.plan\b\|planExpireAt" src/application src/adapter`(spec 제외). 진단 §5-A "~13곳" 실측 확정. 본 계획 작성 중 6 파일 확인(theme-slot/generate-theme/get-theme/plan.usecase/admin.usecase + author.repository) — server가 전수 재실측 | [MUST] | 🟢 | 6분 | - | `Author.plan` 읽기 전 호출처 표 (案 B 이행 sub-task 입력) |
| C1f | `MembershipPlan.polarSubscriptionId` + `WebhookEvent` 멱등성 게이트 Read — `schema.prisma` `MembershipPlan.polarSubscriptionId String? @unique` 확인 + `payment.usecase.ts:276` `webhookEventRepo.findByEventId` 멱등성 게이트 구조 확정 (구독 webhook 재사용 입력) | [MUST] | 🟢 | 5분 | - | `polarSubscriptionId` 스키마 + 멱등성 게이트 박제 |
| C1g | 멤버십 가격 정본 + Polar 구독 상품 등록 가부 Read — `ai-cost-table.md §4`(Pro ₩9,900/93,000pt·Premium ₩19,900/191,500pt §0 PASS) + §7-5 + `shared-contracts §30` 확인. **priceUsd 정본 유무 판정** — 충전 패키지 패턴(`CREDIT_PRODUCTS` priceUsd 299/499/999/2999) 대비 멤버십 priceUsd 미존재 확인 → §3 게이트 발동 여부 결정 | [MUST] | 🟢 | 6분 | - | 멤버십 가격 §0 PASS 박제 + priceUsd 정본 유무 판정 |

**S0 게이트**: C1a~C1g [MUST] 7건 완료 = 진단 §7·§5-A 미확인 해소 → Phase A 진입 허가. 미확인 잔존 시 본 작업 착수 금지.

> 진단 §10 미확인 중 CC-5 직접 관련 = "Polar KYC / test mode 상태"(§3 등록 게이트 종속) — S0가 아닌 §3 사용자 게이트에서 확인. 그 외 §10 항목(dev plan 분포 등)은 CC-4 영역.

---

## 2. sprint 분할 권고 — CC-5(L) + 案 B(M) 단일 sprint 3 Phase

> CREDIT_CORE_DIAGNOSIS §8 Sprint 분할표 — CC-5(PAY-P1-4) L / HIGH-1(案 B) M. 사용자가 "CC-5와 함께 案 B 진행" 지시 → planner가 단일 sprint vs 분리를 권고.

### 2-1. 권고 — **단일 sprint·3 Phase** (분리 안 함)

| 案 | 구조 | 장점 | 단점 |
|---|---|---|---|
| **案 ① 분리** — CC-5 / 案 B 별도 sprint | 案 B 먼저 머지 → CC-5 별도 착수 | sprint 단위 작음 | **案 B 단독은 효용 절반** — 案 B의 `Author.plan` deprecated가 의미를 가지려면 `MembershipPlan.tier`를 갱신하는 활성 진입점(`changeTier`)이 실제 호출돼야 함. CC-5 없이 案 B만 하면 `changeTier` 호출처는 여전히 cron뿐 → "정본화"가 형식적. 진단 §5-A "CC-5의 `changeTier`가 활성화되면 案 B가 자연 정합" |
| **案 ② 단일 sprint·3 Phase (권고)** | Phase A(案 B) → Phase B(webhook) → Phase C(HTTP·통합) 순차 | 案 B 이행으로 `Author.plan` 읽기가 `getPlan` 경유 → Phase B `changeTier`가 정본 갱신 진입점이 되어 案 B 완결. 한 sprint 안에서 案 B↔CC-5 정합 검증 | sub-task 38개로 큼 — Phase 게이트로 분할 진척 관리 |

**권고 — 案 ② (단일 sprint, Phase A·B·C 3 Phase)**. 사유:

1. **案 B와 CC-5는 같은 뿌리** — 진단 §5-A·CC-3 plan-draft가 명시: 案 A(현행 ADR-014)는 "`Author.plan` 정본 + `tier` 미러"이고, 案 B는 "`tier` 정본 + `Author.plan` deprecated". CC-5의 `changeTier`가 구독 webhook으로 활성화되는 순간 案 B가 자연 정합 — 분리하면 案 B 머지~CC-5 머지 사이 과도기에 "정본 전환 미완"이 떠 있다.
2. **Phase 순서가 의존을 해소** — Phase A(案 B 이행)를 먼저 하면 `Author.plan` 읽기 13곳이 `MembershipPlanPort.getPlan` 경유로 바뀜 → Phase B의 `changeTier`가 "유일한 tier 변경 진입점"이 되고, `getPlan`이 모든 읽기의 정본 출처가 됨. 案 B를 나중에 하면 Phase B 구현 후 다시 읽기 경로를 갈아엎어야 함(작업 중복).
3. **단일 sprint 안에서 정합 검증** — Phase C 통합 spec이 "구독 webhook → `changeTier` → `MembershipPlan.tier` 갱신 → `getPlan`이 갱신 tier 반환 → 테마 슬롯·일일 무료가 그 tier 따름"을 한 번에 박제. 분리하면 이 통합 검증이 두 sprint에 쪼개짐.
4. **규모는 Phase 게이트로 관리** — 38 sub-task는 크나, Phase A 게이트 / Phase B 게이트 / Phase C 게이트로 분할 진척 추적(progress.md). CC-2a(28)·CC-3 선례가 이미 30+ sub-task 단일 sprint를 Phase로 관리.

> **단 案 B는 Phase A에서 ADR 재결정 동반** — CC-3가 案 A를 ADR-014로 박제했음 → Phase A 첫 sub-task가 "ADR-014 案 A → 案 B 전환 결정 명문화"(C2a). 사용자가 이미 案 B 진행을 지시했으므로 사용자 결정 게이트가 아닌 ADR 갱신 — 단 §10 사용자 결정 게이트에 "案 B 전환 확인" 1줄 포함(이미 지시받았으나 ADR 변경이라 명시).

---

## 3. Polar 구독 상품 등록 단계 + priceUsd 정본 게이트

> 사용자 요청 — "Polar CLI/API로 구독상품 등록 가능 확인" → **확인됨**(recurring product 생성 probe HTTP 201, `recurring_interval: "month"` + price `type: "recurring"`). 충전 패키지 등록 선례(2026-05-21): `POST /v1/products/` trailing slash, `organization_id` 금지(OAT org-scoped).

### 3-1. priceUsd 정본 유무 — 판정

| 항목 | 현황 (본 계획 작성 중 확인) |
|---|---|
| 멤버십 KRW 가격 | **정본 존재** — `ai-cost-table.md §4`: Pro ₩9,900 / Premium ₩19,900. §7-5가 Polar 수수료 차감 후 §0 PASS 검증 완료 (Pro 순₩9,164 / Premium 순₩18,874, 풀 누적원가 ≤ 구독료÷3). `shared-contracts §30` `MEMBERSHIP_PRICE_KRW` 정합. |
| 멤버십 priceUsd | 🔴 **정본 미존재** — `ai-cost-table.md`·`CREDIT_PRICING_OVERHAUL_PLAN.md §8-3` 어디에도 멤버십 USD 가격 없음. 충전 패키지는 `CREDIT_PRODUCTS`에 `priceUsd`(299/499/999/2999 — "₩X,000 ≈ $X.99" 패턴) 박제됐으나 멤버십은 KRW만. |

→ **Polar 구독 상품은 USD 가격으로 등록**(Polar는 USD 기준 MoR). 멤버십 priceUsd가 정본에 없으므로 **추정값 + 사용자/cost-accountant 게이트 필요**.

### 3-2. priceUsd 추정 + §0 게이트 (C3 sub-task)

- **추정 규칙** — 충전 패키지 패턴 차용: "₩X,000 ≈ $X.99". Pro ₩9,900 → **$9.99** / Premium ₩19,900 → **$19.99**. (환율 ₩1,497.08 기준 $9.99=₩14,956 / $19.99=₩29,926 — KRW 정가보다 높음 → 작가가 USD 결제 시 실수령 KRW가 정가 이상 → §0 안전 측면 보수적).
- **§0 재검증 필요 여부** — `ai-cost-table.md §7-5`의 §0 PASS는 **KRW 가격(₩9,900/₩19,900) 기준**. priceUsd($9.99/$19.99)로 등록하면 실 결제액이 환율 따라 변동 → cost-accountant가 "$9.99/$19.99 → KRW 환산 실수령액 기준 §0 재확인" 필요. 단 위 추정대로 USD 환산액이 KRW 정가 이상이면 §0은 더 안전해짐(마진 ↑) → **cost-accountant 게이트는 "확인" 수준**(차단 가능성 낮음).
- **C3 sub-task**: priceUsd 추정값($9.99/$19.99) 산출 → cost-accountant에 "$9.99/$19.99 KRW 환산 실수령 기준 §0 PASS 재확인" 의뢰 → `ai-cost-table.md §4`에 멤버십 priceUsd 행 추가(cost-accountant 승인) → §6 webhook usecase가 참조.

### 3-3. Polar 구독 상품 등록 — 등록 주체 권고

| 案 | 등록 주체 | 권고 |
|---|---|---|
| **案 A — 메인이 Polar API 등록** | 메인이 `POST /v1/products/` (recurring) 호출 — 3환경(dev/prod) 각 1회 | **권고** — probe로 API 등록 가능 확인됨. 충전 패키지 등록 선례(2026-05-21) 동일 절차 재사용. 메인이 등록 후 product ID를 env에 입력 → 사용자 작업 최소화 |
| 案 B — 사용자 대시보드 등록 | 사용자가 Polar 대시보드에서 수동 생성 | 사용자 작업 부담. 단 메인 API 등록 실패(권한/KYC) 시 폴백 |

**권고 — 案 A (메인 API 등록)**. 단 **§3-4 사용자 게이트 통과 후**:
1. 사용자가 priceUsd 추정값($9.99/$19.99) 승인 (또는 다른 값 지정).
2. cost-accountant가 priceUsd §0 재확인 PASS.
3. 메인이 dev/prod Polar org에 recurring product 2종 등록 (`recurring_interval: "month"`, price `type: recurring`).
4. 등록된 product ID를 `POLAR_PRODUCT_SUBSCRIPTION_PRO`/`_PREMIUM` env로 dev/prod 입력.

> **코드는 등록과 독립** — §4 graceful 설계로 코드·spec·문서는 Polar 등록 전 완전 선작업. Polar 상품 등록 + env 입력은 코드 머지와 병렬 가능, 미완 시에도 구독 외 기능 정상.

### 3-4. 사용자 결정 게이트 (Polar 구독 상품)

- **결정 대상**: (a) 멤버십 priceUsd 추정값 $9.99/$19.99 채택 여부 (b) Polar 구독 상품 등록 주체(메인 API vs 사용자 대시보드) (c) Polar KYC/test mode 상태 — 등록 가능 환경 확인.
- **게이트 판정**: §10 표 참조. 사용자가 추정값 채택 + 메인 API 등록 승인 시 C3 + 메인 등록 진행. priceUsd 변경 시 cost-accountant 재검증.

---

## 4. graceful 설계 — env 미설정 시 구독 기능 비활성 + 나머지 정상

> 사용자 의도 — "사용자가 나중에 Polar 구독 상품 등록 + env 설정만 해도 동작하게 L,M 로직 선작업". 코드가 env(`POLAR_PRODUCT_SUBSCRIPTION_PRO/_PREMIUM`)를 읽어 동작, **env 미설정 시 graceful**.

### 4-1. graceful 설계 결정 (C4a — Phase B 첫 sub-task에서 명문화)

| 기능 경로 | env 미설정 시 동작 |
|---|---|
| `POST /subscriptions/checkout` (구독 시작) | **비활성** — env(`POLAR_PRODUCT_SUBSCRIPTION_{tier}`) 미해결 시 `503 Service Unavailable` + 명확한 메시지("구독 결제가 아직 활성화되지 않았습니다"). `resolvePolarProductId` 패턴(`polar.adapter.ts:161` — null 반환) 재사용 |
| `subscription.*` webhook 수신 | **정상** — webhook 파싱·멱등성 게이트·`changeTier` 호출은 env 무관(수신 측). 단 운영상 구독 상품 미등록이면 webhook 자체가 발생 안 함 → 무해 |
| `GET /membership` (멤버십 조회) | **정상** — `MembershipPlanPort.getPlan` 조회만, Polar env 무관 |
| 기존 충전(`POST /payments/initiate`) | **정상** — `CREDIT_PRODUCTS` env(`POLAR_PRODUCT_STARTER` 등)는 별개, 영향 0 |
| 테마·분석·채팅 | **정상** — 구독 env 무관 |

→ **핵심 원칙**: env 미설정은 **구독 checkout 1개 경로만 비활성**, 나머지(webhook 수신·멤버십 조회·충전·AI 기능) 전부 정상. 사용자가 나중에 Polar 상품 등록 + env 입력 → checkout 즉시 활성화. 재배포 불요(env reload는 인프라 영역 — 컨테이너 재시작 1회).

### 4-2. graceful 구현 패턴 (C4 sub-task 군)

- 구독 product ID 해석 — `polar.adapter.ts`에 `resolveSubscriptionProductId(tier): string | null` 신설 (`process.env['POLAR_PRODUCT_SUBSCRIPTION_' + tier.toUpperCase()]` → 빈 값이면 null). 기존 `resolvePolarProductId`(충전)와 동일 패턴.
- `POST /subscriptions/checkout` usecase — `resolveSubscriptionProductId` null 시 `ServiceUnavailableException` throw (NestJS 503). 명확한 한국어 메시지.
- `infrastructure/config` 환경변수 검증 — `POLAR_PRODUCT_SUBSCRIPTION_PRO/_PREMIUM`을 **Optional**로 등록 (필수 아님 — 미설정이 정상 상태). `environments.md`에 "구독 결제 활성화 시 입력" 명시.
- spec — env 설정/미설정 두 케이스 모두 검증 (미설정 시 503, 설정 시 checkout 생성).

> graceful 설계가 **사용자 의도의 핵심** — "코드·spec·문서 완전 선작업, Polar 설정만 남도록". §4 패턴이 이를 보장.

---

## 5. Phase A — HIGH-1 案 B: `MembershipPlan.tier` 정본화 + `Author.plan` 읽기 13곳 이행

> CREDIT_CORE_DIAGNOSIS §5-A — 案 B: `MembershipPlan.tier` 정본화, `Author.plan` `[DEPRECATED]` + 읽기 경로를 `MembershipPlanPort.getPlan` 경유로 이행. CC-3가 案 A(ADR-014)를 채택했으므로 Phase A는 ADR-014 재결정 동반.

### 5-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C2a | ADR-014 案 A → 案 B 전환 결정 명문화 — 본 계획 §5-2에 案 B 채택 + 근거 박제. ADR-014 보강안 작성(실제 ADR 수정은 C2g 구현 sub-task에서). 사용자가 案 B 진행 지시 → §10 게이트에 "案 B 전환 확인" 1줄 | [MUST] | 🟢 | 6분 | S0 게이트 | §5-2 案 B 근거 명문화 (Phase A 구현 설계 입력) |
| C2b | `getPlan`에 tier 조회 보강 확인 — 案 B는 `MembershipPlanPort.getPlan`이 tier 정본 출처. `getPlan`이 `MembershipPlanState.tier` 반환함은 확인됨(C1c) → 추가 메서드 불요. 단 **`getPlan`이 null 반환 시(멤버십 row 없는 작가) tier 폴백 = 'free'** 정책을 도메인 헬퍼로 박제 (`resolveTierOrFree(plan): MembershipTier`) | [MUST] | 🟡 | 5분 | C2a,C1e | `npx tsc --noEmit` PASS |
| C2c | `resolveTierOrFree` 단위 spec — `membership-tier.spec.ts` 보강: plan null → 'free' / plan.status='cancelled' → 'free' / plan.tier='pro' → 'pro' | [MUST] | 🟡 | 4분 | C2b | `npm test membership-tier.spec` PASS |
| C2d | theme 도메인 4곳 이행 — `generate-theme.usecase`(`DAILY_FREE_LIMITS[author.plan]`·`isPlanExpired`) / `theme-slot.usecase`(`THEME_SLOT_LIMITS[author.plan]` 3곳·`getSlotInfo`) / `get-theme.usecase`(`isPlanExpired` 2곳)를 `MembershipPlanPort.getPlan` + `resolveTierOrFree` 경유로 교체. `MembershipPlanPort` DI 추가 | [MUST] | 🟡 | 8분 | C2c | tsc PASS + theme usecase에서 `author.plan` 직접 읽기 grep 0건 |
| C2e | `plan.usecase` 이행 — `getPlanInfo`(`author.plan`·`planExpireAt`·`THEME_SLOT_LIMITS[author.plan]`)를 `getPlan` 경유로. `activatePlan`(관리자 수동)은 **`changeTier` 경유로 교체**(직접 `updatePlan` SQL 금지 — `membership-plan.port` 주석 정합). `handleExpiry` 정합 | [MUST] | 🟡 | 7분 | C2d | tsc PASS + `plan.usecase` `updatePlan` 직접 호출 0건 |
| C2f | admin 경로 이행 — `admin.usecase`/`admin.controller`의 `Author.plan` 읽기/쓰기를 `getPlan`/`changeTier` 경유로. 관리자 수동 등급 변경은 `changeTier` (AdminAuditLog 박제 유지) | [MUST] | 🟡 | 6분 | C2e | tsc PASS + admin 경로 `author.plan` 직접 쓰기 0건 |
| C2g | `Author.plan`/`planExpireAt` `[DEPRECATED]` 박제 + ADR-014 갱신 — `schema.prisma` `Author.plan`/`planExpireAt`에 `[DEPRECATED]` 주석(`credits` deprecated 주석 패턴 차용 — 컬럼 물리 DROP은 별도 후속). `changeTier`의 案 A 동기 갱신은 **유지**(deprecated 컬럼이지만 과도기 미러 — DROP 전까지 정합). ADR-014를 "案 A → 案 B 전환, `Author.plan` deprecated, 읽기는 `getPlan` 정본"으로 갱신 | [MUST] | 🟡 | 6분 | C2f | tsc PASS + `schema.prisma` deprecated 주석 확인 |
| C2h | 영향 spec 일괄 갱신 — `generate-theme`/`theme-slot`/`get-theme`/`plan`/`admin` usecase spec의 mock을 `MembershipPlanPort.getPlan` mock으로 보강(기존 `mockAuthor.plan` 기반 → `getPlan` 반환 mock). "플랜 만기" 케이스를 `getPlan` 만료 plan으로 재현 | [MUST] | 🟡 | 8분 | C2g | 해당 spec 5종 PASS |
| C2i | Phase A 통합 검증 — `getPlan`이 tier 정본을 반환하고 theme/plan/admin이 그 tier를 따름을 검증하는 통합 spec 1건(또는 C2h에 흡수). `changeTier` 호출 후 `getPlan`·테마 슬롯 한도가 새 tier 정합 | [MUST] | 🟡 | 6분 | C2h | 해당 spec PASS — Phase A 案 B 완결 증명 |

**Phase A 게이트**: C2a~C2i [MUST] 9건 완료 = 案 B 이행 완료(`Author.plan` 읽기 13곳 → `getPlan` 경유, `Author.plan` deprecated) → Phase B 진입 허가.

### 5-2. 案 B 채택 근거 (planner 결정 — C2a 산출)

**권고 — 案 B (`MembershipPlan.tier` 정본화)**. 사유:

1. **사용자 지시** — 사용자가 "CC-5와 함께 案 B 진행"을 명시. CC-3 plan-draft도 "CC-5의 `changeTier`가 활성화되면 案 B가 자연 정합"을 예고.
2. **CC-5와 정합** — CC-5의 구독 webhook이 `changeTier`를 호출 → `MembershipPlan.tier`가 매월 결제·해지로 갱신되는 활성 상태가 됨. tier가 살아 움직이는데 `Author.plan`을 정본으로 두면(案 A) "정본인데 미러가 더 자주 바뀐다"는 역전 → 案 B가 자연스러움.
3. **읽기 단일 출처** — 案 B 이행 후 `Author.plan` 읽기 13곳이 전부 `MembershipPlanPort.getPlan` 경유 → tier 정본 출처가 `MembershipPlan` 하나. 案 A는 읽기는 `Author.plan`·변경은 `changeTier` 양쪽 → 정본 위상 모호.
4. **`Author.plan` DROP 경로 정합** — `Author.credits`가 이미 CC-4에서 deprecated→DROP 경로를 밟음. `Author.plan`도 같은 패턴(案 B deprecated → 별도 후속 sprint DROP)이 일관.
5. **과도기 미러는 유지** — C2g가 `changeTier`의 案 A 동기 갱신(`Author.plan`도 갱신)을 **DROP 전까지 유지**. deprecated 컬럼이라도 미러를 끊으면 컬럼이 stale → 혼란. DROP 시점에 미러 코드도 제거.

> **案 B는 ADR 변경** — CC-3가 案 A를 ADR-014로 박제 → C2a가 전환 결정, C2g가 ADR-014 본문 갱신. 사용자가 이미 지시했으므로 §10 게이트는 "확인" 수준.

---

## 6. Phase B — Polar 구독 webhook 확장 + 구독 usecase + `changeTier` 연동

> CREDIT_CORE_DIAGNOSIS §7-2 #2·#3 — `polar.adapter` webhook 화이트리스트에 `subscription.created/updated/canceled/revoked` 추가 + 구독 webhook usecase 신설 → `changeTier`(created/updated) / free 다운그레이드(canceled/revoked).

### 6-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C4a | graceful 설계 결정 명문화 — 본 계획 §4를 Phase B 설계 입력으로 박제. `resolveSubscriptionProductId` null 시 503 패턴 확정 | [MUST] | 🟢 | 4분 | Phase A 게이트 | §4 graceful 설계 명문화 |
| C5a | `NormalizedWebhookEvent` 구독 표현 확장 — `payment-gateway.port.ts`에 구독 생명주기 표현 추가. 案: `type`은 `'subscription.created'` 등 그대로 두고, **신 필드** `subscription?: { polarSubscriptionId, tier, lifecycle: 'created'\|'updated'\|'canceled'\|'revoked' }` 추가(기존 `status` 3값은 구독에 미사용 — Optional). 또는 별도 `NormalizedSubscriptionEvent` 타입 분리 — C5a가 2案 중 택1 명문화 | [MUST] | 🟡 | 6분 | C4a,C1b | tsc PASS + 타입 설계 박제 |
| C5b | `polar.adapter.ts` webhook 화이트리스트 확장 — `switch (event.type)`에 `subscription.created`/`subscription.updated`/`subscription.canceled`/`subscription.revoked` 4 case 추가. Polar 구독 payload에서 `polarSubscriptionId`(`data.id`) + tier(`data.productId` → 구독 product ID 역매핑 또는 `data.metadata.tier`) + `userId`(metadata) 추출 → C5a 신 타입으로 정규화 | [MUST] | 🟡 | 8분 | C5b 의존 C5a | tsc PASS |
| C5c | tier 역매핑 헬퍼 — Polar 구독 product ID → 내부 tier(`pro`/`premium`). `resolveSubscriptionProductId`의 역(逆) — `tierForSubscriptionProductId(polarProductId): MembershipTier \| null`. env 미설정 시 metadata.tier 폴백 또는 null | [MUST] | 🟡 | 5분 | C5b | tsc PASS |
| C5d | `polar.adapter.spec.ts` 수정 — **`:328` "subscription.created 등은 null 반환" 테스트를 수정** — 이제 `subscription.*` 4 이벤트가 정규화 결과를 반환. 4 이벤트별 정규화 케이스 추가(`polarSubscriptionId`/tier/lifecycle 추출 검증) + 여전히 미지원 이벤트(`benefit.created` 등)는 null 유지 검증 | [MUST] | 🟡 | 7분 | C5c | `npm test polar.adapter.spec` PASS |
| C6a | 구독 webhook usecase 신설 — `application/subscription/process-subscription-webhook.usecase.ts` 류. `subscription.created`/`updated` → `MembershipPlanPort.changeTier(authorId, tier, now)` + `polarSubscriptionId` 매핑 저장 / `canceled`/`revoked` → `changeTier(authorId, 'free', now)`(free 다운그레이드). 멱등성: `WebhookEvent` 게이트 재사용 | [MUST] | 🟡 | 8분 | C5d | tsc PASS |
| C6b | `changeTier`에 `polarSubscriptionId` 매핑 저장 추가 — `changeTier` 시그니처에 `polarSubscriptionId?: string` 인자 추가, `$transaction` 안에서 `MembershipPlan.polarSubscriptionId` 갱신. `MembershipPlan.polarSubscriptionId @unique` — 동일 구독 ID 중복 시 처리(이미 존재하는 매핑 갱신). 진단 §7-2 #3 "`polarSubscriptionId` 매핑 저장" | [MUST] | 🔴 | 7분 | C6a,C1d | tsc PASS + `$transaction` 단일 블록 확인 |
| C6c | 구독 webhook 멱등성/원자성 — 구독 webhook도 `payment.usecase`의 `webhookEventRepo.findByEventId` 멱등성 게이트 경유. `changeTier` $transaction이 `MembershipPlan` 변경 원자성 보장(C1d 확인 — 단일 $transaction). 구독 webhook 진입점이 `payment.usecase.processWebhook`인지 별도 라우팅인지 C6c가 결정(권고: `verifyAndParseWebhook`가 구독/주문 모두 파싱 → usecase 라우팅 분기) | [MUST] | 🟡 | 6분 | C6b | tsc PASS + 멱등성 게이트 경유 확인 |
| C6d | 정기결제 갱신 ↔ cron 정합 — §8 참조. 매월 Polar `order.paid`(또는 `subscription.updated`) 재발행과 `resetMonthlyPool` cron 관계 정리. 구독 갱신 webhook이 `changeTier`를 부르면 풀이 즉시 리셋됨 vs cron이 `poolResetAt` 기준 리셋 — 이중 리셋 방지 정책을 C6d가 명문화 + 구현 | [MUST] | 🟡 | 7분 | C6c | tsc PASS + §8 정합 정책 spec |
| C6e | `process-subscription-webhook.usecase.spec.ts` 신설 — 4 이벤트별 단위 검증: created/updated → `changeTier` 호출 mock / canceled/revoked → `changeTier(_, 'free', _)` / 멱등성(중복 eventId skip) / `polarSubscriptionId` 매핑 저장 | [MUST] | 🟡 | 8분 | C6d | `npm test process-subscription-webhook.usecase.spec` PASS |
| C6f | `changeTier` spec 보강 — `prisma-membership-plan.repository.spec.ts`에 `polarSubscriptionId` 인자 케이스 추가. 案 B 정합(case A 동기 갱신 유지 검증) | [MUST] | 🟡 | 5분 | C6e | `npm test prisma-membership-plan.repository.spec` PASS |

**Phase B 게이트**: C4a·C5a~d·C6a~f [MUST] 11건 완료 = 구독 webhook 4 이벤트 → `changeTier` 연동 완료 → Phase C 진입 허가.

---

## 7. Phase C — HTTP 엔드포인트 + 통합 spec + web 핸드오프

> CREDIT_CORE_DIAGNOSIS §7-2 #4·#5 — `POST /subscriptions/checkout`(구독 시작) + `GET /membership`(멤버십 조회 — CC-3에서 CC-5 이월 박제). 보안(Guard/Throttle/DTO) + 통합 spec.

### 7-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C7a | `resolveSubscriptionProductId` + 구독 checkout adapter 메서드 — `polar.adapter.ts`에 `initiateSubscriptionCheckout(tier, userId, returnUrl)` 신설. `polar.checkouts.create`에 구독 product ID 전달(recurring product → Polar가 정기결제 모드 자동) + metadata(`authorId`, `tier`). CircuitBreaker 래핑(`initiatePayment` 패턴 재사용). env 미해결 시 null/throw | [MUST] | 🟡 | 7분 | Phase B 게이트 | tsc PASS |
| C7b | 구독 checkout usecase — `application/subscription/start-subscription.usecase.ts` 류. `resolveSubscriptionProductId` null 시 `ServiceUnavailableException`(503, graceful §4). `initiateSubscriptionCheckout` 호출 → 호스티드 URL 반환. tier 검증(`pro`/`premium`만 — `free`는 checkout 불가) | [MUST] | 🟡 | 6분 | C7a | tsc PASS |
| C7c | `SubscriptionController` 신설 — `POST /subscriptions/checkout` (`@UseGuards(JwtAuthGuard)` + `@Throttle({ default: { ttl: 60000, limit: 3 } })` — `payment.controller` `initiate` 패턴) + `GET /membership` (`@UseGuards(JwtAuthGuard)`). DTO: `StartSubscriptionDto`(tier) / `MembershipResponseDto`(tier·monthlyPoolPoints·poolBalance·poolResetAt·status — **내부 ID `authorId`/`polarSubscriptionId` 노출 금지** — SECURITY.md §4) | [MUST] | 🟡 | 8분 | C7b | tsc PASS |
| C7d | `GET /membership` usecase — `MembershipPlanPort.getPlan` 경유 + `checkAndResetExpiredPool`(lazy 안전망 — CC-3) 호출 후 응답. `getPlan` null 시 free 폴백 응답(`resolveTierOrFree`). web 구독 페이지 "현재 플랜" 배지가 의존(SUBSCRIPTION_AUDIT_WEB M-1 해소) | [MUST] | 🟡 | 6분 | C7c | tsc PASS |
| C7e | 컨트롤러 spec — `subscription.controller.spec.ts` 신설: `POST /subscriptions/checkout`(Guard 미인증 401 / Throttle / env 미설정 503 / 정상 시 URL) + `GET /membership`(인증 / tier 응답 / 내부 ID 미노출 검증) | [MUST] | 🟡 | 8분 | C7d | `npm test subscription.controller.spec` PASS |
| C7f | 통합 spec 신설 — `application/subscription/subscription-webhook-integration.spec.ts` 류. CC-2a/CC-3 통합 spec 패턴 차용 — DI 실 wiring. **핵심 케이스**: ① `subscription.created` webhook → `changeTier` → `MembershipPlan.tier='pro'` 갱신 + `polarSubscriptionId` 저장 ② `GET /membership`이 갱신 tier 반환 ③ `subscription.revoked` → `changeTier(_, 'free')` → `getPlan` tier='free' | [MUST] | 🟡 | 8분 | C7e | 해당 spec PASS |
| C7g | 통합 spec 추가 케이스 — ④ 案 B 정합: 구독 webhook 후 theme-slot `getSlotInfo`가 새 tier 슬롯 한도 반환(`MembershipPlanPort.getPlan` 경유) ⑤ graceful: env 미설정 시 `POST /subscriptions/checkout` 503 + `GET /membership`·webhook 정상 ⑥ 멱등성: 동일 구독 webhook 2회 → `changeTier` 1회만 | [MUST] | 🟡 | 7분 | C7f | 해당 spec PASS — CC-5 완결 증명 |
| C7h | 정기결제 ↔ cron 정합 통합 케이스 — §8 — 구독 갱신 webhook + `resetMonthlyPool` cron이 같은 작가에 이중 리셋 안 함(C6d 정책 검증). 결제 갱신일 ↔ 풀 리셋일 정합 spec | [MUST] | 🟡 | 6분 | C7g | 해당 spec PASS |

**Phase C 게이트**: C7a~C7h [MUST] 8건 완료 = HTTP 엔드포인트 2개 + 통합 spec 완료 → 마무리(§9) 진입.

---

## 8. 정기결제 갱신 ↔ `resetMonthlyPool` cron 정합 (CC-5 핵심 정합 항목)

> CREDIT_CORE_DIAGNOSIS §7-2 #7 — "정기결제 갱신(매월 Polar `order.paid` 재발행)과 `resetMonthlyPool` cron의 관계 정리 — 결제 갱신일 ↔ 풀 리셋일 정합."

### 8-1. 문제 정의

- `resetMonthlyPool` cron(`@Cron('0 0 4 * * *')` 매일 4시, `poolResetAt <= now`인 plan 리셋) — `poolResetAt`은 `nextMonthStart`(다음 달 1일 0시) 기준. **달력 기준 매월 1일 리셋**.
- Polar 정기결제 갱신 — 작가가 구독한 **날짜 기준 매월 갱신**(예: 15일 가입 → 매월 15일 결제). 갱신 시 Polar가 `order.paid`(또는 `subscription.updated`) webhook 재발행.
- **불일치**: 풀 리셋(달력 1일)과 결제 갱신(가입일)이 다른 날 → 작가가 15일에 결제했는데 풀은 1일에 리셋 → "결제했는데 2주 뒤에야 풀 갱신" 또는 "결제 전 풀 리셋" 혼란.

### 8-2. 정합 정책 (C6d 명문화 — planner 권고)

| 案 | 정책 | 평가 |
|---|---|---|
| **案 A — 달력 기준 유지(권고)** | 풀 리셋은 `resetMonthlyPool` cron의 달력 1일 기준 그대로. 구독 갱신 webhook(`order.paid` 재발행)은 **풀을 건드리지 않음** — `changeTier`를 안 부르고, 결제 영수증 박제만(또는 무시). 풀 갱신은 cron 단독 책임 | **권고** — 풀 리셋 책임을 cron 하나로 단일화. 구독 갱신 webhook은 "구독 유효 연장" 의미만(`MembershipPlan.expiresAt` 갱신). `ai-cost-table.md §4` "매월 리셋(이월 금지)"이 달력 기준 — 정본 정합 |
| 案 B — 가입일 기준 전환 | `poolResetAt`을 구독 갱신일 기준으로. 갱신 webhook이 풀 리셋 | cron의 `nextMonthStart` 로직 전면 재작성 + 작가별 리셋일 분산 → 복잡. CC-3가 이미 달력 기준으로 ADR 박제 |

**권고 — 案 A**. 사유:
1. **풀 리셋 책임 단일화** — `resetMonthlyPool` cron + `checkAndResetExpiredPool` lazy 안전망(CC-3)이 이미 달력 기준으로 완성. 구독 갱신 webhook이 풀을 건드리면 이중 리셋 경로 → CC-3가 막은 이월/중복 리셋 리스크 재현.
2. **`changeTier`는 등급 변경 전용** — 구독 **갱신**(같은 등급 유지)은 `changeTier`를 부를 이유 없음. `changeTier`는 가입(`created`)·등급 변경(`updated` 중 tier 변경)·해지(`canceled`/`revoked`)만. 단순 정기결제 갱신(`order.paid` 재발행, tier 불변)은 `MembershipPlan.expiresAt` 연장만.
3. **C6d 구현** — 구독 webhook usecase가 이벤트를 분류: `subscription.updated` 중 **tier 변경 있음** → `changeTier` / **tier 불변(단순 갱신)** → `expiresAt`만 연장. `order.paid`가 구독 결제면 → `expiresAt` 연장만(풀 미차감·미리셋). C7h가 통합 검증.

> **결제 갱신 ↔ 풀 리셋 정합 = 案 A "분리"** — 풀은 cron(달력), 구독 유효기간은 webhook(가입일). 두 개념을 의도적으로 분리. 작가 체감: "풀은 매월 1일 리셋, 구독료는 매월 가입일 청구" — 명확. web 핸드오프에 이 모델 명시(구독 페이지 안내 문구).

---

## 9. CC-5 마무리 — 빌드·문서·sensor + 원가 게이트

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C8a | 전체 빌드 — `npm run build` 무에러 | [MUST] | 🟢 | 3분 | C7h | 종료코드 0 |
| C8b | 전체 테스트 — `npm test` 통과, server 커버리지 **≥60%** 유지 | [MUST] | 🟢 | 5분 | C8a | jest 전체 PASS, 커버리지 게이트 통과 |
| C8c | `shared-contracts.md` §30 갱신 — `MembershipPlanPort.changeTier` 시그니처에 `polarSubscriptionId?` 추가 + 구독 webhook usecase + `NormalizedWebhookEvent` 구독 확장 + `POST /subscriptions/checkout`·`GET /membership` + `POLAR_PRODUCT_SUBSCRIPTION_PRO/_PREMIUM` env + 멤버십 priceUsd + 案 B(`Author.plan` deprecated) + 변경 이력 1줄. ⚠️ §30 인터페이스 정본 — 미갱신 시 web 통합 깨짐 | [MUST] | 🟡 | 6분 | C8b | `.claude/scripts/sensor-shared-contracts.sh` silent |
| C8d | 문서 일괄 갱신 — `grimoire-server/TECH_STATUS.md`(CC-5 완료) + `docs/api-contract.md`(`POST /subscriptions/checkout`·`GET /membership` 신설) + `docs/environments.md`(`POLAR_PRODUCT_SUBSCRIPTION_*` Optional env) + `docs/data-model.md`/`SCHEMA.md`(`Author.plan` deprecated 주석) + `ADR.md`(ADR-014 案 B 전환 + 정기결제↔cron 정합 案 A) + `SECURITY.md §4`(신 엔드포인트 보안 체크) + 루트 `SYNC_STATUS.md`. `docs-sync` drift sensor 확인 | [MUST] | 🟡 | 6분 | C8c | drift sensor silent |
| C8e | sensor 일괄 — `sensor-shared-contracts` / `-instruction-degradation` / `-agent-priority-labels` / `-agent-interaction` + `sensor-subscription-pool-no-rollover.sh`·`sensor-credit-source-accounting.sh`(존재 시) 실행 | [SHOULD] | 🟢 | 3분 | C8d | sensor 전부 silent/PASS |

> **원가 게이트 판정 (C8 단계 박제)**: 멤버십 KRW 가격(Pro ₩9,900·Premium ₩19,900)은 `ai-cost-table.md §4`·§7-5가 §0 PASS 검증 완료(풀 누적 스트레스 원가 ≤ 구독료÷3 — Pro ₩3,021≤₩3,300 / Premium ₩6,221≤₩6,633). **CC-5의 cost-accountant 게이트는 priceUsd 1건** — §3-2가 추정한 멤버십 priceUsd($9.99/$19.99)를 cost-accountant가 "KRW 환산 실수령 기준 §0 PASS 재확인"해야 함(§10 게이트). USD 환산액이 KRW 정가 이상이면 마진 ↑ → 차단 가능성 낮으나 **신 가격 항목이므로 cost-accountant 승인 필수**. CC-5는 신규 AI 기능 추가 0건(구독은 기존 월 풀 결제 연동) — priceUsd 외 추가 마진 검증 불요.

---

## 10. 사용자 결정 게이트 + cost-accountant / VCK 게이트

### 10-1. 사용자 결정 게이트 (CC-5 착수 전 확인)

| # | 결정 대상 | 현 상태 | 게이트 판정 |
|---|---|---|---|
| G1 | **멤버십 priceUsd** ($9.99/$19.99 추정값 채택 여부) | priceUsd 정본 미존재(§3-1). 충전 패키지 패턴으로 $9.99/$19.99 추정 | 사용자가 추정값 채택 → C3 + cost-accountant §0 재확인 진행 / 변경 → 변경값으로 cost-accountant 재검증 |
| G2 | **Polar 구독 상품 등록 주체** (메인 API vs 사용자 대시보드) | API 등록 가능 확인됨(probe 201). §3-3 권고 = 메인 API 등록 | 사용자가 메인 API 등록 승인 → G1·cost-accountant 통과 후 메인이 dev/prod 등록 |
| G3 | **Polar KYC / test mode 상태** | 진단 §10 미확인 — 구독 상품 등록 가능 환경인지 | 사용자 확인 — KYC 미완료 시 test mode 등록 후 prod 전환 시점 별도 |
| G4 | **HIGH-1 案 B 전환 확인** | CC-3가 案 A를 ADR-014로 박제. 사용자가 案 B 진행 지시함 | 사용자 지시 기수령 — C2a가 ADR-014 변경이므로 명시 확인 1줄 (차단 아님, 통지) |

> G1~G3은 **CC-5 착수 전 필수 확인**. G1(priceUsd)이 cost-accountant 게이트의 입력 — G1 미확정 시 §3·§6·§9 진행 불가. G4는 통지(이미 지시받음).

### 10-2. cost-accountant 게이트 — **필요 (priceUsd 1건)**

- **필요 사유**: 멤버십 priceUsd($9.99/$19.99)가 정본에 없는 신 가격 항목. `ai-cost-table.md §7-5`의 §0 PASS는 KRW 가격 기준 → USD 등록 시 환율 변동분 반영한 "KRW 환산 실수령 기준 §0 재확인"이 cost-accountant 영역.
- **게이트 내용**: cost-accountant가 $9.99/$19.99 → KRW 환산(환율 ₩1,497.08 등 최신) 실수령액에서 Polar 수수료 차감 후 "월 풀 누적 스트레스 원가 ≤ 실수령÷3" 재확인 → PASS 시 `ai-cost-table.md §4`에 멤버십 priceUsd 행 추가(cost-accountant 승인 `commit`).
- **차단 가능성**: 낮음 — $9.99=₩14,956 / $19.99=₩29,926(환율 ₩1,497)로 KRW 정가(₩9,900/₩19,900)보다 높음 → 실수령 ↑ → 마진 ↑. 단 환율 급락 시나리오는 cost-accountant가 스트레스 확인.
- **신규 AI 기능 마진 검증**: CC-5는 신규 AI 기능 추가 0건(구독 = 기존 월 풀의 결제 연동) → priceUsd 외 §0 마진 검증 불요.

### 10-3. visual-canon-keeper(VCK) 게이트 — **불요 (server sprint)**

- CC-5는 server 도메인 한정 — UI 컴포넌트 변경 0건. VCK 사전 검수 불요.
- 단 web이 `GET /membership`·`POST /subscriptions/checkout`을 연결하는 **별도 web sprint**(§11 핸드오프)에서 구독 페이지 UI가 사슴악마 정본 정합인지 VCK 검수 필요 — CC-5 server sprint 범위 외, web sprint 게이트로 이월.

---

## 11. 핸드오프

### 11-1. 담당 + 산출물 위치

| 영역 | 담당 | 산출물 위치 | 다음 단계 진입 조건 |
|---|---|---|---|
| §10 사용자 게이트 G1~G4 | **사용자** (planner 경유 확인) | priceUsd·등록 주체·KYC·案 B 결정 | G1~G3 확정 = §3·§6 진행 / G4 통지 |
| priceUsd §0 재확인 | **grimoire-cost-accountant** | `ai-cost-table.md §4` 멤버십 priceUsd 행 + 승인 | PASS = C3 + Polar 등록 진행 |
| Polar 구독 상품 등록 | **메인** (G1·cost-accountant 통과 후) | dev/prod Polar org recurring product 2종 + env 입력 | 등록 완료 = checkout 활성 (코드와 병렬) |
| CC-5 S0 | grimoire-server | 진단 §7·§5-A 미확인 7건 해소 (progress.md) | C1a~C1g 완료 = Phase A 진입 |
| CC-5 Phase A~C 구현 | grimoire-server (Generator) | adapter/usecase/controller/도메인 코드 + spec + progress.md 갱신 | C8 마무리 |
| CC-5 채점 | grimoire-qa (Evaluator) | `QA_REPORT.md` — sprint-progress 통과율 박제 | — |
| web 구독 페이지 실연결 | **grimoire-web** (별도 sprint) | 구독 페이지 — `GET /membership`·`POST /subscriptions/checkout` 연결 | CC-5 server 머지 + shared-contracts §30 갱신 후 |

### 11-2. Initializer 산출물 (planner)

- 본 계획 = `.claude/state/sprint-cc5-subscription-plan-draft.md`.
- **`reports/sprint-cc5-subscription-progress.md` 생성 권고** — 본 계획 sub-task 38건 체크리스트 + Phase A/B/C 게이트 + 완료 기준을 progress.md로 박제 → server(Generator)가 Read 후 갱신, qa(Evaluator)가 채점 (책 Ch 16 Initializer→Generator→Evaluator 패턴).
- server / qa에게 본 계획 + progress.md Read 후 작업 핸드오프.

### 11-3. web 핸드오프 범위 (별도 web sprint — CC-5 server 머지 후)

> `SUBSCRIPTION_AUDIT_WEB`: 현 web 구독 UI는 **표시 전용**(`MembershipPlans` `onSelect` 미전달 → 버튼 미렌더, M-1 "현재 플랜" 배지 dead path). CC-5가 server 엔드포인트를 만들면 web이 실연결.

| web 작업 | CC-5가 제공하는 것 | SUBSCRIPTION_AUDIT_WEB 근거 |
|---|---|---|
| 구독 시작 버튼 실연결 | `POST /subscriptions/checkout` → 호스티드 URL → redirect | Q2 — `onSelect` 전달 + 버튼 렌더 활성화 |
| "현재 플랜" 배지 활성화 | `GET /membership` → tier 응답 → `currentTier` 전달 | M-1 — 영구 dead path 해소 |
| graceful UX | env 미설정 시 `POST /subscriptions/checkout` 503 → web이 "구독 준비 중" 안내 유지 | Q2 — 현 안내 문구를 503 분기로 |
| 정기결제↔풀 리셋 모델 안내 | §8 案 A — "풀 매월 1일 리셋 / 구독료 매월 가입일 청구" 문구 | — (신규) |
| §30 수치 drift 해소 | web이 `GET /membership`에서 플랜 데이터 수신 → 하드코딩 `MEMBERSHIP_PLANS` 제거 | M-3 — server↔web drift 근본 해소 |
| VCK 검수 | 구독 페이지 UI 사슴악마 정본 정합 | §10-3 — web sprint 게이트 |

### 11-4. 원가 영향 + 시각 검수 플래그

- **원가 영향**: cost-accountant 게이트 **필요** — 멤버십 priceUsd($9.99/$19.99) §0 재확인 1건(§10-2). 신규 AI 기능 0건.
- **시각 검수**: CC-5 server sprint는 VCK **불요**. web 구독 페이지 sprint에서 VCK 필요(§10-3).
- **의존 Phase**: CC-1·CC-2(a+b)·CC-3 완료 선행 + PAY-S1 로컬 DB 동기화 DB 전제. CC-4(V Phase 마이그레이션 적용)와 **병렬 가능**(진단 §8 — CC-5는 CC-3 이후, CC-4와 병렬).

---

## 12. 종합 게이트 — CC-5 완료 선언 조건

### CC-5 완료 선언

- **§10 사용자 게이트**: G1(priceUsd)·G2(등록 주체)·G3(KYC) 확정 + G4(案 B) 통지.
- **cost-accountant 게이트**: 멤버십 priceUsd §0 재확인 PASS + `ai-cost-table.md §4` 갱신.
- **S0 게이트**: C1a~C1g [MUST] 7건 완료 (진단 §7·§5-A 미확인 해소).
- **Phase A 게이트**: C2a~C2i — 案 B 이행 완료(`Author.plan` 읽기 13곳 → `getPlan`, `Author.plan` deprecated).
- **Phase B 게이트**: C4a·C5a~d·C6a~f — 구독 webhook 4 이벤트 → `changeTier` 연동 완료.
- **Phase C 게이트**: C7a~C7h — `POST /subscriptions/checkout` + `GET /membership` + 통합 spec 완료.
- **검증 게이트** (writing-plans Gate 1·2·3):
  - Gate 1 (빌드): C8a `npm run build` 무에러.
  - Gate 2 (테스트): C8b `npm test` 전체 PASS + 커버리지 ≥60%. **통합 spec(C7f·C7g·C7h)이 핵심** — 구독 webhook → `changeTier` → `MembershipPlan.tier` 갱신 → `getPlan` 반영 → 테마 슬롯 정합을 통합 테스트로 증명.
  - Gate 3 (문서/sensor): C8c~e — shared-contracts §30 + TECH_STATUS + api-contract + environments + data-model + ADR 갱신 + sensor silent.
- **[SHOULD]** C8e(sensor 일괄) 실패는 회고만.
- **PAY-P1-4 해소 증명**: `grep -rn "subscription.created\|subscription.revoked" src/adapter/outbound/payment` ≥1건(화이트리스트 확장) + `grep -rn "changeTier" src/application/subscription` 호출처 ≥1건 + 통합 spec C7f PASS = "Polar 구독 정기결제 → MembershipPlan 연동 완료" 선언.
- **HIGH-1 案 B 해소 증명**: `grep -rn "author.plan\b" src/application/theme src/application/plan`(직접 읽기) 0건 + `Author.plan` `[DEPRECATED]` 주석 + 통합 spec C7g 케이스 ④ PASS = "`MembershipPlan.tier` 정본화 완료" 선언.
- **graceful 증명**: 통합 spec C7g 케이스 ⑤ PASS = "env 미설정 시 구독 checkout만 503, 나머지 정상" 선언.

### CC-5 미해소 잔존 (범위 외 — 명시)

- `Author.plan`/`planExpireAt` 컬럼 **물리 DROP** = 案 B deprecated 후 별도 후속 sprint(CC-4 패턴 — deprecated→DROP 분리). CC-5는 deprecated 박제 + 읽기 이행까지.
- web 구독 페이지 실연결 = **별도 web sprint**(§11-3) — CC-5 server 머지 후.
- Polar 구독 상품 dev/prod 등록 + env 입력 = 메인 작업(코드와 병렬) — CC-5 코드 머지는 등록과 독립(graceful §4).
- 구독 환불/부분환불 정밀 처리 = `subscription.canceled`/`revoked` → free 다운그레이드까지가 CC-5 범위. 구독 결제 자체의 환불(이미 낸 구독료 반환)은 기존 `order.refunded` 경로 — CC-5 추가 작업 없음(단 S0 C1a가 현행 확인).

---

## 13. rollback 단위

- 각 sub-task는 git commit 단위 — Phase A / Phase B / Phase C 별 commit 그룹. 실패 시 해당 commit revert.
- C2g(`Author.plan` deprecated 주석)는 스키마 **주석만** — 컬럼 물리 변경 0건 → 마이그레이션 불요, revert 안전.
- C6b(`changeTier` `polarSubscriptionId` 추가)·C7a(`initiateSubscriptionCheckout`)는 🔴/🟡 — DB 쓰기·외부 API 호출 로직. 단 코드 변경이며 **DB 스키마 비변경**(`MembershipPlan.polarSubscriptionId` 필드 이미 존재 — C1f 확인). PAY-S1과 달리 백업 불요. tsc/jest 실패 = 해당 commit 단위 롤백.
- C5d(`polar.adapter.spec` 수정 — `:328` "subscription.* 무시" 테스트 변경)는 회귀 안전 — 기존 테스트를 신 동작으로 갱신, revert 시 구 동작 spec 복원.
- graceful 설계(§4)가 자체 롤백 안전망 — Polar 구독 상품 미등록/env 미설정 시 구독 checkout만 비활성, 나머지 정상 → CC-5 머지 후 Polar 등록 전이라도 운영 무사고.
- ⚠️ C7 통합 spec 전건 PASS가 운영 게이트. dev/prod 배포는 CC-4(마이그레이션 sprint) 또는 별도 — CC-5 자체는 코드 머지까지.

---

## 14. 미확인 / 추정 금지 명시

| 항목 | 상태 | 해소 시점 |
|---|---|---|
| `polar.adapter` webhook 화이트리스트 현행 | **확인** — 본 계획 작성 중 Read(`order.paid`/`order.updated`/`order.refunded`/`checkout.updated` + `default: return null`). S0 C1a 재실측 | C1a |
| `NormalizedWebhookEvent` 시그니처 | **확인** — `status: 'success'\|'fail'\|'cancel'` 3값(구독 생명주기 부적합). S0 C1b 재확인 | C1b |
| `MembershipPlanPort` 5 메서드 시그니처 | **확인** — `getPlan`/`changeTier`/`resetMonthlyPool`/`findPlansToReset`/`checkAndResetExpiredPool`. S0 C1c 재확인 | C1c |
| `changeTier` 案 A 동기 갱신 | **확인** — CC-3가 案 A(ADR-014)로 `Author.plan`+`planExpireAt` 동기 갱신 중. `polarSubscriptionId` 미수신. S0 C1d 재확인 | C1d |
| `Author.plan` 읽기 13곳 | **부분 확인** — 본 계획 작성 중 6 파일 확인(theme-slot/generate-theme/get-theme/plan.usecase/admin + author.repository). server가 전수 grep 재실측 | C1e |
| `MembershipPlan.polarSubscriptionId` | **확인(간접)** — `MembershipPlanState`에 `polarSubscriptionId: string \| null` 필드 존재(`membership-plan.port.ts:29`). `schema.prisma` `@unique` 직접 Read는 S0 | C1f |
| 멤버십 KRW 가격 §0 | **확인** — `ai-cost-table.md §4`·§7-5 Pro/Premium 전건 §0 PASS. priceUsd는 정본 미존재 | C1g |
| 멤버십 priceUsd | **추정** — 정본 미존재. 충전 패키지 패턴($X.99)으로 $9.99/$19.99 추정 — 사용자(G1)+cost-accountant 게이트 | §10 G1 |
| Polar KYC / test mode 상태 | **미확인** — 구독 상품 등록 가능 환경 종속 | §10 G3 |
| Polar 구독 webhook payload 구조 (`subscription.*` 필드명) | **미확인** — Polar SDK 타입 + 실 webhook payload — C5b 구현 시 Polar 문서/SDK 타입 확인 | C5b |
| 구독 갱신 webhook 이벤트 종류 (`order.paid` vs `subscription.updated`) | **미확인** — Polar가 정기결제 갱신을 어떤 이벤트로 발행하는지 — C6d 구현 시 확인 | C6d |
| sub-task 시간 추산 | 상대 추산 — 실측 아님. 본 계획은 분해 단위, 실제 시간은 server 실행 시 확정 | — |

> 본 계획은 코드 변경 0건 — 순수 계획 수립. 모든 file:line은 CREDIT_CORE_DIAGNOSIS 진단 리포트 + 본 계획 작성 중 실제 Read(`polar.adapter.ts`/`payment-gateway.port.ts`/`membership-plan.port.ts`/`prisma-membership-plan.repository.ts`/`plan.usecase.ts`/`payment.usecase.ts`/theme usecase 3종/`shared-contracts.md §30`/`ai-cost-table.md`/`SUBSCRIPTION_AUDIT_*.md`) 기반. 미확인은 §14에 명시 — 추정 0건.

---

## 15. 변경 이력

- 2026-05-22: 본 계획 신설. CC-5(PAY-P1-4 Polar 구독 연동, L) + HIGH-1 案 B(`MembershipPlan.tier` 정본화, M) 묶음 sprint를 writing-plans 양식으로 분해 — S0 7 + Phase A 案 B 9 + Phase B webhook 11 + Phase C HTTP·통합 8 + 마무리 3 = 38 sub-task. sprint 분할 권고 = 단일 sprint·3 Phase(案 ②). priceUsd 정본 미존재 → 충전 패키지 패턴 $9.99/$19.99 추정 + 사용자 G1·cost-accountant 게이트. graceful 설계(§4) — env 미설정 시 구독 checkout만 503, 나머지 정상. 정기결제↔cron 정합 = 案 A 분리(풀 cron 달력 / 구독 webhook 가입일). 사용자 결정 게이트 4건(G1~G4). cost-accountant 게이트 필요(priceUsd 1건). VCK 불요(server sprint). 코드 변경 0건 — 계획 수립 전용.
</invoke>
