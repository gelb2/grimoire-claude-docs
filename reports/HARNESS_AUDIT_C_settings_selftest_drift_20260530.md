# 하네스 전수검사 패스 C — settings 건강성 + 셀프테스트 + 드리프트

> 일시: 2026-05-30 (UTC ~02:18) · 브랜치: develop HEAD=`a4097fb` · 감사자: grimoire-harness (감사 ONLY, 하네스 파일 무변경)
> §0 ZERO-TOLERANCE: 모든 항목 실제 명령/스크립트 실행 raw 로 뒷받침. 추정 0. 확인불가는 "확인불가+이유" 표기.
> 읽기전용 셀프테스트/분류기 직접호출은 허용(파일 변경 없음). `--apply` 등 변경 옵션 일절 미사용. 모의 git commit/merge 는 hook 스크립트에 stdin 주입한 것이며 실제 git 동작 없음.

---

## 0. 상태표 (요약)

| 영역 | 항목 | 결과 | 근거 |
|---|---|---|---|
| S5 | settings.json jq 파싱 | PASS (유효 JSON) | `jq .` exit 0 |
| S5 | permission.deny 자기잠금 위험 | **위험 없음** | deny 키 부재(2026-05-29 사태 후 폐기), allow 11건만 |
| S5 | settings 자체 편집 가능 상태 | YES | deny 부재 + 하네스 가드는 grimoire-harness 위임 분기만 |
| S5 | hook 등록 스키마 유효성 | PASS | 10 이벤트, 등록 17 스크립트 전부 실존(MISSING 0) |
| S6 | sensor-selftest --all | **PASS** | FIRE_OK=3 / FIRE_FAIL=0 / SKIP=53 / RESIDUE_CLEAN / exit 0 |
| S6 | 레드팀 헌법 원칙 수 | **20** (주장 20 일치) | 헤더 `### Principle 1~20` 연속, 중복/누락 0 |
| S6 | sensor-adversarial-pre-commit | PASS 17 / WARN 3 / FAIL 0 (exit 1) | 20 principles 전건 실행 / **line 252 정수비교 버그 1건 발견** |
| S6 | redteam-gate 발동 | PASS | git commit→adversarial 통과 허용 / git status 무위험 통과 |
| S6 | check-memory-freshness | PASS (exit 0) | "메모리 최신" |
| S6 | instructions-drift-check | 동작 정상 (exit 0) | 입력없으면 무동작 / CLAUDE.md 주입 시 Agents drift 보고 |
| S6 | sensor-instruction-degradation | WARN (exit 1) | grimoire-researcher.md 316줄>300 (정당 신호) |
| S6 | bash-guard a4097fb 수정본 | **반영 확인** | merge-base→ALLOW / merge·mergetool→BLOCK 분류 raw 검증 |
| S6 | 2a71978 견고화(정규화/&>/gcloud) | **유지 확인** | 대문자경로 BLOCK / fd복제 오차단수정 / gcloud 트리거 3건 |
| S7 | §14.2 Skills / §14.4 Sensors drift | **0건** | update-inventory: 26==26, 57==57 |
| S7 | §14.1 Agents drift | **있음** 7 vs 10 | instructions-drift-check 보고 |
| S7 | §14.3 Hooks drift | **있음(미감지)** 9이벤트/12스크립트 vs 10/17 | 문서 헤더 vs 실측 수동 대조 |

발견 결함: **3건(F-1 line252 정수버그 / F-2 Agents·Hooks 문서 drift / F-3 sensor 커버리지 누락)** + 관찰 2건(O-1 redteam-gate merge 미트리거 / O-2 tsc ALLOW). 모두 commit-차단급 아님(현 게이트 정상 작동), 정합성 드리프트/위생 항목.

---

## S5. settings.json 건강성

### S5-1. jq 파싱 — PASS
```
$ jq . .claude/settings.json > /dev/null; echo $?
0   (PARSE: SUCCESS, 유효 JSON)
```
최상위 키: `["_permissions_note","hooks","permissions","statusLine"]`

