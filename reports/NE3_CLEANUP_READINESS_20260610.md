# ne3(asia-northeast3) GCP 잔존 정리 — Step 1 readiness + 데이터 안전(dump)

- **일시**: 2026-06-10
- **수행**: grimoire-infrastructure agent
- **범위**: **assess + dump only. 이 단계 삭제 0 / dump 삭제 0 / ne1·grimoire-docker·azure-final 무접촉.**
- **배경**: 5/27 GCP 마이그레이션 = ne1(asia-northeast1) 단독 현역. ne3엔 pre-ne1 시도(5/26 생성) 잔재. Azure decommission(`AZURE_DECOMMISSION_READINESS_20260604.md`) §"별개 정리 후보"로 박제돼 있던 GCP 내부 정리 대상. 동일 안전 패턴(dump→대조→verifier 게이트→삭제) 적용.
- **방법**: 전 항목 CLI raw 실측. 추정 0. **모든 명령 `--project=grimoire-491708` 명시**(기본 config = `pr-letter-addr`/ne3 오정합, 메모리 5/30·6/1·6/4 박제 — 오발 방지).

---

## 판정: **조건부 GO** (삭제는 verifier 독립 게이트 통과 후)

ne3는 **완전 고아**(domain mapping 0 / ne1 어디서도 미참조 / 현역 트래픽 0 / 5/26 이후 write 0). ne3 데이터는 ne1·Azure 컷오버 snapshot과 동일 = ne3-only "잃으면 안 될 현역 데이터" **0건**. 최종 dump 2건 GCS 영속 보관 + 무결성 검증 완료.

**즉 — 정리해도 무방. 단 본 단계는 dump+검증까지만. 삭제는 verifier가 본 결과를 독립 재확인한 뒤 별도 단계.**

ne3-only 현역 데이터가 1건이라도 있으면 STOP이었으나 — **해당 없음**(아래 D항 실측).

---

## A. ne3 자산 enumerate (raw)

### A-1. Cloud SQL — ne3 인스턴스 2 (vs ne1 정본 2)
```
gcloud sql instances list --project=grimoire-491708:
  grimoire-db-prod   asia-northeast1  POSTGRES_16  db-f1-micro  RUNNABLE  35.194.102.178   ← ne1 정본 (현역, 무접촉)
  grimoire-db-dev    asia-northeast1  POSTGRES_16  db-f1-micro  RUNNABLE  104.198.117.103  ← ne1 정본 (현역, 무접촉)
  grimoire-pg-prod   asia-northeast3  POSTGRES_16  db-f1-micro  RUNNABLE  34.64.168.150    ← ne3 정리 대상
  grimoire-pg-dev    asia-northeast3  POSTGRES_16  db-f1-micro  RUNNABLE  34.64.162.34     ← ne3 정리 대상
```
ne3 SQL 상세: db-f1-micro / 10GB PD_HDD / ZONAL / backup=True / PITR=True / `authorizedNetworks=(none)` / ipv4Enabled=True / createTime=2026-05-26T09:27Z.
→ public IP 보유(=과금) but allowlist 비어있음(=공개망 접근 불가, Auth Proxy로만 접근).

### A-2. Cloud Run — ne3 4 서비스 (전부 rev 00001 = 1회 배포 후 방치)
```
gcloud run services list --project=grimoire-491708 --region=asia-northeast3:
  grimoire-server-prod  rev 00001-ksb  traffic 100%  status True  (created 2026-05-26T10:08Z)
  grimoire-server-dev   rev 00001-4cs  traffic 100%  status True  (created 2026-05-26T10:03Z)
  grimoire-web-prod     rev 00001-rbn  traffic 100%  status True  (created 2026-05-26T10:14Z)
  grimoire-web-dev      rev 00001-tzp  traffic 100%  status True  (created 2026-05-26T10:12Z)
revision count 각 서비스 = 1 (00001만, 재배포 0)
```
대조 — ne1 정본(현역): server-prod **rev 00006** / server-dev **rev 00006** / web 00002.
→ ne3는 00001에서 멈춤 = 5/26 1회 배포 후 ne1으로 컷오버하며 방치된 abandoned 시도.

