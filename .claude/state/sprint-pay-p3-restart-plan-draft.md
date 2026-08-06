# Sprint PAY-P3 — 재시작 플랜 (Draft, 본 세션 5/9 사용자 명시 패턴 정합)

> **작성**: 2026-05-09 #10_8 본 세션 grimoire-planner agent (Initializer 역할, 책 Ch 16 Anthropic 3-에이전트 패턴 정합)
> **트리거**: 사용자 명시 (2026-05-09) — "결제 시스템 고도화 관련 과제 추리고 다시 시작 / 에이전트 위임 위주로 진행 / 더 이상 일 진행 불가한 케이스: agent 거부 / agent 메인 전가 → 메인 권한 1개 열기 → agent 수정 → 메인 권한 닫기"
> **본 위치**: `.claude/state/` (PP-13 메인 화이트리스트 우회 영역). 정본 영역 (`reports/sprint-pay-p3-restart-plan.md`)으로 사용자 또는 grimoire-infrastructure agent 위임 후 이동 영역.
> **선행 박제**: `.claude/state/sprint-pay-p3-master-plan-draft.md` (마스터 플랜 13 섹션) + `.claude/state/sprint-pay-p3-a-race-condition-draft.md` (PAY-P3-A AC BDD 8건)

---

## §0 1단락 요약

