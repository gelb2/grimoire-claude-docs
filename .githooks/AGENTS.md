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
- **Pre-push hook**: 2026-07-13 도입 (`.githooks/pre-push`) — eval 회귀 게이트(75 task, HARD-BLOCK). H-1 이중실행 봉합 시 pre-commit에서 이관 (§2 하단 참조).
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

### claude-docs pre-commit + pre-push (워크스페이스 루트)

**2026-07-13 (H-1 이중실행 봉합) 재구성** — eval 회귀 게이트를 pre-commit → pre-push로 이관. pre-commit은 결정적·고속 유지.

pre-commit (`.githooks/pre-commit`) — 매 커밋, 실측 <1분 (네트워크 무관):
```sh
#!/bin/sh
set -e
# [1/3] update-harness-inventory.sh --apply   (HARNESS 인벤토리 drift 사전 갱신)
# [2/3] instructions-drift-check.sh
# [3/3] sensor-adversarial-pre-commit.sh       (Red Team Constitution 20 — WARN 허용, FAIL만 차단)
```

pre-push (`.githooks/pre-push`) — 매 push (반드시 timeout=600000), eval 회귀 게이트:
```sh
#!/bin/sh
set -e
# [1/1] eval-precommit.sh   (eval-runner 75 task, regression-tolerance 0.05, must-pass HARD-BLOCK)
```

**이관 근거 (실측 raw)**:
- eval-runner 단일 실행 = ~240s → Bash 기본 2분 timeout 초과 → 커밋 파싱실패·salvage 빈발 (H-1 근원).
- eval task(`auto-sensor-adversarial-pre-commit` 116s, `auto-sensor-security-gate` 66s 등)가 sensor를 "실행" → redteam-gate + eval task + pre-commit step 이 동일 sensor 3중 실행.
- `sensor-security-gate`는 운영(prod) curl(`--max-time` 無)을 포함 → pre-commit이 네트워크 의존·비결정적.
- **eval 커버리지 75/75 그대로** (eval-precommit.sh 무변경 호출, push 경계로 이동). 게이트 강도 약화 0 — root pre-push는 지금까지 없었으므로 net "게이트 신설(강화)".
- 부수 봉합: `sensor-secret-leak` xargs -I{} → git grep (28.8s→1.1s), `sensor-adversarial` 내부 secret-leak/credit-atomicity 2회→1회, `pretooluse-redteam-gate` 평범한 commit 시 적대검증 skip(pre-commit이 담당).

활성화: `git config core.hooksPath .githooks` (워크스페이스 루트에서 1회).

---

## 3. Pre-Push 변경 시 절차

1. 변경 전 영향 범위 파악 — server·web 양쪽 적용인지 확인
2. shell 구문 체크: `bash -n .githooks/pre-push`
3. 로컬 검증: feature 브랜치에서 dummy push로 hook 실행 확인
4. 본 AGENTS.md 의 §2 hook 본문 동기화

---

## 4. 변경 이력

- 2026-04-30: 본 파일 신설 — 루트 CLAUDE.md §8+§10을 이동 + 실제 server/web hook 본문 박제 (책 Ch 08 60-line 분할). hook 본문이 CLAUDE.md 예시와 달라진 것(prisma validate 추가, sensor-docs-sync 추가) 반영.
- 2026-07-13 (H-1 이중실행 봉합): claude-docs pre-commit에서 eval 회귀 게이트(75 task)를 `.githooks/pre-push` 신설로 이관. pre-commit은 inventory+drift+adversarial(레드팀)만 유지 → 실측 커밋 훅 시간 ~6.2분→<1분. eval 커버리지 75/75·HARD-BLOCK·regression-tolerance 0.05 그대로. 부수: sensor-secret-leak git grep 전환(28.8s→1.1s), adversarial 내부 중복 봉합, redteam-gate commit skip. §1 Pre-push + §2 본문 동기화.
