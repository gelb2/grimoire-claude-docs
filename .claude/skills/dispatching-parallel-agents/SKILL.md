---
name: dispatching-parallel-agents
description: 여러 독립 도메인 작업을 병렬 서브에이전트(Task tool)로 동시 dispatch. obra/superpowers (MIT) 차용 + ProjectGrimoire orchestration-decision skill의 후속 단계. 위임 가치 매트릭스 PASS 후 다중 에이전트 동시 호출 시 자동 발동. 사용자 명시 호출도 가능.
allowed-tools: Read, Bash
disable-model-invocation: true
effort: medium
trigger-mode: keyword + user-invocation (paths 미적용 — 메타 절차)
triggers:
  - "병렬 위임"
  - "동시 dispatch"
  - "parallel agents"
  - "여러 에이전트 동시"
  - "다중 도메인 동시"
---

# Dispatching Parallel Agents — 다중 서브에이전트 동시 dispatch

> **trigger-mode**: user-invocation (disable-model-invocation:true) + 키워드 매칭. paths 미적용 — 메타 절차.
> **신설**: 2026-05-03 #10_6 묶음 EE — 사용자 명시 (proposal §10-3 적용)
> **승격 원본**: obra/superpowers (MIT, 168k+ stars) dispatching-parallel-agents

## 동기 (책 Ch 16 + ProjectGrimoire 패턴 1 KPI)

**orchestration-decision skill (#10_3)** = 단일 에이전트 위임 가치 결정 (1:1 매칭).
**dispatching-parallel-agents (본 skill)** = **다중 에이전트 동시 dispatch** (1:N 매칭).

차별점:
- orchestration-decision: "이 작업을 grimoire-server vs 메인 직접 vs cost-accountant 중 누구에게?"
- dispatching-parallel-agents: "이 작업을 server + web + qa 동시에 위임 가능?"

## 발동 조건

다음 중 1개 이상:
1. **트리거 키워드 매칭** (위 frontmatter triggers)
2. **orchestration-decision 결과 = 다중 에이전트 (2+)** — 자동 후속 발동
3. **사용자 명시 호출**: `/dispatching-parallel-agents`
4. **다중 독립 도메인 작업** (예: server API 추가 + web UI 추가 + docs 갱신 동시)

## 절차 (4 단계)

### Step 1. 작업 분해 가능성 검증
다음 모두 충족 시 병렬 가능:
- 각 작업이 **독립** (다른 작업의 산출물에 의존 X)
- 산출물 충돌 없음 (같은 파일 동시 수정 X)
- 검증 채널 분리 가능 (회귀 검증이 도메인별 독립)

→ **하나라도 위반 시 순차 (orchestration-decision으로 fallback)**

### Step 2. 에이전트 할당 매트릭스
agent-interaction-matrix 정합 검증:

| 작업 | 위임 에이전트 | 동시 발동 가능 (matrix 정합) |
|------|-------------|------------------------|
| server API 추가 | grimoire-server | ✅ (web과 독립) |
| web UI 추가 | grimoire-web | ✅ (server와 독립) |
| docs/api-contract 갱신 | grimoire-server (정본 위치) | ✅ |
| visual 검수 | grimoire-visual-canon-keeper | ✅ (server·web과 독립) |
| 원가 검증 | grimoire-cost-accountant | ✅ (단일 호출) |

### Step 3. 병렬 dispatch (Task tool 동시 호출)
Claude Code Task tool은 **단일 메시지 내 다중 tool_use** 지원:

```python
# 메인 Claude 메시지 내 동시 발동
[
  Task(subagent_type="grimoire-server", prompt="...", description="API 추가"),
  Task(subagent_type="grimoire-web", prompt="...", description="UI 추가"),
  Task(subagent_type="grimoire-visual-canon-keeper", prompt="...", description="시각 검수"),
]
```

**[MUST]** 단일 메시지 — 분리 메시지 호출은 순차 (병렬 효과 X)

### Step 4. 결과 통합 + 회귀 검증
- 각 에이전트 산출물 raw 첨부 (CLAUDE.md §12 정본)
- 충돌 발견 시 (희소 — Step 1에서 거름) → orchestration-decision으로 fallback
- 통합 후 sensor-adversarial-pre-commit 19 principles 자동 검증 (P8 핵심 sensor 통과 강제)

## 절대 금지 사항

### [MUST NOT] 종속 작업 병렬화
A 산출물이 B 입력이면 → 순차 강제. 병렬은 둠 루프 위험 (책 Ch 23 안티패턴 #6).

### [MUST NOT] 분리 메시지 다중 Task
같은 메시지 내 다중 tool_use만 진정한 병렬. 분리 메시지는 순차.

### [MUST NOT] 검증 채널 미분리
server·web 동시 변경 시 회귀 sensor가 양쪽 모두 PASS여야 commit.

### [MUST NOT] cost-accountant·visual-canon-keeper·qa 외 멀티 에이전트 (server·web 외)
matrix 정합 강제 — 임의 조합 금지.

## ProjectGrimoire 적용 사례

### 좋은 사례 (예상)
- **세션 #9 prod 배포 (4-27)**: server + web + claude-docs 동시 commit/push (병렬 dispatch 정합)
- **새 AI 기능 신설**: planner → cost-accountant + visual-canon-keeper 동시 (검증 병렬)

### 나쁜 사례 (예방)
- **결제 변경**: server + web 동시 X (server completed 후 web 변경이 정합 — 종속)

## 관련 정본
- `.claude/skills/orchestration-decision/SKILL.md` — 단일 위임 결정 (선행 skill)
- `.claude/skills/writing-plans/SKILL.md` — 큰 작업 분할 (선행 skill)
- `.claude/knowledge/agent-interaction-matrix.md` — matrix 정합 정본
- `research/HARNESS_FIELD_PATTERNS_4.md` §15.7 — 위임 가치 매트릭스
- 책 V1.1 Ch 16 — 멀티 에이전트 5 패턴 (싱글 / 서브 / 멀티 / Plan-and-Execute / Ralph Loop)
- obra/superpowers (MIT) dispatching-parallel-agents — 차용 원본

---

마지막 업데이트: 2026-05-03 #10_6 묶음 EE
승격 원본: obra/superpowers (MIT) dispatching-parallel-agents
적용 영역: ProjectGrimoire 도메인 (한국어 + 7 에이전트 matrix 정합)
