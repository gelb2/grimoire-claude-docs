---
name: feedback-to-skill
description: memory/feedback_*.md 중 영향력이 커진(N회 이상 참조) 후보를 skill로 승격하는 자동 절차. sensor-feedback-promotion이 후보 식별 → 본 skill이 draft skill 작성 → 사용자 confirm 후 정식 .claude/skills/{name}/SKILL.md로 이동. 사용자 명시 호출만 (`/feedback-to-skill <feedback-name>`). HARNESS §8.9 v2 — Memory Session-to-Skill 승격 자동화.
argument-hint: "[필수: feedback 파일명 (예: feedback_polite_korean) | dry-run]"
disable-model-invocation: true
allowed-tools: Read, Bash, Grep, Glob, Write, Edit
effort: medium
paths:
  - "**/memory/feedback_*.md"
  - ".claude/skills/**/SKILL.md"
  - ".claude/scripts/sensor-feedback-promotion.sh"
---

> **2026-05-06 묶음 PP-3 ARCHIVE**: 30일간 자율 호출 0회 + disable-model-invocation: true + 비상 가치 낮음. 비상 시 `.claude/skills/_archive/feedback-to-skill/SKILL.md` 직접 Read 또는 사용자 명시 호출.

# Feedback to Skill — 메모리 승격 자동화

## 동기 (HARNESS §8.9 v2)

ProjectGrimoire는 50+ memory 파일 보유. 그 중 `feedback_*.md`는 사용자가 강조한 원칙. 시간이 지나면 일부 feedback이 다른 정본/메모리/skill에서 N회 이상 참조됨 = "사용자 반복 강조 원칙" → **skill로 승격할 가치**.

자동 승격은 위험 (사용자 의사 확인 필수). 본 skill은 다음 안전망 강제:
- sensor-feedback-promotion이 PROMOTE 후보 식별 (N≥3 + 신규 90일 면제)
- 본 skill은 draft만 작성 (`.claude/skills/.draft-{name}/`)
- 사용자 confirm 명시 후 정식 위치로 이동

## 절차

### Step 1. 모드 + 인자 확인

```bash
ARG="${ARGUMENTS:?feedback 파일명 또는 dry-run 필요}"
case "$ARG" in
  dry-run) MODE="dry-run" ;;
  feedback_*) MODE="convert"; FEEDBACK="$ARG" ;;
  *) echo "Usage: /feedback-to-skill {feedback_name | dry-run}"; exit 1 ;;
esac
```

### Step 2. sensor-feedback-promotion 선행 실행

```bash
bash /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/sensor-feedback-promotion.sh
```

dry-run 모드면 sensor 결과만 출력하고 종료. 사용자가 PROMOTE 후보 보고 다음 호출에서 특정 파일명 인자 줌.

### Step 3. 대상 feedback 검증

- 파일 존재 확인: `/Users/sokol/.claude/projects/.../memory/{FEEDBACK}.md`
- sensor 결과 jsonl에서 해당 파일이 PROMOTE 또는 OBSERVE 카테고리인지 확인
- KEEP 카테고리면 거절 (count 부족) — 사용자 명시 override 시만 진행

### Step 4. Draft skill 생성

`.claude/skills/.draft-{skill-name}/SKILL.md` 생성:

```yaml
---
name: {skill-name}        # feedback_polite_korean → polite-korean-enforcement
description: {feedback 본문 첫 줄 + skill 발동 트리거 의도 명시}
triggers:                  # feedback에서 추론한 키워드 5~10개
  - "{키워드 1}"
  - "{키워드 2}"
allowed-tools: Read, Edit, Bash    # feedback 본질에 따라
draft: true               # 신규 draft 표시
source-feedback: {FEEDBACK}.md
created: {YYYY-MM-DD}
---

# {Skill 제목}

## 동기 (Promoted from {FEEDBACK}.md)

{feedback 본문 + sensor 카운트 + 참조 위치 요약}

## 절차

{feedback 원칙을 절차로 변환}

## 절대 금지 사항

{feedback에 있는 금지 항목}

## 관련 정본
- 원본 메모리: `{FEEDBACK}.md`
- sensor: `sensor-feedback-promotion.sh`
```

### Step 5. 사용자 confirm 절차

draft 작성 후 다음을 stdout 출력:
- draft 위치 + 본문 미리보기
- "다음 명령으로 정식 승격:"
  ```bash
  mv .claude/skills/.draft-{skill-name} .claude/skills/{skill-name}
  ```
- "또는 거절:"
  ```bash
  rm -rf .claude/skills/.draft-{skill-name}
  ```

본 skill은 mv/rm을 직접 수행하지 않음. **사용자가 draft 본문 검토 후 직접 실행**.

### Step 6. 사후 처리 (사용자가 mv 실행 후 별도 호출)

승격 완료 후:
- `feedback_*.md`의 인덱스(MEMORY.md) 항목에 "→ skill로 승격됨 (skill-name)" 명시
- 원본 feedback 파일은 **유지** (역사 보존, gc-sweep 면제 대상)
- AUTOMATION.md §1.5 Skills 인벤토리 갱신
- research/HARNESS_ENGINEERING.md §14.2 Skills 카운트 +1

## 절대 금지 사항

### [MUST NOT] 사용자 confirm 없는 자동 승격
- draft → 정식 위치 mv는 **사용자만** 실행
- 본 skill이 자동 mv 절대 금지

### [MUST NOT] 원본 feedback 파일 삭제
- 승격 후에도 feedback_*.md는 유지 (역사 보존 + gc-sweep 면제)

### [MUST NOT] sensor 결과 무시
- 항상 sensor-feedback-promotion 선행 실행 + 결과 첨부
- "그냥 승격해" 같은 사용자 요청도 sensor 카운트 보고 후 진행

### [MUST NOT] 신규 90일 미만 강제 승격
- sensor가 OBSERVE_NEW로 분류 시 거절 + 사용자에게 "30일 더 관찰 권장" 명시

## 적용 사례 후보 (2026-04-26 sensor 첫 실행 결과)

### OBSERVE_NEW (90일 후 PROMOTE 가능 — 5회 참조)
- `feedback_docker_credstore.md` — Docker credsStore TCC 처리 (이미 macos-tcc-handling skill로 일부 흡수됨, 추가 승격 검토)
- `feedback_fullcheck_method.md` — 전수검사 방법론 (verification-before-completion + deploy-precheck로 일부 흡수)
- `feedback_polar_coupon_ops.md` — Polar 쿠폰 운영 차단 (refund-logic-audit 관련)

### OBSERVE (PROMOTE 임계값 1건 부족)
- `feedback_chrome_verify.md` — Chrome 실제 확인 (claude-in-chrome-recovery로 일부 흡수)
- `feedback_playwright_verify.md` — Playwright 검증 강제 (verification-before-completion으로 일부 흡수)

→ 위 항목들은 이미 일부 흡수되어 추가 skill 승격 가치 낮음. 전체 상황은 sensor 재실행으로 재평가.

## 관련 정본
- `.claude/scripts/sensor-feedback-promotion.sh` — 후보 식별
- `.claude/skills/gc-sweep/SKILL.md` — 메모리 정리 (승격 안 된 stale feedback)
- `research/HARNESS_ENGINEERING.md` §8.9 — Memory v2 Session-to-Skill 승격
- `verification-before-completion` Skill — 승격 후 검증 패턴

---

마지막 업데이트: 2026-04-26
