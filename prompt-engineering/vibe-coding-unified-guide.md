# 작업 단계·인계 참고자료

> 개발 초기 AI에 제공한 참고 본문이다. [구상과 실제 활용 과정](README.md)을 먼저 읽는다. 아래 예시의 명령은 현재 실행 지시가 아니다.

---

# 바이브코딩 통합 프롬프트 가이드
## 셋업 + 프로토타이핑 + 작업 워크플로우

---

## 📌 개요

하나의 세션에서 작업하되, 세션이 무거워지면 새 세션으로 교체한다.
세션 교체 시 맥락 복원은 **PROGRESS.md + 프로젝트 문서**가 담당한다.

### 핵심 파일 체계

| 파일 | 성격 | 자동 로딩 |
|------|------|-----------|
| CLAUDE.md | 글로벌 코딩 규칙 (프로젝트 무관) | ✅ 자동 |
| PRD.md | 프로젝트 정체성 + 기능 명세 | ❌ 수동 |
| DESIGN.md | 디자인 시스템 | ❌ 수동 |
| docs/architecture.md | 기술 설계 | ❌ 수동 |
| docs/PROGRESS.md | 진행 상황 + 핸드오프 | ❌ 수동 (**가장 중요**) |

### 세션 교체 규칙

세션이 무거워지면 (컴팩션 2회 이상) 새 세션을 만들고 아래 프롬프트를 **먼저** 실행하여 맥락을 복원한다.
복원 후 원하는 작업을 별도의 슬래시 명령어로 지시한다.

> 📋 **복사용 프롬프트:**

```
/sc:load @docs/PROGRESS.md @PRD.md @DESIGN.md @docs/architecture.md "이 프로젝트의 진행 상황, 기술 스택, 설계 구조, 디자인 시스템을 파악하고 현재 상태를 요약해줘." --deep --summary
```

모든 작업이 끝나면 반드시 PROGRESS.md를 업데이트한다.

### 완료 시 산출물

- 기본 문서: `CLAUDE.md`, `PRD.md`, `DESIGN.md`
- 서브에이전트: `.claude/agents/*.md` (7개)
- 설계 문서: `docs/prd-analysis.md`, `docs/architecture.md`
- 실행 가능한 프로토타입 코드 (P0 기능 전체 구현)
- 시드 스크립트: `scripts/seed.ts` (admin + 데모 계정 + 목데이터, `npm run seed`로 실행)
- `README.md`, `docs/integration-report.md`, `docs/test-report.md`, `docs/PROGRESS.md`
- Git 커밋 + Vercel 배포 완료

---
---

# PART 0: 기존 프로젝트 이어받기 (클론 + 방법론 마이그레이션)

GitHub에 이미 올라가 있는 프로젝트를 새 세션에서 이어받아 작업할 때 사용한다.
Desktop 앱에서 **프로젝트 이름과 동일한 빈 폴더를 선택**한 뒤 아래 프롬프트를 입력한다.
클론과 동시에 방법론 파일(서브에이전트, PROGRESS.md 등)이 누락되어 있으면 자동으로 생성한다.

> 📋 **복사용 프롬프트:**

```
/sc:implement "현재 폴더명을 확인하고, 내 GitHub 계정에서 같은 이름의 레포지토리를 찾아서 클론하고 작업 환경을 셋업해줘.

── 1. 클론 + 환경 셋업 ──

1. 현재 디렉토리명 확인 (basename $(pwd))
2. gh repo list --limit 100 --json name,url 로 내 레포 목록에서 폴더명과 일치하는 레포 검색
3. 찾으면 git clone {URL} . (현재 디렉토리에 클론), 못 찾으면 알려줘
4. npm install (또는 패키지 매니저에 맞게)
5. .env.example이 있으면 .env.local로 복사하고 필요한 환경변수 목록을 알려줘
6. npm run dev로 정상 실행되는지 확인
7. 실행 에러가 있으면 즉시 수정

── 2. 방법론 마이그레이션 ──

프로젝트 전체를 분석하고, 아래 파일이 없으면 기존 코드를 분석하여 새로 생성해줘:

- CLAUDE.md: 9개 카테고리(1-1~1-9)로 글로벌 코딩 규칙 작성 (200줄 이하)
- PRD.md: 기존 코드에서 역추출하여 2-1~2-11 구조로 작성
- DESIGN.md: 기존 UI에서 역추출하여 3-1~3-11 구조로 작성
- docs/architecture.md: 기존 코드 구조를 분석하여 아키텍처 문서화
- docs/prd-analysis.md: PRD.md 기반 P0/P1/P2 분류 + AC + 의존 관계
- docs/PROGRESS.md: 현재 상태를 기록
  ## 방법론 마이그레이션 (날짜)
  ### 현재 상태 — 구현된 기능, 배포 URL, 기술 스택
  ### 기술 결정 — 인증, DB, API 응답 포맷
  ### 알려진 이슈 / TODO
  ### 다음 작업 후보
- .claude/agents/ 디렉토리에 서브에이전트 7개:
  prd-analyst, architect, frontend-dev, backend-dev, integrator, code-reviewer, test-writer
  각각 YAML 프론트매터 + 시니어 엔지니어 관점의 상세 프로세스를 본문에 작성

이미 존재하는 파일은 아래 기준에 맞는지 확인하고, 부족하면 보완해줘:
- CLAUDE.md: 1-1~1-9 카테고리 구조인지, 200줄 이하인지
- PRD.md: 2-1~2-11 구조를 빠짐없이 갖추고 있는지
- DESIGN.md: 3-1~3-11 구조를 갖추고 있는지
- 기존 내용은 최대한 보존하고, 누락된 섹션만 추가

── 3. 검증 + 상태 요약 ──

echo '=== 기본 문서 ===' && for f in CLAUDE.md PRD.md DESIGN.md; do [ -f \"\$f\" ] && echo \"✅ \$f\" || echo \"❌ \$f\"; done && echo '' && echo '=== 설계 문서 ===' && for f in docs/architecture.md docs/prd-analysis.md docs/PROGRESS.md; do [ -f \"\$f\" ] && echo \"✅ \$f\" || echo \"❌ \$f\"; done && echo '' && echo '=== 서브에이전트 ===' && for f in prd-analyst architect frontend-dev backend-dev integrator code-reviewer test-writer; do [ -f \".claude/agents/\$f.md\" ] && echo \"✅ \$f\" || echo \"❌ \$f\"; done

모든 파일이 확인되면 마이그레이션 완료를 선언하고, 프로젝트 현재 상태를 요약해줘." --persona-architect
```

> 💡 폴더명이 `place-manager`이면 GitHub에서 `place-manager` 레포를 자동으로 찾아 클론한다.
> 💡 클론 후 상태 요약이 출력되면, 이어서 PART 2의 원하는 작업 번호 명령어를 실행한다.
> 💡 기존 코드가 레이어 구조를 따르지 않더라도, 이 단계에서는 리팩터링하지 않는다. CLAUDE.md에 현재 구조를 기록하고, 리팩터링은 별도 작업으로 진행한다.

---
---

# PART 1: 셋업 프롬프트 (신규 프로젝트)

