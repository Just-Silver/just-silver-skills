# 一键生成 README 技能清单表格（幂等：可重复运行）
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$skillsDir = Join-Path $root 'skills'
if (-not (Test-Path $skillsDir)) { throw "未找到 skills 目录: $skillsDir" }

$rows = @()
Get-ChildItem $skillsDir -Directory | Sort-Object Name | ForEach-Object {
    $dirName = $_.Name
    $skPath = Join-Path $_.FullName 'SKILL.md'
    if (-not (Test-Path $skPath)) { Write-Warning "跳过（无 SKILL.md）: $dirName"; return }
    $content = Get-Content $skPath -Raw
    $name = $dirName
    $desc = ''
    if ($content -match '(?ms)^---\r?\n(.*?)\r?\n---\r?\n') {
        $fm = $Matches[1]
        if ($fm -match '(?m)^name:\s*(.+?)\s*$') { $name = $Matches[1].Trim() }
        if ($fm -match '(?m)^description:\s*(.+?)\s*$') { $desc = $Matches[1].Trim() }
    }
    if ($desc.Length -gt 110) { $desc = $desc.Substring(0, 107) + '...' }
    $desc = $desc -replace '\|', '\|'
    $rows += "| $name | $desc | [skills/$dirName/](skills/$dirName/) |"
}

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