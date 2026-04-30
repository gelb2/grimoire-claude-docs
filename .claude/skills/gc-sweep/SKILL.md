---
name: gc-sweep
description: ProjectGrimoire harness 자산(skills / agents / sensors / hooks / prompts / knowledge / 메모리) 중 미참조·미발동·stale 항목을 식별. Fowler "Requisite Variety" 축 1.5/5 → 3+/5 갭 해소. 사용자 명시 호출만 (`/gc-sweep [dry-run|stage|apply]`). 분기 dry-run 시 후보만 출력, stage 시 .gc-staging/으로 이동, apply 시 실제 삭제(주의).
argument-hint: "[선택: dry-run | stage | apply] (기본 dry-run — 후보만 출력)"
disable-model-invocation: true
allowed-tools: Read, Bash, Grep, Glob, Write, Edit
effort: medium
---

# GC Sweep — Harness 자산 정기 청소

## 동기 (Fowler "Requisite Variety" 갭 해소)

ProjectGrimoire는 9 skills / 9 sensors / 8 hooks / 7 agents / 7 prompts / 3 knowledge / 50+ memory 파일을 보유. 시간이 지나면 미참조·미발동 자산이 누적되어:

- LLM 컨텍스트 잡음 증가 (sshh.io 임계값 150~200 instructions 위협)
- 신규 자산 추가 시 충돌 위험
- 사용자 가시성 ↓ (어떤 게 살아있는지 모름)

본 skill은 정기 청소 (월 1회 권장)로 위 위험을 차단.

## 7 카테고리 검사

### 1. Skills 미참조 (`.claude/skills/<name>/SKILL.md`)
- 9개 skill 중 다음 중 어디에도 참조 안 됨: 다른 SKILL.md / agent .md / hook 스크립트 / settings.json / memory/ / research/HARNESS_ENGINEERING.md
- 후보 식별: `grep -rn "skills/<name>" .claude/ research/ memory/ 2>/dev/null` 결과 0건

### 2. Sensors silent (`.claude/scripts/sensor-*.sh`)
- sensor-hit-rate-report 결과에서 직전 30일간 fire 0회
- 단, 신규 sensor (도입 후 30일 미만)는 면제

### 3. Hooks 미작동 (`.claude/settings.json` hooks)
- PostToolUse / PostToolBatch / PreToolUse 등 이벤트별 등록은 됐는데 fire 로그 0회
- `.launchd-logs/` 또는 sensor-log.sh 결과로 검증

### 4. Memory stale (`memory/feedback_*.md`)
- 90일 이상 참조 안 된 feedback 파일
- MEMORY.md 인덱스에는 있지만 실제 grep 결과 신규 사용 0건

### 5. Scripts 고아 (`.claude/scripts/*.sh`)
- 22개 script 중 다음 중 어디에도 호출 안 됨: settings.json / launchd plist / 다른 script / Makefile / 문서
- `grep -rn "scripts/<name>.sh" .claude/ Makefile 2>/dev/null` 결과 0건

### 6. Agents 미사용 (`.claude/agents/*.md`)
- 7 agent 중 직전 30일간 Task tool 호출 이력 0회
- `~/.claude/projects/.../*.jsonl` 의 subagent_type 필드 grep

### 7. Prompts 고아 (`.claude/prompts/*.txt`)
- 7 prompt 중 매핑되는 agent가 없거나, run-agent.sh 호출 이력 0회

## 절차

### Step 1. 모드 결정

```bash
MODE="${ARGUMENTS:-dry-run}"
case "$MODE" in
  dry-run) ;;
  stage) ;;
  apply) ;;
  *) echo "MODE must be dry-run|stage|apply"; exit 1 ;;
esac
```

### Step 2. 7 카테고리 스캔

각 카테고리에 대해 후보 파일 식별 → `gc-candidates.json` 생성:

```json
{
  "skills_unreferenced": [],
  "sensors_silent": [],
  "hooks_inactive": [],
  "memory_stale": [],
  "scripts_orphan": [],
  "agents_unused": [],
  "prompts_orphan": []
}
```

### Step 3. dry-run / stage / apply 분기