Desktop 앱에서 프로젝트 폴더 선택 후, 아래 프롬프트를 **PRD 파일과 함께** 입력한다.
Phase 0(문서 생성) → Phase 1(분석+설계) → Phase 2(백엔드) → Phase 3(프론트엔드) → Phase 4(통합+테스트) → Phase 5(배포)까지 한번에 수행된다.

> 📋 **복사용 프롬프트: (여기서부터 `지금 Phase 0부터 시작하세요.` 까지 전체가 하나의 프롬프트)**

```
/sc:implement "프로덕션 전환을 전제한 고품질 프로토타입을 개발해줘. 프로젝트 정보는 이 프롬프트와 함께 첨부한 PRD 파일만 참고하고, 추가 입력을 요구하지 마. 기술 스택: Next.js (App Router), Vercel, Supabase, shadcn/ui + Tailwind CSS.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ 핵심 행동 원칙 (이 프롬프트에서 가장 중요)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

<core_principles>
P1. 최소 구현: 요청한 것만 구현. 임의 UI 개선, 추가 API, 부가 기능 금지.
P2. 레이어 구조: API Route(HTTP만) → lib/services/(비즈니스) → lib/repositories/(Supabase). 역방향 금지.
P3. 근본 원인 해결: try-catch 삼키기, any 변환, 기능 비활성화 금지. 원인을 찾아 고친다.
P4. Phase 순차 실행: Phase 0→5를 게이트 체크 통과하며 순서대로. 모든 Phase 완료까지 멈추지 않는다.
P5. PROGRESS.md 필수: 작업 완료 후 docs/PROGRESS.md를 반드시 생성/업데이트한다.
</core_principles>


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Phase 0: 프로젝트 셋업
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

첨부한 PRD 파일을 정독한 뒤, 아래 파일들을 빠짐없이 생성하세요.

<phase0_documents>

── PART A: 기본 문서 3개 ──

### 1. CLAUDE.md — 글로벌 코딩 규칙 (200줄 이하)

어떤 프로젝트에서든 지켜야 할 대원칙. 아래 9개 카테고리를 각각 구체적 실행 규칙 2~5개로 풀어서 작성하세요. 장황한 예시 코드는 넣지 마세요.

1-1. 언어 원칙 — 한글 사용, 코드 식별자는 영어(camelCase/PascalCase)
1-2. 코드 작성 — Google TS 스타일, ESLint+Prettier, no-any, no-console, 단일 책임, 함수 50줄/파일 300줄 제한, 네이밍 규칙(컴포넌트 PascalCase, 유틸 camelCase, 상수 UPPER_SNAKE, API kebab-case)
1-3. 아키텍처 — app/api/ → lib/services/ → lib/repositories/ 레이어 구조, RESTful, 역방향 의존 금지
1-4. 최소 구현 — 요청한 것만, 임의 추가 금지, 변경 범위 최소화
1-5. 트러블슈팅 — 근본 원인 해결, 금지 패턴(try-catch 삼키기, any 변환, 기능 비활성화), 재발 방지를 CLAUDE.md에 추가
1-6. 토큰 효율 — .md 남발 금지, 주석은 "왜"만, 명확한 네이밍 우선
1-7. 과도한 일반화 금지 — YAGNI, 3곳 이상 사용 시에만 추상화
1-8. 버전 관리 — "[타입] 한국어 설명", 하나의 커밋 = 하나의 논리적 변경
1-9. 추가 원칙 — (빈 섹션, 트러블슈팅 교훈이 여기에 누적)

### 2. PRD.md — 요구사항정의서

첨부 PRD 기반. 이 파일을 그대로 프롬프트로 입력하면 동일한 결과물이 나올 수 있어야 합니다.
구조: 2-1 프로젝트 개요, 2-2 페르소나(2개+), 2-3 기능 명세(F-001~, P0/P1/P2, AC 3개+), 2-4 사용자 플로우, 2-5 기술 스택, 2-6 데이터 모델, 2-7 API 설계, 2-8 라우트 맵, 2-9 디렉토리 구조, 2-10 비기능 요구사항, 2-11 MVP 경계([PROD-TODO])

### 3. DESIGN.md — 디자인 시스템 (프리미엄 수준)

shadcn/ui 기반이되, **실제 상용 SaaS/스타트업 랜딩페이지 수준의 고급 디자인**을 목표로 합니다.
"프로토타입처럼 보이면 안 된다"가 디자인 원칙입니다.

구조:
3-1. 디자인 철학 — 프리미엄 감성, 여백 중심 레이아웃, 시선 흐름 설계
3-2. 기술 스택 — shadcn/ui 컴포넌트, Tailwind, Lucide 아이콘, 한글 웹폰트(Pretendard/Noto Sans KR), Framer Motion 마이크로 인터랙션
3-3. 컬러 시스템 — Primary/Secondary/Accent/Neutral/Semantic, 브랜드 그라데이션, 라이트/다크 모드
3-4. 타이포그래피 — 한글/영문 폰트 페어링, Display/Heading/Body/Caption 사이즈 스케일, font-weight 활용
3-5. 스페이싱/레이아웃 — 넉넉한 여백(padding 24px+), max-w-7xl 컨테이너, 12컬럼 그리드, 반응형 브레이크포인트
3-6. 컴포넌트 가이드 — 버튼(호버/액티브 애니메이션), 카드(그림자+호버 리프트), 모달(백드롭 블러), 토스트, 테이블, 네비게이션(스크롤 반응)
3-7. 히어로/랜딩 패턴 — 히어로 섹션(대형 타이틀+서브카피+CTA+비주얼), 기능 소개 그리드, 사회적 증거(로고/후기), 가격표, FAQ 아코디언, 풋터
3-8. 이미지/비주얼 전략 — Unsplash/Pexels 실사 이미지 활용, Next.js Image 최적화, placeholder blur, 아이콘은 Lucide 통일, 필요시 일러스트레이션
3-9. 마이크로 인터랙션 — 페이지 전환 애니메이션, 스크롤 기반 페이드인, 호버 효과, 로딩 스켈레톤, 부드러운 상태 전환
3-10. 레퍼런스 — 벤치마크 웹사이트 URL + 참고 포인트
3-11. 변경 이력

── PART B: 서브에이전트 7개 ──

`.claude/agents/` 디렉토리에 아래 7개 파일을 생성하세요.
각 파일은 YAML 프론트매터 + 본문(시스템 프롬프트)으로 구성합니다.
각 에이전트의 역할에 맞는 시니어 엔지니어 관점의 **상세한 프로세스, 코딩 규칙, 출력 규칙**을 본문에 작성하세요.
모든 에이전트에 CLAUDE.md/PRD.md/DESIGN.md 준수 및 한국어 작업 지침을 포함하세요.

| 파일명 | name | description | tools | model |
|--------|------|-------------|-------|-------|
| prd-analyst.md | prd-analyst | PRD 분석 → 기능 구조화 → docs/prd-analysis.md 생성 | Read,Grep,Glob,Bash | sonnet |
| architect.md | architect | 아키텍처 설계 → 디렉토리/설정 생성 → docs/architecture.md | Read,Write,Edit,Bash,Glob,Grep | sonnet |
| frontend-dev.md | frontend-dev | UI/페이지/상태관리 구현 (shadcn/ui, App Router) | Read,Write,Edit,Bash,Glob,Grep | sonnet |
| backend-dev.md | backend-dev | API/서비스/리포지토리 구현 (Supabase, zod) | Read,Write,Edit,Bash,Glob,Grep | sonnet |
| integrator.md | integrator | 프론트↔백 연결, 플로우 검증, "npm run dev로 전부 동작" 달성 | Read,Write,Edit,Bash,Glob,Grep | sonnet |
| code-reviewer.md | code-reviewer | 품질/보안 리뷰, 🔴🟡🟢 분류 → docs/code-review.md | Read,Grep,Glob,Bash | sonnet |
| test-writer.md | test-writer | P0 테스트(단위+통합+컴포넌트), Vitest → docs/test-report.md | Read,Write,Edit,Bash,Glob,Grep | sonnet |

── PART C: Phase 0 완료 확인 ──

echo '=== 기본 문서 ===' && for f in CLAUDE.md PRD.md DESIGN.md; do [ -f "$f" ] && echo "✅ $f" || echo "❌ $f (누락!)"; done && echo '' && echo '=== 서브에이전트 ===' && for f in prd-analyst architect frontend-dev backend-dev integrator code-reviewer test-writer; do [ -f ".claude/agents/$f.md" ] && echo "✅ $f" || echo "❌ $f (누락!)"; done && echo '' && TOTAL=$(ls CLAUDE.md PRD.md DESIGN.md .claude/agents/*.md 2>/dev/null | wc -l) && echo "총 ${TOTAL}/10 파일 생성 완료"

10개 모두 확인되면 Phase 1로.

</phase0_documents>


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Phase 1: PRD 분석 + 아키텍처 설계
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

<phase1>
prd-analyst 에이전트 프로세스를 따라 docs/prd-analysis.md 생성.
architect 에이전트 프로세스를 따라 docs/architecture.md 생성 + 디렉토리/설정 파일 실제 생성.

게이트 체크:
- prd-analysis.md: P0 3개+, AC 각 3개+, 의존 관계 매트릭스
- architecture.md: 기술 스택+근거, 데이터 모델, API 설계, [PROD-TODO]
- 디렉토리 + 설정 파일(.gitignore, .env.example, tsconfig 등) 존재
</phase1>


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Phase 2: 백엔드 구현
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

<phase2>
backend-dev 에이전트 프로세스(Step 1~6)를 따라 docs/architecture.md 기반으로 전체 백엔드 구현.
admin 시드 계정: admin@admin.com / admin123! [PROD-TODO]

시드 스크립트(scripts/seed.ts 또는 supabase/seed.sql)를 생성하여 admin 계정 + 기본 데이터를 자동 삽입할 수 있게 준비한다.
상세 시딩 지침은 Phase 4에서 통합 시점에 수행한다.

게이트 체크:
- P0 API 전체 구현 + 서버 정상 시작
- admin 시드 완료
- 레이어 위반 없음 (API Route에 비즈니스 로직 없음)
</phase2>


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Phase 3: 프론트엔드 구현 (프리미엄 디자인 필수)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

<phase3>
frontend-dev 에이전트 프로세스(Step 1~5)를 따라 DESIGN.md + architecture.md 기반으로 전체 프론트엔드 구현.

⚠️ 디자인 품질 기준 — "프로토타입처럼 보이면 안 된다. 초안부터 상용 서비스 수준이어야 한다":

1. 히어로/랜딩 섹션:
   - 대형 타이틀(text-4xl~6xl, font-bold) + 감성적 서브카피 + 명확한 CTA 버튼
   - Unsplash 실사 이미지 또는 그라데이션 배경 (next/image + placeholder blur)
   - 히어로 아래에 사회적 증거(로고 배너, 사용자 수, 후기) 배치

2. 여백과 레이아웃:
   - 섹션 간 py-20 이상 넉넉한 여백. 빽빽하게 채우지 않는다
   - max-w-7xl 컨테이너 + 충분한 px 패딩
   - 콘텐츠 간 시각적 호흡 공간 확보

3. 카드와 컴포넌트:
   - rounded-xl + shadow-lg, 호버 시 shadow-xl + translate-y 리프트
   - 카드 안 이미지는 aspect-ratio 통일, object-cover
   - 버튼 호버/액티브 상태에 부드러운 트랜지션

4. 이미지와 비주얼:
   - 모든 placeholder/더미 이미지를 Unsplash 실사 이미지로 교체 (https://images.unsplash.com/...)
   - next/image 컴포넌트 + width/height/alt 필수 + placeholder='blur' + blurDataURL
   - 아이콘은 Lucide React로 통일, 크기/색상 일관성 유지

5. 마이크로 인터랙션 (framer-motion):
   - 페이지 진입 시 섹션별 순차 페이드인 (staggerChildren)
   - 카드/버튼 호버 시 scale(1.02~1.05) + 그림자 변화
   - 페이지 전환 시 부드러운 opacity + y 이동
   - 스크롤 기반 요소 등장 (whileInView)

6. 타이포그래피:
   - Pretendard 또는 Noto Sans KR 한글 웹폰트 적용
   - Display(히어로) / Heading / Body / Caption 사이즈 위계 명확히
   - text-muted-foreground 활용한 보조 텍스트 색상 차이

7. 로딩/에러/빈 상태:
   - Skeleton UI 적용 (shadcn/ui Skeleton)
   - 에러 페이지에 일러스트 또는 아이콘 + 친절한 안내 메시지
   - 빈 상태에 CTA 유도

8. 반응형: 모바일 퍼스트, sm/md/lg 브레이크포인트별 레이아웃 변화

게이트 체크:
- P0 페이지 전체 + shadcn/ui + TypeScript 타입
- DESIGN.md 일관 적용
- 컴포넌트에 비즈니스 로직 없음
- 히어로 섹션 또는 메인 비주얼이 존재하고 실사 이미지가 포함됨
- 로딩/에러/빈 상태에 Skeleton UI 적용
- 여백이 충분하고 빽빽하지 않음
- 마이크로 인터랙션(호버, 페이드인)이 적용됨
- 한글 웹폰트가 적용됨
</phase3>


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Phase 4: 통합 + 테스트 + 검증
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

<phase4>
Step A — 통합: integrator 에이전트 참조. Mock→실제 API 교체, Supabase 연동, P0 플로우 전체 실행, admin 로그인 확인.

Step B — 데모 데이터 시딩:
클라이언트가 배포 URL에 접속하여 admin@admin.com / admin123!로 즉시 로그인하고, 모든 기능을 실감나게 체험할 수 있도록 목데이터를 적극적으로 세팅한다.

<demo_data_seeding>

── B-1: 시드 스크립트 작성 ──

scripts/seed.ts (또는 supabase/seed.sql)에 아래 내용을 모두 포함하는 시드 스크립트를 작성한다.
npm run seed (또는 npx ts-node scripts/seed.ts)로 한번에 실행할 수 있도록 package.json에 스크립트를 등록한다.
이미 데이터가 존재하면 중복 삽입하지 않도록 upsert 또는 존재 여부 체크 로직을 포함한다.

── B-2: 관리자 계정 생성 ──

- Supabase Auth에 admin@admin.com / admin123! 계정 생성 (supabase.auth.admin.createUser)
- email_confirm: true로 설정하여 이메일 인증 없이 바로 로그인 가능하게 한다
- user_metadata에 { role: 'admin', name: '관리자' } 설정
- 프로젝트의 사용자 프로필 테이블(profiles 등)에도 관리자 정보를 삽입한다
- 역할 기반 접근제어(RBAC)가 있는 경우, admin 역할에 모든 권한을 부여한다
- [PROD-TODO] 프로덕션 배포 전 반드시 비밀번호 변경 또는 계정 삭제

── B-3: 일반 사용자 목계정 ──

데모 시나리오의 다양성을 위해 최소 3~5명의 일반 사용자 목계정을 생성한다:
- user1@demo.com / demo123! (활발한 사용자 — 데이터 많음)
- user2@demo.com / demo123! (일반 사용자 — 데이터 보통)
- user3@demo.com / demo123! (신규 사용자 — 데이터 적음)
- 각 계정의 프로필 정보(이름, 프로필 이미지 URL, 가입일 등)도 현실적으로 설정한다
- [PROD-TODO] 프로덕션 배포 전 반드시 삭제

── B-4: 핵심 기능별 목데이터 (P0 기능 전체 커버) ──

PRD.md의 P0 기능 목록을 기준으로, 각 기능이 **빈 상태가 아닌 활성 상태**로 보이도록 데이터를 삽입한다.
데이터는 실제 서비스에서 나올 법한 한국어 텍스트와 현실적인 수치를 사용한다.

기능별 시딩 원칙:
- 리스트/테이블이 있는 기능: 최소 10~20건의 데이터 삽입 (페이지네이션 테스트 가능하도록)
- 상태/단계가 있는 기능: 각 상태별로 최소 2~3건씩 분포 (예: 대기중 3건, 진행중 5건, 완료 7건)
- 날짜 기반 기능: 최근 3개월 범위로 자연스럽게 분포 (오늘 기준 과거~미래 데이터 포함)
- 관계형 데이터: 부모-자식 관계가 자연스럽게 연결되도록 (예: 프로젝트→태스크→코멘트)
- 수치/통계 기능: 대시보드/차트가 의미 있는 패턴을 보이도록 데이터 분포 설계
- 검색 기능: 다양한 키워드로 검색했을 때 결과가 나오도록 텍스트 다양성 확보
- 이미지가 필요한 항목: Unsplash 실사 이미지 URL을 사용 (https://images.unsplash.com/...)
- 카테고리/태그: 미리 정의된 카테고리와 태그를 생성하고 데이터에 다양하게 할당

── B-5: 알림/활동 로그 ──

최근 활동 내역이 있는 프로젝트라면:
- 최근 7일간의 활동 로그/알림 데이터를 10~20건 삽입
- 읽음/안읽음 상태를 혼합하여 알림 배지가 표시되도록 한다

── B-6: 설정/환경 데이터 ──

시스템 설정이나 환경 설정이 있는 경우:
- 기본 설정값을 모두 세팅한다
- admin 계정의 개인 설정도 합리적인 기본값으로 설정한다

── B-7: 시딩 검증 체크리스트 ──

시드 스크립트 실행 후 아래를 모두 확인한다:
1. admin@admin.com / admin123!로 로그인 성공
2. 대시보드/메인 화면에 데이터가 표시됨 (빈 화면이 아님)
3. 모든 P0 페이지에 목데이터가 존재하여 기능 동작을 확인할 수 있음
4. 리스트 페이지에 충분한 데이터가 있어 스크롤/페이지네이션이 동작함
5. 상세 페이지에 진입하면 완전한 데이터가 표시됨
6. 상태별 필터링/정렬이 의미 있는 결과를 반환함
7. 차트/통계가 있다면 의미 있는 그래프가 렌더링됨
8. 검색 기능이 있다면 검색 결과가 정상적으로 반환됨

</demo_data_seeding>

Step C — 테스트: test-writer 에이전트 참조. P0 위주 커버리지 25%+, 전부 통과까지 반복 → docs/test-report.md.
Step D — 마무리: README.md (테스트 계정: admin@admin.com / admin123!, 데모 계정: user1~3@demo.com / demo123!), docs/integration-report.md.

게이트 체크:
- npm run dev 정상, admin 로그인, P0 완주, /api/health 정상
- 모든 P0 페이지에 목데이터가 표시됨 (빈 화면 없음)
- npm test 통과 + 커버리지 25%+
- README.md, test-report.md, integration-report.md 존재
</phase4>


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Phase 5: 문서 최신화 + Git + 배포 + PROGRESS.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

<phase5>
Step A — 문서 최신화: PRD.md, DESIGN.md, CLAUDE.md를 현재 코드에 맞게 갱신
Step B — Git: .gitignore 확인 → git add -A → git commit -m "[feat] 프로토타입 초안 완성" → 리모트 있으면 push
Step C — Supabase: .env.local 설정, 테이블+RLS+Auth 확인, .env.example 기재
Step D — Vercel: npm run build 성공 → npx vercel --prod → 배포 URL을 README.md에 기록 → 프로덕션에서 admin 로그인 + P0 플로우 확인
Step E — PROGRESS.md 생성:

## 초안 개발 완료 (날짜)
### 현재 상태
- 배포 URL: [URL]
- 구현 완료: P0 기능 N개 (F-001, F-002, ... 간략 나열)
- 테스트 커버리지: N%
- 관리자 계정: admin@admin.com / admin123! [PROD-TODO]
- 데모 계정: user1~3@demo.com / demo123! [PROD-TODO]
- 데모 데이터: P0 기능 전체에 목데이터 시딩 완료 (npm run seed) [PROD-TODO]
### 기술 결정
- 인증: [방식], DB: [핵심 테이블/관계], API 응답: { success, data, error, meta }
### 알려진 이슈 / TODO
- [PROD-TODO] 항목 요약
### 다음 작업 후보
- 코드 리뷰, 추가 기능, 테스트 보강 등

Step F — 최종 확인:

echo "=== 최종 산출물 ===" && for f in CLAUDE.md PRD.md DESIGN.md README.md .claude/agents/prd-analyst.md .claude/agents/architect.md .claude/agents/frontend-dev.md .claude/agents/backend-dev.md .claude/agents/integrator.md .claude/agents/code-reviewer.md .claude/agents/test-writer.md docs/prd-analysis.md docs/architecture.md docs/integration-report.md docs/test-report.md docs/PROGRESS.md; do [ -f "$f" ] && echo "✅ $f" || echo "❌ $f"; done && echo "" && npm test 2>&1 | tail -5 && echo "" && npm run build 2>&1 | tail -5 && echo "" && git log --oneline -5 2>/dev/null || echo "❌ Git 없음"

모두 통과 시 프로토타입 초안 완성을 선언하세요.
</phase5>


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ 핵심 행동 원칙 재확인 (반드시 준수)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

<core_principles_reminder>
P1. 최소 구현: 요청한 것만 구현. 임의 추가 금지.
P2. 레이어 구조: API Route → 서비스 → 리포지토리. 역방향 금지.
P3. 근본 원인 해결: 우회 금지. try-catch 삼키기, any 변환, 기능 비활성화 금지.
P4. Phase 순차 실행: 게이트 체크 통과 후 다음 Phase.
P5. PROGRESS.md 필수: 작업 완료 후 반드시 생성/업데이트.
</core_principles_reminder>

지금 Phase 0부터 시작하세요." --persona-architect --deep --think
```

