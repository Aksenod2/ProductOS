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
[ "$role_count" -eq 18 ] || fail "ожидалось 18 мастер-ролей, найдено $role_count"

exam_count=$(grep -Ec '^### [A-Z][0-9]+\.' "$ROOT/team/evals/EXAMS.md" || true)
[ "$exam_count" -eq 36 ] || fail "ожидалось 36 экзаменов, найдено $exam_count"

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

echo "PASS: 18 ролей, 36 экзаменов, контракты и push-gate проверены"
