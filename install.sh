#!/usr/bin/env bash
# claude-skills インストーラ
# リポジトリを単一の真実源として、スキルを symlink で配置する。
# 使い方:
#   ./install.sh <skill>... [--global | --project <path>] [--copy]
#   ./install.sh all        [--global | --project <path>] [--copy]
#   ./install.sh status     [--project <path>]
#   ./install.sh uninstall <skill>... [--global | --project <path>]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_SKILLS_DIR="${HOME}/.claude/skills"

usage() {
  sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

# リポジトリ内のスキル一覧（SKILL.md を持つ直下ディレクトリ）
list_skills() {
  local d
  for d in "${REPO_DIR}"/*/; do
    [ -f "${d}SKILL.md" ] && basename "${d}"
  done
}

skill_exists() {
  [ -f "${REPO_DIR}/$1/SKILL.md" ]
}

# ---- 引数解析 -------------------------------------------------------------
COMMAND=""
SKILLS=()
TARGET_DIR="${GLOBAL_SKILLS_DIR}"
TARGET_LABEL="global (~/.claude/skills)"
MODE="link"

args=("$@")
[ $# -eq 0 ] && usage 1

case "${args[0]}" in
  status|uninstall) COMMAND="${args[0]}"; args=("${args[@]:1}") ;;
  -h|--help)        usage 0 ;;
  *)                COMMAND="install" ;;
esac

i=0
while [ $i -lt ${#args[@]} ]; do
  case "${args[$i]}" in
    --global) ;;
    --project)
      i=$((i + 1))
      [ $i -lt ${#args[@]} ] || { echo "error: --project にはパスが必要です" >&2; exit 1; }
      proj="${args[$i]}"
      [ -d "${proj}" ] || { echo "error: プロジェクトが見つかりません: ${proj}" >&2; exit 1; }
      TARGET_DIR="$(cd "${proj}" && pwd)/.claude/skills"
      TARGET_LABEL="project (${proj%/}/.claude/skills)"
      ;;
    --copy)  MODE="copy" ;;
    -h|--help) usage 0 ;;
    -*)      echo "error: 不明なオプション: ${args[$i]}" >&2; usage 1 ;;
    all)     SKILLS=($(list_skills)) ;;
    *)
      skill_exists "${args[$i]}" || { echo "error: スキルが見つかりません: ${args[$i]}" >&2; exit 1; }
      SKILLS+=("${args[$i]}")
      ;;
  esac
  i=$((i + 1))
done

# ---- status ---------------------------------------------------------------
if [ "${COMMAND}" = "status" ]; then
  echo "配置先: ${TARGET_LABEL}"
  printf '%-24s %s\n' "スキル" "状態"
  printf '%-24s %s\n' "------" "----"
  for skill in $(list_skills); do
    dest="${TARGET_DIR}/${skill}"
    if [ -L "${dest}" ]; then
      link_target="$(readlink "${dest}")"
      if [ "${link_target}" = "${REPO_DIR}/${skill}" ]; then
        state="link（リポジトリと同期）"
      else
        state="link（別の場所を参照: ${link_target}）"
      fi
    elif [ -d "${dest}" ]; then
      if diff -rq "${REPO_DIR}/${skill}" "${dest}" >/dev/null 2>&1; then
        state="copy（最新）"
      else
        state="copy（リポジトリと差分あり）"
      fi
    else
      state="未配置"
    fi
    printf '%-24s %s\n' "${skill}" "${state}"
  done
  exit 0
fi

[ ${#SKILLS[@]} -gt 0 ] || { echo "error: スキル名を指定してください（all で全スキル）" >&2; usage 1; }

# ---- uninstall ------------------------------------------------------------
if [ "${COMMAND}" = "uninstall" ]; then
  for skill in "${SKILLS[@]}"; do
    dest="${TARGET_DIR}/${skill}"
    if [ -L "${dest}" ]; then
      rm "${dest}"
      echo "removed: ${dest} (link)"
    elif [ -d "${dest}" ]; then
      rm -rf "${dest}"
      echo "removed: ${dest} (copy)"
    else
      echo "skip: ${dest} は配置されていません"
    fi
  done
  exit 0
fi

# ---- install --------------------------------------------------------------
mkdir -p "${TARGET_DIR}"
for skill in "${SKILLS[@]}"; do
  dest="${TARGET_DIR}/${skill}"
  if [ -e "${dest}" ] || [ -L "${dest}" ]; then
    rm -rf "${dest}"
  fi
  if [ "${MODE}" = "link" ]; then
    ln -s "${REPO_DIR}/${skill}" "${dest}"
    echo "linked: ${dest} -> ${REPO_DIR}/${skill}"
  else
    cp -R "${REPO_DIR}/${skill}" "${dest}"
    echo "copied: ${dest}"
  fi
done