---
---

# PART 2: 작업 프롬프트 (초안 완료 후 사용)

아래 프롬프트들은 **셋업 프롬프트로 초안 개발이 완료된 상태**에서 사용한다.

---

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ★ 초안 완료 후 마무리 (디자인 + 시딩 + 문서 + 배포)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

셋업 프롬프트(PART 1)로 초안 개발이 완료된 직후, **디자인 대폭 개선 → 전체 목데이터 시딩 → 문서 최신화 → Git 배포**를 한번에 수행한다.

> 📋 **복사용 프롬프트:**

```
/sc:implement "초안 개발 완료 후 마무리 작업을 수행해줘. 아래 4단계를 순서대로 전부 수행해.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 1: 디자인 대폭 개선 (frontend-dev 서브에이전트)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@DESIGN.md 를 기준으로 전체 UI/UX를 프리미엄 수준으로 대폭 개선해줘.

<design_improvement>

1. 히어로/랜딩 섹션:
   - 대형 타이틀(text-4xl~6xl, font-bold) + 감성적 서브카피 + 명확한 CTA 버튼
   - Unsplash 실사 이미지 또는 그라데이션 배경 (next/image + placeholder blur)
   - 히어로 아래에 사회적 증거(로고 배너, 사용자 수, 후기) 배치

2. 여백과 레이아웃:
   - 섹션 간 py-20 이상 넉넉한 여백. 빽빽하게 채우지 않는다
   - max-w-7xl 컨테이너 + 충분한 px 패딩
   - 콘텐츠 간 시각적 호흡 공간 확보

3. 카드와 컴포넌트:
   - rounded-xl + shadow-lg, 호버 시 shadow-xl + translate-y 리프트
   - 카드 안 이미지는 aspect-ratio 통일, object-cover
   - 버튼 호버/액티브 상태에 부드러운 트랜지션

4. 이미지와 비주얼:
   - 모든 placeholder/더미 이미지를 Unsplash 실사 이미지로 교체 (https://images.unsplash.com/...)
   - next/image 컴포넌트 + width/height/alt 필수 + placeholder='blur' + blurDataURL
   - 아이콘은 Lucide React로 통일, 크기/색상 일관성 유지

5. 마이크로 인터랙션 (framer-motion):
   - 페이지 진입 시 섹션별 순차 페이드인 (staggerChildren)
   - 카드/버튼 호버 시 scale(1.02~1.05) + 그림자 변화
   - 페이지 전환 시 부드러운 opacity + y 이동
   - 스크롤 기반 요소 등장 (whileInView)

6. 타이포그래피:
   - Pretendard 또는 Noto Sans KR 한글 웹폰트 적용
   - Display(히어로) / Heading / Body / Caption 사이즈 위계 명확히
   - text-muted-foreground 활용한 보조 텍스트 색상 차이

7. 로딩/에러/빈 상태:
   - Skeleton UI 적용 (shadcn/ui Skeleton)
   - 에러 페이지에 일러스트 또는 아이콘 + 친절한 안내 메시지
   - 빈 상태에 CTA 유도

</design_improvement>

수정 후 모든 P0 페이지를 확인하고, DESIGN.md도 실제 적용된 스타일에 맞게 업데이트해줘.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 2: 전체 목데이터 시딩 (backend-dev 서브에이전트)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

클라이언트가 배포 URL에 접속하여 즉시 로그인하고 모든 기능을 실감나게 데모할 수 있도록, 관리자 계정과 전체 목데이터를 세팅해줘.

<seeding>

── 2-A: 시드 스크립트 작성/갱신 ──

scripts/seed.ts (또는 supabase/seed.sql)에 시드 스크립트를 작성해줘.
package.json에 'seed' 스크립트를 등록해서 npm run seed로 한번에 실행 가능하게 해줘.
기존 데이터가 있으면 중복 삽입하지 않도록 upsert 또는 존재 여부 체크 로직을 포함해줘.

── 2-B: 계정 생성 ──

1. 관리자 계정:
   - admin@admin.com / admin123!
   - Supabase Auth에 생성 (supabase.auth.admin.createUser, email_confirm: true)
   - user_metadata: { role: 'admin', name: '관리자' }
   - 프로필 테이블에도 삽입, RBAC가 있으면 전체 권한 부여

2. 일반 데모 계정 (최소 3개):
   - user1@demo.com / demo123! (활발한 사용자 — 데이터 다수)
   - user2@demo.com / demo123! (일반 사용자 — 데이터 보통)
   - user3@demo.com / demo123! (신규 사용자 — 데이터 소수)
   - 각각 현실적인 프로필 정보(이름, 프로필 이미지 URL, 가입일 차등) 설정

── 2-C: P0 기능별 목데이터 전수 삽입 ──

@PRD.md 의 P0 기능 목록과 @docs/architecture.md 의 데이터 모델을 참조하여,
모든 P0 기능이 빈 화면이 아닌 활성 상태로 보이도록 데이터를 삽입해줘.

데이터 설계 원칙:
- 한국어로 실제 서비스에서 나올 법한 현실적인 텍스트와 수치를 사용
- 리스트/테이블: 최소 10~20건 (페이지네이션 동작 확인 가능)
- 상태/단계별: 각 상태마다 2~3건씩 분포
- 날짜 기반: 최근 3개월 범위로 자연스럽게 분포
- 관계형 데이터: 부모→자식 관계가 자연스럽게 연결
- 수치/통계: 대시보드 차트가 의미 있는 패턴을 보이도록 분포 설계
- 이미지: Unsplash 실사 이미지 URL 사용
- 알림/활동 로그: 최근 7일 내 10~20건, 읽음/안읽음 혼합

── 2-D: 시드 실행 + 검증 ──

시드 스크립트를 실행하고 아래를 모두 확인해줘:
1. admin@admin.com / admin123!로 로그인 성공
2. 대시보드/메인 화면에 데이터가 표시됨 (빈 화면 아님)
3. 모든 P0 페이지에 목데이터가 존재
4. 리스트 페이지에 스크롤/페이지네이션이 동작할 만큼 데이터 존재
5. 차트/통계가 있다면 의미 있는 그래프 렌더링

</seeding>

README.md에 테스트 계정 정보와 npm run seed 실행 방법을 기재해줘.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 3: 전체 문서 최신화
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@CLAUDE.md @PRD.md @DESIGN.md @docs/PROGRESS.md 포함, 지금까지 작업한 내용을 반영이 필요한 모든 .md 파일들을 최신화시켜줘. docs/ 폴더 내 문서도 포함. 핵심만 간결하게.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 4: Git 커밋 + 푸시 + Vercel 배포
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

변경 사항을 커밋하고 푸시해줘. vercel에 배포하고 바로 프로덕션 환경에 반영되도록 해줘. 완료 후 docs/PROGRESS.md에 배포 사항을 기록해줘." --persona-architect --deep --think
```

