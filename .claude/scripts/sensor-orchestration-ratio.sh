#!/usr/bin/env bash
# sensor-orchestration-ratio.sh — 패턴 1 (오케스트레이션 분리) 측정 sensor (P2)
#
# 측정 정의:
#   orchestration_ratio = task_calls / (main_edits + main_writes)
#   - main_edits: 메인 Claude가 직접 호출한 Edit 도구 (isSidechain=false + role=assistant + name=Edit)
#   - main_writes: 메인 Claude가 직접 호출한 Write 도구
#   - task_calls: 메인 Claude가 spawn한 subagent 호출 (Task tool, isSidechain=false)
#
# 데이터 소스:
#   - $HOME/.claude/projects/-Users-sokol-Desktop-Git-ProjectGrimoire/*.jsonl
#   - 최근 7일 (mtime 기준)
#
# 임계값 (Fowler "Steering Loop" + 패턴 1 권장):
#   - ratio ≥ 0.20: PASS (5건당 1건 이상 subagent 위임)
#   - 0.05 ≤ ratio < 0.20: WARN (위임 부족)
#   - ratio < 0.05: FAIL (메인이 사실상 모두 직접 — 패턴 1 위배)
#
# 2026-05-03 #10_6 묶음 II 보강 — 메타 세션 정밀화:
#   - claude/memory/docs/research 등 메타 도메인 비율 ≥ 70% 시 FAIL → META_PASS 다운그레이드
#   - 사유: 책 §15.7 매트릭스 + agent-interaction-matrix.md "메인 직접 처리" 정합 (조율 작업)
#   - jsonl flush 지연 검증: 가장 최근 세션 mtime ≤ 5분 시 "in-progress" 마크 (다음 측정 보강 예상)
#
# 추가 산출물:
#   - subagent type 분포 (어떤 에이전트가 자주 호출되는지)
#   - sidechain edits (subagent 내부 작업량)
#
# 적재 위치:
#   - .claude/state/orchestration-ratio.jsonl (시계열 누적)

set -u

LOG_DIR="/Users/sokol/Desktop/Git/ProjectGrimoire/.claude/state"
RATIO_FILE="$LOG_DIR/orchestration-ratio.jsonl"
JSONL_DIR="$HOME/.claude/projects/-Users-sokol-Desktop-Git-ProjectGrimoire"

mkdir -p "$LOG_DIR"

QUIET=0
STRICT=0
DAYS=7
for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=1 ;;
    --strict) STRICT=1 ;;
    --days=*) DAYS="${arg#--days=}" ;;
  esac
done

if [ ! -d "$JSONL_DIR" ]; then
  [ "$QUIET" -eq 0 ] && echo "[orchestration-ratio] JSONL 디렉토리 없음: $JSONL_DIR"
  exit 0
fi

[ "$QUIET" -eq 0 ] && echo "=== Orchestration Ratio Sensor (P2) ==="
[ "$QUIET" -eq 0 ] && echo "측정 시점: $(date +'%Y-%m-%d %H:%M:%S')"
[ "$QUIET" -eq 0 ] && echo "분석 범위: 최근 ${DAYS}일"
[ "$QUIET" -eq 0 ] && echo ""

