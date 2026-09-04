# 一键生成 README 技能清单表格（幂等：可重复运行）
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$skillsDir = Join-Path $root 'skills'
if (-not (Test-Path $skillsDir)) { throw "未找到 skills 目录: $skillsDir" }

function Add-SkillRow([string]$skPath, [string]$relDir) {
    $content = Get-Content $skPath -Raw
    $name = Split-Path $relDir -Leaf
    $desc = ''
    if ($content -match '(?ms)^---\r?\n(.*?)\r?\n---\r?\n') {
        $fm = $Matches[1]
        if ($fm -match '(?m)^name:\s*(.+?)\s*$') { $name = $Matches[1].Trim() }
        if ($fm -match '(?m)^description:\s*(.+?)\s*$') { $desc = $Matches[1].Trim() }
    }
    if ($desc.Length -gt 110) { $desc = $desc.Substring(0, 107) + '...' }
    $desc = $desc -replace '\|', '\|'
    $relDir = $relDir -replace '\\', '/'
    $script:rows += "| $name | $desc | [skills/$relDir/](skills/$relDir/) |"
}
$rows = @()
$exclude = @('obra-superpowers')  # 上游镜像目录（sync-obra-superpowers.yml 维护），不计入自建技能表
Get-ChildItem $skillsDir -Directory | Where-Object { $exclude -notcontains $_.Name } | Sort-Object Name | ForEach-Object {
    $skPath = Join-Path $_.FullName 'SKILL.md'
    if (Test-Path $skPath) {
        # 顶层技能：skills/<name>/SKILL.md
        Add-SkillRow $skPath $_.Name
    } else {
        # 分组技能：skills/<group>/<name>/SKILL.md（如 skills/sdlc/）
        $group = $_
        $found = $false
        Get-ChildItem $group.FullName -Directory | Sort-Object Name | ForEach-Object {
            $subSk = Join-Path $_.FullName 'SKILL.md'
            if (Test-Path $subSk) { Add-SkillRow $subSk ($group.Name + '/' + $_.Name); $found = $true }
        }
        if (-not $found) { Write-Warning "跳过（无 SKILL.md）: $($group.Name)" }
    }
}
$rows = @($rows | Sort-Object)

$table = $rows -join "`n"
$readmePath = Join-Path $root 'README.md'
if (-not (Test-Path $readmePath)) { throw "未找到 README.md" }
$readme = Get-Content $readmePath -Raw
$block = "<!-- AUTO-GENERATED: 技能表格由 scripts\update-readme.ps1 生成，请勿手改 -->`n`n| 技能 | 介绍 | 跳转位置 |`n|------|------|----------|`n$table`n`n<!-- /AUTO-GENERATED -->"
$pattern = '(?ms)<!-- AUTO-GENERATED:.*?-->\r?\n(?:.*?\r?\n)*?<!-- /AUTO-GENERATED -->'
if ($readme -match $pattern) {
    $readme = $readme -replace $pattern, $block
} else {
    throw 'README.md 缺少 AUTO-GENERATED 标记块，请先按新结构初始化'
}
# 无 BOM UTF-8 写出（保持 GitHub 渲染一致）
[IO.File]::WriteAllText($readmePath, $readme, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "已生成技能清单：$($rows.Count) 个技能"