# Sprint Progress — publishTheme bakedCssUrl 절대화 (P1-#7)

> **Sprint ID**: sprint-baked-css-url-absolute
> **Initializer**: grimoire-planner (세션 #10_7 묶음 II 작업 C)
> **착수일**: 2026-05-03
> **마감**: 본 세션 종료 전 (server 1.5h + web 0.5h + qa 0.5h ≒ 2.5h)
> **PLANNING 근거**: HANDOVER_NEXT_SESSION.md §2-2 작업 C / PLANNING_GRIMOIRE.md P1-#7 (publishTheme bakedCssUrl 무효 처리)
> **Initializer 패턴**: 책 Ch 16 Anthropic 3-에이전트 (Initializer → Generator → Evaluator) — 묶음 II 2회차 시범

본 progress.md는 **Generator(grimoire-server + grimoire-web)와 Evaluator(grimoire-qa)의 단일 진실(single source of truth)** 입니다. 모든 의사결정·범위·검증 게이트는 이 문서를 정본으로 합니다. 모호 시 본 문서를 갱신한 후 진행하십시오.

---

## 0. 한 줄 목표 (Goal)

> `themes.baked_css_url` DB 컬럼은 **항상 절대 URL(Blob CDN)** 또는 **NULL(폴백)** 만 박제한다. 상대 경로(`/api/themes/css/{slug}`) 박제를 폐지하고, 응답 시점에 server가 환경별 base URL로 동적 절대화하여 web에 반환한다. web은 항상 절대 URL 또는 null을 받아 `<link rel="stylesheet" href={bakedCssUrl}>`로 단순 로드한다.

---

## 1. 배경 (Why) — 메인 사전 파악 박제

### 1-1. 현재 동작 (버그)

**server `grimoire-server/src/application/theme/bake-theme.usecase.ts:42-46`**:
```ts
} else {
  cssUrl = `/api/themes/css/${authorSlug}`  // ← 상대 경로 박제
}
await this.themeRepo.updateBakedCssUrl(theme.id, cssUrl)
```
- Blob Storage 미설정 시(localhost) → DB에 상대 경로 박제 → dev/prod 환경 전환 시 무효화되지 않음
- Blob 업로드 실패 시 catch에서도 상대 경로로 박제 → 같은 버그 재현
- `themes.controller.ts:172~177` `findByAuthorSlug` 응답이 Theme model을 그대로 spread → DB 박제값(상대 경로)이 그대로 web에 전파

**web `grimoire-web/src/app/[author]/layout.tsx:39~46`**:
- 주석에 "절대/상대 둘 다 허용" 명시 — 본 Sprint로 "절대 URL 또는 NULL만"으로 단순화
- 상대 경로 수신 시 현재 origin 기준 → BFF 프록시 hop 추가, CDN 활용 불가 (성능 손실 + CDN 캐싱 무효)

### 1-2. 영향 범위
- localhost ↔ dev ↔ prod 간 DB 박제 무효 가능성
- Blob Storage 미설정 환경에서 박제된 후 Blob 활성화 시 stale URL 잔존
- web layout.tsx의 "절대/상대 모두 허용" 분기 코드 정리 가능

---

## 2. 결정 — 방향 B (server 동적 절대화) 채택

### 2-1. 비교

| 방향 | 설명 | 환경분리 | 마이그레이션 | 호환성 | 복잡도 | 채택 |
|------|------|---------|-------------|-------|-------|------|
| **A** | DB는 절대 URL OR NULL, 폴백은 web이 처리 | 약함 (web env 의존) | 단순 (NULL 초기화) | 양호 | 낮음 | ❌ |
| **B** | DB는 절대 URL OR NULL, 응답 시 server가 동적 절대화 | **강함 (server env 단일 소스)** | 단순 (NULL 초기화) | 양호 | 중간 | ✅ |
| **C** | 컬럼 분리(blob_url + fallback_relative) | 강함 | 복잡 (마이그레이션 +호환층) | 약함 | 높음 | ❌ |

### 2-2. 방향 B 채택 근거
1. **환경 분리 강제**: server 단일 환경변수(`PUBLIC_API_BASE_URL` or 요청 host 기반)로 dev/prod 정합화 → DB 박제 무효 0건
2. **마이그레이션 단순**: 기존 row의 상대 경로 값을 NULL로 초기화 → 다음 publishTheme 호출 시 자동 재박제
3. **호환성**: `bakedCssUrl: String?` 이미 NULL 허용 → 무중단 가능
4. **web 단순화**: layout.tsx의 "상대/절대 분기 주석" 제거 → 항상 절대 URL 또는 null
5. **CDN 가용성 보존**: Blob 활성 시 절대 URL 그대로 → CDN 캐싱 효과 유지

### 2-3. 방향 A 기각 근거
- web env 의존 → 멀티 도메인(BFF + 직접) 환경에서 일관성 약화
- 향후 모바일 앱 클라이언트 추가 시 같은 폴백 로직 중복 필요

### 2-4. 방향 C 기각 근거
- 마이그레이션 + 호환층 복잡 → 본 Sprint 범위 초과
- shared-contracts §1 위반 위험 (Theme model 시그니처 2개 필드 추가)

### 2-5. cost-accountant 사전 의견 처리
- **AI 호출 0건** (Blob 업로드는 외부 스토리지 비용만, AI API 무관) → §0 무관
- **단**, 응답 시 동적 절대화는 매 GET /api/themes/{slug} 호출당 실행 (CPU 부하) → cost-accountant 사후 검증으로 충분
- 본 Sprint는 **cost-accountant HANDOFF 면제** (AI 호출 0건 + 인프라 비용 영향 0건)

---

## 3. 범위 (Scope)

### IN — server (정본 변경)

1. **`grimoire-server/prisma/schema.prisma`** — 변경 없음 (`bakedCssUrl: String?` 그대로)

2. **`grimoire-server/prisma/migrations/{ts}_baked_css_url_clear_relative/`** 신설
   - **방법**: `npx prisma migrate dev --create-only --name baked_css_url_clear_relative` 후 SQL 수동 작성
   - up.sql:
     ```sql
     UPDATE themes
     SET baked_css_url = NULL
     WHERE baked_css_url LIKE '/api/themes/css/%';
     ```
   - down.sql: 복원 불가 (NULL → 기존 값 복원 불가) → 주석으로 명시
     ```sql
     -- 본 마이그레이션은 stale 상대 경로를 NULL로 정리하는 일회성 작업.
     -- 롤백은 publishTheme 재호출로 자동 재박제됨.
     -- (down 미작성 — Prisma migrate resolve --rolled-back으로 메타만 정리)
     ```
   - **DB 무중단 보장**: NULL 허용 컬럼 + DELETE 아님 → 무중단 OK
   - **백업 권장**: server agent가 `pg_dump --table=themes`로 사전 백업 (1MB 미만)

3. **`grimoire-server/src/domain/port/outbound/theme-repository.port.ts`**
   - `updateBakedCssUrl(themeId: string, url: string): Promise<void>`
     → `updateBakedCssUrl(themeId: string, url: string | null): Promise<void>`
   - **shared-contracts §1 영향**: 본 인터페이스는 shared-contracts에 명시되지 않음 → 본 Sprint 종료 시 server agent가 `.claude/shared-contracts.md`에 추가 박제 검토 (선택)

4. **`grimoire-server/src/adapter/outbound/persistence/theme.repository.ts`** (구현체 — 위치 추정, server agent가 실제 경로 확인)
   - Prisma `update({ data: { bakedCssUrl: url } })` 시그니처가 이미 `string | null` 허용 → 변경 최소

5. **`grimoire-server/src/application/theme/bake-theme.usecase.ts`**
   - `cssUrl = '/api/themes/css/${authorSlug}'` 라인 2곳(L40 catch, L43 else) → `cssUrl = null` 로 변경
   - 반환값 시그니처: `Promise<{ cssUrl: string; css: string }>` → `Promise<{ cssUrl: string | null; css: string }>`
   - 호출자(controller `publish`)도 `cssUrl: string | null` 허용

6. **`grimoire-server/src/application/theme/get-theme.usecase.ts`** 또는 **`theme.controller.ts`** 응답 변환부
   - **선택지 (server agent 결정)**:
     - (a) `GetThemeUseCase.execute()`/`resolve()` 내부에서 절대화
     - (b) `theme.controller.ts` `findByAuthorSlug` / `resolveTheme` 응답 직전 절대화 helper 호출
   - **권장**: (b) — 도메인 순수성 보존(usecase는 DB 박제 그대로), 응답 변환은 어댑터 책임
   - 절대화 helper 위치 권장: `grimoire-server/src/lib/url-resolver.ts` (신설)
     ```ts
     /** baked_css_url이 NULL이면 /api/themes/css/{slug} 절대 URL로 폴백 */
     export function resolveBakedCssUrl(
       dbValue: string | null,
       authorSlug: string,
       publicApiBaseUrl: string,  // env: PUBLIC_API_BASE_URL
     ): string {
       if (dbValue && /^https?:\/\//.test(dbValue)) return dbValue
       return `${publicApiBaseUrl.replace(/\/$/, '')}/themes/css/${authorSlug}`
     }
     ```
   - 환경변수 `PUBLIC_API_BASE_URL`:
     - localhost: `http://localhost:3000/api`
     - dev: `https://dev-api.grimoire-book.com/api`
     - prod: `https://api.grimoire-book.com/api`
   - **`docs/environments.md`** 추가 (server 정본)

7. **`grimoire-server/src/infrastructure/config/env.validation.ts`** (위치 추정)
   - `PUBLIC_API_BASE_URL` 필수 환경변수 추가 + Joi/Zod 검증

8. **테스트 신설/갱신**
   - `bake-theme.usecase.spec.ts`: Blob 비활성 시 `cssUrl === null` 검증
   - `bake-theme.usecase.spec.ts`: Blob 업로드 실패 시 `cssUrl === null` 검증 (catch 분기)
   - `theme.controller.spec.ts` (있을 시): 응답에 절대 URL 박제 검증
   - `url-resolver.spec.ts` (신설): NULL → 절대 URL 폴백 / 절대 URL → 그대로 / `PUBLIC_API_BASE_URL` 트레일링 슬래시 처리

9. **문서 동기화 (server 정본)**
   - `grimoire-server/docs/data-model.md` — `themes.baked_css_url` 컬럼 설명 업데이트 ("절대 URL 또는 NULL")
   - `grimoire-server/docs/api-contract.md` — `GET /api/themes/{slug}` 응답 `bakedCssUrl` 필드 설명 ("항상 절대 URL")
   - `grimoire-server/docs/environments.md` — `PUBLIC_API_BASE_URL` 환경변수 추가
   - `grimoire-server/SCHEMA.md` — `Theme.bakedCssUrl` 주석 갱신
   - `grimoire-server/MIGRATION.md` — 본 마이그레이션 절차 박제

### IN — web (정본 따름)

1. **`grimoire-web/src/app/[author]/layout.tsx`** (L39~46)
   - 주석 "절대/상대 둘 다 허용" → "항상 절대 URL 또는 null"로 단순화
   - 로직 변경 불필요 (`typeof data.bakedCssUrl === 'string' && data.bakedCssUrl.length > 0`은 그대로)
   - 단, "상대 경로 fallback" 코멘트 제거

2. **`grimoire-web/src/types/api.ts`** (위치 추정 — Theme 타입 정의)
   - `bakedCssUrl: string | null` 명시 (이미 그럴 가능성 높음, server agent 확인)

3. **`grimoire-web/docs/data-model.md`** — server 정본 동기 (수동 복사)

### IN — claude-docs (eval task 신설)

1. **`eval/tasks/regression-51-baked-css-url-absolute.json`** (regression 50→51)
   - category: `api_contract`
   - eval_criteria:
     - `grep_count`: server `bake-theme.usecase.ts`에 `'/api/themes/css/'` 박제 없음 (== 0)
     - `grep`: `url-resolver.ts` 또는 동등 helper 존재
     - `grep`: server `data-model.md`에 "절대 URL 또는 NULL" 명시
   - threshold: 1.0 / runs: 1

### OUT (Out of Scope)
- Blob Storage 어댑터 신설 (별도 과제 — 현재 구현은 인터페이스만 존재, 실제 Azure Blob 구현은 없음)
- CDN 캐시 무효화 (Blob 활성 후 별도 과제)
- 복수 작품별 theme의 baked_css_url 분리 (현재 작가 단위)
- `themes.controller.ts` `getThemeCSS` 라우트 자체 변경 (response는 CSS 본문 직접 반환 — 본 Sprint 무관)

---

## 4. Acceptance Criteria (AC)

Evaluator(qa)는 아래 6건을 **순차적으로** 검증합니다. 모두 PASS여야 Sprint 종료.

| # | 시나리오 | 기대 결과 | 검증 방법 |
|---|---------|----------|----------|
| AC-1 | localhost에서 `POST /api/themes/publish/{slug}` 호출 (Blob 미설정) | DB `themes.baked_css_url`에 NULL 박제됨 | psql 또는 prisma studio로 직접 확인 |
| AC-2 | localhost에서 `GET /api/themes/{slug}` 호출 | 응답 `bakedCssUrl`이 `http://localhost:3000/api/themes/css/{slug}` (절대 URL) | curl + jq 확인 |
| AC-3 | dev 환경에서 같은 호출 | 응답 `bakedCssUrl`이 `https://dev-api.grimoire-book.com/api/themes/css/{slug}` | dev curl |
| AC-4 | 마이그레이션 적용 후 기존 stale 상대 경로(`/api/themes/css/...`) row 0건 | `SELECT COUNT(*) FROM themes WHERE baked_css_url LIKE '/api/themes/css/%'` == 0 | psql |
| AC-5 | `[author]/layout.tsx`에 "상대 경로 fallback" 주석/코드 0건 | grep 결과 0건 | grep |
| AC-6 | sensor 5종 + npm test (server + web) 모두 PASS, drift 0 | 전체 PASS | sensor + test 실행 |

**모호성 정량**: AC 6건 모두 binary(PASS/FAIL) — Ambiguity ≤ 0.1 (하네스 EDD 기준 통과)

---

## 5. Test Plan

### 5-1. server 유닛 테스트 (Jest)
- `bake-theme.usecase.spec.ts`:
  - `it('Blob 비활성 시 cssUrl=null + DB null 박제')`
  - `it('Blob 업로드 실패 시 catch에서 cssUrl=null')`
  - `it('Blob 활성 + 업로드 성공 시 절대 URL 박제')` (기존)
- `url-resolver.spec.ts` (신설):
  - `it('null 입력 → 절대 URL 폴백')`
  - `it('절대 URL 입력 → 그대로 반환')`
  - `it('PUBLIC_API_BASE_URL 트레일링 슬래시 정규화')`
- `theme.controller.spec.ts` (있을 시 — 없으면 e2e로 대체):
  - `it('GET /api/themes/{slug} 응답 bakedCssUrl이 절대 URL')`

### 5-2. server e2e (선택)
- localhost 직접 curl: `curl http://localhost:3000/api/themes/{슬러그}` → `bakedCssUrl` 필드 검증

### 5-3. web 유닛 테스트
- 변경 최소 (주석 정리만) → 기존 layout.spec 회귀 PASS만 확인

### 5-4. 마이그레이션 검증
- `npx prisma migrate dev` (localhost) → up.sql 적용 확인 → 기존 stale row 0건
- `npx prisma migrate status` PASS

### 5-5. 회귀 (eval)
- `bash eval/scripts/eval-runner.sh` → regression-51 포함 전체 PASS (drift 0)

### 5-6. 수동 검증 (개발 서버)
- `npm run start:dev` (server) + `npm run dev` (web)
- /dashboard/theme → publish 버튼 → DB 확인 (NULL) → /{author}/ 접근 → bakedCssUrl 절대 URL 확인

---

## 6. 검증 게이트 (Gates)

Generator(server + web)는 커밋 직전 아래 모두 PASS여야 합니다.

| 게이트 | 명령 | 기대 |
|-------|------|------|
| TypeScript (server) | `cd grimoire-server && npx tsc --noEmit` | 0 errors |
| TypeScript (web) | `cd grimoire-web && npx tsc --noEmit` | 0 errors |
| Lint (server) | `cd grimoire-server && npm run lint` | 0 errors |
| Lint (web) | `cd grimoire-web && npm run lint` | 0 errors |
| Unit test (server) | `cd grimoire-server && npm test -- bake-theme \| url-resolver` | PASS |
| Unit test (web) | `cd grimoire-web && npm test` | 회귀 PASS |
| Migration status | `cd grimoire-server && npx prisma migrate status` | up to date |
| 회귀 task | `bash eval/scripts/eval-runner.sh` | regression-51 포함 전체 PASS |
| sensor-shared-contracts | `bash .claude/scripts/sensor-shared-contracts.sh` | drift 0 (인터페이스 변경 시 contracts 갱신 필수) |
| sensor-server | `bash .claude/scripts/sensor-server.sh` (있을 시) | PASS |
| sensor-web | `bash .claude/scripts/sensor-web.sh` (있을 시) | PASS |
| sensor-docs-sync | `bash .claude/scripts/sensor-docs-sync.sh` | drift 0 (server docs 6건 동기 확인) |
| sensor-instruction-degradation | `bash .claude/scripts/sensor-instruction-degradation.sh` | WARN 0 |
| sensor-agent-priority-labels | `bash .claude/scripts/sensor-agent-priority-labels.sh` | PASS |
| sensor-agent-interaction | `bash .claude/scripts/sensor-agent-interaction.sh` | PASS |

### Evaluator(qa) 추가 게이트
- 위 sensor 5종 독립 재실행 (server + web 양쪽)
- AC-1~AC-6 채점 → QA_REPORT.md `## 3. Eval 결과` 하위에 `### sprint-baked-css-url-absolute 통과율` 박제 (6/6 = 100% 목표)
- dev 환경 curl 검증 (AC-3) — qa가 dev 배포 후 직접 검증

---

## 7. 산출물 체크리스트 (Generator 갱신 대상)

Generator(server + web)가 작업 진행 시 본 섹션의 체크박스를 즉시 갱신합니다.

### server (grimoire-server) — 2026-05-03 Generator 완료
- [x] `prisma/migrations/20260503130451_baked_css_url_clear_relative/migration.sql` 신설 (DDL 0건, DML 단발, down 미작성 코멘트 박제)
- [x] `pg_dump --table=themes` 사전 백업 박제 — localhost 생략 (themes row 20건, baked_css_url IS NOT NULL 0건). dev/prod는 사용자 명시 시 시행
- [x] `src/domain/port/outbound/theme-repository.port.ts` 시그니처 `string | null` 적용 + JSDoc 박제
- [x] `src/adapter/outbound/persistence/prisma-theme.repository.ts` `string | null` 시그니처 반영
- [x] `src/application/theme/bake-theme.usecase.ts` 상대 경로 박제 2곳 → `cssUrl = null` (반환 시그니처도 `string | null`)
- [x] `src/lib/url-resolver.ts` 신설 + `url-resolver.spec.ts` (8건 PASS)
- [x] `src/adapter/inbound/http/controller/theme.controller.ts` `publish` / `findByAuthorSlug` / `resolveTheme` 3곳에 `resolveBakedCssUrl()` 적용
- [x] `src/infrastructure/config/env.validation.ts` `PUBLIC_API_BASE_URL` 필수 + 절대 URL 형식 검증 추가
- [x] `bake-theme.usecase.spec.ts` 갱신 — Blob 미설정/실패 시 `cssUrl=null` + 상대 경로 회귀 차단 spec
- [x] `env.validation.spec.ts` 신설 (5건 PASS)
- [x] `docs/data-model.md` (정본) `themes.baked_css_url` 정책 박제 (절대 URL OR NULL)
- [x] `docs/api-contract.md` (정본) GET/POST/resolve 3 엔드포인트 응답 명세 갱신
- [x] `docs/environments.md` (정본) `PUBLIC_API_BASE_URL` 환경변수 + 환경별 값 박제
- [x] `SCHEMA.md` `Theme.bakedCssUrl` 정책 박제
- [x] `MIGRATION.md` §7-Z 본 마이그레이션 절차 + 롤백 정책 박제
- [x] `TECH_STATUS.md` P1-#7 완료 박제
- [x] `CHANGELOG.md` v0.30.0 박제 (Feat + DB 마이그레이션 항목)
- [x] `.env` + `.env.example` `PUBLIC_API_BASE_URL` 추가 (localhost 기본값)
- [x] 루트 `SYNC_STATUS.md` 갱신 (server API 응답 변경 박제)
- [ ] `.claude/shared-contracts.md` 본 인터페이스 추가 (선택 — 본 Sprint에서 미적용. Theme 응답 시그니처는 §11 신설 필요 시 별도 PR로 분리)

### web (grimoire-web)
- [x] `src/app/[author]/layout.tsx` 주석 정리 (상대 경로 fallback 제거) — 2026-05-03 Generator
  - 주석을 "항상 절대 URL 또는 NULL"로 단순화 + Sprint 근거 박제
  - bakedCssUrl 응답 처리 로직을 `_helpers/baked-css-url.ts` resolveBakedCssUrl로 위임 (의미 불변, testability 확보)
- [x] `src/app/[author]/_helpers/baked-css-url.ts` 신설 — Generator (방어선 helper, 상대 경로 변환 로직 포함 0건)
- [x] `src/app/[author]/_helpers/baked-css-url.test.ts` 신설 — Generator (8 it / 절대 URL · null · undefined · 빈문자열 · 비문자열 · dev/prod URL)
- [x] `src/types/api.ts` `Theme.bakedCssUrl: string | null` JSDoc 박제 — Generator (Sprint 근거 + "절대 URL 또는 NULL" 명시)
- [ ] `docs/data-model.md` server 정본 복사 동기 — **SKIP**: server Generator(grimoire-server) 미완료 시점 — server `feature/baked-css-url-absolute` 브랜치 commit 후 별도 동기화 필요
- [ ] `docs/api-contract.md` server 정본 복사 동기 — **SKIP**: 위와 동일
- [ ] `TECH_STATUS.md` 갱신 — Generator 본 단계 boundary 외 (커밋 단계에서 처리)
- [ ] 루트 `SYNC_STATUS.md` 갱신 — Generator 본 단계 boundary 외

### web 회귀 결과 (Generator self-verification)
- `npx tsc --noEmit`: ✅ 0 errors
- `npm test`: ✅ 9 files / 133 tests PASS (신규 8건 포함, 기존 회귀 0 fail)
- `npm run lint`: ✅ 0 errors / 5 warnings (모두 기존 코드 — AuthorSpace/CardTransition `setState within effect`, 본 작업 무관)
- AC-5 자체검증 grep: layout.tsx의 "상대 경로 fallback 처리" 주석/코드 0건 (잔존 `/api/themes/css/` 박제는 모두 "폐지됨" 설명 주석 + 테스트 fixture 절대 URL)

### claude-docs (eval task)
- [ ] `eval/tasks/regression-51-baked-css-url-absolute.json` 신설
- [ ] `bash eval/scripts/eval-runner.sh` 1회 실행 → drift 0 확인

---

## 8. 위험·롤백 (Risk & Rollback)

### 8-1. 위험 식별

| # | 위험 | 영향 | 완화 |
|---|-----|------|-----|
| R1 | up.sql NULL 일괄 업데이트가 prod에서 의도치 않은 row 영향 | 작가 테마 stale | LIKE 패턴 엄격 (`/api/themes/css/%` only), 사전 백업 |
| R2 | `PUBLIC_API_BASE_URL` env 누락 → 응답 절대화 실패 | bakedCssUrl 잘못된 값 또는 throw | env.validation.ts에서 필수 검증, 누락 시 부팅 실패 |
| R3 | resolveBakedCssUrl helper 누락 호출 → 일부 라우트 NULL 그대로 노출 | web `<link>` 태그 미렌더링 (단, ThemeProvider 인라인 스타일이 보완) | controller spec으로 두 라우트 모두 검증 |
| R4 | Prisma 마이그레이션 down 미작성 → 롤백 불가 | 운영 사고 시 복구 어려움 | publishTheme 재호출로 자동 재박제 가능 → 롤백 불요 (down 코멘트로 명시) |
| R5 | shared-contracts 갱신 누락 시 다음 agent drift | 통합 단계 깨짐 | sensor-shared-contracts 게이트 + 본 progress §10 명시 |

### 8-2. 롤백 절차
1. 서비스 롤백: 이전 commit으로 revert (git revert) → publishTheme의 상대 경로 박제 동작 복원
2. DB 롤백: 불필요 (NULL → 다음 publishTheme 호출 시 자동 재박제)
3. 마이그레이션 메타: `npx prisma migrate resolve --rolled-back baked_css_url_clear_relative`

### 8-3. 무중단 배포
- DB 마이그레이션은 NULL 일괄 업데이트만 → DDL 잠금 없음, 무중단 OK
- 환경변수 `PUBLIC_API_BASE_URL`는 배포 전 Azure Container App secrets에 추가 → 배포 후 부팅 실패 방지

---

## 9. 마이그레이션 정책 (server agent 준수 사항)

본 섹션은 server agent가 마이그레이션 작성 시 따라야 할 정책입니다.

1. **명명**: `{YYYYMMDDHHMMSS}_baked_css_url_clear_relative`
2. **up.sql 정책**:
   - WHERE 절은 `LIKE '/api/themes/css/%'` 정확 매칭 (절대 URL이 우연히 매칭되지 않도록)
   - 절대 URL(`http://`, `https://` 시작)은 그대로 보존
3. **down.sql 정책**:
   - 본 마이그레이션은 일방향 — down 미작성, 코멘트로 명시
   - 운영 사고 시 publishTheme 재호출로 자동 재박제됨
4. **사전 백업** (server agent 선택):
   - `pg_dump --table=themes -d {DATABASE} > themes-backup-{ts}.sql` (1MB 미만 예상)
   - localhost는 생략 가능, dev/prod는 권장
5. **MIGRATION.md 갱신**: 본 마이그레이션 절차 + 위 정책 박제 (코드 변경과 같은 commit)
6. **호환성**: `bakedCssUrl: String?` 이미 NULL 허용 → schema.prisma 변경 없음 → DDL 없음 → 무중단

---

## 10. shared-contracts 갱신 검토

본 Sprint에서 변경되는 인터페이스:

| 인터페이스 | 변경 | shared-contracts 영향 |
|-----------|-----|---------------------|
| `ThemeRepositoryPort.updateBakedCssUrl` | `url: string` → `url: string \| null` | shared-contracts §1~10에 명시되지 않음 → 갱신 불요 |
| `BakeThemeUseCase.execute` 반환 | `cssUrl: string` → `cssUrl: string \| null` | 동상 |
| `GET /api/themes/{slug}` 응답 `bakedCssUrl` | "절대 URL OR 상대" → "항상 절대 URL OR null" | API 응답 시그니처 — server agent가 `.claude/shared-contracts.md`에 §11(?) 신설 검토 (선택, 본 Sprint 종료 후) |

**결론**: 본 Sprint에서는 shared-contracts §1(PLANNER_REPORT)만 본 progress 박제 + DEV_REPORT 박제로 자동 정합. 인터페이스 자체 갱신은 server agent 판단(선택).

---

## 11. HANDOFF Chain

```
planner (Initializer — 본 progress + PLANNER_REPORT 작성 완료)
  ↓
cost-accountant (사전 — 면제. AI 호출 0건 + 인프라 비용 영향 0건. 사후 확인만)
  ↓ (병렬 진행 가능)
grimoire-server (Generator — §7 server 체크리스트 + DEV_REPORT.md Server 섹션)
grimoire-web    (Generator — §7 web 체크리스트 + DEV_REPORT.md Web 섹션)
  ↓
grimoire-qa (Evaluator — §4 AC 6건 채점 + §6 게이트 sensor 5종 + npm test 양 레포 + dev curl)
  ↓
사용자 (배포 게이트 최종 판정 — qa PASS 시 develop → main per-repo 머지)
```

- **next agent**: grimoire-server + grimoire-web (병렬) → grimoire-qa
- **마감**: 본 세션 종료 전 (2.5h)
- **단일 진실**: 본 progress.md (Generator/Evaluator 모두 본 progress.md를 Read 후 작업)

---

## 12. 참조

- HANDOVER_NEXT_SESSION.md §2-2 작업 C
- PLANNING_GRIMOIRE.md P1-#7 (publishTheme bakedCssUrl 무효 처리)
- `.claude/shared-contracts.md` §1 (PLANNER_REPORT 형식) + §4 (DEV_REPORT 형식)
- 책 Ch 16 Anthropic 3-에이전트 (Initializer → Generator → Evaluator) — 묶음 II 2회차
- 작업 B 진행 사례: `reports/sprint-theme-editor-name-sync-progress.md` (패턴 참조)
- `grimoire-server/CLAUDE.md` §3 문서 동기화 체크리스트 + §9 결제/크레딧 원자성 (본 Sprint 무관, 참조용)
- `grimoire-web/CLAUDE.md` §2 BFF + §7 문서 연동 규칙
