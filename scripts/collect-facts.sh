#!/bin/bash
# collect-facts.sh — собирает объективные метрики, которые Qwen не может подделать
# Запускается ПЕРЕД агентом, результат инжектится в промпт как контекст
# Аргумент: $1 = путь к проекту (workdir), по умолчанию ProductOS

set -euo pipefail

PROJECT="${1:-/Users/denis/Desktop/vault/projects/ProductOS}"
TEAM="$PROJECT/team"
LOGS="$PROJECT/logs"
TODAY=$(date +%Y-%m-%d)
FACTS_FILE="$LOGS/raw/facts-$TODAY.json"

mkdir -p "$LOGS/raw"

# --- Git метрики (если проект — git-репо) ---
GIT_COMMITS=0
GIT_REVERTS=0
GIT_HASH=""
if git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1; then
    GIT_COMMITS=$(git -C "$PROJECT" log --oneline --since="1 day ago" 2>/dev/null | wc -l | tr -d ' ')
    GIT_REVERTS=$(git -C "$PROJECT" log --oneline --since="1 day ago" 2>/dev/null | grep -ci 'revert\|rollback\|undo' || true)
    GIT_HASH=$(git -C "$PROJECT" rev-parse --short HEAD 2>/dev/null || echo "none")
fi

# --- Экзамены: считаем прогоны в SCORECARD ---
EXAMS_PASS=0
EXAMS_PARTIAL=0
EXAMS_FAIL=0
EXAMS_TOTAL=0
LATEST_SCORECARD=$(ls -t "$TEAM"/evals/SCORECARD-*.md 2>/dev/null | head -1 || echo "")
if [ -n "$LATEST_SCORECARD" ] && [ -f "$LATEST_SCORECARD" ]; then
    # Парсим итоговую строку вида "13 PASS · 2 PARTIAL · 0 FAIL из 15"
    SCORE_LINE=$(grep -o '[0-9]* PASS.*FAIL.*[0-9]*' "$LATEST_SCORECARD" | head -1 || echo "")
    if [ -n "$SCORE_LINE" ]; then
        EXAMS_PASS=$(echo "$SCORE_LINE" | grep -o '[0-9]*' | sed -n '1p' || echo 0)
        EXAMS_PARTIAL=$(echo "$SCORE_LINE" | grep -o '[0-9]*' | sed -n '2p' || echo 0)
        EXAMS_FAIL=$(echo "$SCORE_LINE" | grep -o '[0-9]*' | sed -n '3p' || echo 0)
        EXAMS_TOTAL=$(echo "$SCORE_LINE" | grep -o '[0-9]*' | sed -n '4p' || echo 0)
    fi
fi

# --- DEBTS ---
DEBTS_TOTAL=0
DEBTS_OPEN=0
DEBTS_CLOSED=0
if [ -f "$PROJECT/docs/DEBTS.md" ]; then
    DEBTS_TOTAL=$(grep -c '^|' "$PROJECT/docs/DEBTS.md" 2>/dev/null || echo 0)
    DEBTS_OPEN=$(grep -c '🟡\|🔴\|открыт\|в работе' "$PROJECT/docs/DEBTS.md" 2>/dev/null || echo 0)
    DEBTS_CLOSED=$(grep -c '✅' "$PROJECT/docs/DEBTS.md" 2>/dev/null || echo 0)
fi

# --- Дайджесты: сколько уже есть ---
DIGEST_COUNT=$(ls "$LOGS"/digest-*.md 2>/dev/null | wc -l | tr -d ' ' || echo 0)

# --- Вывод JSON ---
cat > "$FACTS_FILE" <<EOF
{
  "date": "$TODAY",
  "project": "$PROJECT",
  "git": {
    "commits_today": $GIT_COMMITS,
    "reverts_today": $GIT_REVERTS,
    "head": "$GIT_HASH"
  },
  "exams": {
    "pass": $EXAMS_PASS,
    "partial": $EXAMS_PARTIAL,
    "fail": $EXAMS_FAIL,
    "total": $EXAMS_TOTAL,
    "latest_scorecard": "$(basename "$LATEST_SCORECARD")"
  },
  "debts": {
    "total": $DEBTS_TOTAL,
    "open": $DEBTS_OPEN,
    "closed": $DEBTS_CLOSED
  },
  "meta": {
    "digests_total": $DIGEST_COUNT,
    "team_roles": $(ls "$TEAM"/agents/*.md 2>/dev/null | wc -l | tr -d ' ' || echo 0)
  }
}
EOF

cat "$FACTS_FILE"
