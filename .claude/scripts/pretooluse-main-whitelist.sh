#!/bin/bash
# pretooluse-main-whitelist.sh — 메인 Claude 작업 영역 분류 (공통 로직, 2026-05-29 재작성+verifier보강)
#
# 사용자 명시 2026-05-29 (거짓 PASS 사태 후 재설계):
#   메인 = 업무지시·오케스트레이션·메모리·읽기검증만. 코드/배포/qa/빌드 = 에이전트.
#   하네스(.claude) = 부트스트랩 플래그 ON이면 메인, OFF면 grimoire-harness 에이전트.
#
# verifier 보강 (2026-05-29 1차 독립검증 GAP A/B/C/D 반영):
#   A/B: 레포 루트 설정파일(jest.config/next.config/package.json/tsconfig 등)도 코드영역
#   C:   git 공백변형(git  commit / git -c x commit)도 차단
#   D:   Bash 리다이렉트/파일쓰기로 코드영역 우회(echo>src, tee src, cp→src 등)도 차단
#
# 출력: ALLOW | BLOCK:<agent|reason> | (BOOTSTRAP는 ALLOW/BLOCK로 환원)
# 호출자: pretooluse-edit-write-guard.sh / pretooluse-bash-guard.sh

set -uo pipefail
ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
BOOTSTRAP_FLAG="$ROOT/.claude/state/harness-bootstrap.flag"

KIND="${1:-}"     # "file" 또는 "bash"
TARGET="${2:-}"   # file_path 또는 command 문자열

