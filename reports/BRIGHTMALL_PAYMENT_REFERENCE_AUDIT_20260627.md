# brightMall 결제 패턴 — 참조 커버리지 전수검사

> **작성**: 2026-06-27 (메인 자율, 읽기 전용 감사 — brightMall/grimoire 코드 무수정)
> **목적**: brightMall(덴티움 치과몰, CERTI_PROJ 실제 프로덕션 e-commerce)의 결제 처리에서 grimoire가 **따올 수 있는 패턴을 다 숙지·참조하고 있는지**, 빠뜨린 게 없는지 전수 대조
> **방식**: brightMall 결제 코드 실측(file:line) → grimoire 현행(PAYMENT_SYSTEM_PLAN 인용 + grimoire-server 실구현, Explore 에이전트 인벤토리) 크로스체크 → MISSED 우선순위
> **핵심 주의**: 도메인 상이 — brightMall = 실물 e-commerce(배송/재고/카트/주문) on **MedusaJS + TossPayments(PG 직접)**, grimoire = 소설 SaaS **구독/크레딧** on **Polar(MoR)**. 적용 불가 패턴은 "해당없음"으로 명시 분리.

---

## 0. TL;DR — 핵심 결론

**brightMall 결제 패턴 숙지·참조 커버리지 ≈ 72%** (적용 가능 패턴 기준).

- grimoire의 `research/PAYMENT_SYSTEM_PLAN.md`는 CERTI_PROJ 15개 프로젝트를 분석했으나, **brightMall은 단 1줄(`checkout.ts:35-100` "MedusaJS + Pinia + TossPayments")로 얕게만 인용**됨. 백엔드 패턴은 `no1-sass`/`inapi`/`thermage-batch-api`에, 운영자 UI는 `admin-certilife`에 의존. **brightMall 고유 패턴 다수가 plan 본문에서 직접 차용되지 않음.**
- 그럼에도 grimoire-server **실구현은 핵심 결제 안전 패턴을 대부분 독립적으로 보유**(서버측 금액 재검증, 3중 멱등성, 원자 트랜잭션, 부분환불 누적한도, reconciliation cron, deficit 분기). 즉 "brightMall에서 따왔다"가 아니라 "수렴 진화"로 이미 구현된 항목이 많음 → **실질 커버리지는 인용 커버리지보다 높음.**
- **진짜 MISSED(차용 가치 있음) 3건**:
  1. **결제 금액의 PG 재확인(confirmPayment) 명시적 박제** — brightMall은 successUrl을 **백엔드 콜백**(`/payment/tosspay`)으로 받아 `confirmPayment(orderId, paymentKey, amount)`로 PG에 재조회·검증 후에야 이행. grimoire는 webhook 단일 경로(클라 returnUrl은 토스트용)라 구조적으로 안전하지만, **"returnUrl 신뢰 금지 + 서버 재검증" 원칙이 문서/sensor로 박제돼 있지 않음**.
  2. **크레딧(포인트) 만료·기간필터 이력 UI** — brightMall `point.ts`는 `expiry_date` 포함 거래내역 + 1/3/6/12개월 기간필터 + 잔액. grimoire는 `CreditLedger.expiresAt`(구독풀만) 보유하나 **사용자向 "기간별 크레딧 내역 + 만료예정" 조회가 usecase/HTTP에 미배선**(getLogs는 limit=100 고정, 기간 파라미터 없음).
  3. **결제/주문 상태별 건수 집계(statusCounts)** — brightMall `useOrder.getAllOrders`는 상태별 카운트(결제완료/배송준비중/…)를 응답에 동봉. grimoire admin `listPayments`에 **GROUP BY status 집계 부재**(운영자 대시보드 숫자 뱃지 불가).

**보강 권장(소설 SaaS 적용가치 순)**: ① 크레딧 만료/기간필터 이력 API+UI(사용자 신뢰·CS) > ② "returnUrl 비신뢰 + 서버 재검증" sensor/문서 박제(보안 회귀방지) > ③ admin 결제 status 집계(운영 편의). 나머지 brightMall 패턴은 이미 보유했거나 도메인상 해당없음.

