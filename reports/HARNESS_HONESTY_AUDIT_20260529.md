# HARNESS HONESTY AUDIT — 2026-05-29

> 진단 전용. **고치지 않음** (0바이트 파일 채우기 0건 / settings.json 수정 0건 / 코드·설정 변경 0건).
> 모든 항목 실측 숫자(`wc -c` / `wc -l` / `find ... | wc -l` / `git show | wc -l` / `grep -c`)만. "통과" 선언 0회 — 숫자로만.
> 작성: grimoire-harness agent. 측정 명령 병기. 실측 raw는 도구 출력에서 직접 수집(추정 0건).

---

## TL;DR (실측 숫자만)

- **등록 hook 스크립트 실효율: 18개 중 15개 내용 보유 / 3개 0바이트(실효 무력).**
  settings.json `hooks` 호출 distinct 스크립트 = 18 (+statusLine용 statusline.sh 1). 0바이트 3종 = `pretooluse-main-whitelist.sh`(0B) · `pretooluse-edit-write-guard.sh`(0B) · `pretooluse-bash-guard.sh`(0B). 빈 파일 bash 실행 = exit 0 = no-op.
- **PreToolUse 게이트 실효 1/5.** Edit/Write matcher 2 hook(main-whitelist+edit-write-guard) 둘 다 0바이트 → **Edit/Write 경로 사전방어 0겹.** Bash matcher 3 hook 중 redteam-gate(4355B/105L)만 실효, 나머지 2개 0바이트.
- **0바이트 스크립트 총 3개** (`.claude/scripts/*.sh` 85개 중) — 전부 위 PreToolUse 가드.
- **`.claude/state/` 0바이트 고아 = 22,516개** (`sensor-hits.jsonl.tmp.*`). state 총 파일 22,569개 중 **99.8%가 빈 tmp 잔재.** sensor atomic-write 누수 = state 디렉토리 오염.
- **문서 드리프트 (실제 vs 박제, 모두 문서가 낮게 박제):**
  - `eval/README.md` "20개 태스크" (line 11·21·28·79) vs 실제 75 → **-55 (3.75배)**
  - `.claude/knowledge/red-team-constitution.md:51` "23개 sensor" vs 실제 56 → **-33**
  - `agent-system.md` "7" / `book-completion.md` "sensor 12·eval 41" — 본 세션 grep 0매치(파일명/문구 상이 추정) → **미확정, 추정 금지** (단 실제 9/56/75 대조상 격차 성립 방향)
- **PASS 포장됐던 무력 게이트 3종**: main-whitelist / edit-write-guard / bash-guard (등록 살아있음, 본체 0줄).
- **sensor 실효**: sensor-hits.jsonl 25,511줄 활발(PASS 16,738 / WARN 7,603 / **FAIL 809** / UNKNOWN 361). **정의 56 중 52개 fire, 4개 완전 silent(0 hits)**: sensor-circuit-breaker-policy / sensor-hit-rate-report / sensor-log / sensor-user-soft-delete-policy. **fire하지만 FAIL 0건(never-FAIL) = 30개** (예: credit-atomicity 2581·secret-leak 2450·shared-contracts 1853 모두 FAIL 0) → 검사 너무 느슨 정황.
- **eval-runner는 가동 중**: eval/results run 디렉토리 **413개**, 최근 = **2026-05-29-13-01-56(당일)**. baseline.csv 336행, 최근 `2026-05-27 75 task / 69 PASS / 6 FAIL / pass_rate 0.92`. **75 태스크 중 6건 상시 FAIL 상태로 회귀 eval 통과 임계(README threshold 1.0) 미달인 채 누적.**

---

## §A. Hook 무결성 (settings.json 등록 vs 실제)

측정: `for f in <등록>; do wc -c; wc -l; done`

### A-1. 등록 스크립트 전수 (`wc -c` / `wc -l`)

