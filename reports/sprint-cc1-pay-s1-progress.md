# Sprint PAY-S1 + CC-1 — 진행 박제

> 생성: 2026-05-19 / grimoire-server (Generator) / **PAY-S1 P1~P6 (로컬 DB 한정) 실행 결과**
> 계획 정본: `.claude/state/sprint-cc1-pay-s1-plan-draft.md` §1
> 진단 근거: `reports/PAYMENT_PIPELINE_DIAGNOSIS.md` §5 + `reports/CREDIT_CORE_DIAGNOSIS.md` §3-2
> 범위: PAY-S1 P1~P6 (로컬 localhost:5432 한정). **P7~P9(dev/prod) 범위 외 — 미착수**.

---

## 1. PAY-S1 — 로컬 DB 마이그레이션 동기화 (P1~P6)

### P1 — `prisma migrate status` 재실측 ✅ PASS

실측 (2026-05-19, `grimoire-server/` localhost:5432 grimoire):

```
33 migrations found in prisma/migrations
Following migrations have not yet been applied:
20260505020000_add_webhook_retry_queue
20260510_pay_p2_5_audit_retention_policy
20260510_pay_p3_e_fk_cascade_policy
20260515_user_soft_delete_policy
20260517_credit_overhaul_i_phase
```

→ 미적용 5건 = 진단(2026-05-18)과 **완전 일치**. 진단 후 변동 0건. (종료코드 1은 prisma가
미적용분 존재 시 반환하는 정상 동작 — 에러 아님.)

### P2 — 로컬 DB 백업 ✅ PASS

`pg_dump -h localhost -p 5432 -U grimoireadmin -d grimoire -f backup_pre_pays1_20260519.sql`

- 파일: `grimoire-server/backup_pre_pays1_20260519.sql` — **1,326,125 bytes** (>0 확인)
- 유효성: PostgreSQL plain SQL dump (server 16.13), `CREATE TABLE` 29개 포함 — 스키마+데이터 정합
- ⚠️ 백업 SQL이 git 추적 대상이었음 → `.gitignore`에 `backup_*.sql` / `*.dump` 추가
  (작가 본문 포함 가능 — 커밋 절대 금지 안전 조치. `git check-ignore`로 무시 확정.)

### P3 — 마이그레이션 적용 ✅ PASS

**`npx prisma migrate deploy` 사용** (작업 지시 P3 ⚠️ 준수 — `migrate dev`의 DB 리셋·
인터랙티브 프롬프트 회피. `deploy`는 미적용분만 순차 적용).

```
Applying migration `20260505020000_add_webhook_retry_queue`
Applying migration `20260510_pay_p2_5_audit_retention_policy`
Applying migration `20260510_pay_p3_e_fk_cascade_policy`
Applying migration `20260515_user_soft_delete_policy`
Applying migration `20260517_credit_overhaul_i_phase`
All migrations have been successfully applied.
=== 종료코드: 0 ===
```

→ 5건 전부 순차 적용. **DB 리셋·인터랙티브 프롬프트 0건**. 종료코드 0.

### P4 — `prisma migrate status` 재확인 ✅ PASS

```
33 migrations found in prisma/migrations
Database schema is up to date!
=== 종료코드: 0 ===
```

→ 미적용 **0건**, "up to date".

### P5 — `credit_overhaul_i_phase` 데이터 마이그레이션 검증 ✅ PASS

**마이그레이션 전 스냅샷 (P3 실행 전 실측)**: authors 11 / SUM(credits)=110 /
credits>0 작가=11 / plan 분포 free=11(pro/premium 0) / analysis_reports 0 row.

`migration.sql:16-17` 검증 SQL + CREDIT_CORE_DIAGNOSIS §3-2-A 공식 적용:

| 검증 | 실측값 | 기대값 | 판정 |
|---|---|---|---|
| 검증1: `SUM(points_charged)` | 110,000 | `SUM(credits)*1000` = 110,000 | ✅ 정합 |
| 검증2: `credit_ledgers` row | 11 | (credits>0 작가 11) + (pro/premium 0) = 11 | ✅ §3-2-A 정합 |
| 검증3: `SUM(points_subscription)` | 0 | pro/premium 0명 → 0 | ✅ 정합 |
| 검증4: ledger source 분포 | charged/earn 11건 | (b) INSERT만 ((c-2) 0건) | ✅ 정합 |

