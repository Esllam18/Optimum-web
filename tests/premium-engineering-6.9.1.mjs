import fs from 'node:fs';
import assert from 'node:assert/strict';
const read=p=>fs.readFileSync(p,'utf8');
const pkg=JSON.parse(read('package.json'));
const engineering=read('assets/engineering.js');
const publicEngineering=read('public/assets/engineering.js');
const styles=read('assets/styles.css');
assert.equal(pkg.version,'6.9.0','Premium pass must stay on legacy 6.9 runtime');
assert.equal(engineering,publicEngineering,'engineering.js root/public drift');
assert.equal(styles,read('public/assets/styles.css'),'styles root/public drift');
assert.equal(styles,read('app/globals.css'),'styles root/app drift');
assert.equal(styles,read('platform-console/assets/styles.css'),'styles root/platform drift');

// Canvas-first responsive workspace and one-at-a-time mobile panels.
for(const marker of ['compactCadViewport','cad-mobile-layout','cad-mobile-quick-actions','cad-mobile-panel-backdrop','engineering-close-mobile-panels'])
  assert.ok(engineering.includes(marker),`Premium Engineering missing ${marker}`);
assert.match(engineering,/eng\.showPalette=!compact&&canEditOnOpen;eng\.showInspector=!compact;eng\.showRouteDock=false;eng\.showMinimap=!compact/,'CAD must keep routes hidden on open while preserving canvas-first/read-only panel rules');
assert.match(engineering,/if\(eng\.tool==='route'\)eng\.showRouteDock=true/,'route library must open on demand when the Route tool is selected');
assert.ok(engineering.includes("const canEditOnOpen=isEditableRevision()"),'CAD open state must derive mutation panels from editability');
assert.match(engineering,/if\(compact\)setTimeout\(\(\)=>fitCanvas\(\),0\)/,'compact CAD must fit the drawing after mount');
assert.match(engineering,/compact\?0\.16:0\.24/,'mobile fit range must allow full-sheet framing');
assert.match(engineering,/engineering-toggle-palette[\s\S]{0,220}eng\.showInspector=false;eng\.showRouteDock=false/,'mobile palette must replace other panels');
assert.match(engineering,/engineering-toggle-inspector[\s\S]{0,220}eng\.showPalette=false;eng\.showRouteDock=false/,'mobile inspector must replace other panels');
assert.match(engineering,/engineering-toggle-route-dock[\s\S]{0,220}eng\.showPalette=false;eng\.showInspector=false/,'mobile routes must replace other panels');

// Preserve the professional engineering capabilities rather than simplifying them away.
for(const marker of ['engineering-open-boq','engineering-revisions','engineering-save-to-files','engineering-export-menu','engineering-frame-settings','engineering-open-notes','engineering-validation-fix-layout','Smart Fix','engineering-auto-layout','engineering-smart-routes'])
  assert.ok(engineering.includes(marker),`Engineering capability regressed: ${marker}`);
for(const marker of ['drawingContextReadOnly','engineering-readonly-banner','cad-readonly-context','expected_lock_version','lockVersion'])
  assert.ok(engineering.includes(marker),`Engineering governance contract regressed: ${marker}`);

// Premium visual hierarchy / responsive containment.
for(const marker of [
  'Feature 5 Premium Engineering workspace',
  '.cad-mobile-quick-actions',
  '.cad-mobile-panel-backdrop',
  '.cad-mobile-layout .engineering-editor-body',
  '.cad-mobile-layout .engineering-canvas-viewport',
  '.cad-mobile-layout .engineering-editor-left',
  '.cad-mobile-layout .engineering-editor-right',
  '.cad-mobile-layout .engineering-quick-dock',
  '.engineering-inspector-form textarea{min-height:78px',
  '.cad-route-dock-r2{background:',
  '.cad-route-r2-grid{display:grid',
  '.cad-route-more{grid-column:1/-1'
]) assert.ok(styles.includes(marker),`Premium Engineering style missing ${marker}`);
assert.match(styles,/@media\(max-width:760px\)[\s\S]*\.cad-mobile-layout \.engineering-editor-body\{display:block!important/,'mobile legacy grid containment correction missing');
assert.match(styles,/@media\(max-width:760px\)[\s\S]*grid-template-columns:minmax\(0,1fr\)!important/,'mobile canvas single-column contract missing');

console.log('PASS premium Engineering/CAD 6.9.1: canvas-first responsive workspace, readable panels, governance, and runtime mirrors verified');
