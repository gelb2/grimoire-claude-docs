# 하네스 전수검사 — 패스 B (센서 배선 + 스킬 + 에이전트/라우팅 PP-7)

> 2026-05-30 / 읽기전용 감사 (하네스 파일 무변경) / §0 ZERO-TOLERANCE: 모든 수치 실측 명령 출력 기반, 추정 0.
> 수정안은 전부 "제안"으로만 기재. 실행 금지.

---

## 0. 상태표 (한눈)

| 영역 | 주장값 | 실측 | 정합 | 핵심 결함 |
|---|---|---|---|---|
| Sensors (파일) | 57 | 57 | ✅ | 57 = 56 detector + 1 logging infra(sensor-log.sh) — "57개" headline은 파일수, detector는 56 |
| Sensors (자동배선) | — | **5 + ~14 inline** | — | **38/56 detector가 자동 hook 체인 미배선** (manual/skill/agent-only) |
| Skills (현역) | 26 | 26 | ✅ | frontmatter 26/26 유효, dir==name 26/26, 깨진 스킬 0 |
| Skills (+archive) | — | 35 (26+9) | — | `_archive/` 9개 SKILL.md 별도 (현역 카운트서 정상 제외) |
| Agents (.md) | ~10 | 10 | ✅ | frontmatter 10/10 유효 |
| PP-7 라우팅 ↔ 정의 | 정합 기대 | **불일치** | ❌ | 라우팅 구현 위치 이동 + harness.md §6-2 옛 포맷 문서 + 다수 문서 "7개/6개 에이전트" stale |
| 구문(bash -n) | — | 57/57 sensor + hooks 0 FAIL | ✅ | 전건 통과 |
| 깨진/유령 스킬 참조 | — | 0 | ✅ | settings/스킬-인젝터 참조 전건 실존 |
| 타프로젝트 에이전트 | — | 0 | ✅ | ios-simulator/zenith/personal-funnel 등 미발견 |

---

## 1. S2 — 센서 인벤토리 & 배선

### 1-1. 카운트 (실측 vs 주장 57)

```
$ ls -1 .claude/scripts/sensor-*.sh | wc -l
57
```
- 파일 수 **57** = 주장 일치.
- **그러나 detector는 56**: `sensor-log.sh`는 detector가 아닌 **적재 인프라**(sensor 실행결과를 sensor-hits.jsonl에 기록). selftest.sh가 명시적으로 56을 분류 대상으로 둠.
- 공식 인벤토리(`update-harness-inventory.sh`)는 `sensor-*.sh` glob으로 57을 세고 HARNESS_ENGINEERING.md §14.4에 "57개" 박제 → **드리프트 체커 PASS**(문서=57==실측=57). 내부 정합은 유지되나 "57 detector"라는 인상은 부정확(56 detector + 1 infra).

### 1-2. 호출 경로 — 일괄 디스패처 부재

**중앙 디스패처 없음.** 57개를 한 번에 도는 스크립트는 존재하지 않음. settings.json의 PreToolBatch는 `post-batch-tsc.sh`만 호출(센서 0). 실제 배선은 **개별·산발**:

| 진입점(등록 hook/gate) | 실행 sensor |
|---|---|
| `.githooks/pre-commit` [4/4] → `sensor-adversarial-pre-commit.sh` | (아래 5개 위임) |
| `sensor-adversarial-pre-commit.sh` (287줄, 위임 5 + inline ~14 원칙) | cost-margin / shared-contracts / instruction-degradation / secret-leak / credit-atomicity |
| PreToolUse(Bash) → `pretooluse-redteam-gate.sh` | sensor-adversarial-pre-commit (동일 5+inline) |
| `red-team-data-collector.sh` | sensor-red-team-source-whitelist |
| SubagentStop → `subagent-stop-handler.sh` | sensor-orchestration-ratio |
| PostToolUse(Edit/Write) → post-edit-tsc / post-edit-spec-check | (sensor-log 적재만, detector 0) |
| `.githooks/pre-commit` [2/3] → instructions-drift-check.sh | (sensor 직접 exec 0 — 자체 로직) |
| `.githooks/pre-commit` [3/4] → eval-precommit.sh | (sensor 직접 exec 0) |

**자동 hook 체인에서 실제 실행되는 detector = 8종**:
`sensor-adversarial-pre-commit`, `cost-margin`, `shared-contracts`, `instruction-degradation`, `secret-leak`, `credit-atomicity`, `red-team-source-whitelist`, `orchestration-ratio` (+ sensor-log 인프라).