⚠️ §3-2-A 경고대로 `credit_ledgers` row를 단순 "=10"으로 검증했다면 11≠10으로
**정상인데 롤백을 유발**할 뻔함. 공식 `(credits>0 작가)+(pro/premium 작가)`로 정확히 통과.

**CC-4 후속 입력값 — 분포 측정 (마이그레이션 후 로컬 실측)**:

```
SELECT plan, COUNT(*) FROM authors GROUP BY plan;
  → free=11  (pro/premium 0건)

SELECT DISTINCT credits_charged, COUNT(*) FROM analysis_reports GROUP BY credits_charged;
  → 0 row  (analysis_reports 자체 0건)
  → §3-2-B `×610` 휴리스틱은 로컬 DB에서 영향 0건 (dead code 여부는 dev 측정으로 확정 — 범위 외)

membership_plans tier 분포(참고): free=11, sum_pool=0  ((c) INSERT 전 작가 1건씩 정상)
```

### P6 — 서버 부팅 smoke 테스트 ✅ PASS

`npm run start:dev` 백그라운드 부팅:

- 부팅: **"Nest application successfully started"** — 포트 3000
- 신규 테이블(`webhook_retry_queues`/`credit_ledgers`/`membership_plans`) 접근 런타임 에러 **0건**
  (grep: `does not exist` / `P2021` / `relation not exist` / `PrismaClientKnownRequestError` 전부 0건)
- ERROR/Exception 로그 **0건**
- `curl http://localhost:3000/api/health` → **HTTP 200**, `{"status":"ok","timestamp":"2026-05-19T13:09:13.793Z"}`

**신규 5개 마이그레이션 스키마 반영 검증** (psql 직접 쿼리):
- `webhook_retry_queues` (PAY-P2-2): 테이블 존재, 0 row
- `credit_ledgers` (크레딧개편): 11 row
- `membership_plans` (크레딧개편): 11 row
- `webhook_events.masked_at` / `retention_tier` (PAY-P2-5): 컬럼 존재
- `authors.deleted_at` (USER-SOFT-DELETE): 컬럼 존재

확인 후 서버 종료 — `curl` HTTP=000 (연결 거부)로 종료 확인.

---

## 2. PAY-S1 자율분 종합 게이트

- **P1~P5 [MUST] 5건 — 전부 PASS**.
- **P6 [SHOULD] — PASS** (부팅 에러 0건 + health 200).
- ⚠️ CC-1 통합 spec(C8/C9)은 로컬 DB에 `credit_overhaul_i_phase` 적용된 신 스키마 전제
  → **P3~P5 완료 = CC-1 진입의 DB 전제 충족**.

## 3. 범위 외 (미착수 — 명시)

- ~~**P7~P9 (dev/prod 마이그레이션)**~~ → **P7 (dev) 2026-05-21 완료** (§6 본문). **P8/P9 (prod)** 별도 키워드 게이트 (`크레딧개편 prod migration 진행`) 유지.
- **CC-1 (S0/T1~T8/통합 spec)**: 별도 sprint. PAY-S1 로컬 동기화 완료가 그 DB 전제.

## 4. 코드 변경 점검

- 순수 DB 동기화 — 애플리케이션 코드(`src/`) 변경 **0건**.
- `.gitignore` 1줄 보강 (`backup_*.sql` / `*.dump`) — DB 백업 덤프 커밋 방지 안전 조치.
  코드 동작 무관. 사유: P2 백업 파일이 git 추적 대상이라 작가 본문 누출 차단 필요.

## 5. 변경 이력

- 2026-05-19: PAY-S1 P1~P6 (로컬 localhost:5432 한정) 실행 완료. 미적용 5건 `migrate deploy`
  순차 적용 + 데이터 마이그레이션 검증 PASS(§3-2-A 공식) + 부팅 smoke PASS.
- 2026-05-21: **PAY-S1 P7 + CC-4 V Phase dev apply** (§6 본문). dev DB(`grimoire-db-dev.postgres.database.azure.com`)에 `20260517_credit_overhaul_i_phase` 1건 `migrate deploy` 적용 + 검증 SQL 4건 PASS + smoke 200. firewall rule `tmp-claude-20260521T053404Z` 추가→정리 1묶음.

