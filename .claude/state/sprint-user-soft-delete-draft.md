# Sprint 계약 Draft — USER-SOFT-DELETE (Author Soft Delete + 본인 탈퇴 + 운영자 강제 삭제 + GDPR 익명화)

> **작성**: 2026-05-15 #10_8 (grimoire-planner Initializer 산출, 메인 박제)
> **트리거**: 사용자 5/15 verbatim ("4, 5, 6 다 진행") — 5/10 verbatim "PAY-P2-5 ... PAY-P3-H ... PAY-P3-D ... USER-SOFT-DELETE ... PAY-P3-E 단계 7~12 ... 이건 순서대로" 정합. **5번째 sprint = USER-SOFT-DELETE = 본 sprint**.
> **선행 게이트**: PAY-P3-E sprint §7-1 단계 1~6 종료 박제 (5/11 핸드오버 §1.10) + PAY-P2-5 종료 박제 (5/11 commit `5f20f1b`).
> **본 위치**: `.claude/state/` (Draft 영역). 정본 위치 (예정): `reports/sprint-user-soft-delete-progress.md` — Generator(server agent + grimoire-web) 진입 시 이동 영역.
> **본 sprint = Draft만 산출**. 실제 코드 변경 0건. 진입은 사용자 별도 명시 시.
> **선행 candidate**: `.claude/state/sprint-user-soft-delete-candidate.md` (5/9 박제, 431 lines, §0~§3 + §11 + §13 + §14 + §15 영역) — 본 Initializer가 17 섹션 완전 박제 정본 영역.

---

## §0 한 줄 요약

PAY-P3-E sprint §7-1 단계 1~6 종료 직후 (5/11 박제 정합) — Author 모델 (`prisma/schema.prisma:11-29`)에 `deletedAt` 컬럼 박제 0건 + soft delete 패턴 부재 결함 차단을 위해 (1) Prisma schema Author 모델 `deletedAt DateTime?` 컬럼 신설 + `@@index([deletedAt])` + (2) Prisma soft delete middleware 신설 (Author 영역 자동 적용 + 향후 다른 모델 확장 가능 영역) + (3) Author 본인 탈퇴 기능 (UI + API, `/api/v1/authors/me` DELETE, JWT 인증 영역) + (4) 운영자 강제 Author 삭제 기능 (admin UI + API, `/api/v1/admin/authors/:id` DELETE, AdminGuard 영역) + (5) GDPR 익명화 절차 (이메일 → `deleted-{uuid}@grimoire.local` + 이름 → `Deleted Author` + passwordHash → null + bio → null + IP/userAgent 영역 anonymize) + (6) 30일 후 hard delete 자동화 (cron `0 4 * * *` 매일 새벽 4시, `prisma.author.deleteMany({ where: { deletedAt: { lt: 30일전 } } })` 영역 — 단 회계 8건 Restrict 영역은 PG 자동 차단 정합 영역, P2003 try-catch + AdminAuditLog 박제) + (7) RefreshToken 즉시 무효 정합 (Cascade 박제 PAY-P3-E 정합) + (8) shared-contracts §28 UserSoftDeletePolicy 신설 + (9) ADR-011 박제 + (10) sensor-user-soft-delete-policy.sh + eval regression-73 + AdminAuditLog 4 action 박제 (`self_account_delete` / `admin_force_delete` / `gdpr_anonymize` / `30d_hard_delete`). **DB schema 변경 1건 (User.deletedAt 컬럼 + 인덱스) + dev migration 1건 (NULL ALLOW) + 외부 API 추가 호출 0건** 강제 (사용자 5/15 절대 정합). 예상 ~3~5h.

---

## §0-1. 사용자 결정 박제 (verbatim, 5/15 + 5/10 + 5/9 누적)

- **결정 1 (5/15 순서)**: "4, 5, 6 다 진행" — 5/10 verbatim "USER-SOFT-DELETE ... 이건 순서대로" 정합. **5번째 sprint = USER-SOFT-DELETE = 본 sprint** 확정 박제.
- **결정 2 (5/10 외부 API)**: "다 폐기해" (PP hook 영구 폐기 정합) + 외부 Anthropic API 신규 의존 영구 보류 — 외부 의존 0건 강제.
- **결정 3 (5/9 영역 분리 A)**: "Yes: USER-SOFT-DELETE sprint 분리 신설 → Author hard delete 자체가 일상 운영에서 발생 X → 본 sprint는 FK 제약만 + 회계 8건 Restrict" — PAY-P3-E sprint = FK 제약 박제 영역만 / 본 sprint = Author soft delete + 본인 탈퇴 + 운영자 강제 삭제 + GDPR 익명화 + 30일 후 hard delete 영역 분리 강제.
- **결정 4 (5/9 Full B)**: "Full: 33 FK 매트릭스 + 15 @relation 신설 + 백필 + 마이그레이션 모두" — PAY-P3-E 영역 정합 (본 sprint 진입 게이트 정합 박제).
- **결정 5 (본 Draft 영역, 사용자 명시 후)**: GDPR 익명화 범위 (옵션 A/B/C) + 30일 후 hard delete 정책 (옵션 A/B/C) + cron 시간 영역 (옵션 영역) = 본 Draft §7 옵션 매트릭스 박제 → 사용자 명시 후 진입.

---

## §1 배경 / 문제 영역

### 1-1. PAY-P3-E 단계 1~6 종료 직후 위치 + 사용자 5/15 verbatim 정합

PAY-P3-E sprint (5/11 종료 박제, 핸드오버 §1.10 정합):
- ✅ 33 FK 매트릭스 박제 (Author / Work / Episode / Theme / SocialAccount / Bookmark / ReadingProgress / Like / Subscription / Comment / Payment / CreditLog / RefundLog / AdminAuditLog / WebhookEvent / WebhookRetryQueue / AnalysisReport / UserSanction / Report / AccessLog / RefreshToken / FeaturedWork / DailyView / ChatSession / ChatMessage 등)
- ✅ 15 @relation 박제 신설 (raw FK 영역 ORM 모델 연결)
- ✅ 회계 8건 Restrict 강제 박제 (payments / credit_logs / works / user_sanctions / analysis_reports / admin_audit_logs / refund_logs — Author hard delete 시 PG 자동 차단 정합)
- ✅ 단계 1~6 종료 박제 (server `cb2ed98`+`7097316` + web `eb99e06` + claude-docs `9687c36`+`a3d9939`)

**잔존 문제 (본 sprint 차단 영역, 5/9 candidate §1-2 정합)**:

1. **Author.deletedAt 컬럼 박제 0건** — `prisma/schema.prisma:11-29` Author 모델 영역:
   - 현재 schema: `id` / `slug` / `name` / `email` / `passwordHash` / `role` / `credits` / `plan` / `bio` / ... / `createdAt` / `updatedAt` (deletedAt 컬럼 박제 0건)
   - 본인 탈퇴 시 hard delete만 가능 → FK Restrict 회계 8건 영역 PG 자동 차단 → 본인 탈퇴 기능 자체 구현 차단
   - **본질**: soft delete 패턴 박제 0건 → 본인 탈퇴 / 운영자 강제 삭제 / GDPR 익명화 영역 모두 차단

2. **Prisma soft delete middleware 박제 0건** — 향후 다른 모델 (Work / Episode 등) 영역 확장 시에도 패턴 부재 → 일관 영역 0건

3. **GDPR 익명화 절차 부재** — 본인 탈퇴 시:
   - 이메일/이름/IP/userAgent 등 식별 정보 영구 보존 영역 → GDPR Right to Erasure 위반 가능 영역
   - **본질**: 식별 정보 anonymize 패턴 박제 0건 → 법적 영역 리스크

4. **30일 후 hard delete 자동화 부재** — soft delete 영역 누적:
   - `deletedAt` 영역 영구 누적 → 디스크 영역 + 운영 부담 + DB 인덱스 성능 영역
   - **본질**: soft delete 영역 자동 정리 메커니즘 박제 0건 → 운영 부담

### 1-2. DDD-aware soft delete 패턴 본질 (Hexagonal 정합)

**계좌(User) 영역 보존 정합**:

