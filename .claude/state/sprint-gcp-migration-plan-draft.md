# Sprint GCP Migration — Plan Draft (v2 전면 갱신)

> **상태**: Plan Draft v2 — 메인 결정 게이트 6건 확정 후 grimoire-infrastructure 위임 예정
> **작성**: 2026-05-27 — grimoire-planner (Initializer 역할, 책 Ch 16 Anthropic 3-에이전트 패턴)
> **v1 → v2 변경 사유**: 사용자 새 결정 verbatim ("GCP가 Azure보다 싸 보이고, ProjectZenith가 Azure → GCP 마이그레이션 금방 됐음. 진행해")
>   - region: asia-northeast3(서울) → **asia-northeast1(도쿄, Zenith 동일)**
>   - Secret 관리: Secret Manager → **Cloud Run env 직접 박제 (Zenith 동일, sprint 후 Secret Manager 별도 sprint)**
>   - Blob 이전: 후속 sprint → **본 sprint Phase 4 포함**
>   - Phase 분해: D1/D2/D3 (3 Phase) → **Phase 0~8 (9 Phase)**
>   - sub-task: 32건 → **42건 (Phase 0~8)**
>   - AC: 8건 → **10건**
> **목적**: ProjectGrimoire 인프라 회수 — Azure → GCP 전환 (월 비용 절감 + Zenith 패턴 정합)
> **정본 근거**: `grimoire-server/INFRASTRUCTURE.md` §1~§9 + Zenith GCP 실측(asia-northeast1 운영 中) + `reports/PAYMENT_BACKLOG_AUDIT_20260523.md` (트래픽 0건 박제)

---

## CRITICAL_CONSTRAINTS (이중 앵커 상단)

- **[MUST]** 작가 소설 콘텐츠 수정 0건 (작가 본문 인용/로깅 금지)
- **[MUST]** 결제 도메인 트랜잭션 원자성 보존 — CC-1~5 + PAY-S1~3 코드 변경 0건 (인프라만 이동)
- **[MUST]** shared-contracts 결제 §13~§30 회귀 0건 (sensor 일괄 5/5 PASS 유지)
- **[MUST]** secret/토큰 plain text 출력 금지 — 본 plan-draft 내에서도 마스킹 (`***` / `<MASKED>`)
- **[MUST]** Azure 인프라 절대 보호 (마이그레이션 중) — prod containerapp update 0건, Polar webhook URL 변경 0건
- **[MUST]** prod 미터치 보존 — 마이그레이션 완료 + ≥1주 검증 통과 전 Azure 리소스 삭제 0건 (Phase 7 별도 sprint 진입 게이트)
- **[MUST]** Polar webhook URL 보존 — `api.grimoire-book.com/payments/webhook` 그대로, Cloudflare CNAME만 GCP로 갱신 (Polar 입장 변경 0건)
- **[MUST]** 새 GCP 프로젝트 생성 금지 — 기존 `grimoire-491708` 사용 (사용자 새 메일 미생성)
- **[MUST]** 새 region 다중화 금지 — 모든 리소스 **asia-northeast1**(도쿄) 단일 (Zenith 정합)
- **[MUST]** §0 cost-accountant 게이트 — LLM 호출 0건이라 §0 마진 검증 무관, 인프라 비용 비교만 (§6 박제) — Azure ₩73k vs GCP 추산 비교 → `ai-cost-table.md` §부록 신설 권장
- **[MUST]** ProjectZenith asia-northeast1 prod 사용자 미영향 — Grimoire는 **신규 GCP 진입 0건** (계정 동일, 같은 region에 신 Cloud Run 4 서비스 추가)
- **[SHOULD]** 사용자 트래픽 0건 가정 박제 (`az containerapp logs --tail 1000 | grep HTTP` 0건 + WebhookRetryJob due=0 + PaymentReconciliationJob processed=0, 5/23 박제) — 위험 7건 무력화
- **[SHOULD]** Cloudflare TTL 사전 단축 (300s) — DNS propagation 시간 축소
- **[SHOULD]** Secret Manager 전환은 본 sprint 후 별도 sprint (Zenith 정합 — env 직접 우선, 보안 강화는 후속)

---

## 0. 메타

| 항목 | 값 |
|---|---|
| sprint 이름 | sprint-gcp-migration |
| Initializer | grimoire-planner (본 plan-draft v2) |
| Generator (예정) | grimoire-infrastructure (Phase 0~7 단계별 위임) |
| Evaluator (예정) | grimoire-qa (Sprint 계약 채점 + sprint-progress 통과율 박제) |
| 메인 (메타-검증) | curl 실측 + Azure 잔존 인벤토리 sweep + Cloudflare DNS 갱신 직접 + gcloud 인증 |
| 총 sub-task | **42건** (Phase 0=4 / 1=6 / 2=6 / 3=4 / 4=5 / 5=4 / 6=4 / 7=6 / 8=3) |
| 추정 시간 | **D1~D5 (4~5일)** — Phase 0=0.5h / 1=4~6h / 2=6h / 3=4h / 4=2h / 5=1h / 6=∞~3h / 7=2h+≥1주 / 8=2h |
| 의존 sprint | 없음 (prod 트래픽 0건 = cross-cloud 단절 위험 무력화) |
| 후속 sprint | (a) sprint-azure-decom (Phase 7 ≥1주 검증 후 정식 분리) / (b) sprint-secret-manager (Zenith 정합 — env → Secret Manager 강화) |
| 비용 절감 추산 | **Azure ~₩73,000/월 → GCP ~₩32,500/월 (-55% / 연간 ~₩486k)** ※§6 cost-accountant 정밀 검증 권장 |

---

## 1. 입력 — 현재 Azure 인벤토리 + Zenith 검증 패턴 + 사용자 가정

### 1-1. 현재 Azure 인벤토리 (회수 대상 12개, INFRASTRUCTURE.md §1+§9 정본)

```
[1] Container Apps × 4: grimoire-{server,web}-{dev,prod}
    cpu=0.25, mem=0.5Gi, min-replicas=0, max-replicas=1, port=3000(server)/3001(web)
    custom domain: dev.grimoire-book.com / dev-api.grimoire-book.com / grimoire-book.com / api.grimoire-book.com
    SSL: Azure 자동 HTTPS
[2] Azure Database for PostgreSQL Flexible × 2: grimoire-db-{dev,prod}
    SKU=B1ms (1 vCore / 2GB) / storage=32GB / PITR=7일 / autoGrow=꺼짐 / HA=꺼짐
    역할: 결제 + 크레딧 + 작가 도메인 DB (25+ Prisma 모델)
[3] Azure Container Registry: grimoireacr (Basic, 10GB 포함)
    이미지 태그 전략: grimoireacr.azurecr.io/grimoire-{server,web}:{env}-{SHA}
[4] Azure Blob Storage: grimoire0storage (Standard_LRS)
    역할: 테마 baked CSS + 커버 이미지 CDN
    어댑터: src/infrastructure/storage/blob-storage.service.ts (Hexagonal port 정합 — Phase 4 어댑터 1건 교체)
[5] Container Apps Environment: zenith-env-dev (ProjectZenith 떠남 확정, Grimoire 단독)
[6] Log Analytics × 3: workspace-grimoirergaS1b / workspace-grimoirerglw7l / workspace-zenithrggan5
[7] Container Apps secret refs (~13개):
    POLAR_ACCESS_TOKEN, POLAR_WEBHOOK_SECRET, POLAR_ORGANIZATION_ID,
    POLAR_PRODUCT_STARTER/BASIC/POPULAR/BEST, POLAR_PRODUCT_SUBSCRIPTION_PRO/PREMIUM,
    DATABASE_URL, JWT_SECRET, GOOGLE_CLIENT_ID, ANTHROPIC_API_KEY,
    AZURE_STORAGE_ACCOUNT_NAME/KEY
[8] Cloudflare CNAME × 4 (Azure FQDN 가리킴)
[9] Polar webhook target = api.grimoire-book.com/payments/webhook (Cloudflare 경유, Azure FQDN 직접 호출 X — URL 보존 핵심)
[10] GitHub Actions secrets (AZURE_CREDENTIALS, ACR_LOGIN_SERVER 등, deploy-*.yml `.disabled` 유지)
[11] scripts/deploy-*.sh + Makefile (az CLI 의존)
[12] zenith-rg 리소스 그룹 (ProjectZenith 떠남 확정, Grimoire 단독)
부속: DB Sync Nightly workflow — 6일 연속 실패 (grimoireadmin DB credentials 만료, 어차피 재구축 필요)
```

### 1-2. Zenith GCP 검증된 패턴 (실측 — gcloud 직접 추출, asia-northeast1 운영 중)