---

## 6. PAY-S1 P7 + CC-4 V Phase — dev DB 마이그레이션 적용 (2026-05-21)

> 사용자 명시 (5/20): "너 애저 권한 다 있잖아" → dev 마이그레이션 자율 진행.
> prod 영역(P8/P9)은 별도 키워드 게이트 (`크레딧개편 prod migration 진행`) 유지.
> 인프라 agent §2 `dev migration apply` 영역 + grimoire-server CLAUDE.md MIGRATION.md 정합.

### P7-1 — 사전 환경 박제 ✅

- dev DB host: `grimoire-db-dev.postgres.database.azure.com:5432` / DB `grimoire` (containerapp secret `database-url` 추출)
- 본인 IP: `221.150.30.109`
- firewall rule 추가: `tmp-claude-20260521T053404Z` (start=end=본인 IP)
- 작업 종료 직후 정리 (1묶음) — 잔존 `tmp-*` rule 0건 확인

### P7-2 — 사전 스냅샷 ✅

| 메트릭 | 값 |
|---|---|
| `authors` 행 수 | 12 |
| `SUM(authors.credits)` | 100 |
| `credits > 0` 작가 수 | 10 |
| `plan` 분포 | free 8 / pro 1 / premium 3 |
| `analysis_reports.credits_charged` 분포 | `3` 값 2건만 (4 또는 기타 0건) |

### P7-3 — `prisma migrate status` 사전 ✅

```
33 migrations found in prisma/migrations
Following migration have not yet been applied:
20260517_credit_overhaul_i_phase
```

- 미적용 **1건**: `20260517_credit_overhaul_i_phase` (V Phase / I Phase 데이터 마이그레이션)

### P7-4 — 백업 ✅

- `pg_dump` → `/tmp/grimoire_backup/backup_pre_devmigrate_20260520.sql`
- 크기: **14,640,426 byte** (>0)
- 헤더: `PostgreSQL database dump` / `Dumped from database version 16.13` 정합
- 롤백 명령(필요 시): `psql "$DATABASE_URL" -f /tmp/grimoire_backup/backup_pre_devmigrate_20260520.sql`

### P7-5 — `prisma migrate deploy` ✅

```
Applying migration `20260517_credit_overhaul_i_phase`

The following migration(s) have been applied:
  └─ 20260517_credit_overhaul_i_phase/
    └─ migration.sql

All migrations have been successfully applied.
```

- 인터랙티브 입력 / 리셋 요구 0건 (deploy 비대화식 정합).

### P7-6 — `prisma migrate status` 재확인 ✅

```
33 migrations found in prisma/migrations
Database schema is up to date!
```

- 미적용 0건.

### P7-7 — 데이터 마이그레이션 [B] 검증 SQL 4건 ✅

| ID | SQL | 결과 | 기대 | 판정 |
|---|---|---|---|---|
| V1 | `SELECT SUM(points_charged) FROM authors` | **100,000** | `SUM(credits)*1000` = 100×1000 = 100,000 | PASS |
| V2 | `SELECT COUNT(*) FROM credit_ledgers` | **14** | (credits>0 작가 10) + (pro 1 + premium 3) = 14 (정밀진단 §3-2-A 정정 공식) | PASS |
| V2 분해 | `source='charged'` 10 / `source='subscription'` 4 | 10 / 4 | 정합 | PASS |
| V3 | `SELECT plan, COUNT(*) FROM authors GROUP BY plan` | free:8 / pro:1 / premium:3 | 사전 스냅샷 정합 (변경 없음) | PASS |
| V4 | `SELECT DISTINCT credits_charged, COUNT(*) FROM analysis_reports GROUP BY credits_charged` | **1830:2** | 사전 3:2 → 마이그레이션 SQL `WHERE credits_charged = 3` 분기로 1830 환산 (CC-4 ×610 dead code 판정: **4·3 외 값 0건 — ×610 분기 실 row 변환 0건 확정**) | PASS |
| 추가 V5 | `SUM(authors.points_subscription)` / `SUM(membership_plans.pool_balance)` | **667,500** / **667,500** | 1×93,000 + 3×191,500 = 667,500 (캐시-풀 정합) | PASS |
| 추가 V6 | `COUNT(membership_plans)` / tier 분포 | 12 / free:8 + pro:1 + premium:3 | 전 작가 1건 + Author.plan == MembershipPlan.tier 1:1 정합 | PASS |

