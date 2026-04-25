---
name: writing-plans
description: 큰 작업(예상 ≥30분)을 작성·실행 가능한 단위로 분할하는 메타 절차. 사용자가 "이 작업 어떻게 나눠?", "계획 짜봐", "분할해서 가자"라고 할 때 또는 grimoire-planner 에이전트가 PRD/작업 세부 분해를 시작할 때 발동. obra/superpowers (MIT) writing-plans 차용 + ProjectGrimoire 도메인 적용 (≥30분 작업만 분할 — 마찰 회피).
allowed-tools: Read, Write, Edit
triggers:
  - "계획 짜"
  - "계획을 세"
  - "분할"
  - "쪼개"
  - "나눠"
  - "작업 단위로"
  - "PRD"
  - "step by step"
  - "단계별로"
  - "작업 분해"
---

# Writing Plans — 큰 작업 분할 메타 절차

## 적용 범위

> **트리거 조건**: 예상 작업 시간 **≥30분**.
> 30분 미만의 단순 작업은 분할 마찰이 효과보다 큼 — 메인 Claude가 즉시 진행하는 게 정합 (CLAUDE.md §14.2 메인 오케스트레이션 규칙).

## 절차

### Step 1. 작업 크기 산정 (사전 게이트)
- 예상 시간 계산
- ≥30분이면 본 skill 진행
- <30분이면 **분할 없이 직접 진행** + 본 skill 스킵 안내

### Step 2. 작업 분해 — 2~5분 단위 sub-task

각 sub-task는:
- **2~5분** 소요 (15분 넘으면 더 쪼갤 수 있는지 검토)
- **하나의 검증 가능한 산출물** 생산 (파일 추가/수정 / 명령 실행 결과 / 검증 PASS 등)
- **선행/후행 의존성** 명시
- **rollback 단위** (실패 시 되돌릴 수 있는 단위)

### Step 3. 우선순위 + 위험도 표시

각 sub-task에 다음 라벨 (GMP v2.2):
- `[MUST]` 필수 (실패 시 전체 중단)
- `[SHOULD]` 권장 (실패 시 경고만)
- `[NICE]` 선택 (skip 가능)

위험도:
- 🔴 destructive (DB 변경 / 운영 시스템 / 시크릿 회전)
- 🟡 reversible (코드 변경 / 문서 수정)
- 🟢 read-only (검사 / 측정 / 보고)

### Step 4. 핸드오프 정의

여러 에이전트 / 여러 세션 걸친 작업이면:
- 각 sub-task의 담당자 (메인 / planner / server / web / qa)
- 산출물 위치 (PROGRESS_*.md / HANDOVER.md / memory/)
- 다음 단계 진입 조건

### Step 5. 검증 게이트

각 sub-task 완료 시 검증 방법:
- 코드 변경: tsc + test 통과 / sensor 통과
- 문서 변경: docs-sync sensor 통과 / drift sensor silent
- 운영 변경: curl health check / DB 쿼리 / 사용자 직접 확인

verification-before-completion Skill의 Gate 1·2·3을 sub-task 단위로 적용.

## 출력 양식

```markdown
## 작업 계획: {큰 작업 제목}

### 예상 총 시간: {N}분
### 분할 근거: ≥30분 + {분할 가치 사유}

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| 1 | ... | [MUST] | 🟢 | 3분 | - | tsc PASS |
| 2 | ... | [MUST] | 🟡 | 5분 | 1 | test PASS |
| 3 | ... | [SHOULD] | 🟡 | 4분 | 2 | sensor silent |
| 4 | ... | [NICE] | 🟢 | 2분 | - | (검증 불필요) |

### 핸드오프 (있다면)
- sub-task X (담당: server) → PROGRESS_X.md
- sub-task Y (담당: qa) → 독립 검증 후 HANDOVER 갱신

### 종합 게이트
- 모든 [MUST] 완료 + Gate 1·2·3 통과 시 "작업 완료" 선언
- [SHOULD] 실패는 회고만, 다음 세션 후속
- [NICE]는 skip 무관
```

## 절대 금지 사항

### [MUST NOT] 30분 미만 작업 분할
- 분할 마찰이 효과 초과 → 즉시 진행이 정합
- 사용자가 "분할해줘"라고 명시해도, 30분 미만이면 "분할 불필요" 명시 후 직접 진행

### [MUST NOT] 검증 없는 sub-task
- 각 sub-task는 반드시 검증 가능한 산출물 + 검증 명령 동반
- "구현만 하고 다음에 검증" 금지

### [MUST NOT] rollback 단위 미정의
- 모든 sub-task는 실패 시 되돌릴 수 있어야 함 (git commit / 백업 파일 / 환경변수 원복)

## ProjectGrimoire 적용 사례

### 좋은 사례
- "Top-5 P0 일괄 진행" (세션 #7) — 5개 sub-task로 분할, 각 ≥3분, 의존성 명시 (#3 commands 마이그레이션 먼저), Gate 1·2·3 적용
- "보안 회수 P0 5건" (세션 #4) — Phase 0~9로 분할, 각 단계 명확한 산출물 + 검증

### 나쁜 사례
- "AI 채팅 SSE 구현" (현재 미완) — 분해 없이 거대 작업으로 박제됨. ≥30분이지만 sub-task 분할 안 돼서 진척 정체

## 관련 정본
- `prompt-engineering/GMP-v2.2.md` — 우선순위 라벨 [MUST]/[SHOULD]/[NICE]
- `prompt-engineering/vibe-coding-unified-guide.md` — Phase 분할 + 게이트 체크
- `verification-before-completion` Skill — sub-task 단위 Gate 1·2·3
- `research/HARNESS_ENGINEERING.md` §16.4 — 패턴 1+3 진화 P1~P3 자체가 본 skill 적용 결과
- obra/superpowers `writing-plans` (MIT 차용 원본)

---

승격 원본: obra/superpowers `writing-plans` (MIT)
적용 영역: ProjectGrimoire 도메인 (≥30분 게이트 신설로 마찰 회피)
마지막 업데이트: 2026-04-25
