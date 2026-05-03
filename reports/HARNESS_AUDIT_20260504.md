# HARNESS_AUDIT_20260504 — 호출 누락 + 에러 뭉개기 전수조사

> **명령**: 사용자 (2026-05-04) — "하네스엔지니어링, 에이전트 세팅 관련해서 호출 안 되거나 대충 뭉개고 넘어가는 그런 로직 있는지 전수검사"
> **조사 범위**: hooks 14건 / sensors 28건 / skills 24건 / agents 7건 / eval tasks 49+3건 / LLM-Judge / AGENT_BUDGETS / cost-tracker

---

## 0. 종합 결과 — 5건 결함 발견 (1건 즉시 수정, 4건 사용자 결정)

| # | 카테고리 | 심각도 | 상태 |
|---|---------|--------|------|
| 1 | **PAY-P0 신규 sensor 3건 호출 누락** | 🔴 CRITICAL | ✅ 본 세션 즉시 수정 |
| 2 | 7 에이전트 7일간 Task 호출 0건 | 🟠 구조적 한계 | ⏸️ jsonl flush 한계 (§15.7.3.2) |
| 3 | LLM-as-Judge stub만, 실호출 0회 | 🟡 의도 (사용자 보류) | ⏸️ 영구 보류 |
| 4 | AGENT_BUDGETS 박제만 + 적용 메커니즘 0 | 🟡 책 P0 갭 미해소 | ⏸️ 사용자 결정 |
| 5 | cost-tracker.jsonl 3건만, 활성 운영 안 됨 | 🟡 운영 갭 | ⏸️ 추가 박제 필요 |

---

## 1. 결함 상세

### 결함 #1 (CRITICAL — 즉시 수정 ✅)

**증상**: PAY-P0 진척 중 신설된 sensor 3건이 어떤 hook/wrapper에도 등록 안 됨.

| Sensor | 신설 출처 | 호출 위치 |
|--------|---------|----------|
| `sensor-admin-credit-ui.sh` | PAY-P0-3 (web `af3f04c`) | **0** |
| `sensor-payment-idempotency.sh` | PAY-P0-1 (server `8c13103`) | **0** (shared-contracts.md 정의만) |
| `sensor-payment-reconciliation.sh` | PAY-P0-2 (server `8e9e02e`) | **0** (shared-contracts.md 정의만) |

**의미**: 다른 리모트 세션이 sensor 신설 + 박제는 했으나 **commit 직전 자동 검증 게이트 등록을 누락**. 결과적으로 PAY-P0 회귀 테스트가 실제로는 작동 안 했음. "있는 것처럼 보이지만 호출 안 되는" 가장 위험한 케이스.

**수정 (본 세션 묶음 KK)**: `sensor-adversarial-pre-commit.sh` Principle 8 sensor 리스트에 3건 추가:
```bash
for s in sensor-server sensor-web sensor-docs-sync sensor-secret-leak sensor-credit-atomicity \
         sensor-payment-idempotency sensor-payment-reconciliation sensor-admin-credit-ui; do
```

**검증 결과**: `✅ P8 핵심 Sensor exit ≤2 — 8 핵심 sensor 모두 통과 (exit ≤2, PAY-P0 3건 포함)`

→ 이제 commit 직전 자동 검증 강제 정합.

---

### 결함 #2 (구조적 한계 — Claude Code 자체)

**증상**: `~/.claude/projects/.../*.jsonl` 7일 분석 결과 7 에이전트 Task 호출 **0건**.

**원인**: §15.7.3.2 박제된 jsonl flush 지연 — Task tool 호출이 즉시 jsonl에 박제 안 됨. 본 세션에서도 researcher 1회 위임했으나 미박제.

**완화책 (이미 적용)**: 
- `sensor-orchestration-ratio` META_PASS 다운그레이드 (메타 세션은 정합)
- §15.7 위임 가치 매트릭스 (메인 직접 처리도 정합 영역 명시)

**남은 작업**: Claude Code 자체 jsonl flush 동작 개선 또는 다른 측정 채널 도입 (사용자 결정 영역).

---

### 결함 #3 (의도된 stub — 사용자 영구 보류)

**증상**: `eval/scripts/grade-llm.py`가 stub만 있고 실제 Anthropic API 호출 0회.

```python
def call_anthropic_judge(rubric, content, project_root):
    api_key = os.environ.get('ANTHROPIC_API_KEY')
    if not api_key:
        # 실제 API 호출은 P2 (anthropic SDK 의존성). 본 도입은 인프라 + 가드만.
        return {
            'reasoning': '[STUB] LLM-as-Judge 인프라 도입. 실제 Anthropic API 호출은 P2 후속',
        }, "stub_response"
```

**상태**: 사용자 영구 보류 결정 (2026-04-30) — "외부 Anthropic API 신규 의존 보류". `edd-sample-001`의 정상 baseline FAIL (96.15% 중 2 fail)이 본 stub의 의도된 결과.

**조치**: 보류 유지. 추후 사용자 명시 시 실제 SDK 연동.

---

### 결함 #4 (책 P0 갭 미해소)

**증상**: `AGENT_BUDGETS` 박제는 `.claude/AGENTS.md` + `book-harness-engineering-completion.md` 에만 존재. 7 에이전트 .md / settings.json / 실제 호출 시점 어디에도 적용 메커니즘 없음.

**책 V1.1 Ch 16 권장**:
```python
AGENT_BUDGETS = {
    "frontend": {"max_tokens": 500K, "max_tool_calls": 100, "max_wall_time": 1800},
    "backend":  {"max_tokens": 800K, "max_tool_calls": 150, "max_wall_time": 2700},
    "evaluator":{"max_tokens": 300K, "max_tool_calls": 50,  "max_wall_time": 900},
}
```