### 1-3. 고아 센서 — 전건 (38/56 detector)

정의: hook 체인·agent .md·SKILL.md·디스패처·selftest 어디서도 **실행(bash/sh + sensor-X.sh)되지 않는** detector. (카탈로그/주석/통계리스트 언급은 "실행"으로 보지 않음.)

```
ORPHAN count (never invoked by hook/agent/skill/dispatcher/selftest): 38 / 56 detectors
```

**고아 38건 전체 목록**:
```
sensor-admin-credit-ui          sensor-loop-detection
sensor-agent-interaction*       sensor-oauth-email-verification
sensor-agent-priority-labels    sensor-partial-refund
sensor-audit-log-before-after   sensor-payment-idempotency
sensor-audit-retention-policy   sensor-payment-race-condition
sensor-chat-charge-tier         sensor-payment-reconciliation
sensor-chat-domain              sensor-payment-retry-reuse
sensor-circuit-breaker-policy   sensor-payment-status-mapping
sensor-context-budget           sensor-polar-timeout-policy
sensor-credit-denomination      sensor-refund-atomicity
sensor-credit-overhaul-recalc** sensor-response-zero-realtime
sensor-credit-source-accounting sensor-retry-dedup
sensor-deploy-drift             sensor-security-gate
sensor-eval-trend               sensor-skill-invocation-rate
sensor-feedback-promotion       sensor-skill-paths-coverage
sensor-harness-cross-ref        sensor-slug-login
sensor-harness-self-diagnose    sensor-sms-service-port
sensor-hook-effectiveness       sensor-subscription-pool-no-rollover
                                sensor-user-soft-delete-policy
                                sensor-webhook-dlq
```
`*` agent-interaction / `**` credit-overhaul-recalc — SKILL.md 또는 agent .md에 **언급**되나 실제 `bash ...sh` 실행 라인은 아님(=수동 호출 안내문). 보수적으로 고아 분류했으나 "수동 트리거 존재"로 완화 해석 가능.

#### 1-3-1. 고아의 성격 분류 (정직한 재해석)

고아 = 전부 결함이 아님. selftest.sh가 56 detector를 분류:
- **EXISTENCE 32** — "필수 패턴이 있어야 PASS". 실 tracked 소스를 깨야만 fire → **자동 hook 부적합**이 설계상 정상. 그러나 **어떤 시점에 실행되는지 미배선**이면 "패턴 회귀를 영영 못 잡음" 리스크.
- **EXTERNAL 14** — curl/az/git/build·test 의존 → 격리/자동 부적합. 일부(deploy-health/azure-env-secret)는 skill·agent에서 수동 실행 배선됨.
- **STUB 3** — 항상 exit0(정보성) → fire 불가가 정상.
- **INJECTABLE 3 / GUARDED 4** — selftest가 fire 증명 대상으로 삼음.

**핵심 갭**: 결제 12종(payment-*, partial-refund, refund-atomicity, webhook-dlq, subscription-pool, polar-timeout) + 크레딧(credit-denomination, credit-source-accounting) + 채팅(chat-charge-tier) 등 **도메인 EXISTENCE 센서가 (a)자동 hook 미배선 (b)eval task 미wrap (c)skill/agent 미참조** 삼중 미배선. 즉 해당 정책 회귀를 자동 포착하는 경로가 0.

#### 1-3-2. sensor→eval task 브리지 부분 커버 (보완 경로)

`eval/scripts/generate-sensor-tasks.sh` 존재 + `eval/tasks/auto-sensor-*.json` **18건** 생성됨. 그러나:
- 스크립트 주석 "13 sensors 중..." → **13종만 wrap 대상**.
- auto-sensor 목록에 **결제/크레딧/채팅 도메인 센서 부재**(adversarial/agent-interaction/context-budget/cost-margin/eval-trend/harness-*/hit-rate/instruction-degradation/knowledge-drift/log/loop-detection/redteam/security-gate/skill-paths 위주).
- 따라서 도메인 고아 센서는 eval 경로로도 미커버.

### 1-4. 구문 검증
```
syntax FAIL count: 0 / 57   (모든 sensor bash -n 통과)
hook syntax FAIL count: 0   (pretooluse/posttooluse/post/stop/subagent/user/pre/instructions/check/skill/statusline/loop-detection)
```

---

## 2. S3 — 스킬 인벤토리