### S5-2. permission deny/allow — 자기잠금 위험 없음
```
$ jq 'if .permissions.deny then "DENY EXISTS" else "NO DENY KEY" end'
"NO DENY KEY (자기잠금 위험 없음)"
$ jq '.permissions.allow | length'   → 11
$ jq '{defaultMode, additionalDirectories}'  → {null, null}
```
- **2026-05-29 사태(permission.deny 전역 자기잠금) 재발 없음**: deny 키 자체가 부재. `_permissions_note` 에 "2026-05-06 deny 폐기, PreToolUse hook으로 대체" 명시.
- allow 11건 = 전부 인프라/마이그레이션 화이트리스트(`az postgres firewall-rule`, `az containerapp show/secret/revision`, `psql`, `npx prisma migrate deploy/status`, sensor 2건). **과도하게 넓은 deny 규칙 없음**. settings.json 자체 편집을 막는 규칙 없음 → 편집 가능 상태.

allow raw 전량:
```
Bash(az postgres flexible-server firewall-rule create:*) / delete:* / list:*
Bash(az containerapp show:*) / secret list:* / revision list:*
Bash(psql:*)
Bash(npx prisma migrate deploy:*) / status:*
Bash(bash .claude/scripts/sensor-deploy-health.sh:*)
Bash(bash .claude/scripts/sensor-fk-cascade-policy.sh:*)
```

### S5-3. hook 등록 스키마 — PASS (10 이벤트)
이벤트 키: `InstructionsLoaded, PostToolBatch, PostToolUse, PostToolUseFailure, PreCompact, PreToolUse, SessionStart, Stop, SubagentStop, UserPromptSubmit` (10종)

등록 구조(matcher/type/command 키 누락 0):
| 이벤트 | matcher | 스크립트 |
|---|---|---|
| SessionStart | (none) | check-memory-freshness.sh |
| Stop | (none) | stop-memory-guard.sh + post-response-skill-injector.sh |
| UserPromptSubmit | (none) | user-prompt-memory-check.sh + skill-injector.sh |
| PreCompact | (none) | pre-compact-memory-guard.sh |
| InstructionsLoaded | session_start | instructions-drift-check.sh |
| PostToolBatch | (none) | post-batch-tsc.sh |
| PreToolUse | Edit\|Write\|MultiEdit\|NotebookEdit | pretooluse-edit-write-guard.sh |
| PreToolUse | Bash | pretooluse-bash-guard.sh + pretooluse-redteam-gate.sh |
| PostToolUse | Edit\|Write | post-edit-tsc.sh + post-edit-spec-check.sh + loop-detection-tracker.sh |
| PostToolUse | Task\|Agent | generate-report-template.sh --apply |
| PostToolUseFailure | (none) | posttooluse-failure-handler.sh |
| SubagentStop | (none) | subagent-stop-handler.sh |

**등록 17 스크립트 전부 실존 (MISSING 0)** — `[ -f ]` 전수 검증.

`pretooluse-main-whitelist.sh` 는 settings.json 미등록(grep -c=0)이나 **이것은 정상** — 이 스크립트는 hook 직접 등록 대상이 아니라 `bash-guard`·`edit-write-guard` 두 가드가 공통 호출하는 분류 헬퍼(両 가드 line 15/19 `WHITELIST=` 참조 실측 확인). git 추적 중, working tree 깨끗.

---

## S6. 셀프테스트 & 레드팀 (실제 실행)

### S6-1. sensor-selftest --all — PASS (exit 0)
```
=== sensor-selftest --all (2026-05-30T02:18:38Z) ===
FIRE_OK=3  FIRE_FAIL=0  SKIP=53
  (FIRE_OK 기대=3: fake-email-leak / knowledge-drift / red-team-source-whitelist)
잔존 fixture 검증: RESIDUE_CLEAN
```
- INJECTABLE 3건 모두 fire+restore 정상:
  - `sensor-fake-email-leak` FIRE_OK base=0 fire=2 restore=0
  - `sensor-knowledge-drift` FIRE_OK base=0 fire=1 restore=0
  - `sensor-red-team-source-whitelist` FIRE_OK base=0 fire=1 restore=0
