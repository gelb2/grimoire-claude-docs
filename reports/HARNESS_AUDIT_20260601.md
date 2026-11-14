# HARNESS_AUDIT — 적대적 전수 감사 (2026-06-01)

> 판정 기준: "진짜 규율 강제냐, 알림만 던지는 연극이냐". 읽기 전용 진단 — **수정 0건 / 파일 삭제 0건**.
> 모든 판정에 RAW 증거(코드 라인 인용 / grep 출력 / 라이브 테스트 exit code) 동반. 증거 없는 항목은 "미검증" 명시.
> 거짓 PASS 금지 (2026-05-29 정직성 사태 재발 차단).

---

## 종합 VERDICT: **부분 연극 (Partial Theater)**

하네스는 **강제와 연극·쓰레기가 명확히 분리된 2층 구조**다.

| 층위 | 실태 | 증거 |
|---|---|---|
| **진짜 강제 (REAL)** | PreToolUse 3 가드(edit-write / bash / redteam) + pre-commit adversarial-pre-commit + failure-handler `decision:block` | 라이브 테스트 exit 2 / decision:block 전건 재현됨 |
| **부분 연극 (PARTIAL)** | eval 게이트(75 task) — 단일 sensor FAIL은 commit 차단 못 함(1.33%p < 5%p tolerance), eval-runner는 `--strict` 없으면 항상 exit 0 | eval-runner.sh L255-261 + 회귀 산수 실측 |
| **순수 연극 (THEATER)** | loop-detection 임계 로직 미구현(append만) / sidechain_edits 구조적 영구 0 / orchestration sidechain 추적 불능 | python 코드에 count·alert 부재 / isSidechain:true 0회 / subagents/ 디렉토리 미스캔 |
| **쓰레기 (GARBAGE)** | tmp 25,313개 누수 + sensor-hits.jsonl TTL prune 영구 작동 불능 / 6개 frozen jsonl / 4개 dead script / feedback-promotion 713KB write-only | awk 3-arg match BSD 비호환 재현 / mtime frozen / grep 참조 0 |

**핵심 결론**: 메인의 코드/배포 직접 행위를 막는 "1차 방어선"(PreToolUse 가드 + 커밋 게이트)은 **실제로 작동한다**(라이브 검증 완료). 그러나 그 위에 쌓은 "관측·측정·자가진단" 레이어(eval 정밀도, orchestration ratio, loop detection, sensor-hits 집계)는 **상당 부분 측정 불능이거나 데이터 쓰레기를 누적**하고 있다. 강제는 진짜, 계측은 연극에 가깝다.

---

## Q1 [temp 파일 누수 근본원인] — **FAIL (확정 재현)**

### 근본 원인: `sensor-log.sh` L36-40 의 `awk` 3-인자 `match()` 가 macOS BSD awk에서 syntax error

`sensor-log.sh` (유일한 tmp 생성자, `grep -rln '\.tmp\.\$\$'` 결과 1건):

```bash
# L31-42 — 7일 TTL prune
if [ -f "$LOG_FILE" ]; then
  CUTOFF=$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ ...)
  if [ -n "$CUTOFF" ]; then
    TMP="$LOG_FILE.tmp.$$"
    awk -v c="$CUTOFF" '
      match($0, /"ts":"([^"]+)"/, m) {   # ← 3-인자 match(): GNU gawk 전용 확장
        if (m[1] >= c) print
      }
    ' "$LOG_FILE" > "$TMP" 2>/dev/null && mv "$TMP" "$LOG_FILE"
  fi
fi
```

### 메커니즘 (라이브 재현)

```
$ awk --version → "awk version 20200816"  (BSD awk, GNU 아님)
$ echo '{"ts":"..."}' | awk 'match($0,/regex/,m){...}' 2>&1
  awk: syntax error at source line 1
  context is  match($0, >>> /"ts":"([^"]+)"/, <<<
  EXITCODE=2
```

실제 파이프라인 재현 (`/tmp` 격리 테스트):
```
awk+mv pipeline exit=2
TMP still exists? YES size=0      ← 빈 tmp 잔존
LOG_FILE line count: 1 (변화 없음)  ← mv 실행 안 됨
```