### 2-1. 카운트 (실측 vs 주장 26)
```
현역(_archive 제외) SKILL.md: 26    ← 주장 일치
_archive/*/SKILL.md:          9
합계:                         35
```
- 최초 `ls .claude/skills/*/SKILL.md`가 26을 반환한 이유: `_archive/X/SKILL.md`는 한 단계 더 깊어(`skills/_archive/X/`) glob 미매칭. 즉 26은 정확히 **현역 스킬 수**.
- 공식 인벤토리도 `ls -d skills/*/ | grep -v _archive`로 26 산출 → HARNESS_ENGINEERING.md §14.2 "26종 현역 + 9 Archive" 박제, **드리프트 0**.

### 2-2. frontmatter 유효성
```
broken active skills: 0 / 26   (name + description 전건 존재)
dir==name mismatch: 0          (디렉토리명 = frontmatter name 전건 일치)
```
- 깨진/빈 스킬 **0건**.

### 2-3. 현역 26 스킬 목록
```
claude-in-chrome-recovery   memory-status            sensors-overview
cron-job-verify             orchestration-decision   socratic-self-critique
deploy-image-verify         prod-deploy              sprint-end-commit
deploy-precheck             production-bug-triage    sprint-handover-finalize
dev-db-measure              refund-logic-audit       systematic-debugging
dev-health-check            requesting-code-review   verification-before-completion
dev-migration-apply         rollback-revision        verifier-protocol
eval-run                    gc-sweep                 writing-plans
infra-mutation-guard        macos-tcc-handling
```

### 2-4. 문서/settings가 참조하나 미존재 스킬
- settings.json: 스킬 직접 참조 0 (scripts만 등록) → 유령 참조 없음.
- skill-injector / post-response-skill-injector: 참조 스킬 전건 실존(허위양성 "bash" 1건은 명령어 토큰).
- **유령 스킬 참조 0건.**

### 2-5. 스킬 내부 문서 드리프트 (결함, 경미)
- `sensors-overview/SKILL.md`: frontmatter+본문 "**14개 sensor 인벤토리** (2026-04-30 #10 기준)" — 실측 56/57 대비 **심한 stale**. 카운트 갱신 안 됨(2026-04-30 고정).
  - **제안**: sensors-overview 본문 "14 sensors" → 현 인벤토리(56 detector / 57 파일)로 갱신, 또는 update-harness-inventory 연동.

---

## 3. S4 — 에이전트 정의 ↔ 라우팅 매트릭스 (PP-7)

### 3-1. 에이전트 정의 10건 (frontmatter 요약)

| name | model | tools | 책임(요지) |
|---|---|---|---|
| grimoire-cost-accountant | opus | Read,Write,Edit,Glob,Grep,Bash | §0 크레딧-원가 철칙, ai-cost-table 관리, 마진≥3배 게이트 |
| grimoire-harness | opus | Read,Write,Edit,Bash,Glob,Grep | `.claude/*` 메타(sensor/hook/skill/agent/settings/state/knowledge) |
| grimoire-infrastructure | opus | Read,Write,Edit,Bash,Glob,Grep | Azure ContainerApps/Postgres/Actions/secretRef/cron, 수동배포 |
| grimoire-planner | opus | Read,Write,Edit,Glob,Grep | 기획, PLANNING 종속, 핸드오프 취합 |
| grimoire-qa | opus | Read,Write,Edit,Bash,Glob,Grep | 2레포 테스트/E2E/빌드/시각·원가 검증, 머지 게이트 |
| grimoire-researcher | opus | Read,Write,Edit,Glob,Grep,**WebSearch,WebFetch** | 경쟁사+AI가격 모니터링 |
| grimoire-server | opus | Read,Write,Edit,Bash,Glob,Grep | NestJS+Prisma+PG, docs 정본 |
| grimoire-verifier | opus | **Read,Bash,Glob,Grep** (Write/Edit 없음) | 읽기전용 독립 재실측, 거짓PASS 차단 |
| grimoire-visual-canon-keeper | opus | Read,Write,Edit,Glob,Grep,Bash | deerdevil 시각정본 수호 |
| grimoire-web | opus | Read,Write,Edit,Bash,Glob,Grep | Next.js+TS+Tailwind, 시각정본 준수 |

- frontmatter 전건(name/description/tools/model) **유효**.
- verifier만 의도적으로 Write/Edit/commit/push 도구 제거(구조적 변경 불가 설계) — 정의서와 일치.
- researcher만 WebSearch/WebFetch 보유 — 역할 정합.

