# Native Windows Core verification

Build 01.5 does not install software on your personal computer. Swift was absent from PATH during local preparation, so **CORE WINDOWS: NOT RUN**. The CI installer operates only on disposable GitHub-hosted Windows runners.

## Install the official toolchain

Use Windows 10/11 with current updates. Open PowerShell as Administrator for installation. The official [Swift Windows installation guide](https://www.swift.org/install/windows/) supplies these commands (checked 2026-10-06):

```powershell
winget install --id Microsoft.VisualStudio.2022.Community --exact --force --custom "--add Microsoft.VisualStudio.Component.Windows11SDK.22621 --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.VC.Tools.ARM64" --source winget
winget install --id Swift.Toolchain -e --source winget
```

If WinGet is absent, install/update Microsoft's App Installer using the [official WinGet guide](https://learn.microsoft.com/en-us/windows/package-manager/winget/). Alternatively, follow the manual installers linked from the Swift guide. If Visual Studio 2022 is already installed, use its installer to add the listed C++ tools and Windows SDK components instead of duplicating the IDE.

Enable **Developer Mode**: search for “Developer Mode” in Windows Settings and enable it. SwiftPM needs symlink support, as described by the [official Swift Windows prerequisites](https://www.swift.org/install/windows/winget/). Reboot if an installer requests it. Close all terminals and open a fresh PowerShell so PATH and SDK variables are refreshed. PowerShell 7 is recommended; CI uses `pwsh`.

## Execute real Core tests

```powershell
Set-Location 'C:\Users\karel\Desktop\GymApp'
Get-Command swift
swift --version
& .\tools\verify-windows.ps1
$LASTEXITCODE
```

If execution policy blocks the checked-in script, inspect it, then use a process-scoped policy for that terminal:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
& .\tools\verify-windows.ps1
```

The script runs `swift package resolve`, `swift build -Xswiftc -warnings-as-errors`, and `swift test -Xswiftc -warnings-as-errors --xunit-output ...`. It produces version/resolve/build/test logs, XCTest XML and `status.json` under `work/verification/windows/`. Exit **0** means those commands succeeded; **1** means a tool/build/test failure; **2** means Swift is missing and tests did not run. Native exit codes are checked explicitly. Compiler warnings fail the Core build.

`Package.swift` includes only `ASCEND/Core/Domain` and `Tests/Core`, without external dependencies. SwiftUI, UIKit, Charts, SwiftData and FoundationModels never enter the Windows target. The macOS deployment declaration in the manifest sets a minimum on macOS; it does not exclude Windows. Calendar, DST, timezone and Foundation behavior remain real portability tests, rather than being substituted with mock results.

The Windows package cannot compile the iOS app, SwiftData integration tests or XCUITest. Use the private-repository workflow in `PRIVATE_REPOSITORY_SETUP.md` for those stages.
