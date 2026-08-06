# Sprint Progress — email-p0-3-slug-login

> **Sprint ID**: sprint-email-p0-3-slug-login
> **세션**: #10_7 EMAIL-P0-3 (EMAIL_INTEGRITY_PLAN §13 — slug 로그인 마이그레이션, 사용자 명시 2026-05-05 "deerdevil@grimoire.app 가짜 이메일 박제 → slug + 비밀번호 로그인")
> **Initializer**: grimoire-planner (책 Ch 16 Anthropic 3-에이전트 패턴 — 묶음 III 1회차)
> **작성일**: 2026-05-04 (5)
> **단일 진실**: 본 파일이 Generator (server / web / claude-docs) + Evaluator (qa) 모두의 작업 정본. 모호하면 본 파일 갱신 후 합의.
> **선행 Sprint (PAY 묶음 5건 100% 완료)**:
> - PAY-P0-1 (sprint-pay-p0-1-webhook-event-id-idempotency-progress.md)
> - PAY-P0-2 (sprint-pay-p0-2-payment-reconciliation-cron-progress.md)
> - PAY-P0-3 (sprint-pay-p0-3-admin-credit-grant-ui-progress.md)
> - PAY-P1-1 (sprint-pay-p1-1-refund-atomicity-progress.md)
> - PAY-P1-3 (sprint-pay-p1-3-retry-policy-progress.md)
> **사용자 명시**: slug (예: `deerdevil`) + 비밀번호 1회 로그인. 이메일 입력도 후향호환 유지. OAuth 자동 링크 + SignupHistory 정책 변경은 본 sprint OUT.

---

## 1. 개요

### 1-1. 목표 (한 줄)

`POST /api/auth/login` DTO에 `email` 또는 `slug` (XOR) 1택을 수용하도록 확장하여 `deerdevil` slug + 비밀번호로 로그인 가능하게 한다. `auth.usecase.login`은 `findByEmail(email) ?? findBySlug(slug)` 분기로 두 식별자를 모두 처리하며, 기존 email 로그인은 후향호환 100% 보장. web 로그인 폼은 입력칸 1개로 통합되어 `/^[^\s@]+@[^\s@]+\.[^\s@]+$/` 정규식으로 자동 판별한다.

### 1-2. 규모

server ~3h (LoginDto 확장 + auth.usecase 분기 + access-log slug + spec ≥4 it 추가). web ~3h (login/page.tsx 통합 input + AuthProvider + lib/api login 시그니처 + e2e 1 it). claude-docs ~30min (sensor + regression-59 + shared-contracts §15). 총 ~6.5h.

### 1-3. 도메인

server (Phase 1) + web (Phase 2) 동시 진행. claude-docs (sensor + eval + shared-contracts) 병렬. DB schema 변경 0건 (`Author.email @unique` + `Author.slug @unique` 이미 박제, 검증 SQL은 사용자 영역 1회 실행).

### 1-4. 외부 검증

- jest spec PASS (server 543→555+, +12 이상 — 기존 회귀 + 신규 슬러그 로그인 4 it + email XOR slug 검증 it)
- vitest spec PASS (web 140→145+, AuthProvider login 시그니처 회귀 + lib/api login 회귀)
- e2e spec PASS (auth.spec.ts slug 로그인 1 it 추가)
- eval task `regression-59-slug-login` 신설 (eval 56→57 PASS)
- sensor `sensor-slug-login` 신설 (회귀 + Generator 산출물 검증)
- dev 환경 `POST /api/auth/login` `{ slug: "deerdevil", password: "..." }` raw curl 검증

### 1-5. 백엔드 인벤토리 (실측, EMAIL_INTEGRITY_PLAN §13-2 정합)

| 영역 | 위치 | 상태 |
|---|---|---|
| **DTO** | `auth.dto.ts:21-28` LoginDto (`@IsEmail email!` + `@IsString password!`) | ⚠️ 변경 대상 — `email?` + `slug?` + custom validator (XOR) |
| **UseCase** | `auth.usecase.ts:67-82` `login({ email, password })` → `findByEmail` 단독 | ⚠️ 변경 대상 — `findByEmail(email) ?? findBySlug(slug)` 분기 |
| **Repository Port** | `author-repository.port.ts` `findByEmail` + `findBySlug` 둘 다 박제 | ✅ 변경 0건 (또는 선택적 `findByEmailOrSlug` 추가) |
| **JWT Payload** | `auth.usecase.ts:193-195` `{ sub, slug, role }` (slug 이미 포함) | ✅ 변경 0건 |
| **Schema** | `prisma/schema.prisma:11-29` `email @unique` + `slug @unique` 둘 다 박제 | ✅ 변경 0건 |
| **AuthGuard 이후** | request.user.sub 100% authorId 기반 | ✅ 변경 0건 (auth 통과 후 백엔드 로직 무관) |
| **AccessLog** | `access-log.service.ts:103,98,107` action+email+authorId 박제 | ⚠️ 변경 대상 — slug 식별자 양립 박제 |

### 1-6. 웹 인벤토리 (실측, EMAIL_INTEGRITY_PLAN §13-2 정합)

| 영역 | 위치 | 상태 |
|---|---|---|
| **로그인 폼** | `login/page.tsx:52-62` `<input type="email">` + `placeholder="your@email.com"` | ⚠️ 변경 대상 — type=text + label/placeholder 통합 + 자동 판별 |
| **폼 submit** | `login/page.tsx:28,67` `login(email, password, recaptcha)` | ⚠️ 변경 대상 — login(emailOrSlug, password, recaptcha) |
| **AuthProvider** | `src/features/auth/AuthProvider.tsx` login 시그니처 | ⚠️ 변경 대상 — emailOrSlug → 정규식 분기 → `{ email }` 또는 `{ slug }` 페이로드 |
| **API 클라이언트** | `src/lib/api.ts:35-40` `login({ email, password })` | ⚠️ 변경 대상 — `{ email?, slug?, password }` |
| **Type** | `src/types/api.ts` LoginRequest | ⚠️ 갱신 대상 |
| **e2e** | `e2e/auth.spec.ts:34-45` placeholder("your@email.com") 의존 | ⚠️ 변경 대상 — `getByLabel("이메일 또는 슬러그")` + slug 1 it 추가 |

### 1-7. 현재 갭 (EMAIL_INTEGRITY_PLAN §13-1 사용자 명시)

> 현재 ProjectGrimoire 로그인은 `deerdevil@grimoire.app` 같은 가짜 이메일 박제 — 실제 동작 안 함. `Author.slug @unique`는 이미 스키마에 박제되어 있으나 로그인 식별자로 미사용. EMAIL-P0-2 (운영 DB 가짜 이메일 12~15 row 정리)와 동시 진행하여 deerdevil/lee-gwangsu 등 실제 사용자가 slug로 로그인 가능하도록 한다.

