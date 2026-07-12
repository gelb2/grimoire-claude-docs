# Azure 완전 Decommission 결정성 감사 (READ-ONLY)

- **일시**: 2026-06-04
- **수행**: grimoire-infrastructure agent (READ-ONLY, 변경/삭제 0)
- **배경**: 2026-05-27 GCP 마이그레이션 완료. "잔여 Phase 7 Azure 정리 1건 (≥1주 운영 박제 후)" → ~1주+ 경과. 사용자 질의 "Azure 완전히 내리고 삭제해도 무방한지".
- **방법**: 전 항목 실측 (CLI raw 인용). 추정 0. 직접 SELECT 비교가 read-only 제약에 막힌 항목은 "미검증"으로 정직 명시.

---

## 판정: **조건부 GO** (선결 1건 + 권고 잔여)

GCP는 prod/dev 전 도메인을 **단독 서빙** (DNS·HTTP·DB·Storage·Secret 전수 GCP 확정, 런타임 Azure 의존 0건). Azure는 트래픽 0 상태로 병행 잔존 = 즉시 삭제 가능 상태에 **사실상 도달**.

단 **read-only 감사 경계상 1개 항목(Azure Postgres 내부 데이터 직접 비교)이 미검증**으로 남음. 이 건은 위험도가 낮으나(아래 근거), "삭제 전 최종 덤프 1회 + 1줄 SELECT 비교"라는 값싼 선결 단계로 100% 봉합 가능. 그 단계를 GO의 전제로 둔다.

**즉 — 무방하다. 단 삭제 직전에 ① Azure DB 최종 pg_dump 보관 ② dump의 핵심 row count가 현 GCP와 일치하는지 1회 대조, 두 가지만 거치면 롤백 불가 리스크 0.**

---

## A. Azure 접근·잔존 자원 (raw)

### 인증 — 접근 가능
```
az account show:
  user: rainmaker8492@gmail.com  state: Enabled
  subscription: 59fac0d7-aab6-4bc6-b495-9b63ab42a9aa  ("Azure subscription 1")
```
→ Azure 접근 정상. (접근 불가 = NO-GO 사유였으나 해당 없음)

### 잔존 자원 — `zenith-rg` (koreacentral) 단일 RG, 전부 `Succeeded`
| 자원 | 이름 | 상태 |
|---|---|---|
| Container App × 4 | grimoire-{server,web}-{dev,prod} | **Running** (minReplicas=0 scale-to-zero) |
| Managed Environment | zenith-env-dev | Succeeded |
| Managed Certificate × 6 | mc-zenith-env-dev-* (grimoire/api/dev/dev-api + **inhouse 2건 stale**) | Succeeded |
| ACR | grimoireacr | grimoire-server(24 tags)/grimoire-web(30 tags) |
| Postgres Flexible × 2 | grimoire-db-{dev,prod} | **Ready** (Standard_B1ms Burstable, 32GB, PG16) |
| Storage | grimoire0storage | 컨테이너 `themes` 1개 / blob `deerdevil.css` 631B 1건 |
| Log Analytics × 3 | workspace-zenithrggan5 / grimoirergaS1b / grimoirerglw7l | Succeeded |

**과금**: 다른 RG·다른 구독 **없음** (`az group list` = zenith-rg 1건). Container App scale-to-zero(유휴 0과금) + Postgres B1ms × 2(상시 과금) + Storage(미미) + ACR Basic + LA workspace.
- ⚠️ **실 과금액 미검증**: `az consumption usage list`가 cost=None 반환 (preview 명령, billing scope 권한 미흡). **메모리 5/27 cost-accountant 박제 = Azure ~₩73,000/월 (~$49)** 참조. 주 비용원 = Postgres B1ms × 2 (상시) + LA workspace 3종. Container App은 유휴라 거의 0.

---

## B. GCP 단독 서빙 검증 (health 200 넘어 실서빙 경로 — 전수 GCP 확정)

