#!/usr/bin/env python3
"""grade.py — ProjectGrimoire eval 단일 task 채점

사용:
    python3 grade.py <task.json> <project_root>

출력 (stdout):
    JSON {id, name, total, passed, threshold, pass, criteria: [{type, desc, pass, detail}]}

Exit code:
    0: pass
    1: fail
"""
import json
import os
import re
import subprocess
import sys


def grade_grep(target_file, pattern, min_count=1, max_count=None, project_root=""):
    full_path = os.path.join(project_root, target_file) if not os.path.isabs(target_file) else target_file
    if not os.path.exists(full_path):
        return False, "파일 없음: " + target_file
    try:
        with open(full_path, encoding='utf-8') as f:
            content = f.read()
        cnt = len(re.findall(pattern, content))
        if cnt < min_count:
            return False, "매치 " + str(cnt) + "건 < min " + str(min_count) + " (target: " + target_file + ")"
        if max_count is not None and cnt > max_count:
            return False, "매치 " + str(cnt) + "건 > max " + str(max_count)
        return True, "매치 " + str(cnt) + "건"
    except Exception as e:
        return False, "읽기 실패: " + str(e)


def grade_grep_count(target_dir, include, exclude, pattern, min_count=0, max_count=None, project_root=""):
    full_dir = os.path.join(project_root, target_dir) if not os.path.isabs(target_dir) else target_dir
    if not os.path.exists(full_dir):
        return False, "디렉토리 없음: " + target_dir

    include_patterns = [p.strip() for p in include.split(',') if p.strip()]
    exclude_patterns = [p.strip() for p in exclude.split(',') if p.strip()] if exclude else []

    find_cmd = ['find', full_dir, '-type', 'f']
    name_filters = []
    for inc in include_patterns:
        if name_filters:
            name_filters.append('-o')
        name_filters.extend(['-name', inc])
    if name_filters:
        find_cmd.append('(')
        find_cmd.extend(name_filters)
        find_cmd.append(')')

    try:
        files = subprocess.run(find_cmd, capture_output=True, text=True, timeout=30).stdout.strip().split('\n')
    except Exception as e:
        return False, "find 실패: " + str(e)

    total = 0
    for f in files:
        if not f.strip() or not os.path.exists(f):
            continue
        skip = False
        for exc in exclude_patterns:
            exc_re = exc.replace('*', '.*')
            if re.search(exc_re, f):
                skip = True
                break
        if skip:
            continue
        try:
            with open(f, encoding='utf-8') as fp:
                total += len(re.findall(pattern, fp.read()))
        except Exception:
            pass

    if total < min_count:
        return False, "전체 매치 " + str(total) + "건 < min " + str(min_count)
    if max_count is not None and total > max_count:
        return False, "전체 매치 " + str(total) + "건 > max " + str(max_count)
    return True, "전체 매치 " + str(total) + "건"


def grade_command(command, project_root=""):
    try:
        # /bin/sh 차이 회피 — bash 명시 호출
        result = subprocess.run(
            ['bash', '-c', command],
            capture_output=True,
            timeout=300, cwd=project_root
        )
        if result.returncode == 0:
            return True, "command exit 0"
        stderr_text = result.stderr.decode('utf-8', errors='replace') if result.stderr else ''
        return False, "command exit " + str(result.returncode) + ": " + stderr_text[:120]
    except subprocess.TimeoutExpired:
        return False, "command timeout (300s)"
    except Exception as e:
        return False, "command 실행 실패: " + str(e)


def grade_inventory_match(doc, pattern, actual, project_root=""):
    full_doc = os.path.join(project_root, doc) if not os.path.isabs(doc) else doc
    if not os.path.exists(full_doc):
        return False, "문서 없음: " + doc
    try:
        with open(full_doc, encoding='utf-8') as f:
            content = f.read()
        m = re.search(pattern, content)
        if not m:
            return False, "패턴 미매치: " + pattern[:60]
        doc_count = int(m.group(1))

        result = subprocess.run(actual, shell=True, capture_output=True, text=True, cwd=project_root)
        actual_count = int(result.stdout.strip())

        if doc_count == actual_count:
            return True, "문서 " + str(doc_count) + " == 실측 " + str(actual_count)
        return False, "문서 " + str(doc_count) + " != 실측 " + str(actual_count) + " (drift)"
    except Exception as e:
        return False, "검증 실패: " + str(e)


# 2026-05-03 묶음 II — TaskFlow 5차원 가중치 (책 Ch 15)
# 기능 정확성 40 + 코드 품질 20 + 성능 15 + 보안 15 + UX 10 = 100
TASKFLOW_WEIGHTS = {
    'functional': 40,    # 기능 정확성
    'code_quality': 20,  # 코드 품질 (lint / type / test coverage)
    'performance': 15,   # 성능 (응답시간 / 메모리)
    'security': 15,      # 보안 (auth / injection / leak)
    'ux': 10,            # UX (Visual canon / accessibility)
}
DEFAULT_DIMENSION = 'functional'  # criteria.dimension 미지정 시 기본


def grade_task(task_path, project_root):
    with open(task_path, encoding='utf-8') as f:
        task = json.load(f)

    criteria = task.get('eval_criteria', [])
    threshold = task.get('threshold', 1.0)
    results = []
    passed = 0
    weighted_sum = 0.0
    total_weight = 0.0
    dim_scores = {}  # 차원별 점수 누적

    for c in criteria:
        ctype = c.get('type', 'unknown')
        if ctype == 'grep':
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

        # 가중치 계산 (TaskFlow 5차원, 묶음 II)
        # criteria.dimension 명시 시 해당 차원 가중치, 없으면 'functional' (기본 40)
        dim = c.get('dimension', DEFAULT_DIMENSION)
        weight = c.get('weight', TASKFLOW_WEIGHTS.get(dim, TASKFLOW_WEIGHTS['functional']))
        total_weight += weight
        if ok:
            weighted_sum += weight
        dim_scores.setdefault(dim, {'total': 0, 'earned': 0})
        dim_scores[dim]['total'] += weight
        if ok:
            dim_scores[dim]['earned'] += weight

        results.append({
            'type': ctype,
            'desc': c.get('desc', ''),
            'pass': ok,
            'detail': detail,
            'dimension': dim,
            'weight': weight,
        })
        if ok:
            passed += 1

    total = len(criteria)
    pass_rate = passed / total if total > 0 else 0
    weighted_score = (weighted_sum / total_weight) if total_weight > 0 else 0
    overall_pass = pass_rate >= threshold

    return {
        'id': task.get('id'),
        'name': task.get('name'),
        'category': task.get('category', ''),
        'total': total,
        'passed': passed,
        'pass_rate': round(pass_rate, 4),
        'weighted_score': round(weighted_score, 4),  # 0~1 정규화 (TaskFlow 5차원, 묶음 II)
        'dim_scores': {
            d: round(v['earned'] / v['total'], 4) if v['total'] > 0 else 0
            for d, v in dim_scores.items()
        },
        'threshold': threshold,
        'pass': overall_pass,
        'criteria': results,
    }


def main():
    if len(sys.argv) < 3:
        print("Usage: grade.py <task.json> <project_root>", file=sys.stderr)
        sys.exit(2)
    task_path = sys.argv[1]
    project_root = sys.argv[2]

    result = grade_task(task_path, project_root)
    print(json.dumps(result, ensure_ascii=False))
    sys.exit(0 if result['pass'] else 1)


if __name__ == '__main__':
    main()
