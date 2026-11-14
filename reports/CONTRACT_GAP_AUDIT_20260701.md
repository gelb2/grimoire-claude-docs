# 크로스 계약·미구현 감사 — CONTRACT_GAP_AUDIT (2026-07-11 실측, 파일명은 지시 준수)

> **읽기 전용 감사** — 문서(api-contract/PLANNING/shared-contracts) ↔ server(controller/DTO/usecase) ↔ web(BFF+api.ts+페이지) 3-way 대조 + untracked 미구현 발굴.
> 근거는 전부 raw(파일:라인, curl 응답, git SHA). 추정 0건 — 미실측 항목은 명시.
> **제외(추적된 백로그 — 재보고 안 함)**: Kakao OAuth · HTML/PDF 파서 · Redis · SSE · FSD · 시맨틱캐시 · 이메일/SMS 실발송 · 구독 live 전환 · brightMall MISSED 3 · PAY-S5 · 메인화면 개선(P2).

## 실측 방법
- server 라우트 전수: `grimoire-server/src/adapter/inbound/http/controller/*.ts` @Controller+@Get/Post/Put/Patch/Delete 추출 (21 controller).
- web 호출 전수: `grimoire-web/src/lib/api.ts`(853줄, 전 메서드) + 직접 fetch 5개소(`app/[author]/layout.tsx`, `app/shared/[token]/page.tsx` 등). BFF는 catch-all 프록시(`src/app/api/[...path]/route.ts`) — 경로 변환 없음(rewrites/middleware 부재 확인).
- 라이브 검증: dev-api.grimoire-book.com에 읽기 전용 GET 2건 + products 1건 curl.

---

## 🔴 CRITICAL — 웹이 호출하는데 서버가 받지 못함 / 즉시 사용자 체감 버그 (6건)

### C-1 | 🔴 | 계약불일치(⑤ 라우트 부재) | web `src/lib/api.ts:74-79` + `features/account/AccountDeleteDialog.tsx` → `app/dashboard/profile/page.tsx:142` | **본인 계정 탈퇴가 항상 404** — web은 `DELETE /api/auth/me` 호출, 서버 실제 라우트는 `DELETE /api/authors/me`(author.controller.ts:47 `@Delete('me')` @ `@Controller('authors')`)
- 근거: auth.controller.ts에 `@Delete` 데코레이터 0건(grep 전수). api-contract.md L125도 `/api/authors/me`로 명세. NestJS 라우트 테이블상 `/api/auth/me`는 무매치 → C-2에서 실측한 "Cannot {METHOD} {path}" 404 패턴과 동일 경로.
- 부수 불일치: web은 body `{reason}` 전송+`{deletedAt}` 기대, 서버는 body 미수신+`{deleted, message}` 반환(응답은 호출부에서 미사용이라 경로만 고치면 동작).
- 픽스: api.ts 경로를 `/authors/me`로 1줄 수정(+타입 정리) | 규모 **XS**

### C-2 | 🔴 | 계약불일치(⑤ 라우트 부재) | web `app/shared/[token]/page.tsx:18` + `src/lib/api.ts:314` | **공유 링크 열람이 항상 404** — web은 `GET /api/episodes/shared/{token}`, 서버는 `GET /api/shared/:token`(content.controller.ts:69)
- 근거(라이브 실측 2026-07-11): `GET dev-api…/api/shared/bogus` → 404 `{"message":"공유 링크를 찾을 수 없습니다"}`(비즈니스 404=라우트 존재) vs `GET dev-api…/api/episodes/shared/bogus` → 404 `{"message":"Cannot GET /api/episodes/shared/…"}`(라우트 부재).
- 히스토리: 서버 라우트는 `shared/:token`으로 탄생(33e4c64, 2026-03-31), web 페이지는 `episodes/shared`로 탄생(b51b17c, 2026-04-05) — **태어날 때부터 불일치**, `git log -S "episodes/shared"` server 히트 0. 공유 링크 생성 UI(createShareLink)는 정상이므로 작가가 만든 링크가 전부 죽은 링크.
- 픽스: page.tsx:18 + api.ts:314 경로를 `/shared/${token}`으로 수정 (api.ts getSharedEpisode는 미사용 데드 — C-14 겸) | 규모 **XS**

