# 「하네스 엔지니어링 완전 정복」(shuntailor V1.1, 2026-03) 학습 박제

> ProjectGrimoire 적용 정본. 책 전체 학습 완료 (Ch 1~23 + 부록 A/B/C, 206 페이지).
> 박제 일자: 2026-04-30 #10 (Ch 08/15/16) → 2026-05-01 #10_5 전면 갱신 (책 전체).
> **POINT**: "모델은 범용품(commodity)이다. 하네스가 해자(moat)다." (책 결론)

---

## 책 구조 — 6 Part / 23 Ch / 부록 3

| Part | 챕터 | 주제 |
|------|------|------|
| Part 1 (Ch 1~3) | 개념 정립 | 하네스 정의 + 4 기둥 (CIVC) + 사례 |
| Part 2 (Ch 4~7) | AGENTS.md | 표준 + 60줄 황금률 + 모범 패턴 |
| Part 3 (Ch 8~10) | 컨텍스트 | 60-line + Context Rot + JIT 검색 + Lazy Discovery |
| Part 4 (Ch 11~14) | 4 플랫폼 | Claude Code / OpenAI Codex / Cursor / Devin |
| Part 5 (Ch 15~18) | EDD + 멀티에이전트 + 보안 + 비용 | 정량 운영 |
| Part 6 (Ch 19~23) | 실전 + 안티패턴 | 워크숍 + 7 실패 징후 |
| 부록 A/B/C | 템플릿 + 치트시트 + 130+ 소스 | 즉시 활용 자료 |

---

## 4 기둥 — CIVC (Constrain · Inform · Verify · Correct)

> Anthropic 정리. Fowler 4축 (Reasoning Loop · Tools · Memory · Context Mgmt)과 별개.

| 기둥 | 정의 | 우리 구현 |
|------|------|---------|
| **Constrain** | 에이전트가 "할 수 없는 것" 강제 | Hooks 9이벤트 12스크립트 + .githooks/AGENTS.md 금지 |
| **Inform** | 에이전트가 "해야 하는 것" 알림 | CLAUDE.md+분할정본 + Skills 14 + (MCP 미연동) |
| **Verify** | 결과 품질 측정/검증 | Eval 41 task + EDD + sensor-* 12개 + verification skill |
| **Correct** | 잘못된 경로 진입 시 복구 | PreCompact + (loop-detection 미구현) + posttooluse-failure |

**KEY INSIGHT**: 4 기둥은 누적 (모두 갖춰야 함). Constrain만 비대 → 안티패턴 ① 과도한 제약.

---

## Ch 08 — 60-line 황금률 (HumanLayer Kyle 발견)

### 핵심
- 50개 룰 → 절반 무시 / 100개 룰 → 우선순위 상실 / 60줄 초과 → instruction degradation
- Anthropic 권장 = 60줄 / 프론티어 LLM 안정 추종 한도 = 150~200 지시
- Claude Code 시스템 프롬프트 = 약 50 지시 → AGENTS.md에 100~150 여유

### ProjectGrimoire 적용 (2026-04-30 #10)
| 파일 | 줄수 | 영역 |
|------|------|------|
| CLAUDE.md | 73 | 절대규정 §0 + pointer |
| .claude/AGENTS.md | 126 | 하네스 (메모리 + 멀티에이전트) |
| docs/AGENTS.md | 195 | 문서 (동기화 + 피라미드 + 전수검사) |
| .githooks/AGENTS.md | 142 | Git/CI |

운영 데이터: instruction-degradation 회귀 0건 (4-30 신설 이후 지속 PASS).

---

## Ch 15 — Eval-Driven Development (EDD)

### EDD 6 단계
1. **실패 수집** (20~50 task, Anthropic 권장)
2. **평가 기준 정의** (확률적 임계값 분류)
3. **자동 실행 환경** (eval-runner.sh)
4. **채점** (코드 결정론 / LLM 정성적 / 혼합)
5. **기준선 측정** (20×10=200회 = 카테고리별 통과율)
6. **반복 개선** (가장 통과율 낮은 카테고리부터, CLAUDE.md 3줄로 60→80% 사례)

