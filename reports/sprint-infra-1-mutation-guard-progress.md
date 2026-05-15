# Sprint INFRA-1 — Mutation Guard & Auto Rollback (Initializer Sprint Progress)

> **작성자**: planner #12 (Initializer 역할, 책 Ch 16 Anthropic 3-에이전트 패턴)
> **작성일**: 2026-05-08
> **수신자**: 메인 Claude (orchestration-decision → 메인 직접 작업) → qa Evaluator (독립 재실행)
> **상태**: Sprint 계약 박제 완료 — Generator 진입 대기
> **근거**: 본 세션 prod revision 97 ActivationFailed (`71a96d3..421d51c` GitHub Actions Deploy Production `25538062452` success 2m45s 직후) + dev revision 153 ActivationFailed 동일 패턴 5/6 발생 후 156 회복

---

## §1. 배경 (사용자 분노 정합 + §0 ZERO-TOLERANCE 위반 회고)

### §1-1. 본 세션 prod 사고 사슬

본 세션 server main 머지 (`71a96d3..421d51c`) 이후:
1. GitHub Actions Deploy Production 자동 트리거 — workflow run `25538062452` success 2m45s
2. **prod revision 97 생성 직후 ActivationFailed** (Active=true + Traffic=100 + HealthState=Unhealthy + RunningState=Failed)
3. 사용자가 prod down 발견 → 본 세션 즉시 rollback 진입 (revision 96 image 강제 재배포 → revision 98 Activating)

### §1-2. dev 동일 패턴 (이전 세션 #10_7~#10_8 회고)

- dev revision 153 ActivationFailed (보안 마이그레이션 직후) — 평문 → secretRef 변환 시 `PUBLIC_API_BASE_URL` 누락이 startup fail 유발
- 5/6 시점 회복 (revision 156 Healthy)
- **공통 근본 원인**: 코드 spec PASS = "검증 완료" 보고했지만 운영 환경 검증 0건 (HANDOVER-CRITICAL-2026-05-06.md §0 거짓 검증 매트릭스 7건 박제)

### §1-3. 본 sprint 명제

> **인프라 변경 직후 운영 환경 health 자동 검증 + 실패 시 자동 rollback이 없으면, 코드 단위 spec PASS는 운영 안전성을 보장하지 못한다.**

본 sprint INFRA-1은 PP-3 ~ PP-7 자동 강제 hook 시스템을 **인프라 영역으로 확장** — 베이비시팅 X 진짜 하네스 정합.

---

## §2. 정본 참조 매트릭스 (Sprint 진입 시 메인 Read 의무)

| 정본 | 위치 | 역할 |
|---|---|---|
| HANDOVER-CRITICAL-2026-05-06-PP §3 | `reports/HANDOVER-CRITICAL-2026-05-06-PP.md` | 자동 강제 hook 시스템 (PP-6/PP-7) — 본 sprint 확장 기반 |
| HANDOVER-CRITICAL-2026-05-06 §3 | `reports/HANDOVER-CRITICAL-2026-05-06.md` | 8건 시스템 결함 매트릭스 — 본 sprint 4건 해소 목표 |
| PAYMENT_AUDIT-2026-05-07 §3 | `research/PAYMENT_AUDIT-2026-05-07.md` | 서드파티 실패 추적 — sensor-azure-env-secret 매트릭스 일부 차용 |
| incident-log.jsonl | `.claude/state/incident-log.jsonl` | 누적 incident + 본 세션 prod 97 critical alert |
| shared-contracts.md | `.claude/shared-contracts.md` | §21 InfraMutationGuard 신설 영역 |

---

## §3. 갭 매트릭스 해소 목표 (HANDOVER-CRITICAL-2026-05-06 §3 → 본 sprint)

