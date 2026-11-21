# Grimoire 구현과 수정 기록

Grimoire에서는 작가가 원고를 올려 회차로 발행하고 작가 홈, 회차 목록, 본문의 테마를 고른다. 독자는 탐색 화면에서 작품을 찾아 작가 홈에 들어가고, 회차 하나를 골라 본문을 읽는다. [개발 회고](retrospective.md)

## 원고와 테마

웹은 Next.js App Router로 탐색, 작가 홈, 작품, 회차 읽기 경로를 제공한다. NestJS 서버는 원고를 받아 문단, 제목, 구분선 등 화면에 그릴 블록으로 파싱한다. 원문, 회차, 테마 설정은 Prisma를 통해 PostgreSQL에 저장한다. 웹은 원고 블록과 테마 설정을 따로 받아 배경, 글자색, 서체, 장식 값을 CSS 변수에 넣는다. 같은 회차를 두고 테마를 바꿀 수 있다. [서버 원고 파서](https://github.com/gelb2/grimoire-server/blob/main/PARSER.md) · [웹 테마 명세](https://github.com/gelb2/grimoire-web/blob/main/docs/theme-spec.md)

작가는 프리셋을 고르거나 원하는 분위기를 문장으로 적어 테마를 만들 수 있다. AI는 작가가 적은 분위기를 색·서체·장식 설정으로 바꾼다. [테마 화면](https://github.com/gelb2/grimoire-web/blob/main/SCREENS.md)

![Grimoire의 테마 만들기 화면. AI 생성과 프리셋 선택을 제공한다.](media/grimoire/grimoire-theme.png)

## 원고 파일 업로드

웹의 API 경로는 브라우저 요청을 NestJS 서버에 전달한다. 이 경로에서 DOCX와 이미지가 들어 있는 업로드 본문을 텍스트로 읽으면 바이너리 바이트가 바뀐다. 요청을 `arrayBuffer()`로 읽어 원래 `Content-Type`과 함께 넘기도록 고쳤다. 업로드 검사는 `multipart/form-data` 요청의 본문 바이트가 서버 호출에도 그대로 들어가는지 비교한다. [중계 코드](https://github.com/gelb2/grimoire-web/blob/main/src/app/api/%5B...path%5D/route.ts) · [업로드 검사](https://github.com/gelb2/grimoire-web/blob/main/src/app/api/%5B...path%5D/route.test.ts)

## 사슴악마 회차 카드 복원

2026년 5월 19일 백업을 복원하니 사슴악마 작가 홈에서 가로로 나열됐던 회차 카드가 사라져 있었다. `main`과 `develop`의 관련 웹 파일 7개는 같았다. 백업의 테마에는 `layout: series`가 남아 있었다. 현재 렌더러는 `episodeListLayout`을 읽어서 예전 값을 놓쳤다.

새 설정이 있으면 먼저 읽고, 없으면 예전 `layout`에 들어 있는 레이아웃 값을 읽도록 바꿨다. 작가 홈(`/deerdevil`)에는 원래의 가로 카드가 돌아왔다. 개별 작품 페이지(`/deerdevil/deerdevil`)에는 세로 회차 목차가 있다. 복원 데이터로 Safari에서 작가 홈의 카드에서 1화로 들어가고, 2화로 이동한 뒤, 카드 목록으로 돌아오는 흐름을 확인했다. [레이아웃 선택 코드](https://github.com/gelb2/grimoire-web/blob/main/src/features/theme/episode-list-layout.ts)

## 글꼴과 화면 밀림

작가 홈과 본문은 EB Garamond와 Noto Serif KR을 함께 쓴다. Sass의 글꼴 자체 서빙과 대체 글꼴 크기 보정, Candidate의 선택적 사전 로딩을 참고했다. Grimoire에서는 한글에도 적용되던 라틴 대체 글꼴 크기 보정을 제거했다. Noto Serif KR 파일은 앱에서 직접 제공하고 제목과 목차에 필요한 조각을 먼저 받도록 했다. 첫 화면에 필요한 탐색·작가·작품 데이터는 서버에서 전달하고, 타이핑 제목과 원고가 차지할 자리를 먼저 확보했다.

복원 데이터로 Chrome에서 탐색, 작가 홈, 작품, 1화 본문을 폭 375px과 1440px에서 처음 열고 다시 열었다. 변경 전 최대 누적 레이아웃 이동(CLS)은 약 0.38이었고, 변경 후 16조건에서 모두 0이었다. [글꼴과 CLS 계측](https://github.com/gelb2/grimoire-web/blob/main/reports/FONT_CLS_REVIEW_2026-11-14.md)

## 저장소와 로컬 실행

- [허브](../README.md)는 세 저장소를 받는 명령과 로컬 실행 순서를 안내한다.
- [웹](https://github.com/gelb2/grimoire-web)은 작가 홈, 테마 편집, 회차 읽기, 브라우저 요청 중계를 담는다.
- [서버](https://github.com/gelb2/grimoire-server)는 원고 처리, API, 데이터베이스 마이그레이션, 가상 시드를 담는다.
- [기획서](../PLANNING_GRIMOIRE.md), [웹 테마 명세](https://github.com/gelb2/grimoire-web/blob/main/docs/theme-spec.md), [서버 API 명세](https://github.com/gelb2/grimoire-server/blob/main/docs/api-contract.md)에 기획과 구현의 세부 내용이 있다.
