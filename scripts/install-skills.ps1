# 一键安装/更新本仓库 skills（远程拉取，幂等，原子替换，不动他人技能）
# 用法（命令窗粘贴一条即可，无需先克隆仓库）：
#   irm https://raw.githubusercontent.com/Just-Silver/just-silver-skills/main/scripts/install-skills.ps1 | iex
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    # 统一装到全局技能目录下的 just-silver-skills/ 子目录（OpenCode 支持 SKILL.md 任意深度发现，ID 取叶目录名，不变）
    [string]$Destination = (Join-Path $HOME '.config/opencode/skills/just-silver-skills'),
    [string]$ZipUrl = 'https://github.com/Just-Silver/just-silver-skills/archive/refs/heads/main.zip'
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$parent = Split-Path $Destination -Parent
if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent | Out-Null }
# 预备目录与备份目录必须与目标同级（同一卷），保证最后的 Move-Item 只是同卷重命名（原子），且构建期间目标目录无中间态
$staging = "$Destination.new-$([guid]::NewGuid().ToString('N'))"
$backup = "$Destination.old-$([guid]::NewGuid().ToString('N'))"
$zip = Join-Path ([System.IO.Path]::GetTempPath()) ("jss-skills-$([guid]::NewGuid().ToString('N')).zip")
$extract = Join-Path ([System.IO.Path]::GetTempPath()) ("jss-skills-$([guid]::NewGuid().ToString('N'))")
$swapped = $false
try {
    Invoke-WebRequest -Uri $ZipUrl -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    $top = Get-ChildItem $extract -Directory | Select-Object -First 1
    if (-not $top) { throw "压缩包结构异常：顶层目录缺失 ($ZipUrl)" }
    $skillsSrc = Join-Path $top.FullName 'skills'
    if (-not (Test-Path $skillsSrc)) { throw "压缩包缺少 skills 目录 ($ZipUrl)" }
    New-Item -ItemType Directory -Path $staging | Out-Null
    Copy-Item (Join-Path $skillsSrc '*') $staging -Recurse -Force
    # WhatIf 下 Copy-Item 不实际执行：staging 为空属预期，直接跳过计数校验与替换（ShouldProcess 块也不会执行）
    $count = 0
    if (-not $WhatIfPreference) {
        $count = (Get-ChildItem $staging -Recurse -Filter 'SKILL.md' -File | Measure-Object).Count
        if ($count -eq 0) { throw '构建结果无 SKILL.md，终止安装（目标目录未动）' }
    }

    if ($PSCmdlet.ShouldProcess($Destination, '原子替换为上游最新')) {
        if (Test-Path $Destination) {
            Move-Item $Destination $backup          # 旧版先让位
            try {
                Move-Item $staging $Destination    # 新版一次就位：外界永远只看到完整旧版或完整新版
                $swapped = $true
            } catch {
                if (-not (Test-Path $Destination) -and (Test-Path $backup)) {
                    Move-Item $backup $Destination  # 回滚：恢复旧版
                }
                throw
            }
            if (Test-Path $backup) { Remove-Item $backup -Recurse -Force }
        } else {
            Move-Item $staging $Destination
            $swapped = $true
        }
    }
    Write-Output "已安装/更新 $count 个技能到: $Destination"
} finally {
    if (Test-Path $zip) { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
    if (Test-Path $extract) { Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue }
    if (-not $swapped -and (Test-Path $staging)) { Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue }
}