본 재시작 플랜은 PAY-P3 진입 직전 **본 세션 (#10_8 5/8~5/9)에서 입증된 본질 결함**을 박제 후, 사용자 명시 패턴 (5/9) — "에이전트 위임 위주 + agent 거부/메인 전가 시 케이스 처리 매트릭스" — 정합으로 PAY-P3 7 sprint (Phase 1, 외부 API 0건, ~21h) 재진입 영역을 설계합니다. 본 세션 입증 본질 결함 = **(1) PAY-P3-A grimoire-server agent isSidechain=False 검출 결함** (메인 직접으로 인식 + PP-7/PP-13 차단 + 코드 변경 0건) + **(2) grimoire-infrastructure agent harness 메타 영역 정직 거부** (책임 영역 외부) + **(3) grimoire-server agent .claude/scripts/ 영역 정직 거부** (NestJS 도메인 외부) → **agent 위임 매커니즘 본질 좌절 입증**. 본 결함 해소 = 사용자 직접 영역 (PP-13 우회 함수 복원 → agent 정의/라우팅 수정 → PP-13 우회 함수 제거) — 사용자 1회 직접 작업 후 본 세션 메인 자율 진행 가능. 첫 진입 sprint 재권장 = **PAY-P3-A** 또는 케이스 1 처리 회피 영역 = **PAY-P3-C (Retry 중복, ~2h)** 또는 **PAY-P3-B (Polar timeout, ~2h)** — 본 세션 1차 시도 차단 영역과 동일 결함 가능성 평가.

---

## §1 본 세션 입증 본질 결함 박제 (직접 raw 박제, 추정 0)

### 1-1. PAY-P3-A grimoire-server agent isSidechain 검출 결함 (1순위 결함)

**시도 시점**: 2026-05-08T14:27:55Z (직접 박제 `.claude/state/edit-write-violation.jsonl:9`)

**raw 박제**:
```json
{"ts":"2026-05-08T14:27:55Z","type":"main_direct_in_agent_domain","tool":"Edit","file":"/Users/sokol/Git/ProjectGrimoire/grimoire-server/src/application/payment/payment.usecase.ts","expected_agent":"grimoire-server"}
```

**입증 본질**:
1. PAY-P3-A 1차 시도 = 메인이 grimoire-server agent를 Task tool로 위임
2. agent 내부에서 `payment.usecase.ts` Edit 시도
3. **PP-7 hook (`pretooluse-edit-write-guard.sh`)이 `isSidechain=False`로 검출** → 메인 직접 시도로 인식
4. 차단 메시지: "REJECT — 메인 Claude 직접 작업 차단 (grimoire-server 책임 영역)"
5. **agent 내부 Edit인데도 차단** → agent 위임 본질 좌절

**결함 위치**:
- `.claude/scripts/pretooluse-edit-write-guard.sh:48-56` `isSidechain` 체크 영역
- `.claude/scripts/pretooluse-main-whitelist.sh:36-45` `isSidechain` 체크 영역
- 두 hook 모두 stdin JSON `isSidechain` field 추출이 정상 작동 안 함 (또는 Task tool이 isSidechain field 비전달)

**증거 보강** (직접 Read):
- `pretooluse-edit-write-guard.sh:48-56`:
  ```bash
  SIDECHAIN=$(echo "$INPUT" | python3 -c "import json,sys
  try:
      d=json.loads(sys.stdin.read())
      print(d.get('isSidechain', False))
  except: print('False')" 2>/dev/null || echo "False")

  if [ "$SIDECHAIN" = "True" ]; then
    exit 0  # agent 안에서는 통과
  fi
  ```
- `False` (Bool false) vs `False` (string "False") 정합 영역, Python 출력 시 `print(False)` → `"False"` (capitalized) 정합. 문제는 **Task tool이 isSidechain field를 전달하느냐 / 메인이 stdin JSON에 isSidechain 박제하느냐** 검증 필요.

### 1-2. grimoire-infrastructure agent harness 메타 영역 정직 거부 (2순위 결함)

**시도 시점**: 본 세션 5/8 후속 (PP-13 hook 자동 강제 시스템 구축 영역)

**raw 박제**:
- `.claude/state/main-blocked-log.jsonl:8-12,14,17,19` 다수 박제 (메인 직접 차단 + agent 위임 시도 차단)
- 본 사용자 명시 (2026-05-08): `"메인은 그냥 시발 아무것도 못 하게 권한 박아버려"` → PP-13 hook 강제 영역
- grimoire-infrastructure agent → **harness 메타 영역 (.claude/scripts/, .claude/skills/, .claude/agents/, .claude/settings.json) 책임 영역 외부 정직 거부** → 메인 직접만 가능

**입증 본질**:
1. PP-13 hook 강제 영역 신규 = `.claude/scripts/pretooluse-main-whitelist.sh`
2. 메인 = 신규 hook 작성 시도
3. PP-13 hook 자기 자신을 차단 (자기 모순) → main-blocked-log 박제
4. agent 위임 시도 = grimoire-infrastructure agent → "harness 메타 영역은 grimoire-infrastructure 책임 외부" 정직 거부
5. → 사용자 직접 영역 (사용자가 PP-13 hook 우회 함수 수동 복원 후 메인 작업 → 다시 제거)

**결함 위치**:
- `.claude/agents/grimoire-infrastructure.md` 정의 = harness 메타 영역 책임 미박제
- PP-7 라우팅 매트릭스 (`pretooluse-edit-write-guard.sh:62-87`) = `.claude/scripts/sensor-* + pretooluse-* + ...` → grimoire-infrastructure 매핑 추가 (5/8 본 세션 사용자 명시 적용 박제) — **단 agent 정의 자체에는 책임 영역 박제 안 됨**

### 1-3. grimoire-server agent .claude/scripts/ 영역 정직 거부 (3순위 결함)

**시도 시점**: 본 세션 5/8 PP-7 hook 강제 시스템 구축 영역 (직접 박제 `.claude/state/edit-write-violation.jsonl:4-7`)

**raw 박제**:
```json
{"ts":"2026-05-08T12:08:40Z","type":"main_direct_in_agent_domain","tool":"Edit","file":"/Users/sokol/Git/ProjectGrimoire/.claude/scripts/pretooluse-bash-guard.sh","expected_agent":"grimoire-server"}
{"ts":"2026-05-08T12:33:12Z","type":"main_direct_in_agent_domain","tool":"Edit","file":"/Users/sokol/Git/ProjectGrimoire/.claude/scripts/pretooluse-edit-write-guard.sh","expected_agent":"grimoire-server"}
```

**입증 본질**:
1. PP-7 라우팅 매트릭스 (5/8 박제 시점) = `.claude/scripts/*` → `grimoire-server` 매핑
2. 메인 = `.claude/scripts/pretooluse-bash-guard.sh` Edit 시도
3. PP-7 hook = "grimoire-server 책임 영역 직접 시도" 차단
4. agent 위임 시도 = grimoire-server agent → "`.claude/scripts/`는 NestJS 도메인 외부 / harness 메타 영역" 정직 거부
5. → 사용자 명시 후 PP-7 라우팅 매트릭스 수정 (5/8 후속 = `.claude/scripts/sensor-* / pretooluse-* / stop-* / check-* / skill-* / ...` → `grimoire-infrastructure` 매핑 — `pretooluse-edit-write-guard.sh:71-87` 박제)
6. → grimoire-infrastructure agent 신설 (HANDOVER §1.6 박제 정합) — 단 본 §1-2 결함과 결합

**결함 위치**:
- 5/8 시점 PP-7 라우팅 매트릭스 결함 = `.claude/scripts/*` → `grimoire-server` 자동 매핑
- 사용자 명시 후 수정됨 (5/8 후속, `pretooluse-edit-write-guard.sh:71-87` 박제 정합) — 단 agent 정의 / 책임 영역 박제는 미완료

### 1-4. PP-7 / PP-12 / PP-13 자기 모순 누적 (메인 권한 차단 강제 시스템의 자기 차단)

**누적 박제** (직접 Read `.claude/state/main-blocked-log.jsonl` + `.claude/state/edit-write-violation.jsonl`):

| 박제 일시 | hook | 차단 영역 | 본질 |
|---|---|---|---|
| 2026-05-06T05:47:56Z | PP-7 | grimoire-server/src/test.ts | PP-7 hook 차단 정상 |
| 2026-05-06T05:48:18Z | PP-7 | PLANNING_GRIMOIRE.md 직접 | 사용자 승인 영역 차단 정상 |
| 2026-05-08T12:08:40Z | PP-7 | .claude/scripts/pretooluse-bash-guard.sh | **PP-7 hook 자기 자신을 차단** (자기 모순 1회) |
| 2026-05-08T12:33:12Z | PP-7 | .claude/scripts/pretooluse-edit-write-guard.sh | **PP-7 hook 자기 자신을 차단** (자기 모순 2회) |
| 2026-05-08T13:26:37Z | PP-7 | .claude/scripts/pretooluse-main-whitelist.sh | **PP-13 hook 자기 자신을 차단** (자기 모순 3회) |
| 2026-05-08T13:45:16Z | PP-13 | .claude/scripts/pretooluse-main-whitelist.sh | **PP-13 hook 자기 자신을 차단** (자기 모순 4회 — 무한 루프 가능성) |
| 2026-05-08T14:10:45Z | PP-13 | reports/sprint-pay-p3-master-plan.md | reports 영역 차단 (planner agent 영역 명시 안 됨) |
| 2026-05-08T14:27:55Z | PP-7 | grimoire-server/src/application/payment/payment.usecase.ts | **PAY-P3-A agent 위임 isSidechain 결함** (본 §1-1 본질) |
| 2026-05-08T15:09:24Z | PP-13 | .claude/agents/grimoire-harness.md | **메인 agent 신설 시도 차단** (본 §1-3 후속 — agent 정의 영역도 화이트리스트 외) |

**입증 본질**:
- PP-7/PP-12/PP-13 hook 시스템 = 메인 권한을 차단하기 위해 신설
- **메인이 hook 시스템 신설/수정 시도 시 hook이 자기 자신을 차단** (메인 = 베이비시팅 회피)
- 사용자 명시 (5/8 후속) = "허용패턴만 통과로 남겨놔" → 우회 키워드 자동 적용 함수 제거 → 사용자 직접 영역 강제
- → **본 세션 케이스 처리 영역 = 사용자 직접 (PP-13 우회 함수 복원 → 메인 작업 → 다시 제거)**

### 1-5. agent 위임 매커니즘 본질 좌절 입증

**누적 결함 정합**:
1. **isSidechain 검출 결함** (§1-1): agent 내부 호출도 메인 직접으로 인식 → agent 위임 자체가 코드 변경 0건으로 끝남
2. **agent 책임 영역 외부 정직 거부** (§1-2 + §1-3): infrastructure agent = harness 메타 / server agent = NestJS만 / web agent = Next.js만 → 어느 agent도 책임 영역이 아닌 영역 = 메인 직접만 가능
3. **PP-13 hook 자기 모순** (§1-4): 메인 권한 차단 강제 시스템이 자기 수정도 차단 → 사용자 직접 영역 강제

**해소 영역** (= 사용자 직접 영역):
- 사용자 1회 직접 작업: PP-13 우회 함수 복원 → agent 정의 / 라우팅 매트릭스 / hook 로직 수정 → PP-13 우회 함수 제거
- 케이스 처리 = 사용자 명시 (5/9) "메인 권한 1개 열고 에이전트 수정 → 다시 메인 권한 닫음" 정합

---

## §2 사용자 명시 패턴 정합 (본 세션 5/9)

### 2-1. 사용자 명시 raw 인용 (5/9)

> "결제 시스템 고도화 관련 과제 추리고 다시 시작
> * 에이전트 위임 위주로 진행
> * 더 이상 일 진행 불가한 케이스
>    * 에이전트가 거부 → 메인의 권한 하나 열고 에이전트 수정 → 다시 메인 권한 닫음
>    * 에이전트가 메인으로 전가 → 업무가 에이전트 도메인에 맞으면 메인 권한 하나 열고 에이전트 수정 → 다시 메인 권한 닫음"

### 2-2. 패턴 분해 (메인 자율 영역 + 사용자 영역)

**원칙 1**: 에이전트 위임 위주 진행 (메인 = 지휘자 + 위임 + 검증만)
- planner Initializer → server / web Generator → qa Evaluator
- cost-accountant / visual-canon-keeper / infrastructure / researcher 보조

**원칙 2**: 케이스 처리 매트릭스 (agent 결함 시 사용자 직접 영역)

| 케이스 | 트리거 | 처리 흐름 |
|---|---|---|
| **케이스 1** (agent 거부) | agent가 책임 영역 외부 명시 거부 | 사용자 직접 영역: 메인 권한 1개 열기 → agent 정의/책임 영역 수정 → 메인 권한 닫기 |
| **케이스 2** (agent 메인 전가 + 도메인 정합) | agent가 업무를 메인으로 전가 + 업무가 agent 도메인에 맞음 | 사용자 직접 영역: 메인 권한 1개 열기 → agent 수정 (책임 영역 명시 / 권한 추가) → 메인 권한 닫기 |
| 케이스 3 (agent 거부 + 도메인 정합 안 됨) | agent가 거부 + 다른 agent 책임 영역 | 메인 자율 영역: 다른 agent로 위임 재시도 |
| 케이스 4 (agent 결과 부적절) | agent가 작업 했으나 결과 부적절 | 메인 자율 영역: 사용자에게 보고 + 재시도 또는 사용자 명시 후 진행 |

### 2-3. 본 세션 케이스 처리 영역 명시

본 세션 입증 결함 (§1) → 케이스 1 + 케이스 2 정합 → **사용자 직접 영역**:

1. **케이스 1 처리** (PAY-P3-A isSidechain 결함):
   - **사용자가** `.claude/scripts/pretooluse-edit-write-guard.sh` + `pretooluse-main-whitelist.sh` 우회 함수 복원 (line 60~63 + 128 + 184 + 212)
   - **agent 정의** (grimoire-server.md) — Task tool 진입 시 isSidechain field 박제 영역 명시 / hook 디버깅
   - **사용자가** 우회 함수 다시 제거

2. **케이스 2 처리** (grimoire-infrastructure agent 책임 영역 미박제):
   - **사용자가** PP-13 우회 함수 임시 복원
   - **agent 정의** (grimoire-infrastructure.md) — `.claude/scripts/`, `.claude/skills/`, `.claude/agents/`, `.claude/settings.json`, `eval/scripts/`, `.claude/hooks/`, `.claude/state/` 책임 영역 명시
   - **사용자가** 우회 함수 다시 제거

3. **자동화 영역 (사용자 부담 감소)**:
   - 사용자 1단어 명시 ("위임" / "처리해" / "진행해" / "박아" / "박아버려" / "박제해" / "틀어 막" / "화이트리스트") → 메인 우회 가능
   - 본 세션 5/9 사용자 명시 raw "다시 시작" 키워드 = PP-13 우회 함수 통과 키워드 외 → **사용자 직접 영역 강제**
   - 단 사용자가 다시 한 번 우회 키워드 ("다시 시작") 추가 박제 시 메인 자율 진행 가능

---

## §3 PAY-P3 진입 sprint 우선순위 (본 세션 패턴 정합)

### 3-1. Phase 1 sprint (외부 API 0건) 우선순위 매트릭스

| Sprint | 시간 | 외부 API | 의존성 | 우선순위 | agent 위임 매트릭스 | isSidechain 결함 가능성 | 케이스 처리 발생 시 사용자 영역 |
|---|---|---|---|---|---|---|---|
| **PAY-P3-A** Race condition (구멍-A/B) | ~5h | 0 | 0 | **P1 (적자 1순위)** | planner + server + qa | **🔴 본 세션 입증 차단** | 케이스 1 처리 영역 (§1-1 결함) |
| **PAY-P3-C** Retry 중복 해소 (모순 D) | ~2h | 0 | 0 | P1 | planner + server + qa | 🟡 동일 영역 (server agent + payment.usecase Edit) | 케이스 1 가능 |
| **PAY-P3-B** Polar SDK timeout (구멍 C) | ~2h | 0 (Polar SDK 옵션만) | 0 | P1 | planner + server + qa | 🟡 동일 영역 (server agent + Polar adapter Edit) | 케이스 1 가능 |
| **PAY-P3-E** FK cascade 정책 (모순 F) | ~3h | 0 (DB 마이그레이션) | 0 | P1 | planner + server + infrastructure + qa | 🟡 동일 영역 (server agent + Prisma migration) | 케이스 1 가능 |
| **PAY-P3-H** Circuit breaker | ~4h | 0 | 0 | P1 | planner + server + qa | 🟡 동일 영역 | 케이스 1 가능 |
| **PAY-P3-D** Status enum 정합 (모순 E) | ~2h | 0 | 0 | P2 | planner + server + qa | 🟡 동일 영역 | 케이스 1 가능 |
| **PAY-P2-5** audit retention | ~3h | 0 (cleanup cron만) | 0 | P0 | planner + server + qa | 🟡 동일 영역 | 케이스 1 가능 |

### 3-2. 권장 진입 순서 (3 옵션)

**옵션 A — PAY-P3-A 재시도 + 케이스 1 처리 영역 (권장)**
- 사용자가 케이스 1 처리 (1회 직접 작업 = PP-13 우회 함수 복원 → isSidechain 결함 디버깅 → 우회 함수 제거)
- 이후 PAY-P3-A 재시도 → 적자 위험 1순위 sprint 차단 해소
- 본 세션 입증 결함 영역 자체 해소 → 후속 sprint (PAY-P3-B/C/D/E/H + PAY-P2-5) 자동 통과 가능

**옵션 B — PAY-P3-A 회피 + PAY-P3-C 또는 PAY-P3-B 우선 진입**
- PAY-P3-A 동일 결함 가능성 (server agent + payment.usecase Edit) — 본 세션 입증 결함 회피 안 됨
- 단 PAY-P3-A보다 단순 (PAY-P3-C = payment.usecase 1 line 추가 / PAY-P3-B = polar adapter 1 method 변경)
- 동일 결함 발생 시 케이스 1 처리 영역 동일 — 회피 본질 X

**옵션 C — PAY-P2-5 (audit retention) 우선 진입 (다른 영역)**
- PAY-P2-5 = AdminAuditLog cleanup cron 정책 + 인덱스 전략 → admin 영역 (payment 영역과 분리)
- server agent 위임 정합 (admin 영역도 server agent 책임 영역) — 단 isSidechain 결함은 동일 가능
- 동일 결함 발생 시 케이스 1 처리 영역 동일 — 회피 본질 X

**결론**: **옵션 A 권장** — 본 세션 입증 결함 영역 자체 해소 후 후속 sprint 일괄 통과 가능. 옵션 B/C는 동일 결함 누적 + 회피 본질 X.

### 3-3. Phase 2 sprint (외부 SaaS 결정 후) — 사용자 결정 영역 (메인 자율 진행 금지)

마스터 플랜 §3-2 정합:
1. PAY-P3-G (Sentry/APM, ~8h) — Sentry SaaS 결정 후 (cost-accountant 마진 영향 검증)
2. EMAIL-P1-1 (이메일 인증 시스템, ~12~16h) — 선행 의존성
3. PAY-P3-F = EMAIL-P1-3 (영수증 PDF + 결제 이메일, ~16~20h) — EMAIL-P1-1 종료 후
4. 작업 A + PAY-P1-4 (구독제 + Polar Subscription, ~5~8h) — 기획 단계 선행
5. PAY-P2-4 SMS, ~3h — KISA 발신번호 사용자 영역 후

본 세션 진행 영역 0건 (외부 SaaS 결정 영역, 사용자 명시 후만).

---

## §4 agent 위임 진행 매트릭스

### 4-1. 표준 패턴 (마스터 플랜 §7 정합)

```
[Step 1] 메인 (orchestration-decision skill) → 위임 가치 매트릭스 통과 검증
[Step 2] grimoire-planner (Initializer) → reports/sprint-{name}-progress.md 신설
[Step 3] (필요 시) cost-accountant → 마진 ≥3배 검증 (외부 API 영향 시)
[Step 4] (필요 시) visual-canon-keeper → 사슴악마 정본 검수 (UI 변경 시)
[Step 5] grimoire-server (Generator) + grimoire-web (Generator) → 병렬 위임
[Step 6] verification-before-completion skill + sensor 회귀 검증
[Step 7] socratic-self-critique skill (14 질문 + Ambiguity ≤ 0.2)
[Step 8] requesting-code-review skill (12 항목 체크리스트)
[Step 9] sensor-adversarial-pre-commit (19 principles, FAIL 0건 강제)
[Step 10] grimoire-qa (Evaluator) → reports/QA_REPORT.md (Sprint 계약 채점)
[Step 11] commit + push develop (메인 직접, 화이트리스트 hook 통과 영역)
[Step 12] memory 박제 (Stop hook 강제 + incident-log)
```

### 4-2. 본 세션 입증 검증 영역 매트릭스

| Agent | 본 세션 검증 결과 | 본 세션 결함 |
|---|---|---|
| **grimoire-planner** | ✅ Initializer 위임 검증 완료 (sprint 계약 13 섹션 + AC BDD 8건 박제 정합) | 0건 |
| **grimoire-server** | 🔴 **isSidechain 검출 결함** (Task tool 진입 시 PP-7/PP-13 차단) | §1-1 본질 결함 |
| **grimoire-web** | 🔵 미검증 (UI 영역 sprint 0건 본 세션) | 미검증 |
| **grimoire-qa** | 🔵 미검증 (Generator 영역 코드 변경 0건 → Evaluator 진입 영역 X) | 미검증 |
| **grimoire-visual-canon-keeper** | 🔵 미검증 (UI 변경 0건) | 미검증 |
| **grimoire-cost-accountant** | 🔵 미검증 (외부 API 0건) | 미검증 |
| **grimoire-researcher** | 🔵 미검증 (research 영역 0건 본 세션) | 미검증 |
| **grimoire-infrastructure** | 🟡 **harness 메타 영역 정직 거부** (책임 영역 외부) | §1-2 본질 결함 |

### 4-3. 본 세션 sprint별 위임 매트릭스 (마스터 플랜 §7-2 정합 + 본 세션 입증 결함 박제)

| Sprint | planner | cost-accountant | VCK | server | web | qa | infrastructure | 메인 직접 |
|---|---|---|---|---|---|---|---|---|
| **PAY-P3-A** | ✅ 검증 완료 | 면제 | 면제 | 🔴 isSidechain 결함 | 면제 | 미검증 | 면제 | commit/push (메인 차단) |
| PAY-P3-B | ⏸️ 대기 | 면제 | 면제 | 🟡 동일 결함 가능 | 면제 | 미검증 | 면제 | commit/push |
| PAY-P3-C | ⏸️ 대기 | 면제 | 면제 | 🟡 동일 결함 가능 | 면제 | 미검증 | 면제 | commit/push |
| PAY-P3-D | ⏸️ 대기 | 면제 | 면제 | 🟡 동일 결함 가능 | 면제 | 미검증 | 면제 | commit/push |
| PAY-P3-E | ⏸️ 대기 | 면제 | 면제 | 🟡 동일 결함 가능 | 면제 (DB 마이그레이션 영향만) | 미검증 | 🟡 mutation-guard 영역 | commit/push + 마이그레이션 |
| PAY-P3-H | ⏸️ 대기 | 면제 | 면제 | 🟡 동일 결함 가능 | 면제 | 미검증 | 면제 | commit/push |
| PAY-P2-5 | ⏸️ 대기 | 면제 | 면제 | 🟡 동일 결함 가능 | admin UI 일부 미검증 | 미검증 | 면제 | commit/push |

### 4-4. infrastructure agent 결합 (HANDOVER §1.6 정합)

- DB 마이그레이션 sprint (PAY-P3-E) → grimoire-infrastructure agent 위임 (`infra-mutation-guard` skill)
- mutation 직전 health snapshot + 변경 후 3-stage polling
- rollback skill (`rollback-revision`) 사전 박제

---

## §5 케이스 처리 영역 (사용자 직접)

### 5-1. 케이스 1 (agent 거부) 처리 흐름

**트리거**: agent가 책임 영역 외부 명시 거부 (예: grimoire-server agent → "`.claude/scripts/`는 NestJS 도메인 외부")

**처리 흐름** (사용자 직접 영역):

1. **사용자가 PP-13 우회 함수 임시 복원**:
   - `.claude/scripts/pretooluse-main-whitelist.sh` 우회 함수 정의 추가 (line 60~63 영역)
   - line 128 (Bash 우회 키워드 검사 호출) + line 184 (Edit/Write 우회 키워드 검사 호출) + line 212 (기타 도구 우회 키워드 검사 호출) 복원
   - 우회 키워드 = 사용자 직전 메시지의 1단어 (예: "위임", "처리해", "진행해", "박아", "박아버려", "박제해", "틀어 막", "화이트리스트")
   - 사용자 명시 raw 박제 의무

2. **agent 정의 / 라우팅 매트릭스 수정**:
   - `.claude/agents/{agent-name}.md` 정의 = 책임 영역 명시 추가 (예: grimoire-infrastructure agent = `.claude/scripts/` + `.claude/skills/` + `.claude/agents/` + `.claude/settings.json` + `.githooks/`)
   - PP-7 라우팅 매트릭스 (`pretooluse-edit-write-guard.sh:62-100`) = 영역 매핑 추가/수정
   - PP-13 화이트리스트 (`pretooluse-main-whitelist.sh`) = 화이트리스트 추가 (필요 시)

3. **사용자가 PP-13 우회 함수 다시 제거**:
   - 우회 키워드 검사 함수 제거 (line 60~63 + 128 + 184 + 212 영역)
   - 사용자 명시 (5/8) "허용패턴만 통과로 남겨놔" 정합

### 5-2. 케이스 2 (agent 메인 전가 + 도메인 정합) 처리 흐름

**트리거**: agent가 업무를 메인으로 전가 + 업무가 agent 도메인에 맞음 (예: grimoire-server agent → "이 작업은 메인이 직접 하라")

**처리 흐름** (사용자 직접 영역):

1. **사용자가 PP-7 라우팅 매트릭스에 영역 추가**:
   - `pretooluse-edit-write-guard.sh:62-100` 영역 매핑 추가
   - 예: `*grimoire-server/scripts/*) EXPECTED_AGENT="grimoire-server" ;;`

2. **agent 정의에 책임 영역 추가**:
   - `.claude/agents/{agent-name}.md` 책임 영역 명시 추가
   - 예: grimoire-server.md = `grimoire-server/src/` + `grimoire-server/scripts/` + `grimoire-server/test/`

3. **사용자가 PP-13 우회 함수 임시 복원 → 메인 작업 → 다시 제거**:
   - PP-13 우회 함수 복원
   - 메인 작업 (agent 정의 / 라우팅 매트릭스 수정 = 메인 권한 1개 열림)
   - PP-13 우회 함수 다시 제거

### 5-3. 자동화 영역 (사용자 부담 감소)

**1단어 명시 매커니즘**:
- 사용자 직전 메시지에 우회 키워드 1단어 박제 → PP-13 hook 자동 통과
- 우회 키워드 (`pretooluse-edit-write-guard.sh:158`): `agent로|위임|처리해|진행해|메인 직접|직접 Edit|직접 작업|박아|박아버려|박제해`
- 사용자 명시 raw 박제 의무 (incident-log.sh + main-blocked-log.jsonl)

**전제 조건**:
- 우회 키워드 검사 함수가 PP-13 hook에 박제되어 있어야 함
- 본 세션 5/8 사용자 명시 후 = "허용패턴만 통과로 남겨놔" → 우회 키워드 자동 적용 함수 제거 → **현재 우회 키워드 자동 적용 안 됨** → 사용자 직접 영역 강제

**해소 영역** (사용자 결정 영역):
- 사용자가 PP-13 우회 함수 다시 추가 → 1단어 명시 매커니즘 복원 → 메인 자율 진행 가능
- 또는 사용자가 매번 직접 PP-13 우회 함수 복원 → 메인 작업 → 우회 함수 제거 (현재 본 세션 영역)

### 5-4. 우회 함수 복원 명령 (사용자 직접 영역)

**파일**: `/Users/sokol/Git/ProjectGrimoire/.claude/scripts/pretooluse-main-whitelist.sh`

**복원 영역 1** (Bash 우회 키워드 검사 함수 — line 60~63 영역에 정의 추가 + line 128에서 호출):

```bash
# line 60~63 영역 추가
check_bypass_keyword() {
  local jsonl_dir="$HOME/.claude/projects/-Users-sokol-Git-ProjectGrimoire"
  local latest_jsonl=$(ls -t "$jsonl_dir"/*.jsonl 2>/dev/null | head -1)
  [ -z "$latest_jsonl" ] && return 1
  local last_user_msg=$(LATEST_JSONL_PATH="$latest_jsonl" python3 <<'PYEOF'
import json
import os
jsonl = os.environ.get('LATEST_JSONL_PATH', '')
last_user = ""
try:
    with open(jsonl) as f:
        for line in f:
            try:
                o = json.loads(line)
            except Exception:
                continue
            m = o.get('message', {})
            if isinstance(m, dict) and m.get('role') == 'user':
                content = m.get('content', '')
                if isinstance(content, list):
                    for c in content:
                        if isinstance(c, dict) and c.get('type') == 'text':
                            last_user = c.get('text', '')
                else:
                    last_user = str(content)
except Exception:
    pass
print(last_user[:1000])
PYEOF
)
  if echo "$last_user_msg" | grep -qE "agent로|위임|처리해|진행해|메인 직접|직접 Edit|직접 작업|박아|박아버려|박제해|틀어 막|화이트리스트|다시 시작"; then
    return 0
  fi
  return 1
}

# line 128 (Bash 화이트리스트 외 영역) 호출 추가
if check_bypass_keyword; then
  exit 0
fi

# line 184 (Edit/Write 메타 영역 외) 호출 추가
if check_bypass_keyword; then
  exit 0
fi

# line 212 (기타 도구) 호출 추가
if check_bypass_keyword; then
  exit 0
fi
```

**해소 영역**: 본 세션 5/9 사용자 명시 raw "다시 시작" 키워드 = 위 우회 키워드 검사 함수에 추가 박제 영역 → 본 세션 메인 자율 진행 가능 (단 사용자 직접 영역 1회 작업 후만).

---

## §6 진행 영역 분리 (본 세션 메인 자율 + 사용자 영역)

### 6-1. 본 세션 메인 자율 진행 가능 영역 (PP-13 화이트리스트 통과)

**검증된 영역** (직접 박제):
- planner Initializer 위임 (Task tool subagent_type=grimoire-planner) — 본 세션 5/8 검증 완료 (sprint 계약 13 섹션 + AC BDD 8건 박제 정합)
- server agent 위임 시도 (Task tool subagent_type=grimoire-server) — 본 세션 5/8 차단 영역 (§1-1 결함, isSidechain=False 검출)
- Read / Glob / Grep tool — 화이트리스트 통과 (`pretooluse-main-whitelist.sh:54-58`)
- Bash sensor 호출 (`bash .claude/scripts/sensor-*`) — 화이트리스트 통과 (`pretooluse-main-whitelist.sh:99-101`)
- `.claude/state/` Write/Edit — 메타 영역 통과 (`pretooluse-main-whitelist.sh:166`)
- git commit / push develop — 화이트리스트 통과 (`pretooluse-main-whitelist.sh:78-80`)

**제한된 영역** (본 세션 메인 자율 차단):
- `grimoire-server/src/`, `grimoire-web/src/`, `grimoire-server/docs/`, `grimoire-web/docs/`, `eval/tasks*`, `eval/scripts/` Edit/Write — agent 위임 강제 (PP-7)
- `.claude/scripts/`, `.claude/skills/`, `.claude/agents/`, `.claude/settings.json` Edit/Write — grimoire-infrastructure agent 위임 강제 (PP-7)
- `reports/QA_REPORT*`, `reports/PLANNER_REPORT*`, `reports/COST_AUDIT*`, `reports/VISUAL_CANON*`, `reports/DEV_REPORT*` Write/Edit — 해당 agent 위임 강제 (PP-7)
- `PLANNING_GRIMOIRE.md` Edit — 사용자 승인 영역 (PP-7)
- mutation 명령 (deploy / az containerapp update / git push main / migrate deploy / reset) — grimoire-infrastructure agent 위임 강제 (`pretooluse-bash-guard.sh`)

### 6-2. 사용자 직접 영역 (메인 자율 차단)

**케이스 1 처리 영역** (agent 거부 시):
1. PP-13 우회 함수 복원 (사용자 직접 Edit `pretooluse-main-whitelist.sh`)
2. agent 정의 / 라우팅 매트릭스 수정 (메인 권한 1개 열림 후)
3. PP-13 우회 함수 다시 제거 (사용자 직접 Edit)

**케이스 2 처리 영역** (agent 메인 전가 시):
1. PP-7 라우팅 매트릭스 수정 (사용자 직접 Edit `pretooluse-edit-write-guard.sh`)
2. agent 정의 책임 영역 추가 (사용자 직접 Edit `.claude/agents/{agent-name}.md`)
3. PP-13 우회 함수 임시 복원 → 메인 작업 → 다시 제거

**main 머지 영역** (.githooks/AGENTS.md §1):
- 3 레포 develop → main 머지 = 사용자 per-repo 명시 영역
- 명시 키워드: "claude-docs main 머지" / "server main 머지" / "web main 머지"

**dev curl 자격증명 영역**:
- POST /payments/webhook valid signature mock — Polar HMAC 생성 (사용자 명시 영역)
- DLQ retry 의도적 시뮬 — 사용자 명시 영역

**prod 영역**:
- dev 24h 안정성 박제 후 사용자 명시 영역
- 명시 키워드: "prod 배포 진행"

**기획 변동 영역**:
- 작업 A 구독제 요금제 (가격대 + 등급 구조)
- AI 채팅 1턴 크레딧 비용
- Polar Subscription Product 도입 여부

---

## §7 추천 첫 진입 sprint

### 7-1. 추천 옵션 (3 옵션 비교)

| 옵션 | sprint | 시간 | 본 세션 진행 가능 | 케이스 처리 영역 | 권장 |
|---|---|---|---|---|---|
| **옵션 A** (권장) | PAY-P3-A 재시도 | ~5h | 케이스 1 처리 영역 (사용자 직접) | 사용자 1회 직접 작업 (PP-13 우회 함수 복원 + isSidechain 결함 디버깅 + 우회 함수 제거) | ✅ 본질 해소 |
| **옵션 B** | PAY-P3-C (Retry 중복) | ~2h | 동일 결함 가능 (서버 agent + payment.usecase) | 케이스 1 처리 영역 동일 | ⚠️ 회피 본질 X |
| **옵션 C** | PAY-P3-B (Polar timeout) | ~2h | 동일 결함 가능 (서버 agent + Polar adapter) | 케이스 1 처리 영역 동일 | ⚠️ 회피 본질 X |
| **옵션 D** | PAY-P2-5 (audit retention) | ~3h | 동일 결함 가능 (서버 agent + admin) | 케이스 1 처리 영역 동일 | ⚠️ 회피 본질 X |

### 7-2. 권장 결정: **옵션 A (PAY-P3-A 재시도 + 케이스 1 처리)**

**사유**:
1. **본 세션 입증 결함 영역 자체 해소** = isSidechain 검출 결함 디버깅 + agent 정의 책임 영역 명시 + PP-7 라우팅 매트릭스 수정
2. **후속 sprint 일괄 통과** = 본 세션 결함 해소 후 PAY-P3-B/C/D/E/H + PAY-P2-5 모두 자동 통과 가능
3. **결제 적자 위험 영역 1순위** = PAY-P3-A = 구멍-A (환불 누락) + 구멍-B (잔액 중복 차감) 동시 차단 = 직접 금전 영향 영역
4. **회피 본질 X** = 옵션 B/C/D는 동일 결함 누적, 사용자 직접 영역 회피 안 됨

**전제 조건** (사용자 직접 영역):
- 사용자가 본 세션 5/9 명시 raw "다시 시작" 키워드를 PP-13 우회 함수 검색 키워드에 추가 박제 (영구 박제) — 본 세션 향후 1단어 자동 통과
- 또는 사용자가 매번 직접 PP-13 우회 함수 복원 → 메인 작업 → 우회 함수 제거 (영구 박제 안 함)

### 7-3. 옵션 A 진입 흐름 (본 세션 메인 자율 영역)

1. **메인 자율 영역**:
   - 본 Draft 박제 완료 (`.claude/state/sprint-pay-p3-restart-plan-draft.md`)
   - PAY-P3-A 마스터 플랜 + AC BDD 박제 (이미 박제 완료, `.claude/state/sprint-pay-p3-a-race-condition-draft.md`)
   - sprint progress 영역 박제 (`reports/sprint-pay-p3-a-race-condition-progress.md`) — **PP-7 차단** → planner agent 위임 또는 사용자 직접 영역
   - 사용자 보고 (본 Draft 박제 결과 + 사용자 결정 영역 명시)

2. **사용자 직접 영역** (케이스 1 처리):
   - PP-13 우회 함수 복원 (line 60~63 영역에 `check_bypass_keyword` 함수 추가 + line 128 + 184 + 212 호출 추가)
   - PP-7 hook isSidechain 검출 디버깅:
     - Task tool 진입 시 stdin JSON `isSidechain` field 박제 검증
     - hook stdin JSON dump (debug) 추가 → 결함 본질 파악
     - 수정 (예: `pretooluse-edit-write-guard.sh:48-56` 검출 로직 보강 또는 `pretooluse-main-whitelist.sh:36-45` 검출 로직 보강)
   - PP-13 우회 함수 다시 제거 (영구 박제) 또는 우회 키워드 검사 함수만 유지 (영구 박제)

3. **메인 자율 영역** (재시도):
   - PAY-P3-A grimoire-server agent 위임 재시도 (Task tool subagent_type=grimoire-server)
   - agent 내부 Edit 통과 검증 (isSidechain=True 정합)
   - 코드 + spec + sensor + eval + shared-contracts §22 박제
   - qa Evaluator 위임 (Task tool subagent_type=grimoire-qa)
   - 메인 commit + push develop

---

## §8 변경 이력

### 8-1. 본 Draft 박제 (2026-05-09 #10_8 본 세션)

- **2026-05-09 #10_8 본 세션** (KST) — 본 Draft 박제 (`.claude/state/sprint-pay-p3-restart-plan-draft.md`, PP-13 메인 화이트리스트 우회 영역 박제). 입력 자료 5건:
  - `.claude/state/sprint-pay-p3-master-plan-draft.md` (마스터 플랜 13 섹션, 본 세션 5/8 박제) — 직접 Read
  - `.claude/state/sprint-pay-p3-a-race-condition-draft.md` (PAY-P3-A AC BDD 8건, 본 세션 5/8 박제) — 직접 Read
  - `.claude/scripts/pretooluse-main-whitelist.sh` (PP-13 hook, 본 세션 5/8 박제) — 직접 Read
  - `.claude/scripts/pretooluse-edit-write-guard.sh` (PP-7 hook, 본 세션 5/6+5/8 박제) — 직접 Read
  - `.claude/state/main-blocked-log.jsonl` + `.claude/state/edit-write-violation.jsonl` (본 세션 입증 결함 raw 박제) — 직접 Read

- **본 세션 사용자 명시 패턴 박제** (5/9):
  - 에이전트 위임 위주 진행 정합
  - 케이스 1 (agent 거부) + 케이스 2 (agent 메인 전가 + 도메인 정합) 처리 매트릭스 박제
  - 사용자 직접 영역 명시 (메인 권한 1개 열기 → agent 수정 → 메인 권한 닫기)

- **본 세션 입증 본질 결함 박제** (직접 raw 박제, 추정 0):
  - §1-1: PAY-P3-A grimoire-server agent isSidechain=False 검출 결함 (직접 박제 `edit-write-violation.jsonl:9` 2026-05-08T14:27:55Z)
  - §1-2: grimoire-infrastructure agent harness 메타 영역 정직 거부 (책임 영역 외부, 본 세션 5/8 후속 박제)
  - §1-3: grimoire-server agent `.claude/scripts/` 영역 정직 거부 (NestJS 외부, 직접 박제 `edit-write-violation.jsonl:4-7`)
  - §1-4: PP-7 / PP-12 / PP-13 자기 모순 누적 (메인 권한 차단 강제 시스템의 자기 차단, 누적 9건 박제)
  - §1-5: agent 위임 매커니즘 본질 좌절 입증

- **본 세션 추천 결정 박제**:
  - 옵션 A 권장 (PAY-P3-A 재시도 + 케이스 1 처리 영역 = 사용자 1회 직접 작업 + isSidechain 결함 디버깅)
  - 옵션 B/C/D 회피 본질 X (동일 결함 누적)

### 8-2. 본 Draft 정본 영역 이동 (사용자 결정 후)

- 사용자 결정 시 본 Draft (`.claude/state/`) → 정본 영역 (`reports/sprint-pay-p3-restart-plan.md`) 이동
- 정본 영역 이동은 사용자 직접 또는 grimoire-infrastructure agent 위임 영역 (`reports/` = `pretooluse-edit-write-guard.sh:90-94` 매핑 영역)
- 본 Draft 자체는 `.claude/state/` 영역 박제 (PP-13 화이트리스트 통과 영역, 메인 자율 박제 가능)

---

## 참조 (file:line)

### 본 Draft 직접 입력 자료 (5건, 직접 Read 박제)

- `.claude/state/sprint-pay-p3-master-plan-draft.md` (473 line, 13 섹션) — 마스터 플랜
- `.claude/state/sprint-pay-p3-a-race-condition-draft.md` (668 line, AC BDD 8건) — PAY-P3-A Sprint 계약
- `.claude/scripts/pretooluse-main-whitelist.sh` (222 line) — PP-13 hook
- `.claude/scripts/pretooluse-edit-write-guard.sh` (195 line) — PP-7 hook
- `.claude/state/main-blocked-log.jsonl` (line 1~19) + `.claude/state/edit-write-violation.jsonl` (line 1~9) — 본 세션 입증 결함 raw 박제

### 본 Draft 후속 영역 (사용자 결정 후)

- `reports/sprint-pay-p3-restart-plan.md` (정본 영역, 사용자 또는 infrastructure agent 위임 후 이동)
- `reports/sprint-pay-p3-a-race-condition-progress.md` (PAY-P3-A 재시도 sprint progress, server agent 진입 후 박제 영역)

### 핵심 코드 (server, PAY-P3-A 영역)

- `application/payment/payment.usecase.ts:147-160, 175-186, 264-301` (PAY-P3-A Edit 영역, 본 세션 5/8 차단)
- `adapter/outbound/persistence/prisma-payment.repository.ts:144-224` (PAY-P3-A Edit 영역, 본 세션 5/8 차단)
- `application/payment/refund-payment.usecase.ts:99-115` (호출자 정합)

### hook 영역 (사용자 직접 영역)

- `.claude/scripts/pretooluse-main-whitelist.sh:36-45` (isSidechain 검출 영역) — 케이스 1 처리 영역
- `.claude/scripts/pretooluse-edit-write-guard.sh:48-56` (isSidechain 검출 영역) — 케이스 1 처리 영역
- `.claude/scripts/pretooluse-edit-write-guard.sh:62-100` (PP-7 라우팅 매트릭스) — 케이스 2 처리 영역
- `.claude/scripts/pretooluse-edit-write-guard.sh:124-161` (사용자 우회 키워드 검사) — 1단어 명시 매커니즘 영역

### agent 정의 영역 (사용자 직접 영역)

- `.claude/agents/grimoire-server.md` — server agent 책임 영역 (NestJS / payment / admin 영역)
- `.claude/agents/grimoire-infrastructure.md` — infrastructure agent 책임 영역 (.claude/scripts/, .claude/skills/, .claude/agents/, .claude/settings.json, eval/scripts/, .githooks/)
- `.claude/agents/grimoire-planner.md` — planner agent 책임 영역 (sprint 계약 + AC BDD + reports/PLANNER_REPORT*)

### 관련 sprint 박제 영역 (본 Draft 후속)

- `reports/sprint-pay-p3-a-race-condition-progress.md` (PAY-P3-A 재시도)
- `reports/sprint-pay-p3-b-polar-timeout-progress.md` (PAY-P3-B)
- `reports/sprint-pay-p3-c-retry-dedupe-progress.md` (PAY-P3-C)
- `reports/sprint-pay-p3-d-status-enum-progress.md` (PAY-P3-D)
- `reports/sprint-pay-p3-e-fk-cascade-progress.md` (PAY-P3-E)
- `reports/sprint-pay-p3-h-circuit-breaker-progress.md` (PAY-P3-H)
- `reports/sprint-pay-p2-5-audit-retention-progress.md` (PAY-P2-5)

### shared-contracts 신설 영역 (본 Draft 후속)

- `.claude/shared-contracts.md §22~28` (PaymentRaceCondition + PolarTimeoutPolicy + RetryDeduplication + PaymentStatusEnum + PaymentFkCascade + CircuitBreaker + AuditRetention)

---

**상태**: 본 Draft 박제 완료 (`.claude/state/sprint-pay-p3-restart-plan-draft.md`, PP-13 화이트리스트 통과 영역). **다음 단계 = 사용자 결정 영역 (옵션 A/B/C/D 선택)**. 옵션 A 권장 = PAY-P3-A 재시도 + 케이스 1 처리 (사용자 1회 직접 작업 = PP-13 우회 함수 복원 + isSidechain 결함 디버깅 + 우회 함수 제거 또는 영구 박제). 사용자 명시 후 즉시 케이스 1 처리 진행 → PAY-P3-A 재시도 → 후속 sprint 일괄 통과. 본 Draft 자체는 PP-13 화이트리스트 통과 영역 (`.claude/state/`) 박제 완료, 정본 영역 (`reports/sprint-pay-p3-restart-plan.md`) 이동은 사용자 결정 영역.
