const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const parser = require('luaparse');
const {normalize} = require('./glua.cjs');
const root = path.resolve(__dirname, '..');
const entries = [];
function walk(dir) {
  for (const entry of fs.readdirSync(dir, {withFileTypes:true})) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(file);
    else if (entry.name.endsWith('.lua')) {
      const source = fs.readFileSync(file, 'utf8');
      let syntax = 'pass';
      try { parser.parse(normalize(source), {luaVersion:'5.2'}); }
      catch (error) { syntax = error.message; }
      entries.push({path:path.relative(root, file).replaceAll('\\','/'), lines:source.split('\n').length,
        sha256:crypto.createHash('sha256').update(source).digest('hex'), syntax,
        networkHandlers:[...source.matchAll(/(?:net\.Receive|netstream\.Hook)\s*\(\s*["']([^"']+)/g)].map(m=>m[1]),
        hooks:[...source.matchAll(/function\s+PLUGIN:([\w]+)/g)].map(m=>m[1])});
    }
  }
}
walk(path.join(root,'helix')); walk(path.join(root,'ixhl2rp'));
if (fs.existsSync(path.join(root,'addons'))) walk(path.join(root,'addons'));
const report = {note:'Automated inventory and normalized syntax scan; not a full semantic review or engine test.',
  files:entries.length, lines:entries.reduce((n,e)=>n+e.lines,0),
  syntaxFailures:entries.filter(e=>e.syntax!=='pass'), entries};
fs.mkdirSync(path.join(root,'docs'),{recursive:true});
fs.writeFileSync(path.join(root,'docs/source-audit.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({files:report.files,lines:report.lines,syntaxFailures:report.syntaxFailures.map(e=>({path:e.path,error:e.syntax}))},null,2));
