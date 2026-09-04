# update-actionlint.ps1 —— 检查并更新内置 actionlint 校验器（使用即检查 / 懒更新）
#
# 用法：
#   ./scripts/update-actionlint.ps1                 # 检查上游最新版，有新版自动下载替换
#   ./scripts/update-actionlint.ps1 -Force          # 版本相同也强制重新下载验证
#   ./scripts/update-actionlint.ps1 -Platform linux_amd64   # 显式指定平台资产
#   ./scripts/update-actionlint.ps1 -LintOnly       # 只报告目标版本，不写盘（CI 红灯 PR 评审预演用）
#
# 退出码：0 = 已是最新或更新成功；1 = 上游查询/下载/校验失败（拉取失败即抛错，只有无更新才静默跳过）
#         2 = 检出有新版，但 A2 质量门禁红灯（新版对仓库现有 workflow 引入新增报错，本地未替换；供 CI 截停开 PR）
#
# 设计要点：
#   - 版本事实源：同目录 actionlint.version（脚本与 CI 都读它）
#   - 幂等：版本相同（且未 -Force）时不重新下载
#   - 原子替换：先下载到临时目录并跑 --version 验证，验证通过才覆盖技能目录
#   - A1 自愈：本地 actionlint.exe 缺失时无视版本文件强制重新下载（防产物丢失后静默不恢复）
#   - A2 质量门禁：替换前用新二进制对仓库全部 .github/workflows/*.yml 跑 lint，
#     与旧版（或本脚本已知基线）报错比对；新增报错即红灯 exit 2，本地不替换、由 CI 改开 PR 人工 review。
#     零新增报错 = 绿灯，正常替换。
#   - 失败即抛错：网络/API 出错时输出错误并退出 1（拉取失败必须染红，只有无更新才静默跳过）
#   - 本机平台自动映射（AMD64/ARM64 常见组合）；CI 固定传 -Platform windows_amd64
#     （因为仓库内置的是 Windows amd64 二进制，与 runner 平台无关）

