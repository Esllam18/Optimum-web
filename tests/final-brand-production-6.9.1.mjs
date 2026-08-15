import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const root=process.cwd();
const read=(rel)=>fs.readFileSync(path.join(root,rel),'utf8');
const bytes=(rel)=>fs.readFileSync(path.join(root,rel));

const brandFiles=[
  'assets/brand/optimum-mark.png',
  'assets/brand/optimum-lockup.png',
  'assets/brand/optimum-favicon-64.png',
  'assets/brand/optimum-apple-touch.png',
  'assets/brand/optimum-icon-192.png',
  'assets/brand/optimum-icon-512.png'
];
for(const file of brandFiles){
  assert.ok(fs.existsSync(path.join(root,file)),`missing ${file}`);
  assert.ok(bytes(file).length>1000,`brand asset unexpectedly empty ${file}`);
  const publicFile=`public/${file}`;
  assert.ok(fs.existsSync(path.join(root,publicFile)),`missing ${publicFile}`);
  assert.deepEqual(bytes(file),bytes(publicFile),`brand mirror mismatch ${file}`);
}
assert.deepEqual(bytes('assets/brand/optimum-mark.png'),bytes('platform-console/assets/brand/optimum-mark.png'),'platform brand mark mirror must match');

const app=read('assets/app.js');
const platform=read('assets/platform.js');
const css=read('assets/styles.css');
const manifest=JSON.parse(read('app.webmanifest'));
const config=read('assets/config.js');

assert.ok(app.includes('const productBrandMark'),'client product brand renderer missing');
assert.ok(platform.includes('const productBrandMark'),'platform product brand renderer missing');
assert.ok(app.includes('optimum-mark.png'),'client mark asset missing');
assert.ok(platform.includes('optimum-mark.png'),'platform mark asset missing');
assert.ok(css.includes('Product identity lockup'),'product identity CSS missing');
assert.ok(!app.includes('<span class="brand-mark">O</span>'),'legacy client O mark must be removed');
assert.ok(!platform.includes('<span class="brand-mark">O</span>'),'legacy platform O mark must be removed');
assert.ok(!app.includes('support@optimum.local'),'broken local support address must not ship');
assert.ok(config.includes("supportEmail: ''"),'support contact must stay explicit/configurable instead of invented');
assert.ok(manifest.icons?.some((x)=>x.sizes==='192x192'&&x.src.includes('optimum-icon-192.png')),'192 PWA icon missing');
assert.ok(manifest.icons?.some((x)=>x.sizes==='512x512'&&x.src.includes('optimum-icon-512.png')),'512 PWA icon missing');
assert.ok(read('favicon.svg').includes('data:image/png;base64,'),'legacy favicon route must carry approved product mark');

assert.equal(app,read('public/assets/app.js'),'client runtime mirror must match');
assert.equal(platform,read('public/assets/platform.js'),'platform runtime mirror must match');
assert.equal(platform,read('platform-console/assets/platform.js'),'standalone platform runtime mirror must match');
assert.equal(css,read('public/assets/styles.css'),'public CSS mirror must match');
assert.equal(css,read('app/globals.css'),'Next CSS mirror must match');
assert.equal(css,read('platform-console/assets/styles.css'),'standalone platform CSS mirror must match');

console.log('PASS Optimum final product identity production gate: approved mark, favicons/PWA icons, client/platform branding, mirrors, no broken support placeholder');
