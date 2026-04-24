# 애니메이션 고도화 리서치 — Lottie + 코드 기반 + AI 생성

> 상태: 리서치 단계
> **출처:** Project Zenith 리서치 문서를 Grimoire로 이관 (2026-04-09)
> **원본 위치:** `/Users/sokol/Desktop/Git/simple_project_zenith/RESEARCH_ANIMATION.md`
>
> **Grimoire 적용 대상:**
> - A24식 Artifacts 디자인 방향 (남은 과제 #5)
> - 플랫폼 페이지 디자인 리뉴얼 (남은 과제 #4)
> - 기존 구현 연장:
>   - `CardTransition.tsx` — Framer Motion 원형 확장/수축 (**Prune 패턴이 사실상 이미 동작 중**)
>   - `TypeWriter.tsx` — 타이핑 이펙트
>   - `HorizontalScroll.tsx` — 스크롤 스냅 그리드
>
> **주의:** 이 문서의 §3 "Phase 1~4+" 섹션과 §5 "헤트비히 페르소나" 항목은 **Project Zenith 맥락**이므로 Grimoire 적용 시 재작성 필요. 기술 카탈로그(§1, §2, §4)는 그대로 활용 가능.
> **원 참조:** `project-zenith-brief.md` §2.3 (애니메이션 레퍼런스), `RESEARCH_BEHAVIORAL_UX.md` (의도된 마찰 UX)

---

## 1. 애니메이션 구현 방식 분류

### 코드 기반 (Claude가 직접 구현 가능)

| 유형 | iOS 구현 | Web 구현 | 용도 |
|------|---------|---------|------|
| 원형 확장/수축 (Prune 패턴) | `CAShapeLayer` + `UIBezierPath` | CSS clip-path + transition | 화면 전환, 기록 완료 |
| 숫자 카운팅 | `CADisplayLink` | `requestAnimationFrame` | 스위스 수치 변경 |
| 페이드/슬라이드 | `UIView.animate` | Framer Motion | 일반 UI 전환 |
| 스프링/바운스 | `usingSpringWithDamping` | Framer Motion spring | 버튼 피드백 |
| 프로그레스바 | `CAShapeLayer` strokeEnd | CSS transition width | 롱프레스 버튼 |
| 파티클 (불꽃, 소각) | `CAEmitterLayer` | canvas / Three.js | 스위스 소각 연출 |
| 스크롤 패럴랙스 | `scrollViewDidScroll` | Framer Motion useScroll | 카드 간 깊이감 |
| 3D 회전/기울기 | SceneKit / `CATransform3D` | React Three Fiber | 숫자 물성 부여 |

### Lottie 기반 (디자인 에셋 필요)

| 유형 | 제작 방법 | 용도 |
|------|----------|------|
| 캐릭터 모션 | After Effects → Bodymovin → JSON | 온보딩, 빈 상태 |
| 일러스트 애니메이션 | Figma + LottieFiles 플러그인 | 에러 화면, 로딩 |
| 아이콘 모션 | LottieFiles 무료 에셋 | 탭 전환, 체크마크 |
| 복잡한 시퀀스 | AI 생성 도구 | 기록 후 피드백 모달 |

---

## 2. AI 기반 Lottie 생성 도구

### LottieFiles AI (https://lottiefiles.com/ai)
- **Motion Copilot**: 텍스트로 원하는 움직임을 설명하면 편집 가능한 키프레임 자동 생성
- **AI Prompt to Vector**: 텍스트 → 고품질 벡터 그래픽 생성 → 애니메이션 추가
- **Raster to Vector**: PNG/JPG → SVG 변환 → Lottie 애니메이션으로 확장
- **비용**: 무료 티어 있음

### LottieGen (https://lottiegenai.webflow.io/)
- 텍스트 프롬프트만으로 Lottie 애니메이션 즉시 생성
- "A coin spinning and falling" → 완성된 .json 파일
- **비용**: 무료

### Recraft AI (https://www.recraft.ai/blog/generate-lottie-files-with-ai-for-free)
- 이미지/텍스트 → SVG → Lottie 변환
- PNG/JPG를 무한 확장 가능한 SVG로 벡터화
- **비용**: 무료

### Lottielab (https://www.lottielab.com/)
- 웹 기반 Lottie 에디터 + AI 보조
- After Effects 없이 브라우저에서 직접 애니메이션 편집
- **비용**: 무료 티어

### OmniLottie (https://github.com/OpenVGLab/OmniLottie) ⭐ 주목
- **CVPR 2026 발표** — 세계 최고 컴퓨터비전 학회에서 발표된 학술 연구 기반 오픈소스
- 텍스트/이미지/영상 → Lottie JSON 직접 생성 (멀티모달)
- Vision-Language Model (VLM) 기반 — 복잡한 벡터 애니메이션을 프롬프트로 생성 가능
- 서드파티 래핑이 아닌 end-to-end 모델
- **비용**: 오픈소스 (무료)
- **논문**: https://arxiv.org/pdf/2603.02138

---

## 3. Project Zenith 적용 계획

### Phase 1 (현재) — 코드 기반만
- 페이드/슬라이드 전환 ✅ 구현됨
- 햅틱 피드백 ✅ 구현됨
- 숫자 카운팅 애니메이션 — TODO
- 스켈레톤 로딩 ✅ 구현됨

### Phase 2 — 코드 기반 고도화
- Prune 패턴 원형 트랜지션 (기록 완료 시)
- 롱프레스 프로그레스 버튼 (Helldivers 2 패턴)
- 스크롤 패럴랙스 (카드 간 깊이감)

### Phase 3 — Lottie 도입
- 기록 후 피드백 모달 (헤트비히 톤에 맞는 해맑은 애니메이션)
- 빈 상태 화면 ("아직 기록이 없어요")
- 에러 화면 애니메이션
- 온보딩 시퀀스

### Phase 4+ — AI + Lottie 고도화
- LottieFiles AI / LottieGen으로 커스텀 애니메이션 생성
- 헤트비히 페르소나에 맞는 "해맑고 기괴한" 모션 아이덴티티 확립
- SceneKit 3D 숫자 렌더링 (Not Boring Weather 패턴)

---

## 4. 기술 스택

### iOS
```
lottie-ios (SPM) — Lottie JSON 재생
CAShapeLayer + CABasicAnimation — 코드 기반 애니메이션
CAEmitterLayer — 파티클 효과
CADisplayLink — 프레임 단위 업데이트
SceneKit — 3D (Phase 4+)
CoreMotion — 기기 기울기 (Phase 4+)
CoreHaptics — 햅틱 연동 (구현됨)
```

### Web
```
framer-motion (구현됨) — React 애니메이션
@lottiefiles/dotlottie-react — Lottie 재생 (Phase 3)
@react-three/fiber — 3D (Phase 4+)
CSS transition / animation — 기본 효과
```

---

## 5. 헤트비히 톤과 애니메이션

애니메이션도 헤트비히 페르소나(§2.2.1)를 따라야 한다:

| 원칙 | 적용 |
|------|------|
| **해맑고 우아함** | 부드러운 스프링, 여유로운 duration (0.3~0.6s) |
| **기괴한 내용물** | 소각, 증발, 사라짐을 "예쁘게" 표현 |
| **부재의 미학** | 과도한 파티클/이펙트 지양, 여백 유지 |
| **인지 부조화** | 밝은 색상의 애니메이션이 경제적 파탄을 시각화 |

예시: 지출 기록 완료 → 화사한 파스텔톤 원이 부드럽게 확장 → 그 안에 "0.03 스위스가 향기롭게 태워졌어요" → 원이 우아하게 수축하며 사라짐

---

## 참조 문서

- `project-zenith-brief.md` §2.3 — 애니메이션 레퍼런스 (Prune, 카카오페이, Not Boring Weather)
- `project-zenith-brief.md` §2.2.1 — 헤트비히 페르소나 (톤앤매너 기준)
- `RESEARCH_BEHAVIORAL_UX.md` — 의도된 마찰 UX
- LottieFiles: https://lottiefiles.com
- LottieGen: https://lottiegenai.webflow.io
- Recraft AI: https://www.recraft.ai
- Lottielab: https://www.lottielab.com