---

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1. 레퍼런스 분석
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 1-1. 레퍼런스 웹사이트 분석 (구조 + UI 통합)

레퍼런스 웹사이트의 구조/컨셉과 UI/디자인을 한번에 분석하여 PRD와 DESIGN.md에 반영한다.

> 📋 **복사용 프롬프트:** `{URL}`을 실제 URL로 교체

```
/sc:analyze "prd-analyst 서브에이전트와 frontend-dev 서브에이전트를 사용해줘. {URL} 이 웹사이트를 분석해줘.

── Step 1: 구조/컨셉 분석 (prd-analyst) ──
전체 구조, 컨셉, 아이덴티티, 목적, 핵심 기능을 분석하고 @PRD.md 에 적용해줘.

── Step 2: UI/디자인 분석 (frontend-dev) ──
전체 UI, 디자인 컴포넌트, 테마컬러, 레이아웃 패턴, 여백 활용, 마이크로 인터랙션을 심도있게 분석하고 @DESIGN.md 에 적용해줘. shadcn/ui를 적극적으로 활용할 수 있게 매핑해줘.

변경 사항을 docs/PROGRESS.md에 기록해줘." --persona-analyzer
```

---

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2. 기능 구현 (일상 개발)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 2-1. 기능 추가 — 풀스택

