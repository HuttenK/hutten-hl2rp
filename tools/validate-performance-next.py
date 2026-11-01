"""Run the combined performance regression and full-source syntax inventories."""
import datetime
import importlib.util
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/performance-audit'
spec = importlib.util.spec_from_file_location('deployment', ROOT / 'tools/deploy-performance-next.py')
deployment = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deployment)
MODULES = '''performance-overall performance-batch1 voice facility electrical-hardware world-persistence
blackout-areas blackout-electronics blackout-lighting area-outline area-volume-consumers map3d-native
terminal-map-controls weapon-display holsters bodycams medicine zones water-action-animations
contextual-equipment-use broadcast performance-services-next performance-server-review
performance-client-review render-budget arc9-helperbones arc9-sd-pose arc9-view-ownership
body-drag-render weapon-slots performance-network cctv foundation-network record-store'''.split()

def run(command, name):
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output = result.stdout.decode('utf-8', errors='replace')
    (OUT / name).write_text('Command: ' + ' '.join(command) + '\n' + output +
                            '\nProcess exit code: ' + str(result.returncode) + '\n', encoding='utf-8')
    print(name + ': exit ' + str(result.returncode), flush=True)
    return result.returncode, output

def main():
    before = deployment.runtime_hashes()
    modules = MODULES[:]
    for path in sorted((ROOT / 'tools').glob('test-*network*review*.cjs')):
        name = path.stem.removeprefix('test-')
        if name not in modules:
            modules.append(name)
    tests_code, output = run(['node', 'tools/run-performance-tests.cjs', *modules], 'next-regression-tests.log')
    matches = re.findall(r'(\d+) passed; (\d+) failed; (\d+) standalone modules completed\.', output)
    if len(matches) != 1:
        raise RuntimeError('Combined test summary not found or ambiguous')
    passed, failed, standalone = map(int, matches[0])
    syntax_code, _ = run(['node', 'tools/audit.cjs'], 'next-syntax.log')
    inventory_code, _ = run(['node', 'tools/performance-inventory.cjs', 'docs/performance-audit/next'], 'next-inventory.log')
    syntax = json.loads((ROOT / 'docs/source-audit.json').read_text(encoding='utf-8'))
    inventory = json.loads((OUT / 'next/inventory.json').read_text(encoding='utf-8'))
    after = deployment.runtime_hashes()
    counts = dict(focusedPassed=passed, focusedFailed=failed, standaloneModules=standalone,
                  syntaxFiles=syntax['files'], syntaxFailures=len(syntax['syntaxFailures']),
                  fullInventoryFiles=inventory['files'],
                  fullInventorySyntaxFailures=sum(entry['syntax'] != 'pass' for entry in inventory['entries']))
    okay = not (tests_code or syntax_code or inventory_code or failed or counts['syntaxFailures'] or
                counts['fullInventorySyntaxFailures'] or before != after)
    result = dict(generatedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(), exitCode=0 if okay else 1,
                  sourceChangedDuringRun=before != after, modules=modules, tests=counts,
                  processExitCodes=dict(regression=tests_code, syntax=syntax_code, inventory=inventory_code),
                  runtimeHashes=after)
    (OUT / 'next-verification.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: value for key, value in result.items() if key != 'runtimeHashes'}, indent=2))
    raise SystemExit(result['exitCode'])

if __name__ == '__main__':
    main()
