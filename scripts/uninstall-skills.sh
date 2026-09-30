#!/usr/bin/env bash
# 一键卸载本仓库 skills：技能根目录默认 ~/.agents/skills/，按清单（.just-silver-skills.manifest）
# 加每个目录里的归属标记（.jss-skill）定位本仓库平铺安装的技能，只删这些目录，
# 同级的他人技能（find-skills、gh-skill 等）不受影响；并顺带清理旧布局目录与异常中断残留。
# 用法（任意带 bash 的命令窗粘贴一条即可，无需先克隆仓库；Windows 请在 Git Bash 中执行）：
#   curl -fsSL https://raw.githubusercontent.com/Just-Silver/just-silver-skills/main/scripts/uninstall-skills.sh | bash
# 经管道执行时无法传参，可用环境变量覆盖（JSS_SKILLS_DEST 技能根目录，与安装脚本保持一致）
set -euo pipefail
# 与 install-skills.sh 相同的路径修正：PowerShell 里 curl | bash 时 C:\Windows\system32 排在
# /usr/bin 之前，rm 等会解析到 Windows 版工具。MSYS/Git Bash 下把 Unix 工具目录前置（纯 Linux/macOS 跳过）。
case "$(uname -s)" in
  MSYS_NT*|MINGW*|CYGWIN*)
    for d in /usr/bin /bin; do
      case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH" ;; esac
    done
    export PATH
    ;;
esac

DEST="${JSS_SKILLS_DEST:-$HOME/.agents/skills}"   # 技能根目录（与安装脚本一致）
MANIFEST_NAME=".just-silver-skills.manifest"
MARKER_NAME=".jss-skill"
# 旧布局：整包放在 just-silver-skills/ 子目录里（本仓库历史版本）与更早的 OpenCode 全局位置
LEGACY_NESTED_RAW="$DEST/just-silver-skills"
LEGACY_OPENCODE_RAW="${JSS_LEGACY_SKILLS_DEST:-$HOME/.config/opencode/skills/just-silver-skills}"
# MSYS/Git Bash 下把路径规范为 Unix 路径（/c/...）：rm/cp/mv 能自动翻译盘符路径，但 glob 拼接
# （残留清理的 .new-*/.old-*）不能，统一转换最稳；非 MSYS 环境 cygpath 不存在则跳过（Linux/macOS 本就是 /）。
if command -v cygpath >/dev/null 2>&1; then
  DEST="$(cygpath -u "$DEST")"
  LEGACY_NESTED_RAW="$(cygpath -u "$LEGACY_NESTED_RAW")"
  LEGACY_OPENCODE_RAW="$(cygpath -u "$LEGACY_OPENCODE_RAW")"
fi
LEGACY_NESTED="$LEGACY_NESTED_RAW"
LEGACY_OPENCODE="$LEGACY_OPENCODE_RAW"
MANIFEST="$DEST/$MANIFEST_NAME"

# 候选集合 = 清单项 ∪ 带本仓库标记的一级子目录（清单丢了也能兜底扫出来）；
# 但真正删除前一律要求目录里有标记，避免误删同名接管目录。
declare -A CAND=()
if [ -f "$MANIFEST" ]; then
  while IFS= read -r line; do
    line="${line%$'\r'}"   # 兼容 CRLF 清单（Windows 编辑器另存）
    [ -n "$line" ] || continue
    CAND["$line"]=1
  done < "$MANIFEST"
fi
shopt -s nullglob
for d in "$DEST"/*/; do
  [ -f "$d$MARKER_NAME" ] || continue
  n="${d%/}"
  CAND["${n##*/}"]=1
done
shopt -u nullglob

REMOVED=0
SKIPPED=0
for name in "${!CAND[@]}"; do
  case "$name" in ""|.*|*[!A-Za-z0-9._-]*) echo "! 跳过可疑条目：'$name'（清单被改坏？）" >&2; SKIPPED=$((SKIPPED + 1)); continue ;; esac
  target="$DEST/$name"
  [ -e "$target" ] || continue
  if [ -f "$target/$MARKER_NAME" ]; then
    rm -rf "$target"; REMOVED=$((REMOVED + 1))
  elif [ -d "$target" ]; then
    echo "! 跳过 $target：清单里有但它没有本仓库标记（可能已被其他工具接管），未删除" >&2
    SKIPPED=$((SKIPPED + 1))
  fi
done

if [ -f "$MANIFEST" ]; then rm -f "$MANIFEST"; fi
# 清理安装/更新异常中断（kill -9/断电）可能残留的暂存/备份目录
shopt -s nullglob
EXTRA=("$DEST"/.jss-stage-* "$DEST"/.jss-old-*)
shopt -u nullglob
if [ "${#EXTRA[@]}" -gt 0 ]; then
  rm -rf "${EXTRA[@]}"
  echo "✓ 已清理 ${#EXTRA[@]} 个残留暂存目录"
fi

# 旧布局目录（整包 just-silver-skills/ 与更早的 ~/.config/opencode 位置）及其 .new-*/.old-* 残留
rm_legacy() {
  local dir="$1"
  local stale=()
  [ "$dir" = "$DEST" ] && return 0
  shopt -s nullglob
  stale=("$dir".new-* "$dir".old-*)
  shopt -u nullglob
  if [ -e "$dir" ] || [ "${#stale[@]}" -gt 0 ]; then
    rm -rf "$dir" "${stale[@]}"
    echo "✓ 已清理旧布局目录 $dir"
  fi
}
rm_legacy "$LEGACY_NESTED"
rm_legacy "$LEGACY_OPENCODE"

if [ "$REMOVED" -eq 0 ]; then
  echo "- 未发现本仓库安装的技能（清单不存在或无匹配目录），无需卸载"
else
  echo "✓ 已卸载 $REMOVED 个本仓库技能（根目录: $DEST）"
fi
if [ "$SKIPPED" -gt 0 ]; then echo "（$SKIPPED 项被跳过，见上面的提示）"; fi