# --- 파일 경로 → 영역 분류 (Edit/Write + Bash 파일쓰기 공용) ---
# 2026-05-29 verifier 보강: 매칭 전 경로 정규화로 협조적 LLM의 흔한 변형 우회 차단.
#   - 소문자화 (macOS 대소문자무시 FS 대응: GRIMOIRE-SERVER/SRC → grimoire-server/src)
#   - os.path.normpath (중복슬래시 grimoire-server//src// + dot-slash grimoire-server/./src 해소)
#   적대적 난독화(공백/변수/따옴표)는 협조적 위협모델 밖이라 시도하지 않음.
classify_path() {
  local f="$1"
  # 정규화: 소문자 + normpath. python3 실패 시 원본 fallback (fail-safe: 정규화 못해도 원본으로 매칭).
  local nf
  nf=$(printf '%s' "$f" | python3 -c "import os.path,sys; print(os.path.normpath(sys.stdin.read().strip()).lower())" 2>/dev/null || printf '%s' "$f")
  [ -z "$nf" ] && nf="$f"
  case "$nf" in
    # 코드 영역 = 에이전트 전용
    *grimoire-server/src/*|*grimoire-server/test/*|*grimoire-server/prisma/*|*grimoire-server/docs/*) echo "BLOCK:grimoire-server"; return ;;
    *grimoire-server/scripts/*) echo "BLOCK:grimoire-server"; return ;;
    *grimoire-web/src/*|*grimoire-web/app/*|*grimoire-web/docs/*) echo "BLOCK:grimoire-web"; return ;;
    # GAP A/B: 레포 루트 설정파일도 코드영역 (빌드스킴 = 에이전트)
    # ※ 패턴은 정규화된 소문자 경로($nf) 기준 — Dockerfile/Makefile/AGENTS.md 등도 소문자로 기재.
    *grimoire-server/jest.config.*|*grimoire-server/tsconfig*|*grimoire-server/package.json|*grimoire-server/nest-cli.json|*grimoire-server/dockerfile*|*grimoire-server/docker-compose*|*grimoire-server/makefile|*grimoire-server/prisma.config.*) echo "BLOCK:grimoire-server"; return ;;
    *grimoire-web/next.config.*|*grimoire-web/tsconfig*|*grimoire-web/package.json|*grimoire-web/vitest.config.*|*grimoire-web/playwright.config.*|*grimoire-web/dockerfile*|*grimoire-web/tailwind.config.*|*grimoire-web/makefile) echo "BLOCK:grimoire-web"; return ;;
    *eval/tasks*|*eval/scripts/*) echo "BLOCK:grimoire-qa"; return ;;
    # 하네스 영역 = 부트스트랩 게이트
    *.claude/agents/*|*.claude/skills/*|*.claude/scripts/*|*.claude/settings.json|*.claude/agents.md|*.claude/shared-contracts.md|*.claude/knowledge/*)
      if [ -f "$BOOTSTRAP_FLAG" ]; then echo "ALLOW"; else echo "BLOCK:grimoire-harness"; fi
      return ;;
    # 사용자 승인 영역
    *planning_grimoire.md) echo "BLOCK:USER_APPROVAL"; return ;;
    # 메인 직접 가능: 메모리/리포트/문서/오케스트레이션
    *) echo "ALLOW"; return ;;
  esac
}

classify_bash() {
  local c="$1"
  # 공백 정규화 (GAP C: 다중 공백/탭 → 단일 공백)
  local norm
  norm=$(printf '%s' "$c" | tr '\t' ' ' | tr -s ' ')

  # 변경성 git (commit/push/merge/rebase/reset --hard) — git -c, git -C 변형 포함
  case "$norm" in
    *"git commit"*|*"git push"*|*"git merge "*|*"git merge"|*"git mergetool"*|*"git rebase"*|*"git reset --hard"*) echo "BLOCK:mutating-git"; return ;;
    *"git "*" commit"*|*"git "*" push"*|*"git "*" merge "*|*"git "*" merge") echo "BLOCK:mutating-git"; return ;;  # git -C path commit / git -c k=v push (merge-base는 -base 접미사로 제외)
  esac
  # 배포/인프라
  case "$norm" in
    *"gcloud run deploy"*|*"gcloud sql"*|*"gcloud secrets"*|*"make deploy"*|*"deploy-prod"*|*"deploy-dev"*) echo "BLOCK:deploy"; return ;;
    *"az containerapp update"*|*"az containerapp secret"*|*"npm publish"*|*"npm install"*|*"npm i "*|*"npm ci"*) echo "BLOCK:deploy"; return ;;
  esac
  # 테스트/빌드/마이그레이션
  case "$norm" in
    *"npm test"*|*"npm run build"*|*"npx prisma migrate"*|*"npx jest"*|*"jest "*|*"vitest"*) echo "BLOCK:test-build"; return ;;
  esac
  # GAP D: Bash 리다이렉트/파일쓰기로 코드영역 우회 차단
  #   > 또는 >> 뒤 경로, tee 경로, cp/mv 대상이 코드영역이면 BLOCK
  #   2026-05-29 verifier 지적: fd 복제(2>&1)·stderr 리다이렉트(2>/dev/null)가 읽기명령(cat/ls/grep)을
  #   오차단하던 결함 수정 — fd 리다이렉트를 먼저 제거한 뒤 실제 파일쓰기 리다이렉트만 검사.
  #   2026-05-29 verifier CRITICAL: 기존 's/&>[^ ]*//g'가 &>코드경로를 통째 삭제해 ALLOW 통과시키던 결함.
  #     → &>는 /dev·/tmp 대상일 때만 strip (셋째 fd 패턴과 동일 방식). &>grimoire-server/src/...는 남겨 BLOCK.
  local nofd
  nofd=$(printf '%s' "$norm" | sed -E 's/[0-9]*>&[0-9-]+//g; s/&>>?[[:space:]]*\/(dev|tmp)\/[^ ]*//g; s/[0-9]+>[[:space:]]*\/(dev|tmp)\/[^ ]*//g')
  if printf '%s' "$nofd" | grep -qE '(&>>?|>>?|tee |cp |mv |dd |sed -i|truncate )'; then
    # 코드영역 경로가 (fd 리다이렉트 제거 후) 등장하면 차단
    case "$nofd" in
      *grimoire-server/src/*|*grimoire-server/test/*|*grimoire-server/prisma/*|*grimoire-web/src/*|*grimoire-web/app/*|*eval/tasks*)
        echo "BLOCK:bash-file-write-codearea"; return ;;
    esac
    # 하네스 영역 파일쓰기 (부트스트랩 게이트)
    case "$nofd" in
      *.claude/agents/*|*.claude/skills/*|*.claude/scripts/*|*.claude/settings.json)
        if [ -f "$BOOTSTRAP_FLAG" ]; then echo "ALLOW"; else echo "BLOCK:grimoire-harness"; fi
        return ;;
    esac
  fi
  # 그 외 = 읽기전용/안전 (git status/log/rev-parse/ls-remote/curl/wc/grep/cat/ls 등) → 메인 허용
  echo "ALLOW"
}

case "$KIND" in
  file) classify_path "$TARGET" ;;
  bash) classify_bash "$TARGET" ;;
  *) echo "ALLOW" ;;
esac