```
[Cloud Run] zenith-server-prod / zenith-web-prod / zenith-server-dev / zenith-web-dev
  containerConcurrency=80, timeoutSeconds=240, cpu=1, memory=512Mi
  env 직접 박제 (Secret Manager 미사용):
    NODE_ENV=production
    DATABASE_URL=postgresql://zenith:REMOVED_CREDENTIAL_017@136.109.149.159:5432/zenith?sslmode=require (외부 PG, plain IP)
    CORS_ORIGIN=https://1swiss.app
    기타 timeout 관련
  image: asia-northeast1-docker.pkg.dev/zenith-1swiss/cloud-run-source-deploy/zenith-server-prod@sha256:... (Cloud Build 자동 빌드 패턴)
[Artifact Registry] 2 repo (asia-northeast1):
  cloud-run-source-deploy (Cloud Run source deployment 자동 생성)
  zenith-docker (수동 docker push)
[배포 패턴]
  server: gcloud run deploy --source . (Cloud Build 자동 source deploy)
  web: 수동 docker build + gcloud artifacts docker push + gcloud run deploy --image
```

### 1-3. Grimoire 사용자 자율 default (메인 결정 박제, §9 게이트 통과 전 잠정)

| 항목 | Grimoire default | Zenith 비교 | 변경 사유 |
|---|---|---|---|
| region | **asia-northeast1**(도쿄) | 동일 | 사용자 명시 — Zenith 정합·신 region 진입 0건 |
| 프로젝트 | **grimoire-491708** (기존, enabled service 0개) | zenith-1swiss | 사용자 새 메일 미생성 — 기존 프로젝트 재사용 |
| Cloud Run × 4 | grimoire-{server,web}-{dev,prod} | 동일 명명 | Zenith 명명 정합 |
| Cloud Run resource | cpu=1 / mem=512Mi / min=0 / max=1 / concurrency=80 / timeout=240s | 동일 | Zenith 정합 (Azure Container Apps cpu=0.25보다 높지만 Cloud Run min=0 cold start 대응) |
| DB | **Cloud SQL for PostgreSQL** db-f1-micro (또는 db-g1-small) × 2 (dev/prod 분리) | Zenith는 외부 PG plain IP (자체 GCE VM) | 결제 도메인 자동 백업/PITR/IAM 필요 — Zenith는 환율 계산 도메인이라 외부 PG 충분, Grimoire는 결제 도메인이라 Cloud SQL 필요 |
| Artifact Registry | 단일 repo `grimoire-docker` | 2 repo (source-deploy + docker) | Zenith 패턴 단순화 — 수동 docker build/push (`make deploy-*` 정합) |
| Secret 관리 | **Cloud Run env 직접 박제** | 동일 | Zenith 정합 (sprint 후 Secret Manager는 별도 sprint) |
| Cloud Storage | grimoire-blob bucket (asia-northeast1) | 미사용 | Azure Blob 대체 (Hexagonal port 어댑터 1건 교체) |
| 빌드 클라이언트 | 로컬 gcloud CLI 직접 | 동일 | `feedback_manual_deploy_primary.md` 정합 (GitHub Actions 자동배포 차단) |

### 1-4. 사용자 트래픽 0건 가정 (위험 무력화, `PAYMENT_BACKLOG_AUDIT_20260523.md` 정본)

```
실측 출처 (5/23 11:00 KST 박제):
  - az containerapp logs --tail 1000 | grep HTTP → 0건 (server-prod)
  - WebhookRetryJob due=0 (PaymentReconciliationJob processed=0, 10분 주기 cron 로그)
  - Polar webhook 처리 0건 (KYC 미진입 = test mode)

무력화 위험 7건 (트래픽 0이라 영향 0):
  ① cross-cloud 단절 (Azure ↔ GCP DB 분리)
  ② DB 다운타임 (pg_dump 중 write 손실)
  ③ DNS propagation 사용자 영향
  ④ Polar webhook 중복 처리 (Azure + GCP 동시 수신 — Phase 5 DNS 전환 직전·직후)
  ⑤ Cloud Run cold start 사용자 노출
  ⑥ 환경 공유 (dev/prod 데이터 격리)
  ⑦ JWT secret 재발급 시 활성 세션 무효화

잔존 위험 (마이그레이션 중 진짜 위협):
  ① 실 작업량 (42 sub-task)
  ② DB pg_dump → Cloud SQL restore 정확성 (25+ table row count 정합)
  ③ Blob → Cloud Storage 객체 누락 (rsync 검증)
  ④ Secret 평문 노출 (Cloud Run env 직접 박제 = Zenith 정합이지만 dashboard 노출 위험 — Phase 8 후속 sprint에서 Secret Manager 전환)
```

---

## 2. Sprint 계약 (Initializer 책임 박제, 책 Ch 16 패턴)

### 2-1. 완료 기준 (Definition of Done)

- [ ] **Phase 0 완료**: gcloud 인증 + project 전환 + 5 API enable + Artifact Registry repo + Cloud Storage bucket 생성
- [ ] **Phase 1 완료**: Cloud SQL × 2 + DB/user 생성 + Azure → 로컬 pg_dump 백업 + Prisma migration apply
- [ ] **Phase 2 완료**: Cloud Run server × 2 (dev/prod) 배포 + env ~13개 박제 + health 200
- [ ] **Phase 3 완료**: Cloud Run web × 2 (dev/prod) 배포 + BFF API_URL 매핑 + health 200
- [ ] **Phase 4 완료**: grimoire0storage 인벤토리 + Cloud Storage rsync + BlobAdapter → CloudStorageAdapter 교체 + 객체 count 정합
- [ ] **Phase 5 완료**: Cloudflare CNAME 4 갱신 + Polar webhook auto-disable 사전 점검 + TTL 복구
- [ ] **Phase 6 완료**: 메인 curl 실측 (4 endpoint × dev/prod) + 24h prod 박제 (트래픽 0이라 단축 가능)
- [ ] **Phase 7 완료 (≥1주 검증 후 별도 sprint)**: Azure Container Apps 4 + DB 2 + ACR + Blob + Log Analytics 3 정리 + zenith-rg 잔존 0
- [ ] **Phase 8 완료**: INFRASTRUCTURE.md + environments.md + Makefile + scripts 전면 갱신 + memory + shared-contracts §21 갱신 + sensor 검토
- [ ] **AC BDD 10건 전건 PASS** (§4 참조)
- [ ] **위험 매트릭스 R1~R7 mitigation 박제** (§5 참조)
- [ ] **비용 매트릭스 박제** (§6 — cost-accountant `ai-cost-table.md` §부록 신설 권장)
- [ ] **env 매핑 표 박제** (§7 — Azure secret name ↔ Cloud Run env name 13건)
- [ ] **사용자 결정 게이트 6건 확정** (§9)

### 2-2. 진척 추적

- `reports/sprint-gcp-migration-progress.md` — Generator(infrastructure) Phase별 갱신
- 각 sub-task 체크박스 + 실행 명령 + 검증 게이트 + 결과 박제
- Evaluator(qa) Sprint 계약 채점 → `QA_REPORT.md` sprint-progress 통과율 박제
- 메인 메타-검증 — Phase 5 직후·Phase 6 직후 curl 실측 직접 (qa 위임 X — 사용자 영향 직접 확인)

---

## 3. Phase 분해 — Phase 0~8 (42 sub-task)

### Phase 0 — 사전 (4 sub-task, ~30분, 🟢 메인 직접 가능)

> 목적: GCP 측 사전 준비. Azure 미터치. 사용자 트래픽 영향 0건.

| ID | sub-task | 우선순위 | 위험 | 실행 명령 | 검증 게이트 |
|---|---|---|---|---|---|
| P0-1 | gcloud 인증 + active project 전환 | [MUST] | 🟢 | `gcloud config set project grimoire-491708 && gcloud auth list` | `gcloud config get-value project` = `grimoire-491708` |
| P0-2 | 5 API enable (run / sqladmin / artifactregistry / cloudbuild / storage) | [MUST] | 🟢 | `gcloud services enable run.googleapis.com sqladmin.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com storage.googleapis.com --project=grimoire-491708` | `gcloud services list --enabled` 5건 PASS |
| P0-3 | Artifact Registry repo 생성 `grimoire-docker` (asia-northeast1) | [MUST] | 🟢 | `gcloud artifacts repositories create grimoire-docker --repository-format=docker --location=asia-northeast1 --project=grimoire-491708` | `gcloud artifacts repositories describe grimoire-docker --location=asia-northeast1` |
| P0-4 | Cloud Storage bucket 생성 `grimoire-blob` (asia-northeast1, Standard) | [MUST] | 🟢 | `gcloud storage buckets create gs://grimoire-blob --location=asia-northeast1 --default-storage-class=STANDARD --uniform-bucket-level-access` | `gcloud storage buckets describe gs://grimoire-blob` |

### Phase 1 — DB 마이그레이션 (6 sub-task, ~4~6h, 🔴 고위험)

> 목적: Cloud SQL × 2 셋업 + Azure → Cloud SQL 데이터 이전. Azure DB 미터치 (pg_dump only).

