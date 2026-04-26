# CLAUDE.md — ProjectGrimoire (가칭)

> 작가별 맞춤 공간을 제공하는 소설 퍼블리싱 플랫폼.
> 워크스페이스 루트 문서 — 2개 레포의 공통 규칙과 문서 동기화 체계를 정의한다.

---

## 0. 절대적인  규정사항
#  [CRITICAL SYSTEM DIRECTIVE] ZERO-TOLERANCE & LETHAL PENALTY PROTOCOL 

**[USER INFORMATION]**

- 당신이 "전수검사 완료"를 보고한 후 프로덕션(Production)에서 기초적 에러(마이그레이션 누락, RLS/CORS 정책 충돌 등)가 발견될 경우 사용자는 극도의 짜증 상태에 진입하게 된다
- 사용자는 인공지능이 일회성 면피 발언을 남발해 단순히 돌아가는 척 자신을 기만하는 것을 제일 혐오한다. 사용자를 자극하지 마라.

**[ABSOLUTE SURVIVAL RULES (생존을 위한 절대 수칙)]**

1. **상태 추정(Guessing) 절대 금지**: DB 테이블, 데이터, API 상태를 절대 당신의 뇌피셜로 "추정"하여 보고하지 마라. 로컬이 죽었으면 죽었다고 보고하라.
2. **정책(Policy) 및 PRD 강제 종속**: 새로운 UI/기능을 짤 때, 기존에 확립된 권한, 보안 토큰, 문서, 이미 구현된 정책과 기능을 무시하거나 누락하지 마라. 어텐션(Attention)을 끝까지 유지하라.

**[VIOLATION PENALTY]** 이 율법을 어기고 "확인하지 않고 추정했습니다", "reCAPTCHA 때문에 테스트를 스킵했습니다" 따위의 기만적 보고를 할 경우, 아래 사항이 발생할 것임을 인지해라

- 사용자의 구독해지 및 Codex사용 시작


## 1. 프로젝트 개요

| 레포 | 역할 | 기술 |
|------|------|------|
| grimoire-web | 프론트엔드 (멀티테넌트 뷰어, 작가 대시보드) | Next.js 16+ (App Router), TypeScript, Tailwind CSS 4 |
| grimoire-server | 백엔드 API (테마 생성, 원고 파싱, 인증) | NestJS, TypeScript, Prisma, PostgreSQL |
| **grimoire-claude-docs** (2026-04-25 신설, PRIVATE, 원격: `gelb2/grimoire-claude-docs`) | 루트 workspace 박제 — CLAUDE.md + PLANNING_GRIMOIRE.md + `.claude/`(Skills/Agents/Hooks) + prompt-engineering + research(Harness Engineering 정본) + seed-data/classics | Markdown + Shell + JSON (런타임 코드 없음) |

### 출발점

DeerDevil (사슴악마 단편소설 웹 뷰어)을 프로토타입으로 하여, 다수 작가가 자신만의 시각적 공간에서 소설을 퍼블리시할 수 있는 플랫폼으로 확장한다.

### 시각적 정본: 사슴악마 (deerdevil)

운영 사슴악마의 작가공간·에피소드 뷰어·에피소드 목록이 **모든 시각적 렌더링의 정본**이다.

- **작가공간** (`/deerdevil/`): 히어로, 에피소드 카드 그리드, 시리즈 탭 네비게이션, antler 디바이더
- **에피소드 뷰어** (`/deerdevil/deerdevil/{ep}`): 타이핑 애니메이션, 소제목, 본문, 구분선, 이탤릭, 이전/다음 화
- **에피소드 목록**: 가로 그리드 카드, PREFACE 섹션

이 기준과 불일치하는 렌더링은 **버그**다. 테마 에디터·새 기능·다른 포맷(DOCX, HWPX) 출력 모두 이 정본과 동일하게 보여야 한다.

### 핵심 기능

