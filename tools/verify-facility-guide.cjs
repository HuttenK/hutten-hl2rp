const fs=require('fs'),path=require('path'),assert=require('assert/strict');
const {chromium}=require('C:/Users/q1236/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
(async()=>{
 const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true});
 try{
  const page=await browser.newPage({viewport:{width:1440,height:1100},reducedMotion:'reduce'});
  const errors=[];page.on('pageerror',err=>errors.push(String(err)));
  const external=[];page.on('request',r=>{if(/^https?:/.test(r.url()))external.push(r.url())});
  await page.goto('file:///'+path.resolve('docs/Foundation-Facilities-Guide.html').replaceAll('\\','/'));
  assert.equal(await page.locator('img').count(),3);
  assert(await page.locator('img').evaluateAll(images=>images.every(i=>i.complete&&i.naturalWidth>0)));
  assert.match(await page.locator('#demoResult').innerText(),/60 of 80/);
  await page.locator('#demoBat').check();assert.match(await page.locator('#demoResult').innerText(),/80 of 80.*5 min 0 sec/);
  await page.locator('#demoGen').uncheck();assert.match(await page.locator('#demoResult').innerText(),/20 of 80/);
  await page.locator('#demoBat').uncheck();assert.match(await page.locator('#demoResult').innerText(),/0 of 80/);
  await page.locator('#demoGen').check();
  for(const section of ['start','intercom','power','repair','setup']){
   await page.locator('#'+section).evaluate(e=>e.scrollIntoView());
   await page.waitForTimeout(200); // Give Chromium's offscreen tiles a frame to rasterize.
   await page.screenshot({path:'docs/facility-usability-'+section+'.png'});
  }
  await page.locator('#demoResult').evaluate(e=>e.closest('.powerdiagram').scrollIntoView());
  await page.screenshot({path:'docs/facility-usability-simulator.png'});
  assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'Desktop overflow');
  await page.setViewportSize({width:390,height:844});
  await page.locator('#start').evaluate(e=>e.scrollIntoView());
  assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'Mobile overflow');
  await page.screenshot({path:'docs/facility-usability-mobile.png'});
  await page.locator('#help summary').nth(1).click();assert(await page.locator('#help details').nth(1).getAttribute('open')!==null);
  assert.deepEqual(errors,[]);
  assert.deepEqual(external,[]);
  const report={embeddedImages:3,powerScenarios:4,viewports:[1440,390],pageErrors:errors,externalRequests:external,
   sha256:require('crypto').createHash('sha256').update(fs.readFileSync('docs/Foundation-Facilities-Guide.html')).digest('hex')};
  fs.writeFileSync('docs/facility-guide-validation.json',JSON.stringify(report,null,2));console.log(report);
 }finally{await browser.close()}
})().catch(err=>{console.error(err);process.exitCode=1});
