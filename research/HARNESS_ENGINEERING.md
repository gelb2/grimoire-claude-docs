# Harness Engineering — 리서치 노트

> **작성일**: 2026-04-19 (v1), 2026-04-25 (v2 대폭 확장)
> **발단**: 사용자가 Martin Fowler 원문 + Reddit /r/ClaudeAI 스레드 공유 → ProjectGrimoire harness 수준 점검 지시. v2에서 Skills 개념 + 커뮤니티 3대 레포 분석 + Agent 전수검사 + dev 적용 로드맵 + 루트 workspace git 관리 방법 추가.
> **상태**: 리서치 정리 완료. TODO.md "Claude Code harness 강화" 섹션과 1:1 연동.

---

## 1. Harness Engineering 정의 (Martin Fowler)

Fowler의 2026년 정의: **"Everything in an AI agent except the model itself"**. 모델을 감싸 **가이드(feedforward)**와 **센서(feedback)**로 에이전트 행동을 **조종(steer)**하고 **규제(regulate)**하는 사용자 구축 시스템.

핵심 시각: 모델 품질만으로는 코딩 에이전트의 실수를 막을 수 없으므로 **주변을 조이는 엔지니어링**이 필요하다.

## 2. 핵심 구성요소 (4축)

| 축 | 설명 | ProjectGrimoire 예시 |
|---|---|---|
| **Guides (Feedforward)** | 에이전트가 행동하기 **전에** 방향을 제시 — 프롬프트, 스킬, 규칙 문서, 정본 문서, 템플릿 | CLAUDE.md §0 절대 규정, PLANNING_GRIMOIRE.md, docs/*.md 정본, .claude/prompts/*.txt |
| **Sensors (Feedback)** | 에이전트가 행동한 **후에** 이상 신호를 LLM이 소비할 수 있는 형태로 리턴 | .claude/scripts/sensor-*.sh (docs-sync, security-gate, server, web), pre-push 훅, 테스트 실행 |
| **Computational** | 결정적·빠름·저비용 CPU 도구 (린터, 타입체크, 테스트) | tsc, vitest, jest, eslint, docs 동기화 검증 스크립트 |
| **Inferential** | 의미 기반·느림·비용 GPU 도구 (LLM as judge, review agent) | 서브에이전트 7종 (planner/researcher/cost-accountant/visual-canon-keeper/qa/server/web) |

## 3. 핵심 원리

| 원리 | 요약 | 적용 시사점 |
|---|---|---|
| **Shift Left** | "Keep quality left" — 비용이 낮은 단계에서 최대한 막는다 | Edit 직후 tsc auto > pre-push > CI > 프로덕션 배포 전 preflight |
| **Steering Loop** | 반복 문제 발견 시 harness를 진화시킨다 (에이전트에게 직접 harness를 만들게 할 수도) | 2026-04-19 세션 실수 → TODO에 harness 보강 항목 박제한 것이 이 루프 예시 |
| **Requisite Variety (Ashby)** | 규제자는 규제 대상만큼의 variety를 가져야 한다 | 엔드포인트/파서/테마 조합의 복잡성만큼 sensor가 늘어나야 함 |
| **Harnessability** | 일부 코드베이스는 본질적으로 harness 친화적 (정적 타입, 명확한 경계) | TypeScript strict + Hexagonal + FSD 아키텍처는 ProjectGrimoire의 큰 자산 |
| **Ambient Affordances** | 구조적 환경이 에이전트에 "legible, navigable, tractable"하도록 | 정본 문서 피라미드, 문서 동기화 규칙, 명확한 라우트 구조 |

## 4. 경계해야 할 실패 모드 (Fowler 정리)

| 실패 모드 | 설명 | ProjectGrimoire에서 관찰된 사례 |
|---|---|---|
| **Feedback-only harness** | 규칙 없이 검증만 하면 같은 실수를 무한 반복 | 이번 세션의 "매번 허용 누르세요" TCC 헛소리 — Skill/Guide 부재 |
| **Feedforward-only harness** | 규칙만 많고 실행 결과 검증 없음 | CLAUDE.md §0 경고는 있으나 검증 sensor가 "메모리 freshness" 4개뿐 |
| **Over-reliance on AI-generated tests** | LLM이 만든 테스트는 아직 신뢰도 부족 | 서브에이전트 리포트(researcher/qa)를 그대로 정답으로 받지 말 것 |
| **Silent sensors** | 센서가 한 번도 울리지 않으면 품질이 좋은 건지 감지 안 되는 건지 모호 | sensor-*.sh가 실제로 실패 케이스를 잡아본 이력 추적 필요 |
| **Harness drift** | 가이드와 센서가 시스템 성장에 따라 서로 모순 | CLAUDE.md §14 "미도입" 표기 vs 실제 sensors/knowledge 도입된 상태. AUTOMATION.md도 실존하지만 §14에 "미도입" |

## 5. Guides vs Sensors — Fowler 도식

```
      ┌──────────────────┐
      │     사용자        │
      └────┬─────────┬───┘
           │         │
  ┌────────▼────┐ ┌──▼──────────┐
  │   Guides    │ │   Sensors   │
  │ (feedforward│ │ (feedback)  │
  └────────┬────┘ └──┬──────────┘
           │         │
      ┌────▼─────────▼────┐
      │   Coding Agent    │
      │    (LLM Model)    │
      └───────┬───────────┘
              ▼
         코드 산출물
```

- Guides는 **비용 낮고 선제적** (프롬프트 토큰, 정본 문서 참조)
- Sensors는 **비용 분산** — 빠른 것(tsc)은 Edit 직후, 비싼 것(E2E)은 pre-push 또는 배포 전

## 6. Skills 개념 — Agent와 무엇이 다른가 (v2 신설)

### 6.1 공식 정의

Claude Code의 **Skill**은 `.claude/skills/<skill-name>/SKILL.md` 규약으로 정의되는 **상황 조건부 프로토콜 번들**이다:

```markdown
---
name: skill-name
description: 이 skill이 언제 발동되어야 하는지 (Claude가 trigger 판단)
allowed-tools: Read, Edit, Bash   # 선택
---

# Skill 본문 (Markdown)
구체적 절차, 체크리스트, 참조 파일 경로 등.
```

### 6.2 Agent vs Skill 비교

| 축 | Agent (`.claude/agents/*.md`) | Skill (`.claude/skills/<name>/SKILL.md`) |
|---|---|---|
| **실행 컨텍스트** | 별도 context window (Task 도구 호출 시) | **메인 세션 내** 로드 (Skill tool invoke) |
| **호출 방식** | 명시 호출 (`subagent_type: "grimoire-qa"`) 또는 자동 루팅 | Claude가 description 매칭으로 **자동 판단** 후 invoke |
| **대화 상태** | 독립 대화 — 메인 세션과 분리 | 동일 컨텍스트 — 대화 이어짐 |
| **적합한 용도** | 장시간 작업, 코드 생성, 깊은 리서치 | 재사용 프로토콜, 체크리스트, "이 상황에서 이렇게 하라" |
| **비용** | 별도 context 토큰 | 메인 세션 토큰만 |
| **연쇄 호출** | subagent → subagent 가능 | Skill은 agent 내에서도 호출 가능 |

### 6.3 언제 Agent 쓰고 언제 Skill 쓰는가

**Agent 적합**
- 서버 개발 전담 (grimoire-server)
- 경쟁사 리서치 반나절 작업 (grimoire-researcher)
- 독립 검증 (grimoire-qa)
- 별도 컨텍스트가 필요한 대규모 작업

**Skill 적합**
- "TCC 다이얼로그가 뜨면 osxkeychain으로" 같은 **증상 → 대응 매핑**
- "AI 분석 UI에 '자동 환불' 문구를 추가할 때는 서버 catch 블록 확인" 같은 **게이트 체크**
- "Chrome extension이 not connected면 3회 재시도" 같은 **리커버리 프로토콜**
- Agent 내부에서도 공통으로 쓰는 "verification-before-completion" 같은 **메타 규칙**

### 6.4 ProjectGrimoire에 도입 권장 Skills

P0~P1 구현 후보:

1. **`macos-tcc-handling`** — Docker credsStore desktop → osxkeychain 전환 프로토콜. `memory/feedback_docker_credstore.md`를 승격.
2. **`production-bug-triage`** — curl 실측 → 코드 추적 → 추정 금지. `feedback_fullcheck_method.md` 승격.
3. **`claude-in-chrome-recovery`** — extension 미연결 시 3회 재시도 + 지연 navigate 대응.
4. **`db-sync-safety`** — `--mask-pii` 회귀 방지. dev에 로그인 스모크 테스트 없이 마스킹 변경 금지.
5. **`deploy-precheck`** — preflight 호출 전 양쪽 레포 git 상태/브랜치 정합성.
6. **`refund-logic-audit`** — UI에 "자동 환불" 문구 추가 시 서버 catch 블록 존재 증거 요구.
7. **`grimoire-visual-canon-check`** — 새 컴포넌트 렌더 후 사슴악마 정본(`/deerdevil/`) 대비 diff 요구.
8. **`verification-before-completion`** (superpowers에서 차용) — "완료" 선언 전 tsc + test + 실측 증거 3종 묶음 강제.

### 6.5 Skill 도입이 Harness에서 차지하는 위치

```
 Guides 축(feedforward)
  ├── CLAUDE.md §0~§14 (전체 규칙)
  ├── .claude/prompts/*.txt (에이전트별 프롬프트)
  ├── .claude/skills/*/SKILL.md    ← v2 신설 제안 (상황별 프로토콜)
  ├── docs/*.md (도메인 정본)
  └── memory/feedback_*.md (재발 방지 노트)
```

즉 **Skill = Guides 축의 중간 계층**. 매 세션 프롬프트에 다 넣기엔 많고, agent로 분리하기엔 짧은 프로토콜을 담는다.

---

## 7. 커뮤니티 3대 레포 심층 분석 (v2 신설)

### 7.1 [obra/superpowers](https://github.com/obra/superpowers) — 167k stars, MIT

**정체성**: "A complete software development methodology for your coding agents." TDD + systematic debugging + collaboration 프로토콜 번들.

**제공 Skills**

| 범주 | Skill | 역할 |
|---|---|---|
| Testing | `test-driven-development` | RED-GREEN-REFACTOR 사이클 + 안티패턴 레퍼런스 |
| Debugging | `systematic-debugging` | 4단계 root cause 분석 |
| Debugging | `verification-before-completion` | "완료" 선언 전 검증 강제 |
| Collaboration | `brainstorming` | Socratic 설계 refinement + validation 체크포인트 |
| Collaboration | `writing-plans` | 작업을 **2~5분 단위**로 분할 |
| Collaboration | `executing-plans` | batch 실행 + human 체크포인트 |
| Collaboration | `dispatching-parallel-agents` | 서브에이전트 병렬 발사 패턴 |
| Collaboration | `requesting-code-review` / `receiving-code-review` | 리뷰 pre/post |
| Collaboration | `using-git-worktrees` | 격리 워크스페이스 branch 관리 |
| Collaboration | `finishing-a-development-branch` | merge/PR 결정 워크플로우 |
| Collaboration | `subagent-driven-development` | 2-stage review (spec → quality) |
| Meta | `writing-skills` | 새 skill 작성 best practices |

**설치**:
```bash
# Claude Code 공식 marketplace
/plugin install superpowers@claude-plugins-official
# 또는
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

**ProjectGrimoire 차용 후보**:
- `verification-before-completion` → **P0 필수**. 이번 세션 "분석 끝났는데 fetch aborted는 확인 안 함" 유형 차단
- `writing-plans` → planner 에이전트 프롬프트에 "2~5분 단위 분할" 규칙 주입
- `dispatching-parallel-agents` → 멀티 subagent 병렬 호출 패턴 문서화
- `using-git-worktrees` → 이번 세션의 Edit 집중 모드 대신 worktree 분리 실험

**라이선스 주의**: MIT지만 패키지 그대로 install 시 167k의 범용 규칙이 ProjectGrimoire 도메인 규칙과 충돌 가능. **선별적 이식 권장**.

### 7.2 [Yeachan-Heo/oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) — 31.1k stars, MIT (한국 개발자)

**정체성**: "Teams-first Multi-agent orchestration for Claude Code." "Don't learn Claude Code. Just use OMC."

**핵심 구성**

| 축 | 내용 |
|---|---|
| Agents | **19개** 특화 에이전트 (architecture/research/design/testing/data science) |
| Pipeline | plan → prd → exec → verify → fix 표준 스테이지 |
| Slash commands | `/team`, `/autopilot`, `/ralph`, `/ultrawork`, `/deep-interview` |
| Skills | `.omc/skills/` 재사용 패턴 저장소 |
| Provider advisors | `/ask codex`, `/ask gemini` 교차 검증 |
| HUD | 실시간 orchestration 메트릭 statusline |
| Rate limit daemon | 제한 후 auto-resume |

**설치**:
```bash
/plugin marketplace add https://github.com/Yeachan-Heo/oh-my-claudecode
/plugin install oh-my-claudecode
/setup
# 또는
npm i -g oh-my-claude-sisyphus@latest
omc setup
```

**settings.json**:
```json
{
  "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" },
  "omcHud": { "preset": "focused" }
}
```

**핵심 기능**
- **Auto-skill injection**: description 매칭되는 skill 자동 로드
- **Smart model routing**: Haiku = 단순 / Opus = 복잡 추론 (30~50% 토큰 절감 주장)
- **Verify/Fix loops (Ralph mode)**: 검증 완료까지 자동 반복
- **Session replay**: `.omc/state/agent-replay-*.jsonl`로 재구성 가능
- **Stop callbacks**: Telegram/Discord/Slack 알림

**ProjectGrimoire 차용 후보**:
- **모델 티어링** (`Haiku = FAQ / Opus = 복잡`) → TODO의 "모델 티어링" 과제 직결. `ai-cost-table.md` + `cost-accountant` 에이전트와 결합
- **HUD statusline** → `/statusline` 설정으로 배포 브랜치·크레딧·테스트 상태 표시 실험
- **Rate limit daemon** → 현재 없음. 매일 자율 에이전트 실행 시 유용
- **Stop callbacks** → Slack 알림 연동 (사용자 사전 승인 필요)
- **`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`** → 기존 서브에이전트 구조와 호환성 테스트 필요

**경고**: 19개 agent를 일괄 install하면 ProjectGrimoire의 7개 도메인 agent와 중복/충돌. **선별 이식 권장**.

### 7.3 [Q00/ouroboros](https://github.com/Q00/ouroboros) — 2.7k stars, MIT

**정체성**: "Specification-first workflow engine for AI coding agents." "Stop prompting. Start specifying."

**핵심 워크플로우** (`ooo <cmd>`):

| Command | 역할 |
|---|---|
| `ooo interview` | Socratic 질문으로 가정 노출 |
| `ooo seed` | 인터뷰에서 spec 결정화 |
| `ooo run` | Double Diamond 분해 실행 |
| `ooo evaluate` | 3-stage 검증 게이트 |
| `ooo evolve` | ontology 수렴까지 반복 |
| `ooo unstuck` | 5개 lateral thinking persona |
| `ooo ralph` | 검증 완료까지 persistent loop |
| `ooo pm` / `qa` / `publish` / `brownfield` / `tutorial` / `status` / `cancel` | 상태 제어 |

**핵심 개념**

- **Ambiguity Score**: 1 − weighted clarity. 임계값 ≤ 0.2 아래로 떨어질 때만 코딩 진입. Weights = Goal 40% / Constraint 30% / Success 30% (brownfield 시 Context 15% 추가)
- **Ouroboros Loop**: Interview → Seed → Execute → Evaluate → Evolve → (다음 generation의 seed로 피드백)
- **Ontology Convergence**: 연속 generation 간 schema similarity ≥ 0.95 시 종료
- **Double Diamond**: Diverge(질문)→Converge(ontology), Diverge(설계)→Converge(전달)
- **PAL Router**: 3-tier cost (Frugal 1× / Standard 10× / Frontier 30×) auto-escalation
- **Stagnation Detection**: spinning / oscillation / no-drift / diminishing returns 탐지, 30 generation 안전 cap

**설치**:
```bash
curl -fsSL https://raw.githubusercontent.com/Q00/ouroboros/main/scripts/install.sh | bash
# 또는
pip install ouroboros-ai[all]
ouroboros setup
# Claude Code plugin
claude plugin marketplace add Q00/ouroboros
```

**ProjectGrimoire 차용 후보**:
- **Ambiguity Score** → PLANNING_GRIMOIRE.md 기획 신규 항목 추가 시 "Goal/Constraint/Success 각 명확도 ≥ 80%" 게이트 도입
- **PAL Router** → 모델 티어링과 결합. 단순 파서 호출은 Haiku, 테마 생성은 Sonnet, RAG 분석은 Opus
- **HANDOFF.md 프로토콜** → 이번 세션의 `HANDOVER.md`와 일치. Ouroboros의 프로토콜 참조하여 세련화
- **Stagnation Detection** → 자율 에이전트 무한 루프 방지 안전장치
- **Event sourcing 체크포인트** → 장시간 작업 중 중단/복구 가능 (현재는 launchd plist 로그만)

**경고**: Python 기반이라 Node.js 전용 ProjectGrimoire와 스택 별도. CLI 차원에서만 사용. 주요 아이디어는 차용하되 의존은 피함.

### 7.4 3개 레포 비교 요약

| 축 | superpowers | oh-my-claudecode | ouroboros |
|---|---|---|---|
| 규모 | 167k ⭐ | 31.1k ⭐ | 2.7k ⭐ |
| 철학 | TDD + systematic | Teams-first | Spec-first |
| 언어 | (설정 파일 중심) | TypeScript | Python |
| 설치 | Claude plugin | plugin / npm | pip / plugin |
| 강점 | Skills 라이브러리 | 멀티 agent orchestration | Ambiguity 정량화 |
| 약점 | 과도한 번들 | 19 agent 중복 위험 | Python 스택 분리 |
| ProjectGrimoire 적용도 | 높음 (skills 직접 이식) | 중간 (모델 라우팅 개념) | 중간 (기획 단계 보강) |

---

## 8. Agent/Skill 외에 확인해야 할 Harness 요소 (v2 심층연구)

### 8.1 Hook 전체 목록 (Claude Code 기준)

| Hook | 발동 시점 | ProjectGrimoire 활용도 |
|---|---|---|
| `SessionStart` | 세션 시작 | ✅ 도입 (memory-freshness 체크) |
| `Stop` | Claude 응답 종료 | ✅ 도입 (memory-guard) |
| `UserPromptSubmit` | 사용자 프롬프트 수신 | ✅ 도입 (memory-check) |
| `PreCompact` | 컨텍스트 압축 전 | ✅ 도입 (memory-guard) |
| `PreToolUse` | 도구 실행 전 | ❌ **미도입** — 위험 명령 차단 가능 |
| `PostToolUse` | 도구 실행 후 | ❌ **미도입** — Edit → tsc auto 가능 |
| `Notification` | 알림 이벤트 | ❌ 미도입 |
| `SubagentStop` | 서브에이전트 종료 | ❌ 미도입 — 에이전트 리포트 후 자동 집계 가능 |

**가장 효과 큰 추가 후보**:
- `PostToolUse` matcher: `Edit|Write` AND 파일 확장자 `.ts` → `cd $(git rev-parse --show-toplevel) && npx tsc --noEmit`
- `PreToolUse` matcher: `Bash` AND 명령에 `git push origin main` 포함 → 사용자 확인 요구
- `SubagentStop`: 서브에이전트가 `reports/*.md` 생성하면 Slack/Telegram 알림 또는 CHANGELOG에 추가

### 8.2 Slash Commands (`.claude/commands/*.md`)

정의:
```markdown
---
description: 커맨드 설명
argument-hint: [선택적 인자 설명]
---

# 커맨드 본문 (프롬프트)
$ARGUMENTS 변수로 사용자 입력 받기
```

**ProjectGrimoire 도입 후보**:
- `/fullcheck` — tsc + test + build + docs 동기화를 양쪽 레포에서 실행
- `/dev-login-smoke` — db-sync 회귀 감지 (deerdevil 실계정 로그인 시도)
- `/deploy-precheck [env]` — preflight 수동 호출
- `/rollback-guide [env] [sha]` — 롤백 스크립트 자동 생성
- `/visual-canon-diff` — 현재 구현 vs 사슴악마 정본 시각 대조
- `/credit-audit` — DB CreditLog vs Polar webhook 정합성 스캔
- `/handover-refresh` — HANDOVER.md 자동 갱신

### 8.3 Permissions (`settings.local.json`)

현재:
```json
{
  "permissions": {
    "allow": [
      "mcp__Claude_Preview__preview_start",
      "WebFetch(domain:grimoire-book.com)",
      "Bash(cat)",
      "Bash(chmod +x /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/deploy-prod.sh)"
    ]
  }
}
```

- Bash의 특정 명령만 auto-approve 가능 (`Bash(git status)`, `Bash(npm test)`)
- 위험 명령(`rm -rf`, `git reset --hard`)은 `deny`로 차단 가능
- ProjectGrimoire 추가 후보: `Bash(git status)`, `Bash(git diff*)`, `Bash(npm test*)`, `Bash(npx tsc --noEmit)` 등 반복 명령 auto-approve

### 8.4 Output Styles (`.claude/output-styles/*.md`)

- 응답 스타일 템플릿 (개발자용 / 경영진용 / 리뷰용 등)
- ProjectGrimoire에서는 **미탐색 영역**. 현재 필요도 낮음

### 8.5 Statusline (`.claude/statusline.sh`)

- 터미널 하단에 실시간 정보 표시
- 후보: 현재 브랜치 / 마지막 테스트 결과 / 배포 상태 / 크레딧 카운터

### 8.6 MCP Servers (`.mcp.json`)

현재 사용 중인 MCP (실측):
- `Claude_Preview` (preview-*)
- `Claude_in_Chrome` (navigate/find/computer 등)
- `mcp-registry` / `pencil` / `ccd_session` / `scheduled-tasks` 등 사용자 환경 MCP

ProjectGrimoire 전용 MCP 후보:
- **Polar credit query MCP** — 구독자 크레딧 실시간 조회
- **Azure Container App status MCP** — `az containerapp` 호출 래퍼
- **Grimoire DB admin MCP** — dev 방화벽 열고 쿼리 (위험성 높음, 권한 엄격)

### 8.7 Plugins (marketplace)

Claude Code 2026-04 릴리스에서 plugin marketplace 본격화:
- `obra/superpowers`, `Yeachan-Heo/oh-my-claudecode`, `Q00/ouroboros` 등 install 가능
- 한 레포 install 시 agents/skills/commands 일괄 주입

### 8.8 Knowledge (`.claude/knowledge/*.md`)

현재 도입된 3종:
- `README.md` / `agent-system.md` / `sensors.md`

세션 중 정적 참조. Claude가 필요 시 Read로 로드. TODO:
- `sensors-hit-rate.md` — 각 sensor가 실제로 실패를 잡은 이력 집계 (silent sensor 방지)
- `agent-interaction-matrix.md` — 7개 서브에이전트 간 핸드오프 규칙

### 8.9 Memory (`~/.claude/projects/.../memory/`)

CLAUDE.md §12 절대 규칙으로 박제. 현재:
- 세션 기록 (`project_session_*.md`)
- 피드백 (`feedback_*.md`)
- 현재 상태 (`project_state*.md`)
- 인덱스 (`MEMORY.md`)

v2 추가 제안:
- **Session-to-skill 승격 자동화**: `feedback_*.md`가 3회 이상 참조되면 skill로 승격 트리거

### 8.10 Environment & Worktree

- `$CLAUDE_PROJECT_DIR` 환경변수 활용 가능
- `git worktree` 격리 (superpowers의 skill)
- ProjectGrimoire: Edit 폭주 시 메인 브랜치 오염 방지용 worktree 활용 가치

---

## 9. ProjectGrimoire Agent 전수검사 (2026-04-25 실측) (v2 신설)

### 9.1 에이전트 7개 정합성

```
.claude/agents/
├── grimoire-cost-accountant.md ✅
├── grimoire-planner.md ✅
├── grimoire-qa.md ✅
├── grimoire-researcher.md ✅
├── grimoire-server.md ✅
├── grimoire-visual-canon-keeper.md ✅
└── grimoire-web.md ✅
```

각 파일 frontmatter 실측 결과: `name`, `description`, `tools` 필드 전부 정상 정의. 에이전트 spawn은 가능 상태.

### 9.2 Agent 동작 가능성 — 실측 기반 판정

| 항목 | 상태 | 비고 |
|---|---|---|
| Task 도구로 `subagent_type` 호출 가능 | ✅ | 2026-04-19 세션에서 Explore agent 실제 발사 성공 이력 |
| 7개 에이전트 정의 파일 유효 | ✅ | frontmatter 문법 정상 |
| 자율 실행 (launchd plist) | ❌ **비활성** | `~/Library/LaunchAgents/com.grimoire*.plist` 없음. CLAUDE.md §14에 "launchd 18:00~23:30 KST" 박제됐지만 **실측은 plist 없음 — 문서 drift** |
| `.claude/prompts/*.txt` vs `.claude/agents/*.md` | ⚠️ **불일치** | prompts는 6개 (cost-accountant/developers/planner/qa/researcher/visual-canon-keeper). agents는 7개 (grimoire-server + grimoire-web 분리). prompts엔 developers.txt로 묶임 |
| launchd 로그 보존 | ✅ | `.launchd-logs/` 디렉토리 존재 (이전 실행 흔적) |
| `reports/` 디렉토리 | ✅ | 자율 실행 리포트 저장 경로 유지 |

### 9.3 실수/드리프트 발견

1. **launchd plist 부재**: CLAUDE.md §14가 실제와 다름. 자율 실행 **현재 안 됨**. 다만 Task 도구로의 수동 호출은 정상.
2. **prompts vs agents 개수 불일치**: developers.txt 하나를 grimoire-server + grimoire-web이 공유. 도메인 분리 관점에서 **prompt도 2개로 분리 권장**.
3. **CLAUDE.md §14 "미도입" 오표기**: sensors, knowledge, AUTOMATION.md가 "미도입"으로 적혀있지만 실제 파일 존재 → 문서 현행화 TODO 필수.

### 9.4 Agent 개선 로드맵

- **P0 (즉시)**: CLAUDE.md §14 실측 반영
- **P0 (즉시)**: `.claude/prompts/`를 `server.txt` / `web.txt`로 분리 또는 agents/*.md 내부에 프롬프트 흡수
- **P1 (단기)**: launchd 재활성 필요성 재검토. 자율 실행 없이 on-demand 호출만으로 운영 가능한지 판단
- **P2 (중기)**: 에이전트 간 핸드오프 명시 (planner → researcher → cost-accountant → server+web → qa)

---

## 10. Dev 환경 적용 로드맵 (v2 신설)

### Phase 0 — 이번 세션 완료 항목

- ✅ HARNESS_ENGINEERING.md v2 작성
- ✅ Agent 전수검사
- ✅ 3대 레포 분석
- ✅ Skills 개념 정리

### Phase 1 — 1~2일 (P0) — **완료 (2026-04-25)**

**목표**: Edit 직후 강제 검증 축 확보 + 재발 방지 skill 3종

- [x] `grimoire-web/.githooks/pre-push` 이식 — 실제로는 2026-04-17에 이미 이식 완료 상태 (422 bytes, 4단계 tsc/test/build/docs). 2026-04-25 검증 PASS.
- [x] 루트 `.claude/settings.json`에 `PostToolUse` hook 추가 (matcher=Edit|Write, timeout=60)
  ```json
  "PostToolUse": [{
    "matcher": "Edit|Write",
    "hooks": [{
      "type": "command",
      "command": "bash /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/post-edit-tsc.sh",
      "timeout": 60
    }]
  }]
  ```
  `post-edit-tsc.sh`는 stdin JSON + 인자 fallback 양쪽 지원. `.ts/.tsx/.cts/.mts` 화이트리스트, 그 외는 조용히 exit 0. 파일 경로 기반으로 grimoire-server/ 또는 grimoire-web/ 판별 → `npx tsc --noEmit` 실행 → 실패 시 stderr 20줄만 출력, Claude 흐름은 차단하지 않음.
- [x] `.claude/skills/` 디렉토리 신설 + 3 skill (2026-04-25)
  - `.claude/skills/macos-tcc-handling/SKILL.md` — credsStore=desktop → osxkeychain 강제. "매번 허용" 답변 금지
  - `.claude/skills/production-bug-triage/SKILL.md` — curl → 코드 경로 → 수치 근거 3단계 Chain-of-Verification
  - `.claude/skills/claude-in-chrome-recovery/SKILL.md` — 최소 3회 재시도 + javascript_tool URL 확인 + 새 탭 우회

**독립 검증**: grimoire-qa 서브에이전트 5/5 PASS (`grimoire-server/PROGRESS_HARNESS_P0.md` 참조).

### Phase 2 — 3~5일 (P1) — **부분 완료 (2026-04-25 세션 #2)**

**목표**: Slash commands + dev-login-smoke + db-sync 예외 옵션

이번 세션 #2에서 Hook 중심 변주로 다음을 먼저 완료:

- [x] **UserPromptSubmit `skill-injector.sh`** — Skill frontmatter `triggers:` 키워드 매칭 → `hookSpecificOutput.additionalContext`로 자동 주입. oh-my-claudecode 패턴 차용. 세션 내 중복 주입 방지
- [x] **PreToolUse `pretouluse-bash-guard.sh` (matcher=Bash)** — `git push origin main` / `git reset --hard` / `rm -rf /` 등 destructive 명령 exit 2 차단. `SKIP_INTERACTIVE=1 make deploy-prod`는 경고만
- [x] **Skill 3종 `triggers:` frontmatter 추가** — 36개 키워드 (macos-tcc 11 / bug-triage 16 / chrome 9)
- [x] **Agent 7개 ouroboros 방식 Skill 참조** — 각 에이전트 `.md` 하단에 "Skills 프로토콜 참조" 섹션 + SKILL.md 경로 (Claude Code 공식 스펙상 서브에이전트는 Skill 자동 발동 불가. 프롬프트에 경로 박아서 Read로 로드하게 함)
- [x] **루트 workspace PRIVATE repo 박제** — `gelb2/grimoire-claude-docs` 생성. CLAUDE.md·PLANNING·`.claude/`·prompt-engineering·research·seed-data 전부 버전 관리. ACCOUNTS.md / settings.local.json / 서브 레포 2개는 `.gitignore`로 제외

미수행 (Phase 2 잔여):

- [ ] `.claude/commands/dev-login-smoke.md` — deerdevil 실계정 로그인 시도 후 401 또는 "signal timed out" 감지 시 경고
- [ ] `.claude/commands/deploy-precheck.md` — preflight 수동 호출 + git 브랜치 정합성
- [ ] `.claude/commands/refund-logic-audit.md` — UI 문구 "자동 환불" 추가 시 서버 catch 블록 grep 강제
- [ ] `grimoire-server/scripts/db-sync.ts`에 `--preserve-accounts` 옵션 추가 — 예외 목록의 email/password는 마스킹 스킵
- [ ] `grimoire-web/src/app/login/page.tsx` 테스트 계정 하드코딩 교체

### Phase 3 — 1주 (P2) — **부분 완료 (2026-04-25)**

**목표**: 모델 티어링 + CLAUDE.md 현행화 + HANDOVER 자동화

- [x] **PreToolUse hook — main 직접 push 차단** (세션 #2 Phase 2와 중복, 위 `pretouluse-bash-guard.sh` 참조)
- [x] **CLAUDE.md §14 "미도입" 목록 실측 반영** (2026-04-25 drift 해소 작업에서 처리)
- [ ] oh-my-claudecode 참조 — Haiku/Sonnet/Opus 티어링 정책. `ai-cost-table.md` 마진 재검증 (cost-accountant 필수)
- [ ] `.claude/commands/handover-refresh.md` — git log + TODO + 배포 상태 자동 수집해 HANDOVER.md 갱신
- [ ] superpowers `verification-before-completion` skill 이식 (MIT — 선별 복사 가능)
- [ ] superpowers `writing-plans` 2~5분 단위 분할 규칙 grimoire-planner 에이전트에 이식

### Phase 4 — 2~4주 (P3)

**목표**: 고급 harness + 외부 통합

- [ ] `.mcp.json` — Polar 크레딧 조회 MCP 정의 및 실증
- [ ] Azure Container App 상태 MCP (`az containerapp logs/show` 래퍼)
- [ ] Ouroboros Ambiguity Score 개념 차용 — 기획 단계 게이트
- [x] PreToolUse hook — main 직접 push 차단 ✅ (세션 #2에서 선제 완료)
- [ ] Sensor hit-rate 메트릭 (`.claude/scripts/sensor-*.sh` 실행 결과를 집계)
- [ ] Claude SDK / OpenAI SDK signal 전파 (서버 abort 시 실제 API 호출도 cancel)
- [ ] launchd 재활성 여부 결정 — **"비활성 유지" 결정 (2026-04-25)**: plist 부재 + 매일 토큰 비용 + cost-accountant 마진 검증 미연동. 재활성 보류
- [ ] AUTOMATION.md 현행화

### Phase 5 — 장기 실험

- [ ] Worktree 기반 병렬 작업 (superpowers `using-git-worktrees`)
- [ ] Stop callback Slack/Telegram 알림 (사용자 승인 후)
- [ ] oh-my-claudecode Ralph mode 검토
- [ ] skills 간 상호 참조 그래프 분석

---

## 11. 루트 workspace Git 관리 방법 (v2 신설)

### 11.1 현재 구조 (실측)

```
/Users/sokol/Desktop/Git/ProjectGrimoire/          ← git 아님
├── .DS_Store
├── .claude/                    ← 에이전트·프롬프트·센서·hook 설정
├── .idea/                      ← IntelliJ (로컬)
├── .launchd-logs/              ← 자율 실행 로그
├── .obsidian/                  ← Obsidian (로컬)
├── ACCOUNTS.md
├── AUTOMATION.md
├── CLAUDE.md                   ← 루트 규칙 정본
├── DOC_MAP.html
├── PLANNING_GRIMOIRE.md        ← 최상위 기획 정본
├── SYNC_STATUS.md
├── agents → .claude/agents     ← symlink
├── grimoire-server/            ← 독립 git 레포
├── grimoire-web/               ← 독립 git 레포
├── node_modules/
├── package-lock.json
├── package.json
├── prisma/
├── prompt-engineering/         ← GMP v2.2, 바이브코딩 가이드 등 정본
├── reports/                    ← 자율 에이전트 리포트
├── research/                   ← 이 문서 포함
└── seed-data/
```

**문제**: 루트의 CLAUDE.md·PLANNING_GRIMOIRE.md·prompt-engineering·research·.claude 등 핵심 자산이 **버전 관리 안 됨**. 사용자 수동 백업 의존.

### 11.2 옵션 비교

#### 옵션 A: 루트 git init + 서브 레포 gitignore (**추천**)

```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire
git init -b main
cat > .gitignore <<'EOF'
# 서브 레포 (독립 git으로 관리 중)
grimoire-server/
grimoire-web/

# 빌드 산출물
node_modules/
.launchd-logs/

# 로컬 IDE
.idea/
.obsidian/
.DS_Store

# Claude Code 사용자별
.claude/settings.local.json

# 기타
무제.base
EOF

git add .
git commit -m "chore: 루트 workspace 초기 커밋 (CLAUDE.md·PLANNING_GRIMOIRE·.claude·docs·research)"
gh repo create gelb2/grimoire-workspace --private --source=. --remote=origin --push
```

**장점**
- 기존 server/web 독립성 유지
- 루트 자산(약 10~15MB) 별도 PRIVATE repo로 보호
- GitHub Actions로 self-dogfooding 가능 (프로젝트 상태 요약 봇 등)

**단점**
- 3개 레포 관리 부담 (server/web/workspace)
- 3개 레포 간 동기화는 여전히 사람이 책임

**이번 프로젝트에 권장 이유**: `.claude/`의 agent/prompt/sensor 설정이 사용자 머리 밖으로 벗어나면 재구성 불가. 이걸 PRIVATE git에 박제가 안전장치.

#### 옵션 B: Git Submodule

루트에 init 후 `grimoire-server`/`grimoire-web`을 submodule로 pinning.

**장점**: 3개 레포 연결성 명시
**단점**: 
- Submodule 관리 복잡. 매번 commit hash 추적
- 사용자가 `git submodule update --recursive` 잊으면 stale
- Claude Code가 submodule 내부 변경 추적 어려움

**비추천**.

#### 옵션 C: Monorepo 전환 (pnpm workspaces / turborepo / nx)

`package.json` workspace로 grimoire-server + grimoire-web을 monorepo 편입.

**장점**: 최신 스택. 코드 공유 가능
**단점**:
- 기존 CI/CD, 배포 스크립트, Docker build, GitHub Actions 모두 재구성
- 회귀 리스크 큼
- ProjectGrimoire는 이미 상당한 인프라 투자 완료 상태 — ROI 낮음

**장기 검토는 가치 있음. 지금 실행은 비추천**.

#### 옵션 D: 루트 자산을 grimoire-server에 이식

루트의 `CLAUDE.md`·`PLANNING_GRIMOIRE.md`·`.claude/` 등을 `grimoire-server/workspace/`로 이동.

**장점**: 기존 1 git에 편입, 단순
**단점**:
- 루트 기반 launchd plist, 에이전트 bash 스크립트의 절대경로 대거 수정 필요
- "루트 workspace" 개념 상실
- server 레포가 grimoire-web까지 규정하는 형태가 되어 대칭성 깨짐

**비추천**.

#### 옵션 E: Dotfiles-style 별도 레포 (symlink)

사용자 `~/dotfiles-grimoire` 레포에 파일 저장, 루트로 symlink.

**장점**: 기존 구조 불변
**단점**:
- symlink 관리 복잡 (특히 `.claude/agents/` 같은 중첩)
- Windows 환경 이전 시 문제
- 사용자 혼란 증가

**비추천**.

### 11.3 옵션 A 실행 절차 (제안 — 사용자 승인 필요)

```bash
# 1) 루트 진입
cd /Users/sokol/Desktop/Git/ProjectGrimoire

# 2) 기존 서브 repo 건드리지 않는지 확인
ls -la grimoire-server/.git grimoire-web/.git  # 존재 확인

# 3) git init (메인 브랜치 main)
git init -b main

# 4) .gitignore 작성 (위 §11.2 옵션 A 내용)
cat > .gitignore <<'EOF'
grimoire-server/
grimoire-web/
node_modules/
.launchd-logs/
.idea/
.obsidian/
.DS_Store
.claude/settings.local.json
무제.base
memory/          # ~/.claude/ 로 관리되는 메모리는 별도
reports/         # 자율 에이전트 로그는 재생성 가능
EOF

# 5) 최초 커밋
git add .
git status  # 확인 — grimoire-server/, grimoire-web/ 제외됐는지
git commit -m "chore: ProjectGrimoire workspace 초기 커밋"

# 6) GitHub PRIVATE repo 생성 + push
gh repo create gelb2/grimoire-workspace --private --source=. --remote=origin --push

# 7) 브랜치 전략 확정 (단순: main 직접 작업)
#    루트는 빈번한 변경이 아니므로 develop 분리 불필요
```

### 11.4 운영 원칙 (옵션 A 채택 시)

- **커밋 빈도**: CLAUDE.md / PLANNING_GRIMOIRE.md / `.claude/` 변경 시 즉시
- **서브 레포와의 경계**: 루트 workspace는 **규칙·기획·harness**만, 서브는 **코드**만
- **핸드오프**: HANDOVER.md는 `grimoire-server/`에 유지 (현재 구조) — 다음 세션이 server pull만으로 읽을 수 있으므로
- **민감 정보**: 루트에 `ACCOUNTS.md`가 있음 — 내용 확인 후 반드시 `.gitignore`에 추가하거나 마스킹 후 커밋

### 11.5 사전 경고

- `memory/` 디렉토리는 실제로 `~/.claude/projects/.../memory/`에 위치 (루트 아님). 워크스페이스에 편입하려면 symlink 또는 별도 설계
- `.launchd-logs/` 커밋 시 용량 폭주 — `.gitignore` 필수
- `reports/` 자율 에이전트 생성물은 많은 용량 — `.gitignore` 또는 최근 N개만 보존
- `ACCOUNTS.md`에 계정 정보 있으면 PRIVATE여도 커밋 전 내용 검수

---

## 12. ProjectGrimoire 종합 대조 (v2 업데이트)

### ✅ 이미 도입된 Harness 축

| 도입 요소 | 위치 | 축 분류 |
|---|---|---|
| Sub-agents 7개 | `.claude/agents/*.md` | Inferential |
| Sensors 4개 (docs-sync, security-gate, server, web 빌드) | `.claude/scripts/sensor-*.sh` | Computational/Sensor |
| Memory hooks 4종 (SessionStart, Stop, UserPromptSubmit, PreCompact) | `.claude/settings.json` | Guide 재로딩 유도 |
| pre-push hook (server만) | `grimoire-server/.githooks/pre-push` | Sensor (tsc+test+build+docs) |
| 정본 문서 피라미드 | CLAUDE.md §5 | Guide |
| 문서 동기화 규칙 | CLAUDE.md §3 | Guide |
| Knowledge 3종 | `.claude/knowledge/*.md` | Guide (정적 참조) |
| Memory 시스템 (feedback/session) | `~/.claude/projects/.../memory/` | Guide (재발 방지) |

### ❌ 빠진 Harness 축 (v2 확정)

| 빠진 요소 | 영향 | 우선순위 |
|---|---|---|
| **PostToolUse hook** | Edit 직후 tsc 자동 실행 없음 — Shift-Left 최대치 미활용 | P0 |
| **PreToolUse hook** | main 직접 push / 위험 명령 차단 없음 | P3 |
| **Skills** (`.claude/skills/`) | 재발 방지 프로토콜 강제 참조 불가 | P0 |
| **Slash commands** (`.claude/commands/`) | 반복 검증 자동화 없음 | P1 |
| **grimoire-web pre-push** | 서버만 있고 웹 없음 | P0 |
| **MCP servers** (`.mcp.json`) | 도메인 특화 MCP 부재 | P3 |
| **Statusline** | 실시간 상태 시각화 없음 | P3 |
| **모델 티어링** | Haiku/Opus 라우팅 없음 | P2 |
| **launchd plist (자율 실행)** | 비활성 상태. 수동 Task 호출만 가능 | 판단 필요 |
| **CLAUDE.md §14 drift** | 문서와 실측 불일치 | P1 |
| **HANDOVER.md 자동 갱신** | 수동 작성 | P2 |
| **루트 workspace git** | 버전관리 없음 | 사용자 승인 대기 |

### 2026-04-19 세션 실수 × Fowler 프레임 매핑 (유지)

이번 세션에서 실제로 발생한 실수를 Fowler의 프레임으로 분류:

| 실수 | Fowler 분류 | 부재했던 harness | v2 해결안 |
|---|---|---|---|
| TCC "매번 허용 누르세요" 헛소리 | Guide 부재 + Silent sensor | Skill `macos-tcc-handling` + credsStore 사전 검증 script | **Skill P0** |
| fetch aborted 원인을 추측으로 설명 | Guide 부재 (추정 금지 규칙이 CLAUDE.md §0에 있지만 센서화 안 됨) | Skill `production-bug-triage` | **Skill P0** |
| 환불 UI 문구 거짓말 | Feedforward-only 실패 (문구 추가 시 서버 근거 검증 없음) | PostToolUse hook + Slash command `/refund-logic-audit` | **Hook + Command P0~P1** |
| Chrome extension 조기 포기 | Silent sensor (재시도 규정 없음) | Skill `claude-in-chrome-recovery` | **Skill P0** |
| db-sync --mask-pii 회귀 미감지 | Sensor 부재 (dev 로그인 스모크 테스트 없음) | Slash command `/dev-login-smoke` + db-sync `--preserve-accounts` | **Command P1** |

---

## 13. 출처 (v2 확장)

### 이론 정본
- [Martin Fowler — "Harness Engineering for Coding Agents"](https://martinfowler.com/articles/harness-engineering.html)
- Reddit `/r/ClaudeAI` — "I had Claude read every harness engineering guide..." ([fetch 제한, URL](https://www.reddit.com/r/ClaudeAI/comments/1s9jm0d/i_had_claude_read_every_harness_engineering_guide/))

### 공식 문서
- [Claude Code Skills 공식 문서](https://code.claude.com/docs/en/skills)

### 커뮤니티 3대 레포 (v2 심층 분석 포함)
- [GitHub — obra/superpowers](https://github.com/obra/superpowers) — 167k ⭐, MIT, TDD+systematic methodology
- [GitHub — Yeachan-Heo/oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) — 31.1k ⭐, MIT, Teams-first multi-agent
- [GitHub — Q00/ouroboros](https://github.com/Q00/ouroboros) — 2.7k ⭐, MIT, Spec-first workflow engine

### 부가 참고
- [GitHub — Chachamaru127/claude-code-harness](https://github.com/Chachamaru127/claude-code-harness) — Go guardrail engine
- [GitHub — hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) — 큐레이트 목록
- [Paradime — Claude Code Skills & Harness Engineering](https://www.paradime.io/guides/claude-code-skills-plugins-rules-guide)
- [Medium — David R Oliver "Skills and Hooks Starter Kit" (2026-02)](https://medium.com/@davidroliver/skills-and-hooks-starter-kit-for-claude-code-c867af2ace32)
- [Medium — Jiten Oswal "Ultimate Claude Code CLI Deep Dive" (2026-04)](https://medium.com/@jiten.p.oswal/the-ultimate-claude-code-cli-deep-dive-guide-to-the-newest-commands-from-april-2026-release-1eeb25b03c52)
- [Medium — Ewan Mak "Everything Claude Code: 82K-Star Agent Harness" (2026-03)](https://medium.com/@tentenco/everything-claude-code-inside-the-82k-star-agent-harness-thats-dividing-the-developer-community-4fe54feccbc1)

---

## 14. ProjectGrimoire 멀티 에이전트·Skills·Hooks 구성 인벤토리 (2026-04-25 이동)

> **이동 사유**: 루트 `CLAUDE.md` §14에 있던 본문(약 80줄)을 패턴 3(SSOT + CLAUDE.md 좁게) 채택에 따라 본 research 문서로 이동. CLAUDE.md §14는 이 §14를 가리키는 1줄 pointer로 슬림화. CLAUDE.md 19.6KB → 약 16KB로 축소.

### 14.1 Agents 7개 (`.claude/agents/*.md`)

| 에이전트 | 역할 | 도구 |
|---------|------|------|
| planner | 기획 Draft + 원가 게이트 트리거 | Read/Write/Edit/Glob/Grep |
| researcher | 경쟁사 모니터링 + AI 가격 추적 | +WebSearch/WebFetch |
| cost-accountant | PLANNING §0 크레딧-원가 마진 ≥3배 검증 (Grimoire 고유) | +Bash |
| visual-canon-keeper | 사슴악마 시각 정본 수호 + 디자이너 겸직 (Grimoire 고유) | +Bash |
| qa | 전수검사 + 배포 게이트 판정 | +Bash |
| server | NestJS 백엔드 개발 | +Bash |
| web | Next.js 프론트엔드 개발 | +Bash |

각 에이전트 `.md` 하단에 "Skills 프로토콜 참조" 섹션으로 `.claude/skills/*/SKILL.md` 경로 embed (ouroboros 방식 — 공식 스펙상 서브에이전트는 Skill 자동 발동 불가).

### 14.2 Skills 10종 (`.claude/skills/<name>/SKILL.md`)

| Skill | 트리거 / 호출 | 용도 |
|---|---|---|
| macos-tcc-handling | UserPromptSubmit 자동 매칭 (11 키워드) | Docker credsStore=desktop → osxkeychain |
| production-bug-triage | UserPromptSubmit 자동 매칭 (16 키워드) | curl → 코드 → 수치 3단계 Chain-of-Verification |
| claude-in-chrome-recovery | UserPromptSubmit 자동 매칭 (9 키워드) | Chrome MCP 3회 재시도 + javascript_tool URL 확인 |
| verification-before-completion | UserPromptSubmit 자동 매칭 (17 키워드) | Gate 1·2·3 (코드/기능/회귀) 실측 증거 강제 |
| refund-logic-audit (2026-04-25 #7 마이그레이션) | 사용자 명시 호출 `/refund-logic-audit` (`disable-model-invocation: true`) | UI 환불 문구 ↔ 서버 catch 정합성 |
| dev-login-smoke (2026-04-25 #7 마이그레이션) | 사용자 명시 호출 `/dev-login-smoke` (동일) | db-sync 회귀 감지 + dev preflight |
| deploy-precheck (2026-04-25 #7 마이그레이션) | 사용자 명시 호출 `/deploy-precheck` (동일) | 수동 배포 직전 7-step 게이트 |
| writing-plans (2026-04-25 #8 신설, superpowers MIT 차용) | UserPromptSubmit 자동 매칭 (10 키워드: "계획 짜", "분할", "단계별로" 등) | 큰 작업(≥30분) 분할 메타 절차 (sub-task 2~5분 단위) |
| handover-refresh (2026-04-25 #8 신설) | 사용자 명시 호출 `/handover-refresh [dry-run\|apply]` | grimoire-server/HANDOVER.md 자동 수집 갱신 (git log + memory + sensor + 배포 + TODO) |
| **gc-sweep** (2026-04-26 #9 신설) | 사용자 명시 호출 `/gc-sweep [dry-run\|stage\|apply]` | Fowler GC 축 1.5/5 → 3+/5 갭 해소. 7 카테고리(skills/sensors/hooks/memory/scripts/agents/prompts) 미참조·stale 자산 식별 |

### 14.3 Hooks 8 이벤트 10 스크립트 (`.claude/settings.json`)

| Hook | matcher | 스크립트 | 용도 |
|---|---|---|---|
| SessionStart | - | check-memory-freshness.sh | 메모리 freshness 체크 |
| Stop | - | stop-memory-guard.sh | 응답 종료 시 메모리 강제 기록 |
| UserPromptSubmit | - | user-prompt-memory-check.sh | 메모리 참조 가드 |
| UserPromptSubmit | - | skill-injector.sh | Skill triggers 키워드 매칭 → 자동 주입 |
| PreCompact | - | pre-compact-memory-guard.sh | 컨텍스트 압축 전 메모리 보호 |
| **InstructionsLoaded** (2026-04-25 #7 신설) | session_start | instructions-drift-check.sh | CLAUDE.md 로드 시 research §14 표기 vs 실측 drift 자동 감지 (audit only) |
| PreToolUse | Bash | pretouluse-bash-guard.sh | `git push origin main` / `rm -rf /` / `git reset --hard` 차단 |
| PostToolUse | Edit\|Write | post-edit-tsc.sh | `.ts/.tsx/.cts/.mts` 편집 후 해당 레포 `tsc --noEmit` 자동 |
| PostToolUse | Edit\|Write | post-edit-spec-check.sh | spec/test 누락 감지 (usecase/lib/adapter/features 화이트리스트) |
| **PostToolBatch** (2026-04-25 #7 신설) | - (전체) | post-batch-tsc.sh | parallel batch 완료 후 server+web tsc 일괄 (debounce 60s, 빌드 중복 60% ↓ 목표) |

### 14.4 Sensors 9개 (`.claude/scripts/sensor-*.sh`)

| Sensor | 용도 |
|---|---|
| sensor-docs-sync.sh | server ↔ web docs 9종 해시 일치 검증 |
| sensor-security-gate.sh | 보안 9 항목 (인증/권한/레이트리밋 + §9 secret-leak) |
| sensor-server.sh | server 빌드/테스트 게이트 |
| sensor-web.sh | web 빌드/테스트 게이트 |
| sensor-secret-leak.sh | git tracked 파일 평문 시크릿 탐지 (라이브 prefix + 약한 default) |
| sensor-log.sh | sensor 실행 결과 jsonl 적재 (7일 LRU TTL) |
| sensor-hit-rate-report.sh | 주간 sensor별 PASS/WARN/FAIL 집계 + silent sensor 식별 |
| **sensor-orchestration-ratio.sh (2026-04-26 #9 P2 완성)** | **패턴 1 KPI: jsonl(`~/.claude/projects/.../*.jsonl`) Python 파싱. 메인 Edit/Write vs Task tool 호출 비율 + sidechain 분리 + subagent 타입 분포. 임계값: ≥0.20 PASS / 0.05~0.20 WARN / <0.05 FAIL. **2026-04-26 첫 P2 실측: 696 main vs 0 task = 0.0000 (FAIL — 패턴 1 도입했지만 실제 적용 0%)** |
| sensor-credit-atomicity.sh (2026-04-25 #8 신설, Requisite Variety 갭) | 결제·환불·CreditLog 원자성 정합 검사 (4 항목: $transaction / audit trail / 환불 분기 / webhook secret 하드코딩) |

### 14.5 Knowledge 4개 (`.claude/knowledge/`)
- README.md · agent-system.md · sensors.md · **agent-interaction-matrix.md (2026-04-26 #9 신설 — 7×7 핸드오프 매트릭스 + 산출물 정합 + 트리거 규칙 + 금지 조합)**

### 14.6 Slash commands 0개 (`.claude/commands/*.md` 폐기)

> **2026-04-25 세션 #7**: Anthropic 공식 권장 ("Custom commands have been merged into skills")에 따라 3개 commands를 §14.2 Skills 10종 중 (`refund-logic-audit` / `dev-login-smoke` / `deploy-precheck`)로 마이그레이션 + `disable-model-invocation: true` 부착. 사용자 명시 호출 (`/skill-name`)만 허용. commands 디렉토리는 비어있으나 보존.

### 14.6.1 Prompts 7개 (`.claude/prompts/*.txt` — 2026-04-26 #9 server/web 분리)

| 에이전트 | prompts 파일 |
|---|---|
| planner | planner.txt |
| researcher | researcher.txt |
| cost-accountant | cost-accountant.txt |
| visual-canon-keeper | visual-canon-keeper.txt |
| **server** (2026-04-26 신설) | **server.txt** ← 이전 developers.txt를 분리 |
| **web** (2026-04-26 신설) | **web.txt** ← 이전 developers.txt를 분리 |
| qa | qa.txt |

매핑·호출 예시: `.claude/prompts/README.md` 참조. `developers.txt`는 server.txt + web.txt로 분리되어 제거됨 (§9.4 P0 해소).

### 14.7 자율 실행 현황 (2026-04-25 결정)

launchd plist 비활성 상태. 2026-04-19 세션 + 세션 #5에서 "비활성 유지" 결정. 사유:
- plist 부재 (실측: `~/Library/LaunchAgents/com.grimoire.*.plist` 없음)
- 매일 토큰 비용 발생
- cost-accountant 마진 검증 미연동

현재 에이전트는 **on-demand Task tool 호출**로만 사용. 단 Fowler memo의 "Garbage Collection" 축이 비어있는 갭 (성숙도 진단 1.5/5).

원래 계획했던 스케줄(참조용):
```
18:04 researcher / 19:08 cost-accountant / 20:11 planner /
21:14 visual-canon-keeper / 22:17 server+web / 23:21 qa
```

### 14.8 핵심 제약 (Grimoire 고유)
1. **PLANNING §0 원가 철칙**: 새 AI 기능은 cost-accountant 마진 ≥3배 검증 없이 기획 진행 불가
2. **사슴악마 시각 정본**: 새 UI/테마/포맷 출력은 visual-canon-keeper 정본 검수 없이 구현 불가
3. **작가 콘텐츠 보호**: 소설 본문 수정·인용·로깅 전 에이전트 공통 금지

### 14.9 Zenith 대비 차이
- copywriter 없음 (작가 본인 콘텐츠, 시스템 텍스트 적음)
- designer 역할은 visual-canon-keeper 겸직
- iOS 에이전트 없음 (웹 전용 플랫폼)
- cost-accountant는 Grimoire 고유 (Zenith에 없음)

### 14.10 미도입·보류 결정 항목 (실측 확정, 2026-04-25)
- `TASK_QUEUE.json` — 태스크 큐 파일 (미도입)
- launchd 자율 실행 — **비활성 유지** (위 §14.7)
- `.mcp.json` 도메인 특화 MCP — Phase 4 P3, DB 권한 위험으로 보류
- `/handover-refresh` slash — Phase 3 P2 후보
- 모델 티어링 (Haiku/Sonnet/Opus) — cost-accountant 사전 시뮬 필수

---

## 15. 현장 운영 4 패턴 (2026-04-25 신설)

> **사유**: 외부 팀(다른 회사 사람) 인터뷰에서 도출된 4 패턴이 Fowler 정본 문서에 직접 명시되지 않은 "현장 결정 지점"임을 확인. 외부 자료 (Anthropic 공식 / HumanLayer / sshh.io / Builder.io / PrestaShop / AddyOsmani)로 검증한 결과 4 패턴 모두 실재. ProjectGrimoire가 이 4축에서 어디에 위치하는지 명시 + 향후 진화 방향 결정 근거.

### 15.1 패턴 1 — 오케스트레이션 분리

**정의**: 메인 Claude(채팅 세션) = 지시·조율만. 실제 코드 작성은 서브에이전트/팀에이전트가 수행. 메인의 컨텍스트 보호 + 격리 + 병렬.

**Anthropic 입장**: 권장 (단 agent teams는 experimental, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 필요).

**대표 사례**:
- Anthropic 공식 "Orchestrate teams of Claude Code sessions" — lead session = "coordinating work, assigning tasks, synthesizing results", teammates = "work independently in own context window"
- AddyOsmani "Code Agent Orchestra" — "central AI thread coordinates specialist agents - it doesn't write code itself"
- HumanLayer "subagent-driven-development" — 2-stage review (spec → quality)

**장단점**:
- ✅ 컨텍스트 격리 + 병렬화
- ❌ 토큰 비용 선형 증가 + 조율 오버헤드. 실패 모드: lead가 직접 구현해버림 ("Wait for your teammates to complete")

### 15.2 패턴 2 — CLAUDE.md = 도메인/인프라/문서 허브

**정의**: CLAUDE.md를 모든 정보의 **진입점(허브)**로. 도메인 지식 + 인프라 + 외부 문서 링크를 한 파일에 모음.

**Anthropic 입장**: 중립~약권장 (best-practices가 CLAUDE.md 자체는 권장하나 크기 한도는 명시 안 함).

**대표 사례**:
- Builder.io / DataCamp — "agent's constitution, primary source of truth", 13~25KB까지 정당화
- shanraisshan/claude-code-best-practice 레포

### 15.3 패턴 3 — 루트 기획서 = SSOT, CLAUDE.md = 좁게 (코드 컨벤션·팀 규약만)

**정의**: 진실의 근원은 별도 기획 문서. CLAUDE.md는 좁게 (컨벤션·규약만).

**Anthropic 입장**: 중립.

**대표 사례 + 임계값 근거**:
- HumanLayer "Writing a good CLAUDE.md": "official recommendation under 200 lines, some teams under 60"
- **sshh.io** (결정적): "instruction-following degrades at 150-200 total instructions" — 시스템 프롬프트가 ~50 슬롯 차지 → 가용 100~150 슬롯
- PrestaShop Issue #41152: `CONTEXT.md` = AI-agnostic SSOT, `CLAUDE.md` = pointer

**장단점**:
- ✅ Attention 보존 + instruction-following 유지
- ❌ 도메인 컨텍스트 분산 → 신규 세션 진입 비용 ↑

### 15.4 패턴 4 — Skill / Sub-agent / Team-agent 취향껏

**정의**: 표준 정답 없음 — 팀 선호대로.

**Anthropic 입장**: 분기 기준 제공, 강제는 안 함.
- "rules that apply to nearly every task → CLAUDE.md, specific workflows that only matter sometimes → Skill"
- "Use subagents when... quick focused workers report back. Use agent teams when... share findings, challenge each other"

**대표 사례**: Anthropic Skills 공식 블로그 + Level Up Coding "Mental Model" + AntStack Field Guide.

### 15.5 4 패턴 양립성

**패턴 2 vs 3은 직접 모순**. 결정적 데이터: sshh.io의 "150-200 instruction degradation". CLAUDE.md를 허브로 키우면 instruction-following 자체가 깨진다 → 패턴 2를 무한 확장하는 팀은 임계값 도달 시 **자동으로 패턴 3으로 강제 수렴**.

**패턴 1·4는 패턴 2·3 어느 쪽과도 양립 가능**.

**패턴 1 + 패턴 3 조합은 시너지**: 메인이 코드 작성 안 하면 두꺼운 도메인 컨텍스트가 메인에 들어갈 필요 없음 (subagent에게만 필요) → 패턴 1로 갈수록 CLAUDE.md 슬림화가 자연스러움.

### 15.6 출처
- [Anthropic Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [Skills explained](https://claude.com/blog/skills-explained)
- [HumanLayer — Writing a good CLAUDE.md](https://www.humanlayer.dev/blog/writing-a-good-claude-md)
- [sshh.io — How I Use Every Claude Code Feature](https://blog.sshh.io/p/how-i-use-every-claude-code-feature)
- [Builder.io — How to Write a Good CLAUDE.md](https://www.builder.io/blog/claude-md-guide)
- [PrestaShop #41152 — CONTEXT.md SSOT](https://github.com/PrestaShop/PrestaShop/issues/41152)
- [AddyOsmani — Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/)

---

## 16. ProjectGrimoire 4 패턴 위치 + 진화 결정 (2026-04-25)

### 16.1 채택 결정 — 패턴 1 + 패턴 3 동시 진행

사용자 결정 (2026-04-25, 세션 #6): **패턴 1 (오케스트레이션 분리) + 패턴 3 (CLAUDE.md 슬림화) 동시 진행**.

근거:
- 패턴 1·3 조합 시너지 (§15.5)
- CLAUDE.md (19.6KB) + PLANNING (61KB) 합계 ~80KB → instruction degradation 임계값 근접
- §14 Multi-Agent 구조 본문(80줄)이 일상 작업 무관 메타 정보 → 본 research §14.X로 이동 적합

### 16.2 즉시 실행 항목 (세션 #6)

1. **§14 본문 이동**: CLAUDE.md §14 약 80줄 → 본 문서 §14 (위)로 이동
2. **CLAUDE.md §14 슬림화**: 1줄 pointer + 메인 Claude 조율 강화 규칙 1줄
3. **목표 사이즈**: CLAUDE.md ~16KB (현 19.6KB에서 약 18% 축소)

### 16.3 패턴 1 강화 규칙 (CLAUDE.md에 추가)

> 메인 Claude(채팅 세션)는 가능하면 지시·조율만 한다. 실제 코드 작성·테스트·빌드는 server/web subagent에게 위임한다. 단 다음 경우는 메인이 직접 진행:
> - 문서·메모리·`.claude/` 설정 변경 (조율 자체)
> - 단순 grep/실측·sanity 명령 (Bash 1~3개 수준)
> - 사용자가 "직접 해" 명시 지시
> - subagent 호출 비용이 작업 크기 대비 비효율적 (15초 미만 작업)

### 16.4 향후 진화 (P1~P3)

- **P1 (1주)**: 메인 Claude의 코드 직접 작성 빈도 측정 → `sensor-orchestration-ratio.sh` 신설 검토
- **P2 (1개월)**: §13 참고 프로젝트, §15 프롬프트 엔지니어링 정본 등도 별도 파일로 분리 검토 (CLAUDE.md ~12KB 목표)
- **P3 (3개월)**: agent teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) experimental 도입 — cost-accountant 마진 시뮬 선행 필수

### 16.5 KPI

다음 세션부터 sensor-hit-rate-report에 신규 metric 추가 검토:
- `orchestration_ratio` = (subagent 호출 횟수) / (메인 Claude 직접 Bash·Edit 횟수)
- 목표: 패턴 1 강화에 따라 점진 상승

### 16.6 사용자 직접 결정 보류 항목 (이번 세션 미수행)
- agent teams experimental 도입 (cost 영향)
- launchd 자율 실행 부활 (GC 축 1.5/5 갭 해소용)
- 모델 티어링 (subagent 별 model:)

