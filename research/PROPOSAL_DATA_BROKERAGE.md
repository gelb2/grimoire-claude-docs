# PROPOSAL_DATA_BROKERAGE.md — 데이터 브로커리지 파이프라인 제안 분석

> 제미나이 제안 + Claude 기술 의견. 기획 검토용 문서.
> 이 문서는 기획 단계 문서이며, 구현 결정 전 사용자 검토 필수.

---

## 0. 제안 요약

**핵심:** 작가들이 업로드하는 원고 텍스트에서 장르 트렌드/메타데이터를 추출 → 익명화 → 중소형 CP(콘텐츠 기획사)에게 구독형 리포트로 판매하는 B2B 데이터 사업.

**비유:** 그리모어가 '작가의 레디맥'이라면, 이건 '웹소설판 닐슨 시청률 조사' 또는 'SimilarWeb의 웹소설 버전'.

---

## 1. 메타데이터 추출 및 태깅 엔진

### 제미나이 제안 분류 기준

| 분류 | 추출 대상 | 예시 |
|------|----------|------|
| 장르 블렌딩 비율 | 작품 내 장르 요소 비중 | 로맨스 60% + 판타지 30% + 미스터리 10% |
| 주인공 성격 유형 | 캐릭터 아키타입 | 냉철한 천재, 평범한 회사원, 악역 영애 |
| 스토리 전개 속도 | 챕터당 사건 밀도 | 빠른(액션), 느긋한(일상), 폭풍전개 |
| 클리셰 키워드 | 유행 소재/설정 | 회귀, 빙의, 아카데미, 헌터, 시스템창 |
| 배경 시대/세계관 | 시공간 분류 | 현대 한국, 중세 판타지, SF 우주 |
| 연재 패턴 | 분량/주기 | 회당 3000자, 주 5회 연재 |

### Claude 기술 의견

**현실적 구현 방법:**

```
원고 업로드 → 청킹(1000토큰) → Claude/GPT 배치 분석 → 메타데이터 JSON → DB 저장
```

- **NLP 파이프라인:** Claude API 또는 GPT-4o-mini 배치 호출이 가장 현실적. 한국어 웹소설 특화 NLP 모델은 존재하지 않으므로 LLM 기반이 유일한 선택지.
- **비용 문제:** 원고 1편(5만자) 분석 시 Claude API 비용 약 $0.5~1. 작품 1000개 분석 = $500~1000/월. B2B 구독 가격이 이 비용을 상회해야 사업성 있음.
- **정확도:** 장르 분류는 90%+ 가능하지만, "스토리 전개 속도"나 "클리셰 키워드" 추출은 프롬프트 엔지니어링 난이도 높음. 초기에는 장르/키워드/캐릭터 유형 3가지에 집중 권장.
- **기존 인프라 활용:** 그리모어 서버의 `src/lib/claude.ts` 래퍼 + `src/application/analysis/novel-analysis.usecase.ts`를 확장하면 됨. 새 시스템 구축 불필요.

**권장 기술 스택:**

| 컴포넌트 | 기술 | 이유 |
|---------|------|------|
| 텍스트 분석 | Claude API (배치) | 한국어 웹소설 이해도 높음, 이미 연동됨 |
| 임베딩 | OpenAI text-embedding-3-small | 유사 작품 클러스터링용, 이미 연동됨 |
| 벡터 DB | pgvector (PostgreSQL) | 이미 구현됨 (`src/adapter/outbound/vector/`) |
| 메타데이터 저장 | PostgreSQL JSONB | 유연한 스키마, Prisma 호환 |
| 배치 처리 | BullMQ (Redis) 또는 cron | 업로드 시 즉시 분석 대신 큐 기반 비동기 |

---

## 2. 데이터 익명화 및 집계 로직

### 제미나이 제안 스키마