### C-3 | 🔴 | 계약불일치(③ 응답 shape 정합 실패) | web `app/dashboard/credits/page.tsx:21-25,131-141` + `src/types/api.ts:126-132` | **포인트 충전 페이지 렌더 크래시** — 서버 products는 CC-2a(5/20) 이후 `{id,name,points,bonusRate,price,pricePerPoint}` 반환하는데 web은 구 `{credits, pricePerCredit}` 사용
- 근거(라이브 실측): `GET dev-api…/api/payments/products` → `[{"id":"credit-starter",…,"points":25000,…,"pricePerPoint":0.12},…]` — `credits`/`pricePerCredit` 키 부재. 페이지는 `creditsToPoints(product.credits)`(→NaN 표기) 후 `(product.pricePerCredit).toLocaleString()` — **undefined.toLocaleString() TypeError로 렌더 사망**. 베스트 배지 조건도 구 id `credit-50`(현행 id는 credit-starter/basic/popular/best).
- 시점: 페이지 최종 수정 3e9bb06(5/17) < 서버 필드 개명 CC-2a(5/20) — 5/20부터 회귀. **충전(매출 유입) 경로 차단**이라 최우선.
- 픽스: Product 타입/렌더를 `points`/`pricePerPoint`/신 id 4종으로 갱신(+catch 폴백 상품 3종도 구형 — 함께 교체) | 규모 **S**

### C-4 | 🔴 | 계약불일치(③ 요청 값 도메인 불일치) | web `app/[author]/profile/page.tsx:196-198` + `features/reader/ui/EpisodeFooter.tsx:209-217,273` | **응원 선물이 두 진입점 모두 항상 400** — web은 `amount ∈ {1,3,5}` 전송, 서버는 `GIFT_POINT_OPTIONS=[1000,3000,5000]`(pt)만 허용
- 근거: server `domain/model/gift-points.ts:18` + `social.usecase.ts:126-138` `isGiftPointOption(amount)` 실패 시 400 throw. web 두 곳 모두 `[1,3,5].map(...)` UI. catch가 "선물 실패 (로그인 필요)"로 오도(로그인해도 실패).
- 참고: PLANNING §8은 아직 "1/3/5 크레딧"(구 단위) — CC-2b §6 결정(1,000/3,000/5,000pt, api-contract L251)이 정본. C-13과 연동.
- 픽스: web 선택지 `[1000,3000,5000]`pt + 라벨 pt 표기(+실패 메시지 서버 message 표출) | 규모 **XS~S**

### C-5 | 🔴 | 계약불일치(③ DTO 화이트리스트) + 미구현gap | web `app/dashboard/chat/page.tsx:88-96` → server `adapter/inbound/http/dto/work.dto.ts:10-14` | **AI 채팅 "프로젝트 메모리/작품 지침" 저장이 항상 400 + 무증상 삼킴** — web은 `PATCH /works/:id`에 `{context, instructions}` 전송, `UpdateWorkDto`는 title/subtitle/description 3필드뿐 + 글로벌 ValidationPipe `forbidNonWhitelisted:true`(main.ts:57-61) → "property context should not exist" 400
- 근거: usecase 시그니처도 `{title?,subtitle?,description?}`(application/work/work-management.usecase.ts:43) — **서버 어디에도 context/instructions 쓰기 경로 없음**(git -S 히트 0). 반면 chat.usecase.ts:88은 `work.context`를 시스템 프롬프트에 주입(읽기 경로만 존재), 로딩도 정상(`getWorkDetail`이 context 포함 — prisma-work.repository.ts:287-289). page.tsx:94 `catch {}`가 실패를 완전 은폐(사용자는 저장된 줄 앎).
- 픽스: UpdateWorkDto에 `@IsOptional @IsString context?/instructions?` 추가 + usecase input 확장(소유권 검증 기존 재사용) + web catch에 에러 토스트 | 규모 **S**

### C-6 | 🔴 | 계약불일치(전송 계층 파손) | web BFF `src/app/api/[...path]/route.ts:55` | **BFF가 모든 non-GET body를 `await request.text()`로 통과** — multipart **바이너리**(docx/hwp/hwpx 업로드 `lib/api.ts:334`, 커버 이미지 PUT `lib/api.ts:546`)가 UTF-8 lossy 디코드(U+FFFD 치환)로 **파손**
- 근거: 두 업로드 모두 'use client' 경로라 `/api`(BFF) 경유(WorkList.tsx:148, useUploadPage.ts:145). `Request.text()`의 비-UTF-8 바이트 치환은 Web 표준의 결정적 동작 — ZIP(docx)/이미지엔 무효 시퀀스가 반드시 존재. .md/.txt(순수 텍스트 multipart)만 무손실이라 지금까지 잠복했을 개연성(운영 콘텐츠는 md 중심).
- 미실측 고지: 인증 필요 구간이라 라이브 업로드 실측은 미수행 — 단 코드 경로·디코드 손실은 구조적 확정. 6/26 커버업로드 DI 결함(2855e2f) 수정 후에도 이 계층은 그대로.
- 픽스: BFF에서 `request.body`(stream)/`arrayBuffer()` 패스스루(+`duplex:'half'`), Content-Type 무관 바이너리 안전화 | 규모 **S**