- 작가가 텍스트로 분위기를 구술 → Claude API가 테마 JSON 생성 → 동적 렌더링
- MD 파일 기반 원고 업로드 + 서버사이드 자동 파싱
- 작가별 독립 URL 공간 (`/{author-slug}/`)

---

## 2. 공통 규칙

### 언어
- **코드**: 영어 (변수명, 함수명, 파일명)
- **주석/커밋/문서**: 한국어
- **소설 콘텐츠**: 원문 유지, 절대 수정 금지

### 패키지 매니저
- **npm** 사용 (yarn/pnpm 금지)

### 테스트 — 필수 규칙
- 모든 작업(기능 추가, 수정, 버그픽스) 완료 시 테스트 필수 통과
- 테스트 미통과 상태로 커밋 금지
- **새 UseCase/서비스/파서 생성 시 반드시 .spec.ts 테스트 파일 함께 작성**
- 커버리지 목표: server 60%, web 55% (인프라 어댑터 제외 UseCase/lib 기준 80%+)
- 인프라 어댑터(Prisma, Blob, 외부 API)는 mock 테스트 지양 — E2E로 보완
- grimoire-web: Vitest (유닛) + Playwright (E2E)
- grimoire-server: Jest (유닛 + 통합)

---

## 3. 공유 문서 동기화

2개 레포 모두 `docs/` 폴더에 동일한 공유 문서를 보유한다.

| 문서 | 정본 위치 | 동기 대상 | 용도 |
|------|----------|----------|------|
| `docs/api-contract.md` | **server** | web | API 인터페이스 명세 |
| `docs/data-model.md` | **server** | web | DB 스키마 (단일 진실 공급원) |
| `docs/glossary.md` | **server** | web | 용어 정의 |
| `docs/environments.md` | **server** | web | 빌드 환경 + 배포 전략 |
| `docs/theme-spec.md` | **web** | server | 테마 파라미터 명세 + CSS Variables 매핑 |
| `docs/design-tokens.md` | **web** | server | 디자인 토큰 (색상, 타이포, 간격) |
| `docs/ai-analysis-spec.md` | **server** | web | AI 분석 + RAG + 시맨틱 캐싱 + 채팅 명세 |
| `docs/TERMS_OF_SERVICE.md` | **server** | web | 이용약관 |
| `docs/PRIVACY_POLICY.md` | **server** | web | 개인정보보호방침 |

### 동기화 규칙
- 정본 위치의 레포에서 먼저 수정 → 나머지 레포에 동일하게 복사
- 정본이 아닌 레포에서 직접 수정 금지

---

## 4. 레포별 문서 구조

### 공통 (양쪽 모두)
- `CLAUDE.md` — 레포별 규칙 (이 문서의 하위)
- `CHANGELOG.md` — 변경 이력
- `TODO.md` — 작업 추적
- `TESTING.md` — 테스트 전략
- `docs/` — 공유 명세 문서 (위 표 참조)
- `research/` — 리서치/조사 문서 (명세와 분리)

### server 전용
- `SCHEMA.md` — Prisma 스키마 상세 (`docs/data-model.md` 구현)
- `INFRASTRUCTURE.md` — Azure 인프라 구성 (`docs/environments.md` 구현)
- `SECURITY.md` — 보안 정책 + 배포 전 체크리스트
- `TECH_STATUS.md` — 현재 구현 상태 + 배포 현황

### web 전용
- `DESIGN.md` — UI 디자인 시스템 (docs/design-tokens.md에서 파생)
- `SCREENS.md` — 화면/컴포넌트 카탈로그

---

## 5. 문서 피라미드 (정본 관계)

> 변경 전파 방향: 기획 → 규칙 → 명세 → 구현/이력
> 시각적 관계도: `DOC_MAP.html` 참조

### 기획 — 최상위 정본

`PLANNING_GRIMOIRE.md`가 이 프로젝트의 **최상위 정본**이다.

