---
name: 멀티 에이전트 구조 (10개 = 7 핵심 + 3 메타)
description: .claude/agents/ 10개 파일 — 7 핵심 기능(planner/researcher/cost-accountant/visual-canon-keeper/server/web/qa) + 3 메타·인프라(infrastructure/harness/verifier). PLANNING §0 원가 철칙 게이트, 사슴악마 시각 정본 수호.
type: project
---

**구조:** 현행 10 에이전트 = **7 핵심 기능** + **3 메타·인프라**.

- **7 핵심 기능 (도메인 작업)**: planner / researcher / cost-accountant / visual-canon-keeper / server / web / qa. 메인 Claude가 계층적으로 호출 — researcher → cost-accountant/planner → visual-canon-keeper → server/web → qa. 2026-04-15에 Zenith 패턴 차용해 최초 도입. 2026-04-17 GMP v2.2 구조로 프롬프트 전면 전환 (XML 태그 + 이중 앵커링 + SELF_VERIFICATION).
- **3 메타·인프라 (시스템 자체)**: infrastructure (2026-05-08 신설 — Azure/Cloud Run 배포·secret·cron) / harness (2026-05-09 신설 — 하네스 메타 영역 `.claude/*` 전담) / verifier (2026-05-29 신설 — 읽기전용 독립 검증). 도메인 기능 흐름의 바깥에서 배포·하네스·검증을 담당한다.

> **핸드오프 매트릭스 (`agent-interaction-matrix.md`)는 7 핵심 기준이 정본** — 도메인 작업 흐름(기획→구현→검증)은 7 핵심 사이에서만 발생한다. 3 메타 에이전트는 그 흐름의 트리거 대상이 아니라 시스템 운영 주체이므로 별도 명시(아래 §3 메타 에이전트)한다.

