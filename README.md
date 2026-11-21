# Grimoire

Grimoire는 작가가 원고를 올리고 작가 홈, 회차 목록, 읽기 화면을 꾸미는 소설 발행 플랫폼이다. 개인 소설 뷰어 DeerDevil에서 출발했다. 모두의 창업에 지원했으나 선정되지 않았고 서비스 운영을 접었다. 웹·서버 소스와 개발 문서를 공개했다.

- [개발 회고](docs/retrospective.md) · 시작한 이유, 직접 한 일, 프로젝트를 접고 코드를 공개한 이유
- [구현과 수정 기록](docs/implementation.md) · 원고 업로드, 작가 홈, 테마, 회차 카드 복원, 글꼴과 화면 밀림

## 저장소 배치

공개 저장소 세 곳을 아래 구조로 받는다.

```text
ProjectGrimoire/              ← grimoire-claude-docs (이 허브)
├── grimoire-web/             ← grimoire-web
├── grimoire-server/          ← grimoire-server
├── scripts/local-run.mjs
├── PLANNING_GRIMOIRE.md
├── DOC_MAP.html
└── HARNESS_MAP.html
```

```sh
git clone https://github.com/gelb2/grimoire-claude-docs.git ProjectGrimoire
git clone https://github.com/gelb2/grimoire-web.git ProjectGrimoire/grimoire-web
git clone https://github.com/gelb2/grimoire-server.git ProjectGrimoire/grimoire-server
```

DeerDevil 원고는 이 프로젝트를 만든 사람이 직접 썼다. 빈 데이터베이스에서 실행할 때는 서버의 가상 시드를 사용할 수 있다.

## 로컬 실행

Node.js 22.19 이상/npm과 별도 PostgreSQL을 준비한다. 기존 DB와 환경 파일을 보존한다.
설치·설정·마이그레이션·가상 시드·관리자·시작 명령은
[환경 정본](https://github.com/gelb2/grimoire-server/blob/main/docs/environments.md#공개-준비용-로컬-실행-2026-11-13)을 따른다.
로컬 실행 명령은 외부 키와 주기 작업을 비활성화하고 API 3000/웹 3001에 연결한다.
DB는 기존 기본 포트와 분리한 루프백 55432를 사용한다.

웹은 Next.js App Router/BFF, 서버는 NestJS의 UseCase와 포트·어댑터, DB는 Prisma/PostgreSQL이다.
AI·Google·GCS·메일·Polar 결제 기능은 보존하며, 실제 연동에는 자신의 설정이 필요하다.
직접 개발 실행과 Docker·GCP 실행의 차이도 환경 정본에서 설명한다.

## 기획과 개발 기록

GMP를 AI의 초기 참고자료로 넣고 요구사항을 기능·제약·입출력·검사 기준으로 정리하는 데 활용했다. 이후 Grimoire의 기획 정본, 역할별 프롬프트, 문서 동기화와 검증 장치를 연결했다. [참고자료를 개발 규칙으로 연결한 과정](prompt-engineering/README.md)에서 구상과 실제 파일을 대조할 수 있다.

- [현재 작업 진입](AGENTS.md), [브라우저 화면 확인](BROWSER_REVIEW.md).
- [작가 공간·독서 화면 시장 재검토](research/MARKET_REVIEW_2026-11-14.md): 초기 가설과 현재 공식 기능의 차이.
- [기획 정본](PLANNING_GRIMOIRE.md): 문제 정의, 테마·원고·포인트 정책과 결정 이력.
- [문서 관계도](DOC_MAP.html): 기획→규칙→서버/웹 명세→구현의 관계. 로컬 브라우저에서 연다.
- [하네스 관계도](HARNESS_MAP.html): 당시 역할·훅·센서·스킬의 시각 자료.
- [현행 문서 정본 관계](docs/AGENTS.md): 서버/웹 공유 명세의 소유자와 동기화 규칙.
- [하네스 조사 정본](research/HARNESS_ENGINEERING.md): 당시 구성과 도입 이유.
- 외부 자료 고지 · [웹·글꼴](https://github.com/gelb2/grimoire-web/blob/main/THIRD_PARTY_NOTICES.md), [서버 의존성](https://github.com/gelb2/grimoire-server/blob/main/THIRD_PARTY_NOTICES.md)
- [서버 검사 전략](https://github.com/gelb2/grimoire-server/blob/main/TESTING.md), [웹 검사 전략](https://github.com/gelb2/grimoire-web/blob/main/TESTING.md)

과거 하네스·배포 문서는 당시 개발 기록이다. 지금 로컬에서 실행할 때는 위 환경 문서의 순서를 따른다.