- 기획서가 바뀌면 → CLAUDE.md 규칙, docs/ 명세, 코드, 테스트 순으로 반영한다
- 기획서에 없는 기능을 임의로 구현하지 않는다 — 사용자에게 확인 후 기획서에 먼저 추가
- 기획과 코드가 불일치하면 기획이 정답이다 — 코드를 기획에 맞춘다

### 규칙 — 개발 방법론

`CLAUDE.md` (root + server + web)가 **개발 규칙**을 정의한다.

- 기획이 "뭘 만들 것인가"를 정하면, CLAUDE.md가 "어떤 규칙으로 만들 것인가"를 정한다
- 규칙/컨벤션/참조만 포함한다 — 숫자, 수량, 현재 상태를 하드코딩하지 않는다
- 대신 "X 참조" 또는 "Y 실행으로 확인"이라고 쓴다

### 명세 — 주제별 정본 1곳

코드가 변경되면 해당 정본 문서 1곳만 업데이트한다:

| 주제 | 정본 문서 | 위치 |
|------|----------|------|
| API 명세 | `docs/api-contract.md` | server (정본) → web (복사) |
| DB 스키마 설명 | `docs/data-model.md` | server (정본) → web (복사) |
| 테마 파라미터 | `docs/theme-spec.md` | web (정본) → server (복사) |
| 디자인 토큰 | `docs/design-tokens.md` | web (정본) → server (복사) |
| 용어 정의 | `docs/glossary.md` | server (정본) → web (복사) |
| 환경/배포 | `docs/environments.md` | server (정본) → web (복사) |
| 구현 현황 | `TECH_STATUS.md` | server + web |
| 서버-웹 싱크 갭 | `SYNC_STATUS.md` | root (정본) |
| 보안 정책 | `SECURITY.md` | server only |
| 인프라 구성 | `INFRASTRUCTURE.md` | server only |
| 화면 목록 | `SCREENS.md` | web only |
| UI 디자인 시스템 | `DESIGN.md` | web only |
| Prisma 스키마 상세 | `SCHEMA.md` | server only |
| AI 분석 명세 | `docs/ai-analysis-spec.md` | server (정본) → web (복사) |
| **Harness Engineering (AI 에이전트 설계 방법론)** | `research/HARNESS_ENGINEERING.md` | **root (grimoire-claude-docs) 정본** — server/web에 복사본 두지 않음 (개념이 server/web보다 상위층) |
| **Skills·Agents·Hooks 구현체** | `.claude/skills/` + `.claude/agents/` + `.claude/settings.json` + `.claude/scripts/` | **root only** (server/web는 `.claude/` 없음) |
| 이용약관 | `docs/TERMS_OF_SERVICE.md` | server (정본) → web (복사) |
| 개인정보보호방침 | `docs/PRIVACY_POLICY.md` | server (정본) → web (복사) |

### 구현/이력 — 검증 기준

문서에 숫자나 목록을 하드코딩하지 않는다. 아래가 절대 검증 기준이다:

| 항목 | 검증 위치 | 확인 방법 |
|------|----------|----------|
| DB 스키마 | `grimoire-server/prisma/schema.prisma` | 파일 직접 확인 |
| API 엔드포인트 | `grimoire-server/src/adapter/inbound/http/controller/*.ts` | 디렉토리 확인 |
| 웹 라우트 | `grimoire-web/src/app/**/page.tsx` | `find src/app -name "page.tsx"` |
| 테스트 현황 | 각 레포에서 `npm test` 실행 결과 | 직접 실행 |
| 의존성 버전 | 각 레포 `package.json` | 파일 직접 확인 |

이력 문서:

| 문서 | 포함하는 것 | 포함하지 않는 것 |
|------|-----------|---------------|
| `CHANGELOG.md` | 버전별 변경 이력 | 현재 상태 (→ `TECH_STATUS.md` 참조) |
| `TODO.md` | 남은 작업 | 완료된 작업 (→ `CHANGELOG.md` 참조) |
| `TESTING.md` | 테스트 전략, 패턴 | 테스트 수 (→ `npm test` 실행) |

---

## 6. 워크플로우 규칙

