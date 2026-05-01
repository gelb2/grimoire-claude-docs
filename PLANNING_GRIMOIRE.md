# ProjectGrimoire — 기획서 (v0.2)

> 가칭. 작가별 맞춤 공간을 제공하는 소설 퍼블리싱 플랫폼.
> 구현 현황은 `grimoire-server/TECH_STATUS.md` 참조.
>
> **이 문서는 프로젝트의 최상위 정본이다.** 모든 개발 규칙(CLAUDE.md), API 명세(docs/), 코드 구현은 이 기획서에 기반한다.

---

## 0. 크레딧-원가 수익 원칙 (최상위 규칙)

> **이 원칙은 기획서의 모든 섹션, 웹/백엔드 구현, 가격 정책에 우선한다.**

### 철칙

```
크레딧 1개의 판매 수익 > 해당 크레딧이 소비하는 AI API 원가

절대로 역전되어서는 안 된다.
```

유저가 1,000원을 내고 크레딧을 충전했을 때, 그 크레딧을 전부 소진하는 데 드는 AI API 비용이 1,000원을 넘으면 **적자**다. 크레딧 가격은 반드시 AI 원가에 **마진을 얹은 값**이어야 한다.

### 원가 계산식

```
[1] API 호출 1건의 토큰 비용

  비용 = (input_tokens × input_price) + (output_tokens × output_price)

  예시 (Claude Sonnet 4.6, 2026-04 기준):
    input_price  = $3.00 / 1M tokens
    output_price = $15.00 / 1M tokens

  테마 생성 1건 (추정):
    input  ≈ 800 tokens (시스템 프롬프트 + 유저 설명)
    output ≈ 500 tokens (AuthorTheme JSON)
    비용 = (800 × 3.00 / 1,000,000) + (500 × 15.00 / 1,000,000)
         = $0.0024 + $0.0075
         = $0.0099 × ₩1,474 ≈ ₩14.6 (환율 1,474원 기준, 2026-04)

[2] 크레딧 1개의 판매 단가 (§8 반영, F1 인상 2026-04-19)

  기본   5개 / ₩2,000 → 개당 ₩400   ← F1 인상 (구 ₩1,000/₩200)
  인기  20개 / ₩3,000 → 개당 ₩150
  베스트 50개 / ₩5,000 → 개당 ₩100

[3] 결제 수수료 (Polar/Stripe 기준, §8 참조)

  Stripe 기반: 2.9% + $0.30 (고정)
  고정 수수료 = $0.30 × ₩1,474 = ₩442

  패키지별 개당 수수료 (₩):
    기본   ₩2,000 × 2.9% + ₩442 = ₩500  ÷ 5  = ₩100   ← F1 인상 결과
    인기   ₩3,000 × 2.9% + ₩442 = ₩529  ÷ 20 = ₩26.5
    베스트 ₩5,000 × 2.9% + ₩442 = ₩587  ÷ 50 = ₩11.7

  주: F1 이전(₩1,000)에는 기본 패키지 개당 수수료가 ₩94.2로 단가 ₩200의 47%를 잡아먹어
       안전배수 1.84× (CRITICAL)였음. F1 인상으로 패키지 전체 §0 PASS.

[4] 마진 검증 (AI 원가 + 결제 수수료 합산, 테마 생성 1 크레딧)

  기본   ₩400  vs 총 원가 ₩14.6 + ₩100   = ₩114.6 → 안전배수 3.49× ✅ PASS
  인기   ₩150  vs 총 원가 ₩14.6 + ₩26.5  = ₩41.1  → 안전배수 3.65× ✅ PASS
  베스트 ₩100  vs 총 원가 ₩14.6 + ₩11.7  = ₩26.3  → 안전배수 3.80× ✅ PASS

  안전 마진 기준: 판매 단가 ≥ 총 원가 × 3 — 전 패키지 통과
```

### 원가 절감 — 시맨틱 캐싱

테마 생성 시 프롬프트를 임베딩하여 기존 테마와 유사도 검색. 유사한 테마가 이미 존재하면 Claude API 호출 없이 캐시된 테마를 반환한다.

- Phase 1: 프롬프트 임베딩 → 벡터 DB에서 유사 테마 검색 (임베딩 비용만 ~₩1)
- Phase 2: 유사도 < 0.85 → Claude API 호출 (기존 비용 ~₩14)
- Phase 3: 새 테마를 벡터 DB에 저장 → 다음 검색 자산

캐시 히트율 50% 가정 시 AI 비용 **46% 절감**. 인프라(임베딩+pgvector)는 RAG용으로 이미 구축 완료.

상세 기술 검토: `TECH_REVIEW_SEMANTIC_CACHING.md` 참조.

### 원가 변동 시 대응

| 상황 | 대응 |
|------|------|
| AI 모델 가격 인상 | 크레딧 가격 인상 또는 저렴한 모델로 교체 |
| 기능 추가 (RAG 등)로 토큰 사용량 증가 | 해당 기능에 크레딧 추가 차감 또는 별도 요금제 |
| 환율 급등 | 원가 재계산 → 가격 조정 |

### 기능별 원가 테이블 (2026-04-19 F1~F3 반영)

> 수수료 `₩11.7`는 베스트 패키지(₩5,000) 개당 수수료 기준 — 최악 케이스 아님 주의.
> 기본/인기 패키지는 개당 수수료가 각각 ₩100/₩26.5로 다름. 패키지별 안전배수는 아래 시나리오 참조.

| 기능 | AI 모델 | 추정 input | 추정 output | AI 원가/회 (₩) | 크레딧 차감 | 판매가 (베스트 기준) | 안전배수 (베스트) | 판정 |
|------|---------|-----------|------------|----------------|-------------|---------------------|-------------------|------|
| 테마 AI 초안 생성 | Claude Sonnet 4.6 | ~800 tok | ~500 tok | ₩14.6 | 1 | ₩100 | 3.80× | ✅ PASS |
| AI 작품 분석 (설정/톤/캐릭터) | Claude Sonnet 4.6 | — | — | ₩60.4 | **3** | ₩300 (₩100×3) | 3.14× | ✅ PASS |
| AI 작품 분석 (Haiku 4.5 전환 시) | Claude Haiku 4.5 | — | — | ₩20.6 | **3** | ₩300 (₩100×3) | 5.39× | ✅ PASS |
| AI 채팅 1턴 | Claude Sonnet 4.6 | — | — | ₩16.2 | 1 (연동 미착수) | ₩100 | 3.58× | ⏳ 미연동 |

**패키지별 AI 작품 분석 마진 (3 크레딧 차감, Sonnet 기준)**

| 패키지 | 판매가(3×개당) | 수수료(3×개당) | 총 원가 | 안전배수 | 판정 |
|---|---|---|---|---|---|
| 기본   ₩400×3 = ₩1,200 | ₩300 | ₩60.4 + ₩300 = ₩360.4 | 3.33× | ✅ PASS |
| 인기   ₩150×3 = ₩450   | ₩79.5 | ₩60.4 + ₩79.5 = ₩139.9 | 3.22× | ✅ PASS |
| 베스트 ₩100×3 = ₩300   | ₩35.1 | ₩60.4 + ₩35.1 = ₩95.5  | 3.14× | ✅ PASS |

> **새 AI 기능을 추가할 때마다 이 테이블을 먼저 업데이트하고, `grimoire-cost-accountant` 에이전트 마진 ≥3배 검증을 받은 뒤에 구현한다.**
> 정본: `grimoire-server/docs/ai-cost-table.md`

### 모니터링 (Phase 3~)

- 실제 API 호출당 토큰 사용량을 DB에 기록 (credit_logs에 `token_usage` 필드 추가 검토)
- 월간 AI API 비용 vs 크레딧 매출 대시보드 (관리자 패널)
- 마진율이 50% 이하로 떨어지면 알림

---

## 1. 문제 정의

### 현재 소설 플랫폼의 한계

| 플랫폼                 | 작가가 커스텀 가능한 것       | 불가능한 것                       |
| ------------------- | ------------------- | ---------------------------- |
| 네이버 시리즈             | 표지 1장               | 읽기 화면, 폰트, 색상, 분위기 전부 고정     |
| 카카오페이지              | 표지 1장               | 동일                           |
| 문피아/노벨피아            | 표지 1장               | 동일                           |
| Wattpad             | 표지 + 배너             | 읽기 화면 고정                     |
| 브런치                 | 커버 사진 + 매거진 배치      | 본문 레이아웃 고정                   |
| AO3                 | CSS 스킨 직접 작성        | 코딩 능력 필요 (진입장벽 높음)           |
| **한줄 (hanline.ai)** | AI가 장면별 집필 + 비주얼 생성 | **읽기 공간 커스텀 없음** — AI 창작에 집중 |

**핵심 문제**: 작가의 작품은 각기 다른 톤과 분위기를 가지는데, 읽기 공간은 모든 작품이 동일하다.

**니즈는 존재한다**: 작가들은 이미 표지 일러스트에 돈을 쓰고, AO3에서 CSS를 직접 짜고, 브런치에서 매거진 배치에 신경 쓴다. 하지만 "읽기 공간 자체의 분위기"를 설정할 수 있는 플랫폼은 사실상 없다.

### 유사 서비스와의 포지셔닝

```
                AI 활용 축
                    ↑
    한줄(hanline.ai) │
    "AI가 글을 써줌" │         Grimoire (목표 포지션)
    AI 창작에 집중   │         "AI가 공간을 꾸며줌"
                    │         디자인 자동화에 집중
    ────────────────┼────────────────→ 공간 커스텀 축
    네이버 시리즈     │         AO3
    카카오페이지      │         (CSS 직접 작성)
    "커스텀 불가"    │         "코딩 능력 필요"
```

