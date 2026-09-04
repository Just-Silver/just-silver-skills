# 一键安装/更新本仓库 skills 到 OpenCode 技能目录（幂等：可重复运行）
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Destination = (Join-Path $HOME '.config/opencode/skills'),
    [switch]$Clean   # 删除目标目录下仓库已不存在的残留技能
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$skillsDir = Join-Path $root 'skills'
if (-not (Test-Path $skillsDir)) { throw "未找到 skills 目录: $skillsDir" }

# 枚举所有含 SKILL.md 的技能目录（.mirror 上游镜像照装；相对 skills/ 的路径保持不变）
$relDirs = Get-ChildItem $skillsDir -Recurse -Filter 'SKILL.md' -File |
    ForEach-Object { $_.Directory.FullName.Substring($skillsDir.Length).TrimStart('\', '/') } |
    Sort-Object -Unique

if (-not (Test-Path $Destination)) { New-Item -ItemType Directory -Path $Destination | Out-Null }
$count = 0
foreach ($rel in $relDirs) {
    $src = Join-Path $skillsDir $rel
    $dst = Join-Path $Destination $rel
    if ($PSCmdlet.ShouldProcess($rel, '安装/更新技能')) {
        if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }  # 全量覆盖：上游删了本地跟着删
        $parent = Split-Path $dst -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent | Out-Null }
        Copy-Item $src $dst -Recurse -Force
        $count++
    }
}

if ($Clean) {
    $wanted = [System.Collections.Generic.HashSet[string]]::new([string[]]$relDirs)
    Get-ChildItem $Destination -Recurse -Filter 'SKILL.md' -File |
        ForEach-Object { $_.Directory.FullName.Substring($Destination.Length).TrimStart('\', '/') } |
        Sort-Object -Unique |
        Where-Object { -not $wanted.Contains($_) } |
        ForEach-Object {
            if ($PSCmdlet.ShouldProcess($_, '删除残留技能')) {
                Remove-Item (Join-Path $Destination $_) -Recurse -Force
            }
        }
}

Write-Output "已安装/更新 $count 个技能到: $Destination"
