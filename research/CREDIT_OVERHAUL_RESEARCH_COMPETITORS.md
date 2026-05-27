# 크레딧·구독·채팅 과금 개편 — 경쟁사·업계 리서치

> **성격**: 🌊 Live 리서치 — 경쟁사 요금제 + 게임 재화 + 한국 콘텐츠 플랫폼 + fair-use UX.
> **작성**: grimoire-researcher, 2026-05-16. TTL 14일 (요금제는 변동 잦음 — 2026-05-30 재검증 권장).
> **목적**: `research/CREDIT_PRICING_OVERHAUL_PLAN.md` Phase R 연구 산출물. 사용자 결정 방향 = **"구독 중심(옵션 C) + 디노미네이션(옵션 A)" 하이브리드**.
> **종속**: `PLANNING_GRIMOIRE.md` §0(크레딧-원가 철칙) + §8(크레딧 시스템).
> **방법론 주의**: 본 보고서의 수치는 모두 공식/2차 출처 URL 명기. 출처 불명·추정은 `[추정]` 태그.

---

## CRITICAL_CONSTRAINTS (보고서 사용 시 유의)

- **[MUST]** 본 보고서는 경쟁사 사례 수집물. 마진 시뮬레이션·§0 검증은 grimoire-cost-accountant 영역.
- **[MUST]** 요금제 수치는 모두 출처 URL 기준. 환율·정책 변동 시 재검증 필요.
- **[MUST]** 디노미네이션 비율·구독 가격 최종 결정은 사용자 의사결정 게이트(PLAN §7) 사안.

---

## 1. LLM 종량/구독 요금제 실측

### 1-A. 요약 표 — 6개 서비스 과금 모델 분류

| 서비스 | 과금 방식 | 사용자 노출 단위 | fair-use / 한도 설계 | 초과 시 |
|---|---|---|---|---|
| **Anthropic Claude API** | 순수 토큰 종량 | 100만 토큰당 USD (input/output 분리) | 없음 (개발자 대상, rate limit만) | 계속 종량 과금 |
| **OpenAI API** | 순수 토큰 종량 | 100만 토큰당 USD | 없음 (rate limit만) | 계속 종량 과금 |
| **ChatGPT Business** (구 Team) | 월 정액 fair-use | "메시지" (토큰 비노출) | 기본모델 "사실상 무제한", 상위모델 주간 메시지 캡 (예: GPT-5.5 Thinking 3,000/주) | 캡 소진 시 다음 주기 대기 / 하위모델 폴백 |
| **Cursor** | 월 정액 + **크레딧 풀** + 초과 종량 | USD 가치의 크레딧 풀 ($20 플랜=$20 풀) | 풀 = 정액 금액 그대로. Auto 모드는 풀 미차감(무제한) | 풀 소진 시 상위 플랜 업그레이드 **또는** PAYG 종량(마크업 0%) |
| **Perplexity Pro** | 월 정액 fair-use | "쿼리/검색" 횟수 (토큰 비노출) | 기능별 횟수 캡 (Pro Search 무제한, Deep Research 20/월, Lab 25/월) | 캡 소진 시 다음 주기 대기 |
| **GitHub Copilot** | 월 정액 + **AI 크레딧 allotment** + 초과 종량 | 현재 "premium request" → 2026-06-01부터 **AI 크레딧**(토큰 기반) | 플랜별 월 크레딧 할당 (Pro+ $39 플랜=$39 크레딧). 코드 완성은 크레딧 미차감 | 초과 시 종량 과금($0.04/req 현행), 모델별 배수(5×/20×) |

