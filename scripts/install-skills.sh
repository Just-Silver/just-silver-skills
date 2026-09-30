#!/usr/bin/env bash
# 一键安装/更新本仓库 skills 到通用 agent 技能目录（默认 ~/.agents/skills/），平铺安装：
# 每个技能一个一级子目录（~/.agents/skills/<技能名>/SKILL.md），技能名取 SKILL.md frontmatter 的 name，
# 这样只扫描一级子目录的客户端（Codex / Copilot CLI / Gemini CLI / DeepSeek Harness 等）也能发现。
# 归属跟踪：清单 .just-silver-skills.manifest + 每个已装目录里的标记 .jss-skill，
# 安装只覆盖自己的目录、卸载只删自己的目录，同级的他人技能（find-skills、gh-skill 等）不受影响。
# 用法（任意带 bash 的命令窗粘贴一条即可，无需先克隆仓库；Windows 请在 Git Bash 中执行）：
#   curl -fsSL https://raw.githubusercontent.com/Just-Silver/just-silver-skills/main/scripts/install-skills.sh | bash
# 经管道执行时无法传参，可用环境变量覆盖（JSS_SKILLS_DEST 技能根目录 / JSS_ARCHIVE_URL 压缩包地址）
set -euo pipefail
# 关键路径修正：PowerShell 里直接 curl | bash 时 bash 继承的是 Windows PATH（非登录 shell 不加载
# /etc/profile），C:\Windows\system32 排在 Git Bash 的 /usr/bin 之前，find 会解析到 Windows 的
# find.exe 而报 "FIND: Parameter format not correct"（tar 同理会解析到 bsdtar）。MSYS/Git Bash 下把
# Unix 工具目录前置即可（判据 uname -s，MSYSTEM 在管道调用的 bash 里为空不可靠）；纯 Linux/macOS 跳过。
case "$(uname -s)" in
  MSYS_NT*|MINGW*|CYGWIN*)
    for d in /usr/bin /bin; do
      case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH" ;; esac
    done
    export PATH
    ;;
esac

DEST="${JSS_SKILLS_DEST:-$HOME/.agents/skills}"   # 技能根目录：每个技能装成它的一个直接子目录
MANIFEST_NAME=".just-silver-skills.manifest"       # 清单：一行一个本仓库技能目录名
MARKER_NAME=".jss-skill"                           # 每个已装技能目录内的归属标记（卸载/接管的判据）
# 旧布局：整包放在 just-silver-skills/ 子目录里（本仓库历史版本）与更早的 OpenCode 全局位置，迁移时清理
LEGACY_NESTED_RAW="$DEST/just-silver-skills"
LEGACY_OPENCODE_RAW="${JSS_LEGACY_SKILLS_DEST:-$HOME/.config/opencode/skills/just-silver-skills}"
ARCHIVE_URL="${JSS_ARCHIVE_URL:-https://github.com/Just-Silver/just-silver-skills/archive/refs/heads/main.tar.gz}"

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
mkdir -p "$DEST"

# 上次异常中断（kill -9/断电）可能留下的暂存/备份目录：先清掉
rm -rf "$DEST"/.jss-stage-* "$DEST"/.jss-old-*
STAGE="$DEST/.jss-stage-$$"
OLD="$DEST/.jss-old-$$"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" "$STAGE" "$OLD"' EXIT

# 拉取并解压：archive 顶层为 just-silver-skills-main/，取其下 skills/
curl -fsSL "$ARCHIVE_URL" | tar -xz -C "$TMP" --strip-components=1
SKILLS_SRC="$TMP/skills"
[ -d "$SKILLS_SRC" ] || { echo "压缩包缺少 skills 目录 ($ARCHIVE_URL)" >&2; exit 1; }

# 收集技能目录 + 安装名（frontmatter name 优先，缺省用目录名），并做合法性与重名校验
shopt -s globstar nullglob
SKILL_MDS=("$SKILLS_SRC"/**/SKILL.md)
shopt -u globstar nullglob
[ "${#SKILL_MDS[@]}" -gt 0 ] || { echo '压缩包内没有 SKILL.md，终止安装（目标目录未动）' >&2; exit 1; }

NAMES=()
SRC_DIRS=()
declare -A SEEN=()
for md in "${SKILL_MDS[@]}"; do
  dir="${md%/SKILL.md}"
  rel="${md#"$SKILLS_SRC"/}"
  name="$(head -n 20 "$md" | sed -n 's/^name:[[:space:]]*//p' | head -n 1 | tr -d '\r' | sed -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")"
  [ -n "$name" ] || name="${dir##*/}"
  case "$name" in
    ""|.*|*[!A-Za-z0-9._-]*) echo "非法技能名 '$name'（来自 $rel），终止安装" >&2; exit 1 ;;
  esac
  if [ -n "${SEEN[$name]:-}" ]; then
    echo "技能名重复：'$name'（$rel 与 ${SEEN[$name]}），终止安装（避免相互覆盖）" >&2; exit 1
  fi
  SEEN[$name]="$rel"
  NAMES+=("$name")
  SRC_DIRS+=("$dir")
