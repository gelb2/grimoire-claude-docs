# 센서 시스템

> "AI가 '다 했습니다'라고 말하는 것은 증거가 아니다. 센서 스크립트의 stdout만이 증거다."

vibe-coding-unified-guide.md의 "증거 기반 보고" 원칙을 Grimoire에서 구현한 검증 인프라.

> **⚠️ 정본 = `research/HARNESS_ENGINEERING.md §14.4` (Sensors 전체 인벤토리).**
> 본 문서는 **대표 센서 4종 + 동작 패턴(2중 검증·CoV)** 설명용 부분 발췌다. 센서 개수·전체 목록은 §14.4가 단일 정본이며, 본 표는 카운트 정본이 아니다 (드리프트 방지: 신규 센서 추가 시 §14.4만 갱신 — `bash .claude/scripts/instructions-drift-check.sh`가 §14.4 ↔ 실측 대조). 전체 분류(INJECTABLE/GUARDED/EXISTENCE/EXTERNAL/STUB)는 `bash .claude/scripts/sensor-selftest.sh --list`로 실측.

## 대표 스크립트 (전체 목록 아님 — §14.4 참조)

| 스크립트 | 검증 대상 | 단계 | exit 0 조건 |
|---------|----------|------|-------------|
| `sensor-server.sh` | grimoire-server | tsc + Jest + build + prisma validate (4단계) | 4/4 PASS |
| `sensor-web.sh` | grimoire-web | tsc + Vitest + build (3단계) | 3/3 PASS |
| `sensor-docs-sync.sh` | server↔web docs | 9개 공유 문서 diff | 9/9 일치 |
| `sensor-security-gate.sh` | 보안 16항목 축약 8개 | 가드/admin/쿠키/localStorage/BFF/401/헤더/XSS | 8/8 PASS |

### sensor-security-gate.sh 8개 하위 항목 (2026-04-17 신설)

1. Mutation 엔드포인트 가드 커버리지 (의도적 공개 9개 화이트리스트)
2. Admin 엔드포인트 AdminGuard 커버리지 (admin login 제외)
3. 인증 쿠키 sameSite='strict' 일관성 (grimoire_anon 제외)
4. 웹 localStorage에 token/password/jwt/secret/credential 저장 여부
5. 'use client' 파일에서 외부 API 직접 fetch 여부 (BFF 우회 금지)
6. 운영 보호 엔드포인트 5개 토큰 없이 curl → 401 반환 확인
7. 운영 3개 도메인에 보안 헤더 5종(CSP/HSTS/XFO/XCTO/Referrer) 일관 적용
8. dangerouslySetInnerHTML 사용 여부 (WARN — 정당한 경우 검토)

## 사용법

```bash
# 에이전트(developers/qa)는 작업 후 반드시 실행
.claude/scripts/sensor-server.sh
.claude/scripts/sensor-web.sh
.claude/scripts/sensor-docs-sync.sh
```

exit code 0이 아니면 배포 차단. raw stdout을 reports/DEV_REPORT.md / reports/QA_REPORT.md에 **요약 없이** 전체 첨부.

## 에이전트 규칙 (2중 검증 패턴)

### Phase 4 (developers)
- 코드 변경 후 해당 레포 센서 실행
- raw stdout 전체 → reports/DEV_REPORT.md (요약 금지)
- 1개라도 FAIL이면 커밋 금지

### Phase 5 (qa)
- reports/DEV_REPORT.md의 센서 결과를 읽되, **동일 센서를 독립적으로 재실행**
- dev stdout + qa stdout을 별도 첨부 → reports/QA_REPORT.md
- 대조 판정:

| dev 결과 | qa 결과 | 판정 | 조치 |
|---------|---------|------|------|
| PASS | PASS | ✅ QA PASS | 배포 게이트 통과 |
| PASS | FAIL | 🚨 CRITICAL | 환경 차이 또는 dev 날조 의심. 사용자 에스컬레이션 |
| FAIL | FAIL | ❌ 배포 차단 | developers에게 수정 지시 |
| FAIL | PASS | 🟡 WARN | dev 재실행 권고, 산발적 실패 가능성 |

## GMP v2.2 Chain-of-Verification과의 관계

센서는 CoV의 "독립적 검증 질문" 패턴을 스크립트로 구현한 것:
- 에이전트의 주장(작업 완료 보고) ← 가설
- 센서 실행 stdout ← 독립 검증
- 두 결과가 불일치 → 초안 수정 (= 재작업)

## 현재 미도입 센서 (TODO)

- `sensor-forbidden-words.sh` — 금지어 grep (Zenith 패턴) — 미도입
- ~~`sensor-security-gate.sh`~~ — **도입 완료** (2026-04-17, 위 대표 표 참조). 본 항목 superseded.

> 도입 현황 단일 정본 = §14.4. 본 "미도입" 목록은 §14.4 대비 갭만 기록한다.

## 관련 문서

- `research/HARNESS_ENGINEERING.md` §14.4 — **Sensors 전체 인벤토리 정본**
- `AUTOMATION.md` §3 센서 시스템
- `prompt-engineering/GMP-v2.2.md` §PHASE_3 CoV 기법
- `prompt-engineering/vibe-coding-unified-guide.md` Phase 5 게이트 체크