| 축 | 한줄 (hanline.ai) | Grimoire |
|----|------------------|----------|
| AI가 돕는 것 | **글 쓰기** (장면별 집필, 비주얼 생성) | **공간 꾸미기** (테마 생성, CSS Variable 자동화) |
| 작가의 역할 | 줄거리 입력 → AI가 집필 | 글은 작가가 씀 → AI가 읽기 공간을 디자인 |
| 핵심 가치 | 창작 속도 | 작품 몰입감 (시각적 경험) |
| 에디터 | AI 기반 집필 에디터 | 에디터 없음 — 업로드 전용 (§12) |
| 과금 | AI 창작 토큰 | AI 테마 생성 크레딧 (§0) |

**Grimoire의 차별점**: 한줄이 "AI가 글을 대신 써주는" 서비스라면, Grimoire는 **"작가가 쓴 글이 올라오는 공간 자체를 AI가 꾸며주는"** 서비스다. 글은 작가의 것이고, AI는 그 글이 가장 돋보이는 무대를 만드는 데 쓰인다.

---

## 2. 솔루션

### 핵심 컨셉

> 작가가 텍스트로 자신의 공간 분위기를 구술하면, 시스템이 그에 맞는 읽기 공간을 생성한다.

### 예시

```
작가 A (사슴악마 저자):
  "어둡고 묵직한 톤. A24 감성. 세리프 폰트. 타이핑 이펙트."
  → 지금 DeerDevil과 동일한 다크 UI

작가 B:
  "밝고 따뜻한 느낌. 크림색 배경. 손글씨체. 편안한 독서 공간."
  → 따뜻한 라이트 테마, 라운드 카드, 부드러운 트랜지션

작가 C:
  "사이버펑크. 네온. 고딕 폰트. 글리치 이펙트."
  → 다크 + 네온 강조색, 모노스페이스 폰트, 글리치 애니메이션
```

### 작가별 공간 구성

각 작가는 자신만의 독립된 공간을 가진다:

- **랜딩 페이지**: 작품 목록, 작가 소개
- **읽기 뷰어**: 본문 렌더링 (테마 적용)
- **시각적 테마**: 배경색, 폰트, 강조색, 애니메이션 스타일
- **URL**: `/{작가슬러그}/` → 해당 작가의 공간

---

## 3. 기존 자산 (DeerDevil에서 가져올 것)

| 자산 | 설명 | 재활용 방식 |
|------|------|-----------|
| MD 파서 | `parse-md.ts` — MD → TS 자동 변환 | 서버사이드 파싱으로 이관 |
| Block 시스템 | paragraph, chapter, divider, italic 등 8종 | 그대로 유지 + 확장 |
| CSS Variables | `--u-bg`, `--u-text`, `--u-border` 등 | 테마 시스템의 기반 |
| 타이핑 이펙트 | TypeWriter + 순차 페이드인 | 애니메이션 프리셋으로 분리 |
| EpisodeViewer | 타이머 안전성 확보된 뷰어 | 범용 뷰어로 확장 |
| E2E 테스트 | Playwright 22개 | 멀티테넌트 시나리오 확장 |

---

## 4. 테마 시스템 설계

### 테마 구성 요소

정확한 인터페이스는 `grimoire-web/src/features/theme/presets.ts`의 `AuthorTheme` 참조.

주요 카테고리:
- **색상** (9개): 배경, 카드 배경, 본문, 보조, 흐린, 강조, 강조2, 밝은, 경계선
- **타이포그래피** (7개): 본문/제목 폰트, 제목 크기/두께, 본문 크기, 행간, 자간
- **레이아웃** (5개): 에피소드 목록, 히어로, 톤, 애니메이션, 콘텐츠 폭
- **장식** (6개): 구분선 아이콘/색상, 헤더 아이콘, 서브타이틀, 카드 악센트, 푸터
- **고급 설정** (12개): 카드 둥글기, 섹션 간격, 소제목 스타일, 타이핑 속도 등
- **표시 옵션** (3개): 일러두기/후기/프로필 탭 표시 여부

### 테마 출처 구분 (`source` 필드)

모든 테마는 출처를 명시적으로 기록한다:

| source 값 | 의미 | 예시 |
|-----------|------|------|
| `system` | 플랫폼이 DB에 제공하는 시스템 테마 (`authorId: null`) | midnight, parchment 등 8종 |
| `ai` | 작가가 AI 텍스트 구술로 생성한 테마 | "어둡고 묵직한 A24 감성" |
| `user` | 작가가 에디터에서 직접 만들거나 수정한 테마 | 수동 편집, 프리셋 복사 후 수정 |

- 시스템 테마 8종은 DB에 `authorId: null`, `source: "system"`으로 존재
- 시스템 테마는 수정 불가. 작가가 선택하면 값을 복사하여 작가 소유 테마(`source: "user"`) 생성
- 프리셋(`presets.ts`)은 시스템 테마의 원본이자 테마 에디터의 시작점
- 운영자가 프리셋을 수정하면 시스템 테마도 갱신 (새로 선택하는 작가에게만 영향, 기존 복사본 무관)
- AI 생성 테마는 해당 작가에게 귀속
- 수동 편집 테마도 해당 작가에게 귀속

### 테마 소유와 적용

- **소유권**: 테마는 작가에게 귀속된다
- **적용 대상**: 작가 공간 전체 또는 개별 작품에 적용 가능
- **적용 우선순위**: 작품 전용 테마 > 작가 공간 기본 테마 > 시스템 테마 기본값(midnight)
- **슬롯 제한**: 구독 플랜에 따라 동시 활성화 가능 테마 수 제한 (§8 참조). 테마 생성(보유) 자체는 무제한

```
Author 1:N Theme (소유)
Theme 1:N Work (적용 — 선택적)
Author 1:1 DefaultTheme (작가 공간 기본 테마 — 선택적)
```

### 테마 프리셋

시스템이 기본 제공하는 프리셋 (`source: "system"`). 작가가 선택 후 복제·커스텀 가능:

| 프리셋 | 톤 | 구분선 아이콘 | 헤더 아이콘 | 서브타이틀 | 대상 장르 |
|--------|-----|-------------|-----------|----------|----------|
| Midnight | 다크 | book | book | Solitary Script For Midnight | 호러, 다크 판타지 |
| Parchment | 세피아 | dot | none | — | 역사, 고전 |
| Morning | 라이트 | dot | none | — | 로맨스, 일상 |
| Neon | 다크+네온 | dot | none | — | SF, 사이버펑크 |
| Cream | 따뜻한 라이트 | dot | none | — | 에세이, 시 |
| Magazine | 라이트 | dot | none | — | 매거진 스타일 |
| Gallery | 라이트 | dot | none | — | 갤러리 스타일 |
| Minimal | 라이트 | none | none | — | 미니멀 |

> **주의**: deerDevil(사슴악마) 테마는 시스템 프리셋이 아니다.
> 사슴악마 작가가 AI로 직접 생성한 테마(`source: "ai"`)이며, antler 아이콘은 사슴악마 전용이다.
> Midnight 프리셋은 deerDevil과 독립적인 색상·장식을 가진다.

---

## 5. 사용자 흐름

### 핵심 원칙: 가입한 회원 = 독자이자 작가

회원 유형을 구분하지 않는다. 모든 가입자는 소설을 읽을 수도, 쓸 수도 있다.
작가 기능은 "첫 작품을 만드는 순간" 자연스럽게 활성화된다.

### 회원가입 흐름

```
[방법 1 — 이메일 가입 (Phase 2 구현 완료)]
이메일 입력 → 비밀번호 설정 → 비밀번호 재확인 → 작가명 → 슬러그 설정 → 가입 완료 (3 크레딧 보너스)
※ 이메일 인증(verification) 없음 — 이메일+비밀번호+비밀번호재확인 입력 방식

[방법 2 — 소셜 로그인 가입 (Phase 3 예정)]
Kakao/Google 중 택 1 → 슬러그 설정 → 가입 완료 (3 크레딧 보너스)
※ Apple 로그인은 제외 (심사 요건 대비 비용 과다)
※ Kakao는 기술적 난이도 확인 후 도입 결정

[계정 연동 — 핵심]
Kakao로 가입한 유저가 나중에 Google도 연결 가능.
어떤 채널로 로그인해도 동일 계정으로 인식되어야 함.
→ 소셜 로그인 식별자를 배열(1:N)로 관리 (아래 DB 스키마 §6 참조)
```

### 작가 흐름

```
1. 가입 (이메일 or 소셜) → 슬러그 설정 (예: /deerdevil/)
2. 테마 에디터 진입 → 텍스트로 분위기 구술 [1 크레딧]
   "어둡고 묵직한 A24 감성으로 해줘"
3. AI 초안 생성 → 에디터에서 미세 조정 [무료, 무제한]
   → 작가공간 미리보기 + 에피소드 미리보기로 실시간 확인
4. 저장 (임시) → 대시보드에서 퍼블리시 → Baking (§11)
5. 원고 업로드 (업로드 화면 §12) → 자동 파싱 → 미리보기 → 퍼블리시
6. 작가 대시보드에서 테마 관리 + 조회수/작품 현황 확인 (§13)
```

#### 테마 편집/관리 흐름 (상세)

```
[테마 생성]
대시보드 → "새 테마 만들기" → 에디터 진입 (신규 모드)
  → AI 텍스트 구술 or 프리셋 선택 or 수동 편집
  → 작가공간/에피소드 미리보기로 확인
  → 저장

[테마 수정]
대시보드 → 테마 목록에서 "편집" 클릭 → 에디터 진입 (?id={themeId})
  → 기존 값이 모든 필드에 바인딩된 상태로 로드
  → 수정 → 저장

[테마 퍼블리시]
대시보드 → 테마 목록에서 "퍼블리시" → CSS Baking → 방문자에게 즉시 적용

[테마 활성/보관]
대시보드 → 테마 목록에서 활성/보관 토글 → 슬롯 점유 제어
```

