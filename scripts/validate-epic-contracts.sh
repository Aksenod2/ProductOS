#!/usr/bin/env bash
# Проверяет статический слой контрактов стыков полной дорожки.
# Usage: validate-epic-contracts.sh <path/to/docs/epics/slug>

set -eu

EPIC_DIR="${1:-}"
MANIFEST="$EPIC_DIR/MANIFEST.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -n "$EPIC_DIR" ] || fail "укажи папку эпика"
[ -f "$MANIFEST" ] || fail "нет $MANIFEST"

contracts=$(grep -c '^### Стык ' "$MANIFEST" || true)
[ "$contracts" -gt 0 ] || fail "в MANIFEST.md нет контрактов стыков"

for field in 'Класс' 'Что передаётся' 'Формат' 'Валидация на входе' 'Что при ошибке'; do
  count=$(grep -c "^- \*\*${field}:\*\*" "$MANIFEST" || true)
  [ "$count" -eq "$contracts" ] || fail "поле '${field}': ${count}, стыков: ${contracts}"
done

if grep -qE '<[^>]+>|требует уточнения' "$MANIFEST"; then
  fail "в активных контрактах остались плейсхолдеры или неразрешённые значения"
fi

echo "PASS: $contracts контракт(а/ов), статический формат соблюдён"
