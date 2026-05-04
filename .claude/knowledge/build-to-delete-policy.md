# Build-to-Delete Policy — Skills/Sensors/Hooks 폐기 가능 설계 정본

> **출처**: 「하네스 엔지니어링 완전 정복」V1.1 부록 B 신개념 + Mitchell Hashimoto Ghostty 패턴
> **신설**: 2026-05-03 #10_6 묶음 II (Tier 2 자율 적용)
> **POINT**: "모델 발전에 따라 불필요해질 스캐폴딩을 의도적으로 경량 설계"

---

## 1. 정의 (책 부록 B)

**Build-to-Delete**: 미래의 모델 진화로 자동 해소될 스캐폴딩(Skills/Sensors/Hooks)을 의도적으로 **폐기 가능한 형태로 설계**.

**왜 필요한가**:
- 책 Ch 23 안티패턴 #5 "하네스 부패" — 사용 안 하는 스캐폴딩이 "쓰레기 수거(garbage collection)" 부담
- 책 Ch 18 비용 — 노후 스캐폴딩이 컨텍스트 토큰 + 유지보수 비용 누적
- Mitchell Hashimoto Ghostty 패턴 — "실수마다 규칙 1줄" 추가하면 무한 비대 → 폐기 메타 필요

---

## 2. 분류 — Skills/Sensors/Hooks 3 카테고리

### Category A: 영구 보존 (Permanent)
**기준**: 도메인 정본 + 모델 진화에 무관한 비즈니스 룰
- ✅ 사슴악마 시각 정본 (사용자 도메인 결정)
- ✅ §0 원가 철칙 (사용자 비즈니스 룰)
- ✅ 작가 콘텐츠 보호 (법적/윤리적 절대 규칙)
- ✅ shared-contracts 인터페이스 (책 Ch 16 Sprint 계약)

**박제 의무**: knowledge/red-team-constitution.md P1~P5 / P16

### Category B: 진화 가능 (Evolvable)
**기준**: 모델 진화 + 산업 패턴 변화 시 갱신
- ⚠️ socratic-self-critique 7~14 질문 (Q00/ouroboros 진화 시 동기)
- ⚠️ adversarial-retry max 2 (ng/adversarial-review 패턴 변화 시)
- ⚠️ EDD 점수 가중치 (책 Ch 15 TaskFlow 5차원 진화 시)
- ⚠️ MCP 연동 정책 (Anthropic 공식 변화 시)

**박제 의무**: 각 skill SKILL.md frontmatter `evolvable: true` 마크

### Category C: 폐기 후보 (Deletable)
**기준**: 모델 진화로 자동 해소 예상 + 사용 빈도 ≤ 1회/월
- 🗑️ 모델별 false positive 처리 패턴 (모델 정확도 ↑ 시 자연 폐기)
- 🗑️ 임시 디버그 sensor (특정 버그 해결 후 폐기)
- 🗑️ 1회성 마이그레이션 hook (마이그레이션 완료 후 폐기)

**박제 의무**: 각 skill SKILL.md frontmatter `deprecate-after: YYYY-MM` 마크

---

## 3. 폐기 결정 매트릭스

| 신호 | A 영구 | B 진화 | C 폐기 |
|------|-------|-------|--------|
| 사용 빈도 (지난 30일) | ≥ 1회/주 | ≥ 1회/월 | ≤ 1회/월 |
| 모델 진화 의존도 | 0 (도메인 룰) | 부분 | 100% |
| 비즈니스 룰 위배 시 영향 | 치명적 | 중대 | 작음 |
| 대체 가능 패턴 존재 | X | 부분 | 100% |
| 회귀 테스트 의존 | 강 | 중 | 약 |

**판정 절차**:
1. 신규 Skills/Sensors/Hooks 신설 시 frontmatter에 카테고리 마크
2. sensor-feedback-promotion 30일 트래킹 → 사용 빈도 데이터 수집
3. 분기별 (3개월) 1회 Build-to-Delete 리뷰 — Category C 폐기 후보 자동 식별
4. 사용자 승인 후 폐기 (Stop hook 메모리 박제)

