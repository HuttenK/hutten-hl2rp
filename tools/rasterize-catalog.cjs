const fs=require('fs'),path=require('path');
const sharp=require('C:/Users/q1236/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'..'),dir=path.join(root,'docs/catalog-preview');
(async()=>{
 for(const file of fs.readdirSync(dir).filter(x=>x.endsWith('.svg'))){
  const svg=fs.readFileSync(path.join(dir,file),'utf8').replace(/href="(\.\.\/\.\.\/addons\/[^\"]+)"/g,(_,name)=>`href="data:image/png;base64,${fs.readFileSync(path.resolve(dir,name)).toString('base64')}"`);
  await sharp(Buffer.from(svg)).png().toFile(path.join(dir,file.replace('.svg','.png')));
 }
 const html=path.join(root,'docs/catalog-preview.html');fs.writeFileSync(html,fs.readFileSync(html,'utf8').replaceAll('.svg','.png'));
 console.log('Rasterized production Lua previews with packaged artwork.');
})().catch(e=>{console.error(e);process.exitCode=1});