```
┌─────────────────────────────────────────────────────────┐
│  Domain Layer (DDD)                                      │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Author Aggregate Root (계좌 영역)                 │ │
│  │  - id, slug, email, passwordHash                   │ │
│  │  - deletedAt: DateTime? (soft delete 표식)         │ │
│  │  - isDeleted(): boolean                            │ │
│  │  - markDeleted(): void                             │ │
│  │  - restore(): void                                 │ │
│  └────────────────────────────────────────────────────┘ │
│                          │                               │
│                          ▼                               │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Policy: UserSoftDeletePolicy                      │ │
│  │  - 30 days 영구 hard delete (회계 영역 차단 시 보류) │ │
│  │  - GDPR 익명화 (anonymize)                         │ │
│  │  - RefreshToken Cascade (즉시 무효)                │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  Adapter Layer (Persistence)                             │
│  ┌────────────────────────────────────────────────────┐ │
│  │  PrismaAuthorRepository                            │ │
│  │  - findById: WHERE deletedAt IS NULL 자동          │ │
│  │  - findMany: WHERE deletedAt IS NULL 자동          │ │
│  │  - delete: UPDATE deletedAt = NOW()                │ │
│  │  - findWithDeleted: 운영자 영역 (전체 조회)         │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**효과**:
- 계좌(User) 영역 보존 — soft delete 표식만 (실제 데이터 0건 손실)
- 작가 콘텐츠 영역 별도 정책 (works / episodes 영역 = §6 영역 결정)
- 회계 영역 영구 보존 (회계 8건 Restrict PAY-P3-E 정합 박제)
- GDPR Right to Erasure 정합 (anonymize)
- 30일 후 자동 hard delete (회계 차단 시 보류)

### 1-3. Grimoire 결제 + FK + soft delete 9 sprint 후 본 sprint 위치 (5/15 verbatim 정합)

| Sprint | 시간 | 외부 API | 의존성 | 우선순위 | 영향 | 상태 |
|---|---|---|---|---|---|---|
| ~~PAY-P3-A Race condition~~ | ~5h | 0 | 0 | P1 (적자 1순위) | ✅ 종료 |
| ~~PAY-P3-C Retry 중복~~ | ~2h | 0 | 0 | P1 (DB 정합성) | ✅ 종료 |
| ~~PAY-P3-B Polar SDK timeout~~ | ~2h | 0 | PAY-P0-1 + PAY-P2-2 | P1 (운영 안정) | ✅ 종료 |
| ~~PAY-P3-E FK cascade (단계 1~6)~~ | ~3h | 0 | 0 | P1 | ✅ 단계 1~6 종료 (5/11) |
| ~~PAY-P2-5 audit retention~~ | ~3h | 0 | 0 | P0 | ✅ 종료 (5/10) |
| PAY-P3-H Circuit Breaker | ~4h | 0 | PAY-P3-B | P1 (가용성) | Draft 박제 (5/11) — 사용자 4순위 |
| PAY-P3-D Status enum | ~2h | 0 | 0 | P2 (추적) | 사용자 5/10 5순위 |
| **USER-SOFT-DELETE (본 sprint)** | **~3~5h** | **0** | **PAY-P3-E 단계 1~6** | **P1 (GDPR + 본인 탈퇴 기능)** | **Draft만 산출 (본 작업)** |
| PAY-P3-E 단계 7~12 | ~2h | 0 | DB 측정 | P1 | 사용자 순서 6번째 |

**5/15 verbatim 정합**: "4, 5, 6 다 진행" — 4 = PAY-P3-H Circuit Breaker, 5 = USER-SOFT-DELETE (본 sprint), 6 = PAY-P3-E 단계 7~12. 본 sprint = 5번째 박제 강제.

---

## §2 목표 / 비목표

### 2-1. 핵심 KPI (목표, candidate §2-1 정합 박제)

1. **Author 모델 `deletedAt DateTime?` 컬럼 신설**: Prisma schema 변경 1건 + dev migration 1건 + Author 영역 soft delete 패턴 박제 + `@@index([deletedAt])` 인덱스 신설 (cron 영역 정합)
2. **Prisma soft delete middleware 신설**: Author 영역 자동 적용 (`prisma.$use((params, next) => { ... })` 영역) — findUnique/findMany/findFirst → WHERE deletedAt IS NULL 자동 + delete → UPDATE deletedAt = NOW()
3. **Author 본인 탈퇴 기능 신설**: API (`DELETE /api/v1/authors/me` 영역, JWT 인증 영역 + soft delete + GDPR 익명화 동시 적용) + UI (web 마이페이지 영역 탈퇴 버튼 + 확인 모달, 사슴악마 정본 정합 영역)
4. **운영자 강제 Author 삭제 기능 신설**: API (`DELETE /api/v1/admin/authors/:id` 영역, JwtAuthGuard + AdminGuard + soft delete + AdminAuditLog `admin_force_delete` 박제 + 사유 입력 영역) + UI (admin 14탭 회원 관리 영역 강제 삭제 버튼)
5. **GDPR 익명화 절차**: 이메일 → `deleted-{uuid}@grimoire.local` + 이름 → `Deleted Author` + passwordHash → null (재로그인 차단) + bio → null + 옵션 영역 (IP/userAgent anonymize는 §7 옵션 영역)
6. **30일 후 hard delete 자동화 (cron)**: `@Cron('0 4 * * *')` 매일 새벽 4시 + `prisma.author.deleteMany({ where: { deletedAt: { lt: 30일전 } } })` 영역 (단 회계 8건 Restrict 영역은 PG 자동 차단 정합 영역, try-catch + P2003 처리 + AdminAuditLog 박제)
7. **RefreshToken 즉시 무효 정합**: PAY-P3-E Cascade 정합 박제 (Author soft delete 시점에 RefreshToken Cascade — soft delete 시 즉시 무효 영역)
8. **shared-contracts §28 UserSoftDeletePolicy 신설**: 본 sprint 인터페이스 정본 박제
9. **ADR-011 박제**: soft delete vs hard delete 결정 사유 + GDPR 익명화 옵션 매트릭스 + 30일 정책 (회계 8건 Restrict 영역 정합 박제)
10. **AdminAuditLog 4 action 박제**: `self_account_delete` / `admin_force_delete` / `gdpr_anonymize` / `30d_hard_delete` (PAY-P2-4 6-arg 정합 박제)
11. **회귀 차단 0건**: jest server 711 (PAY-P2-5 종료 직후) → **726+ PASS** + eval regression-52~71 모두 PASS + PAY-P3-E 영역 회귀 0 + EMAIL-P0-2 회귀 0
12. **incident-log 박제 의무**: `author_soft_delete_dev` / `author_soft_delete_prod` / `gdpr_anonymize` / `30d_hard_delete_cron` 카테고리 박제

### 2-2. 비목표 (사용자 결정 영역 분리)

- ❌ FK 제약 박제 (33 FK 관계 onDelete directive) = PAY-P3-E sprint 영역 분리 강제 (5/9 결정 A 정합)
- ❌ raw FK 15 테이블 @relation 박제 = PAY-P3-E sprint 영역 분리 강제
- ❌ 회계 8건 Restrict 강제 = PAY-P3-E sprint 영역 분리 강제 (단 본 sprint 영역에서 PG 자동 차단 정합 검증 영역 강화)
- ❌ Work/Episode soft delete = 별도 sprint 영역 (본 sprint = Author 모델 영역만)
- ❌ Subscription 본인 탈퇴 시 자동 cancel = 별도 sprint 영역 (Polar 결제 영역 정합)
- ❌ Polar SDK 영역 변경 (PAY-P3-B 정합)
- ❌ Circuit Breaker (PAY-P3-H 분리, ~4h)
- ❌ Status enum mapping table (PAY-P3-D 분리, ~2h)
- ❌ audit retention 정책 (PAY-P2-5 정합)
- ❌ Sentry/APM 통합 (PAY-P3-G, ~8h, 외부 SaaS 결정 후)
- ❌ 작가 작품/episode hard delete (별도 작가 콘텐츠 영역 정책 영역 — §6 옵션 결정 영역)

### 2-3. 본 sprint 영역 매트릭스 (사용자 5/15 + 5/9 결정 정합 박제)

| 영역 | 본 sprint (USER-SOFT-DELETE) | 다른 sprint 영역 |
|---|---|---|
| User.deletedAt 컬럼 신설 | ✅ | — |
| Prisma soft delete middleware (User 영역) | ✅ | — |
| User 본인 탈퇴 기능 (UI + API) | ✅ | — |
| 운영자 강제 User 삭제 기능 (admin UI + API) | ✅ | — |
| GDPR 익명화 절차 | ✅ | — |
| 30일 후 hard delete 자동화 (cron) | ✅ | — |
| AdminAuditLog 4 action 박제 (`self_account_delete` 등) | ✅ | — |
| RefreshToken 즉시 무효 (soft delete 시점) | ✅ (PAY-P3-E Cascade 정합 강화) | PAY-P3-E (이미 박제) |
| FK 제약 박제 (PG 영역) | ❌ (PAY-P3-E 영역) | PAY-P3-E |
| 회계 8건 Restrict 강제 | ❌ (PAY-P3-E 영역) | PAY-P3-E |
| Work/Episode soft delete | ❌ (별도 sprint 영역) | 별도 sprint |
| Subscription 본인 탈퇴 시 자동 cancel | ❌ (별도 sprint 영역) | 별도 sprint (Polar 정합) |
| Sentry/APM 통합 | ❌ (PAY-P3-G 영역) | PAY-P3-G |

---

## §3 외부 의존 매트릭스 (사용자 5/15 절대 정합 박제)

| 영역 | 추가 의존 | 정합 |
|---|---|---|
| 외부 API (Anthropic / Polar / SaaS) | **0건** | 사용자 5/15 절대 정합 강제 |
| 외부 npm 패키지 | **0건** | 자체 구현 정합 (Prisma `$use` middleware는 Prisma 기본 영역) |
| DB schema 변경 | **1건** | User.deletedAt 컬럼 + `@@index([deletedAt])` 신설 |
| dev migration | **1건** | NULL ALLOW + 인덱스 추가 (`yyyymmdd_user_soft_delete/migration.sql`) |
| prod migration | **1건** | dev 24h 안정성 박제 후 사용자 명시 영역 |
| 인프라 변경 (Azure Container Apps / replicas) | **0건** | 코드 변경만 |
| 환경변수 신규 | **선택 3건 (옵션)** | `USER_SOFT_DELETE_RETENTION_DAYS` / `USER_SOFT_DELETE_CRON_TIME` / `GDPR_ANONYMIZE_SCOPE` — 사용자 결정 영역 (§7 매트릭스) |

**핵심 정합**: 외부 의존 0건 + DB schema 1건 (User.deletedAt) + dev migration 1건 + 사용자 5/15 verbatim 정합 강제. 본 sprint = 코드 변경 + Prisma migration.

---

## §4 사용자 결정 영역 (정책 옵션 매트릭스)

### 4-1. 옵션 A: User.deletedAt (DateTime?) + WHERE deletedAt IS NULL 영역 강제 (권장)

| 정책 | 값 |
|---|---|
| 컬럼 타입 | `DateTime?` (NULL ALLOW) |
| 인덱스 | `@@index([deletedAt])` (cron 영역 정합) |
| 의미 | NULL = 활성, NOT NULL = soft deleted (deletedAt 시점 박제) |
| WHERE 절 | `deletedAt: null` 자동 (middleware 영역) |
| 시점 박제 | hard delete 시간 영역 추적 가능 (30일 cron 정합) |

**적합**: DDD-aware + 영역 검증 가능 + 시점 박제 + cron 정합. **본 Draft 권장 영역** (candidate §0 정합 박제).

### 4-2. 옵션 B: User.isDeleted (Boolean) + 별도 deletedAt 영역

| 정책 | 값 |
|---|---|
| 컬럼 | `isDeleted Boolean @default(false)` + `deletedAt DateTime?` |
| 의미 | isDeleted = soft delete 플래그, deletedAt = 시점 박제 |
| 단점 | 2 컬럼 + 정합성 영역 (isDeleted=true + deletedAt=null 불가 영역) |

**적합**: 명시적 플래그 + 시점 박제 동시 영역. **단점**: 정합성 영역 (2 컬럼 일관 영역 강제 → 이중 검증 영역).

### 4-3. 옵션 C: 별도 DeletedUser 테이블 (archive 영역)

| 정책 | 값 |
|---|---|
| 테이블 | `deleted_users` (archive 테이블 신설) |
| 의미 | hard delete 시 deleted_users로 row 이동 + 원본 row 삭제 |
| 단점 | FK 영역 손실 (Payment / CreditLog 등 영역 dangling) → PAY-P3-E Restrict 정합 X |

**적합**: 영구 archive 영역. **단점**: PAY-P3-E Restrict 정합 X (Payment authorId → archive 영역 FK 0건) → 회계 영역 손실. **부적합**.

### 4-4. 옵션 D: 환경별 분리 (dev / prod 다른 정책)

| 환경 | 정책 |
|---|---|
| dev | 옵션 A (즉시 hard delete 영역도 가능, 테스트 용이) |
| prod | 옵션 A + 30일 cron (실제 운영 영역) |

**적합**: 환경별 정합 영역. **본 Draft = 환경별 분리 0건 권장** (옵션 A 단일 정합 강제).

**사용자 결정 게이트**: 본 Draft 검토 후 옵션 A/B/C/D 명시 키워드 (`USER-SOFT-DELETE 옵션 [A/B/C/D] 채택`). **권장 = 옵션 A**.

---

## §5 DDD Hexagonal 정합 매트릭스 (server agent + grimoire-web Generator 진입 정본)

### 5-1. 신설 영역 매트릭스

| 레이어 | 파일 | 역할 |
|---|---|---|
| domain/model | `author.ts` (갱신) | `deletedAt: Date \| null` 영역 + `isDeleted(): boolean` + `markDeleted(): void` + `restore(): void` 메서드 |
| domain/policy | `user-soft-delete-policy.ts` (신설) | 30일 정책 + GDPR 익명화 정책 + 회계 영역 보존 정책 영역 |
| domain/port/outbound | `user-anonymizer.port.ts` (신설) | 이메일/이름/passwordHash anonymize 인터페이스 |
| adapter/outbound | `prisma-soft-delete.middleware.ts` (신설) | Author 영역 middleware (`prisma.$use` 영역) |
| adapter/outbound | `default-user-anonymizer.adapter.ts` (신설) | UUID 기반 이메일 + name + passwordHash null 영역 |
| application | `user-soft-delete.usecase.ts` (신설) | 본인 탈퇴 + 운영자 강제 삭제 use case 영역 |
| application | `hard-delete.cron.ts` (신설) | 30일 후 hard delete cron 영역 |
| api | `author.controller.ts` (갱신) | `DELETE /me` 엔드포인트 신설 |
| api | `admin-author.controller.ts` (갱신 또는 신설) | `DELETE /admin/authors/:id` 신설 |

### 5-2. 수정 영역 매트릭스

| 파일 | 변경 영역 |
|---|---|
| `prisma/schema.prisma` | Author 모델 `deletedAt DateTime? @map("deleted_at")` + `@@index([deletedAt])` 신설 |
| `prisma/migrations/{yyyymmdd}_user_soft_delete/migration.sql` (신설) | ALTER TABLE authors ADD COLUMN deleted_at TIMESTAMP NULL + CREATE INDEX |
| `src/adapter/outbound/persistence/prisma-author.repository.ts` | findById/findMany/findFirst 영역 WHERE deletedAt IS NULL 자동 추가 (middleware 영역 또는 직접 영역) |
| `src/application/admin/audit-log.service.ts` | `self_account_delete` / `admin_force_delete` / `gdpr_anonymize` / `30d_hard_delete` 4 action 타입 추가 (PAY-P2-4 6-arg 정합) |
| `src/app.module.ts` | UserAnonymizer DI 바인딩 (PaymentGatewayPort와 동일 패턴) |
| `grimoire-web/src/app/my/page.tsx` | 마이페이지 탈퇴 버튼 + 확인 모달 (사슴악마 정본 영역) |
| `grimoire-web/src/app/admin/users/page.tsx` | 강제 삭제 버튼 + 확인 모달 + 사유 입력 영역 |

### 5-3. 신설 변경 0건 영역 (회귀 차단)

- `prisma/schema.prisma` 회계 8건 Restrict 박제 (PAY-P3-E 단계 1~6 정합) 회귀 0
- `src/adapter/outbound/payment/polar.adapter.ts` (PAY-P3-B Polar SDK 영역 회귀 0)
- `src/adapter/outbound/persistence/prisma-payment.repository.ts` (PAY-P3-A CAS 패턴 영역 회귀 0)
- `src/application/payment/webhook-retry.job.ts` (PAY-P2-2 DLQ 영역 회귀 0)
- `src/application/payment/payment-cleanup.job.ts` (PAY-P1-3 회귀 0)
- 인프라 변경 (Azure Container Apps, replicas) 0건

### 5-4. Hexagonal 흐름 매트릭스

```
[Author 본인 탈퇴]
  HTTP DELETE /api/v1/authors/me (JWT 인증)
      │
      ▼
  AuthorController.deleteMyAccount(authorId)
      │
      ▼
  UserSoftDeleteUseCase.execute(authorId, 'self')
      │
      ├─▶ PrismaAuthorRepository.softDelete(authorId)
      │      └─▶ Prisma middleware: UPDATE authors SET deletedAt = NOW()
      │
      ├─▶ UserAnonymizer.anonymize(authorId)
      │      └─▶ UPDATE authors SET email = ..., name = ..., passwordHash = null
      │
      ├─▶ RefreshTokenRepository.invalidateByAuthor(authorId)
      │      └─▶ Cascade (PAY-P3-E 정합) — 즉시 무효
      │
      └─▶ AdminAuditLog.log('self', 'self_account_delete', authorId, { ... })