---

## 4. ProjectGrimoire 적용 (2026-05-03 시점 분류)

### Category A 영구 (예시)
- skills/verification-before-completion (Constitutional AI 정공법)
- sensors/sensor-credit-atomicity (§0 원가 절대)
- knowledge/red-team-constitution.md P1~P5/P16
- hooks/posttooluse-failure-handler (위험 명령 차단 영구)

### Category B 진화 (예시)
- skills/socratic-self-critique (Q00/ouroboros 차용 — 정본 진화 시 동기)
- skills/dispatching-parallel-agents (obra/superpowers 차용)
- skills/requesting-code-review (obra/superpowers 차용)
- knowledge/red-team-constitution.md P17~P19 (OWASP LLM Top 10 갱신 시)
- sensors/sensor-adversarial-pre-commit (책 Ch 17 Constitutional 진화 시)

### Category C 폐기 후보 (예시 — 2026-05-03 시점 후보 0건)
- (없음 — 신설 1주일 미만 신규 항목 다수)
- 향후 후보:
  - dev-login-smoke (개발 환경 검증 — prod 환경 안정 후 폐기 가능)
  - macos-tcc-handling (macOS 한정 — Linux/Windows 전환 시 폐기)

---

## 5. 폐기 절차 (사용자 승인 게이트)

### Step 1: 자동 식별 (sensor-build-to-delete-candidate, 미구현 — TODO)
- 30일 사용 빈도 ≤ 1회 + Category C 마크 = 후보
- `.claude/state/build-to-delete-candidates.jsonl` 박제

### Step 2: 사용자 검토
- 후보 리스트 사용자 보고
- 사용자 명시 후 폐기 진행

### Step 3: 폐기 실행
1. 별도 브랜치 (`auto-evolve/delete-{skill명}-{date}`)
2. 회귀 검증 (regression + EDD eval) — 영향 0건 확인
3. develop 머지 propose
4. 사용자 명시 후 main 머지

### Step 4: 폐기 후 박제
- memory/project_session_*.md에 폐기 사유 박제
- knowledge/build-to-delete-policy.md 본 문서에 폐기 이력 추가

---

## 6. 안티패턴 방어

### 안티패턴 #1: "혹시 모를" 보존
- **문제**: 사용 안 하는 스캐폴딩을 "혹시 필요할 수도" 보존 → 무한 비대
- **방어**: 30일 미사용 + Category C → 자동 폐기 후보. 보존하려면 카테고리 재분류 (A/B로 승격) 필요

### 안티패턴 #2: 무차별 폐기
- **문제**: Category B/C 구분 없이 일괄 폐기 → 회귀 위험
- **방어**: Step 2 사용자 게이트 + Step 3 회귀 검증

### 안티패턴 #3: 폐기 박제 누락
- **문제**: 폐기 후 사유 박제 안 함 → 미래 동일 패턴 재신설 위험
- **방어**: Step 4 memory + 본 정본 박제 의무

---

## 7. 관련 정본
- 책 V1.1 부록 B (신개념 용어 정본)
- 책 V1.1 Ch 18 (비용 관리 — 컨텍스트 효율)
- 책 V1.1 Ch 23 (안티패턴 #5 하네스 부패)
- `.claude/skills/feedback-to-skill/SKILL.md` (승격 패턴 — 본 정본의 역방향)
- `.claude/scripts/sensor-feedback-promotion.sh` (사용 빈도 추적)
- Mitchell Hashimoto "My AI Adoption Journey" (Feb 5, 2026)

---

## 8. 변경 이력
- 2026-05-03 #10_6 묶음 II 신설 — 책 부록 B + Mitchell Ghostty 패턴 적용
- **갱신 정책**: Category A/B/C 분류는 사용자 승인 후 변경 (자율 변경 금지)