done

# 本机上一轮安装的清单（识别自己的目录、清理仓库里已删除的技能）
PREV_NAMES=""
# 读清单时统一去掉 CR（Windows 编辑器另存可能写成 CRLF，带了 CR 的名字会被当成非法条目）
if [ -f "$MANIFEST" ]; then PREV_NAMES="$(tr -d '\r' < "$MANIFEST" || true)"; fi

# 目标目录已被占用的检查：同名目录若既不在清单里、也没有本仓库标记，就是别人的技能，拒绝覆盖
CONFLICTS=()
for name in "${NAMES[@]}"; do
  target="$DEST/$name"
  if [ -e "$target" ] && [ ! -f "$target/$MARKER_NAME" ]; then
    if ! printf '%s\n' "$PREV_NAMES" | grep -qxF -- "$name"; then
      CONFLICTS+=("$name")
    fi
  fi
done
if [ "${#CONFLICTS[@]}" -gt 0 ]; then
  echo "以下目录已存在于 $DEST 且不属于本仓库（无标记、不在清单），拒绝覆盖：" >&2
  printf '  - %s\n' "${CONFLICTS[@]}" >&2
  echo "请改名或删除后重试；本仓库装出来的目录带标记 $MARKER_NAME，可安全删除。" >&2
  exit 1
fi

# 先在暂存区组装好全部技能，再逐个同卷重命名就位（每个技能目录一次原子替换）
mkdir -p "$STAGE" "$OLD"
for i in "${!NAMES[@]}"; do
  cp -rf "${SRC_DIRS[$i]}" "$STAGE/${NAMES[$i]}"
  printf '%s\n' "just-silver-skills" > "$STAGE/${NAMES[$i]}/$MARKER_NAME"
done
PLACED=()
MOVED_OUT=()
FAILED=0
for name in "${NAMES[@]}"; do
  target="$DEST/$name"
  if [ -e "$target" ]; then
    mv "$target" "$OLD/$name" || { FAILED=1; break; }
    MOVED_OUT+=("$name")
  fi
  mv "$STAGE/$name" "$target" || { FAILED=1; break; }
  PLACED+=("$name")
done
if [ "$FAILED" -ne 0 ]; then
  for name in "${PLACED[@]}"; do rm -rf "$DEST/$name"; done
  for name in "${MOVED_OUT[@]}"; do [ -e "$DEST/$name" ] || mv "$OLD/$name" "$DEST/$name"; done
  echo '安装中途失败，已回滚到安装前状态' >&2
  exit 1
fi

# 清理仓库里已删除/改名的旧技能（只在带本仓库标记时删；清单项被别的工具接管则跳过并提示）
REMOVED=0
if [ -n "$PREV_NAMES" ]; then
  while IFS= read -r old; do
    [ -n "$old" ] || continue
    case "$old" in ""|.*|*[!A-Za-z0-9._-]*) continue ;; esac
    current=0
    for name in "${NAMES[@]}"; do [ "$name" = "$old" ] && { current=1; break; }; done
    [ "$current" -eq 1 ] && continue
    target="$DEST/$old"
    if [ -f "$target/$MARKER_NAME" ]; then
      rm -rf "$target"; REMOVED=$((REMOVED + 1))
    elif [ -d "$target" ]; then
      echo "! 清单中的 '$old' 已无本仓库标记（可能被其他工具接管），未删除：$target" >&2
    fi
  done <<< "$PREV_NAMES"
  if [ "$REMOVED" -gt 0 ]; then echo "已清理 $REMOVED 个仓库中已删除的旧技能"; fi
fi

# 清单原子写入
printf '%s\n' "${NAMES[@]}" > "$MANIFEST.tmp-$$"
mv "$MANIFEST.tmp-$$" "$MANIFEST"

# 迁移：清理旧布局目录（整包 just-silver-skills/ 与更早的 ~/.config/opencode 位置）及其残留
clean_legacy() {
  local dir="$1"
  local stale=()
  [ "$dir" = "$DEST" ] && return 0
  shopt -s nullglob
  stale=("$dir".new-* "$dir".old-*)
  shopt -u nullglob
  if [ -e "$dir" ] || [ "${#stale[@]}" -gt 0 ]; then
    rm -rf "$dir" "${stale[@]}"
    echo "已清理旧布局目录: $dir"
  fi
}
clean_legacy "$LEGACY_NESTED"
clean_legacy "$LEGACY_OPENCODE"

trap - EXIT
rm -rf "$TMP" "$STAGE" "$OLD"
echo "已安装/更新 ${#NAMES[@]} 个技能到: $DEST（清单: $MANIFEST）"