### Cloud Run — 4 서비스 전부 Ready + traffic 100% latestRevision
```
gcloud run services list (asia-northeast1):
  ✔ grimoire-server-prod  rev 00005-kh7  traffic 100%  Ready/RoutesReady=True
  ✔ grimoire-server-dev   rev 00005-9f4  traffic 100%  Ready/RoutesReady=True
  ✔ grimoire-web-prod     rev 00002-qtc  traffic 100%  Ready/RoutesReady=True
  ✔ grimoire-web-dev      rev 00002-7wg  traffic 100%  Ready/RoutesReady=True
```
(revision = 메모리 5/27 박제와 동일 = 그 이후 재배포 0)

### Cloud SQL — prod/dev = ne1 정본, Cloud Run이 ne1만 연결
```
gcloud sql instances list (project grimoire-491708):
  grimoire-db-prod   asia-northeast1-a  RUNNABLE  35.194.102.178   ← 정본 (5/27 IP 일치)
  grimoire-db-dev    asia-northeast1-a  RUNNABLE  104.198.117.103  ← 정본 (5/27 IP 일치)
  grimoire-pg-prod   asia-northeast3-a  RUNNABLE  34.64.168.150    ← GCP 레거시 (문서외, Azure 무관)
  grimoire-pg-dev    asia-northeast3-a  RUNNABLE  34.64.162.34     ← GCP 레거시 (문서외, Azure 무관)

Cloud Run cloudsql-instances annotation:
  server-prod → grimoire-491708:asia-northeast1:grimoire-db-prod
  server-dev  → grimoire-491708:asia-northeast1:grimoire-db-dev

DATABASE_URL secret value (host only, pw redacted):
  prod: postgresql://[USER]:[REDACTED]@localhost/grimoire?host=/cloudsql/grimoire-491708:asia-northeast1:grimoire-db-prod
  dev:  ...host=/cloudsql/grimoire-491708:asia-northeast1:grimoire-db-dev
```
→ DB = GCP Cloud SQL ne1 **완전 전환**. Azure Postgres 연결문자열 0건. **ne3 `grimoire-pg-*` 잔존은 Cloud Run 어디에도 연결 안 됨 = GCP 내 별개 정리 후보 (Azure decommission 범위 밖, 혼동 주의)**.

### GCP row count = 5/27 박제와 정합
```
GCP Cloud SQL prod (via Auth Proxy):
  authors=13  themes=20  works=50  episodes=109  payments=4
  credit_ledgers=15  subscriptions=33  membership_plans=13  admin_audit_logs=3  refresh_tokens=53
  (최신 created_at = 2026-05-21, CC prod 배포 시점)
GCP Cloud SQL dev:
  authors=13(5/27 12→13, +1 정상 dev 작업)  themes=20  works=50  episodes=109  payments=4  subscriptions=33
```
→ 5/27 마이그레이션 박제와 일치. dev authors +1 = 5/27 이후 **GCP에서** 발생한 정상 증가 (현 dev DNS=GCP). 즉 GCP가 최신본.

### GCS — Blob 이전 완료 + 라이브 서빙
```
gs://grimoire-blob-{prod,dev}/themes/deerdevil.css  631 bytes (2026-05-27 04:21 복사)
public URL HTTP 200 / 631 bytes (prod + dev)
```
→ Azure Blob(`themes/deerdevil.css` 631B 1건)과 1:1 일치. GCS 서빙 정상.

---

## C. Azure 의존성 잔존 스윕

### DNS (Cloudflare) — Azure 가리키는 레코드 0건 ✅
```
grimoire-book.com (apex)  → A 216.239.3{2,4,6,8}.21 + AAAA 2001:4860:4802::15 (Cloud Run apex)
api.grimoire-book.com     → CNAME ghs.googlehosted.com
dev.grimoire-book.com     → CNAME ghs.googlehosted.com
dev-api.grimoire-book.com → CNAME ghs.googlehosted.com
azurecontainerapps 매치: 0건 (4도메인 전수)
inhouse.* / inhouse-api.* : 미해소 (이미 정리됨)
```

### HTTP 실 origin — 4도메인 전부 Google Frontend ✅
```
curl -I 4도메인:
  grimoire-book.com/ → 307 / server: Google Frontend / x-cloud-trace-context ✓
  api.grimoire-book.com/api/health → 200 / Google Frontend ✓
  dev.grimoire-book.com/ → 307 / Google Frontend ✓
  dev-api.grimoire-book.com/api/health → 200 / Google Frontend ✓
Azure 헤더(x-azure/x-ms-): 0건
Cloud Run domain-mappings × 4: 전부 ✔ Ready
```

