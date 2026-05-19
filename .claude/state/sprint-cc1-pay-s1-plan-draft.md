# 작업 계획: PAY-S1 + CC-1 sub-task 상세화 (writing-plans)

> 작성: 2026-05-19 / grimoire-planner (Initializer 패턴) / **계획 수립 전용 — 코드 변경 0건**
> 근거 정본: `reports/CREDIT_CORE_DIAGNOSIS.md` (CC-1) + `reports/PAYMENT_PIPELINE_DIAGNOSIS.md` (PAY-S1) + `.claude/state/sprint-credit-overhaul-s-phase-draft.md` (적립 로직 §8-4)
> 적용 양식: `.claude/skills/writing-plans/SKILL.md` (2~5분 sub-task / [MUST]·[SHOULD]·[NICE] / 위험도 🔴🟡🟢 / 의존 / rollback / 검증 게이트)
> 범위: **PAY-S1 + CC-1 2개 sprint만**. CC-2~5 / PAY-S2~7은 범위 외 (착수 직전 상세화 원칙).

---

## 0. 진행 순서 + 의존 개요

```
PAY-S1 (로컬 DB 동기화) ──선행 필수──> CC-1 (적립 비결제 연동)
   │                                        │
   └─ dev/prod apply = 사용자 협력           └─ S0 선행: §10 미확인 2건 Read 해소
```

- **PAY-S1이 CC-1의 DB 전제** — CC-1 통합 spec이 신 스키마(`credit_ledgers`/`membership_plans`)를 전제하므로, 로컬에 `20260517_credit_overhaul_i_phase`가 적용돼야 통합 테스트 실행 가능.
- PAY-S1 로컬 동기화 = 자율 가능 / dev·prod apply = **사용자 협력 sub-task로 분리** (Azure firewall + 키워드 게이트).
- CC-1은 §10 미확인 2건(테마 차감 구 경로 / `theme.usecase`)을 **S0 선행 sub-task에서 Read로 해소**한 뒤 본 작업 진입.

### 예상 총 시간
- PAY-S1: ~1~2h (자율분 ~30~50분 + 사용자 협력분 별도)
- CC-1: ~규모 L — 본 계획 sub-task 합산 ~6~9h (트리거 5 + 테마 차감 + 통합 spec)
- **분할 근거**: ≥30분 + 돈 직결 도메인(적립 회계) + CRITICAL-2 근본 원인(unit PASS인데 미연동)이 통합 spec 부재에서 비롯 → sub-task 단위 검증 게이트 필수.

---

## 1. PAY-S1 — 로컬 DB 마이그레이션 동기화

> 정본: PAYMENT_PIPELINE_DIAGNOSIS §5(로컬 DB stale 실측) + §6-1 PAY-S1 행.
> 실측(2026-05-18 `prisma migrate status` localhost:5432): 5건 미적용 —
> `20260505020000_add_webhook_retry_queue` / `20260510_pay_p2_5_audit_retention_policy` /
> `20260510_pay_p3_e_fk_cascade_policy` / `20260515_user_soft_delete_policy` / `20260517_credit_overhaul_i_phase`.