### 우리 적용
- regression 38 task / 30일 평균 97%+ / 100% PASS 유지
- EDD 41 task / 39 PASS / 95.12% (tasks-edd/ 의도된 갭 분리)
- LLM-as-Judge 가드 ₩2K/일 ₩50K/월 박제 (실제 SDK 보류)
- sensor-eval-trend (30일 mean / 7일 slope / 회귀 빈도)

### 책 권장 점수 가중치 (TaskFlow 5차원)
**기능 정확성 40 + 코드 품질 20 + 성능 15 + 보안 15 + UX 10** = 100
> 우리 PASS/FAIL 이분법 → 점수 분포 추적으로 진화 가치 (P0 후보)

---

## Ch 16 — 멀티 에이전트 + Shared Contracts

### 5 오케스트레이션 패턴 (책 정본)
| 패턴 | 에이전트 수 | 비용 | 적합 |
|------|-----------|-----|------|
| 싱글 (기준선) | 1 | 낮음 | 단일 기능, 버그 수정 |
| 서브에이전트 (계층) | 2~5 | 중간 | 탐색+구현 — 부모 Opus + 자식 Sonnet |
| 멀티 (병렬) | 2~N | 높음 | 대규모 마이그레이션 — Git 워크트리 필수 |
| Plan-and-Execute | 2~3 | 중간 | 장기 실행 — Sprint 계약 |
| **Ralph Loop** | 1+훅 | 가변 | 무한 반복 (장기 실행, 종료 가로채 재주입) |

> "단순한 패턴에서 시작 → 측정 후에만 복잡도 증가" (책 강조)

### 충돌 3 유형 → 해결 (책 정본)
| 충돌 | 원인 | 해결 | 핵심 |
|------|-----|------|------|
| 동시 파일 편집 | 같은 파일 다중 수정 | Git 워크트리 + 순차 머지 | 물리적 격리 |
| 의사결정 전파 누락 | 인터페이스 불일치 | **shared-contracts.md** | 명시적 계약 |
| 비용 폭주 | 무한 루프 / 비효율 | 에이전트별 예산 + 에스컬레이션 | 역할별 한도 |

> 책에서 **`shared-contracts.md` 파일명 그대로 명시** — 우리 4-30 박제와 정확히 동일!

### Anthropic 3-에이전트 시스템 (Prithvi Rajasekaran)
**Initializer → Generator → Evaluator** (Sprint 계약)
- Initializer: 1회 (뼈대 + progress.md)
- Generator: 반복 (progress.md 읽고 미완 기능 구현 후 갱신)
- Evaluator: Playwright E2E 검증 + Sprint 계약 채점

### 에이전트별 예산 할당 (책 정본 패턴)
```python
AGENT_BUDGETS = {
    "frontend": {"max_tokens": 500K, "max_tool_calls": 100, "max_wall_time": 1800, "max_retries": 3},
    "backend":  {"max_tokens": 800K, "max_tool_calls": 150, "max_wall_time": 2700, "max_retries": 3},
    "evaluator":{"max_tokens": 300K, "max_tool_calls": 50,  "max_wall_time": 900,  "max_retries": 1},
}
```
> 우리 7 에이전트 미적용 — **NEW P0 후보**

### shared-contracts.md 10 인터페이스 (2026-04-30 #10)
1. PLANNER_REPORT / 2. COST_AUDIT_REPORT / 3. VISUAL_CANON_REPORT / 4. DEV_REPORT / 5. QA_REPORT / 6. AskOptions / 7. ANALYSIS_CREDIT_COST=4 / 8. Eval task 형식 / 9. LLM-Judge 가드 / 10. PostToolUseFailure 정책

---

## Ch 17 — 보안 (OpenDev 5계층 방어)

| Layer | 방법 | 우리 구현 |
|-------|------|---------|
| 1. Prompt | 시스템 프롬프트 금지 | CLAUDE.md §0 ZERO-TOLERANCE |
| 2. Schema | 도구 스키마 제한 | Plan/Execute 이중 모드 (부분 적용) |
| 3. Runtime | 퍼미션 (Manual→Semi→Auto) | settings.json (Semi-Auto) |
| 4. Tool | 명령어 블랙리스트 + 경로 제한 | posttooluse-failure-handler (force push 차단) |
| 5. Hooks | 라이프사이클 정책 | 9 이벤트 12 스크립트 |