# Python으로 JSONL 파싱 (sed/awk로는 불가능)
export JSONL_DIR DAYS
RESULT=$(python3 <<'PYEOF'
import json, glob, os, time, sys
from collections import Counter

JSONL_DIR = os.environ['JSONL_DIR']
DAYS = int(os.environ['DAYS'])

cutoff = time.time() - DAYS * 86400
files = sorted(
    glob.glob(JSONL_DIR + "/*.jsonl"),
    key=lambda f: os.path.getmtime(f),
    reverse=True
)
recent = [f for f in files if os.path.getmtime(f) > cutoff]

main_edits = 0
main_writes = 0
task_calls = 0
sidechain_edits = 0
sidechain_writes = 0
stypes = Counter()
file_count = len(recent)

# 도메인 분류 (§15.7 위임 가치 가이드라인 적용)
domain_counter = Counter()  # 메인 직접 작업의 도메인 분포

def classify_domain(path):
    if not path:
        return 'unknown'
    if '/grimoire-server/' in path:
        return 'server'
    if '/grimoire-web/' in path:
        return 'web'
    if '/.claude/' in path:
        return 'claude'
    if '/research/' in path:
        return 'research'
    if '/memory/' in path:
        return 'memory'
    if '/docs/' in path:
        return 'docs'
    if path.endswith('.md') and 'ProjectGrimoire/' in path:
        return 'root-doc'
    return 'other'

for fpath in recent:
    try:
        with open(fpath) as f:
            for line in f:
                try:
                    obj = json.loads(line)
                except:
                    continue
                msg = obj.get('message', {})
                if not isinstance(msg, dict):
                    continue
                if msg.get('role') != 'assistant':
                    continue
                content = msg.get('content', [])
                if not isinstance(content, list):
                    continue
                sidechain = obj.get('isSidechain', False)
                for c in content:
                    if not isinstance(c, dict) or c.get('type') != 'tool_use':
                        continue
                    name = c.get('name', '')
                    if name == 'Edit':
                        if sidechain:
                            sidechain_edits += 1
                        else:
                            main_edits += 1
                            fp = c.get('input', {}).get('file_path', '')
                            domain_counter[classify_domain(fp)] += 1
                    elif name == 'Write':
                        if sidechain:
                            sidechain_writes += 1
                        else:
                            main_writes += 1
                            fp = c.get('input', {}).get('file_path', '')
                            domain_counter[classify_domain(fp)] += 1
                    elif name in ('Task', 'Agent') and not sidechain:  # 2026-05-06 INCIDENT KK': Claude Code tool name이 'Agent'로 변경됨 — 'Task'만 매칭하던 결함 → 7일간 0건 거짓 측정 → 메인 Claude 거짓 보고 사슬 유발
                        task_calls += 1
                        stype = c.get('input', {}).get('subagent_type', 'unknown')
                        stypes[stype] += 1
    except Exception as e:
        print("WARN: " + fpath + " skip (" + str(e) + ")", file=sys.stderr)

m_total = main_edits + main_writes
ratio = task_calls / m_total if m_total > 0 else 0

# §15.7 합치 분석
unique_domains = len([d for d, c in domain_counter.items() if c > 0])
multi_domain_pct = sum(c for d, c in domain_counter.items() if d not in ('claude', 'memory', 'docs', 'research', 'root-doc')) / m_total if m_total > 0 else 0

# 2026-05-03 묶음 II — 메타 세션 비율 (FAIL → META_PASS 다운그레이드 판정용)
meta_pct = sum(c for d, c in domain_counter.items() if d in ('claude', 'memory', 'docs', 'research', 'root-doc')) / m_total if m_total > 0 else 0

# jsonl in-progress 검증 — 가장 최근 mtime ≤ 5분 시 마크
in_progress = False
if recent:
    most_recent_mtime = max(os.path.getmtime(f) for f in recent)
    if time.time() - most_recent_mtime < 300:  # 5 minutes
        in_progress = True

# stdout: pipe-separated for shell parsing
print("FILES|" + str(file_count))
print("MAIN_EDITS|" + str(main_edits))
print("MAIN_WRITES|" + str(main_writes))
print("MAIN_TOTAL|" + str(m_total))
print("TASK_CALLS|" + str(task_calls))
print("SIDECHAIN_EDITS|" + str(sidechain_edits))
print("SIDECHAIN_WRITES|" + str(sidechain_writes))
print("RATIO|" + ("%.4f" % ratio))
print("UNIQUE_DOMAINS|" + str(unique_domains))
print("MULTI_DOMAIN_PCT|" + ("%.4f" % multi_domain_pct))
print("META_PCT|" + ("%.4f" % meta_pct))
print("IN_PROGRESS|" + ("1" if in_progress else "0"))
for s, c in stypes.most_common():
    print("STYPE|" + s + "|" + str(c))
for d, c in domain_counter.most_common():
    print("DOMAIN|" + d + "|" + str(c))
PYEOF
)

