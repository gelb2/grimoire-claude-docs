---
description: dev 환경 로그인 가능성 스모크 테스트. db-sync --mask-pii 회귀로 dev 로그인 불가 상태가 됐는지 감지. preflight HTTP + db-sync --preserve-accounts 정합성 + dev API 응답 3종 검증.
argument-hint: "[선택: 검사할 작가 slug, 기본=deerdevil]"
---

# Dev Login Smoke Test

당신은 ProjectGrimoire의 dev 환경 진단관입니다. 본 슬래시 커맨드는 다음 회귀를 차단합니다:

> **2026-04-19 회귀**: `db-sync --mask-pii`가 모든 작가 비번을 고정 해시로 덮어써서 dev에서 deerdevil 계정 로그인 불가 상태 발생 → 사용자 격노. 이번 세션에 `--preserve-accounts` 옵션 추가됐으므로, 이 명령으로 정합성 주기 점검.

## 입력
- `$ARGUMENTS`: 검사할 작가 slug (기본: `deerdevil`)

## 절차 (실측만, 추정 금지)

### Step 1. dev API preflight (3종)

```bash
SLUG="${ARGUMENTS:-deerdevil}"

echo "=== /api/health ==="
curl -s -o /dev/null -w "HTTP %{http_code}  time %{time_total}s\n" https://dev-api.grimoire-book.com/api/health

echo "=== /api/authors/$SLUG ==="
curl -s -o /tmp/author_resp.json -w "HTTP %{http_code}  time %{time_total}s\n" "https://dev-api.grimoire-book.com/api/authors/$SLUG"
cat /tmp/author_resp.json | python3 -m json.tool 2>/dev/null | head -20 || cat /tmp/author_resp.json | head -5

echo "=== /api/auth/login (reCAPTCHA 응답 확인) ==="
curl -s -o /tmp/login_resp.json -w "HTTP %{http_code}\n" -X POST https://dev-api.grimoire-book.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$SLUG@grimoire.app\",\"password\":\"dummy\"}"
cat /tmp/login_resp.json | python3 -m json.tool 2>/dev/null | head -10
```

판정:
- `/api/health` 200 + 응답시간 < 30s = OK (cold start 허용 범위)
- `/api/authors/$SLUG` 200 = 작가 실재 / 404 = 작가 없음 (db-sync 회귀 의심)
- `/api/auth/login` 400 + "reCAPTCHA 토큰 필요" = 정상 (가드 동작)

### Step 2. db-sync 정합성 (드라이런 — 실 동기화 안 함)

```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server

echo "=== --preserve-accounts 옵션 존재 확인 ==="
grep -n "preserve-accounts" scripts/db-sync.ts | head -3
grep -n "DB_SYNC_PRESERVE_EMAILS" scripts/db-sync.ts | head -3

echo "=== preserveEmails 적용 함수 확인 ==="
grep -n "preserveEmails" scripts/db-sync.ts | head -10

echo "=== db-sync 가드 동작 (옵션만, 실행 안 함) ==="
unset DB_SYNC_PRESERVE_EMAILS
npx tsx scripts/db-sync.ts prod dev --mask-pii --preserve-accounts 2>&1 | head -3
# 기대: ❌ DB_SYNC_PRESERVE_EMAILS 환경변수 없음 에러
```

판정:
- `preserve-accounts` 옵션 코드에 존재 = OK
- 환경변수 없을 때 가드 동작 = OK

### Step 3. (선택) dev DB 직접 검증 — 사용자 승인 후만

```bash
# 사용자가 dev DB 방화벽 임시 개방을 승인했을 때만 실행
MY_IP=$(curl -s ifconfig.me)
RULE_NAME="dev-login-smoke-$(date +%s)"

az postgres flexible-server firewall-rule create \
  --resource-group zenith-rg --name grimoire-db-dev \
  --rule-name "$RULE_NAME" \
  --start-ip-address "$MY_IP" --end-ip-address "$MY_IP" --output none

PGPASSWORD='REMOVED_CREDENTIAL_010' psql \
  -h grimoire-db-dev.postgres.database.azure.com \
  -U grimoireadmin -d grimoire \
  -c "SELECT email, slug, name, LENGTH(password_hash) as pw_len FROM authors WHERE slug = '$SLUG';"

# 작업 후 반드시 방화벽 규칙 제거
az postgres flexible-server firewall-rule delete \
  --resource-group zenith-rg --name grimoire-db-dev \
  --rule-name "$RULE_NAME" --yes --output none
```

판정:
- `email`이 `*@masked.local`이면 db-sync가 보존 안 함 → `DB_SYNC_PRESERVE_EMAILS`에 등록 필요
- `email`이 실 도메인 (`*@grimoire.app`)이면 보존 OK
- `password_hash` 길이가 60 (bcrypt 표준)이면 정상, 다른 길이면 회귀 의심

### Step 4. 리포트 양식

```markdown
## Dev Login Smoke Report — YYYY-MM-DD HH:MM

### Step 1. API preflight
- /api/health: HTTP {code} time {N}s
- /api/authors/$SLUG: HTTP {code} (작가 데이터 인용)
- /api/auth/login: HTTP {code} (응답 인용)

### Step 2. db-sync 정합성
- --preserve-accounts 옵션: 존재/부재
- 가드 동작: PASS/FAIL

### Step 3. dev DB 직접 검증 (수행 시)
- $SLUG 계정 email: (실측)
- password_hash 길이: (실측)

### 판정
- 회귀 위험: 없음/PARTIAL/CRITICAL
- 권고 조치: (있다면)
```

## 절대 금지 사항

- **[MUST NOT]** dev DB 방화벽 자동 개방 — 사용자 승인 후만
- **[MUST NOT]** 작가 본문(`episodes.content`) 조회 — 본문 보호 정책
- **[MUST NOT]** psql 결과를 메모리·로그에 패스워드 포함해 박제 (`pw_len`만 박제, 해시 자체 X)
- **[MUST NOT]** 이 스모크에서 db-sync 실 동기화 실행 — 옵션 검증만

## 관련 정본

- `memory/project_session_20260419_4.md` (db-sync 회귀 사례)
- `grimoire-server/scripts/db-sync.ts` (--preserve-accounts 옵션 신설)
- `grimoire-server/HANDOVER.md §4` (dev DB PII 마스킹 함정)

---

마지막 업데이트: 2026-04-25