### 3-2. PP-7 라우팅 매트릭스 — 실제 위치 & 내용

**위치 이동(미동기 결함)**: harness.md §6-2가 기술한 옛 포맷
```
*.claude/scripts/sensor-*) EXPECTED_AGENT="grimoire-harness" ;;   ← 이 포맷은 현 코드에 없음
```
은 **현 구현과 불일치**. 실제 라우팅은 `EXPECTED_AGENT` 케이스문이 아니라 `pretooluse-main-whitelist.sh`의 **`classify_path`/`classify_bash` → `ALLOW|BLOCK:<agent>`** 구조(2026-05-29 재작성).

**실제 라우팅(pretooluse-main-whitelist.sh classify_path)**:
| 경로 패턴 | 라우팅 |
|---|---|
| grimoire-server/{src,test,prisma,docs,scripts}/, 설정파일(jest/tsconfig/package.json/nest-cli/Dockerfile/compose/Makefile/prisma.config) | BLOCK:grimoire-server |
| grimoire-web/{src,app,docs}/, 설정파일(next/tsconfig/package.json/vitest/playwright/Dockerfile/tailwind/Makefile) | BLOCK:grimoire-web |
| eval/tasks, eval/scripts/ | BLOCK:grimoire-qa |
| `.claude/{agents,skills,scripts}/`, settings.json, AGENTS.md, shared-contracts.md, knowledge/ | bootstrap.flag 있으면 ALLOW, 없으면 **BLOCK:grimoire-harness** |
| planning_grimoire.md | BLOCK:USER_APPROVAL |
| 그 외(메모리/리포트/문서) | ALLOW |

**classify_bash 의사-라우팅(에이전트 아님, 차단 사유)**: mutating-git / deploy / test-build / bash-file-write-codearea.

**bootstrap.flag 현재 상태**: `.claude/state/harness-bootstrap.flag` **부재** → 하네스 영역은 현재 **grimoire-harness 에이전트로 라우팅**(메인 직접 차단). 이는 harness.md 신설 취지와 정합.

### 3-3. 교차 대조 — 매트릭스 ↔ 정의 (불일치 전건)

| 교차 항목 | 결과 |
|---|---|
| 라우팅에 등장하는 실제 에이전트(grimoire-server/web/qa/harness) → 정의 .md 보유? | ✅ 4/4 보유 |
| USER_APPROVAL/mutating-git/deploy/test-build/bash-file-write-codearea | 에이전트 아님(차단사유 토큰) — 정의 불요, 정합 |
| 10개 정의 에이전트 중 **Edit/Write 라우팅 미등재** | **6건**: cost-accountant, infrastructure, planner, researcher, verifier, visual-canon-keeper |

**6건 미등재 판정 (정직)**: 이들은 "파일 경로 소유"가 아닌 **역할/리포트 기반** 에이전트.
- planner/cost-accountant/visual-canon-keeper/qa 산출물 = `reports/*` → 현 라우팅에선 `ALLOW`(메인/에이전트 자유). **즉 reports/ 경로 라우팅이 없어** 이들 영역이 "메인 직접 가능"으로 열려 있음 = **PP-7 책임 매트릭스(harness.md §1-2의 reports/QA_REPORT→qa, PLANNER_REPORT→planner 등)와 실제 가드 라우팅 불일치**.
- infrastructure: 배포/인프라는 **classify_bash**(deploy 차단)로 일부 커버되나, `.claude/scripts/deploy-*.sh`·INFRASTRUCTURE.md 등 파일 경로 라우팅은 harness/ALLOW로 흡수 — infrastructure 에이전트로의 파일 라우팅 0.
- verifier: 읽기전용 설계상 라우팅 대상 아님(정상).

