# HARNESS P3 — 센서 고아 배선 설계 제안서 (읽기전용 분석)

> 작성: grimoire-harness agent · 2026-05-30 · **구현 0건 / 편집 0건 / 본 파일 Write만**
> 원칙: CLAUDE.md §0 추정 금지 — 모든 분류·수치는 직접 Read + 격리 실행(`/bin/bash --noprofile --norc`) 실측 박제.
> 범위: `.claude/scripts/sensor-*.sh` 56종(selftest 제외) 자동 hook 배선 분석. settings.json·scripts·skill 무변경.

---

## 0. 핵심 요약 (TL;DR)

| 항목 | 실측값 |
|---|---|
| 전체 센서 (selftest 제외) | **56** |
| 자동 체인(hook/githook)에 직접 걸린 센서 | **16** (아래 §1 표) |
| 자동 체인 밖 "고아" | **40** |
| └ **A 자동배선 적합** (결정적 detector, side-effect 0) | **18** |
| └ **B 자동부적합·정상** (EXTERNAL live-state / GUARDED side-effect) | **19** |
| └ **C 죽은코드 후보** (호출처가 `_archive`뿐 / 半배선) | **3** |
| **추천 디스패처** | **커밋 시점 1곳 집중** — `sensor-adversarial-pre-commit.sh` 도메인 블록 확장(이미 13센서 디스패치 중). 매-Edit hook 추가 **반대**. |
| A군 18개 합산 실행시간 | **약 1.6초** (센서당 50~200ms 실측, 순차) — 커밋 시점이면 허용, 매-Edit이면 과부하 |
| 권고 우선순위 | 1차=결제/크레딧 정책 9종, 2차=감사/인증 5종, 3차=harness 메타 4종. **한 번에 18개 금지, 3 batch.** |

**가장 큰 위험 (결정적)**: A군 중 **3개 센서가 지금 clean tree에서 이미 FAIL/WARN** (`sensor-partial-refund` exit 2, `sensor-payment-race-condition` exit 1, `sensor-instruction-degradation` WARN exit 1). 따라서 "FAIL→block" 디스패처를 순진하게 매 Edit에 걸면 **첫 Edit부터 전면 차단**된다. 반드시 (a) 커밋 시점 게이트 + (b) 기존 baseline FAIL을 WARN으로 격리(adversarial-pre-commit가 이미 쓰는 `check` 컨벤션)해야 함.

---

## 1. 현 배선 실측 (자동 실행 16센서가 어느 이벤트에 어떻게)

### 1-1. 자동 실행 경로 = 4갈래 (settings.json + .githooks/pre-commit)

`git config core.hooksPath` = **`.githooks`** (루트 + grimoire-server + grimoire-web 3 레포 전부 실측 확인). 따라서 `.githooks/pre-commit`이 실제 활성.

| # | 경로(이벤트) | 트리거 시점 | 부르는 센서 | 성격 |
|---|---|---|---|---|
| 1 | **`.githooks/pre-commit`** (git commit) | 매 커밋 | `sensor-adversarial-pre-commit` (디스패처) → 내부 13센서 | **block 게이트** (FAIL=exit≥2 차단, WARN=허용) |
| 2 | **`pretooluse-redteam-gate.sh`** (PreToolUse Bash) | 위험 Bash 명령 직전 (git commit/push, az/gcloud mutation, npm publish, polar) | `sensor-adversarial-pre-commit` (동일 디스패처) | **block 게이트** (exit 2 reject) |
| 3 | **`statusline.sh`** (statusLine) | 상태줄 렌더 | `sensor-cost-margin` / `sensor-deploy-drift` — **단, `.jsonl` 캐시 tail read만** (detector fire 아님) | telemetry (read-only) |
| 4 | **`subagent-stop-handler.sh`** (SubagentStop) + **`posttooluse-failure-handler.sh`** (PostToolUseFailure) | Task 종료 / 도구 실패 | `sensor-orchestration-ratio --quiet`, `sensor-log`(=sensor-hits.jsonl 적재), (failure 시 권고문에 `sensor-web`/`sensor-credit-atomicity` 문자열만) | telemetry / 권고 |

