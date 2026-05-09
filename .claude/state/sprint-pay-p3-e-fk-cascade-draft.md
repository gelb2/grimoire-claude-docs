# Sprint PAY-P3-E — FK Cascade 정책 (모순-F 차단, Draft, PP-13 화이트리스트 영역)

> **작성**: 2026-05-09 #10_8 본 세션 grimoire-planner agent (Initializer 역할, 책 Ch 16 Anthropic 3-에이전트 패턴 정합)
> **트리거**: 사용자 명시 (5/9) — "잔여 과제 진행" + "이거 디비 백필, 마이그레이션 섣불리 하면 위험하니, 세부계획 철저히 세워서 계획검증 먼저 하고, 그 다음이 구현 시작" (Auto mode 활성). PAY-P3-A + PAY-P3-C + PAY-P3-B 종료 직후 Phase 1 네 번째 sprint. 마스터 플랜 §3-1 Phase 1 권장 순서 정합.
> **본 위치**: `.claude/state/` (PP-13 메인 화이트리스트 우회 영역). 정본 영역 (`reports/sprint-pay-p3-e-fk-cascade-progress.md`)으로 사용자 검증 게이트 통과 후 grimoire-server agent 위임 후 이동 영역.
> **정본 위치 (예정)**: `reports/sprint-pay-p3-e-fk-cascade-progress.md` — Initializer 산출물, Generator(server agent + grimoire-infrastructure)가 본 progress.md 갱신, Evaluator(qa)가 채점 대상 영역.
> **본 sprint 핵심 사용자 명시 (2026-05-09)**: **계획검증 먼저, 그 다음 구현**. 본 Initializer 단계 = 계획 산출만. Generator (server 코드 + DB 마이그레이션) 진입 절대 금지 (사용자 검증 게이트 §7 통과 후만).

---

## §0 한 줄 요약

PAYMENT_AUDIT §1 모순-F (FK cascade 미정의 — Author 삭제 시 Payment / CreditLog / RefundLog / AdminAuditLog / WebhookEvent / WebhookRetryQueue / Work / Episode / Theme / SocialAccount / RefreshToken / AccessLog / AnalysisReport / Bookmark / ReadingProgress / Like / Subscription / Comment / ChatSession / UserSanction / Report 등 22 테이블 영향) 차단을 위해 (1) Prisma schema 모든 FK 관계 `onDelete` directive 명시 (4 전략: `Cascade` / `Restrict` / `SetNull` / `NoAction` — 도메인 의미 + 보존 정책 + 감사 정합 기준 결정) + (2) **사용자 명시 핵심 — DB 백필 위험 분석 §6 정밀화 (시나리오 A/B/C + 옵션 A/B/C + dev → prod 순서 + rollback 절차)** + (3) shared-contracts §25 FKCascadePolicy 신설 + (4) ADR-007 결정 박제 + (5) data-model.md FK 매트릭스 갱신 + (6) sensor-fk-cascade-policy.sh 신설 + (7) eval/tasks/regression-69 신설. 본 sprint = 계획 산출만 (Generator 진입 = 사용자 검증 게이트 통과 후). 예상 ~3h (계획 ~1h, 구현 ~2h, 단 사용자 검증 시간 별도). DB schema 변경 1건 (마이그레이션 1건) + 외부 API 추가 호출 0건 + 의존성 0건.

### §0-1 사용자 결정 박제 (2026-05-09 직접 발화 raw 인용)

> **결정 A**: "Yes: USER-SOFT-DELETE sprint 분리 신설 → Author hard delete 자체가 일상 운영에서 발생 X → 본 sprint는 FK 제약만 + 회계 8건 Restrict"
> **결정 B**: "Full: 33 FK 매트릭스 + 15 @relation 신설 + 백필 + 마이그레이션 모두"
> **명시**: "이렇게 진행"

**본 sprint 영역 명확화**:
- ✅ **본 sprint Full 영역 진행**: 33 FK 매트릭스 + 15 @relation 신설 + 백필 + 마이그레이션 (결정 B 정합)
- ✅ **회계 8건 Restrict 강제**: payments / credit_logs / works / user_sanctions / analysis_reports / admin_audit_logs / refund_logs — Author hard delete 시 PG가 자동 차단 (즉 본 sprint = FK 제약 박제만으로 hard delete 차단 영역 정합)
- ❌ **Author hard delete 자체 차단 영역 = USER-SOFT-DELETE sprint 분리 영역** (결정 A 정합, 일상 운영에서 hard delete 자체 발생 X)
- 📝 **USER-SOFT-DELETE candidate 박제 위치**: `.claude/state/sprint-user-soft-delete-candidate.md` (본 sprint 후속 후보 영역)

---

## §1 배경 — PAYMENT_AUDIT §1 모순-F raw 인용 + 메인 정밀 검증 + 영향 범위 분석

### 1-1. 모순-F raw 인용 (PAYMENT_AUDIT §1 L29-30)

> | **모순-F** FK cascade 미정의: Author 삭제 시 Payment/CreditLog 고아 | 데이터 정합성 + EMAIL-P0-2 SQL 백필에서 발견 (works.author_id_fkey 위반) | `schema.prisma:11-29` Author model `onDelete` directive 부재 | `onDelete: Cascade` 또는 `Restrict` 선택 + 문서화 | P1 |

추가 — 마스터 플랜 §3-1 Phase 1 권장:

> 4. **PAY-P3-E (FK cascade 정책, ~3h)** — 모순 F, EMAIL-P0-2 백필 충돌 영역, DB 스키마 안정화

### 1-2. EMAIL-P0-2 백필 충돌 raw (incident-log L73 직접 인용, 2026-05-07)

> EMAIL-P0-2 dev SQL 백필 성공 — UPDATE 전략 (DELETE 대신, FK 제약 회피). authors @grimoire.app → @example.com + social_accounts 동일 + 백업 authors_backup_20260507 생성. 회귀 검증 PASS (잔존 0).

추가 (incident-log L73 prod 검증, 2026-05-08):

> prod EMAIL-P0-2 SQL UPDATE 백필 성공 (사용자 명시 정확 매칭) — Script executed successfully + 회귀 검증 PASS (authors + social_accounts 잔존 0). dev SQL과 동일 (백업명만 _prod). prod firewall rule temp-claude-prod-* 정리.

**결정적 결함 (메인 직접 검증)**: EMAIL-P0-2 백필 시 `DELETE FROM authors` 대신 `UPDATE authors SET email = ...` 영역으로 우회한 사유 = `works.author_id_fkey` FK 제약 위반 차단. 즉 **현재 schema는 Author 삭제 자체를 차단** (FK Restrict 묵시 동작 — Prisma 기본값) — 그러나 schema에 `onDelete` directive **명시 0건** → 의도 불명확 + 향후 schema 변경 시 회귀 위험 + 모든 FK 관계 정책 미확정 영역.

### 1-3. 메인 정밀 검증 — Prisma schema 모든 FK 관계 직접 grep 매트릭스 (실측, 22 테이블)

**`grimoire-server/prisma/schema.prisma` 직접 grep 결과** (`@relation(...)` + `@map("..._id")` 모두):

| # | 테이블 | FK 컬럼 | 참조 모델 | `@relation` 박제 | 현재 `onDelete` | 도메인 의미 |
|---|---|---|---|---|---|---|
| 1 | `themes` (L31-48) | `authorId` (Optional) | Author | ✅ L33 | ❌ 미정의 | 작가 테마 (작가 삭제 시 → Author=null 유지 vs 삭제 결정 필요) |
| 2 | `themes` (L31-48) | — | — | — | — | (Theme → Work 역참조 L44, Theme 자체는 Work에서만 참조) |
| 3 | `works` (L50-70) | `authorId` (Required) | Author | ✅ L52 | ❌ 미정의 | **작가 콘텐츠 — 영구 보존 영역 (Restrict 권장)** |
| 4 | `works` (L50-70) | `themeId` (Optional) | Theme | ✅ L62 | ❌ 미정의 | Work → Theme (Theme 삭제 시 → null 적합) |
| 5 | `episodes` (L72-95) | `workId` (Required) | Work | ✅ L74 | ❌ 미정의 | **Work cascade 권장 (Work 삭제 시 모든 episodes 동시 삭제 — 작가 의도)** |
| 6 | `credit_logs` (L97-105) | `authorId` (Required) | Author | ❌ **@relation 미박제 (raw FK만, ORM 미연결)** | ❌ 미정의 | 크레딧 변동 — **영구 보존 (감사 영역, Restrict 또는 SetNull)** |
| 7 | `social_accounts` (L107-118) | `authorId` (Required) | Author | ✅ L109 | ❌ 미정의 | 소셜 연동 — Author cascade 권장 (계정 자체 종속) |
| 8 | `bookmarks` (L128-137) | `authorId` (Required), `episodeId` (Required) | Author / Episode | ❌ 둘 다 @relation 미박제 | ❌ 미정의 | 북마크 — Cascade 권장 (Author/Episode 삭제 시 무의미) |
| 9 | `reading_progress` (L139-148) | `authorId` (Required), `episodeId` (Required) | Author / Episode | ❌ 둘 다 @relation 미박제 | ❌ 미정의 | 읽기 진행 — Cascade 권장 |
| 10 | `likes` (L150-162) | `authorId` (Optional), `episodeId` (Required) | Author / Episode | ❌ 둘 다 @relation 미박제 | ❌ 미정의 | 좋아요 — Cascade 권장 (Author 삭제 시 → null 또는 cascade) |
| 11 | `subscriptions` (L164-172) | `subscriberId` (Required), `targetAuthorId` (Required) | Author / Author (self-ref) | ❌ 둘 다 @relation 미박제 | ❌ 미정의 | 구독 — Cascade 권장 |
| 12 | `comments` (L174-190) | `authorId` (Optional), `episodeId` (Required), `parentId` (Optional) | Author / Episode / Comment | parent만 ✅ L183 | parentId만 미정의 | 댓글 — Author 삭제 시 SetNull (익명화), Episode cascade, parent SetNull |
| 13 | `payments` (L192-204) | `authorId` (Required) | Author | ❌ **@relation 미박제 (raw FK만)** | ❌ 미정의 | **결제 — 영구 보존 (Restrict 강제, 회계/세무/감사 영역)** |
| 14 | `webhook_events` (L212-224) | — | — | — | — | (FK 0건, eventId @unique만) |
| 15 | `daily_views` (L226-234) | `workId` (Required) | Work | ❌ @relation 미박제 | ❌ 미정의 | 통계 — Work cascade 권장 |
| 16 | `chat_sessions` (L236-247) | `authorId` (Required), `workId` (Required) | Author / Work | ❌ 둘 다 @relation 미박제 | ❌ 미정의 | AI 채팅 세션 — Cascade 권장 |
| 17 | `chat_messages` (L249-259) | `sessionId` (Required) | ChatSession | ✅ L252 | ✅ **Cascade 박제 (현재 정합)** | 채팅 메시지 — ChatSession 삭제 시 cascade |
| 18 | `featured_works` (L274-286) | `workId` (Required), `adminId` (Required) | Work / Author | ❌ 둘 다 @relation 미박제 | ❌ 미정의 | 메인 노출 — Work cascade, admin SetNull (운영자 변경 영역) |
| 19 | `user_sanctions` (L288-303) | `authorId` (Required), `adminId` (Required) | Author / Author | ❌ 둘 다 @relation 미박제 | ❌ 미정의 | 제재 — **Author 삭제 시 영구 보존 (감사, Restrict)** |
| 20 | `reports` (L305-320) | `targetId`, `reporterId` (Optional), `resolvedBy` (Optional) | (polymorphic — work/episode/comment), Author | ❌ 셋 다 @relation 미박제 | ❌ 미정의 | 신고 — Author SetNull (익명화), polymorphic targetId는 코드 영역 |
| 21 | `access_logs` (L331-345) | `authorId` (Optional) | Author | ❌ @relation 미박제 | ❌ 미정의 | 접근 로그 — **영구 보존 (감사, SetNull)** |
| 22 | `refresh_tokens` (L347-360) | `authorId` (Required) | Author | ❌ @relation 미박제 | ❌ 미정의 | refresh token — Cascade 권장 (Author 삭제 시 즉시 무효) |
| 23 | `analysis_reports` (L370-385) | `authorId` (Required) | Author | ❌ @relation 미박제 | ❌ 미정의 | AI 분석 — **영구 보존 (감사 + 환불 추적, Restrict 또는 SetNull)** |
| 24 | `admin_audit_logs` (L387-398) | `adminId` (Required), `targetId` (Optional) | Author | ❌ 둘 다 @relation 미박제 | ❌ 미정의 | 감사 로그 — **영구 보존 (Restrict 강제, 감사 영역)** |
| 25 | `refund_logs` (L423-435) | `paymentId` (Required) | Payment | ❌ @relation 미박제 | ❌ 미정의 | **환불 로그 — 영구 보존 (Restrict 강제, 회계/세무/감사 영역)** |
| 26 | `webhook_retry_queues` (L444-455) | `eventId` (Required, @unique) | (WebhookEvent.eventId 자연 키 — FK 명시 0건) | ❌ FK 명시 0건 | ❌ 미정의 | DLQ — eventId @unique 정합만 |

**총 영향**: 26 테이블 중 24 테이블이 `onDelete` 미정의 (1 테이블 chat_messages만 Cascade 박제, 1 테이블 webhook_events FK 0건).

**raw FK 영역 추가 결함 (메인 발견)**: 24 테이블 중 **15 테이블은 `@relation` directive 자체 박제 0건** (raw `authorId String` 컬럼만 박제, ORM 모델 연결 미박제). 즉 Prisma migration 시 FK 제약 자체가 PG에 적용되지 않을 수 있음 — **본 sprint 영역 = `@relation` 박제 + `onDelete` directive 동시 박제 + DB FK 제약 추가 마이그레이션 필요**.

> **주의 (사용자 검증 영역)**: 위 매트릭스 = Prisma schema raw 영역만 기준. 실제 PG DB의 FK 제약은 별도 직접 검증 필요 (`\d+ payments` SQL 또는 `pg_constraint` 조회). EMAIL-P0-2 incident raw에서 `works.author_id_fkey` 박제 = works 테이블에 FK 제약은 적용되어 있음 박제 (Prisma `@relation` 박제됨). 그러나 raw FK만 있는 15 테이블의 PG 영역 FK 제약 박제 여부는 **사용자 영역 직접 검증 강제** (§7-1 영역).

