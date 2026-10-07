"""Infrastructure fixtures only. These tests do not compile Swift or render an iOS screen."""
from pathlib import Path
import contextlib, io, json, struct, sys, tempfile, unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from verify_ios import SCREENSHOTS, Verification, assert_tests_executed, export_named_screenshots, select_simulator
from report_verification import collect

def temporary_directory():
    base = (ROOT / 'work/infrastructure-fixtures').resolve()
    assert base.is_relative_to(ROOT.resolve())
    base.mkdir(parents=True, exist_ok=True)
    temp = tempfile.TemporaryDirectory(dir=base)
    assert Path(temp.name).resolve().is_relative_to(base)
    return temp

def inventory():
    return {'runtimes': [
        {'identifier': 'ios27', 'name': 'iOS 27.0', 'version': '27.0', 'isAvailable': True},
        {'identifier': 'ios26', 'name': 'iOS 26.0', 'version': '26.0', 'isAvailable': True},
        {'identifier': 'missing', 'name': 'iOS 27.1', 'version': '27.1', 'isAvailable': False}],
        'devices': {'ios27': [
            {'name': 'iPhone 18', 'udid': 'normal', 'isAvailable': True},
            {'name': 'iPhone 18 Pro Max', 'udid': 'largest', 'isAvailable': True},
            {'name': 'iPhone 19 Pro Max', 'udid': 'unavailable', 'isAvailable': False},
            {'name': 'iPad Pro', 'udid': 'tablet', 'isAvailable': True}],
            'ios26': [{'name': 'iPhone 99 Pro Max', 'udid': 'old-runtime', 'isAvailable': True}],
            'missing': [{'name': 'iPhone 99 Pro Max', 'udid': 'missing-runtime', 'isAvailable': True}]}}

def attachments(root):
    root.mkdir(parents=True, exist_ok=True)
    items = []
    for index, name in enumerate(SCREENSHOTS):
        # A header fixture for testing the export parser, never a rendered app image.
        path = root / f'fixture-{index}.png'
        path.write_bytes(b'\x89PNG\r\n\x1a\n' + struct.pack('>I', 13) + b'IHDR' + struct.pack('>II', 1320, 2868) + b'\0' * 10)
        items.append({'suggestedHumanReadableName': name + '_1.png', 'exportedFileName': path.name})
    (root / 'manifest.json').write_text(json.dumps([{'attachments': items}]), encoding='utf-8')
    return items

class SelectionTests(unittest.TestCase):
    def test_prefers_largest_current_available_iphone(self):
        self.assertEqual(select_simulator(inventory())['udid'], 'largest')
    def test_fails_without_compatible_runtime(self):
        data = inventory(); data['devices']['ios27'] = []
        with self.assertRaises(RuntimeError): select_simulator(data)
    def test_device_type_identifier_wins_over_renamed_device(self):
        data = inventory()
        data['devices']['ios27'][0]['deviceTypeIdentifier'] = 'com.apple.CoreSimulator.SimDeviceType.iPhone-20-Pro-Max'
        self.assertEqual(select_simulator(data)['udid'], 'normal')

class ExportTests(unittest.TestCase):
    def test_all_five_names_are_preserved(self):
        with temporary_directory() as temp:
            root = Path(temp); attachments(root / 'export')
            result = export_named_screenshots(root / 'export', root / 'named')
            self.assertEqual([x['name'] for x in result], list(SCREENSHOTS))
            self.assertEqual(list(SCREENSHOTS[:5]), ['01_dashboard', '02_workout', '03_recovery', '04_progress', '05_profile'])
            self.assertEqual(len(list((root / 'named').glob('*.png'))), 8)
    def test_missing_attachment_fails_before_copying(self):
        with temporary_directory() as temp:
            root = Path(temp); items = attachments(root / 'export')
            (root / 'export/manifest.json').write_text(json.dumps([{'attachments': items[:-1]}]))
            with self.assertRaises(ValueError): export_named_screenshots(root / 'export', root / 'named')
            self.assertFalse((root / 'named').exists())
    def test_path_escape_is_rejected(self):
        with temporary_directory() as temp:
            root = Path(temp); items = attachments(root / 'export')
            items[0]['exportedFileName'] = '../outside.png'
            (root / 'export/manifest.json').write_text(json.dumps([{'attachments': items}]))
            with self.assertRaises(ValueError): export_named_screenshots(root / 'export', root / 'named')
    def test_corrupt_png_is_rejected(self):
        with temporary_directory() as temp:
            root = Path(temp); attachments(root / 'export')
            (root / 'export/fixture-0.png').write_text('this is not a screenshot')
            with self.assertRaises(ValueError): export_named_screenshots(root / 'export', root / 'named')
    def test_duplicate_attachment_is_rejected(self):
        with temporary_directory() as temp:
            root = Path(temp); items = attachments(root / 'export')
            items.append(dict(items[0], exportedFileName='another.png'))
            (root / 'export/manifest.json').write_text(json.dumps([{'attachments': items}]))
            with self.assertRaises(ValueError): export_named_screenshots(root / 'export', root / 'named')

