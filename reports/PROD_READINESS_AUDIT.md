# PROD_READINESS_AUDIT — 5 sprint(PAY-S1 + CC-1/2a/2b/3) prod 배포 전 인프라 점검

> 작성: 2026-05-21 (grimoire-infrastructure agent)
> 대상: V Phase 마이그레이션(`20260517_credit_overhaul_i_phase`) prod 적용 + server `9d0d2b7..34de086` (18 commits) prod 배포
> 본 보고서는 **사전 점검만** — prod 마이그레이션/배포 영역 변경 0건. 사용자 명시 후 적용.

---

## 0. 박제 영역 정합 (raw 박제)

| 영역 | 값 |
|---|---|
| server develop HEAD (원격 정합) | `34de086` (CC-3 merge) |
| server origin/main HEAD | `34e37e08` (USER-SOFT-DELETE merge) |
| prod container active revision | `grimoire-server-prod--0000101` (Healthy, ScaledToZero, 5/15 11:32 UTC) |
| prod container image | `grimoireacr.azurecr.io/grimoire-server:prod-34e37e083a918cfb88924d8db691d13d3b0f90a4` |
| dev container active revision | `grimoire-server-dev--0000160` (Healthy, ScaledToZero, 5/15 11:11 UTC) |
| dev container image | `grimoireacr.azurecr.io/grimoire-server:dev-85393b6aa8fb600393a680f3e196af4a28fd8d64` |
| develop ↔ prod image 격차 | **18 commits** (`34e37e08..34de086`) — 5 sprint 전부 미배포 |
| develop ↔ dev image 격차 | **18 commits** (`85393b6a..34de086`) — 5 sprint 전부 미배포 |
| prod DB 마지막 적용 마이그레이션 | `20260515_user_soft_delete_policy` (2026-05-15 11:28) |
| prod DB 미적용 마이그레이션 | **1건** — `20260517_credit_overhaul_i_phase` (175 줄, 5 ALTER + 9 CREATE + 8 DML) |
| prod RUN_MIGRATION env | `true` ★ — **prod 배포 시 entrypoint가 자동 `prisma migrate deploy`** |
| dev RUN_MIGRATION env | `true` |

---

## 1. 8 항목 점검 결과 매트릭스

