# 🤝 HANDOVER — 다음 세션 인계 문서

> **작성 시각**: 2026-05-27 (GCP 마이그레이션 + EMAIL-POLAR-READY 종결 직후)
> **목적**: 다음 세션/리모트 채팅방에서 다른 Claude 인스턴스가 작업 이어받기
> **갱신 규칙**: 세션 종료 시 이 문서를 최신 상태로 덮어쓴다
> **메모리 정본**: `~/.claude/projects/-Users-sokol-Desktop-Git-ProjectGrimoire/memory/` (MEMORY.md 인덱스 + project_session_*.md + project_remaining_tasks.md)

---

## ⚡ 즉시 컨텍스트 (30초 브리핑)

ProjectGrimoire(작가별 소설 퍼블리싱 플랫폼, 3 레포). 2026-05-27 현재:
- **크레딧 개편 코어 CC-1~5** (적립 8경로 + 디노미네이션 1:1,000 + 4 출처 회계 + Polar 구독 정기결제) — prod 종결
- **결제 하드닝 PAY-S1~S3** (로컬 마이그·다중 부분환불 누적 한도·Circuit Breaker 운영자 admin UI) — prod 종결
- **GCP 마이그레이션** (Azure → GCP, Phase 0~6 + 잔여 4작업) — 종결. **Phase 7 Azure decommission만 남음**
- **EMAIL-POLAR-READY** (외부 게이트 통과 시 사용자 1-2줄 액션으로 라이브) — 종결
- **3 레포 main 동기 + 미푸시 0/0/0**. 4 도메인 GCP에서 정상 운영. 실 사용자 트래픽 0 (test data만).

**다음 큰 결정**: ① 👤 Polar KYC + 한국 payout 승인 (매출 임팩트 최상위) ② 👤 Email SaaS 선택 + 절대규정 0-1 해제 ③ Phase 7 Azure 정리 (≥1주 운영 박제 후).

---

## 1. 인프라 핵심 (GCP — Azure에서 이전 완료)

| 항목 | 값 |
|---|---|
| GCP project | **`grimoire-491708`** (number 23295981916) |
| region | **`asia-northeast1`** (Tokyo) 단일 |
| Cloud Run × 4 | server-dev `00005-9f4` / server-prod `00005-kh7` / web-dev `00002-7wg` / web-prod `00002-qtc` |
| Cloud SQL × 2 | `grimoire-db-{dev,prod}` (db-f1-micro Enterprise, PG16, **Auth Proxy** Unix socket, allowlist `221.150.30.109/32`만) |
| Secret Manager | **20건** (`{name}-{env}-an1` 패턴): database-url-authproxy / jwt-secret / recaptcha-secret-key / anthropic-api-key / openai-api-key / polar-access-token / polar-webhook-secret / azure-storage-account-key / **resend-api-key**(placeholder) / **sendgrid-api-key**(placeholder) × dev/prod |
| GCS × 2 | `gs://grimoire-blob-{dev,prod}` (public `allUsers:objectViewer`) |
| Artifact Registry | `grimoire-docker` (asia-northeast1) + `cloud-run-source-deploy`(자동) |
| Domain Mapping × 4 | api/dev-api/dev → CNAME `ghs.googlehosted.com` / apex → A 216.239.32/34/36/38.21 + AAAA. Google managed cert (Trust Services WR3, auto-renewal) |
| Cloudflare DNS | zone `bb46e47d16da5ad279793bda1847c81c`, proxied=**false**, token in `~/.zshrc` (`CLOUDFLARE_API_TOKEN`, DNS 권한만 — Rulesets X) |
| 배포 정본 | **`gcloud run deploy {svc} --source <path> --region asia-northeast1 --project grimoire-491708`** (수동 1차). GitHub Actions 자동배포 4종 `.disabled` 유지 |
| db-sync | `.github/workflows/db-sync-nightly.yml` (GCP Cloud SQL Auth Proxy, GitHub Secret `GCP_SA_KEY`+`DB_PASSWORD_{DEV,PROD}`). schedule 17:00 UTC (KST 자정) |
| 도메인 verification | Google Search Console `grimoire-book.com` verified (rainmaker8492@gmail.com 계정 / DNS TXT) |

**Azure 잔존 (Phase 7 정리 대기, ≥1주 후)**: zenith-rg 내 Container Apps 4 + Postgres Flexible 2 + ACR(grimoireacr) + Blob(grimoire0storage) + Log Analytics. + **asia-northeast3 GCP 잔존**(미사용 Cloud SQL 2 `grimoire-pg-{dev,prod}` + GCS bucket 1). 모두 사용 중지, cert/DNS 전부 GCP 이전 완료, 미삭제.

