# 사용자 검증 가이드 — 2026-05-05 (EMAIL-P0-3 + 누적 검증)

> **목적**: 사용자 자격증명 + 운영 DB 접근 권한이 필요한 검증 영역 절차 박제. 메인 Claude는 권한 외이므로 가이드만 박제. 사용자 직접 실행.

---

## 10. EMAIL-P0-2 운영 DB SQL 백필 (가짜 이메일 12~15 row 정리)

### 10-1. 영향 범위

`@grimoire.app` 도메인은 실존하지 않음 (이전 Claude가 임의 박제). 운영 DB Author row 12~15건 추정. 정리 후 EMAIL-P0-3 slug 로그인 정합.

### 10-2. 실행 절차 (dev → prod 순차)

#### Phase 1: dev 환경 (먼저)

```bash
# 1. Azure DB 비밀번호 박제 (사용자 환경)
export DB_PASSWORD="<dev DB 비밀번호>"

# 2. dev DB 접속 (psql)
psql "postgresql://grimoireadmin:${DB_PASSWORD}@grimoire-db-dev.postgres.database.azure.com:5432/grimoire?sslmode=require"
```

```sql
-- 3. 영향 row 사전 확인
SELECT id, slug, email, name FROM authors WHERE email LIKE '%@grimoire.app%';

-- 기대 결과: deerdevil + 10명 작가 (이광수/김소월/윤동주/이상/채만식/이효석/김유정/현진건/나도향/한용운) 합 ~12 row

-- 4. 백업 (필수)
CREATE TABLE authors_backup_20260505 AS
  SELECT * FROM authors WHERE email LIKE '%@grimoire.app%';

-- 5. 종속 데이터 정리 (FK cascade 미정의 시 수동)
DELETE FROM refresh_tokens
WHERE author_id IN (
  SELECT id FROM authors WHERE email LIKE '%@grimoire.app%'
);

DELETE FROM social_accounts
WHERE author_id IN (
  SELECT id FROM authors WHERE email LIKE '%@grimoire.app%'
);

-- 6. authors row 삭제 (운영 영역 — 시드 작가 12 row 정리)
DELETE FROM authors WHERE email LIKE '%@grimoire.app%';

-- 7. 회귀 검증 (반드시 0 반환)
SELECT COUNT(*) FROM authors WHERE email LIKE '%@grimoire.app%';
-- 기대: 0

-- 8. EMAIL-P0-3 정합 검증 쿼리
SELECT COUNT(*) FROM authors WHERE email IS NULL;       -- 기대: 0
SELECT COUNT(*) FROM authors WHERE slug IS NULL;        -- 기대: 0
SELECT email, COUNT(*) FROM authors GROUP BY email HAVING COUNT(*) > 1;  -- 기대: 0 row
SELECT slug, COUNT(*) FROM authors GROUP BY slug HAVING COUNT(*) > 1;    -- 기대: 0 row
```

#### Phase 2: prod 환경 (dev 정상 확인 후)

dev에서 정상 동작 확인 후 prod 동일 절차:
```bash
export DB_PASSWORD="<prod DB 비밀번호>"
psql "postgresql://grimoireadmin:${DB_PASSWORD}@grimoire-db-prod.postgres.database.azure.com:5432/grimoire?sslmode=require"
```

(위 SQL Phase 1과 동일 — table 이름만 `authors_backup_20260505_prod` 권장)

#### 롤백 (긴급 시)

```sql
-- 백업에서 복원
INSERT INTO authors SELECT * FROM authors_backup_20260505;
-- (refresh_tokens / social_accounts 백업이 없으므로 사용자 재로그인으로 회복)
```

---

## 4-9. dev 환경 검증 명령 (curl + Container Apps 로그)

### 4. PAY-P0-1 webhook event_id 멱등성

```bash
# Container Apps env 추가 (사용자 영역)
az containerapp update \
  --name grimoire-server-dev \
  --resource-group zenith-rg \
  --set-env-vars PUBLIC_API_BASE_URL=https://dev-api.grimoire-book.com/api

# Polar dashboard에서 동일 event_id로 webhook 두 번 시뮬
# 기대: 두 번째 webhook은 skip (DB Payment row 변동 0건)

# Container Apps 로그 검증
az containerapp logs show \
  --name grimoire-server-dev \
  --resource-group zenith-rg \
  --tail 100 \
  | grep "duplicate_event"

# 기대 로그: "중복 webhook 감지 (eventId=evt_xxx, status=processed) — skip"
```

### 5. PAY-P0-2 PG↔DB 정합성 cron

```bash
# Container Apps 로그 (10분 주기 cron)
az containerapp logs show \
  --name grimoire-server-dev \
  --resource-group zenith-rg \
  --tail 200 \
  | grep "PaymentReconciliationJob"

# 기대 로그 패턴:
# [PaymentReconciliationJob] PaymentReconciliationJob 시작 — since=...
# [PaymentReconciliationJob] PaymentReconciliationJob 완료 — processed=N boost=N mismatch=N expire=N
```

### 6. PAY-P0-3 운영자 수동 크레딧 UI

