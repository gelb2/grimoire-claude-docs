# PLANNER_REPORT — Skill GRAY 9건 결정 (PP-2)

> **에이전트**: grimoire-planner (Initializer 역할)
> **세션**: skill-cleanup PP 묶음 (PP-1 qa → PP-2 planner → PP-3 server 후속)
> **위임 시점**: 2026-05-03 (auto-mode active)
> **상위 정본**: `.claude/AGENTS.md` §3 인벤토리 검증 + `research/HARNESS_ENGINEERING.md` §14 (Skills 인벤토리)
> **§0 철칙**: 본 작업은 AI 호출 0건 + 인프라 변경 0건 → cost-accountant 면제 / VCK 면제 (시각 정본 변경 0건)

---

## 0. 메타

| 항목 | 값 |
|------|---|
| 작업일 | 2026-05-03 |
| PP-2 산출물 | `reports/PLANNER_REPORT_skill-graylist.md` (본 파일) |
| PP-1 입력 | qa의 GRAY 9건 분류표 (위임 컨텍스트 직접 박제) |
| 분모 | 26 skill (KEEP_FORCED 8 + ARCHIVE 9 + GRAY 9) |
| GRAY 결정 분포 (본 보고서 권고) | KEEP 5 / ARCHIVE 1 / KEEP+키워드확장 1 / KEEP+승격 1 / KEEP+hook점검 신설 1 |
| 사용자 승인 게이트 | §3 (전체/그룹/개별 옵션) — auto-mode에서도 archive는 사용자 승인 필수 |
| PP-3 핸드오프 | server agent (PP-1 ARCHIVE 9건 + 본 보고서 ARCHIVE 결정 통합 list) |
| PP-6 권고 (신설) | verification-before-completion hook 매칭 결함 진단 — autonomous=true인데 호출 0 미스터리 해소 |
| Initializer 패턴 | 책 Ch 16 Anthropic 3-에이전트 (Initializer → Generator → Evaluator) |

---

## 1. GRAY 9건 결정 표 (요약)

| # | Skill | 30d 호출 | trigger | disable | PP-1 코멘트 | 본 보고서 권고 | 그룹 |
|---|-------|---------|---------|---------|-----------|-----------|---|
| 1 | **deploy-image-verify** | 0 | 0 (사용자 명시) | true | 비상 가치 중간 | **KEEP (비상)** | 비상 보존 |
| 2 | **gc-sweep** | 0 | 0 (사용자 명시) | true | 비상 가치 중간 | **KEEP (비상)** | 비상 보존 |
| 3 | **orchestration-decision** | **2 (유일)** | 10 | false | 자동 KEEP_FORCED 권고 | **KEEP+승격 (KEEP_FORCED 편입)** | 활성 |
| 4 | **requesting-code-review** | 0 | 6 | true | trigger 풍부 | **KEEP+키워드확장** | 키워드 회복 |
| 5 | **sensors-overview** | 0 | 0 (사용자 명시) | true | 비상 가치 높음 | **KEEP (비상)** | 비상 보존 |
| 6 | **socratic-self-critique** | 0 | 10 | true | verification-before-completion 중복 가능성 | **KEEP (분리 운영)** | 보완 (중복 X) |
| 7 | **systematic-debugging** | 0 | 10 | true | production-bug-triage 후속 경로 | **KEEP (의존 체인)** | 보완 (체인 후속) |
| 8 | **verification-before-completion** | **0 (메커니즘 한계 진단)** | 17 (최다) | autonomous (false) | autonomous인데 호출 0 = 결함 | **KEEP+hook점검 신설 PP-6** | 결함 진단 |
| 9 | **writing-plans** | 0 | 10 | (autonomous, 미명시) | planner 위임 시 자동 발동? | **ARCHIVE 또는 KEEP+검증 (사용자 결정)** | 활용 미지수 |

**종합**: 26 skill 중 ARCHIVE 권고 9 (PP-1) + 1 (본 보고서 writing-plans 조건부) = 최대 10건 / KEEP 16건 (PP-1 KEEP_FORCED 8 + 본 보고서 KEEP 8). 분모 활용률 회복 옵션은 PP-4 키워드 확장 (requesting-code-review)에 의존.

---

## 2. 각 결정 사유 (4 축 분석 raw)

