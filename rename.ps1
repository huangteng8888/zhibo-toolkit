# rename.ps1
# 按时间顺序对 videos/ 目录下的视频文件批量重命名
# 规则：课程名_第NN节_<日期>_<标题>.mp4  (课次从第01节起按时间先后连续递增)
#
# 使用方法：
#   1. 编辑下面的 $Map，把"原始文件名 -> 目标文件名"映射填好
#      （如果脚本自动推断成功，可留空让它自动处理）
#   2. 在项目根目录执行：
#        powershell -ExecutionPolicy Bypass -File .\rename.ps1
#
# 干跑模式（不实际改名，只打印计划）：将 $DryRun 改为 $true

[CmdletBinding()]
param(
    [string]$Dir,
    [switch]$Auto = $false   # 启用自动按日期推断排序
)

if (-not $Dir) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
    $Dir = Join-Path $scriptDir 'videos'
}

$ErrorActionPreference = 'Stop'
$DryRun = $false  # 设为 $true 只打印计划

# ============== 1. 课程基础名 ==============
$CourseName = '叶叶财经小灶课'

# ============== 2. 手动映射表 ==============
# 首次批量整理时填这个表，后续新增课只需追加新行
# 格式: '原文件名' = '新文件名'
$Map = [ordered]@{
    '叶叶财经小灶课_5月13日叶叶铁粉小灶课.mp4'           = '叶叶财经小灶课_第01节_5月13日叶叶铁粉小灶课.mp4'
    '叶叶财经小灶课_5月14日叶叶财经小灶课第二节.mp4'     = '叶叶财经小灶课_第02节_5月14日叶叶财经小灶课第二节.mp4'
    '叶叶财经小灶课_5月15日叶叶财经小灶课.mp4'           = '叶叶财经小灶课_第03节_5月15日叶叶财经小灶课.mp4'
    '叶叶财经小灶课_5月17日叶叶小灶课第4节.mp4'          = '叶叶财经小灶课_第04节_5月17日叶叶小灶课第4节.mp4'
    '叶叶财经小灶课_5月18日叶叶小灶课第5节.mp4'          = '叶叶财经小灶课_第05节_5月18日叶叶小灶课第5节.mp4'
    '叶叶财经小灶课_5月19日叶叶小灶课第6节.mp4'          = '叶叶财经小灶课_第06节_5月19日叶叶小灶课第6节.mp4'
    '叶叶财经小灶课_5月20日叶叶小灶课第7节.mp4'          = '叶叶财经小灶课_第07节_5月20日叶叶小灶课第7节.mp4'
    '叶叶财经小灶课_5月21日叶叶小灶课第8节.mp4'          = '叶叶财经小灶课_第08节_5月21日叶叶小灶课第8节.mp4'
    '叶叶财经小灶课_5月22日叶叶小灶课第9节.mp4'          = '叶叶财经小灶课_第09节_5月22日叶叶小灶课第9节.mp4'
    '叶叶财经小灶课_5月24日叶叶小灶课第10节.mp4'         = '叶叶财经小灶课_第10节_5月24日叶叶小灶课第10节.mp4'
    '叶叶财经小灶课_5月25日叶叶小灶课第11节.mp4'         = '叶叶财经小灶课_第11节_5月25日叶叶小灶课第11节.mp4'
    '叶叶财经小灶课_5月26日叶叶小灶课第12节.mp4'         = '叶叶财经小灶课_第12节_5月26日叶叶小灶课第12节.mp4'
    '叶叶财经小灶课_5月27日叶叶小灶课第13节.mp4'         = '叶叶财经小灶课_第13节_5月27日叶叶小灶课第13节.mp4'
    '叶叶财经小灶课_5月28日叶叶小灶课第14节.mp4'         = '叶叶财经小灶课_第14节_5月28日叶叶小灶课第14节.mp4'
    '叶叶财经小灶课_5月29日叶叶小灶课第15节.mp4'         = '叶叶财经小灶课_第15节_5月29日叶叶小灶课第15节.mp4'
    '叶叶财经小灶课_5月31日叶叶小灶课第16节.mp4'         = '叶叶财经小灶课_第16节_5月31日叶叶小灶课第16节.mp4'
    '叶叶财经小灶课_6月1日微信视频.mp4'                  = '叶叶财经小灶课_第17节_6月1日微信视频.mp4'
}