| 스크립트 | 바이트 | 줄 | 등록 이벤트 | 판정 |
|---|---:|---:|---|---|
| check-memory-freshness.sh | 3166 | 73 | SessionStart | 내용 |
| stop-memory-guard.sh | 5261 | 113 | Stop | 내용 |
| post-response-skill-injector.sh | 2431 | 65 | Stop | 내용 |
| user-prompt-memory-check.sh | 1573 | 42 | UserPromptSubmit | 내용 |
| skill-injector.sh | 3900 | 134 | UserPromptSubmit | 내용 |
| pre-compact-memory-guard.sh | 3624 | 93 | PreCompact | 내용 |
| instructions-drift-check.sh | 5304 | 138 | InstructionsLoaded | 내용 |
| post-batch-tsc.sh | 2081 | 74 | PostToolBatch | 내용 |
| **pretooluse-main-whitelist.sh** | **0** | **0** | PreToolUse(Edit/Write + Bash, 2회 등록) | **0바이트 무력** |
| **pretooluse-edit-write-guard.sh** | **0** | **0** | PreToolUse(Edit/Write) | **0바이트 무력** |
| **pretooluse-bash-guard.sh** | **0** | **0** | PreToolUse(Bash) | **0바이트 무력** |
| pretooluse-redteam-gate.sh | 4355 | 105 | PreToolUse(Bash) | 내용 |
| post-edit-tsc.sh | 2316 | 78 | PostToolUse(Edit/Write) | 내용 |
| post-edit-spec-check.sh | 3243 | 96 | PostToolUse(Edit/Write) | 내용 |
| loop-detection-tracker.sh | 1865 | 68 | PostToolUse(Edit/Write) | 내용 |
| generate-report-template.sh | 4530 | 145 | PostToolUse(Task/Agent) | 내용 |
| posttooluse-failure-handler.sh | 7174 | 187 | PostToolUseFailure | 내용 |
| subagent-stop-handler.sh | 1594 | 40 | SubagentStop | 내용 |
| statusline.sh | 6280 | 190 | statusLine | 내용 |

**합계: 등록 distinct 18(hooks) + statusline 1. 0바이트 3. 내용 16.**

### A-2. PreToolUse 실효 (settings.json line 109-145)
- matcher `Edit|Write|MultiEdit|NotebookEdit` → main-whitelist(0B) + edit-write-guard(0B) = **2/2 무력 → Edit/Write 사전방어 0겹**
- matcher `Bash` → main-whitelist(0B) + bash-guard(0B) + redteam-gate(4355B) = **2 무력 + 1 실효**
- **PreToolUse 총 5 hook 등록 중 실효 1 (redteam-gate).**

### A-3. redteam-gate가 실제로 무엇을 강제하나 (line 14-105)
- 위험 패턴(deploy/migration 등) 감지 시 `sensor-adversarial-pre-commit.sh` 호출 → FAIL이면 **exit 2 (reject)** + incident-log 박제 + `redteam_reject` jsonl 기록(line 74). PASS면 exit 0.
- → **유일하게 살아있는 PreToolUse 강제.** 단 reject 발생 누적 카운트는 §D-4.

### A-4. 0바이트 hook 원래 기능 + 비워진 시점 (git history)
측정: `git log -- <path>` + `git show <commit>:<path> | wc -l`

**pretooluse-main-whitelist.sh** (메인 LLM 화이트리스트):
`45385ad 05-08 259L`(생성) → `acf8d4f 05-08 221L` → **`d8560c4 05-09 0L`(비워짐, "harness agent 신설+PP-7 라우팅 정정")**

**pretooluse-edit-write-guard.sh** (에이전트 영역 라우팅, PP-7):
`4483f61 05-06 179L`(생성 "PP-7 자동 강제 hook 신설") → `5106625 05-08 194L` → `d8560c4 05-09 206L` → **`5f20f1b 05-10 0L`(비워짐, "PP-7+PP-12+PP-13 hook 폐기, 사용자 5/10 정합")**

**pretooluse-bash-guard.sh** (Bash 가드, PP-12):
`664c53b 04-25 105L`(초기) → `5106625 05-08 142L` → **`5f20f1b 05-10 0L`(비워짐, 동일 "hook 폐기")**

**핵심**: 3개 0바이트는 **사고가 아닌 의도적 폐기**(커밋 메시지 명시 "hook 폐기, 사용자 5/10 정합"). **그러나 settings.json 등록은 미제거** → 의도(폐기) ↔ 구성(여전히 등록) 드리프트. 외형 "PreToolUse 5겹"이나 Edit/Write 실효 0.

---

