import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=(p)=>fs.readFileSync(p,'utf8');
const app=read('assets/app.js');
const platform=read('assets/platform.js');
const css=read('assets/styles.css');
const work=read('assets/work-os.js');
const config=read('assets/config.js');
const index=read('index.html');
const platformHtml=read('platform.html');

assert.match(css,/OPTIMUM 6\.9\.1 — Premium Polish R5/,'R5 stylesheet marker missing');
assert.match(app,/dashboard-cockpit role-aware-home \$\{mode\} r5/,'dashboard R5 root marker missing');
assert.match(app,/dashboard-focus-meta/,'dashboard task rows must expose priority and due metadata');
assert.match(app,/Connected to live workspace data|متصل بمصدر البيانات الحقيقي/,'dashboard live-source cue missing');
assert.match(work,/tasks-premium-head r5/,'tasks premium header R5 marker missing');
assert.match(work,/simple-work-home r2 r5/,'task home R5 marker missing');

assert.match(platform,/platform-shell r5/,'platform shell R5 marker missing');
assert.match(platform,/platform-ops-cockpit r5/,'platform cockpit R5 marker missing');
assert.match(platform,/platform-topbar-logo/,'platform topbar brand mark missing');
assert.match(platform,/platform-access-denied-r5/,'platform denied experience R5 marker missing');
assert.match(platform,/if\(!state\.admin\)\{app\.innerHTML=deniedView\(\);return;\}/,'platform console must deny non-platform admins before rendering admin surfaces');
assert.match(platform,/No platform administration data is exposed|لن يتم عرض أي بيانات إدارية/,'denied state must explicitly state that admin data is not exposed');

assert.match(config,/6\.9\.0-site-delivery-claim-intelligence/,'certified runtime app version contract must stay on the 6.9 production line');
assert.match(index,/\?v=6\.9\.0/,'certified client cache contract must stay on 6.9.0 query keys');
assert.match(platformHtml,/\?v=6\.9\.0/,'certified platform cache contract must stay on 6.9.0 query keys');

assert.equal(read('public/assets/app.js'),app,'client app public mirror drifted');
assert.equal(read('public/assets/platform.js'),platform,'platform public mirror drifted');
assert.equal(read('public/assets/styles.css'),css,'public stylesheet mirror drifted');
assert.equal(read('public/assets/work-os.js'),work,'work OS public mirror drifted');
assert.equal(read('app/globals.css'),css,'Next stylesheet mirror drifted');
assert.equal(read('platform-console/assets/styles.css'),css,'platform stylesheet mirror drifted');
assert.equal(read('platform-console/assets/platform.js'),platform,'platform runtime mirror drifted');

console.log('PASS Optimum Premium Polish R5: live dashboard hierarchy, semantic focus rows, task polish, platform executive UI, access denial, runtime/version consistency and runtime mirrors');