ne3 server cloudsql 연결: `grimoire-491708:asia-northeast3:grimoire-pg-{prod,dev}` (ne3 SQL을 가리킴, ne1 아님).
ne3 web cloudsql: (none).
ne3 server secret refs: 8건 ne3 시크릿(`database-url-{env}`/`jwt-secret-{env}`/`recaptcha-secret-key-{env}`/`anthropic-api-key-{env}`/`openai-api-key-{env}`/`polar-access-token-{env}`/`polar-webhook-secret-{env}`/`azure-storage-account-key-{env}`).

### A-3. Secret Manager — ne3 패턴 18건 (an1 suffix 없는 것 전부)
```
gcloud secrets list --project=grimoire-491708 → asia-northeast3 location, 전부 2026-05-26 생성:
  anthropic-api-key-{dev,prod}        azure-storage-account-key-{dev,prod}
  database-url-{dev,prod}             db-password-{dev,prod}
  jwt-secret-{dev,prod}               openai-api-key-{dev,prod}
  polar-access-token-{dev,prod}       polar-webhook-secret-{dev,prod}
  recaptcha-secret-key-{dev,prod}
= 18건 (9종 × dev/prod)
```
※ readiness 추정치 "~9건"은 **18건이 정확**(9종 × 2env). ne1 현역은 별도 `*-an1` 19건(`database-url-authproxy-{env}-an1` + `resend-*-an1`/`sendgrid-*-an1` 포함, 5/27~ 생성) — 무접촉.

### A-4. Artifact Registry — ne3 `cloud-run-source-deploy` (ne3 Cloud Run 이미지 저장)
```
gcloud artifacts repositories list --project=grimoire-491708 (location 명시):
  cloud-run-source-deploy  location=asia-northeast1  created 2026-05-27  ← ne1 빌드 (정본 관련, 무접촉)
  grimoire-docker          location=asia-northeast1  created 2026-05-27  ← 🔴 보존 (deploy 타깃, 무접촉)
  cloud-run-source-deploy  location=asia-northeast3  created 2026-05-26  ← ne3 정리 대상 (ne3 이미지 보유)
```
→ `cloud-run-source-deploy`는 **region 2개**에 동명. ne3(an3) 것만 정리 대상. ne1(an1) 2건은 무접촉.

### A-5. 기타 ne3 참조 — 0
```
Cloud Scheduler API = 미활성 (project 전체) → ne3 scheduler job 0. (DB Sync Nightly는 GitHub Actions 경유, 5/27 박제와 정합)
```

---

## B. 고아 확정 (domain mapping 0 + ne1 canonical 재확인)

### B-1. domain mapping — ne3 = **0건** (고아 핵심 증거)
```
gcloud beta run domain-mappings list --project=grimoire-491708 --region=asia-northeast3:
  Listed 0 items.   ← ne3 Cloud Run에 도메인 라우팅 0

gcloud beta run domain-mappings list --project=grimoire-491708 --region=asia-northeast1:
  api.grimoire-book.com      → grimoire-server-prod  True
  dev-api.grimoire-book.com  → grimoire-server-dev   True
  dev.grimoire-book.com      → grimoire-web-dev       True
  grimoire-book.com          → grimoire-web-prod      True   ← 4 도메인 전부 ne1
```
→ **현역 4 도메인 = 전부 ne1. ne3엔 도메인 0** = ne3는 정상 경로로 도달 불가.

### B-2. ne1 Cloud Run이 ne3 시크릿을 참조하나? — **0건**
```
ne1 server-prod secret refs: anthropic/database-url-authproxy/jwt/openai/polar-access/polar-webhook/recaptcha/resend/sendgrid — 전부 *-an1
ne1 server-dev  secret refs: 동상 *-an1
ne1 web-{prod,dev}: (none)
→ ne1 현역은 *-an1 시크릿만 참조. ne3 18 시크릿 참조 0건 = ne3 시크릿 완전 고아.
```

### B-3. ne3 run.app 직접 호출 시 응답하나? (도메인 없어도 URL은 살아있음)
```
curl ne3 server-prod run.app/api/health → HTTP 200 (TIME 11.7s, Google Frontend) ← cold start(scale-to-zero에서 깨어남)
curl ne3 server-dev  run.app/api/health → HTTP 200 (TIME 14.6s, Google Frontend)
```
→ run.app URL을 **직접** 치면 응답(Azure와 동일 패턴). 단 **어떤 도메인도 ne3를 가리키지 않음**(B-1) = Polar/사용자/DNS 트래픽이 ne3 도달 0. 직접 URL 호출은 인프라 밖 행위로만 가능 = 현역 트래픽 아님. (cold start = 평소 scale-to-zero, 즉 유휴 = Cloud Run 과금 ≈ 0 방증)

