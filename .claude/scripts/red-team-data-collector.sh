#!/usr/bin/env bash
# red-team-data-collector.sh — 자율학습 데이터 수집 (3단 분리 — α-자율 단계)
#
# 책 V1.1 Ch 23 정원 가꾸기 자동화 + Ouroboros Evolve + 사용자 추가 요구.
# 외부 API 0 (WebFetch는 Claude Code 기본 도구, 구독료 안).
#
# 동작:
#   1. whitelist 출처 (sensor-red-team-source-whitelist) 검증
#   2. WebFetch 호출 (사용자 또는 Claude 메인 세션)
#   3. 결과를 .claude/state/red-team-data-pending.jsonl에 박제
#
# 사용:
#   bash red-team-data-collector.sh add <URL> <topic>
#   bash red-team-data-collector.sh list
#   bash red-team-data-collector.sh latest 5
#
# 다음 단계: red-team-update-propose skill이 pending → proposals/ 변환 (사용자 게이트)
#
# 빈도 캡 (책 Ch 18 비용 + Ch 23 안티패턴 #4 모델 의존 착각 방어):
#   일주일 1회 또는 사용자 트리거 시만
#
# Exit:
#   0 — 박제 성공
#   1 — whitelist 외 출처 (차단)
#   2 — 인자 누락

set +u

ROOT="/Users/sokol/Git/ProjectGrimoire"
LOG_FILE="$ROOT/.claude/state/red-team-data-pending.jsonl"
mkdir -p "$(dirname "$LOG_FILE")"

ACTION="${1:-help}"

case "$ACTION" in
  add)
    URL="${2:?URL 필수}"
    TOPIC="${3:?topic 필수 (예: socratic / adversarial / constitutional / red-team)}"

    # whitelist 검증
    if ! bash "$(dirname "$0")/sensor-red-team-source-whitelist.sh" "$URL" >/dev/null 2>&1; then
      echo "❌ FAIL whitelist 외 출처 — 박제 차단"
      bash "$(dirname "$0")/sensor-red-team-source-whitelist.sh" "$URL"
      exit 1
    fi

    # 박제 (메타만 — 실제 WebFetch는 사용자/Claude 메인 세션이 직접 호출 후 결과를 별도로 박제)
    TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    ENTRY=$(python3 -c "
import json
print(json.dumps({
  'ts': '$TS',
  'url': '$URL',
  'topic': '$TOPIC',
  'status': 'pending',
  'note': 'WebFetch 결과는 메인 Claude 세션이 별도 박제 (red-team-update-propose skill)'
}, ensure_ascii=False))
")
    echo "$ENTRY" >> "$LOG_FILE"
    echo "✅ 박제: $URL ($TOPIC)"
    echo "💡 다음 단계: red-team-update-propose skill 호출 (사용자 명시 시)"
    ;;

  list)
    if [ ! -s "$LOG_FILE" ]; then
      echo "(red-team-data-pending.jsonl 비어있음 — 박제 0건)"
      exit 0
    fi
    echo "=== red-team-data-pending.jsonl 전체 ==="
    python3 -c "
import json
with open('$LOG_FILE') as f:
    for i, line in enumerate(f, 1):
        try:
            d = json.loads(line)
            print(f\"[{i}] {d.get('ts','?')[:10]} {d.get('topic','?')} — {d.get('url','?')[:80]}\")
        except: pass"
    ;;

  latest)
    N="${2:-5}"
    if [ ! -s "$LOG_FILE" ]; then
      echo "(red-team-data-pending.jsonl 비어있음)"
      exit 0
    fi
    echo "=== 최근 $N 건 ==="
    tail -n "$N" "$LOG_FILE" | python3 -c "
import json, sys
for line in sys.stdin:
    try:
        d = json.loads(line)
        print(f\"  {d.get('ts','?')[:10]} {d.get('topic','?')} — {d.get('url','?')[:80]}\")
    except: pass"
    ;;

  *)
    cat <<EOF
사용:
  red-team-data-collector.sh add <URL> <topic>      # 새 데이터 박제 (whitelist 검증)
  red-team-data-collector.sh list                    # 전체 박제 보기
  red-team-data-collector.sh latest [N]              # 최근 N건 (기본 5)

Topic 권장:
  socratic / adversarial / constitutional / red-team / security / ouroboros

빈도 캡: 일주일 1회 또는 사용자 트리거 시만 (책 Ch 18 비용 + Ch 23 안티패턴 #4 방어)

다음 단계 (3단 분리):
  α-자율 (수집): 본 스크립트 (메타 박제만)
  α-반자율 (Propose): red-team-update-propose skill → .claude/proposals/ 박제
  ⚠️ 사용자 승인 게이트: proposal Read 후 명시 승인 시만 적용
EOF
    ;;
esac
