---
name: claude-in-chrome-recovery
description: Claude-in-Chrome 확장 프로그램 MCP 도구(`mcp__Claude_in_Chrome__tabs_context_mcp`, `navigate`, `read_page`, `javascript_tool` 등)가 "not connected" 반환하거나, navigate 직후 URL이 반영되지 않거나, 읽기·클릭이 응답 없음 상태가 될 때 발동. 1~2회 실패로 "extension이 꺼져 있다"고 조기 결론 내리지 말 것. 최소 3회 재시도 + 확인 프로토콜 강제.
allowed-tools: Bash
triggers:
  - "not connected"
  - "extension"
  - "Chrome extension"
  - "크롬 확장"
  - "tabs_context_mcp"
  - "navigate"
  - "Claude-in-Chrome"
  - "크롬 확인"
  - "브라우저 확인"
  - "크롬 안 되"
  - "extension 꺼졌"
  - "claude in chrome"
effort: medium
trigger-mode: keyword (triggers field) — paths 미적용 명시 (NEW-16 J4 패턴)
---

# Claude-in-Chrome 확장 복구 프로토콜

> **trigger-mode**: keyword (triggers field 9건). paths 미적용 — Chrome MCP 호출 결과에 따라 발동 (파일 매칭 무관).

## 언제 발동하는가

다음 증상 중 1개 이상:
- `mcp__Claude_in_Chrome__tabs_context_mcp` 호출 → "not connected" 또는 빈 응답
- `mcp__Claude_in_Chrome__navigate` 호출 후 `read_page`에서 여전히 이전 URL의 컨텐츠 반환
- `mcp__Claude_in_Chrome__find` 호출 → 요소가 확실히 있는데 `null` 반환
- Chrome MCP 호출이 30초 이상 무응답

## 절대 금지 사항

### [MUST NOT] 1~2회 실패로 "extension 꺼짐" 단정
2026-04-19 세션 #4에서 `tabs_context_mcp` 1회 실패 → "connection 불가" 보고 → 실제로는 일시적 세션 드롭이었음. 사용자에게 Chrome 전수검사 지시 미수행 상태로 커밋. 재발 방지.

### [MUST NOT] 배포·UI 전수검사를 "extension 문제"로 스킵
Chrome 연결이 진짜 안 되면 curl·Playwright·사용자 요청 스크린샷 등 **대체 경로**로 우회해야지, 전수검사 자체를 스킵하면 CLAUDE.md §0 "기만적 보고" 위반.

## 복구 프로토콜 (3단계 재시도)

### 1단계 — 즉시 1차 재시도 (간격 없음)

동일 도구를 **한 번 더** 호출. MCP 세션 드롭은 1회 미스 후 2회차에 회복되는 경우가 흔함.

- `tabs_context_mcp` 실패 → `tabs_context_mcp` 재호출
- `navigate` 후 read 실패 → `navigate` 재호출 → `read_page`

### 2단계 — `javascript_tool`로 URL 검증

navigate가 반영됐는지 `javascript_tool`로 확인:

```javascript
// 실행
"location.href"
```

반환 값이 기대한 URL과 일치하지 않으면 → navigate 재호출. 일치하면 2단계 성공.

### 3단계 — 새 탭 생성 우회

- `tabs_close_mcp`로 문제 탭 정리 후 `tabs_create_mcp`로 재생성
- `tabs_context_mcp` 재확인

### 실패 기준

위 3단계를 **모두** 수행했는데도 실패하면 사용자에게:
```
Chrome 확장이 실제로 연결되지 않은 상태로 판단됩니다. 실측 근거:
- 1차 호출: {에러 원문}
- 2차 호출: {에러 원문}
- javascript_tool location.href: {실제 반환값 또는 에러}
- 새 탭 생성: {성공/실패}

Chrome 확장 상태 확인 부탁드립니다. 그 사이 대체 경로로 {Playwright/curl/스크린샷 요청} 진행하겠습니다.
```

## 대체 검증 경로 (Chrome 진짜 불가 시)

### curl로 HTML 응답 확인
```bash
curl -s https://grimoire-book.com/{path} | head -100
curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" {url}
```

### Playwright E2E (grimoire-web)
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web
npm run test:e2e -- {pattern}
```

### Claude Preview MCP (개발 서버 실행 중인 경우)
- `mcp__Claude_Preview__preview_start` / `preview_screenshot` 등 사용 가능

### 사용자 스크린샷 요청
마지막 수단으로 사용자에게 "{URL} 화면 스크린샷을 공유해 주세요"라고 요청. 단, 실제 Chrome MCP 실패가 3단계 재시도로 확인된 경우에만.

## 대기 간격 기준

- 1차 → 2차: 0초 (즉시)
- 2차 → 3단계 javascript_tool 확인: 1초 (단, sleep 명령 최소화)
- 3단계 실패 시 → 탭 재생성: 즉시

> MCP 호출 자체의 타임아웃이 이미 포함되어 있으므로 Bash `sleep`으로 추가 지연 주지 말 것. 만약 5분 이상 지연 필요 시 사용자에게 확인 후 진행.

## 관련 정본

- `memory/project_session_20260419_4.md` (Chrome extension 조기 포기 실수 사례)
- `grimoire-server/HANDOVER.md §4` (함정 목록 — Chrome extension 항목)
- `CLAUDE.md §0` (ZERO-TOLERANCE — 기만적 보고 금지)

## 검증된 이력

- 2026-04-19 세션 #4: `tabs_context_mcp` not connected 1회 → 조기 포기 → 이후 사용자 재지시로 전수검사 재개. 당시 재시도 규정 부재로 프로토콜화 결정.

---

마지막 업데이트: 2026-04-25
