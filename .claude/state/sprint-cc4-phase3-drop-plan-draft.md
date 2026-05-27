# 작업 계획: CC-4 Phase 3 — `Author.credits` DROP COLUMN + `CreditLog` 테이블 폐기 (writing-plans)

> 작성: 2026-05-21 / grimoire-planner (Initializer 패턴) / **계획 수립 전용 — 코드 변경 0건**
> 근거 정본: `reports/CREDIT_CORE_DIAGNOSIS.md` §2-3 폐기 의존 그래프 + §5-A 案 A·B(HIGH-1 결정 5/21 = Case C) + §8 sprint 분할표 CC-4 행
>           + `reports/sprint-cc4-postcleanup-phase1-progress.md` §7 Phase 3 이월 항목 + §8 발견 사항 (구 메서드 제거 + admin·discovery 분열 해소 완료)
>           + `reports/sprint-cc4-phase2-rename-progress.md` §8 Payment.points 정합 종결 증명 + §9-1 Phase 3 이월 + §9-2 응답 키 보존 결정 박제 + §11 prod rev 104 배포
>           + `.claude/state/sprint-cc4-postcleanup-plan-draft.md` §5 Phase 3 골격 (P3a~P3j 10 sub-task — 본 계획이 상세화)
>           + `.claude/state/sprint-cc4-phase2-rename-plan-draft.md` (동일 섹션 구조·포맷 정합)
>           + `.claude/state/sprint-cc{1-pay-s1,cc2a-charge-wiring,cc2b-gift-refund-wiring,cc3-rollover-source-ledger}-plan-draft.md` — 동일 섹션 구조·포맷
>           + `.claude/shared-contracts.md` §13 RefundPaymentAtomically(line 2380~) / §30 CreditOverhaul(line 2391~)
>           + 사용자 키워드 게이트 박제(2026-05-21): "Author.credits DROP + CreditLog 폐기 prod migration 진행" — Phase 3 prod migration + 배포 사전 승인
> 적용 양식: `.claude/skills/writing-plans/SKILL.md` (2~5분 sub-task / [MUST]·[SHOULD]·[NICE] / 위험도 🔴🟡🟢 / 의존 / rollback / 검증 게이트)
> 구조 정본: CC-1·CC-2a·CC-2b·CC-3·CC-4 Phase 1·Phase 2 계획과 동일 섹션 구조·포맷.
> 범위: **CC-4 Phase 3만 — CC-4 sprint 전체 종결 단계** — ① `Author.credits` Int 컬럼 DROP (비가역) ② `CreditLog` 테이블 DROP (비가역) ③ 잔존 코드 5건 제거 (auth.controller 응답 / refund-payment.usecase 폴백 / credit-migration.ts 디노미 도구 / prisma-author.repository 매핑 / credit.usecase 폴백 분기) ④ `prisma-credit.repository.ts` 파일 삭제 + `CreditRepositoryPort` interface 삭제 ⑤ DI 정리 + spec 정리 ⑥ 응답 키 보존 결정 검증 (案 P3-Y 권고) ⑦ web 핸드오프 평가 + 영향 작업 ⑧ 마이그레이션 dev/prod apply + 사후 검증 SQL.
>     **HIGH-1 案 B 범위 외** — Case C(별도 sprint, CC-4 범위 외) 사용자 결정(2026-05-21) 박제.
>     **CC-5 PAY-P1-4 Polar 구독 연동 범위 외** — 별도 sprint.

---

## 0. 진행 순서 + 의존 개요

```
CC-1 (적립 비결제 — 완료·qa검증)                                      ──선행 완료──┐
CC-2a (충전 결제 — 완료·qa검증)                                       ──선행 완료──┤
CC-2b (선물·환불 결제 — 완료·qa검증)                                  ──선행 완료──┤
CC-3 (이월 + 원장 단일화 — 완료·qa검증)                               ──선행 완료──┤
V Phase 마이그레이션 dev/prod apply (5/21 prod rev 103)              ──선행 완료──┤
CC-4 Phase 1 (구 메서드 제거 + admin/discovery 분열 해소 — 5/21)      ──선행 완료──┤
CC-4 Phase 2 (Payment.credits → points rename — 5/21 prod rev 104)   ──선행 완료──┤
                                                                       │
                                                                       ↓
                                  CC-4 Phase 3 (Author.credits DROP + CreditLog 폐기)
                                  ├─ S0: 잔존 사용처 grep 재실측 + FK 의존성 확인 + web 측 user.credits 참조 grep
                                  ├─ 결정: 응답 키 보존 (案 P3-Y 권고) + web 핸드오프 분리 작업 (案 P3-Y-a 권고)
                                  ├─ 코드 잔존 제거 (5건) + 파일/Port 삭제 + DI 정리 + spec 정리
                                  ├─ Prisma schema 갱신 (credits 컬럼 + CreditLog 모델 + Author.creditLogs 관계 제거)
                                  ├─ 마이그레이션 SQL 작성 (ALTER + DROP TABLE, 비가역)
                                  ├─ 사용자 키워드 게이트(5/21 박제 통과)
                                  ├─ dev migration apply + 사후 검증 SQL
                                  └─ prod migration apply (코드+마이그레이션 단일 deploy 묶음) + 사후 검증 + web docs sync
                                                                       │
                                                                       ↓
                                  CC-4 sprint 전체 종결 — CC-5 + HIGH-1 Case C + 잔여 작업으로 핸드오프
```

- **CC-1·CC-2a·CC-2b·CC-3·CC-4 Phase 1·Phase 2 완전 종결** — 적립 8경로(T1~T8) 전부 신 `CreditLedger` 이행. 구 메서드 시그니처/본문 제거 완료(Phase 1). `Payment.credits → Payment.points` 물리 rename + 案 Y RefundLog 보존 완료(Phase 2 — prod rev 104, 5/21). 잔존 폐기 대상 = **`Author.credits` 컬럼 + `CreditLog` 테이블 + 잔존 코드 5건 + `prisma-credit.repository.ts` 파일 + `CreditRepositoryPort` interface**.
- **사용자 키워드 게이트 통과 (2026-05-21 박제)**: "Author.credits DROP + CreditLog 폐기 prod migration 진행" — Phase 3 prod migration + 배포 사전 승인 박제.
- **HIGH-1 案 B = Case C 별도 sprint 이월 (사용자 결정 5/21 박제)** — Phase 3에서 미시행. `Author.plan` 정본 + `MembershipPlan.tier` 미러는 CC-3 案 A 양측 동기로 안정화 완료(ADR-014) — Phase 3와 무관.
- **S0 선행 게이트** — Phase 1·2 머지 후(5/21 prod rev 104) 코드 추가 변경 가능성 + FK 의존성 확인(`credit_logs.author_id` FK Restrict) + web 측 `user.credits` 참조 grep 결과 변동 가능성 → S0 sub-task에서 재실측으로 해소한 뒤 본 작업 진입.
- **비가역 마이그레이션 안전성** — DROP COLUMN + DROP TABLE 2건. pg_dump 백업 필수, 롤백은 백업 복원만 가능. dev/prod row 수 + FK 의존성 사전 측정 의무.
- **트래픽 0 가정** (Phase 1·2 prod rev 104 적용 후 추가 트래픽 미확인, 7일 결제 0건) — ScaledToZero 정합. Phase 3 적용 시점 트래픽 상태 S0d에서 재확인 의무.

### 0-1. 예상 총 시간

- CC-4 Phase 3 전체: **규모 M** — sub-task 합산 ~3.5~5h (비가역 마이그레이션이라 신중도 ↑, 단 잔존 코드 5건 + 파일/Port 삭제는 명확).
- sub-task 총 **24개** (S0 6 + 응답 키 결정 + web 핸드오프 결정 2 + 코드 잔존 제거 5 + 파일/Port 삭제 + DI 정리 3 + spec 정리 2 + Prisma schema + 마이그레이션 SQL 2 + 마이그레이션 apply + 사후 검증 2 + 마무리 2 = 24).
- **분할 근거**: ≥30분 + **비가역 마이그레이션 + 코드 단일 deploy 묶음**(`Author.credits` 읽기 + `CreditLog` 사용 코드가 DROP 후 컬럼/테이블 부재로 깨짐 → 코드+마이그레이션 동시 배포 필수) + ~12곳 코드 + spec 영향 + Prisma client 타입 갱신 + 사후 검증 SQL 필수 → 1줄 실수가 "DROP 후 코드 호출로 prod 깨짐" / "백업 복원 불가능" / "web `user.credits` 호출 깨짐"으로 직결 → sub-task 단위 검증 게이트 + git commit 단위 rollback (마이그레이션은 백업 복원만).

---

## 1. S0 — 선행: Phase 1·2 머지 박제 + 잔존 사용처/FK/web 영향 현행 재실측 (착수 게이트)

