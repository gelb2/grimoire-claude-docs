# Grimoire

작가가 원고를 올리고 작품마다 읽기 공간을 꾸미는 소설 퍼블리싱 플랫폼이다.
‘모두의 창업’ 지원을 목적으로 만들었으나 선정되지 않았다. 웹·서버 구현과 당시의
하네스·에이전트·스킬·문서 체계를 개발 증빙으로 공개하기 위해 준비하고 있다.

## 저장소 배치

세 개의 독립 저장소를 사용한다. 허브만 clone해도 웹·서버가 내려오지는 않는다.
자신이 접근할 수 있는 각 저장소 URL을 확인한 뒤 아래 구조로 받는다.

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
git clone <hub-repository-url> ProjectGrimoire
git clone <web-repository-url> ProjectGrimoire/grimoire-web
git clone <server-repository-url> ProjectGrimoire/grimoire-server
```

DeerDevil 원고는 사용자가 직접 쓴 저작물이며, 고전문학 원문은 저작권이 없는 자료라는
사용자 확인을 받았다. 외부 참고책자 원본과 자격증명은 공개 후보에서 제외한다.
공개 URL과 자체 소스 라이선스는 아직 확정하지 않았다. 새 DB의 실행 확인에는 가상 시드를 사용할 수 있다.

## 로컬 실행

Node.js 22.19 이상/npm과 별도 PostgreSQL을 준비한다. 기존 DB와 환경 파일을 보존한다.
설치·설정·마이그레이션·가상 시드·관리자·시작 명령은
[환경 정본](grimoire-server/docs/environments.md#공개-준비용-로컬-실행-2026-11-13)을 따른다.
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
- 외부 자료 고지: [웹·글꼴](grimoire-web/THIRD_PARTY_NOTICES.md), [서버 의존성](grimoire-server/THIRD_PARTY_NOTICES.md). 설치 후 `npm run notices`로 실제 운영 의존성의 원문과 출처를 갱신한다.
- [서버 검사 전략](grimoire-server/TESTING.md), [웹 검사 전략](grimoire-web/TESTING.md).

과거 하네스·배포·운영 문서는 해당 시점의 기록이다. 파일이 있다는 사실과 실제 실행된
근거를 구분한다. 설치 직후 오래된 훅·센서·배포 스크립트를 자동 실행하지 않는다.
현재 작업은 로컬 공개 준비이며 공개 전환·원격 게시·클라우드 변경을 수행하지 않는다.

개발에 참고한 외부 책자 원본은 저장소 밖에 보관한다. 이 저장소에는 직접 작성한 조사·적용 기록과 원문 출처만 남긴다.