### 독자 흐름

```
1. 플랫폼 접속 → 작가 목록 또는 직접 URL 입력
2. /deerdevil/ → 다크 테마 공간 진입 (CDN에서 정적 CSS 로드)
3. 에피소드 목록 → 읽기
4. /friend-author/ → 밝은 테마 공간 진입
5. 같은 뷰어 코드, 다른 시각적 경험
```

---

## 6. 기술 아키텍처

### 프로젝트 구조 (projectZenith 참고)

```
ProjectGrimoire/
├── grimoire-server/       # NestJS 백엔드
│   ├── domain/            # 비즈니스 로직
│   ├── application/       # Use Cases
│   ├── adapter/           # HTTP/DB
│   └── infrastructure/    # Prisma, 스케줄러
├── grimoire-web/          # Next.js 프론트엔드
│   ├── app/               # App Router (멀티테넌트 라우팅)
│   ├── features/          # 작가공간, 뷰어, 테마
│   └── shared/            # 공용 컴포넌트, 유틸
├── docs/                  # 공유 문서 (3레포 아닌 2레포지만 동일 패턴)
│   ├── api-contract.md
│   ├── data-model.md
│   ├── theme-spec.md
│   └── glossary.md
└── CLAUDE.md              # 루트 규칙
```

### 기술 스택

| 항목 | 기술 | 근거 |
|------|------|------|
| 프론트엔드 | Next.js (App Router) | DeerDevil 기존 스택 유지 |
| 백엔드 | NestJS | projectZenith에서 검증됨 |
| DB | PostgreSQL + Prisma | projectZenith에서 검증됨 |
| 인증 | 자체 구현 (이메일 + OAuth: Kakao/Google/Apple) | 소셜 계정 1:N 연동 |
| 파일 저장 | Supabase Storage 또는 S3 | 원고 MD 파일 |
| 배포 | Vercel (웹) + Azure 또는 Railway (서버) | 단계적 확장 |
| 테스트 | Vitest + Playwright | DeerDevil에서 검증됨 |

### DB 스키마 (v0.2)

```
users                        # 독자 = 작가 (구분 없음)
├── id (uuid)
├── slug (unique)            # URL 경로 (/{slug}/)
├── name
├── email (unique)
├── password_hash (nullable) # 이메일 가입 시
├── credits (int, default 3)
├── created_at
└── updated_at

social_accounts              # 소셜 로그인 식별자 (1:N — 핵심!)
├── id (uuid)
├── user_id (FK → users)     # 한 유저에 여러 소셜 계정 연결
├── provider (text)          # "kakao" | "google" | "apple"
├── provider_id (text)       # 소셜 서비스가 주는 고유 식별자
├── provider_email (text?)   # 소셜 서비스 이메일 (있으면)
├── created_at
└── @@unique([provider, provider_id])

themes
├── id (uuid)
├── user_id (FK → users)
├── preset ("midnight" | "parchment" | ...)
├── overrides (jsonb)        # AuthorTheme 커스텀 값
├── raw_description (text?)  # AI에 보낸 원본 구술
├── baked_css_url (text?)    # Baking된 CSS CDN URL (§11)
└── updated_at

works
├── id (uuid)
├── user_id (FK → users)
├── slug
├── title
├── subtitle
├── description
├── view_count (int, default 0)  # 작품 총 조회수
└── created_at

episodes
├── id (uuid)
├── work_id (FK → works)
├── slug
├── title
├── subtitle
├── order_num
├── blocks (jsonb)           # 파싱된 Block[]
├── raw_md (text)            # 원본 마크다운
├── source_format (text)     # "markdown" | "txt" | "html" — 업로드 원본 포맷
├── view_count (int, default 0)  # 에피소드 조회수
└── created_at

credit_logs                  # 크레딧 감사 로그 (INSERT only)
├── id (uuid)
├── user_id (FK → users)
├── amount (int)
├── reason (text)
├── created_at

signup_history               # 재가입 악용 방지
├── provider_id (text, PK)
├── first_signup_at
├── signup_count (int)
```

#### 소셜 로그인 식별자 설계 (핵심)

```
유저 A (user_id: abc-123)
  ├── social_accounts[0]: { provider: "kakao", provider_id: "K_12345" }
  ├── social_accounts[1]: { provider: "google", provider_id: "G_67890" }
  └── social_accounts[2]: { provider: "apple", provider_id: "A_XXXXX" }

→ Kakao로 로그인하든, Google로 로그인하든, 같은 유저로 인식
→ 나중에 Apple 추가 연동도 가능
→ signup_history에는 모든 provider_id를 개별 기록 (재가입 방지)
```

---

## 7. AI API 통합 설계 (YECHANGPE 프로젝트 참고)

### 참고 프로젝트

YECHANGPE_urbanProjectAuto (BidFinder) — Claude API + OpenAI Embedding을 활용한 공공입찰 분석 플랫폼. 아래 패턴은 이 프로젝트에서 검증된 것.

### Claude API 호출 구조

중앙화된 래퍼 함수로 모든 AI 호출을 관리한다:

```typescript
// grimoire-server/src/lib/claude.ts
export async function askClaude(
  systemPrompt: string,
  userMessage: string,
  options?: { maxTokens?: number }
): Promise<string>
```

### 테마 생성 파이프라인

```
작가: "어둡고 묵직한 A24 감성. 세리프. 타이핑 효과"
    ↓
grimoire-server가 Claude API 호출:
    시스템 프롬프트: "당신은 웹 테마 디자인 전문가입니다.
      아래 설명을 읽고 테마 JSON을 생성하세요.
      반드시 아래 JSON 형식으로만 응답하세요."
    + 허용된 파라미터 목록 + 예시
    ↓
Claude 반환:
    {
      "bgPrimary": "#0a0a0a",
      "textPrimary": "#d4c5a0",
      "fontBody": "serif",
      "animation": "typing",
      "tone": "dark",
      "cardStyle": "sharp"
    }
    ↓
JSON 파싱 (에러 복구 포함) → DB 저장 → 작가에게 미리보기 제공
    ↓
독자 접속 시 DB에서 테마 로드 → CSS Variables로 주입
```

### 핵심 패턴 (YECHANGPE에서 검증됨)

| 패턴 | 설명 | Grimoire 적용 |
|------|------|-------------|
| 구조화된 프롬프트 | 상세한 시스템 프롬프트 + JSON 출력 강제 | 테마 파라미터 JSON 생성 |
| JSON 파싱 에러 복구 | trailing comma 제거, 점진적 잘라내기 | 동일하게 적용 |
| 결과 캐싱 | 비용이 드는 AI 결과를 DB에 저장 | 테마 1회 생성 후 DB 저장, 재호출 방지 |
| 상태 머신 | draft → analyzing → analyzed | draft → generating → preview → published |
| 토큰 관리 | 용도별 max_tokens 차등 설정 | 테마 생성: 1,024 tokens (작은 JSON) |

### 배포 구조 (Azure)

```
grimoire-server (Azure Container Apps)
    → Claude API (Anthropic 서버, 외부 HTTP 호출)
    → PostgreSQL (Azure Database)

grimoire-web (Azure Static Web Apps)
    → grimoire-server API 호출
```

projectZenith에서 서버가 frankfurter.app(환율 API)을 호출한 것과 동일한 구조. 외부 API를 찌르는 대상만 Claude API로 바뀐다.

---

## 8. 크레딧 시스템 (Tajook 프로젝트 참고)

### 참고 프로젝트

Tajook (타죽) — Claude Haiku 기반 중고 오토바이 AI 분석 서비스. 크레딧 기반 과금 시스템이 구현되어 있음.

### 크레딧 개념

유저가 플랫폼 기능을 사용할 때 크레딧을 소비한다.

| 기능 | 크레딧 소비 | 비고 |
|------|-----------|------|
| 테마 AI 초안 생성 (Claude API 호출) | 1 크레딧 | 일일 무료 횟수 초과 시에만 |
| 커스텀 에디터로 미세 조정 | **무료** | Color Picker 등으로 직접 수정 |
| 에피소드 퍼블리시 | 무료 | - |
| 공간 유지 | 무료 | - |
| 작가에게 크레딧 선물 | 선택한 만큼 | 독자 → 작가 크레딧 이전 |

> **핵심 원칙: "돈은 AI의 창의성에 내는 것이지, 수정 작업에 내게 만들면 안 된다."**
>
> LLM은 비결정적이다 — 한 번에 작가 마음에 쏙 드는 완벽한 Hex 색상을 뽑아줄 확률은 낮다.
> 작가가 "네온 핑크가 너무 쨍한데 톤 다운해 줘"라고 텍스트를 수정할 때마다
> 1 크레딧(200원)을 태워야 한다면 불쾌감 → 이탈로 이어진다.
>
> 따라서 크레딧은 **AI 초안 생성에만** 사용하고,
> 이후 미세 조정은 **무료 커스텀 에디터**로 직접 할 수 있어야 한다.

### 테마 생성 + 수정 흐름 (수정됨)

```
[1 크레딧 소비]
작가: "어둡고 묵직한 A24 감성"
  → Claude API → Base Theme JSON 생성
  → 미리보기 표시

[무료 — 무제한]
작가: "배경색 좀 더 밝게, 강조색은 골드로"
  → 커스텀 에디터 (Color Picker, 폰트 선택, 슬라이더)
  → JSON 직접 수정 → 실시간 미리보기
  → 만족할 때까지 반복

[선택 — 1 크레딧]
작가: "아예 다른 분위기로 다시 해줘"
  → Claude API 재호출 (새로운 Base Theme)

[무료]
작가: "퍼블리시" → 테마 확정 → Baking (§11)
```