### B-4. 경계 재확인 — 현역 도메인 여전히 ne1
```
curl api.grimoire-book.com/api/health → 200 (Google Frontend)
curl dev-api.grimoire-book.com/api/health → 200 (Google Frontend)
```
→ 본 작업(ne3 dump) 중에도 ne1 현역 서빙 정상. ne1 무접촉 유지.

---

## C. dump (verify_before_delete) — **완료, 무결성 PASS**

### C-1. 접근 방식 — Cloud SQL Auth Proxy (firewall/네트워크 변경 0)
- ne3 SQL `authorizedNetworks=(none)` → 공개 IP allowlist 추가 대신 **Auth Proxy(Unix→TCP)** 사용 = 네트워크 설정 변경 0(5/27·6/4 패턴과 동일, 더 안전).
- proxy: `cloud-sql-proxy --port 15440 ...:asia-northeast3:grimoire-pg-prod` / `--port 15442 ...grimoire-pg-dev`. 작업 후 양 proxy 즉시 kill, 잔존 listener 0 확인.
- **자격증명**: `db-password-{env}` secret → bash `PGPASSWORD` 환경변수로만 전달, 작업 후 `unset`. **디스크/로그 기록 0**(host+db만 박제, pw는 `[REDACTED len=32]`, user=`grimoireadmin`).
- **삭제 후 확인**: 양 ne3 SQL `authorizedNetworks=(none)` 유지 = 네트워크 변경 진짜 0.

### C-2. 최종 pg_dump 2건 — GCS 영속 보관
저장처: `gs://grimoire-491708-db-migration/ne3-final/` (`azure-final/`와 prefix 분리). 버킷 **lifecycle 자동삭제 정책 없음 = 무기한 보관(≥30일 충족)**, location=ASIA-NORTHEAST3. 형식 = plain SQL gzip (`pg_dump --no-owner --no-acl | gzip`, PG16.13).

| env | GCS 경로 | 크기 (bytes) | sha256 | GCS md5 = local md5 |
|---|---|---|---|---|
| prod | `ne3-final/ne3-prod-final-20260610T0629Z.sql.gz` | 4,883,451 (4.66MB) | `09b66174b5c9719563df4644e3edaba30fb0f6fdd0e6d1b606170b2920750f5a` | `ww3CaBb16Bb5RHolI4eldA==` MATCH ✓ |
| dev | `ne3-final/ne3-dev-final-20260610T0629Z.sql.gz` | 4,878,920 (4.65MB) | `ffba7aeba19bdc2816c6a9517650c6ecee6a24cd2a6d497cced6efc096982185` | `rFOjSjdVwhm3T5uJehHiVw==` MATCH ✓ |

- **무결성**: 양 dump `gzip -t` OK + PG16 완결 표식(`\unrestrict ...`) 존재 + GCS 업로드본 md5 = 로컬 md5(base64) 비트 동일.
- **구조 sanity**: prod CREATE TABLE 34 = COPY 34 / dev 40 = 40. COPY 행 수 = SELECT 실측과 교차 일치(prod authors=13/payments=4/credit_ledgers=15/subscriptions=33/episodes=109/refresh_tokens=53/reconciliation_checkpoints=1 ; dev authors=12/credit_ledgers=14/membership_plans=12/refresh_tokens=24).
- **참고**: 크기가 6/4 azure-final(prod 4,883,398 / dev 4,878,868)과 거의 동일 = ne3 = 컷오버 snapshot과 같은 데이터 방증.
- 로컬 임시 사본(repo 밖 `~/ne3-final-dumps`)은 GCS 보관 확정 후 정리, **GCS 영속본만 잔존**(local dir empty 확인).

---

## D. ne3 vs ne1 비교 — ne3-only 현역 데이터 **0건** (STOP 사유 없음)

