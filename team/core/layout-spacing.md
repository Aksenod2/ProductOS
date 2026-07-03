# Канон: отступы между элементами — только на уровне лейаута

**Статус:** канон команды, принят стейкхолдером 2026-07-02.

Шкала отступов определяется дизайн-системой проекта; в проекте канон конкретизируется файлом `design-kit/shared/layout-spacing.md`.

---

## Правило (обязательно, без вариантов)

1. **Расстояния между соседними элементами задаёт родительский layout-контейнер** —
   `gap` у flex/grid-контейнера, `Stack spacing`, `Grid spacing`. Значение — токен шага из дизайн-системы проекта, не произвольное число.
2. **Компонент (кубик) не имеет внешних отступов.** Никаких `margin` (и его вариантов:
   `mt/mb/ml/mr/mx/my`) у корня кубика и никаких margin у детей вдоль оси раскладки.
   Кубик заканчивается на своей видимой границе — где он встанет и с каким зазором, решает экран.
3. **Padding — только внутреннее пространство контейнера**: от собственного края
   карточки/панели/кнопки до её контента. Padding НЕ используется, чтобы создать
   расстояние до соседнего элемента.
4. **Внутри кубика — то же правило**: вертикальный/горизонтальный ритм между его
   внутренними элементами задаётся gap его внутренних flex-колонок/рядов, не
   margin'ами детей. Разные зазоры = вложенные стеки с разными gap (паттерн The Stack).

---

## Почему так (первоисточники)

1. **Braid Design System (Seek)** — «components should not provide surrounding white
   space… spacing between elements is owned entirely by layout components. This approach
   ensures that the system is as composable as possible while keeping white space
   completely predictable». → компонент переносим, зазоры предсказуемы.
   <https://seek-oss.github.io/braid-design-system/foundations/layout>

2. **Max Stoiber, «Margin considered harmful»** — «A component should not affect anything
   outside its own visual boundaries»; «One specific margin around a component cannot be
   ideal for all instances»; отступ — свойство контекста, поэтому им владеет родитель.
   <https://mxstbr.com/thoughts/margin>

3. **Every Layout, The Stack** — «margin is really a property of the *relationship*
   between two proximate elements… The trick is to style the context, not the individual
   element(s)»; margin у элемента «правилен» лишь случайно, у контекста — всегда.
   <https://every-layout.dev/layouts/stack/>

4. **Storybook** — компонент в стори рендерится «голым», внешние поля даёт среда:
   параметр `layout: padded` и декораторы обёртывают снаружи. Компонент с собственным
   margin в изоляции не воспроизводим.
   <https://storybook.js.org/docs/configure/story-layout>

5. **MUI Stack** — «manages the layout of its immediate children… with optional spacing»;
   «Customizing the margin on the children is not supported by default» — сам фреймворк
   отдаёт spacing родителю и блокирует margin у детей.
   <https://mui.com/material-ui/react-stack/>

**Сжатое «почему» в 3 тезиса:**
- **Переиспользуемость:** один и тот же кубик стоит в разных местах с разными зазорами —
  зазор принадлежит месту, не кубику.
- **Предсказуемость:** все расстояния экрана читаются в одном месте (лейауте), а не
  размазаны по внутренностям компонентов; нет «невидимых» полей и схлопывания margin.
- **Соответствие мышлению дизайна:** дизайнер задаёт ритм композиции, а не свойства
  отдельного элемента; gap + шкала токенов = ритм из макета один в один.

---

## Разрешённые исключения (закрытый список — больше ничего)

| # | Что | Почему это не отступ | Пример |
|---|---|---|---|
| E1 | Сдвиг **поперёк оси раскладки** для выравнивания (иконка/точка к строке текста в горизонтальном ряду) | выравнивание по cross-axis, расстояние до соседа вдоль оси задаёт gap | точка `mt:'6px'` к первой строке в горизонтальном ряду |
| E2 | **Оптическая микроподгонка ≤ 2px** (компенсация line-height / встроенных отступов фреймворка), с комментарием в коде | компенсация рендеринга, не композиция | `mt:'1px'`, `mt:'-1px'`, `mr:'-2px'` у InputAdornment |
| E3 | **Смещение всплывающего слоя от якоря** (Menu/Tooltip/Popover offset) | позиционирование overlay-слоя, не поток лейаута | `mt:'6px'` у Paper меню селекта |
| E4 | `margin: auto` / `mx:'auto'` для центрирования контейнера, `flex:1`-спейсер | выравнивание свободным пространством, не фиксированный зазор | `mx:'auto'` у страницы |

---

## Чек для ревью

- [ ] У кубика нет внешних margin/padding, создающих расстояние до соседей?
- [ ] Все расстояния на экране заданы layout-уровнем: `gap` / `Stack spacing` / `Grid spacing` с токеном шага?
- [ ] Padding используется только как внутреннее поле контейнера от собственного края?
- [ ] Каждый оставшийся margin подпадает под исключения E1–E4 и (для E2) имеет комментарий?
- [ ] Нет паттерна `&:last-child { mb: 0 }` — это симптом margin-вёрстки, заменить на gap.