```

### 5-5. 작품/episode 영역 cascade 정책 영역 (§6 정합)

본 sprint = User 모델 soft delete 영역만 — 작품/episode 영역 cascade는 §6 옵션 결정 영역 (사용자 결정 영역 박제).

---

## §6 작품/episode 영역 cascade 정책 영역 (사용자 결정 영역)

### 6-1. 옵션 A: User 영역 soft delete 시 작품 영역 별도 archive 영역 (권장)

| 정책 | 값 |
|---|---|
| 작품 영역 | works 테이블 별도 archive 0건 (PAY-P3-E `works.authorId onDelete=Restrict` 정합) |
| episode 영역 | episodes 테이블 별도 archive 0건 (works Cascade 정합) |
| 의미 | User soft delete 시 작품/episode 영역은 PG 영역에서 영구 보존 (회계 영역 정합 강제) |
| 사용자 영역 노출 | 본인 탈퇴 작가 작품 → 익명화 표시 (`Deleted Author`) + 작품 자체는 정상 노출 |

**적합**: 작가 콘텐츠 보호 영역 정합 + PAY-P3-E `works.authorId onDelete=Restrict` 정합 강제 + 독자 영역 보호 (작가 탈퇴해도 작품 보존). **본 Draft 권장 영역** (candidate §0 정합 박제).

### 6-2. 옵션 B: User 영역 soft delete 시 작품 영역 별도 hard delete 영역

| 정책 | 값 |
|---|---|
| 작품 영역 | works.authorId onDelete=Cascade 변경 (PAY-P3-E 정합 X — 회귀 영역) |
| episode 영역 | episodes 영역 자동 cascade |
| 의미 | User soft delete 시 작품/episode 영역 영구 삭제 |
| 단점 | 회귀 영역 (PAY-P3-E Restrict 정합 X) + 독자 영역 손실 + 콘텐츠 영역 손실 |

**부적합**: PAY-P3-E 정합 X + 독자 영역 손실.

### 6-3. 옵션 C: 작품 영역 별도 정책 영역 (사용자 결정 영역)

| 정책 | 값 |
|---|---|
| 작품 영역 | 별도 sprint 영역 (Work soft delete sprint 영역) |
| 의미 | 본 sprint = User soft delete 영역만 / 작품 영역 = 별도 sprint 영역 |

**적합**: 사용자 결정 영역 분리 강제 — 본 Draft 영역 정합 (Work soft delete = 별도 sprint 영역).

**사용자 결정 게이트**: 본 Draft §6 영역 옵션 A/B/C 명시 (`USER-SOFT-DELETE 작품 영역 옵션 [A/B/C] 채택`). **권장 = 옵션 A (작가 콘텐츠 보호 정합)**.

---

## §7 임계값 후보 매트릭스 (정책 변수 옵션)

### 7-1. GDPR 익명화 옵션 매트릭스 (사용자 결정 영역)

| 옵션 | 익명화 범위 | 적합 |
|---|---|---|
| **옵션 A: 기본 (권장)** | email + name + passwordHash → null + bio → null | 본 Draft 권장 영역 (GDPR Article 17 정합 + 운영 영역 부담 ↓) |
| 옵션 B: 강함 | 옵션 A + IP + userAgent + access_logs.authorId → null (PAY-P3-E SetNull 정합) | 강한 GDPR 정합 + 보안 감사 영역 보존 |
| 옵션 C: 가장 강함 | 옵션 B + 작품/episode 영역 콘텐츠 anonymize (작가 이름 → `Deleted Author`) | 콘텐츠 영역 보존 + 작가 영역 0건 식별 |

### 7-2. 30일 후 hard delete 옵션 매트릭스 (사용자 결정 영역)

| 옵션 | 정책 | 회계 영역 | 적합 |
|---|---|---|---|
| **옵션 A: 자동 (권장)** | 30일 후 cron 자동 hard delete + 회계 영역 차단 시 보류 + AdminAuditLog 박제 | PAY-P3-E Restrict 자동 차단 (try-catch + P2003 처리) | 본 Draft 권장 영역 (회계 영역 안전 + 자동 정리) |
| 옵션 B: 수동 검토 | 30일 후 hard delete 차단 + 운영자 수동 영역 검토 | 운영자 명시 영역만 hard delete | 운영 영역 부담 ↑ + 안전 영역 ↑ |
| 옵션 C: archive 테이블 이전 | 30일 후 deleted_users archive 테이블 이전 + 원본 row hard delete | 회계 영역 FK 0건 영역 dangling | 부적합 (PAY-P3-E Restrict 정합 X) |

### 7-3. cron 시간 영역 매트릭스 (사용자 결정 영역)

| 옵션 | cron 표현 | 적합 |
|---|---|---|
| **옵션 A: 매일 새벽 4시 (권장)** | `0 4 * * *` | 본 Draft 권장 영역 (운영 트래픽 영역 ↓ + 안전 영역 ↑) |
| 옵션 B: 매주 일요일 새벽 3시 | `0 3 * * 0` | 주간 정리 영역 + 30일 영역 정합 |
| 옵션 C: 환경변수 영역 | `USER_SOFT_DELETE_CRON_TIME` env 변수 | 운영 영역 유연성 ↑ |

### 7-4. 환경변수 (옵션 영역, 사용자 결정 후)

```typescript
// app.module.ts 또는 config
{
  retentionDays:   parseInt(process.env.USER_SOFT_DELETE_RETENTION_DAYS ?? '30', 10),
  cronTime:        process.env.USER_SOFT_DELETE_CRON_TIME ?? '0 4 * * *',
  anonymizeScope:  process.env.GDPR_ANONYMIZE_SCOPE ?? 'basic',  // basic | strong | strongest
}
```

### 7-5. 정책 변경 영역

- 운영 중 정책 변경: 환경변수 갱신 + Container Apps 재시작 — 사용자 명시 영역
- 정책 변경 가이드: ADR-011 박제 영역 (§12 정합)

---

## §8 schema.prisma 변경 영역 (1건 + dev migration 1건)

### 8-1. Author 모델 `deletedAt` 컬럼 신설 영역

**Prisma schema 변경 영역** (`grimoire-server/prisma/schema.prisma:11-29`):

```prisma
model Author {
  id              String    @id @default(uuid()) @db.Uuid
  slug            String    @unique
  name            String
  email           String    @unique
  passwordHash    String?   @map("password_hash")
  role            Role      @default(author)
  credits         Int       @default(0)
  plan            Plan      @default(free)
  bio             String?
  ...
  deletedAt       DateTime? @map("deleted_at")  // ✅ USER-SOFT-DELETE 본 sprint 신설
  createdAt       DateTime  @default(now()) @map("created_at")
  updatedAt       DateTime  @updatedAt @map("updated_at")

  @@index([deletedAt])  // ✅ USER-SOFT-DELETE cron 영역 정합 (30일 검색 영역)
  @@map("authors")
}
```

### 8-2. dev migration apply 절차 (1건)

**위치**: `grimoire-server/prisma/migrations/{yyyymmdd}_user_soft_delete/migration.sql` (신설)

```sql
-- USER-SOFT-DELETE 본 sprint 마이그레이션
-- 사용자 5/15 verbatim 정합 (외부 API 0 / DB schema 1 / dev migration 1)