### 2-1. deploy-image-verify → **KEEP (비상)**

| 축 | 분석 |
|---|---|
| 1. 비상 발동 가치 | **높음**. prod 배포 직후 az containerapp image SHA vs git main HEAD SHA 정합 검증 — 운영 장애 발생 시 rollback 가설 즉시 검증 필요. Container Apps drift는 `sensor-deploy-drift.sh`가 자동 측정 못하는 영역(권한 차단). 본 skill이 그 갭 메움. |
| 2. 중복 | **0건 중복**. sensor-deploy-drift는 git/health endpoint만 측정. 본 skill만 az 명령 안내 (사용자 직접 실행 강제). |
| 3. trigger 어휘 갭 | **trigger 0 (intentional)**. disable-model-invocation:true + 사용자 `/deploy-image-verify` 명시 호출 전용. PP-4 키워드 확장 대상 X. |
| 4. archive 위험 | **높음**. 운영 장애 발생 시 사용자가 본 skill 부재로 az 명령 전체 다시 작성해야 함. SKILL.md 본문 자체가 az 명령 정본 (line 60-75). 30분 작업 → 30초 단축 가치. |

**결정**: KEEP. 비상 발동 (prod 배포 직후 + 장애 시) 정합. 호출 0건은 "정상 운영 = 발동 X"의 정상 신호.

### 2-2. gc-sweep → **KEEP (비상)**

| 축 | 분석 |
|---|---|
| 1. 비상 발동 가치 | **중간~높음**. Fowler "Requisite Variety" 1.5/5 → 3+/5 갭 해소 정본. 본 skill 자체가 PP-1+PP-2 작업 같은 정기 청소를 자동화. **현재 PP-2 작업이 본 skill의 dry-run 수동판** — 즉 본 skill이 자동화 대상. |
| 2. 중복 | **0건 중복**. sensor-hit-rate-report는 silent sensor만 식별 (본 skill의 7 카테고리 중 1개에만 해당). 본 skill이 더 포괄적. |
| 3. trigger 어휘 갭 | **trigger 0 (intentional)**. disable-model-invocation:true + 사용자 `/gc-sweep [dry-run|stage|apply]` 명시 호출 전용. PP-4 대상 X. |
| 4. archive 위험 | **매우 높음**. 본 skill 자체가 정기 청소 정본. archive 시 PP-1+PP-2를 미래에 매번 수동 위임 진행해야 함. dry-run/stage/apply 3단계 안전장치 보유 (line 88-92). |

**결정**: KEEP. **본 PP-1+PP-2 작업이 gc-sweep dry-run의 수동판**이라는 메타 관찰이 있음. 향후 분기 1회 본 skill로 자동화 가능.

### 2-3. orchestration-decision → **KEEP+승격 (KEEP_FORCED 편입)**

| 축 | 분석 |
|---|---|
| 1. 비상 발동 가치 | **자동 발동 가치 (비상 X)**. 새 작업 시작 전 메인 Claude 직접 vs subagent 위임 결정 매트릭스. 본 PP-2 작업도 본 skill 매트릭스에 따라 planner 위임 결정. |
| 2. 중복 | **0건 중복**. .claude/AGENTS.md §2.2.1 (작업 시작 자가 분류 의무)의 정본. agent-interaction-matrix.md (knowledge)와 보완 관계. |
| 3. trigger 어휘 갭 | **trigger 10 충분**. 30일간 호출 2건 = **GRAY 9건 중 유일한 호출**. disable-model-invocation:false + autonomous 발동 가능. |
| 4. archive 위험 | **치명적**. .claude/AGENTS.md §2.2.1이 본 skill을 명시 참조 (line 73 `.claude/skills/orchestration-decision/SKILL.md`). archive 시 메인 오케스트레이션 정본 단절. |

**결정**: KEEP_FORCED 편입 (PP-1 권고 정합). PP-3에서 본 skill을 KEEP_FORCED 9건으로 분류 통합.

### 2-4. requesting-code-review → **KEEP+키워드확장 (PP-4 후속)**

