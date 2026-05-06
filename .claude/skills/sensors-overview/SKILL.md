---
name: sensors-overview
description: 14개 sensor 인벤토리 + sensor-hit-rate-report (silent sensor 진단) 단축 호출. 사용자 명시 호출만 (`/sensors-overview`).
disable-model-invocation: true
allowed-tools: Bash, Read
effort: low
paths:
  - ".claude/scripts/sensor-*.sh"
owner-agent: grimoire-qa
owner-skill: ""
responsibility-note: "sensor 인벤토리 조회 (qa 도메인)"
---

# Sensors Overview — 14 sensor 인벤토리 + 진단

## 책임 영역 (2026-05-06 묶음 PP-3 박제)

- **owner**: grimoire-qa agent (sensor·검증 도메인)
- **trigger 패턴**: 사용자 입력 키워드 매칭 시 본 skill의 additionalContext 주입 + grimoire-qa agent가 명시 호출
- **메인 책임**: 본 skill을 직접 호출 X — grimoire-qa agent에 위임 후 qa agent가 본 skill 활용

## 사용 패턴

```bash
# 모든 sensor 목록
ls .claude/scripts/sensor-*.sh | xargs -n1 basename

# silent sensor 진단 (30일간 fire 0회)
bash .claude/scripts/sensor-hit-rate-report.sh

# sensor 자체 회귀 (regression task 14, 15, 16, 22 + auto-sensor-*)
bash eval/scripts/eval-runner.sh tasks/14-sensor-server-pass.json
bash eval/scripts/eval-runner.sh tasks/15-sensor-web-pass.json
bash eval/scripts/eval-runner.sh tasks/22-shared-contracts-integrity.json
```

## 14 sensors (2026-04-30 #10 기준)

- sensor-server.sh / sensor-web.sh (빌드)
- sensor-docs-sync.sh (문서 동기화)
- sensor-security-gate.sh / sensor-secret-leak.sh (보안)
- sensor-credit-atomicity.sh (결제)
- sensor-cost-margin.sh (§0 원가)
- sensor-deploy-drift.sh (배포)
- sensor-orchestration-ratio.sh (패턴 1)
- sensor-feedback-promotion.sh (메모리 v2)
- sensor-shared-contracts.sh (Ch 16)
- sensor-instruction-degradation.sh (Ch 08, 2026-04-30 신설)
- sensor-agent-interaction.sh (matrix 정합, 2026-04-30 신설)
- sensor-hit-rate-report.sh / sensor-log.sh (메타 진단)

상세: `AUTOMATION.md` §3, `research/HARNESS_ENGINEERING.md` §14.4
