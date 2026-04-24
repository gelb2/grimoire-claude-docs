# RESEARCH — Competitive Landscape (Live Cache)

> **계층**: 🌊 Live — 경쟁사/시장 데이터 캐시
> **관리자**: `grimoire-researcher` 에이전트
> **정책**: 매일 Daily Discovery + Freshness Sweep, TTL 14일, Provenance 체인 유지
> **Git 추적**: ❌ (루트 전용, 커밋 금지)

---

## 사용 규칙

### 🔍 누가 참조하는가
- `grimoire-planner` — 신규 기획 벤치마킹
- `grimoire-visual-canon-keeper` — 경쟁사 디자인 레퍼런스
- `grimoire-cost-accountant` — 경쟁사 가격/구독 모델 비교
- `grimoire-researcher` — 자기 캐시 갱신

### ⚠️ 참조 시 주의
1. `staleAfter` 확인 — 지났으면 "현재 상태는 다를 수 있음"
2. `confidence: deprecated` 항목은 과거 사례만
3. Provenance id 인용 권장
4. 작가 본인의 소설 콘텐츠는 절대 수집/저장 금지 (메타정보만)

### 🔄 스윕 주기
- **매일** 18:04 KST launchd 자동 실행
- Daily Discovery + Freshness Sweep 통합

### 📅 스윕 이력
- **2026-04-15 (초기 시드)**: 1개 항목 (한줄/hanline.ai). 부록 A 추가는 첫 launchd 실행 시.
- **2026-04-16 (첫 전면 스윕)**: +2개 항목 (네이버 시리즈, 카카오페이지). 한줄 재검증.

---

## 카테고리 목차