> CC-4 Phase 1·2 진행 박제(`reports/sprint-cc4-postcleanup-phase1-progress.md` §1 S0d·S0e + `sprint-cc4-phase2-rename-progress.md` §9-1) + 본 계획 작성 중 grep으로 Phase 3 입력값을 식별했으나, 머지 후 변동 가능성 + FK 의존성 미박제 + web 측 영향 미박제 → S0가 **현행 재실측**.
> ⚠️ Phase 1 (`1760e96`) + Phase 2 (`f9f85b4`) 머지 후 코드 추가 변경 가능성 → S0 grep 박제로 변경 범위 + FK 의존성 + web 참조 확정.

### 1-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| S0a | `Author.credits` / `author.credits` 사용처 전수 grep 재실측 — `grep -rn "Author\.credits\|author\.credits\|\.credits\b" grimoire-server/src grimoire-server/prisma` 결과 file:line 표 박제. 본 계획 작성 중 grep(2026-05-21) 결과: ① `prisma/schema.prisma:26` `credits Int @default(0)` 컬럼 정의 (`[DEPRECATED]` 주석) ② `adapter/inbound/http/controller/auth.controller.ts:48` `credits: author.credits` 응답 직렬화 ③ `application/payment/refund-payment.usecase.ts:124-125` `author.credits ?? 0` 폴백 ④ `domain/model/credit-migration.ts:54,58,84-85` 디노미 환산 도구 (`creditsToPoints(author.credits)`, `author.credits > 0`) ⑤ `adapter/outbound/persistence/prisma-author.repository.ts:248,299,344` toDomain 매핑 + `findDeletedOlderThan` 매핑 ⑥ `domain/model/credit-point.ts:7` 주석(디노미 박제 이력) ⑦ spec 다수 (`refund-payment.usecase.spec.ts:271` + `payment.usecase.spec.ts:809` + `credit-migration.spec.ts` 등 — Phase 3 spec 정리 대상). **본 Phase 3 일괄 제거 대상 = ① 컬럼 정의 + ② 응답 필드 + ③ 폴백 + ④ 디노미 도구(or 보존) + ⑤ 매핑 + ⑦ spec 갱신**. 호출처 파일 ~8~10 파일 + 변경 line ~15~20곳 추정 | [MUST] | 🟢 | 7분 | CC-4 Phase 2 머지 완료(5/21 `f9f85b4`) | `Author.credits`/`author.credits` 사용처 file:line 표 확정 (Phase 3 일괄 변경 범위 입력) |
| S0b | `CreditLog` / `credit_log` / `creditLog` 사용처 전수 grep 재실측 — `grep -rn "CreditLog\|credit_log\|creditLog" grimoire-server/src grimoire-server/prisma --include="*.ts" --include="*.prisma"` 결과 file:line 표 박제. 본 계획 작성 중 grep(2026-05-21) 결과: ① `prisma/schema.prisma:55,154-163` Author.creditLogs 관계 + `model CreditLog { ... }` 정의 ② `domain/model/credit.ts:8,10` 인터페이스 정의(폴백용) ③ `domain/port/outbound/credit-repository.port.ts:1,16` import + 메서드 시그니처 ④ `adapter/outbound/persistence/prisma-credit.repository.ts` 전체 파일(`getGiftRanking` + `findLogsByAuthorId` 폴백 2종) ⑤ `application/credit/credit.usecase.ts:10,175~179` `CreditLog` import + 폴백 분기 ⑥ `application/admin/admin.usecase.ts:184~189` `getAllCreditLogs` (CC-4 P1에서 신 ledger 위임 완료 — `CreditLog` 직접 사용 0건 확인) ⑦ spec 다수. **본 Phase 3 일괄 제거 대상 = ① 관계+모델 + ② 인터페이스 + ③ port + ④ 파일 자체 + ⑤ import+폴백 + ⑦ spec 갱신**. 호출처 파일 ~6~8 파일 + 변경/삭제 line ~80~120곳 추정 | [MUST] | 🟢 | 7분 | - | `CreditLog` 사용처 file:line + 폐기 대상 파일 목록 확정 |
| S0c | **FK 의존성 + DROP 순서 확정** — `credit_logs.author_id` FK는 `Author.id` 참조 + `onDelete: Restrict` (schema.prisma:157). 본 진단 시점 fk_cascade Restrict 영역(`prisma-fk-cascade.spec.ts:8건` ADR-007). DROP TABLE 시 Postgres는 FK 의존 테이블만 명시 — `Author.creditLogs` 관계 schema.prisma 측 제거 후 prisma migrate가 ALTER TABLE으로 자동 처리 또는 SQL 직접 `DROP TABLE "credit_logs"` (Postgres가 FK를 같이 DROP). 안전성 측정: ① `Author.creditLogs` 관계 schema.prisma 측 제거 + `DROP TABLE credit_logs` 1줄 → Prisma migrate 자동 처리 가능 검증 ② 대안 = `ALTER TABLE credit_logs DROP CONSTRAINT credit_logs_author_id_fkey` 명시 후 `DROP TABLE`. 권고 = ① (Prisma 표준 패턴) + 마이그레이션 SQL에 `DROP TABLE IF EXISTS "credit_logs" CASCADE` 명시(FK 자동 cascade). **`Author.credits` 컬럼 DROP은 FK 무관** (단순 컬럼) — `ALTER TABLE "authors" DROP COLUMN "credits"` 단일. 인덱스/제약 무영향(`credits` 컬럼 인덱스 미부여, schema.prisma 확인) | [MUST] | 🟢 | 6분 | S0b | FK 의존성 + DROP 순서 결정 박제 — 마이그레이션 SQL 입력 |
| S0d | **dev/prod DB 상태 박제** — `Author.credits` 컬럼 + `credit_logs` 테이블의 row 수 + 사용 패턴. ① `SELECT COUNT(*) as authors, SUM(credits) as sum_credits, COUNT(*) FILTER (WHERE credits > 0) as nonzero FROM authors`(dev/prod) ② `SELECT COUNT(*) FROM credit_logs`(dev/prod) ③ Phase 2 prod 사후 검증(2026-05-21 prod rev 104) — `payments` 4 rows 정합 + `payments.points = 0`인 행 0건. Phase 3 prod 적용 시점에 추가 트래픽 미발생 가정(7일 결제 0건 + cold-start 검증) 박제 + 마이그레이션 시간 추정 + pg_dump 백업 사이즈 예상. **prod credit_logs row 수 결과로 백업 + 마이그레이션 락 시간 예상**. dev 실측은 server agent가 sprint 진입 시 1회 (`make psql-dev` 류 + `make psql-prod` 류 또는 Azure flexible server 직접 접속) | [MUST] | 🟢 | 6분 | S0a,S0c | dev/prod `Author.credits` 사용 + `credit_logs` row 수 박제 (마이그레이션 시간 + 사후 검증 + 백업 사이즈 입력) |
| S0e | **web 측 `user.credits` / `author.credits` 참조 grep 재실측** — `grep -rn "user\.credits\|me\.credits\|author\.credits\|credits:\s*number\|\.credits\b" grimoire-web/src` 결과 file:line 표 박제. 본 계획 작성 중 grep(2026-05-21) 결과: ① `src/types/api.ts:8` `AuthUser.credits: number` 타입 정의 ② `src/types/api.ts:129` `Product.credits: number` (충전 패키지 — Phase 2 후에는 server `points` 응답을 web `credits`로 매핑) ③ `src/components/PlatformNav.tsx:110-111,134` `{user.credits} 크레딧` UI 직접 표시 (헤더 + 드롭다운) ④ `src/app/admin/page.tsx:209` `{a.credits}` 작가 테이블 ⑤ `src/app/admin/tabs/PaymentsTab.tsx:38,62` `p.credits` (Phase 2 후 server `points` 매핑 응답) ⑥ `src/app/admin/tabs/UsersTab.test.tsx:37` mock ⑦ `src/features/credits/*` 4 출처 잔액 UI (server `/credits/balance` 정규화 — Phase 3 영향 없음, server backward-compatible로 정수 `credits` 응답 시 ×1000 환산). **Phase 3 핵심 영향 = ① `AuthUser.credits` 타입 + ③ `PlatformNav` 헤더 표시 + ④ admin authors 테이블** — `/auth/me` 응답에서 `credits` 필드 제거 시 ③·④ 깨짐 위험. ⑤·⑥은 Phase 2 후 `Product.credits`/`payment.credits` 별도 의미(Phase 2 의미 = pt) — Phase 3 영향 분리. **결정 필요(§2-2)**: 案 P3-Y(응답 키 보존) = `/auth/me` 응답 `credits` 필드 보존(값 = `getBalance().total` 또는 0) → web 무영향 / 案 P3-X(응답 키 제거) = web 코드 변경 동시 필요 | [MUST] | 🟢 | 7분 | - | web 측 `user.credits` 참조 file:line 표 확정 + Phase 3 영향 분리 (案 P3-X/Y 결정 입력) |
| S0f | **Phase 2 발견 응답 키 정리 영향 재평가** — `sprint-cc4-phase2-rename-progress.md` §9-2 박제: `processNormalizedWebhook`/`processWebhook` 반환 `{ processed, credits, deficitCredits? }` — webhook 응답 schema 외부 호환성 보존 결정 박제. Phase 3에서 정리할지 보류할지 결정: ① 案 P3-X-a — `processNormalizedWebhook` 반환도 `points`/`deficitPoints`로 정합(외부 호환성 영향 평가 필요) ② 案 P3-Y-a — Phase 2 박제 그대로 보존 (외부 호환성 + `webhook-retry.job` consumer 영향 없음). **권고 = 案 P3-Y-a** — webhook 응답은 외부 호환성 + `webhook-retry.job` 내부 consumer가 사용 중 (`webhook-retry.job.spec.ts:117,214,286,428`에서 `credits: 50` 등 mock 다수 박제) → 변경 시 회귀 위험. Phase 4(별도 sprint)/CC-5에서 응답 일관성 정합 별도 단위로 분리 권고 | [MUST] | 🟢 | 5분 | S0a,S0e | webhook 응답 키 처리 결정 박제 (案 P3-Y-a 권고) |

