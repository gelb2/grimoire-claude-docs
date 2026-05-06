---
name: requesting-code-review
description: 큰 변경(≥30 Edit, 다중 도메인, prod 배포 직전) commit 전 사전 검토 체크리스트 강제. obra/superpowers (MIT) 차용 + verification-before-completion + sensor-adversarial-pre-commit 시너지. 사용자/Claude 명시 호출 또는 PreToolUse Bash hook 자동 발동.
allowed-tools: Read, Bash, Grep
disable-model-invocation: true
effort: high
trigger-mode: keyword + user-invocation (paths 미적용 — 메타 검증)
triggers:
  - "code review"
  - "코드 리뷰"
  - "사전 검토"
  - "PR 검토"
  - "리뷰 요청"
  - "review request"
  - "리뷰"
  - "검토"
  - "PR 직전"
owner-agent: grimoire-qa
owner-skill: ""
responsibility-note: "코드 리뷰 게이트 (qa 도메인)"
---

# Requesting Code Review — 사전 검토 체크리스트 (메타)

## 책임 영역 (2026-05-06 묶음 PP-3 박제)

- **owner**: grimoire-qa agent (코드 리뷰·게이트 도메인)
- **trigger 패턴**: 사용자 입력 키워드 매칭 시 본 skill의 additionalContext 주입 + grimoire-qa agent가 명시 호출
- **메인 책임**: 본 skill을 직접 호출 X — grimoire-qa agent에 위임 후 qa agent가 본 skill 활용

> **trigger-mode**: user-invocation + 키워드 매칭. paths 미적용 — 메타 검증.
> **신설**: 2026-05-03 #10_6 묶음 EE — 사용자 명시 (proposal §10-3 적용)
> **승격 원본**: obra/superpowers (MIT) requesting-code-review

## 동기 (verification-before-completion + sensor-adversarial 시너지)

기존 보유 메타 검증:
- **verification-before-completion**: 완료 선언 직전 실측 증거 3종 강제 (테스트/빌드/기능 동작)
- **sensor-adversarial-pre-commit**: pre-commit 직전 19 principles 자동 검증
- **socratic-self-critique**: 작업 완료 직전 7~14 메타 질문

본 skill의 차별점:
- **사전 검토 체크리스트** (commit 전 / PR 생성 전 / 사용자에게 요청 전 사용자/외부 reviewer가 봐야 할 항목 목록)
- 위 3 보유 skill은 **자동 검증** — 본 skill은 **수동 검토 가이드**

## 발동 조건

다음 중 1개 이상:
1. **트리거 키워드 매칭** (위 frontmatter)
2. **큰 변경 감지** (≥30 Edit / 다중 도메인 / prod 배포 직전)
3. **사용자 명시 호출**: `/requesting-code-review`
4. **PR 생성 직전** (gh pr create 등 자동 트리거 가능)

## 사전 검토 체크리스트 (12 항목)

### A. 회귀 검증 (자동)
- [ ] **regression eval 100%**: `bash eval/scripts/eval-runner.sh` exit 0
- [ ] **drift sensor exit 0**: `bash .claude/scripts/instructions-drift-check.sh`
- [ ] **adversarial 19 principles**: `bash .claude/scripts/sensor-adversarial-pre-commit.sh` PASS or WARN ACCEPTABLE
- [ ] **server sensor PASS** (server 변경 시): `bash .claude/scripts/sensor-server.sh`
- [ ] **web sensor PASS** (web 변경 시): `bash .claude/scripts/sensor-web.sh`

### B. 의도 검증 (사용자 검토)
- [ ] **사용자 명시 결정 영역 0건**: 외부 API / Polar KYC / PLANNING 등 위반 없음
- [ ] **commit 메시지에 추정 패턴 0건**: "추정" / "아마" / "probably" / "기능 정상 확인 안 함"

### C. shared-contracts 정합 (Ch 16)
- [ ] **shared-contracts 변경 시 7 에이전트 .md 동기**: `bash .claude/scripts/sensor-shared-contracts.sh`
- [ ] **인터페이스 변경 시 reports/ 정본 갱신**

### D. 메모리 박제 (절대 규칙 §1)
- [ ] **memory/project_session_YYYYMMDD*.md 작성**
- [ ] **memory/MEMORY.md 인덱스 갱신**
- [ ] **memory/project_remaining_tasks.md 현행화**

## 출력 형식 (체크리스트 자동 생성)

```bash
# 사용자/Claude 호출 시 자동 생성
echo "=== Code Review Request — $(date +%Y-%m-%d) ==="
echo ""
echo "변경 요약:"
git diff --stat HEAD~1 HEAD
echo ""
echo "체크리스트 (12 항목):"
# 각 항목 자동 검증 + ✅/❌ 마크
```

## 자동 검증 vs 수동 검토 분류

| 항목 | 분류 | 도구 |
|------|------|------|
| A. 회귀 검증 (1~5) | **자동** | sensor 호출 |
| B. 의도 검증 (1~2) | **수동** | 사용자/Claude 메타 검토 |
| C. shared-contracts (1~2) | **자동** | sensor + grep |
| D. 메모리 박제 (1~3) | **자동 + 수동** | Stop hook + 사용자 명시 |

## 절대 금지 사항

### [MUST NOT] 자동 PASS 항목 우회
sensor가 FAIL인 채로 commit / PR 생성 = §0 ZERO-TOLERANCE 위반.

### [MUST NOT] 사용자 명시 결정 영역 우회
외부 API / 모델 티어링 / Polar KYC 등 보류 영역에서 변경 시 즉시 사용자 보고.

### [MUST NOT] verification-before-completion 우회
실측 증거 3종 (테스트/빌드/기능 동작) 첨부 없이 본 skill만으로 완료 선언 X.

### [MUST NOT] 메모리 박제 우회
Stop hook이 차단하지만, 본 skill도 D 항목 강제 검증.

## ProjectGrimoire 적용 사례

### 좋은 사례 (예상)
- **#10_6 5월 3일 J8 머지 3회**: 매 머지 직전 본 skill 실행 → 12 항목 검증 → 통과 시만 머지
- **묶음 R+S+T+V'+W+X+Y+Z 자율 진행**: 각 묶음 commit 전 본 skill로 회귀 + 메모리 검증

### 나쁜 사례 (예방)
- **#10_4 sensor-server flaky 초기 검출**: 본 skill 미적용 → 일회성 추정 → §0 위반 위험 (이후 sensor-server fallback 추가로 해소)

## 관련 정본
- `.claude/skills/verification-before-completion/SKILL.md` — 실측 증거 강제 (선행)
- `.claude/skills/socratic-self-critique/SKILL.md` — 메타 자기-심문 (시너지)
- `.claude/scripts/sensor-adversarial-pre-commit.sh` — 자동 검증 (A 항목)
- `.claude/scripts/stop-memory-guard.sh` — 메모리 박제 강제 (D 항목)
- 책 V1.1 Ch 23 자가진단 7질문 — 본 skill 사상 동일
- obra/superpowers (MIT) requesting-code-review — 차용 원본

---

마지막 업데이트: 2026-05-03 #10_6 묶음 EE
승격 원본: obra/superpowers (MIT) requesting-code-review
적용 영역: ProjectGrimoire 도메인 (한국어 + 12 항목 + 자동/수동 분류)