설계 → 백엔드 → 프론트엔드 순서로 풀스택 기능을 추가한다.

> 📋 **복사용 프롬프트:** `{기능 설명}`을 실제 내용으로 교체

```
/sc:implement "architect 서브에이전트를 총괄로, backend-dev와 frontend-dev 서브에이전트를 실행으로 사용해줘. {기능 설명}. 이 기능을 구현하기 전에 docs/architecture.md에 해당 기능의 설계를 먼저 추가하고, 그 뒤에 백엔드 API → 프론트엔드 UI 순서로 구현해줘. CLAUDE.md의 최소 구현 원칙을 지켜서 요청한 기능만 구현해줘. 완료 후 docs/PROGRESS.md에 추가된 기능을 기록해줘." --persona-architect
```

## 2-2. 기능 추가 — 프론트엔드만

> 📋 **복사용 프롬프트:** `{기능 설명}`을 실제 내용으로 교체

```
/sc:implement "frontend-dev 서브에이전트를 사용해줘. {기능 설명}. @DESIGN.md 의 디자인 시스템을 따라서 구현하고, CLAUDE.md의 최소 구현 원칙을 지켜서 요청한 것만 구현해줘. 완료 후 docs/PROGRESS.md에 기록해줘." --persona-frontend --focus frontend
```

