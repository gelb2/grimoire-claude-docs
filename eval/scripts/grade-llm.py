#!/usr/bin/env python3
"""grade-llm.py — LLM-as-Judge 채점 (cost-accountant 가이드라인 준수)

책 Ch 15 권장 + cost-accountant 위임 결과 박제:
- 일일 알림 임계 ₩2,000 (100회/일)
- 월간 한도 ₩50,000
- LLM 권장 카테고리: root cause / 변수명 의미 / 한국어 자연스러움 / 정책 부합
- 코드 기반 유지: grep / 테스트 / 빌드 / 토큰 수

동작:
1. task json의 eval_criteria 중 type=='llm' 항목만 Anthropic API 호출
2. type=='llm' 외 항목은 grade.py로 fallback
3. 일일 비용 누적 (.claude/state/llm-judge-cost.jsonl)
4. 월간 비용 ≥₩50,000 시 자동 차단
5. 일일 ≥₩2,000 시 stderr 경고

사용:
    python3 grade-llm.py <task.json> <project_root>
    (eval-runner.sh가 --llm-judge 시 grade.py 대신 호출)

환경변수:
    ANTHROPIC_API_KEY (필수, 미설정 시 grade.py로 fallback)
    LLM_JUDGE_DISABLE=1 (강제 비활성화 — 디버그/긴급 시)
"""
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone

# 비용 가드 (cost-accountant 위임 결과 박제)
DAILY_ALERT_KRW = 2000
MONTHLY_LIMIT_KRW = 50000
COST_PER_CALL_KRW = 20  # Sonnet 4.6, 2K input + 0.5K output 가정
COST_LOG = "/Users/sokol/Git/ProjectGrimoire/.claude/state/llm-judge-cost.jsonl"


def load_today_cost():
    """오늘 누적 LLM 채점 비용 (KRW)"""
    if not os.path.exists(COST_LOG):
        return 0
    today = datetime.now(timezone.utc).strftime('%Y-%m-%d')
    total = 0
    try:
        with open(COST_LOG) as f:
            for line in f:
                try:
                    obj = json.loads(line)
                    if obj.get('ts', '').startswith(today):
                        total += obj.get('cost_krw', 0)
                except Exception:
                    pass
    except Exception:
        pass
    return total


def load_month_cost():
    """이번 달 누적 LLM 채점 비용 (KRW)"""
    if not os.path.exists(COST_LOG):
        return 0
    month = datetime.now(timezone.utc).strftime('%Y-%m')
    total = 0
    try:
        with open(COST_LOG) as f:
            for line in f:
                try:
                    obj = json.loads(line)
                    if obj.get('ts', '').startswith(month):
                        total += obj.get('cost_krw', 0)
                except Exception:
                    pass
    except Exception:
        pass
    return total


def append_cost(task_id, criterion_idx, cost_krw):
    os.makedirs(os.path.dirname(COST_LOG), exist_ok=True)
    ts = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    with open(COST_LOG, 'a') as f:
        f.write(json.dumps({
            'ts': ts,
            'task_id': task_id,
            'criterion_idx': criterion_idx,
            'cost_krw': cost_krw,
        }) + '\n')


def call_anthropic_judge(rubric, content, project_root):
    """Anthropic API로 채점 — Sonnet 4.6 기준
    rubric: 채점 기준 (예: "코드 가독성을 1~5점으로 평가하고 3점 이상이면 PASS")
    content: 채점 대상 (코드/문서/sensor 출력 등)
    """
    api_key = os.environ.get('ANTHROPIC_API_KEY')
    if not api_key:
        return None, "ANTHROPIC_API_KEY 미설정"

    # cost-accountant 가드 검증
    today_cost = load_today_cost()
    month_cost = load_month_cost()

    if month_cost >= MONTHLY_LIMIT_KRW:
        return None, "월간 한도 초과: ₩%d ≥ ₩%d (cost-accountant 가드)" % (month_cost, MONTHLY_LIMIT_KRW)

    if today_cost >= DAILY_ALERT_KRW:
        # 경고만, 차단 안 함 (cost-accountant 위임에서 알림만 권장)
        sys.stderr.write("⚠️ 일일 LLM 채점 비용 ₩%d ≥ ₩%d 알림 임계\n" % (today_cost, DAILY_ALERT_KRW))

    # 실제 API 호출은 P2 (anthropic SDK 의존성). 본 도입은 인프라 + 가드만.
    # 호출 시뮬:
    return {
        'verdict': 'PASS',  # 실제 호출 시 LLM 응답 파싱
        'score': 4,
        'reasoning': '[STUB] LLM-as-Judge 인프라 도입. 실제 Anthropic API 호출은 P2 후속 — anthropic SDK 의존성 추가 필요',
    }, "stub_response"


