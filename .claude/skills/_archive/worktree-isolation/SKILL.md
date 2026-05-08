---
name: worktree-isolation
description: 큰 Edit 폭주 작업(예상 ≥50 Edit 호출 또는 ≥1시간 다중 도메인) 시 main 브랜치 오염 방지용 git worktree 격리 절차. obra/superpowers MIT 차용 + ProjectGrimoire 도메인 적용. 사용자 명시 호출만 (`/worktree-isolation start <branch>` / `/worktree-isolation finish` / `/worktree-isolation discard`). HARNESS §8.10 안전망.
argument-hint: "[필수: start <branch> | finish | discard | list]"
disable-model-invocation: true
allowed-tools: Read, Bash, Grep, Glob, Edit, Write
effort: medium
trigger-mode: keyword (triggers field) — paths 미적용 명시 (NEW-16 J4 패턴)
---

> **2026-05-06 묶음 PP-3 ARCHIVE**: 30일간 자율 호출 0회 + disable-model-invocation: true + 비상 가치 낮음. 비상 시 `.claude/skills/_archive/worktree-isolation/SKILL.md` 직접 Read 또는 사용자 명시 호출.

# Worktree Isolation — Edit 폭주 작업 안전망

> **trigger-mode**: user-invocation (disable-model-invocation:true). paths 미적용 — 사용자 `/worktree-isolation` 명시 호출만.

## 동기 (HARNESS §8.10 안전망)

ProjectGrimoire 본 세션 #9 데이터:
- 메인 Edit 696 + Write 123 = 696 메인 직접 작업
- 다중 도메인 작업 47.3% (server/web 합계)
- 단일 develop 브랜치에서 직접 작업 → push 누락/충돌 위험

**격리 효과**:
- worktree로 별도 디렉토리에서 작업 → 메인 develop 브랜치 오염 방지
- 작업 중간 다른 긴급 작업 발생 시 메인 develop으로 즉시 복귀 가능
- 작업 실패 시 worktree만 폐기 → 메인 무결성 보장

**적용 권장 케이스**:
- ≥50 Edit 호출 예상
- ≥1시간 + 다중 도메인 (server + web 동시)
- 실험적 변경 (rollback 가능성 ↑)
- 사용자 검토 대기 중 다른 작업 병행

## 절차

### Step 1. start — worktree 생성

```bash
ARG="${ARGUMENTS:?start <branch> | finish | discard | list 필요}"
case "$ARG" in
  start*)
    BRANCH=$(echo "$ARG" | awk '{print $2}')
    [ -z "$BRANCH" ] && echo "Usage: /worktree-isolation start <branch>" && exit 1
    REPO=$(pwd)
    WORKTREE_DIR="$REPO/.worktrees/$BRANCH"
    git -C "$REPO" worktree add "$WORKTREE_DIR" -b "$BRANCH"
    echo "[worktree] 생성: $WORKTREE_DIR (branch: $BRANCH)"
    echo "[worktree] cd $WORKTREE_DIR 로 이동 후 작업 진행"
    ;;
esac
```

검증:
- `.worktrees/{branch}/` 디렉토리 생성 확인
- `git worktree list`에 새 worktree 표시 확인

### Step 2. 작업 수행 (메인은 그대로)

worktree 안에서 자유롭게 Edit/Write/commit. 메인 워킹 디렉토리는 영향 없음.

```bash
cd .worktrees/{branch}
git add .
git commit -m "..."
```

### Step 3. finish — develop에 머지 + worktree 폐기

```bash
case "$ARG" in
  finish)
    BRANCH=$(git branch --show-current)
    WORKTREE_DIR=$(git rev-parse --show-toplevel)
    MAIN_REPO=$(echo "$WORKTREE_DIR" | sed 's|/.worktrees/.*||')
    cd "$MAIN_REPO"
    git checkout develop
    git merge --no-ff "$BRANCH" -m "merge: $BRANCH → develop (worktree finish)"
    git worktree remove "$WORKTREE_DIR"
    git branch -d "$BRANCH"
    echo "[worktree] $BRANCH 머지 완료 + worktree 폐기"
    ;;
esac
```

### Step 4. discard — 머지 안 하고 폐기

```bash
case "$ARG" in
  discard)
    BRANCH=$(git branch --show-current)
    WORKTREE_DIR=$(git rev-parse --show-toplevel)
    MAIN_REPO=$(echo "$WORKTREE_DIR" | sed 's|/.worktrees/.*||')
    cd "$MAIN_REPO"
    git worktree remove --force "$WORKTREE_DIR"
    git branch -D "$BRANCH"
    echo "[worktree] $BRANCH 폐기 완료 (머지 안 함)"
    ;;
esac
```

### Step 5. list — 현재 worktree 목록

```bash
case "$ARG" in
  list) git worktree list ;;
esac
```

## 절대 금지 사항

### [MUST NOT] worktree에서 main 직접 사용
- worktree는 항상 새 feature/* 브랜치로 생성
- worktree 안에서 main 또는 develop 직접 checkout 금지

### [MUST NOT] worktree 미정리
- finish 또는 discard 없이 중단 시 `.worktrees/` 누적
- 정기 정리: `git worktree list` → 사용 안 하는 worktree `git worktree remove`

### [MUST NOT] 메인 워킹 디렉토리에서 worktree 작업
- worktree 생성 후 반드시 `cd .worktrees/{branch}/` 이동
- 메인 디렉토리 Edit 시 격리 효과 없음

### [MUST NOT] .worktrees/ git 추적
- `.gitignore`에 `.worktrees/` 추가 (없으면)

## ProjectGrimoire 적용 사례

### 좋은 사례 (예상)
- 본 세션 #9 1차+2차 5건 (~3시간 다중 도메인) — worktree 적용 가능했음
- 향후 보안 회수 (Edit 30+ 폭주) 시 worktree 격리

### 나쁜 사례 (예방)
- 단일 도메인 30분 작업 — 격리 오버헤드가 효과 초과
- 메모리/문서 작업 (조율 자체) — worktree 의미 없음

## 권장 빈도
- **start/finish**: 작업 시작/종료마다 (워크플로우)
- **discard**: 실험 실패 시
- **list**: 주 1회 또는 누적 의심 시

## 관련 정본
- `research/HARNESS_ENGINEERING.md` §8.10 — Worktree 안전망
- `research/HARNESS_FIELD_PATTERNS_4.md` §15.7 — 위임 가치 매트릭스 (worktree 적용 기준, 2026-05-02 분리)
- obra/superpowers worktree skill (MIT 차용 원본)
- `gc-sweep` Skill — 누적 worktree 청소 후보 식별

---

마지막 업데이트: 2026-04-27
승격 원본: obra/superpowers (MIT)
적용 영역: ProjectGrimoire 도메인 (다중 도메인 작업 격리)