## 2-3. 기능 추가 — 백엔드만

> 📋 **복사용 프롬프트:** `{기능 설명}`을 실제 내용으로 교체

```
/sc:implement "backend-dev 서브에이전트를 사용해줘. {기능 설명}. RESTful 원칙을 따르고, 기존 응답 포맷과 에러 처리를 통일해줘. CLAUDE.md의 최소 구현 원칙을 지켜서 요청한 것만 구현해줘. 완료 후 docs/PROGRESS.md에 추가된 API를 기록해줘." --persona-backend --focus backend
```

---

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3. 트러블슈팅
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 3-1. 트러블슈팅

백엔드/프론트엔드/빌드/배포 등 영역에 관계없이 근본 원인을 추적하여 해결한다.

> 📋 **복사용 프롬프트:** `{에러 설명 또는 증상}`을 실제 내용으로 교체

```
/sc:troubleshoot "{에러 설명 또는 증상}. CLAUDE.md의 트러블슈팅 원칙을 따라줘. 에러가 발생하는 영역(API, Supabase, 컴포넌트, 빌드, 배포 등)을 먼저 특정하고, 관련 코드와 로그를 추적해서 근본 원인을 파악해줘. 재발하지 않도록 제대로 고치고, 수정 후 정상 동작을 확인해줘. 재발 방지 지침을 CLAUDE.md 1-9에 추가하고, docs/PROGRESS.md에 수정 내역을 기록해줘." --persona-analyzer
```

---

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4. 코드 리뷰 & 품질 개선 (통합)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 4-1. 전체 코드 리뷰 + 수정 + 정리 (원스톱)

리뷰, 이슈 수정, 코드 정리를 한번에 수행한다.

> 📋 **복사용 프롬프트:**

```
/sc:implement "code-reviewer 서브에이전트를 사용해줘. 전체 코드에 대해 리뷰 → 수정 → 정리를 한번에 수행해줘.

── Step 1: 리뷰 ──
@CLAUDE.md 의 모든 원칙을 기준으로 전체 코드를 검토하고, 🔴 심각 / 🟡 경고 / 🟢 제안으로 분류해줘.
각 이슈에 파일 경로, 라인, 현재 코드, 수정 코드, 사유를 포함해줘.
말미에 전체 등급(A~F)과 프로덕션 전환 Top 5를 정리해줘.

── Step 2: 이슈 수정 ──
🔴 심각 이슈와 🟡 경고 이슈를 모두 수정해줘.
수정 후 기존 기능이 깨지지 않았는지 주요 플로우를 확인해줘.
CLAUDE.md의 최소 구현 원칙을 지켜서 리뷰 이슈 수정에만 집중해줘.

── Step 3: 코드 정리 ──
- 사용하지 않는 import/변수/함수 제거
- 네이밍 통일 (CLAUDE.md 규칙 기준)
- 파일 분리 (300줄 초과 파일)
- console.log 제거
- any 타입 제거
- 기능 변경은 하지 마

── Step 4: 결과 보고 ──
docs/code-review.md에 리뷰 결과 + 수정 내역 + 정리 내역을 통합 기록해줘.
docs/PROGRESS.md에 리뷰 등급과 주요 개선 사항을 기록해줘." --persona-analyzer
```

---

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 5. 테스트
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 5-1. 테스트 작성 + 실행

P0 기능 위주 전체 테스트를 작성하고 실행한다.

> 📋 **복사용 프롬프트:**

```
/sc:test "test-writer 서브에이전트를 사용해줘. P0 기능 위주로 전체 코드 커버리지 25% 이상을 목표로 테스트 코드를 작성해줘. 백엔드 서비스 단위 테스트, API 통합 테스트, 핵심 프론트엔드 컴포넌트 테스트를 포함해줘. 작성 완료 후 바로 테스트를 실행하고, 전부 통과할 때까지 반복해줘. 결과를 docs/test-report.md에 기록해줘." --persona-qa
```

---

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 6. 작업 마무리 (문서 최신화 + Git 배포)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 6-1. 문서 최신화 + 커밋 + 푸시 + 프로덕션 반영

모든 작업의 마무리 단계. 문서를 현재 코드에 맞게 최신화한 뒤 Git 커밋 + 배포까지 한번에 수행한다.

