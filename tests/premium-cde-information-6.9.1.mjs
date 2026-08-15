import fs from 'node:fs';
import assert from 'node:assert/strict';
const app=fs.readFileSync(new URL('../assets/app.js',import.meta.url),'utf8');
const publicApp=fs.readFileSync(new URL('../public/assets/app.js',import.meta.url),'utf8');
const css=fs.readFileSync(new URL('../assets/styles.css',import.meta.url),'utf8');
const publicCss=fs.readFileSync(new URL('../public/assets/styles.css',import.meta.url),'utf8');
const globals=fs.readFileSync(new URL('../app/globals.css',import.meta.url),'utf8');
const platformCss=fs.readFileSync(new URL('../platform-console/assets/styles.css',import.meta.url),'utf8');
for(const marker of [
  'cde-scope-bar','cde-onboarding','cde-tools','cde-view-switch','cde-folder-browser',
  'document-pulse-grid','document-control-panel','document-related-panel','document-version-history','current-version-chip',
  'storage-intelligence-summary','recovery-overview-strip','Recovery Center','Smart Trash'
]) assert.ok(app.includes(marker),`missing premium CDE contract: ${marker}`);
for(const marker of [
  '.cde-scope-bar','.cde-tools','.cde-folder-browser-summary','.document-pulse-grid','.document-control-panel',
  '.document-version-history','.current-version-chip','.storage-intelligence-summary','.recovery-overview-strip','.recovery-item'
]) assert.ok(css.includes(marker),`missing premium CDE style: ${marker}`);
assert.ok(css.includes('.folder-card:hover,.cde-document-card:hover{transform:none'), 'CDE cards must not jump on hover');
assert.ok(css.includes('@media(min-width:341px) and (max-width:460px){.document-pulse-grid{grid-template-columns:1fr 1fr}}'), 'mobile Document 360 pulse should remain compact');
const filesBlock=app.slice(app.indexOf('function filesPage()'),app.indexOf('function renderFolderTree'));
assert.ok(filesBlock.indexOf('data-action="upload-files"') < filesBlock.indexOf('data-action="create-folder"'), 'Upload must remain the primary first CDE action');
assert.ok(filesBlock.indexOf('data-action="cde-architecture"') > filesBlock.indexOf('data-action="upload-files"'), 'File architecture must remain secondary to Quick Upload');
assert.ok(filesBlock.indexOf('data-action="open-storage-intelligence"') > filesBlock.indexOf('data-action="upload-files"'), 'Storage intelligence must remain secondary to Quick Upload');
assert.equal(app,publicApp,'app runtime mirror drift');
assert.equal(css,publicCss,'public CSS mirror drift');
assert.equal(css,globals,'global CSS mirror drift');
assert.equal(css,platformCss,'platform CSS mirror drift');
console.log('PASS premium CDE information workspace 6.9.1: calm context, document control, recovery, responsive guards, and mirrors verified');
