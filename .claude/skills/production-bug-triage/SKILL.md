---
name: production-bug-triage
description: 운영/개발 환경에서 "fetch aborted", "작품을 불러올 수 없습니다", "signal timed out", 특정 페이지 502/504, AI 분석 타임아웃 등 사용자 증상이 보고되었을 때 발동. 원인을 "아마도 cold start일 것입니다" 같은 추측으로 답하지 말고, curl/psql/git 실측 → 코드 경로 추적 → 수치 근거 확보 순서를 강제. CLAUDE.md §0 ZERO-TOLERANCE 준수 프로토콜.
allowed-tools: Read, Bash, Grep, Glob
triggers:
  - "fetch aborted"
  - "작품을 불러올 수 없"
  - "signal timed out"
  - "signal is aborted"
  - "502"
  - "504"
  - "cold start"
  - "콜드 스타트"
  - "Application error"
  - "분석 실패"
  - "타임아웃"
  - "timeout"
  - "간헐적으로 실패"
  - "안 된다"
  - "안 되요"
  - "느리다"
effort: high
---

# 운영 버그 트리아지 — 추정 금지 프로토콜

## 언제 발동하는가

사용자가 다음 유형의 보고를 할 때:
- "X 페이지에서 '작품을 불러올 수 없습니다' 뜬다"
- "AI 분석 돌리면 fetch aborted 나온다"
- "로그인 시도하면 signal timed out"
- "API 응답이 이상하다", "느리다", "타임아웃"
- 특정 기능이 "간헐적으로" 실패한다

## 절대 금지 사항 (CLAUDE.md §0 ZERO-TOLERANCE)

### [MUST NOT] 추측성 답변
- "아마도 cold start 때문일 겁니다"
- "네트워크 문제 같습니다"
- "reCAPTCHA가 차단한 것 같네요"
- "Redis 캐시 만료일 수도 있습니다"

→ 이런 문장은 **수치·로그·코드 인용 없이 나오면 전부 금지**. 2026-04-19 세션에서 "fetch aborted → cold start로 단정"이 사용자 격노 직결.

### [MUST NOT] 해결됐다고 선언 후 미검증
- "수정했습니다" + 테스트 누락
- 유닛 테스트만 통과하고 실제 HTTP·브라우저 검증 생략

→ CLAUDE.md §0의 "전수검사 완료" 보고 후 기초 에러 노출이 구독해지 트리거.

## Chain of Verification (3단계 필수)

### 1단계 — 외부 경로 실측 (curl 직접)

증상이 "페이지 로드 실패" 유형이면:

```bash
# 프로덕션
curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" https://grimoire-book.com/{문제_경로}

# BFF 프록시 응답
curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" https://grimoire-book.com/api/{endpoint}

# 직접 API (setGlobalPrefix('api') 때문에 /api 프리픽스 필수)
curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" https://api.grimoire-book.com/api/{endpoint}

# 개발
curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" https://dev.grimoire-book.com/{문제_경로}
curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" https://dev-api.grimoire-book.com/api/{endpoint}
```

- 200이 아닌 HTTP 상태코드는 **코드/숫자 그대로** 기록
- `time_total`이 10초 초과하면 cold start 의심 (단 **근거로 사용하려면 코드 경로 확인 필수**)
- 응답 본문 조사 필요 시 `-o /tmp/resp.json` 후 내용 인용

> **URL 슬러그 주의**: 에피소드 URL은 숫자 기반 아님. 예: `/deerdevil/deerdevil/ep1` (O), `/deerdevil/deerdevil/1` (X → 404). `memory/feedback_fullcheck_method.md` 참조.

### 2단계 — 코드 경로 추적 (Grep + Read)

증상에 매칭되는 문자열/에러를 코드에서 찾는다:

```bash
# 웹 측 에러 메시지
grep -rn "작품을 불러올 수 없습니다" grimoire-web/src --include="*.ts*"
grep -rn "fetch aborted" grimoire-web/src --include="*.ts*"
grep -rn "signal timed out" grimoire-web/src --include="*.ts*"

# 서버 측 throw/exception
grep -rn "CreditInsufficient\|Aborted\|Timeout" grimoire-server/src --include="*.ts"
```

각 매칭 위치를 `Read`로 열어 **어떤 조건에서 그 메시지가 나오는지**를 파악. 조건 문장을 그대로 인용.

예시 (2026-04-19 실제 경로):
- 웹: `grimoire-web/src/lib/api/client.ts:44` — rawFetch 브라우저 타임아웃 10s 고정
- BFF: `grimoire-web/src/app/api/[...path]/route.ts` — fetch에 `signal: request.signal` 전파 여부
- 서버: `grimoire-server/src/application/analysis/novel-analysis.usecase.ts:79-97` — catch 블록 환불 분기

### 3단계 — 수치 근거 확보

추정 대신 **정확한 수치 3종**을 제시:

1. **타임아웃 수치** — 프론트·BFF·서버 각각의 제한시간
2. **실측 응답 시간** — curl `time_total` 출력
3. **재현 조건** — 어떤 입력/상태에서 실패했는지 (cold start 직후 / 세션 만료 / 크레딧 부족 등)

```
예시 리포트 (2026-04-19 세션 #4):
- 프론트 analyzeEpisode timeout: 60s (src/lib/api.ts:402)
- BFF 프록시 fetch: signal 미전파 (src/app/api/[...path]/route.ts:L??)
- 서버: Claude 병렬 호출 abort 미감지 → 환불 분기 우회 (src/application/analysis/novel-analysis.usecase.ts)
- 실측 cold start: /api/health 24.07s
- 재현 조건: 세션 만료 없음, 크레딧 보유, 분석 시작 후 60~90초 대기
→ 수정 대상: 프론트 120s + BFF signal 전파 + 서버 abortableRace
```

## 보고 템플릿

사용자에게 답할 때 **반드시** 아래 형식:

```
### 실측
- curl 결과: {HTTP 상태 / time_total}
- 에러 메시지 위치: {파일:라인}
- 조건: {해당 조건 발동 코드 인용}

### 원인
{코드 인용 기반 설명. "추정" 단어 금지}

### 수정안
- {파일:라인}: {변경 내용}

### 검증 방법
- {curl 또는 유닛/E2E 테스트 명령}
```

## 특수 케이스

### reCAPTCHA 차단
- `curl -X POST /api/auth/login`으로 인증 플로우 테스트 → 400 "reCAPTCHA 토큰 필요" 정상 응답
- 로그인 실측은 브라우저에서만 가능. curl은 공개 엔드포인트(`/api/health`)로

### db-sync --mask-pii 회귀
- dev DB 로그인 불가 시 `grimoire-server/scripts/db-sync.ts:21,36-42` 확인
- `masked2026` 고정 해시 + 이메일 치환이 범인. 수동 UPDATE로 복원 가능하나 다음 db-sync에서 덮어씀

### Azure Container Apps cold start
- min-replicas=0 환경에서 60초 내 무응답은 비정상 아님
- 커버리지: `fetchWithRetry` 4회×2.5s = 최대 70초 (`grimoire-web/src/app/explore/page.tsx`)
- 커버 부족 시 warm-up ping 또는 재시도 간격 상향

## 관련 정본

- `memory/feedback_fullcheck_method.md` (이 skill의 승격 원본)
- `memory/project_session_20260419_3.md` (explore cold start 트리아지 실사례)
- `memory/project_session_20260419_4.md` (AI 분석 fetch aborted 트리아지 실사례)
- `CLAUDE.md §0` (ZERO-TOLERANCE 절대 수칙)
- `grimoire-server/HANDOVER.md §4` (함정 목록)

---

승격 원본: `memory/feedback_fullcheck_method.md`
마지막 업데이트: 2026-04-25