class ResultTests(unittest.TestCase):
    def test_empty_run_cannot_pass(self):
        with temporary_directory() as temp:
            path = Path(temp) / 'summary.json'
            path.write_text(json.dumps({'result': 'Passed', 'passedTests': 0, 'failedTests': 0}))
            with self.assertRaises(ValueError): assert_tests_executed(path)
    def test_summary_with_failures_cannot_pass(self):
        with temporary_directory() as temp:
            path = Path(temp) / 'summary.json'
            path.write_text(json.dumps({'result': 'Failed', 'passedTests': 2, 'failedTests': 1}))
            with self.assertRaises(ValueError): assert_tests_executed(path)
    def test_xcode_27_summary_schema_passes(self):
        with temporary_directory() as temp:
            path = Path(temp) / 'summary.json'
            path.write_text(json.dumps({'result': 'Passed', 'passedTests': 44, 'failedTests': 0, 'totalTestCount': 44}))
            self.assertEqual(assert_tests_executed(path)['passedTests'], 44)
    def test_legacy_summary_schema_remains_supported(self):
        with temporary_directory() as temp:
            path = Path(temp) / 'summary.json'
            path.write_text(json.dumps({'testResult': 'Passed', 'passedTests': 1, 'failedTests': 0}))
            self.assertEqual(assert_tests_executed(path)['passedTests'], 1)
    def test_report_keeps_missing_stages_not_run(self):
        with temporary_directory() as temp:
            path = Path(temp) / 'status.json'
            path.write_text(json.dumps({'results': {'CORE WINDOWS': {'status': 'FAIL', 'reason': 'fixture'}}}))
            result = collect(temp)
            self.assertEqual(result['CORE WINDOWS']['status'], 'FAIL')
            self.assertEqual(result['IOS COMPILE']['status'], 'NOT RUN')
            self.assertEqual(result['FOUNDATION MODELS INFERENCE']['status'], 'NOT TESTED')
    def test_duplicate_platform_evidence_fails(self):
        with temporary_directory() as temp:
            root = Path(temp)
            for name in ('one', 'two'):
                (root / name).mkdir()
                (root / name / 'status.json').write_text(json.dumps({'results': {'IOS COMPILE': {'status': 'PASS'}}}))
            with self.assertRaises(ValueError): collect(root)
    def test_reusing_output_cannot_reuse_stale_results(self):
        with temporary_directory() as temp:
            Verification(temp)
            with self.assertRaises(RuntimeError): Verification(temp)
    def test_windows_never_invokes_apple_commands(self):
        with temporary_directory() as temp, patch('verify_ios.platform.system', return_value='Windows'):
            verification = Verification(temp)
            with self.assertRaises(RuntimeError): verification.execute()
            self.assertEqual(verification.report['commands'], [])
            self.assertEqual(verification.report['results']['IOS COMPILE']['status'], 'NOT RUN')

class FixtureVerification(Verification):
    """Command-response fixtures solely for infrastructure error-propagation testing."""
    def __init__(self, output, failing=None):
        super().__init__(output)
        self.failing = failing
        self.invocations = []
    def run(self, label, command, json_file=None, required=True):
        self.invocations.append(label)
        if label == self.failing:
            if required: raise RuntimeError(f'fixture failure: {label}')
            return '', 65
        text = 'fixture'
        if label == 'xcode-version': text = 'Xcode 27.0\nBuild version fixture\n'
        if label == 'sdk-version': text = '27.0\n'
        if label == 'simulator-inventory': text = json.dumps(inventory())
        if '-resultBundlePath' in command: Path(command[command.index('-resultBundlePath') + 1]).mkdir()
        if json_file:
            data = json.loads(text) if label == 'simulator-inventory' else {'result': 'Passed', 'passedTests': 1, 'failedTests': 0}
            (self.output / json_file).write_text(json.dumps(data))
        if label == 'export-attachments': attachments(self.output / 'attachments')
        return text, 0

class PropagationTests(unittest.TestCase):
    def test_compile_failure_leaves_tests_not_run(self):
        with temporary_directory() as temp, patch('verify_ios.platform.system', return_value='Darwin'), contextlib.redirect_stdout(io.StringIO()):
            verification = FixtureVerification(temp, 'build-app')
            with self.assertRaises(RuntimeError): verification.execute()
            self.assertEqual(verification.report['results']['IOS COMPILE']['status'], 'FAIL')
            self.assertEqual(verification.report['results']['UNIT TESTS']['status'], 'NOT RUN')
    def test_unit_failure_does_not_prevent_ui_and_screenshot_stages(self):
        with temporary_directory() as temp, patch('verify_ios.platform.system', return_value='Darwin'), contextlib.redirect_stdout(io.StringIO()):
            verification = FixtureVerification(temp, 'unit')
            self.assertFalse(verification.execute())
            self.assertEqual(verification.report['results']['UNIT TESTS']['status'], 'FAIL')
            self.assertIn('smoke', verification.invocations)
            self.assertIn('visual', verification.invocations)
    def test_export_failure_is_distinct_from_smoke_success(self):
        with temporary_directory() as temp, patch('verify_ios.platform.system', return_value='Darwin'), contextlib.redirect_stdout(io.StringIO()):
            verification = FixtureVerification(temp, 'export-attachments')
            self.assertFalse(verification.execute())
            self.assertEqual(verification.report['results']['UI SMOKE']['status'], 'PASS')
            self.assertEqual(verification.report['results']['SCREENSHOTS']['status'], 'FAILED')

if __name__ == '__main__': unittest.main()