**CC-4 입력값 박제**:
- pro 1명 / premium 3명 → 구독 풀 활성 ledger 4건 (`source='subscription'` + `expires_at` 익월 1일)
- `analysis_reports.credits_charged` 실 데이터에 `4` 또는 기타 외값 0건 → ×610 분기 dead code 확정 (CC-4 코드 제거 가능).

### P7-8 — Smoke 검증 ✅

- `curl https://dev-api.grimoire-book.com/api/health` → **HTTP 200** / `{"status":"ok","timestamp":"2026-05-21T05:45:08.903Z"}` (cold start 25s — dev 일반 패턴, 마이그레이션 영향 X)
- dev container logs (`az containerapp logs show --tail 200`) — `credit_ledgers` / `membership_plans` / `webhook_retry_queues` / `relation .* does not exist` 관련 런타임 에러 **0건**
- 컨테이너 재시작 불요 (코드 push 0건 / 신 스키마는 prisma client 차기 query 시점 즉시 접근 가능).

### P7-9 — Cleanup ✅

- firewall rule `tmp-claude-20260521T053404Z` 제거 완료
- `az postgres flexible-server firewall-rule list --query "[?starts_with(name, 'tmp-')]"` → `[]` (orphan 0건)

### P7 종합 게이트

- **9 단계 전건 PASS** — 미적용 카운트 1 → 0 / 검증 SQL 6건(V1~V6) PASS / smoke 200 / firewall cleanup 정합.
- **prod 영역(P8/P9) 미진입** — 별도 키워드 게이트 (`크레딧개편 prod migration 진행`) + 24h dev 안정성 박제 후 게이트.

---

# CC-1 — 적립 비결제 연동 (규모 L)

> 생성: 2026-05-19 / grimoire-server (Generator) / **CC-1 sprint 실행 결과**
> 계획 정본: `.claude/state/sprint-cc1-pay-s1-plan-draft.md` §2
> 진단 근거: `reports/CREDIT_CORE_DIAGNOSIS.md` §1·§2-2·§5-D·§8·§10
> 브랜치: `feature/cc1-credit-earn-noncash-wiring`

## CC-1 §0. S0 — §10 미확인 해소 (착수 게이트)

### C0a — 테마 차감 구 경로 존재 여부 ✅ PASS

`grep -rn "credits|chargeTheme|deduct" src/application/theme*` + `generate-theme.usecase.ts` Read 결과:

- **구 경로 존재 확정** — `generate-theme.usecase.ts:44`:
  `await this.creditRepo.adjustCredits(authorId, -1, CreditReason.THEME_GENERATE)`
  (무료 한도 초과 시 구 `Author.credits` 1 차감)
- 실패 환불 경로 — `:56`: `await this.creditRepo.adjustCredits(authorId, 1, 'theme_generate_refund')`
  (Claude API 실패 시 유료 생성분 환불)
- **C5 분기 결정**: 테마 차감 구 경로가 **있으므로** → 신 `chargeTheme` 경로로 **교체**.
  구 `adjustCredits(-1)`/`adjustCredits(+1)` 2건 제거 + 이중 차감 방지.

### C0b — GrantPointsUseCase 5 메서드 시그니처 ✅ PASS

`grant-points.usecase.ts` Read:

| 메서드 | 시그니처 | 적립 출처/값 |
|---|---|---|
| `grantSignupBonus` | `(authorId: string): Promise<void>` | `source='free'`, 3,000pt (`SIGNUP_BONUS_POINTS`) |
| `grantFirstWorkBonus` | `(authorId: string): Promise<void>` | `source='free'`, 2,000pt (`FIRST_WORK_BONUS_POINTS`) |
| `grantCharge` | `(authorId, totalPoints, relatedId?): Promise<{settledDeficit,chargedPoints}>` | CC-2 범위 |
| `grantGift` | `(receiverId, points, relatedId?): Promise<void>` | CC-2 범위 |
| `grantManual` | `(authorId, source: CreditSource, points, adminId): Promise<void>` | 운영자 명시 출처 |