### Polar webhook — GCP 경유 ✅
```
우리측 PUBLIC_API_BASE_URL(prod) = https://api.grimoire-book.com/api → GCP
```
→ webhook URL `api.grimoire-book.com` 보존 (origin만 Azure→GCP 교체, 5/27 박제). Polar dashboard 측 설정은 우리 인프라 밖이나 **URL 무변경 = Azure 삭제해도 webhook auto-disable 위험 0**.

### GCP Cloud Run env/secret — 런타임 Azure host/URL 0건 ✅
```
prod Cloud Run env full-value scan (azurecontainerapps|blob.core.windows|postgres.database.azure|azurecr.io): 0건
유일 Azure 흔적:
  AZURE_STORAGE_ACCOUNT_NAME = grimoire0storage  (계정명, host 아님)
  AZURE_STORAGE_ACCOUNT_KEY  → secretRef azure-storage-account-key-{prod,dev}-an1
→ 둘 다 DEAD ENV (아래 코드 근거)
DATABASE_URL secret = Cloud SQL socket (Azure 아님, B항 확인)
```

### 코드 — Azure adapter는 DI 대체된 DEAD CODE ✅
```
app.module.ts:219  { provide: 'BlobStoragePort', useClass: GcsStorageService }
gcs-storage.service.ts:34  this.bucketName = process.env.GCS_BUCKET  ← GCS_BUCKET만 읽음
blob-storage.service.ts  (Azure 구현, AZURE_STORAGE_* 읽음) = provider 등록 0 = inject 0 = dead
package.json: @azure/storage-blob ^12.31.0 (미사용 의존성 잔존)
ip-extractor.ts:5  주석에 "Azure App Service" 언급 (무해)
```
→ Azure storage env가 살아있어도 **코드 경로에서 읽히지 않음** = 런타임 의존 0. (정리 권고: blob-storage.service.ts + @azure/storage-blob 제거 — 비차단)

### 문서/CI — 비활성 또는 격리됨 (비차단)
```
활성 workflow: ci.yml / db-sync-nightly.yml(5/27 GCP 재작성) = Azure 참조 0
deploy-*.yml.disabled (server+web) = Azure 참조 보유하나 .disabled (영구 비활성, INFRA 정책)
DEPLOY.md / INFRASTRUCTURE.md = Azure 참조 (INFRASTRUCTURE §12 "Azure 잔존 격리"로 의도 문서화)
grimoire-server/CLAUDE.md §4 기술스택 표 = stale ("PostgreSQL (Azure Database)"/"Docker (Azure Container Apps)")
```
→ 런타임 의존 0. decommission **후** 문서 갱신 권고 (비차단).

---

## D. 삭제 안전성

### D-1. Azure Postgres에 GCP에 없는 데이터가 있나? — **미검증 (낮은 위험)**

**직접 SELECT 비교 불가**: Azure Postgres SELECT는 firewall rule 임시 추가(=네트워크 설정 변경)가 선행돼야 하는데, 본 감사는 사용자 명시 "절대 삭제·변경 0" 경계라 정책 분류기가 firewall 생성을 차단 (정당). 따라서 Azure DB 내부 row 직접 대조는 **수행 못함 = 미검증**.

**간접 정황 (변경 0 메트릭으로 수집)**:
```
Azure Container App server-{prod,dev} DATABASE_URL secret → grimoire-db-{prod,dev}.postgres.database.azure.com (= Azure DB)
Azure 앱은 Running(scale-to-zero)이고 DATABASE_URL이 Azure DB를 가리킴
→ Azure 앱이 깨어나면 Azure DB에 write 가능 (이론상 데이터 분기 경로 존재)

Azure prod DB write_throughput (5/27~6/4): ~88MB/day baseline (autovacuum/WAL/checkpoint 수준)
Azure prod DB active_connections: min 6 / max 9~12 (상시 baseline, 0으로 안 떨어짐 = DB측 백그라운드 connection 추정)
Azure App 시스템 로그: 6/4 05:11 KEDAScaleTargetDeactivated 1→0 + ManuallyStopped
  (감사 중 본인이 Azure FQDN 직접 curl한 것이 cold start 유발 가능 — 시각 근접)
```