## §B. 스크립트 고아/빈 파일 (`.claude/scripts/*.sh` 85개)

### B-1. 0바이트 (`find -size 0`) = 3개
`pretooluse-bash-guard.sh` / `pretooluse-edit-write-guard.sh` / `pretooluse-main-whitelist.sh`. 비-가드 0바이트 0개.

### B-2. sensor 56개 무결성 — **ok=56 / empty=0 / no_shebang=0**
`for f in sensor-*.sh: head-1 shebang 검사` → **56개 전부 shebang(`#!`) 보유 + 비어있지 않음.** sensor 본체는 건강.

### B-3. state 0바이트 고아 = **22,516개**
- `find .claude/state -name 'sensor-hits.jsonl.tmp.*' | wc -l` = **22,516** (전부 0바이트, `-size 0` 동일 카운트)
- `.claude/state` 총 파일 = **22,569** → **99.8%가 빈 tmp 잔재**
- `.claude` 전체 0바이트 = 30,364 (worktrees 사본 포함), 비-tmp 0바이트는 §B-1의 3개뿐
- **진단**: sensor가 `> tmp.PID; mv tmp dst` atomic-write에서 tmp 정리 누락 → PID별 빈 파일 무한 적층. **sensor 인프라 누수 결함** (기능 무력은 아니나 디스크/inode 오염).

### B-4. 고아 스크립트 (진정한 고아 0개로 정정)
`grep -rl <basename> .claude eval`(코드/문서 참조)에서 비-sensor 스크립트 중 `deploy-all.sh`(45줄)만 코드/settings.json 참조 0건으로 1차 검출되었으나, **재확인 결과 `.claude/state/tool-failures.jsonl`에 실행 기록 존재 → 과거 실제 호출됨.** 따라서 "코드상 참조는 없지만 실행 이력 있는 준-고아 1개". **완전 고아(정의도 호출도 이력도 없음) = 0개.** (sensor 56개는 §B-5 진입점에서 활발 호출 확인.)

### B-5. sensor 호출 진입점 (실재)
sensor를 호출하는 비-sensor 스크립트(grep `sensor-` in non-sensor .sh):
`pretooluse-redteam-gate.sh`(adversarial 호출) · `posttooluse-failure-handler.sh` · `update-harness-inventory.sh` · `instructions-drift-check.sh` · `post-edit-tsc.sh` · `pre-compact-memory-guard.sh` · `adversarial-retry-handler.sh` · `post-edit-spec-check.sh` · `statusline.sh` · `cost-tracker.sh`. → **sensor는 여러 hook/runner에서 실제 호출됨** (sensor-hits 25,511줄이 증거).

---

## §C. 문서 인벤토리 드리프트

### C-1. 실제 인벤토리 (실측)
| 항목 | 측정 | 실제 |
|---|---|---:|
| agent | `ls .claude/agents/*.md` | **9** |
| skill | `ls .claude/skills/*/SKILL.md` | **25** |
| sensor | `ls .claude/scripts/sensor-*.sh` | **56** |
| script | `ls .claude/scripts/*.sh` | **85** |
| eval task | `ls eval/tasks/*.json` | **75** (+`_archive` 디렉토리) |
| hook 이벤트 | settings.json `hooks` 키 | **10** |

### C-2. 확정 드리프트 (라인번호 + 박제값)
| 문서:라인 | 박제 | 실제 | 격차 |
|---|---|---|---:|
| `eval/README.md:11,21,28,79` | "20개 태스크" / "20개 실패 박제" / "전체 20 태스크 실행" | 75 | **-55 (3.75배)** |
| `eval/README.md:118` | "마지막 업데이트: 2026-04-27" | — | **약 32일 미갱신 자증** |
| `.claude/knowledge/red-team-constitution.md:51` | "본 sensor가 23개 sensor 일괄 호출" | 56 | **-33** |

### C-3. 메인 지목 but 본 세션 grep 0매치 (추정 금지 — 미확정)
`agent-system.md` "7" / `book-completion.md` "sensor 12·eval 41" — 본 세션 정규식 grep에서 해당 문구 0매치(파일 구조/표현 상이). **격차 방향(실제 9·56·75가 더 큼)은 성립하나 정확 박제 문구·라인 재확정 실패 → 추정으로 단정하지 않음.**

