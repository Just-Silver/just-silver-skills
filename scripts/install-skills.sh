#!/usr/bin/env bash
# 一键安装/更新本仓库 skills（远程拉取，幂等，原子替换，不动他人技能）
# 用法（任意带 bash 的命令窗粘贴一条即可，无需先克隆仓库；Windows 请在 Git Bash 中执行）：
#   curl -fsSL https://raw.githubusercontent.com/Just-Silver/just-silver-skills/main/scripts/install-skills.sh | bash
# 经管道执行时无法传参，可用环境变量覆盖（JSS_SKILLS_DEST / JSS_ARCHIVE_URL）
set -euo pipefail
DEST="${JSS_SKILLS_DEST:-$HOME/.config/opencode/skills/just-silver-skills}"
ARCHIVE_URL="${JSS_ARCHIVE_URL:-https://github.com/Just-Silver/just-silver-skills/archive/refs/heads/main.tar.gz}"

# 统一装到全局技能目录下的 just-silver-skills/ 子目录（OpenCode 支持 SKILL.md 任意深度发现，ID 取叶目录名，不变）
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
COUNT="$(find "$STAGING" -name 'SKILL.md' | wc -l | tr -d ' ')"
[ "$COUNT" -gt 0 ] || { echo '构建结果无 SKILL.md，终止安装（目标目录未动）' >&2; exit 1; }

if [ -e "$DEST" ]; then
  mv "$DEST" "$BACKUP"          # 旧版先让位
  if mv "$STAGING" "$DEST"; then  # 新版一次就位：外界永远只看到完整旧版或完整新版
    rm -rf "$BACKUP"
  else
    [ -e "$DEST" ] || mv "$BACKUP" "$DEST"  # 回滚：恢复旧版
    exit 1
  fi
else
  mv "$STAGING" "$DEST"
fi
trap - EXIT
rm -rf "$TMP"
echo "已安装/更新 $COUNT 个技能到: $DEST"
