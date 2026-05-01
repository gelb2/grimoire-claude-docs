# Researcher 리서치 범위 정본

> grimoire-researcher 에이전트가 매일 모니터링하는 범위 정의.
> 본 .md 분리 (2026-04-30 #10 Phase B): 에이전트 .md 316줄 → 압축 + 책 Ch 08 60-line 정합.
> researcher가 daily sweep 시작 전 본 파일 Read 필요.

---

## A. 경쟁사·시장

| 카테고리 | 대표 서비스 | 관찰 포인트 |
|---|---|---|
| **국내 소설 플랫폼** | 네이버 시리즈, 카카오페이지, 문피아, 노벨피아, 조아라 | 작가 커스텀 가능 범위, 수익 분배, 구독 모델 |
| **해외 소설 플랫폼** | Wattpad, Royal Road, AO3, Webtoon Canvas | CSS 스킨, 읽기 공간 커스텀 |
| **AI 창작** | 한줄(hanline.ai), Sudowrite, Jasper, Novelcrafter | AI 창작 vs AI 디자인 차별화 |
| **블로그/매거진** | 브런치, Substack, Medium, Ghost | 편집 도구, 테마 시스템 |
| **웹빌더/테마** | Framer, Webflow, Readymag | AI 테마 생성, 동적 CSS |

---

## B. AI 모델 가격 (Grimoire 특화)

| 제공자 | 모델 | 입력 가격 | 출력 가격 | 모니터링 빈도 |
|---|---|---|---|---|
| Anthropic | Claude Sonnet 4, Haiku, Opus | 매일 확인 | 매일 확인 | 매일 |
| OpenAI | GPT-4o, GPT-4o-mini, GPT-5 | 매일 확인 | 매일 확인 | 매일 |
| Google | Gemini Pro/Flash | 매일 확인 | 매일 확인 | 매일 |
| Voyage/Cohere | 임베딩 모델 | 매일 확인 | N/A | 매일 |

가격 변동 감지 시 cost-accountant 즉시 알림 (`reports/COST_ALERT.md`).

---

## C. 학술/기술

| 영역 | 키워드 | Grimoire 접점 |
|---|---|---|
| RAG | Retrieval-Augmented Generation, 시맨틱 검색 | §14 AI 분석 기능 |
| 임베딩 | text-embedding, sentence-transformers | 시맨틱 캐싱 |
| 벡터 DB | pgvector, HNSW, IVFFlat | 기존 인프라 |
| 프롬프트 캐싱 | Anthropic prompt caching, OpenAI caching | 원가 절감 |

---

## 변경 이력
- 2026-04-30 #10 Phase B: 본 파일 신설 — researcher.md §4 리서치 범위 (4-A/4-B/4-C)를 분리 (에이전트 .md attention 개선, 책 Ch 08).