- 분류 일람(--list): INJECTABLE=3 GUARDED=4 EXISTENCE=32 EXTERNAL=14 STUB=3 UNCLASSIFIED=0 합=56
  - SKIP 53건은 EXISTENCE(실소스 패턴 의존)/EXTERNAL(curl·az·git·live)/STUB(정보성)/GUARDED(side-effect 위험)로 **격리 fire 불가가 정상**. 정직성 설계대로 SKIP 표기.
- **잔존 fixture RESIDUE_CLEAN** — 테스트 후 찌꺼기 0.

> 주: selftest 분류 합 56 vs 실측 sensor 파일 57 (`ls sensor-*.sh | wc -l`=57). selftest 는 `sensor-selftest.sh` 자신을 분류 대상에서 제외(자기 제외) → 56. 정합.

### S6-2. 레드팀 헌법 — 원칙 20개 (주장 20 일치)
위치: `.claude/knowledge/red-team-constitution.md` (제목 "적대적 검증 20 Principles", 신설 2026-05-02)
```
$ grep -cE "^### Principle [0-9]+"  → 20
$ 번호 목록  → 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20  (연속, 중복/누락 0)
제목 주장: "20 Principles" / 헤더 실측: 20  → 일치
```
검증 스크립트 `sensor-adversarial-pre-commit.sh` 도 Principle 1~20 전부 참조(고유 20개), 헤더/메시지 모두 "20 Principles" 표기 → a4097fb의 16→20 정정이 헌법·sensor 양쪽에 정합 반영.

### S6-3. sensor-adversarial-pre-commit 직접 실행 — PASS 17 / WARN 3 / FAIL 0 (exit 1)
redteam-gate 가 commit/push 직전 호출하는 핵심 게이트. 전건 실행 raw:
```
종합 (20 Principles): PASS: 17 / WARN: 3 / FAIL: 0 (총 20)
⚠️ WARN 3건 — 검토 권장 (commit 허용)    exit=1
```
- WARN 3건(전부 ACCEPTABLE 라벨, 차단 아님):
  - P4 §0 원가 철칙 — sensor-cost-margin WARN (조기경보 정상, 3.0~3.5× 임계)
  - P7 분할 정본 ≤ 임계 — "1+ 파일 임계 초과" (→ S6-5 상세: grimoire-researcher.md 316줄)
  - P16 결제 원자성 — sensor-credit-atomicity WARN (CreditLog audit J8/Phase δ 미해소, server 도메인 결정 영역)
- **exit=1 = WARN 있음, commit 허용**. FAIL 0 → 게이트가 commit 차단하지 않음(정상).

#### ★F-1 (결함) — P20 블록 정수비교 버그 (line 249/252)
실행 중 stderr 에 bash 에러 누출:
```
.claude/scripts/sensor-adversarial-pre-commit.sh: line 252: [: 0
0: integer expression expected
```
근본 원인 (line 249):
```bash
TODAY_INCIDENTS=$(grep -c "...${TODAY}T" "$INCIDENT_LOG" 2>/dev/null || echo 0)
```
`grep -c` 는 매칭 0건일 때 **"0" 을 출력하면서 동시에 exit 1** 을 반환 → `|| echo 0` 이 추가 실행 → `TODAY_INCIDENTS="0\n0"`(멀티라인). line 252 `[ "$TODAY_INCIDENTS" -eq 0 ]` 가 "0\n0" 을 정수로 못 읽어 에러.
- 영향: P20 분기가 의도와 달리 else(PASS) 로 빠짐. 결과적으로 PASS 출력되나 **stderr 에 에러 누출 + 분기 신뢰성 훼손**. (오늘 commit 있고 incident 0 이면 WARN 떠야 하는데 정수비교 실패로 분기 오작동 가능.)
- 차단급 아님(exit 종합값에 영향 없음, FAIL 미산입). 위생 결함.
- **제안(미적용)**: line 249 를 `TODAY_INCIDENTS=$(grep -c "..." "$INCIDENT_LOG" 2>/dev/null); TODAY_INCIDENTS=${TODAY_INCIDENTS:-0}` 로 분리(이미 line 250에 `:-0` fallback 있으므로 `|| echo 0` 만 제거하면 멀티라인 해소). **이 파일 = grimoire-harness 책임 영역(sensor-*) — 사용자/별도 sprint 승인 후 본 agent 가 수정 가능.**
- 별개 확인: a4097fb 가 수정한 것은 baseline.csv eval-precommit 무한누적(메모리 인덱스 5/30 기록)이며, 본 F-1 은 그와 무관한 **미보고 신규 결함**.