**3단 고장 사슬**:
1. BSD awk가 3-인자 `match()` 를 syntax error 처리 → exit 2, stdout 없음 → `$TMP` 가 **size 0**으로 생성됨 (`> "$TMP"` 는 awk 실패와 무관하게 빈 파일 생성).
2. `awk ... > "$TMP" && mv ...` — awk가 비-0 종료 → **`&&` 단락(short-circuit)** → `mv` 영구 미실행.
3. cleanup trap 부재 → 빈 `$TMP` (`sensor-hits.jsonl.tmp.<PID>`) 가 매 호출마다 영구 잔존.

### 2차 파급 (더 심각): **7일 TTL prune이 단 한 번도 작동한 적 없음**

- prune이 영구 실패하므로 `sensor-hits.jsonl` 은 무한 증가 → 현재 **3.9MB** (Apr30~).
- tmp 누수 25,313개 = Apr30~May31 sensor-log.sh 호출 횟수 (호출당 1개).
- 파일명 범위 실측: 가장 오래된 `tmp.41496` = Apr 30 15:29 / 최신 `tmp.49736` = May 31 13:45.

### 다른 `*.tmp.*` 누수 패턴: 없음
- `find .claude/state -name '*.tmp*' | grep -v 'sensor-hits.jsonl.tmp'` → 0건.
- `generate-report-template.sh` 도 `.tmp` 문자열을 갖지만 누수 미발생(별도 mktemp 패턴, frozen 무관).

**우선순위: P0** (디스크 inode 고갈 위험 + TTL 미작동으로 sensor-hits.jsonl 무한 증가).

---

## Q2 [dead code] — **PARTIAL (진짜 dead 4건 + 사용 중단 다수)**

86개 중 settings/scripts/skills/agents/githooks/eval 어디에서도 **호출체인 0**인 진짜 dead script:

| script | 참조 증거 | 판정 |
|---|---|---|
| `cost-tracker.sh` | ev=0 self=0 hit=0 adv=0, settings 미등록, 헤더 "수동 박제 모드"(자동 호출 설계 아님), cost-tracker.jsonl **frozen May 2** | **DEAD** (수동 규율 의존 → 중단됨) |
| `generate-skill-graph.sh` | 호출자 0 (자기 참조만), 산출물 skill-graph.json **frozen Apr 26** | **DEAD (orphan)** |
| `orchestration-classify.sh` | hit-rate에 이름만 2회, 호출자 0. 산출물 orchestration-classifications.jsonl **frozen May 2** | **DEAD** (이름만 박제) |
| `deploy-all.sh` / `deploy-prod.sh` | skills/agents 문서엔 참조 존재. 그러나 헤더 "GitHub Actions Billing 실패 시 우회" = **Azure 레거시**. 2026-05-27 GCP 마이그레이션으로 `make deploy-*` 가 정본 | **레거시-STALE** (문서 참조는 있으나 superseded, 위험) |

"이름만 나열(listed-only)" 계층 — eval 미wrap + adversarial 미consume, selftest/hit-rate에 **문자열로만** 존재 → 사람이 수동 호출해야만 작동:
- `sensor-hook-effectiveness.sh` (ev=0 adv=0, selftest EXTERNAL 분류만)
- `sensor-response-zero-realtime.sh` (ev=0 adv=0, hit-rate 이름 2회)
- `sensor-skill-invocation-rate.sh` (ev=0 adv=0, selftest 이름만)

**중요 반증(처음 EXT=0이었으나 dead 아님)**: 첫 grep에서 EXT=0이던 sensor 대부분은 `eval/tasks/`(auto-sensor-*.json + regression-*.json)에 wrap되어 **pre-commit eval-runner로 호출됨**. 47 sensor가 eval-wrapped. 즉 "settings.json 미등록 = 69개"는 dead가 아니라 **eval 경로로 호출**되는 것이 다수.

**우선순위: P2** (dead script는 오작동 위험 낮음. 단 deploy-prod.sh/deploy-all.sh Azure 레거시는 실행 시 사고 위험 → P1).

---

## Q3 [알림전용 vs 강제] — **PARTIAL**

block-incapable sensor(exit 2 없음)의 소비 경로 분류. **핵심: "eval-wrapped"는 강제가 아니다** — eval-runner는 `--strict` 없으면 항상 exit 0이고(L255-261), eval-precommit는 회귀 5%p 초과만 차단하므로 단일 sensor FAIL(1/75=1.33%p)은 commit을 막지 못함(Q4 산수 참조).