### 커스텀 에디터 (Phase 2 구현 예정)

| 기능 | 설명 |
|------|------|
| Color Picker | bgPrimary, textPrimary, accent 등 7개 색상 직접 선택 |
| 폰트 선택 드롭다운 | serif / sans-serif / monospace / handwriting |
| 폰트 크기 | compact / normal / large 토글 |
| 애니메이션 선택 | typing / fade / slide / none |
| 카드 스타일 | sharp / rounded / minimal |
| 실시간 미리보기 | 수정 즉시 CSS Variables 반영 |
| "AI로 다시 생성" 버튼 | 새 설명 입력 → 1 크레딧 소비 (명확히 고지) |

### Tajook과의 차이

| 항목 | Tajook (분석 서비스) | Grimoire (테마 생성) |
|------|-------------------|-------------------|
| AI 결과 만족도 | 분석 결과 = 정답에 가까움 (만족도 높음) | 디자인 취향 = 주관적 (만족도 편차 큼) |
| 재호출 빈도 | 낮음 (1회성 분석) | 높을 수 있음 (수정 반복) |
| 해결 | 1회 = 1크레딧 그대로 | AI 초안 1크레딧 + 수동 수정 무료 |

### 구독 플랜 + 테마 슬롯

테마의 소유권은 유저에게 있으며, 동시에 활성화할 수 있는 테마 수(슬롯)로 플랜을 차등화한다.
테마 생성(보유) 자체는 슬롯에 제한받지 않는다. 테마는 작가 공간 전체 또는 개별 작품에 적용할 수 있다.

| 플랜 | 테마 슬롯 | 일일 무료 생성 | 초과 시 | 월 가격 |
|------|----------|-------------|--------|--------|
| Free | 1개 | 3회 | 크레딧 차감 (1크레딧/회) | ₩0 |
| Pro | 3개 | 7회 | 크레딧 차감 (1크레딧/회) | 미정 |
| Premium | 8개 | 12회 | 크레딧 차감 (1크레딧/회) | 미정 |

**테마 슬롯 규칙:**
- 테마 생성은 슬롯과 무관하게 가능 (보관 상태로 생성됨)
- 슬롯이 꽉 찬 상태에서 새 테마를 활성화(슬롯 배치) → 차단 ("기존 테마를 보관으로 변경하세요")
- 테마 삭제 → 활성 상태였다면 슬롯 반환
- 재생성도 신규 생성과 동일 크레딧 차감 (할인 없음)
- 일일 무료 횟수는 유저 단위 글로벌 (테마 A 2회 + 테마 B 1회 = 3회 소진)

**업셀 동기:**
- Free → Pro: 작품이 2개 이상이면 작품별 테마 필요 → 슬롯 부족
- Pro → Premium: 작품이 6개 이상이면 슬롯 부족

**테마 적용 우선순위:**
```
작품 전용 테마 > 작가 공간 기본 테마 > 시스템 테마 기본값(midnight)
```

**구독 만기 정책:**
- 플랜 만기 시 → 모든 작품/에피소드가 **시스템 테마 기본값(midnight)**으로 폴백
- 작가의 커스텀 테마는 **삭제되지 않음** — DB에 보관 상태로 유지
- 만기 상태에서도 글과 작가공간은 시스템 기본 테마로 정상 표시됨
- 테마 에디터에서 저장/퍼블리시/AI생성 비활성화

**재구독 정책:**
- 구독 플랜 재활성화 시 → 슬롯 개수가 해당 플랜에 맞게 복원
- 작가가 **수동으로** 보관된 테마 중 원하는 것을 슬롯에 배치
- 슬롯에 배치된 테마만 작가공간에서 사용 가능
- 자동 복원 아님 — 작가가 직접 선택해야 함

**슬롯 관리:**
- 슬롯 = 동시 활성화 가능 테마 수. isSlotted=true인 테마만 카운트
- 테마 생성은 슬롯과 무관하게 가능 (보관 상태로 생성됨)
- 슬롯이 꽉 찬 상태에서 테마 활성화 → 차단
- 테마를 슬롯에서 제거 → 보관 상태 (삭제 아님)
- 테마 삭제 → 완전 삭제 + 활성 상태였다면 슬롯 반환

### 크레딧 선물 (독자 → 작가)

독자가 에피소드를 다 읽은 후 작가에게 크레딧을 선물할 수 있다.
Twitch 비트, YouTube 슈퍼챗과 유사한 모델.

```
에피소드 마지막 화면
  → "작가에게 응원 보내기" 버튼
  → 1 / 3 / 5 크레딧 선택
  → 독자 크레딧 차감, 작가 크레딧 적립
  → CreditLog에 type: "gift" 기록
```

**선순환 구조:**
독자 응원(크레딧 선물) → 작가 크레딧 적립 → 테마 생성 → 더 좋은 공간 → 독자 유입 증가

### 크레딧 적립 방법 (무료)

| 방법 | 적립량 | 조건 |
|------|--------|------|
| 가입 보너스 | 3 크레딧 | 최초 가입 시 1회 (재가입 악용 방지) |
| 첫 작품 등록 보너스 | 2 크레딧 | 첫 에피소드 퍼블리시 시 |

### 크레딧 구매 방법 (유료)

| 상품 | 크레딧 | 가격 | 단가 | 비고 |
|------|--------|------|------|------|
| 기본 | 5 크레딧 | ₩2,000 | ₩400/개 | **F1(2026-04-19) 인상** — Polar 고정수수료 $0.30 보전 |
| 인기 | 20 크레딧 | ₩3,000 | ₩150/개 | |
| 베스트 | 50 크레딧 | ₩5,000 | ₩100/개 | |

> F1 배경: 구 기본 패키지 ₩1,000은 Polar 수수료(2.9% + $0.30) 구조에서 고정 ₩442가 44%를 잠식해
> 모든 AI 기능에서 §0 안전배수 1.84× (CRITICAL) 판정을 받았다. ₩2,000 인상으로 개당 ₩400 확보 → 3.49× PASS.
> 대안으로 "최소 결제 ₩3,000 설정(기본 폐지)" 검토됐으나 소액 진입 유지 목적으로 인상 선택.

### 결제 채널 — Polar (구현 완료, KYC 대기)