```sql
-- 개별 작품 메타데이터 (익명화)
CREATE TABLE work_analytics (
  id UUID PRIMARY KEY,
  analyzed_at TIMESTAMPTZ,
  -- 장르 블렌딩 (JSONB)
  genre_blend JSONB,  -- {"romance": 0.6, "fantasy": 0.3, "mystery": 0.1}
  -- 캐릭터 유형
  protagonist_type TEXT[],  -- ["cold_genius", "academy_student"]
  -- 클리셰 키워드
  cliche_keywords TEXT[],  -- ["regression", "villain_lady", "system_window"]
  -- 수치 지표
  pacing_score FLOAT,      -- 전개 속도 (0~1)
  chapter_count INT,
  avg_chapter_length INT,
  -- 시간 버킷 (주간/월간 집계용)
  week_bucket DATE,
  month_bucket DATE
);

-- 주간 트렌드 집계 뷰
CREATE MATERIALIZED VIEW weekly_trends AS
SELECT
  week_bucket,
  keyword,
  COUNT(*) as occurrence,
  LAG(COUNT(*), 1) OVER (ORDER BY week_bucket) as prev_week
FROM work_analytics, UNNEST(cliche_keywords) AS keyword
GROUP BY week_bucket, keyword;
```

### Claude 기술 의견

**익명화 핵심:**
- ✅ 개별 작품 ID를 외부에 노출하지 않음 (UUID는 내부용)
- ✅ 작가명/작품명은 절대 저장하지 않음 — 오직 추출된 메타데이터만
- ✅ 집계는 최소 10건 이상일 때만 노출 (k-anonymity)
- ⚠️ 장르 블렌딩 비율 + 캐릭터 유형 + 분량 조합으로 역추적 가능성 → 집계 단위를 주간 100건+ 으로 설정해야 안전

**현실적 우려:**
1. **데이터 볼륨:** 트렌드 분석이 유의미하려면 최소 주간 500+ 작품 데이터 필요. 그리모어 초기 사용자 수로는 부족. 크롤링 없이는 자체 데이터만으로 "트렌드"를 말하기 어려움.
2. **법적 리스크:** 작가가 업로드한 원고를 "트렌드 분석용으로 활용"하는 것에 대한 동의가 이용약관에 명시되어야 함. GDPR/개인정보보호법 검토 필수.
3. **대안:** 초기에는 외부 크롤링(노벨피아, 문피아 등의 공개 태그/순위 데이터)을 보조 소스로 활용하고, 그리모어 자체 데이터는 장기적으로 축적하는 전략이 현실적.

**권장 접근:**
- Phase 1: 자체 작품에 대한 메타데이터 추출 + 작가 대시보드에 "내 작품 분석" 기능 제공 (B2C)
- Phase 2: 데이터 볼륨이 쌓이면 익명 집계 → B2B 리포트 전환
- Phase 3: 외부 데이터 소스 연동 → 시장 전체 트렌드 분석

---

## 3. B2B 대시보드 및 API 설계

### 제미나이 제안 대시보드 구성

| 섹션 | 내용 |
|------|------|
| 트렌드 오버뷰 | 이번 주 Top 10 클리셰, 장르 분포 파이 차트 |
| 급상승 키워드 | 전주 대비 300%+ 상승한 키워드 알림 |
| 장르 블렌딩 맵 | 장르 조합 히트맵 (로맨스×판타지, SF×미스터리 등) |
| 캐릭터 트렌드 | 인기 주인공 유형 변화 추이 |
| 분량 분석 | 평균 회당 분량, 연재 주기 통계 |
| 경쟁 작품 벤치마크 | "이 장르 조합의 평균 성과" 비교 |

### 제미나이 제안 API 응답 예시

```json
GET /api/b2b/trends/weekly?week=2026-W14

{
  "week": "2026-W14",
  "totalWorksAnalyzed": 1247,
  "topKeywords": [
    { "keyword": "회귀", "count": 342, "changeRate": 0.15 },
    { "keyword": "악역영애", "count": 287, "changeRate": 3.2 },
    { "keyword": "헌터", "count": 201, "changeRate": -0.08 }
  ],
  "genreDistribution": {
    "romance": 0.35,
    "fantasy": 0.28,
    "modernFantasy": 0.18,
    "sf": 0.09,
    "mystery": 0.06,
    "other": 0.04
  },
  "risingBlends": [
    { "genres": ["romance", "regression"], "count": 89, "weekOverWeek": 2.1 },
    { "genres": ["academy", "villainLady"], "count": 67, "weekOverWeek": 3.5 }
  ],
  "protagonistTypes": [
    { "type": "cold_genius", "share": 0.22 },
    { "type": "ordinary_regressor", "share": 0.18 },
    { "type": "villain_lady", "share": 0.15 }
  ]
}
```