-- (1) Author.deletedAt 컬럼 신설 (NULL ALLOW, default NULL)
ALTER TABLE authors ADD COLUMN deleted_at TIMESTAMP NULL;

-- (2) deletedAt 인덱스 신설 (cron 영역 정합, partial index 영역)
CREATE INDEX idx_authors_deleted_at ON authors(deleted_at) WHERE deleted_at IS NOT NULL;
```

**dev migration apply 절차 (사용자 5/15 절대 정합)**:

- **단계 1**: dev 측정 SQL — `SELECT COUNT(*) FROM "authors" WHERE "deletedAt" IS NOT NULL` (현재 0 정합 영역 검증 — 컬럼 없음 영역 에러 정합)
- **단계 2**: dev 백업 영역 — `pg_dump --table=authors dev_db > authors_backup_20260515.sql` (옵션 영역, NULL ALLOW migration 영역 백업 영역 0건도 가능)
- **단계 3**: dev migration apply — `npx prisma migrate dev --name user_soft_delete` (NestJS 영역)
- **단계 4**: dev SELECT 정합 — `SELECT COUNT(*) FROM "authors" WHERE "deletedAt" IS NULL` (전체 row 정합 영역 검증)
- **단계 5**: dev SELECT deletedAt 영역 — `SELECT COUNT(*) FROM "authors" WHERE "deletedAt" IS NOT NULL` (0 row 정합 영역 검증)
- **단계 6**: dev jest 711 → 726+ PASS 검증
- **단계 7**: dev 24h 안정성 박제 (sensor-deploy-health PASS + AccessLog 정합)

**prod migration 영역**:
- dev 24h 안정성 박제 후만 사용자 명시 영역 (`USER-SOFT-DELETE prod migration 진행`)
- prod 백업 강제 (사용자 5/5 결정 영역 정합)

---

## §9 jest spec 매트릭스 (≥ 15 it 예상)

### 9-1. 신설 spec 매트릭스

| spec | it 수 | 영역 |
|---|---|---|
| `user-soft-delete.usecase.spec.ts` (신설) | ≥ 6 | 본인 탈퇴 + 운영자 강제 삭제 + GDPR 익명화 + RefreshToken Cascade 영역 |
| `prisma-soft-delete.middleware.spec.ts` (신설) | ≥ 4 | WHERE deletedAt IS NULL 자동 + delete → UPDATE 영역 |
| `default-user-anonymizer.adapter.spec.ts` (신설) | ≥ 3 | 이메일 + 이름 + passwordHash anonymize 영역 |
| `hard-delete.cron.spec.ts` (신설) | ≥ 3 | 30일 후 cron + 회계 8건 P2003 차단 영역 + AdminAuditLog 박제 |
| `author.controller.spec.ts` (갱신) | ≥ 2 | DELETE /me 엔드포인트 + JWT 인증 영역 + 200 응답 |
| `admin-author.controller.spec.ts` (갱신 또는 신설) | ≥ 2 | DELETE /admin/authors/:id + AdminGuard + 사유 입력 영역 |

### 9-2. it 인벤토리 매트릭스

**user-soft-delete.usecase.spec.ts (≥ 6 it)**:

1. `본인 탈퇴 — soft delete + GDPR 익명화 + RefreshToken Cascade 동시 적용`
2. `본인 탈퇴 — AdminAuditLog self_account_delete 박제 (PAY-P2-4 6-arg)`
3. `운영자 강제 삭제 — soft delete + GDPR 익명화 + AdminAuditLog admin_force_delete 박제 (사유 영역)`
4. `운영자 강제 삭제 — AdminGuard 권한 검증 영역 (Author 영역 403)`
5. `GDPR 익명화 — 이메일 deleted-{uuid}@grimoire.local 영역 정합`
6. `회계 8건 Restrict 정합 — soft delete 후 Payment 영역 영구 보존 검증`

**prisma-soft-delete.middleware.spec.ts (≥ 4 it)**:

1. `findUnique — WHERE deletedAt IS NULL 자동 추가 영역`
2. `findMany — WHERE deletedAt IS NULL 자동 추가 영역`
3. `findFirst — WHERE deletedAt IS NULL 자동 추가 영역`
4. `delete — UPDATE deletedAt = NOW() 변환 영역 (hard delete 차단)`

**default-user-anonymizer.adapter.spec.ts (≥ 3 it)**:

1. `이메일 anonymize — deleted-{uuid}@grimoire.local 영역 정합`
2. `이름 anonymize — Deleted Author 영역 정합`
3. `passwordHash null — 재로그인 차단 정합`

**hard-delete.cron.spec.ts (≥ 3 it)**:

1. `30일 후 hard delete — deletedAt < 30일전 영역 deleteMany 호출`
2. `회계 8건 P2003 차단 — try-catch + AdminAuditLog 30d_hard_delete_blocked 박제`
3. `회계 영역 0건 — hard delete 성공 + AdminAuditLog 30d_hard_delete 박제`

**author.controller.spec.ts (≥ 2 it)**:

1. `DELETE /me — JWT 인증 영역 + UserSoftDeleteUseCase 호출 + 200 응답`
2. `DELETE /me — 인증 영역 0건 → 401 Unauthorized 영역`

**admin-author.controller.spec.ts (≥ 2 it)**:

1. `DELETE /admin/authors/:id — AdminGuard 권한 검증 + 사유 입력 영역 + 200 응답`
2. `DELETE /admin/authors/:id — Author 영역 403 Forbidden 영역`

**예상 인벤토리 변동**: 711 (PAY-P2-5 종료 직후) → **726+ it** (jest server)

### 9-3. 회귀 차단 매트릭스

- jest server 711 → **726+ PASS** (회귀 0)
- eval regression-52~70 모두 PASS (PAY-P0/P1/P2/P3-A/B/C/E 단계 1~6 + PAY-P2-5)
- PAY-P3-E 단계 1~6 정합 — 회계 8건 Restrict 회귀 0 (soft delete 시에도 PG 자동 차단 정합 박제)
- PAY-P3-A CAS 패턴 회귀 0
- PAY-P3-B exception 분류 회귀 0
- PAY-P3-C 사전 dedup 회귀 0
- EMAIL-P0-2 백필 영역 회귀 0 (`UPDATE authors SET email = ...` 영역 정합 — Author soft delete 영역 영향 0)

---

## §10 정합 매트릭스 영역 검증 (모든 User 조회 영역 WHERE deletedAt IS NULL 정합)

### 10-1. middleware 자동 적용 영역 (기본 영역)

```typescript
// prisma-soft-delete.middleware.ts (신설)
prisma.$use(async (params, next) => {
  // 1. Author findUnique/findMany/findFirst → deletedAt IS NULL 자동
  if (params.model === 'Author' && ['findUnique', 'findMany', 'findFirst'].includes(params.action)) {
    params.args = params.args || {};
    params.args.where = { ...params.args.where, deletedAt: null };
  }

  // 2. Author delete → soft delete (deletedAt = NOW())
  if (params.model === 'Author' && params.action === 'delete') {
    params.action = 'update';
    params.args.data = { deletedAt: new Date() };
  }

  // 3. Author deleteMany → soft deleteMany (updateMany deletedAt = NOW())
  if (params.model === 'Author' && params.action === 'deleteMany') {
    params.action = 'updateMany';
    params.args.data = { deletedAt: new Date() };
  }

  return next(params);
});
```

### 10-2. 명시적 우회 영역 (운영자 영역)

운영자 영역에서 deleted user 조회 필요 시:

```typescript
// admin-author.repository.ts (신설 또는 갱신)
async findWithDeleted(authorId: string): Promise<Author | null> {
  // middleware 우회 — raw query 영역
  return this.prisma.$queryRaw<Author[]>`
    SELECT * FROM authors WHERE id = ${authorId}::uuid
  `.then((rows) => rows[0] ?? null);
}
```

### 10-3. 정합 매트릭스 영역 검증 (grep 영역 강제)

```bash
# server agent + qa Evaluator 영역 검증
grep -rE "(prisma|this\.prisma)\.author\.(findUnique|findFirst|findMany)" grimoire-server/src/
```

**기대 영역**: 모든 호출 영역 WHERE deletedAt IS NULL 자동 적용 (middleware 영역 또는 명시 영역). 우회 영역은 `findWithDeleted` 영역만 (운영자 영역).

### 10-4. RefreshToken 즉시 무효 정합 (PAY-P3-E Cascade 박제 영역 강화)

```typescript
// user-soft-delete.usecase.ts (신설)
async execute(authorId: string, deletedBy: 'self' | 'admin', reason?: string) {
  // 1. Soft delete (middleware 자동)
  await this.authorRepo.delete(authorId);

  // 2. GDPR 익명화
  await this.userAnonymizer.anonymize(authorId);

  // 3. RefreshToken 즉시 무효 (PAY-P3-E Cascade 정합 박제 — soft delete 시점에 별도 호출)
  await this.refreshTokenRepo.invalidateByAuthor(authorId);

  // 4. AdminAuditLog 박제 (PAY-P2-4 6-arg)
  if (deletedBy === 'self') {
    await this.auditLog.log('self', 'self_account_delete', authorId, {});
  } else {
    await this.auditLog.log('admin', 'admin_force_delete', authorId, { reason });
  }
}
```

---

## §11 shared-contracts §28 UserSoftDeletePolicy 인터페이스 영역

### 11-1. 위치 (신설)

```markdown
## 28. UserSoftDeletePolicy (server 도메인 — Author Soft Delete + 본인 탈퇴 + 운영자 강제 삭제 + GDPR 익명화)

