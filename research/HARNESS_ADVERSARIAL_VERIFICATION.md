# HARNESS_ADVERSARIAL_VERIFICATION — 적대적 검증 도입 리서치

> **분리 정본**: `research/HARNESS_ENGINEERING.md` §18에서 분리 (2026-05-02 #10_6 신설). cross-ref sensor (sensor-harness-cross-ref) 5정본 등록.
> **작성일**: 2026-05-02 #10_6 (사용자 지시 — 우로보로스 / 악마의 변호인 / 레드팀 ProjectGrimoire 적용 조사)
> **사용자 요구**: "코드/에이전트/유닛테스트/배포 스크립트/하네스 절차에서 누락한 것을 커밋 직전 전방위 공격 → 모두 방어 시에만 commit 가능 → 실패 시 자동 개선 후 재시도 → 사용자 확인 거의 없이 자율"
> **전제**: 외부 Anthropic API 의존 0건 (사용자 명시 0-1 결정 준수)
>
> **결론 미리**: **80% 가능 (외부 API 0, 코드 기반 + 메타 프롬프트) / 20% 보류 (LLM-based dynamic attack은 사용자 결정 영역)**

---

## 1. 조사한 3 개념 — 산업 정본 분석

### 1-1. 우로보로스 (Ouroboros) — 소크라테스 자기-질문 패턴

#### 정본 레포: `Q00/ouroboros` (GitHub)
- **5단계 워크플로우**: Interview → Seed → Execute → Evaluate → Evolve (loop)
- **Two-diamond 모델**:
  - **Socratic Diamond**: 질문 다이버전스 → ontological clarity 컨버전스
  - **Pragmatic Diamond**: 디자인 옵션 다이버전스 → verified delivery 컨버전스
- **임계값**: "Ambiguity ≤ 0.2" — 모호성 정량 측정
- **핵심 인용**: "Why do you want this? Is that truly necessary?" — Socratic questioning이 hidden assumption 노출
- **외부 API 의존**: 명확하지 않음 (MCP 참조). skills/ 디렉토리에 SKILL.md 분산

#### 차용 가치
- **메타 프롬프트 self-critique** (외부 API 0) — Claude Code 메인 세션에서 자체 발동
- 작업 완료 선언 직전 7~10 Socratic 질문 자동 — 우리 `verification-before-completion` skill과 시너지

---

### 1-2. 악마의 변호인 (Devil's Advocate) — 적대적 다중 검토

#### 정본 레포: `ng/adversarial-review` (Claude Code 플러그인)

**The Optimizer (낙관자)** + **The Skeptic (회의자)** 두 에이전트:
- Optimizer: "Find every issue worth fixing" — 모든 수정 가능 문제 발굴
- Skeptic: "Challenge findings + catch missed issues" — 발견 검증 + 누락 포착
- **자동 반박 강요 없음** — 실질적 이의만

**Mechanical Checks First (free)** — 외부 API 0 단계:
- Lint (코드 스타일)
- Typecheck (정적 타입)
- Build (컴파일)
- Test (기존 테스트)

**Cost Gate Scoring** (LLM 비용 필터):
| 점수 | 처리 |
|------|------|
| ≤ 0 | Report만, LLM 스킵 |
| 1~4 | Sonnet only (2 에이전트) |
| ≥ 5 | Sonnet + Opus (4 에이전트) |

**Bounded Verification Loop** (max 2 iterations) — 무한 루프 방지:
```
Apply consensus fixes → Verify (max 2) → Pass? Report : Fix regressions → 2회 후도 실패면 Report with issues
```

**Pre-commit 통합**: GitHub Action만 지원 (`pull_request` 트리거). pre-commit hook 직접 지원 X.

---

### 1-3. 레드팀 (Red Team) — 사이버보안 + 군사

#### LLM Red Teaming 프레임워크 (산업 표준)

**Promptfoo** (OpenAI/Anthropic 실사용):
- GitHub Action 박제
- 20+ adversarial attack methods
- assertion 기반 (declarative)
- LLM 호출 동반 → 외부 API 의존

**DeepTeam** (`confident-ai/deepteam`):
- 동적 attack 생성 (사전 데이터셋 없음)
- 단일/다중 턴 red teaming
- LLM 호출 동반

**RedAmon** (LangGraph): 
- ReAct 패턴 자율 에이전트
- Recon → Exploitation → Post-exploitation 3단계

#### 코드 기반 Pre-commit Security Hooks (외부 API 0)

산업 권장 (DevSecOps School):
- **검사 시간 1~3초 + 결정적**: pre-commit
- **무거운/비결정적**: CI
- **검사 영역**: 시크릿 (git-secrets/talisman/detect-secrets) / CVE / linter / 위험 명령 패턴

---

### 1-4. Constitutional AI (Anthropic) — 자기-비판 정본

**16 Principles** (원본 2022) → **84 페이지 / 200+ principles** (2026 갱신)

**자기-비판 루프**:
1. 응답 생성
2. constitution principle random 선택
3. principle 기반 critique
4. critique 기반 revise
5. 반복

**프롬프트 패턴**:
> "Critique the previous response using the principle: [principle]. Then revise the response."

**핵심**: AI feedback (RLHF) → AI supervision (RLAIF) — 인간 데이터 없이 harmless 학습

---

## 2. ProjectGrimoire 적용 정합성 — 95% 정합 / 5% 갭

### 2-1. 이미 우리 시스템에 박제된 것

| 패턴 | 우리 구현 | 책 출처 |
|------|---------|---------|
| Mechanical Checks First | sensor-server / sensor-web / sensor-secret-leak / sensor-security-gate / sensor-credit-atomicity | ng/adversarial-review |
| Bounded Retry Loop | sensor-web `.next` stale 자동 fallback (max 1 retry) | ng/adversarial-review |
| Pre-commit Hook | `.githooks/pre-commit` (drift + eval-precommit, regression-tolerance 0.05) | DevSecOps 산업 표준 |
| Self-Critique 메타 | `verification-before-completion` skill (완료 선언 전 실측 강제) | Constitutional AI 정본 차용 |
| 산업 패턴 정본 | `.claude/shared-contracts.md` (10 인터페이스, 책 Ch 16) | Anthropic Constitutional |
| Cost Gate | sensor-cost-margin (안전배수 ≥3.5×) + sensor-context-budget (토큰 예산) | ng/adversarial-review cost gate |

→ **80% 정합** (외부 API 0 영역 모두 충족)

### 2-2. 갭 (구현 가능 영역, 외부 API 0)

| ID | 갭 | 구현 가능성 |
|----|------|------------|
| **AV-1** | Constitutional 박제 (우리 도메인 16 principles) | ✅ 즉시 (메타 프롬프트, 외부 API 0) |
| **AV-2** | Socratic Self-Critique skill (Ouroboros 차용) | ✅ 즉시 (Claude Code 메인 세션 자체 호출) |
| **AV-3** | Adversarial Pre-commit Sensor (전방위 패턴 검증) | ✅ 즉시 (정적 분석 + 패턴 grep) |
| **AV-4** | Bounded Retry Loop (max 2 iterations) | ✅ 즉시 (스크립트 + skill 연계) |
| **AV-5** | Pre-commit hook 강화 (기존 + AV-3 + AV-4) | ✅ 즉시 (.githooks/pre-commit 보강) |

### 2-3. 보류 영역 (외부 API 의존, 사용자 0-1 결정)

| ID | 보류 사유 |
|----|---------|
| **DEFER-1** | ng/adversarial-review LLM 단계 (Sonnet/Opus dual model) — 비용 의존 |
| **DEFER-2** | zscole/adversarial-spec 다중 LLM debate (~$0.08/round) — 외부 API |
| **DEFER-3** | Promptfoo LLM-based attack 자동 생성 — 외부 API |
| **DEFER-4** | DeepTeam 동적 attack — 외부 API |

→ **20% 갭** = 사용자가 "0-1 보류 해제" 명시할 때 검토

---

## 3. 기술적 정확성 검증

### 3-1. "전방위 공격" 가능 여부

| 공격 영역 | 외부 API 0 검증 가능? |
|----------|--------------------|
| 코드 보안 (시크릿/SQL injection/XSS) | ✅ 정적 분석 + 패턴 grep (sensor-secret-leak 보유) |
| 의존성 CVE | ✅ npm audit + safety-db (외부 도구 설치 동반) |
| 아키텍처 위반 (Hexagonal/FSD) | ✅ 패턴 grep (sensor-shared-contracts 보유) |
| 정책 위반 (§0 원가 / 시각 정본 / 작가 콘텐츠) | ✅ sensor-cost-margin / sensor-instruction-degradation 보유 |
| 시스템 일관성 (drift) | ✅ instructions-drift-check 보유 |
| 메타 프롬프트 (Ouroboros / Socratic) | ✅ Claude Code 메인 세션 자체 발동 (외부 API 0) |
| **동적 attack (jailbreak / injection)** | ❌ LLM-based — 외부 API 동반 (보류) |
| **adversarial reasoning (Optimizer vs Skeptic 모순 검출)** | ❌ LLM-based (보류) |

→ **80% 커버 가능** (코드 기반 + 메타 프롬프트만으로)

### 3-2. "커밋 직전 발동" — pre-commit hook 정합

이미 `.githooks/pre-commit` 박제. 강화 영역:
```bash
[1/4] update-harness-inventory --apply (NEW-5)
[2/4] instructions-drift-check.sh
[3/4] eval-precommit.sh (regression-tolerance 0.05)
[4/4] adversarial-pre-commit.sh (NEW — Phase α)
```
→ ✅ 가능, 시간 영향 ~30s 추가 (현재 ~30s → ~60s)

### 3-3. "모든 방어 시 성공" — exit 0 게이트

`set -e` + 각 단계 exit 0 검증 → 1건이라도 실패 시 commit 차단. 이미 패턴 정합.

### 3-4. "실패 시 자동 개선 + 재시도" — Bounded Retry

ng/adversarial-review의 max 2 iterations 패턴:
- 1차 실패 → sensor 트레이스 분석 → 자동 fix 시도
- 2차 시도 → 통과 시 commit / 실패 시 사용자 보고

⚠️ **위험 요소**: 자동 fix가 잘못된 방향으로 돌아갈 수 있음 (특히 메타 작업 영역)
- 완화: 자동 fix는 결정적 영역만 (drift 갱신, jsonl 박제 등). 의미 있는 코드 변경은 사용자 보고.

### 3-5. "사용자 확인 거의 없이" — 자율 자동

pre-commit hook = 자동 발동 + 자동 차단. 사용자 개입 = 1차 실패 시 보고만.
- ✅ 가능 (단, 자동 fix 영역 제한 필수 — 위 3-4 위험)

---

## 4. 구현 계획 (외부 API 0, 4 Phase)

### Phase α (~2~3h) — 코드 기반 적대적 sensor 신설

**산출물**:
1. `.claude/knowledge/red-team-constitution.md` (16~20 principles 박제)
   - Constitutional AI 16 principles 패턴 + Grimoire 도메인 적용
   - §0 ZERO-TOLERANCE / 사슴악마 시각 정본 / 작가 콘텐츠 보호 / §0 원가 ≥3배 / 외부 API 보류 / shared-contracts 준수 / 분할 정본 ≤300줄 / sensor PASS / Stop hook 메모리 / 한국어 존댓말 등
2. `.claude/scripts/sensor-adversarial-pre-commit.sh` (코드 기반 전방위 공격)
   - constitution 16 principles 자동 검증
   - 위반 1건이라도 발견 시 exit 1
3. `eval/tasks/auto-sensor-adversarial-pre-commit.json` (회귀 보호)

**검증**: regression PASS + 의도적 위반 commit 시뮬 (시크릿 추가 → 차단 확인)

### Phase β (~1~2h) — Socratic Self-Critique skill

**산출물**:
1. `.claude/skills/socratic-self-critique/SKILL.md` (메타 프롬프트)
   - Ouroboros Two-diamond Socratic 차용
   - 7~10 질문 박제:
     - Why do you want this? (목적 검증)
     - Is that truly necessary? (필요성 검증)
     - What hidden assumption are you making? (가정 노출)
     - What if this fails? (실패 시나리오)
     - Who else is affected? (영향 범위)
     - Is there a simpler way? (단순화 가능성)
     - Have you violated §0 or constitution? (정책 검증)
     - 등
2. 트리거: `verification-before-completion` skill 연계 + 작업 종료 직전

**검증**: 모의 작업 완료 → self-critique 자동 발동 + 7+ 질문 출력

### Phase γ (~1~2h) — Bounded Retry Loop

**산출물**:
1. `.claude/scripts/adversarial-retry-handler.sh` (max 2 iterations)
   - 1차 실패 → sensor 트레이스 → 자동 fix 시도 (결정적 영역만)
   - 2차 시도 → 통과 시 commit / 실패 시 사용자 보고
2. `.githooks/pre-commit` 강화 — Phase α sensor 호출 + Phase γ retry handler

**검증**: 의도적 drift commit → 1차 실패 → 자동 갱신 → 2차 commit 통과

### Phase δ (보류 — 사용자 명시 시)

**조건부 산출물** (사용자가 "0-1 보류 해제" 명시 시):
- ng/adversarial-review 통합 (Optimizer + Skeptic LLM 단계)
- Promptfoo CI 통합 (LLM-based attack)
- DeepTeam 동적 attack

비용 추정: 묶음당 ~$0.10~$0.50 / 월간 ₩50,000 한도 박제 (cost-accountant 가드 활용)

---

## 5. 위험 요소 + 완화책

| 위험 | 완화책 |
|------|--------|
| pre-commit 시간 증가 (30s → 60s+) | Phase α sensor 결정적 + 1초 임계 강제 |
| 자동 fix 잘못된 방향 (위양성) | 자동 fix는 drift 갱신 / jsonl 박제만. 코드 변경은 사용자 보고. |
| Constitution 과대 (16 → 50 principles 폭주) | 책 Ch 23 안티패턴 ② "규칙 폭발" 방어 — 16 principles 캡 |
| Self-critique 마찰 (매번 7질문 자동) | 트리거 조건 — 완료 선언 키워드 매칭 시만 (verification-before-completion skill 패턴) |
| 외부 API 의존 무의식 도입 | sensor-shared-contracts §4 mtime 검증 + 자가진단 Q4 영구 SKIP 박제 |

---

## 5.5. 자율학습/자기-업그레이드 패턴 평가 (2026-05-02 #10_6 사용자 추가 질문)

### 사용자 제안
"모든 작업 시작 직전에 constitution + sensor가 인터넷 검증 데이터로 자기-업그레이드 → 작업 완료 시 자기 역할 수행"

### 평가: **80% 정합 / 20% 위험 (조건부 적용 시 정확)**

#### 80% 정합 (책 V1.1 + 산업 정본)
- Fowler Steering Loop (HARNESS §3) — 반복 문제 → harness 자체 진화
- Ouroboros Evolve 단계 (Q00/ouroboros) — evaluation → next generation
- 책 Ch 23 결론 "하네스는 정원 — 가꿔야 함" 자동화 정공법
- 책 Ch 21 Inform + Correct 기둥 자동 강화
- Mitchell Hashimoto Ghostty (Cuneiform Chat 정합) — "실수마다 규칙 1줄"
- Constitutional AI RLAIF — AI feedback 자기-개선

#### 20% 위험 (책 Ch 23 안티패턴 직격)
- **안티패턴 #4 모델 의존 착각** — "자기-학습이 알아서 해결" 함정
- **안티패턴 #7 거버넌스 부재** — 누가 자기-수정 승인하는가? §0 위반
- **책 Ch 17 보안 Layer 1 Prompt 위협** — 인터넷 데이터 prompt injection
- 무한 자기-수정 (Devin/AlphaZero 한계) — bounded environment 필수
- §0 ZERO-TOLERANCE — 정책 변경은 사용자 명시 결정 영역

### 산업 패턴 검증 (100% 자율 자기-수정 시스템 부재)

| 시스템 | 자기-진화 | 사용자 승인 게이트 |
|--------|---------|------------------|
| Q00/ouroboros | Evolve 단계 | Ambiguity ≤ 0.2 임계 + skill SKILL.md 정적 박제 |
| Constitutional AI | RLAIF self-critique | constitution은 Anthropic 인간 승인 (84 page 2026) |
| AlphaZero | 자기-대국 | bounded game (Go 규칙 불변) |
| Devin | 자율 작업 | 사용자 review 게이트 |
| Mitchell Ghostty | 실수→규칙 | Mitchell 본인이 박제 (자율 X) |

→ **공통 패턴: bounded + governance gate**. 100% 자율 자기-수정 산업 사례 없음.

### 정확한 적용 — 3 Phase 분리 (거버넌스 게이트 필수)

```
[Phase α-자율 — 자료 수집]
WebFetch (whitelist 출처) → .claude/state/red-team-data-pending.jsonl
- 출처: docs.anthropic.com / obra/superpowers MIT / OWASP LLM Top 10 / arxiv / Mozilla MDN
- WebFetch = Claude Code 기본 도구 (구독료 안, 종량제 외부 API 0)

[Phase α-반자율 — Propose]
메인 Claude 자가 검증 + propose → .claude/proposals/red-team-update-{YYYYMMDD}.md
⚠️ 게이트: 사용자 승인 (자율 적용 X)
근거: §0 정책 강제 종속 + 책 Ch 23 거버넌스 부재 방어

[Phase α-자율 — 검증]
pre-commit hook 발동 (이미 박제된 constitution + sensor 사용)
자율 100%, 사용자 개입 0
```

### 추가 안전 장치 (사용자 제안에 보강 권장)

| 안전 장치 | 사유 | 구현 |
|---------|------|------|
| **출처 whitelist** | 검증되지 않은 출처 prompt injection 차단 | sensor-red-team-source-whitelist.sh |
| **Diff 박제** | 자기-수정 결과 추적 가능 | git branch `auto-evolve/red-team-{date}` |
| **회귀 검증** | 갱신 후 자동 회귀 (FAIL 시 propose 폐기) | pre-commit hook 통합 |
| **빈도 캡** | 매 작업마다는 위험 (책 Ch 18 비용 + 안티패턴 #4) | 일주일 1회 또는 사용자 트리거 시만 |
| **사용자 승인 게이트** | §0 정책 보호 | proposals/ 디렉토리 + 사용자 명시 후 적용 |

### 결론
사용자 제안의 핵심 의도(자율학습 + 자기-업그레이드)는 **하네스 엔지니어링 정공법**이지만, "사용자 확인 거의 없이"는 **거버넌스 부재 안티패턴 #7 직격**이라 위험.

**권장 보강**: 자율(수집 + propose) + 사용자 게이트(승인) + 자율(검증) 3단 분리 = 책 V1.1 정합 + §0 보호 + 사용자 의도 80% 충족.

---

## 6. 사용자 결정 영역

다음은 자율 진행 금지 — 사용자 명시 후 진행:
- **Phase δ 진행 여부** (외부 API 의존, 사용자 0-1 결정 위반 가능성)
- **Constitution 16 principles 정확한 내용 검토** (사용자가 도메인 정본 결정자)
- **자동 fix 영역 확장** (위 3-4 위험 — 결정적 영역 외 확장 시 사용자 검토)

---

## 7. 출처 (Citations)

### 우로보로스
- [Q00/ouroboros · GitHub](https://github.com/Q00/ouroboros)
- [Q00/ouroboros CLAUDE.md](https://github.com/Q00/ouroboros/blob/main/CLAUDE.md)
- [The Socratic Method for Self-Discovery in LLMs · Princeton NLP Group](https://princeton-nlp.github.io/SocraticAI/)
- [roy-reshef/socratic-ai-prompt-skill · GitHub](https://github.com/roy-reshef/socratic-ai-prompt-skill)

### 악마의 변호인 / Adversarial Review
- [ng/adversarial-review · GitHub](https://github.com/ng/adversarial-review)
- [zscole/adversarial-spec · GitHub](https://github.com/zscole/adversarial-spec)
- [adversarial-review GitHub Topics](https://github.com/topics/adversarial-review)
- [Claude Plugin Hub — adversarial-review](https://www.claudepluginhub.com/plugins/ng-adversarial-review)

### 레드팀 (사이버보안 + AI)
- [DeepTeam by Confident AI](https://www.trydeepteam.com/docs/what-is-llm-red-teaming)
- [confident-ai/deepteam · GitHub](https://github.com/confident-ai/deepteam)
- [promptfoo/promptfoo · GitHub](https://github.com/promptfoo/promptfoo)
- [Promptfoo CI/CD Integration](https://www.promptfoo.dev/docs/integrations/ci-cd/)
- [studiofarzulla/adversarial-security-agents · GitHub](https://github.com/studiofarzulla/adversarial-security-agents)
- [samugit83/redamon · GitHub](https://github.com/samugit83/redamon)

### Constitutional AI (Anthropic)
- [Claude's Constitution (Anthropic)](https://www.anthropic.com/news/claudes-constitution)
- [Constitutional AI: Harmlessness from AI Feedback (arxiv 2212.08073)](https://arxiv.org/abs/2212.08073)
- [Constitutional AI: Principle-Based Alignment Through Self-Critique (Brenndoerfer)](https://mbrenndoerfer.com/writing/constitutional-ai-principle-based-alignment-through-self-critique)

### Pre-commit Security Hooks (산업 표준)
- [DevSecOps School — Pre-commit Hook Guide 2026](https://devsecopsschool.com/blog/pre-commit-hook/)
- [Pre-Commit Security Hooks (hoop.dev)](https://hoop.dev/blog/pre-commit-security-hooks-stopping-threats-before-code-leaves-your-machine)
- [Catching Bugs Before They Break Out (aquilax.ai)](https://aquilax.ai/blog/pre-commit-hooks-for-security-code-scanning)

---

## 8. 변경 이력
- 2026-05-02 #10_6: 본 파일 신설 — 사용자 지시 (우로보로스 + 악마의 변호인 + 레드팀 ProjectGrimoire 적용 조사). 4 Phase 구현 계획 박제. 외부 API 0 조건 95% 정합 확인.
