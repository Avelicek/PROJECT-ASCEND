"""PowerShell orchestration fixtures. No Swift installation, compilation or XCTest execution."""
from pathlib import Path
import json, os, subprocess, tempfile, unittest

ROOT = Path(__file__).resolve().parents[2]

@unittest.skipUnless(os.name == 'nt', 'Native PowerShell orchestration checks require Windows')
class WindowsRunnerTests(unittest.TestCase):
    def exercise(self, fail_stage=None, invalid_xml=False, missing=False, omit_xml=False, stale_xml=False):
        base = (ROOT / 'work/infrastructure-fixtures').resolve()
        assert base.is_relative_to(ROOT.resolve())
        base.mkdir(parents=True, exist_ok=True)
        temp = tempfile.TemporaryDirectory(dir=base)
        assert Path(temp.name).resolve().is_relative_to(base)
        with temp:
            folder = Path(temp.name)
            fixture = folder / 'swift-fixture.cmd'
            xml = '<testsuites><testsuite><testcase name="infrastructure-fixture" /></testsuite></testsuites>'
            if invalid_xml: xml = invalid_xml if isinstance(invalid_xml, str) else '<testsuites />'
            escaped = xml.replace('<', '^<').replace('>', '^>')
            fixture.write_text('@echo off\n'
                'if "%ASCEND_INFRA_FAIL_STAGE%"=="%~1" exit /b 7\n' +
                (f'if "%~1"=="test" echo {escaped}>"%~8"\n' if not omit_xml else '') +
                'echo Infrastructure command fixture. This is NOT Swift.\nexit /b 0\n', encoding='ascii')
            if stale_xml:
                (folder / 'results').mkdir()
                (folder / 'results/core-tests.xml').write_text('<testsuites><testsuite><testcase name="stale" /></testsuite></testsuites>')
            # verify-windows.ps1 requires an existing SDKROOT before invoking SwiftPM.
            # The orchestration fixture is intentionally not a real Swift toolchain, so point
            # SDKROOT at the temporary fixture directory to exercise control flow only.
            env = dict(os.environ, ASCEND_INFRA_FAIL_STAGE=fail_stage or '', SDKROOT=str(folder))
            command = ['powershell.exe', '-NoProfile', '-File', str(ROOT / 'tools/verify-windows.ps1'),
                       '-OutputDirectory', str(folder / 'results'), '-SwiftExecutable', str(fixture) if not missing else 'ascend-missing-swift-fixture']
            result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=30)
            report = json.loads((folder / 'results/status.json').read_text(encoding='utf-8-sig'))
            return result.returncode, report['results']['CORE WINDOWS']['status'], result.stdout + result.stderr
    def test_missing_tool_is_not_run_with_nonzero_exit(self):
        code, status, _ = self.exercise(missing=True)
        self.assertEqual((code, status), (2, 'NOT RUN'))
    def test_version_failure_is_failure(self):
        code, status, _ = self.exercise(fail_stage='--version')
        self.assertEqual((code, status), (1, 'FAIL'))
    def test_resolve_failure_is_failure(self):
        code, status, _ = self.exercise(fail_stage='package')
        self.assertEqual((code, status), (1, 'FAIL'))
    def test_build_failure_is_failure(self):
        code, status, _ = self.exercise(fail_stage='build')
        self.assertEqual((code, status), (1, 'FAIL'))
    def test_test_failure_is_failure(self):
        code, status, _ = self.exercise(fail_stage='test')
        self.assertEqual((code, status), (1, 'FAIL'))
    def test_empty_xctest_xml_is_failure(self):
        code, status, _ = self.exercise(invalid_xml=True)
        self.assertEqual((code, status), (1, 'FAIL'))
    def test_missing_report_cannot_reuse_previous_success(self):
        code, status, _ = self.exercise(omit_xml=True, stale_xml=True)
        self.assertEqual((code, status), (1, 'FAIL'))
    def test_xml_failure_rejects_successful_command_exit(self):
        code, status, _ = self.exercise(invalid_xml='<testsuites><testsuite><testcase name="failed"><failure /></testcase></testsuite></testsuites>')
        self.assertEqual((code, status), (1, 'FAIL'))
    def test_successful_command_sequence_requires_test_evidence(self):
        code, status, output = self.exercise()
        self.assertEqual((code, status), (0, 'PASS'), output)
        for stage in ('version', 'resolve', 'build', 'test'): self.assertIn(f'=== {stage}', output)
        self.assertIn('--parallel --num-workers 1 --xunit-output', output)

if __name__ == '__main__': unittest.main()
