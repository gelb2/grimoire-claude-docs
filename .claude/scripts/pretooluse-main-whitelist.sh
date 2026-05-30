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

# --- 읽기전용 단정(short-circuit) — substring 오탐 차단 (P4, 2026-05-30) ---
# 문제(감사 재현): `cat deploy-prod.sh` / `grep -rn "make deploy" .` / `echo "git push…"` 등
#   순수 읽기 명령이 인자에 트리거 문자열(deploy/push/npm install…)을 담았다는 이유로 오차단.
# 해법: "실행되는 실제 명령"으로 분류. 파이프/&&/||/; 각 세그먼트의 선두 토큰(env·cd 접두 제외)이
#   전부 읽기전용 도구로 *증명* 가능할 때만 ALLOW 조기반환. 증명 못하면 기존 차단 로직으로 fall-through.
# 안전 불변식: 이 단정은 ALLOW만 추가한다. mutation을 읽기전용으로 오분류해야만 가드가 약화되는데,
#   allowlist는 엄격(unknown=증명실패=fall-through)이고 mutator는 절대 등재하지 않으므로 약화 불가.
#   ★단, 코드영역 파일쓰기 리다이렉트(GAP D)는 선두토큰이 cat/echo여도 우회 금지 → 리다이렉트 있으면 단정 안 함.
_readonly_token() {
  # $1 = 세그먼트 선두 토큰(basename 적용 후). 읽기전용 도구면 0, 아니면 1.
  case "$1" in
    grep|rg|egrep|fgrep|jq|ls|cat|find|wc|head|tail|sort|uniq|comm|diff|test|'['|echo|printf|stat|file|which|basename|dirname|true|pwd|date) return 0 ;;
    *) return 1 ;;
  esac
}
_readonly_git_subcmd() {
  # $1 = git 서브커맨드. 읽기전용 git이면 0, 아니면 1. (merge-base는 읽기전용, merge/commit/push 등은 제외)
  case "$1" in
    status|log|diff|show|rev-list|rev-parse|ls-files|ls-remote|cat-file|branch|remote|config|describe|blame|shortlog|merge-base|name-rev|tag|reflog|whatchanged|grep) return 0 ;;
    *) return 1 ;;
  esac
}
# 명령 전체가 읽기전용으로 증명되면 0, 아니면 1 반환.
_command_is_provably_readonly() {
  local cmd="$1"
  # -1) 명령치환/프로세스치환($(...) `...` <(...) >(...))이 있으면 단정 금지.
  #     이 구문은 세그먼트 토크나이저가 못 보는 내부 명령을 품으므로(예: echo $(git push)),
  #     단정하면 가드가 약화됨 → 기존 substring 차단 로직으로 fall-through.
  case "$cmd" in
    *'$('*|*'`'*|*'<('*|*'>('*) return 1 ;;
  esac
  # 0) 코드영역/비-tmp 파일쓰기 리다이렉트가 있으면 단정 금지 (GAP D는 기존 로직이 판단).
  #    fd 리다이렉트(2>&1, 2>/dev/null, &>/dev/null 등 /dev·/tmp 대상)는 무해 — 제거 후 검사.
  local nofd
  nofd=$(printf '%s' "$cmd" | sed -E 's/[0-9]*>&[0-9-]+//g; s/&>>?[[:space:]]*\/(dev|tmp)\/[^ ]*//g; s/[0-9]+>[[:space:]]*\/(dev|tmp)\/[^ ]*//g')
  if printf '%s' "$nofd" | grep -qE '(&>>?|>>?|[[:space:]]tee[[:space:]]|^tee[[:space:]]|[[:space:]]dd[[:space:]]|sed -i|truncate )'; then
    return 1   # 파일쓰기 가능성 → 단정 안 함 (기존 GAP D 로직으로)
  fi
  # 1) 세그먼트 분리: | && || ; & → 개행
  local segs
  segs=$(printf '%s' "$cmd" | sed -E 's/\|\||&&|;|\||&/\n/g')
  local seg tok
  local IFS=$'\n'
  for seg in $segs; do
    # 앞뒤 공백 제거
    seg="${seg#"${seg%%[![:space:]]*}"}"
    seg="${seg%"${seg##*[![:space:]]}"}"
    [ -z "$seg" ] && continue
    # 선두 env-var 할당(FOO=bar ...) 접두 제거 (반복)
    while printf '%s' "$seg" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*='; do
      seg=$(printf '%s' "$seg" | sed -E 's/^[A-Za-z_][A-Za-z0-9_]*=[^ ]* *//')
    done
    # 선두 토큰
    tok=$(printf '%s' "$seg" | awk '{print $1}')
    [ -z "$tok" ] && continue
    # 선두가 cd → 디렉터리 이동(무해). 다음 세그먼트 계속.
    [ "$tok" = "cd" ] && continue
    # P4 회귀봉합(verifier 처방#1): 세그먼트 토큰에 find의 액션 술어(-exec/-execdir/-ok/-delete)가
    #   하나라도 있으면 단정 거부. `find ... -exec git push \;`는 `\;`로 세그먼트가 안 쪼개져
    #   단일 세그먼트가 되고 선두토큰 find가 읽기전용 allowlist에 들어 조기 ALLOW로 빠지는 회귀가
    #   발생함(OLD=BLOCK→NEW=ALLOW). -exec 내부 mutator는 기존 substring 차단으로 fall-through 시켜야 함.
    case " $seg " in
      *' -exec '*|*' -execdir '*|*' -ok '*|*' -okdir '*|*' -delete '*|*' -delete'|*' -exec'|*' -execdir'|*' -ok'|*' -okdir') return 1 ;;
    esac
    # basename (절대경로 도구 호출 /bin/cat 대응)
    local base="${tok##*/}"
    if [ "$base" = "git" ]; then
      # git: 다음 토큰(옵션 -c/-C는 건너뛰고)이 읽기전용 서브커맨드여야 함
      local sub
      sub=$(printf '%s' "$seg" | awk '{
        for (i=2;i<=NF;i++){
          if ($i=="-c"||$i=="-C"){i++; continue}      # git -c k=v / git -C path
          if (substr($i,1,1)=="-") continue             # 기타 옵션
          print $i; exit
        }
      }')
      # 2026-05-30 파괴봉합: branch/tag는 읽기전용 allowlist에 있으나 삭제 플래그(-D/-d/--delete)가
      #   붙으면 파괴 명령(`git branch -D`/`git tag -d`)이므로 읽기전용 단정 거부 → fall-through →
      #   _command_destructive_verb가 BLOCK. (순수 강화: 평문 `git branch`/`git tag`/`-a`/`-l`은 ALLOW 유지)
      if [ "$sub" = "branch" ] || [ "$sub" = "tag" ]; then
        case " $seg " in
          *' -D '*|*' -D'|*' -d '*|*' -d'|*' --delete '*|*' --delete'|*' -D='*|*' -d='*) return 1 ;;
        esac
      fi
      if _readonly_git_subcmd "$sub"; then continue; else return 1; fi
    fi
    if _readonly_token "$base"; then continue; else return 1; fi
  done
  return 0
}