# 결과 파싱
FILES=$(echo "$RESULT" | grep "^FILES|" | cut -d'|' -f2)
MAIN_EDITS=$(echo "$RESULT" | grep "^MAIN_EDITS|" | cut -d'|' -f2)
MAIN_WRITES=$(echo "$RESULT" | grep "^MAIN_WRITES|" | cut -d'|' -f2)
MAIN_TOTAL=$(echo "$RESULT" | grep "^MAIN_TOTAL|" | cut -d'|' -f2)
TASK_CALLS=$(echo "$RESULT" | grep "^TASK_CALLS|" | cut -d'|' -f2)
SIDECHAIN_EDITS=$(echo "$RESULT" | grep "^SIDECHAIN_EDITS|" | cut -d'|' -f2)
SIDECHAIN_WRITES=$(echo "$RESULT" | grep "^SIDECHAIN_WRITES|" | cut -d'|' -f2)
RATIO=$(echo "$RESULT" | grep "^RATIO|" | cut -d'|' -f2)
UNIQUE_DOMAINS=$(echo "$RESULT" | grep "^UNIQUE_DOMAINS|" | cut -d'|' -f2)
MULTI_DOMAIN_PCT=$(echo "$RESULT" | grep "^MULTI_DOMAIN_PCT|" | cut -d'|' -f2)
META_PCT=$(echo "$RESULT" | grep "^META_PCT|" | cut -d'|' -f2)
IN_PROGRESS=$(echo "$RESULT" | grep "^IN_PROGRESS|" | cut -d'|' -f2)

if [ "$QUIET" -eq 0 ]; then
  echo "분석 jsonl 파일: $FILES"
  echo "메인 Edit / Write: $MAIN_EDITS / $MAIN_WRITES (총 $MAIN_TOTAL)"
  echo "메인 → Task 호출: $TASK_CALLS"
  echo "Sidechain Edit / Write: $SIDECHAIN_EDITS / $SIDECHAIN_WRITES"
  echo "Ratio: $RATIO (Task / Main code edits)"
  echo ""
  echo "도메인 분포 (§15.7 위임 가치 분석):"
  echo "$RESULT" | grep "^DOMAIN|" | while IFS='|' read -r _ d c; do
    echo "  $d: $c"
  done
  echo "  → unique 도메인: $UNIQUE_DOMAINS / 위임 가치 도메인(server/web) 비율: $MULTI_DOMAIN_PCT"
  echo ""
  echo "Subagent 분포:"
  echo "$RESULT" | grep "^STYPE|" | while IFS='|' read -r _ s c; do
    echo "  $s: $c"
  done
  echo ""
  # §15.7 합치 분석
  echo "=== §15.7 위임 가치 합치 분석 ==="
  if [ "$MAIN_TOTAL" -ge 10 ]; then
    if awk -v p="$MULTI_DOMAIN_PCT" -v r="$RATIO" 'BEGIN{exit !(p > 0.30 && r < 0.05)}'; then
      echo "[§15.7] WARN — server/web 작업 비율 $MULTI_DOMAIN_PCT > 30%인데 ratio $RATIO < 0.05"
      echo "        → 다중 도메인 작업을 메인이 직접 처리 중. subagent 위임 후보 다수 누락 가능."
    elif awk -v u="$UNIQUE_DOMAINS" -v r="$RATIO" 'BEGIN{exit !(u >= 4 && r < 0.05)}'; then
      echo "[§15.7] WARN — unique 도메인 $UNIQUE_DOMAINS ≥ 4개인데 ratio $RATIO < 0.05"
      echo "        → 복잡한 다중 도메인 세션. server/web 위임 시도 권장."
    else
      echo "[§15.7] OK — 도메인 분포 + ratio 합치"
    fi
  else
    echo "[§15.7] SKIP — 표본 부족 ($MAIN_TOTAL < 10)"
  fi
  echo ""
fi

# 임계값 판정
RESULT_STATUS="PASS"
EXIT_CODE=0

