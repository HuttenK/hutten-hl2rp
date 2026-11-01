// Independent offline verification. No game, deployment, database files or old audit artifacts are opened.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');
const parser = require('luaparse');
const {normalize} = require('./glua.cjs');

const root = path.resolve(__dirname, '..');
const out = path.join(root, 'docs/performance-audit');
const baselineDir = 'C:/Users/q1236/AppData/Local/Temp/ix-measured-client-before-20261018T015619Z-efe2ca49';
const runtimeRoots = ['helix', 'ixhl2rp', 'addons'];
const allRoots = [...runtimeRoots, 'base', 'sandbox', 'terrortown'];
const modules = ['blackout-lighting', 'blackout-areas', 'blackout-electronics',
  'measured-huds', 'faction-recognition', 'admin-permissions', 'measured-adjacent',
  'core-item-id-query', 'core-inventory-previews', 'core-contracts'];
const readJSON = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const writeJSON = (file, value) => fs.writeFileSync(path.join(out, file), JSON.stringify(value, null, 2) + '\n');
function files(roots) {
  const list = [];
  function walk(dir) {
    for (const ent of fs.readdirSync(dir, {withFileTypes: true})) {
      const file = path.join(dir, ent.name);
      if (ent.isDirectory()) walk(file);
      else if (ent.name.endsWith('.lua')) list.push(path.relative(root, file).replaceAll('\\', '/'));
    }
  }
  for (const entry of roots) walk(path.join(root, entry));
  return list.sort();
}
function hashes() {
  return Object.fromEntries(files(runtimeRoots).map(relative => [relative,
    crypto.createHash('sha256').update(fs.readFileSync(path.join(root, relative))).digest('hex')]));
}
function equal(a, b) {
  const keys = Object.keys(a).sort();
  return JSON.stringify(keys) === JSON.stringify(Object.keys(b).sort()) && keys.every(key => a[key] === b[key]);
}
const startedUTC = new Date().toISOString();
const runtimeHashesBefore = hashes();
const baseline = Object.fromEntries(readJSON(path.join(baselineDir, 'manifest.json')).files.map(x => [x.path, x.sha256]));
const frozen = readJSON(path.join(out, 'measured-client-freeze.json')).runtimeChanges;
const scopeComparison = {
  baseline: baselineDir,
  changed: Object.keys(runtimeHashesBefore).filter(p => p in baseline && baseline[p] !== runtimeHashesBefore[p]),
  added: Object.keys(runtimeHashesBefore).filter(p => !(p in baseline)),
  removed: Object.keys(baseline).filter(p => !(p in runtimeHashesBefore)),
};
scopeComparison.addonsChanged = [...scopeComparison.changed, ...scopeComparison.added, ...scopeComparison.removed].filter(p => p.startsWith('addons/'));
const changed = Object.fromEntries(scopeComparison.changed.map(p => [p, runtimeHashesBefore[p]]));
if (!equal(frozen, changed) || scopeComparison.added.length || scopeComparison.removed.length || scopeComparison.addonsChanged.length) {
  throw new Error('Frozen runtime scope does not match current files; verification not started.');
}
const exclusions = require('./test-measured-adjacent.cjs').excluded;
const broadLog = fs.readFileSync(path.join(out, 'measured-client-expanded-regression-attempt.log'), 'utf8');
const baselineLog = fs.readFileSync(path.join(out, 'measured-client-preexisting-regressions.log'), 'utf8');
const broadReport = readJSON(path.join(out, 'measured-client-expanded-verification-attempt.json'));
const failureNames = log => [...log.matchAll(/^FAIL (.*?): \[string/gm)].map(match => match[1]).sort();
if (JSON.stringify(failureNames(broadLog)) !== JSON.stringify([...exclusions].sort()) ||
    JSON.stringify(failureNames(baselineLog)) !== JSON.stringify([...exclusions].sort()) ||
    !equal(broadReport.runtimeHashesBefore, runtimeHashesBefore) ||
    !equal(broadReport.runtimeHashesAfter, runtimeHashesBefore)) {
  throw new Error('Pre-existing failure evidence does not match the exact current runtime and four exclusions.');
}
const command = ['tools/run-performance-tests.cjs', ...modules];
const testsProcess = spawnSync(process.execPath, command, {cwd: root, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024});
const testLog = (testsProcess.stdout || '') + (testsProcess.stderr || '');
fs.writeFileSync(path.join(out, 'measured-client-regression-tests.log'),
  `Command: node ${command.join(' ')}\nStarted: ${startedUTC}\n${testLog}\nProcess exit code: ${testsProcess.status}\n`);
const matches = [...testLog.matchAll(/(\d+) passed; (\d+) failed; (\d+) standalone modules completed\./g)];
if (matches.length !== 1) throw new Error('Regression summary missing or ambiguous; inspect regression log.');
const [, passCount, failCount, standaloneCount] = matches[0];
const entries = files(allRoots).map(relative => {
  let error = null;
  try { parser.parse(normalize(fs.readFileSync(path.join(root, relative), 'utf8')), {luaVersion: '5.2'}); }
  catch (exception) { error = exception.message; }
  return {path: relative, error};
});
const runtimeSet = new Set(Object.keys(runtimeHashesBefore));
const syntaxFailures = entries.filter(entry => entry.error);
const runtimeSyntaxFailures = syntaxFailures.filter(entry => runtimeSet.has(entry.path));
const syntaxSummary = {startedUTC, completedUTC: new Date().toISOString(), parser: 'luaparse 0.3.1, existing GLua normalization, Lua 5.2',
  runtimeFiles: runtimeSet.size, fullInventoryFiles: entries.length, runtimeSyntaxFailures, fullInventorySyntaxFailures: syntaxFailures};
writeJSON('measured-client-syntax.json', syntaxSummary);
const runtimeHashesAfter = hashes();
const sourceChangedDuringRun = !equal(runtimeHashesBefore, runtimeHashesAfter);
const totalPassLines = [...testLog.matchAll(/^PASS /gm)].length;
const tests = {focusedPassed: Number(passCount), focusedFailed: Number(failCount), standaloneModules: Number(standaloneCount),
  totalPassLines, standalonePassed: totalPassLines - Number(passCount), syntaxFiles: runtimeSet.size,
  syntaxParsed: runtimeSet.size - runtimeSyntaxFailures.length, syntaxFailures: runtimeSyntaxFailures.length,
  fullInventoryFiles: entries.length, fullInventorySyntaxFailures: syntaxFailures.length};
const okay = testsProcess.status === 0 && tests.focusedFailed === 0 && syntaxFailures.length === 0 && !sourceChangedDuringRun;
const report = {generatedUTC: new Date().toISOString(), startedUTC, exitCode: okay ? 0 : 1,
  sourceChangedDuringRun, modules, tests, processExitCodes: {regression: testsProcess.status, syntax: syntaxFailures.length ? 1 : 0},
  runtimeHashes: runtimeHashesAfter, runtimeHashesBefore, runtimeHashesAfter, scopeComparison,
  runtimeChanges: changed, syntaxFailures,
  releaseGate: 'Scoped regression checks pass; expanded run has exactly four identical pre-existing failures reproduced against the untouched baseline. This is not a full broad-suite pass.',
  preExistingFailures: {
    count: exclusions.length, names: exclusions,
    currentExpandedOutcome: {focusedPassed: broadReport.tests.focusedPassed, focusedFailed: broadReport.tests.focusedFailed,
      totalPassLines: broadReport.tests.totalPassLines},
    baselineComparisonOutcome: {focusedPassed: 20, focusedFailed: 4, identicalFailureNames: true,
      failureMessages: 'Manually checked against retained current/baseline logs; the same assertions and generated-Lua error locations recur.'},
    currentLog: 'docs/performance-audit/measured-client-expanded-regression-attempt.log',
    currentReport: 'docs/performance-audit/measured-client-expanded-verification-attempt.json',
    baselineLog: 'docs/performance-audit/measured-client-preexisting-regressions.log',
    reasons: ['The server-only light-restoration assertion fails identically before this pass. Its underlying runtime-versus-fixture cause is not resolved by these client changes.',
      'The other powerbox fixture omits ix.area, which the unchanged server path now requires.',
      'Two unrelated infection fixtures extract an obsolete JavaScript template boundary, leaving an unsupported backtick in their generated Lua.'],
    retainedCoverage: 'All other powerbox/foundation cases, including every client render and status authorization case, remain in the final run; no existing fixture or unrelated runtime was changed.'
  },
  validationLimits: [
    'Production Lua runs in Fengari with mocked GMod callbacks/rendering. Tests do not establish live GPU output, frame time, Linux tick rate or network latency.',
    'Syntax parsing uses the existing GLua normalizer; its continue-to-break replacement checks syntax only and is not a game execution test.',
    'Any native SQLite checks create fresh in-memory databases. No game or server database was opened.',
    'In-game checks remain required for target compositing/alpha, UI scale and resolution changes, MTF-only status visibility, injury updates and blackout material/power transitions.'
  ]};
writeJSON('measured-client-verification.json', report);
console.log(JSON.stringify({exitCode: report.exitCode, tests, sourceChangedDuringRun, scopeComparison, runtimeChanges: changed}, null, 2));
process.exitCode = report.exitCode;
