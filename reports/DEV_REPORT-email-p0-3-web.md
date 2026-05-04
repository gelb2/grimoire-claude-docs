# DEV_REPORT — sprint-email-p0-3-slug-login (web Phase 2)

> Sprint ID: sprint-email-p0-3-slug-login
> Phase: 2 (web)
> Generator: grimoire-web (Anthropic 3-에이전트 패턴)
> 작성일: 2026-05-04 (#10_7)
> 정본 참조: `reports/sprint-email-p0-3-slug-login-progress.md` §1~§12

---

## 1. 변경/신설 파일 목록 (file:line 박제)

| # | 경로 | 변경 유형 | 핵심 박제 |
|---|---|---|---|
| 1 | `grimoire-web/src/lib/api.ts:46` | 수정 | `login()` 시그니처 `{ email?: string; slug?: string; password: string; recaptchaToken?: string }`로 확장 |
| 2 | `grimoire-web/src/features/auth/AuthProvider.tsx:26` | 신설 | `EMAIL_OR_SLUG_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/` |
| 3 | `grimoire-web/src/features/auth/AuthProvider.tsx:35` | 신설 | `detectIdentifierType(input)` 헬퍼 함수 |
| 4 | `grimoire-web/src/features/auth/AuthProvider.tsx:48` | 수정 | `login: (emailOrSlug, password, recaptchaToken)` 시그니처 갱신 |
| 5 | `grimoire-web/src/features/auth/AuthProvider.tsx:95-101` | 수정 | `login` 본문 정규식 분기 — `api.login({ email })` 또는 `api.login({ slug })` XOR |
| 6 | `grimoire-web/src/features/auth/index.ts:1` | 수정 | barrel export에 `EMAIL_OR_SLUG_REGEX` + `detectIdentifierType` 추가 |
| 7 | `grimoire-web/src/app/login/page.tsx:18-19` | 수정 | state명 `email` → `emailOrSlug` 통합 + 주석 박제 |
| 8 | `grimoire-web/src/app/login/page.tsx:28-31` | 수정 | `login(emailOrSlug.trim(), password, recaptchaToken)` 호출 + trim |
| 9 | `grimoire-web/src/app/login/page.tsx:55-65` | 수정 | label "이메일 또는 슬러그" + `type="text"` + placeholder + htmlFor + autoComplete="username" |
| 10 | `grimoire-web/src/app/login/page.tsx:68-79` | 수정 | password input id="password" + autoComplete="current-password" 박제 |
| 11 | `grimoire-web/src/features/auth/AuthProvider.test.tsx` | 신설 | vitest 11 it 블록 (정규식 7건 + login 자동 판별 4건) |
| 12 | `grimoire-web/e2e/auth.spec.ts:8-26` | 수정 | "이메일 또는 슬러그" label + placeholder assertion 갱신 |
| 13 | `grimoire-web/e2e/auth.spec.ts:34-46` | 수정 | shows error 시나리오 `getByLabel` 사용 |
| 14 | `grimoire-web/e2e/auth.spec.ts:55-71` | 신설 | "슬러그로 로그인 후 dashboard 진입" it 박제 (E2E_AUTHOR_SLUG default `deerdevil`) |
| 15 | `grimoire-web/e2e/dashboard.spec.ts:13-19` 외 4건 | 수정 | `process.env.E2E_AUTHOR_SLUG ?? E2E_AUTHOR_EMAIL` 양립 옵션 |
| 16 | `grimoire-web/.env.example:10-14` | 수정 | `E2E_AUTHOR_SLUG=deerdevil` 박제 |
| 17 | `grimoire-web/CHANGELOG.md` `[Unreleased]` | 수정 | EMAIL-P0-3 web Phase 2 박제 |
| 18 | `grimoire-web/SCREENS.md:16` | 수정 | `/login` 행 입력칸 통합 + 정규식 자동 판별 박제 |

server / claude-docs / shared-contracts §15 / regression-59 / sensor-slug-login 모두 변경 0건 — 메인 책임 영역.

---

## 2. AC 충족 검증 표 (Sprint progress §2 정본)

| AC | 명령 | 결과 | 박제 |
|---|---|---|---|
| AC-6 (login/page.tsx 통합 input + 자동 판별) | `grep -nE "이메일 또는 슬러그\|emailOrSlug\|EMAIL_OR_SLUG_REGEX" src/app/login/page.tsx src/features/auth/AuthProvider.tsx src/features/auth/index.ts` | ✅ PASS | label "이메일 또는 슬러그" (page.tsx:56), `EMAIL_OR_SLUG_REGEX` (AuthProvider.tsx:26), barrel export (index.ts:1) 모두 박제 |
| AC-6 (lib/api.ts 시그니처 양립) | `grep -nE 'email\?:[[:space:]]*string\|slug\?:[[:space:]]*string' src/lib/api.ts` | ✅ PASS | `api.ts:46` `{ email?: string; slug?: string; password: string; recaptchaToken?: string }` 박제 |
| AC-6 (AuthProvider login 시그니처) | `grep -nE "login.*emailOrSlug\|login\(emailOrSlug" src/features/auth/AuthProvider.tsx` | ✅ PASS | AuthProvider.tsx:48 (interface) + 95 (구현부) 양쪽 박제 |
| AC-6 (vitest 의미 있는 assertion) | `grep -cE "toHaveBeenCalledWith\|toEqual\|toMatchObject" src/features/auth/AuthProvider.test.tsx` | ✅ PASS | 8건 (≥3건 강제 정합) |
| AC-7 (e2e slug 로그인 it) | `grep -nE "E2E_AUTHOR_SLUG\|getByLabel.*슬러그" e2e/auth.spec.ts` | ✅ PASS | auth.spec.ts:18, 36, 58, 61, 65 박제 (총 5 line) |
| AC-7 (.env.example 양 레포) | `grep -E "E2E_AUTHOR_SLUG" .env.example` | ✅ PASS | `.env.example:10-14` `E2E_AUTHOR_SLUG=deerdevil` 박제 (server는 메인 책임) |
| AC-7 (e2e dry-run 신규 it) | `npx playwright test e2e/auth.spec.ts --list` | ✅ PASS | `auth.spec.ts:60:7 슬러그로 로그인 후 dashboard 진입` 박제 |

---

## 3. raw vitest stdout (G4 검증)

```
$ cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web && npx vitest run

 RUN  v4.1.0 /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web


 Test Files  11 passed (11)
      Tests  151 passed (151)
   Start at  07:04:23
   Duration  2.13s (transform 851ms, setup 1.42s, import 2.00s, tests 1.75s, environment 6.00s)

EXIT_CODE=0
```

이전 baseline 140 → +11 (AuthProvider.test.tsx 11 it 신규).

---

## 4. raw tsc stdout (G1 검증)

```
$ cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web && npx tsc --noEmit
EXIT_CODE=0
```

stdout 비어있음 = 0 errors PASS.

---

## 5. raw build stdout (G5 검증, tail -45)

```
$ cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web && npm run build

✓ Compiled successfully in 4.4s
  Running TypeScript ...
  Finished TypeScript in 3.2s ...
  Collecting page data using 7 workers ...
  Generating static pages using 7 workers (0/23) ...
  Generating static pages using 7 workers (5/23) 
  Generating static pages using 7 workers (11/23) 
  Generating static pages using 7 workers (17/23) 
✓ Generating static pages using 7 workers (23/23) in 225ms
  Finalizing page optimization ...

Route (app)
┌ ○ /
├ ○ /_not-found
├ ƒ /[author]
├ ƒ /[author]/[slug]
├ ƒ /[author]/[slug]/[episode]
├ ƒ /[author]/profile
├ ○ /admin
├ ○ /admin/login
├ ƒ /api/[...path]
├ ○ /dashboard
├ ○ /dashboard/analysis
├ ○ /dashboard/analysis/history
├ ○ /dashboard/analytics
├ ○ /dashboard/chat
├ ○ /dashboard/credits
├ ○ /dashboard/episodes
├ ○ /dashboard/profile
├ ○ /dashboard/theme
├ ○ /dashboard/upload
├ ○ /explore
├ ○ /library
├ ○ /login
├ ○ /privacy
├ ○ /register
├ ○ /robots.txt
├ ƒ /shared/[token]
├ ○ /sitemap.xml
└ ○ /terms


○  (Static)   prerendered as static content
ƒ  (Dynamic)  server-rendered on demand

EXIT_CODE=0
```

`/login` 라우트 정상 prerender (○ Static).

---

## 6. raw lint stdout (G2 검증, 전문)

```
$ cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web && npm run lint

> deer-devil@0.1.0 lint
> eslint


/Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web/src/app/dashboard/analysis/page.tsx
  77:7  warning  Error: Calling setState synchronously within an effect can trigger cascading renders

Effects are intended to synchronize state between React and external systems such as manually updating the DOM, state management libraries, or other platform APIs. In general, the body of an effect should do one or both of the following:
* Update external systems with the latest state from React.
* Subscribe for updates from some external system, calling setState in a callback function when external state changes.

Calling setState synchronously within an effect body causes cascading renders that can hurt performance, and is not recommended. (https://react.dev/learn/you-might-not-need-an-effect).

/Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web/src/app/dashboard/analysis/page.tsx:77:7
  75 |   useEffect(() => {
  76 |     if (!userSlug || !selectedWorkSlug) {
> 77 |       setEpisodes([])
     |       ^^^^^^^^^^^ Avoid calling setState() directly within an effect
  78 |       setSelectedEpisodeId('')
  79 |       return
  80 |     }  react-hooks/set-state-in-effect

/Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web/src/app/explore/page.tsx
  67:6  warning  React Hook useCallback has a missing dependency: 'fetchWithRetry'. Either include it or remove the dependency array  react-hooks/exhaustive-deps

/Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web/src/components/HorizontalScroll.tsx
  45:5  warning  Error: Calling setState synchronously within an effect can trigger cascading renders
... (생략, 동일 패턴)

/Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web/src/features/reader/ui/AuthorSpace.tsx
  35:7  warning  Error: Calling setState synchronously within an effect can trigger cascading renders
... (생략)

/Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web/src/features/reader/ui/CardTransition.tsx
  99:5  warning  Error: Calling setState synchronously within an effect can trigger cascading renders
... (생략)

✖ 5 problems (0 errors, 5 warnings)

EXIT_CODE=0
```

**0 errors PASS**. 5 warnings 모두 본 sprint 외부 (analysis/page.tsx + explore/page.tsx + HorizontalScroll.tsx + AuthorSpace.tsx + CardTransition.tsx) — 본 sprint 변경 파일에서는 lint warning 0건.

---

## 7. e2e raw stdout (G6 dry-run, playwright 서버 미실행 시 정책 정합)

Sprint progress §6-2 G6 정책: "playwright 서버 미실행 시 dry-run skip 박제".

본 작업 환경에서는 grimoire-web localhost (port 3001) + grimoire-server localhost (port 3000)이 미실행 상태이므로 실제 e2e 실행 대신 `--list`로 신규 it 박제만 검증 (dry-run).

```
$ cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web && npx playwright test e2e/auth.spec.ts --list

Listing tests:
  [chromium] › auth.spec.ts:8:7 › 로그인 페이지 (/login) › renders login form with email-or-slug and password fields
  [chromium] › auth.spec.ts:28:7 › 로그인 페이지 (/login) › has link to register page
  [chromium] › auth.spec.ts:34:7 › 로그인 페이지 (/login) › shows error on invalid login attempt
  [chromium] › auth.spec.ts:48:7 › 로그인 페이지 (/login) › Google login button is disabled
  [chromium] › auth.spec.ts:60:7 › 로그인 페이지 (/login) › 슬러그로 로그인 후 dashboard 진입
  [chromium] › auth.spec.ts:79:7 › 회원가입 페이지 (/register) › renders register form with all required fields
  [chromium] › auth.spec.ts:107:7 › 회원가입 페이지 (/register) › has link to login page
  [chromium] › auth.spec.ts:113:7 › 회원가입 페이지 (/register) › shows error when passwords do not match
  [chromium] › auth.spec.ts:133:7 › 회원가입 페이지 (/register) › auto-generates slug from author name
Total: 9 tests in 1 file
EXIT_CODE=0
```

신규 it `auth.spec.ts:60:7 슬러그로 로그인 후 dashboard 진입` 박제 확인. 기존 8 + 신규 1 = 9 tests.

신규 it 본문은 `E2E_AUTHOR_PASSWORD` 미박제 시 `test.skip(!password, ...)`으로 자동 skip — CI/CD 환경에서 환경변수 미박제 시 fail 0건.

dev 환경 또는 사용자가 `E2E_AUTHOR_SLUG=deerdevil` + `E2E_AUTHOR_PASSWORD=...` 박제 후 web/server localhost 부팅 → `npx playwright test e2e/auth.spec.ts --grep "슬러그"` 실행 시 1 passed 기대.

---

## 8. 외부 프로젝트 인용 0건 자가 검증

```
$ grep -rE 'CERTI_PROJ|brightmall|thermage|inapi|admin-certilife|no1-sass' \
    /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web/src/ \
    /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web/e2e/ \
    /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web/docs/ 2>/dev/null | wc -l

       0
```

✅ 0건 PASS. EMAIL_INTEGRITY_PLAN §13 정밀 분석 박제 외에 코드/spec/e2e/docs에 외부 프로젝트명 0건 (Sprint progress §8-6 정합).

---

## 9. 시각 정본 (visual-canon-keeper) 자가 검수 보고

### 9-1. 변경 범위
- `src/app/login/page.tsx` 의 input 1개 (이메일) — 시각 변경 + 1 placeholder 변경
- 변경 전 → 변경 후 비교:
  - label 텍스트: "이메일" → "이메일 또는 슬러그" (텍스트 변경만 — `text-xs uppercase tracking-widest text-neutral-500` 클래스 동일)
  - input type: `type="email"` → `type="text"` (브라우저 검증 동작만 달라짐, 시각 0)
  - placeholder: "your@email.com" → "your@email.com 또는 deerdevil"
  - id + htmlFor 박제 (a11y 강화) — 시각 0
  - autoComplete="username" 박제 — 시각 0

### 9-2. 시각 정본 영향 분석
- `/login`은 **플랫폼 페이지** (작가별 멀티테넌트 공간이 아닌 GNB 외부 일반 페이지). 사슴악마 정본 (deerdevil 작가공간/뷰어/목록)와 직접 영향 0.
- border-radius / padding / 색상 토큰 / focus 스타일 / button 크기 / 폼 레이아웃 변경 0건 (placeholder + label 텍스트 + a11y 속성만 변경).
- placeholder 변경: `placeholder-neutral-400` 색상 클래스 그대로 — placeholder 색상/크기 동일.
- 폰트: `font-ci tracking-[0.2em]` 등 헤더 영역 변경 0.

### 9-3. 자가 검수 결과
- **PASS** — 시각 정본 (deerdevil) 영향 0건 + 로그인 폼 시각 일관성 (border/border-radius/padding/색상) 100% 보존.
- VCK Evaluator 별도 spawn 시 본 보고 + diff 직접 Read로 재검증 가능.
- `reports/VISUAL_CANON_REPORT.md` "EMAIL-P0-3 로그인 폼 슬러그 입력 통합" 항목 박제는 **메인이 VCK Evaluator 호출 후 박제** (web Generator 영역 외).

---

## 10. 자가 보고 단일 진실 정합 검증 표

| 항목 | Sprint progress 정본 §2 | 본 보고 결과 |
|---|---|---|
| AC-6: login/page.tsx 통합 input + 자동 판별 | label "이메일 또는 슬러그" + type="text" + 정규식 + AuthProvider 시그니처 + lib/api 양립 | ✅ 모두 박제 (§1 #2,3,4,5,6,7,8,9,10 + §2 첫 4행) |
| AC-7: e2e slug 로그인 + .env.example | e2e it 1건 + getByLabel + E2E_AUTHOR_SLUG | ✅ 모두 박제 (§1 #14,15,16 + §2 마지막 3행) |
| 거짓말 차단 §8-3: spec 더미 assertion 금지 | toHaveBeenCalledWith / toEqual / toMatchObject ≥3건 | ✅ 8건 박제 (§2 4번째 행) |
| 거짓말 차단 §8-2: commit/push 0건 | 메인 책임 — Generator 자율 commit 금지 | ✅ git 변경 미커밋 상태 (§11 참조) |
| 거짓말 차단 §8-6: 외부 인용 0건 | grep 결과 0 | ✅ 0건 PASS (§8) |
| 시각 정본: VCK 자가 검수 | 사슴악마 정본 영향 0 | ✅ PASS (§9) |
| G1 tsc 0 errors | exit 0 | ✅ §4 |
| G2 lint 0 errors | exit 0 | ✅ §6 (warning 5건은 외부) |
| G4 vitest 145+ PASS | Tests: 145+ | ✅ 151/151 (§3) |
| G5 build 0 errors | exit 0 | ✅ §5 |
| G6 e2e (dry-run skip 박제) | playwright 서버 미실행 시 dry-run | ✅ §7 |
| G10 외부 인용 0건 | grep 0 | ✅ §8 |

**결론: AC-6 + AC-7 모두 충족 ✅. Sprint progress §2 정본 7건 중 web 책임 2건 100% 충족**.

---

## 11. 메인이 다음 단계로 처리할 영역

### 11-1. commit + push (Sprint progress §8-2 정합)
- web 도메인 변경 파일: `git status`로 확인 필요 (Generator 자율 commit 금지)
- 메인이 사용자 승인 후 일괄 commit + push:
  - `feature/email-p0-3-slug-login` 브랜치에서 `git add` + commit
  - develop 머지 (사용자 승인 후)
- 본 Sprint는 server Phase 1 완료 후 메인이 web Phase 2와 동시 머지 권장 (사용자 옵션).

### 11-2. visual-canon-keeper Evaluator 별도 spawn
- 메인이 VCK Evaluator 호출 → `reports/VISUAL_CANON_REPORT.md`에 신규 항목 "EMAIL-P0-3 로그인 폼 슬러그 입력 통합" 박제 → PASS 결과 의무.
- 본 보고 §9 자가 검수와 별개로 VCK가 정본 영향 평가 + diff 직접 Read.

### 11-3. qa Evaluator 독립 재실행 (Sprint progress §8-5)
- `npx vitest src/features/auth src/app/login` 재실행 → AuthProvider.test.tsx 11/11 PASS 검증
- spec 파일 직접 Read → toHaveBeenCalledWith 인자 정합 + toMatchObject 의미 검증
- `git log` 직접 확인 → Generator 자율 commit 흔적 0건 (web 도메인)
- dev 환경 deploy 후 `curl POST /api/auth/login -d '{"slug":"deerdevil","password":"..."}'` raw + 브라우저 `/login` UI 검증

### 11-4. claude-docs 정본 박제 (Generator OUT)
- `.claude/shared-contracts.md` §15 SlugLogin 박제 (Sprint progress §10 정본 텍스트 블록)
- `eval/tasks/regression-59-slug-login.json` 신설
- `.claude/scripts/sensor-slug-login.sh` 신설 (chmod +x)
- `research/HARNESS_ENGINEERING.md` §14.4 Sensors 30→31 + eval task 56→57

### 11-5. server agent Phase 1 진행
- `auth.dto.ts` LoginDto 확장 (XOR validator)
- `auth.usecase.ts` login 분기 (findByEmail ?? findBySlug)
- `auth.usecase.spec.ts` slug 로그인 ≥4 it
- `access-log.service.ts` identifierType 박제
- 본 Generator OUT (별도 server agent 책임)

---

## 12. 검증 게이트 일괄 결과

| 게이트 | 명령 | 결과 |
|---|---|---|
| G1 TypeScript | `npx tsc --noEmit` | ✅ exit 0 (§4) |
| G2 ESLint | `npm run lint` | ✅ exit 0, 0 errors / 5 warnings (외부, §6) |
| G4 vitest | `npx vitest run` | ✅ 151/151 PASS (§3) |
| G5 Build | `npm run build` | ✅ exit 0, /login 라우트 정상 prerender (§5) |
| G6 Playwright | `npx playwright test --list` | ✅ 9 tests (신규 it auth.spec.ts:60 박제, §7) |
| G10 외부 인용 | `grep -rE 'CERTI_PROJ\|...' src/ e2e/ docs/` | ✅ 0건 (§8) |

---

**마지막 갱신**: 2026-05-04 (web Generator Phase 2 완료 — Sprint progress §2 AC-6 + AC-7 100% 충족, 거짓말 차단 정책 8-1~8-7 정합, raw stdout 8 종 박제, 외부 인용 0건, VCK 자가 검수 PASS)
