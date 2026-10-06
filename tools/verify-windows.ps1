param(
    [string]$OutputDirectory = '',
    [string]$SwiftExecutable = 'swift'
)
$ErrorActionPreference = 'Stop'
# Native non-zero exits are handled explicitly, including PowerShell 7.3+.
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) { $PSNativeCommandUseErrorActionPreference = $false }
$taskProject = Split-Path -Parent $PSScriptRoot
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $taskProject 'work\verification\windows' }
$taskOutput = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$taskStatus = [ordered]@{
    platform = 'Windows'; commit = $env:GITHUB_SHA; time = [DateTime]::UtcNow.ToString('o')
    results = [ordered]@{ 'CORE WINDOWS' = @{ status = 'NOT RUN'; reason = 'Swift has not been invoked' } }
}
function Save-Status {
    $taskStatus | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $taskOutput 'status.json') -Encoding UTF8
}
function Invoke-SwiftStage([string]$Stage, [string[]]$Arguments) {
    Write-Host "`n=== $Stage : swift $($Arguments -join ' ') ==="
    $taskLog = Join-Path $taskOutput "$Stage.log"
    & $taskSwift.Source @Arguments 2>&1 | Tee-Object -FilePath $taskLog | ForEach-Object { Write-Host $_ }
    $taskExit = $LASTEXITCODE
    if ($taskExit -ne 0) { throw "$Stage failed with exit code $taskExit. See $taskLog" }
}
Save-Status
$taskSwift = Get-Command $SwiftExecutable -CommandType Application -ErrorAction SilentlyContinue
if (-not $taskSwift) {
    $taskStatus.results['CORE WINDOWS'].reason = 'Swift is absent from PATH. Follow WINDOWS_SETUP.md, reopen PowerShell, and rerun.'
    Save-Status
    Write-Host 'CORE WINDOWS: NOT RUN - Swift is not installed or is absent from PATH.'
    Write-Host "Installation instructions: $(Join-Path $taskProject 'WINDOWS_SETUP.md')"
    exit 2
}
$taskFailed = $false
Push-Location $taskProject
try {
    Write-Host "SDKROOT=$env:SDKROOT"
    if (-not $env:SDKROOT -or -not (Test-Path -LiteralPath $env:SDKROOT)) {
        throw 'SDKROOT is missing or invalid. The Swift Windows SDK must be available before SwiftPM can compile the package manifest.'
    }
    Invoke-SwiftStage 'version' @('--version')
    Invoke-SwiftStage 'resolve' @('package', 'resolve')
    Invoke-SwiftStage 'build' @('build', '-Xswiftc', '-warnings-as-errors')
    Invoke-SwiftStage 'test' @('test', '-Xswiftc', '-warnings-as-errors', '--xunit-output', (Join-Path $taskOutput 'core-tests.xml'))
    [xml]$taskTestResults = Get-Content -LiteralPath (Join-Path $taskOutput 'core-tests.xml') -Raw
    $taskCases = $taskTestResults.SelectNodes('//testcase')
    if ($taskCases.Count -eq 0) { throw 'Swift returned success without executed XCTest cases in its XML report' }
    if ($taskTestResults.SelectNodes('//failure | //error').Count -ne 0) { throw 'The XCTest XML report contains failures/errors' }
    $taskStatus.executedTestCases = $taskCases.Count
    $taskStatus.results['CORE WINDOWS'] = @{ status = 'PASS'; reason = 'Native Swift package resolve, build and core XCTest execution succeeded' }
} catch {
    $taskFailed = $true
    $taskStatus.results['CORE WINDOWS'] = @{ status = 'FAIL'; reason = $_.Exception.Message }
    Write-Host $_.Exception.Message
} finally {
    Pop-Location
    Save-Status
    Write-Host "CORE WINDOWS: $($taskStatus.results['CORE WINDOWS'].status)"
}
if ($taskFailed) { exit 1 }
exit 0
