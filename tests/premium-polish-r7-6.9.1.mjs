import fs from 'node:fs';
import assert from 'node:assert/strict';

const app=fs.readFileSync('assets/app.js','utf8');
const pubApp=fs.readFileSync('public/assets/app.js','utf8');
const work=fs.readFileSync('assets/work-os.js','utf8');
const pubWork=fs.readFileSync('public/assets/work-os.js','utf8');
const css=fs.readFileSync('assets/styles.css','utf8');
const pubCss=fs.readFileSync('public/assets/styles.css','utf8');
const globalCss=fs.readFileSync('app/globals.css','utf8');
const platformCss=fs.readFileSync('platform-console/assets/styles.css','utf8');

assert.match(app,/dashboard-decision-bar r5 r7 count-\$\{signals\.length\}/);
assert.match(app,/One decision needs you|قرار واحد يحتاج تدخلك/);
assert.match(app,/dashboard-attention-empty r7/);
assert.match(app,/Nothing needs your attention|لا يوجد ما يحتاج تدخلك الآن/);
assert.match(app,/dashboard-hero-brand r7/);
assert.match(work,/simple-quick-add r2 r7/);
assert.match(work,/simple-day-rail r7/);
assert.match(work,/tasks-premium-head r5 r7/);
assert.match(css,/Premium Polish R7/);
assert.match(css,/dashboard-decision-bar\.r7\.count-1/);
assert.match(css,/dashboard-attention-empty\.r7/);
assert.match(css,/simple-quick-add\.r7/);
assert.match(css,/nav-link:not\(\.active\):hover/);
assert.equal(app,pubApp,'client app runtime mirror must match public');
assert.equal(work,pubWork,'work OS runtime mirror must match public');
assert.equal(css,pubCss,'styles runtime mirror must match public');
assert.equal(css,globalCss,'global style mirror must match');
assert.equal(css,platformCss,'platform style mirror must match');

console.log('PASS Optimum Premium Polish R7: compact decisions, calm attention empty state, integrated hero brand, task capture density, sidebar interactions and runtime mirrors');