> 기존 PAYAPP 검토 후 **Polar** (https://polar.sh)로 전환 결정. 글로벌 결제 지원 + Stripe 기반 안정성 + webhook 자동화.

#### 현재 구현 상태

- Polar SDK 연동 완료 (서버 + 웹)
- 2환경(dev/prod) webhook 설정 완료 (2026-04-19 inhouse 제거)
- **KYC 승인 대기 중** — 승인 전까지 test mode 운영

#### Grimoire 결제 흐름 (구현 완료)

```
[현재 — Polar webhook 자동화]
사용자가 "크레딧 충전" 클릭 (/dashboard/credits)
    → 상품 선택 (5/20/50 크레딧)
    → grimoire-server가 Polar checkout 세션 생성
    → 사용자가 Polar 결제 페이지에서 결제
    → Polar가 grimoire-server webhook 호출
        POST /api/payments/webhook
    → 결제 검증 (Polar 서명 검증)
    → 검증 성공 시:
        1. payment_logs에 결제 기록 INSERT
        2. credit_logs에 적립 기록 INSERT
        3. users.credits += 구매 크레딧 수
    → 사용자에게 "충전 완료" 알림

[향후 — PG사 확장 검토]
한국 시장 확대 시 토스페이먼츠/포트원 등 정식 PG 연동 검토
```

#### 결제 DB 스키마 (구현 완료)

```
payment_logs                    # 결제 기록
├── id (uuid)
├── user_id (FK → users)
├── product_id (text)           # "credit_5" | "credit_20" | "credit_50"
├── amount_krw (int)            # 결제 금액 (원)
├── credit_count (int)          # 부여할 크레딧 수
├── payment_provider (text)     # "polar"
├── payment_id (text)           # 외부 결제 ID (Polar에서 부여)
├── status (text)               # "pending" | "completed" | "refunded" | "failed"
├── verified_at (timestamptz?)  # 검증 완료 시각
├── created_at (timestamptz)

→ credit_logs.reason: "purchase_credit_5_{paymentId}" 형태로 결제 ID 연결
```

#### 원가 검증 연동 (§0 참조, F1 인상 반영 2026-04-19)

```
크레딧 구매 시 §0의 원가 검증이 자동 적용됨 (환율 ₩1,474, 고정수수료 ₩442):

  [결제] ₩2,000 → 5 크레딧 (개당 ₩400)   ← F1 인상 후
  [소비] 테마 생성 1회 → 1 크레딧 소비 → AI 원가 ₩14.6
  [수수료] ₩2,000 × 2.9% + ₩442 = ₩500 → 개당 ₩100
  [마진] ₩400 - ₩14.6 - ₩100 = ₩285.4 (71.4%), 안전배수 3.49× ✅

  베스트 패키지 (₩5,000, 개당 ₩100):
  [수수료] ₩5,000 × 2.9% + ₩442 = ₩587 → 개당 ₩11.7
  [마진] ₩100 - ₩14.6 - ₩11.7 = ₩73.7 (73.7%), 안전배수 3.80× ✅

→ F1 인상으로 전 패키지 §0 안전 마진 기준(3배) 통과
```

### DB 스키마 (크레딧 관련)

```
credit_logs
├── id (uuid)
├── user_id (uuid, FK → authors)
├── amount (integer)          # 양수: 적립, 음수: 소비
├── reason (text)             # 'signup_bonus', 'theme_generate', 'purchase_credit_20'
├── created_at (timestamptz)

signup_history                # 재가입 악용 방지
├── provider_id (text, PK)   # OAuth provider ID
├── first_signup_at (timestamptz)
├── signup_count (integer)
```

### 핵심 패턴 (Tajook에서 검증됨)

| 패턴 | 설명 | Grimoire 적용 |
|------|------|-------------|
| 즉시 차감 | 기능 실행 전 크레딧 먼저 차감 | 테마 생성 요청 시 즉시 차감 |
| 감사 로그 | credit_logs에 모든 거래 기록 | 동일 |
| 재가입 방지 | signup_history로 provider_id 추적 | 동일 |
| 관리자 부여 | 관리자가 직접 크레딧 설정 가능 | 동일 |
| RLS | 사용자는 자기 로그만 조회 | Supabase RLS 동일 적용 |

---

## 9. 마일스톤

### Phase 0 — 프로젝트 기반 구축
- [x] DeerDevil 프로토타입 (MD 파서, 뷰어, 타이핑 이펙트)
- [x] 유닛테스트 70개 + E2E 22개 = 92개
- [x] ProjectGrimoire 폴더 구조 (루트 + web + server)
- [x] grimoire-web에 DeerDevil 코드 이식 + 테스트 통과
- [x] GitHub 레포 2개 (private, main/develop)
- [x] GitHub Environments + CI/CD 워크플로우
- [x] 공유 문서 6개 + CLAUDE.md 3개
- [x] 기획서 (이 문서)
- [x] grimoire-web 멀티테넌트 라우팅 리팩토링 (`/universe/` → `/[author]/`)
- [x] 테마 시스템 CSS Variables 기반 동적 주입 (프리셋 8종)

### Phase 1 — 백엔드 + Claude API 테마 생성 ✅
- [x] grimoire-server NestJS 세팅 (Hexagonal 구조)
- [x] Prisma + PostgreSQL 스키마 (authors, themes, works, episodes, credit_logs)
- [x] Claude API 래퍼 + 테마 생성 API
- [x] 크레딧 시스템 (적립/차감/로그)
- [x] MD 파서 서버사이드 이관
- [x] Jest 테스트 43개 통과
- [x] Dockerfile + 문서 체계 (전수검사 통과, develop 머지)

### Phase 2 — 인증 + 원고 업로드 + 멀티테넌트 + 테마 캐싱
- [x] DB 스키마 v0.2 적용 (social_accounts, view_count, password_hash, baked_css_url, source_format)
- [x] JWT 기반 회원가입/로그인 API (이메일+비밀번호+비밀번호재확인)
- [x] **원고 업로드 화면** (에디터 아닌 업로더 — §12)
- [x] .txt 파서 추가 (줄바꿈 기반 문단 분리)
- [x] .docx 파서 추가 (mammoth → HTML → Block[])
- [x] 로그인/회원가입 웹 화면
- [x] **작가 대시보드** 기본 화면 (빠른 액션, 작품 목록, 크레딧 현황)
- [x] 멀티테넌트 라우팅 서버 연동 (`/[author]/` → API에서 테마 로드)
- [x] 서버에서 테마 로드 → CSS Variables 동적 주입
- [x] **테마 베이킹 파이프라인** (§11) — Azure Blob Storage CDN
- [x] **커스텀 테마 에디터** (AI 생성 + 프리셋 선택 + 수동 편집 — §8)
- [x] 작가 공간 미리보기 (미리보기 모달)

### Phase 3 — 소셜 로그인 + 대시보드 고도화 + 결제
- [x] 소셜 로그인 (Google OAuth 완료, Kakao 미착수)
- [x] ~~Apple 로그인~~ → **제외** (심사 요건 대비 비용 과다)
- [ ] **소셜 계정 연동** (1 유저 : N 소셜 계정 — §5, §6) — Google만 완료, Kakao 미착수
- [x] 작가 대시보드 고도화 (조회수 통계, 작품 CRUD, 분석 탭)
- [x] 타 플랫폼 대시보드 리서치 (네이버 시리즈, 카카오페이지, Wattpad 등) — 리서치 완료
- [x] 크레딧 충전 UI + 결제 연동 (Polar — KYC 대기 중)
- [x] 프로필 설정 (슬러그, 프로필 편집)

### Phase 4 — 고도화
- [x] 독자 기능 (북마크, 읽은 위치 기억, 좋아요, 댓글)
- [x] 작가 검색/탐색 (`/explore` — 인기/최신/검색)
- [x] 방문자 통계 대시보드 (`/dashboard/analytics`)
- [x] 관리자 패널 (`/admin` — 통계, 크레딧 부여, CSV, 벌크)
- [ ] .html 파서 (최후순위 — 디버깅 공수 과다)
- [ ] .pdf 파서 (텍스트 추출만, 레이아웃 보존 불가)

### Phase 5 — AI 창작 지원 (연구 단계)
- [x] YECHANGPE RAG/Vector 코드 grimoire-server 이식
- [x] 소설 도메인 임베딩 전략 설계 (`docs/ai-analysis-spec.md`)
- [x] 설정 붕괴/톤 일관성/캐릭터 어감 체크 (§14) — 서버 구현 완료
- [ ] 작가 대시보드 AI 피드백 탭 — 웹 UI 미연결

### Phase 5+ — AI 채팅 기능 (장기 검토)
- [x] AI 채팅 모듈 도입 (`/dashboard/chat` — 서버+웹 완료)
- [ ] 모델 티어링 전략 (FAQ→Haiku, 창작→Sonnet)
- [ ] 크레딧 연동 + 토큰 비용 모니터링

---

## 8. DeerDevil과의 관계

DeerDevil은 **Phase 0의 프로토타입**이자 **첫 번째 입점 작가의 공간**이다.

```
ProjectGrimoire 플랫폼
├── /deerdevil/    ← 사슴악마 (기존 DeerDevil이 여기로 이관)
├── /friend-a/     ← 다른 작가 A
└── /friend-b/     ← 다른 작가 B
```

DeerDevil의 기존 코드(뷰어, 파서, 테스트)는 grimoire-web의 코어로 흡수된다.

---

## 11. 테마 캐싱 전략 — "Theme Baking"

### 문제

독자가 `/[author]/[work]` 경로로 접속할 때마다 서버가 DB에서 커스텀 테마(JSON)를 읽어와 CSS Variable로 렌더링해야 한다. 인기 소설에 트래픽이 몰리면 테마 로딩 자체가 DB 커넥션을 갉아먹는 병목이 된다.

```
독자 접속 → API 호출 → DB 쿼리 (themes 테이블) → JSON 파싱 → CSS Variable 주입
                        ↑ 여기가 병목
```

### 해결: 테마 퍼블리시 시점에 정적 자산으로 "굽기(Baking)"

작가가 테마를 확정(퍼블리시)하는 순간, 테마 JSON을 정적 CSS 파일로 변환하여 CDN에 배포한다. 독자는 DB를 거치지 않고 정적 파일을 로드한다.

```
[작가 흐름 — 쓰기 시점]
테마 생성/수정 → Claude API → JSON → DB 저장 → 미리보기
                                                    ↓
                                              "퍼블리시" 버튼
                                                    ↓
                                        JSON → CSS 파일 생성 (Baking)
                                                    ↓
                                        CDN/정적 스토리지 업로드

[독자 흐름 — 읽기 시점]
독자 접속 → CDN에서 정적 CSS 로드 → 끝 (DB 안 거침)
```

### 구현 방안 (Phase 2에서 결정)

| 방안 | 장점 | 단점 | 적합 시점 |
|------|------|------|----------|
| **A. 정적 CSS 파일 (CDN)** | DB 부하 제로, CDN 캐시 무한, 가장 빠름 | 퍼블리시마다 파일 생성/업로드 필요 | Phase 2 — 우선 적용 |
| **B. Redis 인메모리 캐시** | DB 부하 제거, TTL 관리 용이, 실시간 반영 | Redis 인프라 추가 비용, 운영 복잡도 | Phase 3~4 — 트래픽 증가 시 |
| **C. Next.js ISR (SSG + Revalidate)** | 빌드 시 정적 생성 + 주기적 갱신, 인프라 추가 없음 | revalidate 주기 내 지연 발생 | Phase 2 — A와 병행 가능 |

### 의사결정 기록

- projectZenith에서는 Redis를 "오버 엔지니어링"으로 판단하여 미도입
- Grimoire는 **독자 트래픽 패턴이 다름** (인기 소설 → 특정 작가에 트래픽 집중)
- Phase 2에서는 **A안(정적 CSS Baking)** 우선 적용 → 트래픽 증가 시 B안(Redis) 검토
- 테마 변경 빈도가 낮으므로 (작가당 1~수회) 정적 파일 방식이 비용 대비 효과적

### Baking 파이프라인 (Phase 2 구현 예정)

```typescript
// 테마 퍼블리시 시 호출
async function bakeTheme(authorSlug: string, theme: AuthorTheme): Promise<string> {
  const css = generateThemeCSS(theme)  // JSON → CSS Variable 변환
  const path = `themes/${authorSlug}.css`
  await uploadToStorage(path, css)     // Azure Blob / CDN
  return getCDNUrl(path)
}

function generateThemeCSS(theme: AuthorTheme): string {
  return `:root {
    --g-bg: ${theme.bgPrimary};
    --g-bg-card: ${theme.bgSecondary};
    --g-text: ${theme.textPrimary};
    --g-text-muted: ${theme.textMuted};
    --g-text-bright: ${theme.textBright};
    --g-accent: ${theme.accent};
    --g-border: ${theme.border};
    --g-font-body: ${theme.fontBody};
    --g-font-heading: ${theme.fontHeading};
  }`
}
```

### 독자 흐름 (Baking 적용 후)

```
독자 접속 → Next.js 페이지 로드
  → <link rel="stylesheet" href="cdn.grimoire-book.com/themes/deerdevil.css">
  → CSS Variable 즉시 적용 (DB 쿼리 없음)
```

---

## 12. 원고 업로드 화면 — "에디터 아닌 업로더"

### 핵심 원칙

> 에디터 화면은 "에디팅 화면"이 아니다. **"업로드 화면"**이다.

- 디시인사이드/웃긴대학 같은 텍스트 에디팅 + HTML 태그 꾸미기 화면은 **만들지 않는다**
- 잘못 만들면 공수만 많이 들고, 글은 안 예쁘게 디자인되어서 더 짜증난다
- 작가들은 자기만의 글쓰기 앱(맥 앱, Bear, Notion, Obsidian, VS Code 등)을 이미 쓰고 있다
- 우리는 그 결과물을 **받아서 예쁘게 렌더링하는 데** 집중한다

### 업로드 흐름

```
작가의 글쓰기 앱 (Bear, Notion, Obsidian, VS Code 등)
    ↓ 내보내기
텍스트 파일 (.md, .txt, .html)
    ↓ 업로드
grimoire-server 파서
    ↓ 자동 파싱
Block[] 데이터
    ↓ 미리보기
작가 확인 → 퍼블리시
```

### 지원 포맷

| 포맷             | 우선순위            | 파싱 방식                    | 비고                      |
| -------------- | --------------- | ------------------------ | ----------------------- |
| Markdown (.md) | Phase 1 (완료)    | DeerDevil md-parser 이관   | frontmatter + 블록 파싱     |
| 텍스트 (.txt)     | Phase 2 (완료)    | 줄바꿈 기반 문단 분리             | 가장 단순, 가장 범용            |
| Word (.docx)   | Phase 2 (완료)    | mammoth → HTML → Block[] | Word/Google Docs 사용자 대응 |
| PDF (.pdf)     | Phase 4+        | pdf-parse 텍스트 추출         | 레이아웃 보존 불가, 안내 필요       |
| HTML           | Phase 4+ (최후순위) | DOM 파싱 → Block[] 변환      | 디버깅 공수 과다 — 최대한 뒤로      |

> **권장 포맷 안내 (업로드 화면에 표시됨)**:
> .md, .txt, .docx를 권장합니다. Bear, Obsidian, Notion, VS Code 등 대부분의 글쓰기 앱에서 이 포맷으로 내보내기를 지원합니다.
> Pages 파일은 Word(.docx)로 내보내기 후 업로드해 주세요.

### 파싱 파이프라인 (DeerDevil 패턴 확장)

```
클로드 채팅방에서 쓴 글
  → 클로드가 마크다운 아티팩트로 정리
  → HTML로 변환
  → DeerDevil md-parser가 Block[]로 파싱
  → 웹페이지에서 테마 적용하여 렌더링

이 흐름을 서버사이드에서 자동화:
  업로드된 파일 → 포맷 감지 → 적절한 파서 호출 → Block[] → DB 저장
```

### 서비스 철학 — "에디터가 아니라 퍼블리셔"

#### 기존 플랫폼의 문제 (업계 리서치)

**1. 문피아/조아라 (자유 연재 기반)**

웹 에디터를 제공하지만, 대다수의 작가는 한글(HWP)이나 스크리브너에서 글을 쓴 뒤 에디터에 복사+붙여넣기를 한다. 이때 한글의 HTML 태그가 에디터에 묻어 들어와 폰트가 깨지고 줄바꿈이 꼬인다. 작가들은 에디터에서 뭉개진 서식을 지우느라 시간을 허비하고, 플랫폼 개발자는 '복붙 버그'를 막으려고 예외 처리 코드를 유지보수한다.

출처: 웹소설 연재 갤러리 — 스크리브너/메모장 복사 서식 깨짐, 워드 붙여넣기 줄바꿈 오류, 복사 시 문장 띄워지는 문제 등 다수 보고.

**2. 카카오페이지/네이버시리즈 (에이전시/CP사 기반)**

자유 연재 시스템이 없고, 작가가 원고를 CP사(매니지먼트사)에 전달하면 CP사 직원이 내부 CMS에서 교정교열, 업로드, 서식 정리를 수작업으로 진행한다. 작가에게 직접 업로드 권한이 주어지지 않는 구조.

출처: 웹소설 작가 입문 가이드 — "CP사에서 교정교열, 플랫폼 업로드, 표지제작, 영업 마케팅, 정산 담당"

#### Grimoire의 접근

- 이 서비스는 백지상태에서 글을 쓰는 서비스가 **아니다**
- 이 서비스는 이미 업로드된 텍스트를 수정하는 서비스가 **아니다**
- 새 원고를 릴리즈하고 싶으면 → 업로드 기능으로 파일을 올린다
- 연재한 원고를 수정하고 싶으면 → 수정하기 버튼을 눌러서 파일을 다시 올린다
- 백지상태에서 글을 쓰는 것은 작가가 자신에게 맞는 워드/스크리브너/노션 등을 알아서 써야 한다
- 이미 써놓은 글을 수정하는 것은 작가가 자기 도구로 파일을 수정하고, 최종 파일만 올리는 것이 맞다

### 에피소드 상태값

| 상태 | DB 값 | 의미 | 접근 권한 |
|------|-------|------|----------|
| 업로드됨 | `upload` | 업로드만 된 상태, 아직 공개 안 됨 | 작가 본인만 |
| 공개 | `public` | 누구나 볼 수 있음 | 전체 |
| 비공개 | `nonPublic` | 로그인 필요 또는 크레딧 필요 | 조건 충족 사용자 |
| 공유 | `shared` | 공유 링크로 접근 가능 | 공유 링크 소유자 (비로그인 포함) |

> `shared` 상태는 SNS 공유(카카오톡, 페이스북, 인스타그램 등) 기능 도입 시 사용.
> 공유 링크를 타고 들어온 유저는 로그인/크레딧 여부와 무관하게 에피소드를 볼 수 있다.

### 비로그인 참여 정책

디시인사이드 스타일로 비로그인 사용자도 좋아요/댓글에 참여할 수 있다.

| 기능 | 비로그인 | 로그인 | 비고 |
|------|---------|--------|------|
| 좋아요 | 가능 (1회, 취소 불가) | 가능 (토글) | IP + 쿠키 기반 중복 방지 |
| 댓글 작성 | 가능 (닉네임+비번 입력) | 가능 (계정 기반) | 비로그인 댓글에 "(익명)" 표시 |
| 댓글 삭제 | 비번 입력 시 가능 | 본인 댓글만 가능 | 작가는 모든 댓글 삭제 가능 |
| 응원 (크레딧) | 불가 | 가능 | 크레딧 시스템은 로그인 필수 |
| 구독 | 불가 | 가능 | 구독 알림 등 계정 연동 필요 |
| 서재/북마크 | 불가 | 가능 | 개인 데이터 저장 필요 |

> Rate Limiting: 비로그인 사용자는 좋아요 10/분, 댓글 3/분으로 제한 (IP 기준).

### 업로드 화면 UI (Phase 2)

- 드래그 앤 드롭 영역 (파일 업로드)
- 또는 텍스트 붙여넣기 (클립보드에서 직접)
- 포맷 자동 감지 표시 ("Markdown으로 인식됨")
- 파싱 결과 미리보기 (테마 적용 상태)
- "퍼블리시" 버튼

---

## 13. 작가 대시보드

### 핵심 기능

| 기능 | 설명 | Phase |
|------|------|-------|
| 작품 현황 | 내 작품 목록, 에피소드 수, 상태 | 3 |
| 조회수 통계 | 작품별/에피소드별 조회수, 기간별 추이 | 3 |
| 테마 관리 | 내 테마 목록, 활성/보관, 퍼블리시, 에디터 진입 | 2 |
| 원고 관리 | 에피소드 추가/수정/삭제/순서 변경 | 3 |
| 크레딧 현황 | 잔액, 사용 내역, 충전 | 3 |
| 프로필 설정 | 작가명, 슬러그, 소셜 계정 연동 관리 | 3 |

### 분석 탭 (`/dashboard/analytics`)

작가가 본인 작품의 조회수, 좋아요, 구독자 등 통계를 한눈에 확인하는 페이지.

| 영역 | 표시 항목 | 데이터 소스 |
|------|----------|------------|
| 요약 카드 | 총 조회수, 총 좋아요, 구독자 수 | `GET /authors/:slug/profile` |
| 조회수 차트 | 작품별 30일 추이 (ViewChart 재사용) | `GET /works/:id/stats` |
| 에피소드 순위 | 에피소드별 조회수 내림차순 테이블 | `GET /authors/:slug` (works.episodes) |

> 추후 Phase 4에서 기간 필터, 에피소드별 좋아요/댓글 통계, 독자 인구통계 확장 가능.

### 테마 관리 섹션 (`/dashboard` 내)

대시보드 메인에서 테마의 **관리**(목록, 활성/보관, 퍼블리시, 작품 배정)를 담당한다.
테마의 **편집**은 테마 에디터(`/dashboard/theme?id=xxx`)에서 한다.

```
대시보드 — 테마 관리
├── 내 테마 목록
│   ├── 테마명 / 출처(AI·수동·시스템) / 상태(활성·보관)
│   ├── [편집] → /dashboard/theme?id={themeId} 이동
│   ├── [활성/보관] 토글 (슬롯 점유 제어)
│   └── [퍼블리시] → 활성 테마를 CSS로 베이킹하여 방문자에게 적용
├── 슬롯 현황: "활성 2 / 슬롯 3 (STANDARD 플랜)"
└── [새 테마 만들기] → /dashboard/theme (신규 생성 모드)
```

| 동작 | 위치 | 설명 |
|------|------|------|
| 테마 목록 조회 | 대시보드 | 내 테마 전체 목록 (활성/보관 구분) |
| 활성/보관 토글 | 대시보드 | 슬롯 점유 ON/OFF |
| 퍼블리시 | 대시보드 | 현재 활성 테마 → CSS Baking → 방문자 적용 |
| 테마 편집 | 에디터 | 색상, 타이포, 장식, 미리보기 등 편집 전용 |
| AI 테마 생성 | 에디터 | 텍스트 구술 → AI 생성 → 즉시 편집 가능 |
| 임시 저장 | 에디터 | overrides를 DB에 저장 (방문자 미적용) |

### 테마 에디터 (`/dashboard/theme?id={themeId}`)

테마의 **편집에만 집중**하는 페이지. URL 파라미터로 특정 테마를 로드한다.

#### 미리보기 영역

미리보기는 **작가공간** / **에피소드** 2개 탭으로 구성한다.

```
┌─────────────────────────────────────────────────────┐
│ [작가공간]  [에피소드]                    ← 탭 전환   │
├─────────────────────────────────────────────────────┤
│                                                     │
│   선택된 탭에 해당하는 미리보기 렌더링               │
│                                                     │
└─────────────────────────────────────────────────────┘
```

- **자동 탭 전환**: 사용자가 수정한 필드가 작가공간 관련이면 작가공간 탭, 에피소드 관련이면 에피소드 탭으로 자동 전환
- **수동 탭 전환**: 사용자가 직접 탭 클릭으로 전환 가능 (수동 전환 후에는 자동 전환 일시 중단)
- **상태 관리**: Zustand 스토어로 현재 탭 + 자동전환 여부 관리
- **화면 깜박임 방지**: 필드 변경 → 탭 전환 판단은 debounce 처리, 무한 전환 루프 방지
- **클릭 차단**: 미리보기 내 모든 링크/버튼 클릭 시 라우팅 차단 (미리보기이지 네비게이션이 아님)

#### 에피소드 관련 필드 (에피소드 탭 전환 트리거)

`typingSpeed`, `subtitleStyle`, `episodeLabelFormat`, `animation`, `sectionSpacing`, `bodyLineHeight`, `bodySize`, `contentWidth`

#### 작가공간 관련 필드 (작가공간 탭 전환 트리거)

`episodeListLayout`, `heroStyle`, `cardRadius`, `cardWatermarkOpacity`, `cardHoverLift`, `cardCtaText`, `tabPillRadius`, `labelLetterSpacing`, `showProfileTab`

#### 공통 필드 (탭 전환 안 함)

`bgPrimary`, `bgSecondary`, `textPrimary`, `textMuted`, `textDim`, `textBright`, `accent`, `accent2`, `border`, `fontBody`, `fontHeading`, `titleSize`, `titleWeight`, `letterSpacing`, `tone`, `decorations.*`, `tagline`, `showPreface`, `showAfterword`, `footerText`

#### 색상 라벨 (사용자 친화적)

| 기존 라벨 | 변경 | 설명 |
|----------|------|------|
| 배경 | 전체 배경 | 페이지 바탕색 |
| 배경2 | 카드 배경 | 카드·섹션 안쪽 색 |
| 텍스트 | 본문 글자 | 본문 텍스트 색 |
| 뮤트 | 보조 글자 | 날짜, 부제 등 보조 텍스트 |
| 딤 | 흐린 글자 | 비활성·힌트 텍스트 |
| 밝은 | 강조 글자 | 제목·강조 텍스트 |
| 액센트 | 포인트 색 | 링크, 버튼, 강조 요소 |
| 액센트2 | 포인트 보조 | 호버, 보조 강조 |
| 보더 | 구분선 | 카드·섹션 경계선 |

### 타 플랫폼 대시보드 리서치 (Phase 3 착수 시 조사)

| 플랫폼 | 리서치 포인트 |
|--------|-------------|
| 네이버 시리즈 | 작품 관리, 조회수/선호수 통계, 정산 |
| 카카오페이지 | 에피소드 예약 발행, 독자 반응 분석 |
| Wattpad | 읽기 시간 통계, 독자 인구통계 |
| 브런치 | 매거진 관리, 글 노출 순위 |
| AO3 | 히트수/쿠도스/북마크 통계 |
| Medium | 읽기 시간, 구독자 통계, 수익 대시보드 |

> 리서치 후 Grimoire에 맞는 핵심 지표를 선별하여 구현한다.

---

## 14. AI 창작 지원 — RAG/Vector (구현 완료, 크레딧 연동 2026-04-19 F2 확정)

### 개요

YECHANGPE 프로젝트에서 검증된 Claude API + OpenAI Embedding + RAG + Vector 기술을 Grimoire에 이식하여, 소설 작가에게 **창작 품질 유지 피드백**을 제공한다.

### 구현 완료 기능 (서버 + 웹 Analysis UI)

| 기능 | 설명 | 구현 위치 |
|------|------|----------|
| 설정 붕괴 감지 | "1화에서 주인공 눈 색이 갈색이었는데 5화에서 파란색이라고 씀" | `src/application/analysis/novel-analysis.usecase.ts` |
| 톤 일관성 체크 | "이 작품은 묵직한 톤인데 이 에피소드만 갑자기 가벼워짐" | 동일 |
| 캐릭터 어감 체크 | "이 캐릭터는 존댓말 캐릭터인데 반말을 쓰고 있음" | 동일 |
| 작가 대시보드 피드백 | 위 분석 결과 표시 | `grimoire-web/src/app/dashboard/analysis/page.tsx` |

### F2 — AI 분석 크레딧 확정 (2026-04-19)

> **AI 작품 분석 3유형 = 3 크레딧 차감 (Sonnet 4.6 기준)**
>
> 근거: `docs/ai-analysis-spec.md §8` 회당 원가 ₩60.4 + 패키지별 수수료(기본 ₩300/인기 ₩79.5/베스트 ₩35.1)
> 3 크레딧 시 베스트 패키지 ₩300 vs 총 원가 ₩95.5 → 안전배수 3.14× PASS.
> 1~2 크레딧 시 전 패키지 CRITICAL(안전배수 <3×)로 채택 불가. §0 기능별 원가 테이블 참조.

- 차감 지점: `novel-analysis.usecase.ts` 분석 실행 전 크레딧 3 차감
- 차감 실패 시 분석 중단 + 사용자에게 부족 크레딧 안내
- 시맨틱 캐시 히트 시에도 동일 3 크레딧 차감 (정책 단순화) — 향후 1 크레딧으로 할인 검토 여지

### F4 — Q1=(a) 에피소드 ID 모드 확정 (2026-04-24)

> **분석 화면 UX는 Claude Projects 벤치마크 정합으로 완전 전환.**
>
> 근거: `docs/ai-analysis-spec.md §6-1` (Claude 맥 앱 프로젝트 채팅 모방), `research/FEATURE_AI_ANALYSIS.md §1`
> 작가는 회차 업로드 시점에 본문을 이미 제공한 상태 — 분석 화면에서 본문 재입력(복붙) 강제는 벤치마크 위반.

- API 시그니처 변경: `POST /analysis/check { episodeId, types? }` (이전 `newEpisodeText` 제거)
- 서버는 DB의 `Episode.rawMd`로 분석, 자기 자신 청크는 RAG에서 자동 제외 (self-reference 환각 방지)
- 소유권 검증: Episode → workId → Work.authorId === JWT sub (IDOR 방지, 크레딧 차감 전 수행)
- 미완 결정 (Q2 회차 일괄 분석): 크레딧 비용(N×3) 우려로 보류, cost-accountant 검증 필요 시 P2

### 모델 티어링 로드맵 (P1, 별건)

- Haiku 4.5($1/$5)로 전환 시 분석 원가 ₩60.4 → ₩20.6 (3분의 1)
- 베스트 패키지 안전배수 5.39× 달성 가능
- FAQ/단순 질의만 Haiku, 창작 보조는 Sonnet 이중 티어링 로드맵

### 미결 사항 (P1 이하)

- [ ] AI 채팅 1턴 크레딧 차감 연동 (현재 무료 사용 중)
- [ ] 모델 티어링 (Haiku 4.5 FAQ 라우팅)
- [ ] 시맨틱 캐시 히트 시 할인 크레딧 정책

---

## 15. 탐색 페이지 (메인화면) 설계

### 섹션 구성

| 섹션 | 정렬 기준 | 설명 |
|------|----------|------|
| **인기 작품** | 조회수 (viewCount) 내림차순 | 가장 많이 읽힌 작품 |
| **최신 작품** | 등록일 (createdAt) 내림차순 | 새로 올라온 작품 |
| **응원받는 작가** | 받은 크레딧 선물 총액 내림차순 | 독자에게 가장 많이 응원받은 작가 |
| **인기 작가** | 별도 기준 필요 (아래 참조) | 가장 인기있는 작가 |

### 인기 작가 기준 (미확정)

인기 작가의 정렬 기준을 정해야 한다. 후보:

| 후보 | 장점 | 단점 |
|------|------|------|
| 총 조회수 합산 | 단순, 직관적 | 다작 작가에게 유리 |
| 구독자 수 | 팬덤 크기 반영 | 초기에 0이 많음 |
| 최근 N일 조회수 | 현재 트렌드 반영 | 계산 복잡 |
| 조회수 + 좋아요 + 구독 가중합 | 종합 지표 | 가중치 결정 어려움 |

> 결정 보류 — 실제 데이터가 쌓이면 가장 자연스러운 지표로 확정

### "응원받는 작가" vs "인기 작가" 분리 이유

- **인기 작가**: 조회수/구독 기반 — 많이 읽히는 작가
- **응원받는 작가**: 크레딧 선물 기반 — 독자가 돈을 써서 응원하는 작가
- 두 지표는 반드시 일치하지 않음 (조회수는 높지만 선물은 적을 수 있고, 그 반대도 가능)
- 크레딧 선물 기능의 가시성을 높여 선순환 촉진

---

## 10. 미결 사항

- [ ] 프로젝트명 확정 (현재 가칭 Grimoire)
- [x] 배포 인프라 확정 → **Azure 풀스택** (projectZenith과 동일)
- [x] 인증 방식 확정 → **이메일 + 소셜 로그인 (Kakao/Google/Apple)**, 소셜 식별자 배열 관리 (§5, §6)
- [x] 회원 유형 확정 → **독자 = 작가 (구분 없음)** — users 단일 테이블 (§5)
- [x] 에디터 방향 확정 → **에디터 아닌 업로더** — txt/md/html 파싱, WYSIWYG 없음 (§12)
- [ ] 첫 외부 작가 테스트 대상 확보
- [x] 수익 모델 확정 → **구독 플랜(테마 슬롯) + 크레딧(AI 생성) + 선물(독자→작가)** (§8)
- [x] 폴더 구조 확정 → **projectZenith 패턴** (루트 + 하위 독립 레포)
- [x] AI API 통합 방식 확정 → **Claude API 구조화 프롬프트 → JSON 반환** (YECHANGPE 패턴)
- [x] 크레딧 시스템 설계 → **Tajook 패턴** (즉시 차감, 감사 로그, 재가입 방지)
- [x] 크레딧 과금 vs LLM 비결정성 충돌 해소 → **AI 초안 1크레딧 + 커스텀 에디터 무료 수정** (§8)
- [x] 독자 트래픽 DB 병목 대응 → **테마 Baking 파이프라인** Phase 2 적용 (§11)
- [ ] RAG/Vector 이식 범위 + Vector DB 선택 + 비용 구조 확정 (§14)
- [ ] 작가 대시보드 핵심 지표 확정 — 타 플랫폼 리서치 후 결정 (§13)
- [ ] **외부 Anthropic API 신규 의존 (2026-04-30 사용자 명시 보류)** — Claude Code 구독 외 종량제 호출 영역 (LLM-as-Judge 실제 SDK / 모델 티어링 / agent teams / 책 Ch 17)은 사용자 재허용 시까지 진행 금지

---

## 부록. 연구/리서치 문서 (루트 보관)

| 문서 | 내용 | 관련 섹션 |
|------|------|----------|
| `research/FUNDING_RESEARCH_2026.md` | 2026년 공공 지원사업 조사 (10개 프로그램 적합성 평가) | §10 미결 사항 |
| `research/FUNDING_STRATEGY.md` | 공공 자금 신청 전략 프레임워크 (3방향) | §10 미결 사항 |
| `research/PROPOSAL_DIGITAL_SHOWROOM.md` | Phase 2 "디지털 쇼룸" 아키텍처 제안 (Gemini 피드백 기반) | §14 AI 창작 지원 |
| `research/FEATURE_AI_ANALYSIS.md` | AI 분석 + 맥락보정 기능 콘셉 + 로드맵 | §14 AI 창작 지원 |
| `research/PROPOSAL_DATA_BROKERAGE.md` | B2B 데이터 브로커리지 파이프라인 제안 | §10 미결 사항 |
| `research/RESEARCH_HANLINE_API.md` | 경쟁 서비스 한줄(hanline.ai) 기술 분석 | §10 미결 사항 |
| `research/RESEARCH_PLATFORM_CASES.md` | 글로벌/국내 창작 플랫폼 사례 분석 (Substack, Ghost 등) | §13 대시보드 리서치 |

### 레포로 이동된 연구 문서

| 원본 위치 | 이동 위치 | 내용 |
|-----------|----------|------|
| 루트 `TECH_REVIEW_SEMANTIC_CACHING.md` | `grimoire-server/research/` | 시맨틱 캐싱 기술 리뷰 (§11 Baking) |
| 루트 `PAYMENT_RESEARCH.md` | `grimoire-server/research/` | 결제 솔루션 비교 (§8 크레딧) |
| 루트 `CHAT_FEATURE_RESEARCH.md` | `grimoire-server/research/` | AI 챗 기능 연구 (§14 RAG) |
| 루트 `DESIGN_REFERENCE_READYMAG.md` | `grimoire-web/research/` | 레디맥 디자인 리서치 (테마 Phase 1/2) |

---

## 16. 변경 이력 (2026-04-19 ~ 2026-05-02 — J5 박제)

> 본 §16은 PLANNING_GRIMOIRE.md 자체의 변경 + 운영 결정사항 누적. 코드/하네스 변경은 각 레포 CHANGELOG.md / `research/HARNESS_ENGINEERING.md` 참조.

| 일자 | 결정사항 | 정본 위치 |
|------|---------|----------|
| 2026-04-19 F1 | 크레딧 가격 인상 (기본 5개/₩2,000 → ₩400/개) — Polar 고정수수료 $0.30 보전 | §8 |
| 2026-04-19 F2 | AI 분석 크레딧 3 확정 | §14 F2 |
| 2026-04-19 | inhouse 환경 제거 (3환경 → 2환경: dev/prod) | §6, §7 |
| 2026-04-24 F4 | Q1=(a) 에피소드 ID 모드 확정 | §14 F4 |
| 2026-04-25 #5 | JWT 회전 + sensor-secret-leak 신설 (P0 시크릿 회수) | server CHANGELOG |
| 2026-04-26 #6 | launchd 자율 실행 영구 비활성 (on-demand Task 호출만) | AUTOMATION.md §2 |
| 2026-04-27 #9 | 분석 크레딧 3 → 4 인상 (cost-accountant 시뮬: 베스트 2.79× → 3.35×) | §14 + ai-cost-table.md |
| 2026-04-30 #10 | CLAUDE.md 60줄 분할 (책 Ch 08+15+16) — root 73줄 + .claude/AGENTS.md + docs/AGENTS.md + .githooks/AGENTS.md + shared-contracts.md | `.claude/shared-contracts.md` + `research/HARNESS_SPLIT_AND_EDD.md` |
| 2026-04-30 #10 | **외부 Anthropic API 신규 의존 보류** (사용자 명시) — LLM-as-Judge SDK / 모델 티어링 / agent teams 보류 | §10 미결 사항 |
| 2026-04-30 #10 | EDD 모드 도입 (책 Ch 15) — eval-runner --mode=edd, runs=10, category별 threshold | `research/HARNESS_SPLIT_AND_EDD.md` §17.3 |
| 2026-05-01 #10_2 | 핸드오버 박제 (사용자 외출 → 리모트 채팅방 인계) | `HANDOVER_NEXT_SESSION.md` |
| 2026-05-01 #10_3 | 묶음 E~H 자율 진행 (sensor-agent-priority-labels WARN 0 / DOC_MAP v2.1 / orchestration-decision Skill / sensor-eval-trend) | `memory/project_session_20260501_2.md` |
| 2026-05-02 #10_4 묶음 I | sensor-log 9개 통합 + update-harness-inventory generator + PASS-only 면제 박제 | AUTOMATION.md §3 + §4.2 |
| 2026-05-02 #10_4 묶음 K' | pre-commit hook에 update-harness-inventory --apply 통합 + baseline 노이즈 차단 | `.githooks/pre-commit` |
| 2026-05-02 #10_4 묶음 J | orchestration-decision Skill 자가 분류 의무 + PostToolUse Task hook + reports 골격 정합 (책 Ch 16) | `.claude/AGENTS.md §2.2.1` |
| 2026-05-02 #10_4 묶음 K | drift-check §17 검증 + book 운영 데이터 + feedback 14일 단축 | `.claude/knowledge/book-harness-engineering-completion.md` |
| 2026-05-02 #10_4 묶음 L | HARNESS §13/§15/§17 분리 (1328 → 1105줄) — `HARNESS_FIELD_PATTERNS_4.md` + `HARNESS_BIBLIOGRAPHY.md` + `HARNESS_SPLIT_AND_EDD.md` | `research/HARNESS_*.md` 4개 |

### 운영 정책 강화 누적 (2026-04-25 ~ 2026-05-02, 외부 API 0)

- **하네스 분할 정본 확립**: CLAUDE.md (73) + .claude/AGENTS.md (126) + docs/AGENTS.md (195) + .githooks/AGENTS.md (142) + shared-contracts.md — instruction degradation 위험 해소
- **에이전트 7개 모두 분할 완료**: 각 ≤ 300줄 (sensor-instruction-degradation 11/11 PASS)
- **인벤토리 자동 갱신**: pre-commit hook + update-harness-inventory.sh — 새 sensor/skill 추가 시 HARNESS §14 자동 갱신
- **위임 매트릭스 자가 분류**: 작업 시작 전 orchestration-decision Skill 강제 (책 Ch 16 패턴 1 KPI 추적)
- **회귀/EDD 시계열 추적**: sensor-eval-trend (30일 mean / 7일 slope / 회귀 빈도 임계)
- **인벤토리 (2026-05-02)**: Skills 20 / Sensors 17 / Knowledge 6 / Hooks 9 이벤트 11 스크립트 / Generators 2 / Eval task 33

본 §16은 다음 PLANNING 갱신 시 (J5 후속) 추가로 누적.