### 1-8. CERTI_PROJ 차용 결정

- **참조 0건**: 본 sprint는 100% Grimoire 자체 도메인 (slug 식별자는 이미 schema에 박제). 외부 프로젝트 차용 0건. 거짓말 차단 정책 §8-6에서 외부 프로젝트명 0건 강제.

---

## 2. AC (Acceptance Criteria) — 7건, BDD 패턴, Ambiguity ≤ 0.1

각 AC는 **실측 검증 가능한 raw stdout / grep 결과 / spec 결과 / sensor 결과**로 증명. Generator는 본 AC 미충족 시 작업 미완료 박제 (DEV_REPORT.md raw stdout 박제).

### AC-1: LoginDto 확장 — email XOR slug 1택 강제

**Given** Phase 1 server LoginDto 확장
**When** 클라이언트가 `POST /api/auth/login` 호출
**Then**
- `email` 박제 + `slug` 미박제 → 통과 (기존 로직)
- `slug` 박제 + `email` 미박제 → 통과 (신규 로직)
- 둘 다 박제 → BadRequestException ("이메일 또는 슬러그 중 하나만 박제하세요")
- 둘 다 미박제 → BadRequestException ("이메일 또는 슬러그가 필요합니다")
- `password` 항상 필수

**검증 명령**:
```bash
cd /Users/sokol/Git/ProjectGrimoire/grimoire-server
grep -nE "@IsOptional.*email|@IsOptional.*slug|@ValidateIf|@IsString.*slug" src/adapter/inbound/http/dto/auth.dto.ts
grep -nE "email XOR slug|이메일.*슬러그|emailOrSlug" src/adapter/inbound/http/dto/auth.dto.ts
npx jest -t "LoginDto|email XOR slug|XOR" src/adapter/inbound/http/dto 2>&1 | tail -20
```

**기대 raw 출력**:
- LoginDto에 `email?: string` + `slug?: string` 둘 다 `@IsOptional()` 박제
- custom validator (`@ValidateIf` 또는 `class-validator-rule`) XOR 강제 박제
- DTO spec ≥3 it 블록 PASS (정상 email / 정상 slug / 둘 다 박제 시 fail)

### AC-2: auth.usecase.login 분기 — findByEmail ?? findBySlug

**Given** AuthUseCase + AuthorRepositoryPort
**When** `login({ email, password })` 또는 `login({ slug, password })` 호출
**Then**
- `email` 박제 → `authorRepo.findByEmail(email)` 호출 1회
- `slug` 박제 → `authorRepo.findBySlug(slug)` 호출 1회
- 두 분기 모두 적중 author 없으면 `UnauthorizedException` 통일 메시지 ("이메일/슬러그 또는 비밀번호가 올바르지 않습니다")
- author 적중 후 bcrypt.compare 검증 흐름은 기존과 동일
- spec ≥4 it 블록 (정상 slug / 미존재 slug / 비번 불일치 / email 후향호환) + toHaveBeenCalledWith ≥4건 (더미 assertion 0건)

**검증 명령**:
```bash
grep -nE "findByEmail.*\\?\\?|findBySlug|input\\.slug|input\\.email" src/application/auth/auth.usecase.ts
grep -nE "describe.*'AuthUseCase|it\\('slug 로그인|it\\('email 후향호환" src/application/auth/auth.usecase.spec.ts
grep -cE "toHaveBeenCalledWith|toHaveBeenCalledTimes" src/application/auth/auth.usecase.spec.ts
npx jest -t "slug 로그인|email 후향호환" src/application/auth/auth.usecase.spec.ts 2>&1 | tail -25
```

**기대 raw 출력**:
- usecase 본문에 `findByEmail` ?? `findBySlug` 또는 분기 if/else 박제
- spec ≥4 신규 it 블록 + toHaveBeenCalledWith 호출 ≥4건 (정상 slug + 미존재 + 비번 + email 후향호환)
- 기존 email 로그인 spec 회귀 0건 (PASS 유지)

### AC-3: AccessLog slug 식별자 박제 + 양립 가능

**Given** access-log.service + auth.controller logging 흐름
**When** 사용자가 slug 또는 email로 로그인 후 AccessLog 기록
**Then**
- email 로그인 시 → AccessLog.identifier에 email 박제 (또는 별도 컬럼)
- slug 로그인 시 → AccessLog.identifier에 slug 박제
- 두 값 모두 author.id (FK) 기반 join으로 사후 추적 가능 (기존 authorId 박제 정합)
- 단순 식별자 한 컬럼이 아니라 `identifierType: 'email'|'slug'` 구분 또는 두 컬럼 양립 (Generator 결정 — Initializer 권고: 신설 컬럼 `identifierType` + 기존 `email` 컬럼은 nullable로 양립)

**검증 명령**:
```bash
grep -nE "identifierType|identifier_type|loginIdentifier" src/application/auth/access-log.service.ts
grep -nE "identifierType|loginIdentifier" src/adapter/inbound/http/controller/auth.controller.ts
grep -nE "identifierType" prisma/schema.prisma
npx jest -t "AccessLog|access-log" src/application/auth 2>&1 | tail -15
```

**기대 raw 출력**:
- service 본문에 identifierType 분기 박제
- spec PASS (slug 로그인 시 identifierType='slug' 검증)
- schema 변경 0건 또는 1건 (옵션 nullable 컬럼 추가) — Generator 결정 시 PR 박제

**Initializer 권고**: schema 변경 0건 우선. 기존 `email` 컬럼에 slug 박제하고 별도 컬럼 미신설. 단 logger 메시지에 `identifierType` 박제 (debug 추적용). 운영 후 사용자 결정에 따라 schema 확장 가능 (P2 후보).

### AC-4: 후향호환 검증 — 기존 email 로그인 회귀 0건

**Given** 기존 클라이언트 (email 로그인만 박제)
**When** `POST /api/auth/login {"email":"foo@bar.com","password":"..."}` 호출
**Then**
- 기존 `auth.usecase.spec.ts` 모든 it PASS 유지 (회귀 0건)
- 응답 schema 동일 (accessToken / refreshToken / author 필드 동일)
- AuthGuard 통과 후 모든 백엔드 로직 정상 동작 (req.user.sub authorId 기반)
- `auth-security.spec.ts` 보안 시나리오 회귀 0건

**검증 명령**:
```bash
cd /Users/sokol/Git/ProjectGrimoire/grimoire-server
npx jest src/application/auth 2>&1 | grep -E "Tests:|FAIL|email.*로그인" | tail -10
git diff develop -- src/application/auth/auth.usecase.spec.ts | grep -E "^-.*it\\(" | wc -l   # 기존 it 삭제 0건
```

**기대 raw 출력**:
- jest stdout: `Tests: ... passed` 모든 기존 + 신규 PASS
- 기존 it 삭제 0건 (수정만 허용, 삭제 금지)