| # | 점검 항목 | 결과 (raw 박제) | 위험도 |
|---|---|---|---|
| **A.1** | prod container 배포 SHA | `prod-34e37e08` (main HEAD 정합, 5/15 11:32 UTC 빌드) | LOW |
| **A.2** | develop HEAD vs prod 격차 | 18 commits / 5 sprint 전부 미배포 (PAY-S1 + CC-1/2a/2b/3) | MED — 마이그레이션 적용 시 코드 동시 배포 필요 |
| **A.3** | dev container 배포 SHA | `dev-85393b6a` — dev DB는 v6 적용됐으나 컨테이너는 구 코드 (29 model, 신 컬럼 무인지). Prisma 영역 forward 호환 — neutral 영역 작동 정합 | MED — dev 영역 코드 영역 미배포 영역 = 5 sprint 신 로직 영역 검증 영역 0건 (cron 등 미가동) |
| **B.4** | prod `prisma migrate status` | 미적용 1건: `20260517_credit_overhaul_i_phase` (예상 정합) | LOW |
| **B.5** | prod 데이터 분포 | authors=13 / sum(credits)=105 / credits>0 작가=11 (free 8/15pt + pro 1/10pt + premium 2/15pt) / plan 영역 free=9, pro=1, premium=3 (전부 폴백 영역 무발동) / analysis_reports credits_charged=4 1건 (`×610` dead code 영역 정합) / credit_logs=8 / payments=4 / refund_logs=0 / **최근 7일 payments=0건** | LOW — 볼륨 매우 작음, 마이그레이션 추정 < 1초 |
| **C.6** | 신규 env / secretRef 의존 | 5 sprint 신규 운영 env 영역 추가 0건. 유일 추가 영역 = `MONTHLY_POOL_RESET_DISABLED` (테스트 게이트, prod 영역 무영향). 기존 env 영역 21개 (DATABASE_URL/JWT_SECRET/CORS_ORIGIN/RUN_MIGRATION/POLAR_*/AZURE_STORAGE_*/GOOGLE_*/DT/APP_ENV/RECAPTCHA/ANTHROPIC/OPENAI) 정합 | LOW |
| **D.7** | Polar webhook + 결제 흐름 (다운타임) | 최근 7일 payments=0건 → webhook 트래픽 0 추정 영역. 만약 마이그레이션 도중 webhook 도달 영역 = 구 코드 영역 `payment.usecase.processWebhook` 영역 호출 → 신 컬럼 영역 무관, 구 `credits` 영역 read/write — **마이그레이션 후 신 ledger 영역 미박제 영역 누락 발생 위험** (단, 트래픽 0 가정 하 0건). webhook 엔드포인트 영역 시그니처 영역 변경 0건 (`POST /webhooks/polar` 정합) | LOW (트래픽 0 가정 영역) → MED (활성 트래픽 영역 시) |
| **E.8** | 마이그레이션 안전성 종합 | [A] 5 ALTER + 9 CREATE — DROP 0건, 신 컬럼 전부 `DEFAULT 0` 또는 nullable → 구 코드 영역 무영향. [B-a] credits×1000: WHERE credits>0, 11 row 영향, 무손실. [B-b] credit_ledgers 11 row (credits>0 작가). [B-c] membership_plans 13 row (전 작가, plan 매핑 영역 free/pro/premium 100% 정합 영역 폴백 0건). [B-c-2] credit_ledgers subscription row 4건 (pro 1 + premium 3). [B-c-3] points_subscription 4 row 업데이트. [B-d] credits_charged=4 1건 → 2440 정정. `×610` dead code 영역 정합 (값 영역 4 외 0건). 마이그레이션 후 expected: SUM(points_charged)=105000 / credit_ledgers=15 (charged 11 + subscription 4) / membership_plans=13. | LOW — 백업(pg_dump) 보유 시 안전 |

---

## 2. 신구 schema 정합 영역 박제

| 영역 | prod (34e37e08) | develop (34de086) | 정합 영역 |
|---|---|---|---|
| Prisma model 카운트 | 29 | 31 (+CreditLedger, +MembershipPlan) | 신 모델 영역 구 코드 영역 참조 0건 → 무영향 |
| Author 컬럼 추가 | — | +pointsFree, +pointsSubscription, +pointsGift, +pointsCharged, +deficitPoints (전부 `DEFAULT 0`) | 구 코드 영역 PrismaClient 영역 신 컬럼 영역 무인지 — SELECT 영역 무관 |
| ChatMessage 컬럼 추가 | — | +charge_tier, +charged_points, +input_tokens, +output_tokens, +model (전부 nullable) | 구 코드 영역 무영향 |
| AnalysisReport.credits_charged default | 4 | 2440 | 신 INSERT 영역만 영향 — 구 코드 영역 일관성 영역 보존 (구 코드 영역 4 명시 INSERT) |
| FK 영역 | — | +credit_ledgers.author_id (Restrict) / +membership_plans.author_id (Restrict) | 신 테이블 영역 — 구 코드 영역 무관 |
| 신 cron | — | `reset-monthly-pool.job.ts` (0 0 4 * * *, 매일 04:00 KST) | 구 코드 영역 미가동 — 코드 배포 후만 진입 |

---

## 3. 마이그레이션-코드 배포 순서 권고

### 옵션 A (권장 — 1 단계 묶음 영역)

**`make deploy-prod` 1 명령 영역 마이그레이션 + 코드 배포 동시 진행** ★

