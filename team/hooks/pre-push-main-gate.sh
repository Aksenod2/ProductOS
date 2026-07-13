#!/usr/bin/env bash
# PreToolUse (Bash): fail-closed запрет прямого push в прод-ветку.
# Прод-ветка изменяется только через PR/merge после CI и обязательных verdict-ов.

set -u

PROD_BRANCH="{{PROD_BRANCH}}"
INPUT=$(cat)

CMD=$(printf '%s' "$INPUT" | node -e '
let d=""; process.stdin.on("data",c=>d+=c); process.stdin.on("end",()=>{
  try { const j=JSON.parse(d); process.stdout.write(String(j.tool_input?.command||"")); }
  catch { process.exitCode=2; }
});' 2>/dev/null) || {
  echo "⛔ Не удалось проверить команду push: policy gate работает fail-closed." >&2
  exit 2
}

printf '%s' "$CMD" | grep -qE 'git[[:space:]]+push' || exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT" 2>/dev/null || {
  echo "⛔ Не удалось определить репозиторий для проверки push." >&2
  exit 2
}

PUSH_PART=$(printf '%s' "$CMD" | sed -n 's/.*\(git[[:space:]]\{1,\}push\)/\1/p')
TARGETS_PROD=0

if printf '%s' "$PUSH_PART" | grep -qE "(^|[[:space:]:])${PROD_BRANCH}([[:space:]]|$)"; then
  TARGETS_PROD=1
else
  ARGS=$(printf '%s' "$PUSH_PART" | sed 's/^git[[:space:]]*push//' | sed 's/[;&|].*$//')
  REFSPEC=""
  POS=0
  for tok in $ARGS; do
    case "$tok" in
      -*) continue ;;
      *) POS=$((POS + 1)); [ "$POS" -eq 2 ] && REFSPEC="$tok" ;;
    esac
  done
  if [ -z "$REFSPEC" ]; then
    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    [ "$BRANCH" = "$PROD_BRANCH" ] && TARGETS_PROD=1
  fi
fi

[ "$TARGETS_PROD" -eq 1 ] || exit 0

cat >&2 <<MSG
⛔ Прямой push в ${PROD_BRANCH} запрещён стандартом Dream Team.
Отправь рабочую ветку, создай PR, дождись CI и обязательных security/release-контрактов.
Сбой PR-инструмента не является разрешением обхода: остановись и эскалируй владельцу проекта.
MSG
exit 2