- **dry-run**: gc-candidates.json을 stdout 출력. 파일 변경 없음
- **stage**: 후보 파일을 `.claude/.gc-staging/<category>/<name>.bak`로 이동. 실제 삭제는 안 함 → 사용자 확인 후 apply
- **apply**: `.claude/.gc-staging/`의 모든 파일을 영구 삭제. 사용 전 stage 단계 통과 필수

### Step 4. 검증

stage / apply 후:
- 모든 sensor 재실행 → silent 0건 확인
- skill-injector / bash-guard / drift sensor → silent 확인
- TypeScript 컴파일 / 빌드 정상 확인 (server/web 양쪽)
- 의도치 않은 회귀 발견 시 `.gc-staging/`에서 즉시 복원

## 출력 양식 (stdout)

```markdown
## GC Sweep ({YYYY-MM-DD HH:MM})
### 모드: {dry-run|stage|apply}

### 1. Skills 미참조 ({N}건)
- skill-A: 마지막 참조 N일 전 (또는 0건)
- skill-B: ...

### 2. Sensors silent ({N}건)
- sensor-X.sh: 직전 30일 fire 0회 (도입일 YYYY-MM-DD)

### 3. Hooks 미작동 ({N}건)
- ...

### 4. Memory stale ({N}건)
- ...

### 5. Scripts 고아 ({N}건)
- ...

### 6. Agents 미사용 ({N}건)
- ...

### 7. Prompts 고아 ({N}건)
- ...

### 종합
- 총 {N}건 청소 후보
- 모드 {mode}: {수행 결과}
- 다음 단계 권장: {stage / apply / 사용자 검토}
```

## 절대 금지 사항

### [MUST NOT] 무조건 apply
- dry-run → stage → apply 순서 강제. dry-run 스킵하고 apply 금지
- apply 단계 전 사용자 명시 확인 필수 ("정말 삭제하시겠습니까? 후보 N개")

### [MUST NOT] 정본 문서 청소
- CLAUDE.md / PLANNING_GRIMOIRE.md / SYNC_STATUS.md / docs/ / research/ 등 정본 절대 청소 대상 제외
- 검사 시 path filter로 제외 명시

### [MUST NOT] 신규 자산 청소
- 도입 후 30일 미만 자산은 silent여도 면제
- "아직 사용 패턴 형성 중" 가능성 보존

### [MUST NOT] 메모리 절대 규칙 위반
- `feedback_*.md` 중 CLAUDE.md §12에 명시된 항목은 stale 판정해도 청소 금지
- 인덱스(MEMORY.md)에서 빼는 것도 금지 (사용자 결정만)

## ProjectGrimoire 적용 사례

### 좋은 사례 (예상)
- 2026-04-25 commands → skills 마이그레이션 후 `.claude/commands/*.md` 잔재 청소 (실제로는 이미 제거됨)
- 신규 sensor 도입 후 30일 silent 시 cost-benefit 재평가 (silent sensor 자체가 안 좋은 것은 아니지만, hit-rate 0이면 검사 항목 정밀화 필요)

### 나쁜 사례 (예방 대상)
- 사용자가 모르는 사이 verification-before-completion skill을 stale 판정해서 삭제 → 핵심 게이트 사라짐
- agent-system.md를 "참조 0건" 오판해 청소 → planner 작업 마비

## 실행 빈도 권장

- **dry-run**: 월 1회 (사용자 가시성 확보)
- **stage**: 분기 1회 (사용자 검토 후)
- **apply**: 반기 1회 (보수적 운영)

## 관련 정본
- `research/HARNESS_ENGINEERING.md` §15.5 — Requisite Variety 갭 진단 (현재 1.5/5)
- `.claude/scripts/sensor-hit-rate-report.sh` — silent sensor 식별 입력
- `.claude/scripts/instructions-drift-check.sh` — drift 자체 검증 (stage/apply 후 silent 확인)
- `verification-before-completion` Skill — Gate 1·2·3 (stage/apply 검증 단계)
- Fowler "Garbage Collection in software engineering" (메타 비유)

---

마지막 업데이트: 2026-04-26
