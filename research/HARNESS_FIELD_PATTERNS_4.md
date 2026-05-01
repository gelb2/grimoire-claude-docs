# Harness Engineering — 현장 운영 4 패턴 (분리 정본, 2026-05-02 묶음 L M1)

> **분리 사유** (책 Ch 08 60-line 황금률 적용 후속):
> `research/HARNESS_ENGINEERING.md` 1300+ 줄 navigation 부담 해소를 위해 §15 (현장 운영 4 패턴, 161줄)을 별도 정본으로 분리. § 번호는 그대로 유지 (§15.1 ~ §15.7) — 8개 파일 참조에서 본 파일 경로만 갱신.
>
> **참조하는 파일** (8개, § 번호 호환 유지):
> - `.claude/AGENTS.md` §2.2 (메인 Claude 오케스트레이션)
> - `.claude/AGENTS.md` §2.2.1 (자가 분류 의무, 묶음 J K1)
> - `.claude/skills/orchestration-decision/SKILL.md` (위임 가치 매트릭스)
> - `.claude/skills/worktree-isolation/SKILL.md` (위임 가치 매트릭스 적용)
> - `.claude/skills/eval-run/SKILL.md`
> - `.claude/skills/gc-sweep/SKILL.md`
> - `.claude/knowledge/agent-interaction-matrix.md`
> - `.claude/scripts/sensor-credit-atomicity.sh`
>
> **본 파일 변경 시**: `research/HARNESS_ENGINEERING.md` §15 pointer 라인 + 위 8개 파일 참조 갱신 검토.
>
> **원본 위치**: `research/HARNESS_ENGINEERING.md` §15 (2026-04-25 신설 → 2026-05-02 본 파일로 분리, 원본은 1줄 pointer만 남김).

---

## 15. 현장 운영 4 패턴 (2026-04-25 신설)

> **사유**: 외부 팀(다른 회사 사람) 인터뷰에서 도출된 4 패턴이 Fowler 정본 문서에 직접 명시되지 않은 "현장 결정 지점"임을 확인. 외부 자료 (Anthropic 공식 / HumanLayer / sshh.io / Builder.io / PrestaShop / AddyOsmani)로 검증한 결과 4 패턴 모두 실재. ProjectGrimoire가 이 4축에서 어디에 위치하는지 명시 + 향후 진화 방향 결정 근거.

### 15.1 패턴 1 — 오케스트레이션 분리

**정의**: 메인 Claude(채팅 세션) = 지시·조율만. 실제 코드 작성은 서브에이전트/팀에이전트가 수행. 메인의 컨텍스트 보호 + 격리 + 병렬.

**Anthropic 입장**: 권장 (단 agent teams는 experimental, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 필요).

**대표 사례**:
- Anthropic 공식 "Orchestrate teams of Claude Code sessions" — lead session = "coordinating work, assigning tasks, synthesizing results", teammates = "work independently in own context window"
- AddyOsmani "Code Agent Orchestra" — "central AI thread coordinates specialist agents - it doesn't write code itself"
- HumanLayer "subagent-driven-development" — 2-stage review (spec → quality)

**장단점**:
- ✅ 컨텍스트 격리 + 병렬화
- ❌ 토큰 비용 선형 증가 + 조율 오버헤드. 실패 모드: lead가 직접 구현해버림 ("Wait for your teammates to complete")

### 15.2 패턴 2 — CLAUDE.md = 도메인/인프라/문서 허브

**정의**: CLAUDE.md를 모든 정보의 **진입점(허브)**로. 도메인 지식 + 인프라 + 외부 문서 링크를 한 파일에 모음.

**Anthropic 입장**: 중립~약권장 (best-practices가 CLAUDE.md 자체는 권장하나 크기 한도는 명시 안 함).

**대표 사례**:
- Builder.io / DataCamp — "agent's constitution, primary source of truth", 13~25KB까지 정당화
- shanraisshan/claude-code-best-practice 레포

### 15.3 패턴 3 — 루트 기획서 = SSOT, CLAUDE.md = 좁게 (코드 컨벤션·팀 규약만)

**정의**: 진실의 근원은 별도 기획 문서. CLAUDE.md는 좁게 (컨벤션·규약만).

**Anthropic 입장**: 중립.

**대표 사례 + 임계값 근거**:
- HumanLayer "Writing a good CLAUDE.md": "official recommendation under 200 lines, some teams under 60"
- **sshh.io** (결정적): "instruction-following degrades at 150-200 total instructions" — 시스템 프롬프트가 ~50 슬롯 차지 → 가용 100~150 슬롯
- PrestaShop Issue #41152: `CONTEXT.md` = AI-agnostic SSOT, `CLAUDE.md` = pointer

**장단점**:
- ✅ Attention 보존 + instruction-following 유지
- ❌ 도메인 컨텍스트 분산 → 신규 세션 진입 비용 ↑

