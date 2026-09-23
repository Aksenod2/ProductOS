#!/usr/bin/env bash
# Fail-closed проверка готового пакета отдела проектирования перед показом владельцу.

set -eu

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[ "$#" -eq 1 ] || fail "использование: $0 <docs/product-design/run-id>"
[ -d "$1" ] || fail "каталог прогона не найден: $1"

RUN_DIR=$(CDPATH= cd -- "$1" && pwd -P)
REPO_ROOT_RAW=$(git -C "$RUN_DIR" rev-parse --show-toplevel 2>/dev/null) || \
  fail "каталог прогона должен находиться в Git-репозитории"
REPO_ROOT=$(CDPATH= cd -- "$REPO_ROOT_RAW" && pwd -P)

case "$RUN_DIR" in
  "$REPO_ROOT"/*) RUN_REL=${RUN_DIR#"$REPO_ROOT"/} ;;
  *) fail "не удалось определить путь прогона внутри репозитория" ;;
esac

for file in MANIFEST.md PRODUCT-MAP.md SOURCE-REGISTER.md TRACEABILITY.md; do
  [ -f "$RUN_DIR/$file" ] || fail "нет обязательного файла $file"
done

unexpected_files=$(find "$RUN_DIR" -type f \
  ! -path "$RUN_DIR/MANIFEST.md" \
  ! -path "$RUN_DIR/PRODUCT-MAP.md" \
  ! -path "$RUN_DIR/SOURCE-REGISTER.md" \
  ! -path "$RUN_DIR/DECISIONS.md" \
  ! -path "$RUN_DIR/TRACEABILITY.md" \
  ! -path "$RUN_DIR/nodes/*.md" \
  ! -path "$RUN_DIR/reviews/*.md" -print)
[ -z "$unexpected_files" ] || \
  fail "в run-каталоге есть артефакты вне контура отдела: $unexpected_files"

[ -d "$RUN_DIR/nodes" ] || fail "нет каталога подробных узлов nodes/"
node_count=$(find "$RUN_DIR/nodes" -type f -name '*.md' | wc -l | tr -d ' ')
[ "$node_count" -gt 0 ] || fail "нет ни одного подробного проектировочного файла"

[ -d "$RUN_DIR/reviews" ] || fail "нет каталога независимых reviews/"

review_path=$(sed -n \
  's/^- \*\*Текущий reviewer-отчёт:\*\* `\([^`]*\)`$/\1/p' \
  "$RUN_DIR/MANIFEST.md" | tail -n 1)
case "$review_path" in
  reviews/*.md) ;;
  *) fail "MANIFEST.md не указывает актуальный reviewer-отчёт" ;;
esac
[ -f "$RUN_DIR/$review_path" ] || fail "актуальный reviewer-отчёт не найден: $review_path"

IFS= read -r verdict_line < "$RUN_DIR/$review_path" || true
verdict_line=${verdict_line%$'\r'}
[ "$verdict_line" = '# Вердикт: PASS' ] || \
  fail "актуальный reviewer-отчёт не содержит PASS в первой строке"

reviewed_commit=$(sed -n \
  's/^- \*\*Проверенный commit:\*\* `\([0-9a-fA-F][0-9a-fA-F]*\)`$/\1/p' \
  "$RUN_DIR/$review_path" | head -n 1)
case ${#reviewed_commit} in 40|64) ;; *) fail "reviewer-отчёт не содержит полный hash" ;; esac
printf '%s' "$reviewed_commit" | grep -Eq '^[0-9a-fA-F]+$' || \
  fail "некорректный hash в reviewer-отчёте"

extract_runtime_id() {
  awk -F'|' -v wanted="$1" '
    {
      role=$3; id=$5
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", role)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
      if (role == wanted) { print id; exit }
    }
  ' "$RUN_DIR/MANIFEST.md"
}

architect_id=$(extract_runtime_id product-architect)
reviewer_id=$(extract_runtime_id product-design-reviewer)
[ -n "$architect_id" ] && [ "$architect_id" != not_assigned ] || \
  fail "не записан runtime ID product-architect"
[ -n "$reviewer_id" ] && [ "$reviewer_id" != not_assigned ] || \
  fail "не записан runtime ID product-design-reviewer"
[ "$architect_id" != "$reviewer_id" ] || \
  fail "автор и reviewer должны иметь разные runtime ID"

grep -Fq '**Статус:** `ready_for_owner`' "$RUN_DIR/MANIFEST.md" || \
  fail "MANIFEST.md не переведён в статус ready_for_owner"

if [ ! -f "$RUN_DIR/DECISIONS.md" ]; then
  grep -Fq '**Существенные развилки:** не применимо: существенных развилок не обнаружено' \
    "$RUN_DIR/MANIFEST.md" || \
    fail "нет DECISIONS.md и явной отметки, что существенных развилок не обнаружено"
fi

if find "$RUN_DIR" -type f -name 'TASK.md' | grep -q .; then
  fail "отдел проектирования не должен создавать TASK.md"
fi
if grep -Eq 'product-owner|business-analyst' "$RUN_DIR/MANIFEST.md"; then
  fail "в манифесте отдела появились роли следующего процесса"
fi

visible_map=$(sed -E 's/\]\([^)]*\)/]/g' "$RUN_DIR/PRODUCT-MAP.md")
if printf '%s\n' "$visible_map" | grep -Eq '(SRC|NODE|DEC)-[0-9]'; then
  fail "Product Map показывает владельцу служебные ID"
fi
if grep -Eq '<[^>]+>' "$RUN_DIR/PRODUCT-MAP.md"; then
  fail "в Product Map остались плейсхолдеры"
fi

raw_links=$(grep -oE '\]\([^)]+\)' "$RUN_DIR/PRODUCT-MAP.md" | \
  sed -E 's/^\]\((.*)\)$/\1/' || true)
local_link_count=0
while IFS= read -r link; do
  [ -n "$link" ] || continue
  case "$link" in
    http://*|https://*|mailto:*|\#*) continue ;;
    /*|../*|*/../*) fail "непереносимая ссылка в Product Map: $link" ;;
  esac
  target=${link%%#*}
  [ -e "$RUN_DIR/$target" ] || fail "не открывается ссылка Product Map: $link"
  local_link_count=$((local_link_count + 1))
done <<EOF
$raw_links
EOF
[ "$local_link_count" -gt 0 ] || \
  fail "Product Map не содержит ни одной локальной ссылки на подробности"

if ! git -C "$REPO_ROOT" diff --quiet HEAD -- "$RUN_REL"; then
  fail "run-каталог отличается от HEAD; сначала зафиксируй показанный пакет"
fi
untracked=$(git -C "$REPO_ROOT" ls-files --others --exclude-standard -- "$RUN_REL")
[ -z "$untracked" ] || fail "в run-каталоге есть незафиксированные файлы: $untracked"

while IFS= read -r file; do
  file_rel=${file#"$REPO_ROOT"/}
  git -C "$REPO_ROOT" cat-file -e "HEAD:$file_rel" 2>/dev/null || \
    fail "$file_rel отсутствует в HEAD"
done < <(find "$RUN_DIR" -type f -print)

git -C "$REPO_ROOT" cat-file -e "$reviewed_commit^{commit}" 2>/dev/null || \
  fail "проверенный commit не существует"
git -C "$REPO_ROOT" merge-base --is-ancestor "$reviewed_commit" HEAD || \
  fail "проверенный commit не является предком текущего HEAD"

content_paths=(
  "$RUN_REL/PRODUCT-MAP.md"
  "$RUN_REL/SOURCE-REGISTER.md"
  "$RUN_REL/DECISIONS.md"
  "$RUN_REL/TRACEABILITY.md"
  "$RUN_REL/nodes"
)
git -C "$REPO_ROOT" diff --quiet "$reviewed_commit" HEAD -- "${content_paths[@]}" || \
  fail "карта или подробные файлы изменились после актуального ревью"

commit=$(git -C "$REPO_ROOT" rev-parse HEAD)
echo "PASS: пакет отдела проектирования совпадает с commit $commit"
