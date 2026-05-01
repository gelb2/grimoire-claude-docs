#!/usr/bin/env bash
# cost-tracker.sh — 호출별 task_id/model/tokens/cost JSONL 적재기 (책 Ch 18 정본)
#
# 동기 (책 Ch 23 자가진단 Q6 ❌→✅ + 안티패턴 #6 비용 블랙홀 방어):
#   - 우리는 sensor-cost-margin (ai-cost-table 검증)만 보유 → 호출별 추적 부재
#   - 책 Ch 18 cost_tracker.py 패턴: { ts, task_id, model, input_tokens, output_tokens, cache_tokens, cost_usd }
#   - 우리 적용: Anthropic API 신규 호출 0 (사용자 결정 보류) → "추정 박제 모드"로 운영
#     - 사용자/Claude가 작업 단위로 본 스크립트 호출 → 박제 (수동)
#     - 향후 Anthropic API SDK 연동 시 자동화 가능 (현재 stub과 같은 위치)
#
# 사용:
#   cost-tracker.sh log <task_id> <model> <input_tokens> <output_tokens> [cache_tokens]
#   cost-tracker.sh report               # 일별 집계
#   cost-tracker.sh report --month       # 월별 집계
#   cost-tracker.sh estimate <model>     # 모델별 토큰 단가 표시 (참조용)
#
# JSONL 위치: .claude/state/cost-tracker.jsonl
# 컬럼: ts / task_id / model / input_tokens / output_tokens / cache_tokens / cost_usd / cost_krw
#
# 모델 단가 (USD per 1M tokens, 2026-05-02 기준 — researcher AI_COST_MONITOR 동기):
#   - Opus 4.6:   input $15 / output $75 / cache $1.50
#   - Sonnet 4.6: input $3  / output $15 / cache $0.30
#   - Haiku 4.5:  input $0.80 / output $4 / cache $0.08
#
# 환율: USD ₩1,474 (cost-accountant 박제, 30일 stale 시 sensor-cost-margin이 알림)

set +u

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
LOG_FILE="$ROOT/.claude/state/cost-tracker.jsonl"
USD_KRW=1474

mkdir -p "$(dirname "$LOG_FILE")"

ACTION="${1:-help}"

