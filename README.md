# 八字排盘 · Bazi Chart PWA

A Bazi (八字) four-pillar chart calculator and analysis app, built with Flutter for web (installable PWA).

**Live app:** https://kth2.github.io/bazi-app/

## Features

- **排盘**: four pillars from solar or lunar birth date, true solar time correction by birth location, 十神, 藏干, 纳音, 神煞, 空亡, 命宫/身宫/胎元
- **干支直入**: already know the 八字? Enter the four pillars directly (月柱/时柱 options auto-derived via 五虎遁/五鼠遁) and the app reverse-searches 1900-2049 for matching solar dates — no 干支历 lookup needed
- **五行力量**: weighted element scoring (hidden-stem proportions, 月令 weighting, 旺相休囚死) with 身强/身弱/中和 verdict
- **岁运**: full 大运 → 流年 → 流月 → 流日 drill-down timeline (jieqi-bounded months)
- **命理分析**: weighted rule engine (SQLite via drift) with partial-match scoring across 整体命局/财富/事业/学历/婚姻/健康, rules sourced from 渊海子平, 子平真诠, 三命通会
- **AI 深度分析**: 格局法 pattern detection (格局/用神/特殊场景 like 财破印, 伤官见官, 比劫合官), matches analogous real-world example cases, and prompts Gemini or OpenRouter for a 4-category reading (事业财富/婚姻感情/学习发展/健康) at whole-life, 大运, 流年, 流月, or 流日 scope — monthly readings forecast concrete events with likely trigger days (应期), daily readings give event likelihood plus 宜忌 advice. Results cached locally.

## AI setup (bring your own free key)

Open the ⚙️ settings on the chart page. Four providers are supported, each with its **own independently stored key** (switching providers never overwrites another key):

- **Gemini**: free key from [Google AI Studio](https://aistudio.google.com)
- **OpenRouter**: free key from [openrouter.ai](https://openrouter.ai) — the model picker lists only currently available `:free` models, fetched live
- **Agnes**: free key from [platform.agnes-ai.com](https://platform.agnes-ai.com) (free tier ~20 requests/min)
- **其他 (Other)**: any OpenAI-compatible service — set Base URL + key + model

The 🔎 button next to the model field fetches the provider's live model list so you always pick one that actually exists. Keys are stored in your browser's local storage only.

## Install on your phone

Open the live URL in Chrome (Android) or Safari (iOS) → browser menu → **Add to Home Screen / 添加到主屏幕**.

## Development

```bash
flutter pub get
dart run build_runner build     # drift codegen
flutter test
flutter run -d chrome
```

## Deploy (GitHub Pages)

```bash
flutter build web --release --base-href "/bazi-app/"
cd build/web
git init -b gh-pages && git add -A && git commit -m deploy
git push -f https://github.com/kth2/bazi-app.git gh-pages
```

## Calculation engine

Built on [bazi_core](https://pub.dev/packages/bazi_core) (true solar time via sxwnl astronomical algorithms). Chart accuracy is covered by tests against historically known charts.
