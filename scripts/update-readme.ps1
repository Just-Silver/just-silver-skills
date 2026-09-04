# 一键生成 README 技能清单表格（幂等：可重复运行）
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$skillsDir = Join-Path $root 'skills'
if (-not (Test-Path $skillsDir)) { throw "未找到 skills 目录: $skillsDir" }

function Add-SkillRow([string]$skPath, [string]$relDir) {
    $content = Get-Content $skPath -Raw
    $leaf = Split-Path $relDir -Leaf
    $name = $leaf
    $desc = ''
    if ($content -match '(?ms)^---\r?\n(.*?)\r?\n---\r?\n') {
        $fm = $Matches[1]
        if ($fm -match '(?m)^name:\s*(.+?)\s*$') { $name = $Matches[1].Trim() }
        if ($fm -match '(?m)^description:\s*(.+?)\s*$') { $desc = $Matches[1].Trim() }
    }
    if ($desc.Length -gt 110) { $desc = $desc.Substring(0, 107) + '...' }
    $desc = $desc -replace '\|', '\|'
    $relDir = $relDir -replace '\\', '/'
    $parent = Split-Path $relDir -Parent
    if ($parent) {
        $display = ($parent -replace '/', ' / ') + ' / ' + $name
    } else {
        $display = $name
    }
    $script:rows += [pscustomobject]@{ SortKey = $relDir; Row = "| $display | $desc | [skills/$relDir/](skills/$relDir/) |" }
}

function Add-SkillsInDir([string]$dirFull, [string]$relDir) {
    # 含 .mirror 标记的子树整体跳过（各 sync-* 上游同步工作流维护的镜像目录）
    if (Test-Path (Join-Path $dirFull '.mirror')) { return }
    $skPath = Join-Path $dirFull 'SKILL.md'
    if (Test-Path $skPath) { Add-SkillRow $skPath $relDir }
    Get-ChildItem $dirFull -Directory | Sort-Object Name | ForEach-Object {
        Add-SkillsInDir $_.FullName ($relDir + '/' + $_.Name)
    }
}
$rows = @()
# 镜像目录（含 .mirror 标记，由各 sync-* 上游同步工作流维护）不计入自建技能表；支持任意深度嵌套，按路径排序保持同组相邻
Get-ChildItem $skillsDir -Directory | Sort-Object Name | ForEach-Object {
    Add-SkillsInDir $_.FullName $_.Name
}
$rows = @($rows | Sort-Object SortKey | Select-Object -ExpandProperty Row)

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