**S0 게이트**: S0a~S0f [MUST] 6건 완료 = Phase 1·2 머지 후 현행 사용처 + FK 의존성 + DB 상태 + web 참조 + webhook 응답 결정 박제 완료 → §2 결정 게이트 진입 허가. 미확인 잔존 시 본 작업 착수 금지.

> 진단 §10 미확인 잔존 항목 중 CC-4 Phase 3 직접 관련 = S0a·S0b·S0c·S0e. 나머지(HIGH-1 案 B = Case C 결정 5/21 박제 / sensor 7종 hook = harness 영역 / Polar KYC = CC-5)는 Phase 3 범위 외.

---

## 2. §6 사용자 결정 게이트 — 응답 키 + web 핸드오프 처리 방식 (Phase 3 진입 전)

> **사용자 키워드 게이트 사전 통과 (2026-05-21 박제)** = "Author.credits DROP + CreditLog 폐기 prod migration 진행" — Phase 3 prod migration + 배포 사전 승인. 본 §2 = 응답 키 처리 + web 핸드오프 분리 작업 권고案 (추가 사용자 결정 필요 = **0건 예상** — 권고案 채택으로 진행).

### 2-1. 결정 대상 (2 case)

| case | 결정 대상 | 案 |
|---|---|---|
| case Q1: `/auth/me` 응답 `credits` 필드 처리 | `auth.controller:48` `credits: author.credits` 응답 직렬화 | 案 P3-X(필드 제거) / **案 P3-Y(필드 보존 — 값을 `getBalance().total` 또는 0으로 매핑)** |
| case Q2: webhook 응답 키 (`processNormalizedWebhook` 반환) 처리 | `payment.usecase.ts:255,273,479` 반환 `{ processed, credits, deficitCredits? }` | 案 P3-X-a(응답도 `points`/`deficitPoints` 정합) / **案 P3-Y-a(외부 호환성 + 내부 consumer 영향으로 Phase 2 박제 그대로 보존)** |

### 2-2. 案 비교 + 권고

| 영역 | 案 P3-X (전체 정리) | 案 P3-Y (응답 키 보존 — 권고) | 회귀 위험 | 권고 |
|---|---|---|---|---|
| Q1 — `/auth/me` 응답 | `credits` 필드 제거 → web `AuthUser.credits`/`PlatformNav.tsx`/`admin authors` 동시 변경 필요 (web grimoire-web 사이드 별도 PR 필요) | `credits` 필드 보존, 값 = `getBalance().total` 매핑(또는 `pointsCharged` 캐시 폴백) → web 무영향, Phase 3 server 단독 sprint | **案 P3-X**: 회귀 위험 ↑ (web 동시 배포 필수 + 사용자 UX 영향). **案 P3-Y**: 회귀 위험 ↓ (server 단독 + web 후속 sprint 분리 가능) | **案 P3-Y 권고** |
| Q2 — webhook 응답 | `processNormalizedWebhook` 반환도 `points`/`deficitPoints` 정합 — `webhook-retry.job.spec.ts` + `payment.usecase.spec.ts` 다수 변경 | Phase 2 박제 그대로 보존 — 외부 호환성 + 내부 consumer 무영향 | **案 P3-X-a**: 회귀 위험 ↑ (~10~15곳 spec/타입 변경) + 외부 webhook consumer 영향 평가 필요. **案 P3-Y-a**: 회귀 위험 ↓ | **案 P3-Y-a 권고** |

### 2-3. 권고案 종합 — 案 P3-Y + 案 P3-Y-a

**사유**:

1. **Phase 1·2 prod 안정성 정합** — Phase 1 prod 적용(5/21 prod rev 103) + Phase 2 prod 적용(5/21 prod rev 104) 후 안정 운영. Phase 3에서 web 동시 변경 + 외부 호환성 변경을 묶으면 회귀 위험 + 사용자 체감 위험 증가. **응답 키 보존 = 단일 책임 원칙** (Phase 3 = DB 컬럼/테이블 폐기 / web 호환성 변경 = 별도 sprint).
2. **Phase 2 박제 정합** — `sprint-cc4-phase2-rename-progress.md` §9-2 박제: "webhook 응답 schema는 외부 호환성 관점이 있어 응답 키만 keep + 내부 컬럼만 rename. 응답 키 일관성 정합은 Phase 3에서 web `auth/me` 응답 영향과 함께 일괄 결정 권고." → **Phase 3에서 일괄 보존 결정**으로 Phase 4/CC-5/별도 sprint에 응답 일관성 정합 분리.
3. **web 영향 최소화** — `PlatformNav.tsx:110-111` `{user.credits} 크레딧` 헤더 UI + `admin/page.tsx:209` 작가 테이블 + `AuthUser.credits` 타입 — `/auth/me` 응답에서 `credits` 필드 제거 시 4 곳 동시 변경 필요. 案 P3-Y는 server `auth.controller:48`에서 `credits: ledger?.getBalance(author.id).total ?? 0` 매핑(또는 `pointsCharged` 폴백)으로 보존 → web 무영향.
4. **마이그레이션 비가역성 정합** — Phase 3 = DB 비가역(`Author.credits` DROP COLUMN + `CreditLog` DROP TABLE). 응답 키도 동시 정리 시 회귀 시점 마이그레이션 백업 복원 + web 롤백 + webhook consumer 영향 검증 필수 → 책임 분산이 안전.
5. **`/auth/me` 응답 `credits` 값 정합 옵션** — 案 P3-Y 채택 시 값 매핑 옵션:
   - 옵션 A: `credits: ledger?.getBalance(author.id).total ?? 0` (총 잔액, ledger 주입 보장 시) — 신 시스템 정합
   - 옵션 B: `credits: 0` (단순 보존) — 안전, 단 web 헤더에 항상 "0 크레딧" 표시 위험
   - 옵션 C: `credits: Math.floor(getBalance().total / 1000)` (크레딧 단위 환산) — 구 의미 정합, 디노미 1:1000 박제 (`creditsToPoints`/`CREDIT_TO_POINT` 정본)
   - **권고 = 옵션 A** (총 pt 표시, web 정수 → "N 크레딧" 표시는 web에서 디노미 환산 가능 — `point-balance.test.ts:67-71` 기존 패턴) 또는 옵션 C (크레딧 단위 직관, 단 0 표시 가능성).
   - 추가 사용자 결정 1건 — 옵션 A/B/C 中. 권고 = 옵션 A (server 응답은 pt 단위, web 디노미 환산은 기존 패턴).

> ⚠️ 본 계획 §3~§5(코드 잔존 제거 / 파일 삭제 / 마이그레이션 sub-task 표)는 **案 P3-Y + 案 P3-Y-a + 옵션 A 권고 가정**. 사용자 案 P3-X 채택 시 §3-3에 web 동시 변경 sub-task ~5개 추가 (`AuthUser.credits` 제거 + PlatformNav 변경 + admin authors 테이블 변경 + web 테스트 갱신 + web 동시 deploy). 옵션 B/C 채택 시 §3-3 W1 sub-task에서 매핑 로직만 변경.

---

## 3. Phase 3 핵심 작업 — 코드 잔존 제거 + 파일/Port 삭제 + DI 정리 (마이그레이션 직전 코드 정합)

> 범위: ① `Author.credits` 잔존 코드 5건 제거 (auth.controller / refund-payment.usecase / credit-migration.ts / prisma-author.repository / credit.usecase 폴백) ② `prisma-credit.repository.ts` 파일 삭제 + `CreditRepositoryPort` interface 삭제 + `CreditLog` 모델 import 정리 ③ DI 정리 (`app.module.ts`에서 `CreditRepositoryPort` provider 제거) ④ spec 정리 (mock 제거 + 디노미 spec 갱신).
> 마이그레이션 직전 단계 — 마이그레이션 + 코드는 단일 deploy 묶음(P5)으로 같이 push.

