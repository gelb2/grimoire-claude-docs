#!/usr/bin/env bash
# sensor-selftest.sh — 센서 fire 자기검증 (bash 3.2 호환 전면 재작성, 2026-05-29 정직성 사태 후속)
#
# 목적: 센서가 "잡으려는 위반"을 격리 임시 fixture/인자로 주입해
#       센서가 실제로 fire(exit 변화)하는지 증명하고 결과를 박제한다.
#       — 이전 버전은 FIXTURE_MAP 19개 중 15개가 유령 센서(실파일 0건) + bash 3.2
#         `declare -A` 미지원으로 line 304에서 실행 자체 불가였음(거짓 인벤토리).
#
# ── 정직성 원칙 (거품 0) ──
#   "전부 fire 가능"은 거짓이다. 56 센서를 grimoire-harness가 전수 Read하여 분류한 결과:
#     INJECTABLE 3  — 격리 temp/인자로 clean fire 증명 가능 (자동 측정 대상)
#     GUARDED    4  — 원리상 INJECTABLE이나 실 state/git-index/incident-log/baseline≠0
#                     교란이 불가피 → 자동 보류(사유 기록). secret-leak/loop-detection은
#                     verifier가 수동 1회 실증.
#     EXISTENCE  32 — 필수 패턴이 "있어야" PASS. 실 tracked 소스를 깨야만 fire →
#                     격리 fire 불가가 정상 (실소스 영구변경 0 원칙과 양립 불가)
#     EXTERNAL   14 — curl/az/git/transcript/build·test/live-state 의존 → 격리 불가
#     STUB        3 — 항상 exit0(정보성/적재 인프라, detector 아님) → fire 불가가 정상
#
# ── 판정 (변화 기반 — baseline≠0/역 exit convention 견딤) ──
#   FIRE_OK   = fire_rc != base_rc  AND  restore_rc == base_rc
#               (주입이 센서 판정을 바꿨고, 제거 후 원복됨 — 절대 exit값이 아니라 "변화"를 봄.
#                cost-margin/credit-atomicity처럼 FAIL→exit0 역convention이어도 변화로 포착)
#   FIRE_FAIL = INJECTABLE인데 위 조건 불충족 (센서가 안 잡거나 원복 실패) — 그대로 기록
#   SKIP      = GUARDED/EXISTENCE/EXTERNAL/STUB (분류 + 사유 기록)
#
# 사용:
#   sensor-selftest.sh --list            # 56 분류 일람 + 카운트
#   sensor-selftest.sh --all             # INJECTABLE fire 측정 + 나머지 SKIP 기록
#   sensor-selftest.sh <sensor-name>     # 단일 (sensor- prefix 자동 보정)
#
# 절대 규정:
#   - fixture는 격리 임시 파일/인자만 (실 소스 영구변경 0)
#   - 종료 시 잔존 fixture 0 확인 (verify_no_residue)
#   - secret fixture는 가짜값만 (실 secret 금지)
#   - 거짓 금지: 안 잡히면 FIRE_FAIL 그대로 기록
set -uo pipefail

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
SCRIPTS_DIR="$ROOT/.claude/scripts"
STATE_DIR="$ROOT/.claude/state"
RESULTS="$STATE_DIR/sensor-selftest-results.jsonl"
mkdir -p "$STATE_DIR"

TRACKED_FIXTURES=()
track() { TRACKED_FIXTURES+=("$1"); }

# 센서를 깨끗한 bash(프로필 비간섭)로 실행하고 exit code만 반환
run_rc() {
  local s="$1"; shift
  [ -f "$s" ] || { echo 127; return; }
  local rc=0
  /bin/bash --noprofile --norc "$s" "$@" >/dev/null 2>&1 || rc=$?
  echo "$rc"
}

# ═════════════════════════════════════════════════════════════
# 분류 (bash 3.2: declare -A 불가 → 공백구분 리스트 + case 매칭)
# 출처: grimoire-harness 56센서 전수 Read 분류 (2026-05-29). 실측 근거.
# ═════════════════════════════════════════════════════════════
INJECTABLE_LIST="sensor-fake-email-leak sensor-knowledge-drift sensor-red-team-source-whitelist"
STUB_LIST="sensor-feedback-promotion sensor-hit-rate-report sensor-log"
EXTERNAL_LIST="sensor-adversarial-pre-commit sensor-azure-env-secret sensor-chat-domain sensor-context-budget sensor-deploy-drift sensor-deploy-health sensor-eval-trend sensor-harness-self-diagnose sensor-hook-effectiveness sensor-orchestration-ratio sensor-security-gate sensor-server sensor-skill-invocation-rate sensor-web"
EXISTENCE_LIST="sensor-admin-credit-ui sensor-agent-interaction sensor-agent-priority-labels sensor-audit-log-before-after sensor-audit-retention-policy sensor-chat-charge-tier sensor-circuit-breaker-policy sensor-cost-margin sensor-credit-atomicity sensor-credit-denomination sensor-credit-overhaul-recalc sensor-credit-source-accounting sensor-docs-sync sensor-fk-cascade-policy sensor-harness-cross-ref sensor-instruction-degradation sensor-oauth-email-verification sensor-partial-refund sensor-payment-idempotency sensor-payment-race-condition sensor-payment-reconciliation sensor-payment-retry-reuse sensor-payment-status-mapping sensor-polar-timeout-policy sensor-refund-atomicity sensor-retry-dedup sensor-shared-contracts sensor-slug-login sensor-sms-service-port sensor-subscription-pool-no-rollover sensor-user-soft-delete-policy sensor-webhook-dlq"

