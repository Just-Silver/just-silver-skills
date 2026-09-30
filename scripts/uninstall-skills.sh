#!/usr/bin/env bash
# 一键卸载本仓库 skills（删除全局 just-silver-skills/ 目录，含异常中断残留的 .new-*/.old-* 临时目录）
# 用法（任意带 bash 的命令窗粘贴一条即可，无需先克隆仓库；Windows 请在 Git Bash 中执行）：
#   curl -fsSL https://raw.githubusercontent.com/Just-Silver/just-silver-skills/main/scripts/uninstall-skills.sh | bash
# 经管道执行时无法传参，可用环境变量覆盖（JSS_SKILLS_DEST，与安装脚本保持一致）
set -euo pipefail
# 与 install-skills.sh 相同的路径修正：PowerShell 里 `curl | bash` 时 C:\Windows\system32 排在
# /usr/bin 之前，rm 等会解析到 Windows 版工具。MSYS/Git Bash 下把 Unix 工具目录前置（纯 Linux/macOS 跳过）。
case "$(uname -s)" in
  MSYS_NT*|MINGW*|CYGWIN*)
    for d in /usr/bin /bin; do
      case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH" ;; esac
    done
    export PATH
    ;;
esac
DEST="${JSS_SKILLS_DEST:-$HOME/.config/opencode/skills/just-silver-skills}"
# MSYS/Git Bash 下把 $DEST 规范为 Unix 路径（/c/...）：rm/cp/mv 能自动翻译盘符路径，但 glob 拼接（残留
# 清理的 .new-*/.old-*）不能，统一转换最稳；非 MSYS 环境 cygpath 不存在则跳过（Linux/macOS 本就是 /）。
if command -v cygpath >/dev/null 2>&1; then
  DEST="$(cygpath -u "$DEST")"
fi

if [ -e "$DEST" ]; then
  rm -rf "$DEST"
  echo "✓ 已卸载 $DEST"
else
  echo "- 未找到 $DEST，无需卸载"
fi
# 清理安装/更新异常中断（kill -9/断电）可能残留的临时目录（正常结束不留，此处兜底）
shopt -s nullglob
STALE=("$DEST".new-* "$DEST".old-*)
if [ "${#STALE[@]}" -gt 0 ]; then
  rm -rf "${STALE[@]}"
  echo "✓ 已清理 ${#STALE[@]} 个残留临时目录"
fi
shopt -u nullglob