> 📋 **복사용 프롬프트:**

```
/sc:deploy @CLAUDE.md @PRD.md @DESIGN.md @docs/PROGRESS.md "작업 마무리를 수행해줘.

── Step 1: 문서 최신화 ──
지금까지 작업한 내용을 반영이 '필요'한 모든 .md 파일들에 최신화시켜줘. docs/ 폴더 내 문서도 포함해줘. docs/PROGRESS.md도 현재 상태에 맞게 업데이트해줘. 핵심만 간결하게.

── Step 2: Git 커밋 + 푸시 ──
변경 사항을 커밋하고 푸시해줘.

── Step 3: Vercel 배포 ──
vercel에 배포하고 바로 프로덕션 환경에 반영되도록 해줘. 완료 후 docs/PROGRESS.md에 배포 사항을 기록해줘." --persona-architect --think
```

---

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 7. 성능 개선
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 7-1. 전반적 성능 분석 및 개선

번들 사이즈, 초기 로딩, API 응답 시간, 리렌더링을 분석하고 개선한다.

> 📋 **복사용 프롬프트:**

```
/sc:improve "code-reviewer 서브에이전트를 사용해서 먼저 성능 병목을 분석하고, 그 결과를 바탕으로 개선해줘. 번들 사이즈, 초기 로딩, API 응답 시간, 불필요한 리렌더링을 중심으로 확인해줘. 완료 후 docs/PROGRESS.md에 개선 내역을 기록해줘." --persona-performance --focus performance
```

---

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 8. 디자인 개선
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 8-1. 전체 디자인 리뉴얼

프로토타입 수준의 UI를 **상용 서비스 수준의 프리미엄 디자인**으로 전면 개선한다.

> 📋 **복사용 프롬프트:**

```
/sc:implement "frontend-dev 서브에이전트를 사용해줘. @DESIGN.md 를 기준으로 전체 UI/UX를 프리미엄 수준으로 대폭 개선해줘.

개선 영역:

1. 히어로/랜딩 섹션:
   - 대형 타이틀(text-4xl~6xl, font-bold) + 감성적 서브카피 + 명확한 CTA 버튼
   - Unsplash 실사 이미지 또는 그라데이션 배경 (next/image + placeholder blur)
   - 히어로 아래에 사회적 증거(로고 배너, 사용자 수, 후기) 배치

2. 여백과 레이아웃:
   - 섹션 간 py-20 이상 넉넉한 여백. 빽빽하게 채우지 않는다
   - max-w-7xl 컨테이너 + 충분한 px 패딩
   - 콘텐츠 간 시각적 호흡 공간 확보

3. 카드와 컴포넌트:
   - rounded-xl + shadow-lg, 호버 시 shadow-xl + translate-y 리프트
   - 카드 안 이미지는 aspect-ratio 통일, object-cover
   - 버튼 호버/액티브 상태에 부드러운 트랜지션

4. 이미지와 비주얼:
   - 모든 placeholder/더미 이미지를 Unsplash 실사 이미지로 교체 (https://images.unsplash.com/...)
   - next/image 컴포넌트 + width/height/alt 필수 + placeholder='blur' + blurDataURL
   - 아이콘은 Lucide React로 통일, 크기/색상 일관성 유지

5. 마이크로 인터랙션 (framer-motion):
   - 페이지 진입 시 섹션별 순차 페이드인 (staggerChildren)
   - 카드/버튼 호버 시 scale(1.02~1.05) + 그림자 변화
   - 페이지 전환 시 부드러운 opacity + y 이동
   - 스크롤 기반 요소 등장 (whileInView)

6. 타이포그래피:
   - Pretendard 또는 Noto Sans KR 한글 웹폰트 적용
   - Display(히어로) / Heading / Body / Caption 사이즈 위계 명확히
   - text-muted-foreground 활용한 보조 텍스트 색상 차이

7. 로딩/에러/빈 상태:
   - Skeleton UI 적용 (shadcn/ui Skeleton)
   - 에러 페이지에 일러스트 또는 아이콘 + 친절한 안내 메시지
   - 빈 상태에 CTA 유도

수정 후 모든 P0 페이지를 확인하고, DESIGN.md도 실제 적용된 스타일에 맞게 업데이트해줘. docs/PROGRESS.md에 개선 내역을 기록해줘." --persona-frontend --focus frontend
```

## 8-2. 레퍼런스 기반 디자인 개선

벤치마크 웹사이트의 디자인을 분석하고 우리 프로젝트에 적용한다.

> 📋 **복사용 프롬프트:** `{URL}`을 실제 URL로 교체

```
/sc:implement "frontend-dev 서브에이전트를 사용해줘. {URL} 이 웹사이트의 디자인을 분석하고, 그 감성과 레이아웃 패턴을 우리 프로젝트에 적용해줘. 특히 히어로 섹션, 카드 스타일, 여백 활용, 이미지 사용법, 마이크로 인터랙션을 참고해줘. @DESIGN.md 도 분석 결과를 반영해서 업데이트해줘. 완료 후 docs/PROGRESS.md에 기록해줘." --persona-frontend --focus frontend
```

---

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 9. 패키징
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 9-1. 독립 실행 패키지

> 📋 **복사용 프롬프트:**

```
/sc:implement "이 프로그램을 다른 PC에서 별도의 설치나 설정 없이 바로 실행할 수 있도록 필요한 모든 의존성이 포함된 실행 파일을 만들어줘." --persona-architect --focus architecture
```

---

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 10. 인수인계
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 10-1. 프로젝트 분석 + 인수인계 문서 작성 (원스톱)

프로젝트 요약, 심층 분석, 인수인계 문서 작성을 한번에 수행한다.

> 📋 **복사용 프롬프트:**

```
/sc:document "architect 서브에이전트와 prd-analyst, code-reviewer 서브에이전트를 사용해줘.

── Step 1: 맥락 파악 ──
@docs/PROGRESS.md @PRD.md @DESIGN.md @docs/architecture.md @CLAUDE.md 를 읽고 프로젝트의 진행 상황, 기술 스택, 설계 구조, 디자인 시스템을 파악해줘.

── Step 2: 심층 분석 ──
prd-analyst와 code-reviewer 서브에이전트로 전체 프로젝트의 특징, 구조, 기술 스택, 현재 상태, 주요 기능 목록, 코드 품질을 자세히 분석해줘.

── Step 3: 인수인계 문서 작성 ──
이 프로젝트를 이어받아 유지보수 및 추가 개발을 수행할 개발자를 위한 인수인계 문서를 docs/handover.md로 만들어줘.

포함 내용:
- 프로젝트 개요 및 목적
- 기술 스택 상세 (버전 포함)
- 디렉토리 구조 설명
- 주요 기능별 코드 위치
- 데이터 모델 및 API 설계
- 환경 설정 방법 (.env 변수 목록, Supabase 설정, Vercel 설정)
- 개발 서버 실행 및 빌드 방법
- 테스트 계정 및 테스트 실행 방법
- 알려진 이슈 및 기술 부채
- 향후 로드맵 (P1/P2 기능 목록)
- 주의 사항 및 트러블슈팅 팁

── Step 4: 보고 ──
분석 결과 요약과 인수인계 문서 완료를 보고해줘. docs/PROGRESS.md에 인수인계 문서 작성을 기록해줘." --persona-architect
```