param(
  [string]$Platform = '',  # 留空 = 按本机自动判断；可选 windows_amd64 / linux_amd64 / linux_arm64 / darwin_amd64 / darwin_arm64 等
  [switch]$Force,          # 版本相同也强制重新下载
  [switch]$LintOnly,       # 只查询/下载到临时目录并做 A2 lint 比对，不写盘（供 CI 红灯 PR 预演、本地试跑新版本）
  [string]$ApiUrl = 'https://api.github.com/repos/rhysd/actionlint/releases/latest'
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
$exePath = Join-Path $scriptDir 'actionlint.exe'
$versionFile = Join-Path $scriptDir 'actionlint.version'

# ---------- A2 质量门禁核心：比对新旧 lint 结果 ----------
# 入参为两个对象 { ExitCode, Lines }（Lines 为 actionlint 原始输出行数组）。
# 返回 @{ verdict='green'|'red'; added=@(...); oldNorm=@(...); newNorm=@(...) }。
# 判定：退出码 0 = 该侧无报错；否则提取 'path:line:col:' 归一化消息行，去重后取差集。
function Compare-Lint {
  param(
    [Parameter(Mandatory)] [object]$Old,
    [Parameter(Mandatory)] [object]$New
  )
  function Get-Norm([int]$ExitCode, [string[]]$Lines) {
    if ($ExitCode -eq 0) { return @() }
    $norm = @()
    foreach ($ln in $Lines) {
      if ($ln -match '^(.*?):(\d+):(\d+):\s*(.*)$') {
        # 归一化到 "路径:消息"，忽略行/列号，避免版本间行号漂移造成误报新增
        $norm += ($matches[1].Trim() + ':' + $matches[4].Trim())
      }
    }
    return @($norm | Sort-Object -Unique)
  }
  $oldNorm = @(Get-Norm -ExitCode $Old.ExitCode -Lines $Old.Lines)
  $newNorm = @(Get-Norm -ExitCode $New.ExitCode -Lines $New.Lines)
  $added   = @($newNorm | Where-Object { $_ -notin $oldNorm })
  if ($added.Count -gt 0) { return @{ verdict = 'red'; added = $added; oldNorm = $oldNorm; newNorm = $newNorm } }
  return @{ verdict = 'green'; added = @(); oldNorm = $oldNorm; newNorm = $newNorm }
}

# A1：本地 exe 缺失时，即使版本文件显示已最新也要强制重新下载（防产物丢失后静默不恢复）
$current = if (Test-Path $versionFile) { (Get-Content $versionFile).Trim() } else { '未知' }
if (-not (Test-Path $exePath)) {
  Write-Warning "A1 自愈：本地校验器缺失（$exePath），无视版本文件强制重新下载"
  $current = '缺失'
  $Force = $true
}

# ---------- 平台资产名映射 ----------
function Get-NativePlatform {
  if ($IsWindows) {
    switch ($env:PROCESSOR_ARCHITECTURE) {
      'AMD64' { return 'windows_amd64' }
      'ARM64' { return 'windows_arm64' }
      default { return 'windows_amd64' }
    }
  }
  $arch = (uname -m).Trim()
  if ($IsLinux) {
    switch ($arch) {
      'x86_64'  { return 'linux_amd64' }
      'aarch64' { return 'linux_arm64' }
      'armv6l'  { return 'linux_armv6' }
      'armv7l'  { return 'linux_armv6' }
      default   { return 'linux_amd64' }
    }
  }
  if ($IsMacOS) {
    switch ($arch) {
      'x86_64' { return 'darwin_amd64' }
      'arm64'  { return 'darwin_arm64' }
      default  { return 'darwin_amd64' }
    }
  }
  return 'linux_amd64'  # 兜底
}

if (-not $Platform) { $Platform = Get-NativePlatform }
Write-Output "目标平台资产: $Platform"

# ---------- 查询上游最新版（优先 gh CLI，其带认证配额高；CI 的 GH_TOKEN 自动生效）----------
Write-Output "本地版本: $current"
$release = $null
if (Get-Command gh -ErrorAction SilentlyContinue) {
  try { $release = gh api repos/rhysd/actionlint/releases/latest 2>$null | ConvertFrom-Json } catch { $release = $null }
}
if (-not $release) {
  try { $release = Invoke-RestMethod -Uri $ApiUrl -Headers @{ 'User-Agent' = 'just-silver-skills' } } catch { $release = $null }
}
if (-not $release) {
  Write-Error '查询上游最新版失败（gh 与匿名 API 均不可用，可能限流、网络不通或仓库被删/改名）；拉取失败必须抛错'
  exit 1
}
$latestTag = $release.tag_name
Write-Output "上游最新: $latestTag"

# ---------- 版本比较 ----------
# A1 自愈强制下载时 $current 为 '缺失'，必然不等 → 走更新
if ($latestTag -eq $current -and -not $Force) {
  Write-Output '已是最新，无需更新'
  exit 0
}

# ---------- 定位并下载对应平台资产（不落地，先下载到临时目录验证）----------
$verNoV = $latestTag -replace '^v', ''
$asset = $release.assets | Where-Object { $_.name -like "actionlint_${verNoV}_${Platform}*" } | Select-Object -First 1
if (-not $asset) {
  Write-Warning "未找到平台 $Platform 的资产（assets 列表可能变化，请核对 https://github.com/rhysd/actionlint/releases/latest）"
  exit 1
}
Write-Output "下载资产: $($asset.name)"

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("actionlint-update-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpDir | Out-Null
try {
  $archive = Join-Path $tmpDir $asset.name
  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $archive -Headers @{ 'User-Agent' = 'just-silver-skills' }

  # 解压（Windows 为 .zip，其余平台为 .tar.gz）
  if ($asset.name -like '*.zip') {
    Expand-Archive -Path $archive -DestinationPath $tmpDir -Force
  } else {
    tar -xzf $archive -C $tmpDir
  }

  # 定位解压出的二进制
  $newExe = Join-Path $tmpDir 'actionlint.exe'
  if (-not (Test-Path $newExe)) { $newExe = Join-Path $tmpDir 'actionlint' }
  if (-not (Test-Path $newExe)) { throw '解压产物中未找到 actionlint 可执行文件' }

  # 验证新二进制可运行（注意：不能写成 `& $newExe --version 2>&1 | Select-Object -First 1` 再读
  # $LASTEXITCODE——命令进管道后 $LASTEXITCODE 读取不可靠（可能为空导致误判失败），须先直跑捕获再读）
  $verOut = & $newExe --version 2>&1
  $verExit = $LASTEXITCODE
  Write-Output "新二进制版本: $(($verOut | Select-Object -First 1) -join '')"
  if ($verExit -ne 0) { throw '新二进制 --version 校验失败' }

  # ---------- A2 质量门禁：新二进制对仓库全部 workflow 自举 lint，比对旧版/基线 ----------
  $repoRoot = git rev-parse --show-toplevel 2>$null
  $workflows = @()
  if ($repoRoot) {
    $wfDir = Join-Path $repoRoot '.github/workflows'
    if (Test-Path $wfDir) { $workflows = @(Get-ChildItem -Path $wfDir -Filter '*.yml' | ForEach-Object { $_.FullName }) }
  }
  if ($workflows.Count -eq 0) {
    Write-Warning 'A2 门禁：未找到仓库 .github/workflows/*.yml（可能不在 git 仓库内），跳过 A2 lint 比对，直接替换'
  } else {
    # 用当前（替换前的）校验器跑一遍作为基线（缺失时用新版自身跑，仅自检语法）
    $oldExe = if (Test-Path $exePath) { $exePath } else { $newExe }
    $oldOut = @(& $oldExe $workflows 2>&1)
    $oldCode = $LASTEXITCODE
    $newOut = @(& $newExe $workflows 2>&1)
    $newCode = $LASTEXITCODE

    $cmp = Compare-Lint -Old @{ ExitCode = $oldCode; Lines = $oldOut } -New @{ ExitCode = $newCode; Lines = $newOut }

    if ($cmp.verdict -eq 'red') {
      Write-Warning "A2 质量门禁红灯：新版 v$verNoV 对仓库现有 workflow 引入 $($cmp.added.Count) 条新增报错，本地未替换。`n请在人工 review 后决定忽略（升级）或修复。"
      Write-Output '---- 新版新增报错（相对旧版） ----'
      $cmp.added | ForEach-Object { Write-Output $_ }
      Write-Output '---- 旧版全部报错（基线） ----'
      $cmp.oldNorm | ForEach-Object { Write-Output $_ }
      exit 2
    }
    Write-Output "A2 绿灯：新版对仓库 workflow 无新增报错（旧版 $($cmp.oldNorm.Count) 条，新版 $($cmp.newNorm.Count) 条一致）"
  }

  # ---------- LintOnly：仅报告，不写盘 ----------
  if ($LintOnly) {
    Write-Output "LintOnly：已下载并验证新版 v$verNoV（绿灯），未写盘。如需替换请去掉 -LintOnly 重跑。"
    exit 0
  }

  # 原子替换 + 更新版本事实源
  Copy-Item -Path $newExe -Destination $exePath -Force
  if (-not $IsWindows) {
    & chmod +x $exePath 2>$null   # 非 Windows 补可执行权限
  }
  Set-Content -Path $versionFile -Value $latestTag
  Write-Output "更新完成: $current -> $latestTag（$exePath）"
  exit 0
} catch {
  Write-Warning "更新失败: $($_.Exception.Message)（现有校验器保持可用）"
  exit 1
} finally {
  Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