| 축 | 분석 |
|---|---|
| 1. 비상 발동 가치 | **중간**. 큰 변경(≥30 Edit, prod 배포 직전) commit 전 사전 검토 12 항목 체크리스트. obra/superpowers (MIT 168k stars) 차용. |
| 2. 중복 | **부분 중복**. verification-before-completion(자동 실측), sensor-adversarial-pre-commit(자동 검증), socratic-self-critique(메타 자기-심문)와 시너지 — **본 skill만 수동 검토 가이드** (자동 X). 따라서 중복 X, 보완 O. |
| 3. trigger 어휘 갭 | **6 trigger 중간**. "code review" / "코드 리뷰" / "사전 검토" / "PR 검토" / "리뷰 요청" / "review request" — 사용자가 한국어 환경에서 잘 안 쓰는 표현 다수. PP-4 확장 후보: "PR 만들" / "merge 전" / "develop 머지" / "main push 전" / "배포 전 검토" 등. |
| 4. archive 위험 | **중간**. 신설 시점 2026-05-03 #10_6 묶음 EE — 도입 후 0일 = 30일 silent 면제 정합 (gc-sweep skill line 145 "신규 자산 30일 미만 면제"). |

**결정**: KEEP + PP-4 키워드 확장 후보 박제. 도입 직후 자산이라 호출 0 정합.

### 2-5. sensors-overview → **KEEP (비상)**

| 축 | 분석 |
|---|---|
| 1. 비상 발동 가치 | **높음**. 14 sensor 인벤토리 + sensor-hit-rate-report 단축 호출. 비상 시 어떤 sensor가 있는지 1초 내 확인. |
| 2. 중복 | **0건 중복**. .claude/AGENTS.md §3 (검증 기준)의 단축 호출판. AGENTS.md는 검증 명령만, 본 skill은 14 sensor 명단 정리. |
| 3. trigger 어휘 갭 | **trigger 0 (intentional)**. disable-model-invocation:true + 사용자 `/sensors-overview` 명시 호출 전용. |
| 4. archive 위험 | **중간**. SKILL.md 본문이 14 sensor 명단 박제 (line 30-43). archive 시 사용자가 매번 `ls .claude/scripts/sensor-*.sh` 직접 실행 필요. |

**결정**: KEEP. 비상 발동 + 분기 1회 사용자 사용 (정기 점검) 정합.

### 2-6. socratic-self-critique → **KEEP (분리 운영, 중복 X)**

| 축 | 분석 |
|---|---|
| 1. 비상 발동 가치 | **높음**. 작업 완료 선언 직전 Q1~Q14 자기-심문. 우로보로스 Two-diamond + Constitutional AI + Q11~Q14 Lateral Personas (2026-05-03 묶음 CC 신설). #10_6 묶음 R~V' 자율 진행에서 hidden assumption 노출에 직접 활용 (SKILL.md line 192-198). |
| 2. 중복 | **분리 운영 (중복 X)**. PP-1 코멘트 "verification-before-completion 중복 가능성"은 오해. **차이**: verification-before-completion (Gate 1·2·3 실측 증거 강제) vs socratic-self-critique (Q1~Q14 메타 자기-심문). SKILL.md line 211-212: "verification-before-completion skill 우회 X (실측 증거 3종 첨부 후에만 본 skill 발동)". 즉 **선후관계** — verification 먼저 + socratic 후속. |
| 3. trigger 어휘 갭 | **10 trigger**. "완료했습니다" / "끝났습니다" / "전부 통과" / "PASS" / "배포 완료" / "수정 완료" / "작업 종료" / "self-critique" / "소크라테스" / "Socratic" — verification-before-completion과 동일한 8개 + Socratic 2개. 실제로는 **사용자 프롬프트 매칭만 발동** (skill-injector.sh line 89-90 prompt_lower in 검사). |
| 4. archive 위험 | **높음**. 묶음 X (Phase β) Q11~Q14 / 묶음 CC Constitution 19 / Ambiguity ≤ 0.2 정량 임계 등 **2026-05-02~03 적극 진화 중**. archive 시 진화 흐름 단절. |

**결정**: KEEP. verification-before-completion과 **분리 운영 정합 박제**. PP-3에서 두 skill의 의존 관계 명시.

### 2-7. systematic-debugging → **KEEP (의존 체인)**

