---
name: red-team-update-propose
description: 자율학습 3단 분리의 α-반자율 단계 — pending.jsonl 데이터 자가 검증 + Constitution/Sensor 갱신 propose. 사용자 승인 게이트(.claude/proposals/) 거치지 않은 자율 적용 금지. 책 Ch 23 거버넌스 부재 안티패턴 #7 방어.
allowed-tools: Read, Write, Bash, Grep, WebFetch
disable-model-invocation: true
effort: high
trigger-mode: user-invocation (disable-model-invocation:true) — 사용자 명시 호출만
---

> **2026-05-06 묶음 PP-3 ARCHIVE**: 30일간 자율 호출 0회 + disable-model-invocation: true + 비상 가치 낮음. 비상 시 `.claude/skills/_archive/red-team-update-propose/SKILL.md` 직접 Read 또는 사용자 명시 호출.

# Red-Team Update Propose — 자율학습 α-반자율 단계 (사용자 승인 게이트)

> **trigger-mode**: user-invocation (disable-model-invocation:true). 사용자 `/red-team-update-propose` 명시 호출만.
> **신설**: 2026-05-02 #10_6 묶음 Z (Phase ε-2) — 사용자 추가 요구 (자율학습 + 자기-업그레이드)
> **빈도 캡**: 일주일 1회 또는 사용자 트리거 시만 (책 Ch 18 비용 + Ch 23 안티패턴 #4 방어)

## 목적

자율학습 3단 분리의 **α-반자율 단계**:
1. **α-자율 (수집)**: `red-team-data-collector.sh add <URL> <topic>` — pending.jsonl 박제 (별도)
2. **α-반자율 (Propose) — 본 skill**: 메인 Claude가 pending → WebFetch → propose 박제
3. **사용자 승인 게이트**: `.claude/proposals/red-team-update-{date}.md` 사용자 명시 승인 시만 적용

**근거**: 책 Ch 23 안티패턴 #7 거버넌스 부재 방어 + §0 정책·PRD 강제 종속. 100% 자율 자기-수정은 산업 사례 없음.

---

## 호출 조건

다음 중 1개 이상 (사용자 명시):
1. **사용자 명시 호출**: `/red-team-update-propose`
2. **adversarial sensor 신규 위반 패턴 발견 시**: 사용자가 학습 위탁
3. **빈도 캡 도달 시**: 일주일 1회 자동 (단, 사용자 사전 동의 후만)

---

## 절차 (5 단계)

### Step 1. pending.jsonl Read
```bash
bash .claude/scripts/red-team-data-collector.sh latest 10
```
최근 10건 pending 데이터 확인. 0건이면 종료 (수집 단계 선행 필요).

### Step 2. WebFetch (whitelist 정합 검증)
각 pending URL에 대해:
1. `bash .claude/scripts/sensor-red-team-source-whitelist.sh <URL>` (재검증)
2. WebFetch 호출 (Claude Code 기본 도구, 외부 API 0)
3. 응답을 적절한 prompt로 분석:
   - "이 자료에서 ProjectGrimoire red-team-constitution.md 16 principles에 추가하거나 갱신할 내용이 있는가?"
   - "이 자료가 sensor-adversarial-pre-commit.sh의 검증 패턴을 강화할 단서를 제공하는가?"

### Step 3. 변경 propose 작성
`.claude/proposals/red-team-update-{YYYYMMDD}.md` 신설:

```markdown
# Red-Team Update Proposal — YYYY-MM-DD

> 작성: {Claude 메인 세션 ID}
> 출처: pending.jsonl 최근 10건 (whitelist 정합)
> 사용자 승인 게이트: 본 proposal Read 후 명시 승인 시만 적용

## 1. red-team-constitution.md 갱신 후보

### Principle [N] — [제목]
- **현재**: [현재 정의]
- **제안**: [신규/갱신 제안]
- **근거**: [출처 URL + 인용 짧게 (15단어 이하)]
- **위험**: [잘못 적용 시 영향]
- **사용자 결정**: [✅ 적용 / ❌ 거절 / ⏸️ 보류]

### Principle [N+1] — [제목]
- ...

## 2. sensor-adversarial-pre-commit.sh 갱신 후보
- 신규 검증 패턴 [P]: [제안]
- 근거: ...

## 3. 위험 평가 (책 Ch 23 안티패턴 검증)
- #4 모델 의존 착각: 본 proposal이 "AI가 알아서 해결"이라는 함정에 빠지지 않았는가?
- #7 거버넌스 부재: 사용자 승인 게이트 거치는가? (✅ 본 proposal은 대기 상태)
- 보안 Layer 1: prompt injection 의심 출처 0건 (whitelist 정합)

## 4. 사용자 결정 영역
- [ ] 본 proposal 적용 (사용자 명시 승인)
- [ ] 부분 적용 (위 §1/§2에서 ✅ 표시 항목만)
- [ ] 거절 (사유 박제)
- [ ] 보류 (다음 세션에서 재검토)
```

### Step 4. 위험 평가 (책 Ch 23 안티패턴 검증)
proposal 작성 후 자기-검증:
- 안티패턴 #4 모델 의존 착각 회피?
- 안티패턴 #7 거버넌스 부재 회피?
- 보안 Layer 1 (prompt injection) 회피?
- §0 ZERO-TOLERANCE 정합?

### Step 5. 사용자에게 보고 + 게이트 대기
proposal 경로 + 핵심 변경 요약을 사용자에게 보고. 사용자 명시 승인 전까지 적용 금지.

---

## 절대 금지 사항

### [MUST NOT] 사용자 승인 없이 constitution / sensor 직접 수정
proposal 박제만. 적용은 사용자 명시 후.

### [MUST NOT] whitelist 외 출처 데이터 사용
sensor-red-team-source-whitelist 차단 영역은 즉시 polluted 데이터로 분류.

### [MUST NOT] 빈도 캡 위반
일주일 1회 또는 사용자 트리거 시만. 매 작업마다 호출 = 책 Ch 23 안티패턴 #4 직격.

### [MUST NOT] 외부 Anthropic API 호출 (사용자 0-1 결정)
WebFetch만 사용 (Claude Code 기본 도구). anthropic SDK / Promptfoo / DeepTeam X.

### [MUST NOT] proposal에 "추정 / 아마 / probably" 표현 사용
§0 ZERO-TOLERANCE — 모든 propose는 출처 인용 + 직접 검증 데이터에 근거.

---

## 사용자 승인 후 적용 절차 (별도 작업)

사용자가 proposal 승인 시 메인 Claude 또는 사용자 직접:
1. `git checkout -b auto-evolve/red-team-{date}` (별도 브랜치, main 직접 X)
2. constitution / sensor 갱신
3. 회귀 검증 (regression + adversarial sensor 자체)
4. **회귀 PASS 시에만** develop 머지 propose
5. develop → main 머지는 사용자 명시 시

**FAIL 시**: proposal 자체 폐기 (`.claude/proposals/{date}.md`에 "거절 — 회귀 FAIL" 박제)

---

## ProjectGrimoire 적용 사례 (예상)

### 좋은 사례
- 사용자가 매주 월요일 본 skill 명시 호출 → 지난 1주 산업 변화 반영 propose → 사용자 검토 후 승인 → 자동 진화

### 나쁜 사례 (예방)
- 매 commit마다 자동 발동 → 비용 폭주 + 거버넌스 부재
- whitelist 외 출처에서 prompt injection 자료 학습 → constitution 오염

---

## 관련 정본
- `.claude/scripts/red-team-data-collector.sh` — α-자율 수집 단계
- `.claude/scripts/sensor-red-team-source-whitelist.sh` — 출처 검증
- `.claude/knowledge/red-team-constitution.md` — 갱신 대상 정본 (16 principles)
- `.claude/scripts/sensor-adversarial-pre-commit.sh` — 갱신 대상 sensor
- `research/HARNESS_ADVERSARIAL_VERIFICATION.md` §5.5 — 자율학습 패턴 평가 (3단 분리 정본)
- 책 V1.1 Ch 23 안티패턴 #4 + #7 — 거버넌스 부재 방어

---

마지막 업데이트: 2026-05-02 #10_6 묶음 Z (Phase ε-2)
승격 원본: 사용자 추가 요구 (자율학습 + 자기-업그레이드) + Q00/ouroboros Evolve + Anthropic Constitutional AI RLAIF + 책 V1.1 Ch 23
적용 영역: ProjectGrimoire 도메인 (한국어 + 외부 API 0 + 사용자 승인 게이트 강제)
