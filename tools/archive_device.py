"""Build an unsigned physical-iPhone archive on macOS; never claim it is installable."""
from pathlib import Path
import json, os, platform, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "work/verification/device"

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    status = {"commit": os.environ.get("GITHUB_SHA"), "signed": False, "installable": False, "status": "NOT RUN"}
    try:
        if platform.system() != "Darwin": raise RuntimeError("Xcode 27 on macOS is required. No device archive was built.")
        command = ["xcodebuild", "-project", "ASCEND.xcodeproj", "-scheme", "ASCEND", "-configuration", "Release", "-destination", "generic/platform=iOS", "-derivedDataPath", str(OUT / "DerivedData"), "-archivePath", str(OUT / "ASCEND-unsigned.xcarchive"), "CODE_SIGNING_ALLOWED=NO", "SWIFT_TREAT_WARNINGS_AS_ERRORS=YES", "SWIFT_STRICT_CONCURRENCY=complete", "archive"]
        with (OUT / "archive.log").open("w", encoding="utf-8") as log:
            process = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=False)
        app = OUT / "ASCEND-unsigned.xcarchive/Products/Applications/ASCEND.app"
        if process.returncode or not (app / "ASCEND").is_file() or not (app / "PlugIns/AscendRestWidget.appex").is_dir():
            raise RuntimeError(f"Unsigned device archive failed (exit {process.returncode}). Inspect archive.log.")
        status.update(status="GENERATED", reason="arm64 iPhone app and Live Activity extension. Requires signing and a matching provisioning profile before installation.")
        (OUT / "README.txt").write_text("UNSIGNED IPHONE ARCHIVE\nThis artifact cannot be installed directly. It contains a physical-device app, not a simulator app. See Docs/iPhoneInstall.md for signing, packaging and installation. No signing credentials were used.\n", encoding="utf-8")
        return 0
    except (OSError, RuntimeError) as error:
        status.update(status="FAILED", reason=str(error)); print(str(error), file=sys.stderr); return 1
    finally:
        (OUT / "status.json").write_text(json.dumps(status, indent=2), encoding="utf-8")

if __name__ == "__main__": raise SystemExit(main())