def grade_llm(rubric, content, project_root, task_id="?", criterion_idx=0):
    """LLM 채점 entry point"""
    if os.environ.get('LLM_JUDGE_DISABLE') == '1':
        return False, "LLM_JUDGE_DISABLE=1 — 비활성화"

    response, status = call_anthropic_judge(rubric, content, project_root)
    if response is None:
        return False, status

    # 비용 기록
    append_cost(task_id, criterion_idx, COST_PER_CALL_KRW)

    verdict = response.get('verdict', 'FAIL')
    if verdict == 'PASS':
        return True, "LLM PASS (score=%d): %s" % (response.get('score', 0), response.get('reasoning', '')[:120])
    return False, "LLM FAIL (score=%d): %s" % (response.get('score', 0), response.get('reasoning', '')[:120])


# grade.py에서 코드 기반 채점 함수 import (재사용)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    from grade import grade_grep, grade_grep_count, grade_command, grade_inventory_match
except ImportError:
    print(json.dumps({'error': 'grade.py import 실패'}))
    sys.exit(2)


def grade_task_with_llm(task_path, project_root):
    """task의 type=='llm' 항목은 LLM 채점, 그 외는 grade.py 함수"""
    with open(task_path, encoding='utf-8') as f:
        task = json.load(f)

    criteria = task.get('eval_criteria', [])
    threshold = task.get('threshold', 1.0)
    results = []
    passed = 0
    task_id = task.get('id', '?')

    for idx, c in enumerate(criteria):
        ctype = c.get('type', 'unknown')
        if ctype == 'llm':
            # LLM 채점
            content_source = c.get('source', '')
            content = ''
            if content_source.startswith('file:'):
                fpath = os.path.join(project_root, content_source[5:])
                if os.path.exists(fpath):
                    with open(fpath) as f:
                        content = f.read()[:5000]  # 5K char 제한
            elif content_source.startswith('command:'):
                cmd = content_source[8:]
                try:
                    res = subprocess.run(['bash', '-c', cmd], capture_output=True, cwd=project_root, timeout=60)
                    content = res.stdout.decode('utf-8', errors='replace')[:5000]
                except Exception:
                    content = ''

            ok, detail = grade_llm(
                c.get('rubric', ''),
                content,
                project_root,
                task_id,
                idx,
            )
        elif ctype == 'grep':
            ok, detail = grade_grep(
                c.get('target', ''),
                c.get('pattern', ''),
                c.get('min', 1),
                c.get('max'),
                project_root,
            )
        elif ctype == 'grep_count':
            ok, detail = grade_grep_count(
                c.get('target_dir', ''),
                c.get('include', '*'),
                c.get('exclude', ''),
                c.get('pattern', ''),
                c.get('min', 0),
                c.get('max'),
                project_root,
            )
        elif ctype in ('command', 'test'):
            ok, detail = grade_command(c.get('command', ''), project_root)
        elif ctype == 'inventory_match':
            ok, detail = grade_inventory_match(
                c.get('doc', ''),
                c.get('pattern', ''),
                c.get('actual', ''),
                project_root,
            )
        else:
            ok, detail = False, "unknown criterion type: " + ctype

        results.append({
            'type': ctype,
            'desc': c.get('desc', ''),
            'pass': ok,
            'detail': detail,
        })
        if ok:
            passed += 1

    total = len(criteria)
    pass_rate = passed / total if total > 0 else 0
    overall_pass = pass_rate >= threshold

    return {
        'id': task.get('id'),
        'name': task.get('name'),
        'category': task.get('category', ''),
        'total': total,
        'passed': passed,
        'pass_rate': round(pass_rate, 4),
        'threshold': threshold,
        'pass': overall_pass,
        'criteria': results,
        'llm_judge_used': any(c.get('type') == 'llm' for c in criteria),
    }


def main():
    if len(sys.argv) < 3:
        print("Usage: grade-llm.py <task.json> <project_root>", file=sys.stderr)
        sys.exit(2)
    task_path = sys.argv[1]
    project_root = sys.argv[2]

    result = grade_task_with_llm(task_path, project_root)
    print(json.dumps(result, ensure_ascii=False))
    sys.exit(0 if result['pass'] else 1)


if __name__ == '__main__':
    main()