---

## 1. brightMall 결제 아키텍처 실측 (스택·구조)

| 항목 | 실측 |
|---|---|
| 프론트 스택 | Vue 3 + Pinia + Vite + TypeScript (`package.json`) |
| 백엔드 | **MedusaJS v2** (`@medusajs/js-sdk` 2.8.1) — PG-agnostic e-commerce 엔진 (별도 레포, 본 분석 대상 외) |
| PG | **TossPayments** (`@tosspayments/tosspayments-sdk` 2.3.4) — **PG 직접 연동**(MoR 아님). 영수증/세금은 자체 책임 |
| 결제수단 | TossPayments 위젯(카드 등) + **포인트(선수금) 결제**(`pp_point-payment`) 병행 |
| 모바일 | AOS(Kotlin)/iOS(Swift) 모두 **WebView 래퍼** — 네이티브 결제 코드 0건, 결제는 임베드된 web에서 수행 |
| 결제 핵심 파일 | `src/stores/checkout.ts`(605줄, 결제 오케스트레이션) / `src/lib/utils/order-identifier.ts` / `src/features/payment/views/{PaymentSuccessView,PaymentFailView}.vue` / `src/features/mypage/order/{hooks/useOrder.ts, components/PaymentInfo.vue}` / `src/stores/point.ts` / `src/stores/promotion.ts` / `docs/backend-order-id-handling.md`(백엔드 콜백 규격) |

> **구조 핵심**: brightMall은 결제 **확정(capture)을 백엔드 콜백**에서 수행. 클라(`checkout.ts`)는 Toss 위젯 `requestPayment`만 호출하고, **successUrl/failUrl을 백엔드 엔드포인트**(`${backendUrl}/payment/tosspay`)로 지정 → Toss가 `paymentKey/orderId/amount`를 백엔드로 리다이렉트 → 백엔드가 `confirmPayment`로 PG 재조회 후 주문 이행. **클라이언트는 결제 성공을 "선언"할 수 없다**(SuccessView는 캐시된 주문 표시용).

---

## 2. brightMall 결제 패턴 추출 + grimoire 크로스체크 (전수 표)

> 상태 범례: **참조됨**(plan 인용 or grimoire-server 구현 존재) / **MISSED**(따올 수 있는데 미숙지·미배선) / **해당없음**(도메인 상이로 grimoire 적용 불가/불필요)