> PostToolUse(Edit/Write) 체인(`post-edit-tsc`/`post-edit-spec-check`/`loop-detection-tracker`)은 **detector 센서를 안 부른다** — `sensor-log` 적재(telemetry)만. `loop-detection-tracker`는 `sensor-loop-detection`을 **호출하지 않음**(자체 jsonl 누적).

### 1-2. `sensor-adversarial-pre-commit.sh` = 사실상 유일한 "디스패처" (실측)

이 스크립트가 Red Team Constitution 20 principles로 아래 센서를 직접 `bash` 호출(라인 실측):

- 라인 73 `sensor-cost-margin` (§0 원가, WARN 허용)
- 라인 94 `sensor-shared-contracts`
- 라인 105 `sensor-instruction-degradation`
- 라인 116~118 루프: `sensor-server` `sensor-web` `sensor-docs-sync` `sensor-secret-leak` `sensor-credit-atomicity` `sensor-payment-idempotency` `sensor-payment-reconciliation` `sensor-admin-credit-ui` `sensor-chat-domain`
- 라인 169 `sensor-secret-leak`(재확인) / 라인 232 `sensor-credit-atomicity`(lenient)
- 라인 274~284 `sensor-log` (결과 박제)

→ **직접 디스패치 = 13 detector** + cost-margin/credit-atomicity는 WARN-허용 컨벤션. 경로 1·2가 **같은 디스패처를 공유** → "커밋 시점 1곳 집중" 구조가 이미 존재. P3는 **이 디스패처에 도메인 센서를 더하는 것**이 정합(새 hook 신설보다 안전).

### 1-3. sensor-selftest FIRE_OK=3 / SKIP=53 분류 체계 (실측 정의)

`sensor-selftest.sh --list/--all`의 5분류는 다음과 같이 정의됨(스크립트 라인 9~25 + classify() 실측):

| 분류 | 수 | 정의 | selftest 처리 |
|---|---|---|---|
| **INJECTABLE** | 3 | 격리 temp/인자로 clean fire 증명 가능 (`fake-email-leak`/`knowledge-drift`/`red-team-source-whitelist`) | **FIRE 측정** (base≠fire & restore=base → FIRE_OK) |
| **GUARDED** | 4 | 원리상 injectable이나 실 state/git-index/incident-log/baseline≠0 교란 불가피 (`response-zero-realtime`/`secret-leak`/`loop-detection`/`skill-paths-coverage`) | SKIP(사유) — verifier 수동 1회 |
| **EXISTENCE** | 32 | 필수 패턴이 "있어야" PASS. 실 tracked 소스를 깨야만 fire → 격리 fire 불가가 **정상** | SKIP |
| **EXTERNAL** | 14 | curl/az/gcloud/git/transcript/build·test/live-state 의존 → 격리 불가 | SKIP |
| **STUB** | 3 | 항상 exit0 (정보성/적재 인프라, detector 아님) (`feedback-promotion`/`hit-rate-report`/`log`) | SKIP |

**FIRE_OK=3 / SKIP=53**은 "selftest가 fire를 *측정*할 수 있는가" 기준이지 "**자동 배선 적합한가**"와 **다른 축**임에 유의. EXISTENCE 32는 selftest에선 SKIP(격리 fire 불가)이지만, **자동 배선 관점에선 결정적 PASS/FAIL detector라 A군 적합**이다. 본 제안서 §2는 selftest 분류를 그대로 베끼지 않고 "자동 배선 적합성" 축으로 재분류한다.

---

## 2. 40 고아 전건 분류 (실측 — 자동 배선 적합성 축)

분류 기준:
- **(A) 자동배선 적합**: 격리 실행에서 결정적 exit(같은 입력=같은 결과, side-effect 0=incident-log/state append/git index 변경 없음), tracked 실파일 grep 기반. → 디스패처에 추가 가능.
- **(B) 자동부적합·정상**: EXTERNAL(curl/az/gcloud/npm test/tsc/transcript/live-state) 또는 GUARDED(fire 시 incident-log/state append side-effect, 또는 baseline 비결정).
- **(C) 죽은코드 후보**: 호출처가 `_archive` skill뿐이거나, 활성 skill에서만 半배선(자동 hook 미배선이지만 의도된 user-invoke).

### 2-A. 자동배선 적합 (18) — 디스패처 추가 후보