| sensor | 소비 경로 | 분류 |
|---|---|---|
| sensor-cost-margin | adversarial-pre-commit P4가 EC 직접 소비 → FAIL시 commit 차단 | **(a) consumed (강제)** |
| sensor-credit-atomicity | adversarial P16 EC 소비 (단 P16은 exit≤2 WARN 처리, ≥3만 FAIL) | **(a) consumed** |
| sensor-secret-leak | adversarial P13 EC 소비 (≥3만 FAIL) | **(a) consumed** |
| sensor-shared-contracts | adversarial P6 EC 소비 (≥3만 FAIL) | **(a) consumed** |
| sensor-instruction-degradation | adversarial P7 EC 소비 + pre-commit 단독 호출 | **(a) consumed** |
| sensor-server / sensor-web / sensor-docs-sync / sensor-payment-idempotency / sensor-payment-reconciliation / sensor-admin-credit-ui / sensor-chat-domain | adversarial P8 루프에서 EC>2만 카운트 | **(a) consumed** (단 FAIL=exit≥3 한정) |
| sensor-refund-atomicity, sensor-payment-status-mapping, sensor-payment-retry-reuse, sensor-subscription-pool-no-rollover, sensor-credit-denomination, sensor-credit-overhaul-recalc, sensor-credit-source-accounting, sensor-chat-charge-tier, sensor-polar-timeout-policy, sensor-audit-retention-policy, sensor-audit-log-before-after, sensor-circuit-breaker-policy, sensor-user-soft-delete-policy, sensor-oauth-email-verification, sensor-slug-login, sensor-webhook-dlq | adversarial **P3 블록(L271-292)에서 호출되나 명시적 "WARN 격리"** — L293 "이 블록은 FAIL 미발생, commit 차단 신호 없음". eval-wrap도 됨(단일 FAIL 차단 불가) | **(b) notification (보고 전용)** |
| sensor-eval-trend, sensor-context-budget, sensor-harness-cross-ref, sensor-harness-self-diagnose, sensor-loop-detection, sensor-skill-paths-coverage, sensor-agent-priority-labels, sensor-agent-interaction, sensor-feedback-promotion, sensor-knowledge-drift, sensor-fake-email-leak, sensor-red-team-source-whitelist 등 | eval-wrap만(차단 불가) 또는 selftest 분류만 | **(b) notification** |
| sensor-hook-effectiveness, sensor-response-zero-realtime, sensor-skill-invocation-rate | 어디서도 EC 소비 안 됨, eval 미wrap | **(c) dead (수동 전용)** |

**증거 인용** — adversarial-pre-commit.sh L116-122 (P8 핵심 sensor만 FAIL 게이트):
```bash
for s in sensor-server sensor-web sensor-docs-sync sensor-secret-leak sensor-credit-atomicity \
         sensor-payment-idempotency sensor-payment-reconciliation sensor-admin-credit-ui sensor-chat-domain; do
  bash "$ROOT/.claude/scripts/$s.sh" >/dev/null 2>&1; EC=$?
  [ "$EC" -gt 2 ] && SENSOR_FAIL=$((SENSOR_FAIL+1))   # exit≥3만 FAIL 카운트
done
```
L293 (P3 16종 WARN 격리 자백):
```
echo "  (P3 배선 16종 — WARN 격리: 이 블록은 FAIL 미발생, commit 차단 신호 없음. ...)"
```

**판정**: 진짜 강제는 약 **16 sensor**(adversarial가 EC>2를 FAIL로 소비). 나머지 ~20 sensor는 보고 전용(P3 WARN 격리 + eval-wrap 차단 불가). 3 sensor는 수동 전용(dead).

---

## Q4 [등록 훅 17개 실효성] — **PARTIAL** (3 진짜 차단 + 3 컨텍스트 주입 + 11 알림/기록 전용)

라이브 기능 테스트 결과:

| 훅 | 이벤트 | 동작 | 라이브 테스트 |
|---|---|---|---|
| **pretooluse-edit-write-guard** | PreToolUse Edit/Write | **차단(exit 2)** | 코드경로→`EXIT=2`, harness경로→`EXIT=2`, reports경로→`EXIT=0`, agent_id셋→`EXIT=0`. **진짜 강제** |
| **pretooluse-bash-guard** | PreToolUse Bash | **차단(exit 2)** | `rm -rf src`→`EXIT=2 (destructive)`, `git push`→`EXIT=2 (mutating-git)`, `ls`→`EXIT=0`. **진짜 강제** |
| **pretooluse-redteam-gate** | PreToolUse Bash | **차단(exit 2 조건부)** | `git commit`→adversarial 호출→현재 exit=1(WARN)→`EXIT=0 통과`. `echo`→`EXIT=0`. adversarial가 ≥2면 차단(메커니즘 확인). **진짜 강제(조건부)** |
| **posttooluse-failure-handler** | PostToolUseFailure | **decision:block JSON** | force-push 실패→`{"decision":"block",...}` 출력, 일반실패→silent append. **진짜(Claude Code honored)** |
| skill-injector | UserPromptSubmit | additionalContext 주입 (L126-128) | exit 0, hookSpecificOutput.additionalContext. **컨텍스트 주입(비차단)** |
| user-prompt-memory-check | UserPromptSubmit | 컨텍스트 주입 | 비차단 |
| post-response-skill-injector | Stop | 컨텍스트 주입 (단 post-response-skill-trigger.jsonl **frozen May 6** = 트리거 경로 사실상 죽음) | 비차단 |
| check-memory-freshness | SessionStart | `exit 0`만 (L11/18/45) | **알림 전용** |
| stop-memory-guard | Stop | `exit 0`만 (L26/63/113 — 이름과 달리 Stop 차단 안 함) | **알림 전용** |
| instructions-drift-check | InstructionsLoaded + pre-commit | 모든 경로 `exit 0`/`sys.exit(0)` | **알림 전용** (pre-commit `set -e`도 비-0 미발생) |
| post-batch-tsc | PostToolBatch | "차단 안 함, stderr 경고만" (L8) | **알림 전용** |
| post-edit-tsc | PostToolUse | "tsc 실패해도 exit 0" (L13) | **알림 전용** |
| post-edit-spec-check | PostToolUse | "이 경고는 차단이 아닌 알림" (L92), 항상 exit 0 | **알림 전용** (+ sensor-log 호출 → Q1 tmp 누수 유발) |
| **loop-detection-tracker** | PostToolUse | append만 — **헤더는 "MAX_EDITS=5 초과시 ALERT" 약속하나 python L56-64는 count·비교·alert 전무** | **연극(미구현)** |
| subagent-stop-handler | SubagentStop | sensor-orchestration-ratio + sensor-log 호출 후 exit 0 (Anthropic 명세상 차단 불가) | **관측 전용 (Q6 추적 불능)** |
| generate-report-template | PostToolUse Task | 리포트 템플릿 scaffold, 기존 SKIP | **기능적(비차단)** |

**loop-detection-tracker 연극 자백** — 헤더 L13-16:
```
# 임계값: 정상 1~4회 / WARN 5회 / FAIL 6회 이상
```
실제 python (L56-64): `entry={ts,date,tool,file}; f.write(json.dumps(entry))` — **카운트도 임계 비교도 ALERT도 없음**. loop-detection.jsonl(247KB)은 write-only, 소비자는 sensor-loop-detection.sh(eval-wrap만, 차단 불가).

**우선순위**: loop-detection 임계 미구현 = P2(연극). post-response-skill-trigger frozen = P2.

---

## Q5 [거대 산출물·로그] — **FAIL (거대 dead artifact 다수)**

### skill-graph.json (13.9MB)
- **소비자: 없음.** `grep -rln 'skill-graph.json'` → `generate-skill-graph.sh` 단독(자기 참조: L10 주석 / L21 OUTPUT / L166 md 문자열). 읽는 코드 0.
- **generate-skill-graph.sh 트리거: 없음(orphan).** 어떤 훅·스크립트·skill·agent도 호출 안 함.
- **frozen Apr 26 21:17** = 마지막 수동 실행. → 13.9MB **순수 dead artifact**.

### state jsonl 19개 소비 분류 (READER = 내용 소비 / WRITE-ONLY = 적재만)