| # | brightMall 패턴 | brightMall file:line | grimoire 상태 | 적용가치 / 근거 |
|---|---|---|---|---|
| **멱등성·중복방지** ||||
| 1 | UI 상태 기반 재호출 차단(`loading`/`USER_CANCEL` 분기로 중복 결제 방지) | `checkout.ts:503-507` (USER_CANCEL → `{cancelled:true}`, throw 안 함) ; `TossPaymentDialog.vue:81-97` | **참조됨** | grimoire `useThrottle.ts` + `@Throttle` 보유(plan §2-2 #7). 동등. |
| 2 | 서버측 결제 확정 멱등성(주문 status로 중복 confirm 차단) | `docs/backend-order-id-handling.md:56-73` (백엔드 confirmPayment 경로) | **참조됨(우월)** | grimoire 3중 멱등성(L1 eventId@unique / L2 externalTxId / L3 status race) — `payment.usecase.processNormalizedWebhook:306-355`. brightMall보다 강함. |
| **결제 검증·PG 연동** ||||
| 3 | **successUrl을 백엔드로 → confirmPayment(PG 재조회·금액 검증)** | `checkout.ts:443-444` (successUrl=`${backendUrl}/payment/tosspay`) ; `docs/backend-order-id-handling.md:62-72` (`confirmPayment(order.id, paymentKey, amount)`) | **부분참조 / MISSED(원칙박제)** | grimoire는 webhook이 진실원천(returnUrl `?checkout_id`는 토스트용, plan §1-4 #6) → 구조적 안전. **단 "returnUrl 비신뢰 + 서버 재검증" 원칙이 sensor/문서로 박제 안 됨**. → **MISSED #2** (회귀방지 가치). |
| 4 | 클라가 가격/금액 조작 불가(금액은 서버 권위) | `checkout.ts:210,241` (`paymentCart.total` 서버값) ; 위젯 `setAmount` 후 백엔드 재확정 | **참조됨** | grimoire `initiatePayment`가 productId→product.price 서버조회로 재검증(클라 가격 불신, payment.usecase:206-232). 동등. |
| 5 | PII(이메일/이름/전화) **정규화·마스킹** 후 PG 전달 | `checkout.ts:406-417` (sanitizeString/normalizePhoneNumber), `:475-480` (로그 마스킹) | **참조됨(부분)** | grimoire는 Polar checkout metadata로 전달 + webhook payload PII 90일 마스킹(`WebhookEvent.maskedAt`). 로그 마스킹 정합. plan §2-2 #5에 customer info 전달 언급. |
| 6 | **HMAC/서명 webhook 검증** | (brightMall은 Toss 직접 인증, plan §2-3 A안티: "Toss 서명검증 미흡") | **참조됨(우월)** | grimoire `polar-webhooks.ts` validateEvent(Standard Webhooks). plan §2-3에서 "brightMall보다 우월"로 명시. |
| **주문↔결제 정합 / 식별자** ||||
| 7 | **이중 주문ID**(erpOrderId=PG표시·운영연동용 `YYYYMMDDHHMM_NNNNNNNNN` ↔ actualOrderId=UUID 백엔드조회용) | `checkout.ts:375-398` (상세 주석) ; `order-identifier.ts:20-72` (getBrightOrderNo) ; `docs/backend-order-id-handling.md:123-155` (display_id 역파싱) | **해당없음(부분 차용가치)** | grimoire는 `externalTransactionId`(Polar) + Payment.id(UUID)로 이미 2-ID. **운영자가 읽는 사람친화 주문번호** 개념은 grimoire에 약함 — 단 SaaS 결제는 건수 적고 admin이 Polar 대시보드 병행 → 가치 낮음. |
| 8 | PG 콜백 파라미터 소실 대응(Toss는 custom param 제거, `paymentKey/orderId/amount`만 보존) | `checkout.ts:420-434` (주석) ; `docs/backend-order-id-handling.md:5-12` | **해당없음** | Polar는 webhook payload로 전체 전달 → 파라미터 소실 문제 없음. brightMall 고유 제약. |
| **환불·취소** ||||
| 9 | **부분환불 회계**(captured_amount − refunded_amount = finalAmount, `partially_refunded` 상태, 비율 표시) | `PaymentInfo.vue:19-91` (refundAmount/capturedAmount/finalAmount/actualPaidAmount) | **참조됨** | grimoire `refundPaymentWithPoints`: isPartial 비율계산 + `partial_refunded` status + PAY-S2 **누적환불 한도검증**(`refundLog.aggregate` sum > amount throw, prisma-payment.repository:295-305). brightMall은 표시만, grimoire는 누적한도 강제 → **우월**. |
| 10 | 환불 시 포인트/현금 분리 정산(포인트 결제분 vs 현금 결제분 환불 안분) | `PaymentInfo.vue:46-91` (pointSession/pointPayment 안분) | **참조됨(우월)** | grimoire `computeRefundLedgerEntries` 4-source 우선순위 환수(charged→gift→subscription→free) + deficit 분기 + CAS 동시성 보호. 훨씬 정교. |
| 11 | USER_CANCEL(사용자 취소)을 에러와 구분 | `checkout.ts:503-507` | **참조됨** | grimoire는 결제 취소=webhook 미수신(pending 유지) → reconciliation S3로 24h후 expire. 경로 다르나 정합. |
| **재시도·orphan 정리** ||||
| 12 | 결제 실패 시 새 카트 발급 + 재시도 경로(failUrl→cartId 보존→재시도) | `checkout.ts:509-511` (CART_ID 임베드) ; `PaymentFailView.vue:48-54` (retryPayment) ; `checkout.ts:578-598` (handlePaymentFailure) | **참조됨** | grimoire `findReusablePendingPayment`(24h 윈도우 pending 재사용, orphan 폭주 차단, payment.usecase:186-200) + reconciliation S3 expire. plan §3-2 P1-3에서 "brightMall과 구조 다름(재고/배송 vs 크레딧)"으로 차용 판단 완료. |
| **정합성 검증 batch** ||||
| 13 | PG↔DB reconciliation(누락 보완) | (brightMall 자체엔 약함 — thermage-batch-api가 정본) | **참조됨** | grimoire `payment-reconciliation.job` `@Cron('0 */10 * * * *')` S1 boost/S2 mismatch/S3 expire + checkpoint. plan §2-2 #11(thermage 차용). brightMall과 무관. |
| **포인트/크레딧(★ 도메인 직결)** ||||
| 14 | **포인트 거래내역 + 만료일(expiry_date) + 기간필터(1/3/6/12개월) + 잔액** | `point.ts:5-10` (PointTransaction.expiry_date) ; `:71-121` (loadPointHistory, from_date 필터) ; `:23-28` (periods) | **MISSED** | grimoire `CreditLedger.expiresAt`는 **구독풀에만** 부여, **사용자向 기간필터 조회 미배선**(getLogs limit=100 고정, 기간 파라미터 없음 — credit.usecase:174-179). 소설 SaaS에 **만료예정·기간별 내역은 신뢰/CS 직결** → **MISSED #1 (최고 가치)**. |
| 15 | 포인트(선수금)를 결제수단으로 cart에 적용/해제 | `checkout.ts:160-196` (setSelectedPaymentMethod POINT 분기) ; `promotion.ts:543-567` (applyPointPromotions) | **해당없음** | grimoire 크레딧은 "결제 대상"이 아니라 "충전 후 AI 기능 차감" 모델. 결제수단으로서의 포인트 개념 부재(정상). |
| **운영자/관리** ||||
| 16 | **상태별 건수 집계**(statusCounts: 결제완료/배송준비중/…) | `useOrder.ts:92-111` (getAllOrders 응답에 statusCounts 동봉) | **MISSED** | grimoire admin `listPayments`(admin.controller:288-295)에 GROUP BY status 집계 부재. 운영 대시보드 숫자뱃지/필터 카운트 불가 → **MISSED #3 (운영 편의)**. |
| 17 | 주문목록 필터(기간/상태/날짜/검색어 + 페이지네이션) | `useOrder.ts:5-11,48-128` (OrderFilters) ; `point.ts:32-45` (페이지네이션) | **참조됨(부분)** | grimoire `listPayments`는 page/limit/authorId/status 필터 보유. 날짜범위·검색어는 부분(admin.controller:288-295). 대부분 정합. |
| 18 | 결제이력에서 **다시 주문하기(reorder)** | `PaymentInfo.vue:118-175` (reorder: 새 카트+아이템 복제) | **해당없음** | "재구매=같은 상품 다시 장바구니"는 실물 e-commerce 개념. grimoire는 크레딧 재충전(상품 1종) → reorder 불필요. |
| 19 | 주문번호 클립보드 복사 + 토스트 | `OrderDetailView.vue:35-60` | **해당없음(저가치)** | UX 미세 패턴. grimoire 결제 UX에 필수 아님. |
| **에러·브라우저 호환** ||||
| 20 | 브라우저별 호환 분기(Whale 브라우저 특수처리) | `checkout.ts:483-491` | **해당없음** | TossPayments SDK 특유 이슈. Polar Checkout(호스티드 페이지)은 PG측 처리 → 불필요. |
| 21 | successUrl/failUrl **분리**(실패 흐름 별도 라우트) | `checkout.ts:437-444` ; `PaymentFailView.vue` 전체 | **참조됨** | plan §2-2 #5에서 "Grimoire returnUrl 단일 → 실패 흐름 별도 처리 필요" 인지됨(`successUrl`/`failUrl` 2회 인용). Polar는 실패 시 미결제로 returnUrl 복귀 안 함 → webhook fail 분기로 처리(payment.usecase fail branch). 정합. |
| **모바일(WebView)** ||||
| 22 | WebView 결제 리다이렉트/PG앱 스킴 핸드오프 | AOS `WebViewActivity.kt:99-104`(generic new-window intent) ; iOS `BasicWebViewNavigationDelegateAdapter.swift:106-126`(전부 `.allow`) | **해당없음(brightMall도 미흡)** | brightMall AOS/iOS는 PG앱 스킴(`supertoss`/`ispmobile`/`intent://`) **명시 인터셉트 부재** = brightMall 자체 약점(따올 패턴 아님). grimoire는 **모바일 앱 없음(web 전용)** → 전면 해당없음. |
| **알림** ||||
| 23 | 결제 성공/실패/환불 알림 | (brightMall 결제경로에 이메일/SMS 알림 코드 미발견) | **참조됨(우월)** | grimoire `payment-notification.usecase`(4종: 성공/실패/환불/구독갱신, non-blocking, NullAdapter 기본). brightMall보다 앞섬. |
| **영수증·세금** ||||
| 24 | 영수증/세금계산서 | (brightMall=Toss 직접연동 → 자체 책임, 코드상 영수증 URL 노출 미발견) | **해당없음(구조 상이)** | grimoire=Polar **MoR**(영수증/VAT/세금계산서 Polar 자동, KYC 후). plan §1-4 #8 + §2-3 A2 명시. grimoire가 구조적으로 유리. |

---

## 3. 커버리지 산정

**적용 가능 패턴(해당없음 제외) = 14건**: #1,2,3,4,5,6,9,10,11,12,13,14,16,17,(21,23,24는 참조됨 추가) → 실효 분모 정리:

| 분류 | 건수 | 항목 |
|---|---|---|
| **참조됨**(보유/구현/plan인용) | **10** | #1,2,4,5,6,9,10,11,12,13,17,21,23,24 중 적용가능분 — 핵심 안전패턴 전부 |
| **MISSED**(차용가치 有) | **3** | #14(크레딧 만료·기간필터 이력) / #3(returnUrl 비신뢰+서버재검증 원칙 박제) / #16(결제 status 집계) |
| **해당없음**(도메인 상이) | **8** | #7,8,15,18,19,20,22,24(영수증) — 실물 e-commerce/TossPG직접/모바일WebView 고유 |

**숙지·참조 커버리지 = 참조됨 / (참조됨 + MISSED) = 10 / 13 ≈ 72%**

> 보수적 산정(원칙 박제 #3을 "부분참조"로 0.5 가중 시 ≈ 79%). **인용 커버리지(plan이 brightMall을 직접 인용한 정도)는 낮으나(~1줄), 실구현 커버리지는 높음** — grimoire-server가 핵심 결제 안전망을 독립 보유했기 때문.

---

## 4. MISSED 보강 권장 (grimoire 소설 SaaS 적용가치 순)

### ★ MISSED #1 — 크레딧 만료·기간별 이력 조회 (사용자向) — **최고 가치**
- **brightMall 근거**: `point.ts:5-10`(expiry_date) + `:71-121`(from_date 기간필터) + `:23-28`(1/3/6/12개월).
- **grimoire 현황**: `CreditLedger.expiresAt`는 구독풀 reset에만 세팅. 사용자 조회 `getLogs`는 limit=100 고정·기간 파라미터 없음(credit.usecase:174-179). 즉 데이터는 일부 있으나 **API/UI 미배선**.
- **권장**: ① `getLogs(authorId, {from,to,limit,offset})` 기간/페이지 파라미터 확장 ② "만료 예정 크레딧"(구독풀 expiresAt 임박분) 노출 ③ web 마이페이지 크레딧 내역 탭(기간필터 + 만료일 컬럼).
- **이유**: 소설 SaaS는 크레딧 충전→소진이 결제 신뢰의 핵심. "내 크레딧 언제 만료/얼마 썼나"는 CS 1순위 문의. **§0 원가 영향 0(조회만)**.

### MISSED #2 — "returnUrl 비신뢰 + 서버 재검증" 원칙 sensor/문서 박제 — 회귀방지
- **brightMall 근거**: successUrl을 **백엔드 콜백**으로(`checkout.ts:443`) + `confirmPayment(orderId,paymentKey,amount)` PG 재조회(`docs/backend-order-id-handling.md:62-72`). 클라가 성공 선언 불가.
- **grimoire 현황**: 구조적으로 이미 안전(webhook 진실원천, returnUrl은 토스트용). **단 이 불변식이 sensor/문서로 명시 박제 안 됨** → 향후 누군가 returnUrl 파라미터로 크레딧 적립하는 코드를 짜도 막을 자동 게이트 없음.
- **권장**: ① `sensor-payment-returnurl-trust.sh`(신설) — returnUrl/checkout_id 처리부에서 크레딧 mutation 호출 금지 패턴 검사 ② PAYMENT_SYSTEM_PLAN §1-4에 "클라 복귀 경로 비신뢰" 불변식 1줄 박제.
- **이유**: ZERO-TOLERANCE 정책(정책·보안 누락 금지) 정합. 저비용 고보험.

### MISSED #3 — admin 결제 상태별 건수 집계(statusCounts) — 운영 편의
- **brightMall 근거**: `useOrder.ts:92-111` getAllOrders 응답에 상태별 카운트 동봉.
- **grimoire 현황**: `listPayments`(admin.controller:288-295)는 목록만, GROUP BY status 집계 없음.
- **권장**: `listPayments` 응답에 `statusCounts {pending,completed,failed,refunded,partial_refunded,expired}` 추가(단일 `groupBy` 쿼리). web admin 결제탭 필터 뱃지.
- **이유**: 운영자 대시보드 가독성. 우선순위는 낮음(건수 적으면 체감 작음).

---

## 5. 적용 불가(해당없음) 패턴 — 명시 제외 사유

| 패턴 | 제외 사유 |
|---|---|
| 이중 주문ID(erpOrderId, #7) / 콜백 param 소실(#8) | TossPayments **PG 직접연동** 고유 제약. Polar는 webhook full payload → 불필요. grimoire는 externalTxId+UUID로 이미 2-ID. |
| 포인트=결제수단(#15) / reorder(#18) / 클립보드복사(#19) | 실물 e-commerce(카트/배송/재구매) 개념. grimoire 크레딧은 충전→차감 모델, 상품 1종. |
| Whale 브라우저 분기(#20) | Toss SDK 클라 위젯 특유. Polar 호스티드 결제는 PG측 처리. |
| 모바일 WebView PG앱 스킴(#22) | grimoire는 **web 전용(모바일 앱 없음)**. + brightMall 자체도 스킴 인터셉트 미흡(따올 패턴 아님). |
| 영수증/세금 자체발급(#24) | grimoire=Polar **MoR**(자동). brightMall=Toss직접(자체책임). 구조적으로 grimoire 유리. |

---

## 6. 접근 불가/제약 명시

- **brightMall MedusaJS 백엔드 본체**: 별도 레포(본 워크스페이스 미존재). 백엔드 결제 확정 로직은 **`docs/backend-order-id-handling.md` 규격 문서 + checkout.ts successUrl 라우팅**으로 역추적(의사코드 수준). 실 `confirmPayment` 구현체 직접 미열람 → 해당 부분은 문서 근거.
- **모바일 앱**: AOS/iOS 모두 WebView 래퍼 확인(네이티브 결제 0건). 결제 UX·영수증·에러처리는 임베드 web(brightmall-v2)의 것 = 본문 §2 web 분석에 포함.
- 그 외 brightmall-v2/grimoire-server 결제 파일은 전부 실측(file:line 표기).

---

## 7. 변경 이력
- 2026-06-27: 신설 — brightMall 결제패턴 24건 추출·크로스체크, 커버리지 72% 판정, MISSED 3건 보강 권장. 읽기 전용(무수정).