**위험 평가 = 낮음**:
- DNS·Polar·도메인 트래픽이 전부 GCP라 **정상 경로로는 Azure 앱에 도달 0** → Azure DB에 신규 write 유입 경로 사실상 없음.
- write_throughput baseline + 상시 connection은 애플리케이션 트래픽이 아니라 **유휴 PG 백그라운드(autovacuum/WAL) + 모니터링 connection** 패턴 (min이 0이 아니라 6 고정).
- 단 **Azure FQDN 직접 호출 시 200 응답** = 누군가 FQDN을 직접 치면 Azure 앱이 깨어나 Azure DB write 가능 (트래픽 0 가정 하에 무시 가능하나 0이라 단정 불가 = 미검증).

⚠️ **메트릭 시계열 신뢰성 한계**: `az monitor metrics list`가 본 환경에서 다중 버킷 분해 실패(단일 데이터포인트만 반환) — 시간대별 connection=0 구간 존재 여부를 정밀 확정 못함. 이 또한 D-1 미검증의 일부.

→ **봉합법**: 삭제 직전 firewall 임시 추가(사용자 승인 후 별도 위임) → Azure DB 최종 pg_dump + 핵심 row count 1회 대조. GCP와 일치하면 위험 0 확정.

### D-2. 롤백 불가 지점
- **Azure ACR 삭제** = grimoire-server(24)/grimoire-web(30) 이미지 영구 소실. 단 **현 라이브 이미지는 GCP Artifact Registry `cloud-run-source-deploy`(879MB)에 있음** → Azure로의 롤백만 불가, GCP 운영엔 영향 0.
- **Azure Postgres 삭제** = 5/27 컷오버 snapshot + 그 이후 (있다면) Azure-only write 영구 소실. → D-1 덤프로 봉합.
- **Storage 삭제** = `deerdevil.css` 631B (GCS에 동본 존재, 손실 0).

---

## GO 시 안전 Teardown 계획 (사용자 승인 후 별도 위임 + verifier 재실측 전제)

### 선결 (GO 전제, 값싼 봉합)
1. firewall 임시 rule 추가(timestamp suffix) → **Azure DB 최종 `pg_dump`** (dev+prod) 로컬/GCS 보관 (보관 ≥30일 권고) → firewall 즉시 정리.
2. dump의 핵심 13모델 row count를 현 GCP와 1회 대조 → 일치 확인 (D-1 봉합).

### 삭제 순서 (의존 역순)
1. **Container App × 4** 먼저 (Azure DB로의 유일한 write 경로 차단 — 이 시점부터 Azure DB write 유입 0 확정)
2. **Managed Environment** zenith-env-dev (+ managed cert 6건 동반 소멸)
3. **Postgres Flexible × 2** (덤프 보관 확인 후)
4. **Storage** grimoire0storage
5. **ACR** grimoireacr
6. **Log Analytics workspace × 3**
7. **RG `zenith-rg` 삭제** (잔존 일괄 — 최종)

### 보존할 것
- Azure DB 최종 덤프 (≥30일).
- Polar webhook URL은 GCP라 **무조치** (건드리지 말 것 — auto-disable 위험).
- GCP 측은 일절 미터치.

### 롤백 불가 명시
- ACR 삭제 후 Azure 롤백 불가 (GCP 운영 무영향).
- Postgres/Storage 삭제 후 Azure-only 데이터 복구는 덤프로만 가능.

---

## 별개 정리 후보 (Azure 무관, GCP 내부 — 혼동 주의)
- **ne3 Cloud SQL `grimoire-pg-{prod,dev}`** (문서외, Cloud Run 미연결) — GCP 정리 후보.
- **Secret Manager ne3 9건** (`*-dev`/`*-prod` 5/26 생성, an1으로 대체됨) — GCP 정리 후보.
- **GCP Artifact Registry `grimoire-docker`** (0 items, 미사용) — GCP 정리 후보.
- gcloud 기본 config 오정합 (`pr-letter-addr`/ne3) — ops 오발 위험, `--project grimoire-491708` 명시로 무영향.

