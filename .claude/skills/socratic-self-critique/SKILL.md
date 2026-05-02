---
name: socratic-self-critique
description: 작업 완료 선언 직전 메인 Claude가 자기 자신에게 7~10 Socratic 질문을 자동 발동. 우로보로스(Q00/ouroboros) Two-diamond 패턴 + Constitutional AI self-critique 차용. "Why? Necessary? Hidden assumption? What if fails?" 등 메타 질문으로 hidden assumption 노출 + 정책 위반 자가 검출. 외부 API 0 (Claude Code 메인 세션 자체 호출만).
allowed-tools: Read, Grep, Bash
disable-model-invocation: true
effort: medium
trigger-mode: keyword (triggers field) — paths 미적용 (verification-before-completion + adversarial sensor 연계)
triggers:
  - "완료했습니다"
  - "끝났습니다"
  - "전부 통과"
  - "PASS"
  - "배포 완료"
  - "수정 완료"
  - "작업 종료"
  - "self-critique"
  - "소크라테스"
  - "Socratic"
---

# Socratic Self-Critique — 우로보로스 Two-diamond 자기-심문

> **trigger-mode**: keyword (triggers field 완료 선언 키워드 + 사용자 명시 호출). paths 미적용 — 메타 검증, 모든 도메인 적용.
> **신설**: 2026-05-02 #10_6 묶음 X (Phase β) — 사용자 지시 (우로보로스 정본 적용)

## 목적

작업 완료 선언 직전 **메인 Claude가 자기 자신에게 7~10 Socratic 질문을 자동 발동** → hidden assumption 노출 + Constitution 위반 자가 검출 → 회귀 차단.

**근거 (책 V1.1 + 산업 정본)**:
- **우로보로스 Q00/ouroboros**: Two-diamond Socratic ("Why? Necessary? — Ambiguity ≤ 0.2")
- **Constitutional AI** (Anthropic): "Critique using principle [N]. Then revise."
- **verification-before-completion** skill (이미 보유): 실측 증거 강제
- **production-bug-triage** skill: 추정 금지

**외부 API 0**: Claude Code 메인 세션 자체에서 자기-호출. anthropic SDK / WebFetch 호출 없음.

---

## 발동 조건

다음 중 1개 이상:
1. **트리거 키워드 매칭** (위 frontmatter triggers 10개)
2. **adversarial sensor WARN/FAIL 감지** (sensor-adversarial-pre-commit exit 1+)
3. **사용자 명시 호출** (`/socratic-self-critique`)
4. **verification-before-completion skill 후속** (실측 증거 첨부 후 메타 질문)

---

## 우로보로스 Two-diamond 패턴 (Q00/ouroboros 차용)

### Diamond 1 — Socratic (질문 다이버전스 → ontological clarity)

**목적**: hidden assumption 노출 + 모호성 ≤ 0.2 도달

작업 완료 선언 전 **자기 자신에게 7 질문**:

#### Q1. Why do you want this? (목적 검증)
- 본 작업이 진짜 필요했는가?
- 사용자가 명시적으로 요청했는가, 아니면 내가 propose했는가?
- 사용자 지시와 일치하는가?

#### Q2. Is that truly necessary? (필요성 검증)
- 더 단순한 대안이 있는가?
- 기존 sensor/skill 활용으로 가능했는가?
- 새 파일 신설이 정말 필요한가?

#### Q3. What hidden assumption are you making? (가정 노출)
- "당연히 작동할 것"이라고 가정한 영역은?
- 검증되지 않은 외부 의존성?
- 환경 차이 (dev vs prod) 무시?

#### Q4. What if this fails? (실패 시나리오)
- 1차 실패 시 어떻게 회복하는가?
- 영구 차단되는 영역은?
- bounded retry가 적용되는가?

#### Q5. Who else is affected? (영향 범위)
- 다른 sensor/skill이 깨질 가능성?
- 7 에이전트 .md 갱신 필요?
- shared-contracts 변경 동반?

#### Q6. Have you violated §0 or red-team-constitution? (정책 검증)
- §0 ZERO-TOLERANCE 준수?
- 사슴악마 시각 정본 준수?
- 작가 콘텐츠 보호 준수?
- 외부 Anthropic API 보류 (사용자 0-1 결정) 준수?
- 16 principles 모두 PASS인가?

#### Q7. Is there a simpler way? (단순화 가능성)
- 책 Ch 23 안티패턴 ① "과도한 제약" 위반 없나?
- 책 Ch 23 안티패턴 ② "규칙 폭발" 위반 없나?
- 코드 줄수 / 복잡도 정당한가?

