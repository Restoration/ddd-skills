#!/usr/bin/env bash
# スキルリポジトリの検証。CI と手元の両方で使う。
# 検査項目:
#   1. スキル以外の管理ディレクトリを除く直下ディレクトリに SKILL.md があるか
#   2. frontmatter が存在するか（--- で始まり --- で閉じる）
#   3. frontmatter の name: がディレクトリ名と一致するか
#   4. description: が存在し、空でなく、1行で書かれ、起動条件（〜使う/〜参照する）で終わるか
#   5. README の表に全スキルが載っているか / 存在しないスキルが残っていないか
#   6. SKILL.md 内の相対 markdown リンクが実在するファイルを指しているか
#   7. ディレクトリ名が kebab-case か
#   8. allowed-tools: がカンマ区切り1行か（YAML リスト形式でないか）
#   9. disable-model-invocation: の値が true か
#  10. README 内の相対 markdown リンクが実在するファイルを指しているか
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERRORS=0

fail() {
  echo "NG: $1" >&2
  ERRORS=$((ERRORS + 1))
}

# frontmatter からキーの値を取り出す（1行値のみ対応）
fm_value() { # $1=SKILL.md path, $2=key
  awk -v key="$2" '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---"  { exit }
    NR > 1 && index($0, key ":") == 1 {
      sub(key ":", ""); sub(/^[ \t]+/, ""); print; exit
    }
  ' "$1"
}

# frontmatter にキーが存在するか（値の有無は問わない）
fm_has_key() { # $1=SKILL.md path, $2=key
  awk -v key="$2" '
    NR == 1 && $0 != "---" { exit 1 }
    NR > 1 && $0 == "---"  { exit 1 }
    NR > 1 && index($0, key ":") == 1 { found = 1; exit }
    END { exit found ? 0 : 1 }
  ' "$1"
}

NON_SKILL_DIRS="scripts tests .github .claude"

for dir in "${REPO_DIR}"/*/; do
  name="$(basename "${dir}")"
  case " ${NON_SKILL_DIRS} " in *" ${name} "*) continue ;; esac

  skill_md="${dir}SKILL.md"

  # 7. ディレクトリ名の kebab-case（name: は 3. でこれと一致することを検査する）
  case "${name}" in
    *[!a-z0-9-]*|-*|*-) fail "${name}/: ディレクトリ名が kebab-case（小文字英数字とハイフン）ではありません" ;;
  esac

  # 1. SKILL.md の存在
  if [ ! -f "${skill_md}" ]; then
    fail "${name}/: SKILL.md がありません（スキルでないなら scripts/lint.sh の NON_SKILL_DIRS に追加）"
    continue
  fi

  # 2. frontmatter の存在
  if [ "$(head -1 "${skill_md}")" != "---" ] || ! sed -n '2,50p' "${skill_md}" | grep -qx -- '---'; then
    fail "${name}/SKILL.md: frontmatter（--- ... ---）がありません"
    continue
  fi

  # 3. name とディレクトリ名の一致
  fm_name="$(fm_value "${skill_md}" name)"
  if [ "${fm_name}" != "${name}" ]; then
    fail "${name}/SKILL.md: name: '${fm_name}' がディレクトリ名 '${name}' と一致しません"
  fi

  # 4. description の存在（1行値）と、起動条件で終わっているか
  fm_desc="$(fm_value "${skill_md}" description)"
  if [ -z "${fm_desc}" ]; then
    fail "${name}/SKILL.md: description: がないか、空か、複数行で書かれています（1行で書く）"
  else
    case "${fm_desc}" in
      *使う。|*参照する。) ;;
      *) fail "${name}/SKILL.md: description の最終文が起動条件（「〜使う。」「〜参照する。」）になっていません" ;;
    esac
  fi

  # 8. allowed-tools はカンマ区切り1行（キーがあるのに1行値が取れない = YAML リスト等）
  if fm_has_key "${skill_md}" allowed-tools && [ -z "$(fm_value "${skill_md}" allowed-tools)" ]; then
    fail "${name}/SKILL.md: allowed-tools: はカンマ区切り1行で書く（YAML リスト形式は使わない）"
  fi

  # 9. disable-model-invocation の値は true のみ（不要なら行ごと消す）
  if fm_has_key "${skill_md}" disable-model-invocation; then
    dmi="$(fm_value "${skill_md}" disable-model-invocation)"
    if [ "${dmi}" != "true" ]; then
      fail "${name}/SKILL.md: disable-model-invocation: の値は true のみ（自動起動を許すなら行ごと削除する）"
    fi
  fi

  # 5. README の表に載っているか
  if ! grep -q "(${name}/SKILL.md)" "${REPO_DIR}/README.md"; then
    fail "README.md: ${name} が表に載っていません（scripts/update-readme.sh を実行）"
  fi

  # 6. SKILL.md 内の相対リンク切れ
  while IFS= read -r link; do
    case "${link}" in
      http://*|https://*|/*|\#*) continue ;;
    esac
    target="${link%%#*}"
    [ -z "${target}" ] && continue
    if [ ! -e "${dir}${target}" ]; then
      fail "${name}/SKILL.md: リンク切れ: ${link}"
    fi
  done < <(grep -o '](\([^)]*\))' "${skill_md}" 2>/dev/null | sed 's/^](//; s/)$//' || true)
done

# 10. README 内の相対リンク切れ（表以外の prose 部分も含む）
while IFS= read -r link; do
  case "${link}" in
    http://*|https://*|/*|\#*) continue ;;
  esac
  target="${link%%#*}"
  [ -z "${target}" ] && continue
  if [ ! -e "${REPO_DIR}/${target}" ]; then
    fail "README.md: リンク切れ: ${link}"
  fi
done < <(grep -o '](\([^)]*\))' "${REPO_DIR}/README.md" 2>/dev/null | sed 's/^](//; s/)$//' || true)

# README の表に、存在しないスキルが残っていないか
while IFS= read -r listed; do
  if [ ! -f "${REPO_DIR}/${listed}/SKILL.md" ]; then
    fail "README.md: 存在しないスキル '${listed}' が表に残っています（scripts/update-readme.sh を実行）"
  fi
done < <(grep -o '([a-z0-9-]*/SKILL\.md)' "${REPO_DIR}/README.md" | sed 's|^(||; s|/SKILL\.md)$||' | sort -u)

if [ ${ERRORS} -gt 0 ]; then
  echo "lint: ${ERRORS} 件のエラー" >&2
  exit 1
fi
echo "lint: OK"