→ DI: `@Inject('CreditLedgerPort')` 단일 의존. `app.module.ts:143` provider 등록 확인.

### C0c — ChargePointsUseCase.chargeTheme + deficit 분기 ✅ PASS

`charge-points.usecase.ts` Read:

- `chargeTheme(authorId, relatedId?): Promise<void>` — `THEME_POINT_COST=590` 정액.
  사전 `getBalance().available < 590` 검증 → 부족 시 `BadRequestException` throw (deficit 불가).
- 관리자 차감 전용 메서드 **없음** — `ledger.spend()`는 잔액 부족 시 deficit 발생 모드.
  → T6(관리자 차감 deficit 불가)는 **사전 `getBalance` 잔액 검증 후 `spend`** 패턴 필요
  (`chargeAnalysis`/`chargeTheme`와 동일한 "사전검증 → spend" 패턴 차용).

### C0d — 호출처 5곳 현행 코드 ✅ PASS

| # | 호출처 | 현행 코드 | 트랜잭션 경계 |
|---|---|---|---|
| T1-a | `auth.usecase.ts:55` | `await this.creditUseCase.grant(author.id, 3, 'signup_bonus')` | 단일 (author create 후 별도 호출) |
| T1-b | `auth.usecase.ts:149` | `await this.creditUseCase.grant(author.id, 3, 'signup_bonus')` | 단일 |
| T2 | `work-management.usecase.ts:213` | `await this.creditUseCase.grant(authorId, 2, CreditReason.FIRST_WORK_BONUS)` | 단일 (멱등 가드: `!hasPublished`) |
| T5 | `admin.usecase.ts:109` | `await this.creditUseCase.grant(authorId, amount, ` + `` `admin_grant:${reason}` `` + `)` | AuditLog 박제 동반 |
| T6 | `admin.usecase.ts:128` | `await this.creditUseCase.deduct(authorId, amount, ` + `` `admin_deduct:${reason}` `` + `)` | AuditLog 박제 동반 |

→ 5곳 전부 `CreditUseCase` 구 경로(`Author.credits` Int). `creditUseCase.grant/deduct` 반환값
`{credits, log}`를 admin.usecase는 AuditLog `afterState`에 사용 → 신 경로 교체 시 잔액 재조회 필요.

### CRITICAL-2 RED 상태 확정 (착수 전 grep)

```
grep -rn "GrantPointsUseCase" src/application/{auth,work-management,admin}  → 0건
grep -rn "chargeTheme" src/ (spec 제외)                                     → 정의·주석만 (호출처 0건)
```

**S0 게이트 — C0a~C0d [MUST] 4건 PASS. CC-1 본 작업 진입 허가.**

---

## CC-1 본 작업 — 완료

### T1 — 가입 보너스 (C1a~d) ✅ PASS

- `auth.usecase.ts` — `CreditUseCase` DI 제거 → `GrantPointsUseCase` DI 추가
- `:55` (email 가입) + `:149` (Google 신규 가입) 2 호출처: 구 `creditUseCase.grant(id,3,'signup_bonus')`
  → `grantPoints.grantSignupBonus(author.id)` 교체
- `auth.usecase.spec.ts` — mock 교체 + `grantSignupBonus` 호출 검증 + Google 신규 가입 케이스 추가
- 검증: tsc PASS / `auth.usecase.spec` 17개 PASS / 구 `creditUseCase.grant` grep 0건
- 주요 변경 파일: `src/application/auth/auth.usecase.ts`, `auth.usecase.spec.ts`

### T2 — 첫 작품 보너스 (C2a~c) ✅ PASS

- `work-management.usecase.ts` — `CreditUseCase`/`CreditReason` import 제거 → `GrantPointsUseCase` DI 추가
- `:213` (`updateEpisodeStatus`, upload→public 최초 전환): 구 `grant(id,2,FIRST_WORK_BONUS)`
  → `grantPoints.grantFirstWorkBonus(authorId)` 교체. `hasPublished` 멱등 가드 보존
- `work-management.usecase.spec.ts` — mock 교체 + 첫 전환 적립 + 멱등(재전환 미적립) + 비-최초전환 미적립 케이스
- 검증: tsc PASS / `work-management.usecase.spec` 35개 PASS / 구 `creditUseCase` grep 0건
- 주요 변경 파일: `src/application/work/work-management.usecase.ts`, `work-management.usecase.spec.ts`