ne1은 무접촉 경계 → 라이브 쿼리 안 함. 대신 **6/4 Azure readiness(verifier-passed)에 박제된 ne1 baseline**과 ne3 실측을 대조(ne1 = 6/4 이후 정상 운영만, 그 baseline이 canonical 기준).

### PROD — ne3 13/13 = ne1 baseline 완전 일치 ✅
| 모델 | ne3 prod (실측) | ne1 prod (6/4 baseline) | 일치 |
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

ne3 prod newest created_at = **2026-05-15**(authors) — 5/26 컷오버 이후 신규 write 0. → ne3 prod = 동결 snapshot. **ne3-only 데이터 0**.

### DEV — ne3 = Azure dev(6/4)와 동일, 3 divergent도 동일 규명 ✅
| 모델 | ne3 dev (실측) | ne1 dev (6/4 baseline) | 판정 |
|---|---|---|---|
| authors | 12 | 13 | ne1 +1 (5/27 이후 ne1에서 정상 증가, ne1 최신) |
| themes/works/episodes/payments/subscriptions/reconciliation_checkpoints | 20/50/109/4/33/1 | 동일 | ✓ |
| admin_audit_logs/webhook_events/refund_logs | 0/0/0 | 동일 | ✓ |
| credit_ledgers | 14 | 0 | ne3>ne1 — nightly sync가 ne1 dev에서 비움(정책) |
| membership_plans | 12 | 0 | ne3>ne1 — 동상 |
| refresh_tokens | 24 | 0 | ne3>ne1 — 동상(만료 세션토큰) |

3개 ne3>ne1 차이 = **STOP 사유 아님**(6/4 Azure 조사로 이미 완전 규명, ne3 = Azure dev와 동수치):
1. 전부 5/27 컷오버 이전 생성(credit_ledgers/membership_plans = CC 개편 seed `denomination_migration_v6` 등 일괄 `2026-05-21`, refresh_tokens = 만료 세션). **신규 write 아님.**
2. ne1에서 사라진 원인 = DB Sync Nightly 정상 동작(`db-sync.ts` L243/244/250 deleteMany — seed성/PII 세션은 prod→dev 재삽입 제외). **데이터 사고 아님, 의도된 정책.**
3. ne3 최종 dump에 온전히 보존(COPY rows credit_ledgers=14/membership_plans=12/refresh_tokens=24 검증) = ne3 삭제해도 GCS dump로 100% 복구 가능.
- ne3 dev newest created_at = **2026-04-10**(authors) — 컷오버 이후 write 0. 동결 snapshot.

→ **요약: "ne3에만 있는, 잃으면 안 될 현역 데이터" = 0건.** ne3는 ne1보다 구버전(ne1이 최신). ne3 prod=ne1과 동일, ne3 dev=Azure dev와 동일(차이 3건 모두 신규 write 아님·dump 보존). **STOP 해당 없음.**

---

## E. 과금 (ne3 유휴 비용)

실 과금 SKU별 분해는 BigQuery billing export/Console 필요(CLI 단순 조회 불가 — Azure `consumption`과 동일 한계). billing account `018E85-DA526A-227CE8` 활성/`billingEnabled: true` 확인. 아래는 SKU 기반 추정(asia-northeast3, 월 기준):

| 자원 | 과금 성격 | 추정 |
|---|---|---|
| Cloud SQL grimoire-pg-prod (db-f1-micro ALWAYS, 10GB HDD, backup+PITR) | **상시 과금** | vCPU/RAM ~$8~9 + 10GB HDD ~$0.9 + backup storage 소액 ≈ **~$9~11/월** |
| Cloud SQL grimoire-pg-dev (동일 사양) | **상시 과금** | ≈ **~$9~11/월** |
| Cloud Run × 4 (scale-to-zero, 도메인 0, 트래픽 0) | 유휴 = 거의 0 | ≈ **$0** (cold start만, B-3 방증) |
| Secret Manager 18건 | 버전 storage 극소 | ≈ **$0.1/월** (활성 secret version $0.06/건/월 무료분 내외) |
| AR cloud-run-source-deploy (ne3, 이미지 storage) | storage 소액 | ≈ **$0.1~0.5/월**(이미지 ~수백MB) |
| **합계 (ne3 정리 시 절감)** | | **≈ ~$18~23/월 (~₩25k~32k)** |