| jsonl | 크기 | READER (소비처) | 판정 |
|---|---|---|---|
| sensor-hits.jsonl | 3.9MB | statusline.sh L150 (WARN 집계, 라이브) + sensor-hit-rate-report.sh (수동) | **소비됨** (단 Q1로 무한증가) |
| cost-margin.jsonl | 340KB | statusline.sh L67-68 `tail -1` | **소비됨(라이브)** |
| deploy-drift.jsonl | 30KB | statusline.sh L88-89 `tail -1` | **소비됨(라이브)** |
| incident-log.jsonl | 115KB | adversarial P20 / redteam-gate / stop-memory-guard / sensor-hook-effectiveness | **소비됨** |
| loop-detection.jsonl | 247KB | sensor-loop-detection.sh(eval-wrap, 차단불가) | 준-write-only |
| tool-failures.jsonl | 130KB | (소비처 grep 0 — failure-handler가 append만) | **WRITE-ONLY** |
| **feedback-promotion-candidates.jsonl** | **713KB** | sensor-feedback-promotion.sh가 **OUTPUT으로 write만**, READER 0 | **WRITE-ONLY 쓰레기** |
| sensor-selftest-results.jsonl | 145KB | (write-only, selftest 자기 적재) | WRITE-ONLY |
| cost-tracker.jsonl | 530B | (cost-tracker.sh dead) frozen May 2 | dead |
| **sidechain-debug.jsonl** | 27KB | **writer 코드 0** (현 스크립트 중 아무도 안 씀) frozen May 15 | **orphan artifact** |
| **main-blocked-log.jsonl** | 11KB | **writer 코드 0** frozen May 15 | **orphan artifact** |
| orchestration-classifications.jsonl | 1KB | orchestration-classify.sh(dead) frozen May 2 | orphan |
| hook-effectiveness.jsonl | 318B | sensor-hook-effectiveness.sh(dead) frozen May 6 | orphan |
| red-team-data-pending.jsonl | 1.3KB | red-team-data-collector.sh frozen May 3 | 준-orphan |
| post-response-skill-trigger.jsonl | 1.7KB | post-response-skill-injector(등록됨) but frozen May 6 = 트리거 경로 죽음 | 준-orphan |
| skill-invocation-rate.jsonl | 768B | sensor-skill-invocation-rate(dead) | 준-orphan |
| orchestration-ratio.jsonl | 164KB | (writer만 = sensor-orchestration-ratio) READER 0 | WRITE-ONLY (Q6) |
| bash-guard-violation.jsonl | 5KB | bash-guard가 append만 | WRITE-ONLY (감사 로그) |
| edit-write-violation.jsonl | 5KB | edit-write-guard가 append만 | WRITE-ONLY (감사 로그) |

**판정**: write-only/orphan jsonl 다수. 특히 ① skill-graph.json 13.9MB dead ② feedback-promotion-candidates 713KB write-only ③ sidechain-debug/main-blocked-log = writer조차 없는 유령 파일.

**우선순위: P2** (관측 데이터 쓰레기, 강제엔 영향 없으나 디스크·혼선 유발).

---

## Q6 [sidechain=0 추적 불능] — **FAIL (구조적 추적 불능 = 연극)**

### orchestration-ratio의 sidechain_edits는 영구 0 — 측정 불능

`sensor-orchestration-ratio.sh` L71 glob: `glob.glob(JSONL_DIR + "/*.jsonl")` — **최상위 transcript만 스캔**.
L123: `sidechain = obj.get('isSidechain', False)` → L129 `if sidechain: sidechain_edits += 1`.

### RAW 증거 1 — isSidechain:true는 전 transcript에서 0회

```
$ grep -ho '"isSidechain":true' <project>/*.jsonl | wc -l   → 0
$ grep -ho '"isSidechain":false' <project>/*.jsonl | wc -l  → 18,825
```
한 transcript의 top-level key 분석: `isSidechain` 737회 등장, **distinct values = {False}** 뿐.

### RAW 증거 2 — 에이전트 작업은 별도 `subagents/` 디렉토리에 저장됨 (이 sensor가 안 읽는 곳)

현 Claude Code 버전은 subagent 작업을 `<session-uuid>/subagents/*.jsonl` 에 분리 저장:
```
subagent jsonl 파일: 301개
subagents/ 내 Edit tool_use: 1,154회
subagents/ 내 Write tool_use:  321회
subagents/ 내 Bash tool_use: 5,701회
```
→ **에이전트는 막대한 작업(1,154 Edit + 321 Write)을 실제로 수행했으나**, `grep -rln 'subagents' .claude/scripts/` → **0건** (어떤 sensor·스크립트도 subagents/ 디렉토리를 읽지 않음).

### 결론
- `sidechain_edits=0`은 "에이전트가 0건 편집"이 아니라 **측정 코드가 데이터를 못 보는 추적 불능**.
- 원인: (a) isSidechain 필드가 이 버전에서 항상 false (b) 실제 데이터는 subagents/ 서브디렉토리에 있고 sensor는 최상위만 glob.
- orchestration-ratio의 `ratio=task_calls/main_edits`(0.5676 PASS)는 **spawn 횟수**로는 유효하나(L142 Task/Agent 매칭은 작동), `sidechain_edits/sidechain_writes` 컬럼은 **구조적 죽은 지표 = 연극**.
- subagent-stop-handler / sensor-agent-interaction 도 동일 한계(subagents/ 미스캔).