### AC-5: regression-59-slug-login + sensor-slug-login + eval 56→57 PASS

**검증 명령**:
```bash
cd /Users/sokol/Git/ProjectGrimoire
ls eval/tasks/regression-*.json | wc -l
cat eval/tasks/regression-59-slug-login.json | python3 -c "import json,sys;d=json.load(sys.stdin);print(len(d['eval_criteria']))"
ls -la .claude/scripts/sensor-slug-login.sh
bash .claude/scripts/sensor-slug-login.sh
echo "exit: $?"
bash eval/scripts/eval-runner.sh 2>&1 | tail -10
```

**기대 raw 출력**:
- regression 파일 수 57 (현재 56 — PAY-P1-3 이후)
- regression-59 eval_criteria ≥7건
- sensor 파일 chmod +x + exit 0
- sensor 검증 항목 ≥7건:
  1. LoginDto에 email + slug XOR 박제
  2. auth.usecase.login 분기 (findByEmail + findBySlug)
  3. spec ≥4 신규 it 블록 + toHaveBeenCalledWith ≥4건
  4. 기존 email 로그인 spec 회귀 0건 (it 삭제 0건)
  5. web login/page.tsx label "이메일 또는 슬러그" 박제
  6. lib/api.ts login 시그니처 `{ email?, slug?, password }` 박제
  7. e2e/auth.spec.ts slug 로그인 it 추가 박제
- eval-runner stdout 마지막 행: `regression: 57/57 PASS (100%)`

### AC-6: web login/page.tsx 통합 input + 자동 판별

**Given** Phase 2 web login form
**When** 사용자가 로그인 폼 입력
**Then**
- `<input type="text">` (email 아님) — slug 입력 가능
- label "이메일" → "이메일 또는 슬러그"
- placeholder "your@email.com" → "your@email.com 또는 deerdevil"
- submit 시 정규식 `/^[^\s@]+@[^\s@]+\.[^\s@]+$/` 분기:
  - 이메일 형식 → `login({ email, password, recaptcha })` 호출
  - 비-이메일 → `login({ slug, password, recaptcha })` 호출
- AuthProvider login 시그니처 갱신: `login(emailOrSlug: string, password: string, recaptcha?: string)`
- lib/api.ts: `{ email?: string; slug?: string; password: string }` 양쪽 수용
- 시각 정본 영향 — visual-canon-keeper 검수 의무 (label/placeholder 변경)

**검증 명령**:
```bash
cd /Users/sokol/Git/ProjectGrimoire/grimoire-web
grep -nE "이메일 또는 슬러그|emailOrSlug|EMAIL_OR_SLUG_REGEX" src/app/login/page.tsx
grep -nE "type=\"text\"" src/app/login/page.tsx
grep -nE "email\\?:.*string|slug\\?:.*string" src/lib/api.ts
grep -nE "login.*emailOrSlug|login\\(emailOrSlug" src/features/auth/AuthProvider.tsx
npm test -- src/app/login src/features/auth 2>&1 | tail -15
```

**기대 raw 출력**:
- page.tsx에 label "이메일 또는 슬러그" 박제 + type="text" 박제 + 정규식 박제
- lib/api.ts login 시그니처 `email?` + `slug?` 양립
- AuthProvider 시그니처 emailOrSlug 박제
- vitest stdout: `Tests: ... passed` 모든 회귀 + 신규 PASS

### AC-7: e2e slug 로그인 + visual-canon-keeper 검수 + .env.example

**Given** e2e/auth.spec.ts + .env.example
**When** Playwright e2e 실행 + VCK 검수 흐름
**Then**
- e2e/auth.spec.ts 신규 it 1건: "slug + 비밀번호 로그인 후 dashboard 진입" — `getByLabel("이메일 또는 슬러그")` + `process.env.E2E_AUTHOR_SLUG` 박제 + `getByLabel("비밀번호")` + submit + `/dashboard` 진입 검증
- .env.example에 `E2E_AUTHOR_SLUG=deerdevil` 추가 (양 레포 — server는 기존 EMAIL과 양립, web 신규)
- visual-canon-keeper 사전 검수 박제 — `reports/VISUAL_CANON_REPORT.md` 신규 항목 "EMAIL-P0-3 로그인 폼 label/placeholder 변경" PASS 박제 (사슴악마 정본 기준 wireframe 영향 검토 — 단순 텍스트 변경 + type=text는 시각 정본 영향 0 수준 예상이지만 `/login` route 자체는 사슴악마 정본 외부 평가)
- e2e raw stdout DEV_REPORT.md §5 박제

**검증 명령**:
```bash
cd /Users/sokol/Git/ProjectGrimoire/grimoire-web
grep -nE "E2E_AUTHOR_SLUG|이메일 또는 슬러그.*fill|getByLabel.*슬러그" e2e/auth.spec.ts
grep -E "E2E_AUTHOR_SLUG" .env.example
grep -E "E2E_AUTHOR_SLUG" ../grimoire-server/.env.example
grep -nE "EMAIL-P0-3.*PASS|slug-login.*PASS" /Users/sokol/Git/ProjectGrimoire/reports/VISUAL_CANON_REPORT.md
npx playwright test e2e/auth.spec.ts --grep "slug" 2>&1 | tail -15
```

**기대 raw 출력**:
- e2e it 박제 + .env.example 양 레포 박제
- VCK_REPORT에 PASS 박제 (또는 기각 사유 박제)
- e2e raw stdout: `1 passed`

---

## 3. DB 모델 변동

**변경 0건** — `Author.email @unique` + `Author.slug @unique` 둘 다 이미 schema에 박제 (`prisma/schema.prisma:11-29`). 백필 SQL 0건 (사용자 영역 §13-6 검증 쿼리 1회 실행 — slug NULL row 0건 + email/slug @unique 정합 검증).

**기각 대안** — `AccessLog.identifierType` 컬럼 신설:
- 장점: 명시적 구분 (email vs slug 추적 강화)
- 단점: schema 변경 1건 + 마이그레이션 + 기존 row 백필 (`identifierType='email'`)
- **결론**: schema 변경 0건 우선 (AC-3 Initializer 권고). 운영 후 P2 후보로 보존.

---

## 4. 신설/수정 파일 목록 (예상)

### 4-1. server (16~20건, EMAIL_INTEGRITY_PLAN §13-4 정합)