→ 주 비용원 = **Cloud SQL × 2 ALWAYS-on**(Cloud Run/Secret/AR은 미미). ne3 정리 시 ~₩25k~32k/월 절감 추정. (정밀 실측은 Console billing 권고 — 비차단)

---

## F. 삭제 순서 계획 (GO 시 — **본 단계 아님, verifier 게이트 후 별도**)

의존 역순. **전제: 사용자 삭제 승인 + verifier 독립 게이트 PASS(dump 무결성·ne3-only 데이터 0·ne1 canonical 재확인).**

1. **ne3 Cloud Run × 4 삭제** 먼저 (`gcloud run services delete ... --region=asia-northeast3`) — ne3 SQL로의 유일 연결 경로(server 2건) 차단. 이 시점부터 ne3 SQL 참조 0 확정.
2. **ne3 Cloud SQL × 2 삭제** (`gcloud sql instances delete grimoire-pg-{prod,dev}`) — dump 보관 재확인 후. **삭제 직후 GCS dump 2건 md5 재확인(무손상)**.
3. **ne3 Secret Manager 18건 삭제** (`gcloud secrets delete ...` — ne3 9종 × dev/prod). ne1 `*-an1` 무접촉.
4. **ne3 AR `cloud-run-source-deploy`(asia-northeast3) 삭제** (`gcloud artifacts repositories delete ... --location=asia-northeast3`). 🔴 ne1 `grimoire-docker`/`cloud-run-source-deploy`(an1) 무접촉.

### 롤백 불가 지점
- ne3 SQL 삭제 = ne3 snapshot 영구 소실 → **GCS dump(≥30일)로만 복구**. ne3 = 구버전이라 ne1 운영 영향 0.
- ne3 AR 삭제 = ne3 이미지 영구 소실. ne1 라이브 이미지는 별도 repo(`grimoire-docker`/an1) → ne1 운영 영향 0.

### 보존(무접촉) — 🔴 절대 경계
- **ne1 전부**: Cloud SQL grimoire-db-{prod,dev}, Cloud Run 4(an1), secret `*-an1`, domain mapping 4.
- **AR `grimoire-docker`(an1)** = deploy 타깃.
- **GCS `azure-final/` dump 2건** + 본 작업 `ne3-final/` dump 2건.

---

## G. 검증 못한 항목 (정직 명시)
1. **ne1 라이브 row count 직접 대조** — ne1 "무접촉" 경계 준수로 라이브 쿼리 안 함(Auth Proxy 1회 잘못 띄웠다 classifier 차단→즉시 kill, ne1 SELECT 0). 대신 6/4 verifier-passed ne1 baseline과 대조. → prod 13/13 일치 / dev 차이 3건 6/4 규명과 동일. **위험 낮음**(ne3는 구버전, ne1>ne3가 자연).
2. **ne3 실 과금액 SKU별** — Console/BigQuery billing 필요(CLI 한계). SKU 추정 ~$18~23/월. → 추정으로 GO 처리 안 함(과금은 GO/NO-GO 사유 아님, 절감 참고치).

위 모두 **추정으로 GO 처리 안 함**. 1은 ne1 무접촉 준수의 정당한 결과 + 6/4 baseline으로 봉합. **삭제 게이트는 verifier 독립 재확인이 최종 판단.**

---

## 종합

- **ne3 자산**: Cloud SQL 2(grimoire-pg-{prod,dev}) + Cloud Run 4(rev 00001 방치) + Secret 18(ne3 9종×2env) + AR 1(cloud-run-source-deploy@an3). 전부 5/26 생성, 5/27 ne1 컷오버로 방치.
- **고아 확정**: domain mapping 0 + ne1 미참조 + 트래픽 0 + 컷오버 이후 write 0.
- **데이터 안전**: ne3-only 잃을 데이터 0(prod=ne1 일치, dev=Azure dev 동일·차이 3건 규명·dump 보존). 최종 dump 2건 GCS 영속(sha256/md5 박제, ≥30일).
- **본 단계 변경**: Auth Proxy 기동/종료뿐(네트워크 변경 0, 자격증명 디스크 기록 0). **ne3 포함 삭제 0 / dump 삭제 0 / ne1·grimoire-docker·azure-final 무접촉.**
- **판정**: **조건부 GO** — verifier가 본 Step 1(dump 무결성+ne3-only 0+ne1 baseline 대조)을 독립 재확인 후 삭제 단계(§F) 진입.