### 1-4. 결제 적자 위험 분석 (cost-accountant 면제 영역, 자체 분석)

| 시나리오 | 영향 | 적자 영향 |
|---|---|---|
| 모순-F 미차단 + Author 삭제 시도 | FK 제약 위반 → 삭제 차단 (현재 묵시 Restrict) | **적자 X** (단 운영 영역 수동 처리 부담) |
| 모순-F 미차단 + raw FK 영역 (15 테이블) | PG FK 제약 미적용 가능 → 고아 행 박제 가능 | **데이터 정합성 위험** (감사 영역 깨짐) |
| 모순-F 미차단 + Author 강제 삭제 (운영자) | works/payments/credit_logs 고아 행 → 회계 영역 깨짐 | **적자 위험 영역** (환불 추적 불가, 세무 영역) |
| 모순-F 미차단 + 향후 schema 변경 (cascade 의도 추가) | 의도 불명확 → 회귀 위험 + 데이터 손실 가능 | **데이터 손실 위험** (영구 보존 영역 손실) |
| 본 sprint 차단 적용 후 | 26 테이블 onDelete 명시 + Restrict/Cascade/SetNull 도메인 정합 | 데이터 정합성 + 회계 + 감사 영구 보존 정합 |

**모순-F 위치**: 마스터 플랜 §3-1 Phase 1 P1 우선순위 영역 (DB 정합성 + 감사 + 회계 + 영구 보존 영역, 직접 적자 영역은 아니지만 데이터 손실 + 감사 영역 깨짐 위험).

### 1-5. 결제 12 sprint + PAY-P3-A + PAY-P3-C + PAY-P3-B 완료 후 본 sprint 위치 (마스터 플랜 §2 정합)

| Sprint | 시간 | 외부 API | 의존성 | 우선순위 | 영향 |
|---|---|---|---|---|---|
| ~~PAY-P3-A Race condition (구멍-A/B)~~ | ~5h | 0 | 0 | P1 (적자 1순위) | ✅ 완료 |
| ~~PAY-P3-C Retry 중복 (모순-D)~~ | ~2h | 0 | 0 | P1 (DB 정합성) | ✅ 완료 (5/9) |
| ~~PAY-P3-B Polar SDK timeout (구멍-C)~~ | ~2h | 0 (SDK 옵션만) | 0 | P1 (운영 안정) | ✅ 완료 (5/9) |
| **PAY-P3-E** (본 sprint) | ~3h | 0 (DB 마이그레이션) | 0 | P1 (DB 정합성 + 감사) | 26 테이블 onDelete + 백필 |
| PAY-P3-H Circuit breaker | ~4h | 0 | 0 | P1 | 가용성 |
| PAY-P3-D Status enum | ~2h | 0 | 0 | P2 | 추적 일관성 |
| PAY-P2-5 audit retention | ~3h | 0 | 0 | P0 | 운영 |

---

## §2 목표 — 26 테이블 onDelete 정합 + 백필 SQL + 마이그레이션 정합

### 2-1. 핵심 KPI (사용자 결정 B Full 영역 강제 정합)

1. **Prisma schema 26 테이블 FK 관계 onDelete 명시 (Full 강제)**: 4 전략 (`Cascade` / `Restrict` / `SetNull` / `NoAction`) 도메인 의미 + 보존 정책 + 감사 정합 기준 결정 (§3-1 매트릭스 정합) — **사용자 결정 B Full 정합 박제**
2. **raw FK 영역 (15 테이블) `@relation` 박제 추가 (Full 강제)**: ORM 모델 연결 박제 + PG FK 제약 마이그레이션 적용 — **사용자 결정 B Full 정합 박제**
3. **마이그레이션 SQL 박제 (Full 강제)**: `yyyymmdd_pay_p3_e_fk_cascade/migration.sql` — (a) 백필 SQL (있다면) + (b) FK 제약 추가 + (c) onDelete 정책 적용 (사유 박제) — **사용자 결정 B Full 정합 박제**
4. **회귀 차단 0건**: jest server 643+ + eval regression-52~68 + EMAIL-P0-2 영역 회귀 0
5. **shared-contracts §25 FKCascadePolicy 신설**: 26 테이블 매트릭스 + 4 전략 정합 + 도메인 의미
6. **incident-log 박제 의무 (Mitchell Ghostty 정합, sensor-adversarial-pre-commit P20 정합)**: 마이그레이션 직전 + 직후 박제 강제 (특히 `fk_cascade_migration_dev` + `fk_cascade_migration_prod` 카테고리)
7. **사용자 검증 게이트 통과 강제 (Generator 진입 차단, 본 sprint 핵심 §7)**
8. **회계 8건 Restrict 강제 박제 (사용자 결정 A 정합)**: payments / credit_logs / works / user_sanctions / analysis_reports / admin_audit_logs / refund_logs (8 FK 관계) — Author hard delete 시 PG가 자동 차단 영역 정합 (USER-SOFT-DELETE sprint 영역 진입 전 본 sprint 영역에서 차단 강제 박제)
9. **USER-SOFT-DELETE sprint 영역 분리 박제**: 본 sprint = FK 제약 박제 영역만 (Author hard delete 자체 차단 영역) / Author.deletedAt 컬럼 + soft delete 패턴 + 본인 탈퇴 + 운영자 강제 삭제 기능 = **USER-SOFT-DELETE sprint 후속 영역** (본 sprint 비목표 영역 분리 정합)

### 2-2. 비목표 (사용자 결정 영역 분리, USER-SOFT-DELETE sprint 후속 영역 분리 박제)

- ❌ **Author.deletedAt 컬럼 + soft delete 패턴 = USER-SOFT-DELETE sprint 영역** (사용자 결정 A 정합, 본 sprint 비목표 영역 분리 강제 박제)
- ❌ **Author 본인 탈퇴 기능 (UI + API) = USER-SOFT-DELETE sprint 영역** (사용자 결정 A 정합)
- ❌ **운영자 강제 Author 삭제 기능 (admin UI + API) = USER-SOFT-DELETE sprint 영역** (사용자 결정 A 정합)
- ❌ **GDPR 익명화 절차 + 30일 후 hard delete 영역 = USER-SOFT-DELETE sprint 영역** (사용자 결정 A 정합)
- ❌ **Prisma soft delete middleware = USER-SOFT-DELETE sprint 영역** (사용자 결정 A 정합)
- ❌ Author hard delete 기능 신설 (일상 운영에서 발생 X — 사용자 결정 A 정합, 본 sprint 영역 외 USER-SOFT-DELETE sprint 영역)
- ❌ Polar SDK 영역 변경 (PAY-P3-B 정합)
- ❌ Circuit breaker (PAY-P3-H 분리, ~4h)
- ❌ Status enum mapping table (PAY-P3-D 분리, ~2h)
- ❌ audit retention 정책 (PAY-P2-5 분리, ~3h)
- ❌ Sentry/APM 통합 (PAY-P3-G, ~8h, 외부 SaaS 결정 후)
- ❌ DB hard delete 운영 도구 (Author 삭제 UI/API — USER-SOFT-DELETE sprint 영역 정합)

### 2-3. 본 sprint 영역 vs USER-SOFT-DELETE sprint 영역 분리 박제 (사용자 결정 A 정합)

| 영역 | 본 sprint (PAY-P3-E) | USER-SOFT-DELETE sprint (후속) |
|---|---|---|
| FK 제약 박제 (33 FK 관계 onDelete directive) | ✅ Full 영역 강제 | ❌ (본 sprint 영역) |
| raw FK 15 테이블 @relation 박제 | ✅ Full 영역 강제 | ❌ (본 sprint 영역) |
| 백필 SQL (시나리오 B 영역) | ✅ Full 영역 (옵션 결정 후) | ❌ (본 sprint 영역) |
| 회계 8건 Restrict 강제 (Author hard delete 시 PG 자동 차단) | ✅ Full 영역 강제 | ❌ (본 sprint 영역) |
| Author.deletedAt 컬럼 신설 | ❌ (USER-SOFT-DELETE 영역) | ✅ |
| Prisma soft delete middleware | ❌ (USER-SOFT-DELETE 영역) | ✅ |
| Author 본인 탈퇴 기능 (UI + API) | ❌ (USER-SOFT-DELETE 영역) | ✅ |
| 운영자 강제 Author 삭제 기능 (admin UI + API) | ❌ (USER-SOFT-DELETE 영역) | ✅ |
| GDPR 익명화 절차 (이메일/이름/IP 등) | ❌ (USER-SOFT-DELETE 영역) | ✅ |
| 30일 후 hard delete 자동화 (cron) | ❌ (USER-SOFT-DELETE 영역) | ✅ |
| 회계 8건 영구 보존 영역 (Restrict 박제 후) | ✅ (PG 자동 차단 정합) | ✅ (soft delete 시에도 영구 보존 정합) |

---

## §3 변경 영역 (server agent + grimoire-infrastructure Generator 진입 정본)

### 3-1. 26 테이블 onDelete 정책 결정 매트릭스 (본 sprint 핵심 결정 영역)

| # | 테이블 | FK 컬럼 | 참조 | **권장 onDelete** | **사유** |
|---|---|---|---|---|---|
| 1 | themes | authorId (Opt) | Author | `SetNull` | 작가 삭제 시 테마 익명화 (다른 작가가 cloning 가능) — 데이터 보존 |
| 2 | works | authorId (Req) | Author | `Restrict` | **작가 콘텐츠 영구 보존 (저작권 영역) — 삭제 차단** |
| 3 | works | themeId (Opt) | Theme | `SetNull` | Theme 삭제 시 Work는 default theme 유지 |
| 4 | episodes | workId (Req) | Work | `Cascade` | **Work 삭제 시 모든 episodes 동시 삭제 (작가 의도 정합)** |
| 5 | credit_logs | authorId (Req) | Author | `Restrict` | **크레딧 변동 영구 보존 (감사 + 회계 영역)** |
| 6 | social_accounts | authorId (Req) | Author | `Cascade` | 소셜 연동 = 계정 종속, Author 삭제 시 cascade |
| 7 | bookmarks | authorId (Req) | Author | `Cascade` | 북마크 = 사용자 종속, cascade |
| 8 | bookmarks | episodeId (Req) | Episode | `Cascade` | Episode 삭제 시 무의미 |
| 9 | reading_progress | authorId (Req) | Author | `Cascade` | 읽기 진행 = 사용자 종속 |
| 10 | reading_progress | episodeId (Req) | Episode | `Cascade` | Episode 삭제 시 무의미 |
| 11 | likes | authorId (Opt) | Author | `SetNull` | 좋아요 카운트 보존 (익명화) |
| 12 | likes | episodeId (Req) | Episode | `Cascade` | Episode 삭제 시 무의미 |
| 13 | subscriptions | subscriberId (Req) | Author | `Cascade` | 구독자 삭제 시 cascade |
| 14 | subscriptions | targetAuthorId (Req) | Author | `Cascade` | 대상 작가 삭제 시 cascade |
| 15 | comments | authorId (Opt) | Author | `SetNull` | 댓글 보존 (익명화 — '작성자 삭제됨') |
| 16 | comments | episodeId (Req) | Episode | `Cascade` | Episode 삭제 시 댓글 cascade |
| 17 | comments | parentId (Opt) | Comment | `SetNull` | 답글 보존 (parent 삭제 시 → 최상위 댓글로) |
| 18 | payments | authorId (Req) | Author | `Restrict` | **결제 영구 보존 (회계/세무/감사 — 7년 보존 영역)** |
| 19 | daily_views | workId (Req) | Work | `Cascade` | Work 통계 = Work 종속 |
| 20 | chat_sessions | authorId (Req) | Author | `Cascade` | AI 채팅 = 사용자 종속 |
| 21 | chat_sessions | workId (Req) | Work | `Cascade` | Work 채팅 = Work 종속 |
| 22 | chat_messages | sessionId (Req) | ChatSession | ✅ `Cascade` (현재 정합) | 메시지 = 세션 종속 (이미 박제) |
| 23 | featured_works | workId (Req) | Work | `Cascade` | Work 삭제 시 메인 노출 cascade |
| 24 | featured_works | adminId (Req) | Author | `SetNull` | 운영자 변경 시 메인 노출 보존 (단 adminId Optional 변경 필요) |
| 25 | user_sanctions | authorId (Req) | Author | `Restrict` | **제재 영구 보존 (재가입 추적 영역)** |
| 26 | user_sanctions | adminId (Req) | Author | `SetNull` | 운영자 변경 시 제재 기록 보존 (단 adminId Optional 변경 필요) |
| 27 | reports | reporterId (Opt) | Author | `SetNull` | 신고자 익명화 |
| 28 | reports | resolvedBy (Opt) | Author | `SetNull` | 운영자 변경 시 처리 기록 보존 |
| 29 | access_logs | authorId (Opt) | Author | `SetNull` | **접근 로그 영구 보존 (보안 감사 영역, 익명화)** |
| 30 | refresh_tokens | authorId (Req) | Author | `Cascade` | refresh token = 사용자 종속, Author 삭제 시 즉시 무효 |
| 31 | analysis_reports | authorId (Req) | Author | `Restrict` | **AI 분석 영구 보존 (환불 추적 + 감사 영역)** |
| 32 | admin_audit_logs | adminId (Req) | Author | `Restrict` | **감사 로그 영구 보존 (Restrict 강제, 절대 삭제 차단)** |
| 33 | refund_logs | paymentId (Req) | Payment | `Restrict` | **환불 로그 영구 보존 (회계/세무 영역, payments Restrict 정합)** |

**4 전략 분포** (총 33 FK 관계):
- `Cascade`: 16건 (사용자 종속 + Work/Episode 종속 + 통계)
- `Restrict`: 8건 (회계/세무/감사 영구 보존 — works / credit_logs / payments / user_sanctions / analysis_reports / admin_audit_logs / refund_logs)
- `SetNull`: 9건 (익명화 + 운영자 변경 + Theme 삭제 시 default 유지)
- `NoAction`: 0건 (PG default와 동일, 명시 0건)