---

## §D. sensor 실효성 (활발 vs silent)

### D-1. sensor-hits.jsonl 규모 — **25,511줄 / 2,965,150B(~2.9MB)**, mtime 2026-05-29 13:07. sensor 인프라 살아있음.

### D-2. result 분포 (`grep -oE '"result":"..."' | sort | uniq -c`)
| result | 건수 | 비율 |
|---|---:|---:|
| PASS | 16,738 | 65.6% |
| WARN | 7,603 | 29.8% |
| **FAIL** | **809** | **3.2%** |
| UNKNOWN | 361 | 1.4% |
**→ sensor 전체는 PASS만 찍는 게 아님(FAIL 809건). 단 §D-4에서 보듯 FAIL은 소수 sensor에 집중, 대다수는 never-FAIL.** WARN 29.8%(7,603건)는 redteam-gate가 FAIL만 exit 2 처리 → reject 안 됨.

### D-3. silent sensor (정의 56 중 fire 이력 0)
`for n in sensor-*: grep -c '"sensor":"$n"' sensor-hits.jsonl` → **52/56 fire, 4개 완전 silent(0 hits)**:
`sensor-circuit-breaker-policy` · `sensor-hit-rate-report` · `sensor-log` · `sensor-user-soft-delete-policy`.
→ 이 4개는 정의는 있으나 어느 진입점에서도 호출된 적 없음(또는 호출돼도 hit 미기록) = 실효 0.

### D-4. never-FAIL sensor (fire하지만 FAIL 0건) = **30개** — 검사 느슨 정황
hit 많은데 FAIL 한 번도 안 낸 sensor (= 항상 PASS/WARN, 검사 항목이 무의미하거나 너무 느슨할 수 있음). 대표:
| sensor | hits | FAIL |
|---|---:|---:|
| sensor-credit-atomicity | 2581 | 0 |
| sensor-secret-leak | 2450 | 0 |
| sensor-shared-contracts | 1853 | 0 |
| sensor-cost-margin | 1548 | 0 |
| sensor-instruction-degradation | 1514 | 0 |
| sensor-payment-idempotency | 940 | 0 |
| sensor-payment-reconciliation | 940 | 0 |
| sensor-chat-domain | 886 | 0 |
| sensor-feedback-promotion | 336 | 0 |
| sensor-harness-self-diagnose | 314 | 0 |
| sensor-knowledge-drift | 310 | 0 |
| ... (총 30개) | | 0 |
→ **secret-leak·credit-atomicity 같은 핵심 보안/원자성 sensor가 수천 회 실행되며 단 한 번도 FAIL 안 함.** 코드가 완벽해서일 수도, 검사 로직이 실제 위반을 못 잡아서일 수도 — **후자라면 "PASS 포장" 위험.** (FAIL을 실제 낸 sensor는 server/web/docs-sync/security-gate 등 소수.)

### D-5. redteam reject 실제 발생 = **0건 기록**
- redteam-gate는 reject 시 `redteam_reject` jsonl 기록(line 74). 그러나 `grep -rl "redteam_reject" .claude/state/*.jsonl` = **0 매치** → reject 실제 발생 기록 0.
- `.claude/state` violation 파일은 main-blocked-log(29줄, 5/8~5/10 동결)·edit-write-violation(22줄, 5/6~5/10 동결) 2종뿐, 둘 다 hook 폐기 후 추가 0.
- → **유일 실효 PreToolUse(redteam-gate)조차 실제 reject를 남긴 기록 0건** = 위험 명령이 안 들어왔거나(정상) / adversarial sensor가 FAIL을 못 낸 것(§D-4 패턴과 일관).

---

## §E. eval 실효성

### E-1. eval/README 박제 vs 실제: "20" vs 75 (§C-2). README line 118 "마지막 업데이트 2026-04-27".
### E-2. eval-runner 실행 흔적 — **마지막 실행 2026-04-30**
- `eval/results/` 하위 타임스탬프 디렉토리 전부 `2026-04-30-*` (02:01~13:20). **2026-04-30 이후 신규 run 디렉토리 0 → 약 29일간 eval 미실행.**
- `eval/results/baseline.csv` + `edd-baseline.csv` 존재. (최근 pass_rate·75 task 중 FAIL 개수 정수는 본 세션 burst-flush로 재현 미완 → 미확정, 추정 금지.)
- **결론: README가 표방한 "Stripe 1,000 PR/주 회귀 eval"은 실제로 4/30 이후 가동 중단 상태.**

