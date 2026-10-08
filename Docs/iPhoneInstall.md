# Installing ASCEND on a physical iPhone

ASCEND V1 targets **iOS 27 or later** and needs Xcode 27 with the matching device SDK. The private repository contains no signing credentials. CI attempts an **unsigned arm64 device archive**, not an installable signed IPA.

## Know which artifact you have

| Artifact | Meaning |
|---|---|
| Simulator `ASCEND.app` | Built for the simulator platform; cannot be installed on a phone, even when its CPU architecture is arm64. |
| Device `ASCEND.app` | Built using `iphoneos`; needs valid code signing and provisioning, including its embedded Live Activity extension. |
| `.xcarchive` | Xcode archive with device app, extension and archive metadata; input to a signing/export process. |
| `.ipa` | ZIP container with `Payload/ASCEND.app`; packaging alone does not sign or authorize installation. |

The GitHub Actions artifact **ascend-unsigned-device-archive** contains `ASCEND-unsigned.xcarchive`, build log and `status.json` when archive succeeds. Inspect its own status and find `Products/Applications/ASCEND.app/PlugIns/AscendRestWidget.appex`. A compile or signing-preparation failure must not be reported as a usable app. Downloading Actions artifacts requires access to the private repository; retention is 14 days.

## Preferred first test: Mac + Xcode + iPhone 17

1. Export a backup from any existing ASCEND installation before replacing/deleting it.
2. Clone/update private `main` on a Mac. Open `ASCEND.xcodeproj`; choose **ASCEND**, not ASCEND Demo.
3. Connect and unlock iPhone 17, trust the Mac and select the device as the run destination. Confirm the phone actually runs supported iOS 27+.
4. In Xcode Settings → Accounts, add your Apple Account. In **both ASCEND and AscendRestWidget** targets, Signing & Capabilities, select the same personal/developer Team and Automatic Signing. Use a unique app bundle identifier and an extension identifier with that app prefix, for example `your.unique.ascend` and `your.unique.ascend.rest`.
5. If Xcode requests Developer Mode, enable it in Settings → Privacy & Security → Developer Mode, restart and confirm. Follow the actual iOS prompts for profile trust when required. [Apple Developer Mode instructions](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).
6. Build and Run. Confirm onboarding, no demo marker, catalog-only initial state and unknown measurements. Follow the device QA matrix in [V1MasterUpdate.md](V1MasterUpdate.md).
7. Turn on notification permission when starting the first rest. Enable Live Activities for ASCEND in phone settings if offered. Test lock, background, force-close/reopen and the embedded widget. Neither a simulator screenshot nor an unsigned archive validates this behavior.

The project generator owns build settings and shared schemes. Set signing locally **after** `python tools/generate_project.py`, or reapply your local signing choices after regeneration. Do not commit team credentials, certificates, provisioning profiles, passwords or exported personal backups.

## Free signing and durable testing

Apple's free Personal Team can support personal device development, but its provisioning profiles expire after **7 days**, requiring a new build/install. The developer account has further device/App-ID limits; check the current [Apple account comparison](https://developer.apple.com/help/account/basics/about-your-developer-account/). Free signing is not a six-month unattended installation plan.

A paid Apple Developer Program membership allows the relevant distribution/provisioning routes. For development/ad hoc installation, the device must be included when required by that profile, and **app plus extension** need matching identifiers, profiles and signing certificates. Xcode Organizer → Distribute App can export an appropriately signed IPA from a signed archive. Do not assume the unsigned CI archive can be exported without obtaining those signing assets; rebuilding from source with automatic signing is the clearest first path.

For TestFlight: create the app record in App Store Connect with the same registered app identifier; archive a signed Release in Xcode; distribute to App Store Connect; wait for processing; add permitted testers and install using TestFlight. External testing may require beta review. Each TestFlight build is available for **90 days**, so it also needs renewal. [Apple TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).

## Possible Windows route: re-sign a real device build

Windows cannot compile this native app against the Apple SDK. Obtain the **iphoneos device** app/archive from a successful macOS build first. Re-signing tools do not turn a simulator build into a device build.

[Sideloadly's official FAQ](https://sideloadly.io/faq.html) documents Windows installation and Apple Account signing. [AltStore Classic's Windows guide](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) explains AltServer and phone installation. Follow their current official steps and iOS compatibility information. Do not assume iOS 27 or ASCEND's widget is supported merely because an older version worked.

If a re-signing tool requires an IPA, on a Mac package the unsigned **device** app with proper ZIP tooling, preserving bundle structure:

```sh
mkdir -p work/device-package/Payload
cp -R work/verification/device/ASCEND-unsigned.xcarchive/Products/Applications/ASCEND.app work/device-package/Payload/
(cd work/device-package && /usr/bin/zip -qry ../ASCEND-unsigned.ipa Payload)
```

That file remains **unsigned**. Give it to the chosen tool's signing/import workflow, authenticate privately, connect/trust the phone and follow that tool's install/refresh procedure. Do not rename a generic `.zip` of the archive to `.ipa`: `Payload/ASCEND.app` is required. Re-sign every nested executable/extension correctly. Some sideloading routes remove extensions; that disables Live Activity and is not full V1 acceptance. Prefer Xcode for validating the complete app/extension pair. Free account installations require periodic refresh; do not rely on them remaining runnable indefinitely. Export backup before reinstalling, changing bundle IDs or uninstalling.

## Release blockers and secret handling

No signed IPA, certificate, registered physical device, provisioning profile or successful iPhone QA is supplied by this change. These require the owner's account/device and compatible Apple tooling. Store any future CI certificate/profile secrets only in private GitHub Actions Secrets with a deliberately configured signing job; the current workflow does not request them. Personal fitness data stays local; never upload an exported user backup as a CI fixture.