이유 정합:
1. `RUN_MIGRATION=true` 영역 박제됨 → docker-entrypoint.sh 영역 컨테이너 기동 시 `prisma migrate deploy` 자동 실행 영역
2. 신 컬럼/모델 영역 영역 구 코드 영역 무영향 → 마이그레이션 단독 영역도 작동 정합. 즉 신 코드 영역 동시 배포 영역 안전
3. 트래픽 영역 0 추정 영역 (최근 7일 payments 0건) → 다운타임 영역 무관
4. cron `reset-monthly-pool` 영역 매일 04:00 KST — **배포 직후 04:00 이전 영역** 배포 권장 (첫 cron 영역 신 코드 영역 진입 정합)

### 옵션 B (보수 — 2 단계 영역, **불권장**)

마이그레이션 단독 → 24h 안정성 박제 → 코드 배포

비권장 사유: `RUN_MIGRATION=true` 영역 영역 + entrypoint 영역 마이그레이션 영역 컨테이너 기동 결합 영역 → 마이그레이션 단독 영역 진행 영역 = SSH 영역 또는 임시 firewall + 로컬 `prisma migrate deploy` 영역 = **본 에이전트 영역 추가 작업** 영역. 옵션 A 영역 정합 영역 영역 시간 영역 단축.

### 권장 순서 (옵션 A 영역 정합 영역 박제)

1. **사전 영역 백업**: `pg_dump $PROD_URL > backup_pre_credit_overhaul_$(date +%Y%m%d).sql` (firewall 임시 추가 + 정리 영역)
2. **사용자 명시 영역 확인**: `prod main 머지 + 배포 진행` 또는 `크레딧개편 prod migration + 배포 진행`
3. **prod main 머지 영역**: develop `34de086` → main 영역 (server agent 영역 또는 사용자 명시 영역)
4. **`make deploy-prod` 영역 1 묶음 영역**:
   - ACR 영역 image push 영역
   - `az containerapp update --image grimoire-server-prod:prod-34de086...` 영역
   - 컨테이너 기동 영역 `prisma migrate deploy` 자동 실행 (RUN_MIGRATION=true)
   - 3-stage polling (10s/30s/60s)
   - sensor-deploy-health.sh + sensor-azure-env-secret.sh
5. **사후 영역 정합성 영역 검증 SQL** (firewall 임시 + cleanup):
   - `SELECT SUM(points_charged) FROM authors;` → **expected 105000** (현재 sum credits 105 × 1000)
   - `SELECT COUNT(*) FROM credit_ledgers;` → **expected 15** (charged 11 + subscription 4)
   - `SELECT COUNT(*) FROM membership_plans;` → **expected 13** (전 작가)
   - `SELECT tier, COUNT(*) FROM membership_plans GROUP BY tier;` → free=9, pro=1, premium=3
6. **3개 자릿수 영역 불일치 영역 검출 시**: `make rollback-prod` 영역 또는 `psql < backup_pre_credit_overhaul_...sql` 영역

---

## 4. 최종 판정

### **INFRA-CONDITIONAL** ★

조건:
1. ★ **prod main 머지 영역 사용자 명시 영역 필수** — develop `34de086` → main 영역 진행 영역
2. ★ **사전 백업 영역 필수** — `pg_dump` 영역 영역 시점 박제 (롤백 안전망)
3. ★ **사용자 명시 영역 키워드 정합** — `prod main 머지 + 배포 진행` 또는 `크레딧개편 prod migration + 배포 진행` (per-target 명시)
4. **사후 정합성 SQL 영역 3건 정합 확인 후만 종료** (105000 / 15 / 13)
5. **cron `reset-monthly-pool` 영역 첫 발동 영역 04:00 KST 영역 logs 영역 박제 영역 확인** (배포 후 24h 이내)

### 사유