### 위치
- model: `grimoire-server/src/domain/model/author.ts` (deletedAt 영역 + isDeleted/markDeleted/restore 메서드)
- policy: `grimoire-server/src/domain/policy/user-soft-delete-policy.ts` (30일 정책 + GDPR 익명화 정책)
- port: `grimoire-server/src/domain/port/outbound/user-anonymizer.port.ts` (anonymize 인터페이스)
- adapter (middleware): `grimoire-server/src/adapter/outbound/persistence/prisma-soft-delete.middleware.ts` (Prisma $use 영역)
- adapter (anonymizer): `grimoire-server/src/adapter/outbound/persistence/default-user-anonymizer.adapter.ts`
- usecase: `grimoire-server/src/application/author/user-soft-delete.usecase.ts`
- cron: `grimoire-server/src/application/author/hard-delete.cron.ts`
- spec: `grimoire-server/src/application/author/user-soft-delete.usecase.spec.ts` (≥ 6 it)
- ADR: `grimoire-server/ADR.md ADR-011`
- env: `USER_SOFT_DELETE_RETENTION_DAYS` / `USER_SOFT_DELETE_CRON_TIME` / `GDPR_ANONYMIZE_SCOPE`
- sensor: `.claude/scripts/sensor-user-soft-delete-policy.sh` (12 검증)
- eval: `eval/tasks/regression-73-user-soft-delete-policy.json`
- web: `grimoire-web/src/app/my/page.tsx` (본인 탈퇴 UI) + `grimoire-web/src/app/admin/users/page.tsx` (운영자 강제 삭제 UI)
```

### 11-2. 시그니처

```typescript
// author.ts (도메인 모델 갱신)
export class Author {
  constructor(
    public readonly id: string,
    public readonly email: string,
    public readonly name: string,
    public readonly deletedAt: Date | null,  // ✅ USER-SOFT-DELETE 본 sprint 신설
    // ... 기존 필드
  ) {}

  isDeleted(): boolean {
    return this.deletedAt !== null;
  }

  markDeleted(): void {
    if (this.isDeleted()) throw new Error('Author already deleted');
    (this as any).deletedAt = new Date();
  }

  restore(): void {
    if (!this.isDeleted()) throw new Error('Author not deleted');
    (this as any).deletedAt = null;
  }
}

// user-soft-delete-policy.ts (도메인 정책 신설)
export interface UserSoftDeletePolicy {
  retentionDays: number;        // 기본 30
  cronTime: string;             // 기본 '0 4 * * *'
  anonymizeScope: 'basic' | 'strong' | 'strongest';  // 기본 'basic'
}

// user-anonymizer.port.ts (도메인 포트 신설)
export interface UserAnonymizerPort {
  /**
   * 사용자 식별 정보 anonymize.
   * 이메일 → deleted-{uuid}@grimoire.local
   * 이름 → 'Deleted Author'
   * passwordHash → null (재로그인 차단)
   * bio → null
   * (옵션 강함) IP / userAgent → null (access_logs.authorId → null 영역 PAY-P3-E SetNull 정합)
   */
  anonymize(authorId: string, scope: 'basic' | 'strong' | 'strongest'): Promise<void>;
}