### 3-1. `Author.credits` 잔존 코드 제거 (sub-task 표)

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| P1a | `auth.controller:48` 응답 처리 — 案 P3-Y + 옵션 A 권고 적용. `credits: author.credits` → `credits: balance?.total ?? 0` (CreditLedgerPort 주입 가정, ledger 미주입 시 `0` 폴백). `getMe` 핸들러에서 `creditLedger.getBalance(author.id)` 호출 추가. ⚠️ `getBalance`는 throw 위험 — try/catch로 안전 폴백 `0` (lazy 안전망 패턴 정합). 또는 옵션 C 채택 시 `credits: Math.floor((balance?.total ?? 0) / CREDIT_TO_POINT)` | [MUST] | 🟡 | 7분 | S0 게이트 + §2 결정 | tsc PASS + `auth.controller.ts`에서 `author.credits` grep 0건 |
| P1b | `auth.controller.spec.ts` 갱신 — `getMe` 응답 검증 시 `credits` 필드 값이 신 ledger 잔액 기반인지 검증. `mockCreditLedger.getBalance` mock 추가 + `credits` 응답 값 검증 (옵션 A 채택 시 `total` 정합, 옵션 C 채택 시 환산값 정합). 옵션 결정에 따라 assertion 분기 | [MUST] | 🟡 | 6분 | P1a | `npm test auth.controller.spec` PASS |
| P1c | `refund-payment.usecase:115-136` 폴백 제거 — `else if (this.authorRepo)` 폴백(ledger 미주입 시 author.credits ?? 0)을 완전 제거. **`CreditLedgerPort` 항상 주입 보장** 검증 (현재 `Optional`? Required? 코드 확인 후 결정). 만일 Optional 잔존이면 폴백 제거 시 spec 영향 — `refund-payment.usecase.spec.ts:271` "author.credits 만 charged 슬롯에 박제" spec 케이스 제거 + 폴백 시그니처 정리. 안전 옵션 = 폴백을 `balanceBefore = null`로 단순화(audit 박제 skip만) — author.credits 의존 0건 | [MUST] | 🟡 | 7분 | P1a | tsc PASS + `refund-payment.usecase.ts`에서 `author.credits` grep 0건 |
| P1d | `domain/model/credit-migration.ts:54,58,84-85` 디노미 도구 정리 — `expectMigratedAuthor` + `migrationIntegrityCriteria` 함수가 `author.credits` 의존. **결정**: ① 案 P3-d-X (파일 자체 삭제) = V Phase 마이그레이션 적용 완료(5/21 prod rev 103) — 디노미 검증 도구는 V Phase 직후 1회 사용 후 폐기 — 본 Phase 3 자연 폐기 시점. ② 案 P3-d-Y (`credit-migration.ts` 파일 보존 + `PreMigrationAuthor.credits` 인터페이스만 보존, 함수는 V Phase 마이그레이션 적용 박제 도구로 보존). **권고 = 案 P3-d-X (파일 자체 삭제)** — V Phase 마이그레이션은 prod rev 103 적용 완료 + 박제는 `reports/CREDIT_CORE_DIAGNOSIS.md` + migration.sql 자체에 박제. `credit-migration.spec.ts`도 삭제. 만일 미래 추가 검증 필요성 박제하려면 `_archive` 디렉토리 이동 옵션 | [MUST] | 🟡 | 6분 | S0a | tsc PASS + `credit-migration.ts` 파일 부재 + spec 부재 + 기타 코드에서 `expectMigratedAuthor` grep 0건 |
| P1e | `prisma-author.repository.ts:248,299,344` toDomain 매핑 정리 — `credits: row.credits` 매핑 + `findDeletedOlderThan` raw query SELECT * snake_case → `Author` 도메인 model `credits` 필드 제거에 정합. `Author` 도메인 model(`domain/model/author.ts` 추정) `credits: number` 필드도 제거. raw query `SELECT * FROM authors` 결과는 Postgres에서 `credits` 컬럼 부재 자동 정합 (DROP COLUMN 후) — 컴파일러가 누락 강제 | [MUST] | 🟡 | 7분 | S0a | tsc PASS + `prisma-author.repository.ts`에서 `credits` grep 0건 (정의된 필드/매핑) |

### 3-2. `CreditLog` 테이블 + 파일/Port 삭제 (sub-task 표)

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| P2a | `adapter/outbound/persistence/prisma-credit.repository.ts` 파일 자체 삭제 — Phase 1 후 잔존 2 메서드(`getGiftRanking`/`findLogsByAuthorId` 폴백). 호출처 0건 검증(`credit.usecase.ts:175~179`/`:160~163` 폴백 분기는 P2c에서 제거 후 호출처 0건). 파일 + `prisma-credit.repository.spec.ts` 같이 삭제 | [MUST] | 🟡 | 5분 | P1a,P1c (잔존 author.credits 제거 후) | `ls grimoire-server/src/adapter/outbound/persistence/prisma-credit.repository.ts` = "No such file" |
| P2b | `domain/port/outbound/credit-repository.port.ts` interface 삭제 — `CreditRepositoryPort` interface 정의 파일 자체 삭제. import `CreditLog` 정리. 호출처 0건 검증(`credit.usecase.ts:33` `@Inject('CreditRepositoryPort')` DI는 P2c에서 제거 후 호출처 0건) | [MUST] | 🟡 | 4분 | P2a | `ls grimoire-server/src/domain/port/outbound/credit-repository.port.ts` = "No such file" |
| P2c | `application/credit/credit.usecase.ts` 정리 — ① `import { CreditRepositoryPort }` 제거 ② `@Inject('CreditRepositoryPort') private readonly creditRepo: CreditRepositoryPort` DI 제거 ③ `getGiftRanking:160~163` 폴백 분기 제거 (`return this.creditRepo.getGiftRanking(limit)` 라인 + `if (this.ledger)` 가드 제거 후 `return this.ledger.getGiftRanking(limit)` 단일 분기 — `ledger` Required 보장 필요, 아니면 throw) ④ `getLogs:175~179` 폴백 분기 동일 정리 ⑤ `import { CreditLog }` 제거 + 반환 타입 `Promise<CreditLedgerEntry[] | CreditLog[]>` → `Promise<CreditLedgerEntry[]>` 정합. **`ledger` Required 가드**: 현재 `Optional`이면 Phase 3에서 `Required`로 변경 또는 throw 분기 명시 — CC-3 박제 검토 | [MUST] | 🟡 | 8분 | P2b | tsc PASS + `credit.usecase.ts`에서 `creditRepo`/`CreditRepositoryPort`/`CreditLog` grep 0건 |
| P2d | `domain/model/credit.ts` 정리 — `CreditLog` interface 정의 + `toDomain` 함수 제거. 파일 자체 삭제 가능 검토(다른 export 0건 시) | [MUST] | 🟡 | 4분 | P2c | tsc PASS + `credit.ts`에서 `CreditLog` interface grep 0건 또는 파일 삭제 |
| P2e | `app.module.ts` DI 정리 — `provide: 'CreditRepositoryPort'` provider 등록 line 제거. 의존 module/usecase에서 `CreditRepositoryPort` DI 잔존 0건 검증 (admin.usecase / discovery.usecase / social.usecase 등은 Phase 1에서 이미 제거 — credit.usecase가 Phase 3 마지막 사용처) | [MUST] | 🟡 | 4분 | P2c | tsc PASS + `app.module.ts`에서 `CreditRepositoryPort` grep 0건 |

### 3-3. spec 정리 + 통합 spec 검증 (sub-task 표)

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| P3a | spec mock 정리 — Phase 1·2 후 잔존 `mockCreditRepo` mock + `author.credits` mock 일괄 정리. ① `credit.usecase.spec.ts` — `mockCreditRepo.getGiftRanking/findLogsByAuthorId` mock 제거 + ledger 미주입 폴백 spec 케이스 제거 ② `refund-payment.usecase.spec.ts:271` "fallback author.credits 만 charged 슬롯에 박제" spec 케이스 제거 ③ `auth-security.spec.ts` 등에서 `Author.credits` mock 잔존 점검 + 제거 ④ `prisma-payment.repository.spec.ts:144` 주석 정리. **회귀 case 보존**: ledger 주입 정상 경로 + 4 출처 잔액 spec 100% 유지 | [MUST] | 🟡 | 8분 | P2c | `npm test` 전체 PASS — mock 정리 후 spec 회귀 0건 |
| P3b | 통합 spec 갱신 — `credit-rollover-source-ledger-integration.spec.ts` 끝(I1b CC-4 Phase 1) 박제된 통합 케이스 검토 + Phase 3 케이스 추가: ① `CC-4 Phase 3 — Author.credits 컬럼 + CreditLog 테이블 폐기 정합` describe ② `it('Phase 3 — auth/me 응답 credits 필드 = ledger getBalance.total 매핑 정합 (案 P3-Y 옵션 A)')` ③ `it('Phase 3 — CreditRepositoryPort interface 부재 + 컴파일 타임 박제')` (컴파일러가 누락 강제 — 별도 it 또는 P2c 검증으로 갈음) ④ `it('Phase 3 — Author 도메인 model에 credits 필드 부재 + Prisma client 타입 정합')` (컴파일 타임 박제) ⑤ `it('Phase 3 — 신·구 분열 잔존 0건 + 4 출처 잔액 단일 정본')` (회귀 안전망) | [MUST] | 🟡 | 8분 | P3a | 해당 describe + it 신설 + PASS — Phase 3 종결 증명 |