**증거 인용** — orchestration-ratio.sh L142 주석(과거 동종 사고 박제):
```bash
elif name in ('Task', 'Agent') and not sidechain:  # ... 'Task'만 매칭하던 결함 → 7일간 0건 거짓 측정 → 메인 Claude 거짓 보고 사슬 유발
```
→ 같은 클래스의 측정 결함(now isSidechain/subagents)이 **여전히 잔존**.

**우선순위: P1** (2026-05-29 정직성 사태의 본질이 "측정 거짓"이었고, 이 sidechain 추적 불능이 동일 클래스의 거짓 지표를 PASS로 보고 중).

---

## 결함 우선순위 리스트 (수정 금지 — 진단만)

### P0
1. **sensor-log.sh TTL prune 영구 작동 불능** (BSD awk 3-arg match 비호환) → ① tmp 25,313개 누수(inode) ② sensor-hits.jsonl 무한증가 3.9MB. 수정 방향: 3-arg match → `gawk`/`grep`/`python` 대체 + cleanup trap + `&&`→`;` 분리. (수정은 사용자/grimoire-harness 결정.)

### P1
2. **orchestration sidechain 추적 불능 = 거짓 PASS 위험** (Q6). isSidechain 항상 false + subagents/ 미스캔. ratio는 spawn만 유효, sidechain_edits는 구조적 0. 정직성 사태 동일 클래스.
3. **eval 게이트가 per-sensor 강제 아님** (Q3/Q4). eval-runner `--strict` 미사용 → 항상 exit 0. 단일 sensor FAIL(1.33%p) < tolerance 5%p → commit 통과. 6개 standing FAIL(`auto-sensor-security-gate 0/1`, regression-001/003/061/066/074)이 무기한 미차단 누적.
4. **deploy-all.sh / deploy-prod.sh Azure 레거시 잔존** (Q2). "GitHub Actions 우회" 헤더 = GCP 마이그레이션(5/27) 이전. skill/agent 문서 참조 살아있어 오실행 시 사고 위험.

### P2
5. **loop-detection-tracker 임계 로직 미구현** (Q4). 헤더는 MAX_EDITS=5 ALERT 약속, 코드는 append만. 247KB write-only.
6. **dead/orphan artifact**: skill-graph.json 13.9MB(소비 0) / feedback-promotion-candidates 713KB(write-only) / sidechain-debug·main-blocked-log(writer 코드조차 0인 유령 파일) / cost-tracker·generate-skill-graph·orchestration-classify(dead script).
7. **post-response-skill-trigger.jsonl frozen May 6** — 등록 훅(post-response-skill-injector)의 트리거 경로 사실상 죽음.
8. **sensor-hook-effectiveness / sensor-response-zero-realtime / sensor-skill-invocation-rate** = 수동 전용(eval 미wrap, adversarial 미consume) — 자동 강제 0.

### 강제가 진짜인 부분 (연극 아님 — 명시)
- PreToolUse edit-write-guard: 코드/harness 경로 차단(exit 2) 라이브 검증.
- PreToolUse bash-guard: destructive(rm)/mutating(push/commit) 차단(exit 2) 라이브 검증.
- PreToolUse redteam-gate: 위험명령 → adversarial-pre-commit EC 소비, ≥2면 차단(메커니즘 확인).
- pre-commit adversarial-pre-commit: 16 sensor EC>2 = FAIL 게이트 → exit 2 → commit 차단. (단 P3 16종은 WARN 격리.)
- posttooluse-failure-handler: force-push/reCAPTCHA/prod-Chrome 실패 → decision:block JSON(Claude Code honored).
- agent_id 우회 정상 작동(sub-agent 통과), 분류기(main-whitelist.sh) 존재·실행가능, 86 스크립트 syntax 0 error.

---

## 감사 방법론 메모 (재현 가능)
- 모든 판정은 라이브 stdin 주입 테스트(exit code 관찰) 또는 `/tmp` 격리 재현으로 검증. 추정 0건.
- "EXT=0 = dead" 단순 grep은 **반증됨**: eval/tasks wrap 경로를 누락하면 거짓 dead 판정. 호출체인을 eval-runner→pre-commit까지 추적해야 정확.
- "eval-wrapped = 강제" 도 **반증됨**: eval-runner 비-strict exit 0 + 회귀 tolerance 5%p로 단일 FAIL 미차단. 산수 실측 필수.