- [ ] `src/adapter/inbound/http/dto/auth.dto.ts` — LoginDto 확장 (email? + slug? + custom XOR validator)
- [ ] `src/adapter/inbound/http/controller/auth.controller.ts` — logging slug 식별자 박제 (identifierType 분기)
- [ ] `src/application/auth/auth.usecase.ts` — `login()` 분기 (findByEmail ?? findBySlug)
- [ ] `src/domain/port/outbound/author-repository.port.ts` — (선택) `findByEmailOrSlug` 추가 또는 분기 유지 결정
- [ ] `src/adapter/outbound/persistence/prisma-author.repository.ts` — (선택) findByEmailOrSlug 구현
- [ ] `src/application/auth/access-log.service.ts` — slug 식별자 박제 (logging 메시지 identifierType 박제)
- [ ] `src/application/auth/auth.usecase.spec.ts` — slug 로그인 ≥4 신규 it 블록 (정상 slug / 미존재 / 비번 불일치 / email 후향호환)
- [ ] `src/application/auth/auth-security.spec.ts` — slug 보안 시나리오 (XOR 강제 / SQL injection slug)
- [ ] `src/adapter/inbound/http/dto/auth.dto.spec.ts` — (신설) LoginDto XOR validator ≥3 it 블록
- [ ] `src/adapter/inbound/http/controller/auth.controller.spec.ts` — slug 로그인 logging 회귀 spec
- [ ] `docs/api-contract.md` — `POST /api/auth/login` request schema 갱신 (`email?` + `slug?` + XOR 정책 박제)
- [ ] `docs/data-model.md` — Author email/slug @unique 정책 강화 박제 (이미 박제 가정)
- [ ] `docs/glossary.md` — "로그인 식별자 (login identifier)" 용어 추가 (email | slug)
- [ ] `SCHEMA.md` — Author 모델 정책 갱신 (slug @unique 박제 강화)
- [ ] `TECH_STATUS.md` — Auth 카테고리에 EMAIL-P0-3 한 줄 박제
- [ ] `CHANGELOG.md` — `[Unreleased]` Added — slug 로그인 마이그레이션 박제
- [ ] `.env.example` — `E2E_AUTHOR_SLUG=deerdevil` 추가 (server e2e 픽스처 양립)
- [ ] DEV_REPORT.md Server 섹션 §5 — sensor-server / sensor-slug-login / jest raw stdout 전문 박제

### 4-2. web (6~8건, EMAIL_INTEGRITY_PLAN §13-4 정합)

- [ ] `src/app/login/page.tsx` — input type="text" + label "이메일 또는 슬러그" + 정규식 자동 판별
- [ ] `src/app/register/page.tsx` — (선택) slug 강조 안내 강화 (옵션, 본 sprint OUT 가능 — Generator 판단)
- [ ] `src/lib/api.ts` — login 시그니처 `{ email?: string; slug?: string; password: string }` 양립
- [ ] `src/features/auth/AuthProvider.tsx` — login(emailOrSlug, password, recaptcha) 시그니처 갱신
- [ ] `src/types/api.ts` — LoginRequest 타입 갱신 (email + slug 양립)
- [ ] `e2e/auth.spec.ts` — slug 로그인 1 it 추가 + getByLabel("이메일 또는 슬러그") 박제
- [ ] `e2e/dashboard.spec.ts` — `process.env.E2E_AUTHOR_SLUG` 환경변수 양립 (기존 EMAIL과 동시 박제 가능)
- [ ] `.env.example` — `E2E_AUTHOR_SLUG=deerdevil` 추가
- [ ] `docs/SCREENS.md` — 로그인 페이지 갱신 (label/placeholder 변경 박제)
- [ ] DEV_REPORT.md Web 섹션 §5 — vitest + playwright raw stdout 전문 박제

### 4-3. claude-docs (4건)

- [ ] `.claude/scripts/sensor-slug-login.sh` — 신설 (chmod +x, 검증 항목 ≥7건 — AC-5 정본)
- [ ] `eval/tasks/regression-59-slug-login.json` — 신설 (eval_criteria ≥7건, AC-1~7 grep 명령 박제)
- [ ] `.claude/shared-contracts.md` §15 — SlugLogin 인터페이스 박제 + 변경 이력
- [ ] `research/HARNESS_ENGINEERING.md` §14.4 — Sensors 30→31 + sensor-slug-login 행 + eval task 56→57 갱신 (drift 0 박제)

---

## 5. 외부 의존성

- **외부 API 0건** — 본 sprint는 100% 내부 도메인 (이메일 발송 / OAuth provider 추가 / SaaS 통합 모두 OUT). EMAIL-P1-1 (이메일 인증 시스템) + EMAIL-P1-3 (결제 알림 이메일)은 별도 sprint, 본 OUT.
- **NestJS class-validator**: LoginDto XOR validator 작성 시 `@ValidateIf` 또는 custom decorator 활용 (기존 의존성). 별도 패키지 추가 0건.
- **Playwright e2e**: 기존 e2e 환경 활용 (별도 의존성 0).
- **OAuth 자동 링크 (auth.usecase.ts:100)**: 본 sprint OUT (위험 영역 §12-1 별도 보안 sprint).

---

## 6. 검증 게이트 G1~G9

### 6-1. server 검증 게이트

| # | 게이트 | 명령 | 기대 |
|---|---|---|---|
| G1 | TypeScript | `cd grimoire-server && npx tsc --noEmit` | 0 errors |
| G2 | Lint | `npm run lint` | 0 errors |
| G3 | jest (전체) | `npm test 2>&1 \| tail -30` | 모든 spec PASS, 회귀 0건, 신규 spec ≥4 + ≥3 it 블록 모두 PASS, Tests: 555+ |
| G4 | Build | `npm run build` | 0 errors |
| G5 | Prisma | `npx prisma generate` | 성공 (schema 변경 0건이므로 migrate diff 불필요) |

### 6-2. web 검증 게이트

| # | 게이트 | 명령 | 기대 |
|---|---|---|---|
| G6 | TypeScript | `cd grimoire-web && npx tsc --noEmit` | 0 errors |
| G7 | vitest | `npm test 2>&1 \| tail -20` | Tests: 145+ passed, 회귀 0건 |
| G8 | playwright | `npx playwright test e2e/auth.spec.ts --grep "slug" 2>&1 \| tail -15` | 1 passed (slug 로그인 it) |

### 6-3. claude-docs 검증 게이트

| # | 게이트 | 명령 | 기대 |
|---|---|---|---|
| G9 | sensor 11종 + eval | `for s in sensor-shared-contracts sensor-server sensor-docs-sync sensor-credit-atomicity sensor-payment-idempotency sensor-payment-reconciliation sensor-admin-credit-ui sensor-refund-atomicity sensor-payment-retry-reuse sensor-slug-login sensor-adversarial-pre-commit; do bash .claude/scripts/$s.sh; done && bash eval/scripts/eval-runner.sh` | 모두 exit 0, regression 57/57 PASS, drift 0 |

### 6-4. 외부 인용 검증 게이트