---

## 4. Prisma schema 갱신 + 마이그레이션 SQL (M1) — 비가역

> 범위: ① `Author.credits Int @default(0)` 컬럼 제거 ② `Author.creditLogs CreditLog[]` 관계 제거 ③ `model CreditLog` 모델 정의 전체 제거 ④ 마이그레이션 SQL 작성 (`ALTER TABLE DROP COLUMN` + `DROP TABLE`).
> **비가역** — 데이터 손실 발생 (DROP COLUMN credits 데이터 + DROP TABLE credit_logs 전체). pg_dump 백업 필수 + 사용자 키워드 게이트 통과 (사전 박제 5/21).

### 4-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| M1a | Prisma schema 갱신 — `prisma/schema.prisma`:① `model Author` line 23-26 `credits Int @default(0)` + 주석 4줄 제거 ② line 55 `creditLogs CreditLog[]` 관계 제거 (Restrict 영역 주석도 정합 갱신 — "credit_logs.authorId" → 제거) ③ line 154-163 `model CreditLog { ... }` 전체 제거. 본 sprint 박제 주석 1줄 추가 (`/// [CC-4 Phase 3 — 2026-05-21] Author.credits 컬럼 + CreditLog 모델 폐기. 마이그레이션: 20260521_author_credits_drop_credit_log_phase3.`). `npx prisma format` PASS / `npx prisma generate` PASS — Prisma client 타입 `Author.credits` 부재 + `CreditLog` 모델 부재 정합 | [MUST] | 🔴 | 7분 | P3b | tsc PASS + Prisma client 타입 `Author.credits` 부재 + `CreditLog` 모델 부재 |
| M1b | 마이그레이션 SQL 작성 — 경로: `prisma/migrations/20260521_author_credits_drop_credit_log_phase3/migration.sql`. 내용:① `ALTER TABLE "authors" DROP COLUMN "credits";` ② `DROP TABLE IF EXISTS "credit_logs" CASCADE;` (FK 자동 cascade). 박제 주석 헤더 ~15줄 (CC-4 Phase 3 비가역 + 사용자 게이트 박제 + pg_dump 백업 의무 + 사후 검증 SQL 4건). **CASCADE 명시 이유**: `credit_logs.author_id` FK Restrict로 정의됐으나 (schema.prisma:157) DROP TABLE 시 FK 동시 DROP 필요. Postgres CASCADE = 의존 객체(인덱스/FK 제약) 동시 DROP — `credit_logs` 자체가 사라지므로 FK도 무의미해짐 + 안전한 cascade | [MUST] | 🔴 | 8분 | M1a,S0c | 마이그레이션 SQL 파일 작성 + `npx prisma migrate diff` 결과 정합 (`ALTER TABLE DROP COLUMN` + `DROP TABLE`만 박제) |
| M1c | 마이그레이션 안전성 분석 — pg_dump 백업 + 락 시간 + 데이터 손실 + 롤백 정합 박제. **DROP COLUMN credits 영향**: ① 락 시간 — Postgres 12+ `ALTER TABLE DROP COLUMN`은 메타데이터 한정 ACCESS EXCLUSIVE 락 짧음, 즉시 완료(데이터는 백그라운드 VACUUM에서 회수 — 마이그레이션 자체는 즉시) ② 데이터 손실 — `authors.credits` 모든 row 정수 데이터 손실. V Phase 마이그레이션에서 `points_charged = credits × 1000` 환산 후 충전 출처로 적립 완료(prod rev 103, 5/21) → `credits` 의미는 더 이상 정본 아님 — 안전한 손실. ③ 인덱스/제약 — `credits` 컬럼 인덱스 부여 0건 (schema.prisma 확인) — 무영향. ④ 롤백 — 비가역, pg_dump 백업 복원만. **DROP TABLE credit_logs 영향**: ① 락 시간 — ACCESS EXCLUSIVE 즉시 완료. ② 데이터 손실 — `credit_logs` row 전체 삭제 (prod row 수 = S0d 박제 결과 — V Phase 후 신 박제 0건 가정, 단 V Phase 이전 박제 row 다수 잔존 가능). ③ FK — CASCADE로 자동 처리. ④ 롤백 — 비가역. **pg_dump 백업 명령**: `pg_dump --table=authors --table=credit_logs --data-only --schema-only > backup-cc4-phase3-{ts}.sql` (스키마 + 데이터 양쪽) | [MUST] | 🔴 | 6분 | M1b | 마이그레이션 안전성 분석 보고서 작성 (락 시간 + 데이터 손실 + FK 처리 + 롤백) |

### 4-2. 마이그레이션 안전성 종합

| 영역 | 분석 결과 |
|---|---|
| 락 시간 | DROP COLUMN + DROP TABLE 둘 다 ACCESS EXCLUSIVE 짧음 — Postgres 12+ 메타데이터 한정, 즉시 완료. cold-start 24s 정합(7일 트래픽 0). |
| 데이터 영향 | `authors.credits` 전 row 정수 손실 (V Phase에서 이미 신 시스템 이행 완료, 의미 폐기 — 안전한 손실) / `credit_logs` 전 row 손실 (백업 의무, V Phase 이전 박제 잔존 가능). |
| 인덱스/제약 | `Author.credits` 인덱스 0건. `credit_logs.author_id` FK Restrict → CASCADE로 자동 처리. 기타 인덱스(`credit_logs` 자체 인덱스)도 CASCADE 동시 DROP. |
| FK | `credit_logs.author_id → authors.id` FK는 CASCADE로 명시 — DROP TABLE이 자동 처리. `Author.creditLogs` Prisma 관계는 schema.prisma 측 제거 후 Prisma migrate 정합. |
| 롤백 | 비가역. `pg_dump --table=authors --table=credit_logs --data-only --schema-only > backup-{ts}.sql` 직전 1회 + 복원만 가능. |
| pg_dump 백업 | dev/prod 양쪽 — Phase 2 prod rev 104 적용 시 pg_dump 14.66MB 박제 정합(전체 DB). Phase 3는 `--table=authors --table=credit_logs --data-only --schema-only`로 한정 백업 가능 (사이즈 작음) 또는 안전망 전체 백업. |

---

## 5. 마이그레이션 apply + 사후 검증 + 단일 deploy 묶음 (F1) — 비가역

> Phase 2와 동일 패턴 — `RUN_MIGRATION=true` + `make deploy-prod`(또는 `scripts/deploy-prod.sh`) 한 묶음. 단 **비가역**이므로 pg_dump 백업 + 사후 검증 SQL 통과 의무 + cleanup만 진행.

### 5-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| F1a | pg_dump 백업 (dev) + dev migration apply + 사후 검증 — ① `pg_dump --table=authors --table=credit_logs --data-only --schema-only` (dev) → `/tmp/grimoire_backup/backup_pre_phase3_dev_{ts}.sql` ② `npx prisma migrate deploy` (dev) ③ 사후 검증 SQL 4건 (§5-2) — 전부 PASS 필수 ④ `payments` 4 rows + 기타 의존 테이블 정합 회귀 0건 검증 | [MUST] | 🔴 | (사용자 협력 + 8분) | M1c | dev migration apply PASS + 사후 검증 SQL 4건 PASS |
| F1b | pg_dump 백업 (prod) + prod migration apply (코드+마이그레이션 단일 deploy) — ① `pg_dump --table=authors --table=credit_logs` (prod) → `/tmp/grimoire_backup/backup_pre_phase3_prod_{ts}.sql` (사이즈 검증) ② 사용자 키워드 게이트 박제 5/21 적용 (사전 통과). ③ server develop push (이전 커밋들과 함께) → main 머지 → `SKIP_INTERACTIVE=1 bash scripts/deploy-prod.sh`(또는 `make deploy-prod`) — `RUN_MIGRATION=true` 환경변수로 boot 시 `prisma migrate deploy` 자동 적용. ④ revision 박제 (예: `grimoire-server-prod--0000105`). ⑤ 헬스 상태 검증 — `RunningAtMaxScale` + `Healthy` | [MUST] | 🔴 | (사용자 협력 + grimoire-infrastructure agent) | F1a + 사용자 키워드 게이트 박제(5/21) | prod migration apply PASS + Container revision 105 Healthy + 마이그레이션 자동 적용 박제 |
| F1c | prod 사후 검증 SQL 4건 — §5-2 정합. 양 환경(dev/prod) 모두 통과 박제 | [MUST] | 🔴 | (사용자 협력 + 5분) | F1b | 사후 검증 SQL 4건 dev/prod 양쪽 PASS |
| F1d | prod-api smoke — ① `GET /api/health` 200 OK ② `GET /api/auth/me` (인증 토큰 필요 — qa 영역) 응답 `credits` 필드 보존 + 값 = `getBalance().total` 정합 (案 P3-Y 옵션 A 박제) ③ `GET /api/credits/balance` 응답 4 출처 정합 ④ 컨테이너 로그 runtime error 0건 (`error\|exception\|fatal`) | [MUST] | 🔴 | (사용자 협력 + 5분) | F1c | prod smoke 4건 PASS |