| 센서 | clean exit (실측) | 실행시간 | 스캔 대상 (실측) | 비고 |
|---|---|---|---|---|
| sensor-slug-login | 0 | 166ms | `$SERVER/src/adapter/.../auth.dto.ts` 등 | 슬러그 로그인 회귀 |
| sensor-webhook-dlq | 0 | 62ms | `$SERVER/prisma/schema.prisma` | DLQ 스키마 |
| sensor-refund-atomicity | 0 | 67ms | `$ROOT/grimoire-server` | 환불 원자성 |
| sensor-payment-status-mapping | 0 | 85ms | `$ROOT/grimoire-server` | Polar status 매핑 |
| sensor-payment-retry-reuse | 0 | 201ms | grimoire-server | 재시도 재사용 (최대 지연) |
| sensor-subscription-pool-no-rollover | 0 | 61ms | `$ROOT/grimoire-server` | 구독 풀 이월금지 |
| sensor-user-soft-delete-policy | 0 | 95ms | grimoire-server | soft-delete 정책 |
| sensor-audit-retention-policy | 0 | 102ms | `$ROOT/grimoire-server` | 감사 보존 |
| sensor-audit-log-before-after | 0 | 99ms | grimoire-server | 감사 before/after |
| sensor-circuit-breaker-policy | 0 | 58ms | grimoire-server | CB 정책 |
| sensor-credit-denomination | 0 | 67ms | grimoire-server | 크레딧 단위 |
| sensor-credit-overhaul-recalc | 0 | 66ms | grimoire-server | 크레딧 개편 재계산 |
| sensor-credit-source-accounting | 0 | 69ms | grimoire-server | 적립 출처 회계 |
| sensor-chat-charge-tier | 0 | 82ms | grimoire-server | 채팅 과금 tier |
| sensor-oauth-email-verification | 0 | 62ms | grimoire-server | OAuth 이메일 검증 |
| sensor-polar-timeout-policy | 0 | 61ms | grimoire-server | Polar timeout |
| **sensor-partial-refund** | **2 (이미 FAIL)** | 61ms | grimoire-server | ⚠️ clean tree에서 PASS7/FAIL3 — 기존 결함 검출 中 |
| **sensor-payment-race-condition** | **1 (이미 FAIL)** | 57ms | grimoire-server | ⚠️ clean tree에서 PASS6/FAIL2 — 기존 결함 검출 中 |

> A군 합산 실행시간 ≈ **1.57초** (순차). 결정성: `sensor-payment-idempotency` 3회 반복 all exit=0 확인. side-effect: 18개 모두 incident-log/state append/git 변경 0(§5 무한루프 점검에서 확인).
> ⚠️ **partial-refund / payment-race-condition는 지금 FAIL** → 배선 시 반드시 WARN 격리(아래 §3-3). 이건 센서 오탐이 아니라 코드가 기대 패턴 미충족 — grimoire-server/qa 도메인 결정 사항(별도 incident).

### 2-A 경계(半): 이미 디스패처에 있으나 A 성격인 것 (참고, 추가 불필요)

`sensor-payment-idempotency`(0/51ms)·`sensor-payment-reconciliation`(0/53ms)·`sensor-admin-credit-ui`(0/69ms)·`sensor-chat-domain`(0/82ms)·`sensor-shared-contracts`(0/113ms)·`sensor-docs-sync`(0/48ms)·`sensor-instruction-degradation`(WARN1/77ms) = **이미 adversarial-pre-commit 디스패치 중**. 별도 배선 불필요(중복 방지).

### 2-B. 자동부적합·정상 (19) — 배선 금지