### 보안 체크리스트 8 — 우리 충족 7/8
| # | 항목 | 우리 |
|---|------|------|
| 1 | 퍼미션 시스템 활성화 | ✅ settings.json |
| 2 | 네트워크 도메인 제한 | ⚠️ 부분 |
| 3 | 시크릿 출력 차단 | ✅ sensor-secret-leak |
| 4 | **AI 코드 정적 분석 (Snyk/Semgrep)** | ❌ **NEW P0** |
| 5 | 파일 경로 제한 | ✅ Hooks |
| 6 | 위험 명령어 블랙리스트 | ✅ posttooluse |
| 7 | 도구 호출 로깅 | ✅ sensor-log |
| 8 | Diff/토큰/비용 감사 로깅 | ⚠️ 부분 (cost-tracker 미구현) |

### 샌드박스 3단계
마이크로VM (Firecracker / 최강) > gVisor (강) > 강화 컨테이너 (중간 — 우리 로컬 환경 적합)

---

## Ch 18 — 비용 관리

### 토큰 경제학
| 모델 | 입력 (MTok) | 출력 (MTok) | 캐시 읽기 | 비고 |
|------|------------|------------|----------|------|
| Opus 4.6 | $15 | $75 | $1.50 | 1x (계획) |
| Sonnet 4.6 | $3 | $15 | $0.30 | 0.2x (구현) |
| Haiku 4.5 | $0.80 | $4 | $0.08 | 0.05x (단순) |

### 3단계 모델 라우팅 (책 권장: 40~60% 절감)
- **Opus (30%)**: 아키텍처, 복잡 디버깅
- **Sonnet (50%)**: 기능 구현, 테스트
- **Haiku (20%)**: 포맷팅, 단순 변환

> 우리 미적용 (J5 보류 결정) — **재검토 가치 NEW**

### Reasoning Sandwich (LangChain TerminalBench 2.0 패턴)
계획 = 高추론 / 구현 = 표준 / 검증 = 高추론

### 비용 절감 5기법
1. 컨텍스트 효율 도구 설계 (응답 25K 토큰 이하)
2. **Lazy Discovery** (MCP 도구 스키마 필요시만)
3. 짧은 피드백 루프 (긴 프롬프트 1회 < 짧은 N회)
4. **태스크별 토큰 예산** (버그 50K / 기능 200K / 리팩토링 500K)
5. **이터레이션 캡** (둠 루프 방지)

### Anthropic 비용 데이터
- $9 (실패) < $124.70 (균형) < $200 (완성). $9짜리 실패 = 가치 0

### cost_tracker.py 패턴 (책 정본)
호출별 JSONL: `{ts, task_id, model, input_tokens, output_tokens, cache_tokens, cost_usd}`
> 우리 sensor-cost-table.sh 있지만 호출별 추적 미구현 — **NEW P0**

---

## Ch 21 — 4 기둥 통합 (TaskFlow 최종 완성)

| 기둥 | 책 권장 구현 | 우리 구현 | 갭 |
|------|------------|---------|------|
| **Inform** | AGENTS.md + Skills + **MCP** | CLAUDE.md+분할 + Skills 14 | **MCP 미연동** |
| **Constrain** | Hooks + 퍼미션 Semi-Auto | Hooks 9이벤트 + settings.json | 퍼미션 정책 미정의 |
| **Verify** | Eval + Self-check + 서브에이전트 | Eval 41 + verification skill | 서브에이전트 탐색 패턴 미적용 |
| **Correct** | 루프 탐지 + 컨텍스트 컴팩션 | (없음) + PreCompact | **MAX_EDITS_PER_FILE=5 임계 미박제** |

POINT (책 정본): **"Foundation Model = CPU, 하네스 = OS" (Philipp Schmid)**

---

## Ch 23 — 실패 7가지 징후 + 하네스 자가진단 (가장 중요)