| # | 게이트 | 명령 | 기대 |
|---|---|---|---|
| G10 | 외부 인용 0건 | `grep -rE "CERTI_PROJ\|brightmall\|thermage\|inapi\|admin-certilife\|no1-sass" reports/sprint-email-p0-3-* grimoire-server/src/ grimoire-web/src/ .claude/scripts/sensor-slug-login.sh eval/tasks/regression-59-*.json 2>/dev/null \| wc -l` | 0 |

---

## 7. 테스트 시나리오

### 7-1. 정상 slug 로그인 (jest)

```typescript
it('slug + password 로그인 정상', async () => {
  mockAuthorRepo.findBySlug.mockResolvedValueOnce({ id: 'a1', slug: 'deerdevil', passwordHash: 'hash', ... })
  mockBcrypt.compare.mockResolvedValueOnce(true)
  const result = await usecase.login({ slug: 'deerdevil', password: 'secret' })
  expect(mockAuthorRepo.findBySlug).toHaveBeenCalledWith('deerdevil')
  expect(mockAuthorRepo.findByEmail).not.toHaveBeenCalled()
  expect(result.author.slug).toBe('deerdevil')
})
```

### 7-2. 미존재 slug → UnauthorizedException

```typescript
it('미존재 slug 로그인 시 UnauthorizedException', async () => {
  mockAuthorRepo.findBySlug.mockResolvedValueOnce(null)
  await expect(usecase.login({ slug: 'nonexistent', password: 'x' }))
    .rejects.toThrow(UnauthorizedException)
})
```

### 7-3. email + slug 둘 다 박제 시 BadRequest

```typescript
it('email + slug 둘 다 박제 시 BadRequest', async () => {
  await expect(usecase.login({ email: 'x@y.com', slug: 'deerdevil', password: 'x' }))
    .rejects.toThrow(BadRequestException)
})
```

### 7-4. email 후향호환 회귀

```typescript
it('email 로그인 기존 동작 그대로 PASS', async () => {
  mockAuthorRepo.findByEmail.mockResolvedValueOnce({ id: 'a1', email: 'foo@bar.com', passwordHash: 'hash', ... })
  mockBcrypt.compare.mockResolvedValueOnce(true)
  const result = await usecase.login({ email: 'foo@bar.com', password: 'secret' })
  expect(mockAuthorRepo.findByEmail).toHaveBeenCalledWith('foo@bar.com')
  expect(mockAuthorRepo.findBySlug).not.toHaveBeenCalled()
  expect(result.author.email).toBe('foo@bar.com')
})
```

### 7-5. OAuth 자동 링크 회귀 (변경 0 검증)

```typescript
it('googleLogin 흐름은 변경 0 — findByEmail 자동 링크 정책 유지', async () => {
  // auth.usecase.ts:100 findByEmail(payload.email) 동작 회귀 검증
  // 본 sprint OUT — 별도 보안 sprint 영역
  expect(usecase.googleLogin).toBeDefined()
})
```

### 7-6. SignupHistory 회귀 (변경 0 검증)

```typescript
it('SignupHistory providerId=email 정책 변경 0 검증', async () => {
  // auth.usecase.ts:38,58 providerId=input.email 동작 회귀
  // slug 도입 후에도 SignupHistory는 email 기반 (본 sprint OUT)
  await usecase.register({ email: 'foo@bar.com', password: 'x', name: 'Foo', slug: 'foo' })
  expect(mockSignupHistoryRepo.upsert).toHaveBeenCalledWith('foo@bar.com')
})
```

### 7-7. web e2e 자동 판별 (Playwright)

```typescript
test('slug + 비밀번호로 로그인 후 dashboard 진입', async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('이메일 또는 슬러그').fill(process.env.E2E_AUTHOR_SLUG || 'deerdevil')
  await page.getByLabel('비밀번호').fill(process.env.E2E_AUTHOR_PASSWORD || '...')
  await page.getByRole('button', { name: '로그인' }).click()
  await expect(page).toHaveURL(/\/dashboard/)
})
```

### 7-8. 수동 검증 (localhost) — 사용자 + qa 협업

1. localhost server + web 부팅 + EMAIL-P0-2 백필 SQL 사용자 1회 실행 (운영 DB는 대상 외 — localhost 시드만)
2. `curl POST /api/auth/login -d '{"slug":"deerdevil","password":"..."}'` → 200 + accessToken/refreshToken 반환
3. `curl POST /api/auth/login -d '{"email":"deerdevil@example.com","password":"..."}'` → 200 (후향호환)
4. `curl POST /api/auth/login -d '{"email":"x","slug":"y","password":"z"}'` → 400 BadRequest
5. `curl POST /api/auth/login -d '{"password":"z"}'` → 400 BadRequest
6. 브라우저 `/login` → "이메일 또는 슬러그" label 확인 → "deerdevil" 입력 + 비번 → /dashboard 진입

raw 박제 위치: DEV_REPORT.md Server 섹션 §3 + Web 섹션 §3 (curl + browser screenshot raw).

---

## 8. 거짓말 차단 정책 (사용자 ★ PAY-P1-1 + PAY-P1-3 회고 정합)

### 8-1. PAY-P1-1 + P1-3 회고 (자가 보고 vs 실제 검증 격차)

- PAY-P1-1: server agent "eval 55/55" 자가 보고 → 실제 52/55 docs drift (qa Evaluator 직접 Read로 검출)
- PAY-P1-3: server agent action명 'payment_expired' vs 실제 'payment_expire' 표기 차이 (메인 직접 검증으로 검출)

본 sprint progress에 다음 명시:

### 8-2. ★ commit/push 절대 금지 — server agent + web agent 모두

- Generator(server agent + web agent)는 코드 변경 + DEV_REPORT.md raw stdout 박제까지만.
- commit/push는 메인이 사용자 승인 후 일괄 진행.
- Generator 자율 commit/push 시 즉시 FAIL 박제 (qa Evaluator git log 검증).
- 양 레포 모두 강제 적용 (server는 ~3h, web은 ~3h, 서로 git 영향 0건 보장).

### 8-3. spec 더미 assertion 금지

다음 패턴 차단:
- `expect(true).toBe(true)`
- `expect(1+1).toBe(2)`
- `expect(result).toBeTruthy()` (의미 없는 truthy 검증)
- `expect(() => fn()).not.toThrow()` (단순 throw 회피)

**[MUST]** 다음 패턴 강제:
- `toHaveBeenCalledWith({ ... 정확한 인자 ... })`
- `toHaveBeenCalledTimes(N)` (구체 N)
- `expect(result).toEqual({ ... 정확한 객체 ... })`
- `expect(result).toMatchObject({ ... 정확한 부분 객체 ... })`

AC-2 / AC-5 grep 검증으로 자동 차단:
```bash
grep -cE "toHaveBeenCalledWith|toHaveBeenCalledTimes" src/application/auth/auth.usecase.spec.ts
grep -cE "toHaveBeenCalledWith|toEqual|toMatchObject" src/features/auth/AuthProvider.spec.tsx
```
기대: server ≥6건 / web ≥3건.