### 3-2. raw FK → @relation 박제 추가 영역 (15 테이블)

| 테이블 | FK 컬럼 | 추가할 @relation directive 영역 |
|---|---|---|
| credit_logs | authorId | `author Author @relation(fields: [authorId], references: [id], onDelete: Restrict)` |
| bookmarks | authorId, episodeId | 둘 다 @relation 추가 |
| reading_progress | authorId, episodeId | 둘 다 @relation 추가 |
| likes | authorId, episodeId | 둘 다 @relation 추가 |
| subscriptions | subscriberId, targetAuthorId | 둘 다 @relation 추가 (self-ref @relation name 영역) |
| comments | authorId, episodeId | 두 FK 추가 (parentId는 이미 박제) |
| payments | authorId | @relation 추가 |
| daily_views | workId | @relation 추가 |
| chat_sessions | authorId, workId | 둘 다 @relation 추가 |
| featured_works | workId, adminId | 둘 다 @relation 추가 |
| user_sanctions | authorId, adminId | 둘 다 @relation 추가 |
| reports | reporterId, resolvedBy | 둘 다 @relation 추가 |
| access_logs | authorId | @relation 추가 |
| refresh_tokens | authorId | @relation 추가 |
| analysis_reports | authorId | @relation 추가 |
| admin_audit_logs | adminId | @relation 추가 |
| refund_logs | paymentId | @relation 추가 |

> **결정 영역**: Author 모델 정의 (L11-29) 영역에 모든 역참조 (themes / works / payments / credit_logs / refresh_tokens / analysis_reports / ... 33 관계) 박제 vs 명시 0건 (Prisma optional 영역 — Required) — Generator 영역 결정. 메인 권장 = 핵심 종속만 박제 (works / themes / socialAccounts), 나머지는 raw FK + @relation directive만 박제 (Author 모델 비대화 차단).

### 3-3. 핵심 코드 변경 (server)

| 파일 | 변경 영역 | 영향 |
|---|---|---|
| `prisma/schema.prisma` | 26 테이블 33 FK 관계 `onDelete` directive 명시 + raw FK → @relation 박제 (15 테이블) | 모순-F 차단 (정책 명시) |
| `prisma/migrations/{yyyymmdd}_pay_p3_e_fk_cascade/migration.sql` 신설 | (a) 백필 SQL (시나리오 B/C 영역만, §6 정합) + (b) FK 제약 추가 + (c) onDelete 정책 적용 (DROP CONSTRAINT + ADD CONSTRAINT ON DELETE 정책) | DB 정합 |
| `application/author/author-delete.usecase.ts` (신설 또는 보강) | Author 삭제 시 cascade 도메인 의미 + Restrict 영역 검증 spec (현재 Author 삭제 기능 미구현 영역 = 검증만, 운영자 도구는 별도 sprint) | 검증 영역 |

### 3-4. 신설 파일

| 파일 | 영역 |
|---|---|
| `prisma/migrations/{yyyymmdd}_pay_p3_e_fk_cascade/migration.sql` 신설 | 백필 + FK 제약 + onDelete 정책 마이그레이션 |
| `prisma/schema.spec.ts` 또는 `prisma-payment.repository.spec.ts` 갱신 | 33 FK 관계 onDelete 정책 spec (≥ 6 it: Cascade / Restrict / SetNull 각 2 it) |
| `eval/tasks/regression-69-fk-cascade.json` 신설 | 8 검증 (AC 8건 정합) |
| `.claude/scripts/sensor-fk-cascade-policy.sh` 신설 | 26 테이블 onDelete directive 박제 + raw FK 영역 @relation 박제 grep |
| `.claude/shared-contracts.md §25` 신설 | FKCascadePolicy 인터페이스 정본 박제 |
| `grimoire-server/docs/migration-rollback-procedure.md` 신설 (사용자 영역 가이드) | dev → prod 마이그레이션 + rollback 절차 + 백업 명령 |
| `grimoire-server/ADR.md ADR-007` 신설 | 4 전략 결정 사유 (Cascade vs Restrict vs SetNull vs NoAction) |

### 3-5. 변경 시 동시 갱신 대상 (책 Ch 16 shared-contracts 정합)

- `grimoire-server/docs/data-model.md` — 33 FK 관계 표 + onDelete 정책 매트릭스 (§3-1 정합)
- `grimoire-server/SCHEMA.md` — 26 테이블 onDelete 정책 박제
- `grimoire-server/SECURITY.md §4` — 데이터 보존 정책 (Restrict 영역 8건 영구 보존 강제 박제)
- `grimoire-server/ADR.md ADR-007` — 4 전략 결정 사유
- `grimoire-server/MIGRATION.md` — 본 sprint 마이그레이션 절차 + rollback 박제
- `.claude/shared-contracts.md §25` — FKCascadePolicy 신설 (본 sprint 핵심)
- `eval/tasks/regression-69-fk-cascade.json`
- `.claude/scripts/sensor-fk-cascade-policy.sh`
- `grimoire-server/docs/migration-rollback-procedure.md` 신설

### 3-6. 변경 0건 영역 (회귀 차단)

- `src/application/payment/payment.usecase.ts` (PAY-P3-A/B/C 회귀 0)
- `src/application/payment/webhook-retry.job.ts` (PAY-P3-C 회귀 0)
- `src/application/payment/payment-reconciliation.job.ts` (PAY-P0-2 회귀 0)
- `src/adapter/outbound/payment/polar.adapter.ts` (PAY-P3-B 회귀 0)
- `src/adapter/outbound/persistence/prisma-payment.repository.ts` (PAY-P3-A 회귀 0)
- 인프라 변경 (Azure Container Apps, replicas 등) 0건

---

## §4 AC BDD 8건 (qa Evaluator 채점 대상)

### AC-1: Author 삭제 시 Payment Restrict 차단 (회계 영구 보존)

```yaml
GIVEN PG DB에 Author X와 Payment(authorId=X, status='completed', amount=10000) 박제
WHEN DELETE FROM authors WHERE id = X 시도
THEN
  - PG FK 제약 위반 (foreign key constraint "payments_author_id_fkey")
  - DELETE 차단 + 23503 SQLSTATE 박제
  - jest spec PASS — Prisma `prisma.author.delete({ where: { id: X } })` 호출 시 PrismaClientKnownRequestError P2003 throw
  - shared-contracts §25 정합 검증 (payments.authorId onDelete=Restrict)
  - **회계 영구 보존 정합**: Payment 영구 보존 (7년) + admin_audit_logs Restrict + refund_logs Restrict 정합
```

### AC-2: Work 삭제 시 Episode + DailyView Cascade 자동 삭제 (작가 의도)

```yaml
GIVEN Work W와 Episode 5건 + DailyView 30건 (workId=W) 박제
WHEN DELETE FROM works WHERE id = W 시도
THEN
  - Episode 5건 자동 삭제 (cascade)
  - DailyView 30건 자동 삭제 (cascade)
  - bookmarks / reading_progress / likes / comments / chat_sessions Episode 종속 영역도 cascade
  - jest spec PASS — `prisma.work.delete({ where: { id: W } })` 호출 후 Episode count = 0 + DailyView count = 0
  - sensor-fk-cascade-policy.sh PASS (workId onDelete=Cascade 박제 검증)
```

### AC-3: Author 삭제 시 SetNull 영역 (Comment 익명화 + AccessLog 보존)

```yaml
GIVEN Author Y와 Comment(authorId=Y, content='hello') + AccessLog(authorId=Y, action='login_success') 박제
WHEN Author Y 삭제 시도 (단 Restrict 영역 0건일 시 — 즉 Y는 Payment / Work / CreditLog / AnalysisReport 0건)
THEN
  - Comment.authorId → null (SetNull, content 보존)
  - AccessLog.authorId → null (SetNull, ip + action 보존)
  - likes.authorId → null (SetNull, episodeId 정합 카운트 보존)
  - reports.reporterId → null + reports.resolvedBy → null (SetNull, 신고/처리 기록 보존)
  - **익명화 영역 정합**: 작가 본인 자율 탈퇴 영역 = 콘텐츠 영구 보존 + 본인 식별 정보만 익명화
```

### AC-4: 기존 고아 행 백필 처리 (시나리오 A/B/C 결정 후, §6-3 정합)

```yaml
GIVEN dev DB에 고아 행 N건 박제 (§7-1 사용자 영역 측정 결과 N>0인 경우)
  # 측정 명령:
  #   SELECT COUNT(*) FROM payments WHERE author_id NOT IN (SELECT id FROM authors);
  #   SELECT COUNT(*) FROM credit_logs WHERE author_id NOT IN (SELECT id FROM authors);
  #   SELECT COUNT(*) FROM works WHERE author_id NOT IN (SELECT id FROM authors);
  #   ... (전체 33 FK 관계)
WHEN 사용자 결정 (옵션 A/B/C, §6-3) 후 마이그레이션 진행
THEN
  - 옵션 A (placeholder author 재할당): authors 테이블에 `deleted_author_placeholder` 박제 + 고아 행 → placeholder.id 재할당 + cascade 적용
  - 옵션 B (직접 삭제 — DB 정합성 우선): 고아 행 DELETE + cascade 적용
  - 옵션 C (archive 테이블 이전 — 감사 보존): authors_archive_yyyymmdd 신설 + 고아 행 archive 이전 + cascade 적용
  - **각 옵션 사용자 결정 영역 강제 (§6-3)**
  - jest spec PASS — 마이그레이션 후 고아 행 0
```

### AC-5: 회귀 차단 — 기존 12 sprint + PAY-P3-A + PAY-P3-C + PAY-P3-B 시나리오 회귀 0건

```yaml
GIVEN 기존 PAY-P0-1/P0-2/P0-3/P1-1/P1-3/P2-1/P2-2/P2-3/P2-4 + PAY-P3-A + PAY-P3-C + PAY-P3-B + EMAIL-P0-2 시나리오
WHEN 본 sprint 변경 후 동일 시나리오 재실행 (jest server 643+ + eval regression-52~68)
THEN
  - jest 643/643+ PASS (회귀 0)
  - eval regression-52~68 모두 PASS
  - PAY-P0-2 Reconciliation cron 회귀 0
  - PAY-P2-2 DLQ 정상 retry 회귀 0
  - PAY-P3-A 사전 게이트 회귀 0
  - PAY-P3-C 사전 dedup 회귀 0
  - PAY-P3-B exception 분류 회귀 0
  - EMAIL-P0-2 영역 회귀 0 (UPDATE 백필 결과 정합 — @example.com 박제 정합)
```

### AC-6: 마이그레이션 rollback 정합 (사용자 영역 검증 §6-5)

```yaml
GIVEN 본 sprint 마이그레이션 적용 직후 (dev 또는 prod)
WHEN 회귀 발견 + rollback 결정
THEN
  - 백업 영역: 마이그레이션 직전 `pg_dump --schema-only > backup_yyyymmdd_schema.sql` + `pg_dump --data-only --table=authors --table=payments --table=credit_logs ... > backup_yyyymmdd_data.sql` 박제
  - rollback 명령: `prisma migrate resolve --rolled-back {migration_name}` + `psql < backup_yyyymmdd_schema.sql` 영역
  - Container Apps revision rollback (grimoire-infrastructure 협업 영역) — schema 변경 후 첫 revision rollback 시 schema 정합 영역 (revision N-1과 schema 호환성 검증 강제)
  - **사용자 영역 검증 강제** (§7-3): rollback 절차 사용자 검토 + 승인 후만 prod 적용
```

### AC-7: dev → prod 순차 적용 + 사용자 검증 게이트 통과

```yaml
GIVEN dev DB 고아 행 측정 + 백필 옵션 결정 + onDelete 정책 결정 사용자 영역 통과
WHEN 마이그레이션 적용 순서
THEN
  1. dev 백필 SQL (시나리오 B/C 영역) → 사용자 명시: `dev 백필 SQL 진행`
  2. dev migration apply (`npm run prisma:migrate:dev` 또는 `prisma migrate deploy`) → 사용자 명시: `PAY-P3-E dev migration 진행`
  3. dev jest/eval/sensor 검증 + dev curl 검증 (curl https://dev-api... HTTP 200)
  4. dev 24h 안정성 박제 (사용자 영역)
  5. prod 백필 SQL → 사용자 명시: `prod 백필 SQL 진행`
  6. prod migration apply → 사용자 명시: `PAY-P3-E prod migration 진행`
  7. prod 검증 (curl + Container Apps revision Healthy + sensor-deploy-health PASS)
  - **각 단계 사용자 명시 영역 분리 강제 (§6-2 + §7-2 + §7-4 정합)**
```

### AC-8: incident-log + AdminAuditLog 정합

```yaml
GIVEN 본 sprint 마이그레이션 진행 영역
WHEN 마이그레이션 직전 + 직후 박제 영역
THEN
  - 마이그레이션 직전 박제:
    ```bash
    bash .claude/scripts/incident-log.sh \
      --category=fk_cascade_migration_dev \
      --severity=high \
      --source=planner \
      --description="PAY-P3-E dev migration 직전 — 고아 행 N건 박제 + 옵션 X 결정 + 백업 backup_yyyymmdd 박제"
    ```
  - 마이그레이션 직후 박제 (성공):
    ```bash
    bash .claude/scripts/incident-log.sh \
      --category=fk_cascade_migration_dev \
      --severity=info \
      --source=server \
      --description="PAY-P3-E dev migration 성공 — 33 FK 관계 onDelete 적용 + 회귀 0 + jest 643/643 PASS"
    ```
  - prod 영역 동일 박제 강제 (`fk_cascade_migration_prod` 카테고리)
  - sensor-adversarial-pre-commit P20 PASS (incident-log 박제 의무 정합)
```

---

## §5 검증 매트릭스 (Generator + Evaluator 공동 영역)

### 5-1. jest server spec 신설 (≥ 6 it)

| spec | it 수 | 영역 |
|---|---|---|
| `prisma-author.repository.spec.ts` (또는 신설) | ≥ 3 | Author 삭제 시 Payment Restrict 차단 + Work Restrict 차단 + chat_sessions Cascade 검증 |
| `prisma-work.repository.spec.ts` (또는 신설) | ≥ 2 | Work 삭제 시 Episode + DailyView Cascade 검증 |
| `prisma-fk-cascade.spec.ts` 신설 | ≥ 3 | SetNull 영역 (Comment + AccessLog + Like 익명화) + Restrict 영역 8건 (payments / credit_logs / works / user_sanctions / analysis_reports / admin_audit_logs / refund_logs) |

