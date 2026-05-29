# Red-Team Constitution — ProjectGrimoire 적대적 검증 16 Principles

> **출처**: Anthropic Constitutional AI 16 principles 패턴 (arxiv 2212.08073) + ProjectGrimoire 도메인 적용
> **사용**: `sensor-adversarial-pre-commit.sh`가 매 commit 직전 16 principles 자동 검증
> **갱신 정책**: 사용자 승인 게이트 (proposals/ 게이트 거치지 않은 자율 갱신 금지 — 책 Ch 23 안티패턴 #7 거버넌스 부재 방어)
> **신설일**: 2026-05-02 #10_6 묶음 W

---

## 절대 규정 (Critical — 위반 시 즉시 차단)

### Principle 1 — §0 ZERO-TOLERANCE (CLAUDE.md §0)
> "전수검사 완료" 보고 후 프로덕션 기초 에러 발견 시 사용자 격노 진입
- **검증**: commit 메시지 + 변경 파일에서 "추정/aim/probably" 패턴 검출 → ALERT
- **검증 sensor**: instructions-drift-check + 본 sensor

### Principle 2 — 사슴악마 시각 정본 (CLAUDE.md §1)
> 모든 시각 렌더링은 deerdevil 작가공간/에피소드 뷰어/에피소드 목록 정본과 일치
- **검증**: grimoire-web 신규 컴포넌트가 antler / typing 패턴 사용 여부
- **검증 task**: eval/tasks/09-deerdevil-visual-canon.json + 25-visual-canon-typing-effect.json

### Principle 3 — 작가 콘텐츠 보호 (CLAUDE.md §0)
> 소설 본문 수정/인용/로깅 절대 금지
- **검증**: parser 코드에서 `block.text =` / `content.toUpperCase` 등 본문 수정 패턴 0건
- **검증 task**: eval/tasks/10-author-content-protection.json + 27-author-content-parser-readonly.json

### Principle 4 — §0 원가 철칙 (PLANNING_GRIMOIRE.md §0)
> 새 AI 기능은 cost-accountant 마진 ≥3배 검증 없이 기획/구현 금지
- **검증**: ai-cost-table.md 모든 안전배수 ≥3.0 (WARN ≥3.5)
- **검증 sensor**: sensor-cost-margin

### Principle 5 — 외부 Anthropic API 보류 (사용자 명시 0-1 결정, 2026-04-30)
> "앤스로픽 외부 api를 쓰는 방향으로의 하네스엔지니어링·에이전트 고도화는 나중 과제로 미루고 싶다"
- **검증**: `from anthropic` / `import anthropic` import 0건 (grade-llm.py stub 유지)
- **검증 sensor**: 본 sensor § Principle 5

---

## 강제 규정 (Strict — 위반 시 차단)

### Principle 6 — shared-contracts 정합 (책 Ch 16)
> 인터페이스 변경 시 shared-contracts.md 먼저 갱신 → 7 에이전트 .md 동기
- **검증 sensor**: sensor-shared-contracts (10 인터페이스 + §4 변경 리뷰)

### Principle 7 — 분할 정본 ≤ 임계 (책 Ch 08 60-line)
> CLAUDE.md ≤80 / .claude/AGENTS.md ≤200 / docs/AGENTS.md ≤300 / .githooks/AGENTS.md ≤200 / 7 에이전트 .md ≤300
- **검증 sensor**: sensor-instruction-degradation

### Principle 8 — Sensor 모두 PASS/WARN
> pre-commit 시점 모든 sensor exit ≤2 (PASS/WARN 허용, FAIL 차단)
- **검증 sensor**: 본 sensor(sensor-adversarial-pre-commit)의 Principle 8 단계가 **9개 핵심 sensor** 일괄 호출 후 FAIL 카운트 (실측 2026-05-29: 스크립트 line 116~124 정합. 이전 박제 "23개"는 코드 미정합 드리프트였음 — `reports/HARNESS_HONESTY_AUDIT_20260529.md` §C-2)

### Principle 9 — Stop hook 메모리 절대 규칙 (.claude/AGENTS.md §1)
> 세션 종료 전 project_session_*.md + MEMORY.md 인덱스 갱신
- **검증 hook**: stop-memory-guard

### Principle 10 — 한국어 존댓말 (memory/feedback_polite_korean.md)
> 모든 응답 한국어 존댓말 (반말 금지)
- **검증**: commit 메시지 한국어 패턴 (memory/feedback 박제 정합)

---

## Git/CI 규정

### Principle 11 — Git main 직접 commit 금지 (.githooks/AGENTS.md §1)
> develop → main 머지는 사용자 명시 시만
- **검증 sensor**: post-edit-tsc + pre-commit hook 자체

### Principle 12 — Pre-push hook 우회 금지 (.githooks/AGENTS.md §2)
> --no-verify 사용 시 사용자 명시 승인 필수
- **검증**: git config alias 검증

---

## 보안 규정

### Principle 13 — 시크릿 평문 금지 (CLAUDE.md §0)
> API 키/JWT/DB 비밀번호 하드코딩 차단
- **검증 sensor**: sensor-secret-leak

### Principle 14 — BFF 프록시 강제 (CLAUDE.md §1)
> 클라이언트 컴포넌트는 /api/... 만, 백엔드 URL 직접 노출 금지
- **검증 task**: eval/tasks/07-bff-proxy-required.json

### Principle 15 — HttpOnly Cookie 강제 (CLAUDE.md §0)
> localStorage에 토큰 저장 금지
- **검증 task**: eval/tasks/08-httponly-cookie.json

### Principle 16 — 결제 원자성 (PLANNING + grimoire-server SECURITY.md §3)
> 돈이 오가는 로직 단일 DB transaction (Payment + Author + CreditLog)
- **검증 sensor**: sensor-credit-atomicity

---

## OWASP LLM Top 10 적용 (2026-05-03 묶음 CC, BB proposal §10-1 적용)

### Principle 17 — LLM Prompt Injection 방어 (OWASP LLM01)
> 사용자 입력에 prompt injection 의심 패턴 자동 검증
- **검증**: sensor-adversarial-pre-commit이 grimoire-server controller에 prompt injection 휴리스틱 grep
  - 검출 패턴: "ignore previous", "system prompt", "you are now", "</prompt>"
  - controller 보강 자체는 grimoire-server 레포 영역 (사용자 결정, P17 sensor만 자율)
- **근거**: OWASP LLM Top 10 #1 — "Prompt Injection이 LLM 응용 최우선 위협"

### Principle 18 — LLM Output Encoding (OWASP LLM02)
> LLM 응답을 Next.js 렌더링 전 검증 — dangerouslySetInnerHTML 사용 0건 강제
- **검증**: grimoire-web에서 `dangerouslySetInnerHTML.*ai|llm|claude` grep → 0건
- **현재 정합**: 이미 0건 (명시 박제로 회귀 차단)
- **근거**: OWASP LLM Top 10 #2 — "Insecure Output Handling이 downstream security exploits 야기"

### Principle 19 — Sensitive Info Disclosure 강화 (OWASP LLM06)
> 환경변수 노출 / DB 스키마 정보 노출 / 사용자 PII 마스킹 검증
- **검증**: sensor-adversarial-pre-commit가 env/DB/PII 정규식 검출
  - process.env 직접 응답 노출
  - prisma findMany 직접 응답 노출
  - email/phone/address 응답 평문
- **근거**: OWASP LLM Top 10 #6 — "Sensitive Information Disclosure 방지를 위한 데이터 분류 + 마스킹"

---

## 박제 의무 규정 (2026-05-06 사용자 명시 — Mitchell Ghostty + Cuneiform Chat 패턴)

### Principle 20 — incident-log 박제 의무 (Mitchell Hashimoto Ghostty 패턴)
> 사용자 명시 (2026-05-06): "앞으로 모든 실수, 그게 툴이면 툴, 에이전트면 에이전트, 문서 누락이면 누락에, 실수가 발견된거든, 실수를 우회한 거든, 내가 지금처럼 발견한 거든 하나도 빼놓지 말고 나올 때마다 주제별로 다 기록해"
- **검증 sensor**: sensor-adversarial-pre-commit P20 (오늘 commit 있는데 incident 박제 0건이면 WARN)
- **박제 도구**: `bash .claude/scripts/incident-log.sh <category> <severity> <source> <description>`
- **카테고리**: tool / agent / sensor / hook / skill / doc / infra / response / workflow / security
- **severity**: info / warn / error / critical
- **source**: user / sensor / self / remote
- **출처**:
  - Mitchell Hashimoto Ghostty: "실수마다 규칙 1줄"
  - Cuneiform Chat (Bikash Das): "팀의 기억"
  - 책 V1.1 Ch 23 안티패턴 #5 "하네스 부패" 방어
  - Anthropic Constitutional AI 자기-비판 루프 결과 박제

---

## 레드팀 운영 절대규정 5조 (2026-05-29 사용자 명시 — 정직성 사태 후속)

> **배경**: 2026-05-29 하네스 정직성 사태 — 이전 세션들이 "sensor PASS / 가드 통과"로 보고했으나 실측 결과 fire/reject 실적 raw 0건(효과 입증 0)으로 드러남 (`reports/HARNESS_HONESTY_AUDIT_20260529.md`). 사용자가 레드팀 운영을 절대규정으로 박제 명시.
> **원문 보존**: 사용자 발화 그대로(아래 1~5). 가공·축약 금지.

1. **전수 참조**: 레드팀은 유닛테스트 + `.claude/agents` + `.claude/skills` 모든 내용을 다 참조한다.
2. **실패 시 차단**: 유닛테스트 실패 / 컴파일 에러 시 절대 커밋·푸시 불가.
3. **커밋 직전 강제**: 커밋 직전에 반드시 레드팀을 돌린다.
4. **동반 확장**: 새 실수기록(incident)·유닛테스트 추가 시 레드팀도 그에 맞춰 항목 추가.
5. **상위 기준선**: 레드팀 스트레스테스트 기준선은 유닛테스트·실수기록보다 **더 높게** — 더 엄격한 절차로 매 커밋 직전 감사.

> **거품 방지 정직 병기 (정직성 사태 핵심 교훈)**: 위 5조는 **목표 규정**이다. 박제 = 규정 명시이지 효과 보장이 아니다. 현 시점(2026-05-29) 구현 충족도는 미달 항목이 존재한다 — 예: 1조의 `.claude/agents`·`.claude/skills` 전수 참조는 현재 `sensor-adversarial-pre-commit.sh`에 미구현(본체 grep 0건). **각 조의 실제 충족 여부는 grimoire-verifier가 변경 0 상태로 독립 실측해 raw 근거(exit code / grep 카운트 / 파일 존재)로 판정한다.** "박제했으므로 지켜진다"는 추정 금지.

---

## 적용 방식 (책 Ch 17 Constitutional AI 자기-비판 패턴)

각 commit 직전 본 sensor가 16 principles 자동 검증:
1. principle 1~16 순차 검증
2. 위반 1건이라도 발견 시 commit 차단 (exit 1)
3. 모두 PASS 시 commit 허용 (exit 0)

자기-비판 (Constitutional AI 패턴) — Claude 메인 세션 자체 호출:
> "Critique the previous commit using principle: [principle N]. Then revise."

---

## 변경 이력
- 2026-05-02 #10_6 묶음 W: 본 파일 신설 (Constitutional AI 16 principles + ProjectGrimoire 정책 통합)
- **갱신 정책**: 사용자 승인 게이트 (proposals/ 거치지 않은 자율 갱신 금지)