case "$ACTION" in
  log)
    TASK_ID="${2:?task_id 필수}"
    MODEL="${3:?model 필수 (opus/sonnet/haiku)}"
    INPUT_TOK="${4:?input_tokens 필수}"
    OUTPUT_TOK="${5:?output_tokens 필수}"
    CACHE_TOK="${6:-0}"

    # 모델별 단가 USD/MTok
    case "$MODEL" in
      opus|opus-4.6)     IN_PRICE=15;     OUT_PRICE=75;   CACHE_PRICE=1.50 ;;
      sonnet|sonnet-4.6) IN_PRICE=3;      OUT_PRICE=15;   CACHE_PRICE=0.30 ;;
      haiku|haiku-4.5)   IN_PRICE=0.80;   OUT_PRICE=4;    CACHE_PRICE=0.08 ;;
      *) echo "FAIL: unknown model '$MODEL' (opus/sonnet/haiku)"; exit 1 ;;
    esac

    # 비용 계산 (USD)
    COST_USD=$(python3 -c "
in_cost = $INPUT_TOK * $IN_PRICE / 1000000
out_cost = $OUTPUT_TOK * $OUT_PRICE / 1000000
cache_cost = $CACHE_TOK * $CACHE_PRICE / 1000000
print(round(in_cost + out_cost + cache_cost, 6))
")
    COST_KRW=$(python3 -c "print(round($COST_USD * $USD_KRW, 2))")

    TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    ENTRY=$(python3 -c "
import json
print(json.dumps({
  'ts': '$TS',
  'task_id': '$TASK_ID',
  'model': '$MODEL',
  'input_tokens': $INPUT_TOK,
  'output_tokens': $OUTPUT_TOK,
  'cache_tokens': $CACHE_TOK,
  'cost_usd': $COST_USD,
  'cost_krw': $COST_KRW
}, ensure_ascii=False))
")
    echo "$ENTRY" >> "$LOG_FILE"
    echo "✅ 박제: $TASK_ID ($MODEL) — \$$COST_USD ≈ ₩$COST_KRW"
    ;;

  report)
    SCOPE="${2:-day}"
    if [ ! -s "$LOG_FILE" ]; then
      echo "(cost-tracker.jsonl 없음 — 호출 박제 0건)"
      exit 0
    fi

    if [ "$SCOPE" = "--month" ] || [ "$SCOPE" = "month" ]; then
      MONTH=$(date -u +"%Y-%m")
      echo "=== cost-tracker 월별 집계 ($MONTH) ==="
      python3 <<PYEOF
import json
from collections import defaultdict
total_usd = 0.0
total_krw = 0.0
by_model = defaultdict(lambda: {'count': 0, 'usd': 0.0, 'krw': 0.0, 'in_tok': 0, 'out_tok': 0})
by_task = defaultdict(lambda: {'count': 0, 'usd': 0.0})

with open('$LOG_FILE') as f:
    for line in f:
        try:
            obj = json.loads(line)
            if not obj.get('ts', '').startswith('$MONTH'):
                continue
            total_usd += obj.get('cost_usd', 0)
            total_krw += obj.get('cost_krw', 0)
            m = obj.get('model', 'unknown')
            by_model[m]['count'] += 1
            by_model[m]['usd'] += obj.get('cost_usd', 0)
            by_model[m]['krw'] += obj.get('cost_krw', 0)
            by_model[m]['in_tok'] += obj.get('input_tokens', 0)
            by_model[m]['out_tok'] += obj.get('output_tokens', 0)
            t = obj.get('task_id', 'unknown')
            by_task[t]['count'] += 1
            by_task[t]['usd'] += obj.get('cost_usd', 0)
        except Exception:
            pass

print(f"총 비용: \${total_usd:.4f} ≈ ₩{total_krw:.2f}")
print(f"")
print(f"── 모델별 ──")
for m, d in sorted(by_model.items(), key=lambda x: -x[1]['usd']):
    print(f"  {m:20s} {d['count']:4d}회  in={d['in_tok']:>10,}  out={d['out_tok']:>8,}  \${d['usd']:.4f} ≈ ₩{d['krw']:.2f}")
print(f"")
print(f"── 태스크 Top 10 (비용순) ──")
for t, d in sorted(by_task.items(), key=lambda x: -x[1]['usd'])[:10]:
    print(f"  {t:40s} {d['count']:3d}회  \${d['usd']:.4f}")
PYEOF
    else
      TODAY=$(date -u +"%Y-%m-%d")
      echo "=== cost-tracker 일별 집계 ($TODAY) ==="
      python3 <<PYEOF
import json
from collections import defaultdict
total_usd = 0.0
total_krw = 0.0
by_model = defaultdict(lambda: {'count': 0, 'usd': 0.0})
by_task = defaultdict(lambda: {'count': 0, 'usd': 0.0})

with open('$LOG_FILE') as f:
    for line in f:
        try:
            obj = json.loads(line)
            if not obj.get('ts', '').startswith('$TODAY'):
                continue
            total_usd += obj.get('cost_usd', 0)
            total_krw += obj.get('cost_krw', 0)
            m = obj.get('model', 'unknown')
            by_model[m]['count'] += 1
            by_model[m]['usd'] += obj.get('cost_usd', 0)
            t = obj.get('task_id', 'unknown')
            by_task[t]['count'] += 1
            by_task[t]['usd'] += obj.get('cost_usd', 0)
        except Exception:
            pass

print(f"오늘 총 비용: \${total_usd:.4f} ≈ ₩{total_krw:.2f}")
print(f"")
if by_model:
    print(f"── 모델별 ──")
    for m, d in sorted(by_model.items(), key=lambda x: -x[1]['usd']):
        print(f"  {m:15s} {d['count']:3d}회  \${d['usd']:.4f}")
if by_task:
    print(f"── 태스크별 ──")
    for t, d in sorted(by_task.items(), key=lambda x: -x[1]['usd']):
        print(f"  {t:40s} {d['count']:3d}회  \${d['usd']:.4f}")
PYEOF
    fi
    ;;

  estimate)
    MODEL="${2:?model 필수 (opus/sonnet/haiku)}"
    case "$MODEL" in
      opus|opus-4.6)     echo "Opus 4.6:   input \$15 / output \$75 / cache \$1.50 per MTok" ;;
      sonnet|sonnet-4.6) echo "Sonnet 4.6: input \$3  / output \$15 / cache \$0.30 per MTok" ;;
      haiku|haiku-4.5)   echo "Haiku 4.5:  input \$0.80 / output \$4  / cache \$0.08 per MTok" ;;
      *) echo "FAIL: unknown model '$MODEL'"; exit 1 ;;
    esac
    ;;

  *)
    cat <<EOF
사용:
  cost-tracker.sh log <task_id> <model> <input_tokens> <output_tokens> [cache_tokens]
  cost-tracker.sh report               # 일별 집계
  cost-tracker.sh report --month       # 월별 집계
  cost-tracker.sh estimate <model>     # 모델별 단가

모델: opus | sonnet | haiku

예시:
  cost-tracker.sh log "묶음-R-cost-tracker-개발" sonnet 5000 800
  cost-tracker.sh report
  cost-tracker.sh report --month
EOF
    ;;
esac
