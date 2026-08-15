import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=(p)=>fs.readFileSync(p,'utf8');
const app=read('assets/app.js');
const platform=read('assets/platform.js');
const css=read('assets/styles.css');

assert.match(app,/premium-dialog-r4/,'client dialogs must use the R4 premium dialog contract');
assert.match(app,/dialog-product-identity/,'client dialogs must carry Optimum product identity');
assert.match(app,/premium-drawer-r4/,'generic drawers must use the R4 drawer contract');
assert.match(app,/drawer-brand-rail/,'generic drawers must carry the Optimum brand rail');
assert.match(platform,/premium-dialog-r4/,'platform admin dialogs must share the R4 dialog language');
assert.match(platform,/optimum-mark\.png/,'platform admin dialogs must carry Optimum identity');
assert.match(css,/OPTIMUM 6\.9\.1 — Premium Polish R4/,'R4 stylesheet marker missing');
assert.match(css,/\.table-wrap thead th\{position:sticky/,'long data tables need sticky headers');
assert.match(css,/\.form-row:focus-within>label:first-child/,'form focus hierarchy missing');
assert.match(css,/@media\(prefers-reduced-motion:reduce\)/,'reduced-motion contract missing');
assert.match(css,/\.topbar-product\{display:grid!important/,'product mark must remain visible in the topbar');
assert.equal(read('public/assets/app.js'),app,'client app public mirror drifted');
assert.equal(read('public/assets/platform.js'),platform,'platform public mirror drifted');
assert.equal(read('public/assets/styles.css'),css,'public stylesheet mirror drifted');
assert.equal(read('app/globals.css'),css,'Next stylesheet mirror drifted');
assert.equal(read('platform-console/assets/styles.css'),css,'platform stylesheet mirror drifted');
assert.equal(read('platform-console/assets/platform.js'),platform,'platform runtime mirror drifted');

console.log('PASS Optimum Premium Polish R4: overlay identity, sticky data tables, form focus hierarchy, mobile composition and reduced-motion consistency');
