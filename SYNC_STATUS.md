# SYNC_STATUS.md — 서버-웹 연결 현황

> 서버 API 구현 대비 웹 연결 상태 정본.
> 서버 기능 추가 또는 웹 연결 시 이 문서를 업데이트한다.
> 각 레포 TECH_STATUS.md는 레포 내부 구현 상태만 기록한다.
>
> **마지막 갱신: 2026-05-03 #10_7 (작업 C, P1-#7)**. server publishTheme bakedCssUrl 절대화 — 응답은 항상 절대 URL (Blob CDN 또는 폴백 절대 URL). web 동기화는 web agent가 진행 (`grimoire-web/src/app/[author]/layout.tsx` 주석 정리 + types).

---

## 연결 상태 범례

| 기호 | 의미 |
|------|------|
| ✅ | 서버 구현 + 웹 연결 완료 |
| ⚠️ | api.ts 메서드 있음, UI 미구현 |
| ❌ | api.ts 없음, UI 없음 |

---

## 기능별 싱크 현황

| 기능 | 서버 | api.ts | UI 페이지 | 상태 |
|------|------|--------|-----------|------|
| 회원가입 / 로그인 / 로그아웃 | ✅ | ✅ | `/login`, `/register` | ✅ |
| Google OAuth | ✅ | ✅ | `/login` | ✅ |
| 테마 생성/수정/조회 | ✅ | ✅ | `/dashboard/theme` | ✅ |
| 테마 개별 조회 (detail/:themeId) | ✅ | ✅ | `/dashboard/theme?id=` | ✅ |
| 테마 퍼블리시 (CSS Baking) | ✅ | ✅ | `/dashboard` | ✅ |
| 테마 슬롯 관리 (활성/보관) | ✅ | ✅ | `/dashboard` | ✅ |
| 원고 텍스트 파싱 | ✅ | ✅ | `/dashboard/upload` | ✅ |
| 원고 파일 업로드 (md/txt/docx/hwp) | ✅ | ✅ | `/dashboard/upload` | ✅ |
| 작품 CRUD | ✅ | ✅ | `/dashboard/upload` | ✅ |
| 에피소드 CRUD | ✅ | ✅ | `/dashboard/upload` | ✅ |
| **커버 이미지 업로드** | ✅ | ✅ | `/dashboard` 작품 목록 커버 버튼 | ✅ |
| 작가 공간 조회 | ✅ | ✅ | `/[author]` | ✅ |
| 작가 프로필 조회/수정 | ✅ | ✅ | `/[author]/profile`, `/dashboard/profile` | ✅ |
| 작품 조회 | ✅ | ✅ | `/[author]/[slug]` | ✅ |
| 에피소드 뷰어 | ✅ | ✅ | `/[author]/[slug]/[episode]` | ✅ |
| 탐색 (인기/최신/검색) | ✅ | ✅ | `/explore` | ✅ |
| 좋아요 | ✅ | ✅ | `EpisodeFooter` | ✅ |
| 댓글 (대댓글 포함) | ✅ | ✅ | `EpisodeFooter` | ✅ |
| 구독 | ✅ | ✅ | `/[author]/profile` | ✅ |
| **북마크** | ✅ | ✅ | `EpisodeFooter` 버튼 추가 | ✅ |
| **읽기 진행도** | ✅ | ✅ | `EpisodeFooter` 진입 시 저장 | ✅ |
| 서재 (북마크 목록) | ✅ | ✅ | `/library` | ✅ |
| 크레딧 선물 | ✅ | ✅ | `EpisodeFooter` | ✅ |
| 크레딧 잔액 조회 | ✅ | ✅ | `/dashboard/credits` | ✅ |
| **결제 (Polar)** | ✅ | ✅ | `/dashboard/credits` (KYC 전 test mode) | ⚠️ KYC 대기 |
| 관리자 통계 | ✅ | ✅ | `/admin` | ✅ |
| 관리자 크레딧 부여 | ✅ | ✅ | `/admin` | ✅ |
| **작품 분석 (조회수/좋아요/구독)** | ✅ | ✅ | `/dashboard/analytics` | ✅ |
| **AI 채팅 (세션/메시지/RAG)** | ✅ | ✅ | `/dashboard/chat` | ✅ |
| **구독 플랜 조회** | ✅ | ✅ | `/dashboard/theme` 배너 | ✅ |
| **테마 슬롯 관리** | ✅ | ✅ | `/dashboard/theme` 활성/보관 | ✅ |
| **AI 테마 생성** | ✅ | ✅ | `/dashboard/theme` AI 생성 버튼 | ✅ |
| Analysis (RAG 일관성 체크) — **분석 4 크레딧/회 (2026-04-27 인상)** | ✅ | ✅ | `/dashboard/analysis` | ✅ |
| **테마 활성화 (defaultThemeId 설정)** | ✅ | ✅ | `/dashboard/theme`, `/dashboard` | ✅ |
| **작품별 테마 배정** | ✅ | ✅ | api.ts 메서드 | ⚠️ UI 미구현 |

---

## 미연결 기능 우선순위

| 순위 | 기능 | 작업 |
|------|------|------|
| 1 | ~~결제 (Polar)~~ | ✅ 연동 완료 (KYC 대기) |
| 2 | ~~원고 파일 업로드~~ | ✅ api.ts + UI 연결 완료 |
| 3 | ~~읽기 기능 UI 연결~~ | ✅ 좋아요/북마크/댓글 전부 연결 완료 |
| 4 | ~~RAG 일관성 체크 UI~~ | ✅ `/dashboard/analysis` 연결 완료 |
| 5 | 작품별 테마 배정 UI | api.ts 메서드 있음, 대시보드 UI 미구현 |
| 6 | AI 채팅 1턴 크레딧 차감 연동 | 현재 무료 사용 — Polar payout 후 P1 (cost-accountant 검증 필요) |

---

## 참조

- `grimoire-server/TECH_STATUS.md` — 서버 구현 상태
- `grimoire-web/TECH_STATUS.md` — 웹 구현 상태
- `docs/api-contract.md` — 전체 API 명세 (정본: server)