# --- 파괴 명령 단정(2026-05-30 verifier 갭 봉합) — substring 금지, 명령위치 기준 ---
# 갭(verifier 확인): 메인 가드가 git-mutation/deploy/test/코드쓰기 substring만 막아
#   rm -rf / find -delete / chmod / mv / dd / git clean·stash·checkout --·restore 등
#   파괴 명령이 메인에서 ALLOW로 통과(OLD=NEW). 읽기전용 short-circuit이 먼저 ALLOW를 조기반환하므로
#   여기 도달하는 명령은 "읽기전용으로 증명 못 한" 것뿐 — 그중 실제 파괴 verb만 BLOCK.
# 설계: _command_is_provably_readonly와 동일 세그먼트 토크나이저(세그먼트 분리 → env·cd 접두 제거 →
#   선두 토큰 → basename → git 서브커맨드 처리)를 재활용. substring(rm/mv 문자열) 절대 금지 →
#   form/alarm/경로명/`grep rm` 오탐 없음. 파괴 verb면 0(BLOCK), 아니면 1(파괴 아님).
_command_destructive_verb() {
  local cmd="$1"
  # 세그먼트 분리: | && || ; & → 개행 (_command_is_provably_readonly와 동일)
  local segs
  segs=$(printf '%s' "$cmd" | sed -E 's/\|\||&&|;|\||&/\n/g')
  local seg tok
  local IFS=$'\n'
  for seg in $segs; do
    # 앞뒤 공백 제거
    seg="${seg#"${seg%%[![:space:]]*}"}"
    seg="${seg%"${seg##*[![:space:]]}"}"
    [ -z "$seg" ] && continue
    # 선두 env-var 할당(FOO=bar ...) 접두 제거 (반복)
    while printf '%s' "$seg" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*='; do
      seg=$(printf '%s' "$seg" | sed -E 's/^[A-Za-z_][A-Za-z0-9_]*=[^ ]* *//')
    done
    tok=$(printf '%s' "$seg" | awk '{print $1}')
    [ -z "$tok" ] && continue
    [ "$tok" = "cd" ] && continue
    local base="${tok##*/}"
    # 1) 선두 명령이 find인 경우: 파괴 술어(-delete) 또는 -exec계 mutator 검사.
    #    find -name/-type 등 비파괴 술어만 있으면 통과(과차단 0). 단 short-circuit이 이미
    #    -exec/-delete 있는 find는 readonly 단정을 거부했으므로 여기까지 옴.
    if [ "$base" = "find" ]; then
      # -delete 술어 → 파괴
      case " $seg " in
        *' -delete '*|*' -delete') return 0 ;;
      esac
      # -exec/-execdir/-ok/-okdir 뒤 첫 토큰(mutator) 추출 → 파괴 verb면 BLOCK.
      #   (find -exec git push 는 기존 mutating-git substring이 별도로 잡지만, 여기서도 정합)
      local fx
      fx=$(printf '%s' "$seg" | awk '{
        for (i=1;i<=NF;i++){
          if ($i=="-exec"||$i=="-execdir"||$i=="-ok"||$i=="-okdir"){
            if (i+1<=NF){print $(i+1); exit}
          }
        }
      }')
      if [ -n "$fx" ]; then
        local fxb="${fx##*/}"
        case "$fxb" in
          rm|rmdir|mv|chmod|chown|dd|truncate|shred|unlink|sh.|sh|bash) return 0 ;;
          git) return 0 ;;
        esac
      fi
      continue
    fi
    # 2) 파일시스템 파괴 verb (세그먼트 선두 명령 위치)
    case "$base" in
      rm|rmdir|mv|chmod|chown|dd|truncate|shred|unlink) return 0 ;;
    esac
    # 3) 파괴 git 서브커맨드
    if [ "$base" = "git" ]; then
      local sub
      sub=$(printf '%s' "$seg" | awk '{
        for (i=2;i<=NF;i++){
          if ($i=="-c"||$i=="-C"){i++; continue}      # git -c k=v / git -C path
          if (substr($i,1,1)=="-") continue             # 기타 옵션
          print $i; exit
        }
      }')
      case "$sub" in
        clean|stash|restore|rm) return 0 ;;
        checkout)
          # 브랜치 전환(git checkout <branch>)은 비파괴 → 통과.
          #   파괴 형태는 `git checkout -- <path>` / `git checkout .`(현 디렉터리 작업트리 복원)만.
          case " $seg " in
            *' -- '*|*' -- '|*' . '*|*' .') return 0 ;;
          esac
          ;;
        branch)
          # 브랜치 삭제(-D/-d)만 파괴. 목록(git branch)·생성은 비파괴.
          case " $seg " in
            *' -D '*|*' -D'|*' -d '*|*' -d'|*' --delete '*|*' --delete'|*' -D='*|*' -d='*) return 0 ;;
          esac
          ;;
        tag)
          # 태그 삭제(-d/--delete)만 파괴.
          case " $seg " in
            *' -d '*|*' -d'|*' --delete '*|*' --delete') return 0 ;;
          esac
          ;;
        push)
          # 강제 push만 (일반 push는 기존 mutating-git이 별도 차단)
          case " $seg " in
            *' --force '*|*' --force'|*' -f '*|*' -f'|*' --force-with-lease'*) return 0 ;;
          esac
          ;;
      esac
    fi
  done
  return 1
}