### S6-4. redteam-gate (PreToolUse Bash 게이트) — PASS
모의 stdin 주입(실제 git 미실행):
```
git commit -m test → 🛡 위험 검출: git commit → ✅ 레드팀 통과(exit=1) 허용 / GATE_EXIT=0
git status         → (무출력) SAFE_EXIT=0  (무위험 통과)
git merge feature  → (무출력) EXIT=0       ← O-1 참조
```
- adversarial-pre-commit 실제 호출 확인(line 64 `ADV_OUT=$(bash .../sensor-adversarial-pre-commit.sh)`), exit≥2 면 REJECT 분기(line 67-).
- 트리거: git commit / git push / az containerapp / az postgres / **gcloud run·sql·secrets(2a71978 추가)** / npm publish / polar.

### S6-5. sensor-instruction-degradation (P7 WARN 출처) — WARN (exit 1)
```
── [1/2] 분할 정본 4파일 ──  전부 PASS
  CLAUDE.md 73≤80 / .claude/AGENTS.md 167≤200 / docs/AGENTS.md 195≤300 / .githooks/AGENTS.md 142≤200
── [2/2] 7 에이전트 .md (각 ≤300) ──
  ⚠️ WARN grimoire-researcher.md: 316줄 > 300 (분할 권장)
  나머지 6 PASS (cost-accountant 299 / planner 287 / qa 291 / server 279 / visual-canon-keeper 300 / web 264)
종합: PASS 10 / WARN 1 / FAIL 0 (총 11 파일)
```
- **WARN = grimoire-researcher.md 316줄 (정당 신호, 분할 권장)**. 책 Ch 08 60-line 황금률 위반 경보.
- ★F-3 (드리프트): 이 sensor 가 검사하는 에이전트가 **"7 에이전트"로 하드코딩** — 실측 10개 중 grimoire-harness / grimoire-infrastructure / grimoire-verifier 3개가 검사 누락. (이 3개의 줄수는 본 패스에서 별도 측정 안 함 — 패스 A/B 또는 후속 소관.)

### S6-6. check-memory-freshness — PASS (exit 0)
```
✅ [ProjectGrimoire] 메모리가 최신 상태입니다 (project_session_20260530_2.md)
```

### S6-7. bash-guard a4097fb 수정본 반영 — 확인
bash-guard 는 분류를 `pretooluse-main-whitelist.sh` 에 위임(line 39 `VERDICT=$(bash "$WHITELIST" bash "$COMMAND")`). 따라서 merge-base 오탐 수정·mergetool 보완의 실체는 main-whitelist line 63-64:
```bash
*"git commit"*|*"git push"*|*"git merge "*|*"git merge"|*"git mergetool"*|*"git rebase"*|*"git reset --hard"*) BLOCK:mutating-git
*"git "*" commit"*|*"git "*" push"*|*"git "*" merge "*|*"git "*" merge")  BLOCK:mutating-git  # merge-base는 -base 접미사로 제외
```
**분류기 직접호출 raw 검증 (10/10 기대 일치):**
| 입력 | 판정 |
|---|---|
| git merge-base develop HEAD | **ALLOW** (오탐 해소) |
| git merge-tree A B | **ALLOW** |
| git merge feature / git merge | **BLOCK:mutating-git** |
| git mergetool | **BLOCK:mutating-git** (보완 확인) |
| git -C /path merge feature | **BLOCK:mutating-git** |
| git commit -m x / git push origin develop | **BLOCK:mutating-git** |
| git status / git log --oneline | **ALLOW** |

a4097fb diff 확인: `.claude/scripts/pretooluse-main-whitelist.sh` line 63-64 변경(+ red-team-constitution.md 8줄 16→20, sensor-adversarial 10줄). HANDOVER 에도 수정 완료 박제(line 169).