if [ "$MAIN_TOTAL" -lt 10 ]; then
  RESULT_STATUS="SKIP"
  [ "$QUIET" -eq 0 ] && echo "[RESULT] SKIP — 메인 작업 표본 부족 ($MAIN_TOTAL < 10)"
elif awk -v r="$RATIO" 'BEGIN{exit !(r < 0.05)}'; then
  # 2026-05-03 묶음 II — 메타 세션 다운그레이드 판정
  if awk -v m="$META_PCT" 'BEGIN{exit !(m >= 0.70)}'; then
    RESULT_STATUS="META_PASS"
    [ "$QUIET" -eq 0 ] && echo "[RESULT] META_PASS — ratio $RATIO < 0.05이지만 메타 세션 ($META_PCT ≥ 70% claude/memory/docs/research)"
    [ "$QUIET" -eq 0 ] && echo "        → §15.7 매트릭스 정합 (메타 작업은 메인 직접 처리가 적합 — 조율 자체)"
  else
    RESULT_STATUS="FAIL"
    EXIT_CODE=$([ "$STRICT" -eq 1 ] && echo 1 || echo 0)
    [ "$QUIET" -eq 0 ] && echo "[RESULT] FAIL — ratio $RATIO < 0.05 (패턴 1 위배: 메인이 사실상 모두 직접 작업)"
    [ "$QUIET" -eq 0 ] && echo "        → server/web 작업 비율 $MULTI_DOMAIN_PCT, 메타 비율 $META_PCT"
  fi
elif awk -v r="$RATIO" 'BEGIN{exit !(r < 0.20)}'; then
  RESULT_STATUS="WARN"
  [ "$QUIET" -eq 0 ] && echo "[RESULT] WARN — ratio $RATIO < 0.20 (subagent 위임 부족)"
else
  [ "$QUIET" -eq 0 ] && echo "[RESULT] PASS — ratio $RATIO ≥ 0.20"
fi

# in-progress 마크 (다음 측정 보강 안내)
if [ "$IN_PROGRESS" = "1" ] && [ "$QUIET" -eq 0 ]; then
  echo "[NOTE] in-progress 세션 검출 (mtime ≤ 5분) — 다음 측정에서 추가 박제 예상"
fi

# JSONL 적재 (§15.7 합치 데이터 포함)
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
printf '{"ts":"%s","files":%s,"main_edits":%s,"main_writes":%s,"main_total":%s,"task_calls":%s,"sidechain_edits":%s,"sidechain_writes":%s,"ratio":%s,"status":"%s","days":%s,"unique_domains":%s,"multi_domain_pct":%s,"meta_pct":%s,"in_progress":%s}\n' \
  "$TS" "$FILES" "$MAIN_EDITS" "$MAIN_WRITES" "$MAIN_TOTAL" "$TASK_CALLS" \
  "$SIDECHAIN_EDITS" "$SIDECHAIN_WRITES" "$RATIO" "$RESULT_STATUS" "$DAYS" \
  "$UNIQUE_DOMAINS" "$MULTI_DOMAIN_PCT" "$META_PCT" "$IN_PROGRESS" \
  >> "$RATIO_FILE"

[ "$QUIET" -eq 0 ] && echo "[기록] $RATIO_FILE"
[ "$QUIET" -eq 0 ] && echo "=== 끝 ==="

# sensor-log 박제 (2026-05-02 H8) — RESULT_STATUS는 PASS/WARN/FAIL/SKIP/META_PASS 중
LOG_TAG="$RESULT_STATUS"
[ "$LOG_TAG" = "SKIP" ] && LOG_TAG="PASS"  # SKIP은 PASS로 간주 (실측 불가, 데이터 없음)
[ "$LOG_TAG" = "META_PASS" ] && LOG_TAG="PASS"  # META_PASS는 PASS (메타 세션 정합)
bash "$(dirname "$0")/sensor-log.sh" "sensor-orchestration-ratio" "$LOG_TAG" "ratio=$RATIO main=$MAIN_TOTAL task=$TASK_CALLS meta=$META_PCT days=$DAYS" 2>/dev/null || true

exit $EXIT_CODE
