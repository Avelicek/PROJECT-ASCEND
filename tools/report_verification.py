#!/usr/bin/env python3
"""Combine actual platform statuses. Missing evidence is never reported as a pass."""
from pathlib import Path
import argparse, json, os, sys
STAGES = ('CORE WINDOWS', 'IOS COMPILE', 'UNIT TESTS', 'UI SMOKE', 'SCREENSHOTS', 'FOUNDATION MODELS INFERENCE')
ALLOWED = {stage: {'PASS', 'FAIL', 'NOT RUN'} for stage in STAGES}
ALLOWED['SCREENSHOTS'] = {'GENERATED', 'FAILED', 'NOT RUN'}
ALLOWED[STAGES[-1]] = {'PASS', 'FAIL', 'UNAVAILABLE', 'NOT TESTED'}

def collect(root):
    results = {stage: dict(status='NOT TESTED' if stage == STAGES[-1] else 'NOT RUN', reason='No execution evidence received') for stage in STAGES}
    seen = set()
    for path in sorted(Path(root).rglob('status.json')):
        report = json.loads(path.read_text(encoding='utf-8-sig'))
        for stage, value in report.get('results', {}).items():
            if stage not in ALLOWED or value.get('status') not in ALLOWED[stage]: raise ValueError(f'Invalid status in {path}: {stage}')
            if stage in seen: raise ValueError(f'Duplicate evidence for {stage}; use one run only')
            seen.add(stage); results[stage] = value
    return results

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    results = collect(args.root)
    lines = ['# ASCEND Build 01.5 verification', '', '| Verification | Status | Evidence / reason |', '|---|---|---|']
    for stage, result in results.items():
        reason = result.get('reason', '').replace('|', '\\|').replace('\n', ' ').replace('\r', ' ')
        lines.append(f"| {stage} | **{result['status']}** | {reason} |")
    lines += ['', 'Infrastructure/upload failures can fail a job separately. Inspect job logs even when an earlier stage passed.', 'Fallback tests do not demonstrate Foundation Models inference.', '']
    markdown = '\n'.join(lines)
    print(markdown)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(markdown, encoding='utf-8')
        args.output.with_suffix('.json').write_text(json.dumps({'results': results}, indent=2) + '\n', encoding='utf-8')
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as file: file.write(markdown)
    return 0
if __name__ == '__main__': sys.exit(main())