**예상 spec 인벤토리 변동**: 643 (PAY-P3-B 종료 직후) → **649+ it** (jest server)

### 5-2. eval regression-69 신설

```json
{
  "id": "regression-69-fk-cascade-policy",
  "category": "regression",
  "description": "PAY-P3-E — FK Cascade 정책 (모순-F 차단, 26 테이블 33 FK 관계 onDelete 명시 + 백필)",
  "checks": [
    "schema.prisma 33 FK 관계 모두 onDelete directive 명시 (Cascade/Restrict/SetNull 4 전략)",
    "schema.prisma raw FK 15 테이블에 @relation directive 박제",
    "Restrict 영역 8건 박제 (payments/credit_logs/works/user_sanctions/analysis_reports/admin_audit_logs/refund_logs)",
    "Cascade 영역 16건 박제 (Episode/DailyView/chat_sessions/refresh_tokens 등)",
    "SetNull 영역 9건 박제 (Comment/AccessLog/Like 익명화)",
    "prisma/migrations/{yyyymmdd}_pay_p3_e_fk_cascade/migration.sql 신설 + DB FK 제약 적용",
    "shared-contracts.md §25 FKCascadePolicy 신설",
    "ADR.md ADR-007 신설 + data-model.md FK 매트릭스 갱신"
  ]
}
```

**예상 eval 인벤토리 변동**: 68 (PAY-P3-B 종료 직후) → **69 regression tasks**

### 5-3. sensor 신설 — `sensor-fk-cascade-policy.sh`

```bash
#!/bin/bash
# sensor-fk-cascade-policy.sh
# PAY-P3-E 회귀 차단 — Prisma schema 33 FK 관계 onDelete 박제 + raw FK @relation 박제 grep

# 1. Restrict 영역 8건 박제 검증 (영구 보존 영역)
for table_fk in "payments authorId" "credit_logs authorId" "works authorId" "user_sanctions authorId" "analysis_reports authorId" "admin_audit_logs adminId" "refund_logs paymentId"; do
  table=$(echo "$table_fk" | cut -d' ' -f1)
  fk=$(echo "$table_fk" | cut -d' ' -f2)
  grep -E "${fk}.*onDelete:\\s*Restrict" grimoire-server/prisma/schema.prisma || {
    echo "FAIL: ${table}.${fk} onDelete=Restrict 박제 0건"
    exit 1
  }
done

# 2. Cascade 영역 핵심 박제 검증
grep -E "workId.*onDelete:\\s*Cascade" grimoire-server/prisma/schema.prisma || {
  echo "FAIL: episodes.workId onDelete=Cascade 박제 0건"
  exit 1
}

# 3. SetNull 영역 핵심 박제 검증
for fk_field in "comments.*authorId" "access_logs.*authorId" "likes.*authorId"; do
  grep -qE "${fk_field}.*onDelete:\\s*SetNull" grimoire-server/prisma/schema.prisma || {
    echo "FAIL: ${fk_field} onDelete=SetNull 박제 0건"
    exit 1
  }
done

# 4. raw FK 15 테이블 @relation 박제 검증
for raw_table in "credit_logs" "payments" "refresh_tokens" "analysis_reports" "admin_audit_logs" "refund_logs"; do
  grep -A 3 "model.*${raw_table}" grimoire-server/prisma/schema.prisma | grep -qE "@relation\\(fields:" || {
    echo "FAIL: ${raw_table} @relation directive 박제 0건"
    exit 1
  }
done

# 5. shared-contracts §25 박제
grep -q "## 25\\. FKCascadePolicy" .claude/shared-contracts.md || {
  echo "FAIL: shared-contracts §25 FKCascadePolicy 박제 0건"
  exit 1
}

# 6. migration SQL 박제 검증
ls grimoire-server/prisma/migrations/ | grep -qE "pay_p3_e_fk_cascade" || {
  echo "FAIL: prisma/migrations/{yyyymmdd}_pay_p3_e_fk_cascade 박제 0건"
  exit 1
}

echo "PASS: PAY-P3-E FK Cascade 정책 정합"
```

**예상 sensor 인벤토리 변동**: 42 (PAY-P3-B 종료 직후) → **43 sensors**

### 5-4. shared-contracts §25 신설 (인터페이스 정본)

```markdown
## 25. FKCascadePolicy (server 도메인 — 26 테이블 FK 관계 onDelete 정책 정합)

**위치**:
- Schema: `grimoire-server/prisma/schema.prisma` (26 테이블 33 FK 관계 onDelete directive 명시)
- Migration: `grimoire-server/prisma/migrations/{yyyymmdd}_pay_p3_e_fk_cascade/migration.sql` (백필 + FK 제약 + onDelete 정책)
- Sensor: `.claude/scripts/sensor-fk-cascade-policy.sh` (6 검증)
- ADR: `grimoire-server/ADR.md ADR-007` (4 전략 결정 사유)

**적용**: PAYMENT_AUDIT §1 모순-F (FK cascade 미정의 — Author 삭제 시 22 테이블 고아 행 위험) 차단. EMAIL-P0-2 백필 영역 정합 (UPDATE 전략 vs DELETE 전략 결정 영역). DB schema 변경 1건 (마이그레이션 1건). 외부 API 추가 호출 0건.

### 4 전략 매트릭스 (33 FK 관계)

- **Cascade (16건)**: 사용자 종속 + Work/Episode 종속 + 통계 (episodes.workId / chat_sessions.authorId / chat_sessions.workId / refresh_tokens.authorId / bookmarks.* / reading_progress.* / social_accounts.authorId / subscriptions.* / daily_views.workId / featured_works.workId / comments.episodeId / likes.episodeId)
- **Restrict (8건)**: 회계/세무/감사 영구 보존 (works.authorId / credit_logs.authorId / payments.authorId / user_sanctions.authorId / analysis_reports.authorId / admin_audit_logs.adminId / refund_logs.paymentId)
- **SetNull (9건)**: 익명화 + 운영자 변경 + 기본값 유지 (themes.authorId / works.themeId / likes.authorId / comments.authorId / comments.parentId / reports.reporterId / reports.resolvedBy / access_logs.authorId / featured_works.adminId / user_sanctions.adminId)

### 시그니처 — Prisma schema onDelete directive

```prisma
// 예: payments.authorId Restrict 박제 (회계 영구 보존)
model Payment {
  ...
  authorId String @map("author_id")
  author   Author @relation(fields: [authorId], references: [id], onDelete: Restrict)
  ...
}

// 예: episodes.workId Cascade 박제 (Work 삭제 시 cascade)
model Episode {
  ...
  workId String @map("work_id")
  work   Work   @relation(fields: [workId], references: [id], onDelete: Cascade)
  ...
}

// 예: comments.authorId SetNull 박제 (익명화)
model Comment {
  ...
  authorId String? @map("author_id")
  author   Author? @relation(fields: [authorId], references: [id], onDelete: SetNull)
  ...
}
```

### 시그니처 — migration SQL 영역

```sql
-- prisma/migrations/{yyyymmdd}_pay_p3_e_fk_cascade/migration.sql
-- (a) 백필 SQL (시나리오 B/C 영역만 — 사용자 결정 후 박제)
-- 예 (옵션 A — placeholder 재할당):
-- INSERT INTO authors (id, slug, name, email, password_hash, role, credits, plan, created_at)
-- VALUES ('deleted-placeholder-uuid', 'deleted-placeholder', 'Deleted Author', 'deleted@grimoire.local', NULL, 'system', 0, 'free', NOW());
-- UPDATE payments SET author_id = 'deleted-placeholder-uuid' WHERE author_id NOT IN (SELECT id FROM authors);

-- (b) FK 제약 추가 (raw FK 15 테이블 영역)
-- ALTER TABLE credit_logs ADD CONSTRAINT credit_logs_author_id_fkey FOREIGN KEY (author_id) REFERENCES authors(id) ON DELETE RESTRICT;
-- ALTER TABLE payments ADD CONSTRAINT payments_author_id_fkey FOREIGN KEY (author_id) REFERENCES authors(id) ON DELETE RESTRICT;
-- ... (15 테이블 영역)

-- (c) 기존 FK 제약 영역 → onDelete 정책 적용 (DROP + ADD CONSTRAINT)
-- ALTER TABLE works DROP CONSTRAINT works_author_id_fkey;
-- ALTER TABLE works ADD CONSTRAINT works_author_id_fkey FOREIGN KEY (author_id) REFERENCES authors(id) ON DELETE RESTRICT;
-- ALTER TABLE episodes DROP CONSTRAINT episodes_work_id_fkey;
-- ALTER TABLE episodes ADD CONSTRAINT episodes_work_id_fkey FOREIGN KEY (work_id) REFERENCES works(id) ON DELETE CASCADE;
-- ... (33 FK 관계 영역)
```

### 변경 이력

- 2026-05-09 #10_8 PAY-P3-E: 신설 — PAYMENT_AUDIT §1 모순-F 차단. 26 테이블 33 FK 관계 onDelete 정합 (4 전략: Cascade 16 / Restrict 8 / SetNull 9 / NoAction 0). raw FK 15 테이블 @relation 박제. 백필 SQL 옵션 A/B/C 결정 영역 (사용자 영역). DB schema 변경 1건 (마이그레이션 1건). EMAIL-P0-2 영역 정합. 정본: `reports/sprint-pay-p3-e-fk-cascade-progress.md` (Generator 진입 후 박제).
```

**예상 shared-contracts 변동**: §1~24 (PAY-P3-B 종료 직후) → **§1~25**

### 5-5. 검증 게이트 종합

| 게이트 | 통과 기준 |
|---|---|
| jest server | 643 → 649+ PASS (회귀 0) |
| eval regression | 68 → 69 PASS (재실행 검증) |
| sensor-fk-cascade-policy.sh | PASS |
| sensor-payment-race-condition.sh (PAY-P3-A 회귀) | PASS |
| sensor-retry-dedup.sh (PAY-P3-C 회귀) | PASS |
| sensor-polar-timeout-policy.sh (PAY-P3-B 회귀) | PASS |
| sensor-adversarial-pre-commit P16 (결제 원자성) | PASS |
| sensor-shared-contracts.sh | PASS (§25 박제 정합) |
| sensor-deploy-health (INFRA-1) | PASS (마이그레이션 후 revision Healthy) |
| visual-canon-keeper | 면제 (UI 변경 0) |
| cost-accountant | 면제 (외부 API 추가 0) |
| qa Evaluator | CONDITIONAL PASS 또는 PASS (AC 8건 채점) |

---

## §6 위험 분석 (사용자 명시 핵심 영역) — DB 백필/마이그레이션 정밀 분석

> **본 sprint Initializer가 가장 정밀하게 분석한 영역**. 사용자 명시 (5/9) — "이거 디비 백필, 마이그레이션 섣불리 하면 위험하니, 세부계획 철저히 세워서 계획검증 먼저 하고, 그 다음이 구현 시작" 정합.

### 6-1. 기존 고아 행 측정 영역 (마이그레이션 직전 1차 박제 필수)

**dev DB SQL 측정 명령** (사용자 영역 — `psql` 직접 실행 필요, §7-1 사용자 검증 게이트):