→ 위 4건은 본 Azure 감사 범위 밖. 사용자 결정 시 별도 처리.

---

## 검증 못한 항목 (정직 명시)
1. **Azure DB 내부 row 직접 대조** — firewall 변경 차단으로 미수행 (D-1). 삭제 전 덤프+대조로 봉합.
2. **Azure 실 과금액** — `az consumption` cost=None (권한). 5/27 박제 ~₩73k/월 참조.
3. **Azure DB 시간대별 connection=0 구간** — 메트릭 다중버킷 분해 실패로 정밀 미확정.

위 3건 모두 **추정으로 GO 처리 안 함**. 1·3은 위험 낮음(정황상 idle)이나, 삭제 직전 덤프 1회로 확정 봉합 가능하므로 "조건부 GO"의 조건으로 둠.

---

# Step 1 — 데이터 안전 (최종 덤프 + row 대조) — **PASS** (2026-06-04, grimoire-infrastructure agent)

- **수행**: 사용자 안전 decommission 승인 후. **Azure 리소스 삭제 0 / dump 삭제 0** (덤프+대조만).
- **목적**: 위 D-1 (firewall 차단으로 미검증) 봉합 — "Azure DB에 GCP에 없는, 잃어선 안 될 신규 데이터"가 없음을 실측 확정.
- **결론**: **데이터 안전. 삭제 게이트 통과 가능.** Azure DB 2개 최종 dump GCS 영속 보관 + 13모델 대조 완료. Azure-only 신규 write 0건 확정.

## S1-A. 임시 firewall rule 생성/삭제 timestamp + 잔존 0

| rule | server | 생성 (UTC) | 삭제 (UTC) | 용도 |
|---|---|---|---|---|
| `tmp-decom-20260604T065959Z` | grimoire-db-prod | 2026-06-04T07:01:01Z | 2026-06-04T07:13:41Z | prod 측정+dump |
| `tmp-decom-20260604T070701Z` | grimoire-db-dev | 2026-06-04T07:08:03Z | 2026-06-04T07:13:41Z | dev 측정+dump |
| `tmp-decom-20260604T072341Z` | grimoire-db-dev | 2026-06-04T07:23:41Z | 2026-06-04T07:31:45Z | dev 불일치 규명 (재진입) |

- IP = `221.150.30.109` (5/27 동일). 모든 rule = timestamp suffix 명명, 사용 후 즉시 삭제.
- **최종 잔존 0 직접 확인** (`firewall-rule list`): 양 서버 모두 `AllowAzureServices` (baseline, 0.0.0.0) **1건만** — `tmp-decom` 0건. orphan 0.
- 자격증명: `az containerapp secret show database-url` → bash 변수(`PGPASSWORD`)로만 전달. **비밀번호 디스크/로그 기록 0** (host+db만 박제, pw는 `[REDACTED len=N]`).

## S1-B. 최종 pg_dump 2건 — GCS 영속 보관 (≥30일 충족)

저장처: `gs://grimoire-491708-db-migration/azure-final/` (5/26 컷오버 dump와 `azure-final/` prefix로 구분). 버킷 **lifecycle 자동삭제 정책 0** = 무기한 보관 (≥30일 충족). 형식 = plain SQL gzip (`pg_dump --no-owner --no-acl | gzip`, PG16.13).

| env | GCS 경로 | 크기 (bytes) | sha256 (로컬) | MD5 무결성 |
|---|---|---|---|---|
| prod | `azure-final/azure-prod-final-20260604T065959Z.sql.gz` | 4,883,398 (4.65MB) | `cbcab078dd81486ffd4cb930c2ec42198e85cbb725190d69e8ab8229201394f7` | local=GCS ✓ |
| dev | `azure-final/azure-dev-final-20260604T070701Z.sql.gz` | 4,878,868 (4.65MB) | `c75fbe8c874a1308528e93ca4eb7d4ca7e6eb872d9de808acba3c887ed138c9b` | local=GCS ✓ |