### 15.4 패턴 4 — Skill / Sub-agent / Team-agent 취향껏

**정의**: 표준 정답 없음 — 팀 선호대로.

**Anthropic 입장**: 분기 기준 제공, 강제는 안 함.
- "rules that apply to nearly every task → CLAUDE.md, specific workflows that only matter sometimes → Skill"
- "Use subagents when... quick focused workers report back. Use agent teams when... share findings, challenge each other"

**대표 사례**: Anthropic Skills 공식 블로그 + Level Up Coding "Mental Model" + AntStack Field Guide.

### 15.5 4 패턴 양립성

**패턴 2 vs 3은 직접 모순**. 결정적 데이터: sshh.io의 "150-200 instruction degradation". CLAUDE.md를 허브로 키우면 instruction-following 자체가 깨진다 → 패턴 2를 무한 확장하는 팀은 임계값 도달 시 **자동으로 패턴 3으로 강제 수렴**.

**패턴 1·4는 패턴 2·3 어느 쪽과도 양립 가능**.

**패턴 1 + 패턴 3 조합은 시너지**: 메인이 코드 작성 안 하면 두꺼운 도메인 컨텍스트가 메인에 들어갈 필요 없음 (subagent에게만 필요) → 패턴 1로 갈수록 CLAUDE.md 슬림화가 자연스러움.