## 🟠 HIGH (4건)

### C-7 | 🟠 | 계약불일치(③ 응답 shape) | web `app/dashboard/credits/page.tsx:28-34,187-195` | **크레딧 사용 내역 표시 파손 2중** — ① 서버 `/credits/logs`는 CC-3 이후 `CreditLedgerEntry[]`(`reason` 필드, credit.usecase.ts:174-179)인데 web은 `log.description` 렌더 → 내역 설명 전부 공란 ② `formatPoints(creditsToPoints(log.amount))` — ledger amount는 이미 pt인데 ×1,000(credit-overhaul.ts:148) → **1,000배 인플레 표기**(3,000pt 선물이 "3,000,000 pt")
- 근거: api-contract L254(응답 형태 변경 명세) vs page 인터페이스 `CreditLog{description…}`. 픽스: `reason` 매핑(한글 라벨화) + amount 원값 표기 | 규모 **XS~S**

### C-8 | 🟠 | stub방치(무증상 실패) | server `adapter/outbound/persistence/prisma-admin.repository.ts:135-136` | **신고 승인 모더레이션이 거짓 성공 가능** — `hideEpisode`/`deleteCommentById`가 `.catch(() => {})`로 DB 오류 통삼킴, 호출부 admin.usecase.ts:319-322는 그대로 신고 resolved+AuditLog `report_resolve` 박제 → 대상 콘텐츠가 공개로 남아도 "처리 완료"
- 픽스: catch 제거(에러 전파) 또는 실패 시 resolve 중단+audit에 실패 박제 | 규모 **XS**

### C-9 | 🟠 | 미구현gap(⑥ 서버만 존재) | server `theme.controller.ts:169 GET /themes/resolve/:authorSlug` ↔ web 호출 0건 | **작품별 테마가 독자 화면에 절대 반영 안 됨** — 대시보드에서 작품에 테마 배정(`assignThemeToWork`, api.ts:150 사용 중)은 되는데, 독자 경로(`app/[author]/layout.tsx:33`, `[slug]/[episode]/page.tsx:20`)는 작가 기본 테마(`/themes/{slug}`)만 로드. PLANNING §8 우선순위("작품 전용 > 작가 기본 > midnight") 위반 — resolve 엔드포인트는 이를 위해 만들어졌으나 web 소비자 0(grep "resolve/" web 히트 0)
- 픽스: 작품/에피소드 페이지에서 `?work=` resolve 호출로 교체 | 규모 **S~M**

### C-10 | 🟠 | 계약불일치(② 문서 누락 14건 + ③ 문서 stale 5건) | `grimoire-server/docs/api-contract.md` | **api-contract 정본에서 코드 현행 이탈**
- ② 코드에 있는데 문서에 없음(14): `POST /auth/refresh`(auth.controller.ts:180 — web 자동갱신이 매일 쓰는 핵심 경로!) · `GET /episodes/:episodeId/raw`(web 인라인 편집 사용 중) · admin 12종 `GET stats/timeseries`/`GET·POST·DELETE announcements`/`GET·POST·DELETE featured`/`GET revenue`/`GET·POST·PATCH·DELETE themes`(전부 web admin 탭이 실사용 — api.ts:730-763)
- ③ 문서가 구현과 다름(5): L95 Plan절 `POST /admin/authors/:id/plan` → 실제 `@Patch`(admin.controller.ts:226, 같은 문서 L276은 PATCH — 내부 모순) · L397 themes/generate 요청 `{authorId, description}` → 실제 DTO `{description, name?}`(JWT 귀속) · L539 episodes 생성 `{title, slug, blocks, rawMd}` → 실제 `{title, rawContent, sourceFormat}`(work.dto.ts:16-20) · L906 analysis/index 응답 `{indexed:true}` → 실제 `{chunkCount, tokensUsed}`(novel-analysis.usecase.ts:38) · L315/916 분석 "3 크레딧" → 실제 `ANALYSIS_POINT_COST=2440pt`(chat-charge-tier.ts:47, usecase:155) — 4/27 "4크레딧" 인상 이력과도 불일치. discover 페이지네이션(page/pageSize — 서버 지원+web 사용)도 미문서
- 픽스: api-contract 1회 정비 커밋(server 정본 → web 동기화) | 규모 **S**

