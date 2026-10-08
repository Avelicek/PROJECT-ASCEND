#!/usr/bin/env python3
"""Run real Apple tooling. No synthetic compile, test or screenshot evidence."""
from pathlib import Path
import argparse
from datetime import datetime, timezone
import json, os, platform, re, shlex, shutil, struct, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
SCREENSHOTS = ('01_dashboard', '02_workout', '03_recovery', '04_progress', '05_profile', '06_live_workout', '07_workout_summary', '08_daily_evaluation', '09_exercise_library', '10_routine', '11_exercise_history', '12_brain_today', '13_brain_detail', '14_brain_low_confidence', '15_post_workout_brain', '16_onboarding', '17_sleep_mode', '18_end_sleep', '19_daily_objectives', '20_sick_mode', '21_data_management', '22_anatomy_3d')

def select_simulator(inventory):
    runtimes = {r['identifier']: r for r in inventory['runtimes'] if r.get('isAvailable') and 'iOS' in r.get('name', '')}
    candidates = []
    for runtime_id, devices in inventory['devices'].items():
        runtime = runtimes.get(runtime_id)
        if not runtime: continue
        version = tuple(int(v) for v in runtime['version'].split('.'))
        if version[0] < 27: continue
        for device in devices:
            if not device.get('isAvailable') or not device.get('name', '').startswith('iPhone'): continue
            model = device.get('deviceTypeIdentifier', device['name'])
            generation = re.search(r'iPhone[- ]?(\d+)', model, re.I)
            generation = int(generation[1]) if generation else 0
            size = 2 if re.search(r'Pro[- ]Max|Plus', model, re.I) else 1
            candidates.append(((generation, size, version, device['name']), dict(device, runtime=runtime)))
    if not candidates: raise RuntimeError('No available iPhone simulator with iOS 27+. Inspect simulator-inventory.json.')
    return max(candidates, key=lambda item: item[0])[1]

def export_named_screenshots(export_root, output):
    export_root, output = Path(export_root).resolve(), Path(output)
    manifest = json.loads((export_root / 'manifest.json').read_text(encoding='utf-8'))
    matches = {name: set() for name in SCREENSHOTS}
    def visit(node):
        if isinstance(node, list):
            for value in node: visit(value)
        elif isinstance(node, dict):
            name, filename = node.get('suggestedHumanReadableName', ''), node.get('exportedFileName')
            if filename and not isinstance(filename, str): raise ValueError('Attachment filename is not a string')
            if filename and isinstance(name, str):
                for expected in SCREENSHOTS:
                    if re.search(r'(?<![A-Za-z0-9])' + expected + r'(?![A-Za-z0-9])', name):
                        path = (export_root / filename).resolve()
                        if not path.is_relative_to(export_root): raise ValueError('Attachment path escapes export directory')
                        if path.suffix.lower() == '.png': matches[expected].add(path)
            for value in node.values():
                if isinstance(value, (list, dict)): visit(value)
    visit(manifest)
    validated = []
    for name, paths in matches.items():
        if len(paths) != 1: raise ValueError(f'Expected one {name} PNG; found {len(paths)}. Inspect manifest.json.')
        path = paths.pop()
        data = path.read_bytes()
        if len(data) < 33 or data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR': raise ValueError(f'Invalid PNG: {path.name}')
        width, height = struct.unpack('>II', data[16:24])
        if width < 300 or height < 600: raise ValueError(f'Unexpected screenshot size: {width}x{height}')
        validated.append((name, path, width, height))
    output.mkdir(parents=True, exist_ok=True)
    images = []
    for name, path, width, height in validated:
        shutil.copyfile(path, output / f'{name}.png')
        images.append(dict(name=name, width=width, height=height, exportedFileName=path.name))
    return images

def assert_tests_executed(path):
    data = json.loads(Path(path).read_text(encoding='utf-8'))
    passed, failed = data.get('passedTests', 0), data.get('failedTests', 0)
    if not isinstance(passed, int) or not isinstance(failed, int) or passed + failed < 1:
        raise ValueError('xcresult summary does not demonstrate executed tests. Inspect summary JSON and CLI help.')
    result = data.get('result', data.get('testResult'))
    if failed or result != 'Passed': raise ValueError('xcresult reports failed/non-passing tests')
    return data