### Claude 기술 의견

**API 설계 자체는 깔끔함.** 하지만:

1. **인증/과금:** B2B API는 API Key 기반 인증 + 월 요청 수 제한이 필요. 현재 그리모어의 JWT 쿠키 방식과 완전히 다른 인증 체계.
2. **캐싱:** 주간 트렌드는 주 1회 갱신이면 충분 → CDN 캐싱 또는 Materialized View로 사전 계산.
3. **가격 설정:** 경쟁사 부재이므로 가격 설정이 어려움. 월 30~50만원 대 (중소 CP 1곳 기준) → 연 매출 1000만원을 넘기려면 최소 20~30개 CP 확보 필요.

**기존 그리모어 인프라와의 관계:**
- B2B API는 별도 서비스로 분리해야 함 (작가용 API와 혼재하면 안 됨)
- 하지만 DB는 공유 가능 (읽기 전용 replica)
- grimoire-server에 `src/application/b2b/` 디렉토리를 만들면 Hexagonal 아키텍처 안에서 수용 가능

---

## 4. 종합 의견 — 지금 해야 하나?

### 결론: **지금은 아님. Phase 2 이후.**

| 판단 기준 | 현재 상태 | 필요 조건 |
|----------|----------|----------|
| 데이터 볼륨 | 작가 11명, 작품 ~50개 | 최소 주간 500작품+ |
| 사용자 기반 | 테스트 계정만 | 실 작가 100명+ |
| 핵심 제품 완성도 | 테마 에디터 막 완성 | 업로드→퍼블리시→독자 유입 흐름 안정화 |
| B2B 영업 | 미시작 | CP 10곳+ 파일럿 계약 |
| 법적 준비 | 이용약관 미작성 | 데이터 활용 동의 조항 필수 |

### 권장 로드맵

```
현재 (Phase 1)
  → 작가 플랫폼 안정화 (테마, 파서, 결제, 사용자 유입)
  → 이용약관에 "데이터 분석 활용 동의" 조항 포함

Phase 2 (사용자 100+)
  → "내 작품 AI 분석" 기능 (B2C): 작가 대시보드에 장르/키워드/페이싱 분석 제공
  → 메타데이터 DB 축적 시작

Phase 3 (사용자 500+)
  → 익명 집계 시작 → B2B 리포트 MVP
  → CP 파일럿 영업 (3~5곳)

Phase 4 (사용자 1000+)
  → B2B API 공개 + 구독 과금
  → 외부 데이터 소스 연동
```

### 지금 할 수 있는 준비

1. **DB 스키마 예약:** `work_analytics` 테이블 설계만 해두기 (데이터 적재 안 함)
2. **분석 프롬프트 프로토타입:** Claude API로 메타데이터 추출 프롬프트 테스트 (이미 `novel-analysis.usecase.ts` 존재)
3. **이용약관 초안:** "서비스 개선 및 시장 분석을 위해 익명화된 통계 데이터를 활용할 수 있습니다" 조항

---

## 5. 기술 스택 요약 (구현 시)

| 레이어 | 기술 | 비고 |
|--------|------|------|
| 텍스트 분석 | Claude API 배치 | 기존 래퍼 확장 |
| 임베딩 | OpenAI text-embedding-3-small | 기존 구현 활용 |
| 벡터 DB | pgvector | 기존 구현 활용 |
| 메타데이터 DB | PostgreSQL JSONB | Prisma 스키마 추가 |
| 배치 큐 | BullMQ (Redis) | 신규 인프라 |
| 집계 | Materialized View | PostgreSQL 내장 |
| B2B API | NestJS 별도 모듈 | Hexagonal 구조 유지 |
| B2B 인증 | API Key + 월 한도 | JWT와 별도 |
| 대시보드 | Next.js 별도 앱 | grimoire-admin 또는 별도 레포 |