### 1-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| P1 | `grimoire-server/`에서 `npx prisma migrate status` 재실측 — 5건 미적용 현행 확인 (진단 후 변동 가능성 점검) | [MUST] | 🟢 | 3분 | - | 출력에 미적용 목록 표시 |
| P2 | 로컬 DB 백업 — `pg_dump grimoire > backup_pre_pays1_YYYYMMDD.sql` (localhost:5432). ⚠️ `credit_overhaul_i_phase` 데이터 마이그레이션 [B] 실행 전 스냅샷 | [MUST] | 🟢 | 4분 | P1 | 백업 파일 크기 >0, `pg_restore --list` 또는 head로 SQL 유효성 확인 |
| P3 | 로컬 마이그레이션 적용 — `npx prisma migrate dev` (5건 일괄). prisma가 `migrate dev` 시 `migrate deploy`처럼 미적용분만 순차 적용 | [MUST] | 🔴 | 5분 | P2 | 명령 종료코드 0, "5 migrations applied" 류 출력 |
| P4 | 적용 후 `npx prisma migrate status` 재실측 — "Database schema is up to date" 확인 | [MUST] | 🟢 | 2분 | P3 | 미적용 0건 |
| P5 | `credit_overhaul_i_phase` 데이터 마이그레이션 [B] 로컬 실행 결과 검증 — `migration.sql:16-17` 검증 SQL 실행: `SELECT SUM(points_charged) FROM authors` = `SUM(credits)*1000` (적용 전 스냅샷 대비) | [MUST] | 🟢 | 5분 | P4 | SUM 정합. ⚠️ `credit_ledgers` row 수는 CREDIT_CORE_DIAGNOSIS §3-2-A대로 `(credits>0 작가)+(pro/premium 작가)` — 단순 "=10" 검증 금지 |
| P6 | 로컬 서버 부팅 smoke — `npm run start:dev` 후 health curl. `webhook_retry_queues` 등 신규 테이블 접근 런타임 에러 0건 확인 | [SHOULD] | 🟡 | 5분 | P4 | `curl localhost:3000/health` 200, 부팅 로그에 테이블 부재 에러 0건 |
| P7 | dev `prisma migrate status` 실측 — Azure firewall 임시 개방 필요 → **사용자 협력** | [MUST] | 🟢 | (사용자) | P4 | dev 미적용 목록 확보 |
| P8 | dev 미적용분 `prisma migrate deploy` — **사용자 협력 + 키워드 게이트** (`크레딧개편 dev migration 진행` 류) | [MUST] | 🔴 | (사용자) | P7 | dev status "up to date" |
| P9 | prod `prisma migrate status` + `deploy` — **사용자 협력 + 키워드 게이트** (`크레딧개편 prod migration 진행`) | [MUST] | 🔴 | (사용자) | P8 | prod status "up to date" |

### 1-2. 자율 vs 사용자 협력 구분

- **자율 가능 (server agent)**: P1~P6 — 로컬 DB 한정. ~24분.
- **사용자 협력 필수**: P7~P9 — Azure DB firewall 임시 개방 + 키워드 게이트. 본 계획 범위에서는 **"사용자 협력 sub-task"로 분리 표기만** — server agent가 임의 실행 금지.
  - P7 진입 전 사용자에게 firewall 개방 요청.
  - P8/P9는 TECH_STATUS §2 명시 키워드 게이트 — 사용자 명시 키워드 없이 실행 금지.

### 1-3. rollback 단위

- P3 실패 시: `psql grimoire < backup_pre_pays1_YYYYMMDD.sql`로 P2 백업 복원. ⚠️ **수동 UPDATE 재실행 금지** (CREDIT_CORE_DIAGNOSIS §3-2-C — 데이터 마이그레이션 (a)/(c-2) 비멱등). 롤백은 백업 복원으로만.
- P8/P9 실패 시: 사용자 영역 — dev/prod 백업 복원은 infrastructure agent + 사용자 승인.

### 1-4. PAY-S1 종합 게이트

- **자율분 완료 선언**: P1~P5 [MUST] 통과 + P6 [SHOULD] (실패 시 회고만).
- **전체 완료 선언**: P7~P9 사용자 협력 [MUST] 통과까지 — dev/prod status "up to date".
- ⚠️ CC-1 통합 spec(C8/C9)은 로컬 DB에 `credit_overhaul_i_phase`가 적용된 신 스키마를 전제 → **P3~P5 완료 = CC-1 진입의 DB 전제 충족**.

---

## 2. CC-1 — 적립 비결제 연동 (규모 L)

> 정본: CREDIT_CORE_DIAGNOSIS §1 트리거 매핑(T1·T2·T5·T6·T8) + §2-2 신 시스템 호출처 + §8 Sprint 분할표 CC-1 행 + §5-D + §10 미확인.
> 핵심: `GrantPointsUseCase` 5 메서드 전부 호출처 0건(CRITICAL-2) — auth/work/admin usecase에 DI + 호출 교체. 테마 차감 `chargeTheme` 호출처 0건 연동. **통합 spec 신설**이 근본 해결.

### 2-0. S0 — 선행: §10 미확인 해소 (착수 게이트)