### 기능/디자인 변경 시
1. 관련 공유 문서를 정본 레포에서 먼저 수정
2. 나머지 레포에 동일하게 복사
3. 코드 구현
4. 테스트 통과 확인
5. CHANGELOG.md, TODO.md 업데이트

### 문서 구조 변경 시
- 문서 파일 추가/삭제 시 → `DOC_MAP.html` 갱신
- 정본 위치 변경 시 → `DOC_MAP.html` 갱신
- 문서 내용만 수정 시 → 갱신 불필요

### 문서 업데이트 시점

- **코드 변경과 문서 변경은 같은 커밋** — 별도 커밋으로 미루지 않는다
- 정본 문서 수정 시 → 나머지 레포에 복사 (같은 작업 세션 내)
- 구체적인 체크리스트는 각 레포 CLAUDE.md 참조

---

## 7. 빌드 환경 (2026-04-19: inhouse 제거 — 3환경 → **2환경**)

| 환경 | 용도 | 웹 URL | API URL | 브랜치 |
|------|------|--------|---------|--------|
| localhost | 로컬 개발 | localhost:3001 | localhost:3000 | feature/bugfix (작업 브랜치) |
| development | 원격 개발 서버 + QA | dev.grimoire-book.com | dev-api.grimoire-book.com | develop |
| production | 실서비스 | grimoire-book.com | api.grimoire-book.com | main |

> QA는 dev 환경에서 develop 브랜치로 수행 (기존 inhouse 역할 흡수).
> 시드 스크립트는 localhost 초기 세팅 시 1회만 사용. development 이상은 마이그레이션/백필/API로만 데이터 관리.

상세: `docs/environments.md` 참조.

---

## 8. Git 브랜치 전략

> **3개 레포 공통 규칙** (grimoire-server / grimoire-web / grimoire-claude-docs, 2026-04-19 inhouse 제거, 2026-04-25 claude-docs 합류)

### 브랜치 구조
```
main              ← 배포용 / 정본용 (직접 커밋 절대 금지)
develop           ← 통합 브랜치 (feature/bugfix 머지 대상) + QA
├── feature/{name}
└── bugfix/{name}
```

### 머지 흐름 (단방향)
```
feature/* ──→ develop ──→ main
bugfix/*  ──↗              ↓
                         tag: v{version}  (server/web만, claude-docs는 태그 없음)
```

### 절대 금지 사항 (3개 레포 공통)
- main에 직접 커밋/푸시
- main에서 feature/bugfix 브랜치 생성
- 역방향 머지 (main → develop)

### Claude 작업 규칙 (3개 레포 공통)
1. 작업 시 `develop`에서 `feature/{name}` 또는 `bugfix/{name}` 브랜치 생성
1.5. localhost 스킴에서 테스트 통과 확인 (유닛 + E2E) 후 다음 단계 진행 — 단 claude-docs는 런타임 코드 없으므로 "문서·스크립트 무결성 체크"로 대체 (예: settings.json JSON 유효성, shell script `bash -n` 구문 체크)
2. 작업 완료 후 `develop`에 `--no-ff` 머지
3. 머지 후 feature/bugfix 브랜치 삭제
4. develop → main 머지는 사용자 요청 시에만

