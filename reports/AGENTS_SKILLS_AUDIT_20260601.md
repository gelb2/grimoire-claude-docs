# AGENTS · SKILLS 등록 무결성 감사 (D4 · D5) — 2026-06-01

> **읽기 전용 감사. 수정 0건.** 작업 디렉터리 `/Users/sokol/Desktop/Git/ProjectGrimoire`.
> 핵심 질문: 에이전트는 실제로 일을 나눠 갖는 구조인가(분업 실체) / 스킬은 제대로 등록·트리거되는가.
> 모든 수치는 RAW 실측(파일 경로·frontmatter 라인·grep 출력·transcript tool_use 카운트). 미검증은 "미검증" 명시.

---

## 종합 판정

| 도메인 | 판정 | 한 줄 |
|--------|------|-------|
| **D4 에이전트 분업 실체** | **PASS** | 10개 정의 전부 실제 invoke 증거 있음(transcript tool_use). 도구 권한은 의미 있게 분화(특히 verifier 읽기전용 구조 확인). 핸드오프 매트릭스 7×7은 "설계상 의도된 축소"로 문서화됨 — 다만 일부 헤더 stale. |
| **D5 스킬 등록 무결성** | **PASS** | 활성 26 + archive 9 = 35 SKILL.md 전건 frontmatter 유효. 고아 0건. broken 참조 0건. 두 injector 훅 모두 등록·실제 발동 증거 있음. 트리거 메커니즘 3종 정합. |

**전제 정합 확인**: 질문에 명시된 "agents 10개 / skills 35개(_archive 포함)" = **실측 일치**(agents `*.md` 10, active SKILL.md 26 + archive 9 = 35).

> 선행 감사 `reports/HARNESS_AUDIT_B_sensors_skills_agents_20260530.md`(5/30)가 D4·D5 일부를 이미 다룸(10/10 frontmatter 유효, verifier 읽기전용, 신설 3 에이전트 매트릭스 미동기, sensors-overview stale). 본 감사는 이를 **재확인 + 확장**한다. **확장점**: ① 10개 에이전트 각각의 **실제 invoke 횟수**를 transcript tool_use에서 실측(선행 감사엔 없던 데이터) ② 스킬 **3중 트리거 reachability 매트릭스**(triggers/native/refs)로 고아 정밀 판정.

---

# D4 — 에이전트 분업 실체

## D4-1. 도구 권한 분화 (frontmatter 실측)

`.claude/agents/*.md` 10개. 각 frontmatter `tools:` / `model:` 라인 직접 추출.

| 에이전트 | frontmatter 라인 | `tools:` | Write/Edit | Bash | Web* | model |
|----------|------------------|----------|:----------:|:----:|:----:|-------|
| grimoire-server | L4 | Read, Write, Edit, **Bash**, Glob, Grep | ✅ | ✅ | — | opus |
| grimoire-web | L4 | Read, Write, Edit, **Bash**, Glob, Grep | ✅ | ✅ | — | opus |
| grimoire-planner | L4 | Read, Write, Edit, Glob, Grep | ✅ | ❌ | — | opus |
| grimoire-qa | L4 | Read, Write, Edit, **Bash**, Glob, Grep | ✅ | ✅ | — | opus |
| grimoire-cost-accountant | L4 | Read, Write, Edit, Glob, Grep, **Bash** | ✅ | ✅ | — | opus |
| grimoire-visual-canon-keeper | L4 | Read, Write, Edit, Glob, Grep, **Bash** | ✅ | ✅ | — | opus |
| grimoire-researcher | L4 | Read, Write, Edit, Glob, Grep, **WebSearch, WebFetch** | ✅ | ❌ | ✅ | opus |
| grimoire-infrastructure | L4 | Read, Write, Edit, **Bash**, Glob, Grep | ✅ | ✅ | — | opus |
| grimoire-harness | L5 | Read, Write, Edit, **Bash**, Glob, Grep | ✅ | ✅ | — | opus |
| **grimoire-verifier** | **L4** | **Read, Bash, Glob, Grep** | **❌ 없음** | ✅ | — | opus |