> CREDIT_CORE_DIAGNOSIS §10 — 추정 금지. 본 sub-task로 미확인을 Read 해소한 뒤 본 작업 진입.

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C0a | `theme.usecase` 계열 파일 Read — 테마 차감 **구 경로**(`credits` 1 차감) 존재 여부 확인. `grep -rn "credits\|chargeTheme\|deduct" src/application/theme*` | [MUST] | 🟢 | 5분 | PAY-S1 P5 | 구 경로 위치 file:line 확정 or "구 경로 0건" 명시. 결과를 C5 분기 입력으로 박제 |
| C0b | `GrantPointsUseCase` 5 메서드 시그니처 Read — `grant-points.usecase.ts` (`grantSignupBonus`/`grantFirstWorkBonus`/`grantManual`/`grantGift`/`grantCharge`) 인자·반환 확정 | [MUST] | 🟢 | 4분 | - | 5 메서드 시그니처 표 확보 (DI 교체 시 인자 정합용) |
| C0c | `ChargePointsUseCase` Read — `chargeTheme` 시그니처 + deficit 분기 동작 확인 (관리자 차감 "deficit 불가 모드" 설계 입력) | [MUST] | 🟢 | 4분 | - | `chargeTheme`/`spend` 시그니처 + deficit 분기 확정 |
| C0d | `auth.usecase.ts:55,149` / `work-management.usecase.ts:213` / `admin.usecase.ts:109,128` 호출처 5곳 Read — 구 `CreditUseCase.grant/deduct` 호출 형태 + 트랜잭션 경계 확인 | [MUST] | 🟢 | 5분 | - | 5 호출처 현행 코드 박제 (교체 diff 입력) |

**S0 게이트**: C0a~C0d [MUST] 4건 완료 = §10 미확인 해소 → CC-1 본 작업 진입 허가. 미확인 잔존 시 본 작업 착수 금지.

### 2-1. T1 — 가입 보너스 (auth.usecase)

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C1a | `AuthUseCase`에 `GrantPointsUseCase` DI 추가 — constructor 주입 + `app.module.ts` provider 정합 확인 | [MUST] | 🟡 | 5분 | C0b,C0d | `npx tsc --noEmit` PASS |
| C1b | `auth.usecase.ts:55` (email 가입) 구 `creditUseCase.grant(id,3,'signup_bonus')` → `grantPointsUseCase.grantSignupBonus(id)` 교체 | [MUST] | 🟡 | 4분 | C1a | tsc PASS + `grep -n "creditUseCase.grant" auth.usecase.ts` 해당 줄 0건 |
| C1c | `auth.usecase.ts:149` (Google 가입) 동일 교체 | [MUST] | 🟡 | 4분 | C1b | tsc PASS + grep 0건 |
| C1d | `auth.usecase.spec.ts` 갱신 — 가입 시 `grantSignupBonus` 호출 mock 검증 (구 `grant` mock 제거) | [MUST] | 🟡 | 5분 | C1c | `npm test auth.usecase.spec` PASS |

### 2-2. T2 — 첫 작품 등록 보너스 (work-management.usecase)

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C2a | `WorkManagementUseCase`에 `GrantPointsUseCase` DI 추가 + app.module provider 정합 | [MUST] | 🟡 | 5분 | C0b,C0d | tsc PASS |
| C2b | `work-management.usecase.ts:213` (`updateEpisodeStatus`, upload→public 최초 전환) 구 `grant(id,2,FIRST_WORK_BONUS)` → `grantFirstWorkBonus(id)` 교체 | [MUST] | 🟡 | 4분 | C2a | tsc PASS + grep 0건 |
| C2c | `work-management.usecase.spec.ts` 갱신 — 첫 작품 최초 public 전환 시 `grantFirstWorkBonus` 호출 검증 + 재전환 시 미호출(멱등) 검증 | [MUST] | 🟡 | 5분 | C2b | `npm test work-management.usecase.spec` PASS |

### 2-3. T5/T6 — 관리자 수동 지급·차감 (admin.usecase)

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C3a | `AdminUseCase`에 `GrantPointsUseCase` + `ChargePointsUseCase`(또는 `CreditLedgerPort`) DI 추가 + app.module 정합 | [MUST] | 🟡 | 5분 | C0b,C0c,C0d | tsc PASS |
| C3b | T5 — `admin.usecase.ts:109` (`grantCredits`) 구 `grant` → `grantManual(id, source, points, adminId)` 교체. **출처 파라미터 명시** (운영자 입력, 기본 'charged'). `AdminAuditLog` 박제 유지 | [MUST] | 🟡 | 5분 | C3a | tsc PASS + AuditLog 호출 잔존 grep 확인 |
| C3c | T6 — `admin.usecase.ts:128` (`deductCredits`) 구 `deduct` → `ChargePointsUseCase`/`CreditLedgerPort.spend` 교체. **deficit 불가 모드** — 잔액 부족 시 throw (관리자 차감은 외상 금지, §1 T6 + MEDIUM-2) | [MUST] | 🟡 | 5분 | C3b | tsc PASS. deficit 분기 미진입(throw) 경로 명시 |
| C3d | `admin.usecase.spec.ts` 갱신 — 지급 `grantManual` 호출 + 차감 잔액부족 시 throw + AuditLog 박제 검증 | [MUST] | 🟡 | 6분 | C3c | `npm test admin.usecase.spec` PASS |