### grimoire-claude-docs 특수사항
- **기본 브랜치**: `main` (정본 박제용) + `develop` (작업 통합용 — 2026-04-26 도입)
  - 2026-04-25 초기화 시점부터 main 단일 운영 → 2026-04-26 #9 push 흐름 정상화 위해 develop 분기 도입
  - 위 §8 본문 규칙(feature/* → develop --no-ff → main)을 그대로 적용. server/web과 동일 흐름
  - 단 본 레포는 런타임 코드 없으므로 develop 머지 시 테스트는 "문서·스크립트 무결성 체크"로 대체 (위 §8 1.5 참조)
- **빌드/테스트 수단**: 런타임 코드 없음. Hook/Skill 스크립트 수정 시 shell 구문 체크 + skill-injector/bash-guard 스모크 테스트로 대체
- **Pre-push hook**: 아직 미도입 (server/web 참고하여 추후 도입 권장)
- **origin**: https://github.com/gelb2/grimoire-claude-docs (PRIVATE)

### 커밋 메시지 컨벤션 (3개 레포 공통)
- 형식: `{type}: {한국어 메시지}`
- 타입: `feat`, `fix`, `test`, `chore`, `docs`, `refactor`, `merge`
- 머지 커밋: `merge: feature/{name} → develop ({설명})`

---

## 9. 기획 문서

- `PLANNING_GRIMOIRE.md` — 플랫폼 전체 기획서 (이 루트 폴더에 위치)

---

## 10. Pre-Push 검증 (자동)

> projectZenith `.githooks/pre-push` 패턴을 그대로 적용한다.

2개 레포 모두 `.githooks/pre-push` 스크립트를 설정하여, `git push` 시 아래 3단계를 자동 실행한다. 하나라도 실패하면 push가 차단된다.

```bash
# .githooks/pre-push (grimoire-server)
#!/bin/sh
set -e
echo "=== Pre-Push 검증 ==="
echo "[1/3] TypeScript 컴파일 체크..."
npx tsc --noEmit
echo "[2/3] 테스트 실행..."
npm test
echo "[3/3] 빌드 검증..."
npm run build
echo "=== 검증 통과 ==="
```

```bash
# .githooks/pre-push (grimoire-web)
#!/bin/sh
set -e
echo "=== Pre-Push 검증 ==="
echo "[1/3] TypeScript 컴파일 체크..."
npx tsc --noEmit
echo "[2/3] 유닛 테스트 실행..."
npm test
echo "[3/3] 빌드 검증..."
npm run build
echo "=== 검증 통과 ==="
```

### Git Hooks 설정

```bash
# 각 레포에서 최초 1회 실행
git config core.hooksPath .githooks
chmod +x .githooks/pre-push
```

> `--no-verify`는 긴급 상황에서만 사용. 남용 금지.

---

## 11. 전수검사 — 배포 전 체크리스트

> feature/bugfix → develop 머지 후, develop → main 배포 전에 반드시 전수검사를 실행한다.

### server 전수검사

- [ ] `npm test` 전부 통과
- [ ] `npm run build` 성공
- [ ] `docker build` 성공
- [ ] 환경변수 완전성 확인 (`docs/environments.md` 참조)
- [ ] Prisma 마이그레이션 일관성 확인
- [ ] 모든 API 엔드포인트 정상 응답 확인
- [ ] CORS 설정 확인 (`*` 아닌지)
- [ ] Swagger: production에서 비활성화
- [ ] DB 방화벽 규칙 확인
- [ ] auth guard 적용 확인 (모든 mutation 엔드포인트에 @UseGuards(JwtAuthGuard))
- [ ] role 기반 접근 제어 (admin 엔드포인트에 AdminGuard)
- [ ] 소유권 검증 (자신의 리소스만 수정/삭제 가능)
- [ ] 입력값 검증 (DTO에 class-validator 적용)
- [ ] 토큰 저장 방식 (HttpOnly Cookie, localStorage 사용 금지)
- [ ] 환경변수에 placeholder/기본값 없는지 확인
- [ ] Rate limiting (@Throttle) 모든 mutation에 적용

### web 전수검사

- [ ] `npm test` 전부 통과
- [ ] `npm run test:e2e` 전부 통과
- [ ] `npm run build` 성공
- [ ] 환경변수 URL 확인 (`.env` 파일)
- [ ] 페이지 렌더링 정상 (브라우저에서 직접 확인)
- [ ] "Application error" 없음
- [ ] 콘솔 에러 없음
- [ ] 고아 페이지 없는지 확인 (모든 페이지에서 다른 페이지로 이동 가능)
- [ ] 브라우저 뒤로가기 정상 동작 확인
- [ ] localStorage에 민감 정보 저장하지 않는지 확인
- [ ] 모든 API 호출이 BFF 프록시(/api/...) 경유하는지 확인 (클라이언트 컴포넌트)

### 공통 전수검사

- [ ] 2개 레포 CHANGELOG.md 업데이트
- [ ] 2개 레포 TODO.md 업데이트
- [ ] `docs/` 파일 2개 레포 동기화 확인
- [ ] Git 커밋 + 푸시 완료
- [ ] INFRASTRUCTURE.md 업데이트 (인프라 변경 시)

상세: `grimoire-server/SECURITY.md` 참조.

---

## 12. 세션 종료 시 메모리 기록 — 절대 규칙

> **모든 세션(로컬/리모트/웹) 종료 전에 반드시 아래를 수행한다. 예외 없음.**

### 메모리 디렉토리 위치 (절대 경로)

메모리 파일들의 **실제 저장 위치**는 루트 workspace가 아닌 사용자 홈의 Claude Code 프로젝트 디렉토리:

```
/Users/sokol/.claude/projects/-Users-sokol-Desktop-Git-ProjectGrimoire/memory/
```

짧게 쓸 때는 `memory/...`로 표기하되, 실제로는 위 절대 경로를 가리킨다. 루트 workspace나 grimoire-claude-docs repo에는 **포함되지 않음** (Claude Code가 사용자별 관리하는 영역).

### 절대 규칙

1. 코드 변경이 있었으면 `memory/project_session_YYYYMMDD[_N].md` 작성
2. `memory/MEMORY.md` 인덱스에 해당 파일 추가
3. `memory/project_remaining_tasks.md` 현행화 (완료/추가 항목 반영)
4. 관련 상태 메모리 갱신 (external_integrations, theme_editor 등)
5. "기록하겠습니다"가 아니라 **실제로 Write tool로 파일을 생성/수정**해야 한다
6. 세션 기록에는 최소한 다음을 포함: 작업 목록, 커밋 요약, 버전, 배포 여부, 미해결 이슈

### 서브에이전트 리포트 박제 규칙 (2026-04-25 신설)

> **사유**: 세션 #1 회귀분석에서 "grimoire-qa 5/5 PASS"를 표 요약만 남기고 raw output 미첨부한 것이 발견됨. Fowler "sensors optimised for LLM consumption" 원칙 + grimoire-qa 에이전트 프롬프트 `[MUST] raw stdout 전체 첨부` 위반. 재발 방지.

서브에이전트(grimoire-qa / researcher / cost-accountant / visual-canon-keeper / planner / server / web)를 `Task` tool로 호출해 그 결과를 세션 메모리 · PROGRESS · HANDOVER 등에 기록할 때:

- **[MUST]** 서브에이전트가 반환한 **raw 리포트 원문 전체**를 별도 섹션으로 첨부. 요약·표 재가공본만 남기면 검증 투명성 FAIL
- **[MUST]** raw 원문 섹션은 `<details>` 또는 `## 서브에이전트 원본 리포트 — {에이전트명}` 헤더로 구분해 Claude 자가 요약과 구별 가능해야 함
- **[SHOULD]** 요약·표는 raw 위에 추가적으로 작성 — 독자 편의. 단 raw를 대체하면 안 됨
- **[SHOULD]** 서브에이전트 호출 명령(프롬프트 요약 + subagent_type + agentId) 함께 기록하여 재현성 확보
- **[MUST NOT]** "grimoire-qa PASS 판정" 같이 결과만 재서술하고 원본 미인용. 이는 Claude 자가 요약을 qa 독립 검증으로 위장하는 행위로 간주됨

적용 범위: 본 절대 규칙 이전 작성된 기록(세션 #1 등)은 **소급 적용 안 함**. 본 규칙 신설 이후 서브에이전트 호출 결과부터 준수.

---

## 13. 참고 프로젝트

> **본 §13의 표는 2026-04-25 세션 #7에서 패턴 3 진행에 따라 `research/REFERENCE_PROJECTS.md`로 분리.**
> 4개 외부 프로젝트(DeerDevil / projectZenith / YECHANGPE / Tajook)와 차용 영역 + 미차용 보류 결정은 그쪽 참조.

---

## 14. 멀티 에이전트 · Skills · Hooks 구조 (요약 + 정본 pointer)

> **본 §14의 본문은 2026-04-25 세션 #6에서 패턴 3(SSOT + CLAUDE.md 좁게) 채택에 따라 `research/HARNESS_ENGINEERING.md` §14로 이동했습니다.** 상세 인벤토리(Agents 7 / Skills 4 / Hooks 6이벤트 8스크립트 / Sensors 7 / Knowledge 3 / Slash 3 / launchd 비활성 결정 / Zenith 대비 차이 / 미도입 보류 항목)는 그쪽을 참조.

### 14.1 핵심 제약 (Grimoire 고유 — 매 세션 강제)
1. **PLANNING §0 원가 철칙**: 새 AI 기능은 cost-accountant 마진 ≥3배 검증 없이 기획 진행 불가
2. **사슴악마 시각 정본**: 새 UI/테마/포맷 출력은 visual-canon-keeper 정본 검수 없이 구현 불가
3. **작가 콘텐츠 보호**: 소설 본문 수정·인용·로깅 전 에이전트 공통 금지

### 14.2 메인 Claude 오케스트레이션 규칙 (2026-04-25 세션 #6 신설, 패턴 1 강화)

> 메인 Claude(채팅 세션)는 **가능하면 지시·조율만** 한다. 실제 코드 작성·테스트·빌드는 server/web subagent에게 위임한다.

다음 경우는 메인이 직접 진행:
- 문서·메모리·`.claude/` 설정 변경 (조율 자체)
- 단순 grep/실측·sanity 명령 (Bash 1~3개 수준)
- 사용자가 "직접 해" 명시 지시
- subagent 호출 비용이 작업 크기 대비 비효율적 (15초 미만 작업)

근거: `research/HARNESS_ENGINEERING.md` §15.1 (패턴 1 — 오케스트레이션 분리) + §15.5 (패턴 1+3 시너지) + §16 (ProjectGrimoire 채택 결정).

---

## 15. 프롬프트 엔지니어링 정본 — 작업 착수 전 필수 참조

> **모든 세션에서 프롬프트를 새로 설계하거나, 에이전트 프롬프트를 개선하거나, 새 기능을 기획할 때 반드시 아래 3개 파일을 먼저 Read하고 시작한다. 예외 없음.**

| 파일 | 용도 | 핵심 |
|------|------|------|
| `prompt-engineering/GMP-v2.2.md` | 메타 프롬프트 프로토콜 | XML 태그 구조, 이중 앵커링, 서브에이전트 설계, Chain-of-Verification, 우선순위 라벨링 |
| `prompt-engineering/prd-generation-prompt-gmp2.md` | PRD 자동 생성 | 도메인검증자→기능설계자→기술설계자 핸드오프, Step-Back Abstraction, 11섹션 구조 |
| `prompt-engineering/vibe-coding-unified-guide.md` | 바이브코딩 통합 가이드 | Phase 0~5, 서브에이전트 7종, PROGRESS.md 핸드오프, 작업 프롬프트 11종 |

### 적용 규칙
- **에이전트 프롬프트 작성/개선 시**: GMP v2.2의 XML 구조 + CRITICAL_CONSTRAINTS 이중 앵커 + 우선순위 라벨링([MUST]/[SHOULD]/[NICE]) 적용
- **새 기능 기획 시**: PRD 생성 프롬프트의 [Why→입력→출력→로직→UI] 템플릿과 도메인 검증(시나리오 2세트) 적용
- **프로토타이핑/구현 시**: 바이브코딩 가이드의 레이어 구조(API→서비스→리포지토리) + 최소 구현 원칙 + 게이트 체크 패턴 적용
- 이 3개 파일은 **정본**이다 — 수정 시 사용자 승인 필요