### T5/T6 — 관리자 지급·차감 (C3a~d) ✅ PASS

- `admin.usecase.ts` — `CreditUseCase`/`CreditLog` import 제거 → `GrantPointsUseCase` + `CreditLedgerPort` DI 추가
- T5 `grantCredits` — `grantManual(authorId, source, amount, adminId)` 교체. **출처 파라미터** 운영자 명시
  (미지정/유효하지 않으면 'charged' 폴백 — `isCreditSource` 검증). AuditLog 박제 신 원장 total 기준
- T6 `deductCredits` — `CreditLedgerPort.spend` 교체. **deficit 불가 모드** — 사전 `getBalance().available`
  검증, 부족 시 `BadRequestException`(외상 금지). spend 미호출 보장
- `admin.controller.ts` — `POST /admin/credits/grant` body `source?` 추가 (JwtAuthGuard+AdminGuard+Throttle 기존 유지)
- `admin.usecase.spec.ts` — mock 교체 + T5 출처 명시/폴백 + T6 차감/잔액부족 throw + author 미존재 케이스
- 검증: tsc PASS / `admin.usecase.spec` 29개 PASS
- 주요 변경 파일: `src/application/admin/admin.usecase.ts`, `admin.usecase.spec.ts`, `admin.controller.ts`

### T-신규 — 테마 차감 (C5a~d) ✅ PASS

- **C5a 분기 결정**: C0a 결과 — 테마 차감 구 경로 존재 → **신 경로 교체** 분기 확정
- `generate-theme.usecase.ts` — `CreditRepositoryPort`/`CreditReason` import 제거 → `ChargePointsUseCase` DI 추가
- 구 `creditRepo.adjustCredits(authorId,-1,THEME_GENERATE)` → `chargePoints.chargeTheme(authorId)` (590pt) 교체.
  `chargeTheme` 자체 잔액 검증 → 구 try-catch 래핑 제거
- 구 환불 `adjustCredits(authorId,1,'theme_generate_refund')` → `chargePoints.refundTheme(authorId)` 교체
- `ChargePointsUseCase.refundTheme` 신설 (`refundAnalysis` 동일 패턴 — 구 환불 동작 보존)
- 구 테마 차감 경로 완전 제거 — 이중 차감 0건
- `generate-theme.usecase.spec.ts` / `charge-points.usecase.spec.ts` — mock 교체 + 차감/무료범위/실패환불 케이스
- 검증: tsc PASS / theme+charge spec 32개 PASS
- 주요 변경 파일: `src/application/theme/generate-theme.usecase.ts` (+spec), `charge-points.usecase.ts` (+spec)

### C6 [SHOULD] — refundAnalysis 출처 정합 ✅ PASS (CC-1 완수, CC-2 이월 불요)

- **C6a 결정**: `chargeAnalysis` 가 `SpendResult` 반환 → `novel-analysis.usecase` 가 메모리 보유 →
  `refundAnalysis(authorId, relatedId?, spentBySource?)` 전달. **AnalysisReport 스키마 필드 추가 불요**
  (차감·환불이 동일 메서드 흐름 내 — 메모리 전달, DB 비변경 = CC-1 범위 정합)
- `charge-points.usecase.ts` — `chargeAnalysis` 반환 `void`→`SpendResult` / `refundAnalysis` 출처별 복원
  (`CREDIT_CONSUMPTION_ORDER` 순회, `spentBySource` 0 출처 skip, 미전달 시 charged 폴백)
- `novel-analysis.usecase.ts` — `spentBySource` 보유 후 실패 환불에 전달
- `charge-points.usecase.spec` / `novel-analysis.usecase.spec` — 출처별 복원/단일출처/폴백 케이스
- 검증: tsc PASS / charge+novel-analysis spec 53개 PASS

### 통합 spec 신설 (C8a~e) — CC-1 근본 해결 ✅ PASS

- `src/application/credit/credit-grant-integration.spec.ts` 신설
- 실 `GrantPointsUseCase`/`ChargePointsUseCase` 인스턴스 + 인메모리 `FakeCreditLedger`
  (`planConsumption`/`settleDeficitOnCharge` 도메인 정책 재사용 — 소진 우선순위·deficit 정확 재현)