### 2-4. T-신규 — 테마 차감 연동 (chargeTheme)

> CREDIT_CORE_DIAGNOSIS §2-2 신규 발견 — `ChargePointsUseCase.chargeTheme` 호출처 0건. §10 미확인(구 경로)은 C0a에서 선행 해소.

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C5a | C0a 결과 분기 결정 — 테마 차감 구 경로(`credits` 1 차감)가 **있으면** 신 경로 교체, **없으면** 신규 `chargeTheme` 연결. 분기 결정을 PLANNER 핸드오프에 박제 | [MUST] | 🟢 | 3분 | C0a | 분기 결정 1줄 명문화 |
| C5b | 테마 생성 usecase에 `ChargePointsUseCase` DI 추가 + `chargeTheme` 호출 연결 (디노미 후 `THEME_POINT_COST=590` 정액, S Phase draft §8-4) | [MUST] | 🟡 | 6분 | C5a,C0c | tsc PASS + `grep -rn chargeTheme src/application` 호출처 ≥1건 |
| C5c | 구 테마 차감 경로 제거 (C0a에서 발견된 경우) — 구 `credits` 차감 코드 제거, 이중 차감 방지 | [MUST] | 🟡 | 4분 | C5b | tsc PASS + 구 경로 grep 0건 |
| C5d | 테마 생성 usecase spec 갱신 — 일일 무료 초과 시 `chargeTheme` 호출 + 무료 범위 내 미차감 검증 | [MUST] | 🟡 | 6분 | C5c | `npm test` 해당 spec PASS |

### 2-5. T8 / 5-D — refundAnalysis 출처 오귀속 정합 (MEDIUM)

> CREDIT_CORE_DIAGNOSIS §5-D — `refundAnalysis`가 전액 `source='charged'`로 복원 → 무료적립/구독풀 차감분이 charged로 둔갑(CAC/COGS 왜곡). `spend`가 `spentBySource` 반환하므로 출처별 복원.

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C6a | `chargeAnalysis` 차감 시 `SpendResult.spentBySource` 저장 위치 결정 — `AnalysisReport` 필드 추가 vs `CreditLedger` 메타 (C0c Read 결과 기반). 결정 1줄 박제 | [MUST] | 🟢 | 4분 | C0c | 저장 위치 결정 명문화 |
| C6b | `charge-points.usecase.ts:155` `refundAnalysis` — 전액 `charged` 복원 → `spentBySource` 기반 출처별 복원으로 수정 | [SHOULD] | 🟡 | 6분 | C6a | tsc PASS |
| C6c | `charge-points.usecase.spec.ts` 갱신 — 무료적립 차감분 환불 시 `source='free'`로 복원 검증 | [SHOULD] | 🟡 | 5분 | C6b | `npm test charge-points.usecase.spec` PASS |

> C6은 [SHOULD] — CC-1 핵심(CRITICAL-2 적립 연동)이 아닌 회계 정확성 보강. 실패 시 회고 후 CC-2 흡수 가능(§5-D는 CC-1/CC-2 양쪽 후보).

### 2-6. 통합 spec 신설 (CC-1 근본 해결)

