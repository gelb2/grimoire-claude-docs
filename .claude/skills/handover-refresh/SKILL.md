---
name: handover-refresh
description: grimoire-server/HANDOVER.md를 git log + 최근 메모리 + sensor 결과 + 배포 상태를 자동 수집해 갱신. 사용자 명시 호출만 (`/handover-refresh`). 세션 종료 직전 또는 세션 시작 시 stale 검증용. CLAUDE.md §12 메모리 기록 절대 규칙과 결합.
argument-hint: "[선택: dry-run | apply] (기본 dry-run — 결과만 표시, 실제 갱신 안 함)"
disable-model-invocation: true
allowed-tools: Read, Bash, Grep, Glob, Write, Edit
effort: medium
paths:
  - "grimoire-server/HANDOVER.md"
  - "grimoire-web/HANDOVER.md"
  - "**/memory/MEMORY.md"
  - "**/memory/project_session_*.md"
---

# Handover Refresh — HANDOVER.md 자동 갱신

## 목적

`grimoire-server/HANDOVER.md`는 세션 간 인계 정본 (CLAUDE.md §12 절대 규칙). 수동 갱신은 누락·stale 발생 위험. 본 skill은 다음을 자동 수집:

1. **최근 git log** (3 레포 각각, 7일 또는 5 커밋)
2. **최신 메모리 세션** (`memory/project_session_*.md` 인덱스)
3. **sensor 상태 스냅샷** (sensor-secret-leak / sensor-docs-sync / sensor-hit-rate-report)
4. **배포 상태** (Container Apps revision + last health check)
5. **TODO.md 진행도** (양 레포의 P0/P1/P2 잔여)

## 절차

### Step 1. 모드 결정

```bash
MODE="${ARGUMENTS:-dry-run}"
case "$MODE" in dry-run|apply) ;; *) echo "MODE must be dry-run|apply"; exit 1 ;; esac
```

### Step 2. 데이터 수집

```bash
# 3 레포 git log (최근 5 커밋)
for REPO in /Users/sokol/Desktop/Git/ProjectGrimoire \
            /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server \
            /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web; do
  echo "=== $(basename $REPO) ==="
  cd "$REPO" && git log --oneline -5
done

# 최신 메모리 세션 5개
ls -t /Users/sokol/.claude/projects/-Users-sokol-Desktop-Git-ProjectGrimoire/memory/project_session_*.md | head -5

# sensor 스냅샷
bash /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/sensor-secret-leak.sh 2>&1 | tail -3
bash /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/sensor-docs-sync.sh 2>&1 | tail -3
bash /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/sensor-hit-rate-report.sh 2>&1 | tail -10

# 배포 상태 (curl health)
curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" https://dev-api.grimoire-book.com/api/health
curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" https://api.grimoire-book.com/api/health

# TODO 미체크 카운트
grep -c "^- \[ \]" /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server/TODO.md
grep -c "^- \[ \]" /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web/TODO.md
```

### Step 3. HANDOVER.md 갱신안 작성

기존 HANDOVER.md 헤더 (§0 절대 수칙) 보존 + §0.5에 새 세션 요약 추가:

```markdown
## 0.5. 마지막 세션 자동 수집 ({YYYY-MM-DD HH:MM})

### 최근 커밋
- root: {hash} {msg}
- server: {hash} {msg}
- web: {hash} {msg}

### Sensor 상태
- secret-leak: PASS/FAIL
- docs-sync: PASS/FAIL
- hit-rate: silent sensors {N}개

### 배포 헬스
- dev: HTTP {code} {time}
- prod: HTTP {code} {time}

### TODO 잔여
- server: {N}개 미체크
- web: {N}개 미체크

### 최신 메모리 세션 5개
- {파일명}
- ...
```

### Step 4. dry-run / apply 분기

- **dry-run**: 위 갱신안을 **stdout에만 출력**. HANDOVER.md 안 건드림
- **apply**: HANDOVER.md §0.5 자동 갱신 (기존 §0.5 덮어쓰기)

apply 시 검증:
- 갱신 후 git diff 출력 (사용자 확인용)
- HANDOVER.md 라인 수가 급증/급감 안 했는지 sanity check

## 절대 금지 사항

- **[MUST NOT]** §0 절대 수칙 / §1~§N 다른 섹션 수정 — §0.5만 갱신
- **[MUST NOT]** 자동 git commit — 사용자가 직접 commit 결정
- **[MUST NOT]** ACCOUNTS.md / 시크릿 정보 박제 — 갱신안에 시크릿 노출 시 즉시 마스킹

## 적용 사례

매 세션 종료 직전 또는 다음 세션 시작 시:
```
/handover-refresh dry-run     # 결과 확인
/handover-refresh apply       # 실제 갱신
```

## 관련 정본

- `CLAUDE.md §12` — 메모리 기록 절대 규칙 + 서브에이전트 raw 박제
- `grimoire-server/HANDOVER.md` — 갱신 대상
- `research/HARNESS_ENGINEERING.md` §10 Phase 3 — 본 skill이 §10 잔여 항목 충족
- `verification-before-completion` Skill — 갱신 후 Gate 1·2·3 적용

---

마지막 업데이트: 2026-04-25
