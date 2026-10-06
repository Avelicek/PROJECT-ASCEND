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
$env:PATH = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + $env:PATH
# Some toolchain installers add SDKROOT as a machine variable.
foreach ($taskName in @('SDKROOT', 'DEVELOPER_DIR')) {
    $taskValue = [Environment]::GetEnvironmentVariable($taskName, 'Machine')
    if ($taskValue) { [Environment]::SetEnvironmentVariable($taskName, $taskValue, 'Process') }
}
if (-not (Get-Command swift -CommandType Application -ErrorAction SilentlyContinue)) { throw 'Installer completed but swift is absent from PATH' }