- ✅ 마이그레이션 영역 자체 영역 안전 (DROP 0건 / 신 컬럼 영역 DEFAULT / 11 row 영향 / 백워드 호환)
- ✅ 트래픽 영역 0 (최근 7일 payments 0건) → 다운타임 영역 무관
- ✅ env 영역 추가 0건 / cron 영역 신설 1건 (단순 영역)
- ✅ 신구 코드 영역 정합 가능 (Prisma forward 호환 / `credits` 컬럼 영역 deprecated 유지)
- ⚠️ **dev container 영역 5 sprint 미배포** — dev 영역 운영 영역 검증 영역 0건 영역 (사용자 명시 영역 dev DB 적용 영역만 박제 영역, dev container 영역 배포 영역 미진행 영역). prod 영역 진입 영역 전 영역 dev container 영역 5 sprint 영역 배포 영역 + cron 영역 1회 영역 영역 발동 영역 박제 영역 = 옵션 영역 (사용자 영역 결정 영역)
- ⚠️ webhook 영역 활성 트래픽 영역 발생 영역 시 영역 = 마이그레이션 진행 중 영역 영역 회계 누락 영역 위험 영역 (구 코드 영역 신 ledger 미박제). 트래픽 0 가정 영역 영역 = MED
- ✅ 백업 영역 + 롤백 영역 가능 영역

---

## 5. 박제 영역 / 작업 영역 영역

### 본 보고서 영역 작업 박제

- prod DB 영역 SELECT 영역만 영역 (변경 0건 영역) — firewall rule 영역 임시 추가 → measure → cleanup 1 묶음 영역 정합 (`tmp-readiness-20260521T060800Z` 영역)
- 자격증명 영역 mask 영역 (host + DB명만 박제 영역) — 비밀번호 영역 평문 박제 0건 영역
- /tmp 영역 파일 영역 즉시 삭제 영역 (prod_db_url.txt + prod_rule.env 영역)
- firewall rule 영역 영역 cleanup 영역 1분 이내 영역 정합 (orphan rule 0건 영역)

### 영역 다음 단계 영역 사용자 명시 영역 영역 필요

1. `prod main 머지 진행` — server agent 또는 사용자 영역
2. `크레딧개편 prod migration + 배포 진행` 또는 `prod main 머지 + 배포 진행` (per-target)
3. pg_dump 백업 영역 영역 진행 영역 확인

### 영역 본 에이전트 영역 영역 옵션 영역 영역 (사용자 결정 영역)

- dev container 영역 5 sprint 영역 영역 배포 영역 영역 영역 사전 영역 영역 영역 (옵션) — 운영 영역 영역 검증 영역 1 단계 영역 추가 영역

---

## 6. 정본 영역 cross-reference

- migration.sql: `grimoire-server/prisma/migrations/20260517_credit_overhaul_i_phase/migration.sql`
- 정본 영역: `grimoire-server/research/CREDIT_PRICING_OVERHAUL_PLAN.md` §8 (v6)
- 영역 정본 영역: `.claude/state/sprint-credit-overhaul-s-phase-draft.md` §6 매트릭스 + §7 단계 3·4
- 배포 정본 영역: `grimoire-server/docs/DEPLOY.md` §1
- 인프라 영역: `grimoire-server/INFRASTRUCTURE.md`
- 보안 영역: `grimoire-server/SECURITY.md` §3 결제 원자성 + §4 배포 전 체크리스트
- 사용자 합의 영역: `memory/feedback_manual_deploy_primary.md` (4/18 수동 배포 1차)

---

## 변경 영역 이력 영역

- 2026-05-21 INFRA: 신설 — V Phase 마이그레이션 영역 prod 영역 진입 영역 직전 영역 점검 영역 (사용자 명시 영역 "서버 포함한 인프라쪽 장애 발생할 여지도 있나 확인"). prod DB SELECT 영역 측정 영역 8건 + firewall 영역 1 묶음 영역 정합 + 사후 정합성 SQL 영역 expected 영역 박제 영역.