class Verification:
    def __init__(self, output):
        self.output = Path(output)
        self.output.mkdir(parents=True, exist_ok=True)
        if any(self.output.iterdir()): raise RuntimeError('Output directory must be empty. Use --output with a new directory to rerun.')
        self.report = dict(platform=platform.platform(), commit=os.environ.get('GITHUB_SHA'), time=datetime.now(timezone.utc).isoformat(), commands=[], results={
            name: dict(status='NOT RUN', reason='Stage has not executed') for name in ('IOS COMPILE', 'UNIT TESTS', 'UI SMOKE', 'SCREENSHOTS')})
        self.report['results']['FOUNDATION MODELS INFERENCE'] = dict(status='NOT TESTED', reason='No inference device was probed; fallback tests do not verify inference')
        self.save()
    def save(self):
        (self.output / 'status.json').write_text(json.dumps(self.report, indent=2) + '\n', encoding='utf-8')
    def status(self, stage, value, reason):
        self.report['results'][stage] = dict(status=value, reason=reason)
        self.save()
        print(f'{stage}: {value} - {reason}', flush=True)
    def run(self, label, command, json_file=None, required=True):
        print(f'\n=== {label}: {shlex.join(command)} ===', flush=True)
        entry = dict(label=label, command=command)
        self.report['commands'].append(entry)
        self.save()
        lines = []
        with (self.output / f'{label}.log').open('w', encoding='utf-8') as log:
            log.write(shlex.join(command) + '\n')
            process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace', bufsize=1)
            for line in process.stdout:
                log.write(line); log.flush(); lines.append(line); print(line, end='', flush=True)
            code = process.wait()
        entry['exitCode'] = code
        self.save()
        text = ''.join(lines)
        if code and required: raise RuntimeError(f'{label} exited {code}. See {label}.log')
        if json_file and code == 0:
            (self.output / json_file).write_text(json.dumps(json.loads(text), indent=2) + '\n', encoding='utf-8')
        return text, code
    def test(self, stage, label, only, base):
        bundle = self.output / f'{label}.xcresult'
        self.status(stage, 'FAILED' if stage == 'SCREENSHOTS' else 'FAIL', 'Test started; not yet successful')
        _, code = self.run(label, base + ['test-without-building', f'-only-testing:{only}', '-resultBundlePath', str(bundle)], required=False)
        summary_ok = False
        summary_reason = 'Result bundle/summary is missing'
        if bundle.exists():
            try:
                self.run(label + '-summary', ['xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', str(bundle)], json_file=label + '-summary.json')
                assert_tests_executed(self.output / (label + '-summary.json'))
                summary_ok = True
            except (RuntimeError, ValueError, OSError) as error:
                summary_reason = str(error)
                print(f'{label} summary validation failed: {error}', flush=True)
                self.report['results'][stage]['reason'] = summary_reason; self.save()
        ok = code == 0 and summary_ok
        if stage != 'SCREENSHOTS': self.status(stage, 'PASS' if ok else 'FAIL', 'Executed XCTest suite passed' if ok else f'Test exit {code}; {summary_reason if not summary_ok else "summary passed but command failed"}; see {label}.log and summary')
        return ok, bundle
    def execute(self):
        if platform.system() != 'Darwin': raise RuntimeError('A Mac with Xcode 27 and iOS 27+ is required. No Apple stages ran.')
        self.run('macos-version', ['sw_vers'])
        xcode, _ = self.run('xcode-version', ['xcodebuild', '-version'])
        self.run('swift-version', ['swift', '--version'])
        sdk, _ = self.run('sdk-version', ['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'])
        self.run('simulator-list', ['xcrun', 'simctl', 'list'])
        inventory, _ = self.run('simulator-inventory', ['xcrun', 'simctl', 'list', '--json'], json_file='simulator-inventory.json')
        if not re.search(r'Xcode 27(?:\.|\s)', xcode) or int(sdk.strip().split('.')[0]) < 27: raise RuntimeError('Xcode 27 and iOS SDK 27+ are required. Inspect developer directory/version logs.')
        device = select_simulator(json.loads(inventory))
        self.report.update(simulator=device, xcode=xcode.strip(), sdk=sdk.strip()); self.save()
        self.run('resolve-core', ['swift', 'package', 'resolve'])
        self.run('resolve-app', ['xcodebuild', '-resolvePackageDependencies', '-project', 'ASCEND.xcodeproj', '-scheme', 'ASCEND'])
        if device.get('state') != 'Booted': self.run('simulator-boot', ['xcrun', 'simctl', 'boot', device['udid']])
        self.run('simulator-boot-status', ['xcrun', 'simctl', 'bootstatus', device['udid'], '-b'])
        self.run('simulator-status-bar', ['xcrun', 'simctl', 'status_bar', device['udid'], 'override', '--time', '09:41', '--batteryState', 'charged', '--batteryLevel', '100'], required=False)
        base = ['xcodebuild', '-project', 'ASCEND.xcodeproj', '-scheme', 'ASCEND', '-configuration', 'Debug', '-sdk', 'iphonesimulator', '-destination', f"platform=iOS Simulator,id={device['udid']}", '-destination-timeout', '180', '-derivedDataPath', str(self.output / 'DerivedData'), '-parallel-testing-enabled', 'NO', 'CODE_SIGNING_ALLOWED=NO', 'SWIFT_TREAT_WARNINGS_AS_ERRORS=YES', 'GCC_TREAT_WARNINGS_AS_ERRORS=YES', 'SWIFT_STRICT_CONCURRENCY=complete']
        self.status('IOS COMPILE', 'FAIL', 'App and test compilation started; not yet successful')
        try:
            self.run('build-app', base + ['build'])
            demo = base.copy(); demo[demo.index('-scheme') + 1] = 'ASCEND Demo'
            self.run('build-demo', demo + ['build'])
            release = base.copy(); release[release.index('-configuration') + 1] = 'Release'
            self.run('build-release', release + ['build'])
            self.run('build-tests', base + ['build-for-testing'])
        except (RuntimeError, OSError) as error:
            self.status('IOS COMPILE', 'FAIL', str(error)); raise
        self.status('IOS COMPILE', 'PASS', 'Debug/Release app, Demo scheme, unit target and UI target compiled against the real Apple SDK')
        # Archive the installed CLI contract. A changed result/export schema fails visibly.
        self.run('xcresult-summary-help', ['xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--help'])
        self.run('xcresult-attachments-help', ['xcrun', 'xcresulttool', 'export', 'attachments', '--help'])
        unit_ok, _ = self.test('UNIT TESTS', 'unit', 'ASCENDTests', base)
        smoke_ok, _ = self.test('UI SMOKE', 'smoke', 'ASCENDUITests/AscendSmokeTests', base + ['-only-testing:ASCENDUITests/PersonalTrainingSmokeTests', '-only-testing:ASCENDUITests/PersonalBrainSmokeTests', '-only-testing:ASCENDUITests/OwnerSystemSmokeTests'])
        screenshot_ok, bundle = self.test('SCREENSHOTS', 'visual', 'ASCENDUITests/AscendScreenshotTests', base)
        try:
            export = self.output / 'attachments'
            self.run('export-attachments', ['xcrun', 'xcresulttool', 'export', 'attachments', '--path', str(bundle), '--output-path', str(export)])
            images = export_named_screenshots(export, self.output / 'screenshots')
            provenance = {key: self.report[key] for key in ('commit', 'xcode', 'sdk', 'simulator')}
            provenance.update(images=images, testSuitePassed=screenshot_ok, demoClock='2026-10-06T12:00:00Z', origin='Real XCUIApplication.screenshot() attachments from ASCEND Demo')
            (self.output / 'screenshots/provenance.json').write_text(json.dumps(provenance, indent=2) + '\n', encoding='utf-8')
            self.status('SCREENSHOTS', 'GENERATED' if screenshot_ok else 'FAILED', 'Twenty-two real simulator PNGs exported' if screenshot_ok else 'Images exported but screenshot test failed')
        except (RuntimeError, ValueError, OSError) as error:
            self.status('SCREENSHOTS', 'FAILED', str(error)); screenshot_ok = False
        return unit_ok and smoke_ok and screenshot_ok

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'work/verification/ios')
    args = parser.parse_args()
    try: verification = Verification(args.output.resolve())
    except (OSError, RuntimeError) as error:
        print(error, file=sys.stderr); return 2
    try: return 0 if verification.execute() else 1
    except (RuntimeError, ValueError, OSError) as error:
        verification.report['infrastructureError'] = str(error); verification.save()
        for stage, result in verification.report['results'].items():
            if result['status'] == 'NOT RUN': result['reason'] = 'Stage did not start: ' + str(error)
        verification.save()
        print(f'Verification could not complete: {error}', file=sys.stderr); return 1
    finally:
        for stage, result in verification.report['results'].items(): print(f"{stage}: {result['status']} - {result['reason']}")

if __name__ == '__main__': sys.exit(main())