- 무결성: 양 dump `gzip -t` OK + `PostgreSQL database dump complete` 완결 표식 + GCS 업로드본 MD5 = 로컬 MD5 (비트 동일).
- 구조 sanity: prod CREATE TABLE 34=COPY 34 / dev 40=40. (5/27 박제 "prod 27 / dev 30 tables"보다 많음 = 5/27 이후 prod/dev에 적용된 CC·PAY·EMAIL 마이그레이션 누적 = 데이터 손실 아님.)
- 로컬 임시 사본은 GCS 보관 확정 후 정리 (repo 밖 `~/azure-final-dumps`, 디스크 정리, GCS 영속본만 잔존).

## S1-C. 13 핵심 모델 row count 대조 (Azure DB 실측 vs GCP Cloud SQL ne1 실측)

### PROD — **전건 일치 (13/13)** ✅
| 모델 | Azure prod | GCP prod (ne1) | 일치 |
|---|---|---|---|
| authors | 13 | 13 | ✓ |
| themes | 20 | 20 | ✓ |
| works | 50 | 50 | ✓ |
| episodes | 109 | 109 | ✓ |
| payments | 4 | 4 | ✓ |
| credit_ledgers | 15 | 15 | ✓ |
| subscriptions | 33 | 33 | ✓ |
| membership_plans | 13 | 13 | ✓ |
| admin_audit_logs | 3 | 3 | ✓ |
| refresh_tokens | 53 | 53 | ✓ |
| webhook_events | 0 | 0 | ✓ |
| refund_logs | 0 | 0 | ✓ |
| reconciliation_checkpoints | 1 | 1 | ✓ |

→ prod는 Azure = GCP **완전 일치**. dump COPY 행 수도 DB 실측과 일치 (authors=13/payments=4/credit_ledgers=15/subscriptions=33/episodes=109 교차검증).

### DEV — 10/13 일치 + 3개 모델 Azure>GCP (조사 완료, **NO-GO 아님**)
| 모델 | Azure dev | GCP dev (ne1) | 판정 |
|---|---|---|---|
| authors | 12 | **13** | GCP +1 (5/27 이후 GCP에서 정상 증가, GCP가 최신) |
| themes / works / episodes / payments / subscriptions / reconciliation_checkpoints | 20/50/109/4/33/1 | 동일 | ✓ |
| admin_audit_logs / webhook_events / refund_logs | 0/0/0 | 동일 | ✓ |
| **credit_ledgers** | **14** | **0** | Azure>GCP — DB Sync Nightly가 dev에서 비움 (정상) |
| **membership_plans** | **12** | **0** | Azure>GCP — 동상 |
| **refresh_tokens** | **24** | **0** | Azure>GCP — 동상 (전건 expired 세션토큰) |

**3개 모델 Azure>GCP 차이 = NO-GO 사유 아님. 조사로 완전 규명**:
1. **전부 5/27 컷오버 이전 생성** — credit_ledgers/membership_plans 14·12건 = created_at 일괄 `2026-05-21 05:41:35` (CC 개편 마이그레이션 seed: reason=`denomination_migration_v6`/`subscription_pool_migration_v6`). refresh_tokens 24건 = `2026-04-16~05-16`, **valid=0/expired=24** (전부 만료 세션토큰). → **Azure-only 신규 write 0건** (컷오버 후 생성 0).
2. **GCP에서 사라진 원인 = DB Sync Nightly 정상 동작** — `grimoire-server/scripts/db-sync.ts` L243 `creditLedger.deleteMany()` / L244 `membershipPlan.deleteMany()` / L250 `refreshToken.deleteMany()`. prod→dev sync가 dev를 비운 뒤 prod 데이터로 채우는데, 이 3개(seed성/PII 세션)는 재삽입 대상에서 제외 = dev에서 0. 5/27 sync run #26497023775 success 시점에 비워짐. **데이터 사고 아님, 의도된 정책**.
3. **최종 dump에 온전히 보존** — dev dump COPY 블록 직접 추출 검증: credit_ledgers=**14** / membership_plans=**12** / refresh_tokens=**24** (Azure 실측과 일치). 즉 Azure 삭제해도 이 데이터는 GCS 보관 dump로 100% 복구 가능.