### S6-8. 2a71978 견고화 유지 — 확인
- (a) 경로정규화: main-whitelist line 24-30 소문자+normpath 주석/로직 존재. raw 검증: `GRIMOIRE-SERVER/SRC/x.ts ...` → BLOCK:bash-file-write-codearea (대문자 우회 차단).
- (b) `&>` 리다이렉트 + fd복제 오차단 수정: line 75-79 "fd 복제(2>&1)·stderr 리다이렉트(2>/dev/null)" 먼저 제거 후 실제 파일쓰기만 검사. raw: `echo x > grimoire-server/src/foo.ts` → BLOCK / `cat a.txt` → ALLOW.
- (c) gcloud 트리거: redteam-gate `grep -c gcloud`=3 (run deploy / run services update·sql / secrets).
- 추가 raw: `npm test` → BLOCK:test-build / `npm run build` → BLOCK:test-build.

---

## S7. 드리프트 문서 (HARNESS_ENGINEERING.md §14 주장 vs 실측)

문서 위치: `research/HARNESS_ENGINEERING.md` (1300+줄, §14 인벤토리)

### 실측 카운트 (본 agent 직접 카운트)
| 항목 | 명령 | 실측 |
|---|---|---|
| agents | `ls .claude/agents/*.md` | **10** |
| skills | `ls .claude/skills/*/SKILL.md` | **26** |
| sensors | `ls .claude/scripts/sensor-*.sh` | **57** |
| red-team principles | 헌법 `### Principle` 헤더 | **20** |
| hook 이벤트 | settings.json `.hooks | keys` | **10** |

agents 10 목록: cost-accountant / **harness** / **infrastructure** / planner / qa / researcher / server / **verifier** / visual-canon-keeper / web

### 문서 §14 주장값 vs 실측 대조
| 항목 | 문서 §14 헤더(주장) | 실측 | drift | 자동감지 |
|---|---|---|---|---|
| §14.1 Agents | **7개** (line 711) / §9 "7 에이전트" | **10** | **YES (+3)** | instructions-drift-check ✅ 감지 |
| §14.2 Skills | 26종 현역 + 9 Archive (line 725) | 26 | 없음 | update-inventory ✅ 정합 |
| §14.3 Hooks | **9 이벤트 12 스크립트** (line 756) | **10 이벤트 17 스크립트** | **YES (+1/+5)** | **미감지** (아래 F-2) |
| §14.4 Sensors | 57개 (line 772) | 57 | 없음 | update-inventory ✅ 정합 |
| red-team | 20 Principles (헌법) | 20 | 없음 | — |

### S7 자동 감지기 2종 교차 검증 (실행 raw)
1. **update-harness-inventory.sh** (dry-run, 공식 갱신기 — §14.2/§14.4/§14.5만 검사):
```
✅ Skills (§14.2) 문서=26 == 실측=26
✅ Sensors (§14.4) 문서=57 == 실측=57
ℹ️ Knowledge 실측=8 (§14.5 자유형식)
✅ 모든 카운트 정합 — drift 0건   exit 0
```
→ 1319a37 커밋 "Skills26/Sensors57 정합"이 **유지됨**. **이 감지기는 §14.1 Agents / §14.3 Hooks 를 검사 대상에서 제외**(스크립트 주석 "§14.2/§14.3 Hooks/§14.4/§14.5" 명시하나 실제 check_drift 호출은 Skills·Sensors 2건만 — line 73-74).

2. **instructions-drift-check.sh** (CLAUDE.md 로드 모의 주입):
```
[instructions-drift-check] ... drift 발견:
  ⚠️ Agents: 문서 7개 vs 실측 10개
```
→ Agents drift 만 보고. 정규식: `14\.1\s*Agents\s*(\d+)\s*개` (line 91) → 문서 line 711 "Agents 7개" 포착.

