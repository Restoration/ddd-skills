#!/usr/bin/env bash
# README のスキル一覧表を各スキルの frontmatter から再生成する。
# 表は README.md の SKILLS-TABLE:BEGIN / END マーカーの間に書き込む。
# 説明文は description の先頭2文（3文目以降は通常「いつ使うか」の起動条件なので省く）。
# 起動列は disable-model-invocation の有無から生成する（true = スラッシュ専用）。
# 使い方:
#   ./scripts/update-readme.sh           # README.md を更新
#   ./scripts/update-readme.sh --check   # 最新かどうか検査のみ（CI 用）
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="${REPO_DIR}/README.md"
BEGIN_MARK='<!-- SKILLS-TABLE:BEGIN (scripts/update-readme.sh が生成。手で編集しない) -->'
END_MARK='<!-- SKILLS-TABLE:END -->'

fm_value() { # $1=SKILL.md path, $2=key
  awk -v key="$2" '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---"  { exit }
    NR > 1 && index($0, key ":") == 1 {
      sub(key ":", ""); sub(/^[ \t]+/, ""); print; exit
    }
  ' "$1"
}

# 先頭2文を取り出す（日本語は「。」、英語は ". " を文区切りとみなす）
# sed/awk の正規表現はマルチバイトを扱えないため、シェルのパラメータ展開で切る
first_two_sentences() {
  local text="$1" sep="。" glue="" s1 rest
  case "${text}" in
    *。*) ;;
    *'. '*) sep=". "; glue=" " ;;
    *) echo "${text}"; return ;;
  esac
  s1="${text%%"${sep}"*}${sep% }"
  rest="${text#*"${sep}"}"
  case "${rest}" in
    *"${sep}"*) echo "${s1}${glue}${rest%%"${sep}"*}${sep% }" ;;
    *)          echo "${text}" ;;
  esac
}

TABLE="| スキル | 起動 | 説明 |
|--------|------|------|"
for dir in "${REPO_DIR}"/*/; do
  name="$(basename "${dir}")"
  [ -f "${dir}SKILL.md" ] || continue
  desc="$(fm_value "${dir}SKILL.md" description)"
  summary="$(first_two_sentences "${desc}" | sed 's/|/\\|/g')"
  if [ "$(fm_value "${dir}SKILL.md" disable-model-invocation)" = "true" ]; then
    invoke="\`/\` 専用"
  else
    invoke="自動"
  fi
  TABLE="${TABLE}
| [${name}](${name}/SKILL.md) | ${invoke} | ${summary} |"
done

if ! grep -qF "${END_MARK}" "${README}"; then
  echo "error: README.md にマーカー ${END_MARK} がありません" >&2
  exit 1
fi

TABLE_FILE="$(mktemp)"
trap 'rm -f "${TABLE_FILE}"' EXIT
printf '%s\n' "${TABLE}" > "${TABLE_FILE}"

NEW_README="$(awk -v begin="${BEGIN_MARK}" -v end="${END_MARK}" -v tablefile="${TABLE_FILE}" '
  $0 == begin {
    print
    while ((getline line < tablefile) > 0) print line
    skipping = 1; next
  }
  $0 == end { skipping = 0 }
  !skipping { print }
' "${README}")"

if [ "${1:-}" = "--check" ]; then
  if [ "${NEW_README}" != "$(cat "${README}")" ]; then
    echo "NG: README.md のスキル表が古いです。scripts/update-readme.sh を実行してください" >&2
    diff <(cat "${README}") <(echo "${NEW_README}") >&2 || true
    exit 1
  fi
  echo "update-readme: OK（最新）"
else
  echo "${NEW_README}" > "${README}"
  echo "update-readme: README.md を更新しました"
fi