→ **요약: "Azure에만 있는, 잃어선 안 될 신규 데이터" = 0건.** dev의 Azure>GCP 3건은 (a) 신규 write 아님(컷오버 전 seed/만료토큰) (b) GCP에서 nightly sync가 정책대로 비운 것 (c) 그마저 최종 dump 보존. 데이터 안전 확정.

## S1-D. 종합 — **Step 1 PASS → verifier 게이트로**

- prod 13/13 일치 + dev 차이 3건 전부 규명(신규 write 0·dump 보존) = **Azure-only 잃을 데이터 0**.
- 최종 dump 2건 GCS 영속 보관 (sha256/MD5 박제, ≥30일).
- 임시 firewall rule 3개 전부 삭제, 양 서버 잔존 0 직접 확인.
- **Azure 리소스(앱/DB/스토리지/ACR/RG) 삭제 0 / dump 삭제 0** — 본 단계 변경 = firewall rule 추가/삭제(원복 완료)뿐.
- **다음**: verifier가 ① 본 Step 1 결과(dump 보관+row 대조) ② GCP 단독 서빙을 독립 재확인 → 통과 시에만 삭제 단계(Teardown 계획 §) 진입.

### Step 1에서 추가 규명된 사항 (참고)
- **D-1 봉합 완료**: readiness 본문 "검증 못한 항목 1번(Azure DB 내부 row 직접 대조)" = 본 Step 1로 실측 봉합. prod 일치 + dev 차이 규명.
- ne3 `grimoire-pg-{dev,prod}`는 본 작업에서 미접속 (Cloud Run 미연결 레거시, Azure decom 범위 밖 — readiness §"별개 정리 후보" 유지).

---

# Step 3 — 실제 삭제 (되돌릴 수 없음) — **DONE** (2026-06-04, grimoire-infrastructure agent)

- **전제 (충족)**: 사용자 안전 decommission 승인 + verifier GATE PASS(dump 무결성·데이터 보존·GCP 단독서빙 독립 확인) + Step 1 PASS(prod 13/13 일치·dev 차이 3건 규명·dump 보존).
- **결론**: **Azure `zenith-rg` 전체(18 리소스) 삭제 완료. RG 부재 확정. GCP 4도메인 무영향. GCS dump 2건 무손상.** "지웠다" 단정 대신 raw(RG 부재 + 잔존 0)로 박제.

## S3-A. 삭제 전 박제 (baseline)

```
[계정] az account show: user=rainmaker8492@gmail.com / sub=59fac0d7-... ("Azure subscription 1") / Enabled
[RG] az group show -g zenith-rg: koreacentral / Succeeded (존재)
[리소스] az resource list -g zenith-rg = 18건:
  Microsoft.App/containerApps × 4 (grimoire-{server,web}-{dev,prod})
  Microsoft.App/managedEnvironments × 1 (zenith-env-dev)
  Microsoft.App/managedEnvironments/managedCertificates × 6 (grimoire/api/dev/dev-api + inhouse 2 stale)
  Microsoft.ContainerRegistry/registries × 1 (grimoireacr)
  Microsoft.DBforPostgreSQL/flexibleServers × 2 (grimoire-db-{dev,prod})
  Microsoft.Storage/storageAccounts × 1 (grimoire0storage)
  Microsoft.OperationalInsights/workspaces × 3 (workspace-zenithrggan5 / grimoirergaS1b / grimoirerglw7l)
[GCP 4도메인 baseline] grimoire-book.com 307 / api 200 / dev 307 / dev-api 200 (전부 Google Frontend)
[GCS dump 2건] azure-prod-final 4,883,398 + azure-dev-final 4,878,868 bytes (잔존 확인)
[Storage 잔여 객체] themes 컨테이너 / deerdevil.css 631B 1건만 (GCS 동본 존재, 손실 0) — 혹시 모를 잔여 객체 없음
```

## S3-B. 단계별 삭제 raw (의존 역순 staged → RG 일괄)