**불일치 전건 요약**:
1. **harness.md §6-2 문서가 옛 EXPECTED_AGENT 포맷** 기술 — 현 whitelist 구조와 불일치 (문서 드리프트, 자기 정의 내부).
2. **reports/ 경로 라우팅 부재** — harness.md §1-2(QA_REPORT→qa, PLANNER_REPORT→planner, COST_AUDIT→cost-accountant, VISUAL_CANON→visual-canon-keeper)가 가드 미반영. 현재 메인이 모든 reports/* 직접 작성 가능.
3. **다수 정본 문서가 "7개/6개 에이전트" stale**:
   - `.claude/AGENTS.md:106` "7개 에이전트 .md에 반영"
   - `.claude/knowledge/agent-system.md:7` "6개 에이전트"
   - `.claude/knowledge/README.md:18` "에이전트 7개 인벤토리"
   - `research/HARNESS_ENGINEERING.md:503,526,546` "7개 서브에이전트/7개 에이전트 정의"
   - `research/HARNESS_SPLIT_AND_EDD.md:32,40` "7개 에이전트"
   - shared-contracts.md는 생산자/소비자로 7개 역할 에이전트 등장하나 infrastructure/harness/verifier(5/8·5/9·5/29 신설) 미반영.
   → **실측 10개. 신설 3(infrastructure/harness/verifier)이 카운트·핸드오프 문서에 미동기.**

### 3-4. 타프로젝트 참조 에이전트
```
ios-simulator / personal-funnel / projectzenith / simulator-runner: NONE FOUND
```
- 외래 에이전트 0건. ProjectGrimoire 전용 10개만 존재. (질문의 ios-simulator-runner는 여기 부재 = 정상, 이식 불요.)

---

## 4. 결함 종합 (심각도순)

| # | 심각도 | 영역 | 결함 | 제안(실행 금지, 제안만) |
|---|---|---|---|---|
| B1 | **중** | 센서 배선 | 도메인 EXISTENCE 센서 ~30종(결제12/크레딧/채팅/감사/소프트삭제 등)이 자동 hook·eval·skill·agent **삼중 미배선** → 정책 회귀 자동 포착 경로 0 | generate-sensor-tasks 대상을 13→도메인 포함 확대 wrap, 또는 server/web 변경시 도메인 sensor를 requesting-code-review 체크리스트에 추가 |
| B2 | **중** | PP-7 정합 | reports/ 경로 라우팅 부재 — harness.md §1-2(QA/PLANNER/COST/VISUAL_CANON→각 에이전트)가 가드 미반영, 메인 직접 작성 열림 | classify_path에 `*reports/QA_REPORT*→qa` 등 추가 검토 (단 감사 산출물 자유작성과 상충 여부 사용자 판단) |
| B3 | **경** | 문서 드리프트 | "7개/6개 에이전트" 6개 문서 stale (실측 10). 신설 3 미반영 | AGENTS.md/knowledge/agent-system·README/HARNESS_ENGINEERING/HARNESS_SPLIT 카운트 10으로 갱신 + 핸드오프 매트릭스에 infra/harness/verifier 추가 |
| B4 | **경** | 자기 문서 드리프트 | harness.md §6-2가 옛 EXPECTED_AGENT 포맷 기술 — 현 whitelist(BLOCK:<agent>)와 불일치 | harness.md §6-2를 pretooluse-main-whitelist.sh classify_path 실제 구조로 갱신 |
| B5 | **경** | 스킬 문서 | sensors-overview SKILL "14 sensors(2026-04-30)" 심한 stale (실측 56/57) | 본문 카운트 갱신 또는 update-harness-inventory 연동 |
| B6 | **정보** | 카운트 의미 | "57 sensors" headline은 파일수(=56 detector + sensor-log 인프라). 드리프트 체커는 PASS(내부 정합) | HARNESS_ENGINEERING §14.4에 "56 detector + 1 적재 infra" 주석 추가 검토 |

**무결함 확인(정상)**: 스킬 frontmatter 26/26, dir==name, 유령 스킬 참조 0, 에이전트 frontmatter 10/10, 외래 에이전트 0, bash -n 전건 통과, bootstrap.flag 부재로 하네스→harness 라우팅 정합, 공식 인벤토리 드리프트 0.

---

## 5. 확인불가 / 미검증 (정직 박제)
- **센서 fire 실증**: 본 패스는 배선/카운트 감사. 각 센서가 실제 위반에 fire하는지(selftest INJECTABLE 3/GUARDED 4 측정)는 미실행 — 패스 범위 외(selftest.sh 별도 실행 필요).
- **라우팅 런타임 동작**: whitelist 분류 로직을 정적 Read로 검증. 실제 PreToolUse hook이 stdin JSON으로 BLOCK 반환하는지 라이브 실측은 미수행(감사 무변경 원칙상 commit/Edit 트리거 회피).
- **agent_id 주입 실태**: 가드가 `agent_id` 존재로 sub-agent 통과시키나(line 42), 실제 sub-agent 호출 시 agent_id가 주입되는지는 5/29 verifier 실측 주석에 의존(본 패스 재실측 안 함).