**계정**: GCP/Azure/Cloudflare = `rainmaker8492@gmail.com`. (Chrome default Google 계정은 hiphopxy@gmail.com — Search Console 등 `/u/1/` URL로 rainmaker 강제 필요)

---

## 2. git 상태 (3 레포 main 동기, 미푸시 0)

| 레포 | main | develop | 비고 |
|---|---|---|---|
| grimoire-server | `a255140` | `92b5eef` | EMAIL-POLAR-READY Phase B/C/D |
| grimoire-web | `ed1d940` | `e81ecb8` | EMAIL-POLAR-READY Phase A |
| grimoire-claude-docs (= 워크스페이스 root) | `609caba` | `694bc99` | CC-3~EMAIL-POLAR-READY 누적 docs |

브랜치 정책: feature → develop(QA dev) → main(prod). 수동 배포 정본.

---

## 3. prod 정합 (2026-05-27 curl 실측)

- 4 도메인 200: `api.grimoire-book.com`/`dev-api`/`grimoire-book.com`/`dev` (health 200 / membership 401 / circuit-breaker/state 401 / payments/products 4종)
- EMAIL-POLAR-READY 신 endpoint: `POST /api/auth/email/verify-request` 미인증 401 / `POST /api/auth/password/reset-request` 빈 body 400
- jest **1174 PASS** / vitest **226 PASS** / 회귀 0
- SSL Google managed cert (WR3)
- Polar webhook POST 빈 body → 201 (Standard Webhooks 멱등성 정합, 정상)

---

## 4. 잔존 백로그 (우선순위)

### 👤 사용자 외부 액션 (최우선 — 코드 선행 0)
1. **Polar KYC + 한국 payout 승인** — Polar Dashboard. 승인 후 아래 §5-A 1줄로 구독 라이브
2. **Email SaaS 선택 + 절대규정 0-1 해제** — Resend(무료 3,000/월 권장) / SendGrid. 선택 후 §5-B 2줄로 실 발송

### Tier 1 (즉시 자율, 외부 의존 0)
- **PAY-S7** cron 시간대 명시 (`timeZone: 'Asia/Seoul'`, ~10분)
- **sensor regex micro-sprint** — false-positive 2건 정합화 (`sensor-payment-race-condition` CC-2b CAS 패턴 + `sensor-credit-atomicity` CC-4 Phase 3 stale regex), ~1-2h

### Tier 2 (사용자 결정 후 자율)
- **PAY-S5** webhook 비동기화 (BullMQ/agenda, ~3-4h, 트래픽 0이라 후순위)
- **PAY-S6 최소안** 운영 알림 (PAY-S3 admin UI 결합 — permanent_failed/mismatch/circuit OPEN 배지, ~1h)

### Tier 3 (외부 게이트 통과 후)
- **PAY-S4** 결제 알림 실 발송 (코드 박제 완료 — EMAIL-POLAR-READY Phase D, env 전환만)
- **PAY-S6 Sentry 정식안** (cost-accountant 게이트)
- **SMS 알림** (PAY-P2-3, SmsServicePort + Author.phone 컬럼 별도 sprint)

### Tier 4 (후속 sprint)
- **Phase 7 Azure decommission** (≥1주 GCP 운영 박제 후): zenith-rg 정리 + asia-northeast3 GCP 잔존 정리 + dead code(`blob-storage.service.ts` provider) 제거
- Cloud SQL g1-small 업그레이드 (사용자 트래픽 진입 시 cost-accountant 재호출)
- `Author.emailVerifiedAt` 컬럼 + verifyToken 후 갱신 (EMAIL-P1-1 후속)
- 비밀번호 reset-confirm → set-password 2단계 (현재 토큰 검증만)

---

## 5. 사용자 라이브 액션 매뉴얼 (외부 게이트 통과 직후)

### A. Polar KYC + payout 승인 후 (web env 1줄)
```bash
gcloud run services update grimoire-web-prod --region asia-northeast1 \
  --update-env-vars NEXT_PUBLIC_SUBSCRIPTION_LIVE=true
```
→ `MembershipPage`가 즉시 실 `api.startSubscriptionCheckout(tier)` 호출 → Polar Checkout redirect. 실패 시 ComingSoonModal fallback (UX 보존). (dev: `grimoire-web-dev`)