| # | 단계 | 명령 | 결과 |
|---|---|---|---|
| 1 | Container App × 4 | `az containerapp delete` (server-dev/web-dev/server-prod/web-prod) | 전건 `Containerapp successfully deleted` exit 0. **이 시점부터 Azure DB write 경로 차단** |
| 2 | Managed Environment | `az containerapp env delete -n zenith-env-dev` | exit 0 (cert × 6 동반 소멸). 삭제 ~수분 소요 → 잔존 0 직접 확인 |
| 3 | Postgres Flexible × 2 | `az postgres flexible-server delete` (dev → prod) | 전건 exit 0. **삭제 직후 GCS dump 2건 비트 동일 재확인(무손상)** |
| 4 | Storage | `az storage account delete -n grimoire0storage` | exit 0 |
| 5 | ACR | `az acr delete -n grimoireacr` | exit 0 (라이브 이미지는 GCP Artifact Registry, 무영향) |
| 6 | Log Analytics × 3 | `az monitor log-analytics workspace delete --force true` × 3 | 전건 exit 0 |
| — | **RG 삭제 직전 잔존** | `az resource list -g zenith-rg` | **0건** (staged로 18→0 전부 비움) |
| 7 | **RG 일괄** | `az group delete -g zenith-rg --yes` | exit 0 (최종, 되돌릴 수 없음) |

## S3-C. 최종 검증 (raw — "지웠다" 단정 대신 부재 확인)

```
[최종-1] RG 부재:   az group show -g zenith-rg → ERROR (ResourceGroupNotFound) exit 3 ✓ 삭제 확정
[최종-2] 전체 RG:    az group list → (비어있음) ✓ 이 구독 RG = zenith-rg 하나뿐 → 잔존 0, 다른 RG 오작동 0
[최종-3] GCP 4도메인: grimoire-book.com 307 / api 200 / dev 307 / dev-api 200 (전부 Google Frontend)
                     → 삭제 전 baseline과 완전 동일 = Azure 완전 삭제가 GCP에 영향 0 실측
[최종-4] GCS dump:   azure-prod-final 4,883,398 + azure-dev-final 4,878,868 bytes ✓ 삭제 전후 비트 동일, 무손상 보존
[최종-5] GCP Cloud Run: server/web × dev/prod 4 서비스 전부 status True (ne1) — 무접촉 ✓
[최종-6] GCP Cloud SQL: ne1 정본 2(grimoire-db-{prod,dev}) + ne3 잔존 2(grimoire-pg-{prod,dev}) RUNNABLE
                       → ne3 잔존은 사용자 명시 "Azure only" 경계 준수, 손대지 않음 ✓
```

## S3-D. 종합 — **Azure decommission 완료 (Phase 7 종결)**

- Azure `zenith-rg` 18 리소스 staged 삭제(의존 역순) → RG 일괄 삭제 → **RG 부재 확정(ResourceGroupNotFound)**, 잔존 0.
- GCP 4도메인 삭제 후에도 307/200/307/200 동일 = **Azure↔GCP 독립 입증, 서빙 영향 0**.
- GCS dump 2건(`gs://grimoire-491708-db-migration/azure-final/`) 삭제 전후 비트 동일 = **롤백 안전망 무손상**.
- GCP(Cloud Run/Cloud SQL ne1·ne3/GCS/Secret Manager) **일절 미터치** — ne3 `grimoire-pg-*` 보존(사용자 경계).
- **과금 영향**: Azure 유휴 ~₩73,000/월(5/27 cost-accountant 박제, 주 비용원 = Postgres B1ms × 2 상시 + LA workspace 3종) → RG 삭제로 **0 방향**(잔존 과금 리소스 0). 실 과금 종료는 다음 billing cycle 반영.
- **다음**: verifier가 post-delete(RG 부재 + GCP 4도메인 + GCS dump 잔존)를 독립 재확인. 통과 시 메모리 5/27 "잔여 Phase 7 Azure 정리 1건" 항목 **종결** + 정본 문서(INFRASTRUCTURE §12 "Azure 잔존 격리" / DEPLOY.md / grimoire-server CLAUDE.md §4 stale 표) Azure 참조 정리 권고(비차단).