- C8b 가입 / C8c 첫작품 / C8d 관리자 지급·차감(deficit 불가 포함) / C8e 테마 차감(+실패환불 순잔액 보존)
  — auth/work/admin/theme usecase 가 신 시스템을 **실제 호출**해 `CreditLedger` row 박힘을 검증
- **RED 재현 실증**: `auth.usecase` 의 `grantSignupBonus` 호출 라인 주석 처리 → 통합 spec T1 이
  `expect(earnRows).toHaveLength(1)` 받은값 `0` 으로 FAIL 확인 → 원복 → GREEN 복귀.
  단위 spec(mock)은 이 미연동을 못 잡음 — 통합 spec 만이 CRITICAL-2 를 잡음을 실증
- 검증: 통합 spec 9개 PASS
- 주요 변경 파일: `src/application/credit/credit-grant-integration.spec.ts` (신규)

### C9 — 마무리 ✅ PASS

- **Gate 1** `npm run build` — 종료코드 0, 무에러
- **Gate 2** `npm test` — 71 suites / **991 it 전부 PASS** (CC-1 진입 전 971 → +20). 커버리지 `All files`
  Statements **60.18%** / Lines **61.72%** — server ≥60% 게이트 충족
- **Gate 3** 문서 — `shared-contracts.md` §30 변경 이력 1줄 박제 / `TECH_STATUS.md` CC-1 완료 박제 /
  `CHANGELOG.md` [0.36.0] / `docs/api-contract.md` admin credits 갱신 + web 복사 완료

### CRITICAL-2 해소 증명

```
grep -rn "GrantPointsUseCase" src/application/{auth,work-management,admin}
  → DI import 3건 (auth/work/admin 각 1) + 내부 참조 — 미연동 0건→연동 완료

실 호출 (spec 제외):
  grantSignupBonus    auth.usecase.ts:57, :152          (2건)
  grantFirstWorkBonus work-management.usecase.ts:215     (1건)
  grantManual         admin.usecase.ts:132               (1건)
  chargeTheme         generate-theme.usecase.ts:45       (1건)
  → 적립·차감 실 호출 5건 ≥5 게이트 충족
통합 spec 9개 PASS — 호출 사슬 검증 완료
```

### CC-2 이월 항목 (범위 외 — 명시)

- **T3 충전 적립** (`payment.usecase.ts:334`) — 구 `completePaymentAtomically` 잔존. 결제 트랜잭션
  재설계 필요 (진단 §1-A) = CC-2
- **T4 선물 적립** (`credit.usecase.ts:74` `gift`) — 구 `giftTransfer` 잔존. `CreditLedgerPort.transfer`
  단일 트랜잭션 신설 필요 (§1-B) = CC-2
- **T7 환불 역적립** (`refund-payment.usecase.ts`) — 구 경로 + 이중 외상 통합 필요 (§1-C) = CC-2
- `settleDeficit` 완결 — T3 충전 연동에 흡수 (§6-2) = CC-2
- 구 `CreditUseCase.grant/deduct` 메서드 / `Author.credits` Int — CC-1 후에도 잔존
  (`gift`/`getGiftRanking`/`getLogs`/`getPointBalance` 가 아직 사용, `credit.usecase`/`credit.controller`).
  폐기는 CC-2(선물 이행) + 별도 sprint(`Author.credits` DROP — §2-3 폐기 의존 그래프)
- `getStats`/`getAllCreditLogs` 의 구 `CreditLog` 조회 — HIGH-3 `getGiftRanking`/`getLogs`
  `CreditLedger` 재작성 = CC-3 범위 (CC-1 은 적립·차감 *쓰기* 경로만 이행, *읽기* 통계는 보존)

### 변경 이력 (CC-1)

- 2026-05-19: CC-1 sprint 실행 완료. S0 게이트(C0a~d) → T1/T2/T5/T6/테마차감 5경로 신 원장 연동
  + C6 출처 정합 + 통합 spec 신설. jest 971→991 PASS, build 무에러, 커버리지 60.18%. CRITICAL-2 해소.
  브랜치 `feature/cc1-credit-earn-noncash-wiring` → develop `--no-ff` 로컬 머지 (remote push 0건).