### 5-2. 사후 검증 SQL 4건 (DROP 완료 박제)

```sql
-- ① authors 테이블에서 credits 컬럼 부재 확인 (DROP COLUMN 성공)
SELECT column_name FROM information_schema.columns
WHERE table_name = 'authors' AND column_name = 'credits';
-- 기대: 0 rows (credits 컬럼 부재)

-- ② credit_logs 테이블 부재 확인 (DROP TABLE 성공)
SELECT table_name FROM information_schema.tables
WHERE table_name = 'credit_logs';
-- 기대: 0 rows (credit_logs 테이블 부재)

-- ③ authors 컬럼 정합 (points_charged 등 신 4 출처 + deficit_points 보존)
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'authors'
  AND column_name IN ('points_free', 'points_subscription', 'points_gift', 'points_charged', 'deficit_points')
ORDER BY column_name;
-- 기대: 5 rows (신 4 출처 + deficit 정합 보존)

-- ④ prisma migration history 정합
SELECT migration_name, finished_at FROM _prisma_migrations
WHERE migration_name = '20260521_author_credits_drop_credit_log_phase3';
-- 기대: 1 row + finished_at NOT NULL (apply 완료)
```

추가 검증 (Phase 2 prod rev 104 정합 회귀 0건):
```sql
-- ⑤ payments.points 정합 회귀 0건 (Phase 2 박제 보존)
SELECT COUNT(*) FROM payments WHERE points > 0;
-- 기대: Phase 2 prod 사후 검증과 일치 (4 rows 박제)
```

---

## 6. 마무리 — 빌드 / jest / 커버리지 / 문서 / sensor + web 핸드오프 (F2)

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| F2a | 전체 빌드 + tsc — `npx tsc --noEmit` 무에러 + `npm run build` (`nest build`) PASS | [MUST] | 🟢 | 4분 | F1d | tsc/build 무에러 |
| F2b | 전체 jest + 커버리지 — `npm test` 통과 + server 커버리지 **≥60%** 유지. 통합 spec(P3b)이 Phase 3 핵심 — `Author.credits` 컬럼 + `CreditLog` 테이블 폐기 + auth/me 응답 정합 박제. **신·구 분열 잔존 0건 박제 it 통과** | [MUST] | 🟡 | 5분 | F2a | jest 전체 PASS + 커버리지 ≥60% |
| F2c | `shared-contracts.md` §13 + §30 갱신 — §30 변경 이력 1줄 추가 (`CC-4 Phase 3` — `Author.credits` 컬럼 DROP + `CreditLog` 테이블 폐기 + `prisma-credit.repository.ts` 파일 삭제 + `CreditRepositoryPort` interface 삭제 + `/auth/me` 응답 案 P3-Y 옵션 A 박제 + 마이그레이션 + 종결 증명). §13 `RefundPaymentAtomically` 변경 이력 1줄 (CC-4 Phase 3 author.credits 폴백 제거). ⚠️ §13/§30 인터페이스 정본 → 미갱신 시 다른 agent 통합 단계 깨짐 | [MUST] | 🟡 | 7분 | F2b | `.claude/scripts/sensor-shared-contracts.sh` silent |
| F2d | `grimoire-server/TECH_STATUS.md` + `docs/data-model.md`(`Author.credits` 행 제거 + `CreditLog` 행 제거 + ADR-007 Restrict 8건 → 7건 정합) + `docs/api-contract.md`(`GET /auth/me` 응답 `credits` 필드 案 P3-Y 옵션 A 박제) + `SCHEMA.md` 갱신 — Phase 3 종결(`Author.credits` DROP + `CreditLog` 폐기) 박제. `docs-sync` drift sensor silent | [MUST] | 🟡 | 8분 | F2c | drift sensor silent + data-model.md 정합 |
| F2e | `ADR.md` 갱신 — ADR-007 Restrict 영역 + ADR-012 (I Phase) + ADR-014 (CC-3 案 A) + CC-4 Phase 3 종결 박제. `credit_logs.authorId` Restrict 행 제거 (7건으로 감소) + `Author.credits` DROP + `CreditLog` 폐기 명시 | [MUST] | 🟡 | 6분 | F2d | ADR.md 정합 |
| F2f | sensor 일괄 — `sensor-shared-contracts` / `-instruction-degradation` / `-agent-priority-labels` / `-agent-interaction` + `sensor-credit-source-accounting.sh` / `-credit-overhaul-recalc.sh`(존재 시) 실행 | [SHOULD] | 🟢 | 3분 | F2e | sensor 전부 silent/PASS |
| F2g | **web develop → main 머지 (docs sync only)** — Phase 3 prod 적용 후 (P3j 정합). server `data-model.md` + `api-contract.md` cp → web 동기화 + commit (web 사이드 변경 = `/auth/me` 응답 형태는 案 P3-Y 옵션 A로 보존 → web 코드 변경 0건). 단 server `data-model.md`/`api-contract.md`가 정본이므로 web cp → docs drift sensor silent | [SHOULD] | 🟢 | (web agent + 5분) | F2f | web docs sync commit PASS + drift sensor silent |
| F2h | **sensor 7종 hook 등록 권고 핸드오프** — Phase 1 F1f 정합. `.claude/scripts/sensor-credit-overhaul-recalc.sh` / `-denomination.sh` / `-source-accounting.sh` / `-subscription-pool-no-rollover.sh` / `-chat-charge-tier.sh` / `-credit-atomicity.sh` / `-admin-credit-ui.sh` settings.json hook 등록 = **harness 영역** (server sprint 외) → DEV_REPORT.md에 명시 핸드오프 박제 (Phase 1·2 박제 패턴 정합) | [SHOULD] | 🟢 | 3분 | F2g | 핸드오프 박제 명시 |

> **원가 게이트 판정 (F2 단계 박제)**: Phase 3은 **신규 AI 기능 추가 0건** — DB 컬럼/테이블 폐기 + 코드 잔존 제거. AI 모델 호출 0건, `CREDIT_PRODUCTS` 무변경, 차감 N 무변경. §0 직결값을 건드리지 않음. **cost-accountant 마진 검증 게이트 불요** — CC-3·Phase 1·Phase 2와 동일.

> **visual-canon-keeper 게이트 판정**: Phase 3는 **server 도메인 한정** — UI 변경 0건. 시각 정본(사슴악마) 영향 0건. `/auth/me` 응답 `credits` 필드 案 P3-Y 옵션 A 보존 → web 코드 변경 0건. visual-canon-keeper 검수 **불요**.

---

## 7. cost-accountant / visual-canon-keeper 게이트

### 7-1. cost-accountant 게이트 — **불요**

CC-4 Phase 3는 **신규 AI 기능 추가 0건**. `Author.credits` 컬럼 + `CreditLog` 테이블 폐기 + 코드 잔존 제거. AI 모델 호출 0건, `CREDIT_PRODUCTS` 무변경, 차감 N 무변경. §0 직결값을 건드리지 않음 — CC-1·CC-2b·CC-3·CC-4 Phase 1·Phase 2와 동일 판정.

### 7-2. visual-canon-keeper 게이트 — **불요**

CC-4 Phase 3는 **server 도메인 한정** — UI 변경 0건. 시각 정본(사슴악마) 영향 0건. **web 핸드오프 1건(docs sync only)** — 案 P3-Y 옵션 A 채택으로 `/auth/me` 응답 `credits` 필드 보존 → web 코드 변경 0건. F2g 실행.

---

## 8. 핸드오프

### 8-1. 담당 + 산출물 위치