| # | 결함 영역 | 본 sprint 해소 산출물 | 잔존 |
|---|---|---|---|
| 1 | sensor-secret-leak (Azure env 평문 미커버) | sensor-azure-env-secret (AC-4) | — |
| 2 | sensor-adversarial-pre-commit (`az containerapp update` 미발동) | infra-mutation-guard skill (AC-1) | — |
| 3 | orchestration-decision skill (인프라 변경 위임 검토 0건) | infra-mutation-guard SKILL.md trigger 매핑 | (잔존: 지속 자가검증) |
| 4 | verification-before-completion (인프라 health check 0건) | sensor-deploy-health (AC-3) | — |
| 5 | production-bug-triage skill (root cause 추적 0건) | (잔존 — 별도 sprint) | ★ |
| 6 | systematic-debugging skill (startup Failed 진단 0건) | (잔존 — 별도 sprint) | ★ |
| 7 | 인프라 rollback skill 미존재 | rollback-revision skill (AC-2) | — |
| 8 | §0 ZERO-TOLERANCE 추정 금지 (운영 환경 미검증) | deploy-precheck skill 강화 (AC-5) | — |

**본 sprint 해소: 8건 중 6건 (#1, #2, #3 부분, #4, #7, #8). 잔존 #5, #6은 별도 sprint INFRA-2 권고.**

---

## §4. 산출물 명세 (5건 신설/강화)

### §4-1. infra-mutation-guard skill (신설, AC-1)

**위치**: `.claude/skills/infra-mutation-guard/SKILL.md`

**발동 조건 (frontmatter triggers)**:
- `az containerapp update`
- `az containerapp set-secrets`
- `az containerapp replace-env-vars`
- `az containerapp revision activate`
- `az containerapp revision deactivate`
- `kubectl apply` (향후 K8s 확장 대비)
- 메인 응답 텍스트 키워드: "인프라 변경", "secretRef", "container apps update"

**동작 절차 (SKILL.md 본문)**:
1. **Pre-mutation snapshot**: `az containerapp revision list -n <app> -g <rg>` raw 박제 (HealthState + RunningState + TrafficWeight + replicas)
2. 사용자에게 변경 의도 명시 요구 (orchestration-decision skill 연동)
3. 변경 명령 실행
4. **3회 polling**:
   - +10s: revision 생성 여부 확인
   - +30s: HealthState=Healthy 검증 (Activating 허용)
   - +60s: HealthState=Healthy + RunningState=Running + TrafficWeight=100 검증
5. **실패 시 자동 rollback-revision skill 호출 권고** (또는 multi-revision mode 권고)

**로깅**: `.claude/state/infra-mutation-guard.jsonl` (mutation event + snapshot before/after + polling 결과)

### §4-2. rollback-revision skill (신설, AC-2)

**위치**: `.claude/skills/rollback-revision/SKILL.md`

**발동 조건 (frontmatter triggers)**:
- revision Failed 검출 시 (infra-mutation-guard 연동)
- 메인 응답 텍스트 키워드: "rollback", "revision Failed", "ActivationFailed"

**동작 절차**:
1. **마지막 Healthy revision 식별 로직**:
   ```bash
   az containerapp revision list -n <app> -g <rg> \
     --query "[?properties.healthState=='Healthy'] | [0].properties.template.containers[0].image" -o tsv
   ```
2. **강제 재배포**:
   ```bash
   az containerapp update -n <app> -g <rg> --image <prev-image>
   ```
3. **대안 — multi-revision mode + traffic 분산**:
   ```bash
   az containerapp revision set-mode -n <app> -g <rg> --mode multiple
   az containerapp ingress traffic set -n <app> -g <rg> \
     --revision-weight <prev-revision>=100 <failed-revision>=0
   ```
4. **사용자 명시 권한 요구**: 자동 rollback은 사용자 승인 후 진행 (CLAUDE.md §0 인프라 변경 사전 보고 정합)

**로깅**: `.claude/state/rollback-revision.jsonl` (rollback event + 이전/이후 image 박제)

### §4-3. sensor-deploy-health.sh (신설, AC-3)

**위치**: `.claude/scripts/sensor-deploy-health.sh`

**발동**: pre-push (main 브랜치) + GitHub Actions polling 후 + 정기 회귀

**5 검증 항목**:
1. revision HealthState=Healthy
2. revision TrafficWeight=100
3. `curl --max-time 30 https://<public-endpoint>/api/health` HTTP 200
4. replicas ≥ 1 (currentReplicas)
5. startup time ≤ 90s (revision createdTime → Healthy 전환)

**Exit code**:
- 0: 5건 PASS
- 1: WARN (1~2건 일시 실패 — polling 재시도 권고)
- 2: FAIL (3건 이상 실패 — main push 차단 또는 rollback 자동 권고)

**로깅**: `.claude/state/deploy-health.jsonl` (5건 검증 결과 raw)

### §4-4. sensor-azure-env-secret.sh (신설, AC-4)

**위치**: `.claude/scripts/sensor-azure-env-secret.sh`

**발동**: 정기 회귀 + pre-deploy + main 머지 직후

**8 시크릿 매트릭스** (모두 secretRef 강제):

| 시크릿 | 환경변수 | secret name |
|---|---|---|
| 1 | DATABASE_URL | database-url |
| 2 | JWT_SECRET | jwt-secret |
| 3 | RECAPTCHA_SECRET_KEY | recaptcha-secret-key |
| 4 | ANTHROPIC_API_KEY | anthropic-api-key |
| 5 | OPENAI_API_KEY | openai-api-key |
| 6 | POLAR_ACCESS_TOKEN | polar-access-token |
| 7 | POLAR_WEBHOOK_SECRET | polar-webhook-secret |
| 8 | AZURE_STORAGE_ACCOUNT_KEY | azure-storage-account-key |

**검증 명령**:
```bash
az containerapp show -n <app> -g <rg> \
  --query "properties.template.containers[0].env[].{name:name, hasValue:value!=null, hasSecretRef:secretRef!=null}" -o table
```

**Exit code**:
- 0: 8건 모두 hasValue=False + hasSecretRef=True
- 2: 1건 이상 hasValue=True (평문 누출 회귀) — Constitution P13 위반 차단

**부가 검증**: `PUBLIC_API_BASE_URL` 누락 검증 (dev 153 회귀 차단 — 웹 빌드 시 필수)

**로깅**: `.claude/state/azure-env-secret.jsonl` (8건 매트릭스 + PUBLIC_API_BASE_URL 별도)

### §4-5. deploy-precheck skill 강화 (AC-5)

**위치**: `.claude/skills/deploy-precheck/SKILL.md` (기존 갱신)

**강화 항목**:
1. **main push 직전 dev startup 시뮬**: dev에 동일 image 배포 후 sensor-deploy-health PASS 확인
2. **dev에서 secretRef 정합 검증**: sensor-azure-env-secret PASS 후 main push 허용
3. **필수 env 매핑 검증**: `PUBLIC_API_BASE_URL` 등 빌드 시 필수 변수 누락 차단
4. **회귀 차단**: dev 회복 후 24h 안정성 박제 후 main push 권고

**로깅**: `.claude/state/deploy-precheck.jsonl`

---

## §5. AC 8건 BDD 명세 (qa Evaluator 채점 대상)

### AC-1. infra-mutation-guard skill 신설
- **GIVEN** `.claude/skills/infra-mutation-guard/` 디렉토리 부재
- **WHEN** 메인이 SKILL.md 박제 (frontmatter triggers + 본문 5단계 절차)
- **THEN**
  - `test -f .claude/skills/infra-mutation-guard/SKILL.md` exit 0
  - SKILL.md frontmatter에 `az containerapp update` trigger 포함
  - SKILL.md 본문에 polling 3회 (10s/30s/60s) 명시
  - SKILL.md 본문에 실패 시 rollback-revision skill 호출 권고 명시

### AC-2. rollback-revision skill 신설
- **GIVEN** `.claude/skills/rollback-revision/` 디렉토리 부재
- **WHEN** 메인이 SKILL.md 박제 (frontmatter triggers + 본문 4단계 절차)
- **THEN**
  - `test -f .claude/skills/rollback-revision/SKILL.md` exit 0
  - SKILL.md 본문에 마지막 Healthy revision 식별 명령 박제
  - SKILL.md 본문에 multi-revision mode 대안 박제
  - SKILL.md 본문에 사용자 명시 권한 요구 박제 (CLAUDE.md §0 정합)

### AC-3. sensor-deploy-health.sh 신설
- **GIVEN** `.claude/scripts/sensor-deploy-health.sh` 부재
- **WHEN** 메인이 sensor 박제 (5 검증 + exit code 3단계)
- **THEN**
  - `test -x .claude/scripts/sensor-deploy-health.sh` exit 0
  - sensor 실행 시 5 검증 (HealthState/Traffic/curl 200/replicas/startup time) raw 출력
  - exit code 0/1/2 분기 정합
  - `.claude/state/deploy-health.jsonl` 신설

### AC-4. sensor-azure-env-secret.sh 신설
- **GIVEN** `.claude/scripts/sensor-azure-env-secret.sh` 부재
- **WHEN** 메인이 sensor 박제 (8 시크릿 매트릭스 + PUBLIC_API_BASE_URL 부가 검증)
- **THEN**
  - `test -x .claude/scripts/sensor-azure-env-secret.sh` exit 0
  - sensor 실행 시 8 시크릿 hasValue=False + hasSecretRef=True 검증
  - PUBLIC_API_BASE_URL 누락 시 별도 WARN 출력
  - exit code 0/2 분기 정합 (Constitution P13 위반 차단)

### AC-5. deploy-precheck skill 강화
- **GIVEN** `.claude/skills/deploy-precheck/SKILL.md` 기존 존재
- **WHEN** 메인이 강화 항목 4건 갱신 (dev 시뮬 + secretRef 검증 + env 매핑 + 24h 안정성)
- **THEN**
  - SKILL.md 본문에 sensor-deploy-health 호출 명시
  - SKILL.md 본문에 sensor-azure-env-secret 호출 명시
  - SKILL.md 본문에 dev 24h 안정성 박제 후 main push 권고 명시

### AC-6. regression-65 신설
- **GIVEN** `eval/tasks/regression-65.json` 부재
- **WHEN** 메인이 task 박제 (5 산출물 모두 존재 + sensor exit code 정합)
- **THEN**
  - `test -f eval/tasks/regression-65.json` exit 0
  - `bash eval/scripts/eval-runner.sh` 실행 시 regression-65 PASS
  - grade.py 점수 ≥ 0.8 (책 Ch 15 LLM-as-Judge 기준)

### AC-7. shared-contracts.md §21 InfraMutationGuard 박제
- **GIVEN** `.claude/shared-contracts.md` 기존 §17까지 존재 (PP-7 시점 §17, 본 세션 PAY-P2-1~3에서 §18~§20 추가됨)
- **WHEN** 메인이 §21 InfraMutationGuard 인터페이스 박제
- **THEN**
  - shared-contracts.md §21 헤더 신설 (`## §21. InfraMutationGuard`)
  - 5 산출물 인터페이스 명시 (skill 2 + sensor 2 + skill 강화 1)
  - 변경 이력 1줄 박제 (`2026-05-08 — planner — §21 InfraMutationGuard 신설 (Sprint INFRA-1)`)

### AC-8. HANDOVER §3 갭 8건 중 4건 해소 박제
- **GIVEN** HANDOVER-CRITICAL-2026-05-06.md §3 8건 결함 잔존
- **WHEN** 본 sprint 5건 산출물 develop 반영 후
- **THEN**
  - HANDOVER §3 갭 #1 (Azure env 평문) 해소 — sensor-azure-env-secret
  - HANDOVER §3 갭 #2 (`az containerapp update` 미발동) 해소 — infra-mutation-guard
  - HANDOVER §3 갭 #4 (인프라 health check) 해소 — sensor-deploy-health
  - HANDOVER §3 갭 #7 (인프라 rollback skill) 해소 — rollback-revision
  - HANDOVER §3 갭 #8 (운영 환경 미검증) 해소 — deploy-precheck 강화
  - 4건 해소 박제 — 본 sprint progress §3 매트릭스 갱신

---

## §6. 거짓말 차단 정책 (사용자 ★ — 누적 회고 정합)

본 sprint 진행 시 메인이 절대 위반 금지:

1. **★ commit/push 절대 금지** — 메인 직접 책임이 아니면 모든 commit/push는 사용자 명시 권한 후 메인 직접 실행 (agent 위임 금지 영역)
2. **spec 더미 assertion 금지** — 가능한 영역에서 의미 있는 검증:
   - skill: SKILL.md frontmatter triggers 키워드 매칭 검증
   - sensor: exit code 분기 + raw stdout 박제
   - regression: grade.py 점수 ≥ 0.8
3. **raw stdout 박제 의무** — sensor + skill 호출 결과 jsonl 박제 (`.claude/state/`)
4. **qa Evaluator 독립 재실행** — qa #18 위임 시 본 sprint progress AC 8건 채점 + raw 명령 직접 재실행
5. **외부 프로젝트 인용 0건** — CERTI_PROJ / brightmall / thermage / inapi 인용 금지
6. **운영 환경 검증 강제** — 본 sprint 핵심 명제. 코드 spec PASS만으로 "검증 완료" 보고 차단:
   - skill 신설 후 실제 trigger 매칭 검증 (`.claude/state/post-response-skill-trigger.jsonl` 발생 확인)
   - sensor 신설 후 실제 az containerapp 명령 호출 박제
   - regression-65 grade.py PASS 박제

**거짓말 자가검증 5건** (본 sprint 종료 시 메인 자가 자문):
- Q1: 5 산출물 모두 실제 파일 존재? (`test -f` 5건 모두 exit 0?)
- Q2: SKILL.md frontmatter triggers가 실제 메인 응답 텍스트 매칭 가능?
- Q3: sensor 2건 실제 exit code 분기 정합?
- Q4: regression-65 grade.py PASS 점수 ≥ 0.8?
- Q5: shared-contracts.md §21 박제 + 변경 이력 1줄 추가?

---

## §7. 멀티에이전트 흐름 (Initializer → Generator → Evaluator)

| 단계 | 역할 | 책임 |
|---|---|---|
| 1 | **Initializer (planner #12, 본 보고서)** | Sprint 계약 박제 + AC 8건 BDD + 거짓말 차단 정책 |
| 2 | orchestration-decision skill 발동 | 인프라 영역 위임 검토 — 메인 직접 작업 영역 식별 |
| 3 | cost-accountant 면제 | AI 기능 추가 0건 (skill + sensor + regression만) |
| 4 | visual-canon-keeper 면제 | UI 컴포넌트 변경 0건 |
| 5 | **Generator (메인 직접)** | claude-docs 영역 5 산출물 박제:<br>- `.claude/skills/infra-mutation-guard/SKILL.md`<br>- `.claude/skills/rollback-revision/SKILL.md`<br>- `.claude/scripts/sensor-deploy-health.sh`<br>- `.claude/scripts/sensor-azure-env-secret.sh`<br>- `.claude/skills/deploy-precheck/SKILL.md` (갱신)<br>- `.claude/shared-contracts.md` §21<br>- `eval/tasks/regression-65.json` |
| 6 | **Evaluator (qa #18)** | AC 8건 독립 채점 + raw 명령 재실행 + sprint progress 통과율 박제 |
| 7 | 메인 commit + push | 사용자 명시 후 develop push |

---

## §8. 인벤토리 변동 예상

| 카테고리 | 현재 | 본 sprint 후 | 변동 |
|---|---|---|---|
| Skills | 17 | 19 | +2 (infra-mutation-guard / rollback-revision) |
| Sensors | 39 | 41 | +2 (sensor-deploy-health / sensor-azure-env-secret) |
| Eval regression | 67 | 68 | +1 (regression-65) |
| shared-contracts §N | §17~§20 | §21 | +1 (InfraMutationGuard) |
| .claude/state jsonl | 13 | 16 | +3 (infra-mutation-guard / rollback-revision / deploy-health) |
| HANDOVER §3 갭 해소 | 0/8 | 4/8 (+ 부분 1) | 50% |

---

## §9. Sprint 완료 기준 (Definition of Done)

본 sprint progress가 PASS로 박제되려면 다음 모두 충족:

1. **AC 8건 모두 PASS** (qa #18 독립 채점)
2. **5 산출물 develop push 완료** (메인 commit + 사용자 명시 후 push)
3. **eval-runner.sh 실행 시 regression-65 PASS** (grade.py 점수 ≥ 0.8)
4. **HANDOVER-CRITICAL-2026-05-06.md §3 매트릭스 갱신** (4건 해소 박제)
5. **shared-contracts.md §21 박제 + 변경 이력 1줄**
6. **incident-log.jsonl** prod 97 ActivationFailed critical alert 박제 + 본 sprint resolution 박제
7. **sprint progress §3 갭 매트릭스 갱신** (#1, #2, #4, #7, #8 해소 ✓)
8. **거짓말 자가검증 5건 모두 PASS** (§6 Q1~Q5)

**미충족 시**: 별도 sprint INFRA-1.5 진입 권고 (잔존 #5, #6은 별도 sprint INFRA-2 권고)

---

## §10. 다음 sprint 예고 (INFRA-2)

본 sprint INFRA-1 종료 후 잔존 결함 #5, #6 해소 sprint:

- **production-bug-triage skill 강화**: prod 사고 발생 시 root cause 추적 자동화
- **systematic-debugging skill 강화**: startup Failed 진단 절차 박제
- **sensor-deploy-health 확장**: K8s / Vercel / Railway 등 다중 플랫폼 매트릭스

진입 시점: 본 sprint 종료 + 24h 안정성 박제 후

---

## §11. SELF_VERIFICATION (Chain-of-Verification)

본 보고서 박제 전 자문:

1. **본 sprint progress의 모든 주장이 실제 파일/커밋/사고에 근거?**
   - ✓ HANDOVER-CRITICAL-2026-05-06-PP.md §3 + HANDOVER-CRITICAL-2026-05-06.md §3 직접 Read
   - ✓ 본 세션 prod revision 97 ActivationFailed 사용자 명시 박제
2. **[MUST] 항목 누락?**
   - ✓ 갭 분석 (§3 8건 매트릭스)
   - ✓ Phase 취합 (§7 Initializer → Generator → Evaluator)
   - ✓ 우선순위 (§3 #1, #2, #4, #7, #8 P0 + #5, #6 별도 sprint)
   - ✓ HANDOFF (§7 + §10)
3. **COST_AUDIT / VISUAL_CANON CRITICAL 반영?**
   - ✓ cost-accountant 면제 (AI 기능 추가 0건)
   - ✓ visual-canon-keeper 면제 (UI 컴포넌트 변경 0건)
4. **새 AI 기능 cost-accountant 승인 필요 플래그?**
   - ✓ 본 sprint AI 기능 0건 — 면제 명시
5. **PLANNING_GRIMOIRE.md 직접 수정 X — "사용자 권고"로 기록?**
   - ✓ 본 보고서는 sprint progress (PLANNING 직접 수정 0건)
6. **메인이 본 보고서만 읽고 작업 시작 가능?**
   - ✓ §4 산출물 명세 5건 + §5 AC 8건 BDD + §7 멀티에이전트 흐름 모두 구체

---

## §12. HANDOFF_PROTOCOL

**다음 액션 (메인 즉시 진입)**:
1. 본 sprint progress Read 완료 후 orchestration-decision skill 발동
2. 5 산출물 박제 (Generator 단계, claude-docs 영역 메인 직접)
3. qa #18 위임 (Evaluator 단계, 독립 재실행)
4. 통과 시 사용자 명시 후 develop commit + push

**대상**: 메인 Claude → qa #18

**산출물**: `reports/sprint-infra-1-mutation-guard-progress.md` (본 파일)

**필수 포함**:
- 5 산출물 명세 (§4)
- AC 8건 BDD (§5)
- 거짓말 차단 정책 (§6)
- 멀티에이전트 흐름 (§7)
- Sprint 완료 기준 (§9)

**동시 참조**: HANDOVER-CRITICAL-2026-05-06-PP.md, HANDOVER-CRITICAL-2026-05-06.md, PAYMENT_AUDIT-2026-05-07.md §3, incident-log.jsonl

---

## §13. FINAL_REMINDER (이중 앵커 하단)

- **[MUST]** 본 sprint는 코드 spec PASS만으로 "검증 완료" 보고 차단 — 운영 환경 검증 강제
- **[MUST]** commit/push 메인 직접 책임 (agent 위임 금지)
- **[MUST]** 5 산출물 모두 SKILL.md frontmatter triggers + sensor exit code 분기 정합
- **[MUST]** qa #18 독립 재실행 통과 후 develop push
- **[MUST]** 외부 프로젝트 인용 0건 (CERTI_PROJ / brightmall / thermage / inapi)
- **[MUST]** PLANNING_GRIMOIRE.md 직접 수정 0건 (사용자 권고만)
- **[MUST]** ACCOUNTS.md 참조 0건
- **[MUST]** 작가 본문 인용 0건

---

> **Sprint 계약 박제 완료** — Generator 진입 대기. 메인은 본 보고서를 §4 산출물 명세부터 순차 진행 가능.