---

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 11. 데모 데이터 시딩 (목데이터 세팅)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 11-1. 전체 목데이터 시딩 (관리자 계정 + 데모 데이터)

클라이언트가 배포된 앱에 접속하여 즉시 로그인하고 모든 기능을 체험할 수 있도록, 관리자/데모 계정과 목데이터를 세팅한다.
셋업 프롬프트(PART 1) Phase 4에서 자동으로 수행되지만, 데이터 리셋이 필요하거나 추가 기능 구현 후 데모 데이터를 보강할 때 독립적으로 사용한다.

> 📋 **복사용 프롬프트:**

```
/sc:implement "backend-dev 서브에이전트를 사용해줘. 클라이언트가 배포 URL에 접속하여 즉시 로그인하고 모든 기능을 실감나게 데모할 수 있도록, 관리자 계정과 전체 목데이터를 세팅해줘.

── Step 1: 시드 스크립트 작성/갱신 ──

scripts/seed.ts (또는 supabase/seed.sql)에 시드 스크립트를 작성해줘.
package.json에 'seed' 스크립트를 등록해서 npm run seed로 한번에 실행 가능하게 해줘.
기존 데이터가 있으면 중복 삽입하지 않도록 upsert 또는 존재 여부 체크 로직을 포함해줘.

── Step 2: 계정 생성 ──

1. 관리자 계정:
   - admin@admin.com / admin123!
   - Supabase Auth에 생성 (supabase.auth.admin.createUser, email_confirm: true)
   - user_metadata: { role: 'admin', name: '관리자' }
   - 프로필 테이블에도 삽입, RBAC가 있으면 전체 권한 부여

2. 일반 데모 계정 (최소 3개):
   - user1@demo.com / demo123! (활발한 사용자 — 데이터 다수)
   - user2@demo.com / demo123! (일반 사용자 — 데이터 보통)
   - user3@demo.com / demo123! (신규 사용자 — 데이터 소수)
   - 각각 현실적인 프로필 정보(이름, 프로필 이미지 URL, 가입일 차등) 설정

── Step 3: P0 기능별 목데이터 전수 삽입 ──

@PRD.md 의 P0 기능 목록과 @docs/architecture.md 의 데이터 모델을 참조하여,
**모든 P0 기능이 빈 화면이 아닌 활성 상태**로 보이도록 데이터를 삽입해줘.

데이터 설계 원칙:
- 한국어로 실제 서비스에서 나올 법한 현실적인 텍스트와 수치를 사용
- 리스트/테이블: 최소 10~20건 (페이지네이션 동작 확인 가능)
- 상태/단계별: 각 상태마다 2~3건씩 분포 (예: 대기 3건, 진행 5건, 완료 7건)
- 날짜 기반: 최근 3개월 범위로 자연스럽게 분포
- 관계형 데이터: 부모→자식 관계가 자연스럽게 연결
- 수치/통계: 대시보드 차트가 의미 있는 패턴을 보이도록 분포 설계
- 검색: 다양한 키워드로 검색 결과가 나오도록 텍스트 다양성 확보
- 이미지: Unsplash 실사 이미지 URL 사용 (https://images.unsplash.com/...)
- 카테고리/태그: 미리 정의하고 데이터에 다양하게 할당
- 알림/활동 로그: 최근 7일 내 10~20건, 읽음/안읽음 혼합
- 시스템 설정: 기본 설정값 모두 세팅

── Step 4: 시드 실행 + 검증 ──

시드 스크립트를 실행하고 아래를 모두 확인해줘:
1. admin@admin.com / admin123!로 로그인 성공
2. 대시보드/메인 화면에 데이터가 표시됨 (빈 화면 아님)
3. 모든 P0 페이지에 목데이터가 존재
4. 리스트 페이지에 스크롤/페이지네이션이 동작할 만큼 데이터 존재
5. 상세 페이지에 완전한 데이터 표시
6. 필터/정렬이 의미 있는 결과 반환
7. 차트/통계가 있다면 의미 있는 그래프 렌더링
8. 검색 결과가 정상 반환

── Step 5: 문서 업데이트 ──

- README.md에 테스트 계정 정보와 npm run seed 실행 방법을 기재해줘
- docs/PROGRESS.md에 시딩 완료 내역을 기록해줘
- 시드 데이터 항목에 [PROD-TODO] 태그를 달아서 프로덕션 전 정리 대상임을 명시해줘" --persona-backend
```

---
---

# 부록

## 추천 워크플로우 시나리오

### A-0: 기존 프로젝트 이어받기

```
PART 0 (클론+마이그레이션) → {원하는 작업 번호}
```

### A: 신규 프로젝트 풀 개발

```
[셋업 프롬프트 실행] → Phase 0~5 자동 완료 → ★ 초안 완료 후 마무리 (디자인+시딩+문서+배포)
이후: 4-1 리뷰+수정+정리 → 5-1 테스트 보강 → 6-1 마무리(문서+배포)
```

### B: 새 기능 추가

```
2-1 or 2-2 or 2-3 → 11-1 → 5-1 → 4-1 → 6-1
기능 구현              시딩보강  테스트   리뷰+수정   마무리(문서+배포)
```

### C: 버그 핫픽스

```
3-1 → 5-1 → 6-1
트러블슈팅   테스트   마무리(문서+배포)
```

### D: 정기 품질 관리

```
4-1 → 7-1 → 5-1 → 6-1
리뷰+수정+정리   성능개선   테스트   마무리(문서+배포)
```

### E: 디자인 대폭 개선

```
8-1 (전체 리뉴얼) → 6-1
디자인 개선            마무리(문서+배포)

또는 레퍼런스 기반:
1-1 (레퍼런스 분석) → 8-2 (레퍼런스 적용) → 6-1
```

### F: 세션 교체 후 이어서 작업

```
[개요의 세션 교체 프롬프트 실행] → 상태 요약 확인 → {원하는 작업 번호}
```

### G: 인수인계

```
10-1 (분석+인수인계 문서 원스톱) → 6-1 (최종 마무리)
```

### H: 데모 데이터 보강

```
11-1 (목데이터 시딩) → 6-1 (마무리)
```

---

## 서브에이전트 × 명령어 매핑

| 서브에이전트 | 주 사용 명령어 | 사용 시점 |
|-------------|---------------|----------|
| `prd-analyst` | /sc:analyze | 레퍼런스 분석, 프로젝트 분석, 인수인계 |
| `architect` | /sc:implement | 풀스택 기능 추가 총괄, 인수인계 |
| `frontend-dev` | /sc:implement | UI 구현, 디자인 분석/개선, 레퍼런스 분석 |
| `backend-dev` | /sc:implement | API 구현 |
| `integrator` | /sc:implement | FE↔BE 연결, 전체 플로우 검증 |
| `code-reviewer` | /sc:implement | 코드 리뷰+수정+정리 통합, 성능 분석 |
| `test-writer` | /sc:test | 테스트 작성/실행 |