출처:
- Anthropic API 가격: [Claude API Docs — Pricing](https://platform.claude.com/docs/en/about-claude/pricing) / [Finout: Anthropic API Pricing 2026](https://www.finout.io/blog/anthropic-api-pricing)
- ChatGPT Business: [OpenAI Help — ChatGPT Business Models & Limits](https://help.openai.com/en/articles/12003714-chatgpt-business-models-limits) / [CustomGPT: ChatGPT Plus Limits 2026](https://customgpt.ai/chatgpt-plus-limits-2026/)
- Cursor: [Vantage: Cursor Pricing Explained 2026](https://www.vantage.sh/blog/cursor-pricing-explained) / [Finout: What Happened to Cursor Pricing](https://www.finout.io/blog/what-happened-to-cursor-pricing-2026-guide-5-cost-cutting-tips)
- Perplexity: [Finout: Perplexity Pricing 2026](https://www.finout.io/blog/perplexity-pricing-in-2026) / [ScreenApp: Perplexity Pricing 2026](https://screenapp.io/blog/perplexity-pricing)
- GitHub Copilot: [GitHub Blog: Copilot moving to usage-based billing](https://github.blog/news-insights/company-news/github-copilot-is-moving-to-usage-based-billing/) / [GitHub Docs — Premium requests](https://docs.github.com/en/billing/concepts/product-billing/github-copilot-premium-requests)

### 1-B. 핵심 관찰 — 3가지 추상화 계층

업계는 토큰 변동성을 **3단계 추상화 사다리**로 처리한다:

1. **개발자 계층 (날것 노출)** — Anthropic/OpenAI API. 토큰을 그대로 노출. 변동성 대응은 고객(개발자) 몫. → ProjectGrimoire 작가에게 부적합 (작가는 토큰 개념 모름).

2. **소비자 계층 (완전 추상화)** — ChatGPT Business, Perplexity. 토큰을 **"메시지"·"쿼리"** 같은 직관 단위로 완전히 가린다. 월 정액 안에 fair-use로 녹임. 변동성 리스크는 **플랫폼이 전부 흡수**. 단, 헤비유저 적자 방지를 위해 **상위 모델·고비용 기능에만 별도 캡**을 둔다 (Perplexity Deep Research 20/월, ChatGPT GPT-5.5 Thinking 3,000/주).

3. **하이브리드 계층 (정액 풀 + 종량)** — Cursor, GitHub Copilot(2026-06 이후). **월 구독료 = 선불 크레딧 풀**로 환산하고, 풀 소진 시 종량으로 자동 전환. 풀 크기를 "구독료와 동일한 USD 가치"로 잡아 사용자가 가치를 직관적으로 이해 ($20 구독 = $20어치).

> **ProjectGrimoire 시사점**: 사용자가 정한 "구독중심+디노미네이션" 방향은 정확히 **2계층(소비자 추상화) + 3계층(정액 풀)의 결합**이다. 채팅 → 구독 fair-use(2계층), 테마/분석 종량 → 디노미네이션 포인트(3계층의 단위 설계). 업계 검증된 조합.

### 1-C. 주목할 디테일 — Cursor "Auto 모드 무제한"

Cursor는 **저비용 라우팅 모델(Auto 모드)을 크레딧 풀 미차감·무제한**으로 두고, 비싼 프론티어 모델 수동 선택 시에만 풀을 차감한다 ([Vantage](https://www.vantage.sh/blog/cursor-pricing-explained)). → ProjectGrimoire 채팅도 "기본 응답(Haiku 등 저가 모델)은 fair-use 무제한, 긴 컨텍스트·고급 분석은 풀/포인트 차감" 같은 **모델 티어링 기반 한도 설계**가 가능. (모델 티어링 자체는 사용자 보류 항목 — MEMORY 참조. 단 채팅 한도 설계의 한 옵션으로만 기록.)

### 1-D. 경고 사례 — Cursor 가격 개편 반발

Cursor가 2025년 "fast request" 모델 → 토큰 종량으로 전환하며 **사실상 20× 가격 인상**으로 받아들여져 사용자 반발이 컸다 ([Medium: When Cursor silently raised price](https://medium.com/@jimeng_57761/when-cursor-silently-raised-their-price-by-over-20-and-more-what-is-the-message-the-users-are-6af93385f362)). GitHub Copilot도 usage-based 전환에 "같은 값 내고 덜 받는다"는 반발 ([VSM: Devs Sound Off](https://visualstudiomagazine.com/articles/2026/04/27/devs-sound-off-on-usage-based-copilot-pricing-change-you-will-get-less-but-pay-the-same-price.aspx)).
→ **개편 시 마이그레이션 커뮤니케이션이 기능 설계만큼 중요**. 기존 크레딧 잔액 환산(PLAN §7-7)을 "손해 없음"으로 명확히 고지해야 함.

---

## 2. 게임/앱 이중 재화 + 디노미네이션 사례

### 2-A. 하드/소프트 커런시 구조

- **하드 커런시**: 현금으로 구매하는 고가치 재화 (다이아·젬). 예: Hay Day의 diamond, Clash of Clans의 gem.
- **소프트 커런시**: 플레이로 무료 획득하는 범용 저가치 재화 (coin·credit).
- 출처: [Udonis: 12 Types of Mobile Game Currencies](https://www.blog.udonis.co/mobile-marketing/mobile-games/mobile-game-currencies)

### 2-B. 디노미네이션 환율 실측 사례

학술 실험(F2P 의사결정 연구)에서 사용된 실제 환율 설계:
- 현금→다이아: `2€=25D / 5€=55D / 12€=135D`
- 다이아→골드: `4D=65G / 15D=250G / 50D=830G`
- 출처: [CEUR-WS Vol-2186: Economic decision-making in F2P games](https://ceur-ws.org/Vol-2186/paper11.pdf)

관찰: 게임은 **딱 떨어지는 1:100 같은 비율을 거의 안 쓴다.** 일부러 `25D`, `65G` 같은 비정수 비율로 환율 직관 계산을 어렵게 만들어 "실제 현금 체감을 흐린다"(double currency model의 의도된 obfuscation, [Udonis](https://www.blog.udonis.co/mobile-marketing/mobile-games/mobile-game-currencies)).
→ **ProjectGrimoire는 반대 방향이어야 한다.** Grimoire 작가는 비용을 *정확히 이해*해야 신뢰가 생기는 B2B성 도구 사용자. 게임의 obfuscation 패턴은 **차용하지 말 것**. 깔끔한 10진수 비율(1:100/1:1,000)을 권장.

### 2-C. 큰 숫자의 심리 — 인지 부담

- "100,000 보상이 10 보상보다 항상 기분 좋다" — 큰 단위는 만족감을 준다 ([LinkedIn: 50 Things a Game Economy Designer Should Know](https://www.linkedin.com/pulse/50-things-game-economy-designer-should-know-oliver-jones)).
- 그러나 idle game들은 숫자가 너무 커지면 `K/M/B` 약어 표기로 인지 부담을 관리한다 ([InnoGames Blog: Dealing with huge numbers](https://blog.innogames.com/dealing-with-huge-numbers-in-idle-games/)).
- 인지 부담 최소화 = 게임 UX의 핵심 ([Medium: Minimizing Cognitive Load in Game UX](https://medium.com/@coreyhobson/minimizing-cognitive-load-strategies-for-simplifying-complex-systems-in-game-ux-fcc72544c8e3)).

> **시사점**: 큰 단위는 "풍족" 인상을 주지만, **4자리 이상(만 단위) 넘어가면 약어가 필요해진다.** Grimoire 채팅 1턴이 "수십~수백 포인트" 범위에 들어오는 비율이 인지적으로 가장 편하다 (3자리 이내 유지).

---

## 3. 한국 웹소설·창작 플랫폼 재화 단위

| 플랫폼 | 재화명 | 단위 가격 | 환산 구조 | 비고 |
|---|---|---|---|---|
| **네이버 시리즈** | 쿠키 | **1쿠키 = 100원** (웹) / 120원(앱) | 1:1 고정, 수량 할인 없음 | 1·10·30·50·100·200·300·500·700·1000개 묶음 판매 |
| **카카오페이지** | 캐시 | `[추정]` 1캐시 ≈ 1원대 | 캐시 → "이용권"으로 사용 | 공식 환율 수치 미확인 — `[확인 필요]` |
| **노벨피아** | 골드/실버 코인 | `[확인 필요]` | 골드 구매 시 실버 10% 보너스 지급. 코인 → 웹툰코인 자동 환전 | 골드(후원 가능) vs 실버(후원 불가) 이중 재화 |

출처:
- 네이버 쿠키: [나무위키 — 네이버/쿠키](https://namu.wiki/w/%EB%84%A4%EC%9D%B4%EB%B2%84/%EC%BF%A0%ED%82%A4) / [스페셜매뉴얼: 쿠키당 100원 충전팁](https://specialmanual.com/) / [funissu: 네이버 쿠키 충전 꿀팁](https://funissu.com/naver-cookie-charge/)
- 카카오페이지: [나무위키 — 카카오페이지/시스템](https://namu.wiki/w/%EC%B9%B4%EC%B9%B4%EC%98%A4%ED%8E%98%EC%9D%B4%EC%A7%80/%EC%8B%9C%EC%8A%A4%ED%85%9C)
- 노벨피아: [나무위키 — 노벨피아/시스템](https://namu.wiki/w/%EB%85%B8%EB%B2%A8%ED%94%BC%EC%95%84/%EC%8B%9C%EC%8A%A4%ED%85%9C)

### 3-A. 한국 플랫폼 패턴 관찰

1. **단위가 "원"에 1:1 가깝게 정렬됨** — 네이버 쿠키 1개=100원처럼, 한국 콘텐츠 플랫폼은 게임과 달리 **재화-현금 비율을 단순·투명하게** 유지한다. 사용자가 "쿠키 5개 = 500원"을 즉시 계산 가능. (게임의 obfuscation과 정반대 — §2-B와 대조.)
2. **이중 재화는 "획득 경로"로 구분** — 노벨피아 골드/실버는 가치가 같고, 차이는 후원 가능 여부뿐. 즉 한국 플랫폼의 이중 재화는 *가치 위계*가 아니라 *사용처 제한* 기준.
3. **묶음 판매는 수량만 다르고 단가는 동일** — 네이버는 1000개를 사도 1개당 100원 (할인 없음). Grimoire 현 패키지(5개 ₩400/개 → 50개 ₩100/개)는 오히려 한국 콘텐츠 플랫폼보다 게임에 가까운 대량할인 구조.

### 3-B. 차용할 만한 패턴

- **차용 권장**: 네이버 쿠키식 **"재화 ↔ 원화 직관 환산"**. Grimoire 포인트도 "1포인트 ≈ X원" 멘탈모델이 서도록 비율을 잡으면 작가 신뢰↑.
- **차용 권장**: 노벨피아식 **"가치는 같되 사용처가 다른 이중 재화"** — 만약 Grimoire가 "구독 풀 토큰"과 "충전 포인트"를 둘 다 둔다면, 둘을 *가치 동일·소진 우선순위만 다르게*(풀 먼저, 포인트 나중) 설계하면 사용자 혼란 최소화.
- **비차용**: 게임식 비정수 환율(25D 등) obfuscation.

---

## 4. 구독 fair-use 한도 소진 시 UX 패턴

### 4-A. 업계 3대 패턴

| 패턴 | 동작 | 채택 사례 | 사용자 체감 |
|---|---|---|---|
| **다음 주기 대기 (reset)** | 캡 소진 시 기능 잠금, 다음 결제일에 리셋 | ChatGPT Business 상위모델, Perplexity Deep Research | 명확하나 "기다림" 불만 |
| **하위 등급 폴백 (throttle/downgrade)** | 캡 소진 시 저비용 모델·저속으로 계속 제공 | ChatGPT (상위모델 소진 → 기본모델 계속), ISP 속도 throttle | 끊김 없음, "성능 저하" 체감 |
| **종량 전환 (PAYG overage)** | 풀 소진 시 자동 종량 과금으로 무중단 | Cursor, GitHub Copilot | 무중단이나 "예상 못한 청구" 리스크 |

출처: [Solvimon: Overage Charges](https://www.solvimon.com/glossary/overage-charges) / [CustomGPT: ChatGPT Plus Limits 2026](https://customgpt.ai/chatgpt-plus-limits-2026/) / [Finout: Perplexity Pricing](https://www.finout.io/blog/perplexity-pricing-in-2026)

### 4-B. AI 제품 특유의 위험 — Solvimon 경고

> "AI 제품은 종량 질문을 더 복잡하게 만든다. 토큰 비용이 높고 예측 불가하다. 할당량을 2배 초과한 고객은 토큰마다 실제 추론 비용이 있어 $500+ 청구를 맞을 수 있다. **그래서 대부분의 AI 제품은 날것의 overage 과금 대신 크레딧 시스템을 쓴다 — 크레딧은 사용과 청구 사이에 선불 완충재(prepaid buffer)를 만든다.**"
> — [Solvimon Glossary](https://www.solvimon.com/glossary/overage-charges)

> **ProjectGrimoire 직접 시사점**: 이것이 사용자가 정한 "구독중심+디노미네이션" 방향의 업계 정당화 근거다. 채팅 풀 소진 후 **날것의 종량 청구로 직행하지 말고, 선불 충전된 "포인트(디노미네이션 통화)"로 차감**하라. 포인트는 곧 prepaid buffer다. 작가는 절대 "예상 못한 청구"를 안 맞고, 플랫폼은 §0 마진을 포인트 단가에 미리 박아둘 수 있다.

### 4-C. Grimoire 권장 UX 흐름

업계 패턴을 §0 철칙과 결합한 권장 흐름:
1. 구독 플랜 = 월 채팅 fair-use 한도(턴 수 또는 토큰 풀) 포함.
2. 한도 소진 → **하드 차단 대신**, 보유 포인트로 자동 차감 계속 (Cursor식 무중단 + Solvimon식 선불버퍼).
3. 포인트도 0 → 그때 비로소 "다음 주기 대기" 또는 "포인트 충전 유도" (날것 청구 없음).
4. 한도 80%·100% 도달 시 사전 고지 (Cursor/Copilot이 usage reporting 제공하는 이유).

---

## 5. 핵심 질문 답변

### Q1. LLM 서비스들이 토큰 변동성을 사용자에게 어떻게 추상화하는가?
→ **§1-A 표 + §1-B 3계층 사다리** 참조. 요약: ① 개발자용은 토큰 날것 노출, ② 소비자용(ChatGPT/Perplexity)은 "메시지/쿼리"로 완전 추상화 후 월정액 fair-use로 흡수, ③ 하이브리드(Cursor/Copilot)는 "구독료=선불 크레딧 풀"로 환산 + 풀 소진 시 종량. ProjectGrimoire 작가는 토큰 개념이 없으므로 ②+③ 결합이 적합.

### Q2. "구독 토큰 풀 + 초과 종량" 모델의 대표 사례와 한도 설계 방식?
→ **Cursor**와 **GitHub Copilot(2026-06-01 전환)**. 둘 다 **"풀 크기 = 구독료와 동일한 USD 가치"**로 설계 (Cursor $20 플랜 = $20 풀, Copilot Pro+ $39 = $39 크레딧). 사용자가 "내 구독료어치만큼 쓴다"를 직관적으로 이해. 초과분은 마크업 0%의 종량(Cursor) 또는 모델별 배수 종량(Copilot). 코드 완성(저가 기능)은 풀 미차감(Copilot)·Auto 모드 무제한(Cursor)으로 저비용 사용을 무료화 → 헤비유저 적자는 고비용 기능에만 한도 집중.

### Q3. 디노미네이션 비율 중 사용자 인지 부담이 가장 적은 사례 근거?
→ **1:1,000을 권장.** 근거:
- 게임 economy 연구상 "큰 단위가 풍족감을 주지만"(§2-C), idle game은 **4자리(만 단위)를 넘으면 K/M 약어가 필요할 만큼 인지 부담**이 생긴다 ([InnoGames](https://blog.innogames.com/dealing-with-huge-numbers-in-idle-games/)).
- Grimoire 채팅 1턴 원가가 약 ₩3~₩60(PLAN §1-2). 1:1,000이면 채팅 1턴 ≈ **수십~수백 포인트**(3자리 이내), 테마 = 1,000pt, 분석 = 4,000pt(4자리 1개) — 대부분 표시가 3~4자리에 머문다.
- 1:100은 채팅 짧은 턴이 한 자릿수 포인트(예: 6pt)가 되어 디노미네이션 효과가 약하고, 1:10,000은 분석이 40,000pt로 만 단위 진입 → 인지 부담↑.
- 한국 플랫폼 패턴(§3-A)도 "재화-원화 직관 환산"을 중시 → 1:1,000이면 "1,000pt ≈ 기존 1크레딧 가치"라는 깔끔한 멘탈모델 성립.
- 단, **최종 비율은 cost-accountant의 반올림 오차·마진 시뮬(PLAN §4-2) 후 사용자 결정 게이트(§7-1) 사안.** 본 항목은 인지 부담 관점 권고에 한정.

### Q4. 한국 콘텐츠 플랫폼 재화 단위에서 차용할 만한 패턴?
→ **§3-B** 참조. ① 네이버 쿠키식 재화↔원화 1:N 직관 환산(투명성), ② 노벨피아식 "가치 동일·사용처만 다른 이중 재화"(구독 풀 vs 충전 포인트의 소진 우선순위 설계에 적용). ③ 비차용: 게임식 비정수 환율 obfuscation.

### Q5. "구독중심+디노미네이션" 조합에 가장 참고할 벤치마크 3개와 이유

1. **Cursor** — "구독료 = 동일 가치 크레딧 풀 + 초과 시 마크업 0% 종량 + 저가 기능(Auto) 무제한". 사용자가 정한 옵션 C(구독중심)+옵션 A(단일 통화 디노미네이션)의 **거의 완성형 레퍼런스**. 채팅 풀 → 포인트 종량 전환 구조를 그대로 벤치마크 가능. 단 가격 인상 반발(§1-D)은 마이그레이션 반면교사.

2. **GitHub Copilot (2026-06 usage-based 전환)** — "월 구독에 AI 크레딧 allotment 포함 + 코드완성(저비용)은 크레딧 미차감". Grimoire의 "구독에 채팅 fair-use 포함 + 테마 일일 무료분은 포인트 미차감" 구조와 1:1 대응. 토큰을 "크레딧" 단위로 추상화한 점도 디노미네이션 통화 설계의 직접 모델.

3. **네이버 시리즈 쿠키** — 한국 작가/독자에게 가장 익숙한 재화 멘탈모델. "1쿠키=100원, 묶음으로 충전"의 투명·단순함. Grimoire 포인트 표시 UX와 충전 패키지 화면을 한국 사용자 친숙도 기준으로 설계할 때의 로컬 벤치마크. (Solvimon의 prepaid buffer 원리 + 네이버의 투명 환산이 결합되면 작가 신뢰 최적.)

> 보조 참고: Solvimon의 "AI 제품은 크레딧=prepaid buffer를 써라"(§4-B)는 벤치마크라기보다 **전체 방향의 업계 정당화 근거**로 별도 인용 가치.

---

## 6. cost-accountant 핸드오프 메모

본 보고서가 다루지 않은(=cost-accountant 영역) 후속 과제:
- 디노미네이션 비율 최종 확정 — 반올림 오차 + §0 마진 시뮬 (PLAN §4-2).
- 구독 fair-use 한도 역산 — "한도 내 누적 원가 ≤ 구독료 ÷ 3" (PLAN §6).
- 채팅 턴별 토큰 분포 P50/P90/P95/P99 → 옵션별 마진 분포.
- Pro/Premium 월 가격 후보대 마진 검증.
- 본 보고서 §1-A의 Anthropic Sonnet 4.6 가격($3/$15 per 1M, [출처](https://platform.claude.com/docs/en/about-claude/pricing))은 `ai-cost-table.md` 현행값과 대조 필요 — 불일치 시 `reports/COST_ALERT.md` 트리거. (본 sweep 시점 ai-cost-table 직접 대조는 cost-accountant 단독 권한.)

---

## 7. 출처 일람

**LLM 요금제**
- [Claude API Docs — Pricing](https://platform.claude.com/docs/en/about-claude/pricing)
- [Finout — Anthropic API Pricing 2026](https://www.finout.io/blog/anthropic-api-pricing)
- [Vantage — Cursor Pricing Explained 2026](https://www.vantage.sh/blog/cursor-pricing-explained)
- [Finout — What Happened to Cursor Pricing 2026](https://www.finout.io/blog/what-happened-to-cursor-pricing-2026-guide-5-cost-cutting-tips)
- [Medium — When Cursor silently raised price 20×](https://medium.com/@jimeng_57761/when-cursor-silently-raised-their-price-by-over-20-and-more-what-is-the-message-the-users-are-6af93385f362)
- [OpenAI Help — ChatGPT Business Models & Limits](https://help.openai.com/en/articles/12003714-chatgpt-business-models-limits)
- [CustomGPT — ChatGPT Plus Limits 2026](https://customgpt.ai/chatgpt-plus-limits-2026/)
- [Finout — Perplexity Pricing 2026](https://www.finout.io/blog/perplexity-pricing-in-2026)
- [ScreenApp — Perplexity Pricing 2026](https://screenapp.io/blog/perplexity-pricing)
- [GitHub Blog — Copilot moving to usage-based billing](https://github.blog/news-insights/company-news/github-copilot-is-moving-to-usage-based-billing/)
- [GitHub Docs — Copilot premium requests](https://docs.github.com/en/billing/concepts/product-billing/github-copilot-premium-requests)
- [Visual Studio Magazine — Devs Sound Off on Copilot Pricing](https://visualstudiomagazine.com/articles/2026/04/27/devs-sound-off-on-usage-based-copilot-pricing-change-you-will-get-less-but-pay-the-same-price.aspx)

**게임 재화 / 디노미네이션**
- [Udonis — 12 Types of Mobile Game Currencies](https://www.blog.udonis.co/mobile-marketing/mobile-games/mobile-game-currencies)
- [CEUR-WS Vol-2186 — Economic decision-making in F2P games](https://ceur-ws.org/Vol-2186/paper11.pdf)
- [LinkedIn — 50 Things a Game Economy Designer Should Know](https://www.linkedin.com/pulse/50-things-game-economy-designer-should-know-oliver-jones)
- [InnoGames Blog — Dealing with huge numbers in idle games](https://blog.innogames.com/dealing-with-huge-numbers-in-idle-games/)
- [Medium — Minimizing Cognitive Load in Game UX](https://medium.com/@coreyhobson/minimizing-cognitive-load-strategies-for-simplifying-complex-systems-in-game-ux-fcc72544c8e3)

**한국 콘텐츠 플랫폼**
- [나무위키 — 네이버/쿠키](https://namu.wiki/w/%EB%84%A4%EC%9D%B4%EB%B2%84/%EC%BF%A0%ED%82%A4)
- [나무위키 — 카카오페이지/시스템](https://namu.wiki/w/%EC%B9%B4%EC%B9%B4%EC%98%A4%ED%8E%98%EC%9D%B4%EC%A7%80/%EC%8B%9C%EC%8A%A4%ED%85%9C)
- [나무위키 — 노벨피아/시스템](https://namu.wiki/w/%EB%85%B8%EB%B2%A8%ED%94%BC%EC%95%84/%EC%8B%9C%EC%8A%A4%ED%85%9C)
- [스페셜매뉴얼 — 네이버 쿠키 충전](https://specialmanual.com/)

**fair-use / overage UX**
- [Solvimon Glossary — Overage Charges](https://www.solvimon.com/glossary/overage-charges)

---

## FINAL_REMINDER

- 본 보고서는 경쟁사 사례 수집물 — 마진 시뮬·§0 검증·디노미네이션 비율 확정은 grimoire-cost-accountant + 사용자 결정 게이트.
- 모든 수치는 출처 URL 명기. `[추정]`/`[확인 필요]` 태그는 후속 정밀화 대상 (카카오페이지 캐시 환율, 노벨피아 코인 단가).
- TTL 14일 — 2026-05-30 재검증. LLM 요금제는 변동 잦음.

## 변경 이력
- **v1 (2026-05-16)**: grimoire-researcher 초안. LLM 6사 요금제 실측 + 게임 디노미네이션 + 한국 플랫폼 3사 + fair-use UX 4패턴 + 핵심질문 5답 + 벤치마크 Top-3(Cursor/GitHub Copilot/네이버 쿠키).