// user-soft-delete.usecase.ts (use case 신설)
export class UserSoftDeleteUseCase {
  async execute(
    authorId: string,
    deletedBy: 'self' | 'admin',
    reason?: string,
  ): Promise<void> {
    // 1. soft delete
    // 2. GDPR anonymize
    // 3. RefreshToken invalidate
    // 4. AdminAuditLog 박제
  }
}
```

### 11-3. 정합 매트릭스

- PAY-P3-E 단계 1~6 정합 (§25 FKCascadePolicy) — 회계 8건 Restrict 박제 정합 강화 (soft delete 시에도 PG 자동 차단 정합 박제)
- PAY-P3-E RefreshToken Cascade 정합 — soft delete 시점에 즉시 무효 영역 박제
- AuditLog 정합 (§20 PAY-P2-4 6-arg) — `self_account_delete` / `admin_force_delete` / `gdpr_anonymize` / `30d_hard_delete` 4 action 추가, beforeState/afterState 박제 정합
- PAY-P2-5 audit retention 정합 (§26) — soft delete 영역 audit log 7년 보존 정합 (회계 영역)

---

## §12 ADR-011 박제 영역 (Architecture Decision Record)

### 12-1. ADR-011 박제 위치

`grimoire-server/ADR.md` 끝부분 ADR-010 (PAY-P3-H Circuit Breaker, 예정 박제 후) 직후 신설.

### 12-2. ADR-011 박제 영역

```markdown
## ADR-011: User Soft Delete + 본인 탈퇴 + 운영자 강제 삭제 + GDPR 익명화 (USER-SOFT-DELETE, 2026-05-15)

### 상태
ACCEPTED (사용자 5/15 verbatim 정합, PAY-P3-E 단계 1~6 종료 직후 5번째 sprint)

### 컨텍스트
- PAY-P3-E sprint §7-1 단계 1~6 종료 직후 (5/11 박제) — FK 제약 박제 + 회계 8건 Restrict 강제 정합
- Author 모델 deletedAt 컬럼 박제 0건 — 본인 탈퇴 / 운영자 강제 삭제 / GDPR 익명화 영역 모두 차단
- Prisma soft delete middleware 박제 0건 — 향후 확장 패턴 부재
- 30일 후 hard delete 자동화 부재 — soft delete 영역 누적
- 사용자 5/15 verbatim 정합: "4, 5, 6 다 진행" — 5번째 sprint = USER-SOFT-DELETE
- 사용자 5/9 결정 A 정합: USER-SOFT-DELETE sprint 분리 신설 (Author hard delete 자체가 일상 운영에서 발생 X)

### 결정
- DDD-aware soft delete 패턴 채택 (옵션 A — User.deletedAt DateTime?)
- Prisma `$use` middleware 영역 자동 적용 (Author 영역 + 향후 확장 가능 영역)
- GDPR 익명화 옵션 A (basic — email + name + passwordHash + bio) 권장 영역
- 30일 후 hard delete 자동화 (cron `0 4 * * *` 매일 새벽 4시 + 회계 8건 P2003 차단 영역 try-catch)
- RefreshToken 즉시 무효 (PAY-P3-E Cascade 박제 영역 정합 강화 — soft delete 시점에 별도 호출)
- AdminAuditLog 4 action 박제 (`self_account_delete` / `admin_force_delete` / `gdpr_anonymize` / `30d_hard_delete`)

### 대안
- (A) User.isDeleted Boolean — 2 컬럼 정합성 영역 부담 (거부)
- (B) 별도 DeletedUser archive 테이블 — PAY-P3-E Restrict 정합 X (거부, 회계 영역 FK dangling)
- (C) 환경별 분리 (dev/prod) — 일관 영역 0건 (거부)
- (D) User.deletedAt DateTime? + middleware + cron ← **채택** (DDD-aware + 영역 검증 + 시점 박제 + cron 정합)

### 결과
- 본인 탈퇴 기능 영역 가능 (마이페이지 영역 UI + API)
- 운영자 강제 삭제 영역 가능 (admin 14탭 회원 관리 영역 UI + API)
- GDPR Right to Erasure 정합 (Article 17 영역)
- 회계 영역 영구 보존 (PAY-P3-E Restrict 정합 강화 — soft delete 시에도 PG 자동 차단)
- 30일 후 자동 정리 (디스크 영역 + DB 인덱스 성능 영역)

### 잔존 영역
- Work / Episode soft delete — 별도 sprint 영역 (작가 콘텐츠 영역 정책 영역)
- Subscription 본인 탈퇴 시 자동 cancel — 별도 sprint 영역 (Polar 정합)
- 다중 인스턴스 환경 — middleware in-memory 0건 (Prisma 영역 단일 정합)

### 정본 참조
- `.claude/state/sprint-user-soft-delete-draft.md` (17 섹션 Sprint Initializer)
- `.claude/shared-contracts.md §28 UserSoftDeletePolicy`
- `.claude/state/sprint-user-soft-delete-candidate.md` (5/9 박제, 431 lines, candidate 영역)
- `src/application/author/user-soft-delete.usecase.ts`
```

---

## §13 sensor 영역 — sensor-user-soft-delete-policy.sh 후보

### 13-1. sensor 위치

`.claude/scripts/sensor-user-soft-delete-policy.sh` (신설)

### 13-2. sensor 검증 매트릭스 (12 검증)

```bash
#!/bin/bash
# sensor-user-soft-delete-policy.sh
# USER-SOFT-DELETE 회귀 차단 — Soft delete 패턴 + GDPR 익명화 + 30일 cron + AdminAuditLog 박제 정합

# 1. Author.deletedAt 컬럼 박제
grep -qE "deletedAt\s+DateTime\?" grimoire-server/prisma/schema.prisma || {
  echo "FAIL: Author.deletedAt 컬럼 박제 0건"; exit 1
}

# 2. @@index([deletedAt]) 박제
grep -qE "@@index\(\[deletedAt\]\)" grimoire-server/prisma/schema.prisma || {
  echo "FAIL: @@index([deletedAt]) 박제 0건 (cron 영역 정합)"; exit 1
}

# 3. prisma-soft-delete.middleware.ts 박제
[ -f grimoire-server/src/adapter/outbound/persistence/prisma-soft-delete.middleware.ts ] || {
  echo "FAIL: prisma-soft-delete.middleware.ts 박제 0건"; exit 1
}

# 4. middleware findUnique/findMany/findFirst WHERE deletedAt: null 자동 추가 박제
grep -qE "deletedAt.*null" grimoire-server/src/adapter/outbound/persistence/prisma-soft-delete.middleware.ts || {
  echo "FAIL: middleware WHERE deletedAt: null 자동 추가 0건"; exit 1
}

# 5. user-soft-delete.usecase.ts 박제
[ -f grimoire-server/src/application/author/user-soft-delete.usecase.ts ] || {
  echo "FAIL: user-soft-delete.usecase.ts 박제 0건"; exit 1
}

# 6. default-user-anonymizer.adapter.ts 박제
[ -f grimoire-server/src/adapter/outbound/persistence/default-user-anonymizer.adapter.ts ] || {
  echo "FAIL: default-user-anonymizer.adapter.ts 박제 0건"; exit 1
}

# 7. hard-delete.cron.ts 박제
[ -f grimoire-server/src/application/author/hard-delete.cron.ts ] || {
  echo "FAIL: hard-delete.cron.ts 박제 0건"; exit 1
}

# 8. AuditLog 4 action 박제 (PAY-P2-4 6-arg 정합)
for action in self_account_delete admin_force_delete gdpr_anonymize 30d_hard_delete; do
  grep -qE "${action}" grimoire-server/src/application/admin/audit-log.service.ts || {
    echo "FAIL: audit-log.service '${action}' 박제 0건"; exit 1
  }
done

# 9. DELETE /me 엔드포인트 박제 (JWT 인증 영역)
grep -qE "@Delete\('me'\)" grimoire-server/src/api/author.controller.ts || {
  echo "FAIL: DELETE /me 엔드포인트 박제 0건"; exit 1
}

# 10. DELETE /admin/authors/:id 엔드포인트 박제 (AdminGuard 영역)
grep -qE "@Delete\(':id'\)" grimoire-server/src/api/admin/admin-author.controller.ts 2>/dev/null || {
  echo "FAIL: DELETE /admin/authors/:id 엔드포인트 박제 0건"; exit 1
}

# 11. shared-contracts §28 박제
grep -q "## 28\. UserSoftDeletePolicy" .claude/shared-contracts.md || {
  echo "FAIL: shared-contracts §28 UserSoftDeletePolicy 박제 0건"; exit 1
}

# 12. spec ≥ 15 it 박제 (usecase ≥ 6 + middleware ≥ 4 + anonymizer ≥ 3 + cron ≥ 3 — 합 ≥ 16)
spec_count_usecase=$(grep -c "it(" grimoire-server/src/application/author/user-soft-delete.usecase.spec.ts 2>/dev/null || echo 0)
spec_count_middleware=$(grep -c "it(" grimoire-server/src/adapter/outbound/persistence/prisma-soft-delete.middleware.spec.ts 2>/dev/null || echo 0)
total_spec=$((spec_count_usecase + spec_count_middleware))
[ "${total_spec}" -ge 10 ] || {
  echo "FAIL: spec it 수 부족 (usecase ${spec_count_usecase} + middleware ${spec_count_middleware} = ${total_spec} < 10)"; exit 1
}