### 8-4. raw stdout DEV_REPORT.md §5 박제 의무

Generator는 다음 raw stdout 전문 박제 의무:

**server**:
- `bash .claude/scripts/sensor-server.sh 2>&1` 전문
- `bash .claude/scripts/sensor-slug-login.sh 2>&1` 전문
- `npm test 2>&1 | tail -50` 전문 (Tests: ... 라인 포함)
- `npx tsc --noEmit 2>&1` 전문
- `npm run lint 2>&1` 전문
- §7-8 수동 검증 결과 (curl raw response 4건)

**web**:
- `npm test 2>&1 | tail -30` 전문 (vitest, Tests: ... 라인 포함)
- `npx tsc --noEmit 2>&1` 전문
- `npx playwright test e2e/auth.spec.ts --grep "slug" 2>&1` 전문
- §7-8 브라우저 검증 (screenshot 또는 텍스트 raw)

### 8-5. qa Evaluator 독립 재실행 + 직접 Read

qa는 Generator 박제와 별개로:
1. `bash .claude/scripts/sensor-slug-login.sh` 직접 재실행 → exit 0 검증
2. `npx jest src/application/auth` 직접 재실행 → 모두 PASS 검증
3. `npx vitest src/features/auth src/app/login` 직접 재실행 → 모두 PASS 검증
4. `npx playwright test e2e/auth.spec.ts` 직접 재실행 → slug 로그인 PASS 검증
5. spec 파일 직접 Read → 의미 있는 assertion 검증 (toHaveBeenCalledWith 인자 정합 + toMatchObject 검증)
6. `eval/scripts/eval-runner.sh` 직접 재실행 → 57/57 PASS 검증
7. `git log` 직접 확인 (양 레포) → Generator 자율 commit 흔적 0건
8. visual-canon-keeper 검수 결과 직접 Read → VISUAL_CANON_REPORT.md PASS 박제 확인

### 8-6. 외부 프로젝트 인용 0건

`grep -rE "CERTI_PROJ|brightmall|thermage|inapi|admin-certilife|no1-sass" reports/sprint-email-p0-3-* grimoire-server/src/ grimoire-web/src/ .claude/scripts/sensor-slug-login.sh eval/tasks/regression-59-*.json 2>/dev/null | wc -l` → **0건** 강제. EMAIL_INTEGRITY_PLAN §13 정밀 분석 박제 외에 코드/sensor/eval에 외부 프로젝트명 0건.

### 8-7. visual-canon-keeper 강제 발동

- 로그인 폼 시각 변경 (label "이메일" → "이메일 또는 슬러그", placeholder 변경, type="email" → "text")
- 사슴악마 정본 직접 영향 0 예상이지만 `/login` route는 플랫폼 영역 — 정본 wireframe 외부 시각 정합 평가 의무
- 메인 또는 사용자가 visual-canon-keeper 호출 → `reports/VISUAL_CANON_REPORT.md` 신규 항목 박제 → PASS 결과 의무

---

## 9. 멀티에이전트 흐름

```
1. orchestration-decision (사전 — 메인 직접 판단)
   - 본 Sprint는 §0 원가 영향 0건 (AI 호출 0) + 시각 정본 영향 ⚠️ (로그인 폼 label/placeholder/type 변경)
   - planner Initializer → cost-accountant 면제 → VCK Phase 2 검수 → server Generator + web Generator 병렬 → qa Evaluator
   - 첫 server+web 동시 병렬 멀티에이전트 시연 (PAY-P0-2와 동일 패턴 — server+web 동시 위임)

2. planner (Initializer — 본 sprint progress + PLANNER_REPORT 갱신)
   ↓
3. cost-accountant (사전 — ✅ 면제. AI 호출 0건 + 인프라 비용 영향 0건. 본 Sprint는 100% server DTO/UseCase + web 폼 + claude-docs)
   ↓
4. visual-canon-keeper (사전 — ⚠️ 강제 발동. 로그인 폼 label/placeholder/type 변경 → 사슴악마 정본 영향 검수 의무)
   - VISUAL_CANON_REPORT.md `### EMAIL-P0-3 로그인 폼 슬러그 입력 통합` 박제
   - 결과: PASS (정본 영향 0 — /login은 플랫폼 영역) 또는 FAIL (재기획 필요)
   ↓
5. 메인 직접 (병렬 진행)
   - shared-contracts §15 박제 (claude-docs)
   - regression-59 task 신설 (claude-docs)
   - sensor-slug-login 신설 (claude-docs)
   ↓
6. grimoire-server (Generator — Phase 1)
   - 본 progress.md §4-1 IN — server 16~20건 + §6-1 검증 게이트 G1~G5 PASS
   - DEV_REPORT.md Server 섹션 §5 raw stdout 전문 박제
   - ★ commit/push 절대 금지 — 메인 책임 (PAY-P1-1/P1-3 회고 정합)
   
   [병렬]

7. grimoire-web (Generator — Phase 2)
   - 본 progress.md §4-2 IN — web 6~8건 + §6-2 검증 게이트 G6~G8 PASS
   - DEV_REPORT.md Web 섹션 §5 raw stdout 전문 박제
   - ★ commit/push 절대 금지 — 메인 책임
   - server Phase 1 완료 의존 (Phase 1 → Phase 2 순차 또는 web mock으로 병렬 가능 — Generator 결정)
   ↓
8. grimoire-qa (Evaluator)
   - AC 7건 raw 채점 (PASS/FAIL 박제)
   - QA_REPORT.md `### sprint-email-p0-3-slug-login 통과율` 박제 (목표 7/7 = 100%)
   - dev 환경 slug 로그인 실제 검증 (curl raw response + browser raw 박제)
   - Generator 자율 commit/push 흔적 검증 (git log 양 레포 확인) — 발견 시 즉시 FAIL 박제
   - eval-runner 57/57 PASS 직접 재실행 검증
   - VCK 검수 결과 직접 Read 확인
   ↓
9. 사용자 (배포 게이트 최종 판정 + commit/push 최종 책임)
   - qa PASS 시 commit + push 진행
   - develop → main per-repo 머지 3 레포:
     - server: `git checkout main && git merge develop` + `git push origin main`
     - web: `git checkout main && git merge develop` + `git push origin main`
     - claude-docs: `git checkout main && git merge develop` + `git push origin main`
   - prod 배포 (`npx prisma generate` — schema 변경 0건이므로 migrate deploy 불필요. server + web Container Apps 양쪽 재배포)
   - EMAIL-P0-2 운영 DB 백필 SQL 1회 실행 (사용자 직접, dev → prod 순차)
