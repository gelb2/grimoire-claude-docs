# Grimoire 작업 진입

최신 사용자 지시를 우선한다. 프로젝트 목적·실행은 [README](README.md), 문서 정본 관계는 [docs/AGENTS.md](docs/AGENTS.md)를 따른다. 기존 사용자 변경·원고·DB를 보존하고 실행 결과만 완료로 보고한다.

Safari 등 실제 앱·웹 화면을 사용할 때는 [컴퓨터 화면 사용 스킬](.agents/skills/engineering-browser/SKILL.md)과 [Grimoire 화면 확인](BROWSER_REVIEW.md)을 읽는다. 사용자가 지정한 앱과 열린 Grimoire 탭을 우선한다. 현재 제공된 CUA의 계약을 따르며 관측→조작→새 결과 확인을 수행한다. 브라우저 공급자 오류를 Safari 앱 제어 실패로 확대하지 않는다.

반복 회귀는 기존 제품 검사 명령으로 확인한다. Playwright WebKit·Chromium 에뮬레이션을 실제 Safari·iPhone 검증으로 표시하지 않는다. 문서만 수정했을 때 무관한 전체 UI 검사를 반복하지 않는다.

현재 범위는 로컬 공개 준비다. 공개·push·원격 게시·클라우드 변경·유료 API 호출·키 유효성 시험·운영 DB 변경은 실행하지 않는다. 다른 세션이 같은 Safari를 사용 중이면 완료 안내 뒤에 이어서 사용한다.

`.claude/`, `.githooks/`, `AUTOMATION.md`와 과거 프롬프트는 당시 개발 체계의 보존 자료다. 이를 읽었다는 이유로 훅·센서·커스텀 에이전트·배포를 자동 활성화하지 않는다. 초기 참고자료의 실제 활용 설명은 [prompt-engineering/README.md](prompt-engineering/README.md)를 따른다.