| 영역 | 담당 | 산출물 위치 | 다음 단계 진입 조건 |
|---|---|---|---|
| §6 사용자 게이트 (이미 사전 통과 — 5/21) | 사용자 키워드 게이트 박제 = "Author.credits DROP + CreditLog 폐기 prod migration 진행" | (박제 완료) | Phase 3 즉시 진행 |
| §2 응답 키 결정 (案 P3-Y + 옵션 A 권고) | planner 권고 + server 채택 | 본 계획 §2 박제 | server agent 채택 시 즉시 진행 (사용자 별도 결정 권고 없음 — 권고案으로 진행) |
| CC-4 Phase 3 S0 | grimoire-server | 잔존 사용처 + FK + web 참조 + DB 상태 재실측 결과 박제 (progress.md) | S0a~S0f 완료 = Phase 3 구현 진입 |
| CC-4 Phase 3 구현 (P1·P2·P3·M1) | grimoire-server (Generator) | 코드 잔존 제거 + 파일/Port 삭제 + DI 정리 + spec + Prisma schema + 마이그레이션 SQL + progress.md 갱신 | F2h 마무리 (sensor 등록 권고 박제) |
| CC-4 Phase 3 마이그레이션 apply (F1) | grimoire-infrastructure agent | pg_dump 백업 + dev/prod migration apply + 사후 검증 SQL + Container revision 105 박제 | F1a~F1d 통과 |
| CC-4 Phase 3 채점 | grimoire-qa (Evaluator) | `QA_REPORT.md` — sprint-progress 통과율 박제 + **`Author.credits` DROP + `CreditLog` 폐기 종결 증명 박제** | Phase 3 머지 |
| **CC-4 sprint 전체 종결 박제** | grimoire-server / planner | sprint 전체 종결 progress (Phase 1+2+3 합산 박제) + 잔여 작업 핸드오프 | Phase 3 머지 완료 = CC-4 종결 |
| web develop → main 머지 (docs sync only) | grimoire-web | data-model.md + api-contract.md cp + commit. **코드 변경 0건** (案 P3-Y 옵션 A 보존 정합) | Phase 3 prod 적용 후 (F2g) |
| sensor 7종 hook 등록 | grimoire-harness agent (별도) | sensor 7종 settings.json hook 등록 | Phase 3 머지 후 |
| HIGH-1 案 B 별도 sprint (Case C — 5/21 박제) | grimoire-server / planner | 별도 sprint(예: `HIGH-1-CASE-B`) 계획 신설 + 실행 | Phase 3 머지 후 또는 CC-5와 병렬 |
| CC-5 PAY-P1-4 Polar 구독 연동 | grimoire-server / planner | 별도 sprint 계획 신설 (착수 직전 상세화) | Phase 3 머지 후 |

### 8-2. Initializer 산출물 (planner)

- 본 계획 = `.claude/state/sprint-cc4-phase3-drop-plan-draft.md`.
- **`reports/sprint-cc4-phase3-drop-progress.md` 생성 권고** — Phase 3 sub-task 24건 체크리스트 + 완료 기준 + **`Author.credits` DROP + `CreditLog` 폐기 종결 증명 항목**을 progress.md로 박제 → server(Generator)가 Read 후 갱신, qa(Evaluator)가 채점 (책 Ch 16 Initializer→Generator→Evaluator 패턴).
- **`reports/sprint-cc4-complete-progress.md` 생성 권고** — Phase 3 머지 완료 시점에 Phase 1+2+3 합산 종결 박제 (CC-4 sprint 전체 종결 선언).
- server / qa에게 본 계획 + progress.md Read 후 작업 핸드오프.

### 8-3. 원가 영향 + 시각 검수 + web 핸드오프 플래그

- CC-4 Phase 3는 **신규 AI 기능 추가 0건** — cost-accountant 마진 검증 게이트 **불요** (§7-1).
- 시각 검수(visual-canon-keeper) **불요** — server 도메인 한정 (§7-2).
- **web 핸드오프 1건** (Phase 3 후) — docs sync only (data-model.md + api-contract.md). **코드 변경 0건** (案 P3-Y 옵션 A 보존 정합). F2g 실행.
- **harness 핸드오프 1건** (F2h) — sensor 7종 settings.json hook 등록 권고 박제.

### 8-4. CC-5·후속 sprint로 이월되는 범위 (CC-4 범위 외 — 명시)

| 항목 | 진단 근거 | 이월 sprint |
|---|---|---|
| HIGH-1 案 B (`Author.plan` 읽기 13곳 → `MembershipPlanPort.getPlan` + `Author.plan` `[DEPRECATED]`) | §5-A 案 B + 5/21 사용자 결정 = Case C | 별도 sprint(`HIGH-1-CASE-B`) — CC-5와 병렬 가능 |
| `MembershipPlanPort.getPlan` HTTP 노출 (`GET /membership` 등) | §7 + 진단 §10 | CC-5 PAY-P1-4 (구독 도메인 응집) |
| PAY-P1-4 Polar 구독 결제 연동 (`subscription.*` webhook + `changeTier` 활성화 + 구독 시작/멤버십 조회 엔드포인트) | §7 | CC-5 |
| Phase 4 응답 일관성 정합 (선택) — `processNormalizedWebhook` 반환 `{ credits, deficitCredits }` → `{ points, deficitPoints }` 정합 + webhook consumer 영향 평가 | Phase 2 §9-2 + Phase 3 §2-3 案 P3-Y-a 박제 | Phase 4 또는 별도 sprint (외부 호환성 영향 평가 종속) |
| PAY-S2/S3/S4 후속 sprint | progress.md 핸드오프 | 별도 sprint |
| sensor 7종 hook 등록 | LOW-1 / §10 | harness agent |

> ⚠️ **CC-4 Phase 3 완료 = CC-4 sprint 전체 종결**. 잔존 폐기 정리 0건 — `Author.credits` 컬럼 + `CreditLog` 테이블 + `prisma-credit.repository.ts` 파일 + `CreditRepositoryPort` interface 폐기 100% 완료. `/auth/me` 응답 `credits` 필드는 案 P3-Y 옵션 A 보존(값 = `getBalance().total` 매핑) — Phase 4/CC-5에서 응답 일관성 정합 별도 결정.

---

## 9. 종합 게이트 — CC-4 Phase 3 완료 선언 조건 + Author.credits·CreditLog 폐기 종결 증명

### Phase 3 완료 선언

- **§6 사용자 게이트**: "Author.credits DROP + CreditLog 폐기 prod migration 진행" 사전 통과 박제(5/21) — 추가 결정 0건 (案 P3-Y + 옵션 A 권고 채택).
- **S0 게이트**: S0a~S0f [MUST] 6건 완료 (잔존 사용처 + FK + DB 상태 + web 참조 + webhook 응답 처리 박제).
- **본 작업 [MUST]**: P1a~P1e + P2a~P2e + P3a~P3b + M1a~M1c + F1a~F1d + F2a~F2e — 전부 통과. ([SHOULD] F2f·F2g·F2h 실패는 회고만.)
- **검증 게이트** (writing-plans Gate 1·2·3):
  - Gate 1 (빌드): F2a `npm run build` 무에러.
  - Gate 2 (테스트): F2b `npm test` 전체 PASS + 커버리지 ≥60%. **통합 spec(P3b)이 핵심** — Phase 3 컬럼/테이블 폐기 + auth/me 응답 정합 + 신·구 분열 잔존 0건 박제.
  - Gate 3 (문서/sensor): F2c~e — shared-contracts §13/§30 + TECH_STATUS + api-contract + data-model + SCHEMA + ADR 갱신 + sensor silent.

### Author.credits·CreditLog 폐기 종결 증명 (Phase 3 종결 게이트 — 가장 중요)

Phase 3은 CC-4 sprint 전체 종결 — 완료 시 다음 박제:

| 결함 | 증명 방법 |
|---|---|
| **`Author.credits` 컬럼 폐기** | ① `SELECT column_name FROM information_schema.columns WHERE table_name='authors' AND column_name='credits'` dev/prod 양쪽 0 rows ② `grep -rn "author\.credits\|Author\.credits" grimoire-server/src --exclude="*.spec.ts"` **0건** (주석 매치만 허용 = 박제 이력) ③ tsc PASS — Prisma client 타입 `Author.credits` 부재 컴파일 시 누락 강제 |
| **`CreditLog` 테이블 폐기** | ① `SELECT table_name FROM information_schema.tables WHERE table_name='credit_logs'` dev/prod 양쪽 0 rows ② `grep -rn "CreditLog\b\|credit_log\b" grimoire-server/src --exclude="*.spec.ts"` **0건** (주석 매치만 허용) ③ `prisma-credit.repository.ts` 파일 부재 + `CreditRepositoryPort` interface 부재 |
| **`/auth/me` 응답 `credits` 필드 정합 (案 P3-Y 옵션 A)** | ① 통합 spec P3b PASS — `getMe` 응답 `credits` 필드 = `ledger.getBalance(author.id).total` 매핑 정합 ② prod smoke F1d 정합 — `GET /api/auth/me` 응답 `credits` 필드 값 보존 ③ web `PlatformNav` + admin authors 테이블 회귀 0건 (案 P3-Y 옵션 A 보존) |
| **`prisma-credit.repository.ts` 파일 폐기 + `CreditRepositoryPort` interface 폐기** | ① 파일 부재 + interface 부재 ② `grep -rn "CreditRepositoryPort" grimoire-server/src` **0건** (DI provider + import 0건) ③ tsc PASS — 컴파일러가 누락 강제 |
| **신·구 분열 잔존 0건** | ① 통합 spec P3b PASS — 신 `CreditLedger` 단일 정본 박제 ② `grep -rn "CreditLog\|adjustCredits\|completePaymentAtomically\|refundPaymentAtomically\|giftTransfer\|sumNegativeAmounts" grimoire-server/src --exclude="*.spec.ts"` **0건** (CC-4 sprint 전체 종결 박제) |
| **마이그레이션 dev/prod apply 정합** | ① 사후 검증 SQL 4건 + ⑤ 정합 회귀 dev/prod 양쪽 PASS ② Container revision 105 Healthy ③ `prisma migrate status` "up to date" ④ pg_dump 백업 사이즈 박제 |
| **sensor 7종 hook 등록 권고 핸드오프** | DEV_REPORT.md 또는 PLANNER_REPORT.md에 명시 박제 (harness agent로 전달, Phase 1·2 박제 패턴 정합) |

