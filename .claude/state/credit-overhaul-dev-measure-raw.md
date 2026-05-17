# 크레딧 개편 — dev DB 측정 raw (§7 마이그레이션 단계 1)

> 크레딧 디노미네이션 마이그레이션(1크레딧 = 1,000pt) SQL/검증 기준 확정용 실측.
> 정본: `.claude/state/sprint-credit-overhaul-s-phase-draft.md` §7 단계 1.
> **본 측정은 읽기 전용 SELECT만 — INSERT/UPDATE/DELETE/DDL 0건. dev 전용 (prod 미접촉).**

## 측정 메타

| 항목 | 값 |
|---|---|
| 측정 일시 (UTC) | 2026-05-17T08:27Z |
| 측정 일시 (KST) | 2026-05-17 17:27 |
| 대상 환경 | development (dev) |
| DB host | `grimoire-db-dev.postgres.database.azure.com` (Azure Postgres flexible server `grimoire-db-dev`) |
| DB명 | `grimoire` |
| DB user | `grimoireadmin` |
| 연결 방법 | dev Container App(`grimoire-server-dev`, RG `zenith-rg`) secretRef `database-url` → DATABASE_URL 추출 → `psql` 직접 접속 (sslmode=require) |
| firewall 접근 | 임시 rule `tmp-20260517T082709Z` (측정 IP 단일) 추가 → 측정 → **즉시 정리 완료** (orphan rule 0건 검증) |
| 측정 에이전트 | grimoire-infrastructure |

## 측정값 (raw)

| # | SELECT | 결과값 | 디노미 마이그레이션 검증 기준 |
|---|---|---|---|
| 1 | `SELECT COUNT(*) FROM authors;` | **12** | 작가 총 row 수 |
| 2 | `SELECT COALESCE(SUM(credits),0) FROM authors;` | **100** | 기존 `credits` 합계 — 디노미 후 `SUM(points_charged)` = 100 × 1000 = **100,000pt** 검증 기준 (§7 정합성 검증: 1pt도 어긋나면 롤백) |
| 3 | `SELECT COUNT(*) FROM authors WHERE credits > 0;` | **10** | `credits > 0` 작가 수 — `CreditLedger` 초기 row 수 검증 기준 (§7 단계 4-b: type='earn'/source='charged' row 1건/작가, ledger row 수 = **10**) |
| 4 | `SELECT COUNT(*) FROM chat_messages;` | **22** | 채팅 메시지 총 row 수 — `ChatMessage` 5 필드 ADD COLUMN(§6 #6) 영향 row, 전부 nullable → 기존 22 row는 null |
| 5 | `chat_messages` 토큰/모델 컬럼 부재 확인 | **부재 확정** | 아래 §컬럼 실측 참조 |

> Q1·Q3 확인: 작가 12명 중 credits 보유(>0) 10명, 보유 0(또는 0 credits) 2명. SUM=100 → 보유 10명 평균 10 credits.

## §5 — chat_messages 토큰/모델 컬럼 부재 실측

`information_schema.columns` 조회 (`table_name='chat_messages'`) — 현재 컬럼 전체 (`ordinal_position` 순):

```
id
session_id
role
content
created_at
```

- `input_tokens` / `output_tokens` / `model` (및 camelCase `inputTokens`/`outputTokens`) — **컬럼 0건 검출 = 부재 확정.**
- §6 스키마 매트릭스 #6 (`ChatMessage` 필드 추가 `inputTokens Int?` / `outputTokens Int?` / `model String?` / `chargedPoints Int?` / `chargeTier String?`) 와 정합 — 5 필드 전부 신규 ADD COLUMN 대상, 기존 22 row는 전량 null.

## 마이그레이션 SQL 검증 기준 요약 (§7 단계 6·9 직후 검증)

- `SELECT SUM(points_charged) FROM authors` **= 100,000** (= 구 `SUM(credits)` 100 × 1000). 마이그레이션 전 스냅샷 대비 1pt 오차 시 롤백.
- `CreditLedger` 초기 row 수 **= 10** (= `credits > 0` 작가 수).
- `credits` 컬럼은 단계 9에서도 보존(deprecated) — 후속 sprint DROP.

## 제약 준수 박제

- 실행 SQL 전건 `SELECT` — `INSERT|UPDATE|DELETE|TRUNCATE|DROP|ALTER|CREATE` 0건 (DB row 변경 0건).
- prod DB(`grimoire-db-prod`) 미접촉 — dev 전용.
- firewall 임시 rule 추가 → 측정 → 정리 1 묶음 강제 — 정리 후 `tmp-*` rule 잔존 0건 검증 완료.
- DB 자격증명 평문 박제 0건 — host + DB명 + user만 박제, 비밀번호 미기재.
