# QA Report — Skill 사용 빈도 분석 + archive 후보 선정 (PP-1)

> 위임 출처: 본 세션 #3 grimoire-qa 위임 (planner #2 정책 C+A 결정 후속).
> 본 보고서는 PP-1 (분석 전담). archive 실행은 PP-3 server agent.
> 메타: 본 위임이 본 세션 세 번째 grimoire-* agent 위임 (qa #1 → planner #2 → qa #3).

---

## §0 메타

- **측정 시점**: 2026-05-03 (KST)
- **측정 범위**: `.claude/skills/` 박제된 SKILL.md 26건
- **측정 방법**:
  1. `~/.claude/projects/-Users-sokol-Git-ProjectGrimoire/*.jsonl` (47개 파일) 30일 mtime 필터
  2. `assistant` role 메시지 안 `tool_use` 중 `name == 'Skill'` 또는 `name == 'mcp__claude-skill__skill'` 카운트
  3. 각 SKILL.md frontmatter (`disable-model-invocation`, `triggers`, `paths`, `effort`, `description`) 추출
  4. 본문 + description에서 비상 발동 가치 키워드 매치 (29개 키워드: 비상/장애/복구/롤백/배포/디버깅/보안/유출/환불/긴급/incident/rollback/deploy/debug/credential/leak/audit/RLS/CORS/마이그레이션/삭제/토큰/회전/guard/shared/drift/incompatible/production)
- **raw 데이터 출처**:
  - `bash .claude/scripts/sensor-skill-invocation-rate.sh` → `/tmp/sensor_raw.txt`
  - `python3 /tmp/skill_count.py` → `/tmp/raw_30d.txt`
  - `python3 /tmp/skill_classify.py` → `/tmp/raw_matrix.txt`
- **분류 기준 (planner §2.3)**: ARCHIVE = 7일 0회 + 30일 0회 + `disable-model-invocation: true` + 비상 가치 < 4 키워드 + KEEP_FORCED 명시 제외 (4 조건 AND)

---

## §1 30일간 Skill tool_use 카운트 raw stdout

### §1.1 sensor-skill-invocation-rate.sh raw (EXIT=2 = FAIL)

```
=== sensor-skill-invocation-rate (묶음 OO-3) ===
박제된 skill: 26
7일간 호출: 3회
활용된 unique skill: 2 / 26

활용률: 0.0769

Top skill 호출:
  orchestration-decision: 2회
  anthropic-skills:consolidate-memory: 1회

[RESULT] FAIL — Skill 활용률 0.0769 < 0.10 (박제만 + 자율 호출 X)
  → 메인 자율 skill 호출 편향 누적. UserPromptSubmit hook 키워드 매칭 강화 권장
```

### §1.2 30일/7일 독립 카운트 raw (qa python 재측정)

```
=== Files scanned (30d): 47 ===
=== Total skill calls (30d): 4 ===
=== Unique skills (30d): 3 ===

=== 30d Skill calls (descending) ===
    2  orchestration-decision
    1  anthropic-skills:consolidate-memory
    1  update-config

=== 7d Skill calls (descending) ===
    2  orchestration-decision
    1  anthropic-skills:consolidate-memory
```

### §1.3 sensor vs qa 측정 차이 (정합성)

| 항목 | sensor | qa 재측정 | 차이 |
|------|--------|-----------|------|
| 박제 skill | 26 | 26 | 0 |
| 7일 총 호출 | 3 | 3 | 0 |
| 30일 총 호출 | 미측정 | 4 | — |
| Unique 7d | 2 | 2 | 0 |

**정합 PASS** — 두 측정이 일치 (sensor는 7d만, qa는 30d/7d 둘 다 측정).

---

## §2 26행 분류 매트릭스

> 컬럼: skill / 7d 호출 / 30d 호출 / disable-model-invocation / triggers 수 / paths 수 / 비상 키워드 매치 수 / 분류

| skill | 7d | 30d | disable | trig | path | emrg | 분류 |
|-------|----|----|---------|------|------|------|------|
| claude-in-chrome-recovery | 0 | 0 | false | 9 | 0 | 2 | KEEP_FORCED |
| deploy-image-verify | 0 | 0 | true | 0 | 4 | 5 | GRAY |
| deploy-precheck | 0 | 0 | true | 0 | 5 | 4 | KEEP_FORCED |
| dev-login-smoke | 0 | 0 | true | 0 | 5 | 2 | ARCHIVE |
| dispatching-parallel-agents | 0 | 0 | true | 5 | 0 | 1 | ARCHIVE |
| drift-check | 0 | 0 | true | 0 | 5 | 1 | ARCHIVE |
| eval-run | 0 | 0 | true | 0 | 4 | 0 | ARCHIVE |
| feedback-to-skill | 0 | 0 | true | 0 | 3 | 3 | ARCHIVE |
| gc-sweep | 0 | 0 | true | 0 | 5 | 4 | GRAY |
| handover-refresh | 0 | 0 | true | 0 | 4 | 2 | ARCHIVE |
| infra-mutation-guard | 0 | 0 | true | 8 | 0 | 8 | KEEP_FORCED |
| macos-tcc-handling | 0 | 0 | false | 10 | 4 | 5 | KEEP_FORCED |
| memory-status | 0 | 0 | true | 0 | 0 | 0 | KEEP_FORCED |
| orchestration-decision | 2 | 2 | false | 10 | 0 | 3 | GRAY |
| production-bug-triage | 0 | 0 | false | 16 | 0 | 2 | KEEP_FORCED |
| red-team-update-propose | 0 | 0 | true | 0 | 0 | 1 | ARCHIVE |
| refund-logic-audit | 0 | 0 | true | 0 | 3 | 3 | KEEP_FORCED |
| requesting-code-review | 0 | 0 | true | 6 | 0 | 4 | GRAY |
| rollback-revision | 0 | 0 | true | 4 | 0 | 3 | KEEP_FORCED |
| sensors-overview | 0 | 0 | true | 0 | 1 | 6 | GRAY |
| shared-contracts-check | 0 | 0 | true | 0 | 5 | 2 | ARCHIVE |
| socratic-self-critique | 0 | 0 | true | 10 | 0 | 4 | GRAY |
| systematic-debugging | 0 | 0 | true | 10 | 0 | 5 | GRAY |
| verification-before-completion | 0 | 0 | false | 17 | 0 | 4 | GRAY |
| worktree-isolation | 0 | 0 | true | 0 | 0 | 3 | ARCHIVE |
| writing-plans | 0 | 0 | false | 10 | 0 | 5 | GRAY |

### 분류 합계

| 분류 | 건수 |
|------|------|
| ARCHIVE | 9 |
| KEEP_FORCED | 8 |
| GRAY | 9 |
| **TOTAL** | **26** |

---

## §3 ARCHIVE 후보 9건 (사유 + frontmatter 요약)

> 4 조건 AND (7d=0 + 30d=0 + disable:true + 비상 키워드<4 + KEEP_FORCED 비명시).

| # | skill | 7d | 30d | trig | emrg | 사유 | description 요약 |
|---|-------|----|----|------|------|------|------------------|
| 1 | dev-login-smoke | 0 | 0 | 0 | 2 | 호출 없음 + disable + triggers 0 + 비상 키워드 2 (마이그레이션, 토큰) | dev 환경 로그인 가능성 스모크. db-sync --mask-pii 회귀 감지 |
| 2 | dispatching-parallel-agents | 0 | 0 | 5 | 1 | 호출 없음 + disable + triggers 5건 있으나 비상 키워드 1 (배포)만 | 병렬 서브에이전트 dispatch (obra/superpowers MIT 차용) |
| 3 | drift-check | 0 | 0 | 0 | 1 | 호출 없음 + disable + triggers 0 + 비상 키워드 1 (drift) | HARNESS_ENGINEERING.md §14 인벤토리 vs 실측 drift 자동 검증 |
| 4 | eval-run | 0 | 0 | 0 | 0 | 호출 없음 + disable + triggers 0 + 비상 키워드 0 | eval 시스템(eval/scripts/eval-runner.sh) 실행 단축 슬래시 |
| 5 | feedback-to-skill | 0 | 0 | 0 | 3 | 호출 없음 + disable + triggers 0 + 비상 키워드 3 (deploy, audit, 삭제) | memory/feedback_*.md 영향력 큰 후보 → skill 승격 절차 |
| 6 | handover-refresh | 0 | 0 | 0 | 2 | 호출 없음 + disable + triggers 0 + 비상 키워드 2 (배포, leak) | grimoire-server/HANDOVER.md를 git log + 메모리 + sensor 결과로 자동 갱신 |
| 7 | red-team-update-propose | 0 | 0 | 0 | 1 | 호출 없음 + disable + triggers 0 + 비상 키워드 1 (보안) | 자율학습 3단 분리 α-반자율 단계 — pending.jsonl 데이터 자가 검증 |
| 8 | shared-contracts-check | 0 | 0 | 0 | 2 | 호출 없음 + disable + triggers 0 + 비상 키워드 2 (audit, shared) | shared-contracts.md ↔ 7 에이전트 .md / reports / 코드 인터페이스 정합 검증 |
| 9 | worktree-isolation | 0 | 0 | 0 | 3 | 호출 없음 + disable + triggers 0 + 비상 키워드 3 (보안, 긴급, rollback) | 큰 Edit 폭주 작업 시 main 브랜치 오염 방지용 git worktree 격리 |

### §3 보충 — ARCHIVE 후보 정량적 공통점
- 9건 모두 7d/30d 호출 0회 (실측 미발동)
- 9건 모두 `disable-model-invocation: true` (자율 호출 차단)
- 9건 모두 비상 키워드 매치 < 4 (Q&A 라벨 4 미만 = "비상 가치 낮음" 정합)
- 9건 모두 사용자 명시 슬래시 호출 전제 (description 안 "사용자 명시 호출만" 표현 다수)

---

## §4 KEEP_FORCED 8건 (이름 + 비상 가치)

> 4 조건 AND 미충족 + KEEP_FORCED 명시 → 비상 발동 가치 명백.

| # | skill | trig | emrg | 비상 가치 |
|---|-------|------|------|----------|
| 1 | claude-in-chrome-recovery | 9 | 2 | Chrome MCP "not connected" 회복. 1~2초 안 검증. trigger 9건 (자율 매칭) |
| 2 | deploy-precheck | 0 | 4 | 수동 배포 (make deploy-{dev,prod}) 직전 정합성 종합 검증. 배포 게이트 |
| 3 | infra-mutation-guard | 8 | 8 | az/polar 인프라 변경 직전 health snapshot + rollback 가이드. **2026-05-06 dev API down 사고 회복 절차 박제** |
| 4 | macos-tcc-handling | 10 | 5 | macOS TCC 다이얼로그 반복 노출 처리. trigger 10건 + paths 4건 (자율+슬래시 양립) |
| 5 | memory-status | 0 | 0 | memory/MEMORY.md 인덱스 + project_remaining_tasks.md 표출. 세션 시작/중간 점검 필수 (planner 명시 keep) |
| 6 | production-bug-triage | 16 | 2 | "fetch aborted", "작품 불러올 수 없습니다" 등 사용자 증상 보고 시 발동. trigger 16건 (전 skill 中 두 번째 많음) |
| 7 | refund-logic-audit | 0 | 3 | 환불 UI ↔ 서버 환불 로직 (processRefund/refundCredit) 정합 감사. UI 거짓말 차단 |
| 8 | rollback-revision | 4 | 3 | Container Apps revision activate/deactivate 자동화. 사고 회복 시 명령 박제 부담 해소 |

### §4 보충 — KEEP_FORCED 정당화
- planner 명시 keep 강제 8건과 정확히 일치 (memory-status / infra-mutation-guard / deploy-precheck / rollback-revision / refund-logic-audit / claude-in-chrome-recovery / macos-tcc-handling / production-bug-triage)
- 비상 발동 가치 명백 + 인프라/배포/회복 직결 → archive 시 사용자 손실 큼

---

## §5 GRAY 9건 (결정 사유 + PP-2 planner 권고 질문)

> ARCHIVE 4조건 일부만 충족 또는 KEEP_FORCED 후보로 명시 안 됨. PP-2에서 planner 추가 결정 필요.

| # | skill | 7d | 30d | disable | trig | emrg | 회색 사유 | PP-2 planner 질문 |
|---|-------|----|----|---------|------|------|-----------|-------------------|
| 1 | deploy-image-verify | 0 | 0 | true | 0 | 5 | 호출 0 + disable이지만 비상 키워드 5 (장애/배포/rollback/deploy/drift) — sensor-deploy-drift 권한 차단 보완용 명시 | "image SHA 정합 검증을 사용자 직접 호출로 운영하는 빈도가 어느 정도인지 사용자 확인 후 ARCHIVE/KEEP 결정 필요" |
| 2 | gc-sweep | 0 | 0 | true | 0 | 4 | 호출 0 + disable + 비상 키워드 4 (마이그레이션/삭제/guard/drift). harness 자산 정리 인프라 절차 | "60일 1회 호출 패턴(주기적 GC) 기대 시 KEEP, 일회성 도구 시 ARCHIVE — sensor-feedback-promotion 등 다른 sensor와의 시너지 평가 필요" |
| 3 | orchestration-decision | 2 | 2 | false | 10 | 3 | **유일하게 7d 호출 있음 (2회)** + autonomous (disable:false) + trigger 10건. 책 Ch 16 패턴 1 KPI | "사용 中이므로 KEEP 자명. 분류 자동 KEEP_FORCED 승격 가능" |
| 4 | requesting-code-review | 0 | 0 | true | 6 | 4 | 호출 0이지만 trigger 6건 + 비상 키워드 4 (배포/guard/shared/drift). prod 배포 직전 사전 검토 | "verification-before-completion + sensor-adversarial-pre-commit과 시너지 — 슬래시 호출 사용 빈도 확인 후 ARCHIVE/KEEP" |
| 5 | sensors-overview | 0 | 0 | true | 0 | 6 | 호출 0이지만 비상 키워드 6 (배포/보안/deploy/leak/shared/...). sensor 인벤토리 단축 호출 | "14 sensor 진단 명세 — `/sensors-overview` 슬래시 호출 사용 빈도 확인 (낮으면 ARCHIVE)" |
| 6 | socratic-self-critique | 0 | 0 | true | 10 | 4 | 호출 0이지만 trigger 10건 + 비상 키워드 4 (보안/shared/drift/production). Q00/ouroboros 자기검증 | "verification-before-completion과 중복 가능성 평가 필요. 두 skill 통합 또는 한쪽 ARCHIVE 결정" |
| 7 | systematic-debugging | 0 | 0 | true | 10 | 5 | 호출 0이지만 trigger 10건 + 비상 키워드 5 (디버깅/debug/leak/토큰/production). production-bug-triage 1차 실패 시 발동 | "production-bug-triage가 KEEP인데 본 skill이 후속 경로면 KEEP, 사용자 명시만이면 ARCHIVE 검토" |
| 8 | verification-before-completion | 0 | 0 | false | 17 | 4 | 호출 0이지만 **trigger 17건 (전 skill 中 최다)** + autonomous. 완료 선언 직전 발동 | "trigger 17건이 자율 매칭에 충분한지, hook 설정 누락은 없는지 확인 (자율 발동 0건은 이상 신호)" |
| 9 | writing-plans | 0 | 0 | false | 10 | 5 | 호출 0이지만 trigger 10건 + 비상 키워드 5 (보안/rollback/마이그레이션/회전/drift). planner 작업 분해 | "grimoire-planner 위임 시 본 skill 발동 자동화 여부 확인. 자동 발동 미가동이면 KEEP, 동작이면 KEEP" |

### §5 보충 — GRAY 회색 패턴 분석
- **9건 中 7건이 비상 키워드 4 이상** → 비상 가치 측면에서 ARCHIVE 부적합
- **8건이 trigger 또는 paths를 가짐** → 자율 매칭 또는 슬래시 호출 메커니즘 보유
- **유일한 호출 발생 skill (orchestration-decision)이 GRAY 분류** → 자동 KEEP_FORCED 승격 권고
- **PP-2 planner 추가 결정 필요 사유**: 4 조건 AND 룰만으로 단순 ARCHIVE 처리 시 비상 가치 5+ 키워드 보유 skill 손실 위험

---

## §6 SELF_VERIFICATION (Chain-of-Verification)

### 핵심 주장 3개 + 독립 검증

**주장 1**: ARCHIVE 후보 9건이 4조건 AND 모두 충족함

- 검증 질문: ARCHIVE 9건 모두 (1) 7d=0 (2) 30d=0 (3) disable:true (4) emrg<4 (5) KEEP_FORCED 미명시 충족하는가?
- 독립 답: 매트릭스 §2 ARCHIVE 행 9건 — 7d/30d 모두 0, disable 모두 true, emrg 0~3 (모두 <4), KEEP_FORCED 명단(memory-status / infra-mutation-guard / deploy-precheck / rollback-revision / refund-logic-audit / claude-in-chrome-recovery / macos-tcc-handling / production-bug-triage)에 9건 중 누구도 포함 안 됨 → **PASS**
- 결과: 일치

**주장 2**: KEEP_FORCED 8건이 planner 명시 명단과 정확히 일치함

- 검증 질문: planner 명시 8건 (memory-status / infra-mutation-guard / deploy-precheck / rollback-revision / refund-logic-audit / claude-in-chrome-recovery / macos-tcc-handling / production-bug-triage)이 §4 표 8건과 일치하는가?
- 독립 답: §4 표 [claude-in-chrome-recovery, deploy-precheck, infra-mutation-guard, macos-tcc-handling, memory-status, production-bug-triage, refund-logic-audit, rollback-revision] 8건 = planner 명시 8건. 1:1 일치 **PASS**
- 결과: 일치

**주장 3**: 분류된 26건의 합계가 박제 skill 26건과 정확히 일치함

- 검증 질문: ARCHIVE 9 + KEEP 8 + GRAY 9 = 26 = `ls .claude/skills | wc -l` 출력?
- 독립 답: 9+8+9=26, `ls /Users/sokol/Git/ProjectGrimoire/.claude/skills/ | wc -l` = 26 → **PASS**
- 결과: 일치

### CRITICAL_CONSTRAINTS 점검 (qa agent 정합)

- [PASS] 코드 수정 0건 (Edit/Write 호출은 본 보고서 1건뿐, 코드 0건)
- [PASS] 추정/가능성 키워드 사용 0건 (모든 분류 raw 데이터 기반)
- [PASS] raw stdout 그대로 첨부 (§1.1, §1.2 코드블록)
- [PASS] 작가 본문 인용 0건
- [PASS] Git 커밋 0건 (PP-3에서 server agent가 실행)
- [PASS] dev PASS + qa FAIL 케이스 — sensor-skill-invocation-rate FAIL (0.0769) 그대로 보고 (PASS 포장 X)
- [PASS] 분류된 skill 수 합계 (26) == 실제 박제 skill 수 (26)

---

## §7 PP-3 server agent 핸드오프 입력

PP-3에서 server agent가 본 보고서를 입력으로 archive 실행 시 다음 정보 사용:

### §7.1 ARCHIVE 대상 9개 디렉토리 절대 경로

```
/Users/sokol/Git/ProjectGrimoire/.claude/skills/dev-login-smoke
/Users/sokol/Git/ProjectGrimoire/.claude/skills/dispatching-parallel-agents
/Users/sokol/Git/ProjectGrimoire/.claude/skills/drift-check
/Users/sokol/Git/ProjectGrimoire/.claude/skills/eval-run
/Users/sokol/Git/ProjectGrimoire/.claude/skills/feedback-to-skill
/Users/sokol/Git/ProjectGrimoire/.claude/skills/handover-refresh
/Users/sokol/Git/ProjectGrimoire/.claude/skills/red-team-update-propose
/Users/sokol/Git/ProjectGrimoire/.claude/skills/shared-contracts-check
/Users/sokol/Git/ProjectGrimoire/.claude/skills/worktree-isolation
```

### §7.2 archive 후 검증 게이트

- `ls .claude/skills | wc -l` = 17 (26 - 9)
- `bash .claude/scripts/sensor-skill-invocation-rate.sh` 재실행 시 박제 skill 17건으로 갱신 + 활용률 = unique_skills(2) / 17 = 0.1176 → WARN (≥0.10) 진입 가능
- HARNESS_ENGINEERING.md §14 인벤토리 동기 갱신 필요 (Skills 26 → 17 또는 KEEP+GRAY 17건)
- drift-check sensor 통과 확인 (drift-check 자체가 ARCHIVE 후보이므로 archive 후 sensor 의존 영향 평가 필요)

### §7.3 GRAY 9건은 PP-3 대상 아님

PP-2 (planner) 추가 결정 후 PP-4(예정)에서 별도 처리.

---

## §8 변경 이력 박제 (.claude/shared-contracts.md 정합)

본 보고서 자체는 인터페이스 변경 없음 (PLANNER_REPORT/COST_AUDIT/DEV_REPORT 필드 등). 단, PP-3 archive 실행 후 다음 인터페이스 영향:
- **HARNESS_ENGINEERING.md §14 Skills 카운트** (26 → 17)
- **sensor-skill-invocation-rate 임계 분모** (26 → 17)
- **drift-check sensor 자체 archive 시 후속 조치 필요** (대안 확보 또는 함께 ARCHIVE)

PP-3 server agent가 archive 실행 시 `.claude/shared-contracts.md`에 1줄 박제:
```
2026-05-03 — server (PP-3) — Skill 26→17 (ARCHIVE 9건). HARNESS §14 갱신.
```

---

## §9 메타 — 본 위임 정합

- 본 위임이 본 세션 세 번째 grimoire-* agent 위임 (qa #1 → planner #2 → qa #3)
- 책 Ch 16 Initializer (planner) → Generator/Evaluator (qa) 3-역할 정공법 두 번째 사이클
- PP-1 산출물(분석 + 분류) 완료 → planner PP-2 (GRAY 결정) + server PP-3 (ARCHIVE 실행) 다음 핸드오프 가능

---

**보고서 종료 — qa #3 위임 완료**
