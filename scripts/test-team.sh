#!/usr/bin/env bash
# Быстрая воспроизводимая проверка переносимой Dream Team.

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

for script in "$ROOT"/scripts/*.sh "$ROOT"/team/hooks/*.sh; do
  bash -n "$script"
done

node -e "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'))" \
  "$ROOT/team/hooks/settings-hooks-snippet.json"

role_count=$(find "$ROOT/team/agents" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')
[ "$role_count" -eq 20 ] || fail "ожидалось 20 мастер-ролей, найдено $role_count"

inherit_count=$(grep -l '^model: inherit$' "$ROOT"/team/agents/*.md | wc -l | tr -d ' ')
[ "$inherit_count" -eq "$role_count" ] || \
  fail "все мастер-роли должны оставаться provider-neutral с model: inherit"

routing="$ROOT/team/core/MODEL-ROUTING.md"
[ -f "$routing" ] || fail "нет канона MODEL-ROUTING.md"
for tier in lead standard mechanical; do
  grep -Fq "### $tier " "$routing" || fail "в MODEL-ROUTING.md нет уровня $tier"
done
grep -Fq 'MODEL-ROUTING.md' "$ROOT/team/core/ORCHESTRATOR.md" || \
  fail "ORCHESTRATOR.md не ссылается на MODEL-ROUTING.md"

exam_count=$(grep -Ec '^### [A-Z][0-9]+\.' "$ROOT/team/evals/EXAMS.md" || true)
experimental_exam_count=$(grep -Ec '^### I[0-9]+\.' "$ROOT/team/evals/EXAMS.md" || true)
stable_exam_count=$((exam_count - experimental_exam_count))
[ "$stable_exam_count" -eq 36 ] || \
  fail "ожидалось 36 проверенных экзаменов, найдено $stable_exam_count"
[ "$experimental_exam_count" -eq 4 ] || \
  fail "ожидалось 4 экспериментальных кандидата, найдено $experimental_exam_count"

for design_role in product-architect product-design-reviewer; do
  [ -f "$ROOT/team/agents/$design_role.md" ] || fail "нет роли $design_role"
done

for design_core in PRODUCT-DESIGN-DEPARTMENT.md PRODUCT-DESIGN-NODE-TEMPLATE.md \
  PRODUCT-MAP-TEMPLATE.md TRACEABILITY-TEMPLATE.md \
  PRODUCT-DESIGN-RUN-MANIFEST-TEMPLATE.md; do
  [ -f "$ROOT/team/core/$design_core" ] || fail "нет проектировочного канона $design_core"
done

if grep -Eq '^tools:.*(Edit|Write)' "$ROOT/team/agents/product-design-reviewer.md"; then
  fail "product-design-reviewer должен оставаться технически read-only"
fi

grep -Fq 'PRODUCT-DESIGN-DEPARTMENT.md' "$ROOT/team/core/ORCHESTRATOR.md" || \
  fail "ORCHESTRATOR.md не маршрутизирует отдел проектирования"

grep -Fq 'Владелец не обязан заранее назвать ядро' \
  "$ROOT/team/agents/product-architect.md" || \
  fail "product-architect перекладывает определение ядра на владельца"
grep -Fq '2–3 варианта' "$ROOT/team/agents/product-architect.md" || \
  fail "product-architect не обязан приносить варианты по существенной развилке"
[ -x "$ROOT/scripts/validate-product-design-run.sh" ] || \
  fail "валидатор готового пакета отдела проектирования не исполняемый"

version=$(tr -d '[:space:]' < "$ROOT/VERSION")
printf '%s' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || \
  fail "VERSION должен иметь формат MAJOR.MINOR.PATCH"
grep -Fq "## [$version]" "$ROOT/CHANGELOG.md" || \
  fail "в CHANGELOG.md нет раздела текущей версии $version"

author_path='/Users''/denis'
if grep -R -n -F "$author_path" \
  "$ROOT/README.md" "$ROOT/constitution" "$ROOT/scripts" \
  "$ROOT/team/agents" "$ROOT/team/coach" "$ROOT/team/core" \
  "$ROOT/team/hooks" "$ROOT/team/skills" "$ROOT/team/stakeholder"; then
  fail "в исполняемом каноне остался локальный путь автора"
fi

mkdir -p "$TMP_DIR/valid" "$TMP_DIR/invalid"

cat > "$TMP_DIR/valid/MANIFEST.md" <<'EOF'
# MANIFEST — тест

### Стык C-1: Product Owner → Business Analyst

- **Класс:** свободный
- **Что передаётся:** story и критерии готовности
- **Формат:** Markdown, `TASK.md`
- **Валидация на входе:** BA проверяет story и критерии
- **Что при ошибке:** возврат Product Owner, затем эскалация владельцу проекта
EOF

cat > "$TMP_DIR/invalid/MANIFEST.md" <<'EOF'
# MANIFEST — тест с дырой

### Стык C-1: Product Owner → Business Analyst

- **Класс:** свободный
- **Что передаётся:** story и критерии готовности
- **Формат:** Markdown, `TASK.md`
- **Что при ошибке:** возврат Product Owner
EOF

"$ROOT/scripts/validate-epic-contracts.sh" "$TMP_DIR/valid" >/dev/null

if "$ROOT/scripts/validate-epic-contracts.sh" "$TMP_DIR/invalid" >/dev/null 2>&1; then
  fail "валидатор принял контракт без обязательного поля"
fi

pilot_project="$ROOT/projects/kanban-product-design-pilot"
pilot_run="$pilot_project/docs/product-design/pilot-01"
"$ROOT/scripts/validate-epic-contracts.sh" "$pilot_run" >/dev/null

[ ! -e "$pilot_run/TASK.md" ] || \
  fail "пилот Product Map вообще не должен создавать TASK.md"
[ ! -e "$pilot_run/PRODUCT-MAP.md" ] || \
  fail "пилот не должен заранее создавать Product Map до работы product-architect"
[ ! -e "$pilot_run/DECISIONS.md" ] || \
  fail "пилот не должен заранее создавать журнал решений до первой развилки"
[ ! -e "$pilot_run/TRACEABILITY.md" ] || \
  fail "пилот не должен заранее создавать трассировку до начала проектирования"
[ ! -e "$pilot_run/nodes" ] || \
  fail "пилот не должен заранее создавать проектировочные узлы"
[ ! -e "$pilot_run/reviews" ] || \
  fail "пилот не должен заранее создавать reviewer-артефакты"

if grep -Eq 'product-owner|business-analyst' "$pilot_run/MANIFEST.md"; then
  fail "пилот Product Map не должен включать Product Owner или Business Analyst доставки"
fi

if grep -Fq 'TASK.md' "$pilot_run/MANIFEST.md"; then
  fail "пилот Product Map не должен создавать или обещать TASK.md"
fi

free_design_contracts=$(grep -A2 -E '^### Стык D[1-4]:' "$pilot_run/MANIFEST.md" | \
  grep -Fc '**Класс:** свободный' || true)
[ "$free_design_contracts" -eq 4 ] || \
  fail "все четыре смысловых стыка пилота должны оставаться свободными"

if grep -Eq '(SRC|NODE|DEC)-[0-9]' "$ROOT/team/core/PRODUCT-MAP-TEMPLATE.md"; then
  fail "пользовательская часть Product Map не должна показывать служебные ID"
fi

grep -Fq 'без перенумерации и изменения регистра' \
  "$ROOT/team/core/TRACEABILITY-TEMPLATE.md" || \
  fail "служебная трассировка не защищает сквозные ID от переименования"
grep -Fq 'сам предложит контур, ядро и области' "$pilot_run/MANIFEST.md" || \
  fail "пилот перекладывает проектирование первого контура на владельца"

if "$ROOT/scripts/validate-product-design-run.sh" "$pilot_run" >/dev/null 2>&1; then
  fail "валидатор готового пакета принял ещё не запущенный пилот"
fi

design_repo="$TMP_DIR/product-design-repo"
design_run="$design_repo/docs/product-design/test-01"
mkdir -p "$design_run/nodes" "$design_run/reviews"

cat > "$design_run/MANIFEST.md" <<'EOF'
# MANIFEST — тестовый пакет

- **Статус:** `designing`
- **Существенные развилки:** DECISIONS.md
- **Текущий reviewer-отчёт:** `pending`

| Задача | Роль | Уровень | Runtime / agent ID | Модель | Выход | Статус |
|---|---|---|---|---|---|---|
| Проектирование | product-architect | lead | architect-1 | test | карта | done |
| Проверка | product-design-reviewer | lead | reviewer-1 | test | verdict | pending |
EOF
cat > "$design_run/PRODUCT-MAP.md" <<'EOF'
# Product Map

| Область | Детали |
|---|---|
| Работа с карточкой | [Подробности](nodes/card-work.md) |
EOF
cat > "$design_run/SOURCE-REGISTER.md" <<'EOF'
# Источники
EOF
cat > "$design_run/DECISIONS.md" <<'EOF'
# Решения
EOF
cat > "$design_run/TRACEABILITY.md" <<'EOF'
# Трассировка
EOF
cat > "$design_run/nodes/card-work.md" <<'EOF'
# Работа с карточкой
EOF
git -C "$design_repo" init -q
git -C "$design_repo" add .
git -C "$design_repo" -c user.name='Dream Team Test' \
  -c user.email='test@example.invalid' commit -qm 'candidate product design package'
content_commit=$(git -C "$design_repo" rev-parse HEAD)

cat > "$design_run/reviews/01.md" <<EOF
# Вердикт: PASS
- **Проверенный commit:** \`$content_commit\`
EOF
sed 's/\*\*Статус:\*\* `designing`/\*\*Статус:\*\* `ready_for_owner`/' \
  "$design_run/MANIFEST.md" > "$design_run/MANIFEST.next"
mv "$design_run/MANIFEST.next" "$design_run/MANIFEST.md"
sed 's/\*\*Текущий reviewer-отчёт:\*\* `pending`/\*\*Текущий reviewer-отчёт:\*\* `reviews\/01.md`/' \
  "$design_run/MANIFEST.md" > "$design_run/MANIFEST.next"
mv "$design_run/MANIFEST.next" "$design_run/MANIFEST.md"
git -C "$design_repo" add .
git -C "$design_repo" -c user.name='Dream Team Test' \
  -c user.email='test@example.invalid' commit -qm 'record passing review'
"$ROOT/scripts/validate-product-design-run.sh" "$design_run" >/dev/null

cat > "$design_run/reviews/02.md" <<EOF
# Вердикт: BLOCK
- **Проверенный commit:** \`$content_commit\`
EOF
sed 's#reviews/01.md#reviews/02.md#' "$design_run/MANIFEST.md" \
  > "$design_run/MANIFEST.next"
mv "$design_run/MANIFEST.next" "$design_run/MANIFEST.md"
git -C "$design_repo" add .
git -C "$design_repo" -c user.name='Dream Team Test' \
  -c user.email='test@example.invalid' commit -qm 'record newer blocking review'
if "$ROOT/scripts/validate-product-design-run.sh" "$design_run" >/dev/null 2>&1; then
  fail "валидатор принял старый PASS вместо актуального BLOCK"
fi

cat > "$design_run/reviews/02.md" <<EOF
# Вердикт: PASS
- **Проверенный commit:** \`$content_commit\`
EOF
sed 's/| product-design-reviewer | lead | reviewer-1 |/| product-design-reviewer | lead | architect-1 |/' \
  "$design_run/MANIFEST.md" > "$design_run/MANIFEST.next"
mv "$design_run/MANIFEST.next" "$design_run/MANIFEST.md"
git -C "$design_repo" add .
git -C "$design_repo" -c user.name='Dream Team Test' \
  -c user.email='test@example.invalid' commit -qm 'reuse author id for reviewer'
if "$ROOT/scripts/validate-product-design-run.sh" "$design_run" >/dev/null 2>&1; then
  fail "валидатор принял одинаковые runtime ID автора и reviewer"
fi

sed 's/| product-design-reviewer | lead | architect-1 |/| product-design-reviewer | lead | reviewer-2 |/' \
  "$design_run/MANIFEST.md" > "$design_run/MANIFEST.next"
mv "$design_run/MANIFEST.next" "$design_run/MANIFEST.md"
git -C "$design_repo" add .
git -C "$design_repo" -c user.name='Dream Team Test' \
  -c user.email='test@example.invalid' commit -qm 'restore independent reviewer'
"$ROOT/scripts/validate-product-design-run.sh" "$design_run" >/dev/null

printf '\nИзменение карты после ревью.\n' >> "$design_run/PRODUCT-MAP.md"
git -C "$design_repo" add .
git -C "$design_repo" -c user.name='Dream Team Test' \
  -c user.email='test@example.invalid' commit -qm 'change map after review'
if "$ROOT/scripts/validate-product-design-run.sh" "$design_run" >/dev/null 2>&1; then
  fail "валидатор принял карту, изменённую после актуального ревью"
fi

map_rel='docs/product-design/test-01/PRODUCT-MAP.md'
git -C "$design_repo" show "$content_commit:$map_rel" > "$design_run/PRODUCT-MAP.md"
git -C "$design_repo" add .
git -C "$design_repo" -c user.name='Dream Team Test' \
  -c user.email='test@example.invalid' commit -qm 'restore reviewed map'
"$ROOT/scripts/validate-product-design-run.sh" "$design_run" >/dev/null

decision_rel='docs/product-design/test-01/DECISIONS.md'
git -C "$design_repo" rm -q "$decision_rel"
git -C "$design_repo" -c user.name='Dream Team Test' \
  -c user.email='test@example.invalid' commit -qm 'delete decisions after review'
if "$ROOT/scripts/validate-product-design-run.sh" "$design_run" >/dev/null 2>&1; then
  fail "валидатор принял удаление DECISIONS.md после актуального ревью"
fi

sed 's/{{PROD_BRANCH}}/main/g' "$ROOT/team/hooks/pre-push-main-gate.sh" \
  > "$TMP_DIR/pre-push-main-gate.sh"

if printf '%s' '{"tool_input":{"command":"git push origin main"}}' | \
  CLAUDE_PROJECT_DIR="$ROOT" bash "$TMP_DIR/pre-push-main-gate.sh" >/dev/null 2>&1; then
  fail "предохранитель разрешил прямой push в main"
fi

printf '%s' '{"tool_input":{"command":"git push -u origin feature/test"}}' | \
  CLAUDE_PROJECT_DIR="$ROOT" bash "$TMP_DIR/pre-push-main-gate.sh" >/dev/null

if printf '%s' '{broken json' | \
  CLAUDE_PROJECT_DIR="$ROOT" bash "$TMP_DIR/pre-push-main-gate.sh" >/dev/null 2>&1; then
  fail "предохранитель не закрылся при повреждённом входе"
fi

echo "PASS: 20 ролей, 36 проверенных экзаменов + 4 экспериментальных кандидата, model routing, отдел проектирования, контракты и push-gate проверены"