| ID | sub-task | 우선순위 | 위험 | 실행 명령 | 검증 게이트 |
|---|---|---|---|---|---|
| P1-1 | Cloud SQL 인스턴스 dev 생성 `grimoire-db-dev-gcp` (db-f1-micro / PG 16 / asia-northeast1 / PITR 7일) | [MUST] | 🟡 | `gcloud sql instances create grimoire-db-dev-gcp --database-version=POSTGRES_16 --tier=db-f1-micro --region=asia-northeast1 --backup-start-time=18:00 --backup-location=asia-northeast1 --enable-point-in-time-recovery --retained-backups-count=7 --storage-size=10GB --storage-type=HDD` | `gcloud sql instances describe grimoire-db-dev-gcp --format="value(state)"` = RUNNABLE |
| P1-2 | Cloud SQL 인스턴스 prod 생성 `grimoire-db-prod-gcp` | [MUST] | 🟡 | P1-1 정합, env=prod (사용자 KYC 통과 시 SSD 전환 검토 — §9 게이트 #1) | P1-1 정합 |
| P1-3 | Cloud SQL DB + 사용자 생성 (`grimoire` DB + `grimoireadmin` user × dev/prod) | [MUST] | 🟢 | `gcloud sql databases create grimoire --instance=grimoire-db-{env}-gcp` + `gcloud sql users create grimoireadmin --instance=grimoire-db-{env}-gcp --password='<MASKED>'` × 2 | psql connection 성공 (Cloud SQL Auth Proxy 또는 public IP + firewall) |
| P1-4 | Azure DB → 로컬 pg_dump 백업 (dev/prod 각각, ≥30일 보관) | [MUST] | 🟡 | `pg_dump --host=grimoire-db-{env}.postgres.database.azure.com --username=grimoireadmin --dbname=grimoire --format=custom --file=backup-{env}-$(date +%Y%m%d).dump` (방화벽 임시 추가 후 제거) | `ls -lh backup-*.dump` 파일 크기 ≥10MB 예상 + 평문/덤프 분리 보관 |
| P1-5 | Cloud SQL pg_restore 적용 (dev/prod 각각) + Prisma migrate deploy | [MUST] | 🔴 | `pg_restore --host=<Cloud SQL public IP> --username=grimoireadmin --dbname=grimoire --no-owner --no-acl backup-{env}-*.dump` + `DATABASE_URL=postgresql://... RUN_MIGRATION=true npx prisma migrate deploy` | `_prisma_migrations` 테이블 entries 정합 + connection 성공 |
| P1-6 | row count 정합 검증 — 25+ Prisma 모델 전건 | [MUST] | 🔴 | Azure psql vs GCP Cloud SQL psql 양쪽 `SELECT COUNT(*) FROM {table}` × 25+ table | 핵심 7 모델(Author/Theme/Work/Episode/Payment/CreditLedger/MembershipPlan) + WebhookEvent + RefundLog + ReconciliationCheckpoint + WebhookRetryQueue + AdminAuditLog + SubscriptionTier 전건 일치 |

### Phase 2 — server Cloud Run × 2 이전 (6 sub-task, ~6h, 🟡 중위험)

> 목적: server-dev / server-prod 배포 + env ~13개 박제. Cloudflare DNS 아직 Azure 가리킴 = 사용자 트래픽 영향 0.

| ID | sub-task | 우선순위 | 위험 | 실행 명령 | 검증 게이트 |
|---|---|---|---|---|---|
| P2-1 | Dockerfile 정합 검증 (Azure Container Apps용이 Cloud Run에서도 통하는지 — alpine 정합) | [MUST] | 🟢 | `cd grimoire-server && docker build -t test-gcp . && docker run --rm -e PORT=3000 test-gcp` | 로컬 build PASS + container `:3000/health` 200 |
| P2-2 | Cloud Run server-dev 배포 (Cloud Build source deploy) | [MUST] | 🟡 | `cd grimoire-server && gcloud run deploy grimoire-server-dev --source=. --region=asia-northeast1 --platform=managed --allow-unauthenticated --port=3000 --min-instances=0 --max-instances=1 --memory=512Mi --cpu=1 --concurrency=80 --timeout=240 --set-env-vars="NODE_ENV=development,APP_ENV=development,DATABASE_URL=<MASKED>,JWT_SECRET=<MASKED>,..." --project=grimoire-491708` | `gcloud run services describe grimoire-server-dev --region=asia-northeast1 --format="value(status.url)"` Cloud Run URL 반환 |
| P2-3 | Cloud Run server-prod 배포 | [MUST] | 🔴 | P2-2 정합, env=prod (POLAR_SERVER=production / NODE_ENV=production) | P2-2 정합 |
| P2-4 | server env 매핑 13건 검증 (§7 표 정합 — POLAR_* 7건 + DATABASE_URL + JWT_SECRET + GOOGLE_CLIENT_ID + ANTHROPIC_API_KEY + AZURE_STORAGE_* 2건은 Phase 4 후 갱신) | [MUST] | 🔴 | `gcloud run services describe grimoire-server-{env} --region=asia-northeast1 --format=yaml \| grep -E "POLAR|DATABASE|JWT|GOOGLE|ANTHROPIC"` 13건 count | 평문 박제 13건 정합 + Phase 4 후 AZURE_STORAGE_* 2건은 CloudStorage env로 교체 |
| P2-5 | Cloud Run server health 검증 (dev/prod 직접 Cloud Run URL) | [MUST] | 🟢 | `curl https://grimoire-server-{env}-<hash>-an.run.app/api/health` × 2 | HTTP 200 + body `{"status":"ok"}` |
| P2-6 | server 결제 도메인 sensor 일괄 (sensor-payment-idempotency + reconciliation + refund-atomicity + circuit-breaker-policy + race-condition) | [MUST] | 🔴 | `bash .claude/scripts/sensor-payment-*.sh` 5개 (Cloud Run server-{env} URL 대상) | 5개 sensor 결과가 Azure 박제(`PAYMENT_BACKLOG_AUDIT_20260523.md` 부록 A) 정합 (PASS 7+10+10+10+6/FAIL 2 정합 — sensor regex stale 대상 동일) |

### Phase 3 — web Cloud Run × 2 이전 (4 sub-task, ~4h, 🟡 중위험)

> 목적: web-dev / web-prod 배포 + BFF API_URL 매핑. Cloudflare DNS 아직 Azure 가리킴.

| ID | sub-task | 우선순위 | 위험 | 실행 명령 | 검증 게이트 |
|---|---|---|---|---|---|
| P3-1 | web Dockerfile 정합 검증 (Next.js 16+ Cloud Run port 3001 → Cloud Run PORT env 자동 매핑 — Azure와 동일하게 listen) | [MUST] | 🟢 | `cd grimoire-web && docker build -t test-gcp . && docker run --rm -e PORT=3001 test-gcp` | 로컬 build PASS + container `:3001` HTTP 200 |
| P3-2 | Cloud Run web-dev 배포 (build-env-vars NEXT_PUBLIC_API_BASE_URL 박제 — server-dev Cloud Run URL 매핑) | [MUST] | 🟡 | `cd grimoire-web && gcloud run deploy grimoire-web-dev --source=. --region=asia-northeast1 --platform=managed --allow-unauthenticated --port=3001 --min-instances=0 --max-instances=1 --memory=512Mi --cpu=1 --concurrency=80 --timeout=240 --build-env-vars="NEXT_PUBLIC_API_BASE_URL=https://grimoire-server-dev-<hash>-an.run.app/api" --set-env-vars="API_URL=https://grimoire-server-dev-<hash>-an.run.app/api,NEXT_PUBLIC_APP_ENV=development" --project=grimoire-491708` | `gcloud run services describe grimoire-web-dev --region=asia-northeast1 --format="value(status.url)"` |
| P3-3 | Cloud Run web-prod 배포 | [MUST] | 🔴 | P3-2 정합, env=prod (NEXT_PUBLIC_APP_ENV=production / API_URL=server-prod Cloud Run URL) | P3-2 정합 |
| P3-4 | Cloud Run web 검증 (dev/prod 직접 Cloud Run URL) | [MUST] | 🟢 | `curl -I https://grimoire-web-{env}-<hash>-an.run.app` × 2 | HTTP 200 + Next.js HTML 응답 + BFF `/api/*` proxy 정상 |

### Phase 4 — Blob → Cloud Storage 이전 (5 sub-task, ~2h, 🟡 중위험)

> 목적: grimoire0storage(테마 baked CSS + 커버 이미지) 객체 이전 + 어댑터 1건 교체. Hexagonal port 인터페이스 그대로 = 도메인/UseCase 코드 변경 0건.

| ID | sub-task | 우선순위 | 위험 | 실행 명령 | 검증 게이트 |
|---|---|---|---|---|---|
| P4-1 | grimoire0storage 객체 인벤토리 박제 (커버 이미지 + 테마 baked CSS 분류 + count) | [MUST] | 🟢 | `az storage blob list --account-name grimoire0storage --container-name <name> --account-key <MASKED> --query "[].{name:name,size:properties.contentLength}" -o table` | 컨테이너별 객체 count + 총 용량 박제 |
| P4-2 | Cloud Storage rsync (Azure SDK → gcs SDK) — `azcopy` 또는 `gsutil` rsync | [MUST] | 🟡 | `azcopy copy "https://grimoire0storage.blob.core.windows.net/<container>?<SAS>" "gs://grimoire-blob/<container>" --recursive` 또는 로컬 다운로드 후 `gcloud storage cp -r ./local gs://grimoire-blob/` | `gcloud storage ls -r gs://grimoire-blob/` 객체 count 정합 + 샘플 5개 size 일치 |
| P4-3 | 신 CloudStorageAdapter 추가 (src/infrastructure/storage/cloud-storage.service.ts) — `@google-cloud/storage` SDK + BlobStoragePort 인터페이스 그대로 구현 | [MUST] | 🟡 | server 레포에서 신 어댑터 코드 + spec 추가 (도메인/UseCase 변경 0건 — Hexagonal port 유지) | `npm test cloud-storage.service.spec.ts` PASS + sensor-docs-sync PASS |
| P4-4 | server env 갱신 — Cloud Run server-{env} `--update-env-vars` 로 AZURE_STORAGE_* 제거 + GOOGLE_CLOUD_STORAGE_BUCKET=grimoire-blob 추가 | [MUST] | 🟡 | `gcloud run services update grimoire-server-{env} --region=asia-northeast1 --remove-env-vars="AZURE_STORAGE_ACCOUNT_NAME,AZURE_STORAGE_ACCOUNT_KEY" --update-env-vars="GOOGLE_CLOUD_STORAGE_BUCKET=grimoire-blob"` × 2 | `gcloud run services describe ... --format=yaml \| grep -E "AZURE_STORAGE\|GOOGLE_CLOUD_STORAGE"` AZURE 0건 / GCS 1건 |
| P4-5 | 테마 baked CSS + 커버 이미지 사용자 액션 검증 (dev에서 새 테마 1건 baking + 새 커버 업로드 1건) | [MUST] | 🔴 | dev 사이트 직접 — POST /api/themes/{id}/bake + POST /api/works/{id}/cover (Cloud Run URL 직접) | bakedCssUrl 응답 `https://storage.googleapis.com/grimoire-blob/...` + 200 OK |

### Phase 5 — Cloudflare DNS 전환 (4 sub-task, ~1h + propagation 5분, 🔴 고위험)

> 목적: Cloudflare CNAME 4건 갱신 → 실 사용자 트래픽 GCP 라우팅. Polar webhook URL 변경 0건.

| ID | sub-task | 우선순위 | 위험 | 실행 명령 | 검증 게이트 |
|---|---|---|---|---|---|
| P5-1 | Cloudflare TTL 사전 단축 — 4 CNAME TTL=300s (24h 전 권장이나 트래픽 0건이라 즉시 진입 가능) | [MUST] | 🟢 | Cloudflare Dashboard 또는 API | `dig {domain}` TTL ≤ 300 |
| P5-2 | Cloudflare CNAME 갱신 — dev 우선 (dev-api.grimoire-book.com + dev.grimoire-book.com → Cloud Run URL) | [MUST] | 🟡 | Cloudflare Dashboard CNAME edit × 2 | `dig dev-api.grimoire-book.com` Cloud Run hash 확인 + `dig dev.grimoire-book.com` Cloud Run hash 확인 |
| P5-3 | Cloudflare CNAME 갱신 — prod (api.grimoire-book.com + grimoire-book.com → Cloud Run URL) | [MUST] | 🔴 | Cloudflare Dashboard CNAME edit × 2 (Polar webhook URL = api.grimoire-book.com 정합) | `dig api.grimoire-book.com` Cloud Run hash + `dig grimoire-book.com` Cloud Run hash |
| P5-4 | Cloud Run custom domain 매핑 — 4 도메인 (Cloud Run Domain Mappings + Free SSL 자동 발급) — §9 게이트 #4 Cloudflare SSL Full Strict 모드 결정 종속 | [MUST] | 🟡 | `gcloud beta run domain-mappings create --service=grimoire-{server,web}-{env} --domain={env}.grimoire-book.com --region=asia-northeast1` × 4 | `gcloud beta run domain-mappings describe` SSL 인증서 issued 확인 |

### Phase 6 — 검증 + 24h 박제 (4 sub-task, ~∞~3h, 🟡 중위험)

> 목적: 메인 curl 실측 (4 endpoint × dev/prod) + Polar webhook 살아있는지 확인. 트래픽 0건이라 24h 단축 가능.

| ID | sub-task | 우선순위 | 위험 | 실행 명령 | 검증 게이트 |
|---|---|---|---|---|---|
| P6-1 | 메인 curl 실측 — dev (4 endpoint: health / products / membership / circuit-breaker state) | [MUST] | 🔴 | `curl https://dev-api.grimoire-book.com/api/health` + `/api/payments/products` + `/api/subscriptions/plans` + `/api/admin/circuit-breaker/state` (인증 필요 시 토큰 박제 X — public endpoint만 검증) | 전건 HTTP 200 + Cloud Run revision response header |
| P6-2 | 메인 curl 실측 — prod (4 endpoint 동일) | [MUST] | 🔴 | `curl https://api.grimoire-book.com/api/health` + 동일 4종 | 전건 HTTP 200 |
| P6-3 | Polar webhook 살아있는지 확인 (Polar Dashboard "Send test event" or `gh secret list` 정합) | [SHOULD] | 🟡 | Polar Dashboard webhook page 직접 — Send test event 1회 | webhook_events 테이블 신 row INSERT (eventId 신규) + Cloud Run logs `payment.usecase.processWebhook 진입` 박제 |
| P6-4 | Cloudflare TTL 복구 (옵션) — 4 CNAME TTL=auto 또는 사용자 선호값 | [SHOULD] | 🟢 | Cloudflare Dashboard | TTL 정합 |

### Phase 7 — Azure 정리 (별도 sprint, 6 sub-task, ~2h + ≥1주 검증, 🟢 후속 sprint)

> **별도 sprint**: `sprint-azure-decom` (Phase 6 검증 ≥1주 통과 + 사용자 명시 승인 후 진입)
> **전제**: prod 미터치 보존 정본 (Phase 0~6 완료 후 사용자 메인 결정 #5 통과 시)
> 본 sprint 범위 외 — 본 plan-draft에서는 절차만 박제.

| ID | sub-task | 우선순위 | 위험 | 실행 명령 | 검증 게이트 |
|---|---|---|---|---|---|
| P7-1 | Azure DB 추가 pg_dump 백업 (≥30일 보관, 별도 GCS bucket 또는 로컬) | [MUST] | 🟢 | P1-4 정합, file=`backup-{env}-decom-$(date +%Y%m%d).dump` | 파일 크기 정합 + 로컬+GCS 이중 보관 |
| P7-2 | Container Apps 4 서비스 stop (`revision deactivate`, 회수는 후행 ≥3일 stop 모니터링) | [MUST] | 🟡 | `az containerapp revision deactivate --name grimoire-{server,web}-{env} --resource-group zenith-rg` × 4 | revision state=Inactive |
| P7-3 | Container Apps 4 서비스 + Container Apps Environment 삭제 | [MUST] | 🟡 | `az containerapp delete --name grimoire-{server,web}-{env} -g zenith-rg --yes` × 4 + `az containerapp env delete --name zenith-env-dev -g zenith-rg --yes` (Zenith가 떠난 후) | `az containerapp list -g zenith-rg` grimoire-* 0건 |
| P7-4 | PostgreSQL Flexible Server 2개 삭제 (P7-1 백업 후) | [MUST] | 🔴 | `az postgres flexible-server delete --name grimoire-db-{env} -g zenith-rg --yes` × 2 | `az postgres flexible-server list -g zenith-rg` 0건 |
| P7-5 | ACR + Log Analytics 3 + Blob Storage 회수 | [MUST] | 🟡 | `az acr delete --name grimoireacr -g zenith-rg --yes` + `az monitor log-analytics workspace delete` × 3 + `az storage account delete --name grimoire0storage` (Phase 4 객체 이전 확인 후) | `az resource list -g zenith-rg \| grep grimoire` 0건 |
| P7-6 | zenith-rg 잔존 인벤토리 sweep + 월 비용 실측 (Azure Cost Management) | [MUST] | 🟢 | `az resource list -g zenith-rg -o table` + Azure Portal Cost Management | grimoire-* 잔존 0건 + 월 비용 < ₩5,000 (Azure 잔재만) |

### Phase 8 — 문서 갱신 + sensor 박제 (3 sub-task, ~2h, 🟢 메인+infrastructure 분담)

> 목적: Azure → GCP 정본 문서 전면 갱신 + 메모리 박제 + shared-contracts §21 갱신.

| ID | sub-task | 우선순위 | 위험 | 실행 명령 | 검증 게이트 |
|---|---|---|---|---|---|
| P8-1 | INFRASTRUCTURE.md + environments.md + Makefile + scripts/deploy-*.sh 전면 갱신 (Azure → GCP, `az` → `gcloud`) | [MUST] | 🟡 | server/web 양 레포에서 docs 수정 + Makefile target 재작성 (`make deploy-dev` → gcloud run deploy) | `bash .claude/scripts/sensor-docs-sync.sh` PASS + sensor-instruction-degradation PASS |
| P8-2 | memory + shared-contracts §21 (InfraMutationGuard) 갱신 + 새 sensor 검토 (sensor-gcp-deploy-health 신설 필요 시) | [MUST] | 🟢 | `.claude/shared-contracts.md` §21 + `~/.claude/projects/.../memory/feedback_manual_deploy_primary.md` 갱신 (Azure → GCP 명령) + `.claude/scripts/sensor-deploy-health.sh` Azure → GCP 분기 | sensor-shared-contracts PASS + sensor-agent-priority-labels PASS |
| P8-3 | eval/scripts/eval-runner.sh 실측 + reports/sprint-gcp-migration-progress.md 종료 박제 + 메모리 1줄 인덱스 추가 | [MUST] | 🟢 | `bash eval/scripts/eval-runner.sh` 회귀 regression 모드 + memory `project_session_2026MMDD.md` 신설 | regression PASS ≥95% (baseline 정합) + memory MEMORY.md 인덱스 1줄 추가 |

---

## 4. AC (Acceptance Criteria) BDD 10건

```gherkin
Scenario AC-1: Phase 0~1 GCP 인프라 + DB 셋업 완료 (Azure 미터치)
  Given Azure 리소스가 정상 동작 중이고 (Container Apps 4 + DB 2 + ACR + Blob 전건 running)
  And Cloudflare DNS는 Azure FQDN을 가리키고 있다
  When grimoire-infrastructure가 Phase 0+1 sub-task를 수행하고
  Then GCP 5 API enable + Artifact Registry repo + Cloud Storage bucket 생성 + Cloud SQL × 2 RUNNABLE
  And `gcloud services list --enabled` 5건 PASS
  And `gcloud sql instances list --filter="name~grimoire-db-.*-gcp"` 2 row RUNNABLE
  And Azure 리소스에 변경 0건 (`az resource list -g zenith-rg` diff = 0)

Scenario AC-2: P1-6 DB row count 정합 (25+ Prisma 모델)
  Given Azure dev/prod DB pg_dump 백업 파일이 ≥10MB 존재하고
  And Cloud SQL dev/prod에 pg_restore 적용 + Prisma migrate deploy 완료
  When `psql -c "SELECT COUNT(*) FROM {table}"` 양쪽 (Azure + GCP) 25+ table
  Then 전건 COUNT 일치 (Author / Theme / Work / Episode / Payment / CreditLedger / MembershipPlan + WebhookEvent + RefundLog + ReconciliationCheckpoint + WebhookRetryQueue + AdminAuditLog + SubscriptionTier 핵심 13 모델 100% 일치)
  And `_prisma_migrations` 테이블 entries 일치
  And FK 깨짐 0건 (`psql -c "SELECT conname FROM pg_constraint WHERE contype='f'"` count 정합)

Scenario AC-3: Cloud Run health 200 (4 서비스 직접 URL, Cloudflare 우회)
  Given Cloud Run server-dev / server-prod / web-dev / web-prod 4 서비스 배포 완료
  When `curl https://grimoire-{server,web}-{env}-<hash>-an.run.app/{health\|/}` × 8
  Then 전건 HTTP 200
  And server health body `{"status":"ok"}`
  And web HTML response Next.js 응답

Scenario AC-4: P4 Blob 객체 이전 정합 (count + 샘플 size)
  Given grimoire0storage 객체 인벤토리 박제 완료 (P4-1)
  And gs://grimoire-blob rsync 완료 (P4-2)
  When `gcloud storage ls -r gs://grimoire-blob/ \| wc -l` vs Azure container 객체 count
  Then 객체 count 100% 일치
  And 샘플 5개 size 일치 (head 1k bytes hash 비교)
  And 테마 baked CSS 신 1건 + 커버 이미지 신 1건 dev 사이트에서 정상 응답 (P4-5)

Scenario AC-5: Polar webhook URL 보존 (api.grimoire-book.com 그대로, Polar 입장 변경 0)
  Given Cloudflare DNS api.grimoire-book.com이 Cloud Run prod로 갱신됨 (P5-3)
  And Polar Dashboard webhook URL = https://api.grimoire-book.com/payments/webhook (변경 0건)
  When Polar Dashboard에서 "Send test event" 실행 (P6-3)
  Then webhook_events 테이블에 신 row INSERT (eventId 신규)
  And payment.usecase.processWebhook 진입 로그 박제 (Cloud Run logs `gcloud run services logs read grimoire-server-prod --region=asia-northeast1 --limit=100`)
  And HTTP 200 응답 (Polar 측 webhook auto-disable 차단)
  And webhook signing secret 변경 0건 (POLAR_WEBHOOK_SECRET 박제 Cloud Run env에 평문 그대로 박제됨)

Scenario AC-6: 결제 도메인 sensor 5종 회귀 0 (Azure 박제 정합)
  Given Cloud Run server-{env} 배포 + DB 마이그레이션 + 모든 결제 spec PASS
  When `bash .claude/scripts/sensor-payment-{idempotency,reconciliation,refund-atomicity,circuit-breaker-policy,race-condition}.sh` 5개
  Then 결과가 Azure 박제 (`PAYMENT_BACKLOG_AUDIT_20260523.md` 부록 A) 정합
  And sensor-payment-idempotency: PASS 7/7
  And sensor-payment-reconciliation: PASS 10/10
  And sensor-refund-atomicity: PASS 10/10
  And sensor-circuit-breaker-policy: PASS 10/10
  And sensor-payment-race-condition: PASS 6 / FAIL 2 (sensor regex stale — false-positive 박제 정합)

Scenario AC-7: Reconciliation cron 정상 동작 (Cloud Run server-prod)
  Given Cloud Run server-prod 배포 + DB 마이그레이션 완료 후 ≥10분 경과
  When `gcloud run services logs read grimoire-server-prod --region=asia-northeast1 --limit=200 \| grep "PaymentReconciliationJob"`
  Then "PaymentReconciliationJob 시작" 로그 ≥1건
  And "PaymentReconciliationJob 완료 — processed=N boost=N mismatch=N expire=N" 로그 ≥1건
  And exception 0건
  And 10분 주기 정상 (replicas=1 가정 — in-memory isRunning lock 정합)

Scenario AC-8: secret 평문 박제 정책 정합 (Zenith 정합 — Secret Manager 미사용)
  Given Cloud Run server-{dev,prod} 환경 변수 박제 완료 (P2-2/P2-3)
  When `gcloud run services describe grimoire-server-{env} --region=asia-northeast1 --format=yaml \| grep -E "POLAR_ACCESS_TOKEN\|JWT_SECRET\|DATABASE_URL\|ANTHROPIC_API_KEY"`
  Then 평문 박제 정상 (Zenith 정합 — Secret Manager 미사용)
  And 13건 env 박제 정합 (§7 표)
  And Cloud Run dashboard 접근권한이 사용자 단독 (다인 GCP IAM 진입 시 Secret Manager 전환 sprint 진입 권장)
  And 본 plan-draft + reports 내 평문 출력 0건 (모두 `<MASKED>` 또는 `***`)

Scenario AC-9: 메인 curl 실측 (Phase 6) dev+prod 8 endpoint 전건 200
  Given Cloudflare DNS 4 CNAME 갱신 완료 (Phase 5) + TTL propagation 5분 경과
  When 메인 `curl https://{dev.,dev-api.,api.,}grimoire-book.com/api/{health,payments/products,subscriptions/plans,admin/circuit-breaker/state}` 8 endpoint
  Then dev 4 endpoint + prod 4 endpoint 전건 HTTP 200
  And Cloud Run revision header 박제 (Azure FQDN 미참조)
  And /api/health body `{"status":"ok"}`

Scenario AC-10: Azure 미터치 (Phase 0~6 마이그레이션 중 + Phase 7 별도 sprint 진입 전)
  Given Phase 0 시작 시점부터 Phase 6 완료 시점까지
  When `az resource list --resource-group zenith-rg -o tsv \| wc -l` 매 Phase 종료 시 비교
  Then Azure 리소스 수 변동 0건
  And `az containerapp revision list --name grimoire-{server,web}-{env}` 최신 revision 변동 0건
  And `az postgres flexible-server show --name grimoire-db-{env}` config 변동 0건
  And Azure DB pg_dump 백업 외 Azure 측 write 0건 (firewall 규칙 임시 추가/제거만)
```

---

## 5. 위험 매트릭스 + 롤백 전략

### 5-1. 위험 매트릭스 (R1~R7)

| ID | 위험 | 발생 확률 | 영향 | mitigation | 잔존 위험 |
|---|---|---|---|---|---|
| R1 | DB pg_dump → Cloud SQL restore 정확성 (row count 불일치 / FK 깨짐) | 🟡 중 | 🔴 치명 | P1-4 백업 ≥30일 보관 + P1-6 25+ table row count 정합 검증 + Prisma migrate deploy로 schema 정합 + FK constraint count 정합 (AC-2) | row 단위 deep equality 미검증 (LIMIT 100 sample만) — 사용자 트래픽 0건 = 운영 진입 전 dev 1주 추가 검증 권장 |
| R2 | Cloud Storage rsync 누락 (테마 baked CSS + 커버 이미지 손실) | 🟡 중 | 🟡 중 | P4-1 인벤토리 박제 + P4-2 rsync 후 객체 count 정합 + 샘플 5개 size 일치 (AC-4) + P4-5 신 1건 baking 검증 | 객체 metadata (cacheControl / contentType) 미검증 — bakedCssUrl 응답 정합만 검증 |
| R3 | Polar webhook auto-disable (URL 변경 시 또는 5xx 반복 시) | 🟢 낮 | 🔴 치명 | URL 변경 0건 (Cloudflare CNAME만 갱신) + P5-3 prod CNAME 갱신 직후 P6-3 test event 검증 (AC-5) + POLAR_WEBHOOK_SECRET 평문 그대로 박제 = signing 정합 | Cloudflare 일시 5xx 시 Polar retry 정책 ≤24h이라 사용자 트래픽 0건 가정 = 영향 0 |
| R4 | Cloud Run cold start (min-replicas=0 정합, Container Apps와 동등) | 🟢 낮 | 🟢 낮 | knative `min-instances=0` + `startup-cpu-boost=true` (Zenith 패턴 정합) + Cloudflare edge 캐시 | 첫 요청 5-10초 지연 (Container Apps 10-30초보다 빠름) |
| R5 | env 13건 누락 / 오타 (Cloud Run dashboard 평문 박제 = Zenith 정합) | 🟡 중 | 🔴 치명 | §7 env 매핑 표 정본 + P2-4 검증 게이트 + `gcloud run services describe ... --format=yaml \| grep` 13건 count + AC-8 평문 정합 박제 | env diff 자동화 미박제 (수동 검증) — 후속 sprint에서 `sensor-gcp-env.sh` 신설 권장 |
| R6 | Cloud SQL db-f1-micro 성능 부족 (B1ms = 1 vCore / 2GB vs db-f1-micro = shared vCPU / 0.6GB) | 🟡 중 | 🟡 중 | dev DB는 db-f1-micro 충분 / prod DB는 트래픽 진입 시 db-g1-small (1.7GB) 즉시 업그레이드 검토 (§9 게이트 #1) | 사용자 트래픽 0건 = 즉시 영향 0 / KYC 통과 후 사용자 진입 시점에 prod DB tier 재검토 필수 |
| R7 | Cloudflare DNS propagation 시간 (TTL 미단축 시 ≤48h) | 🟢 낮 | 🟡 중 | P5-1 사전 TTL=300s 단축 + P6-4 복구 | 사용자 트래픽 0건 = 영향 0 |

### 5-2. 롤백 전략 (사용자 트래픽 0건 가정 = 즉시 가능, Phase별)

```
Tier 1 — Phase 5 직후 (DNS 전환 직후) 사용자 발견 시: Cloudflare CNAME만 Azure로 복귀 (∞ + 5분)
  Cloudflare Dashboard → 4 CNAME edit (Cloud Run hash → Azure FQDN 복귀)
  TTL=300s = propagation 5분 내
  Azure Container Apps 그대로 살아있어서 즉시 복귀
  → 영향: Phase 6 검증 실패 시 5분 내 복귀 가능

Tier 2 — Phase 4 직후 (Blob 이전 직후) 객체 누락 발견 시: Cloud Storage 삭제 + Azure Blob 복귀
  gcloud storage rm -r gs://grimoire-blob/* (또는 bucket 자체 삭제)
  server env GOOGLE_CLOUD_STORAGE_BUCKET 제거 + AZURE_STORAGE_* 복귀
  → Cloudflare DNS는 Phase 5 진입 전이라 Azure 그대로 = 영향 0

Tier 3 — Phase 2/3 직후 (Cloud Run 배포 직후) 코드 회귀 발견 시: Cloud Run revision rollback
  gcloud run services update-traffic grimoire-{server,web}-{env} --to-revisions=PREVIOUS=100
  또는 stop: gcloud run services delete (재배포 가능)
  → Cloudflare DNS Azure 그대로 = 영향 0

Tier 4 — Phase 1 직후 (DB 마이그레이션 직후) row count 불일치 발견 시: Cloud SQL restore + Azure 복귀
  gcloud sql backups restore <backup-id> --restore-instance=grimoire-db-{env}-gcp (이전 백업 복원)
  또는 P1-4 백업으로 재 restore
  → Azure DB 그대로 = 영향 0

Tier 5 — Phase 0 직후 (인프라 생성 직후) 회귀 발견 시: GCP 리소스 완전 삭제 (∞ + 15분)
  gcloud run services delete × 4
  gcloud sql instances delete grimoire-db-{env}-gcp × 2
  gcloud storage buckets delete gs://grimoire-blob
  gcloud artifacts repositories delete grimoire-docker
  Azure 리소스는 그대로 ≥1주 보존

조건: Azure 리소스 ≥1주 보존 = sprint-azure-decom (Phase 7 별도 sprint) 진입 전까지 안전망
```

---

## 6. 비용 매트릭스 — Azure vs GCP 추산

> **§0 정합**: LLM 호출 0건이라 cost-accountant 마진 ≥3배 검증 무관. 인프라 비용 비교만 박제.
> 박제 위치: `grimoire-server/docs/ai-cost-table.md` §부록 "인프라 비용 매트릭스" 신설 권장 (Phase 8 sub-task로 cost-accountant 별도 위임).

### 6-1. 현재 Azure 비용 (INFRASTRUCTURE.md §9 정본 추산)

| 리소스 | 수량 | 월 비용 |
|---|---|---|
| PostgreSQL B1ms + 32GB | 2 | ~₩47,000 |
| Container Apps (min=0, 0.25vCPU, 0.5Gi) | 4 | ~₩15,000 (idle 비용 거의 0) |
| Container Registry Basic | 1 | ~₩7,000 |
| Blob Storage Standard_LRS | 1 | ~₩3,000 |
| Log Analytics 3 workspace | 3 | ~₩5,000 |
| Bandwidth | - | ~₩2,000 |
| **합계** | | **~₩73,000/월** |

### 6-2. GCP 목표 비용 (추산 — cost-accountant 정밀 검증 권장)

| 리소스 | 수량 | 추산 월 비용 | 근거 |
|---|---|---|---|
| Cloud SQL db-f1-micro (shared vCPU / 0.6GB / 10GB HDD / PITR 7일) | 2 | ~₩20,000 | GCP 공식 — db-f1-micro ~$9/월 × 2 = $18 × ₩1,474 = ~₩26,500. asia-northeast1 = 도쿄, 서울 대비 동등 |
| Cloud Run (min=0, max=1, 512Mi, 1 vCPU) | 4 | ~₩5,000 (idle) | Cloud Run 무료 quota: vCPU-sec 180,000 + 메모리-sec 360,000 + 요청 2M/월. 사용자 트래픽 0건 가정 = idle = 무료 quota 내. 트래픽 진입 시 재추산 |
| Artifact Registry (Docker storage) | 1 repo | ~₩2,000 | GCP 무료 quota 0.5GB / 그 외 $0.10/GB. Cloud Build 배포 5회 가정 = ~1GB |
| Cloud Build (빌드 min) | 4 services × 2 env | ~₩3,000 | GCP 무료 quota 120 min/일. 빌드 1회 ~5min × 8 = 40min/배포. 월 5 배포 가정 = 200min < 무료 quota = 0원 (첫 달 빌드 다회 발생 시 ~3,000원 마진) |
| Cloud Storage (Standard, asia-northeast1) | 1 bucket | ~₩2,500 | 추산 10GB Standard = $0.020/GB × 10 = $0.20 = ~₩300. 사용량 미정 시 ~₩2,500 마진 |
| Cloud SQL egress (region 내) | - | ~₩0 | 같은 region 내 통신 무료 |
| Egress (Cloudflare → 사용자) | - | ~₩0 | Cloudflare 흡수 + 사용자 트래픽 0건 가정 |
| **합계** | | **~₩32,500/월** | **Azure ₩73,000 대비 ~₩40,500 절감 (-55%)** |

### 6-3. 절감 분석

```
Azure ₩73,000 → GCP ~₩32,500 = 약 ₩40,500/월 절감 (-55%)
연간 절감: ~₩486,000

주요 절감 항목:
  ① PostgreSQL B1ms (₩47,000) → db-f1-micro (~₩20,000) = ~₩27,000 절감
  ② Container Apps (₩15,000) → Cloud Run 무료 quota (~₩5,000) = ~₩10,000 절감 (idle 흡수)
  ③ Log Analytics 3 (₩5,000) → Cloud Logging 무료 quota = ~₩5,000 절감
  ④ ACR Basic (₩7,000) → Artifact Registry (~₩2,000) = ~₩5,000 절감

증가 항목:
  ⑤ Cloud Build (~₩3,000) — Azure는 로컬 docker build = ₩0 (단 배포 자동화 가치 + 첫 달 마진)
  ⑥ Cloud Storage (~₩2,500) — Blob ₩3,000 대비 ~₩500 절감

순 절감: ~₩40,500/월 (cost-accountant 정밀 검증 권장 — Phase 8 sub-task)
```

### 6-4. cost-accountant 게이트 권장 사항 (Phase 8 sub-task)

- P1-1 직후 Cloud SQL 실측 가격 확인 → `ai-cost-table.md` §부록 박제
- Phase 2~4 직후 Cloud Run idle 비용 측정 (≥1주 후) → 정밀 추산 갱신
- Phase 6 완료 후 Cloudflare egress 측정 (Cloudflare Dashboard) → 정밀 추산 갱신
- 사용자 트래픽 진입 시점 (Polar KYC 통과 후) → cost-accountant 재계산 (Cloud Run vCPU-sec + 메모리-sec 사용량 추정)

---

## 7. env 매핑 표 — Azure secret name ↔ GCP env name (13건)

> Zenith 정합 — Cloud Run env 직접 박제 (Secret Manager 미사용, 후속 sprint 별도).
> 본 plan-draft 내 평문 출력 0건 — 모두 `<MASKED>` 또는 `***`.

| Azure secret ref | GCP Cloud Run env | env 종류 | dev 값 | prod 값 | 주의 |
|---|---|---|---|---|---|
| DATABASE_URL | DATABASE_URL | DB connection | `postgresql://grimoireadmin:<MASKED>@<Cloud SQL dev public IP>:5432/grimoire?sslmode=require` | `postgresql://grimoireadmin:<MASKED>@<Cloud SQL prod public IP>:5432/grimoire?sslmode=require` | P1-1/P1-2 Cloud SQL public IP 박제 후 갱신. Cloud SQL Auth Proxy 사용 시 socket 경로로 교체 (§9 게이트 #3) |
| JWT_SECRET | JWT_SECRET | 인증 | `<MASKED>` (Azure dev 동일 박제) | `<MASKED>` (Azure prod 동일 박제) | **세션 무효화 방지** — Azure 값과 동일하게 박제 (재발급 X) |
| ANTHROPIC_API_KEY | ANTHROPIC_API_KEY | AI | `sk-ant-<MASKED>` | `sk-ant-<MASKED>` | Anthropic console 단일 키 = dev/prod 동일 |
| POLAR_ACCESS_TOKEN | POLAR_ACCESS_TOKEN | 결제 | `polar_oat_<MASKED>` | `polar_oat_<MASKED>` | 2027-04-09 만료 (`reference_polar_setup.md` 박제) |
| POLAR_WEBHOOK_SECRET | POLAR_WEBHOOK_SECRET | 결제 | `polar_whs_<MASKED>` | `polar_whs_<MASKED>` | **변경 절대 금지** — signing 정합 (AC-5) |
| POLAR_ORGANIZATION_ID | POLAR_ORGANIZATION_ID | 결제 | `<MASKED>` | `<MASKED>` | Polar org UUID |
| POLAR_PRODUCT_STARTER | POLAR_PRODUCT_STARTER | 결제 | `<MASKED>` (Polar dev product UUID) | `<MASKED>` (Polar prod product UUID) | CC-2a 4 신 product 정합 (5/21 박제) |
| POLAR_PRODUCT_BASIC | POLAR_PRODUCT_BASIC | 결제 | `<MASKED>` | `<MASKED>` | |
| POLAR_PRODUCT_POPULAR | POLAR_PRODUCT_POPULAR | 결제 | `<MASKED>` | `<MASKED>` | |
| POLAR_PRODUCT_BEST | POLAR_PRODUCT_BEST | 결제 | `<MASKED>` | `<MASKED>` | |
| POLAR_PRODUCT_SUBSCRIPTION_PRO | POLAR_PRODUCT_SUBSCRIPTION_PRO | 결제 | `<MASKED>` (Optional, KYC 미진입 시 비어있음) | `<MASKED>` | CC-5 Polar 구독 정합 (5/22 박제) |
| POLAR_PRODUCT_SUBSCRIPTION_PREMIUM | POLAR_PRODUCT_SUBSCRIPTION_PREMIUM | 결제 | `<MASKED>` (Optional) | `<MASKED>` | |
| GOOGLE_CLIENT_ID | GOOGLE_CLIENT_ID | OAuth | `<MASKED>` | `<MASKED>` | Google OAuth Console 단일 (redirect URI는 Cloud Run URL 추가 필요 — Phase 5 후) |

### 부속 env (Cloud Run 기본값 + APP_ENV)

| env | dev | prod | 주의 |
|---|---|---|---|
| NODE_ENV | development | production | Node/Express 표준 (Cloud Run 자동 박제 X — 명시 박제) |
| APP_ENV | development | production | 코드 내 분기용 (`src/infrastructure/config/app-env.ts` 정본) |
| PORT | 3000 (server) / 3001 (web) | 동일 | Cloud Run PORT env 자동 박제 — `--port` 옵션 정합 |
| CORS_ORIGIN | https://dev.grimoire-book.com | https://grimoire-book.com | Phase 5 DNS 전환 후 정합 |
| PUBLIC_API_BASE_URL | https://dev-api.grimoire-book.com/api | https://api.grimoire-book.com/api | bakedCssUrl 절대화 (P1-#7) — Phase 5 DNS 전환 후 정합 |
| POLAR_SERVER | sandbox 또는 production | production | dev는 sandbox 정합 (KYC 진입 시 production 전환) |
| POLAR_SDK_TIMEOUT_MS | 30000 | 30000 | PAY-P3-B 정합 (`shared-contracts.md` §24) |

### Phase 4 후 교체 env (Blob → Cloud Storage)

| Azure env (제거) | GCP env (추가) | 값 |
|---|---|---|
| AZURE_STORAGE_ACCOUNT_NAME=grimoire0storage | GOOGLE_CLOUD_STORAGE_BUCKET=grimoire-blob | 정합 |
| AZURE_STORAGE_ACCOUNT_KEY=`<MASKED>` | (GCP 기본 service account 자동 인증 — env 박제 0건) | Cloud Run service account에 Storage Object Admin 권한 부여 |

---

## 8. orchestration KPI 박제 + 사용자 결정 정합

### 8-1. 책 Ch 16 Anthropic 3-에이전트 패턴 (sprint-progress 정합)

```
Initializer (grimoire-planner)
  ↓ Sprint 계약 + sprint-progress.md 생성 + plan-draft 박제 (본 파일)
Generator (grimoire-infrastructure)
  ↓ Phase 0 ~ 6 / Phase 8 단계별 수행 + sprint-progress.md 갱신
Evaluator (grimoire-qa)
  ↓ Sprint 계약 채점 + QA_REPORT.md sprint-progress 통과율 박제
메인 (메타-검증)
  ↓ Phase 0 직접 가능 (~30분) / Phase 5 Cloudflare DNS 직접 / Phase 6 curl 실측 직접
별도 sprint (≥1주 후)
  ↓ sprint-azure-decom (Phase 7) — 사용자 명시 승인 게이트
별도 sprint (후속)
  ↓ sprint-secret-manager (Zenith 정합 — env → Secret Manager 보안 강화)
```

### 8-2. 사용자 결정 단일 지시 정합

```
사용자 verbatim:
  "GCP가 Azure보다 싸 보이고, ProjectZenith가 Azure → GCP 마이그레이션 금방 됐음. 진행해."
   ↓
- 비용 비교: §6 Azure ₩73k → GCP ~₩32.5k = -55% 절감 박제 ✅
- Zenith 패턴 정합: asia-northeast1 + Cloud Run env 직접 + Cloud Build source deploy ✅
- 진행 명령: plan-draft v2 박제 (구현 X) ✅
- Blob 본 sprint 포함: 사용자 명시 Phase 4 → 포함 ✅
- 9 Phase 0~8 + 42 sub-task: 사용자 요청 ≥40 정합 ✅
- AC 8건 이상: AC-1 ~ AC-10 (10건) 정합 ✅
```

### 8-3. 메모리 박제 (Phase 8 P8-3 직후)

```
project_session_2026MMDD.md — sprint-gcp-migration Phase 0~6 종결 박제
  Initializer plan-draft v2 작성 (2026-05-27) → grimoire-infrastructure Generator Phase 0~6 단계별 수행 → 메인 curl 실측 검증 (P6-1/P6-2) → memory 1줄 인덱스
```

---

## 9. 메인 결정 게이트 (6건 — 본 plan-draft 검토 후 확정 → grimoire-infrastructure 위임)

| # | 결정 항목 | 자율 default | 대안 | 결정 시점 | 영향 |
|---|---|---|---|---|---|
| 1 | **Cloud SQL tier** (dev / prod 각각) | dev = db-f1-micro (shared vCPU / 0.6GB) / prod = db-f1-micro (사용자 KYC 통과 후 db-g1-small 즉시 전환 검토) | 즉시 db-g1-small (1.7GB) 시작 = 안정성 우선 (~+₩10,000/월) | P1-1/P1-2 진입 전 | R6 위험 / §6 비용 추정 |
| 2 | **Cloud SQL storage type** (HDD vs SSD) | HDD (저렴 ~₩9/월) — 사용자 트래픽 0건 가정 | SSD (~₩15/월) = 결제 latency 우선 | P1-1/P1-2 진입 전 | 결제 cron(10분 주기) latency / §6 비용 추정 |
| 3 | **Cloud SQL 연결 방식** (public IP + firewall vs Cloud SQL Auth Proxy vs Private IP) | public IP + firewall (Zenith 정합 = plain IP + 방화벽 규칙) | Cloud SQL Auth Proxy (IAM 인증, sidecar) / Private IP (VPC + 추가 비용) | P1-3 진입 전 + Cloud Run env DATABASE_URL 박제 시점 | 보안 / latency / Cloud Run service account IAM |
| 4 | **Cloud Run custom domain 매핑** (Cloud Run Domain Mapping vs Cloudflare 직접 CNAME) | Cloud Run Domain Mapping (Free SSL 자동 발급) — Phase 5 P5-4 | Cloudflare 직접 CNAME (Cloudflare SSL Full Strict, Cloud Run Domain Mapping 미사용 — 둘 다 가능) | Phase 5 진입 전 | SSL 인증서 관리 / propagation |
| 5 | **Phase 진입 시각** | 사용자 트래픽 0건 가정 = 평일 낮 진입 가능 (운영 진입 전 마이그레이션 완료 = 사용자 가정) | KYC 통과 후 또는 PAY-S3 prod 배포 (`PAYMENT_BACKLOG_AUDIT_20260523.md` Tier 1) 후 진입 | Phase 0 진입 직전 | Polar KYC 일정 / PAY-S3 배포 일정 동기화 |
| 6 | **Phase 7 (sprint-azure-decom) 진입 시점** | 본 sprint Phase 6 검증 ≥1주 후 = 2026-06-03 이후 권장 + 사용자 명시 승인 게이트 | 즉시 진입 (≥1주 미준수) — 비용 절감 가속이나 롤백 안전망 X | Phase 6 완료 후 ≥1주 | R1/R5 잔존 위험 / 비용 절감 가속 |

### 9-1. 부속 결정 (자율 진행 가능 — 메인 확정 0건)

| # | 항목 | 결정 | 근거 |
|---|---|---|---|
| 7 | DB 마이그레이션 방법 (P1-5) | `pg_restore --host=<Cloud SQL public IP>` 직접 (Cloud SQL Auth Proxy 미사용 시) | 사용자 트래픽 0건 + 단순화 / Cloud SQL Auth Proxy는 게이트 #3 종속 |
| 8 | Polar webhook test event 발송 시점 (P6-3) | Phase 5 직후 즉시 (P5-3 prod CNAME 갱신 후 5분 이내) | Polar auto-disable 차단 (24h retry policy 안전망) |
| 9 | sensor 신설 vs 기존 활용 (P8-2) | 기존 sensor-deploy-health 분기 추가 (Azure → GCP) — 신 sensor-gcp-deploy-health 미신설 (Zenith 정합) | 단순화 / 후속 sprint에서 GCP 전용 sensor 분리 |
| 10 | scripts/deploy-*.sh 재작성 vs Makefile target만 (P8-1) | Makefile target 우선 재작성 (`make deploy-dev` → gcloud run deploy --source .) + scripts/ 보조 | `feedback_manual_deploy_primary.md` 정합 |

---

## 10. 참조 + 후속 sprint

### 10-1. 참조

- `grimoire-server/INFRASTRUCTURE.md` §1~§9 — 현재 Azure 인벤토리 + 비용 매트릭스 (정본)
- `grimoire-server/docs/environments.md` — 13건 env 항목 정본
- `.claude/shared-contracts.md` §12 (PaymentReconciliation cron) + §17 (PartialRefund) + §18 (WebhookDLQ) + §21 (InfraMutationGuard) + §22 (PaymentRaceCondition) + §27 (CircuitBreakerPolicy) — Cloud Run 로그 검증 매트릭스
- `reports/PAYMENT_BACKLOG_AUDIT_20260523.md` — 결제 백로그 Tier 1/2/3 분류 (본 sprint 진입 전·후 GCP 진입 결정 박제 정합)
- `~/.claude/projects/.../memory/feedback_manual_deploy_primary.md` — GitHub Actions 자동배포 차단 (gcloud CLI 직접 — Phase 8 갱신 대상)
- `~/.claude/projects/.../memory/feedback_azure_single_rg.md` — Azure 단일 리소스 그룹 정합 (Phase 7 회수 단순화)
- `~/.claude/projects/.../memory/feedback_chrome_verify.md` + `feedback_fullcheck_method.md` + `feedback_playwright_verify.md` — 메인 curl 실측 정본
- `~/.claude/projects/.../memory/reference_polar_setup.md` — Polar 3환경 webhook + token 만료 (2027-04-09) 박제 + Polar webhook URL 보존 정책
- (구) `.claude/state/sprint-gcp-migration-plan-draft.md` v1 (2026-05-26 작성, asia-northeast3 서울 기준 32 sub-task) — v2 전면 갱신 사유 박제 (사용자 새 결정 정합)
- (예정) `reports/sprint-gcp-migration-progress.md` — Generator(infrastructure) Phase별 갱신
- (예정) `.claude/state/sprint-azure-decom-plan-draft.md` — Phase 6 검증 ≥1주 후 후속 sprint
- (예정) `.claude/state/sprint-secret-manager-plan-draft.md` — Zenith 정합 후속 sprint (env → Secret Manager 보안 강화)

### 10-2. 후속 sprint (Phase 7 + 추가)

| sprint | 진입 조건 | 우선순위 | 추정 시간 |
|---|---|---|---|
| sprint-azure-decom (Phase 7) | 본 sprint Phase 6 검증 ≥1주 + 사용자 명시 승인 | [SHOULD] | ~2h + ≥1주 모니터링 |
| sprint-secret-manager | 본 sprint 완료 + 다인 GCP IAM 진입 시 | [NICE] | ~4h (16 secret × 2 env 박제 + Cloud Run service account IAM 부여 + AC 검증) |
| sprint-gcp-sensor-suite | Phase 8 P8-2 후속 | [NICE] | ~3h (sensor-gcp-deploy-health 신설 + sensor-gcp-env 신설 + sensor-cloud-sql-pitr 신설) |
| sprint-db-sync-nightly-rebuild | Phase 7 후 | [SHOULD] | ~2h (DB Sync Nightly workflow grimoireadmin credentials 재발급 + Cloud SQL public IP 정합 + GCS 백업 정책) |

---

## FINAL_REMINDER (이중 앵커 하단)

- [MUST] prod 미터치 보존 — Azure 리소스 ≥1주 유지 후 사용자 명시 승인 후 정리 (Phase 7 별도 sprint)
- [MUST] Polar webhook URL = `api.grimoire-book.com/payments/webhook` 그대로 (Cloudflare CNAME만 갱신) — Polar 입장 변경 0건
- [MUST] secret 평문 박제 정책 정합 (Zenith 정합 — Secret Manager 미사용, 후속 sprint 별도) — 본 plan-draft 내 평문 출력 0건
- [MUST] DB row count 정합 검증 25+ table 전건 (AC-2 검증)
- [MUST] Blob 객체 count + 샘플 size 정합 (AC-4 검증)
- [MUST] 결제 도메인 sensor 5종 회귀 0건 (AC-6 — Azure 박제 정합)
- [MUST] §0 cost-accountant 게이트 — LLM 호출 0건이지만 인프라 비용 매트릭스(§6) 박제 + ai-cost-table.md 부록 신설 권장 (Phase 8 sub-task)
- [MUST] 사용자 단일 지시 "GCP가 싸 보이고 Zenith 정합" → plan-draft v2 42 sub-task 전건 반영 ✅
- [MUST] 메인 결정 6건 (§9) 확정 후 grimoire-infrastructure 위임
- [MUST] 작가 본문 인용/로깅 0건 / ACCOUNTS.md 참조 0건 / Git 커밋 0건 (planner 권한 X — 본 plan-draft만 박제)

---

## SELF_VERIFICATION (Chain-of-Verification)

본 plan-draft v2 출력 전 자문:
1. [MUST] 항목 누락? → 9개 [MUST] CRITICAL_CONSTRAINTS + 10건 AC + 7건 위험 + 13건 env 매핑 + 6건 메인 게이트 박제 ✅
2. cost-accountant 사전 승인 필요 플래그? → LLM 호출 0건이라 §0 면제 / 인프라 비용 §6 박제 + Phase 8 P8-1 cost-accountant 위임 권장 박제 ✅
3. visual-canon-keeper 사전 검수 필요 플래그? → 새 UI 컴포넌트 0건 (인프라 sprint) — VCK 검수 무관 ✅
4. PLANNING_GRIMOIRE.md 직접 수정? → 0건 (본 plan-draft = `.claude/state/` 박제 — 사용자 권고 형식) ✅
5. 사용자 verbatim 정합? → 9 Phase + 42 sub-task + AC 10건 + asia-northeast1 + Cloud Run env 직접 + Blob 본 sprint 포함 ✅
6. grimoire-infrastructure 위임 시 본 plan-draft만 읽고 작업 가능? → Phase별 sub-task ID + 실행 명령 + 검증 게이트 + 위험 mitigation + 롤백 절차 + env 매핑 + 메인 결정 게이트 박제 ✅
7. 트래픽 0건 가정 박제? → §1-4 + §5-1 R3/R7 + §5-2 Tier 1~5 박제 ✅
8. shared-contracts §13~§30 회귀 0 명시? → §5 R7 + AC-6 sensor 5종 회귀 0 박제 + §10 참조 정합 ✅
