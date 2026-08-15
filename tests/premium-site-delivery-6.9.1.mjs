import fs from 'node:fs';
import assert from 'node:assert/strict';
const read=p=>fs.readFileSync(p,'utf8');
const app=read('assets/app.js');
const css=read('assets/styles.css');
const pkg=JSON.parse(read('package.json'));

assert.equal(pkg.version,'6.9.0','premium point 7 must stay on the 6.9 production line');
assert.equal(app,read('public/assets/app.js'),'app mirror drift');
for(const peer of ['public/assets/styles.css','app/globals.css','platform-console/assets/styles.css']) assert.equal(css,read(peer),`style mirror drift: ${peer}`);

for(const needle of [
  'deliveryReadiness','claimNextAction','delivery-signal-grid','site-delivery-workspace','site-claim-next-card',
  'claim-site-package-hero','claim-scope-summary','claim-missing-panel','claim-primary-action-bar','claim-evidence-section','claim-evidence-list',
  'مستخلص موقع واحد','تجميع المستندات فقط','تجهيز حزمة المستخلص','INDEX.html','MANIFEST.json'
]) assert.ok(app.includes(needle),`premium Site Delivery client contract missing: ${needle}`);

for(const needle of [
  'add-claim-requirement','edit-claim-requirement','auto-collect-claim','freeze-claim','reopen-claim','submit-claim',
  'remove-claim-item','open-claim-package','open-site-files','new-cabinet','open-cabinet',
  "api.rpc('site_claim_package_360'","api.rpc('site_360'"
]) assert.ok(app.includes(needle),`existing Site Delivery action/contract lost: ${needle}`);

for(const cls of [
  '.delivery-readiness','.delivery-signal-grid','.delivery-unit-card','.site-claim-next-card',
  '.claim-site-package-hero','.claim-scope-summary','.claim-missing-panel','.claim-primary-action-bar',
  '.claim-evidence-list','.claim-requirement-title','.claim-export-history'
]) assert.ok(css.includes(cls),`premium Site Delivery style missing: ${cls}`);

assert.match(css,/\.delivery-signal-grid\{display:grid;grid-template-columns:repeat\(4/,'desktop delivery signals must use a compact decision grid');
assert.match(css,/@media\(max-width:480px\)[\s\S]*?\.delivery-signal-grid\{grid-template-columns:1fr 1fr/,'mobile delivery signals must compact to two columns');
assert.match(css,/\.claim-scope-summary\{[^}]*display:grid/,'claim scope must use a clear compact grid');
assert.match(css,/\.claim-primary-action-bar\{[^}]*display:flex/,'claim preparation must stay prominent and actionable');

// Product truth: evidence remains canonical in CDE, and freeze/submit lifecycle semantics stay explicit.
for(const truth of ['بدون نسخ الملفات','without copying files','يثبت Versions الحالية','pins current versions','لا أسعار','No pricing']) assert.ok(app.includes(truth),`delivery truth copy missing: ${truth}`);

console.log('Premium Site Delivery + Claim Intelligence 6.9.1 checks passed.');