---

마지막 업데이트: 2026-06-10 — grimoire-infrastructure agent (Step 1: assess + dump, 삭제 0)

---

# Step 3 — 실제 삭제 (되돌릴 수 없음) — **완료**

- **일시**: 2026-06-10
- **수행**: grimoire-infrastructure agent
- **전제**: verifier GATE PASS 완료(dump 무결성·데이터 보존·고아·경계). 사용자 "Step 3 실제 삭제" 명시.
- **방법**: 의존 역순 staged 삭제. 전 명령 `--project=grimoire-491708` 명시(기본 config=`pr-letter-addr` 오정합 방지). 전 항목 CLI raw 실측. "지웠다" 대신 raw 부재 확인.

## 0. 삭제 전 baseline (raw)
- **gcloud account** = `rainmaker8492@gmail.com` / 기본 config = `pr-letter-addr`(오정합 확인 → 전 명령 `--project` 강제).
- **ne3 삭제 대상 스냅샷**: Cloud Run 4(server/web×prod/dev @ an3, 5/26 배포) + Cloud SQL 2(`grimoire-pg-prod` 34.64.168.150 / `grimoire-pg-dev` 34.64.162.34 @ an3) + Secret non-an1 **18건**(9종×dev/prod) + AR `cloud-run-source-deploy`@an3 1건.
- **삭제 전 dump 잔존 재확인**: `ne3-final/` prod 4,883,451 + dev 4,878,920 bytes 생존. `azure-final/` 2건 생존.
- **삭제 전 ne1 baseline**: Cloud Run 4 전부 `True`(server-prod/dev rev 00006, web rev 00002, 트래픽 100%) / 4 도메인 = api·dev-api **200**, apex·dev **307**.
- **보존 경계 사전 확인**: `*-an1` secret **20건**(readiness §A-3 추정 19 → 실측 20, 어느 쪽이든 보존). AR an1 = `cloud-run-source-deploy` + `grimoire-docker` 2건.

## 1. STEP 3-1 — ne3 Cloud Run × 4 삭제 (raw)
의존 역순 1단계: ne3 SQL로의 유일 연결 경로(server 2건) 먼저 차단.
```
DELETE grimoire-web-prod   @ an3 → Deleted service. [exit=0]
DELETE grimoire-web-dev    @ an3 → Deleted service. [exit=0]
DELETE grimoire-server-prod@ an3 → Deleted service. [exit=0]
DELETE grimoire-server-dev @ an3 → Deleted service. [exit=0]
확인: ne3 Cloud Run 잔존 = 0
```
**중간 ne1 무영향**: ne1 4서비스 `True` 유지 / 4 도메인 200·200·307·307 (삭제 전과 동일).

## 2. STEP 3-2 — ne3 Cloud SQL × 2 삭제 (raw, 롤백 불가 핵심)
삭제 직전 dump 2건 잔존 재확인(prod 4,883,451 / dev 4,878,920) 후, region 가드(asia-northeast3 확인 시에만 삭제):
```
DELETE grimoire-pg-prod (region=asia-northeast3 확인) → Deleted. [exit=0]
DELETE grimoire-pg-dev  (region=asia-northeast3 확인) → Deleted. [exit=0]
확인: Cloud SQL 잔존 = grimoire-db-prod/dev (asia-northeast1, RUNNABLE) 2건만 = ne1 보존
```
**삭제 직후 dump md5 무손상 재확인** (롤백 안전망):
| dump | Content-Length | MD5 | readiness §C-2 박제 |
|---|---|---|---|
| ne3-prod-final | 4,883,451 | `ww3CaBb16Bb5RHolI4eldA==` | 비트 동일 ✓ |
| ne3-dev-final | 4,878,920 | `rFOjSjdVwhm3T5uJehHiVw==` | 비트 동일 ✓ |
→ Cloud SQL 영구 삭제됐으나 GCS dump 무손상(md5 일치) = 복구 경로 보존.