→ **CC-4 Phase 3 종결 선언 조건**: 위 7건 전부 증명 + 통합 spec P3b PASS = "CC-4 Phase 3 — `Author.credits` 컬럼 + `CreditLog` 테이블 폐기 완료. 신 `CreditLedger` 단일 정본 박제. CC-4 sprint 전체 종결". qa(Evaluator)가 QA_REPORT.md에 종결 통과율 박제.

### CC-4 sprint 전체 종결 선언

- **Phase 1 종결**(5/21 박제): 구 메서드 시그니처/본문 제거 + admin·discovery 신·구 분열 해소 완료 (`1760e96`).
- **Phase 2 종결**(5/21 박제): `Payment.credits → Payment.points` 물리 rename + 案 Y RefundLog 보존 완료 (prod rev 104, `f9f85b4`).
- **Phase 3 종결**(본 계획 적용 후): `Author.credits` DROP + `CreditLog` 폐기 + 코드 잔존 5건 제거 + 파일/Port 삭제 + 案 P3-Y 옵션 A `/auth/me` 응답 정합 (prod rev 105 박제).
- **CC-4 sprint 전체 종결** = 크레딧 개편 코어 6 sprint (CC-1 + CC-2a + CC-2b + CC-3 + CC-4 Phase 1+2+3) 완전 종결. 크레딧 개편 코어 종결 시점 = **2026-05-21 또는 익일 prod rev 105 적용 시점**.

### CC-4 미해소 잔존 (범위 외 — 명시)

- HIGH-1 案 B 이행 = Case C 별도 sprint(`HIGH-1-CASE-B`) — CC-5와 병렬 가능.
- CC-5 PAY-P1-4 Polar 구독 연동 = 별도 sprint (CC-3 §4-2 案 A 후속).
- Phase 4 응답 일관성 정합 (선택) = `processNormalizedWebhook` 반환 `{ credits, deficitCredits }` → `{ points, deficitPoints }` 정합 — 외부 호환성 영향 평가 종속, 별도 sprint.
- sensor 7종 hook 등록 = harness agent 영역.
- PAY-S2/S3/S4 후속 sprint.

---

## 10. rollback 단위

- 각 sub-task는 git commit 단위 — P1·P2·P3·M1·F1·F2 별 commit 권장. 실패 시 해당 commit revert.
- **P1·P2·P3 단계** (코드 잔존 제거 + 파일/Port 삭제 + spec 정리): tsc/jest 실패 = 즉시 해당 commit 단위 롤백. DB 스키마 비변경 → 백업 불요.
- **M1 단계** (Prisma schema + 마이그레이션 SQL 작성): 코드는 commit revert. 마이그레이션 SQL 파일은 미적용 상태로 보존 가능.
- **F1 단계** (마이그레이션 apply — 비가역): pg_dump 백업 필수. dev apply 사후 검증 실패 시 — `psql -f backup-pre-phase3-dev-{ts}.sql` 복원. prod apply 실패 시 — 사용자 협력 + `psql -f backup-pre-phase3-prod-{ts}.sql` 복원 + Container revision 104 롤백 + 사후 검증 SQL 재실행. **DROP COLUMN + DROP TABLE은 비가역 → 백업 복원만 롤백 가능. 사전 검증 게이트 §5-1 통과 의무.**
- **F2 단계** (마무리 — 문서/sensor/web sync): 문서 commit revert. drift sensor 실패 시 docs sync 재실행.
- **案 P3-Y 옵션 A 회귀 시**: `auth.controller:48`에서 `credits: 0` 단순 폴백(옵션 B)으로 임시 회귀 가능 — single commit revert.

---

## 11. 변경 이력

- 2026-05-21: 본 계획 신설. CC-4 Phase 3 폐기 정리(S0 6 + 결정 게이트 2 + 코드 잔존 제거 5 + 파일/Port 삭제 5 + spec 정리 2 + Prisma schema + 마이그레이션 SQL 2 + 마이그레이션 apply 2 + 사후 검증 + 마무리 8 = 총 24 sub-task) writing-plans 양식 분해. 비가역 마이그레이션 안전성 분석(DROP COLUMN + DROP TABLE) + 응답 키 보존 결정 (案 P3-Y 권고) + 옵션 A 권고 (auth/me `credits` 필드 = `getBalance().total` 매핑) + web 핸드오프 분리(docs sync only, 案 P3-Y 옵션 A 보존으로 web 코드 변경 0건). 사용자 결정 게이트 = 0건 추가 (5/21 사전 키워드 통과 + 案 P3-Y 권고 채택으로 진행). cost-accountant 게이트 불요 (신규 AI 0건). visual-canon-keeper 불요 (server 한정, web 코드 0건). web 핸드오프 1건(F2g docs sync). harness 핸드오프 1건(F2h sensor 7종 hook 등록). CC-4 sprint 전체 종결 시점 = Phase 3 머지 = prod rev 105. 코드 변경 0건 — 계획 수립 전용.

---

## 12. 미확인 / 추정 금지 명시

| 항목 | 상태 | 해소 시점 |
|---|---|---|
| `Author.credits` / `author.credits` 사용처 file:line | **확인** — 본 계획 작성 중 grep(~10 파일 + ~15~20곳). S0a 현행 재실측 | S0a |
| `CreditLog` 사용처 file:line | **확인** — 본 계획 작성 중 grep(~6~8 파일). S0b 현행 재실측 | S0b |
| `credit_logs.author_id` FK 의존성 + DROP 순서 | **부분 확인** — schema.prisma:157 `onDelete: Restrict` 박제. S0c 본 sprint 진입 시 마이그레이션 SQL 정합 검증 (CASCADE 권고) | S0c |
| dev/prod `authors.credits` + `credit_logs` row 수 | **미확인** — 본 계획 작성 시 DB 미접속. S0d server agent sprint 진입 시 1회 측정 | S0d |
| web 측 `user.credits` / `author.credits` 참조 file:line | **확인** — 본 계획 작성 중 grep(`AuthUser.credits` + `PlatformNav` 헤더 + `admin authors` 테이블). S0e 현행 재실측 | S0e |
| webhook 응답 키 (`processNormalizedWebhook` 반환) 처리 결정 | **권고 = 案 P3-Y-a** (보존, Phase 2 박제 정합). S0f 본 sprint 진입 시 채택 박제 | S0f |
| `/auth/me` 응답 `credits` 필드 처리 결정 (案 P3-X/Y + 옵션 A/B/C) | **권고 = 案 P3-Y + 옵션 A** (server agent 채택 권고). §2 결정 게이트 | §2 결정 (server 채택 시점) |
| `CreditLedgerPort` 주입 필수 여부 (Phase 3 후 `Optional` → `Required` 검토) | **미확인** — 현재 credit.usecase에서 `Optional` 잔존 + 폴백 분기. P2c 정리 시 결정 (권고 = `Required`로 변경, 미주입 시 throw) | P2c |
| `refund-payment.usecase` 폴백 `authorRepo.findById` 사용 — `CreditLedgerPort` 주입 보장 시 폴백 제거 가능 여부 | **미확인** — P1c sub-task에서 `CreditLedgerPort` 주입 보장 검증 | P1c |
| sub-task 시간 추산 | 상대 추산 — 실측 아님. 본 계획은 분해 단위, 실제 시간은 server 실행 시 확정 | — |

> 본 계획은 코드 변경 0건 — 순수 계획 수립. 모든 file:line은 CREDIT_CORE_DIAGNOSIS 진단 리포트 + CC-1~CC-3 progress + CC-4 Phase 1·2 progress + 본 계획 작성 중 실제 Read(`schema.prisma`/`auth.controller.ts`/`refund-payment.usecase.ts`/`credit-migration.ts`/`prisma-author.repository.ts`/`prisma-credit.repository.ts`/`credit-repository.port.ts`/`credit.usecase.ts`/`admin.usecase.ts`/`shared-contracts.md §30`) + grep(`author\.credits` / `CreditLog` / `user\.credits` web 측 / `processNormalizedWebhook`) 기반. 미확인은 §12에 명시 — 추정 0건.