> CREDIT_CORE_DIAGNOSIS §8 CC-1 행 — CRITICAL-2가 "unit PASS인데 미연동"으로 가려진 근본 원인. auth/work/admin usecase가 `GrantPointsUseCase`를 **실제 호출**하는지 검증하는 통합 테스트.

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C8a | 통합 spec 파일 신설 — `application/credit/credit-grant-integration.spec.ts` 류. DI 컨테이너 실제 wiring 기반(mock 최소화), `GrantPointsUseCase` 실 인스턴스 주입 | [MUST] | 🟡 | 8분 | C1d,C2c,C3d | 파일 생성 + tsc PASS |
| C8b | 가입 통합 케이스 — `AuthUseCase` 실행 → `CreditLedger`에 `source='free'` 3,000pt earn row 박제 검증 (`grantSignupBonus` 미연동이면 FAIL) | [MUST] | 🟡 | 6분 | C8a | `npm test` 해당 it PASS, 미연동 시 RED 재현 확인 |
| C8c | 첫 작품 통합 케이스 — `WorkManagementUseCase` public 전환 → `CreditLedger` `free` 2,000pt earn 검증 | [MUST] | 🟡 | 5분 | C8a | 해당 it PASS |
| C8d | 관리자 지급·차감 통합 케이스 — `AdminUseCase` 지급 → ledger earn / 차감 → ledger spend, 잔액부족 throw 검증 | [MUST] | 🟡 | 6분 | C8a | 해당 it PASS |
| C8e | 테마 차감 통합 케이스 — 테마 생성 usecase 일일무료 초과 → `chargeTheme` ledger spend(590pt) 검증 | [MUST] | 🟡 | 5분 | C8a,C5d | 해당 it PASS |

### 2-7. CC-1 마무리 — 빌드·문서·sensor

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C9a | 전체 빌드 — `npm run build` 무에러 | [MUST] | 🟢 | 3분 | C8e | 종료코드 0 |
| C9b | 전체 테스트 — `npm test` 통과, server 커버리지 ≥60% 유지 | [MUST] | 🟢 | 5분 | C9a | jest 전체 PASS, 커버리지 게이트 통과 |
| C9c | `shared-contracts.md` §30 CreditOverhaul — 적립 연동 완료 상태 + 변경 이력 1줄 박제 (인터페이스 변경 시) | [MUST] | 🟡 | 4분 | C9b | `.claude/scripts/sensor-shared-contracts.sh` silent |
| C9d | `grimoire-server/TECH_STATUS.md` 갱신 — CC-1 완료(적립 5경로 + 테마 차감 신 경로 연동) 박제. `docs-sync` drift sensor 확인 | [MUST] | 🟡 | 4분 | C9c | drift sensor silent |
| C9e | sensor 일괄 — `sensor-shared-contracts` / `-instruction-degradation` / `-agent-priority-labels` / `-agent-interaction` + `sensor-credit-source-accounting.sh`(존재 시) 실행 | [SHOULD] | 🟢 | 3분 | C9d | sensor 전부 silent/PASS |

### 2-8. CC-1 rollback 단위

- 각 sub-task는 git commit 단위 — C1·C2·C3·C5·C6·C8 별 commit 권장. 실패 시 해당 commit revert.
- DI 추가(C1a/C2a/C3a)는 app.module 정합 동반 — revert 시 provider 등록도 함께 원복.
- 코드 변경만(🟡) — DB 비변경. PAY-S1과 달리 백업 불요. tsc/jest 실패 = 즉시 해당 commit 단위 롤백.

---

## 3. 핸드오프

### 3-1. 담당 + 산출물 위치

| 영역 | 담당 | 산출물 위치 | 다음 단계 진입 조건 |
|---|---|---|---|
| PAY-S1 P1~P6 | grimoire-server | 로컬 DB 동기화 + `reports/sprint-cc1-pay-s1-progress.md` 갱신 | P3~P5 완료 = CC-1 DB 전제 충족 |
| PAY-S1 P7~P9 | **사용자 협력** + grimoire-infrastructure | dev/prod migration apply | firewall 개방 + 키워드 게이트 |
| CC-1 S0 | grimoire-server | §10 미확인 해소 결과 박제 (progress.md) | C0a~C0d 완료 = CC-1 본 진입 허가 |
| CC-1 T1~T8 + 통합 spec | grimoire-server (Generator) | usecase 코드 + spec + progress.md 갱신 | C9 마무리 |
| CC-1 채점 | grimoire-qa (Evaluator) | `QA_REPORT.md` — sprint-progress 통과율 박제 | — |

### 3-2. Initializer 산출물 (planner)

- 본 계획 = `.claude/state/sprint-cc1-pay-s1-plan-draft.md`.
- **`reports/sprint-cc1-pay-s1-progress.md` 생성 권고** — 본 계획의 sub-task 체크리스트 + 완료 기준을 progress.md로 박제 → server(Generator)가 Read 후 갱신, qa(Evaluator)가 채점. (책 Ch 16 Initializer→Generator→Evaluator 패턴.)
- server / qa에게 본 계획 + progress.md Read 후 작업 핸드오프.

### 3-3. 원가 영향 플래그