## 🟡 MEDIUM (5건)

### C-11 | 🟡 | 미구현gap(untracked) | PLANNING §13 "원고 관리 — 순서 변경" ↔ 서버·web 전무 | **에피소드 순서 변경 수단 없음** — orderNum은 생성 시 자동 부여뿐, reorder 엔드포인트 0(컨트롤러 grep), web UI도 표시만(dashboard/episodes) | 픽스: `PATCH /works/:id/episodes/reorder` + 목록 드래그 | 규모 **M**

### C-12 | 🟡 | 미구현gap(untracked) | server `POST /auth/change-password`(auth.controller.ts:217, 문서 L54) ↔ web 호출 0건 | **비밀번호 변경 UI 부재**(프로필 페이지에 진입점 없음). 유사: 이메일 인증/비번 리셋 4종도 web UI 0 — 발송은 추적된 외부 게이트지만 **"env 1줄로 라이브" 주장에 web 화면 부재는 미추적 선행 결핍** | 규모 **S(변경)+M(리셋 플로우)**

### C-13 | 🟡 | 계약불일치(문서 stale — 역방향 포함) | `PLANNING_GRIMOIRE.md` | 최상위 정본이 크레딧 개편(5/17~5/22) 미반영: §8 선물 "1/3/5 크레딧"(→1,000/3,000/5,000pt) · §8/§0 구 패키지(5/20/50개·₩2,000/3,000/5,000 — 현행 4종 ₩3,000~30,000) · §14 미결 "[ ] AI 채팅 크레딧 연동(현재 무료)" — **실제로는 4구간 사후차감 구현 완료**(chat.usecase.ts:157-179, 역방향 stale) · Phase 5 "[ ] AI 피드백 탭 웹 UI 미연결" vs §14 표 "구현 완료"(내부 모순, /dashboard/analysis 존재) ※ §16 규칙상 PLANNING 갱신은 사용자 명시 필요 — 승인 대기 항목으로만 등재 | 규모 **S(문서)**

### C-14 | 🟡 | 데드코드+stale 타입 | web `src/lib/api.ts` | 정의만 있고 호출 0 + 타입도 구형: `getCredits`(:231, `{credits}` — 실제 CreditBalanceResponseDto) · `getCreditBalance`(:447, 동일 stale) · `getSharedEpisode`(:313, C-2 경로 오류 포함) · `getMembership`(:811, `{monthlyPool, used}` — 서버는 `{monthlyPoolPoints, poolBalance, poolResetAt, status…}` subscription.dto.ts:37-50) · `giftCredits` 반환 타입 `{senderCredits, receiverCredits}`(실제 `{senderSpentBySource, receiverGiftBalance}`, 호출부는 응답 미사용이라 잠복) · `adminForceDelete/anonymize` 반환 `{deletedAt}/{anonymizedAt}`(실제 `{deleted,message}` 등) | 부수: 멤버십 페이지가 getMembership을 안 써 **현재 등급/풀 현황 UI 자체가 없음**(plans+checkout만) | 픽스: 제거 또는 타입 현행화 | 규모 **S**

### C-15 | 🟡 | 의도 확인 필요(⑥) | server 전용 엔드포인트 | web 미사용 4종: `GET /payments/history`(사용자 결제내역 화면 없음 — admin만 존재) · `POST /credits/gift`+`GET /credits/ranking`(web은 social/gift·discover/most-gifted 경유 — 중복 표면, receiverId 노출형이라 정리 후보) · `GET /admin/works/:wid/episodes/:eid`(admin UI 미사용) | 픽스: 유지 의도 문서화 or 제거 | 규모 **XS~S**

## 🟢 LOW (3건)

### C-16 | 🟢 | 데드코드 | agent 스윕(전수 grep 검증) | **미사용 export 상위 18** — Tier1(참조 0): web `AfterwrdViewer`/`EpisodeNav`/`HorizontalScroll`/`PageFlipTransition`/`PrefaceViewer`/`useNavigationStore`, server `isAborted`(lib/abort.ts:22)/`isAuthorDeleted`(author.ts:56)/`isPlanExpired`(plan.ts:2, JSDoc 스스로 대체됨 명시)/`themePresets`(theme-presets.ts:230 — 서버 전체 파일 데드, web 자체 사본 사용)/`DEFAULT_USER_SOFT_DELETE_POLICY`(:36). Tier2(spec만 참조 7): `getPromptInjectionPatternCount`/`resolveChatChargePoints`/`isPolarSuccessStatus`/`isPolarRefundedStatus`/`pointsToCredits`/`totalBalance`/`MEMBERSHIP_PRICE_KRW` | 규모 **S(일괄 정리)**

