# update-actionlint.ps1 —— 检查并更新内置 actionlint 校验器（使用即检查 / 懒更新）
#
# 用法：
#   ./scripts/update-actionlint.ps1                 # 检查上游最新版，有新版自动下载替换
#   ./scripts/update-actionlint.ps1 -Force          # 版本相同也强制重新下载验证
#   ./scripts/update-actionlint.ps1 -Platform linux_amd64   # 显式指定平台资产
#
# 退出码：0 = 已是最新或更新成功；1 = 上游查询/下载/校验失败（拉取失败即抛错，只有无更新才静默跳过）
#
# 设计要点：
#   - 版本事实源：同目录 actionlint.version（脚本与 CI 都读它）
#   - 幂等：版本相同（且未 -Force）时不重新下载
#   - 原子替换：先下载到临时目录并跑 --version 验证，验证通过才覆盖技能目录
#   - 失败即抛错：网络/API 出错时输出错误并退出 1（拉取失败必须染红，只有无更新才静默跳过）
#   - 本机平台自动映射（AMD64/ARM64 常见组合）；CI 固定传 -Platform windows_amd64
#     （因为仓库内置的是 Windows amd64 二进制，与 runner 平台无关）

param(
  [string]$Platform = '',  # 留空 = 按本机自动判断；可选 windows_amd64 / linux_amd64 / linux_arm64 / darwin_amd64 / darwin_arm64 等
  [switch]$Force,          # 版本相同也强制重新下载
  [string]$ApiUrl = 'https://api.github.com/repos/rhysd/actionlint/releases/latest'
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
$exePath = Join-Path $scriptDir 'actionlint.exe'
$versionFile = Join-Path $scriptDir 'actionlint.version'

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
$current = if (Test-Path $versionFile) { (Get-Content $versionFile).Trim() } else { '未知' }
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

if ($latestTag -eq $current -and -not $Force) {
  Write-Output '已是最新，无需更新'
  exit 0
}

# ---------- 定位并下载对应平台资产 ----------
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

  # 验证解压出的二进制可运行
  $newExe = Join-Path $tmpDir 'actionlint.exe'
  if (-not (Test-Path $newExe)) { $newExe = Join-Path $tmpDir 'actionlint' }
  if (-not (Test-Path $newExe)) { throw '解压产物中未找到 actionlint 可执行文件' }
  $verOut = & $newExe --version 2>&1 | Select-Object -First 1
  Write-Output "新二进制版本: $verOut"
  if ($LASTEXITCODE -ne 0) { throw '新二进制 --version 校验失败' }

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