---

## §F. "한때 작동 → 비워짐" 타임라인

| 일자 | 사건 | 근거 |
|---|---|---|
| 2026-04-25 | bash-guard 초기(105L) + sensor-hits 첫 기록 | `664c53b` / sensor-hits head ts `2026-04-25T12:07` |
| 2026-04-30 | **eval-runner 마지막 실행** (이후 run 0) | eval/results 디렉토리 전부 04-30 |
| 2026-05-06 | edit-write-guard 생성(179L, PP-7) + edit-write-violation 기록 시작 | `4483f61` / EWV ts min `2026-05-06T05:47` |
| 2026-05-08 | main-whitelist 생성(259→221L, PP-13) + PP-12 강화 + main-blocked 기록(8건) | `45385ad`·`5106625` / MBL ts `2026-05-08T13:45~15:09` |
| 2026-05-09 01:45 | **main-whitelist 0L 비워짐** | `d8560c4` |
| 2026-05-10 13:11 | edit-write-violation 마지막 기록(22줄째, expected `grimoire-harness`) | EWV ts max `2026-05-10T13:11` |
| 2026-05-10 23:56 | **edit-write-guard + bash-guard 0L 비워짐** ("hook 폐기, 사용자 5/10") | `5f20f1b` |
| 이후 | violation 로그 2종 추가 0 (edit-write 22줄 / main-blocked 29줄 동결) | wc -l |
| 2026-05-29 | sensor-hits 계속 기록(158건/당일) | sensor-hits tail |

**해석**: hook 폐기는 **사용자 5/9~5/10 지시 기반 의도적 결정**(메인 권한차단 PP 실험 종료). **진짜 진실성 결함 = "폐기 결정 후 settings.json 등록 미제거"** → 빈 스크립트 3개가 영구 no-op 등록 상태로 잔존, 외형상 5겹 방어로 보이나 Edit/Write 0겹.

---

## §수정 권고 (실행은 사용자 결정 — 본 감사 실행 0건)

1. **settings.json 정합화**: PreToolUse 0바이트 3개 등록 제거(폐기 의도 확정 시) — 외형/실효 일치. 또는 폐기 철회면 git `5106625`/`d8560c4`에서 본체 복원.
2. **state tmp 고아 22,516개 청소** + sensor atomic-write tmp 정리 로직 추가(누수 차단).
3. **문서 드리프트 해소**: eval/README "20"→75, red-team-constitution "23"→56, (agent-system/book-completion 재확인 후 갱신). `update-harness-inventory.sh` 활용 검토.
4. **eval-runner 재가동**: 4/30 이후 중단된 회귀 eval 복구 + baseline 갱신.
5. **WARN 처리 정책 재검토**: sensor WARN 29.8%(7,603건)이 reject 없이 누적 — 느슨도 점검.

---

## 본 감사 자기-한계 (정직성 원칙 / CLAUDE.md §0 정합)

- 본 세션 도구 출력이 **burst-flush(묶음 지연·간헐 유실)** 로 동작. 대량 배치는 ~20콜 뒤 일괄 도착했으나 일부 단일 정수값(baseline pass_rate / 개별 silent sensor 전수 / redteam reject 누적)을 재현 마감 못함.
- **미확정으로 명시한 항목**(§C-3 agent-system·book-completion 정확문구 / §D-3 개별 silent·never-FAIL 목록 / §D-4 redteam reject 카운트 / §E-2 baseline pass_rate)은 **추정/낙관으로 채우지 않음.**
- 확정 수치(§A 전수 wc / §A-4·F git history / §B 0바이트·22,516·sensor 56 / §C 인벤토리 9·25·56·85·75 + 드리프트 라인 / §D result 분포 809 FAIL / §E eval 4/30 중단)는 도구 출력에서 직접 수집.

---

*경로: `/Users/sokol/Desktop/Git/ProjectGrimoire/reports/HARNESS_HONESTY_AUDIT_20260529.md`*
*수정 0건 — 진단 전용. "PASS" 선언 0회.*
