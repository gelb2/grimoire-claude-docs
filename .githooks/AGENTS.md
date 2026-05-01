# AGENTS.md — `.githooks/` Git 브랜치 전략 + Pre-Push 검증

> 본 파일은 ProjectGrimoire 3개 레포(grimoire-server / grimoire-web / grimoire-claude-docs) 공통 Git/CI 규칙을 정의한다.
> 루트 `CLAUDE.md` §8 + §10에서 본 파일로 분리 (2026-04-30, 책 Ch 08 60-line 적용).
> **주의**: 워크스페이스 루트의 `.githooks/` (이 폴더)는 **AGENTS.md 만 있다**. 실제 hook 스크립트는 `grimoire-server/.githooks/pre-push` + `grimoire-web/.githooks/pre-push`에 위치한다.

---

## 1. Git 브랜치 전략

### 브랜치 구조
```
main              ← 배포용 / 정본용 (직접 커밋 절대 금지)
develop           ← 통합 브랜치 (feature/bugfix 머지 대상) + QA
├── feature/{name}
└── bugfix/{name}
```

### 머지 흐름 (단방향)
```
feature/* ──→ develop ──→ main
bugfix/*  ──↗              ↓
                         tag: v{version}  (server/web만, claude-docs는 태그 없음)
```

### 절대 금지 사항 (3개 레포 공통)
- main에 직접 커밋/푸시
- main에서 feature/bugfix 브랜치 생성
- 역방향 머지 (main → develop)

### Claude 작업 규칙 (3개 레포 공통)
1. 작업 시 `develop`에서 `feature/{name}` 또는 `bugfix/{name}` 브랜치 생성
1.5. localhost 스킴에서 테스트 통과 확인 (유닛 + E2E) 후 다음 단계 진행 — 단 claude-docs는 런타임 코드 없으므로 "문서·스크립트 무결성 체크"로 대체 (예: settings.json JSON 유효성, shell script `bash -n` 구문 체크)
2. 작업 완료 후 `develop`에 `--no-ff` 머지
3. 머지 후 feature/bugfix 브랜치 삭제
4. develop → main 머지는 사용자 요청 시에만

### grimoire-claude-docs 특수사항
- **기본 브랜치**: `main` (정본 박제용) + `develop` (작업 통합용 — 2026-04-26 도입)
  - 2026-04-25 초기화 시점부터 main 단일 운영 → 2026-04-26 #9 push 흐름 정상화 위해 develop 분기 도입
  - 위 §1 본문 규칙(feature/* → develop --no-ff → main)을 그대로 적용. server/web과 동일 흐름
  - 단 본 레포는 런타임 코드 없으므로 develop 머지 시 테스트는 "문서·스크립트 무결성 체크"로 대체 (위 §1 1.5 참조)
- **빌드/테스트 수단**: 런타임 코드 없음. Hook/Skill 스크립트 수정 시 shell 구문 체크 + skill-injector/bash-guard 스모크 테스트로 대체
- **Pre-push hook**: 아직 미도입 (server/web 참고하여 추후 도입 권장)
- **origin**: https://github.com/gelb2/grimoire-claude-docs (PRIVATE)

### 커밋 메시지 컨벤션 (3개 레포 공통)
- 형식: `{type}: {한국어 메시지}`
- 타입: `feat`, `fix`, `test`, `chore`, `docs`, `refactor`, `merge`
- 머지 커밋: `merge: feature/{name} → develop ({설명})`

---

## 2. Pre-Push 검증 (자동)

> projectZenith `.githooks/pre-push` 패턴을 그대로 적용한다.

2개 레포 모두 `.githooks/pre-push` 스크립트를 설정하여, `git push` 시 아래를 자동 실행한다. 하나라도 실패하면 push가 차단된다.

### grimoire-server 실제 hook (5단계)

```bash
# grimoire-server/.githooks/pre-push
#!/bin/sh
set -e
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
echo "=== Pre-Push 검증 ==="
echo "[1/5] TypeScript 컴파일 체크..."
npx tsc --noEmit
echo "[2/5] 테스트 실행..."
npm test
echo "[3/5] 빌드 검증..."
npm run build
echo "[4/5] Prisma 스키마 검증..."
npx prisma validate
echo "[5/5] docs 동기화 검증..."
/Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/sensor-docs-sync.sh
echo "=== 검증 통과 ==="
```

### grimoire-web 실제 hook (4단계)

```bash
# grimoire-web/.githooks/pre-push
#!/bin/sh
set -e
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
echo "=== Pre-Push 검증 ==="
echo "[1/4] TypeScript 컴파일 체크..."
npx tsc --noEmit
echo "[2/4] 유닛 테스트 실행..."
npm test
echo "[3/4] 빌드 검증..."
npm run build
echo "[4/4] docs 동기화 검증..."
/Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/sensor-docs-sync.sh
echo "=== 검증 통과 ==="
```

### Git Hooks 설정

```bash
# 각 레포에서 최초 1회 실행
git config core.hooksPath .githooks
chmod +x .githooks/pre-push
```

> `--no-verify`는 긴급 상황에서만 사용. 남용 금지.

### claude-docs pre-commit (워크스페이스 루트, 2026-04-30 #10 H6 신설)

```sh
# .githooks/pre-commit (claude-docs 자체)
#!/bin/sh
set -e
echo "=== claude-docs pre-commit 검증 ==="
echo "[1/2] instructions-drift-check.sh ..."
bash /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/instructions-drift-check.sh
echo "[2/2] eval-precommit.sh (regression-tolerance 0.05) ..."
bash /Users/sokol/Desktop/Git/ProjectGrimoire/eval/scripts/eval-precommit.sh
echo "=== pre-commit 검증 통과 ==="
```

활성화: `git config core.hooksPath .githooks` (워크스페이스 루트에서 1회).
근거: 책 Ch 15 "EDD CI/CD 통합" — claude-docs는 코드 없으므로 매 commit 부담 작음 (~30s + 1s).

---

## 3. Pre-Push 변경 시 절차

1. 변경 전 영향 범위 파악 — server·web 양쪽 적용인지 확인
2. shell 구문 체크: `bash -n .githooks/pre-push`
3. 로컬 검증: feature 브랜치에서 dummy push로 hook 실행 확인
4. 본 AGENTS.md 의 §2 hook 본문 동기화

---

## 4. 변경 이력

- 2026-04-30: 본 파일 신설 — 루트 CLAUDE.md §8+§10을 이동 + 실제 server/web hook 본문 박제 (책 Ch 08 60-line 분할). hook 본문이 CLAUDE.md 예시와 달라진 것(prisma validate 추가, sensor-docs-sync 추가) 반영.
