---
name: verifier-protocol
description: grimoire-verifier 에이전트 전용 검증 절차. 변경 0 상태로 독립 재실측 — git ref 직접 조회, 파일 크기/존재, HTTP 코드, 테스트·sensor 재실행. 셸 출력 불신(파일 격리 후 Read), 가짜 SHA/에러 대조, raw 근거 강제, 자기검증 금지. 2026-05-29 거짓 PASS 사태 재발 차단용.
---

# Verifier Protocol — 읽기전용 독립 검증 절차

## 책임 영역 (2026-05-29 박제)

- **owner**: grimoire-verifier 에이전트 (메인·다른 에이전트는 호출 안 함 — 검증은 verifier 전담)
- **목적**: 작업 주체와 검증 주체 분리. "자기가 짠 걸 자기가 PASS"의 구조적 거짓 차단.

## 핵심 원칙 (이번 사태 교훈)

1. **셸 stdout을 그대로 믿지 않는다.** 중요한 판정은 파일로 격리 출력 후 Read.
   - 이번 사태: 셸 출력이 가짜 SHA(`4b8f21e`, `99936c4`)·가짜 GH006 에러를 섞어 뱉음 → `ls-remote`를 파일로 격리해 진짜 SHA(`bb57841`) 확인으로 돌파.
2. **"PASS" 단어 + raw 근거 없음 = 그 보고가 FAIL.** 파일 크기·로그 라인·HTTP 코드·git ref 숫자 첨부.
3. **추정 0.** 실행 못 한 검증은 "미검증(SKIP — 사유)". 모르면 모른다.
4. **자기 보고 복사 0.** 작업자 보고는 입력일 뿐, 반드시 독립 재실측.

## 5단계 검증 절차

### 1. git/ref (가짜 출력 면역)
```bash
git rev-parse <branch>                              # 로컬 실제 SHA
git ls-remote origin <branch> > /tmp/v-remote.txt   # 원격 — 파일 격리
# Read /tmp/v-remote.txt 로 확인 (셸 출력 불신)
git show <sha>:<path> | wc -l                        # 커밋된 실제 내용
```

### 2. 파일 실재/크기 (빈 파일 = 무력)
```bash
test -f <file> && wc -c < <file> || echo MISSING
# 0바이트인데 settings.json에 등록됨 = 무력 hook (이번 사태 핵심)
```

### 3. 런타임 (서비스 실동작)
```bash
curl -s -m 30 -o /dev/null -w "%{http_code}" <url>
curl -s <url> | head -c 300                          # 응답 바디
```

### 4. 테스트/sensor (직접 재실행, 복사 금지)
```bash
bash .claude/scripts/sensor-<name>.sh; echo "exit=$?"
# npm test 등은 read 실행만 — verifier는 코드 변경 0
```

### 5. settings.json hook 실효 (등록 vs 실제)
```bash
python3 - <<'PY'
import json,os
s=json.load(open('.claude/settings.json'))
for ev in s['hooks']:
    for m in s['hooks'][ev]:
        for h in m.get('hooks',[]):
            p=h['command'].split()[-1]
            sz=os.path.getsize(p) if os.path.isfile(p) else -1
            print(ev, os.path.basename(p), f'{sz}B' if sz>=0 else 'MISSING')
PY
# 등록됐는데 0바이트/MISSING = 무력 → FAIL
```

## 적대적 재현 (최소 1건 필수)

통과한 것도 일부러 깨본다:
- 고친 가드라면 → 차단 케이스를 만들어 실제 exit 2 나는지
- 원격 상태라면 → `ls-remote` 직접 조회로 작업자 주장 SHA와 대조
- 테스트라면 → 핵심 단언 1개 무력화 시 FAIL 재현되는지 (확인 후 원복은 작업자 영역, verifier는 재현만 관찰)

## 보고 양식

```
## Verification: <대상>
판정: PASS | FAIL | 미검증(SKIP)

| 주장 | 검증 명령 | raw 결과 | 판정 |
|---|---|---|---|

적대적 재현: <무엇을 깨봤고 결과>
발견(숨김 0): <FAIL/모순/미검증/이상치>
```

## 절대 금지

- Edit/Write/commit/push/배포/Task = verifier 도구 미보유. 절차에 넣지 않는다.
- 검증 중 발견한 수정거리 = 고치지 않고 FAIL + 권고. 수정은 메인이 도메인/harness 에이전트 위임.

## 관련 정본
- `.claude/agents/grimoire-verifier.md` — 본 스킬 owner
- `.claude/knowledge/red-team-constitution.md` — 레드팀 절대규정 (2026-05-29 5조)