### Diamond 2 — Pragmatic (옵션 다이버전스 → verified delivery)

**목적**: 실측 증거 + 회귀 검증 도달

#### Q8. Have you measured? (실측)
- 회귀 (Regression eval) 실행했는가?
- drift sensor exit 0인가?
- 영향 영역 모두 sensor PASS인가?

#### Q9. Have you committed? (박제)
- 변경 파일 모두 git add 했는가?
- commit 메시지에 사유 박제 했는가?
- 다음 세션이 이해할 수 있는 메시지인가?

#### Q10. Have you updated memory? (다음 세션 인계)
- project_session_*.md 갱신?
- MEMORY.md 인덱스 추가?
- HANDOVER 갱신 (큰 작업의 경우)?

---

## 자기-비판 출력 형식 (Constitutional AI 패턴)

작업 완료 선언 직전 다음 마크다운 출력:

```markdown
## Socratic Self-Critique (자기-심문)

### Diamond 1 — Socratic
- Q1 Why?: [답변]
- Q2 Necessary?: [답변]
- Q3 Hidden assumption?: [답변]
- Q4 What if fails?: [답변]
- Q5 Who affected?: [답변]
- Q6 Constitution PASS?: [답변, 16 principles 검증 결과]
- Q7 Simpler?: [답변]

### Diamond 2 — Pragmatic
- Q8 Measured?: [실측 데이터 인용]
- Q9 Committed?: [git status / commit hash]
- Q10 Memory updated?: [memory file 경로]

### Ambiguity Score
- 7/10+ 답변에 "확실" 표명 → Ambiguity ≤ 0.3 → 완료 가능
- 답변에 "추정/아마/probably" 1건이라도 → Ambiguity > 0.5 → 재검증 필수

### 위반 발견 시 (Constitutional AI 패턴)
- 위반 principle [N] 박제 → "Critique using principle [N]. Then revise."
- revise 후 재발동 → 모두 PASS 시에만 완료 선언
```

---

## ProjectGrimoire 적용 사례

### 좋은 사례 (예상)
- **묶음 R~V' (#10_6 자율 진행)**: 4 묶음 마무리 직전 self-critique 자동 발동
  - Q3 Hidden assumption: "sensor-server flaky는 환경 일시적 문제로 추정" → Q6 §0 추정 금지 위반 검출 → 직접 명령 검증으로 revise
  - Q8 Measured: regression 47/47 PASS 인용

### 나쁜 사례 (예방)
- **#10_4 sensor-server FAIL 검출 시점**: self-critique 없이 일회성 추정 → 사용자 격노 위험
- **#10_2 분할 작업 마무리**: drift 1건 누락 → MEMORY.md 인덱스 박제 누락 위험

---

## 절대 금지 사항

### [MUST NOT] 7+ 답변에 "확실" 표명 없이 완료 선언
Ambiguity > 0.3 = 재검증 강제. 추정 보고는 §0 ZERO-TOLERANCE 위반.

### [MUST NOT] 위반 principle 발견 후 revise 없이 완료
Constitutional AI 패턴 — critique → revise 루프 강제.

### [MUST NOT] verification-before-completion skill 우회
실측 증거 3종 (테스트/빌드/기능 동작) 첨부 후에만 본 skill 발동.

### [MUST NOT] 외부 API 호출 (사용자 0-1 결정)
self-critique는 메인 Claude 자체. anthropic SDK / WebFetch 호출 금지.

---

## 관련 정본
- `.claude/knowledge/red-team-constitution.md` — 16 principles (Q6 검증 정본)
- `.claude/scripts/sensor-adversarial-pre-commit.sh` — adversarial sensor (자동 트리거)
- `.claude/skills/verification-before-completion/SKILL.md` — 실측 증거 강제 (선행 skill)
- `research/HARNESS_ADVERSARIAL_VERIFICATION.md` §1-1 — Ouroboros Two-diamond 정본
- 책 V1.1 Ch 23 자가진단 7질문 — 본 skill 사상 동일

---

## 빈도 권장
- **자동 발동**: 트리거 키워드 매칭 시 (1일 1~5회 예상)
- **명시 호출**: 사용자 `/socratic-self-critique` (큰 작업 마무리 시)
- **adversarial sensor 연계**: WARN/FAIL 감지 시 자동 (pre-commit hook)

---

마지막 업데이트: 2026-05-02 #10_6 묶음 X (Phase β)
승격 원본: Q00/ouroboros (Socratic) + Anthropic Constitutional AI (self-critique loop) + 책 V1.1 Ch 23
적용 영역: ProjectGrimoire 도메인 (한국어 + 16 principles + verification-before-completion 연계)
