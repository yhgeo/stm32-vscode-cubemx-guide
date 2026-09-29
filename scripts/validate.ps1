[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot ".."))
)

$ErrorActionPreference = "Stop"
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-Condition {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        $failures.Add($Message)
    }
}

function Read-JsonFile {
    param([string]$Path)

    try {
        return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
    }
    catch {
        $failures.Add("JSON 无法解析: $Path - $($_.Exception.Message)")
        return $null
    }
}

$requiredFiles = @(
    "README.md",
    ".gitignore",
    "LICENSE",
    "templates/settings.json",
    "templates/c_cpp_properties.json",
    "templates/dot-clangd",
    "templates/launch.json",
    "templates/tasks.json",
    "templates/openocd.cfg",
    "templates/CMakeLists-auto-sources.cmake"
)

foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $Root $relativePath
    Assert-Condition (Test-Path -LiteralPath $path -PathType Leaf) "缺少文件: $relativePath"
}

foreach ($relativePath in @(
    "templates/settings.json",
    "templates/c_cpp_properties.json",
    "templates/launch.json",
    "templates/tasks.json"
)) {
    $path = Join-Path $Root $relativePath
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        [void](Read-JsonFile $path)
    }
}

$readme = Get-Content -LiteralPath (Join-Path $Root "README.md") -Raw
Assert-Condition ($readme -match "STM32CubeIDE for Visual Studio Code") "README 未说明当前 ST VS Code 工作流"
Assert-Condition ($readme -match "Discover STM32Cube project") "README 未说明项目发现步骤"
Assert-Condition ($readme -match "CMake") "README 未说明 CMake 主线"
Assert-Condition ($readme -match "## 目录") "README 缺少目录"
Assert-Condition ($readme -match "从零创建到烧录") "README 缺少从零创建到烧录流程"
Assert-Condition ($readme -match "D:\\VS Code\\Microsoft VS Code\\bin\\code\.cmd") "README 未说明当前 VS Code 命令行入口"

$allTemplateText = Get-ChildItem -LiteralPath (Join-Path $Root "templates") -File |
    Get-Content -Raw |
    Out-String

Assert-Condition ($allTemplateText -notmatch "D:/OpenOCD|C:/Users/|C:\\Users\\") "模板包含开发者本机绝对路径"
Assert-Condition ($allTemplateText -notmatch "14\.3\.1\+st\.2|4\.3\.1\+st\.1|1\.13\.2\+st\.1") "模板仍包含固定 bundle 版本号"

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Validation passed: $($requiredFiles.Count) repository files checked."
