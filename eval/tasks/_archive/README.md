# eval/tasks/_archive — 면제 박제 영역

> eval-runner.sh가 `tasks/*.json`만 sort 영역 → `_archive/*.json`은 자동 제외 정합.
> 본 디렉토리는 면제 박제(사유 + 결정 commit) 영역 — 정본 archive.

---

## 면제 사슬 박제

### `11-main-direct-push-blocked.json` — 2026-05-15 archive

**원본 영역**:
- ID: `regression-011`
- 카테고리: convention
- 검증: `.claude/scripts/pretooluse-bash-guard.sh`에 `git push.*origin.*main` 패턴 ≥ 1건 + `.claude/settings.json` 등록 ≥ 1건

**FAIL 박제 시점**: 2026-05-10 22:38 KST 이후 (PAY-P2-5 commit `5f20f1b` 사슬)

**FAIL 원인**:
- 5/10 사용자 verbatim "다 폐기해" 결정 (PP-7 + PP-12 + PP-13 + `pretooluse-bash-guard.sh`까지 영역)
- 4 hook script size 0 → `pretooluse-bash-guard.sh` 142 line 영역 영구 폐기

**5/15 사용자 결정 — 옵션 C 채택 (verbatim)**:
> "권장: C (hook size 0 유지 + task 면제 박제) — 5/10 '다 폐기해' 결정 정합 + pre-push hook이 동일 차단 강제 중."

**면제 사유 정합 매트릭스**:

| 영역 | 박제 |
|---|---|
| 사용자 5/10 결정 정합 | "다 폐기해" 확대 해석 + PP-7/12/13/bash-guard 4 hook 영역 동일 폐기 |
| 실질 차단 강제 영역 대체 | `.githooks/pre-push` hook이 main 직접 push 차단 강제 중 (CLAUDE.md §8 동일 강제) |
| pre-push hook 영역 검증 | `.githooks/pre-push` 영역 main branch 직접 push 분기 박제 정합 |
| 본 task 영역 본질 | hook script size 0이라 PASS 도달 불가능 영역 — 면제 정합 |
| 영역 진입 결정 | hook 복원 X (5/10 결정 번복 위배), task 폐기 X (확대 해석 위배), **archive 면제 박제 ✅** |

**관련 incident-log 박제**:
- 2026-05-14T15:16:16Z (NEW-4 진단, harness agent 자율 박제)
- 2026-05-10T13:20:55Z (PP hook 4건 폐기 박제, 본 세션 직전)
- 2026-05-10T13:12:04Z (PP-7 isSidechain 결함 박제)

**관련 commit 사슬**:
- `5f20f1b` (PAY-P2-5 + PP hook 폐기 영역)
- `f12bc2e` (NEW-4 진단 + H8 + H9, harness agent 자율)
- 본 archive commit (사용자 5/15 옵션 C 채택)

---

## 영역 진입 규칙

1. **archive 영역 task는 eval-runner.sh sort 영역 외부** — `tasks/*.json` glob 매칭 X
2. **면제 사유는 본 README에 박제** — 향후 영역 검증 가능
3. **사용자 결정 verbatim 박제** — 추정 보고 차단 (§0 ZERO-TOLERANCE 정합)
4. **incident-log 영역 사슬 박제** — Mitchell Ghostty 정직 영역 정합

## 영역 복원 규칙 (필요 시)

archive 영역 task 복원 시:
1. `git mv eval/tasks/_archive/{file}.json eval/tasks/{file}.json`
2. 본 README 영역 박제 정정 (복원 사유 박제)
3. eval-runner.sh 자동 재포함 영역 (코드 변경 X)
4. baseline.csv 영역 갱신

---

마지막 갱신: 2026-05-15 (사용자 옵션 C 채택, regression-011 영역 첫 면제 박제)