**현재 상태**: 책 P0 갭 그대로. 도입 시 7 agent .md frontmatter 확장 + Task tool 호출 시 검증 hook 필요.

**조치**: 사용자 결정 영역 (구현 우선순위 결정 필요).

---

### 결함 #5 (활성 운영 갭)

**증상**: `cost-tracker.jsonl` 3건만 박제 (5월 2일 마지막 갱신).

**원인**: 묶음 R로 인프라 도입했으나 실제 매 세션/매 호출 시 자동 박제 안 됨. cost-tracker.sh가 어디서도 자동 호출 안 됨.

**자가진단 영향**: Q6 ("태스크 비용 인지") 현재 PASS는 ≥1건 임계로 충족 — 실제 활성 운영 X.

**조치**: 본 세션에서는 사용자 명시 결함 보고만. 활성화 작업은 별도 묶음 (Hook 추가 또는 wrapper 패턴).

---

## 2. 정합 (호출 검증됨)

### 2-1. Hook 14건 — 모두 정합
settings.json 등록 + 실행 권한 + 스크립트 존재 모두 ✅:
- SessionStart: check-memory-freshness
- Stop: stop-memory-guard
- UserPromptSubmit: user-prompt-memory-check + skill-injector
- PreCompact: pre-compact-memory-guard
- InstructionsLoaded: instructions-drift-check
- PostToolBatch: post-batch-tsc
- PreToolUse (Bash): pretooluse-bash-guard
- PostToolUse (Edit|Write): post-edit-tsc + post-edit-spec-check + loop-detection-tracker
- PostToolUse (Task|Agent): generate-report-template
- PostToolUseFailure: posttooluse-failure-handler
- SubagentStop: subagent-stop-handler

### 2-2. 25 sensor 중 22건 활성
sensor-hits.jsonl 박제 기준 활성 호출:
- sensor-credit-atomicity: 372회 (최다)
- sensor-shared-contracts: 363회
- sensor-cost-margin: 294회
- sensor-instruction-degradation: 252회
- sensor-security-gate: 219회
- sensor-deploy-drift: 190회
- sensor-web: 129회
- sensor-adversarial-pre-commit: 126회
- 등 22건

silent 5건:
- sensor-log (wrapper, 의도)
- sensor-hit-rate-report (리포트형, 의도)
- **sensor-admin-credit-ui** ← 결함 #1 수정 후 호출됨
- **sensor-payment-idempotency** ← 결함 #1 수정 후 호출됨
- **sensor-payment-reconciliation** ← 결함 #1 수정 후 호출됨

### 2-3. 24 skill 중 21건 정합 + 3건 의도된 user-only
- 21건: triggers + paths + disable-model-invocation 정합
- 3건 (memory-status / red-team-update-propose / worktree-isolation): 사용자 명시 호출만 의도

### 2-4. eval task 49+3건
항상 PASS 패턴 0건. auto-sensor-* 16건은 sensor exit 0 검증 (의도된 PASS-only).

### 2-5. 3 레포 pre-commit 모두 자동 발동 (이전 묶음 JJ 보강)
- claude-docs hookspath = .githooks ✅
- server hookspath = .githooks ✅
- web hookspath = .githooks ✅

---

## 3. 에러 뭉개기 패턴 분석

### 3-1. `|| true` 패턴 — 검토 결과 모두 의도

전수 grep 결과 `|| true` 패턴은 모두 sensor-log wrapper 호출:
```bash
bash "$(dirname "$0")/sensor-log.sh" "..." 2>/dev/null || true
```

**의도**: sensor-log 자체 실패해도 메인 sensor PASS 유지 (옵저버빌리티 < 본질 검증).

→ 결함 아님.

### 3-2. `>/dev/null 2>&1` 패턴 — 검토 결과 모두 의도

sensor-adversarial-pre-commit이 내부 sensor 호출 시 출력 모두 버리고 exit code만 사용:
```bash
bash "$ROOT/.claude/scripts/sensor-cost-margin.sh" >/dev/null 2>&1
EC=$?
```

**의도**: wrapper sensor가 자체 출력만 통일 + 내부 sensor의 raw 출력은 리포트 노이즈 회피.

→ 결함 아님.

### 3-3. `set +e ... ADV_RC=$? ... set -e` 패턴 — 묶음 JJ 보강

server/web pre-commit에서 sensor-adversarial 호출 시 set -e가 WARN(exit 1)을 차단하는 문제 → set +e/-e 패턴으로 회피. WARN 허용, FAIL만 차단.

→ 의도된 정합.

---

## 4. 후속 조치

### 즉시 (본 세션 완료)
- ✅ 결함 #1 수정 (sensor-adversarial P8에 PAY-P0 3 sensor 추가)
- ✅ 본 보고서 박제

### 사용자 결정 영역
- 결함 #2: jsonl flush 한계 — Claude Code 본질, 측정 채널 추가 검토
- 결함 #3: LLM-as-Judge — 외부 API 보류 유지 / 해제 결정
- 결함 #4: AGENT_BUDGETS — 적용 메커니즘 도입 우선순위 결정
- 결함 #5: cost-tracker 활성화 — Hook 또는 wrapper 패턴 도입 결정

---

## 5. 변경 이력
- 2026-05-04 묶음 KK 신설: 호출 누락 + 에러 뭉개기 전수조사 (5건 결함)
- 결함 #1 즉시 수정: sensor-adversarial-pre-commit P8 sensor 리스트 5→8건 확장
