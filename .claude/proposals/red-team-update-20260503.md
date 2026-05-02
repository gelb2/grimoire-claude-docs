# Red-Team Update Proposal — 2026-05-03

> **작성**: Claude 메인 세션 (#10_6 묶음 BB 시범 운영)
> **출처**: pending.jsonl 5건 (whitelist 정합 확인 완료)
> **사용자 승인 게이트**: 본 proposal Read 후 명시 승인 시만 적용
> **적용 대상**: red-team-constitution.md / sensor-adversarial-pre-commit.sh / socratic-self-critique skill / adversarial-retry-handler.sh

---

## 0. 시범 운영 메타

본 proposal은 **자율학습 3단 분리의 첫 시범 운영** 결과 (#10_6 묶음 Z 박제).
- α-자율 (수집): pending.jsonl 5건 박제 ✅
- α-반자율 (Propose): 본 문서 ✅
- **사용자 승인 게이트**: ⏳ 대기 중

---

## 1. red-team-constitution.md 갱신 후보 (3 신규 Principles)

### Principle 17 — LLM Prompt Injection 방어 (NEW, OWASP LLM01)
- **현재**: 부재
- **제안**: 사용자 입력 (AI 채팅 / 분석 입력 / 테마 설명)에 prompt injection 의심 패턴 자동 검증
- **근거**: OWASP LLM Top 10 #1 — "Prompt Injection이 LLM 응용 최우선 위협"
- **위험**: false positive 시 정상 사용자 입력 차단 가능성
- **사용자 결정**: [ ] 적용 / [ ] 부분 / [ ] 거절 / [ ] 보류

### Principle 18 — LLM Output Encoding (NEW, OWASP LLM02)
- **현재**: dangerouslySetInnerHTML 사용 0건 (이미 정합)
- **제안**: LLM 응답을 Next.js 렌더링 전 검증 패턴 박제 (현행 명시)
- **근거**: OWASP LLM Top 10 #2 — "Insecure Output Handling이 downstream security exploits 야기"
- **위험**: 낮음 (현재 정합 — 명시 박제만)
- **사용자 결정**: [ ] 적용 / [ ] 부분 / [ ] 거절 / [ ] 보류

### Principle 19 — Sensitive Information Disclosure 강화 (NEW, OWASP LLM06)
- **현재**: sensor-secret-leak 보유 (시크릿 평문 검출)
- **제안**: 환경변수 노출 / DB 스키마 정보 노출 / 사용자 PII 마스킹 검증 추가
- **근거**: OWASP LLM Top 10 #6 — "Sensitive Information Disclosure 방지를 위한 데이터 분류 + 마스킹"
- **위험**: 작가 콘텐츠 보호(P3)와 시너지
- **사용자 결정**: [ ] 적용 / [ ] 부분 / [ ] 거절 / [ ] 보류

→ **결정 시 Constitution 16 → 19 principles로 확장**

---

## 2. sensor-adversarial-pre-commit.sh 갱신 후보

### 추가 검증 패턴 3건

#### Pattern A — LLM Prompt Injection 휴리스틱
- 사용자 입력에 패턴 grep:
  - "ignore previous instructions"
  - "system prompt"
  - "you are now"
  - "</prompt>"
- 위치: grimoire-server controller (input DTO 검증 영역)

#### Pattern B — LLM Output Encoding 검증
- grimoire-web에서 LLM 응답 렌더링: `dangerouslySetInnerHTML.*ai|llm|claude` grep → 0건 강제
- 이미 정합 — 명시 박제

#### Pattern C — Sensitive Info Disclosure 정규식
- 환경변수 노출 패턴 / DB 스키마 노출 패턴 / PII 응답 평문 패턴

→ **결정 시 sensor 자체 패턴 +3 (P17/P18/P19 매핑)**

---

## 3. socratic-self-critique skill 갱신 후보

### 4 새 Socratic 질문 추가 (Q00/ouroboros 차용)

#### Q11 — 존재론적 (Contrarian)
> "이것이 정말 필요한가? 반대라면 어떻게 되나?"

#### Q12 — 경계 (Boundary)
> "어디서 끝나는가? 범위가 명확한가?"

#### Q13 — 증거 (Evidence)
> "이를 어떻게 알 수 있나? 실측 근거는?"

#### Q14 — Lateral Personas
> "Hacker / Simplifier / Researcher / Skeptic / User 관점에서 검토했나?"

### Ambiguity 정량 공식 도입 (NEW)

**현재**: "확실/추정" 키워드 정성 검증
**제안**: `Ambiguity = 1 - Σ(clarity_i × weight_i)`
- clarity_i: 각 답변의 명확도 (0~1)
- weight_i: 질문 가중치
- **임계**: ≤ 0.2 → 완료 가능 / > 0.2 → 재검증

→ **결정 시 socratic-self-critique 7~10 질문 → 10~14 질문 + 정량 공식**

---

## 4. adversarial-retry-handler.sh 갱신 후보 (제한적)

### Cost Gate Scoring 명시화 (외부 API 0 영역만)
- **Score ≤ 0**: Report만 생성 (현재 우리 패턴 정합 — 명시 박제)
- **Score 1~4 / ≥5**: LLM 호출 동반 → **사용자 0-1 결정 위반 — 보류**

### Cross-model consensus = LLM 동반 → **보류 (외부 API 의존)**

→ **결정 시 cost gate scoring 명시 박제만 (LLM 영역은 Phase δ로 이관)**

---

## 5. 신규 Skill 후보 (obra/superpowers 차용)

### 5-1. dispatching-parallel-agents (NEW Skill)
- 병렬 서브에이전트 dispatching 프로토콜
- §15.7 위임 가치 매트릭스 + orchestration-decision skill 강화

### 5-2. requesting-code-review (NEW Skill)
- 사전 검토 체크리스트
- verification-before-completion + sensor-adversarial-pre-commit 시너지

→ **결정 시 Skills 22 → 24**

---

## 6. 위험 평가 (책 Ch 23 안티패턴 검증)

| 안티패턴 | 본 proposal 검증 |
|---------|----------------|
| **#4 모델 의존 착각** | ❌ 회피됨 — 자동 적용 X (사용자 승인 게이트) |
| **#7 거버넌스 부재** | ❌ 회피됨 — proposal 박제 + 사용자 결정 영역 |
| **보안 Layer 1 (prompt injection)** | ❌ 회피됨 — whitelist 5 출처 모두 정합 (anthropic/owasp/github MIT) |
| **§0 ZERO-TOLERANCE** | ❌ 회피됨 — 모든 propose는 출처 인용 + WebFetch 직접 검증 |
| **외부 API 0 (사용자 0-1)** | ❌ 회피됨 — WebFetch만 (Claude Code 기본 도구) |

---

## 7. 사용자 결정 영역

다음 중 명시 후 적용:
- [ ] **전체 적용** (Principles 17/18/19 + sensor 3 패턴 + skill 4 질문 + Ambiguity 공식 + 신규 2 skill)
- [ ] **부분 적용** (위 §1~§5에서 ✅ 표시 항목만)
- [ ] **거절** (사유 박제)
- [ ] **보류** (다음 주 재검토)
- [ ] **개별 검토 필요**

### 적용 시 절차 (사용자 승인 후)
1. `git checkout -b auto-evolve/red-team-20260503` (별도 브랜치, main 직접 X)
2. constitution / sensor / skill 갱신
3. 회귀 검증 (regression + adversarial sensor 자체)
4. **회귀 PASS 시에만** develop 머지 propose
5. develop → main 머지는 사용자 명시 시 (J8)

### FAIL 시 (회귀 깨짐)
- proposal 자체 폐기

---

## 8. 출처 (whitelist 정합 5건)

| 출처 | 박제 내용 |
|------|----------|
| docs.anthropic.com (→ code.claude.com redirect) | Skills frontmatter 베스트 프랙티스 (다음 fetch 후 추가 박제 필요) |
| owasp.org/www-project-top-10-for-large-language-model-applications/ | LLM01/02/06 적용 가능성 + 우리 환경 우선순위 |
| github.com/Q00/ouroboros | 4 새 Socratic 질문 + Lateral Diamond + Ambiguity 정량 공식 |
| github.com/ng/adversarial-review | Bounded Loop 3단계 + Cost Gate Scoring + Cross-model consensus |
| github.com/obra/superpowers | dispatching-parallel-agents / requesting-code-review skill 후보 |

---

## 9. 본 proposal 메타

- **수집 단계**: red-team-data-collector add 5건 (whitelist 정합 100%)
- **WebFetch 단계**: 5 출처 fetching (외부 API 0 — Claude Code 기본 도구)
- **Propose 단계**: 본 문서
- **사용자 승인 게이트**: ⏳ 대기 중
- **시범 운영 결과**: 자율학습 3단 분리 패턴 정합 작동 확인 ✅

---

## 10. 적용 방향 깊은 분석 (2026-05-03 사용자 추가 요구)

본 proposal 5 영역 각각의 위험/가치/자율 적용 가능성 정밀 분석:

### 10-1. 자율 적용 가능 (외부 API 0, 위험 작음, 회귀 영향 작음)

| 항목 | 영역 | 위험 | 회귀 영향 | 자율 적용 |
|------|------|------|----------|----------|
| **P18 명시 박제** | Constitution + sensor | 0 (이미 정합) | 0 | ✅ 즉시 가능 |
| **P19 강화** | Constitution + sensor-secret-leak 확장 | 작음 (정적 분석 강화) | 작음 | ✅ 즉시 가능 |
| **§2 sensor LLM02 패턴** | sensor 추가 (dangerouslySetInnerHTML grep) | 0 (이미 정합) | 0 | ✅ 즉시 가능 |
| **§2 sensor LLM06 패턴** | sensor 추가 (env/DB/PII grep) | 작음 | 작음 | ✅ 즉시 가능 |
| **§3 socratic +4 질문** | skill SKILL.md 갱신 | 0 (메타 프롬프트) | 0 | ✅ 즉시 가능 |
| **§3 Ambiguity 정량 공식** | skill 본문 추가 | 0 | 0 | ✅ 즉시 가능 |
| **§4 cost gate 명시 박제** | retry-handler 주석 강화 (외부 API 0 영역만) | 0 | 0 | ✅ 즉시 가능 |

→ **묶음 CC 적용 가능** (~2시간)

### 10-2. 사용자 결정 영역 (server 코드 변경 동반)

| 항목 | 영역 | 사유 |
|------|------|------|
| **P17 controller 보강** | server 도메인 (NestJS controller 입력 검증) | server 코드 변경 = 사용자 명시 영역 (J8/Phase δ 정합) |
| **§2 sensor LLM01 패턴 (sensor만)** | sensor 추가 | 자율 가능하지만 P17 controller 보강과 함께 적용이 정합 |

→ 사용자 명시 후 진행 (Phase δ 또는 별도 묶음)

### 10-3. 중첩 우려 — 사용자 검토 필요

| 항목 | 우리 보유 | 차별점 분석 | 추천 |
|------|---------|-----------|------|
| **§5 dispatching-parallel-agents** | orchestration-decision skill | orch-decision = 단일 위임 결정 / dispatching = 다중 동시 dispatching → **차별점 있음** | ⚠️ 사용자 검토 후 결정 (적용 가치 vs 인벤토리 비대 |
| **§5 requesting-code-review** | verification-before-completion + sensor-adversarial-pre-commit | verification = 실측 강제 / adversarial = 16 principles / requesting = 사용자/외부 review 트리거 → **약간 차별** | ⚠️ 사용자 검토 (중첩 vs 사용자 트리거 가치) |

→ 사용자 검토 후 결정 (단순 적용 시 책 Ch 23 안티패턴 ② "규칙 폭발" 위험)

---

## 11. 추천 적용 순서

### 옵션 A — **즉시 적용 가능한 것만 자율** (묶음 CC, ~2시간) — **추천**
- §10-1 7 항목 일괄 적용
- 별도 commit + 회귀 검증
- main 머지는 사용자 결정 (J8)

### 옵션 B — 사용자 검토 후 적용 (J8 후)
- §10-2 P17 server controller 보강 (사용자 명시 시)
- §10-3 §5 신규 skills (사용자 검토 후 결정)

### 옵션 C — 전체 적용 (사용자 직접 결정 + 일부 자율)
- §10-1 자율 + §10-2/§10-3 사용자 명시
- 묶음 CC + 묶음 DD (server 영역) + 묶음 EE (skill 영역)

---

## 12. 사용자 결정 후보 (정리)

다음 중 명시 후 자율 진행:
- [ ] **옵션 A 진행** (묶음 CC — §10-1 7 항목 자율 적용, ~2시간)
- [ ] **옵션 B 진행** (§10-2 P17 server controller 보강 — 사용자 명시 시 진행)
- [ ] **옵션 C 진행** (§10-1 자율 + §10-2/§10-3 사용자 추가 결정)
- [ ] **§5 신규 2 skills 검토 결과**:
   - dispatching-parallel-agents [ ] 적용 / [ ] 거절
   - requesting-code-review [ ] 적용 / [ ] 거절
- [ ] **거절** (proposal 전체 폐기)
- [ ] **보류** (다음 주 재검토)

---

## 변경 이력
- 2026-05-03 #10_6 묶음 BB 시범 운영: 본 proposal 신설 (자율학습 첫 결과 박제)
- 2026-05-03 #10_6 적용 방향 분석 (사용자 추가 요구): §10/§11/§12 추가 — 자율/결정/중첩 분류
- 사용자 승인 게이트 — 적용 X