\* Web = WebSearch/WebFetch.

**판정: 도구 권한은 가짜 동일이 아니라 의미 있게 분화.** 3개 축에서 차이:
1. **verifier = 유일하게 Write/Edit 없음** (`tools: Read, Bash, Glob, Grep`, L4). frontmatter description(L3)에 "Edit/Write/commit/push/배포 도구 없음(구조적 변경 불가)" 명문화 → **자기검증 금지 / 작업↔검증 주체 분리 구조가 도구 레벨에서 강제됨**. 질문의 핵심 확인 사항 = **TRUE**.
2. **researcher = 유일하게 WebSearch/WebFetch 보유**, 반대로 Bash 없음 → 외부 조사 전담, 로컬 실측 불가.
3. **planner = Bash 없음** (Read/Write/Edit/Glob/Grep만) → 문서 기획 전담, 셸 실측은 도메인 에이전트로 위임 강제.

> 나머지 7개는 `Read,Write,Edit,Bash,Glob,Grep` 동일 세트지만, 이는 "코드/문서 생산 에이전트는 동일 기본 권한"이라는 합리적 설계이며, description(L3)으로 도메인 책임이 명확히 분리됨(server=NestJS/Prisma, web=Next.js, infra=Azure/GCP 배포, harness=`.claude/*`). **권한 미분화 = 가짜 분리** 라는 의심은 verifier/researcher/planner 3건의 명확한 차등으로 **반증됨**.

> ⚠️ 주의(가짜 안전 아님): tools 화이트리스트는 "역할 의도"의 표현이며, 실제 런타임 차단 여부(예: verifier가 Edit 시도 시 harness가 막는지)는 본 frontmatter만으로는 **미검증**. 다만 `.claude/scripts/pretooluse-edit-write-guard.sh` + `edit-write-violation.jsonl`(5061B 적재)가 별도 가드로 존재 — 가드 효력 정밀검증은 본 감사 범위 밖.

## D4-2. 실제 호출 증거 — 정의됐지만 안 쓰인 에이전트 0건

