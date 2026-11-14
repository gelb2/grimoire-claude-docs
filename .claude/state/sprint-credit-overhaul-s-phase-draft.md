# Sprint 계약 Draft — 크레딧·구독·채팅 과금 개편 S Phase (스키마 설계)

> **작성**: 2026-05-17 (grimoire-planner Initializer 산출)
> **정본 종속**: `research/CREDIT_PRICING_OVERHAUL_PLAN.md` **§8** (골격·수치 정본 — v6, 2026-05-16) + `PLANNING_GRIMOIRE.md` §0(크레딧-원가 철칙)
> **선행 완료**: R Phase(연구) + S Phase 수치 산출(§8-7 #2 researcher 재스윕 + #3 cost-accountant v3 산출) — 5/16 별도 세션 종료
> **본 Draft 범위**: §8-7 S Phase 선행 8건 中 **스키마 영역** + §8-8 CRITICAL 5건의 **스키마 설계 구체화**. 코드/스키마 미변경 — Draft만 산출.
> **구조 정본**: PAY-P2-5 Draft(`sprint-pay-p2-5-audit-retention-draft.md`, 17 섹션) + PAY-P3-H Draft(`sprint-pay-p3-h-circuit-breaker-draft.md`, 17 섹션) 골격 차용.

<!-- GMP v2.2 이중 앵커 — 상단 -->
## CRITICAL_CONSTRAINTS

- **[MUST]** `research/CREDIT_PRICING_OVERHAUL_PLAN.md` §8이 골격·수치 정본. §8과 본 Draft가 불일치하면 §8이 정본.
- **[MUST]** §8-8 CRITICAL 5건을 위반하는 스키마는 채택 불가: ① 비스트레스 원가 차감 ② 풀 이월 ③ 토큰 필드 누락 ④ 채팅 3구간 ⑤ 재산정 트리거 sensor 미연동.
- **[MUST]** 본 Draft는 **설계 산출물** — 실제 schema.prisma / migration / ai-cost-table.md 변경 0건. 사용자 결정 게이트 6건 통과 후 I Phase에서 server Generator가 구현.
- **[MUST]** `ai-cost-table.md` 개정은 cost-accountant 단독 승인 영역 — 본 Draft는 "개정 필요" 명시만.
- **[MUST]** 외부 Anthropic API 의존 0건. Draft는 정본 문서 + schema.prisma 직접 Read 기반 — 추정 보고 금지(§0 ZERO-TOLERANCE).

---

## §0. 한 줄 요약

§8 골격 정본(디노미네이션 1:1,000 + 단일 통화 + 구독 월 포인트 풀 + 채팅 4구간 정액) → S Phase 스키마 설계로 (1) **포인트 출처 4종 분리 회계** 구조 결정(필드 분리 vs `CreditLedger` 테이블) + (2) **디노미네이션 마이그레이션** 설계(`Author.credits Int` ×1,000 환산, 출처 전량 "충전" 분류) + (3) **`ChatMessage` 토큰 필드** 추가(`inputTokens`/`outputTokens`/`model`) + (4) **구독 월 포인트 풀** 구조(`Subscription` 신설 vs `Author` 필드, 매월 리셋 + 이월 금지) + (5) **채팅 4구간 차감 + 사후 차감 + `deficit` 외상**(기존 `RefundLog.deficitCredits` 패턴 차용) + (6) **차감 N 재산정 트리거 sensor**. 산출물: shared-contracts §30 CreditOverhaul + ADR-012 + sensor 신설안 + jest spec 매트릭스. **사용자 결정 게이트 6건** 통과가 I Phase 진입 전제.

## §0-1. 사용자 결정 박제 (정본 §8 + 5/16~5/17 인용)

- **§8 골격 확정 (v3~v6, 5/16)**: 디노미네이션 1:1,000 / 단일 통화 / 구독 = 월 포인트 풀 + 초과 종량 / 구독 "테마 슬롯 → 월 포인트 풀" 병존 확장 / 구독 가격 Pro ₩9,900·Premium ₩19,900 / 채팅 Sonnet 4.6 단일(Haiku 티어링 미채택) / 채팅 4구간 정액 / 1pt 표면 ₩0.12.
- **5/17 작업 순서 결정**: "작업 순서 재산출 Tier 2 진입. 크레딧 개편은 결제·구독·채팅 백본" — AI 채팅 차감·PAY-P1-4 구독·시맨틱 캐시·결제알림 4건이 본 개편에 종속.
- **본 S Phase Draft 범위 (5/17 지시)**: §8-7 선행 8건 中 스키마 영역 + §8-8 CRITICAL 5건의 스키마 설계 구체화. 실제 코드/스키마 변경 0건, ai-cost-table.md 수정 0건.
- **미확정 (사용자 결정 대기 — §16)**: 본 Draft §4 결정 게이트 6건 + §8-5 패키지 충전액 4종/보너스율(cost-accountant "가정" 표기) + §8-6 응원 선물 단위 적정성.

## §1. 배경 / 문제 영역

### §1-1. 현행 스키마 한계 (schema.prisma 직접 Read 박제)

| # | 모델 | line | 현행 | S Phase 결함 |
|---|---|---:|---|---|
| 1 | `Author.credits` | L23 | `credits Int @default(0)` 단일 정수 | 디노미네이션 1,000pt 표현 불가 + 출처 4종 분리 회계 불가 |
| 2 | `ChatMessage` | L309-319 | `content` 만 (토큰 필드 0건) | 채팅 4구간 판정·차감액 산출 불가 → 모든 차감액 추측 (§8-8 CRITICAL #3) |
| 3 | `CreditLog` | L137-146 | `amount Int + reason String` | 출처별 적립/소진 이력 추적 불가 (reason 문자열 파싱 의존) |
| 4 | `Subscription` | L211-221 | 작가↔독자 팔로우 관계 (구독제 아님) | **월 포인트 풀 구독제와 무관** — 동명이지만 다른 도메인 |
| 5 | `Author.plan` | L24 | `plan String @default("free")` | 월 포인트 풀 크기·리셋 시점·잔여 풀 저장 필드 0건 |
| 6 | `AnalysisReport.creditsCharged` | L452 | `@default(3)` (현 4크레딧 운영, default stale) | 디노미 후 2,440pt 환산 — Int 단위 부적합 |

> **중대 발견 (정본 §1-4 정합)**: 현행 `Subscription` 모델(L211-221)은 **독자가 작가를 팔로우하는 관계** — 본 개편의 "구독 플랜(Free/Pro/Premium 월 포인트 풀)"과 **완전히 다른 도메인**이다. 같은 이름이라 I Phase에서 혼동 위험 → §4 결정 게이트 4에서 신설 모델 명명을 별도 결정한다 (`MembershipPlan` / `CreditSubscription` 등).

### §1-2. §8-7 S Phase 선행 8건 中 스키마 영역 추출

| §8-7 # | 선행 과제 | 본 Draft 스키마 영역 | 다루는 §4 게이트 |
|---|---|---|---|
| #1 | `ChatMessage` 토큰 필드 추가 | ✅ 스키마 직접 | 게이트 3 |
| #2 | researcher `AI_COST_MONITOR.md` 재스윕 | 완료 (5/16) — 본 Draft 입력 | — |
| #3 | cost-accountant 최종 산출 | 완료 (5/16, COST_SIM §v3) — 본 Draft 입력 | — |
| #4 | 포인트 출처 분리 회계 스키마 | ✅ 스키마 직접 (필드 vs ledger) | 게이트 1 |
| #5 | 채팅 토큰 실측 누적 → P50~P99 대체 | 부분 — 토큰 필드(#1)가 선행. 실측은 I Phase 후 운영 1~2주 | 게이트 3 (필드만) |
| #6 | 채팅 구간 경계값 + 사후 차감/`deficit` 로직 | ✅ 스키마 + 차감 로직 영역 | 게이트 5 |
| #7 | `ai-cost-table.md` 개정 | 본 Draft "개정 필요" 명시만 (cost-accountant 승인) | §14 위임 |
| #8 | 차감 N 재산정 트리거 sensor | ✅ sensor 신설안 | 게이트 6 |

> #2·#3은 5/16 완료 → 본 Draft는 그 산출 수치(§8-1~§8-5)를 입력으로 받는다. #5의 실측 자체는 I Phase 배포 후 운영 누적 — 본 Draft는 실측을 담을 필드(#1)만 설계.

### §1-3. §8 확정 수치 (본 Draft 입력 — 정본 §8-1~§8-5 인용, 재산출 금지)

| 항목 | §8 확정값 | 정본 위치 |
|---|---|---|
| 디노미네이션 | 1크레딧 = 1,000pt, 단일 통화 | §8-1 |
| pt 표면 단가 | 1pt = ₩0.12 | §8-1 |
| §0 검증 기준 | 최악 실효 순단가 ₩0.09856/pt (스트레스 원가 ₩1,624.33 기준 `ceil(스트레스원가×3 ÷ ₩0.09856)`) | §8-1 |
| 채팅 차감 (4구간) | 짧음 ≤500tok=**190pt** / 보통 501~4,000=**810pt** / 긺 4,001~12,000=**3,390pt** / 초장문 >12,000=**5,520pt** | §8-4 |
| 분석 차감 | 정액 **2,440pt** (현 4크레딧 환산, 스트레스 3.01×) | §8-4 |
| 테마 차감 | 정액 **590pt** (현 1크레딧 환산, 스트레스 3.01×) | §8-4 |
| 구독 월 풀 | Pro **93,000pt** / Premium **191,500pt** (채팅·테마·분석 공용) | §8-3 |
| 구독 가격 | Pro ₩9,900 / Premium ₩19,900 | §8-3 |
| 풀 이월 | **금지** (매월 리셋) | §8-3, §8-8 #2 |
| 소진 우선순위 | 무료적립 → 구독풀 → 응원선물 → 충전 | §8-2 |
| 패키지 | 입문 ₩3,000(25,000pt) / 기본 ₩5,000(41,667pt) / 인기 ₩10,000(91,667pt, +10%) / 베스트 ₩30,000(287,500pt, +15%) | §8-5 |
| 응원 선물 | 현 1·3·5크레딧 → 1,000·3,000·5,000pt 환산 (적정성 S Phase 재검토) | §8-6 |

## §2. 목표 + 비목표

### §2-1. 목표 (S Phase = 스키마 설계)

1. 포인트 출처 4종 분리 회계 스키마 **구조 결정** (필드 분리 vs `CreditLedger` ledger 테이블) — §4 게이트 1.
2. 디노미네이션 마이그레이션 **단계 설계** (`Author.credits` ×1,000 환산, 출처 분류, dev→prod) — §7.
3. `ChatMessage` 토큰 필드 3종 추가 **설계** (nullable 정책, 기존 row 처리) — §4 게이트 3.
4. 구독 월 포인트 풀 스키마 **구조 결정** (`Author` 필드 vs 신설 모델, 리셋·이월 금지 구현 방식) — §4 게이트 4.
5. 채팅 4구간 차감 + 사후 차감 + `deficit` 외상 **로직 영역 설계** — §4 게이트 5, §8.
6. 차감 N 재산정 트리거 **sensor 신설안** — §4 게이트 6, §10.
7. shared-contracts §30 CreditOverhaul + ADR-012 + jest spec 매트릭스 + eval regression **설계** — §11, §12, §9, §13.
8. `ai-cost-table.md` 개정 **필요 항목 명시** (cost-accountant 승인 영역 — 본 Draft는 수정 0건) — §14.

### §2-2. 비목표 (S Phase 범위 외)

- **실제 코드/스키마/migration 작성** — I Phase server Generator 영역.
- **`ai-cost-table.md` 직접 수정** — cost-accountant 단독 승인. 본 Draft는 개정 항목 명시만.
- **§8 수치 재산출** — §8-1~§8-5는 cost-accountant v3 확정. 본 Draft는 입력으로만 사용.
- **채팅 토큰 P50~P99 재측정** — I Phase 배포 후 운영 1~2주 실측 (§8-7 #5). 본 Draft는 실측을 담을 필드만 설계.
- **구독 결제 연동(Polar)** — I Phase. 본 Draft는 풀 저장 스키마만.
- **web UI 설계** — I Phase web Generator. 본 Draft는 §14에서 web 위임 항목만 명시.
- **패키지 충전액 4종/보너스율 최종 확정** — §8-5 cost-accountant "가정" 표기 → 사용자 확정 영역(§16).

## §3. 외부 의존 매트릭스

| 의존 | 본 Draft 영역 | I Phase 영역 |
|---|---|---|
| Anthropic Claude API | **0건** (Draft = 정본 문서 + schema.prisma Read 기반) | 채팅 토큰 usage 기록 (응답 메타) |
| OpenAI API | **0건** | — |
| Polar (결제) | **0건** | 구독 결제 webhook (별도 sprint PAY-P1-4) |
| 외부 npm 라이브러리 | **0건** | I Phase에서도 신규 0건 권장 (PAY-P3-H ADR-009 정합) |
| DB schema 변경 | **0건** (Draft) | I Phase: 마이그레이션 (§6 매트릭스) |

> **본 S Phase Draft = 외부 API 0건 / DB 변경 0건 / 코드 변경 0건.** 순수 설계 산출물.

## §4. 사용자 결정 영역 (결정 게이트 6건 — I Phase 진입 전 필수)

> 각 게이트는 옵션 + 장단점 + 권장. **사용자 결정 전 I Phase 착수 불가** (§17 진입 게이트).

---

### 게이트 1 — 포인트 출처 4종 분리 회계 구조 (§8-2)

**문제**: §8-2가 포인트 출처 4종(무료적립 / 구독풀 / 응원선물 / 충전)을 **분리 회계**하라고 확정. `Author.credits` 단일 Int로는 불가. 어떻게 분리 저장하는가.

**§8-2 제약 (정본)**:
- 출처별 §0 위상 다름: 무료적립=CAC(매출 0) / 구독풀="월 한도 누적원가 ≤ 구독료÷3" / 응원선물=독자 결제분 이전(재검증 불요) / 충전=pt 단가에 §0 박힘(영구 보존).
- **소진 우선순위 강제**: 무료적립 → 구독풀 → 응원선물 → 충전.

| 옵션 | 구조 | 장점 | 단점 |
|---|---|---|---|
| **1-A** 출처별 4 필드 분리 | `Author`에 `pointsFree` / `pointsSubscription` / `pointsGift` / `pointsCharged` Int 4 필드 | 조회 단순(SELECT 1회), 잔액 계산 즉시(4 필드 합), 마이그레이션 단순 | 입출금 이력 부재(언제 어느 출처가 얼마 변동?), 만료 시점(구독풀 매월 리셋) 개별 row 추적 불가, audit 약함 |
| **1-B** `CreditLedger` 입출금 테이블 | 신설 `CreditLedger` (authorId, source enum, type enum[earn/spend], amount, balanceAfter, expiresAt?, reason, createdAt) — 모든 적립/소진을 1 row 박제, 잔액 = 합산 또는 캐시 | 완전한 입출금 이력(회계 정합·audit 강함), 출처별 만료(`expiresAt`) row 단위 관리, 소진 우선순위 추적 가능, 분쟁 시 역추적 | 잔액 조회 시 SUM 집계 또는 캐시 필요(N+1 위험), 마이그레이션 복잡(기존 잔액 → 초기 ledger row 생성), 구현량 큼 |
| **1-C** 하이브리드 (1-A 캐시 + 1-B 원장) | `Author` 4 필드 = **잔액 캐시**(빠른 조회) + `CreditLedger` = **입출금 원장**(audit·이력). 적립/소진 시 $transaction으로 ledger insert + Author 4 필드 동기 갱신 | 조회 빠름(캐시) + 이력 완전(원장) + 정합성 검증 가능(SUM vs 캐시 cron 대조 — PAY-P0-2 `ReconciliationCheckpoint` 패턴 재사용) | 가장 복잡 — 캐시-원장 2중 갱신 + 정합성 cron 필요. 단 결제 도메인(PAY)이 이미 이 패턴 운영 중 |

**권장 — 1-C 하이브리드**. 사유:
- §0 회계 분리(CAC/COGS) + 분쟁 역추적은 `CreditLedger` 원장 없이는 불가능 → 1-A 단독 탈락.
- 채팅 사후 차감 + `deficit` 외상(게이트 5)은 "어느 출처에서 얼마 소진"을 row 단위로 박아야 함 → 원장 필수.
- 구독풀 매월 리셋(이월 금지, §8-8 #2)은 `expiresAt` 있는 ledger row여야 정확 — 1-A는 "리셋 시 필드 0" 외에 만료분 추적 불가.
- 조회 빈도가 높은 잔액(대시보드·차감 전 검증)은 캐시 4 필드로 N+1 회피.
- **기존 패턴 재사용**: PAY-P0-2 `ReconciliationCheckpoint`(L481-492)가 "단일 row checkpoint로 PG↔DB 정합 cron" 패턴을 이미 운영 → 캐시-원장 정합 cron에 동일 패턴 차용 가능. RefundLog의 $transaction 3중 박제(shared-contracts §13)도 적립/소진 트랜잭션 템플릿으로 재사용.
- **트레이드오프 인정**: 가장 복잡. 단 §8-2 분리 회계 + §8-8 CRITICAL #2(이월 금지)를 동시에 만족하는 유일한 구조. 1-B 단독은 조회 N+1, 1-A 단독은 회계 불가.

> **결정 필요**: 1-A / 1-B / **1-C(권장)** 중 택일. 1-C 채택 시 §6 스키마 매트릭스의 `CreditLedger` 신설 + `Author` 4 필드가 확정된다.

---

### 게이트 2 — 디노미네이션 마이그레이션: `credits` 필드 변경 방식 (§8-1, §8-6)

**문제**: `Author.credits Int`(L23)를 1,000pt 환산 단위로 전환. 기존 잔액 ×1,000. `credits` 필드 자체를 의미 변경하는가, 신규 필드를 두는가.

| 옵션 | 방식 | 장점 | 단점 |
|---|---|---|---|
| **2-A** `credits` 필드 의미 변경 | 기존 `credits` 컬럼을 그대로 두되 단위만 "크레딧 → 포인트"로 재해석. 마이그레이션 SQL `UPDATE authors SET credits = credits * 1000` | 컬럼 추가 0건 | 의미 변경이 코드 전역에 암묵 전파 — 마이그레이션 직후 ~직전 코드 혼재 시 단위 불일치 치명적. 모든 차감/적립/표시 코드를 동일 커밋에 전환해야 함 |
| **2-B** 신규 `pointsBalance` 필드 + `credits` deprecate | `credits` 보존(읽기 전용 deprecated) + 신규 `pointsBalance` 또는 게이트 1의 4 필드 신설. 마이그레이션이 `credits×1000` → 신규 필드 채움 | 단위 혼동 0건(필드명이 단위를 말함), 롤백 용이(`credits` 원본 보존), 점진 전환 가능 | 컬럼 잔존(`credits` deprecated) — 일정 기간 후 별도 sprint로 제거 |
| **2-C** 게이트 1과 통합 — `credits` 폐기 + 4 필드 신설 | 게이트 1이 1-C(하이브리드)면 `Author.credits` 자체를 폐기하고 `pointsFree`/`pointsSubscription`/`pointsGift`/`pointsCharged` 4 필드 + `CreditLedger`로 완전 이행. 마이그레이션이 `credits×1000` → 전량 `pointsCharged`에 적재(§8-6 권고 "충전 분류") + ledger 초기 row 1건 | 게이트 1과 일관, 단위·출처 동시 해결, deprecated 컬럼 0건 | 마이그레이션 1회로 큰 변경 — 철저한 dev 검증 + 백업 필수 |

**권장 — 2-C (게이트 1이 1-C인 경우)**. 사유:
- 게이트 1을 1-C로 권장한 이상, `credits` 단일 Int는 어차피 폐기 대상 → 별도 `pointsBalance`(2-B)를 두면 "4 필드 + pointsBalance + credits" 3중 중복.
- §8-6 정본: "기존 잔액의 출처 분류 **권고: 전량 충전(유료)으로 분류**" — 마이그레이션 시 `credits×1000` → `pointsCharged`에 적재가 정확히 §8-6 권고와 일치.
- `CreditLog` 이력이 남아 있으면 출처별 역추적 가능성도 §8-6이 언급 → 1-C의 `CreditLedger` 초기 row를 `CreditLog` 기반으로 분해 적재하는 옵션도 I Phase에서 검토 가능(단 권장은 단순하게 전량 충전).
- **롤백 안전망**: `credits` 컬럼을 마이그레이션에서 **즉시 DROP하지 않고** deprecated 보존(별도 후속 sprint DROP) → Cursor 가격개편 반발 반면교사(§8-6) + dev 안정성 검증 기간 확보. 즉 "2-C 채택 + `credits` 컬럼은 1 sprint 유예 후 제거".

> **결정 필요**: 2-A / 2-B / **2-C(권장, 게이트 1=1-C 전제)** 중 택일. 게이트 1 결정에 종속 — 게이트 1을 1-A로 정하면 2-A/2-B 중 2-B 권장.

---

### 게이트 3 — `ChatMessage` 토큰 필드 추가 (§8-7 #1, §8-8 CRITICAL #3)

**문제**: §8-8 CRITICAL #3 — "채팅 토큰 실측 필드(`ChatMessage.inputTokens/outputTokens`) 선행 필수. 없으면 모든 차감액이 추측." `model` 필드도 §8-7 #1이 명시.

**현행 (schema.prisma L309-319)**: `ChatMessage`는 `id / sessionId / role / content / createdAt` — 토큰 필드 0건.

**추가 필드 (§8-7 #1 정본)**:
```prisma
model ChatMessage {
  // ... 기존 유지 ...
  inputTokens  Int?    @map("input_tokens")   // assistant 메시지에만 — API 응답 usage.input_tokens
  outputTokens Int?    @map("output_tokens")  // assistant 메시지에만 — API 응답 usage.output_tokens
  model        String? // 'claude-sonnet-4-6' 등 — 차감 N 재산정 시 모델 식별
  chargedPoints Int?   @map("charged_points") // 이 턴에 차감된 pt (4구간 정액) — null=미차감(과거 무료 시대 row)
}
```

| 결정 항목 | 옵션 | 권장 |
|---|---|---|
| **nullable 여부** | (a) `Int` NOT NULL + default 0 / (b) `Int?` nullable | **(b) nullable**. 사유: `role='user'` 메시지는 토큰 usage가 assistant 응답에만 붙음(input은 user 메시지 누적이나 차감은 턴 단위) → user row는 null. 과거 무료 시대 row도 null. NOT NULL+0은 "0 토큰"과 "미측정"을 구분 못 함 — §8-8 #3 "추측 금지" 위반 위험 |
| **기존 row 처리** | (a) 0 백필 / (b) null 유지 / (c) 측정 불가 표식 | **(b) null 유지**. 과거 무료 채팅은 토큰 미기록 — 소급 측정 불가. null = "측정 안 됨" 의미 보존. 차감액 산출 시 null row는 §8-4 차감 대상 0건(과거 무료) |
| **`chargedPoints` 추가 여부** | 차감 pt를 메시지에 박을지 | **추가 권장**. 게이트 5 사후 차감의 감사 정합 — "이 턴이 어느 구간으로 판정돼 얼마 차감됐는지"를 메시지 row에 박으면 분쟁/검증 용이. `CreditLedger`(게이트 1)와 교차 검증 가능 |
| **구간 필드 추가 여부** | `tier` enum('short'/'normal'/'long'/'xlong') 박을지 | **추가 권장** (`chargeTier String?`). inputTokens만으로 구간 재계산 가능하나, 경계값(§8-4 500/4,000/12,000)이 운영 중 재확정될 수 있음(§8-4 "경계값은 가정") → 차감 시점의 구간을 박아두면 경계 변경 후에도 과거 차감 근거 보존 |

**권장 종합**: `inputTokens Int?` + `outputTokens Int?` + `model String?` + `chargedPoints Int?` + `chargeTier String?` 5 필드 추가, 전부 nullable, 기존 row null 유지.

> **CRITICAL 정합**: 이 필드 추가는 §8-8 #3 "선행 필수" — **게이트 5(채팅 차감 로직)보다 반드시 먼저 마이그레이션**. 토큰 필드 없이 차감 구현 진행 = §8-8 #3 위반.

> **결정 필요**: 5 필드 전체 채택 / 토큰 3 필드(`inputTokens`/`outputTokens`/`model`)만 채택(§8-7 #1 최소) 중 택일. 권장 = 5 필드(감사·재확정 정합).

---

### 게이트 4 — 구독 월 포인트 풀 스키마 구조 (§8-3)

**문제**: §8-3 — Pro 93,000pt / Premium 191,500pt 월 포인트 풀. 매월 리셋 + **이월 금지**(§8-8 #2). 어디에 저장하고 리셋을 어떻게 구현하는가.

**제약 (정본)**:
- §1-1 발견: 현행 `Subscription` 모델(L211-221)은 **독자→작가 팔로우** — 본 구독제와 무관. 신설 모델 필요 또는 `Author` 확장.
- §8-3: 월 풀은 채팅·테마·분석 **3기능 공용**. 일일 무료 테마 생성과는 계층 구조(무료 횟수 → 공용 풀 → 충전 pt).
- §8-8 #2: 풀 이월 금지 — 무제한 이월 시 §0이 0.14×로 붕괴.

| 옵션 | 구조 | 리셋 구현 | 장점 | 단점 |
|---|---|---|---|---|
| **4-A** `Author` 필드 확장 | `Author`에 `subscriptionPoolBalance Int` + `subscriptionPoolResetAt DateTime` + 기존 `plan`/`planExpireAt` 활용 | 매월 cron 또는 조회 시점 — `resetAt` 경과 시 풀을 plan별 기본값(93,000/191,500)으로 재설정 | 모델 신설 0건, 조회 단순 | 구독 이력(언제 가입/변경/해지) 추적 불가, 풀 사용 이력 부재 |
| **4-B** 신설 `MembershipPlan` 모델 | `MembershipPlan` (authorId, tier enum[free/pro/premium], monthlyPoolPoints, poolBalance, poolResetAt, startedAt, expiresAt, polarSubscriptionId?, status) — 구독 1건 = 1 row | `poolResetAt` 경과 시 `poolBalance = monthlyPoolPoints` 재설정 (cron 또는 lazy) | 구독 이력 완전, Polar 연동 필드(`polarSubscriptionId`) 수용, 플랜 변경 추적 | 모델 신설 + `Author.plan`과 정합 필요(이중 출처 위험) |
| **4-C** `MembershipPlan` + `CreditLedger` 통합 | 4-B 모델 + 풀 적립/소진은 게이트 1의 `CreditLedger`에 `source='subscription'` + `expiresAt=다음 리셋일` row로 기록. 리셋 = 만료된 subscription row 무효 + 신규 풀 row 생성 | `CreditLedger` row의 `expiresAt`이 곧 리셋 — 만료 row는 잔액 집계에서 제외 → **이월이 구조적으로 불가능** | §8-8 #2(이월 금지)를 스키마가 강제, 풀 사용 이력 완전, 게이트 1과 일관 | 가장 복잡 — `MembershipPlan` + ledger 2 모델 협조 |

**권장 — 4-C (게이트 1=1-C 전제)**. 사유:
- §8-8 CRITICAL #2 "이월 금지"를 **cron 로직에 의존(4-A/4-B)하면 cron 누락 시 §0 0.14× 붕괴** — 스키마가 강제하는 4-C가 안전. `CreditLedger` row의 `expiresAt < now()` → 잔액 집계 자동 제외 = 이월이 코드 버그로도 발생 불가.
- §8-3 "풀은 채팅·테마·분석 공용" — 공용 풀은 게이트 1의 `CreditLedger`에서 `source='subscription'` 단일 출처로 관리하면 소진 우선순위(무료적립→구독풀→응원선물→충전)가 자연 구현.
- Polar 구독 결제 연동(별도 sprint PAY-P1-4)은 `MembershipPlan.polarSubscriptionId`가 수용 — 본 Draft는 필드만 두고 연동은 I Phase 외.
- `Author.plan` 이중 출처 위험 → `MembershipPlan`을 정본으로 하고 `Author.plan`은 deprecated 또는 `MembershipPlan.tier` 미러로 정리(I Phase 결정 항목으로 §15에 명시).
- **리셋 구현 방식**: lazy(조회 시점 계산) vs cron. 권장 = **cron + lazy 이중 안전망** — 매월 cron(`@Cron`)이 만료 row 정리 + 신규 풀 생성, 단 cron 실패 대비 조회 시점에도 `expiresAt` 체크. PAY-P2-5 `audit-mask.scheduler`(`@Cron('0 0 3 * * *')`) 패턴 차용.

> **결정 필요 (2 항목)**:
> (a) 구독 풀 저장: 4-A / 4-B / **4-C(권장)** 중 택일.
> (b) 신설 모델명: `MembershipPlan` / `CreditSubscription` / `SubscriptionPlan` 중 택일 — 현행 `Subscription`(팔로우)과 충돌 회피 필수. **권장 `MembershipPlan`** (팔로우 `Subscription`과 명확히 구분, "멤버십 등급" 의미).

---

### 게이트 5 — 채팅 4구간 차감 + 사후 차감 + `deficit` 외상 (§8-4)

**문제**: §8-4 — 채팅은 4구간 정액 차감. 토큰은 API 응답 후 확정 → **사후 차감**. 잔액 부족 시 `deficit`(외상) 기록.

**제약 (정본 §8-4)**:
- 채팅 차감 = 구간 정액 4구간(§1-3 표). **3구간 금지**(§8-8 #4 — P99 꼬리 2.40× §0 위반).
- 판정 시점: 토큰은 API 응답 후 확정 → **사후 차감**(선차감 아님).
- 사후 차감 시 잔액 부족 → `deficit`(외상) 기록 후 다음 충전 시 우선 상계 — **기존 `RefundLog.deficitCredits` 패턴 차용**(정본 §8-4 명시).
- 구간 경계값(500/4,000/12,000 tok)은 가정 — 운영 1~2주 실측 후 재확정.

| 결정 항목 | 옵션 | 권장 |
|---|---|---|
| **차감 시점** | (a) 선차감(요청 전 최대구간 차감 후 정산) / (b) 사후 차감(응답 후 구간 확정 차감) | **(b) 사후 차감** — §8-4 정본 강제. 토큰은 API 응답 `usage`로만 확정 가능 → 선차감 불가 |
| **`deficit` 저장 위치** | (a) `Author`에 `deficitPoints Int` 필드 / (b) `CreditLedger`에 음수 잔액 row / (c) 신설 `CreditDeficit` 테이블 | **(a) `Author.deficitPoints Int @default(0)`** — `RefundLog.deficitCredits` 패턴(shared-contracts §13)과 동형. 단순·조회 즉시. 충전 시 우선 상계 로직이 명확. 단 ledger와 교차 검증 위해 deficit 발생/상계도 `CreditLedger` row로 박제(type='deficit_incur'/'deficit_settle') |
| **구간 경계값** | (a) 하드코딩 상수 / (b) `SystemSetting` 테이블 동적 값 | **(b) `SystemSetting`** — §8-4 "경계값은 가정, 운영 1~2주 실측 후 재확정". 하드코딩이면 재확정 시 재배포 필수. `SystemSetting`(L388-395, key-value) 활용 → `chat.tier.boundary.short=500` 등. 차감 N(190/810/3,390/5,520)도 동일하게 `SystemSetting` 후보 — 단 §0 직결값이라 cost-accountant 승인 게이트(§14)와 연동 |
| **차감 실패 시** | 잔액 0 + deficit도 한계 초과 시 | **응답은 정상 제공 + deficit 누적** — 사후 차감이므로 응답은 이미 생성됨. deficit 상한(예: -10,000pt) 도달 시 신규 채팅 차단 → 충전 유도. 상한은 `SystemSetting` |

**차감 로직 영역 설계 (§8 정합)**:
```
1. 채팅 요청 → Claude API 호출 → 응답 + usage{input_tokens, output_tokens} 수신
2. ChatMessage(assistant) 저장 시 inputTokens/outputTokens/model 박제
3. 구간 판정: inputTokens 기준 4구간 (SystemSetting 경계값)
   ≤500 → 190pt / 501~4,000 → 810pt / 4,001~12,000 → 3,390pt / >12,000 → 5,520pt
4. $transaction (RefundLog 3중 박제 패턴 차용 — shared-contracts §13):
   a. CreditLedger insert (type='spend', source=소진우선순위 적용, amount=-구간정액)
   b. Author 캐시 4 필드 차감 (소진 우선순위: 무료적립→구독풀→응원선물→충전)
   c. 잔액 부족분 = deficit → Author.deficitPoints += 부족분 + CreditLedger(type='deficit_incur')
   d. ChatMessage.chargedPoints / chargeTier 박제
5. 충전 시: deficitPoints > 0 → 충전 pt에서 우선 상계 (CreditLedger type='deficit_settle')
```

> **소진 우선순위 + deficit 상호작용 (게이트 1과 결합)**: 4 출처 순서대로 차감하다 전부 0이면 deficit. 충전 시 §8-2 우선순위상 충전이 마지막이지만, deficit 상계는 **충전 즉시 최우선**(외상 갚기). 이 모순 없는 순서는 I Phase spec에서 명확히 — 본 Draft는 "deficit 상계 > 신규 적립"으로 권장.

> **결정 필요 (3 항목)**:
> (a) `deficit` 저장: **(a) `Author.deficitPoints`(권장)** / (b) ledger 음수 / (c) 신설 테이블.
> (b) 구간 경계값/차감 N 저장: 하드코딩 / **`SystemSetting` 동적(권장)**.
> (c) deficit 상한값(신규 채팅 차단 임계) — 권장 -10,000pt, 사용자 확정.

---

### 게이트 6 — 차감 N 재산정 트리거 sensor (§8-7 #8, §8-8 CRITICAL #5)

**문제**: §8-7 #8 + §8-8 #5 — "경계선 운영(쿠션 거의 0). 재산정 트리거를 sensor에 반드시 연동." 환율/모델가 임계 도달 시 차감 N(190/810/3,390/5,520/2,440/590pt) 재산정 ALERT.

**제약 (정본 §8-7 #8)**:
- 트리거 3 조건: ① 환율 ₩1,624.33 도달 ② Sonnet 단가 ±20% 도달 ③ **합성 변동 누적 +25% 도달**(스트레스 한계 +30.2% 직전 선제).
- `AI_COST_MONITOR.md §6` 가격알림과 **별개**의 "차감 N 코드변경" 트리거.
- researcher 스윕 시 cost-accountant 핸드오프.

**sensor 신설안 — `sensor-credit-overhaul-recalc.sh`** (`.claude/scripts/`):

| 검증 항목 | 트리거 조건 | ALERT 동작 |
|---|---|---|
| 환율 임계 | `AI_COST_MONITOR.md` 환율 ≥ ₩1,624.33 | WARN → cost-accountant 호출 권고 |
| Sonnet input 임계 | Sonnet input 단가 현재 대비 ±20% | WARN → 차감 N 재산정 필요 |
| Sonnet output 임계 | Sonnet output 단가 현재 대비 ±20% | WARN → 차감 N 재산정 필요 |
| 합성 변동 누적 | (환율변동% + 모델가변동%) 누적 ≥ +25% | **CRITICAL → I Phase 차감 N 코드변경 sprint 발의** |
| ai-cost-table 정합 | `ai-cost-table.md` 채팅 4구간/분석/테마 pt가 §8 확정값과 일치 | drift 시 WARN |

| 옵션 | 방식 | 권장 |
|---|---|---|
| **6-A** sensor만 (수동 호출) | `.claude/scripts/sensor-*.sh` — 작업 완료 시 일괄 실행에 포함 | 기존 sensor 23종 패턴 정합. 단 researcher 스윕과 수동 연동 |
| **6-B** sensor + researcher 핸드오프 명문화 | 6-A + researcher 정의(.md)에 "스윕 시 환율 임계 도달하면 cost-accountant 핸드오프" 명문화 + cost-accountant 정의에 "재산정 트리거 수신 시 차감 N 재산출" 추가 | §8-7 #8 "researcher 스윕 시 cost-accountant 핸드오프" 정본 충족 |

**권장 — 6-B**. 사유: §8-7 #8이 "researcher 스윕 시 cost-accountant 핸드오프"를 명시 → sensor 신설(6-A)만으로는 핸드오프 주체가 불명. researcher/cost-accountant 정의에 트리거 동작을 명문화해야 §8-8 #5 "반드시 연동" 충족. 본 Draft §14 위임에 이 명문화를 포함.

> **결정 필요**: 6-A / **6-B(권장)** 중 택일. 6-B 채택 시 §14 위임에 researcher/cost-accountant 정의 갱신이 추가된다.

---

### §4-요약. 결정 게이트 6건 한눈에

| 게이트 | 결정 항목 | 권장 | 종속 |
|---|---|---|---|
| 1 | 포인트 출처 4종 회계 구조 | **1-C** 하이브리드(`Author` 4 필드 캐시 + `CreditLedger` 원장) | — |
| 2 | `credits` 필드 변경 방식 | **2-C** `credits` 폐기 + 4 필드(1 sprint 유예 후 DROP) | 게이트 1 |
| 3 | `ChatMessage` 토큰 필드 | **5 필드** nullable (`inputTokens`/`outputTokens`/`model`/`chargedPoints`/`chargeTier`) | — |
| 4 | 구독 월 풀 구조 + 모델명 | **4-C** `MembershipPlan` 신설 + `CreditLedger` 통합 / 모델명 `MembershipPlan` | 게이트 1 |
| 5 | 채팅 차감 + deficit + 경계값 | 사후 차감 / `Author.deficitPoints` / 경계값·N `SystemSetting` 동적 / 상한 -10,000pt | 게이트 1·3 |
| 6 | 재산정 트리거 sensor | **6-B** sensor + researcher/cost-accountant 핸드오프 명문화 | — |

## §5. DDD Hexagonal 정합

> grimoire-server는 Hexagonal — domain → port → adapter → application → controller (CLAUDE.md §5). 본 개편의 신규 요소를 레이어별 배치.

| 레이어 | 신규 요소 (게이트 권장값 기준) |
|---|---|
| `domain/model/` | `credit-point.ts` (Point 값 객체 + 디노미네이션 상수 `CREDIT_TO_POINT=1000`) / `credit-source.ts` (CreditSource enum: free/subscription/gift/charged) / `chat-charge-tier.ts` (ChatChargeTier enum + 4구간 경계·차감 N) / `membership-tier.ts` (MembershipTier enum: free/pro/premium + 풀 크기) |
| `domain/port/outbound/` | `credit-ledger.port.ts` (CreditLedgerPort — earn/spend/getBalance/settleDeficit) / `membership-plan.port.ts` (MembershipPlanPort — getPlan/resetPool/findExpiredPools) |
| `adapter/outbound/persistence/` | `prisma-credit-ledger.repository.ts` / `prisma-membership-plan.repository.ts` |
| `application/` | `credit/charge-points.usecase.ts` (소진 우선순위 + deficit) / `credit/grant-points.usecase.ts` (적립) / `subscription/reset-monthly-pool.job.ts` (`@Cron` 월간 리셋) / `chat/*` 기존 채팅 usecase에 사후 차감 연동 |
| `domain/policy/` | `credit-consumption-policy.ts` (소진 우선순위 무료적립→구독풀→응원선물→충전 + deficit 상계 정책) — USER-SOFT-DELETE의 `user-soft-delete-policy.ts` 패턴 차용 |
| `controller/` | 기존 `/dashboard/chat` · `/dashboard/credits` 컨트롤러에 차감/잔액 응답 변경. 신규 구독 결제는 별도 sprint |
| `scheduler/` 또는 `application/*/` | `reset-monthly-pool.job.ts` — `@Cron` (PAY-P2-5 `audit-mask.scheduler` + USER-SOFT-DELETE `user-hard-delete.job` 패턴) |

> **정합 원칙**: §0 크레딧-원가 직결 상수(차감 N 등)는 `domain/model/` + `SystemSetting` 동적 — 헥사고날상 domain 순수 영역. Claude API 토큰 usage는 기존 `adapter/outbound/ai/` 영역에서 추출.

## §6. 스키마 변경 매트릭스 (prisma 모델별 — 게이트 권장값 기준, I Phase 확정)

> **본 매트릭스는 게이트 권장값(1-C/2-C/3=5필드/4-C/5/6-B) 채택 가정.** 사용자가 다른 옵션 선택 시 재산정.

| # | 모델 | 변경 유형 | 상세 | 게이트 |
|---|---|---|---|---|
| 1 | `Author` | 필드 추가 | `pointsFree Int @default(0)` / `pointsSubscription Int @default(0)` / `pointsGift Int @default(0)` / `pointsCharged Int @default(0)` (잔액 캐시 4 필드) + `deficitPoints Int @default(0)` | 1, 2, 5 |
| 2 | `Author` | 필드 deprecate | `credits Int` — 읽기 전용 deprecated 표기, 마이그레이션에서 즉시 DROP 안 함(1 sprint 유예) | 2 |
| 3 | `Author` | 필드 정리(I Phase 결정) | `plan` / `planExpireAt` — `MembershipPlan` 정본화 후 deprecated 또는 미러 (§15) | 4 |
| 4 | `CreditLedger` | **신설** | `id` / `authorId` (FK Restrict — 회계 영구 보존, ADR-007 정합) / `source` (free/subscription/gift/charged) / `type` (earn/spend/deficit_incur/deficit_settle/expire) / `amount Int` (부호 有) / `balanceAfter Int` / `expiresAt DateTime?` (구독풀 리셋·만료) / `reason String` / `relatedId String?` (ChatMessage/Payment/AnalysisReport FK 약결합) / `createdAt` | 1 |
| 5 | `MembershipPlan` | **신설** | `id` / `authorId` (FK — 1:1 또는 이력 1:N) / `tier` (free/pro/premium) / `monthlyPoolPoints Int` / `poolBalance Int` / `poolResetAt DateTime` / `startedAt` / `expiresAt DateTime?` / `polarSubscriptionId String?` (Polar 연동 — I Phase 외) / `status` (active/expired/cancelled) | 4 |
| 6 | `ChatMessage` | 필드 추가 | `inputTokens Int?` / `outputTokens Int?` / `model String?` / `chargedPoints Int?` / `chargeTier String?` — 전부 nullable, 기존 row null | 3 |
| 7 | `AnalysisReport` | 필드 정리 | `creditsCharged Int @default(3)` → `chargedPoints Int` (2,440pt) 또는 단위 의미 변경. default stale 정정 | 2 |
| 8 | `SystemSetting` | 데이터 추가 (스키마 무변경) | `chat.tier.boundary.short=500` 등 경계값 + 차감 N + deficit 상한 — key-value row INSERT (마이그레이션 또는 seed) | 5 |
| 9 | `Payment` | 필드 검토(I Phase) | `credits Int` — 충전 시 pt 단위 정합 검토 (디노미 후 pt 적립) | 2 |
| 10 | `RefundLog` | 필드 검토(I Phase) | `credits` / `deficitCredits` — pt 단위 정합 검토 (환불도 pt 단위) | 2, 5 |

> **신규 모델 2건 (`CreditLedger` / `MembershipPlan`) 의 FK onDelete 정책**: ADR-007 FKCascadePolicy 정합 — `CreditLedger.authorId`는 **Restrict**(회계 영구 보존, 8건째 → 9건째 Restrict), `MembershipPlan.authorId`는 **Cascade 또는 Restrict** 검토(구독 이력 보존 필요 시 Restrict). USER-SOFT-DELETE(ADR-011) soft delete 시 ledger/plan은 보존(Author.deletedAt만, hard delete는 30일 cron + Restrict 차단). 이 FK 정책 확정은 I Phase server Generator + ADR-012에 박제.

> **인덱스 권장**: `CreditLedger` — `@@index([authorId, createdAt])` + `@@index([authorId, source])` + `@@index([expiresAt])`(만료 집계). `MembershipPlan` — `@@index([authorId])` + `@@index([poolResetAt])`(리셋 cron) + `@@index([status])`.

## §7. 마이그레이션 단계 (dev → prod, 기존 잔액 환산)

> PAY-P2-5/PAY-P3-E 마이그레이션 단계 패턴 차용. 각 단계 사용자 명시 키워드 게이트(§8). **돈(잔액) 직결 마이그레이션 → 백업·검증 최강 강도.**

| 단계 | 내용 | 산출/명시 키워드 |
|---|---|---|
| 1 | **dev 측정** — 기존 `authors` row 수 + `credits` 합계 + `chat_messages` row 수 + 토큰 필드 부재 확인 | `.claude/state/credit-overhaul-dev-measure-raw.md` (server/infrastructure agent) |
| 2 | **dev 백업** — `pg_dump` (authors / credit_logs / chat_messages / payments / refund_logs 최소) | 명시: `크레딧개편 dev 백업 박제 완료` |
| 3 | **schema.prisma + migration.sql 작성** — §6 매트릭스: `CreditLedger`/`MembershipPlan` 신설(CREATE TABLE 2) + `Author` 5 필드 ADD COLUMN + `ChatMessage` 5 필드 ADD COLUMN + FK 제약(ADR-007 정합) + 인덱스 | server Generator |
| 4 | **데이터 마이그레이션 SQL** — (a) `Author.pointsCharged = credits * 1000`, 나머지 3 필드 0 (§8-6 전량 충전 분류) (b) `CreditLedger` 초기 row 1건/작가 (type='earn', source='charged', amount=pointsCharged, reason='denomination_migration_v6') (c) `MembershipPlan` 초기 row — 기존 `plan`별 tier 매핑 + poolBalance=plan별 기본값 (d) `AnalysisReport.creditsCharged` 단위 정정 | server Generator + 마이그레이션 SQL |
| 5 | **spec + sensor + eval + shared-contracts §30 + ADR-012** | I Phase 영역 (§9~§13) |
| 6 | **dev migration apply** — `npx prisma migrate deploy` + 직후 검증(`Author.pointsCharged` 합 = 구 `credits`×1000, `CreditLedger` row 수 = 작가 수) | 명시: `크레딧개편 dev migration 진행` |
| 7 | **dev 차감 로직 직접 검증** — 채팅 4구간 차감 + deficit + 구독 풀 소진 dev curl 검증 | 명시: `크레딧개편 dev 차감 검증 진행` |
| 8 | **dev 24h 안정성** — 월간 리셋 cron + 차감 정합 자연 누적 | 명시: `크레딧개편 dev 24h 안정성 박제 통과` |
| 9 | **prod migration** — prod 측정 → 백업(`pg_dump`) → migration → 검증. **고지문**: "기존 크레딧 손해 없음 — 1크레딧 = 1,000pt 환산"(§8-6 Cursor 반면교사) | 명시: `크레딧개편 prod migration 진행` |

> **마이그레이션 정합성 검증 (단계 6·9 직후 필수)**:
> - `SELECT SUM(points_charged) FROM authors` = `SELECT SUM(credits)*1000 FROM authors`(마이그레이션 전 스냅샷) — 1pt도 어긋나면 롤백.
> - `CreditLedger` 초기 row 수 = `credits > 0` 작가 수.
> - `credits` 컬럼은 단계 9에서도 **보존**(deprecated) — 별도 후속 sprint에서 dev 안정성 확인 후 DROP.

## §8. 차감 로직 영역 설계 (§8-4 정합)

> 게이트 5의 차감 로직 영역을 기능별로 정리. **본 Draft는 로직 영역 설계 — 실제 코드는 I Phase server Generator.**

### §8-1. 채팅 차감 (사후 차감 4구간)

게이트 5 차감 로직 영역 5단계 (§4 게이트 5 본문) 그대로. 핵심:
- 사후 차감(API 응답 후 구간 확정) — §8-4 강제.
- 구간: `inputTokens` 기준 4구간, 경계값 `SystemSetting` 동적.
- $transaction = RefundLog 3중 박제 패턴(shared-contracts §13) 차용 — ledger insert + Author 캐시 차감 + deficit 분기 + ChatMessage 박제.

### §8-2. 분석 차감 (정액 2,440pt)

- 현행 `ANALYSIS_CREDIT_COST=4`(shared-contracts §7, config.ts) → **`ANALYSIS_POINT_COST=2440`** 으로 디노미 환산.
- 차감 시점: 분석 실행 직전(원가 고정 — 채팅과 달리 사전 차감 가능, §8 정본 "테마·분석은 1회=예측가능 고정원가").
- 소진 우선순위 동일(무료적립→구독풀→응원선물→충전), 잔액 부족 시 차단(분석은 사전 차감 → deficit 불필요, 잔액 부족 시 실행 거부).
- 기존 환불 분기(분석 실패 시 환불 — `project_analysis_refund_gap` 해소 정합)는 pt 단위로 환산 유지.

### §8-3. 테마 차감 (정액 590pt)

- 현행 1크레딧 → **590pt**.
- 계층 구조(§8-3): ① 일일 무료 횟수(3/7/12회 plan별) 내 → 무료(차감 0) → ② 초과 → 공용 풀(`pointsSubscription`) → ③ 풀 소진 → `pointsCharged`.
- 일일 무료 횟수 카운트 저장 위치 — I Phase 결정 항목(§15): `Author` 필드 vs 별도 일일 카운터. 권장 = 기존 일일 생성 카운트 메커니즘 재사용(현행 구현 확인 필요).

### §8-4. 적립 (가입·첫작품·충전·응원선물)

| 적립 출처 | pt | `CreditLedger.source` | §0 위상 |
|---|---|---|---|
| 가입 보너스 | 현 3크레딧 → 3,000pt | `free` | CAC (매출 0) |
| 첫 작품 등록 | 현 2크레딧 → 2,000pt | `free` | CAC |
| 충전 (Polar) | 패키지별 (§8-5) | `charged` | pt 단가 §0 박힘 |
| 응원 선물 수령 | 1,000·3,000·5,000pt (§8-6) | `gift` | 독자 결제 시 §0 충족 |
| 구독 월 풀 | Pro 93,000 / Premium 191,500 | `subscription` | 구독료÷3 한도 |

- 충전 시 deficit 우선 상계(게이트 5) — `deficitPoints > 0` 이면 충전분에서 먼저 차감.

### §8-5. 응원 선물 (독자 → 작가)

- 현 1·3·5크레딧 → 1,000·3,000·5,000pt 환산(§8-6).
- §8-6 "채팅 시대 단위 적정성은 S Phase에서 재검토" → **§16 사용자 확정 영역**. 본 Draft 권장: 채팅 보통구간 1턴=810pt 대비 1,000pt 선물은 "채팅 1턴+α" 체감 — 단위 자체는 유지하되 표시 UX(천단위)로 보완. 단위 변경 시 별도 결정.

### §8-6. 월간 풀 리셋 (cron)

- `MembershipPlan.poolResetAt` 경과 시 `poolBalance = monthlyPoolPoints` 재설정.
- 게이트 4-C: `CreditLedger`의 `source='subscription'` row가 `expiresAt`(=다음 리셋일) 도달 → 만료 → 잔액 집계 제외 → **이월 구조적 불가**(§8-8 #2).
- cron `@Cron` (PAY-P2-5 패턴) + lazy 조회 이중 안전망.

## §9. jest spec 매트릭스 (I Phase — server Generator)

> PAY-P2-5(+13 it)/PAY-P3-D(+34 it)/USER-SOFT-DELETE(+28 it) 패턴. 본 개편은 돈 직결 → spec 강도 최상.

| spec 파일 | 검증 영역 | 추정 it |
|---|---|---|
| `domain/model/credit-point.spec.ts` | 디노미네이션 상수(1,000) + Point 값 객체 | ≥6 |
| `domain/model/chat-charge-tier.spec.ts` | 4구간 경계 판정(500/4,000/12,000) + 차감 N(190/810/3,390/5,520) + **경계값 정확성**(off-by-one) | ≥10 |
| `domain/policy/credit-consumption-policy.spec.ts` | 소진 우선순위(무료적립→구독풀→응원선물→충전) + deficit 상계 | ≥10 |
| `application/credit/charge-points.usecase.spec.ts` | 채팅 사후 차감 + 잔액 부족 → deficit + $transaction 원자성 + 4구간별 | ≥14 |
| `application/credit/grant-points.usecase.spec.ts` | 적립 4출처별 + 충전 시 deficit 우선 상계 | ≥8 |
| `application/subscription/reset-monthly-pool.job.spec.ts` | 월간 리셋 + 이월 금지(만료 row 제외) + cron noop | ≥6 |
| `adapter/.../prisma-credit-ledger.repository.spec.ts` | ledger insert + 잔액 집계(SUM) + 캐시 정합 | ≥8 |
| 채팅 usecase 기존 spec 확장 | 사후 차감 연동 + ChatMessage 토큰 필드 박제 | +4 |
| 분석 usecase 기존 spec 확장 | `ANALYSIS_POINT_COST=2440` 차감 + 환불 pt 환산 | +4 |
| **마이그레이션 검증 spec** | `pointsCharged = credits*1000` 정합 + ledger 초기 row | ≥4 |

> 추정 합계 ≥84 it 신설/확장. 현행 jest server 805 PASS → I Phase 후 ~890 목표 (정확값은 I Phase `npm test`).

## §10. sensor 신설안 (I Phase — 1차 본 Draft 설계)

| sensor | 검증 | 게이트 |
|---|---|---|
| `sensor-credit-overhaul-recalc.sh` | §4 게이트 6 표 5 검증 (환율/Sonnet ±20%/합성 +25%/ai-cost-table drift) | 6 |
| `sensor-credit-denomination.sh` | 코드 전역에 `credits`(구 정수) 직접 차감 잔존 0건 + 디노미 상수 1,000 일관 + pt 단위 일관 | 2 |
| `sensor-credit-source-accounting.sh` | 4 출처 분리 회계 정합 — `CreditLedger.source` enum 4값 + 소진 우선순위 코드 정합 | 1 |
| `sensor-subscription-pool-no-rollover.sh` | 풀 이월 금지 정합 — `expiresAt` 만료 row 잔액 집계 제외 검증 (§8-8 #2) | 4 |
| `sensor-chat-charge-tier.sh` | 채팅 4구간 정합 — 3구간 회귀 차단(§8-8 #4) + 차감 N이 §8 확정값 | 5 |

> 현행 sensor 23종(정확값 `ls .claude/scripts/sensor-*.sh`) → +5. sensor 작성은 I Phase(harness/server) — 본 Draft는 검증 항목 설계.

## §11. shared-contracts §30 CreditOverhaul (신설안)

> shared-contracts.md 현재 §29(UserSoftDeletePolicy)가 마지막 → **§30이 후속 위치 확정**(Grep 검증 — §29 L2225, §30 미존재).

```typescript
// §30. CreditOverhaul (server 도메인 — 크레딧 디노미네이션 + 출처 회계 + 채팅 4구간 차감)

/** 디노미네이션 상수 — 1크레딧 = 1,000pt */
export const CREDIT_TO_POINT = 1000;

/** 포인트 출처 4종 (§8-2 분리 회계) */
export type CreditSource = 'free' | 'subscription' | 'gift' | 'charged';

/** ledger 엔트리 타입 */
export type CreditLedgerType = 'earn' | 'spend' | 'deficit_incur' | 'deficit_settle' | 'expire';

/** 소진 우선순위 (§8-2) — 인덱스 0이 최우선 소진 */
export const CREDIT_CONSUMPTION_ORDER: CreditSource[] = ['free', 'subscription', 'gift', 'charged'];

/** 채팅 4구간 차감 (§8-4 — 경계값은 SystemSetting 동적, 아래는 §8 기본값) */
export const CHAT_CHARGE_TIERS = [
  { tier: 'short',  inputMax: 500,    points: 190  },
  { tier: 'normal', inputMax: 4000,   points: 810  },
  { tier: 'long',   inputMax: 12000,  points: 3390 },
  { tier: 'xlong',  inputMax: Infinity, points: 5520 },
] as const;

/** 분석·테마 정액 차감 (§8-4) */
export const ANALYSIS_POINT_COST = 2440;   // 구 ANALYSIS_CREDIT_COST=4 디노미 환산
export const THEME_POINT_COST = 590;       // 구 1크레딧 디노미 환산

/** 멤버십 등급 + 월 포인트 풀 (§8-3) */
export type MembershipTier = 'free' | 'pro' | 'premium';
export const MEMBERSHIP_MONTHLY_POOL: Record<MembershipTier, number> = {
  free: 0, pro: 93000, premium: 191500,
};

export interface CreditLedgerPort {
  /** 적립 (가입/충전/응원선물/구독풀) */
  earn(authorId: string, source: CreditSource, amount: number, reason: string, expiresAt?: Date): Promise<void>;
  /** 소진 (소진 우선순위 적용 + 잔액 부족 시 deficit) */
  spend(authorId: string, amount: number, reason: string, relatedId?: string): Promise<SpendResult>;
  /** 출처별 잔액 + deficit */
  getBalance(authorId: string): Promise<CreditBalance>;
  /** 충전 시 deficit 우선 상계 */
  settleDeficit(authorId: string, fromAmount: number): Promise<number>;
}

export interface SpendResult {
  spentBySource: Record<CreditSource, number>;  // 출처별 차감액
  deficitIncurred: number;                       // 외상 발생분 (잔액 부족, 정상 시 0)
}

export interface CreditBalance {
  free: number; subscription: number; gift: number; charged: number;
  total: number;          // 4 출처 합
  deficit: number;        // Author.deficitPoints (외상)
  available: number;      // total - deficit (실사용 가능)
}

export interface MembershipPlanPort {
  getPlan(authorId: string): Promise<MembershipPlanState>;
  /** 월간 리셋 (poolBalance = monthlyPoolPoints, 이월 금지) */
  resetMonthlyPool(authorId: string): Promise<void>;
  /** 리셋 대상 (poolResetAt 경과) */
  findPlansToReset(now: Date): Promise<MembershipPlanState[]>;
}

export interface MembershipPlanState {
  authorId: string;
  tier: MembershipTier;
  monthlyPoolPoints: number;
  poolBalance: number;
  poolResetAt: Date;
  status: 'active' | 'expired' | 'cancelled';
}
```

> **변경 시 동시 갱신 대상** (shared-contracts 규칙): `domain/model/credit-point.ts` / `chat-charge-tier.ts` / `ai-cost-table.md`(cost-accountant) / `ai-analysis-spec.md` / web 가격 안내 페이지. 기존 §7 `ANALYSIS_CREDIT_COST`는 §30 `ANALYSIS_POINT_COST`로 이행 — §7에 `[DEPRECATED → §30]` 표기(shared-contracts "삭제 금지, DEPRECATED 표기만" 규칙).

## §12. ADR-012 (신설안)

> ADR.md 현재 ADR-001~011 → **ADR-012가 후속 번호 확정**(직접 Read 검증).

- **제목**: 크레딧 디노미네이션 + 포인트 출처 분리 회계 + 채팅 4구간 차감 (크레딧 개편 S Phase)
- **상태**: PROPOSED → 사용자 결정 게이트 6건 통과 시 ACCEPTED
- **컨텍스트**: 정수 크레딧이 채팅 가변 비용 표현 불가(§1-2 정본). `Author.credits` 단일 Int로 출처 4종 분리 회계 불가. §8 골격 정본 v6.
- **결정** (게이트 권장값 기준): ① 디노미네이션 1:1,000 단일 통화 ② 출처 4종 = `Author` 4 필드 캐시 + `CreditLedger` 원장(1-C) ③ `credits` 폐기 + 4 필드(2-C) ④ 구독 = `MembershipPlan` 신설 + `CreditLedger` 통합(4-C) ⑤ 채팅 사후 차감 4구간 + `deficit` 외상 ⑥ 재산정 sensor + 핸드오프 명문화.
- **대안**: (A) 이중 통화 — 지갑 2개 UX 복잡 → 거부(§3 정본 옵션 B). (B) 출처 4 필드만(1-A) — 회계 이력 불가 → 거부. (C) 구독 풀 cron 의존 이월 차단(4-A/B) — cron 누락 시 §0 붕괴 → 거부.
- **§0 정합**: 차감 N 전부 스트레스 원가 `ceil(스트레스원가×3 ÷ ₩0.09856)` 기준(§8-1), cost-accountant v3 전 항목 §0 PASS(경계선 운영).
- **결과**: 채팅 가변 비용 4구간 정액으로 표현 + 출처별 CAC/COGS 분리 + 이월 구조적 차단.
- **잔존 영역**: 채팅 토큰 P50~P99 실측(I Phase 배포 후 운영 1~2주) → 구간 경계·N 재확정. 패키지 충전액/보너스율 사용자 확정. `credits` 컬럼 후속 sprint DROP. Polar 구독 결제 연동(별도 sprint).

## §13. eval regression (I Phase)

| task | 검증 | criteria 추정 |
|---|---|---|
| `regression-74-credit-denomination.json` | 디노미 상수 1,000 + `credits` 직접 차감 잔존 0 + pt 단위 일관 | ~10 |
| `regression-75-credit-source-accounting.json` | 4 출처 분리 + 소진 우선순위 + deficit 상계 | ~12 |
| `regression-76-chat-charge-tier.json` | 채팅 4구간 + 3구간 회귀 차단 + 차감 N §8 확정값 | ~10 |
| `regression-77-subscription-pool.json` | 월 풀 + 이월 금지(만료 제외) + 리셋 cron | ~10 |

> 현행 eval regression(정확값 `ls eval/tasks/`, 5/15 기준 활성 71) → +4. category = `cost_zero`(§0 직결, EDD threshold 0.95+, shared-contracts §8). eval task 작성은 I Phase — 본 Draft는 검증 의도 설계.

## §14. agent 위임 매트릭스

| agent | 역할 | 영역 |
|---|---|---|
| grimoire-planner | **Initializer** | 본 S Phase Sprint 계약 Draft (현 산출물) |
| **grimoire-cost-accountant** | **승인 게이트** | `ai-cost-table.md` 개정 — §8 확정 수치(1pt ₩0.12, 채팅 4구간 190/810/3,390/5,520pt, 분석 2,440pt, 테마 590pt, 패키지 4종, 구독 풀)를 §2·§3에 반영. **본 Draft는 개정 항목 명시만 — 실제 수정은 cost-accountant 단독.** §0 마진 ≥3배 재검증 + COST_SIM §v3 정합 확인 |
| grimoire-server | **Generator** | I Phase — schema.prisma(`CreditLedger`/`MembershipPlan` 신설 + `Author`/`ChatMessage` 필드) + migration + domain/port/adapter/usecase/policy/job + spec + sensor 작성 |
| grimoire-web | Generator (I Phase) | 잔액 표시(4 출처 + deficit) / 채팅 차감 안내(4구간) / 구독 플랜 페이지 / 충전 패키지 UI / 디노미 표시(천단위·축약 — §8-1 "큰 숫자 완화 UI") |
| grimoire-researcher | 트리거 명문화 (게이트 6-B) | researcher 정의(.md)에 "스윕 시 환율 ₩1,624.33 / 모델가 ±20% 도달 → cost-accountant 핸드오프" 추가 |
| grimoire-infrastructure | 협업 (I Phase) | dev/prod DB 측정(§7 단계 1) + 마이그레이션 apply + Container Apps Healthy |
| grimoire-qa | Evaluator (I Phase) | AC 채점 + jest/eval/sensor PASS + 마이그레이션 정합성(`pointsCharged` 합 검증) |
| grimoire-visual-canon-keeper | 검수 (I Phase web) | 잔액·구독·충전 UI가 사슴악마 정본 정합 — §8-1 "큰 숫자 표시" 디노미 UX 검수 |

> **cost-accountant 핸드오프 (S Phase 내 — 본 Draft 직후 권장)**: `ai-cost-table.md` 개정안은 §8-7 #7 선행 과제. 본 Draft 산출 직후 cost-accountant에게 "§8 확정 수치로 ai-cost-table.md §2·§3 개정 + §0 재검증" 위임 → 개정 완료 후 I Phase 진입. **본 Draft는 ai-cost-table.md 수정 0건.**

## §15. §8-8 CRITICAL 5건 준수 매트릭스

| # | §8-8 CRITICAL | 본 Draft 반영 | 위치 |
|---|---|---|---|
| 1 | 비스트레스 원가로 차감 N 산출 금지 | 차감 N(190/810/3,390/5,520/2,440/590pt)은 전부 §8 cost-accountant v3 스트레스 원가 `ceil(스트레스원가×3 ÷ ₩0.09856)` 산출값을 **입력으로만 수용 — 본 Draft 재산출 0건**. §30 `CHAT_CHARGE_TIERS` 주석에 "SystemSetting 동적, §8 기본값" 명시 | §1-3, §11 §30, ADR-012 §0 정합 |
| 2 | 구독 풀 이월 금지 | 게이트 4-C 채택 시 `CreditLedger.source='subscription'` row의 `expiresAt`(=리셋일) → 잔액 집계 자동 제외 → **이월이 코드 버그로도 불가능**(cron 의존 아님). `sensor-subscription-pool-no-rollover.sh` 회귀 차단 | 게이트 4, §6 #4·#5, §8-6, §10 |
| 3 | 채팅 토큰 실측 필드 선행 필수 | 게이트 3 — `ChatMessage.inputTokens/outputTokens/model` 추가. **§7 마이그레이션 단계 3에서 게이트 5(차감 로직)보다 먼저** 적용 강제. nullable + 기존 row null(측정 불가 보존) | 게이트 3, §6 #6, §7 |
| 4 | 채팅 초장문 4구간 분리 필수 | §1-3·§11 `CHAT_CHARGE_TIERS` 4구간(short/normal/long/**xlong**) — 3구간 금지. `sensor-chat-charge-tier.sh` + `regression-76`이 3구간 회귀 차단 | §1-3, §11, §10, §13 |
| 5 | 경계선 운영 → 재산정 트리거 sensor 연동 | 게이트 6-B — `sensor-credit-overhaul-recalc.sh`(환율/모델가 임계) + researcher/cost-accountant 핸드오프 명문화. §8-7 #8 3 트리거 조건(환율 ₩1,624.33 / Sonnet ±20% / 합성 +25%) 전부 검증 | 게이트 6, §10, §14 |

> **5건 전부 본 Draft 설계에 반영 확인.** I Phase 구현 시 server Generator가 이 매트릭스를 준수 기준으로 사용.

## §16. 사용자 결정 대기 (자율 변경 차단)

### §16-1. §4 결정 게이트 6건 (I Phase 진입 필수 — §4-요약 표)

1. 게이트 1 — 포인트 출처 회계 구조: 1-A / 1-B / **1-C(권장)**
2. 게이트 2 — `credits` 필드 변경: 2-A / 2-B / **2-C(권장)** + `credits` 컬럼 1 sprint 유예 후 DROP
3. 게이트 3 — `ChatMessage` 토큰 필드: **5 필드(권장)** / 토큰 3 필드만
4. 게이트 4 — 구독 풀: 4-A / 4-B / **4-C(권장)** + 모델명 **`MembershipPlan`(권장)** / `CreditSubscription` / `SubscriptionPlan`
5. 게이트 5 — 채팅 차감: deficit 저장 **`Author.deficitPoints`(권장)** / 경계값·N **`SystemSetting` 동적(권장)** / deficit 상한 **-10,000pt(권장)**
6. 게이트 6 — 재산정 트리거: 6-A / **6-B(권장)**

### §16-2. §8 잔여 — ✅ 사용자 확정 (2026-05-17)

7. **패키지 충전액 4종 + 보너스율** — ✅ **확정**: 입문 ₩3,000 / 기본 ₩5,000 / 인기 ₩10,000 (+10%) / 베스트 ₩30,000 (+15%). cost-accountant §8-5 권장값 그대로 채택 — §0 마진 ≥3× 검증 완료.
8. **응원 선물 단위** — ✅ **확정**: 현행 1,000·3,000·5,000pt 유지 (단위 변경 없음). §8-5 planner 권장 채택 — 표시 UX만 천단위 보완(web Generator).

### §16-3. I Phase 결정 항목 (S Phase 범위 외 — I Phase 착수 시)

- `Author.plan` / `planExpireAt` — `MembershipPlan` 정본화 후 deprecated vs 미러 (§6 #3).
- 일일 무료 테마 생성 카운트 저장 위치 (§8-3) — 기존 메커니즘 재사용 vs 신설.
- `Payment.credits` / `RefundLog.credits/deficitCredits` pt 단위 정합 (§6 #9·#10).
- 신규 모델 2건 FK onDelete 최종 정책 (ADR-007 정합 — §6 주석).
- `CreditLedger` 잔액 = SUM 집계 vs 캐시 정합 cron 주기.

## §17. 진입 게이트 (I Phase 착수 전제)

I Phase(server Generator 구현) 착수 전 **모두 충족 필수**. **현황(2026-05-17): ✅ 6/6 충족 — server Generator 착수 가능.**

- [x] ① §16-1 결정 게이트 6건 사용자 결정 완료 (5/17 권장값 1-C/2-C/5필드/4-C/5/6-B 일괄 채택).
- [x] ② §16-2 패키지 충전액/보너스율 + 응원 선물 단위 사용자 확정 (5/17 — #7 권장값 / #8 현행 유지).
- [x] ③ cost-accountant `ai-cost-table.md` 개정 완료 (`786b0f3` — §8 확정 수치 §2·§3 반영 + §0 전항목 ≥3× PASS) — §8-7 #7.
- [x] ④ 게이트 6-B 채택 → researcher §3-D + cost-accountant §4-4 트리거 명문화 완료 (5/17 grimoire-researcher 위임).
- [x] ⑤ §6 스키마 매트릭스 — 사용자가 권장값(1-C/2-C/4-C 등) 전건 채택 → §6 가정 유지, 재산정 불요.
- [x] ⑥ §7 단계1 dev 측정 완료 (5/17 — authors 12 / SUM credits 100 / credits>0 10 / chat_messages 22, `credit-overhaul-dev-measure-raw.md`).

> **§8-8 CRITICAL 5건 위반 설계는 진입 게이트 자동 FAIL** — 비스트레스 차감 / 풀 이월 / 토큰 필드 누락 / 채팅 3구간 / 재산정 트리거 누락.

<!-- GMP v2.2 이중 앵커 — 하단 -->
## FINAL_REMINDER

- [MUST] `research/CREDIT_PRICING_OVERHAUL_PLAN.md` §8이 골격·수치 정본. §8 ≠ 본 Draft면 §8 우선.
- [MUST] §8-8 CRITICAL 5건 위반 스키마 채택 불가 (§15 매트릭스). I Phase 진입 게이트 자동 FAIL 조건.
- [MUST] 본 Draft = 설계 산출물. schema.prisma / migration / ai-cost-table.md 변경 0건. 사용자 결정 게이트 6건(§16-1) 통과 후 I Phase server Generator 구현.
- [MUST] `ai-cost-table.md` 개정은 cost-accountant 단독 승인 — 본 Draft는 §14에 개정 항목 명시만.
- [MUST] 외부 Anthropic API 의존 0건. 본 Draft는 정본 문서 + schema.prisma 직접 Read 기반. 추정 보고 0건.

---

## §18. 변경 이력

- **2026-05-17 (S Phase Initializer)**: grimoire-planner Initializer 본 Sprint 계약 Draft 신설. 정본 `CREDIT_PRICING_OVERHAUL_PLAN.md` §8(v6) + `schema.prisma`(L23 `Author.credits` / L309-319 `ChatMessage` / L137-146 `CreditLog` / L211-221 `Subscription` / L501-514 `RefundLog`) + `ai-cost-table.md` + `shared-contracts.md`(§7·§13·§29) + `ADR.md`(ADR-001~011) 직접 Read 기반. 17 섹션(PAY-P2-5/PAY-P3-H Draft 골격 차용). §8-7 S Phase 선행 8건 中 스키마 영역 + §8-8 CRITICAL 5건을 사용자 결정 게이트 6건으로 구체화. shared-contracts §30 / ADR-012 후속 위치 확정. 코드/스키마/ai-cost-table 변경 0건 — Draft만 산출.

## §19. 정본 참조 (file:line)

- `/Users/sokol/Git/ProjectGrimoire/research/CREDIT_PRICING_OVERHAUL_PLAN.md` §8 (L219-330 — §8-1~§8-8 골격·수치 정본 v6)
- `/Users/sokol/Git/ProjectGrimoire/grimoire-server/prisma/schema.prisma` L15-62(Author) / L137-146(CreditLog) / L211-221(Subscription=팔로우) / L243-257(Payment) / L294-319(ChatSession/ChatMessage) / L388-395(SystemSetting) / L442-458(AnalysisReport) / L481-514(ReconciliationCheckpoint/RefundLog)
- `/Users/sokol/Git/ProjectGrimoire/grimoire-server/docs/ai-cost-table.md` (§2·§3 — cost-accountant 개정 영역, 본 Draft 수정 0건)
- `/Users/sokol/Git/ProjectGrimoire/.claude/shared-contracts.md` §7 L274-294(ANALYSIS_CREDIT_COST) / §13 L595-664(RefundLog deficit 패턴) / §29 L2225~(마지막 섹션 → §30 후속)
- `/Users/sokol/Git/ProjectGrimoire/grimoire-server/ADR.md` ADR-001(트랜잭션) / ADR-007(FKCascadePolicy) / ADR-011(UserSoftDelete) — ADR-012 후속
- `/Users/sokol/Git/ProjectGrimoire/.claude/state/sprint-pay-p2-5-audit-retention-draft.md` (17 섹션 구조 정본)
- `/Users/sokol/Git/ProjectGrimoire/.claude/state/sprint-pay-p3-h-circuit-breaker-draft.md` (17 섹션 구조 정본)
