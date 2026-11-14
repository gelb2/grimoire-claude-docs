# AGENTS.md — `.claude/` 하네스 레이어

> 초기 참고자료의 구상과 활용 과정은 [적용 기록](../prompt-engineering/README.md)을 따른다. 이 문서의 과거 하네스 구성과 명령은 당시 기록이며 최신 사용자 지시 없이 자동 실행하지 않는다.

> 워크스페이스 루트 `CLAUDE.md` §15 (Prompt Engineering 정본) 준수 + Martin Fowler 4 기둥(Constrain·Inform·Verify·Correct) 적용.
> 본 파일은 멀티 에이전트 오케스트레이션 + 세션 메모리 + Skills/Hooks 정본을 정의한다.
> **참조 정본**: `research/HARNESS_ENGINEERING.md` (상세 인벤토리 + 패턴 결정 근거).

---

## 1. 세션 종료 시 메모리 기록 — 절대 규칙

> 모든 세션(로컬/리모트/웹) 종료 전에 반드시 아래를 수행한다. 예외 없음.

### 메모리 디렉토리 위치 (절대 경로)

메모리 파일들의 **실제 저장 위치**는 루트 workspace가 아닌 사용자 홈의 Claude Code 프로젝트 디렉토리:

```
/Users/sokol/.claude/projects/-Users-sokol-Git-ProjectGrimoire/memory/
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

## 2. 멀티 에이전트 · Skills · Hooks 구조 (요약 + 정본 pointer)

> **본 §2의 본문은 2026-04-25 세션 #6에서 패턴 3(SSOT + CLAUDE.md 좁게) 채택에 따라 `research/HARNESS_ENGINEERING.md` §14로 이동했습니다.** 상세 인벤토리(Agents 10 = 7 핵심 + 3 메타 / Skills 26현역 + 9 archive / Hooks 10이벤트 / Sensors 57 / Knowledge 9 / launchd 비활성 결정 / Zenith 대비 차이 / 미도입 보류 항목)는 그쪽을 참조 — 수치는 §3 인벤토리 검증 명령으로 실측.

### 2.1 핵심 제약 (Grimoire 고유 — 매 세션 강제)
1. **PLANNING §0 원가 철칙**: 새 AI 기능은 cost-accountant 마진 ≥3배 검증 없이 기획 진행 불가
2. **사슴악마 시각 정본**: 새 UI/테마/포맷 출력은 visual-canon-keeper 정본 검수 없이 구현 불가
3. **작가 콘텐츠 보호**: 소설 본문 수정·인용·로깅 전 에이전트 공통 금지

### 2.2 메인 Claude 오케스트레이션 규칙 (2026-04-25 세션 #6 신설, 패턴 1 강화)

> 메인 Claude(채팅 세션)는 **가능하면 지시·조율만** 한다. 실제 코드 작성·테스트·빌드는 server/web subagent에게 위임한다.

다음 경우는 메인이 직접 진행:
- 문서·메모리·`.claude/` 설정 변경 (조율 자체)
- 단순 grep/실측·sanity 명령 (Bash 1~3개 수준)
- 사용자가 "직접 해" 명시 지시
- subagent 호출 비용이 작업 크기 대비 비효율적 (15초 미만 작업)

근거: `research/HARNESS_FIELD_PATTERNS_4.md` §15.1 (패턴 1 — 오케스트레이션 분리) + §15.5 (패턴 1+3 시너지) + `research/HARNESS_ENGINEERING.md` §16 (ProjectGrimoire 채택 결정).

### 2.2.1 작업 시작 시 자가 분류 의무 (2026-05-02 묶음 J K1 신설)

새 작업/묶음 시작 전 메인 Claude는 다음 1단계를 강제 수행:

1. **`.claude/skills/orchestration-decision/SKILL.md`의 매트릭스에 따라 자가 분류**
2. **결정 박제** (사용자 보고 또는 메모리): `메인 직접 vs subagent 위임 → grimoire-{name}` + 매트릭스 행 근거
3. **반례 박제**: 매트릭스 권장과 다른 결정을 한 경우 사유 함께 박제

박제 누적은 sensor-orchestration-ratio jsonl + 메모리 양 채널. 패턴 1 KPI 0.0 → 양수 진입을 위한 필수 인프라.

본 의무는 §15.7.4 "다음 세션부터 적용 규칙" 첫 항목의 자율 운영판.

### 2.2.2 5 오케스트레이션 패턴 박제 (2026-05-02 BN-#10 신설, 책 Ch 16 + 부록 B)

새 작업이 단일 패턴으로 안 풀릴 때 5 패턴 중 선택. **단순한 패턴부터 — 측정 후에만 복잡도 증가** (책 Ch 16 강조):

| 패턴 | 에이전트 수 | 비용 | 적합 |
|------|-----------|-----|------|
| 1. **싱글** (기준선) | 1 | 낮음 | 단일 기능, 버그 수정 |
| 2. **서브에이전트** (계층) | 2~5 | 중간 | 탐색+구현 — 부모 Opus + 자식 Sonnet (우리 10 에이전트 = 이 패턴, 7 핵심 도메인 흐름이 대표) |
| 3. **멀티** (병렬) | 2~N | 높음 | 대규모 마이그레이션 — Git 워크트리 필수 (worktree-isolation skill은 현재 `.claude/skills/_archive/` — 미사용, 필요 시 복원) |
| 4. **Plan-and-Execute** | 2~3 | 중간 | 장기 실행 — Sprint 계약 (Initializer/Generator/Evaluator) |
| 5. **Ralph Loop** (책 부록 B 신규) | 1+훅 | 가변 | 무한 반복 (장기 실행, 종료 가로채 재주입) — 우리 PostToolBatch hook이 부분 적용 |

선택 기준 (orchestration-decision skill 매트릭스와 동기):
- **싱글**: ≤15분 작업, 단일 도메인
- **서브에이전트**: cost-accountant·VCK·qa 외부 검증 필요 시 (우리 §15.7 위임 가치)
- **멀티**: 다중 독립 도메인 (server + web 동시 + 5+ Edit 폭주) — worktree 권장
- **Plan-and-Execute**: ≥1시간 다단계 작업 (writing-plans skill 시너지)
- **Ralph Loop**: 종료 조건 미정의 + 반복 검증 (sensor 회귀 자동 catch-up 등)

### 2.3 서브에이전트 간 인터페이스 정본 (2026-04-30 신설)

다른 에이전트의 출력 포맷(PLANNER_REPORT/COST_AUDIT_REPORT/QA_REPORT 등)을 변경하기 전에 반드시 `.claude/shared-contracts.md`를 읽고 호환 영향을 검토한다.

- **인터페이스 변경 = 모든 에이전트가 알아야 함** (책 Ch 16)
- 정본 위치: `.claude/shared-contracts.md`
- 새 인터페이스 추가/기존 변경 시 → shared-contracts.md 먼저 업데이트 → 7 핵심 에이전트 .md에 반영 (reports/*.md 산출물은 7 핵심 도메인 흐름 한정. 3 메타 에이전트는 별도 산출물 규약)

### 2.4 에이전트별 예산 할당 (2026-05-02 BN-#3 신설, 책 Ch 16 AGENT_BUDGETS)

호출 비용 폭주 / 둠 루프 / 무한 반복 방어용 에이전트별 한도. 본 정본을 기준으로 메인 Claude가 위임 시 예산 초과 의심 시 ALERT (sensor-loop-detection / cost-tracker 결합).

**7 핵심 기능** (책 Ch 16 정본 수치):

| 에이전트 | max_tokens | max_tool_calls | max_wall_time | max_retries |
|---------|------------|---------------|---------------|------------|
| **researcher** | 500K | 80 (WebSearch 다회) | 1800s (30분) | 2 |
| **cost-accountant** | 200K | 30 | 600s (10분) | 1 |
| **planner** | 400K | 50 | 1500s (25분) | 2 |
| **visual-canon-keeper** | 250K | 40 (find/grep 위주) | 900s (15분) | 1 |
| **server** (개발) | 800K | 150 | 2700s (45분) | 3 |
| **web** (개발) | 800K | 150 | 2700s (45분) | 3 |
| **qa** (검증 전담) | 400K | 80 | 1800s (30분) | 1 |

**3 메타·인프라** (역할·도구 특성 근거 — 책 Ch 16 원 정본엔 미수록, 신설 시점별 도구 범위 기준 산정):

| 에이전트 | max_tokens | max_tool_calls | max_wall_time | max_retries |
|---------|------------|---------------|---------------|------------|
| **infrastructure** (배포·secret·cron) | 400K | 80 (gcloud/az/배포 다단계) | 1800s (30분) | 2 |
| **harness** (메타 영역 .claude/*) | 400K | 80 (sensor/hook 시뮬 다회) | 1800s (30분) | 2 |
| **verifier** (읽기전용 검증) | 300K | 60 (Read/Grep 위주, Edit/Write 없음) | 1200s (20분) | 1 |

운영 규칙:
- **[MUST]** 위 한도는 책 Ch 16 정본. 변경 시 반드시 사용자 승인 (cost-accountant도 호출됨)
- **[MUST]** 한도 80% 초과 시 sensor-cost-margin이 ALERT 발생 (cost-tracker.jsonl 기반)
- **[SHOULD]** 사용자가 큰 작업 위임 시 메인 Claude가 사전 예산 추정 보고
- **[NICE]** 향후 Claude Code SDK가 max_tokens 강제 지원 시 frontmatter 자동 적용

근거: 책 Ch 16 "비용 폭주 → 에이전트별 예산 + 에스컬레이션 = 역할별 한도" / Ch 18 "Anthropic 비용 데이터 — $9 실패 = 가치 0".

---

## 3. Skills · Sensors · Hooks · Eval 인벤토리 — 검증 기준

> 숫자/목록은 하드코딩하지 않는다. 아래로 실측한다.

| 항목 | 검증 방법 |
|------|----------|
| Skills | `ls .claude/skills/` |
| Sensors | `ls .claude/scripts/sensor-*.sh` |
| Hooks 이벤트 | `python3 -c "import json; print(list(json.load(open('.claude/settings.json'))['hooks'].keys()))"` |
| Hook 스크립트 | `ls .claude/scripts/hook-*.sh` |
| Knowledge | `ls .claude/knowledge/` |
| Prompts | `ls .claude/prompts/` |
| Slash commands | `ls .claude/commands/` |
| Eval tasks | `ls eval/tasks/*.json | wc -l` |
| Eval baseline | `cat eval/results/baseline.csv | tail -5` |
| Statusline | `cat .claude/scripts/statusline.sh` |

---

## 4. 프롬프트 엔지니어링 정본 (요약 + 정본 pointer)

> 본 §4는 루트 CLAUDE.md §15에 좁게 정의된 정본을 그대로 참조한다.

| 파일 | 용도 |
|------|------|
| `prompt-engineering/GMP-v2.2.md` | 요구사항 분해·프롬프트 구조화 참고 |
| `prompt-engineering/prd-generation-prompt-gmp2.md` | PRD 자동 생성 |
| `prompt-engineering/vibe-coding-unified-guide.md` | 바이브코딩 통합 가이드 |

이 3개 파일은 **정본**이다 — 수정 시 사용자 승인 필요. 에이전트 프롬프트 작성/개선 시 GMP v2.2의 XML 구조 + CRITICAL_CONSTRAINTS 이중 앵커 + 우선순위 라벨링([MUST]/[SHOULD]/[NICE]) 적용.

---

## 5. 변경 이력

- 2026-04-30: 본 파일 신설 — 루트 CLAUDE.md §12 + §14 + §15을 본 파일로 이동 (책 Ch 08 60-line 분할 + Ch 16 shared-contracts 도입과 같은 세션). 인벤토리 §3 추가 (드리프트 방지).
- 2026-05-30 (harness): 7 → **10 에이전트 (7 핵심 + 3 메타)** 정합. §2 인벤토리 pointer 수치 갱신(Agents 10/Skills 26현역+9archive/Hooks 10이벤트/Sensors 57/Knowledge 9), §2.2.2 패턴 표 "우리 10 에이전트", §2.3 shared-contracts 반영 대상 "7 핵심" 명시, §2.4 예산표에 3 메타(infrastructure/harness/verifier) 행 추가(책 Ch 16 원 정본 미수록 → 도구·역할 특성 근거 산정 명시).
