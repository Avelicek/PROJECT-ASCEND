# Connect ASCEND to a private GitHub repository

The project is ready locally at `C:\Users\karel\Desktop\GymApp`. No repository has been created, no source has been pushed and no remote CI run has occurred. These steps connect the existing files when you are ready.

## 1. Create an empty private repository

Sign into GitHub. Open [New repository](https://github.com/new). Choose your account or organization, name it `PROJECT-ASCEND` (or your preferred name), and select **Private**. Leave “Add a README”, `.gitignore`, and license unchecked because this project already contains files. Click **Create repository**. Copy its HTTPS URL.

GitHub documents the [existing-local-project import process](https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github).

## 2. Commit and push this existing project

Open PowerShell and replace `YOUR_ACCOUNT` and the repository name below with the URL you copied:

```powershell
Set-Location 'C:\Users\karel\Desktop\GymApp'
git init -b main
git status --short
git add .
git diff --cached --stat
git commit -m "Prepare ASCEND Build 01.5 verification"
git remote add origin https://github.com/YOUR_ACCOUNT/PROJECT-ASCEND.git
git push -u origin main
```

Git is installed on this computer. If commit reports missing author identity, run `git config user.name "Your name"` and `git config user.email "Your GitHub email or GitHub-provided no-reply email"` inside this project, then repeat the commit and push. Use your actual identity. HTTPS push can prompt for Git Credential Manager/browser sign-in. GitHub account passwords are not used as Git passwords; see [GitHub authentication guidance](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/about-authentication-to-github).

Generated `work/`, `.build/`, `.swiftpm/`, DerivedData, result bundles and Python caches are ignored. Source, shared Xcode schemes, test targets and `.github/workflows/ios-ci.yml` are committed. Inspect the staged file list before pushing. These commands assume this project's current state: no existing Git repository or remote.

## 3. Enable GitHub Actions

In the repository open **Settings → Actions → General**. Enable Actions for the repository if disabled. Allow the official `actions/checkout`, `actions/upload-artifact` and `actions/download-artifact` actions (or “Allow all actions and reusable workflows” for this private hobby repository). Organization policies may require an administrator to permit them. Keep workflow token permissions at **Read repository contents**; this workflow requests only `contents: read` and does not push changes.

No Apple Developer account, certificates, signing secrets or App Store credentials are needed for simulator builds. The workflow uses a native Windows job and GitHub's `xcode-27` macOS runner, currently a public-preview image. This label and availability are documented in [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) and [the Xcode 27 runner announcement](https://github.blog/changelog/2026-09-10-xcode-27-runner-image-now-runs-on-macos-27/). It is checked against the actual installed Xcode/SDK at runtime.

Private repository runs use your account's Actions allocation. Check the account/organization **Billing and licensing → Actions** settings if jobs cannot start because of quota or a spending limit; consult [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions). Artifact retention is configured to 14 days and may be shortened by repository policy.

## 4. Trigger the first real macOS/Xcode run

The first push to `main` automatically triggers **ASCEND Build 01.5 verification**. To run it again manually: open **Actions → ASCEND Build 01.5 verification → Run workflow**, choose `main`, and click **Run workflow**. `workflow_dispatch` is already checked in. It appears after the workflow is on the repository's default branch. [GitHub's manual-run guide](https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-workflow-runs/manually-running-a-workflow) describes this flow.

The **Native Windows Core** job installs official prerequisites and runs SwiftPM on Windows. Independently, **Xcode 27 compile, XCTest and screenshots** prints versions and inventory, chooses an available iPhone/iOS 27+ simulator, resolves dependencies, builds ASCEND and the ASCEND Demo **scheme**, builds both test targets, then executes hosted unit tests, UI smoke and screenshot tests. Demo is a shared scheme for the app target, not a duplicate application target. Simulator selection prefers the highest installed iPhone model generation, then its Pro Max/Plus variant, then newest available runtime. It does not assume a named simulator exists.

Both Debug and Release app configurations compile; the screenshot/test suites use Debug to enable isolated Demo data. Swift/Clang compiler warnings and complete Swift concurrency diagnostics are errors. Asset-catalog diagnostics are retained in logs; empty owner-supplied artwork slots are not silently replaced. A unit-test failure still allows smoke and screenshot stages to run when test binaries compiled. A compile failure leaves later stages NOT RUN.

The workflow will fail if a compiler/test/export stage fails. The first remote run is the authority for Swift syntax, Apple API signatures, macro expansion, relationships and simulator behavior. No local Windows check establishes that these have passed. Correct any reported source error, commit and push it; the workflow reruns automatically. If `xcode-27` is unavailable, inspect the official runner list and use only an image verified to provide Xcode 27, or a Mac runner with that exact toolchain. Do not remove the version guard to turn an older SDK run green.

## 5. Find logs, tests and rendered screenshots on Windows

Open **Actions**, select the run for your commit, and open each job. Expand the named steps for full compiler and XCTest logs. The **Six independent verification statuses** job and run summaries show:

| Stage | Values |
|---|---|
| CORE WINDOWS | PASS / FAIL / NOT RUN |
| IOS COMPILE | PASS / FAIL / NOT RUN |
| UNIT TESTS | PASS / FAIL / NOT RUN |
| UI SMOKE | PASS / FAIL / NOT RUN |
| SCREENSHOTS | GENERATED / FAILED / NOT RUN |
| FOUNDATION MODELS INFERENCE | PASS / FAIL / UNAVAILABLE / NOT TESTED |

On the completed run's summary page, scroll to **Artifacts**:

- **windows-core-results**: install/compiler/test logs, native XCTest XML and `status.json`.
- **ios-build-and-test-results**: all Apple logs, installed CLI help, simulator inventory, selected device in `status.json`, `unit-summary.json`, `smoke-summary.json`, `visual-summary.json`, attachment manifest and three `.xcresult` bundles. JSON and text are readable on Windows; opening a raw `.xcresult` in Xcode requires a Mac.
- **ascend-simulator-screenshots**: `01_dashboard.png`, `02_workout.png`, `03_recovery.png`, `04_progress.png`, `05_profile.png` and `provenance.json`. Download the ZIP, extract it in Explorer and open the PNGs in Photos. These are real rendered simulator captures, with Alex's seeded weight, workouts, recovery and rank history. The suite verifies demo ELO 1084 before capture. This artifact appears only when screenshot attachments were actually exported; inspect the screenshot status if a partial/failed suite produced files.
- **verification-summary**: combined Markdown/JSON table for this run. Platform status artifacts also preserve the original evidence independently.

Uploads are attempted even after failure. A canceled/timed-out runner can prevent final uploads; missing evidence is reported NOT RUN, never PASS. A job may fail on infrastructure or upload errors even when an earlier compile stage passed. Read the job log as well as the status table. [GitHub's artifact download guide](https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-workflow-runs/downloading-workflow-artifacts) covers access and download.

Foundation Models inference remains **NOT TESTED** in this workflow. Launch and deterministic fallback are checked without requesting inference. To report PASS or UNAVAILABLE for inference later, a supported Apple Intelligence device and actual recorded model-availability/request evidence are required.