**RAW 출처**: `~/.claude/projects/-Users-sokol-Desktop-Git-ProjectGrimoire/*.jsonl` (transcript 25개, 199M).
**방법**: `"name":"Agent"` tool_use 블록(= Task tool, 2026-05-06 INCIDENT KK'에서 `Task`→`Agent` 리네임 박제됨) 내 `subagent_type` 카운트. 전 294 `name:Agent` 블록 전건 `subagent_type` 보유(0 누락).

| 에이전트 | 실제 invoke 횟수 | 샘플 description(raw) |
|----------|:----------------:|------------------------|
| grimoire-server | 48 | — |
| grimoire-harness | 48 | — |
| grimoire-infrastructure | 46 | — |
| grimoire-planner | 38 | — |
| grimoire-qa | 31 | — |
| grimoire-verifier | 22 | — |
| grimoire-web | 13 | — |
| grimoire-cost-accountant | 11 | — |
| grimoire-visual-canon-keeper | 6 | — |
| **grimoire-researcher** | **3** | "게이트 6-B 트리거 명문화" / "경쟁사 토큰 요금제 리서치" / "AI 모델 가격 재스윕" |
| (built-in) general-purpose | 2 | — |
| (built-in) claude-code-guide | 2 | — |

- **10개 정의 에이전트 전부 ≥3회 실제 invoke 증거.** **장식(정의만 있고 안 쓰임) = 0건.** 최저는 researcher(3) — 그래도 3건 모두 raw description 동반한 진짜 tool_use 블록(위 샘플).
- grimoire 합계 266 + built-in 4 = 270, 전체 `name:Agent` 라인 294와 24 차이 = 결과/연속 블록·다중매치 라인(분포 결론엔 무영향).
- 분포 편중: **harness/server/infra/planner 상위 4개가 전체의 ~68%**. 메타·인프라(harness/infra) + 핵심 구현(server) + 조율(planner) 중심 운영 = 최근 세션 성격(GCP 마이그레이션·하네스 정합)과 정합.

### task_calls=235 (orchestration-ratio) 와의 관계
- `orchestration-ratio.jsonl` 최신 1줄(`ts=2026-05-31T04:45:26Z`): `task_calls=235`, `main_total=414`, `ratio=0.5676`, `status=PASS`, `days=7`, `unique_domains=8`.
- 235 vs 본 감사 270(grimoire)/294(전체)의 차이 **= 측정 윈도우 차이**. `sensor-orchestration-ratio.sh` L142는 `name in ('Task','Agent') and not sidechain`만 카운트 + **7일 윈도우**. 본 감사는 **전체 transcript(5/02~6/01)**. 두 수치는 모순이 아니라 스코프 차이 — **정합**.
- ⚠️ **per-agent 분포는 jsonl에 미박제**: 스크립트는 `stypes[stype]`를 stderr로만 출력하고 jsonl엔 집계값(`task_calls`)만 기록(L269 printf). 따라서 "235가 어느 에이전트에 분포하는가"는 **jsonl 단독으로는 미검증** → 본 감사는 transcript 직접 grep으로 대체 실측(위 표).

### subagent-stop 센서는 per-agent 분포에 부적합 (결함 D4-F1)
- `sensor-hits.jsonl` 내 `subagent-stop` 이벤트 214건 중 **213건이 `type=unknown`**, 1건만 `type=grimoire-test`(존재하지 않는 팬텀 에이전트명).
- 원인: `.claude/scripts/subagent-stop-handler.sh` L18-25가 stdin JSON에서 `subagent_type`을 찾지만, **SubagentStop 훅 payload에 해당 필드가 없어** L22 fallback `unknown`으로 떨어짐(MEMORY 5/29 "isSidechain hook에 없음" 동일 계열 한계).
- 영향: subagent-stop 센서 로그는 **에이전트 분업 분포 측정에 무효** → 실측은 transcript 경유만 신뢰 가능.

## D4-3. agent-interaction-matrix.md 정합 (7×7 vs 10개)

**파일**: `.claude/knowledge/agent-interaction-matrix.md` (L1-146, 마지막 업데이트 L145=`2026-04-26`).

- L13 헤더: "**7×7 핸드오프 정본**". L29-38 매트릭스 = `planner / researcher / cost-accountant / visual-canon-keeper / server / web / qa` 7개 × 7개.
- **누락 3개**: infrastructure(2026-05-08 신설), harness(2026-05-09), verifier(2026-05-29) → 매트릭스에 **부재**.
- frontmatter L2 `name: 7 서브에이전트 핸드오프 매트릭스`, L3 7개 나열 → **10개와 불일치**.

**그러나 이것은 "silent drift"가 아니라 "문서화된 의도적 축소":**
- `.claude/knowledge/agent-system.md`(L2, 마지막 갱신 2026-05-30)가 **명시적 정합 결정** 박제:
  - L2: "멀티 에이전트 구조 (10개 = 7 핵심 + 3 메타)"
  - L12: "**핸드오프 매트릭스는 7 핵심 기준이 정본** — 도메인 작업 흐름(기획→구현→검증)은 7 핵심 사이에서만 발생. 3 메타 에이전트는 흐름의 트리거 대상이 아니라 시스템 운영 주체이므로 별도 명시"
  - L178: "2026-05-30 (harness): 7 → 10 에이전트 전면 정합 … 핸드오프 매트릭스는 도메인 흐름 정본인 7 핵심 기준 유지 명시"
- → **즉 7×7은 버그가 아니라 "도메인 핸드오프는 7 핵심만, 메타 3개는 운영 주체로 분리"라는 설계 결정.** agent-system.md는 10개 전부 열거(grep 확인: 10개 토큰 전건 출현).

**결함 D4-F2 (LOW, 문서 표면 stale)**: 단, `agent-interaction-matrix.md` **자체의 frontmatter/헤더(L2·L3·L13)에는 이 "7 핵심 한정" 정합 주석이 없음**. agent-system.md를 안 본 독자는 "10개인데 매트릭스가 7개 = drift"로 오해 가능. → 매트릭스 헤더에 "본 매트릭스는 7 핵심 도메인 한정(메타 3개는 agent-system.md §3)" 1줄 cross-ref 추가가 적절(수정은 본 감사 범위 밖, 진단만).

## D4-4. shared-contracts.md 정합

**파일**: `.claude/shared-contracts.md` (197,513B).

- L1 헤더: "**7 Agents 인터페이스 규약**", L2: "agent-interaction-matrix.md(7×7 핸드오프 메타)의 보완 정본".
- 도입부(L1-25)는 일관되게 "7 핵심 에이전트 공유 인터페이스" 전제(agent-system.md L15-16과 정합: "산출물 reports/*.md를 주고받는 도메인 흐름은 7 핵심에 한정").
- 에이전트명 출현 빈도(grep): server 185, web 20, qa 4, planner 3, infrastructure 2, cost-accountant 2, visual-canon-keeper 1, researcher 1 / **harness·verifier = 본문 인터페이스 섹션 0**.
- **정합 해석**: shared-contracts는 "reports/*.md 산출물 인터페이스(SWEEP/COST_AUDIT/VISUAL_CANON/PLANNER/DEV/QA_REPORT 등) 주고받는 7 핵심 흐름" 정본이므로, 메타 2개(harness/verifier)가 인터페이스 섹션 없는 것은 **D4-3과 동일한 의도적 7-핵심 한정 = 정합**. infrastructure 2회 출현은 배포 관련 언급.

**결함 D4-F3 (LOW, 동일 표면 stale)**: shared-contracts L1 "7 Agents" 헤더도 D4-F2와 동종 — "7 핵심 한정" 정합 주석 없음. agent-system.md만이 10↔7 관계의 단일 정합 정본이고, 매트릭스·contracts 헤더는 그 결정을 역참조하지 않음.

### D4 결함 요약
| ID | 심각도 | 결함 | 근거 |
|----|--------|------|------|
| D4-F1 | MEDIUM | subagent-stop 센서가 per-agent 분포 측정 불가(213/214 `unknown`) | `sensor-hits.jsonl` grep / `subagent-stop-handler.sh` L18-25 |
| D4-F2 | LOW | `agent-interaction-matrix.md` 헤더(L2/L3/L13)에 "7 핵심 한정" 정합 주석 부재 → 10↔7 drift 오해 소지 | matrix L2-13 vs agent-system.md L12 |
| D4-F3 | LOW | `shared-contracts.md` L1 "7 Agents" 헤더 동일(정합 주석 부재) | shared-contracts L1-2 |
| (정보) | — | per-agent task_calls가 orchestration-ratio.jsonl에 미박제(stderr만) → 분포는 transcript로만 검증 가능 | `sensor-orchestration-ratio.sh` L144-146, L269 |

**D4 판정 = PASS** (분업 실체 확인: 10/10 invoke 증거 + 도구 권한 유의미 분화 + verifier 읽기전용 구조 확정). 결함 3건 전부 **측정/문서 표면 레벨**이며 분업 실체 자체를 부정하지 않음.

---

# D5 — 스킬 등록 무결성

## D5-1. SKILL.md frontmatter 유효성 (활성 26 / archive 9)

**방법**: 각 SKILL.md 첫 줄 `---` 확인 + frontmatter 내 `name:` / `description:` 추출.

- **활성 26개**: 전건 `name:` 존재 + **name == 디렉터리명 일치** + `description:` 존재 + frontmatter 구분자(`---`) 정상. **누락/malformed 0건.**
- **archive 9개**: 전건 동일하게 유효(`dev-login-smoke, dispatching-parallel-agents, drift-check, eval-run, feedback-to-skill, handover-refresh, red-team-update-propose, shared-contracts-check, worktree-isolation`).
- **중복 name**: `eval-run` 1건이 **활성과 archive 양쪽**에 존재(`.claude/skills/eval-run/` + `.claude/skills/_archive/eval-run/`). 활성↔archive 경계를 가로지른 동명 = **충돌 아님**(archive는 비활성). 활성 26개 내부엔 중복 0. 고유 name 33개(35 - 중복 2건분).

활성/archive 분리 집계: **활성 26 + archive 9 = 35** (질문 명시치 일치).

## D5-2. 트리거 메커니즘 (3종) — 실측

스킬은 **3개 독립 경로**로 발동되며, 어느 하나라도 걸리면 reachable:

### (A) 모델 네이티브 자동 발동 — `disable-model-invocation` 게이트
활성 26개 중 `disable-model-invocation: true` = **20개**(자동발동 차단), unset/false = **6개**(자동발동 허용):
- 자동발동 허용 6개 = `claude-in-chrome-recovery`(unset), `macos-tcc-handling`(unset), `production-bug-triage`(unset), `verification-before-completion`(unset), `verifier-protocol`(unset), `writing-plans`(unset), `orchestration-decision`(**false**).
  - (정확히는 unset 6 + false 1 = 7개가 자동발동 가능. macos-tcc-handling은 네이티브 광고 목록엔 부재하나 DMI unset.)
- 이 게이트가 **"available skills" 네이티브 광고 목록의 실체**: 시스템이 광고한 ProjectGrimoire 스킬 6종 = `claude-in-chrome-recovery / orchestration-decision / production-bug-triage / verification-before-completion / verifier-protocol / writing-plans` → **6/6 디렉터리 실존**(팬텀 광고 0건). 광고됐는데 없는 스킬 = 0.

### (B) 키워드 주입 — `skill-injector.sh` (UserPromptSubmit 훅)
- `.claude/scripts/skill-injector.sh`(L1-135): 각 SKILL.md frontmatter의 **`triggers:` 블록**(L83) 파싱 → 사용자 프롬프트와 **대소문자 무시 substring 매칭**(L90) → 매칭 시 SKILL.md 본문을 `additionalContext`로 주입(L125-131). **세션 내 중복방지**(`skill-sessions.json`, L116-119).
- `triggers:` 블록 보유 = **16/26**. 미보유 10개(`cron-job-verify, dev-db-measure, dev-health-check, dev-migration-apply, eval-run, prod-deploy, refund-logic-audit, sprint-end-commit, sprint-handover-finalize, verifier-protocol`)는 **이 경로로 주입 불가**(L83-84 `if not tb: continue`).
- **실제 발동 증거** (`.claude/state/skill-sessions.json`, 17 세션 누적): production-bug-triage 8, orchestration-decision 8, socratic-self-critique 6, macos-tcc-handling 5, gc-sweep 5, claude-in-chrome-recovery 4, verification-before-completion 4, requesting-code-review 3, writing-plans 3, rollback-revision 2, deploy-precheck 2, infra-mutation-guard 2, systematic-debugging 1, deploy-image-verify 1, memory-status 1, sensors-overview 1.
  - **= 정확히 16개 distinct = `triggers:` 보유 16개와 완전 일치.** injector 메커니즘 ↔ 실제 주입 **정합 입증.**
  - 본 세션에서 "오케스트레이션"→orchestration-decision, "나눠"→writing-plans 주입이 산 증거(둘 다 triggers 보유 + skill-sessions 누적 확인).

### (C) Stop 훅 사후 트리거 — `post-response-skill-injector.sh`
- `.claude/scripts/post-response-skill-injector.sh`(L1-66): Stop 훅에서 **메인 응답 텍스트** 매칭. **하드코딩 3종**: `verification-before-completion`(L43-44, "완료/done/finished"), `socratic-self-critique`(L45-46, "틀렸/잘못/실수"), `writing-plans`(L47-48, "나눠서/단계/분할/sub-task"). **실제 주입이 아닌 jsonl 로그만**(Stop 훅은 additionalContext 미지원, L12-13 자인).
- **실제 발동 증거** (`.claude/state/post-response-skill-trigger.jsonl`, 8건): socratic-self-critique 4, verification-before-completion 3, writing-plans 2. **하드코딩 3종과 정확히 일치.**
- 하드코딩 3종 전부 실존 스킬 = **broken 참조 0.**

### 훅 등록 확인 (`.claude/settings.json`)
양 injector + subagent 핸들러 전부 등록(python 파싱 실측):
```
UserPromptSubmit -> skill-injector.sh          (L69)
Stop             -> post-response-skill-injector.sh  (L49)
SubagentStop     -> subagent-stop-handler.sh
```
7개 훅 이벤트 전건 배선(SessionStart/Stop×2/UserPromptSubmit×2/PreCompact/InstructionsLoaded/PostToolBatch/PreToolUse×3/PostToolUse×4/PostToolUseFailure/SubagentStop).

## D5-3. 광고 목록 ↔ 디렉터리 정합

| 방향 | 결과 |
|------|------|
| 네이티브 광고됨 → 디렉터리 있음 | **6/6 OK** (claude-in-chrome-recovery, orchestration-decision, production-bug-triage, verification-before-completion, verifier-protocol, writing-plans). 팬텀 광고 0. |
| 디렉터리 있음 → 네이티브 광고 안 됨 | 20개. **결함 아님** — 이 20개는 `disable-model-invocation: true`(자동발동 의도적 차단)이거나 unset이어도 네이티브 목록 미노출. 발동은 (B)키워드 또는 `/slash` 명시 경로 사용. |

> 광고 목록이 26개 전부가 아니라 6개만 노출되는 것은 **정상 설계**: DMI=true 스킬은 "사용자가 `/명령`으로 명시 호출하거나 키워드 매칭될 때만" 의도. 시스템 reminder의 anthropic-skills:* / cowork-* 등은 플러그인/빌트인이며 본 감사(프로젝트 스킬) 범위 밖.

## D5-4. broken 참조 / 고아 스킬

### broken 참조 = 0건
- `.claude/skills/<name>` **경로 참조** 전건 실존(scripts/agents/settings/CLAUDE.md/AUTOMATION.md grep → 미존재 경로 0).
- **archive 스킬을 활성처럼 참조** = 0건(agents/CLAUDE.md/AUTOMATION.md/knowledge에서 8개 archive명 검색 → 활성 참조 0; reports/research 내 역사적 언급은 제외).
- post-response 하드코딩 3종 + 네이티브 광고 6종 모두 실존.

### 고아 스킬 = 0건 (3중 reachability 매트릭스)
스킬 reachable 조건 = **(A)네이티브 자동발동 OR (B)triggers 보유 OR (C)전체 repo 참조 ≥1**. 활성 26개 전수:

| 스킬 | DMI | triggers | native | repo참조 | reachable |
|------|:---:|:--------:|:------:|:--------:|-----------|
| claude-in-chrome-recovery | unset | Y | Y | 15 | trig+native+refs |
| cron-job-verify | true | . | . | 4 | refs |
| deploy-image-verify | true | Y | . | 5 | trig+refs |
| deploy-precheck | true | Y | . | 13 | trig+refs |
| dev-db-measure | true | . | . | 4 | refs |
| dev-health-check | true | . | . | 5 | refs |
| dev-migration-apply | true | . | . | 5 | refs |
| eval-run | true | . | . | 67 | refs |
| gc-sweep | true | Y | . | 12 | trig+refs |
| infra-mutation-guard | true | Y | . | 16 | trig+refs |
| macos-tcc-handling | unset | Y | . | 13 | trig+refs |
| memory-status | true | Y | . | 6 | trig+refs |
| orchestration-decision | false | Y | Y | 25 | trig+native+refs |
| prod-deploy | true | . | . | 5 | refs |
| production-bug-triage | unset | Y | Y | 25 | trig+native+refs |
| refund-logic-audit | true | . | . | 7 | refs |
| requesting-code-review | true | Y | . | 16 | trig+refs |
| rollback-revision | true | Y | . | 10 | trig+refs |
| sensors-overview | true | Y | . | 7 | trig+refs |
| socratic-self-critique | true | Y | . | 21 | trig+refs |
| sprint-end-commit | true | . | . | 5 | refs |
| sprint-handover-finalize | true | . | . | 3 | refs |
| systematic-debugging | true | Y | . | 13 | trig+refs |
| verification-before-completion | unset | Y | Y | 36 | trig+native+refs |
| verifier-protocol | unset | . | Y | 4 | native+refs |
| writing-plans | unset | Y | Y | 25 | trig+native+refs |

- **고아(트리거·참조 어디에도 없음) = 0건.** 26개 전부 최소 1경로로 reachable.
- ⚠️ **거짓 PASS 방지 주석**: 초기 좁은 grep(agents/scripts/knowledge/docs/CLAUDE.md/shared-contracts만)에선 `refund-logic-audit`가 "참조 0 = 고아"로 보였으나, **AUTOMATION.md·research/SKILL_GRAPH.md·reports/ 포함 전체 repo로 확장 시 7건 참조** + frontmatter `disable-model-invocation: true`(`/refund-logic-audit` 명시호출 전용, SKILL.md L8) → **고아 아님 / 의도적 slash-only 설계**. 동일하게 `cron-job-verify, dev-*, prod-deploy, sprint-*` 등 DMI=true·triggers없음 스킬도 `/slash` 명시호출 + repo 참조로 reachable. **"triggers 없음 = 고아"는 오판**(질문이 우려한 함정).

### D5 결함 요약
| ID | 심각도 | 결함 | 근거 |
|----|--------|------|------|
| D5-F1 | INFO | `eval-run` name 활성/archive 동시 존재(중복 name) | active + `_archive/eval-run` 양쪽 SKILL.md L2 |
| D5-F2 | INFO | triggers 미보유 10개는 UserPromptSubmit 키워드 주입 불가(slash/native 경로만) — **설계상 정상**(대부분 DMI=true) | skill-injector.sh L83-84 |
| (정보) | — | sensors-overview SKILL.md "14개 sensor" 카운트 stale(실측 56/57) — 선행 감사 B(L149)에서 이미 지적 | 본 감사 미재실측, 선행 감사 인용 |

**D5 판정 = PASS** (frontmatter 35/35 유효 + broken 참조 0 + 고아 0 + injector 2종 등록·발동 정합). 결함 전부 INFO 레벨.

---

## 부록 — 본 감사 RAW 명령 추적 (재현용)

- 에이전트 frontmatter: `awk` between `---` on `.claude/agents/*.md`
- invoke 분포: `grep -rhE '"name":"Agent"' ~/.claude/projects/.../*.jsonl | grep -c '"subagent_type":"<agent>"'`
- orchestration: `tail -1 .claude/state/orchestration-ratio.jsonl`
- skill frontmatter: `awk` name/description/triggers/disable-model-invocation on `*/SKILL.md`
- injector 발동: `.claude/state/skill-sessions.json`(16 distinct) + `post-response-skill-trigger.jsonl`(3 distinct)
- 훅 등록: `python3 json.load('.claude/settings.json')['hooks']`
- 고아: 3중 reachability(triggers ∪ native-advertised ∪ full-repo grep)

## 부록 — 본 감사 범위 밖(미검증 명시)
1. tools 화이트리스트의 **런타임 강제력**(verifier가 실제로 Edit 차단되는지) — frontmatter 의도만 확인, 가드 효력 미검증.
2. `sensors-overview` sensor 카운트 재실측 — 선행 감사 B 인용만.
3. `.claude/state/`의 **~25,118개 `sensor-hits.jsonl.tmp.<PID>` 0바이트 고아 임시파일**(state 총 25,368 entries 중 대부분) — 센서 atomic-write 임시파일 누수로 추정. **본 감사 범위(에이전트·스킬) 밖이나 발견 사실로 기록.** 정리 후보.
4. archive 9개 스킬의 archive 적정성(왜 보관/폐기인지) — 본 감사 미판정.

---
*감사자: 메인 위임 read-only 서브에이전트 / 수정 0건 / 2026-06-01*