```

---

## 10. shared-contracts §15 SlugLogin 박제 후보

**[MUST]** claude-docs Generator (또는 메인 직접)는 아래 텍스트 블록을 `.claude/shared-contracts.md` `## 14. PaymentRetryReuse` 섹션 직후에 박제.

```markdown
## 15. SlugLogin (server + web 도메인 — slug 로그인 마이그레이션)

**위치**:
- DTO: `grimoire-server/src/adapter/inbound/http/dto/auth.dto.ts` (LoginDto 확장)
- UseCase: `grimoire-server/src/application/auth/auth.usecase.ts` (`login()` 분기)
- Controller: `grimoire-server/src/adapter/inbound/http/controller/auth.controller.ts` (logging slug 식별자)
- Repository Port: `grimoire-server/src/domain/port/outbound/author-repository.port.ts` (findByEmail + findBySlug 박제)
- Web Form: `grimoire-web/src/app/login/page.tsx` (input 통합 + 자동 판별)
- API Client: `grimoire-web/src/lib/api.ts` (login 시그니처 확장)
- AuthProvider: `grimoire-web/src/features/auth/AuthProvider.tsx` (login 시그니처)
- DB 모델: `grimoire-server/prisma/schema.prisma` (변경 0건 — email/slug @unique 이미 박제)

**적용**: 사용자가 `email` 또는 `slug` (XOR 1택) + 비밀번호로 로그인. 후향호환 — 기존 email 클라이언트 변경 0건. web 로그인 폼은 입력칸 1개로 통합 + 정규식 자동 판별.

### 시그니처

```typescript
// LoginDto (server)
class LoginDto {
  @IsOptional() @IsEmail() email?: string
  @IsOptional() @IsString() @Matches(/^[a-z0-9-]+$/) slug?: string
  @IsString() @MinLength(6) password!: string
  // custom @ValidateIf or @Validate decorator: email XOR slug 강제
}

// AuthUseCase.login (server)
async login(input: { email?: string; slug?: string; password: string }) {
  if (!input.email && !input.slug) throw new BadRequestException('이메일 또는 슬러그가 필요합니다')
  if (input.email && input.slug) throw new BadRequestException('이메일 또는 슬러그 중 하나만 박제하세요')
  const author = input.email
    ? await this.authorRepo.findByEmail(input.email)
    : await this.authorRepo.findBySlug(input.slug!)
  if (!author || !author.passwordHash) throw new UnauthorizedException('이메일/슬러그 또는 비밀번호가 올바르지 않습니다')
  // ... 기존 bcrypt.compare 흐름
}

// API client (web)
login(input: { email?: string; slug?: string; password: string; recaptcha?: string }): Promise<LoginResponse>

// AuthProvider (web)
login(emailOrSlug: string, password: string, recaptcha?: string): Promise<void>
// 내부 정규식 분기: /^[^\s@]+@[^\s@]+\.[^\s@]+$/ → email, 아니면 slug
```

### 정책

- **로그인 식별자**: email | slug (XOR 1택)
- **후향호환**: 기존 email 로그인 100% 유지 (auth.usecase.spec.ts 기존 it 모두 PASS)
- **JWT payload 변경 0**: `{ sub, slug, role }` 그대로 (slug 이미 포함)
- **AccessLog**: identifierType 분기 박제 (logger 메시지) — schema 변경 0건
- **OAuth 자동 링크 (auth.usecase.ts:100)**: 본 sprint OUT — 별도 보안 sprint
- **SignupHistory providerId=email**: 본 sprint OUT (정책 변경은 별도 sprint)
- **비밀번호 초기화**: EMAIL-P1-1 (이메일 인증 시스템) 진입 시 신설 — 본 sprint OUT
- **email deprecate (Phase 3)**: 본 sprint OUT — Phase 1+2 정합 후 1개월 검증 후 사용자 결정

### 처리 흐름

1. 클라이언트 `POST /api/auth/login {"slug":"deerdevil","password":"secret"}` 호출
2. LoginDto validator → email XOR slug 강제 통과
3. AuthUseCase.login → input.slug 박제 → `findBySlug('deerdevil')` 호출
4. author 적중 → bcrypt.compare(secret, passwordHash) 검증
5. accessToken/refreshToken 발급 + AccessLog (identifierType='slug') 박제
6. 응답: `{ accessToken, refreshToken, author: { id, slug, email, name, role } }`

### 변경 시 동시 갱신 대상

- `grimoire-server/src/adapter/inbound/http/dto/auth.dto.ts` (LoginDto)
- `grimoire-server/src/application/auth/auth.usecase.ts` (login 분기)
- `grimoire-server/src/application/auth/auth.usecase.spec.ts` (slug 로그인 spec)
- `grimoire-server/src/adapter/inbound/http/controller/auth.controller.ts` (logging)
- `grimoire-server/src/application/auth/access-log.service.ts` (identifierType)
- `grimoire-server/docs/api-contract.md` (POST /api/auth/login schema)
- `grimoire-web/src/app/login/page.tsx` (input 통합)
- `grimoire-web/src/lib/api.ts` (login 시그니처)
- `grimoire-web/src/features/auth/AuthProvider.tsx` (login 시그니처)
- `grimoire-web/src/types/api.ts` (LoginRequest)
- `grimoire-web/e2e/auth.spec.ts` (slug 로그인 it)
- `grimoire-server/.env.example` + `grimoire-web/.env.example` (E2E_AUTHOR_SLUG)
- `eval/tasks/regression-59-slug-login.json`
- `.claude/scripts/sensor-slug-login.sh`

### 변경 이력

- 2026-05-04 #10_7 EMAIL-P0-3: 신설 — slug 로그인 마이그레이션 (EMAIL_INTEGRITY_PLAN §13 정합, Phase 1 server + Phase 2 web)
```

추가로 shared-contracts.md 마지막 줄 `마지막 업데이트:` 라인을 `2026-05-04 (§15 SlugLogin 신설)`로 교체.

---

## 11. 사용자 영역 잔존

### 11-1. EMAIL-P0-2 운영 DB 백필 SQL (사용자 책임 — destructive action)

> EMAIL_INTEGRITY_PLAN §2-1 EMAIL-P0-2 박제 — 가짜 `@grimoire.app` 12~15 row 정리. EMAIL-P0-3 본 sprint와 함께 진행 권장.