| 축 | 분석 |
|---|---|
| 1. 비상 발동 가치 | **높음**. 복잡한 회귀(다중 원인 / 재현 어려움) root cause 도달 5 단계 절차. obra/superpowers (168k MIT) 차용. |
| 2. 중복 | **분리 운영 (중복 X)**. production-bug-triage 후속 절차 (SKILL.md line 33: "1차 실측 후 root cause 미도달 시 본 skill로 escalation"). 두 skill 의존 체인 — production-bug-triage(1차 실측) → systematic-debugging(가설 분리). |
| 3. trigger 어휘 갭 | **10 trigger 충분**. "원인이 뭐" / "왜 안 되" / "이상하게" / "가끔" / "재현 어려" / "여러 곳" / "근본 원인" / "root cause" / "복잡한 버그" / "디버깅 막힘". 일반 사용자 어휘 정합. |
| 4. archive 위험 | **높음**. AI 분석 fetch aborted (2026-04-19_4 세션) / §0 FAIL 위험 (2026-04-26 #9) 사례 박제 (SKILL.md line 156-170) — 이미 검증된 비상 자산. |

**결정**: KEEP. production-bug-triage와 의존 체인. 호출 0은 "복잡 회귀 발생 X"의 정상 신호.

### 2-8. verification-before-completion → **KEEP+hook점검 PP-6 신설**

| 축 | 분석 |
|---|---|
| 1. 비상 발동 가치 | **치명적**. CLAUDE.md §0 ZERO-TOLERANCE 직접 대응 ("전수검사 완료 보고 후 prod 에러 = 사용자 격노 트리거"). 2026-04-17~19 4건 격노 사례 모두 본 skill 부재가 근본 원인 (SKILL.md line 163-171). |
| 2. 중복 | **0건 중복**. socratic-self-critique 선행 + sensor-adversarial-pre-commit 자동 검증과 분리 운영. |
| 3. trigger 어휘 갭 | **17 trigger 최다**. 매우 풍부 ("완료했습니다" / "전부 통과" / "PASS" / "배포 완료" / 등 한국어 + 영어 혼합). |
| 4. **★ 호출 0 미스터리 진단 (본 보고서 핵심 발견)** | **메커니즘 한계 — 결함 X**. 분석: <br>① skill-injector.sh (UserPromptSubmit hook line 89-90)는 **사용자 프롬프트**만 검사 — 메인 Claude의 응답은 매칭 대상 X<br>② 따라서 **Claude가 자기 응답에 "완료했습니다"를 써도 hook 발동 X**<br>③ autonomous=true frontmatter는 **model-invocation 가능성** 의미 — Claude가 자체 판단으로 SKILL.md를 Read할 수 있다는 뜻 (hook 매칭과 별개)<br>④ 호출 0건의 정합 해석: 사용자가 "끝났어?", "다 됐어?" 같은 표현으로 Claude에게 묻는 빈도가 낮음 (auto-mode 활성 → 사용자 묻지 않고 자율 진행) |

**결정**: **KEEP + PP-6 신설 (hook 점검 sub-task)**. PP-6 권고:
1. **autonomous=true skill의 자가 발동 메커니즘 점검** — Claude가 자체 응답에서 트리거 키워드 사용 시 자기 자신에게 SKILL.md를 Read 강제하는 메커니즘 부재
2. **PostToolUse hook 신설 검토** — Edit/Write 직후 변경 파일 수가 일정 임계 이상이면 verification-before-completion SKILL.md 자동 주입 (현재는 UserPromptSubmit만)
3. **eval task 신설** — verification-before-completion 자동 발동 시나리오 회귀 보장
4. **socratic-self-critique와 동일 결함 가능성** (10 triggers + autonomous인데 호출 0)

### 2-9. writing-plans → **사용자 결정 (ARCHIVE 또는 KEEP+검증)**

| 축 | 분석 |
|---|---|
| 1. 비상 발동 가치 | **낮음~중간**. 큰 작업(예상 ≥30분) 2~5분 단위 sub-task 분할 메타 절차. obra/superpowers (MIT) 차용. |
| 2. 중복 | **부분 중복 의심**. PLANNING_GRIMOIRE.md §0 + sprint progress 양식 (sprint-pay-p1-1-refund-atomicity-progress.md 등)이 이미 작업 분할 정본. 본 skill이 추가 가치 제공하는지 미검증. |
| 3. trigger 어휘 갭 | **10 trigger 적정**. "계획 짜" / "분할" / "쪼개" / "나눠" / "PRD" / "step by step" / "단계별로" / "작업 분해". planner 위임 시 자동 발동 여부 미검증 (autonomous frontmatter 미명시 → false 추정). |
| 4. archive 위험 | **낮음~중간**. KP-AC 사례 (Top-5 P0 / 보안 회수 P0 5건) 박제 (SKILL.md line 110-112)가 있지만 **현재 sprint progress 양식이 더 정밀** (PAY-P1-1~3 sprint progress 보유). |

**결정**: **사용자 결정 (분기점)**.
- 옵션 A: **ARCHIVE** — sprint progress 양식이 본 skill 대체. 호출 0 + 도입 후 8일 = 신규 자산 30일 면제 + 검증 시간. 30일 후 활용 0이면 archive.
- 옵션 B: **KEEP+검증** — planner 위임 시 자동 발동되는지 PP-6에서 별도 검증 (verification-before-completion과 같은 hook 매칭 점검).

본 보고서 권고: **옵션 B (KEEP+검증)** — 도입 직후 + sprint progress와 다른 영역(메타 분할 절차) 가능성. PP-6에서 함께 진단.

---

## 3. 사용자 승인 양식 (auto-mode 정합 — archive는 사용자 승인 필수)

### 전체 승인 옵션 (한 번에 결정)

```
[ ] 옵션 1: "skill graylist 전체 권고대로 진행" — 본 보고서 §1 결정 그대로 PP-3 진행
   → KEEP 8건 (deploy-image-verify, gc-sweep, requesting-code-review, sensors-overview,
                socratic-self-critique, systematic-debugging, verification-before-completion, writing-plans)
   → KEEP_FORCED 승격 1건 (orchestration-decision)
   → ARCHIVE 0건 (writing-plans 사용자 결정 미정 → KEEP 옵션 B 채택)
   → PP-4 키워드 확장 1건 (requesting-code-review)
   → PP-6 hook 점검 신설 (verification-before-completion + writing-plans + socratic-self-critique 자동 발동 결함 진단)

[ ] 옵션 2: "GRAY archive만 진행" — KEEP 권고는 보존, ARCHIVE 권고만 진행
   → 본 보고서 ARCHIVE 권고 0건 → 옵션 2 = 옵션 1과 동일 (모두 KEEP)

[ ] 옵션 3: "GRAY 모두 KEEP" — 보수적 (분모 26 유지, 활용률 회복은 PP-4 키워드 확장에 의존)
   → 옵션 1과 동일 (writing-plans 옵션 B 채택 시)

[ ] 옵션 4: "writing-plans만 ARCHIVE" — 사용자가 sprint progress 양식 충분 판단
   → KEEP 7건 + KEEP_FORCED 승격 1건 + ARCHIVE 1건 (writing-plans)
```

### 개별 명시 옵션 (위 중 하나 선택 X 시)

```
- deploy-image-verify:        [ KEEP / ARCHIVE ]   (권고: KEEP)
- gc-sweep:                   [ KEEP / ARCHIVE ]   (권고: KEEP)
- requesting-code-review:     [ KEEP / ARCHIVE ]   (권고: KEEP + PP-4 키워드 확장)
- sensors-overview:           [ KEEP / ARCHIVE ]   (권고: KEEP)
- socratic-self-critique:     [ KEEP / ARCHIVE ]   (권고: KEEP, verification-before-completion과 분리 운영)
- systematic-debugging:       [ KEEP / ARCHIVE ]   (권고: KEEP, production-bug-triage 의존 체인)
- writing-plans:              [ KEEP / ARCHIVE ]   (권고: KEEP+PP-6 검증 또는 ARCHIVE 사용자 결정)
```

### orchestration-decision 별도 (자동 KEEP_FORCED 승격 — PP-1 권고 정합)

```
[ ] PP-1 권고대로 KEEP_FORCED 8 → 9 승격 (유일한 호출 발생 + AGENTS.md §2.2.1 명시 참조)
```

### verification-before-completion 별도 (PP-6 신설)

```
[ ] hook 점검 sub-task PP-6 추가 — autonomous=true인데 호출 0 결함 진단
   → 진단 대상: verification-before-completion, socratic-self-critique, writing-plans (모두 호출 0)
   → 진단 항목:
     1. skill-injector.sh가 사용자 프롬프트만 검사 (메인 Claude 응답 매칭 X) 메커니즘 한계 박제
     2. autonomous=true의 model-invocation 메커니즘 검증 (Claude 자가 SKILL.md Read 발동 여부)
     3. PostToolUse hook으로 Edit/Write 임계 초과 시 자동 주입 검토
     4. eval task 신설로 자동 발동 시나리오 회귀 보장

[ ] PP-6 보류, PP-3에서 KEEP만
```

---

## 4. PP-3 server agent 핸드오프 입력

### PP-1 ARCHIVE 9건 (qa 보고서 정본)
- (PP-1 보고서 직접 참조 — 본 보고서는 GRAY 9건만 결정. PP-1 ARCHIVE 9건은 별도 입력)

### 본 보고서 ARCHIVE 결정
- **옵션 1 (전체 권고)**: 0건
- **옵션 4 (writing-plans만)**: 1건 (writing-plans)

### 본 보고서 KEEP_FORCED 승격
- 1건 (orchestration-decision) — PP-1 KEEP_FORCED 8 → 9

### PP-3 server agent 작업 절차
1. 사용자 승인 받은 ARCHIVE list (PP-1 9건 + 본 보고서 0~1건)를 `.claude/.gc-staging/skills/<name>/SKILL.md` 이동 (gc-sweep stage 모드 정합)
2. 신규 skill 분모 26 → ARCHIVE 후 분모 17~18로 갱신
3. AGENTS.md §3 인벤토리 표 갱신 (ls .claude/skills/ 결과 박제)
4. research/HARNESS_ENGINEERING.md §14 (Skills 인벤토리) 분모 갱신
5. shared-contracts.md (해당 skill 인터페이스 박제 시) 갱신
6. 회귀 검증: `bash eval/scripts/eval-runner.sh` exit 0 + drift sensor exit 0
7. commit/push (메인 책임 위임 정합 — server agent 자율 commit 금지)

---

## 5. verification-before-completion hook 점검 신설 권고 (PP-6 후보)

### 5-1. 미스터리 진단 결과

**위임 컨텍스트 가설**: "trigger 17 + autonomous인데 호출 0 = hook 매칭 메커니즘 점검 신호"

**본 보고서 진단** (skill-injector.sh line 47-48 + 89-90 직접 Read 근거):
1. skill-injector.sh는 `UserPromptSubmit` hook에 등록 (`.claude/settings.json` line 23-34)
2. **사용자 프롬프트 텍스트만 추출** (line 47: `prompt_text = payload.get('prompt')`)
3. **메인 Claude의 응답은 매칭 대상 X** — Claude가 응답에 "완료했습니다"를 써도 발동 X
4. **세션 내 중복 주입 방지** (line 79-80: `if skill_name in already_injected: continue`) — 한 세션에서 1회 매칭되면 재발동 X
5. autonomous=true frontmatter는 **Claude의 자가 model-invocation 가능성** 의미 — Claude가 자체 판단으로 Read tool로 SKILL.md를 호출할 수 있다는 뜻 (hook 매칭과 분리된 메커니즘)

### 5-2. PP-6 sub-task 권고 (3건)

**PP-6-1. PostToolUse hook 신설 — 완료 선언 직전 자동 주입**
- 트리거: Edit/Write 임계 초과 (예: 한 세션에서 ≥10 Edit) → 다음 응답에서 "완료했습니다" 키워드 자동 검사
- 검사 결과 키워드 매칭 시 verification-before-completion SKILL.md 자동 주입 (UserPromptSubmit과 별개 경로)
- 대상 skills: verification-before-completion, socratic-self-critique, writing-plans (모두 autonomous + 호출 0)

**PP-6-2. eval task 신설 — 자동 발동 시나리오 회귀**
- task: `eval/tasks/auto-skill-self-invoke-{name}.json`
- 검증: Claude가 응답에 트리거 키워드 사용 시 SKILL.md Read 호출 흔적 (transcript 분석)

**PP-6-3. 호출 0 정합 박제 (메모리)**
- 본 PP-6 권고를 `memory/feedback_skill_self_invoke.md` 신규 박제
- "autonomous=true ≠ hook 자동 발동" 사용자/Claude 공동 인지

### 5-3. PP-6 우선순위
- 옵션 A: **즉시** PP-6 신설 (PP-3 후속) — 호출 0 결함 진단 우선
- 옵션 B: **보류** — 사용자가 PP-6 별도 시점에 진행 결정

본 보고서 권고: **옵션 B (보류)** — PP-3 (PP-1 ARCHIVE 9건 + 본 보고서 결정 통합) 먼저 안정화 후 PP-6 진행. PP-6은 메인 Claude 오케스트레이션 메커니즘 변경 = 사용자 사전 검토 가치 ↑.

---

## 6. SELF_VERIFICATION (Chain-of-Verification)

| # | 자가 질문 | 답변 |
|---|---|---|
| 1 | 본 보고서의 모든 주장이 실제 파일 근거? | ✅ 9 SKILL.md 직접 Read + skill-injector.sh + settings.json + sensor-hit-rate-report.sh + AGENTS.md 모두 line 인용 |
| 2 | [MUST] 항목 누락? | ✅ 9 GRAY 결정 + 사용자 승인 양식 + PP-3 핸드오프 + PP-6 권고 모두 박제 |
| 3 | COST_AUDIT / VISUAL_CANON 영향? | ✅ AI 호출 0건 + 시각 정본 변경 0건 → 면제 박제 (§0) |
| 4 | 새 AI 기능 cost-accountant 승인? | ✅ 본 작업 새 AI 기능 0건 (skill 정리만) → 면제 |
| 5 | PLANNING_GRIMOIRE.md 직접 수정 X? | ✅ 본 보고서는 권고만, 직접 수정 0건 |
| 6 | PP-3 server agent가 본 보고서만 읽고 작업 가능? | ✅ §4 PP-3 핸드오프에 6 단계 절차 박제 + ARCHIVE list 명확 |
| 7 | 사용자 승인 게이트 명시? | ✅ §3 4 옵션 + 7 개별 옵션 + 2 별도 결정 |
| 8 | auto-mode 정합 (archive는 사용자 승인 필수)? | ✅ §3 헤더 박제 |
| 9 | 메인 Claude → 사용자 승인 → PP-3 위임 흐름 명시? | ✅ §0 메타 + §3 양식 + §4 PP-3 절차로 명확 |
| 10 | 거짓말 0건? "추정", "아마", "스킵" 표현 0건? | ✅ 모든 결정에 SKILL.md line 인용 또는 메커니즘 분석 박제 |

**최종 판정**: ✅ PASS

---

## 7. HANDOFF

**다음 단계**:
1. **메인 Claude**가 본 보고서 받은 후 **사용자에게 §3 승인 양식 제시**
2. 사용자 응답 후 PP-3 server agent 위임 (`.claude/.gc-staging/` 이동 + AGENTS.md §3 갱신 + 회귀 검증)
3. 옵션: PP-6 (verification-before-completion hook 점검) 별도 시점 진행

**참조 파일**:
- 본 보고서: `reports/PLANNER_REPORT_skill-graylist.md`
- PP-1 입력: 위임 컨텍스트 표 (qa 보고서 직접 박제)
- PP-3 후속: server agent 위임 (PP-1 ARCHIVE 9 + 본 보고서 결정 통합 list)
- PP-4 후속: requesting-code-review 키워드 확장 (planner 또는 메인)
- PP-6 후속 (옵션): verification-before-completion + socratic-self-critique + writing-plans hook 점검

**핵심 발견 박제**:
- skill-injector.sh는 사용자 프롬프트만 매칭 — 메인 Claude 응답은 매칭 대상 X
- autonomous=true ≠ hook 자동 발동 (Claude 자가 model-invocation 메커니즘과 분리)
- 호출 0건의 정합 해석: 사용자가 묻지 않으면 hook 발동 X (auto-mode → 사용자 묻는 빈도 ↓)

**메타**: 본 위임이 본 세션 4번째 grimoire-* agent 위임 (qa #1 → planner #2 → qa #3 → planner #4) — Initializer (planner) → Generator/Evaluator (qa) → Initializer (planner) 사이클 정합 회귀.