```
1. 브라우저: https://dev.grimoire-book.com/admin/credits
2. 관리자 로그인
3. 사용자 검색 (이메일 또는 슬러그)
4. 크레딧 지급 (amount + reason 입력)
5. 확인 모달 클릭
6. 토스트 성공 메시지 박제
7. DB credit_logs row 직접 검증:
   psql ... -c "SELECT * FROM credit_logs ORDER BY created_at DESC LIMIT 5;"
```

### 7. PAY-P1-1 Refund 정밀 처리

```bash
# Polar dashboard에서 order.refunded webhook 시뮬
# 기대 1: RefundLog row 신설
# 기대 2: Author.credits decrement (잔액 부족 시 0 fix)
# 기대 3: AuditLog operator='system_refund' 박제

psql ... -c "
SELECT rl.payment_id, rl.amount, rl.credits, rl.deficit_credits, rl.reason,
       a.slug, a.credits AS current_credits
FROM refund_logs rl
JOIN payments p ON p.id = rl.payment_id
JOIN authors a ON a.id = p.author_id
ORDER BY rl.processed_at DESC LIMIT 5;
"
```

### 8. PAY-P1-3 결제 실패 retry 정책

```bash
# 동일 productId 2회 호출 — paymentId 동일 + Polar URL 신규 검증
TOKEN="<dev JWT 토큰>"

curl -X POST https://dev-api.grimoire-book.com/api/payments/initiate \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"productId":"credits-50","returnUrl":"https://dev.grimoire-book.com/dashboard"}' \
  | jq

# 5분 대기 또는 즉시 재호출
curl -X POST https://dev-api.grimoire-book.com/api/payments/initiate \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"productId":"credits-50","returnUrl":"https://dev.grimoire-book.com/dashboard"}' \
  | jq

# 기대: 두 응답의 paymentId 동일 + paymentUrl 다름

# Container Apps 로그 (cleanup cron 새벽 4시)
az containerapp logs show --name grimoire-server-dev --resource-group zenith-rg --tail 200 \
  | grep "PaymentCleanupJob"

# 기대 로그:
# [PaymentCleanupJob] PaymentCleanupJob 시작 — startedAt=... expireHours=24
# [PaymentCleanupJob] PaymentCleanupJob 완료 — expireCount=N stalePendingCount=N
```

### 9. EMAIL-P0-3 slug 로그인 + 후향호환 + XOR

```bash
# A. slug 로그인 (정상 — 사용자 자격증명 필요)
curl -X POST https://dev-api.grimoire-book.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"slug":"deerdevil","password":"<deerdevil 비번>"}' \
  | jq
# 기대: 200 + { user, accessToken, refreshToken }

# B. email 후향호환 (정상)
curl -X POST https://dev-api.grimoire-book.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"deerdevil@<dev 실 이메일>","password":"<비번>"}' \
  | jq
# 기대: 200

# C. XOR 위반 (둘 다 박제)
curl -X POST https://dev-api.grimoire-book.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"a@b.com","slug":"a","password":"pass"}' \
  | jq
# 기대: 400 + "이메일 또는 슬러그 중 하나만 박제하세요"

# D. XOR 위반 (둘 다 미박제)
curl -X POST https://dev-api.grimoire-book.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"password":"pass"}' \
  | jq
# 기대: 400

# E. 미존재 slug
curl -X POST https://dev-api.grimoire-book.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"slug":"no-such-slug","password":"pass"}' \
  | jq
# 기대: 401 + "이메일/슬러그 또는 비밀번호가 올바르지 않습니다"
```

---

## 1-3. main per-repo 머지 (메인 Claude 자율 영역)

> **메인 Claude가 진행** (사용자 명시 "1-3 진행"). 다음 세션에서 별도 진행 안 해도 됨 — 본 sprint 종료 시점 박제.

| # | 레포 | 명령 | 자동 배포 |
|---|---|---|---|
| 1 | claude-docs | `git checkout main && git merge develop --no-ff && git push origin main` | — (정본 박제) |
| 2 | server | 동일 | `.github/workflows/deploy-prod.yml` 자동 트리거 가능성 (확인 필요) |
| 3 | web | 동일 | `.github/workflows/deploy-prod.yml` 자동 트리거 가능성 |

---

## main 정상 로그인 + 페이지 접속 검증

### 메인 Claude 자율 영역

- `curl https://api.grimoire-book.com/api/auth/login` (XOR 위반 400 검증)
- `curl https://grimoire-book.com` (페이지 200 + HTML 박제 검증)
- Chrome MCP로 `https://grimoire-book.com/deerdevil/` (사슴악마 작가공간 시각 정본 검증)
- Chrome MCP로 `https://grimoire-book.com/login` (로그인 폼 "이메일 또는 슬러그" label 박제 검증)

### 사용자 자격증명 영역

- 정상 slug 로그인 200 검증 (사용자 deerdevil 비번 입력)
- 정상 email 후향호환 200 검증 (사용자 이메일 입력)
- dashboard / 작품 / 결제 흐름 실제 검증

---

## 변경 이력

- 2026-05-05 #10_7 EMAIL-P0-3 종료 시점: 본 가이드 신설. 사용자 영역 (운영 DB SQL + dev 환경 자격증명 검증)와 메인 자율 영역 (main 머지 + prod 페이지 검증) 분리 박제.