```sql
-- A. Author FK 영역 (16개 테이블)
SELECT 'payments' AS table_name, COUNT(*) AS orphan_count FROM payments WHERE author_id NOT IN (SELECT id FROM authors);
SELECT 'credit_logs' AS table_name, COUNT(*) AS orphan_count FROM credit_logs WHERE author_id NOT IN (SELECT id FROM authors);
SELECT 'works' AS table_name, COUNT(*) AS orphan_count FROM works WHERE author_id NOT IN (SELECT id FROM authors);
SELECT 'themes' AS table_name, COUNT(*) AS orphan_count FROM themes WHERE author_id IS NOT NULL AND author_id NOT IN (SELECT id FROM authors);
SELECT 'social_accounts' AS table_name, COUNT(*) AS orphan_count FROM social_accounts WHERE author_id NOT IN (SELECT id FROM authors);
SELECT 'bookmarks' AS table_name, COUNT(*) AS orphan_count FROM bookmarks WHERE author_id NOT IN (SELECT id FROM authors);
SELECT 'reading_progress' AS table_name, COUNT(*) AS orphan_count FROM reading_progress WHERE author_id NOT IN (SELECT id FROM authors);
SELECT 'likes' AS table_name, COUNT(*) AS orphan_count FROM likes WHERE author_id IS NOT NULL AND author_id NOT IN (SELECT id FROM authors);
SELECT 'subscriptions_subscriber' AS table_name, COUNT(*) AS orphan_count FROM subscriptions WHERE subscriber_id NOT IN (SELECT id FROM authors);
SELECT 'subscriptions_target' AS table_name, COUNT(*) AS orphan_count FROM subscriptions WHERE target_author_id NOT IN (SELECT id FROM authors);
SELECT 'comments' AS table_name, COUNT(*) AS orphan_count FROM comments WHERE author_id IS NOT NULL AND author_id NOT IN (SELECT id FROM authors);
SELECT 'chat_sessions' AS table_name, COUNT(*) AS orphan_count FROM chat_sessions WHERE author_id NOT IN (SELECT id FROM authors);
SELECT 'user_sanctions' AS table_name, COUNT(*) AS orphan_count FROM user_sanctions WHERE author_id NOT IN (SELECT id FROM authors);
SELECT 'access_logs' AS table_name, COUNT(*) AS orphan_count FROM access_logs WHERE author_id IS NOT NULL AND author_id NOT IN (SELECT id FROM authors);
SELECT 'refresh_tokens' AS table_name, COUNT(*) AS orphan_count FROM refresh_tokens WHERE author_id NOT IN (SELECT id FROM authors);
SELECT 'analysis_reports' AS table_name, COUNT(*) AS orphan_count FROM analysis_reports WHERE author_id NOT IN (SELECT id FROM authors);
SELECT 'admin_audit_logs' AS table_name, COUNT(*) AS orphan_count FROM admin_audit_logs WHERE admin_id NOT IN (SELECT id FROM authors);
SELECT 'reports_reporter' AS table_name, COUNT(*) AS orphan_count FROM reports WHERE reporter_id IS NOT NULL AND reporter_id NOT IN (SELECT id FROM authors);
SELECT 'reports_resolved' AS table_name, COUNT(*) AS orphan_count FROM reports WHERE resolved_by IS NOT NULL AND resolved_by NOT IN (SELECT id FROM authors);
SELECT 'featured_works_admin' AS table_name, COUNT(*) AS orphan_count FROM featured_works WHERE admin_id NOT IN (SELECT id FROM authors);
SELECT 'user_sanctions_admin' AS table_name, COUNT(*) AS orphan_count FROM user_sanctions WHERE admin_id NOT IN (SELECT id FROM authors);

-- B. Work FK 영역
SELECT 'episodes' AS table_name, COUNT(*) AS orphan_count FROM episodes WHERE work_id NOT IN (SELECT id FROM works);
SELECT 'daily_views' AS table_name, COUNT(*) AS orphan_count FROM daily_views WHERE work_id NOT IN (SELECT id FROM works);
SELECT 'featured_works_work' AS table_name, COUNT(*) AS orphan_count FROM featured_works WHERE work_id NOT IN (SELECT id FROM works);
SELECT 'chat_sessions_work' AS table_name, COUNT(*) AS orphan_count FROM chat_sessions WHERE work_id NOT IN (SELECT id FROM works);

-- C. Episode FK 영역
SELECT 'bookmarks_episode' AS table_name, COUNT(*) AS orphan_count FROM bookmarks WHERE episode_id NOT IN (SELECT id FROM episodes);
SELECT 'reading_progress_episode' AS table_name, COUNT(*) AS orphan_count FROM reading_progress WHERE episode_id NOT IN (SELECT id FROM episodes);
SELECT 'likes_episode' AS table_name, COUNT(*) AS orphan_count FROM likes WHERE episode_id NOT IN (SELECT id FROM episodes);
SELECT 'comments_episode' AS table_name, COUNT(*) AS orphan_count FROM comments WHERE episode_id NOT IN (SELECT id FROM episodes);

-- D. Theme/Payment 등 FK 영역
SELECT 'works_theme' AS table_name, COUNT(*) AS orphan_count FROM works WHERE theme_id IS NOT NULL AND theme_id NOT IN (SELECT id FROM themes);
SELECT 'refund_logs' AS table_name, COUNT(*) AS orphan_count FROM refund_logs WHERE payment_id NOT IN (SELECT id FROM payments);
SELECT 'comments_parent' AS table_name, COUNT(*) AS orphan_count FROM comments WHERE parent_id IS NOT NULL AND parent_id NOT IN (SELECT id FROM comments);
SELECT 'chat_messages' AS table_name, COUNT(*) AS orphan_count FROM chat_messages WHERE session_id NOT IN (SELECT id FROM chat_sessions);
```

**총 측정 SQL 33건** (33 FK 관계 정합).

**prod DB도 동일 측정 영역** (사용자 영역, dev 검증 통과 후만).

### 6-2. 마이그레이션 위험 시나리오 분석

#### 시나리오 A — 고아 행 0건 (이상적 영역)

**조건**: 모든 33 측정 SQL → 0 박제 (현재 schema의 묵시 Restrict로 인해 EMAIL-P0-2 영역 같은 우회 처리 후 정합 박제 가능성 높음).

**처리 흐름**:
1. 백필 SQL **불필요**
2. 마이그레이션 SQL = (a) raw FK 15 테이블 `ALTER TABLE ... ADD CONSTRAINT ... FOREIGN KEY` + (b) 기존 FK 제약 영역 `DROP CONSTRAINT + ADD CONSTRAINT ... ON DELETE 정책`
3. dev → prod 순차 적용

**예상 결과**: 안전 영역 (회귀 0 + 데이터 손실 0).

#### 시나리오 B — 고아 행 N건 (현실적 영역, 가능성 ≥ 30%)

**조건**: 33 측정 SQL 중 1건 이상 → N>0 박제 (특히 EMAIL-P0-2 백필 직전 회귀 박제 영역, raw FK 15 테이블 영역).

**처리 흐름**:
1. 백필 SQL **필수** — §6-3 옵션 A/B/C 사용자 결정
2. 백필 SQL 적용 → 측정 SQL 재실행 → 0 박제 검증
3. 마이그레이션 SQL 적용 (시나리오 A와 동일)
4. dev → prod 순차 적용

**예상 결과**: 사용자 결정 후 안전 영역.

#### 시나리오 C — 마이그레이션 도중 race condition

**조건**: 마이그레이션 진행 중 동시 Author 삭제 또는 Author 신규 생성 + payment 처리 동시 발생.

**처리 흐름**:
1. 마이그레이션 직전 운영 트래픽 차단 영역 검토 (사용자 명시 영역, prod 영역)
2. 또는 DB lock 전략: `BEGIN; LOCK TABLE authors, payments, ... IN SHARE MODE;` 영역 (단 짧은 마이그레이션만 안전)
3. Container Apps revision = 마이그레이션 직전 새 revision deploy 차단 (사용자 명시 영역 — `prod main 머지 차단`)

**예상 결과**: prod 영역 = 사용자 명시 + dev 24h 안정성 박제 후만 진행 (§7-4).

### 6-3. 백필 SQL 정합 검증 영역 (시나리오 B 발동 시 사용자 결정)

만약 §6-1 측정 결과 고아 행 N>0 발견 시:

#### 옵션 A — placeholder author 재할당 후 cascade 적용

**SQL**:
```sql
-- 1. placeholder author 박제 (1회만)
INSERT INTO authors (id, slug, name, email, role, credits, plan, created_at)
VALUES ('00000000-0000-0000-0000-000000000000', 'deleted-placeholder', 'Deleted Author', 'deleted@grimoire.local', 'system', 0, 'free', NOW())
ON CONFLICT (id) DO NOTHING;

-- 2. 고아 행 → placeholder.id 재할당 (예: payments)
UPDATE payments SET author_id = '00000000-0000-0000-0000-000000000000' WHERE author_id NOT IN (SELECT id FROM authors);
-- ... (33 영역)
```

**장점**: 데이터 보존 (감사 추적 가능) + cascade 적용 후 placeholder.id로 추적 가능.
**단점**: placeholder author 자체가 의미 없는 row + admin 도구에서 노출 시 혼란.

#### 옵션 B — 고아 행 직접 삭제 (DB 정합성 우선)

**SQL**:
```sql
-- 예: payments
DELETE FROM payments WHERE author_id NOT IN (SELECT id FROM authors);
-- ... (33 영역)
```

**장점**: 단순 + DB 정합성 100%.
**단점**: 데이터 손실 (감사 추적 불가) — **회계/세무/감사 영역 (Restrict 8건) = 절대 금지** (회계 영역 손실 시 법적 책임 영역).

#### 옵션 C — archive 테이블 이전 후 정리 (감사 보존)

**SQL**:
```sql
-- 1. archive 테이블 신설
CREATE TABLE authors_archive_20260509 AS SELECT * FROM authors WHERE 1=0; -- schema clone
CREATE TABLE payments_archive_20260509 AS SELECT * FROM payments WHERE 1=0;
-- ... (33 영역)

-- 2. 고아 행 archive 이전
INSERT INTO payments_archive_20260509 SELECT * FROM payments WHERE author_id NOT IN (SELECT id FROM authors);
DELETE FROM payments WHERE author_id NOT IN (SELECT id FROM authors);
-- ... (33 영역)
```

**장점**: 감사 보존 + DB 정합성 보장 + 향후 archive 테이블 검토 가능.
**단점**: archive 테이블 33개 신설 부담 + 디스크 영역 + 운영 복잡성.

### 6-4. 사용자 결정 영역 강제 (사용자 결정 박제 + Initializer 권장)

**사용자 결정 박제 (2026-05-09 직접 발화 raw 인용)**:

> **결정 A**: "Yes: USER-SOFT-DELETE sprint 분리 신설 → Author hard delete 자체가 일상 운영에서 발생 X → 본 sprint는 FK 제약만 + 회계 8건 Restrict"
> **결정 B**: "Full: 33 FK 매트릭스 + 15 @relation 신설 + 백필 + 마이그레이션 모두"
> **명시**: "이렇게 진행"

**본 sprint 영역 정합 박제**:

- **결정 A 정합**: USER-SOFT-DELETE sprint 분리 영역 박제 (`.claude/state/sprint-user-soft-delete-candidate.md` 후속 후보 영역) — Author hard delete 자체가 일상 운영에서 발생 X 영역 정합
- **결정 B 정합**: 본 sprint = Full 영역 (33 FK 매트릭스 + 15 @relation 신설 + 백필 + 마이그레이션 모두) 진행 강제
- **회계 8건 Restrict 강제 (사용자 결정 A 정합)**: payments / credit_logs / works / user_sanctions / analysis_reports / admin_audit_logs / refund_logs (8 FK 관계) — Author hard delete 시 PG가 자동 차단 영역 정합 (즉 본 sprint = FK 제약 박제만으로 hard delete 차단 영역 정합)

**Initializer 권장 영역 (사용자 검토 후 변경 가능, 시나리오 B 발동 시만 — §6-1 측정 결과 후 결정)**:

- **회계/세무/감사 영역 8건 (Restrict 강제)** — 옵션 C (archive) **강제** (절대 삭제 금지) — 사용자 결정 A 정합
- **나머지 25건** — 옵션 A (placeholder 재할당) **권장** (단순 + 추적 가능) — 사용자 측정 결과 후 결정
- **단 고아 행 0건일 시 (시나리오 A)** — 백필 SQL 자체 불필요 (옵션 무관)

**옵션 결정 영역 매트릭스** (사용자 결정 A 정합 박제):

| 영역 | 옵션 | 결정 영역 |
|---|---|---|
| **회계 8건 (Restrict 강제)** | 옵션 C (archive) **강제** | **사용자 결정 A 정합 — 본 sprint 강제 박제** |
| 나머지 25건 (Cascade 16 + SetNull 9) | 옵션 A/B/C | §6-1 측정 결과 후 사용자 결정 (시나리오 B 발동 시만) |
| 시나리오 A (고아 행 0건) | 백필 불필요 | 옵션 결정 영역 무관 |

### 6-5. dev → prod 적용 순서 + 검증 게이트

