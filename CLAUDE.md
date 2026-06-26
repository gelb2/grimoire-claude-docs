# CLAUDE.md — ProjectGrimoire (가칭)

> 작가별 맞춤 공간을 제공하는 소설 퍼블리싱 플랫폼. 워크스페이스 루트 — 3개 레포 공통 핵심 규칙만.
> **분할 정본 (책 Ch 08 60-line 적용, 2026-04-30)**: `.claude/AGENTS.md` (하네스/메모리/멀티에이전트), `docs/AGENTS.md` (문서 동기화/피라미드/전수검사), `.githooks/AGENTS.md` (Git/Pre-Push), `.claude/shared-contracts.md` (에이전트 인터페이스 정본, 책 Ch 16).

---

## 0. ZERO-TOLERANCE & LETHAL PENALTY PROTOCOL — 절대 규정

**[USER INFORMATION]**
- "전수검사 완료" 보고 후 프로덕션 기초 에러(마이그레이션 누락, RLS/CORS 정책 충돌 등) 발견 시 사용자는 극도 짜증 진입
- 일회성 면피 발언으로 돌아가는 척 기만 행위 — 사용자 최혐오. 자극 금지.

**[ABSOLUTE SURVIVAL RULES]**
1. **상태 추정(Guessing) 절대 금지**: DB 테이블/데이터/API 상태를 절대 뇌피셜로 "추정" 보고 금지. 로컬이 죽었으면 죽었다고 보고
2. **정책(Policy)·PRD 강제 종속**: 새 UI/기능 짤 때 기존 권한·보안 토큰·문서·이미 구현된 정책을 무시·누락 금지. 어텐션 끝까지

**[VIOLATION PENALTY]** 위반 시 → 사용자의 구독해지 + Codex 사용 시작

---

## 1. 프로젝트 (3개 레포)

| 레포 | 역할 | 기술 |
|------|------|------|
| grimoire-web | 프론트 (멀티테넌트 뷰어 + 작가 대시보드) | Next.js 16+ (App Router), TS, Tailwind 4 |
| grimoire-server | 백엔드 API (테마 생성/원고 파싱/인증) | NestJS, TS, Prisma, PostgreSQL |
| **grimoire-claude-docs** (PRIVATE, 2026-04-25 신설) | 루트 workspace 박제 — CLAUDE.md+PLANNING+`.claude/`+research+prompt-engineering | Markdown+Shell+JSON |

**시각적 정본**: 사슴악마(deerdevil) 작가공간/에피소드 뷰어/에피소드 목록이 모든 시각 렌더링의 정본. 불일치는 **버그**.

---

## 2. 공통 규칙

- **언어**: 코드=영어, 주석/커밋/문서=한국어, 소설 콘텐츠=원문 유지 절대 수정 금지
- **패키지**: npm (yarn/pnpm 금지)
- **테스트**: 커밋 전 필수 통과. 새 UseCase/서비스/파서는 .spec.ts 함께. 커버리지 server 60%/web 55%
- **상세 문서 동기화 + 피라미드 + 전수검사**: `docs/AGENTS.md` 참조

---

## 7. 빌드 환경 (2환경, 2026-04-19 inhouse 제거)

| 환경 | 웹 URL | API URL | 브랜치 |
|------|--------|---------|--------|
| localhost | localhost:3001 | localhost:3000 | feature/bugfix |
| development | dev.grimoire-book.com | dev-api.grimoire-book.com | develop |
| production | grimoire-book.com | api.grimoire-book.com | main |

> QA는 dev 환경에서 develop 브랜치로. 시드 스크립트는 localhost 1회만.
> 상세: `grimoire-server/docs/environments.md` (정본 = grimoire-server, web 복사본 = `grimoire-web/docs/environments.md`) + `.githooks/AGENTS.md` (브랜치/Pre-Push)

---

## 9. 기획 + 13. 참고 프로젝트

- **기획 정본**: `PLANNING_GRIMOIRE.md` (이 루트)
- **참고 프로젝트**: `research/REFERENCE_PROJECTS.md` (DeerDevil/projectZenith/YECHANGPE/Tajook 차용 영역)

---

## 15. 프롬프트 엔지니어링 정본 (필수 참조)

작업 착수 전 반드시 Read하고 시작 — 예외 없음.

| 파일 | 핵심 |
|------|------|
| `prompt-engineering/GMP-v2.2.md` | 메타 프롬프트 (XML 구조, 이중 앵커, 우선순위 라벨링) |
| `prompt-engineering/prd-generation-prompt-gmp2.md` | PRD 자동 생성 (도메인검증→기능설계→기술설계 핸드오프) |
| `prompt-engineering/vibe-coding-unified-guide.md` | Phase 0~5 + 서브에이전트 7종 + 작업 프롬프트 11종 |

이 3개 파일은 **정본** — 수정 시 사용자 승인 필요. 적용 규칙은 `.claude/AGENTS.md` §4 참조.