### 설계 안티패턴 4
1. **과도한 제약**: Constrain만 비대 → 작업 시간 절반이 승인 대기
2. **규칙 폭발**: 500줄 AGENTS.md → 규칙 간 충돌
3. **Eval 부재**: 감으로 수정 → 6개월 뒤 추적 불가
4. **모델 의존 착각**: "다음 모델 나오면 해결" → 실제로는 하네스 차이가 28계단

### 운영 안티패턴 3
5. **하네스 부패**: 문서 ↔ 코드 괴리 → "쓰레기 수거(garbage collection)" 필요
6. **비용 블랙홀**: 어디서 새는지 모름 → 최적화 불가
7. **거버넌스 부재**: CLAUDE.md 누가 수정해도 OK → 무책임

### 자가진단 7질문 (3 이상 "아니오"면 쇠퇴 경로)
| # | 질문 | 우리 sensor | 상태 |
|---|------|-----------|------|
| 1 | 작업 시간 70%+ 실제 구현? | sensor-orchestration-ratio | ✅ |
| 2 | CLAUDE.md ≤100줄? | sensor-claude-md-size | ✅ (73줄) |
| 3 | 하네스 수정 효과 수치 증명? | sensor-eval-trend | ✅ |
| 4 | 모델 개선 여지 측정? | — | ❌ **NEW** |
| 5 | CLAUDE.md ↔ 코드 일치? | sensor-doc-drift | ✅ |
| 6 | 태스크 유형별 비용 인지? | — | ❌ **NEW** (cost-tracker) |
| 7 | 하네스 변경 리뷰 프로세스? | sensor-shared-contracts | ⚠️ |

**최우선 해결**: ③ Eval → ⑤ 부패 → 나머지

> POINT: "하네스는 코드보다 빠르게 썩는다. CI/CD가 필요한 것처럼 하네스에도 지속 검증이 필요하다."
> "하네스는 정원과 같다. 심는 것보다 가꾸는 데 더 많은 시간이 든다."

---

## Ch 11~14 — 4 플랫폼 비교 (우리 = Claude Code)

| 플랫폼 | 격리 | Inform | Constrain | 차별점 |
|--------|-----|--------|-----------|--------|
| **Claude Code** | 강화 컨테이너 | CLAUDE.md + Skills + MCP | Hooks 라이프사이클 | 가장 유연 (우리 선택) |
| OpenAI Codex | **Firecracker μVM** | AGENTS.md | App Server JSON-RPC | 최강 보안 |
| Cursor | 워크스페이스 | **MDC Rules (.cursor/rules/ 경로별)** + 모델별 튜닝 | BugBot (Verify+Correct 통합) | UI 가장 친숙 |
| Devin | **Brain (stateless) + Workspace** 분리 | 계획-실행 명시 분리 | Devin 2.0 ACU 83% 효율 | 엔터프라이즈 (Infosys Topaz) |

> "보안 우선 → Codex/Devin / 유연성 우선 → Claude Code/Cursor / **AGENTS.md는 모두 필수**"

---

## 부록 핵심 — 즉시 적용 자료

### 부록 A — 8 시스템 프롬프트 패턴
역할 정의 / 단계 추론 / 금지 목록 / 출력 형식 / 컨텍스트 주입 / **에러 복구 (3회 이상 같은 에러 → 사용자 에스컬레이션)** / 품질 게이트 / 보안 가드레일

### 부록 B — 신개념 용어
- **Build-to-Delete**: 모델 발전에 따라 불필요해질 스캐폴딩을 의도적으로 경량 설계 (예: Ch 18 비용 절감 연동)
- **컨텍스트 방화벽**: 서브에이전트가 부모 컨텍스트 오염 차단
- **둠 루프**: 같은 파일 5회 이상 편집 (LoopDetectionMiddleware 임계)
- **Ralph Loop**: Hook으로 종료 가로채 새 컨텍스트 재주입 (장기 실행 작업)
- **컨텍스트 컴팩션 5단계**: 요약 → 절삭 → 버킷팅 → 압축 → 퇴출