| 센서 | 사유 (실측 의존) |
|---|---|
| sensor-azure-env-secret | `az` CLI (live Azure) |
| sensor-deploy-health | `az` + `curl` (live endpoint) |
| sensor-deploy-drift | `az` + `curl` + `git fetch`/`git log` (live + 원격) |
| sensor-security-gate | `curl` (live endpoint) |
| sensor-server | `npm test` + `tsc` (빌드/테스트 — 무거움, 별도 PostToolBatch tsc가 이미 담당) |
| sensor-web | `npm test` + `tsc` (동) |
| sensor-eval-trend | eval 결과 시계열 (live state, baseline.csv) |
| sensor-context-budget | transcript/세션 토큰 (live) |
| sensor-orchestration-ratio | 세션 Task 비율 (live state) — 이미 SubagentStop telemetry |
| sensor-hook-effectiveness | edit-write/skill-trigger/incident jsonl 시계열 (live state read) |
| sensor-harness-self-diagnose | 자가진단 종합 (메타, 정보성) |
| sensor-skill-invocation-rate | skill 발동 시계열 (live state) |
| sensor-feedback-promotion | **STUB** (항상 exit0, 후보 식별 정보성) |
| sensor-hit-rate-report | **STUB** (정보성 리포트) |
| sensor-fake-email-leak | **GUARDED→INJECTABLE이나** selftest 전용 fixture 경로. 자동배선 시 매 Edit grep `@grimoire.app` 가능하나 EXISTENCE성 약함 — 보류 |
| sensor-knowledge-drift | INJECTABLE이나 `.claude/knowledge` orphan 검출 = harness 도메인 한정, 매 Edit 부적합 |
| sensor-red-team-source-whitelist | 인자 기반 detector (URL 인자 필요) — 디스패처 무인자 호출에 부적합 |
| **sensor-response-zero-realtime** | ⚠️ **GUARDED — fire 시 incident-log.jsonl append side-effect** (라인 67~68 실측). 자동 배선 시 매번 incident 누적 → **절대 무인자 자동배선 금지** |
| sensor-loop-detection | GUARDED — 실 state(오늘 data 대용량) 의존, backup/restore 필요 |

> sensor-azure-* / deploy-* / security-gate / server / web는 **이미 skill로 半배선**(deploy-precheck/dev-health-check/prod-deploy/requesting-code-review 등) — 배포·검증 시점에 호출되는 게 정상. 매 커밋·Edit 배선은 과부하 + live 의존으로 오프라인 FAIL.

### 2-C. 죽은코드 후보 (3) — 호출처가 `_archive`뿐

| 센서 | 유일 호출처 | 판정 |
|---|---|---|
| sensor-skill-paths-coverage | (자동 0 / skill 0 / selftest는 GUARDED SKIP) | **고아 + baseline 이미 exit2** — 활성 호출처 0. 죽은코드 강력 후보. 단 폐기 전 grimoire-harness 확인 필요(skill frontmatter 검증 용도일 수 있음) |
| sensor-agent-interaction | `sensors-overview`(카탈로그) + `_archive` 간접 | 카탈로그 외 활성 호출 0 — 半죽음 |
| sensor-agent-priority-labels | (자동 0 / 활성 skill 0) | 활성 호출 0 — 半죽음 (agent .md priority 라벨 검증 = EXISTENCE) |

> `_archive` skill 5종(`dispatching-parallel-agents`/`red-team-update-propose`/`shared-contracts-check`/`feedback-to-skill`/`handover-refresh`)은 모두 `disable-model-invocation: true` + `_archive/` 위치 → 자동 발동 불가, 사용자 명시 호출도 사실상 dormant. 이들이 부르는 `sensor-feedback-promotion`/`sensor-hit-rate-report`는 STUB라 무해.
> **C군은 "배선" 대상이 아니라 "폐기 검토" 대상** — P3 배선 범위 밖. 별도 gc-sweep 안건으로 분리 권고.

---

## 3. 디스패처 설계 옵션 (A군 18 대상)

### 3-1. 이벤트 선택 — 3안 비교