# 출력: "CLASS|reason"
classify() {
  local n="$1"
  case "$n" in
    sensor-response-zero-realtime) echo "GUARDED|fire 시 incident-log.jsonl(P20 박제파일) append side-effect → 자동보류"; return ;;
    sensor-secret-leak)            echo "GUARDED|git ls-files 기반: 값≥30 alnum + git add 인덱스 교란 필요 → verifier 수동실증"; return ;;
    sensor-loop-detection)         echo "GUARDED|실 state(오늘 data, 대용량) PREEXIST + 스키마 date/file → backup/restore 필요, 자동보류"; return ;;
    sensor-skill-paths-coverage)   echo "GUARDED|baseline 이미 exit2(기존 skill frontmatter FAIL 중) → clean 전이 증명 불가"; return ;;
  esac
  case " $INJECTABLE_LIST " in *" $n "*) echo "INJECTABLE|격리 temp/인자로 fire 증명 가능"; return ;; esac
  case " $STUB_LIST "       in *" $n "*) echo "STUB|항상 exit0(정보성/적재 인프라, detector 아님) → fire 불가가 정상"; return ;; esac
  case " $EXTERNAL_LIST "   in *" $n "*) echo "EXTERNAL|외부의존(curl/az/git/transcript/build·test/live-state) → 격리 불가"; return ;; esac
  case " $EXISTENCE_LIST "  in *" $n "*) echo "EXISTENCE|tracked 실파일 패턴/카운트 의존 → 격리 fire 불가가 정상(실소스 변경 금지)"; return ;; esac
  echo "UNCLASSIFIED|분류 누락 — 점검 필요"
}

# ═════════════════════════════════════════════════════════════
# INJECTABLE probe: 센서별 baseline→inject→fire→cleanup→restore
# 출력: "base fire rest" (exit code 3개)
# ═════════════════════════════════════════════════════════════
probe() {
  local s base fire rest f
  case "$1" in
    sensor-fake-email-leak)
      # grep -rn '@grimoire.app' (git ls-files 아님) → untracked .ts 스캔됨 (harness 실측 CONFIRM)
      s="$SCRIPTS_DIR/sensor-fake-email-leak.sh"
      f="$ROOT/grimoire-server/src/.selftest-fixture-fakeemail.ts"
      base=$(run_rc "$s")
      printf 'export const SUPPORT = "noreply@grimoire.app";\n' > "$f"; track "$f"
      fire=$(run_rc "$s")
      rm -f "$f"
      rest=$(run_rc "$s")
      echo "$base $fire $rest" ;;
    sensor-knowledge-drift)
      # 어디서도 참조 안 되는 비-점 .md → orphan + README 누락 = WARN(exit1). baseline 0(클린)
      s="$SCRIPTS_DIR/sensor-knowledge-drift.sh"
      f="$ROOT/.claude/knowledge/selftest-orphan.md"
      base=$(run_rc "$s")
      printf '# selftest orphan (임시 fixture — 자동 제거)\n' > "$f"; track "$f"
      fire=$(run_rc "$s")
      rm -f "$f"
      rest=$(run_rc "$s")
      echo "$base $fire $rest" ;;
    sensor-red-team-source-whitelist)
      # 인자 기반: whitelist good → 0, whitelist 외 → 1. 상태 무변경 → restore=base
      s="$SCRIPTS_DIR/sensor-red-team-source-whitelist.sh"
      base=$(run_rc "$s" "https://docs.anthropic.com")
      fire=$(run_rc "$s" "https://evil.example.test")
      echo "$base $fire $base" ;;
    *)
      echo "NA NA NA" ;;
  esac
}

# ═════════════════════════════════════════════════════════════
# 잔존 검증: selftest fixture 패턴이 남아있는지 스캔
# ═════════════════════════════════════════════════════════════
verify_no_residue() {
  local residue=()
  while IFS= read -r p; do [ -n "$p" ] && residue+=("$p"); done < <(
    find "$ROOT/grimoire-server/src" "$ROOT/.claude/knowledge" \
      \( -name '.selftest-fixture-*' -o -name 'selftest-orphan.md' \) \
      2>/dev/null
  )
  if [ ${#residue[@]} -gt 0 ]; then
    echo "RESIDUE_FOUND"
    printf '  %s\n' "${residue[@]}"
    return 1
  fi
  echo "RESIDUE_CLEAN"
  return 0
}

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))' 2>/dev/null || printf '"%s"' "$1"; }

