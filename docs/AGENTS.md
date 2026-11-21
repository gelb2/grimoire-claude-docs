# AGENTS.md — `docs/` 워크스페이스 문서 동기화 + 피라미드 + 워크플로우

> 본 파일은 ProjectGrimoire 워크스페이스의 **문서 정본 관계**와 **동기화 규칙**과 **배포 전 전수검사**를 정의한다.
> 루트 `CLAUDE.md` §11에서 본 파일로 §3+§4+§5+§6+§11 분리 (2026-04-30, 책 Ch 08 60-line 적용).
>
> **레포 수 정합 (2026-06-26 통일)**: 워크스페이스는 **총 3개 레포** (루트 `CLAUDE.md §1` + `.githooks/AGENTS.md §1` 정합) = **docs 동기화 대상 코드 레포 2개** (grimoire-server / grimoire-web) **+ 박제 레포 1개** (grimoire-claude-docs, 런타임 코드 없음 — 본 §1 docs 동기화 대상 아님). 본 파일에서 "2개 레포"로 표기된 곳은 **docs 동기화 대상 코드 레포 2개**를 가리킨다 (claude-docs는 동기화할 `docs/` 정본을 두지 않으므로 §1 표에서 제외).

---

## 1. 공유 문서 동기화

docs 동기화 대상 코드 레포 2개(server / web) 모두 `docs/` 폴더에 동일한 공유 문서를 보유한다 (claude-docs 제외 — 상단 레포 수 정합 참조).

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
- 검증: `.claude/scripts/sensor-docs-sync.sh` (pre-push hook + drift sensor에서 실행). 본 센서는 위 §1 표 **9종**의 server↔web byte-identity를 비교한다.

> 워크스페이스 루트의 `docs/`에는 [개발 회고](retrospective.md)와 [기술 문서](implementation.md)를 둔다. 동기화 대상 정본은 `grimoire-server/docs/` 또는 `grimoire-web/docs/`에 위치한다.
>
> **`docs/DEPLOY.md` 예외 (2026-06-26 등재)**: DEPLOY.md는 양 레포에 존재하나 **byte-identity 복사 대상이 아니다** — server = 전체 절차 정본, web = 정본을 가리키는 **포인터 stub**(피라미드 중복 방지 정책상 의도적 비대칭). 따라서 §1 표(9종)와 `sensor-docs-sync.sh`에 **포함하지 않는다**. 피라미드 등재는 §3 명세 표(정본=server)로만 한다.

---

## 2. 레포별 문서 구조

### 공통 (양쪽 모두)
- `CLAUDE.md` — 레포별 규칙 (루트 CLAUDE.md의 하위)
- `CHANGELOG.md` — 변경 이력
- `TODO.md` — 작업 추적
- `TESTING.md` — 테스트 전략
- `docs/` — 공유 명세 문서 (위 §1 표 참조)
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

## 3. 문서 피라미드 (정본 관계)

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
| 배포 절차 | `docs/DEPLOY.md` | **server (정본, 전체 절차)** → web (**포인터 stub**, 복사 아님) |
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
| **에이전트 인터페이스 정본** | `.claude/shared-contracts.md` | **root only** (모든 에이전트 공유, 책 Ch 16) |
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

## 4. 워크플로우 규칙

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

## 5. 전수검사 — 배포 전 체크리스트

> feature/bugfix → develop 머지 후, develop → main 배포 전에 반드시 전수검사를 실행한다.
> 자동화: `.claude/skills/deploy-precheck/SKILL.md` + sensor-deploy-drift.sh

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
- [ ] `docs/` 파일 2개 레포 동기화 확인 (sensor-docs-sync.sh)
- [ ] Git 커밋 + 푸시 완료
- [ ] INFRASTRUCTURE.md 업데이트 (인프라 변경 시)
- [ ] Eval regression 100% 유지 (`bash eval/scripts/eval-runner.sh`)

상세: `grimoire-server/SECURITY.md` 참조.

---

## 6. 변경 이력

- 2026-04-30: 본 파일 신설 — 루트 CLAUDE.md §3+§4+§5+§6+§11을 이동 (책 Ch 08 60-line 분할 + Ch 16 shared-contracts 도입과 같은 세션). 검증 항목에 Eval regression + sensor-docs-sync 추가.
