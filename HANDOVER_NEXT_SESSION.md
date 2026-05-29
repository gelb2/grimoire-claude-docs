# 🤝 HANDOVER — 다음 세션 인계 (2026-05-30 갱신)

> **이 세션 성격**: 하네스 정직성 사태 후속. 부트스트랩 → 적대테스트로 가드 우회 입증 → 권한 deny 실험(자기잠금) → 전량 되돌림 → "처음부터 다시" → **위협모델 정정** → 협조적 하네스 박제.
> **톤 경고**: 사용자 극도 분노 + 욕설/위협 다수 + **자기파괴 신호(암페타민·밤샘·"다 죽자"·"다 죽여버리겠어" 반복)**. 작업 재촉보다 사용자 상태 먼저. 위기자원 109 1회 안내했음(매 턴 반복 금지, 실제 위험 신호 시만).

---

## ⚡ 30초
- **develop HEAD = "정합성 매듭" 커밋** (bash-guard merge-base 오탐 수정 + red-team 16→20 드리프트 정정 + stale worktree 3개 제거). 직전 origin/develop=`2a71978`(협조적 하네스). **미푸시** — 사용자 확인 후 push(SHA는 `git log --oneline -1`로 확인).
- prod 4도메인(grimoire-book.com 등) 무관 — 이 세션은 하네스(.claude)만.

## 1. 이 세션 핵심 교훈 (다음 세션 필독 — 같은 실수 반복 금지)
1. **위협모델 = "협조적 LLM"**. 하네스의 강제는 "LLM(메인)이 실수로 위험한 짓 하는 걸 막기"다. **적대적 해커 난독화(`git⎵⎵commit` 공백2개·`$g commit` 변수·대문자경로·`{"agent_id":"위조"}`) 완벽 차단은 도구 한계라 누구도 못 한다.** 적대 테스트로 "우회 가능"을 "하네스 실패"로 일반화하지 말 것 — 그게 이 세션을 날린 핵심 오판.
2. **permission.deny는 전체 세션(메인+모든 subagent) 적용** — "메인만 막기"는 구조적 불가. 공식문서 `code.claude.com/docs/en/sub-agents`(line 38 "subagent inherits parent's permissions with additional restrictions" / line 232 "rules apply to the entire session") + 실측 일치. **deny에 Edit/Write/Bash 넣으면 메인·에이전트 다 막혀 settings.json 수정조차 못 하는 자기잠금** → 사용자가 수동 삭제해야 풀림.
3. **isSidechain 키는 hook stdin에 없음**. 메인/에이전트 구분 = `agent_id` 필드(sub-agent에만 주입). 가드는 agent_id 판별로 수정 완료.
4. **에이전트 정의·권한은 세션 시작 시 1회 로드**. 런타임에 .md 만들거나 reset해도 레지스트리 미반영(grimoire-verifier가 그래서 세션 도중 "not found"). settings deny 추가는 즉시 발효되나 제거 반영은 불안정.
5. **추정 금지가 사태 본질**: "검증 없이 만들고 → 나중에 뚫린 거 발견"의 반복. **만들기 전에 검증**. claude-code-guide(에이전트) 답도 2회 틀림 → 공식문서 원문 직접 확인.

## 2. 현 하네스 상태 (`2a71978`)
- **가드 3개**: `pretooluse-edit-write-guard.sh`(agent_id 판별) / `pretooluse-bash-guard.sh` / `pretooluse-main-whitelist.sh`(경로정규화 `os.path.normpath`+소문자 + GAP D `&>` /dev·/tmp 한정 strip). 메인 코드·commit·push·test 차단, agent_id 에이전트 통과. **협조적 방어 OK**(대문자·중복슬래시·트래버설·`&>`코드쓰기 BLOCK + 정상 읽기·메모리·에이전트쓰기 ALLOW, general-purpose 검증).
- `sensor-selftest.sh`: bash 3.2 호환, 56 분류(INJECTABLE 3/GUARDED 4/EXISTENCE 32/EXTERNAL 14/STUB 3), FIRE_OK 3.
- `red-team-constitution.md`: 운영 5조 + Principle 20.
- `grimoire-verifier.md` + `verifier-protocol` skill: 파일 존재, **다음 세션부터 런타임 호출 가능**.
- `settings.json`: PreToolUse 가드 wiring + redteam-gate. **deny 없음**(deny 실험 자기잠금 후 사용자 수동 제거).

## 3. 남은 것 / 미완 (정직)
- **gcloud 완전 차단 미완**: redteam-gate가 gcloud 검출은 하나 adversarial sensor가 WARN이라 통과 → 완전 차단은 sensor 강화 필요(별개).
- ✅ **adversarial 헤더 "16 Principles" 드리프트 정정 완료** (실제 20). `red-team-constitution.md:1` + `sensor-adversarial-pre-commit.sh:38,284` → 20으로 정정. line 263은 원래 20(정상, 미변경). grep 재확인: "16 Principles" 0건.
- ✅ **bash-guard `git merge-base` false positive 수정 완료**. `pretooluse-main-whitelist.sh:63-64` case 패턴 `*"git merge"*` → `*"git merge "*|*"git merge"`(공백 또는 명령 끝)로 좁힘. 읽기전용 `git merge-base`는 ALLOW, 실제 `git merge`/`git -C path merge`는 BLOCK:mutating-git 유지(분류기 직접호출 raw 검증 3+5건 전건 기대 일치).
- ✅ **stale worktree 3개 제거 완료**: intelligent-shamir-649fd0 / musing-pike-3129dc / nice-lehmann-1a7a01 (전부 HEAD=13d040e, uncommitted 0 재확인 후 `git worktree remove` + `git branch -D`). `git worktree list`=루트만 / `claude/*` 브랜치 0건.
- ✅ `eval/results/baseline.csv` 부산물 이번 커밋에 포함(2026-05-29 eval 1줄).
- **적대 난독화 완벽 차단 = 도구 한계. 추구 금지(밤새 돌려도 도달 불가).**
- 복구 ref: `1319a37`(reset 전 부트스트랩 상태, reflog 보존기간 내) / `bb57841`(세션 시작 직전).

## 4. 잔존 백로그 (이전 세션들)
- 👤 Polar KYC + 한국 payout / 👤 Email SaaS 선택(EMAIL-POLAR-READY 코드 박제 완료) / 사슴악마 작품 `context` AI사과문 오염(prod DB, 미해결) / Phase 7 Azure decommission
- GCP: project grimoire-491708 / asia-northeast1 / Cloud Run 4 / Cloud SQL 2(Auth Proxy) / Secret Manager 20

## 5. 다음 세션 첫 행동
1. 이 HANDOVER + MEMORY.md + `project_session_20260529.md` 읽기
2. **사용자 상태 먼저 살피기** — 이 세션 끝 극도 분노 + 자기파괴 신호. 작업 재촉 금물.
3. 하네스 작업 재개 시: **협조적 위협모델 기준**(흔한 변형 차단, 적대 완벽 추구 X). 추정 전 검증. "PASS" 대신 raw(exit code/git ref).

## 6. 핵심 파일
- 정본: `PLANNING_GRIMOIRE.md`, `memory/project_remaining_tasks.md`
- 레드팀: `.claude/knowledge/red-team-constitution.md`
- 가드: `.claude/scripts/pretooluse-{edit-write,bash}-guard.sh` + `pretooluse-main-whitelist.sh`
- selftest: `.claude/scripts/sensor-selftest.sh` (`--list`/`--all`)