```sql
-- 1단계: 백업
CREATE TABLE authors_backup_20260505 AS
  SELECT * FROM authors WHERE email LIKE '%@grimoire.app%';

-- 2단계: 영향 row 확인
SELECT id, slug, email FROM authors WHERE email LIKE '%@grimoire.app%';

-- 3단계: 종속 데이터 정리
DELETE FROM refresh_tokens WHERE author_id IN (SELECT id FROM authors WHERE email LIKE '%@grimoire.app%');
DELETE FROM social_accounts WHERE author_id IN (SELECT id FROM authors WHERE email LIKE '%@grimoire.app%');

-- 4단계: 작가 row 삭제
DELETE FROM authors WHERE email LIKE '%@grimoire.app%';

-- 5단계: 회귀 검증 (EMAIL_INTEGRITY_PLAN §13-6)
SELECT COUNT(*) FROM authors WHERE email LIKE '%@grimoire.app%';  -- 0 강제
SELECT COUNT(*) FROM authors WHERE email IS NULL;                  -- 0 기대
SELECT COUNT(*) FROM authors WHERE slug IS NULL;                   -- 0 기대
SELECT email, COUNT(*) FROM authors GROUP BY email HAVING COUNT(*) > 1;  -- 0 row
SELECT slug, COUNT(*) FROM authors GROUP BY slug HAVING COUNT(*) > 1;    -- 0 row
```

dev → production 순차 (사용자 절대 규정 + .githooks/AGENTS.md §1).

### 11-2. main 머지 (사용자 책임)

- qa Evaluator PASS 박제 후 메인 또는 사용자가 직접 commit + push
- develop → main per-repo 머지 3 레포 (server + web + claude-docs)

### 11-3. dev 검증 (qa Evaluator + 사용자 협업)

- dev 환경 deploy 후 qa가 slug + email 로그인 양쪽 raw curl + browser 검증 (DEV_REPORT.md §5 + QA_REPORT.md `### sprint-email-p0-3-slug-login 통과율`)
- 사용자가 실제 `/login` 접속 → `deerdevil` 입력 → /dashboard 진입 (수동 UX 검증)

### 11-4. prod 배포 (사용자 최종 결정)

- `npx prisma generate` (schema 변경 0건 → migrate deploy 불필요)
- Container Apps server + web 양쪽 재배포
- prod 환경 첫 24h 모니터링 (slug 로그인 적중률 + 에러 로그 확인)

### 11-5. EMAIL-P0-3 후속 — 미해결 영역 (사용자 결정)

- **OAuth 자동 링크 보안 강화**: §12-1 위험 영역 #1 — 별도 보안 sprint
- **SignupHistory providerId 정책**: §12-2 위험 영역 #2 — slug 정책 변경 별도 sprint
- **비밀번호 초기화**: EMAIL-P1-1 의존 (이메일 인증 시스템 + 외부 API 결정)
- **email deprecate (Phase 3)**: 1개월 운영 후 사용자 결정

---

## 12. 위험 영역 + 별도 sprint 권장 (EMAIL_INTEGRITY_PLAN §13-5 정합)

| # | 위험 | 현재 코드 | 본 sprint | 후속 sprint |
|---|---|---|---|---|
| 1 | **OAuth 동일 이메일 자동 링크 (보안)** | `auth.usecase.ts:100` `findByEmail(payload.email)` 적중 시 자동 링크 | OUT (회귀 0 검증만) | 별도 보안 sprint — 이메일 + 검증 토큰 강제 또는 명시적 동의 추가 |
| 2 | **SignupHistory 2회 제한 (정책)** | `auth.usecase.ts:38,58` providerId=email | OUT (회귀 0 검증만) | 별도 sprint — slug 도입 후 정책 결정 (email+slug 동시 박제 또는 IP/디바이스 추가 제한) |
| 3 | **RefreshToken / SocialAccount FK** | `schema.prisma:347,107` authorId 기반 | OUT (변경 0) | — |
| 4 | **비밀번호 초기화 미구현** | (코드 0건) | OUT | EMAIL-P1-1 진입 시 신설 (외부 API 결정 후) |

---

## 13. 참조

- `research/EMAIL_INTEGRITY_PLAN.md` §13 EMAIL-P0-3 (slug 로그인 마이그레이션 정밀 분석 박제, line 483-714)
- `research/EMAIL_INTEGRITY_PLAN.md` §13-2 8 영역 file:line 표 (Explore subagent 결과)
- `research/EMAIL_INTEGRITY_PLAN.md` §13-3 마이그레이션 3 Phase
- `research/EMAIL_INTEGRITY_PLAN.md` §13-4 영향 파일 28개 (server 16~20 + web 6~8)
- `research/EMAIL_INTEGRITY_PLAN.md` §13-5 위험 영역 4건
- `research/EMAIL_INTEGRITY_PLAN.md` §13-6 백필 SQL (검증 쿼리만, 0건 추정)
- `reports/sprint-pay-p0-1-webhook-event-id-idempotency-progress.md` (선행 1)
- `reports/sprint-pay-p0-2-payment-reconciliation-cron-progress.md` (선행 2)
- `reports/sprint-pay-p0-3-admin-credit-grant-ui-progress.md` (선행 3)
- `reports/sprint-pay-p1-1-refund-atomicity-progress.md` (선행 4 — 거짓말 차단 정책 정합)
- `reports/sprint-pay-p1-3-retry-policy-progress.md` (선행 5 — 12 섹션 패턴 정합)
- `grimoire-server/src/application/auth/auth.usecase.ts:67-82` (login — 변경 대상)
- `grimoire-server/src/application/auth/auth.usecase.ts:100` (OAuth 자동 링크 — 본 sprint OUT)
- `grimoire-server/src/application/auth/auth.usecase.ts:38,58` (SignupHistory — 본 sprint OUT)
- `grimoire-server/src/adapter/inbound/http/dto/auth.dto.ts:21-28` (LoginDto — 변경 대상)
- `grimoire-server/prisma/schema.prisma:11-29` (Author email/slug @unique — 변경 0건)
- `grimoire-web/src/app/login/page.tsx:52-62` (input — 변경 대상)
- `grimoire-web/src/lib/api.ts:35-40` (login — 변경 대상)
- `.claude/shared-contracts.md` §11 PAY-P0-1 + §12 PAY-P0-2 + §13 PAY-P1-1 + §14 PAY-P1-3 + §15 SlugLogin (본 Sprint 신설)
- `grimoire-server/CLAUDE.md` §3 문서 동기화 + §5 Hexagonal 아키텍처
- `grimoire-web/CLAUDE.md` §2 크로스 브라우저 호환성 + §4 BFF 패턴
- `feedback_visual_canon.md` (시각 정본 = 사슴악마 정본)
- `feedback_chrome_verify.md` (qa 단계 실측 정합)
- `feedback_no_shortcut_migration.md` (마이그레이션 시 기능 뭉개기 금지)
- 책 Ch 16 Anthropic 3-에이전트 (Initializer → Generator → Evaluator) — 묶음 III 1회차

---

**마지막 업데이트**: 2026-05-04 (EMAIL-P0-3 Initializer 신설 — slug 로그인 마이그레이션 + AC 7건 + Ambiguity ≤ 0.1 + commit/push 메인 책임 + spec 더미 assertion 금지 + visual-canon-keeper 강제 발동 + cost-accountant 면제 + 외부 인용 0건)