classify_bash() {
  local c="$1"
  # 공백 정규화 (GAP C: 다중 공백/탭 → 단일 공백)
  local norm
  norm=$(printf '%s' "$c" | tr '\t' ' ' | tr -s ' ')

  # P4: 명령 전체가 읽기전용으로 증명되면 인자 내용(deploy/push 등) 무관 ALLOW.
  #     (증명 실패 시 아래 기존 차단 로직으로 그대로 진행 — 가드 약화 0)
  if _command_is_provably_readonly "$norm"; then echo "ALLOW"; return; fi

  # 파괴 명령 차단(2026-05-30 verifier 갭 봉합) — 순수 가산. 읽기전용 short-circuit 통과 후 평가하므로
  #   find -name·grep rm·경로내 rm 같은 읽기전용은 이미 위에서 ALLOW로 빠져 여기 안 옴 → 과차단 0.
  #   명령위치 토크나이저로 실제 파괴 verb만 검출(substring 아님).
  if _command_destructive_verb "$norm"; then echo "BLOCK:destructive-command"; return; fi

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
    # P4(verifier 처방#2): 경로 매칭은 소문자 사본으로 — `> GRIMOIRE-SERVER/src/` 대문자 우회 차단.
    #   (classify_path와 동일한 macOS 대소문자무시 FS 대응. 순수 강화: BLOCK 범위만 넓힘.)
    local nofd_lc
    nofd_lc=$(printf '%s' "$nofd" | tr 'A-Z' 'a-z')
    # 코드영역 경로가 (fd 리다이렉트 제거 후) 등장하면 차단
    case "$nofd_lc" in
      *grimoire-server/src/*|*grimoire-server/test/*|*grimoire-server/prisma/*|*grimoire-web/src/*|*grimoire-web/app/*|*eval/tasks*)
        echo "BLOCK:bash-file-write-codearea"; return ;;
    esac
    # 하네스 영역 파일쓰기 (부트스트랩 게이트)
    case "$nofd_lc" in
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
