# Sprint CC-3 — 이월 금지 lazy 안전망 + Author.plan/tier 이중출처 정리 + 원장 단일화 (PROGRESS)

> 시작: 2026-05-20 / grimoire-server
> 정본 계획: `.claude/state/sprint-cc3-rollover-source-ledger-plan-draft.md`
> 진단 근거: `reports/CREDIT_CORE_DIAGNOSIS.md` §4·§5-A·§5-B·§8
> 브랜치: `feature/cc3-rollover-source-ledger` (develop 분기)

---

## 0. sub-task 체크리스트 (27건)

### S0 — 선행 코드 현행 해소

- [x] **S0a** `Author.plan` 읽기 호출처 grep 재실측
  - 결과: theme-slot.usecase 5건 (L20·34·87·98·134·137-139) + generate-theme.usecase 3건 (L31·39·98) + get-theme.usecase 2건 (L22·36) + plan.usecase 2건 (L30-33·66) + admin.usecase 3건 (L65-66·188) + prisma-author.repository.ts 3건(매핑 — 무관) = application/adapter 합산 13건 (theme/spec 제외). 案 A 권고와 동일.
- [x] **S0b** `MembershipPlanPort.getPlan` 호출처 grep
  - 결과: application 호출처 **0건** (port 정의 + repository 구현 + spec 외엔 호출 없음). 案 A의 "데드 path 회피" 근거 박제.
- [x] **S0c** `credit.usecase`/`prisma-credit.repository` 본문 Read
  - `getGiftRanking`: `creditLog.groupBy(by:['authorId'], where: { reason: { startsWith: 'gift_received' } }, _sum: { amount }, orderBy: { _sum: { amount: 'desc' } }, take: limit)` → `{authorId, totalGifted}[]`.
  - `findLogsByAuthorId`: `creditLog.findMany({ where: { authorId }, orderBy: { createdAt: 'desc' } })` → `CreditLog[]`.
  - **동등성 게이트 박제** — 신 ledger 재작성 시 ① groupBy 동일 입력(`source='gift', type='earn'`) + 동일 정렬(`_sum.amount desc`) + 동일 limit ② findByAuthor는 이미 port에 존재.
- [x] **S0d** `reset-monthly-pool.job.ts` + `prisma-membership-plan.repository.resetMonthlyPool` 본문
  - cron: `@Cron('0 0 4 * * *')` 매일 새벽 4시 + `MONTHLY_POOL_RESET_DISABLED=1` 비활성화 + `isRunning` 동시 차단.
  - 본문(L18 명시): "lazy 리셋은 별도(getPlan 호출처에서 poolResetAt 체크 — I Phase 후속)".
  - `resetMonthlyPool` 트랜잭션 — ① `findFirst({status:'active'})` ② Author FOR UPDATE ③ 기존 잔여 만료 ledger ④ 신규 풀 ledger ⑤ MembershipPlan + Author 캐시 갱신. **idempotency**: 동시 2회 호출 시 두 번째는 FOR UPDATE 직렬화 + `monthlyPoolFor(tier)` 결정적 → 같은 newPool 재설정(외부 관찰 결과 동일).
- [x] **S0e** sensor 5종 파일 + hook 등록
  - 파일: `.claude/scripts/sensor-credit-denomination.sh` / `sensor-subscription-pool-no-rollover.sh` / `sensor-credit-source-accounting.sh` / `sensor-credit-atomicity.sh` / `sensor-admin-credit-ui.sh` / `sensor-chat-charge-tier.sh` / `sensor-credit-overhaul-recalc.sh` — **7건 확인** (계획 §S0e 추정 2건 대비 추가 5건).
  - settings.json/agents/skills 등록 grep: **0건** (harness 영역, server sprint 외).

### CC-3 본 작업

#### CRITICAL-1 lazy 안전망 (案 B)

- [x] **L1a** 설계 결정 명문화 — 案 B (cron + lazy 이중 안전망)
- [x] **L2a** lazy 진입점 = `MembershipPlanPort.checkAndResetExpiredPool(authorId, now)` (案 (i) port 신설)
- [x] **L2b** `MembershipPlanPort.checkAndResetExpiredPool` 시그니처 추가
- [x] **L2c** `prisma-membership-plan.repository.checkAndResetExpiredPool` 구현
- [x] **L2d** `prisma-membership-plan.repository.spec` 단위 검증 (5 it 신규)
- [x] **L2e** `credit.usecase.getPointBalance` 진입에 lazy 훅 + `MembershipPlanPort` Optional DI
- [x] **L2f** `credit.usecase.spec` lazy 호출 검증 (3 it 신규)