- [1. 국내 소설 플랫폼](#1-국내-소설-플랫폼)
- [2. 해외 소설 플랫폼](#2-해외-소설-플랫폼)
- [3. AI 창작 / 에디터 서비스](#3-ai-창작--에디터-서비스)
- [4. 블로그 / 매거진 / 작가 공간](#4-블로그--매거진--작가-공간)
- [5. 디자인/테마 시스템](#5-디자인테마-시스템)
- [부록 A. 스윕 예정 항목](#부록-a-스윕-예정-항목)

---

## 1. 국내 소설 플랫폼

### 🟢 naver-series-2026-04-16

```yaml
id: naver-series-2026-04-16
service: "네이버 시리즈 — 웹소설 연재 플랫폼"
category: "domestic-novel-platform"
collectedAt: 2026-04-16
lastVerifiedAt: 2026-04-16
staleAfter: 2026-04-30
confidence: verified
sources:
  - url: "https://namu.wiki/w/네이버웹소설"
    title: "네이버웹소설 — 나무위키"
    accessedAt: 2026-04-16
  - url: "https://theparang.com/entry/2-웹소설-시장-분석-플랫폼별-특징과-수익-구조-총정리"
    title: "웹소설 시장 분석: 플랫폼별 특징과 수익 구조 총정리"
    accessedAt: 2026-04-16
```

**서비스 개요**
- 네이버 자회사 운영. 국내 최대 웹소설 플랫폼 중 하나.
- 정식연재(계약) + 베스트리그(자유 연재) 이중 트랙.
- 남녀 비율 균형, 판타지·무협·SF·로맨스 고루 인기.
- 주 2회 연재 기본.

**수익 분배**
- 플랫폼 수수료: ~30%
- 매니지먼트(출판사): 남은 70% 중 30% → 작가 실수령 ~49%
- 다운로드 1건당 작가 수령: 약 ₩20~30

**작가 커스텀 범위**
- **극히 제한적**: 표지 이미지만 커스텀 가능 (플랫폼이 일러스트레이터 배정)
- 작가별 독립 URL 공간: **없음** (플랫폼 통일 UI)
- 테마/CSS/배경색 변경: **불가**
- 읽기 뷰어: 플랫폼 표준 뷰어 강제

**구독/결제 모델**
- 편당 유료 결제 (쿠키 시스템)
- 기다리면 무료 (기다무) 모델 병행
- 네이버플러스 멤버십으로 쿠키 지급

**Grimoire 차별점**
- 네이버 시리즈 = 대형 플랫폼, 작가 공간 커스텀 전무
- Grimoire = 작가별 독립 URL + AI 테마 생성 + 완전 커스터마이징
- **네이버 시리즈에서 연재하는 작가도 "나만의 공간"은 Grimoire에서** → 공존 가능

**[확인 필요]**
- 2026년 신규 기능 변경사항
- 정확한 MAU 수치
- 베스트리그 최신 정책

---

### 🟢 kakaopage-2026-04-16

```yaml
id: kakaopage-2026-04-16
service: "카카오페이지 — 웹소설/웹툰 플랫폼"
category: "domestic-novel-platform"
collectedAt: 2026-04-16
lastVerifiedAt: 2026-04-16
staleAfter: 2026-04-30
confidence: verified
sources:
  - url: "https://brunch.co.kr/@@gB3T/7"
    title: "카카페 조회수100만 수익. 웹소설작가 얼마 벌까 공개"
    accessedAt: 2026-04-16
  - url: "https://www.threads.com/@dotori_7777/post/DB56bP9BVPZ"
    title: "카카오페이지 작가 수익 구조"
    accessedAt: 2026-04-16
  - url: "https://namu.wiki/w/웹소설%20작가"
    title: "웹소설 작가 — 나무위키"
    accessedAt: 2026-04-16
```

**서비스 개요**
- 카카오엔터테인먼트 운영. 네이버 시리즈와 함께 국내 양대 플랫폼.
- 웹소설 + 웹툰 통합 플랫폼.
- 기다리면 무료(기다무) 모델의 원조.

**수익 분배**
- 플랫폼 수수료: 30~50%
- 출판사에 약 ₩60 전달 (₩100 기준)
- 작가:출판사 비율: 보통 7:3~8:2
- 작가 실수령: 약 ₩40~42/편 (₩100 기준, 세전)
- 세금 3.3% 공제 후 약 ₩40

**작가 커스텀 범위**
- **극히 제한적**: 네이버 시리즈와 동일하게 표지만 가능
- 작가별 독립 URL: **없음**
- 테마/CSS 변경: **불가**
- 플랫폼 통일 뷰어 강제

**구독/결제 모델**
- 편당 유료 (캐시 시스템)
- 기다무 모델 (일정 시간 후 무료 공개)
- 카카오페이지 프로모션/이벤트 빈번

**Grimoire 차별점**
- 카카오페이지도 네이버와 마찬가지로 작가 공간 커스텀 전무
- 플랫폼이 모든 UX 통제 → 작가 개성 표현 불가
- Grimoire는 이 gap을 정확히 타겟 ("작가의 무대")

**[확인 필요]**
- 2026년 최신 수수료율 변경 여부
- 카카오페이지 스테이지(독립 작가 연재) 최신 상태
- 정확한 MAU

---

## 3. AI 창작 / 에디터 서비스

### 🟢 hanline-ai-2026-04-15

```yaml
id: hanline-ai-2026-04-15
service: "한줄 (hanline.ai) — AI 창작 플랫폼"
category: "ai-creative-writing"
collectedAt: 2026-04-15
lastVerifiedAt: 2026-04-15
staleAfter: 2026-04-29
confidence: verified
sources:
  - url: "https://www.hanline.ai/"
    title: "한줄 — AI 창작 플랫폼 공식"
    accessedAt: 2026-04-15
```

**서비스 개요**
- AI가 줄거리를 받아 소설/웹툰/영상 콘텐츠를 **장면별로** 작성하면서 비주얼도 생성.
- 모든 장르/언어 지원.
- AI 창작 토큰 기반 과금 (정확한 가격 [확인 필요]).
- **Grimoire와의 가장 직접적인 비교 대상.**

**Grimoire 차별점 (PLANNING_GRIMOIRE.md §1 인용)**
- 한줄 = AI가 **글 쓰기** (장면별 집필, 비주얼 생성)
- Grimoire = AI가 **공간 꾸미기** (테마 생성, CSS Variable 자동화)
- **글은 작가가 씀 → AI는 그 글이 가장 돋보이는 무대를 만든다**

**시각/UX 분석**
- AI 창작에 집중, 작가별 공간 커스텀은 부재
- 에디터 중심 UX
- Grimoire는 에디터 없음 — 업로드 전용 (PLANNING §12)

**§0 원가 적용 인사이트**
- 한줄은 "AI가 글을 대신 쓰기" 때문에 토큰 사용량이 매우 큼 (시나리오 1편 = 수만~수십만 토큰)
- Grimoire는 "테마 1건 ≈ 1300 토큰"으로 압도적으로 저렴
- → Grimoire의 §0 마진 구조가 한줄보다 본질적으로 안전

**제외 영역 (Grimoire가 가지 않는 길)**
- AI가 작가 글을 쓰는 것 (작가 정체성 침해)
- 비주얼 자동 생성 (작가 디자인 권한 침해)
- 에디터 통합 (Grimoire는 업로드 전용 유지)

**[확인 필요]**
- 한줄 정확한 가격표 (다음 스윕에서 hanline.ai 직접 방문해서 갱신)
- 사용자 수
- 월간 활성 작가 수

---

## 부록 A. 스윕 예정 항목 (미검증)

| 우선순위 | 서비스 | 카테고리 | 수집 필요 항목 |
|---|---|---|---|
| ~~High~~ | ~~**네이버 시리즈**~~ | ~~국내 소설 플랫폼~~ | ✅ 조사 완료 (2026-04-16) |
| ~~High~~ | ~~**카카오페이지**~~ | ~~국내 소설 플랫폼~~ | ✅ 조사 완료 (2026-04-16) |
| High | **문피아** | 국내 소설 플랫폼 | 무료 연재, 유료 전환 |
| High | **노벨피아** | 국내 소설 플랫폼 | 작가 인디 분위기 |
| High | **Wattpad** | 해외 소설 플랫폼 | 표지 + 배너, 책 커뮤니티 |
| High | **AO3 (Archive of Our Own)** | 해외 소설 플랫폼 | CSS 스킨 직접 작성 (Grimoire의 안티패턴) |
| Med | **Royal Road** | 해외 소설 플랫폼 | 영문 웹소설 |
| Med | **Webtoon Canvas** | 해외 웹툰 | 작가 등록 모델 |
| Med | **브런치** | 블로그/매거진 | 매거진 배치, 커버 사진 |
| Med | **Substack** | 뉴스레터 | 작가 구독, 수익 모델 |
| Med | **Medium** | 블로그 | 작가 공간 |
| Med | **Ghost** | 블로그 엔진 | 테마 시스템 |
| Low | **Sudowrite** | AI 창작 도구 | 한줄 대체재 |
| Low | **Jasper** | AI 창작 도구 | 마케팅 카피 |
| Low | **Novelcrafter** | AI 창작 도구 | 소설 에디터 |
| Low | **Framer** | 디자인 빌더 | 드래그앤드롭 + 코드 |
| Low | **Webflow** | 웹빌더 | 비주얼 디벨로퍼 |
| Low | **Readymag** | 웹빌더 | 매거진 디자인 (이미 grimoire-web에 차용 흔적 있음) |

---

## 부록 B. 제외 대상

| 서비스 | 제외 이유 |
|---|---|
| Project Zenith / RoadRage | 자매 프로젝트 |
| 작가 본인의 실제 소설 본문 | 콘텐츠 보호 — 메타정보만 수집 |

---

## 부록 C. Provenance 체인 규칙

```markdown
이 테마 옵션은 [id: hanline-ai-2026-04-15] 의 AI 창작 vs 디자인 자동화
포지셔닝과 정반대 방향(작가 글 보존, 공간만 자동화)에 따라 설계되었다.
```

---

## 부록 D. 프론트매터 스키마

```yaml
id: <service-name>-<YYYY-MM-DD>
service: "..."
category: "..."
collectedAt: YYYY-MM-DD
lastVerifiedAt: YYYY-MM-DD
staleAfter: YYYY-MM-DD
confidence: verified | inferred | stale | deprecated
sources:
  - url, title, accessedAt
```

---

**최종 갱신**: 2026-04-16 (3개 항목: 한줄 재검증 + 네이버 시리즈 + 카카오페이지 신규)
**다음 예정 스윕**: 2026-04-17 (매일)
**관리자**: `grimoire-researcher` 에이전트