| 안 | 이벤트 | A군 18 실행 빈도 | 지연 영향 | 평가 |
|---|---|---|---|---|
| **안 1 (추천)** | **커밋 시점** = `sensor-adversarial-pre-commit.sh` 도메인 블록 확장 (`.githooks/pre-commit` + `pretooluse-redteam-gate`가 공유) | 커밋당 1회 | +1.6초/커밋 (기존 ~수초 게이트에 합산) | ✅ 결제/크레딧/감사 "정책" 센서는 **커밋 단위 정합**. 기존 디스패처 재사용=새 hook 0. 경로 1·2 동시 커버. |
| 안 2 | PostToolBatch (배치 일괄) | 배치(여러 Edit 묶음)당 1회 | +1.6초/배치 | △ tsc(90s timeout)와 같은 이벤트. 매 배치 1.6초는 잦음. 정책 센서엔 과함(미커밋 중간 상태도 검사 → 오탐). |
| 안 3 | PostToolUse(Edit/Write) 매 Edit | Edit당 1회 | +1.6초/**매 Edit** | ❌ **금지**. 파일 1개 고치는데 18센서 1.6초 → 메인 작업 체감 지연. partial-refund/race FAIL이 매 Edit block. |

**근거**: 결제/크레딧/감사 정책 센서는 "이 변경을 영구화(commit)해도 정책 불변인가"를 보는 것이라 **커밋 시점이 의미론적으로 맞다**. 매 Edit은 중간 미완성 상태를 검사해 오탐 폭증 + 지연.

### 3-2. 성능 (실측 기반 지연 추정)

- 센서당 실측: 50~201ms (median ≈ 67ms). A군 18 순차 합 ≈ **1.57초**.
- 기존 `sensor-adversarial-pre-commit` 자체도 13센서 + cost/contracts 호출 → 이미 수초 게이트. +1.6초는 상대 증가 작음.
- **병렬화 옵션**: A군은 상호 독립(공유 state 쓰기 0) → `xargs -P 4` 병렬 시 ≈ 0.4~0.5초로 단축 가능. 단 출력 순서 섞임 → 결과 집계 로직 필요. **1차엔 순차 권고**(단순/결정적), 지연 문제되면 병렬 후속.

### 3-3. 실패 처리 — block vs warn (기존 게이트와 충돌 점검)

**현 게이트 컨벤션 (실측)**: `.githooks/pre-commit` 라인 47~64 = `sensor-adversarial-pre-commit` exit≥2 → 커밋 차단(exit1), exit1(WARN) → 허용. 내부 `check N "라벨" PASS|WARN|FAIL` 함수가 WARN/FAIL 집계.

**충돌 위험 (결정적)**: A군 18 중 `sensor-partial-refund`(exit2)·`sensor-payment-race-condition`(exit1)이 **지금 FAIL**. 이를 그대로 디스패처 FAIL로 올리면 → adversarial exit≥2 → **모든 커밋 즉시 차단**(현재 통과 중인 커밋도 막힘). 회귀.

**권고 실패 처리**:
1. 신규 배선 센서는 1차 전부 **WARN 등급**으로 추가 (`check N "..." WARN`). 즉 **block 아님 — 보고만**. 기존 통과 커밋 영향 0.
2. 센서가 clean tree에서 exit0인 것만(16/18) 추후 FAIL 승격 후보. partial-refund/race-condition은 **먼저 grimoire-server가 코드 결함 해소** → exit0 확인 후에만 FAIL 승격.
3. adversarial-pre-commit 외 **별도 게이트 신설 금지** (중복·충돌 회피). 단일 게이트 원칙 유지.

### 3-4. 멱등·잔존 fixture 안전성 (RESIDUE_CLEAN 개념)

- A군 18은 **모두 read-only grep**(tracked 파일 스캔) → fixture 생성 0, state append 0, git index 변경 0. selftest의 `verify_no_residue` 대상 패턴(`.selftest-fixture-*`/`selftest-orphan.md`) 미생성. **멱등 보장**.
- 대조군(배선 금지): `sensor-response-zero-realtime`은 fire 시 incident-log append → 매 커밋 누적 → **비멱등**. B군 유지 필수.
- 결론: A군 배선은 RESIDUE 안전. 단 **무인자 호출 가정** — `sensor-red-team-source-whitelist`처럼 인자 필요한 건 A군에서 제외(B로 분류 완료).

---

## 4. 권고안 + 단계적 구현 계획 (구현은 사용자 승인 후 별도)

### 4-1. 추천 배선 방식 (1개)

> **`sensor-adversarial-pre-commit.sh`의 도메인 센서 루프(라인 116~118)에 A군을 WARN 등급으로 증분 추가.** 새 hook·새 settings.json 등록 0. 경로 1(githook)·2(redteam-gate)가 자동 공유. 매-Edit/PostToolBatch hook 추가는 하지 않는다.

이유: (a) 디스패처가 이미 존재·검증됨, (b) 커밋 시점이 정책 센서에 의미론적 정합, (c) settings.json 무변경 → 자기잠금/배포 영향 0(2026-05-29 permission.deny 자기잠금 사태 교훈), (d) WARN 등급 → 기존 커밋 회귀 0.

### 4-2. 우선순위 3 batch (한 번에 18개 금지)

| Batch | 센서 (수) | 사유 | 위험도 |
|---|---|---|---|
| **1차 — 결제/크레딧 정책 (9)** | refund-atomicity, payment-status-mapping, payment-retry-reuse, subscription-pool-no-rollover, credit-denomination, credit-overhaul-recalc, credit-source-accounting, chat-charge-tier, polar-timeout-policy | §0 원가·결제 정합 = 사용자 최우선 도메인. 전부 clean exit0. | 낮음 (WARN) |
| **2차 — 감사/인증/CB (5)** | audit-retention-policy, audit-log-before-after, circuit-breaker-policy, user-soft-delete-policy, oauth-email-verification | 보안·감사 정책. 전부 clean exit0. | 낮음 (WARN) |
| **3차 — 웹/회귀 (2)** | slug-login, webhook-dlq | 도메인 회귀. clean exit0. | 낮음 |
| **보류 — 코드결함 선행 (2)** | partial-refund(exit2), payment-race-condition(exit1) | **배선 전 grimoire-server가 코드 결함 해소 필수.** 지금 배선 시 WARN으로도 잡음. | 중 (선행 의존) |

각 batch: 추가 → `bash -n` syntax → `--list`/`--all` selftest 회귀 → adversarial-pre-commit 전체 PASS 재확인 → 다음 batch. **batch 간 커밋 분리.**

### 4-3. 롤백 방법

- 단일 파일(`sensor-adversarial-pre-commit.sh`) 도메인 루프 증분이므로 → `git revert` 1 커밋 or 루프에서 센서명 제거. settings.json 무변경이라 hook 재등록/해제 불요 = **롤백 비용 최소**.
- 자기잠금 위험 0(permission/hook 등록 무변경).

---

## 5. 위험 (전수 점검 실측)

| 위험 | 실측 결과 | 완화 |
|---|---|---|
| **매 도구호출 지연** | A군 18 = 1.6초. 매 Edit 배선 시 메인 체감 지연 | ✅ 커밋 시점만 배선(안1) → 매 Edit 영향 0 |
| **오차단 (false block)** | partial-refund/race-condition 지금 FAIL → block 시 전 커밋 차단 | ✅ 신규 전부 WARN 등급, FAIL 승격은 exit0 확인 후 |
| **무한루프 (센서가 도구/CLI 호출)** | `grep 'claude (run\|-p\|chat\|code)'` = **0건**, `git commit/push` 실행 = **0건**. 센서는 도구/CLI 미실행 | ✅ 재귀 위험 없음 |
| **잔존 fixture (비멱등)** | A군 18 = read-only grep, append 0. `response-zero-realtime`(incident append)은 B 유지 | ✅ A군 멱등, side-effect 센서 배제 |
| **기존 게이트 충돌/중복** | 별도 게이트 신설 X, 단일 adversarial 디스패처 확장. payment-idempotency 등 7종은 이미 등록(중복 회피 §2-A경계) | ✅ 단일 게이트, 중복 명시 제외 |
| **EXTERNAL 오프라인 FAIL** | az/curl/gcloud/npm-test 센서를 배선하면 오프라인 시 게이트 영구 FAIL | ✅ B군 19 전부 배선 금지 |
| **인자 의존 센서 오동작** | red-team-source-whitelist는 URL 인자 필요 → 무인자 호출 시 오판 | ✅ B군 분류(배선 제외) |

---

## 6. 부록 — 실측 명령 및 재현

- 자동 체인 센서 집합 산출: `comm -23 <전체 56> <REFD 16>` = 고아 40.
- 실행시간/exit: `/bin/bash --noprofile --norc <sensor> ; echo $?` + python time delta (프로필 비간섭, selftest run_rc와 동일 방식).
- 결정성: `sensor-payment-idempotency` 3회 all exit=0.
- side-effect: `grep -lE 'incident-log' sensor-*.sh` → response-zero-realtime/hook-effectiveness/adversarial/selftest만(A군 18 미포함).
- 재귀: `grep 'claude (run|-p|chat|code)'` 0건, `git commit|push` 실행 0건.
- githook 활성: `git config core.hooksPath` = `.githooks` (3 레포).

> 본 제안서는 **분석·제안 전용**. 구현·편집·커밋·settings.json 변경 0건. 배선 실행은 사용자 승인 후 grimoire-harness가 §4-2 batch 순서로 진행.
