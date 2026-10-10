#!/usr/bin/env bash
# 一键安装/更新本仓库 skills（远程拉取，幂等，原子替换，不动他人技能）
# 输出每个技能的真实状态：新增 / 更新 / 移除 / 未变；完全无变化时不做替换，直接报告"已是最新"
# 用法（任意带 bash 的命令窗粘贴一条即可，无需先克隆仓库；Windows 请在 Git Bash 中执行）：
#   curl -fsSL https://raw.githubusercontent.com/Just-Silver/just-silver-skills/main/scripts/install-skills.sh | bash
# 经管道执行时无法传参，可用环境变量覆盖（JSS_SKILLS_DEST / JSS_ARCHIVE_URL）
set -euo pipefail
# 关键路径修正：PowerShell 里直接 `curl | bash` 时 bash 继承的是 Windows PATH（非登录 shell 不加载
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
DEST="${JSS_SKILLS_DEST:-$HOME/.config/opencode/skills/just-silver-skills}"
ARCHIVE_URL="${JSS_ARCHIVE_URL:-https://github.com/Just-Silver/just-silver-skills/archive/refs/heads/main.tar.gz}"

# 统一装到全局技能目录下的 just-silver-skills/ 子目录（OpenCode 支持 SKILL.md 任意深度发现，ID 取叶目录名，不变）
# MSYS/Git Bash 下把 $DEST 规范为 Unix 路径（/c/...）：rm/cp/mv 能自动翻译盘符路径，但 glob 拼接（残留
# 清理的 .new-*/.old-*）不能，统一转换最稳；非 MSYS 环境 cygpath 不存在则跳过（Linux/macOS 本就是 /）。
if command -v cygpath >/dev/null 2>&1; then
  DEST="$(cygpath -u "$DEST")"
fi
mkdir -p "$(dirname "$DEST")"
# 预备目录与备份目录必须与目标同级（同一文件系统），保证最后的 mv 只是同卷重命名（原子），且构建期间目标目录无中间态
STAGING="$DEST.new-$$"
BACKUP="$DEST.old-$$"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" "$STAGING"' EXIT

# 拉取并解压：archive 顶层为 just-silver-skills-main/，取其下 skills/
curl -fsSL "$ARCHIVE_URL" | tar -xz -C "$TMP" --strip-components=1
SKILLS_SRC="$TMP/skills"
[ -d "$SKILLS_SRC" ] || { echo "压缩包缺少 skills 目录 ($ARCHIVE_URL)" >&2; exit 1; }
mkdir -p "$STAGING"
cp -rf "$SKILLS_SRC/." "$STAGING/"
# 校验 staging 里有 SKILL.md；纯 bash 递归计数（shopt -s globstar），不依赖 find
shopt -s globstar nullglob
SKILL_FILES=("$STAGING"/**/SKILL.md)
COUNT="${#SKILL_FILES[@]}"
shopt -u globstar nullglob
[ "$COUNT" -gt 0 ] || { echo '构建结果无 SKILL.md，终止安装（目标目录未动）' >&2; exit 1; }

# ---- 对比新旧，逐技能得出真实状态（新增 / 更新 / 移除 / 未变），不再一律显示"已安装" ----
# 技能键 = SKILL.md 相对技能根的目录路径（如 github-actions、obra-superpowers/writing-skills）
skill_key() { local p="${2#"$1"/}"; printf '%s' "${p%/SKILL.md}"; }
dirs_differ() { ! diff -rq "$1" "$2" >/dev/null 2>&1; }

shopt -s globstar nullglob
NEW_SKILL_MD=("$STAGING"/**/SKILL.md)
OLD_SKILL_MD=()
if [ -e "$DEST" ]; then
  OLD_SKILL_MD=("$DEST"/**/SKILL.md)
fi
shopt -u globstar nullglob

ADDED=(); UPDATED=(); UNCHANGED=(); REMOVED=()
declare -A NEW_SET=()
for f in "${NEW_SKILL_MD[@]}"; do
  k="$(skill_key "$STAGING" "$f")"
  NEW_SET["$k"]=1
  if [ ! -e "$DEST/$k" ]; then
    ADDED+=("$k")
  elif dirs_differ "$DEST/$k" "$STAGING/$k"; then
    UPDATED+=("$k")
  else
    UNCHANGED+=("$k")
  fi
done
if [ "${#OLD_SKILL_MD[@]}" -gt 0 ]; then
  for f in "${OLD_SKILL_MD[@]}"; do
    k="$(skill_key "$DEST" "$f")"
    if [ -z "${NEW_SET[$k]:-}" ]; then
      REMOVED+=("$k")
    fi
  done
fi

echo "== 技能状态（目标：$DEST）=="
if [ "${#ADDED[@]}" -gt 0 ]; then printf '  + 新增  %s\n' "${ADDED[@]}"; fi
if [ "${#UPDATED[@]}" -gt 0 ]; then printf '  ↑ 更新  %s\n' "${UPDATED[@]}"; fi
if [ "${#REMOVED[@]}" -gt 0 ]; then printf '  - 移除  %s\n' "${REMOVED[@]}"; fi
printf '  = 未变  %s 个\n' "${#UNCHANGED[@]}"
printf '共 %s 个技能：新增 %s / 更新 %s / 移除 %s / 未变 %s\n' \
  "$COUNT" "${#ADDED[@]}" "${#UPDATED[@]}" "${#REMOVED[@]}" "${#UNCHANGED[@]}"

# 完全无变化：不做原子替换（不动时间戳），如实报告
if [ "${#ADDED[@]}" -eq 0 ] && [ "${#UPDATED[@]}" -eq 0 ] && [ "${#REMOVED[@]}" -eq 0 ]; then
  echo "✓ 已是最新，无变化（共 $COUNT 个技能）"
  exit 0   # trap 负责清理 $TMP 与 $STAGING
fi

FRESH=0
if [ -e "$DEST" ]; then
  mv "$DEST" "$BACKUP"          # 旧版先让位
  if mv "$STAGING" "$DEST"; then  # 新版一次就位：外界永远只看到完整旧版或完整新版
    rm -rf "$BACKUP"
  else
    [ -e "$DEST" ] || mv "$BACKUP" "$DEST"  # 回滚：恢复旧版
    exit 1
  fi
else
  FRESH=1
  mv "$STAGING" "$DEST"
fi
trap - EXIT
rm -rf "$TMP"
if [ "$FRESH" -eq 1 ]; then
  echo "✓ 安装完成：共 $COUNT 个技能（全部新增）→ $DEST"
else
  echo "✓ 更新完成：新增 ${#ADDED[@]} / 更新 ${#UPDATED[@]} / 移除 ${#REMOVED[@]}（共 $COUNT 个技能）→ $DEST"
fi