**인터페이스 정본 (2026-04-30 #10 신설, 책 Ch 16):**
- `.claude/shared-contracts.md` — 7 핵심 에이전트 공유 인터페이스 10개 정본 (PLANNER_REPORT / COST_AUDIT_REPORT / VISUAL_CANON_REPORT / DEV_REPORT / QA_REPORT / AskOptions / ANALYSIS_CREDIT_COST=4 / Eval task 형식 / LLM-Judge 가드 / PostToolUseFailure hook)
- 7 핵심 에이전트 .md 모두 §0 직후 1줄 동기 참조 박제 — 인터페이스 변경 시 shared-contracts.md 먼저 갱신 → 7 .md 자동 정합 (산출물 reports/*.md를 주고받는 도메인 흐름은 7 핵심에 한정)
- 자동 검증: `sensor-shared-contracts.sh` (FAIL/WARN 0건 박제 강제)

**프롬프트 정본 3개 (역할별 차등 Read):**
- `prompt-engineering/GMP-v2.2.md` — 프롬프트 설계 원칙 (XML, 이중 앵커, CoV, 우선순위 라벨)
- `prompt-engineering/prd-generation-prompt-gmp2.md` — PRD 자동 생성 (planner 전용)
- `prompt-engineering/vibe-coding-unified-guide.md` — Phase 0~5, 레이어 구조, 게이트 체크

역할별 매핑:
| 에이전트 | GMP | PRD | vibe-coding |
|---|:---:|:---:|:---:|
| planner | ✅ | ✅ | ✅ |
| researcher | ✅ | — | — |
| server / web | — | — | ✅ |
| qa | ✅ | — | ✅ |
| cost-accountant / visual-canon-keeper | — | — | — |

에이전트 프롬프트 작성/수정 시 반드시 해당 정본 구조를 따라야 한다.

**Why:** Zenith/RoadRage와 달리 Grimoire의 핵심 제약은 두 가지 — ① §0 크레딧-원가 마진 불역전, ② 사슴악마 시각 정본. 이 두 제약의 전용 수호자를 에이전트화(cost-accountant, visual-canon-keeper). copywriter는 Grimoire에 불필요 (작가 본인 콘텐츠, 시스템 텍스트 적음). designer 역할은 visual-canon-keeper가 겸직.

**How to apply:**
- 신규 AI 기능: cost-accountant 마진 ≥3배 검증 없이 기획 진행 불가
- 신규 UI 컴포넌트: visual-canon-keeper 사슴악마 정본 검수 없이 구현 불가
- 커스텀 에이전트는 세션 재시작 후 로드

## 에이전트 파일 위치 (10개 = 7 핵심 + 3 메타)

> 초기 참고자료의 구상과 활용 과정은 [적용 기록](../../prompt-engineering/README.md)을 따른다. 이 문서의 과거 하네스 구성과 명령은 당시 기록이며 최신 사용자 지시 없이 자동 실행하지 않는다.

```
.claude/agents/
│  # ── 7 핵심 기능 (도메인 작업) ──
├── grimoire-planner.md              ← 기획 + §0 게이트 트리거 (opus)
├── grimoire-researcher.md           ← 경쟁사 + AI 가격 모니터링 (opus)
├── grimoire-cost-accountant.md      ← §0 원가 수호자 (opus, Grimoire 고유)
├── grimoire-visual-canon-keeper.md  ← 사슴악마 정본 수호자 (opus, Grimoire 고유)
├── grimoire-qa.md                   ← 전수검사 (opus)
├── grimoire-server.md               ← NestJS + Prisma + pgvector (opus)
├── grimoire-web.md                  ← Next.js + Tailwind 4 (opus)
│  # ── 3 메타·인프라 (시스템 자체) ──
├── grimoire-infrastructure.md       ← Azure/Cloud Run 배포·secret·cron (2026-05-08 신설)
├── grimoire-harness.md              ← 하네스 메타 영역 .claude/* 전담 (2026-05-09 신설)
└── grimoire-verifier.md             ← 읽기전용 독립 검증 (2026-05-29 신설)
```

## 역할 분담

### 7 핵심 기능 (도메인 작업)

| 에이전트 | 도구 | 담당 |
|---------|------|------|
| **planner** | Read/Write/Edit/Glob/Grep | 기획 Draft, §0 원가 게이트 트리거, 시각 정본 검수 요청 |
| **researcher** | +WebSearch/WebFetch | 경쟁사(네이버 시리즈/카카오페이지/문피아/Wattpad/AO3/한줄) + **Claude/OpenAI 가격 매일 모니터링** + RAG 학술 |
| **cost-accountant** | +Bash | §0 전용 — ai-cost-table.md 단독 관리, 마진 ≥3배 검증, 가격 변동 시 재산정, 월간 원가 vs 매출 |
| **visual-canon-keeper** | +Bash | 사슴악마 정본 수호 — 새 UI·테마·포맷 출력 검수, 디자이너 역할 겸직 (SVG 제안) |
| **qa** | +Bash | server + web 테스트·빌드·타입·시각 정본·§0 원가·보안 게이트 |
| **server** | +Bash | NestJS 헥사고날, Prisma, pgvector, 인증, 결제, 테마 생성 UseCase |
| **web** | +Bash | Next.js FSD, Tailwind 4, 사슴악마 정본 준수, BFF 프록시 |

### 3 메타·인프라 (시스템 자체)

| 에이전트 | 도구 | 담당 |
|---------|------|------|
| **infrastructure** (2026-05-08 신설) | Read/Bash | Azure/Cloud Run 배포·secret·cron. 수동 배포 1차(`make deploy-{env}`), GitHub Actions 자동배포 차단. INFRA-1 자동배포 사고 후속 신설 |
| **harness** (2026-05-09 신설) | Read/Write/Edit/Bash | 하네스 메타 영역 `.claude/*` 전담 — sensor/hook/skill/agent 정의/settings.json/state/knowledge. PP-7 라우팅 매트릭스 ↔ agent 정의 불일치(메타 영역 책임 누락) 정정 신설 |
| **verifier** (2026-05-29 신설) | Read/Bash/Glob/Grep | 읽기전용 독립 검증 (작업 주체 ↔ 검증 주체 분리). Edit/Write/commit 없음 — 거짓 PASS 검출 전담. 정직성 사태 후속 신설 |

## 작업 플로우

```
사용자: "기능 X 만들어"
  ↓
researcher (필요 시) → reports/SWEEP_REPORT.md + Live 캐시 + (가격 변동 시) reports/COST_ALERT.md
  ↓
planner → 기획 Draft + reports/PLANNER_REPORT.md
  ↓
[AI 기능]       → cost-accountant 승인 → reports/COST_AUDIT_REPORT.md
[시각 영향]     → visual-canon-keeper 검수 → reports/VISUAL_CANON_REPORT.md
  ↓
server / web 병렬 구현 → reports/DEV_REPORT.md
  ↓
qa 전수검사 → reports/QA_REPORT.md → 배포 게이트 판정
```

## 리서치 자료 계층 (Canonical vs Live)

| 계층 | 예시 | 저장 위치 | 정책 |
|---|---|---|---|
| Canonical | RAG 논문, 임베딩 이론, 시맨틱 캐싱 | `research/*.md` (기존) | 사용자 승인 |
| Live 경쟁사 | 네이버 시리즈/카카오페이지/문피아/Wattpad/AO3/한줄 | `research/RESEARCH_COMPETITIVE_LANDSCAPE.md` | 매일 스윕 |
| Live AI 가격 | Claude Sonnet/Haiku/Opus, GPT-4o/5, Gemini, 임베딩 | `reports/AI_COST_MONITOR.md` | **매일 스윕 필수 — 가격 변동 즉시 cost-accountant 알림** |
| Ephemeral | 일회성 특정 논문 | 저장 안 함 | — |

## 각 에이전트의 필수 참조 문서

공통:
- `root CLAUDE.md` (§0 수칙, §1 시각 정본, §5 문서 피라미드, §14 에이전트 — §14는 2026-04-16 추가)
- `PLANNING_GRIMOIRE.md` (§0 크레딧-원가 철칙 — ※ 원가 철칙은 PLANNING의 §0이지 CLAUDE.md §0이 아님. CLAUDE.md §0은 ZERO-TOLERANCE PROTOCOL)
- `SYNC_STATUS.md`

특수 (7 핵심):
- planner: PLANNING + research/FEATURE_AI_ANALYSIS.md + research/FUNDING_*
- researcher: research/* + 두 Live 캐시 + AI 제공자 공식 가격 페이지
- cost-accountant: PLANNING §0 + ai-cost-table.md (grimoire-server/docs/) + reports/AI_COST_MONITOR.md
- visual-canon-keeper: grimoire-web/src/app/[author]/* (동적 라우트, deerdevil은 런타임 파라미터) + DESIGN.md + docs/design-tokens.md + docs/theme-spec.md
- qa: TESTING.md + TECH_STATUS.md + cost-accountant/visual-canon-keeper 리포트
- server: grimoire-server/CLAUDE.md + 모든 docs/*
- web: grimoire-web/CLAUDE.md + DESIGN.md + SCREENS.md + 디자인 토큰 + 사슴악마 소스

특수 (3 메타):
- infrastructure: docs/INFRASTRUCTURE.md + docs/DEPLOY.md + Makefile + docs/environments.md + memory/feedback_manual_deploy_primary.md
- harness: research/HARNESS_ENGINEERING.md (§14 인벤토리 정본) + .claude/AGENTS.md + .claude/shared-contracts.md + 본 agent-system.md
- verifier: `.claude/skills/verifier-protocol/SKILL.md` + 검증 대상 작업의 산출물 (commit diff / sensor raw / 리포트)

## 스케줄 (매일, 18:00~23:30 KST)

```
18:04 researcher          (daily discovery + sweep + AI 가격 모니터링)
19:08 cost-accountant     (원가 감사)
20:11 planner             (기획 draft)
21:14 visual-canon-keeper (정본 diff 감사)
22:17 server + web (병렬)
23:21 qa                  (전수검사)
```

※ Zenith 06~11, RoadRage 12~17 과 시간대 안 겹침.

## §0 원가 철칙 자동 검증 구조

1. **researcher**가 매일 Claude/OpenAI 공식 가격 페이지 확인 → `reports/AI_COST_MONITOR.md` 갱신
2. 가격 변동 감지 시 `reports/COST_ALERT.md` 생성 (이벤트 발생 시에만 동적 생성 — 평상시 미존재) → cost-accountant 즉시 알림
3. **cost-accountant**가 `COST_AUDIT_REPORT.md` 에서 ai-cost-table.md 전체 마진 재계산
4. 마진 <50% 하락 기능 검출 시 사용자 에스컬레이션
5. **qa**가 배포 전 `COST_AUDIT_REPORT.md` CRITICAL 체크 → FAIL 시 배포 차단

## 사슴악마 시각 정본 자동 검증 구조

1. **visual-canon-keeper**가 매일 deerdevil 라우트 + 모든 작가 공간 순회
2. 정본 대조 (구조/타이포/색상/애니메이션/레이아웃)
3. BUG 발견 시 `VISUAL_CANON_REPORT.md` CRITICAL 항목
4. **qa**가 배포 전 BUG 체크 → FAIL 시 배포 차단

## 작가 콘텐츠 보호 (전 에이전트 공통)

- 작가가 업로드한 소설 본문은 **수정·인용·로깅 금지**
- 테스트/리포트에 본문 유출 감지 시 qa가 차단
- DB 조회 결과도 본문 필드는 로깅 제외

## ACCOUNTS.md 참조 금지 (전체 공통)

모든 에이전트가 ACCOUNTS.md 를 절대 참조 안 함. Polar/PAYAPP 시크릿 키 등 포함 가능성.

## 세션 재시작 전 임시 우회

```
Agent(subagent_type="general-purpose",
      prompt="당신은 grimoire-cost-accountant 에이전트입니다.
              /Users/sokol/Git/ProjectGrimoire/.claude/agents/grimoire-cost-accountant.md
              를 먼저 읽고 §0 크레딧-원가 철칙 전용 수호자 역할을 숙지한 후...")
```

## 변경 이력

- 2026-05-30 (harness): 7 에이전트 → **10 에이전트 (7 핵심 + 3 메타)** 전면 정합. 3 메타·인프라(infrastructure 2026-05-08 / harness 2026-05-09 / verifier 2026-05-29) 항목 추가 — frontmatter·도입부·파일 위치 트리·역할 분담 표(7+3 분리)·필수 참조 문서. 핸드오프 매트릭스(agent-interaction-matrix.md)는 도메인 흐름 정본인 7 핵심 기준 유지 명시. 실측 기준(`research/HARNESS_ENGINEERING.md` §14.1 Agents 10개 표).
