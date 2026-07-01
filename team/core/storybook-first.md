# Storybook-first — component-driven разработка

Мы строим интерфейс **компонентами в изоляции сначала**, потом собираем экраны. Это официальная
практика Storybook (component-driven development): базовые компоненты → сложные → страницы. Так все
состояния видны и проверены ДО сборки всего приложения.

Источники: [storybook.js.org — Why Storybook](https://storybook.js.org/docs/get-started/why-storybook) · [componentdriven.org](https://www.componentdriven.org/)

## Правило
- **Сначала компонент в story со ВСЕМИ состояниями** (default / hover / active / disabled / loading /
  empty / error), потом сборка в экран. **Не собирай экран из компонентов, не покрытых сторями.**
- Story — место, где паттерн и все его состояния видны сразу. Полируй и ревьюй компонент **в его
  story (изоляция)**, а не только на живом экране.
- Скрины story снимает `webapp-testing` — отдельный инструмент не нужен.

## По ролям
- **frontend-engineer** — строит компонент в story со всеми состояниями ДО сборки экрана.
- **visual-designer** — полирует компонент в его story, а не только на живом экране.
- **design-lead** — паттерн проверяет по Storybook: нет стори на состояние → паттерн не закрыт.
