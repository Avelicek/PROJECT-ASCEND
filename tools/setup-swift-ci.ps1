# Only for disposable GitHub-hosted Windows runners. For a personal PC use WINDOWS_SETUP.md.
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'This installer is restricted to Windows GitHub Actions runners.' }
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) { $PSNativeCommandUseErrorActionPreference = $false }
$taskExistingSwift = Get-Command swift -CommandType Application -ErrorAction SilentlyContinue
if ($taskExistingSwift) {
    $taskVersion = & $taskExistingSwift.Source --version 2>&1
    $taskVersionExit = $LASTEXITCODE
    $taskVersionMatch = [regex]::Match(($taskVersion -join ' '), 'Swift version (\d+)\.')
    if ($taskVersionExit -eq 0 -and $taskVersionMatch.Success -and [int]$taskVersionMatch.Groups[1].Value -ge 6) {
        Write-Host "Using the runner's existing official Swift toolchain: $taskVersion"
        return
    }
}
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
    Install-Module Microsoft.WinGet.Client -Force -AllowClobber -Scope CurrentUser -Repository PSGallery
    Repair-WinGetPackageManager -AllUsers
    $env:PATH = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + $env:PATH
}
winget --version
if ($LASTEXITCODE -ne 0) { throw 'WinGet bootstrap failed' }
$taskVswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$taskVS = $null
if (Test-Path -LiteralPath $taskVswhere) {
    $taskVS = & $taskVswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 Microsoft.VisualStudio.Component.Windows11SDK.22621 -property installationPath
}
if (-not $taskVS) {
    winget install --id Microsoft.VisualStudio.2022.Community --exact --force --custom '--add Microsoft.VisualStudio.Component.Windows11SDK.22621 --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.VC.Tools.ARM64' --source winget --accept-source-agreements --accept-package-agreements --silent
    if ($LASTEXITCODE -notin @(0, 3010)) { throw "Visual Studio prerequisites failed: $LASTEXITCODE" }
}
# SwiftPM uses symlinks. The official Windows guide requires Developer Mode.
New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Name AllowDevelopmentWithoutDevLicense -Value 1 -PropertyType DWord -Force | Out-Null
winget install --id Swift.Toolchain --exact --source winget --accept-source-agreements --accept-package-agreements --silent
if ($LASTEXITCODE -notin @(0, 3010)) { throw "Swift toolchain installation failed: $LASTEXITCODE" }
$taskMachinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$taskUserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$env:PATH = $taskMachinePath + ';' + $taskUserPath + ';' + $env:PATH

# WinGet installs Swift per-user on hosted runners. Environment-variable broadcasts from
# the installer are not visible to the already-running PowerShell process, so discover
# and apply the SDK/runtime explicitly before invoking SwiftPM.
$taskSwiftRoot = Join-Path $env:LOCALAPPDATA 'Programs\Swift'
$taskSDKCandidates = @()
foreach ($taskScope in @('Process', 'User', 'Machine')) {
    $taskValue = [Environment]::GetEnvironmentVariable('SDKROOT', $taskScope)
    if ($taskValue) { $taskSDKCandidates += $taskValue }
}
$taskPlatforms = Join-Path $taskSwiftRoot 'Platforms'
if (Test-Path -LiteralPath $taskPlatforms) {
    $taskSDKCandidates += Get-ChildItem -LiteralPath $taskPlatforms -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -in @('Windows.sdk', 'WindowsExperimental.sdk') } |
        Sort-Object @{ Expression = { if ($_.Name -eq 'Windows.sdk') { 0 } else { 1 } } }, FullName |
        Select-Object -ExpandProperty FullName
}
$taskSDKRoot = $taskSDKCandidates |
    Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
    Select-Object -First 1
if (-not $taskSDKRoot) {
    throw "Swift installed but no Windows SDK was found under $taskPlatforms and SDKROOT is unset."
}
$env:SDKROOT = $taskSDKRoot
Write-Host "Swift SDKROOT: $env:SDKROOT"

$taskRuntimeRoot = Join-Path $taskSwiftRoot 'Runtimes'
if (Test-Path -LiteralPath $taskRuntimeRoot) {
    $taskRuntimeBins = Get-ChildItem -LiteralPath $taskRuntimeRoot -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName 'usr\bin' } |
        Where-Object { Test-Path -LiteralPath $_ }
    if ($taskRuntimeBins) {
        $env:PATH = ($taskRuntimeBins -join ';') + ';' + $env:PATH
        Write-Host "Swift runtime PATH: $($taskRuntimeBins -join ';')"
    }
}

if (-not (Get-Command swift -CommandType Application -ErrorAction SilentlyContinue)) { throw 'Installer completed but swift is absent from PATH' }
if (-not (Get-Command swiftc -CommandType Application -ErrorAction SilentlyContinue)) { throw 'Installer completed but swiftc is absent from PATH' }

# Fail during setup, with useful diagnostics, instead of later as a vague SwiftPM manifest error.
$taskTargetInfo = & swiftc -print-target-info 2>&1
$taskTargetExit = $LASTEXITCODE
$taskTargetInfo | ForEach-Object { Write-Host $_ }
if ($taskTargetExit -ne 0) { throw "swiftc -print-target-info failed with exit code $taskTargetExit" }
