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

- **P7~P9 (dev/prod 마이그레이션)**: 본 작업 범위 밖. Azure firewall 개방 + 사용자 키워드
  게이트 필요한 별도 단계. dev/prod DB 미접촉 — 추정 0건.
- **CC-1 (S0/T1~T8/통합 spec)**: 별도 sprint. PAY-S1 로컬 동기화 완료가 그 DB 전제.

## 4. 코드 변경 점검

- 순수 DB 동기화 — 애플리케이션 코드(`src/`) 변경 **0건**.
- `.gitignore` 1줄 보강 (`backup_*.sql` / `*.dump`) — DB 백업 덤프 커밋 방지 안전 조치.
  코드 동작 무관. 사유: P2 백업 파일이 git 추적 대상이라 작가 본문 누출 차단 필요.

## 5. 변경 이력

- 2026-05-19: PAY-S1 P1~P6 (로컬 localhost:5432 한정) 실행 완료. 미적용 5건 `migrate deploy`
  순차 적용 + 데이터 마이그레이션 검증 PASS(§3-2-A 공식) + 부팅 smoke PASS.