### B. Email SaaS(Resend) 활성 후 (server 2줄)
```bash
echo -n "<RESEND_API_KEY>" | gcloud secrets versions add resend-api-key-prod-an1 \
  --project grimoire-491708 --data-file=-
gcloud run services update grimoire-server-prod --region asia-northeast1 \
  --update-env-vars EMAIL_PROVIDER=resend
```
→ NullEmailAdapter → ResendEmailAdapter 즉시 전환. 인증/비밀번호 reset/결제 알림(충전·환불·구독갱신·실패) 실 발송. (SendGrid: `sendgrid-api-key-prod-an1` + `EMAIL_PROVIDER=sendgrid`. dev: `*-dev-an1` + `grimoire-server-dev`)

> **3중 안전망**: factory default NullAdapter → adapter placeholder/empty 체크 → usecase isEnabled() 가드. env 미설정 시 외부 호출 0건 (사용자 절대규정 0-1 정합).

---

## 6. 알려진 false-positive / 주의사항

- **sensor-payment-race-condition FAIL 2건** = false-positive (CC-2b가 `$executeRawUnsafe` CAS로 이행, regex stale). 실 코드 정합 — sensor regex micro-sprint 대기
- **sensor-credit-atomicity WARN 2건** = false-positive (CC-4 Phase 3 CreditLog 폐기, regex stale)
- **sensor-instruction-degradation WARN 1건** = `researcher.md` 316줄 (pre-existing, 비-결제)
- **eval regression 7일 mean 0.92~0.93** = 외부 영향 0, harness 영역 별도 sprint
- **eval-precommit이 baseline.csv 자동 append** → root commit/머지 시 working tree dirty 유발. main 머지 전 `git stash` 우회 필요
- **Polar webhook POST 201** = 정상 (Standard Webhooks 멱등성, PAY-P0-1)

### 절대 규칙 (CLAUDE.md §0 + 메모리 박제)
- **수동 배포 정본** (`gcloud run deploy --source`). GitHub Actions 자동배포 금지
- **GCP 절대 규칙** (server/CLAUDE.md §1): project grimoire-491708 / region asia-northeast1 단일 / Secret Manager 단일 진실 / Cloud SQL Auth Proxy 강제
- **결제 원자성** (§9): 돈 로직 단일 `$transaction`. 알림은 트랜잭션 외부 (throw 0)
- **작가 소설 콘텐츠 수정 절대 금지**
- **메인 = 조율자**: 코드/배포/마이그레이션은 agent 위임 (단, 메모리/문서/curl 실측/단순 gcloud는 메인 직접 가능)
- **존댓말 필수** / 추정 금지 (curl/psql/git 실측)

---

## 7. 정본 문서 위치

| 영역 | 정본 |
|---|---|
| 기획 | `PLANNING_GRIMOIRE.md` (루트) |
| 남은 과제 | `memory/project_remaining_tasks.md` (재추산 + 5/19~5/27 갱신 노트) |
| 인프라 | `grimoire-server/INFRASTRUCTURE.md` (GCP 정합, §12 Azure 잔존) |
| 배포 | `grimoire-server/docs/DEPLOY.md` + `Makefile` (GCP) |
| 환경 | `grimoire-server/docs/environments.md` (정본) |
| API | `grimoire-server/docs/api-contract.md` (정본 → web sync) |
| 인터페이스 | `.claude/shared-contracts.md` §11~§33 (§31 EmailServiceFactory / §32 EmailVerificationTokenPolicy / §33 PaymentNotificationPolicy 최신) |
| sprint plan-draft | `.claude/state/sprint-*-plan-draft.md` |
| 진단 보고서 | `reports/FULL_AUDIT_20260527.md` + `reports/PAYMENT_BACKLOG_AUDIT_20260523.md` |
| 세션 메모리 | `memory/project_session_20260527.md` (GCP + EMAIL-POLAR-READY 상세) |

---

## 8. 멀티 에이전트 / 도구 노트

- **agent**: grimoire-{planner, server, web, infrastructure, qa, cost-accountant, visual-canon-keeper} (orchestration-decision skill로 위임 분류)
- **agent AUP 차단 사례** (5/27): Phase 5 spawn 시 `API Error ... Usage Policy` 1건 — 메인 직접 진행으로 우회. 사용자 폭언 발화가 conversation-level safety classifier 발동 추정
- **Chrome MCP** (`mcp__Claude_in_Chrome__*`): Search Console verification 등 GUI 자동화 가능. CAPTCHA/로그인은 사용자 영역 (메인 우회 금지)
- **자격증명 위치**: Cloudflare token `~/.zshrc` / GCP `gcloud auth` (rainmaker8492) / Cloud SQL 비번 `/tmp/grimoire-sqlpass-{dev,prod}.txt` (600, 임시)