### 부록 C — 130+ 소스 (정본)
- F01 Mitchell Hashimoto "My AI Adoption Journey" (Feb 5, 2026 — 용어 명명자)
- F02 OpenAI "Harness Engineering: Codex" (Feb 2026)
- F03 Birgitta Bockeler / **Martin Fowler** "Harness Engineering" (Feb 17, 2026 — 4축 정의)
- F04~F10 Anthropic Building Effective Agents / Context Engineering / MCP 등
- L01~L06 LangChain (Deep Agents / Anatomy / TerminalBench 2.0)
- I01 **Philipp Schmid "The Importance of Agent Harness in 2026"** (Foundation = CPU, Harness = OS)

---

## 솔로 개발자 영감 — Cuneiform Chat (Bikash Das, 책 인용)

> 4개월 동안 혼자서 6마이크로서비스 + 2프론트엔드 + 7채널 (Telegram/WhatsApp/Discord/Slack/웹 위젯)
> Claude Code + `.claude/` 30 참조 문서 + CLAUDE.md = "인덱스 및 결정 라우터"

**우리 패턴과 정확히 동일**. 차별 강조 규칙 예시 (책 인용):
> "모든 데이터베이스 쿼리는 반드시 org_id 필터 포함" — 멀티테넌트 SaaS 치명적 버그를 CLAUDE.md 한 줄로 차단

→ 우리 ProjectGrimoire의 author_content 절대 수정 금지 / 작가 본문 보호 패턴과 같은 철학

**솔로 개발자 3 원칙 (책 정본)**:
1. CLAUDE.md = "팀의 기억" 대체
2. .claude/ = 사내 위키 대체 (구조화 데이터)
3. **1일차부터 옵저버빌리티** (체감 vs 실제 39% 괴리 — METR 연구)

---

## 우리 시스템 검증 — 95% 정합 / 5% 갭

### ✅ 정합 (책 권장 그대로 적용)
1. shared-contracts.md (책 정본 파일명 동일!)
2. 60-line 황금률 4 분할
3. EDD 38 task + sensor-eval-trend
4. Hooks 9이벤트 12스크립트
5. Skills 14 (Progressive Disclosure)
6. PreCompact memory guard
7. Sprint 계약 (Plan/QA agent로 부분 적용)
8. .claude/ 디렉토리 = 사내 위키 패턴 (Cuneiform Chat 동일)
9. CLAUDE.md = 인덱스 및 결정 라우터

### ❌ 미적용 (NEW P0 후보)
1. **MCP 연동** (Inform 3층 中 미완) — Figma MCP / GitHub MCP / Playwright MCP 등
2. **에이전트별 모델 티어링** (J5 보류 결정 — 책 강력 권장 40~60% 절감)
3. **에이전트별 예산 할당** (max_tokens/max_tool_calls/max_wall_time)
4. **cost-tracker.jsonl** (호출별 task_id/model/tokens/cost — 비용 블랙홀 방어)
5. **sensor-loop-detection** (MAX_EDITS_PER_FILE=5 둠 루프 방지)
6. **sensor-harness-self-diagnose** (자가진단 7질문 자동화 — 매주 ALERT)
7. **Hooks에 Semgrep/Snyk 통합** (AI 코드 정적 분석)
8. **Eval 점수 가중치 도입** (이분법 PASS/FAIL → 0~100 점수 분포)
9. **컨텍스트 토큰 예산 sensor** (시스템 프롬프트 + CLAUDE.md + 누적 대화)
10. **5 오케스트레이션 박제** (현재 .claude/AGENTS.md §2.2.1 위임 매트릭스 → 5 패턴 표 추가)

---

## 변경 이력
- 2026-04-30 #10: 본 파일 신설 — 책 Ch 08/15/16 핵심 박제
- 2026-05-02 묶음 K L2: 운영 데이터 + 보류 챕터 박제
- **2026-05-01 #10_5: 책 전체 학습 완료 후 전면 갱신 (Ch 1~23 + 부록 A/B/C, 206 페이지)**. CIVC 4 기둥 + 5 오케스트레이션 + 7 안티패턴 + 4 플랫폼 비교 + 비용 관리 + 보안 5계층 + Cuneiform Chat 정합 + 95% 정합/5% 갭 NEW P0 10건 도출.