### 15.6 출처
- [Anthropic Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [Skills explained](https://claude.com/blog/skills-explained)
- [HumanLayer — Writing a good CLAUDE.md](https://www.humanlayer.dev/blog/writing-a-good-claude-md)
- [sshh.io — How I Use Every Claude Code Feature](https://blog.sshh.io/p/how-i-use-every-claude-code-feature)
- [Builder.io — How to Write a Good CLAUDE.md](https://www.builder.io/blog/claude-md-guide)
- [PrestaShop #41152 — CONTEXT.md SSOT](https://github.com/PrestaShop/PrestaShop/issues/41152)
- [AddyOsmani — Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/)

### 15.7 패턴 1 위임 가치 가이드라인 (2026-04-26 #9 신설)

> **사유**: sensor-orchestration-ratio P2 첫 실측 결과 ratio 0.0000 (메인 696 / Task 0). 패턴 1 도입(§15.1) vs 실제 적용 0% 갭 객관화. 메인 Claude가 어떤 작업에서 subagent 위임이 가치 있는지 가이드라인 없으면 패턴 1 KPI 영구 0 유지. 본 §15.7은 ProjectGrimoire 운영 데이터 기반 위임 결정 매트릭스.

#### 15.7.1 위임 가치 매트릭스

| 작업 특성 | 메인 직접 | subagent 위임 |
|---|---|---|
| **시간** ≤ 30분 | ✅ (spawn 오버헤드 > 작업) | ❌ |
| **시간** 30분 ~ 1시간 | ✅ (조건부, 단일 도메인 시) | ⚠️ (다중 도메인 시) |
| **시간** ≥ 1시간 + 다중 도메인 | ❌ (컨텍스트 폭주 위험) | ✅ |
| **시간** ≥ 2시간 단일 도메인 | ⚠️ (할 만하지만 컨텍스트 부담) | ✅ (격리 가치) |
| **도메인** 단일 (.claude/) | ✅ | ❌ |
| **도메인** 단일 (server only) | ⚠️ | ✅ (grimoire-server) |
| **도메인** 단일 (web only) | ⚠️ | ✅ (grimoire-web) |
| **도메인** 다중 (server + web 동시) | ❌ | ✅ (server + web 병렬) |
| **검증 단계** (qa) | ❌ (자가 검증 신뢰성 ↓) | ✅ (qa 독립 재실행) |
| **메모리/문서/.claude 설정** | ✅ (조율 자체) | ❌ |
| **단순 grep/실측** (Bash 1~3개) | ✅ | ❌ |
| **사용자 "직접 해" 명시** | ✅ | ❌ (사용자 의도 종속) |
| **반복 sub-task 병렬화 가능** | ❌ (순차 비효율) | ✅ |
| **외부 검증 필요 (보안/원가)** | ❌ | ✅ (cost-accountant / VCK / qa) |

#### 15.7.2 핸드오프 비용 임계값

subagent 위임은 다음 비용 동반:
1. **Spawn**: ~15초 (Task tool 초기화 + agent 정의 로드)
2. **컨텍스트 전달**: 메인 → subagent prompt (~2~5K 토큰)
3. **결과 반환**: subagent → 메인 요약 (~1~3K 토큰)
4. **메인 재인수**: subagent 결과 검증 + 다음 단계 결정 (~2~5K 토큰)

**총 핸드오프 비용 ≈ 30초 + 5~13K 토큰**.

작업 자체 비용이 위 임계값을 **3배 이상 초과**할 때 위임 가치 있음:
- 시간: ≥ 90초 (실제로는 너무 짧아 다른 기준이 우선) → **≥ 1시간 권장**
- 토큰: ≥ 30K (작업 컨텍스트 + 출력) → **다중 파일 작업 + 다중 도메인 권장**

#### 15.7.3 ProjectGrimoire 적용 데이터 (2026-04-26 #9 첫 케이스)

본 세션에서 메인 직접 처리한 작업 분류:

| 작업 | 시간 | 도메인 | 적합 결정 | 실제 결정 | 합치 |
|---|---|---|---|---|---|
| Z (claude-docs develop 분기) | ~30분 | 단일 (메모리/git) | 메인 직접 | 메인 직접 | ✅ |
| X-L (sensor + skill) | ~1시간 | 단일 (.claude/) | 메인 직접 (조건부) | 메인 직접 | ✅ |
| X-P (graph 생성) | ~1시간 | 단일 (.claude/ + research/) | 메인 직접 (조건부) | 메인 직접 | ✅ |
| Y (가이드라인 박제) | ~30분 | 단일 (research/) | 메인 직접 | 메인 직접 | ✅ |
| N (SDK signal) | ~30분 | 단일 (server) | 메인 직접 (조건부) | 메인 직접 | ✅ |
| **1차+2차 (이전 메시지)** | ~3시간 | **다중 (.claude/ + research/ + AUTOMATION)** | **subagent 위임 권장** | **메인 직접** | **❌ KPI 손실** |

본 세션 합치율: **5/6 = 83%**. 1차+2차에서만 부적합 결정 (subagent 위임 가치 있었으나 메인 직접 처리 → 패턴 1 KPI 0.0 유지).

##### 15.7.3.1 위임 3건 추가 박제 (2026-04-26 #9 H'+I'+F + W + X 묶음)

| 작업 | 위임 대상 | 매트릭스 매칭 | 효과 | 합치 |
|---|---|---|---|---|
| I' (WARN 5건 정밀 분석) | cost-accountant | ✅ "AI 기능 마진 검증 / 가격 변동" 외부 검증 도메인 | 분석/베스트 FAIL 약점 식별 + planner 핸드오프 박제 | ✅ |
| 분석 4 크레딧 재계산 + 시뮬 | cost-accountant | ✅ "ai-cost-table.md 단독 관리" + 가격 변경 시 마진 검증 | ai-cost-table 직접 갱신 + §0 위반 차단 (베스트 2.79→3.35× FAIL→PASS) | ✅ |
| BBB (AI_COST_MONITOR 갱신) | researcher | ✅ "시장 조사 / AI 가격 모니터링" | staleAfter 갱신 + Claude Opus 4.7 신규 박제 | ✅ |

**누적 합치율 (본 세션): 8/9 = 88.9%** (1차+2차 5/6 + 위임 3건 3/3).

##### 15.7.3.2 sensor-orchestration-ratio 측정 한계 발견

본 세션 #9에서 위임 3건 모두 §15.7.3.1처럼 박제했으나 sensor-orchestration-ratio가 ratio 0.0000을 보고. 원인:

- **진행 중 세션의 jsonl flush 지연** (Claude Code가 세션 종료 후 또는 일정 시점에 flush)
- 본 세션 jsonl(`af2dbdaa-...jsonl`) Task 박제 0건 (실제 위임 3건과 불일치)
- 다음 세션 진입 시 본 세션 위임 3건이 jsonl에 박제되어 측정 가능

**해결**: §15.7.3 합치율은 **메인 자가 박제**(본 절)와 **sensor 자동 측정**(sensor-orchestration-ratio jsonl) 두 채널 병행. 다음 세션부터 ratio 0.0 → 양수 진입 예상.

#### 15.7.4 다음 세션 부터 적용 규칙

1. **사전 분류**: 작업 시작 전 위 매트릭스로 결정 (메인 직접 / subagent 위임 / 사용자 결정 필요)
2. **결정 박제**: 사용자에게 sub-task 분할 제시 시 각 항목에 "메인 / subagent 위임 / 위임 후보" 표시
3. **사후 측정**: sensor-orchestration-ratio가 매주 실행 → 합치율 추적 (목표: ≥ 80% 유지 + 위임 가치 있는데 메인 직접한 케이스 0% 향함)
4. **반례 박제**: 가이드라인과 다른 결정을 했을 때 사유를 sensor-hits.jsonl 또는 메모리에 박제 (가이드라인 진화 데이터)

#### 15.7.5 가이드라인 자체 진화

본 §15.7은 **운영 데이터로 진화**:
- N+1 세션마다 sensor-orchestration-ratio jsonl 누적
- 케이스 데이터 100건 도달 시 가이드라인 재검토 (임계값 조정)
- 패턴 1 KPI 0.0 → 0.20 도달 시 §15.7 첫 진화 (P4 단계)

본 가이드라인은 **시작점**. ProjectGrimoire 1인 운영 + 짧은 작업 빈도 패턴이 다른 팀(다인 운영)과 다를 수 있음.

---