# ============== 3. 自动化推断（实验性） ==============
# 仅处理 $Map 中没列出的 mp4 文件。从文件名抽取日期后排序自动编号。
# 已知日期模式：5月N日, 6月N日, 5.18 (历史别名)
function Get-DateFromName([string]$name) {
    if ($name -match '5\.18') { return [datetime]'2026-05-18' }
    if ($name -match '5月(\d{1,2})日') { return [datetime]("2026-05-{0:D2}" -f [int]$Matches[1]) }
    if ($name -match '6月(\d{1,2})日') { return [datetime]("2026-06-{0:D2}" -f [int]$Matches[1]) }
    if ($name -match '6月(\d{1,2})')   { return [datetime]("2026-06-{0:D2}" -f [int]$Matches[1]) }
    return $null
}

# ============== 4. 执行 ==============
if (-not (Test-Path $Dir)) {
    Write-Error "目录不存在: $Dir"
    exit 1
}

Set-Location $Dir
$files = Get-ChildItem *.mp4 -File | Sort-Object Name

# 把 $Map 里的目标和源做反向补全：如果目标文件已存在但源文件不在了，跳过；
# 如果源在 $Map 中有定义，用定义。
$plan = [System.Collections.Specialized.OrderedDictionary]::new()

# 自动推断时，需要先收集所有要重命名的文件，按日期排序后再编号
if ($Auto) {
    $needRename = @()
    foreach ($f in $files) {
        if ($f.Name -match '^叶叶财经小灶课_第\d{2}节_') { continue }
        $d = Get-DateFromName $f.Name
        if ($d) {
            $needRename += [pscustomobject]@{ Name = $f.Name; Date = $d }
        } else {
            Write-Warning "无法从文件名推断日期，跳过: $($f.Name)"
        }
    }
    $maxN = 0
    foreach ($f in $files) {
        if ($f.Name -match '^叶叶财经小灶课_第(\d{2})节_') {
            $n = [int]$Matches[1]
            if ($n -gt $maxN) { $maxN = $n }
        }
    }
    $needRename = $needRename | Sort-Object Date
    foreach ($item in $needRename) {
        $maxN++
        $nn = '{0:D2}' -f $maxN
        $src = $item.Name
        $body = $src -replace '^叶叶财经小灶课_', ''
        $dst = "叶叶财经小灶课_第${nn}节_$body"
        $plan[$src] = $dst
    }
} else {
    # 使用手动 $Map：过滤掉"源不存在"或"源==目标"的项
    foreach ($k in $Map.Keys) {
        $target = $Map[$k]
        if (-not (Test-Path -LiteralPath $k)) {
            if (Test-Path -LiteralPath $target) {
                Write-Verbose "源不存在但目标已就位，跳过: $target"
                continue
            } else {
                Write-Warning "源文件不存在且目标也未找到: $k"
                continue
            }
        }
        if ($k -eq $target) { continue }
        $plan[$k] = $target
    }
}

if ($plan.Count -eq 0) {
    Write-Host "没有需要重命名的文件。" -ForegroundColor Yellow
    exit 0
}

Write-Host "=== 重命名计划 (DryRun=$DryRun) ===" -ForegroundColor Cyan
$plan.GetEnumerator() | ForEach-Object {
    Write-Host ("  {0}  ->  {1}" -f $_.Key, $_.Value)
}

# 两步重命名：先全部改成临时名，再改成最终名，避免冲突
$tmp = @{}
$i = 0
foreach ($k in $plan.Keys) {
    $t = "__tmp_${i}.mp4"
    if ($DryRun) {
        Write-Host "  [DRY] $k -> $t -> $($plan[$k])"
    } else {
        Rename-Item -LiteralPath $k -NewName $t
    }
    $tmp[$t] = $plan[$k]
    $i++
}
foreach ($k in $tmp.Keys) {
    if ($DryRun) {
        Write-Host "  [DRY] $k -> $($tmp[$k])"
    } else {
        Rename-Item -LiteralPath $k -NewName $tmp[$k]
    }
}

if ($DryRun) {
    Write-Host "`n干跑完成，未实际修改文件。" -ForegroundColor Yellow
} else {
    Write-Host "`n重命名完成。" -ForegroundColor Green
    Write-Host "最终文件列表：" -ForegroundColor Cyan
    Get-ChildItem *.mp4 -File | Sort-Object Name | ForEach-Object {
        $size = [math]::Round($_.Length/1MB, 2)
        Write-Host ("  {0}  ({1} MB)" -f $_.Name, $size)
    }
}