#### HIGH-1 案 A (Author.plan ↔ tier 동기)

- [x] **H1a** 案 결정 = 案 A 권고 (사용자 확정)
- [x] **H2a** `prisma-membership-plan.repository.changeTier` 트랜잭션에 `Author.plan` 동기 추가
- [x] **H2b** `prisma-membership-plan.repository.spec` changeTier 양측 동기 단위 검증 (4 it 신규)
- [x] **H2c** ADR-014 신설 — HIGH-1 案 A + CRITICAL-1 案 B
- [x] **H2d** `membership-plan.port.ts` + `schema.prisma`(`Author.plan` 주석) 案 A 박제

#### HIGH-3 — getGiftRanking/getLogs CreditLedger 위임

- [x] **H3a** `prisma-credit-ledger.repository.getGiftRanking` 신설 (CreditLedger groupBy)
- [x] **H3b** `CreditLedgerPort.getGiftRanking` 시그니처 추가
- [x] **H3c** `credit.usecase.getGiftRanking`/`getLogs` ledger 위임
- [x] **H3d** spec 갱신 (credit.usecase.spec + prisma-credit-ledger.repository.spec)

#### 통합 spec

- [x] **I1a** 통합 spec 파일 신설 (`credit-rollover-source-ledger-integration.spec.ts`)
- [x] **I1b** CRITICAL-1 lazy 안전망 통합 케이스
- [x] **I1c** HIGH-1 changeTier 동기 + HIGH-3 신 선물 ranking 통합 케이스

#### sensor / 마무리

- [x] **S1a** sensor 등록 권고 핸드오프 박제 (harness 영역 — DEV_REPORT 명시)
- [x] **F1a** `npm run build` 무에러
- [x] **F1b** `npm test` 전체 PASS + 커버리지 ≥60%
- [x] **F1c** `shared-contracts.md` §30 갱신 (변경 이력 + 신 인터페이스)
- [x] **F1d** `TECH_STATUS.md` + ADR-014 + `docs/api-contract.md`(GET /credits/logs) + `docs/data-model.md`(Author.plan 案 A) 갱신
- [x] **F1e** sensor 일괄 실행 (silent 확인)

---

## 1. 결함 3건 종결 증명

### CRITICAL-1 (이월 금지 lazy 안전망 부재)

- `grep -rn "checkAndResetExpiredPool" src` ≥1건 (port + repository + usecase + spec)
- `getPointBalance` 진입에 호출 (membershipRepo가 optional 주입 시)
- 통합 spec I1b PASS — cron 미실행 상태에서 lazy 자동 보정 박제

### HIGH-1 (Author.plan ↔ MembershipPlan.tier 이중출처)

- `changeTier` 트랜잭션 본문에 `tx.author.update({ data: { plan: tier, planExpireAt: ... } })` 추가
- 통합 spec I1c PASS — `changeTier` 호출 시 양측 동기
- ADR-014 案 A 박제

### HIGH-3 (getGiftRanking/getLogs CreditLog 의존)

- `grep -rn "creditRepo\.getGiftRanking\|creditRepo\.findLogsByAuthorId" src/application` **0건**
- `ledger.getGiftRanking` 호출처 ≥1건
- 통합 spec I1c PASS — CC-2b 신 선물(`source='gift'`)이 ranking에 집계

---

## 2. CC-3 미해소 잔존 (범위 외 — 명시)

- HIGH-1 案 B 이행 (`Author.plan` 읽기 13건 → `MembershipPlanPort.getPlan`) — CC-5 또는 후속
- `MembershipPlanPort.getPlan` HTTP 노출 (`GET /membership`) — CC-5 PAY-P1-4
- 구 `CreditLog` 테이블 자체 폐기 — CC-4 후속
- `Author.credits` DROP / 구 `CreditUseCase.grant/deduct/gift` 제거 — CC-4 후속
- V Phase 마이그레이션 dev/prod apply — CC-4
- PAY-P1-4 Polar 구독 연동 — CC-5
- sensor 7종 hook 등록 — harness agent