### C-17 | 🟢 | 영구 off 분기 | server `domain/policy/user-soft-delete-policy.ts:52` | `GDPR_ANONYMIZE_SCOPE` strong/strongest 분기(default-user-anonymizer.adapter.ts:48-55)가 어느 환경에도 미설정(env.example/Dockerfile/INFRASTRUCTURE.md 부재) — 코드 주석 스스로 "향후 확장" 명시라 의도적 잠복. 메모만 | 규모 **XS**

### C-18 | 🟢 | 문서 미세 lag | `.claude/shared-contracts.md` §14 | cron 스니펫 `@Cron('0 0 4 * * *')`에 PAY-S7(6월)로 코드에 추가된 `{ timeZone: 'Asia/Seoul' }` 미반영(payment-cleanup.job.ts:46) — §14만 잔존, api-contract/eval은 반영됨 | 규모 **XS**

---

## 축별 요약

| 축 | 결과 |
|---|---|
| 1. 3-way 계약 diff | ①문서만 존재 1(POST plan — 방법 오기) · ②코드만 존재 **14** · ③시그니처/shape 불일치 **12**(라이브 5: C-3/4/5/7 + doc 5 + 잠복 타입 다수) · ④에러코드류 1(분석 크레딧 문구) · **⑤웹 호출↔서버 부재 = 2건(C-1, C-2) + 전송계층 파손 1(C-6)** · ⑥서버만 존재 ~8(C-9 포함) |
| 2. 기획 vs 구현 | untracked gap 3: 작품별 테마 독자 미적용(C-9) · 에피소드 순서 변경(C-11) · 비밀번호 변경/리셋 web UI(C-12). 역방향 stale 2(채팅 차감·피드백 탭 — C-13). 일일 무료 생성 쿼터·첫작품 보너스·SocialAccount/SignupHistory는 **구현 확인 PASS** |
| 3. TODO/stub | 영어 TODO/FIXME 0(비영어 코드베이스). 방치 시 폭발 (a)급 3: admin 모더레이션 삼킴 2(C-8) + chat 설정 저장 삼킴(C-5 내). abort 시 AI 토큰 비용 누수는 문서화된 트레이드오프(🟢) |
| 4. shared-contracts 표본 | §11 멱등성 · §12 recon cron · §14 재사용 · §17 부분환불(PAY-S2 누적한도 aggregate 실재) · §27 CB(env 4종+화이트리스트) · §29 soft-delete(30일 cron+4필드 익명화) · §30 크레딧(1:1000·소진순서·2440/590·풀 93k/191.5k·채팅 190/810/3390/5520 — server=web 상수 일치) → **7/7 PASS**, 예외 §14 timeZone 스니펫(C-18) |
| 5. Prisma↔data-model 신규 drift | **0건** — 6/27 이후 schema.prisma·data-model.md 커밋 0(마지막 2026-05-27 2bafb4f) |
| 6. 영구 off/데드 | env 사실상 1(C-17, 의도적) · 미사용 export 18(C-16) · stale 클라이언트 메서드 6(C-14) |

## 권장 처리 순서
1. **C-3**(충전 페이지 크래시 — 매출 직결, XS~S) → 2. **C-1/C-2**(탈퇴·공유 404 — 각 1~2줄) → 3. **C-4**(선물 400) → 4. **C-5**(프로젝트 메모리 — DTO+usecase+web 토스트) → 5. **C-6**(BFF 바이너리 — 업로드 신뢰성) → 6. C-7/C-8 → 7. C-10 문서 정비 커밋 → 8. C-9/C-11/C-12 스프린트化 → 9. C-13 PLANNING 갱신(사용자 승인 게이트) → 10. C-14~C-16 정리.

> 검증 한계 고지: C-1(DELETE 라이브 curl은 권한 정책상 미수행 — 정적 라우트 테이블+동일 404 패턴으로 확정), C-6(인증 필요로 업로드 실측 미수행 — 디코드 손실은 표준 동작으로 확정). 나머지 라이브 주장 2건(C-2, C-3)은 dev-api 실측 완료.