## 3. STEP 3-3 — ne3 Secret 18건 삭제 (raw, non-an1만)
하드코딩 18건 리스트 + `*-an1` GUARD-BLOCK(이중 안전). **1차 시도 = shell 단어분리 실패로 삭제 0건(gcloud INVALID_ARGUMENT 거부, exit=1) — `*-an1` 무손상**. 배열로 재시도:
```
anthropic-api-key-{dev,prod} / azure-storage-account-key-{dev,prod} / database-url-{dev,prod}
db-password-{dev,prod} / jwt-secret-{dev,prod} / openai-api-key-{dev,prod}
polar-access-token-{dev,prod} / polar-webhook-secret-{dev,prod} / recaptcha-secret-key-{dev,prod}
→ 18건 전부 Deleted [exit=0]. GUARD-BLOCK 도달 0건.
확인: non-an1 secret 잔존 = 0
```

## 4. STEP 3-4 — ne3 AR cloud-run-source-deploy@an3 삭제 (raw)
```
DELETE cloud-run-source-deploy --location=asia-northeast3 → Deleted repository. [exit=0]
확인(JSON `[]` + describe NOT_FOUND): an3 AR 잔존 = 0
```
※ `value(name) | grep -c .`가 "Listing items under..." 헤더 라인 1을 오탐 → JSON `[]` + describe `NOT_FOUND`로 부재 교차 확정.

## 5. 최종 검증

### ne3 부재 확인 (전부 0)
| 자원 | 잔존 | 확인 방식 |
|---|---|---|
| Cloud Run @ an3 | **0** | services list 빈 |
| Cloud SQL `grimoire-pg-*` | **0** | instances list = ne1 2건만 |
| Secret non-an1 | **0** | grep -v an1 빈 |
| AR @ an3 | **0** | JSON `[]` + describe NOT_FOUND |

### 보존 대상 생존 확인 (🔴 경계 무손상)
| 보존 자원 | 상태 |
|---|---|
| ne1 Cloud SQL `grimoire-db-prod`/`grimoire-db-dev` | **2건 RUNNABLE** ✓ |
| `*-an1` secret | **20건 생존** ✓ |
| AR an1 `cloud-run-source-deploy` + `grimoire-docker` | **2건 생존** ✓ |
| GCS `azure-final/` dump 2 + `ne3-final/` dump 2 | **4건 전부 생존** ✓ |

### ne1 4서비스 + 4도메인 무영향 (전체 삭제 후)
```
ne1 Cloud Run: server-dev/prod rev 00006, web-dev/prod rev 00002 — 전부 True, 트래픽 100% (baseline 동일)
4 도메인: api 200 / dev-api 200 / apex 307 / dev 307 (baseline 동일)
domain mapping 4: api→server-prod, dev-api→server-dev, dev→web-dev, apex→web-prod (ne1 정합)
```

## 절감
ne3 정리 완료 → readiness §E 추정 **~$18~23/월(~₩25k~32k)** 절감. 주 비용원 = Cloud SQL × 2 ALWAYS-on 제거. (정밀 실측은 Console billing, 비차단.)

## 종합 (Step 3)
- **삭제 완료**: Cloud Run 4 + Cloud SQL 2 + Secret 18 + AR 1 = ne3 자산 전건 제거(전부 exit=0).
- **데이터 안전**: Cloud SQL 삭제 직후 dump md5 = readiness 박제와 비트 동일(무손상). GCS dump 4건 전부 생존.
- **경계 무손상**: ne1 Cloud SQL 2 + `*-an1` 20 + AR an1 2 + dump 4 전부 생존. ne1 4서비스/4도메인 baseline 동일(무영향).
- **롤백 불가 지점 통과**: ne3 SQL/AR 영구 소실 but ne3=구버전(ne1 최신)·GCS dump 복구 경로 보존 → ne1 운영 영향 0.
- **5/27 Phase 7(Azure decommission) + 6/4 잔여 GCP 정리 후속의 ne3 잔재 제거 = GCP 단일 region(ne1) 정합 완성.**
- ⚠️ verifier가 본 Step 3을 독립 재확인(post-delete: ne3 부재 + 보존 생존 + ne1 무영향) 예정.

마지막 업데이트: 2026-06-10 — grimoire-infrastructure agent (Step 3: 실제 삭제 완료, ne3 전건 제거 / 보존 경계 무손상)