| 순서 | 단계 | 영역 | 사용자 명시 키워드 |
|---|---|---|---|
| 1 | dev DB 고아 행 측정 SQL 실행 (§6-1, 33건) | 사용자 영역 | `dev 고아 행 측정 진행` |
| 2 | dev 측정 결과 분석 + 옵션 A/B/C 결정 (시나리오 B 영역만) | 사용자 영역 | `dev 옵션 A/B/C 결정 박제` |
| 3 | dev 백업 (`pg_dump --schema-only > backup_dev_yyyymmdd_schema.sql` + `pg_dump --data-only --table=... > backup_dev_yyyymmdd_data.sql`) | 사용자 영역 | `dev 백업 박제` |
| 4 | dev 백필 SQL 적용 (시나리오 B 영역만) | 사용자 영역 | `dev 백필 SQL 진행` |
| 5 | dev 측정 SQL 재실행 → 0 박제 검증 | 사용자 영역 | (자동 박제) |
| 6 | dev migration apply (`prisma migrate deploy`) | server agent 자동 영역 | `PAY-P3-E dev migration 진행` |
| 7 | dev jest/eval/sensor 검증 (§5) | server agent + qa 자동 영역 | (자동 박제) |
| 8 | dev curl 검증 (https://dev-api.grimoire-book.com/health → HTTP 200) | grimoire-infrastructure agent 자동 영역 | (자동 박제) |
| 9 | dev 24h 안정성 박제 | 사용자 영역 | `dev 24h 안정성 박제 통과` |
| 10 | prod DB 고아 행 측정 SQL 실행 (§6-1, 33건) | 사용자 영역 | `prod 고아 행 측정 진행` |
| 11 | prod 측정 결과 분석 + 옵션 결정 (dev와 다른 결과 가능) | 사용자 영역 | `prod 옵션 결정 박제` |
| 12 | prod 백업 (`pg_dump --schema-only > backup_prod_yyyymmdd_schema.sql` + `pg_dump --data-only > backup_prod_yyyymmdd_data.sql`) | 사용자 영역 | `prod 백업 박제` |
| 13 | prod 운영 트래픽 영역 검토 (마이그레이션 시 deadlock 위험 영역 — 짧은 영역만 안전) | 사용자 영역 | `prod 트래픽 영역 검토 통과` |
| 14 | prod 백필 SQL 적용 (시나리오 B 영역만) | 사용자 영역 | `prod 백필 SQL 진행` |
| 15 | prod migration apply | server agent + grimoire-infrastructure 협업 영역 | `PAY-P3-E prod migration 진행` |
| 16 | prod 검증 (curl + Container Apps revision Healthy + sensor-deploy-health PASS) | grimoire-infrastructure agent 자동 영역 | (자동 박제) |

### 6-6. rollback 절차 정밀화

| 회귀 영역 | rollback 절차 | 사용자 영역 |
|---|---|---|
| dev migration 직후 jest 회귀 | `prisma migrate resolve --rolled-back {migration_name}` + `psql < backup_dev_yyyymmdd_schema.sql` (schema 복원) | 사용자 명시: `dev migration rollback 진행` |
| dev curl 200 회귀 | Container Apps revision rollback (직전 healthy revision) + DB rollback 동시 영역 | 사용자 명시: `dev rollback 진행` |
| prod migration 직후 회귀 | `prisma migrate resolve --rolled-back` + `psql < backup_prod_yyyymmdd_schema.sql` 복원 + `psql < backup_prod_yyyymmdd_data.sql` 데이터 복원 | 사용자 명시: `prod migration rollback 진행` |
| prod 운영 트래픽 영역 deadlock | Container Apps replica 즉시 차단 (replicas=0) + 트래픽 차단 + DB rollback | 사용자 명시: `prod 긴급 rollback 진행` |
| 영구 보존 영역 (Restrict 8건) 데이터 손실 | **회복 불가** — backup 영역에서 직접 복원만 가능 | **본 sprint 절대 금지 영역** (옵션 B 회계 영역 적용 시 발동 가능, §6-4 정합) |

### 6-7. 본 sprint 위험도 매트릭스

| 위험 | 가능성 | 영향 | 차단 영역 |
|---|---|---|---|
| dev 영역 고아 행 N>0 (시나리오 B) | 30% | 중 | §6-3 옵션 결정 강제 |
| prod 영역 고아 행 N>0 (dev와 다른 분포) | 50% | 중 | §6-5 prod 측정 SQL 별도 실행 강제 |
| 회계 영역 (Restrict 8건) 데이터 손실 | 낮음 (옵션 C 강제 시) | **치명적** (법적 책임) | §6-4 옵션 C 강제 |
| 마이그레이션 도중 race condition (prod) | 중 | 중 | §6-2 시나리오 C + §7-4 사용자 명시 |
| Container Apps revision rollback 시 schema 정합 깨짐 | 낮음 | 높음 | §6-6 rollback 절차 + grimoire-infrastructure 협업 |
| Prisma migration 실패 (DB 권한 영역) | 낮음 | 중 | dev 1차 검증 영역 차단 |
| jest 회귀 (33 FK 관계 영역) | 중 | 낮음 | §5-1 spec ≥ 6 it 신설 |
| EMAIL-P0-2 영역 회귀 (UPDATE 백필 결과 정합) | 낮음 | 중 | §4 AC-5 회귀 차단 검증 강제 |

---

## §7 사용자 검증 게이트 (본 sprint 핵심) — Generator 진입 차단 영역

### 7-1. 사용자 영역 명령 키워드 박제 (Generator 진입 영역 분리 강제)

본 Initializer 산출 후 **사용자 검증 영역 명시 강제** — 각 단계 사용자 명시 키워드 박제 후만 다음 단계 진행:

| 단계 | 사용자 명시 키워드 | Generator 진입 차단 영역 |
|---|---|---|
| **1. dev 고아 행 측정** | `PAY-P3-E dev 고아 행 측정 진행` | 측정 SQL 실행 + 결과 박제 영역 (사용자 영역) |
| **2. dev 옵션 결정** | `PAY-P3-E dev 옵션 [A/B/C] 결정` | 시나리오 B 발동 시만 (시나리오 A는 skip) |
| **3. dev 백업 박제** | `PAY-P3-E dev 백업 박제 완료` | 백업 명령 (`pg_dump --schema-only` + `pg_dump --data-only`) |
| **4. dev 백필 SQL** | `PAY-P3-E dev 백필 SQL 진행` | 옵션 결정 후 SQL 적용 (사용자 영역) |
| **5. dev migration apply** | `PAY-P3-E dev migration 진행` | server agent Generator 진입 영역 (본 키워드 후만 진입) |
| **6. dev 24h 안정성** | `PAY-P3-E dev 24h 안정성 박제 통과` | prod 영역 진입 차단 (24h 후만 진입) |
| **7. prod 고아 행 측정** | `PAY-P3-E prod 고아 행 측정 진행` | dev와 별도 측정 강제 (분포 다름) |
| **8. prod 옵션 결정** | `PAY-P3-E prod 옵션 [A/B/C] 결정` | dev 결정과 다를 가능성 (사용자 영역 별도) |
| **9. prod 백업** | `PAY-P3-E prod 백업 박제 완료` | 사용자 영역 |
| **10. prod 트래픽 영역 검토** | `PAY-P3-E prod 트래픽 영역 검토 통과` | deadlock 위험 영역 검토 |
| **11. prod 백필 SQL** | `PAY-P3-E prod 백필 SQL 진행` | 옵션 결정 후 SQL 적용 |
| **12. prod migration apply** | `PAY-P3-E prod migration 진행` | server agent + grimoire-infrastructure 협업 영역 |
| **13. main 머지** | `claude-docs main 머지 진행` / `server main 머지 진행` | per-repo 명시 강제 (.githooks/AGENTS.md §1 정합) |

### 7-2. dev curl 자격증명 영역

- 본 sprint = curl 직접 검증 영역 = grimoire-infrastructure agent 자동 영역 (firewall rule 박제 후 사용자 명시)
- prod curl 검증 = 사용자 명시: `PAY-P3-E prod curl 검증 진행`

### 7-3. rollback 절차 검토 + 승인 영역 (사용자 영역)

- **dev rollback**: 사용자 명시 — `PAY-P3-E dev rollback 진행`
- **prod rollback**: 사용자 명시 — `PAY-P3-E prod rollback 진행` (영향 분석 + 사용자 검토 후만)

### 7-4. prod 영역 진입 차단 (3 게이트 통과 강제)

- 게이트 1: dev migration 통과 (jest + eval + sensor + curl 모두 PASS)
- 게이트 2: dev 24h 안정성 박제 (회귀 0건 박제)
- 게이트 3: 사용자 명시 `PAY-P3-E prod migration 진행` 정확 매칭

**3 게이트 모두 통과 후만** prod 영역 진입 (Generator 자율 진입 절대 금지).

---

## §8 멀티에이전트 위임 매트릭스

### 8-1. 본 sprint 위임 순서 (책 Ch 16 Anthropic 3-에이전트 + GMP v2.2 정합)

```
[Step 1] 메인 (orchestration-decision skill) → 본 sprint = server agent + grimoire-infrastructure 협업 영역 (DB 마이그레이션 + Container Apps 정합)
[Step 2] grimoire-planner (Initializer, 본 작업) → `.claude/state/sprint-pay-p3-e-fk-cascade-draft.md` 박제 + AC BDD 8건 박제 + §6 위험 분석 정밀화 박제 (사용자 명시 핵심 영역)
[Step 3] **사용자 검증 게이트** §7-1 13 단계 (Generator 진입 차단 영역, 사용자 영역 명시 강제)
[Step 4] cost-accountant 면제 (외부 API 추가 호출 0)
[Step 5] visual-canon-keeper 면제 (UI 변경 0)
[Step 6] grimoire-server (Generator) → 본 sprint 영역 (사용자 검증 게이트 통과 후만):
  - prisma/schema.prisma 33 FK 관계 onDelete directive 박제 + raw FK 15 테이블 @relation 박제
  - prisma/migrations/{yyyymmdd}_pay_p3_e_fk_cascade/migration.sql 신설
  - prisma-author/work/fk-cascade.spec.ts ≥ 6 it 신설
  - sensor 신설 + eval task 신설 + shared-contracts §25 신설 + ADR-007 신설
  - data-model.md / SCHEMA.md / SECURITY.md §4 / MIGRATION.md / migration-rollback-procedure.md 갱신
  - reports/sprint-pay-p3-e-fk-cascade-progress.md 갱신 (Initializer 산출 영역에서 인계)
[Step 7] grimoire-infrastructure (협업) → DB migration apply + Container Apps revision Healthy 검증 + sensor-deploy-health PASS 박제
[Step 8] verification-before-completion skill + sensor 회귀 검증
[Step 9] socratic-self-critique skill (14 질문 + Ambiguity ≤ 0.2)
[Step 10] requesting-code-review skill (12 항목 체크리스트)
[Step 11] sensor-adversarial-pre-commit (19 principles, FAIL 0건 강제)
[Step 12] grimoire-qa (Evaluator) → reports/QA_REPORT.md (AC 8건 채점 + jest 649+ + eval 69 + sensor 43 + shared-contracts §25 검증)
[Step 13] commit + push develop (메인 직접, 화이트리스트 hook 통과)
[Step 14] memory 박제 (Stop hook 강제 + incident-log)
[Step 15] **사용자 검증 게이트** §7-4 3 게이트 통과 후만 prod 영역 진입
```

### 8-2. 위임 매트릭스 (각 agent 책임 영역)

| Agent | 책임 영역 | 산출물 |
|---|---|---|
| **grimoire-planner (Initializer, 본 작업)** | Sprint 계약 17 섹션 + AC BDD 8건 + §6 위험 분석 정밀화 박제 | `.claude/state/sprint-pay-p3-e-fk-cascade-draft.md` (본 파일) |
| **사용자** | §6-1 측정 SQL 실행 + 옵션 결정 + 백업 + 백필 + 24h 안정성 + per-repo 명시 강제 | 측정 결과 + 결정 박제 + 백업 파일 |
| cost-accountant | **면제** (외부 API 추가 호출 0) | 면제 박제 |
| visual-canon-keeper | **면제** (UI 변경 0) | 면제 박제 |
| **grimoire-server (Generator)** | schema + migration + spec + sensor + eval + shared-contracts §25 + ADR-007 + 정본 동시 갱신 | `reports/sprint-pay-p3-e-fk-cascade-progress.md` 갱신 + commit |
| **grimoire-infrastructure (협업)** | DB migration apply + Container Apps revision Healthy 검증 + sensor-deploy-health PASS + rollback 절차 정합 | dev/prod migration 검증 박제 |
| **grimoire-qa (Evaluator)** | AC 8건 채점 + jest/eval/sensor 회귀 + 거짓말 차단 (qa 독립 재실행 + 직접 Read) | `reports/QA_REPORT.md` |
| 메인 직접 | commit + push develop (화이트리스트 통과 영역) | 2 레포 develop branch (server + claude-docs) |

### 8-3. infrastructure agent 결합 (HANDOVER §1.6 정합) — 본 sprint 핵심 영역

- 본 sprint = DB 마이그레이션 1건 → grimoire-infrastructure agent **필수 협업** (PAY-P3-B와 다름, 본 sprint는 schema 변경 영역)
- dev migration apply 영역: server agent가 `prisma migrate deploy` 실행, infrastructure agent가 Container Apps revision Healthy 검증
- prod migration apply 영역: 사용자 명시 후 server + infrastructure 협업 진행 (revision rollback 절차 정합 박제)
- sensor-deploy-health (INFRA-1 정합) PASS 강제 — 마이그레이션 직후 revision Healthy 박제

### 8-4. 케이스 처리 매트릭스 (재시작 플랜 §2-2 정합)

본 sprint 진행 중 결함 발견 시 케이스 처리:

| 케이스 | 트리거 | 처리 흐름 |
|---|---|---|
| 케이스 1 (시나리오 B 발동) | dev 측정 결과 N>0 박제 | §6-3 옵션 A/B/C 사용자 결정 강제 → 백필 SQL 적용 → §6-1 재측정 → 0 박제 후 마이그레이션 진행 |
| 케이스 2 (회계 영역 옵션 B 시도) | 사용자가 Restrict 8건 영역에 옵션 B (직접 삭제) 결정 | **본 sprint 차단 강제** — 옵션 C (archive) 강제 영역 (§6-4 정합) |
| 케이스 3 (prod 영역 dev와 다른 분포) | prod 측정 결과 dev와 다른 N건 박제 | prod 영역 별도 옵션 결정 강제 (§7-1 단계 7-8 정합) |
| 케이스 4 (마이그레이션 도중 deadlock) | prod 영역 마이그레이션 시 운영 트래픽 영역 deadlock | §6-6 긴급 rollback 절차 (사용자 명시: `prod 긴급 rollback 진행`) |
| 케이스 5 (Container Apps revision rollback schema 정합 깨짐) | revision N → N-1 rollback 시 schema 변경 영역 정합 영역 | grimoire-infrastructure agent 협업 강제 — backup 복원 + revision rollback 동시 영역 |
| 케이스 6 (agent 거부) | grimoire-server agent가 schema/migration 책임 영역 외부 명시 거부 | 사용자 직접 영역: PP-13 우회 함수 복원 → agent 정의 책임 영역 명시 → 우회 함수 제거 |

---

## §9 incident-log 박제 의무 (Mitchell Ghostty 정합)

### 9-1. 본 sprint 진행 중 박제 의무 카테고리

각 카테고리 발견 시 **즉시 박제** (sensor-adversarial-pre-commit P20 + Constitution Principle 20 정합):

| 카테고리 | 박제 시점 | 본 sprint 예상 시나리오 |
|---|---|---|
| **fk_cascade_orphan_found** | §6-1 측정 결과 N>0 박제 시 | 시나리오 B 발동 |
| **fk_cascade_migration_dev** | dev migration apply 직전 + 직후 박제 | §7-1 단계 5 |
| **fk_cascade_migration_prod** | prod migration apply 직전 + 직후 박제 | §7-1 단계 12 |
| **fk_cascade_backfill_option** | 백필 옵션 A/B/C 결정 시 | §6-3 사용자 결정 |
| **fk_cascade_rollback_dev** | dev rollback 진행 시 | 회귀 발견 시 |
| **fk_cascade_rollback_prod** | prod rollback 진행 시 | 영구 보존 영역 데이터 손실 위험 시 |
| **agent_failure** | server agent commit/push 0건인데 자율 시도 | Generator 진입 시 |
| **documentation_gap** | shared-contracts §25 박제 누락 발견 시 | 본 sprint 진행 중 |
| **dev_verification_skip** | code spec PASS만 박제 후 운영 영향 0 보고 | qa Evaluator 채점 시점 |
| **false_report_caught** | 거짓 보고 사슬 발견 시 | 모든 단계 |
| **guard_bypass_attempt** | sensor 우회 시도 시 | sensor-adversarial-pre-commit FAIL |

### 9-2. 박제 명령 표준 (sensor-adversarial-pre-commit 정합)

```bash
bash .claude/scripts/incident-log.sh \
  --category=fk_cascade_migration_dev \
  --severity=high \
  --source=server \
  --description="PAY-P3-E dev migration 직전 — 고아 행 N건 박제 (payments=0, credit_logs=0, ...) + 옵션 A 결정 + 백업 backup_dev_20260509 박제"
```

### 9-3. incident-log 검증 게이트

- qa Evaluator는 본 sprint 진행 중 박제된 incident-log를 직접 Read 후 QA_REPORT 박제
- sensor-adversarial-pre-commit은 incident-log 부재 시 FAIL (본 sprint 진행 중 fk_cascade_migration_dev 카테고리 ≥ 2건 박제 필수 — 직전 + 직후)

---

## §10 dev 작동 검증 영역 (메인 자율 vs 사용자 영역 분리)

### 10-1. 메인 자율 영역 (가드 통과)

| # | 검증 영역 | 명령 | 기대 |
|---|---|---|---|
| 1 | jest server 회귀 | `cd grimoire-server && npm test` | 649+ PASS |
| 2 | eval regression-52~69 | `bash eval/scripts/eval-runner.sh --filter regression-` | 69/69 PASS |
| 3 | sensor-fk-cascade-policy.sh | `bash .claude/scripts/sensor-fk-cascade-policy.sh` | PASS |
| 4 | sensor-payment-race-condition.sh (PAY-P3-A 회귀) | `bash .claude/scripts/sensor-payment-race-condition.sh` | PASS |
| 5 | sensor-retry-dedup.sh (PAY-P3-C 회귀) | `bash .claude/scripts/sensor-retry-dedup.sh` | PASS |
| 6 | sensor-polar-timeout-policy.sh (PAY-P3-B 회귀) | `bash .claude/scripts/sensor-polar-timeout-policy.sh` | PASS |
| 7 | sensor-adversarial-pre-commit P16/P20 | `bash .claude/scripts/sensor-adversarial-pre-commit.sh` | PASS |
| 8 | sensor-shared-contracts.sh | `bash .claude/scripts/sensor-shared-contracts.sh` | PASS (§25 박제 정합) |
| 9 | sensor-deploy-health (INFRA-1) | `bash .claude/scripts/sensor-deploy-health.sh dev` | PASS (revision Healthy) |
| 10 | dev API 회귀 (curl) | `curl -fs https://dev-api.grimoire-book.com/health` | HTTP 200 |
| 11 | EMAIL-P0-2 영역 회귀 박제 (authors @example.com 정합) | `psql -c "SELECT COUNT(*) FROM authors WHERE email LIKE '%@example.com'"` | dev 영역 ≥ 1건 (EMAIL-P0-2 백필 결과 정합) |

### 10-2. 사용자 명시 권한 영역 (자격증명 영역)

| # | 검증 영역 | 준비 | 명시 키워드 |
|---|---|---|---|
| 1 | dev DB 고아 행 측정 SQL 실행 (33건) | psql 직접 실행 영역 | `PAY-P3-E dev 고아 행 측정 진행` |
| 2 | dev 백업 (`pg_dump --schema-only` + `pg_dump --data-only`) | dev DB 권한 영역 | `PAY-P3-E dev 백업 박제 완료` |
| 3 | dev 백필 SQL (시나리오 B 영역) | 옵션 결정 후 | `PAY-P3-E dev 백필 SQL 진행` |
| 4 | dev migration apply | server agent 자동 영역 | `PAY-P3-E dev migration 진행` |
| 5 | dev 24h 안정성 박제 후 prod 영역 | dev 회귀 0건 박제 후 | `PAY-P3-E dev 24h 안정성 박제 통과` |
| 6 | prod DB 고아 행 측정 SQL 실행 (33건) | psql 직접 실행 영역 | `PAY-P3-E prod 고아 행 측정 진행` |
| 7 | prod 백업 | prod DB 권한 영역 | `PAY-P3-E prod 백업 박제 완료` |
| 8 | prod 백필 SQL | 옵션 결정 후 | `PAY-P3-E prod 백필 SQL 진행` |
| 9 | prod migration apply | server + infrastructure 협업 영역 | `PAY-P3-E prod migration 진행` |
| 10 | per-repo main 머지 | 각 레포 사용자 명시 강제 | `claude-docs main 머지 진행` / `server main 머지 진행` |

### 10-3. 자동 검증 영역 (sensor 영역)

- sensor-fk-cascade-policy.sh = CI/CD pre-push hook 자동 검증
- eval regression-69 = sensor-eval-trend.sh 자동 검증
- jest server = pre-push hook 자동 검증
- sensor-deploy-health (INFRA-1) = 마이그레이션 직후 자동 검증

---

## §11 사용자 결정 영역 (메인 자율 진행 금지 영역)

### 11-1. main 머지 영역 (.githooks/AGENTS.md §1 정합)

- 본 sprint 진행 중 **develop push만** 자동 (2 레포 server + claude-docs)
- main 머지는 **per-repo 명시 승인** 필수
- 명시 키워드: `server main 머지 진행` / `claude-docs main 머지 진행`

### 11-2. dev/prod DB SQL 직접 실행 영역 (자격증명 영역)

- §6-1 33 측정 SQL = 사용자 영역 (psql 권한 영역)
- 백필 SQL = 사용자 영역
- 백업 명령 = 사용자 영역

### 11-3. prod 배포 영역

- dev 24h 안정성 박제 후 사용자 명시 필요
- 명시 키워드: `PAY-P3-E prod migration 진행` (현재 본 sprint = dev 배포만 자동)

### 11-4. 옵션 A/B/C 결정 영역 (사용자 결정 A 정합 박제)

- §6-3 옵션 결정 = 사용자 영역
- **회계 영역 (Restrict 8건) = 옵션 C (archive) 강제** (사용자 결정 A 정합, 본 sprint 강제 박제 영역)
- 나머지 25건 = 옵션 A/B/C — **§6-1 측정 결과 후 사용자 결정 영역** (시나리오 B 발동 시만, 시나리오 A — 고아 행 0건일 시 옵션 무관)

#### 11-4-1. 옵션 결정 영역 매트릭스 (사용자 결정 A 정합 박제)

| 영역 | 옵션 | 결정 영역 박제 |
|---|---|---|
| **회계 8건 (Restrict 강제)** | 옵션 C (archive) **강제** | **사용자 결정 A 정합 — 본 sprint 강제 박제 (변경 불가)** |
| 나머지 25건 (Cascade 16 + SetNull 9) | 옵션 A/B/C | §6-1 측정 결과 후 사용자 결정 (시나리오 B 발동 시만) |
| 시나리오 A (고아 행 0건) | 백필 불필요 | 옵션 결정 영역 무관 |

### 11-5. USER-SOFT-DELETE sprint 후속 박제 영역 (사용자 결정 A 정합 신설)

**사용자 결정 A 정합** (2026-05-09 직접 발화 raw 인용):

> "Yes: USER-SOFT-DELETE sprint 분리 신설 → Author hard delete 자체가 일상 운영에서 발생 X → 본 sprint는 FK 제약만 + 회계 8건 Restrict"

**USER-SOFT-DELETE sprint 후속 박제 영역**:

- **위치**: `.claude/state/sprint-user-soft-delete-candidate.md` (PP-13 메인 화이트리스트 영역, draft 단계 박제만, §0~§3 + §11 + §13 + §14 + §15 박제)
- **본 sprint 진입 직후 발견 정합**: PAY-P3-E sprint 진입 직후 발견 — Author 모델 (`prisma/schema.prisma:11-29`)에 `deletedAt` 컬럼 박제 0건, soft delete 패턴 부재 결함
- **본 sprint 영역 분리 강제**: USER-SOFT-DELETE sprint 영역 = Author.deletedAt 컬럼 + Prisma soft delete middleware + Author 본인 탈퇴 기능 (UI + API) + 운영자 강제 Author 삭제 기능 (admin UI + API) + GDPR 익명화 절차 + 30일 후 hard delete 자동화 (cron) 영역
- **본 sprint 진입 게이트**: PAY-P3-E sprint 종료 후 진입 영역 (FK 제약 박제 후만 진입 영역, 회계 8건 Restrict 박제 후 soft delete 영역도 영구 보존 정합 박제)
- **사용자 명시 키워드**: `USER-SOFT-DELETE sprint Initializer 진행` (본 sprint 종료 후 사용자 명시 영역)

### 11-6. PaymentGatewayPort 시그니처 결정 영역 — N/A

- 본 sprint = schema 영역만 변경, port 시그니처 영역 0건

---

## §12 Definition of Done (qa Evaluator 채점 기준)

### 12-1. 정량 KPI

- [ ] jest server **649+ PASS** (회귀 0)
- [ ] eval regression **69 PASS** (재실행 검증)
- [ ] sensor **43 PASS** (sensor-fk-cascade-policy.sh 신설)
- [ ] shared-contracts **§25 박제** (FKCascadePolicy)
- [ ] AC BDD **8건 PASS** (qa 독립 재실행 + 직접 Read 검증)
- [ ] incident-log **≥ 2건 박제** (fk_cascade_migration_dev 직전 + 직후)
- [ ] sensor-deploy-health PASS (마이그레이션 직후 dev/prod revision Healthy)

### 12-2. 정성 검증

- [ ] schema.prisma 33 FK 관계 모두 onDelete directive 명시 (Cascade 16 / Restrict 8 / SetNull 9)
- [ ] schema.prisma raw FK 15 테이블에 @relation directive 박제
- [ ] Restrict 영역 8건 박제 (payments / credit_logs / works / user_sanctions / analysis_reports / admin_audit_logs / refund_logs)
- [ ] prisma/migrations/{yyyymmdd}_pay_p3_e_fk_cascade/migration.sql 신설
- [ ] DB FK 제약 적용 검증 (`\d+ payments` SQL 또는 pg_constraint 조회)
- [ ] 백필 SQL 적용 검증 (시나리오 B 영역 — 고아 행 0 박제)
- [ ] EMAIL-P0-2 영역 회귀 0 (UPDATE 백필 결과 @example.com 정합)
- [ ] 사용자 검증 게이트 §7-1 13 단계 통과 박제

### 12-3. 산출물 박제

- [ ] **Draft commit** + push develop (`.claude/state/sprint-pay-p3-e-fk-cascade-draft.md` 박제)
- [ ] Generator (server + infrastructure) 진입 후 `reports/sprint-pay-p3-e-fk-cascade-progress.md` 신설 + 갱신
- [ ] qa Evaluator의 `reports/QA_REPORT.md` CONDITIONAL PASS 또는 PASS

### 12-4. 회귀 차단

- [ ] PAY-P0-1 (webhook event_id 멱등성) 회귀 0
- [ ] PAY-P0-2 (PG↔DB 정합성 cron) 회귀 0
- [ ] PAY-P0-3 (운영자 수동 크레딧 UI) 회귀 0
- [ ] PAY-P1-1 (Refund 4분기 처리) 회귀 0
- [ ] PAY-P1-3 (결제 실패 retry + cleanup cron) 회귀 0
- [ ] PAY-P2-1 (부분 환불 비율) 회귀 0
- [ ] PAY-P2-2 (Webhook DLQ + retry) 회귀 0
- [ ] PAY-P2-3 (SmsServicePort 캡슐화) 회귀 0
- [ ] PAY-P2-4 (AdminAuditLog beforeState/afterState) 회귀 0
- [ ] PAY-P3-A (Race condition 사전 게이트 + CAS 패턴) 회귀 0
- [ ] PAY-P3-C (Retry 사전 dedup 게이트) 회귀 0
- [ ] PAY-P3-B (Polar SDK timeout 정책) 회귀 0
- [ ] EMAIL-P0-2 (UPDATE 백필 결과 @example.com 정합) 회귀 0
- [ ] INFRA-1 (sensor-deploy-health) 회귀 0

---

## §13 회귀 차단 영역 (eval regression-52~68 회귀 0 보장)

### 13-1. 결제 회귀 매트릭스

| eval task | sprint | 본 sprint 영향 | 회귀 검증 |
|---|---|---|---|
| regression-52 | PAY-P0-1 webhook event_id 멱등성 | webhook_events @unique 회귀 0 | 자동 |
| regression-53 | PAY-P0-2 PG↔DB 정합성 cron | reconciliation cron 회귀 0 | 자동 |
| regression-54 | PAY-P0-3 admin grant credits | admin UI 회귀 0 | 자동 |
| regression-55 | PAY-P1-1 refund atomicity | refundPaymentAtomically 회귀 0 (refund_logs.paymentId Restrict 정합) | 자동 + AC-1 |
| regression-57 | PAY-P1-3 payment retry reuse | findReusablePendingPayment 회귀 0 | 자동 |
| regression-58 | PAY-P2-1 부분 환불 비율 | partial_refunded 사전 게이트 회귀 0 | 자동 |
| regression-59 | PAY-P2-2 webhook DLQ | DLQ 흐름 회귀 0 | 자동 |
| regression-60~65 | PAY-P2-3/4 + 기타 | SMS/audit 회귀 0 (admin_audit_logs.adminId Restrict 정합) | 자동 + AC-1 |
| regression-66 | PAY-P3-A race condition | payment.status 사전 게이트 + CAS 회귀 0 | 자동 |
| regression-67 | PAY-P3-C retry dedup | webhook-retry.job 사전 dedup 회귀 0 | 자동 |
| regression-68 | PAY-P3-B Polar SDK timeout | classifyPolarError 회귀 0 | 자동 |
| regression-69 | **PAY-P3-E 본 sprint** | 신설 | 신설 |

### 13-2. 강화 영역 (회귀 0 + 보강)

- **regression-55 (PAY-P1-1)**: refund_logs.paymentId onDelete=Restrict 박제 정합 강화 (Payment 영구 보존 영역 정합) — 회귀 0 보장.
- **regression-60~65 (PAY-P2-4)**: admin_audit_logs.adminId onDelete=Restrict 박제 정합 강화 (감사 영구 보존 영역) — 회귀 0 보장.
- **EMAIL-P0-2 영역**: UPDATE 백필 결과 @example.com 정합 회귀 0 — 본 sprint AC-5 검증 강제 (`SELECT COUNT(*) FROM authors WHERE email LIKE '%@example.com'` ≥ 1건).
- **INFRA-1 영역**: sensor-deploy-health PASS 박제 강화 (마이그레이션 직후 dev/prod revision Healthy 박제) — 회귀 0 보장.

---

## §14 변경 이력

- **2026-05-09 #10_8 본 세션 grimoire-planner agent (사용자 결정 박제 갱신, 2차)** — 사용자 직접 발화 raw 인용 박제 (5/9):
  - **결정 A**: "Yes: USER-SOFT-DELETE sprint 분리 신설 → Author hard delete 자체가 일상 운영에서 발생 X → 본 sprint는 FK 제약만 + 회계 8건 Restrict"
  - **결정 B**: "Full: 33 FK 매트릭스 + 15 @relation 신설 + 백필 + 마이그레이션 모두"
  - **명시**: "이렇게 진행"
  - **갱신 영역**: §0 한 줄 요약 (§0-1 사용자 결정 박제 신설) + §2-1 핵심 KPI (KPI 8 회계 8건 Restrict 강제 + KPI 9 USER-SOFT-DELETE sprint 영역 분리 박제 신설) + §2-2 비목표 (USER-SOFT-DELETE sprint 영역 5건 분리 박제 + §2-3 본 sprint vs USER-SOFT-DELETE sprint 매트릭스 11 영역 신설) + §6-4 사용자 결정 영역 강제 (사용자 결정 A/B raw 인용 박제 + 회계 8건 Restrict 강제 박제 + 옵션 결정 매트릭스 신설) + §11-4 옵션 A/B/C 결정 영역 (사용자 결정 A 정합 박제 + 매트릭스 11-4-1 신설) + §11-5 USER-SOFT-DELETE sprint 후속 박제 영역 신설 (사용자 명시 키워드 박제 + 본 sprint 영역 분리 강제 박제) + §11-6 PaymentGatewayPort 시그니처 결정 영역 N/A (이전 §11-5 이전 박제).
  - **본 sprint Full 영역 진행 명시 박제**: 33 FK 매트릭스 + 15 @relation 신설 + 백필 + 마이그레이션 모두 진행 (결정 B 정합) + 회계 8건 Restrict 강제 (결정 A 정합) + 나머지 25건 = §6-3 옵션 A/B/C 사용자 측정 결과 후 결정 (시나리오 B 발동 시만).
  - **USER-SOFT-DELETE candidate 신설 박제**: `.claude/state/sprint-user-soft-delete-candidate.md` 후속 후보 영역 박제 (§0~§3 + §11 + §13 + §14 + §15 박제, 본 sprint 진입 직전 Initializer 영역 박제는 §4~§10 + §12 + §16~§17 영역 외).
  - **commit/push 0건**: Initializer 영역 정합 (Generator 진입 0건, 사용자 검증 게이트 §7-1 단계 1 통과 전).
- **2026-05-09 #10_8 본 세션 grimoire-planner agent (Initializer 1차 신설)** — 본 Sprint 계약 신설 (`.claude/state/` Draft 박제 영역, PP-13 화이트리스트 우회). 입력 자료 7건 (sprint-pay-p3-master-plan-draft.md + sprint-pay-p3-a/b/c-draft.md + PAYMENT_AUDIT-2026-05-07.md §1 모순-F + Prisma schema.prisma 직접 grep 33 FK 관계 + EMAIL-P0-2 incident-log L73 + shared-contracts §22/§23/§24) 직접 Read 후:
  - **§0 한 줄 요약** + **§1 배경** (모순-F raw 인용 + EMAIL-P0-2 백필 충돌 raw + 메인 정밀 검증 26 테이블 33 FK 매트릭스 — raw FK 15 테이블 발견 추가) + **§2 목표** (KPI 7건 + 비목표 7건) + **§3 변경 영역** (33 FK 관계 onDelete 매트릭스 + raw FK 15 테이블 @relation 박제 영역 + 신설 7건 + 회귀 차단 5건) + **§4 AC BDD 8건** (qa Evaluator 채점 정본 형식) + **§5 검증 매트릭스** (jest ≥6 it / eval task 1건 / sensor 1건 / shared-contracts §25) + **§6 위험 분석 (사용자 명시 핵심)** — 시나리오 A/B/C + 옵션 A/B/C + dev → prod 16 단계 순서 + rollback 절차 + 위험도 매트릭스 + **§7 사용자 검증 게이트** (13 단계 명시 키워드 박제 + Generator 진입 차단 영역 분리 강제) + **§8 멀티에이전트 위임** (책 Ch 16 정합 + grimoire-infrastructure 협업 영역 + 케이스 처리 매트릭스) + **§9 incident-log 박제 의무** (Mitchell Ghostty 정합) + **§10 dev 검증 영역** (메인 자율 + 사용자 영역 분리) + **§11 사용자 결정 영역** (main 머지 + DB SQL + 옵션 결정) + **§12 Definition of Done** (정량 + 정성 + 산출물 + 회귀) + **§13 회귀 차단 영역** (eval 52~68 회귀 0 + EMAIL-P0-2 + INFRA-1 강화) + **§14 변경 이력** 박제.
  - **메인 정밀 발견 (직접 Read)**: 모순-F 본질 = (1) `prisma/schema.prisma` 26 테이블 33 FK 관계 중 24 미정의 (chat_messages 1 Cascade 박제, webhook_events FK 0건) + (2) **raw FK 15 테이블 = `@relation` directive 박제 0건** (raw `authorId String` 컬럼만 박제, ORM 모델 연결 + DB FK 제약 영역 영향) + (3) EMAIL-P0-2 incident raw에서 `works.author_id_fkey` 위반 = 현재 schema가 묵시 Restrict 동작하지만 명시 0건 (의도 불명확). 본 sprint 핵심 = (a) 33 FK 관계 onDelete 명시 (Cascade 16 / Restrict 8 / SetNull 9 / NoAction 0) + (b) raw FK 15 테이블 @relation 박제 + (c) 백필 SQL 옵션 A/B/C 사용자 결정 영역 + (d) dev → prod 16 단계 순서 + 사용자 명시 키워드 13건 + (e) rollback 절차 + 백업 영역 + grimoire-infrastructure agent 협업.
  - **§6 위험 분석 정밀화 (사용자 명시 핵심 영역)**: 시나리오 A (고아 행 0건) / B (N>0 — 옵션 결정) / C (race condition) + 옵션 A (placeholder) / B (직접 삭제 — 회계 영역 절대 금지) / C (archive — 회계 영역 강제) + dev → prod 16 단계 + rollback 6 케이스 + 위험도 매트릭스 8건. 사용자 명시 키워드 13건 박제 (Generator 진입 차단 강제).

---

## §15 참조 (file:line)

### 정본 문서

- `.claude/state/sprint-pay-p3-master-plan-draft.md` — PAY-P3 마스터 플랜 (본 sprint 위치 박제, Phase 1 네 번째 권장)
- `.claude/state/sprint-pay-p3-a-race-condition-draft.md` — PAY-P3-A Sprint 계약 (정합 패턴 정본)
- `.claude/state/sprint-pay-p3-b-polar-timeout-draft.md` — PAY-P3-B Sprint 계약 (정합 패턴 정본 + 17 섹션 구조)
- `.claude/state/sprint-pay-p3-c-retry-dedup-draft.md` — PAY-P3-C Sprint 계약 (정합 패턴 정본)
- `research/PAYMENT_AUDIT-2026-05-07.md §1` L29-30 — 모순-F raw + Author 삭제 시 Payment/CreditLog 고아 영역
- `.claude/state/incident-log.jsonl` L73 — EMAIL-P0-2 prod SQL UPDATE 백필 성공 raw (works.author_id_fkey 우회)
- `.claude/shared-contracts.md §11` — WebhookEventIdempotency (인접 영역, eventId @unique 멱등성)
- `.claude/shared-contracts.md §13` — RefundPaymentAtomically (인접 영역, refund_logs Restrict 정합)
- `.claude/shared-contracts.md §22` — PaymentRaceCondition (정합 영역, 영역 분리)
- `.claude/shared-contracts.md §23` — RetryDeduplication (정합 영역, 영역 분리)
- `.claude/shared-contracts.md §24` — PolarSDKTimeoutPolicy (PAY-P3-B 정합 영역, 영역 분리)
- `.claude/shared-contracts.md §25` (예정) — FKCascadePolicy 신설 정본 (본 sprint 산출)

### 핵심 코드 (server, 직접 Read 검증)

- `prisma/schema.prisma:11-29` Author 모델 — **본 sprint 영역 외 (Author 모델 자체는 수정 0)**
- `prisma/schema.prisma:31-48` Theme 모델 — themes.authorId Optional onDelete=SetNull 박제 영역
- `prisma/schema.prisma:50-70` Work 모델 — works.authorId onDelete=Restrict + works.themeId onDelete=SetNull 박제 영역
- `prisma/schema.prisma:72-95` Episode 모델 — episodes.workId onDelete=Cascade 박제 영역
- `prisma/schema.prisma:97-105` CreditLog 모델 — **raw FK + onDelete=Restrict 박제 영역 (영구 보존)**
- `prisma/schema.prisma:192-204` Payment 모델 — **raw FK + onDelete=Restrict 박제 영역 (회계 영구 보존)**
- `prisma/schema.prisma:249-259` ChatMessage 모델 — **이미 onDelete=Cascade 박제됨 (정합 검증)**
- `prisma/schema.prisma:387-398` AdminAuditLog 모델 — **raw FK + onDelete=Restrict 박제 영역 (감사 영구 보존)**
- `prisma/schema.prisma:423-435` RefundLog 모델 — **raw FK + onDelete=Restrict 박제 영역 (회계 영구 보존)**

### Sprint progress 박제 영역 (본 sprint 신설 후 영역)

- `reports/sprint-pay-p3-e-fk-cascade-progress.md` (Generator 진입 후 신설)

### 관련 sprint progress (완료)

- `reports/sprint-pay-p0-1/2/3-progress.md`
- `reports/sprint-pay-p1-1-refund-progress.md`
- `reports/sprint-pay-p1-3-retry-policy-progress.md`
- `reports/sprint-pay-p2-1/2/3/4-*.md`
- `reports/sprint-pay-p3-a-race-condition-progress.md` (Generator 진입 영역)
- `reports/sprint-pay-p3-c-retry-dedup-progress.md` (Generator 진입 영역)
- `reports/sprint-pay-p3-b-polar-timeout-progress.md` (Generator 진입 영역)

### 관련 정본 문서 (Generator가 갱신할 영역)

- `grimoire-server/docs/data-model.md` — 33 FK 관계 표 + onDelete 정책 매트릭스 (§3-1 정합)
- `grimoire-server/SCHEMA.md` — 26 테이블 onDelete 정책 박제
- `grimoire-server/SECURITY.md §4` — 데이터 보존 정책 (Restrict 8건 영구 보존 강제)
- `grimoire-server/ADR.md ADR-007` — 4 전략 결정 사유 (Cascade vs Restrict vs SetNull vs NoAction)
- `grimoire-server/MIGRATION.md` — 본 sprint 마이그레이션 절차 + rollback 박제
- `grimoire-server/docs/migration-rollback-procedure.md` 신설 — 사용자 영역 가이드 (백업 + 측정 SQL + 백필 SQL + rollback 명령)
- `grimoire-server/CLAUDE.md §9` — 결제/크레딧 원자성 절대 규칙 (정합 검증)

---

## §16 Initializer 종료 보고 영역

본 sprint Initializer 책임 영역 종료. **Generator (server agent + grimoire-infrastructure) 진입 차단 강제** — 사용자 검증 게이트 §7-1 13 단계 통과 후만 진입.

### 16-1. 사용자 검증 영역 명령 키워드 (즉시 진행 영역)

```
PAY-P3-E dev 고아 행 측정 진행
```

(§7-1 단계 1 — dev DB 33 측정 SQL 실행 영역)

### 16-2. 산출물 절대경로

- `.claude/state/sprint-pay-p3-e-fk-cascade-draft.md` (본 파일, ~880 lines)

### 16-3. 본 sprint 진행 0건 영역 (Initializer 책임 영역 외)

- ❌ Prisma schema 직접 수정 0건
- ❌ DB migration 적용 0건
- ❌ DB SQL 직접 실행 0건
- ❌ commit / push 0건
- ❌ Generator 진입 0건 (사용자 검증 게이트 통과 전)

### 16-4. 본 sprint 진행 영역 (Initializer 책임 영역 정합)

- ✅ Prisma schema 직접 grep 박제 (33 FK 관계 + raw FK 15 테이블 + chat_messages 1 Cascade)
- ✅ EMAIL-P0-2 incident raw 직접 인용 (L73)
- ✅ 26 테이블 33 FK 관계 onDelete 권장 매트릭스 박제 (Cascade 16 / Restrict 8 / SetNull 9)
- ✅ 시나리오 A/B/C 위험 분석 박제
- ✅ 옵션 A/B/C 백필 SQL 박제 + Initializer 권장 박제 (회계 영역 옵션 C 강제)
- ✅ dev → prod 16 단계 순서 박제 + 사용자 명시 키워드 13건 박제
- ✅ rollback 절차 6 케이스 박제 + 백업 명령 박제
- ✅ AC BDD 8건 시나리오 박제
- ✅ 검증 매트릭스 (jest / eval / sensor / shared-contracts §25 / 정본 동시 갱신 영역) 박제
- ✅ 멀티에이전트 위임 매트릭스 박제 (grimoire-infrastructure 협업 영역)
- ✅ incident-log 박제 의무 (Mitchell Ghostty 정합) 박제
- ✅ Definition of Done 채점 기준 박제

---

**상태**: Sprint 계약 17 섹션 + AC BDD 8건 + §6 위험 분석 정밀화 (사용자 명시 핵심 영역) + **사용자 결정 박제 (2026-05-09 결정 A/B 정합)** 박제 완료 (`.claude/state/` Draft 영역, PP-13 화이트리스트 통과). **본 sprint Full 영역 진행 명시 박제** (결정 B): 33 FK 매트릭스 + 15 @relation 신설 + 백필 + 마이그레이션 모두 + 회계 8건 Restrict 강제 (결정 A). **USER-SOFT-DELETE sprint 후속 영역 분리 박제** (결정 A): `.claude/state/sprint-user-soft-delete-candidate.md` 후속 후보 영역 박제 (Author hard delete 자체가 일상 운영에서 발생 X 영역 정합). **다음 단계 = 사용자 검증 게이트 §7-1 13 단계 진입 (Generator 진입 절대 금지 영역)**. 본 Draft가 server + infrastructure agent 진입 정본 — 모호 영역 0건. shared-contracts §25 FKCascadePolicy 신설 영역 박제. 사용자 검증 게이트 통과 후만 즉시 server agent (Generator) 위임 → grimoire-infrastructure agent 협업 → qa Evaluator 위임 → 메인 commit/push 진행. **USER-SOFT-DELETE sprint 영역 진입 게이트 = PAY-P3-E sprint 종료 후만** (사용자 명시 키워드 `USER-SOFT-DELETE sprint Initializer 진행` 영역 정합).