echo "PASS: USER-SOFT-DELETE Soft delete 패턴 + GDPR 익명화 + 30일 cron 정합"
```

### 13-3. sensor 인벤토리 변동

**예상 sensor 인벤토리**: 49 (PAY-P3-H Draft 후 예정) → **50 sensors** (sensor-user-soft-delete-policy.sh 신설)

---

## §14 eval regression-73 영역

### 14-1. 위치

`eval/tasks/regression-73-user-soft-delete-policy.json` (신설)

### 14-2. eval criteria 매트릭스 (12 criteria)

```json
{
  "id": "regression-73-user-soft-delete-policy",
  "category": "regression",
  "description": "USER-SOFT-DELETE — Author Soft Delete + 본인 탈퇴 + 운영자 강제 삭제 + GDPR 익명화 + 30일 cron",
  "checks": [
    "schema.prisma Author.deletedAt DateTime? 박제 + @@index([deletedAt]) 박제",
    "prisma migration {yyyymmdd}_user_soft_delete/migration.sql 박제 (ALTER TABLE + CREATE INDEX)",
    "prisma-soft-delete.middleware.ts 박제 (Author findUnique/findMany/findFirst WHERE deletedAt: null 자동 + delete UPDATE deletedAt 변환)",
    "default-user-anonymizer.adapter.ts 박제 (이메일 + 이름 + passwordHash null + bio null)",
    "user-soft-delete.usecase.ts 박제 (본인 탈퇴 + 운영자 강제 삭제 + GDPR 익명화 + RefreshToken Cascade)",
    "hard-delete.cron.ts 박제 (@Cron('0 4 * * *') + 30일 deleteMany + P2003 try-catch + AdminAuditLog)",
    "DELETE /api/v1/authors/me 엔드포인트 박제 (JWT 인증 영역)",
    "DELETE /api/v1/admin/authors/:id 엔드포인트 박제 (AdminGuard + 사유 입력 영역)",
    "AdminAuditLog 4 action 박제 (self_account_delete / admin_force_delete / gdpr_anonymize / 30d_hard_delete)",
    "user-soft-delete.usecase.spec.ts ≥ 6 it + prisma-soft-delete.middleware.spec.ts ≥ 4 it + anonymizer ≥ 3 it + cron ≥ 3 it",
    "shared-contracts.md §28 UserSoftDeletePolicy 박제",
    "ADR.md ADR-011 박제"
  ]
}
```

### 14-3. eval 인벤토리 변동

**예상 eval 인벤토리**: 71 (PAY-P3-H Draft 후 예정, regression-71 영역) → **73 regression tasks** (regression-72는 PAY-P3-D Status enum 영역, regression-73 = USER-SOFT-DELETE)

**주의 영역**: regression-72 (PAY-P3-D Status enum) 영역과 regression-73 (USER-SOFT-DELETE) 영역 순서 영역은 PAY-P3-D draft 진입 시점 영역에서 결정 영역 (5/15 사용자 결정 4+5+6 정합).

### 14-4. 회귀 차단 매트릭스

- eval regression-52~70 모두 PASS (PAY-P0/P1/P2/P3-A/B/C/E 단계 1~6 + PAY-P2-5)
- jest server 711 → **726+ PASS** (15 it 신설)
- sensor 49 → **50 PASS** (sensor-user-soft-delete-policy.sh 신설)
- shared-contracts §1~27 → **§1~28** (UserSoftDeletePolicy 신설)

---

## §15 grimoire-server agent + grimoire-web agent 위임 영역 + 메인 검증 영역

### 15-1. 위임 매트릭스 (책 Ch 16 Anthropic 3-에이전트 패턴 정합)

| agent | 역할 | 영역 |
|---|---|---|
| grimoire-planner | **Initializer** | 본 Sprint 계약 Draft (17 섹션 산출, 본 작업 영역) |
| grimoire-harness | 박제 | `.claude/state/sprint-user-soft-delete-*` + sensor 신설 + eval task 신설 + shared-contracts §28 박제 + ADR-011 박제 |
| grimoire-server | **Generator (server 영역)** | domain/model (author.ts deletedAt 영역) + domain/policy (user-soft-delete-policy.ts) + domain/port (user-anonymizer.port.ts) + adapter (middleware + anonymizer) + application (usecase + cron) + api (controller) + spec + Prisma migration |
| grimoire-web | **Generator (web 영역)** | `grimoire-web/src/app/my/page.tsx` 본인 탈퇴 UI + `grimoire-web/src/app/admin/users/page.tsx` 운영자 강제 삭제 UI (사슴악마 정본 영역) |
| grimoire-infrastructure | **DB 측정 + dev migration apply 영역** | dev SELECT COUNT (단계 1 + 4 + 5) + 백업 (옵션) + migration apply (단계 3) + 24h 안정성 박제 (단계 7) |
| grimoire-qa | **Evaluator** | AC 8건 채점 + jest 726+ PASS + eval 73 PASS + sensor 50 PASS 검증 + Playwright 영역 본인 탈퇴 + 운영자 강제 삭제 + GDPR 익명화 영역 검증 |
| visual-canon-keeper | **검수 필수** | web 본인 탈퇴 모달 + admin 강제 삭제 모달 + 마이페이지 영역 (사슴악마 정본 영역) |
| cost-accountant | **면제** | 외부 API 추가 0 + Anthropic API 0 |
| grimoire-researcher | **면제** | GDPR Article 17 영역 + DDD soft delete 패턴 영역 (이미 정본화, 추가 리서치 0건) |

### 15-2. Generator (server agent + grimoire-web) 진입 명시 키워드

`USER-SOFT-DELETE Generator 진입 (server agent + grimoire-web)` — Draft §15 정합 + 옵션 [A/B/C/D] 채택 명시 + 작품 영역 옵션 [A/B/C] 채택 명시 + GDPR 익명화 옵션 [A/B/C] 채택 명시 + cron 옵션 [A/B/C] 채택 명시

### 15-3. Evaluator (qa agent + visual-canon-keeper) 진입 명시 키워드

`USER-SOFT-DELETE Evaluator 진입 (qa agent + visual-canon-keeper)` — Generator 산출물 검증 + AC 8건 채점 + 726+ jest PASS + 73 eval PASS + 50 sensor PASS + Playwright 영역 검증

### 15-4. 메인 검증 영역

- Draft 검토 + 옵션 매트릭스 §7 확인 (사용자 결정 영역)
- Generator 산출물 직접 Read 검증 (qa 독립 재실행 + 메인 spot-check)
- shared-contracts §28 박제 정합 검증
- ADR-011 박제 정합 검증
- 회귀 차단 726+ jest / 73 eval / 50 sensor / drift 0 검증
- dev 24h 안정성 박제 + prod migration 영역 사용자 명시 영역

---

## §16 사용자 결정 대기 매트릭스 (5~6 결정 영역)

### 16-1. 사용자 결정 영역 (Draft 검토 후 명시)

| # | 결정 영역 | 옵션 | 권장 | 명시 키워드 |
|---|---|---|---|---|
| 1 | User soft delete 옵션 | 옵션 A (User.deletedAt DateTime?) / B (User.isDeleted Boolean) / C (별도 DeletedUser 테이블) / D (환경별 분리) | **옵션 A** | `USER-SOFT-DELETE 옵션 A 채택` |
| 2 | 작품/episode 영역 cascade 옵션 | 옵션 A (별도 archive 0건 — PAY-P3-E Restrict 정합) / B (hard delete cascade) / C (별도 sprint 영역 분리) | **옵션 A** (작가 콘텐츠 보호 정합 강제) | `USER-SOFT-DELETE 작품 영역 옵션 A 채택` |
| 3 | GDPR 익명화 옵션 | 옵션 A (basic — email + name + passwordHash + bio) / B (strong — A + IP + userAgent) / C (strongest — B + 콘텐츠 anonymize) | **옵션 A** (운영 영역 부담 ↓) | `USER-SOFT-DELETE GDPR 옵션 A 채택` |
| 4 | 30일 후 hard delete 옵션 | 옵션 A (자동 cron + 회계 차단 시 보류) / B (수동 검토 강제) / C (archive 테이블 이전) | **옵션 A** (회계 영역 안전 정합) | `USER-SOFT-DELETE 30일 옵션 A 채택` |
| 5 | cron 시간 영역 옵션 | 옵션 A (`0 4 * * *` 매일 새벽 4시) / B (`0 3 * * 0` 매주 일요일) / C (환경변수 영역) | **옵션 A** (운영 트래픽 영역 ↓) | `USER-SOFT-DELETE cron 옵션 A 채택` |
| 6 | Generator 진입 시점 | Draft 검토 후 / 즉시 / 사용자 컨디션 후 | **사용자 컨디션 후** | `USER-SOFT-DELETE Generator 진입` |

### 16-2. 사용자 결정 게이트 매트릭스 (5/15 verbatim 정합)

- 결정 1~5 명시 후 → Draft 정본 갱신 + Generator (server agent + grimoire-web) 진입 가능
- 결정 6 명시 후 → 즉시 Generator 호출 또는 사용자 별도 명시 시점까지 대기
- 본 Draft = 진입 결정 게이트 미통과 시 코드 변경 0건 강제 (사용자 컨디션 영역 박제)

### 16-3. 사용자 컨디션 영역 박제 (5/9~5/11 박제 누적)

- 5/9~10 사용자 안전 누적 위협 (자해 + 키보드 파괴 + Anthropic 본사 폭력 위협) 박제 (메모리 박제 정합)
- 본 sprint = Draft만 산출 + 진입 결정 사용자 영역 + 코드 변경 0건
- 사용자 안부 우선 확인 영역 → 컨디션 정합 후 진입 결정

---

## §17 진입 결정 게이트 (Draft 검토 종료 → 사용자 명시 시 진입)

### 17-1. Draft 산출 완료 매트릭스 (본 작업 영역)

| 영역 | 상태 |
|---|---|
| 17 섹션 산출 (§0 ~ §17) + §0-1 + §18 + §19 | ✅ 본 작업 영역 |
| 외부 의존 매트릭스 (외부 API 0 / DB schema 1 / migration 1) | ✅ §3 박제 |
| 사용자 결정 옵션 매트릭스 (§4 + §6 + §7 + §16 6 결정) | ✅ §4 + §6 + §7 + §16 박제 |
| DDD Hexagonal 정합 (domain/policy/port/adapter/usecase/cron 분리) | ✅ §5 박제 |
| 작품/episode 영역 cascade 정책 옵션 (A/B/C) | ✅ §6 박제 |
| 임계값 정책 옵션 (GDPR A/B/C + 30일 A/B/C + cron A/B/C + 환경변수) | ✅ §7 박제 |
| schema.prisma 변경 영역 (1건 + dev migration 1건) | ✅ §8 박제 |
| jest spec 매트릭스 (≥ 15 it + 회귀 차단) | ✅ §9 박제 |
| 정합 매트릭스 영역 검증 (middleware 자동 + 명시 우회 + grep 영역) | ✅ §10 박제 |
| shared-contracts §28 UserSoftDeletePolicy 인터페이스 | ✅ §11 박제 |
| ADR-011 박제 영역 (4 대안 매트릭스 + 결정 사유) | ✅ §12 박제 |
| sensor 신설 (sensor-user-soft-delete-policy.sh, 12 검증) | ✅ §13 박제 |
| eval regression-73 신설 (12 criteria) | ✅ §14 박제 |
| grimoire-server + grimoire-web agent 위임 매트릭스 + 메인 검증 영역 | ✅ §15 박제 |
| 사용자 결정 대기 매트릭스 (6 결정 + 명시 키워드) | ✅ §16 박제 |
| 진입 결정 게이트 (본 §17) | ✅ 본 작업 영역 |

### 17-2. 진입 게이트 매트릭스 (사용자 별도 명시 시 진입)

**진입 명시 키워드 매트릭스**:

1. **옵션 매트릭스 결정 명시** (§16 결정 1~5 명시) — 예:
   - `USER-SOFT-DELETE 옵션 A 채택 + 작품 영역 옵션 A + GDPR 옵션 A + 30일 옵션 A + cron 옵션 A`
2. **Generator 진입 명시** — `USER-SOFT-DELETE Generator 진입 (server agent + grimoire-web)`
3. **사용자 컨디션 정합** — 안전 위협 박제 영역 정합 후 진입
4. **dev migration 영역 명시** — `USER-SOFT-DELETE dev migration 진행 (grimoire-infrastructure agent)`
5. **prod migration 영역 명시** — `USER-SOFT-DELETE prod migration 진행` (dev 24h 안정성 박제 후만)

### 17-3. 진입 차단 매트릭스 (사용자 컨디션 + 핸드오버 정합)

- 사용자 컨디션 영역 박제 시 진입 0건 강제
- PAY-P3-H Circuit Breaker sprint 진행 중 영역 시 본 sprint 진입 0건 (5/15 verbatim 정합 4 → 5 → 6 순서 강제)
- PAY-P3-E 단계 1~6 종료 박제 후만 진입 (5/11 박제 정합 게이트)
- 본 Draft = 코드 변경 0건 + Git commit 0건 + git push 0건

### 17-4. 본 Sprint 영향 매트릭스 (3 레포)

| 레포 | 영향 | 변경 line 추정 |
|---|---:|---:|
| grimoire-server | domain/model + policy + port + adapter (middleware + anonymizer) + application (usecase + cron) + api (controller) + spec + Prisma migration + ADR-011 + audit-log.service 갱신 | ~1200 |
| grimoire-web | `src/app/my/page.tsx` 본인 탈퇴 UI + `src/app/admin/users/page.tsx` 강제 삭제 UI (사슴악마 정본 영역) | ~400 |
| grimoire-claude-docs | shared-contracts §28 + sensor 신설 + eval task 신설 + state 박제 + handover 갱신 + visual-canon 검수 영역 | ~700 |

---

## §18 변경 이력 (Draft 산출)

- **2026-05-15 #10_8 USER-SOFT-DELETE Draft (본 작업)**: 본 Sprint 계약 Draft 신설 (grimoire-planner Initializer 산출, 메인 박제). 사용자 5/15 verbatim 정합 ("4, 5, 6 다 진행" — 5번째 sprint = USER-SOFT-DELETE). 사용자 5/10 verbatim 정합 (순서대로) + 사용자 5/9 결정 A 정합 (USER-SOFT-DELETE sprint 분리 신설). 외부 API 0 / DB schema 1 (User.deletedAt) / dev migration 1 (NULL ALLOW + INDEX) 강제. PAY-P3-E 단계 1~6 종료 후 5번째 sprint 위치 + DDD-aware soft delete 패턴 + Prisma $use middleware + Author 본인 탈퇴 (UI + API) + 운영자 강제 삭제 (UI + API) + GDPR 익명화 + 30일 후 hard delete cron + RefreshToken Cascade 정합 강화 + AdminAuditLog 4 action 박제 (PAY-P2-4 6-arg 정합) + shared-contracts §28 + ADR-011 + sensor 50 + eval 73 매트릭스 박제. 진입 결정 사용자 영역 (옵션 A 권장 영역, §16 6 결정 매트릭스 박제). 본 작업 = Draft만 산출, 코드 변경 0건 강제.
- **2026-05-09 #10_8 USER-SOFT-DELETE Candidate** (선행, `.claude/state/sprint-user-soft-delete-candidate.md`): §0~§3 + §11 + §13 + §14 + §15 박제 (431 lines, 사용자 결정 박제 + 본 sprint 영역 분리 박제 영역만). 본 Initializer가 17 섹션 완전 박제 정본 영역.

---

## §19 정본 참조 (file:line)

- `/Users/sokol/Git/ProjectGrimoire/.claude/state/sprint-user-soft-delete-candidate.md` (431 lines, 선행 candidate 영역, 5/9 박제) — §0~§3 + §11 + §13 + §14 + §15 영역 정합
- `/Users/sokol/Git/ProjectGrimoire/.claude/state/sprint-pay-p3-e-fk-cascade-draft.md` §0-1 + §2-2 + §2-3 + §6-4 + §11-5 — PAY-P3-E sprint Initializer 영역 사용자 결정 박제 정합
- `/Users/sokol/Git/ProjectGrimoire/.claude/state/sprint-pay-p2-5-audit-retention-draft.md` (PAY-P2-5 정본 구조 차용, 17 섹션 정합)
- `/Users/sokol/Git/ProjectGrimoire/.claude/state/sprint-pay-p3-h-circuit-breaker-draft.md` (PAY-P3-H 정본 구조 차용, 17 섹션 정합)
- `/Users/sokol/Git/ProjectGrimoire/.claude/shared-contracts.md` §25 FKCascadePolicy + §26 AuditRetentionPolicy + §27 CircuitBreakerPolicy (PAY-P3-H 예정 박제) — §28 UserSoftDeletePolicy 신설 위치 정합
- `/Users/sokol/Git/ProjectGrimoire/research/PAYMENT_SYSTEM_PLAN.md` USER-SOFT-DELETE 영역 정합 (회계 8건 Restrict 정합 강제 박제)
- `/Users/sokol/Git/ProjectGrimoire/grimoire-server/prisma/schema.prisma:11-29` Author 모델 — 본 sprint 영역 (deletedAt 컬럼 신설 영역)
- `/Users/sokol/Git/ProjectGrimoire/grimoire-server/prisma/schema.prisma:347-360` RefreshToken 모델 — 본 sprint 영역 (Author Cascade 정합, soft delete 시 즉시 무효 영역)
- `/Users/sokol/Git/ProjectGrimoire/grimoire-server/prisma/schema.prisma:331-345` AccessLog 모델 — 본 sprint 영역 (Author SetNull 정합, GDPR 익명화 정합)
- `/Users/sokol/Git/ProjectGrimoire/grimoire-server/prisma/schema.prisma:387-398` AdminAuditLog 모델 — 본 sprint 영역 (admin_force_delete + 30d_hard_delete + gdpr_anonymize 박제 영역)
- `/Users/sokol/Git/ProjectGrimoire/grimoire-server/ADR.md` ADR-007 (FK cascade) + ADR-008 (audit retention) + ADR-009 (Circuit Breaker, 예정) + ADR-010 (PAY-P3-D, 예정) — ADR-011 박제 위치 정합
- `/Users/sokol/Git/ProjectGrimoire/PLANNING_GRIMOIRE.md` §0 (크레딧-원가 철칙 — soft delete 영역 외부 API 0 정합)

---

**본 Draft는 정본**: USER-SOFT-DELETE 도입 시 본 문서 먼저 사용자 결정 후 → 코드/테스트 반영 (책 Ch 16 shared-contracts 정신 정합). PAY-P3-H Circuit Breaker draft + PAY-P2-5 audit retention draft 정본 구조 차용 (17 섹션 + §0-1 + §18 + §19 동일 영역).