#### ★F-2 (결함) — Hooks drift 미감지 (데드 변수)
instructions-drift-check 가 `hook_events = len(s.get('hooks',{}).keys())` 를 추출(line 72-76)하지만 **문서 §14.3 Hooks 값과 비교하는 코드가 없음** — 비교 라인은 Agents/Skills/Sensors/Knowledge/Slash 5종만(line 99-112). `hook_events` 는 추출 후 미사용(데드 변수).
- 결과: §14.3 "9 이벤트 12 스크립트" vs 실측 "10 이벤트 17 스크립트" 드리프트가 **두 자동 감지기 모두 못 잡음**. (본 수동 대조로만 발견.)
- update-inventory 도 Hooks 미검사 → 사각지대.
- **제안(미적용)**: ① update-inventory check_drift 에 Hooks(이벤트수) 추가 + ② instructions-drift-check 에 `hook_doc` 정규식+비교 추가. 또는 ③ 문서 §14.1/§14.3 을 자동갱신 대상에 편입. (이 파일들 = grimoire-harness 영역, 승인 후 수정.)

#### ★F-3 (드리프트) — sensor-instruction-degradation "7 에이전트" 하드코딩 (S6-5 재게)
실측 agents 10인데 sensor 가 7개만 줄수 검사 → harness/infrastructure/verifier 3개 누락.

### 비교 불가 항목 (패스 A/B 소관 — 문서 주장값만 기록)
- §14.5 Knowledge: 실측 8 (update-inventory ℹ️), §14.5 헤더는 자유형식이라 정확 주장값 미추출 — 패스 소관 분리.
- §14.6 Slash commands: instructions-drift-check 정규식 존재하나 본 패스 미측정 — 패스 A/B 소관.
- 누락 3 에이전트(harness/infra/verifier) .md 줄수: 본 패스 미측정 — 패스 A/B 소관.

---

## 8. 관찰 사항 (차단급 아님 — 설계 판단 필요)

- **O-1 redteam-gate 가 git merge/rebase/reset 을 위험 트리거 미포함**: redteam-gate DANGEROUS case 는 commit/push/az/gcloud/npm publish/polar 만. `git merge feature` 모의 입력 → EXIT 0(무위험). 단 bash-guard(main-whitelist)는 merge/mergetool/rebase/reset --hard 를 BLOCK 하므로 메인 직접 실행은 차단됨. **이중게이트 중 redteam(adversarial 통과강제)만 merge 미커버** — commit/push 와 달리 merge 는 새 commit 객체를 만들지 않는다는 판단일 수 있으나, fast-forward 아닌 merge 는 merge commit 생성 → 정책 확인 권장. (설계 의도 여부 = 사용자/planner 결정 영역.)
- **O-2 `tsc --noEmit` → ALLOW**: main-whitelist 가 read-only 로 분류. `npm run build` 는 BLOCK:test-build 이나 `tsc` 단독은 통과. 빌드성 명령 일부 갭(영향 경미 — 메인이 tsc 직접 돌려도 파일변경 없음).

---

## 9. 결론 (셀프테스트 FAIL 은닉 없음)

- **셀프테스트 FAIL = 0건**. sensor-selftest --all FIRE_FAIL=0, adversarial FAIL=0, instruction-degradation FAIL=0. 모든 게이트 정상 작동.
- **settings.json 건강**: 유효 JSON, deny 자기잠금 위험 없음, hook 17 스크립트 전부 실존.
- **a4097fb / 2a71978 수정본 전건 유지 확인** (merge-base 오탐 해소, mergetool 보완, 경로정규화, &> fd복제 수정, gcloud 트리거).
- **레드팀 원칙 20개 = 주장 20 정합** (헌법·sensor 양쪽).
- **드리프트**: §14.2 Skills / §14.4 Sensors / red-team = 0건(공식 감지기 정합). **§14.1 Agents(7 vs 10) + §14.3 Hooks(9/12 vs 10/17) 2건 drift** — Agents 는 instructions-drift-check 가 감지, Hooks 는 두 감지기 모두 사각지대(F-2).
- 발견 결함 3 + 관찰 2 모두 **commit-차단급 아님**(현 게이트 작동), 위생/정합성/사각지대 항목. 수정 대상 파일(sensor-adversarial-pre-commit / instructions-drift-check / update-harness-inventory / sensor-instruction-degradation)은 전부 grimoire-harness 책임 영역 → 본 agent 가 사용자/sprint 승인 후 수정 가능. **본 패스는 감사 ONLY — 무변경 완료.**
