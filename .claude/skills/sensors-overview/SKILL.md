---
name: sensors-overview
description: 14개 sensor 인벤토리 + sensor-hit-rate-report (silent sensor 진단) 단축 호출. 사용자 명시 호출만 (`/sensors-overview`).
disable-model-invocation: true
allowed-tools: Bash, Read
effort: low
paths:
  - ".claude/scripts/sensor-*.sh"
---

# Sensors Overview — 14 sensor 인벤토리 + 진단

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