# ═════════════════════════════════════════════════════════════
# 단일 센서 실행
# ═════════════════════════════════════════════════════════════
run_one() {
  local name="$1"
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local script="$SCRIPTS_DIR/${name}.sh"
  if [ ! -f "$script" ]; then printf '%-38s NOT_FOUND\n' "$name"; return; fi

  local cr class reason
  cr="$(classify "$name")"
  class="${cr%%|*}"
  reason="${cr#*|}"

  if [ "$class" != "INJECTABLE" ]; then
    printf '%-38s SKIP[%-11s] %s\n' "$name" "$class" "$reason"
    printf '{"ts":"%s","sensor":"%s","verdict":"SKIP","class":"%s","reason":%s}\n' \
      "$ts" "$name" "$class" "$(printf '%s' "$reason" | json_escape)" >> "$RESULTS"
    return
  fi

  local res base fire rest
  res="$(probe "$name")"
  base="$(printf '%s' "$res" | awk '{print $1}')"
  fire="$(printf '%s' "$res" | awk '{print $2}')"
  rest="$(printf '%s' "$res" | awk '{print $3}')"

  local verdict
  if [ "$fire" != "$base" ] && [ "$rest" = "$base" ]; then
    verdict="FIRE_OK"
  else
    verdict="FIRE_FAIL"
  fi
  printf '%-38s %-9s base=%s fire=%s restore=%s\n' "$name" "$verdict" "$base" "$fire" "$rest"
  printf '{"ts":"%s","sensor":"%s","verdict":"%s","class":"INJECTABLE","base_rc":%s,"fire_rc":%s,"restore_rc":%s}\n' \
    "$ts" "$name" "$verdict" "$base" "$fire" "$rest" >> "$RESULTS"
}

# ═════════════════════════════════════════════════════════════
# 모드
# ═════════════════════════════════════════════════════════════
sensor_names() {
  ls "$SCRIPTS_DIR"/sensor-*.sh 2>/dev/null | xargs -n1 basename | sed 's/\.sh$//' | grep -v '^sensor-selftest$'
}

list_all() {
  echo "=== 센서 분류 일람 (실측 분류 — grimoire-harness 56 전수 Read) ==="
  local inj=0 grd=0 exi=0 ext=0 stb=0 unc=0 nm cr class
  while IFS= read -r nm; do
    [ -z "$nm" ] && continue
    cr="$(classify "$nm")"; class="${cr%%|*}"
    case "$class" in
      INJECTABLE)   inj=$((inj+1)); printf '  [INJECTABLE]   %s\n' "$nm" ;;
      GUARDED)      grd=$((grd+1)); printf '  [GUARDED]      %s — %s\n' "$nm" "${cr#*|}" ;;
      EXISTENCE)    exi=$((exi+1)) ;;
      EXTERNAL)     ext=$((ext+1)) ;;
      STUB)         stb=$((stb+1)) ;;
      *)            unc=$((unc+1)); printf '  [UNCLASSIFIED] %s\n' "$nm" ;;
    esac
  done < <(sensor_names)
  echo "---"
  printf 'INJECTABLE=%d GUARDED=%d EXISTENCE=%d EXTERNAL=%d STUB=%d UNCLASSIFIED=%d  합=%d\n' \
    "$inj" "$grd" "$exi" "$ext" "$stb" "$unc" "$((inj+grd+exi+ext+stb+unc))"
  echo "(EXISTENCE/EXTERNAL/STUB는 격리 fire 불가가 정상 — 일람 생략. GUARDED만 사유 표시.)"
}

run_all() {
  echo "=== sensor-selftest --all ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="
  echo "정직성: INJECTABLE만 fire 측정. 나머지는 SKIP(격리 fire 불가가 정상)."
  echo ""
  local fire_ok=0 fire_fail=0 skip=0 nm last
  while IFS= read -r nm; do
    [ -z "$nm" ] && continue
    run_one "$nm"
    last="$(tail -1 "$RESULTS" 2>/dev/null)"
    case "$last" in
      *'"verdict":"FIRE_OK"'*)   fire_ok=$((fire_ok+1)) ;;
      *'"verdict":"FIRE_FAIL"'*) fire_fail=$((fire_fail+1)) ;;
      *'"verdict":"SKIP"'*)      skip=$((skip+1)) ;;
    esac
  done < <(sensor_names)
  echo "─────────────────────────────────────────────"
  printf 'FIRE_OK=%d  FIRE_FAIL=%d  SKIP=%d\n' "$fire_ok" "$fire_fail" "$skip"
  echo "  (FIRE_OK 기대=3: fake-email-leak / knowledge-drift / red-team-source-whitelist)"
  echo "─────────────────────────────────────────────"
  echo "잔존 fixture 검증:"
  verify_no_residue
}

main() {
  local arg="${1:-}"
  case "$arg" in
    --list) list_all ;;
    --all)  run_all ;;
    "")     echo "usage: sensor-selftest.sh [--list|--all|<sensor-name>]"; exit 1 ;;
    *)
      local nm="$arg"; case "$nm" in sensor-*) ;; *) nm="sensor-$nm" ;; esac
      run_one "$nm"
      echo "잔존 검증:"; verify_no_residue ;;
  esac
}

main "$@"
