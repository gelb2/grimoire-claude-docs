---
name: verification-before-completion
description: "완료했습니다", "작업 끝났습니다", "전부 통과", "PASS", "배포 완료", "수정 완료" 등 완료 선언을 하기 직전에 발동. 추정·자가 주장이 아닌 실측 증거 3종(테스트·빌드·기능 동작) 첨부를 강제. 2026-04-19 "fetch aborted 추측"·"환불 UI 거짓말"·"전수검사 완료 보고 후 prod 에러" 재발 방지. obra/superpowers MIT 차용.
allowed-tools: Read, Bash, Grep
triggers:
  - "완료했습니다"
  - "완료했어"
  - "끝났습니다"
  - "끝났어"
  - "다 됐"
  - "모두 통과"
  - "전부 통과"
  - "전부 PASS"
  - "PASS 판정"
  - "배포 완료"
  - "배포 끝"
  - "수정 완료"
  - "fix 완료"
  - "구현 완료"
  - "전수검사 완료"
  - "검증 통과"
  - "이상 없음"
effort: high
---

# Verification Before Completion — 완료 선언 전 실측 증거 강제

## 언제 발동하는가

Claude가 다음 표현으로 작업 완료를 선언하려는 순간:
- "X 완료했습니다", "전부 통과", "PASS", "배포 끝", "이상 없음", "수정 완료"
- 사용자가 "완료했어?", "다 됐어?"로 확인 요청

이때 **즉시 본 프로토콜로 전환**하여 실측 증거 없는 완료 선언을 차단한다.

## 절대 금지 사항 (CLAUDE.md §0 ZERO-TOLERANCE)

### [MUST NOT] 실측 없는 완료 주장
- "테스트 통과했습니다" + 실행 명령 인용 없음
- "빌드 성공" + 출력 인용 없음
- "Chrome으로 확인했습니다" + 스크린샷·DOM 인용 없음
- "에이전트 PASS" + raw output 미첨부

### [MUST NOT] 부분 검증 후 전체 완료 선언
- 유닛 테스트만 돌리고 "전수검사 완료"
- 로컬에서만 확인하고 "prod 정상"
- 1개 페이지만 보고 "모든 페이지 정상"

### [MUST NOT] 이전 세션 결과를 현재 검증으로 둔갑
- "지난번 빌드 통과했으니 이번에도 통과"
- "어제 검증한 결과 PASS"

## 완료 선언 게이트 — 실측 증거 3종 (필수)

완료를 선언하려면 아래 3가지 증거를 **이번 세션 내** 실측해 첨부:

### Gate 1. 코드 검증 (정적)
변경 유형에 따라:

```bash
# TypeScript 변경
cd <repo> && npx tsc --noEmit
# 출력 캡처 + exit code 인용

# 테스트
cd <repo> && npm test  # 또는 vitest run / jest
# Test Suites: N passed / Tests: N passed 인용

# 빌드 (prod 배포 전이라면)
cd <repo> && npm run build
# 빌드 결과 인용
```

**[MUST]** 명령 실행 결과를 답변에 인용. 이전 세션 결과 재사용 금지.

### Gate 2. 기능 검증 (동적)
변경된 기능을 실제로 동작시켜 결과 캡처:

#### 서버 변경 시
```bash
curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" {endpoint}
# 200 + 응답 시간 인용. 또는 응답 본문 인용
```

#### 웹 UI 변경 시
- Claude Preview MCP: `preview_screenshot` 또는 `preview_snapshot`
- Claude-in-Chrome MCP: `read_page` + `find` 으로 DOM 인용
- Playwright: `npm run test:e2e -- {pattern}`

#### DB 마이그레이션 시
```bash
npx prisma migrate status
# 결과 인용
```

### Gate 3. 회귀 영향 검증
변경이 다른 부분을 깨지 않았는지:

```bash
# 양 레포 전체 테스트 (CI 수준)
cd grimoire-server && npm test
cd grimoire-web && npm test -- --run
```

**[MUST]** 변경한 파일과 직접 무관한 기존 테스트들도 통과해야 PASS.

## 보고 템플릿 (완료 선언 시 필수)

```
## 완료 보고

### Gate 1. 코드 검증
- 명령: `npx tsc --noEmit && npm test`
- 출력: (실측 인용)
- 결과: PASS / FAIL

### Gate 2. 기능 동작
- 명령: `curl ...` 또는 Chrome 스크린샷
- 결과: (실측 데이터)

### Gate 3. 회귀 영향
- 명령: 전체 테스트
- 결과: (N passed / N failed)

### 미해결 또는 미검증
- (있으면 솔직히 명시)
```

## 서브에이전트 호출 시 추가 규칙

서브에이전트(예: grimoire-qa) 결과를 완료 근거로 제시할 때:

- **[MUST]** raw 리포트 원문을 답변·메모리에 첨부
- **[MUST NOT]** "qa 5/5 PASS"만 쓰고 원본 생략 (CLAUDE.md §12 박제 규칙)
- **[SHOULD]** 서브에이전트 결과 중 **주요 PASS 판정 1개를 본 Claude가 독립 재현**해서 확증

## 특수 케이스

### 환경 차이 의심
dev에서 PASS인데 prod에서 FAIL 가능성:
- prod에 동일 검증 명령 재실행 (환경변수 차이 확인)
- "dev 통과 = prod 통과"로 단정 금지

### 테스트 미작성 영역
- E2E 미작성 영역은 "검증 안 됨"으로 명시. "유닛 통과 = 전체 정상"으로 둔갑 금지

### Chrome MCP 미연결
- `claude-in-chrome-recovery` Skill 발동 후 3회 재시도 → 그래도 실패면 사용자 스크린샷 요청. UI 검증 자체를 스킵하지 말 것

## 관련 정본

- `CLAUDE.md §0` ZERO-TOLERANCE — "전수검사 완료 보고 후 prod 에러는 사용자 격노 트리거"
- `memory/feedback_chrome_verify.md` — 모든 작업 후 크롬 실제 확인 필수
- `memory/feedback_playwright_verify.md` — 유닛만으로 완료 선언 금지
- `memory/feedback_fullcheck_method.md` — curl 기반 HTTP 검증
- `memory/feedback_check_actions_after_push.md` — push 후 gh run list로 Actions 성공 확인
- `production-bug-triage` Skill — 운영 증상 보고 시 검증 3단계
- obra/superpowers `verification-before-completion` (MIT 라이선스 차용)

## 검증된 회귀 사례

- 2026-04-17~19: 사용자가 격노 유발한 4건 모두 "검증 누락"이 근본 원인
  - TCC 다이얼로그: 실측 없이 "매번 허용" 답변
  - fetch aborted: 추측으로 "cold start" 단정
  - 환불 UI: 서버 catch 블록 검증 없이 "자동 환불" 문구
  - Chrome extension: 1회 실패에 "연결 불가" 단정

이 4건이 본 Skill의 존재 이유다.

---

승격 원본: obra/superpowers `verification-before-completion` (MIT)
적용 영역: ProjectGrimoire 도메인 (server NestJS / web Next.js / 양 레포 docs 동기화)
마지막 업데이트: 2026-04-25