- CC-1은 **신규 AI 기능 추가 0건** — 기존 적립/차감 경로의 신 시스템 재배선. cost-accountant 마진 검증 게이트 **불요**.
- 단 테마 차감 `THEME_POINT_COST=590` / 분석 환불 `ANALYSIS_POINT_COST=2440`은 S Phase draft §8-4 확정값 — CC-1은 그 값을 **소비만** (값 변경 없음).
- 시각 검수(visual-canon-keeper) **불요** — CC-1은 server 도메인 한정, UI 변경 0건.

---

## 4. 종합 게이트 — sprint 완료 선언 조건

### PAY-S1 완료 선언
- **자율분**: P1~P5 [MUST] 5건 통과 + P6 [SHOULD] (실패 시 회고만).
- **전체**: P7~P9 사용자 협력 [MUST] 통과 — dev/prod `migrate status` "up to date".
- ⚠️ P7~P9는 사용자 키워드 게이트 — server agent 임의 실행 시 §0 ZERO-TOLERANCE 위반.

### CC-1 완료 선언
- **S0 게이트**: C0a~C0d [MUST] 4건 완료 (§10 미확인 해소).
- **본 작업 [MUST]**: C1a~d / C2a~c / C3a~d / C5a~d / C8a~e / C9a~d — 전부 통과.
- **검증 게이트** (writing-plans Gate 1·2·3):
  - Gate 1 (빌드): C9a `npm run build` 무에러.
  - Gate 2 (테스트): C9b `npm test` 전체 PASS + 커버리지 ≥60%. **통합 spec(C8)이 핵심** — auth/work/admin이 `GrantPointsUseCase`를 실제 호출함을 통합 테스트로 증명.
  - Gate 3 (문서/sensor): C9c~e — shared-contracts §30 + TECH_STATUS 갱신 + sensor silent.
- **[SHOULD]** C6(refundAnalysis 출처 정합) / C9e(sensor 일괄) 실패는 회고만 — CC-2 후속 흡수 가능.
- **CRITICAL-2 해소 증명**: `grep -rn "GrantPointsUseCase" src/application/{auth,work-management,admin}` 호출처 ≥5건 + 통합 spec PASS = "적립 비결제 경로 신 시스템 연동 완료" 선언.

### CC-1 미해소 잔존 (범위 외 — 명시)
- T3 충전(§1-A) / T4 선물(§1-B) / T7 환불(§1-C) = **CC-2 범위** — CC-1 완료 후에도 충전·선물·환불 적립은 구 경로 잔존.
- `Author.credits` DROP / `CreditLog` 폐기 = 별도 후속 sprint (CC-1만으로 폐기 불가 — §2-3 폐기 의존 그래프).
- CC-1 완료 ≠ V Phase 마이그레이션 적용 가능 — CC-4는 CC-1·2·3 전부 완결 후 (CREDIT_CORE_DIAGNOSIS §8 가장 중요한 결론).

---

## 5. 미확인 / 추정 금지 명시

| 항목 | 상태 | 해소 시점 |
|---|---|---|
| 테마 차감 구 경로(`credits` 1 차감) 존재 여부 | **미확인** — `theme.usecase` 미열람 | C0a (CC-1 착수 시 Read) |
| `GrantPointsUseCase` 5 메서드 정확 시그니처 | **미확인** — 본 계획은 §1 매핑 기반, 인자 정합 미확인 | C0b |
| `ChargePointsUseCase.chargeTheme` 시그니처 + deficit 분기 | **미확인** | C0c |
| dev/prod DB 마이그레이션 status | **미확인** — Azure firewall 미개방 | P7 (사용자 협력) |
| CC-1 sub-task 시간 추산 | 상대 추산 — 실측 아님. 본 계획은 분해 단위, 실제 시간은 server 실행 시 확정 | — |

> 본 계획은 코드 변경 0건 — 순수 계획 수립. 모든 file:line은 CREDIT_CORE_DIAGNOSIS / PAYMENT_PIPELINE_DIAGNOSIS 진단 리포트에 근거. 미확인은 §5에 명시 — 추정 0건.

---

## 6. 변경 이력

- 2026-05-19: 본 계획 신설. PAY-S1(P1~P9 9 sub-task) + CC-1(S0 4 + T1~T8 + 통합 spec + 마무리 = 25 sub-task) writing-plans 양식 분해. 코드 변경 0건 — 계획 수립 전용.
