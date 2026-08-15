import fs from 'node:fs';
import assert from 'node:assert/strict';
const read=p=>fs.readFileSync(p,'utf8');
const app=read('assets/app.js');
const css=read('assets/styles.css');
const pkg=JSON.parse(read('package.json'));

assert.equal(pkg.version,'6.9.0','premium point 8 must stay on the 6.9 production line');
assert.equal(app,read('public/assets/app.js'),'app mirror drift');
for(const peer of ['public/assets/styles.css','app/globals.css','platform-console/assets/styles.css']) assert.equal(css,read(peer),`style mirror drift: ${peer}`);

for(const needle of [
  'globalEntityMeta','commandDefaultContent','quickCreateSections','renderQuickCreateSections','groupedSearchResults',
  'commandSearchEpoch','epoch!==state.commandSearchEpoch','p_limit:30','moveCommandSelection','activateCommandSelection',
  'notificationNeedsAction','renderNotificationGroup','notification-inbox','Attention inbox','صندوق الانتباه',
  'global-command-shell','command-result-section','command-search-summary'
]) assert.ok(app.includes(needle),`premium global-action contract missing: ${needle}`);

for(const needle of [
  "if(can('tasks.create'))", "if(can('projects.create'))", "if(can('members.invite'))", "if(can('roles.create'))", "if(can('members.manage'))",
  "data-action=\"open-search-result\"", "data-action=\"open-notification\"", "data-action=\"mark-notifications-read\"",
  "api.rpc('global_search'", "navigateToEntity(el.dataset.type,el.dataset.id)"
]) assert.ok(app.includes(needle),`existing permission/deep-link contract lost: ${needle}`);

assert.match(app,/query\.length<2\)\{setCommandResults\(commandDefaultContent\(\)\)/,'short queries must restore the default action layer');
assert.match(app,/commandInput&&\['ArrowDown','ArrowUp'\]\.includes\(ev\.key\)/,'command search must support arrow-key navigation');
assert.match(app,/commandInput&&ev\.key==='Enter'/,'command search must support keyboard activation');
assert.ok(!/box\.innerHTML=quick\+memberResults/.test(app),'active search must not prepend quick actions to results');

for(const cls of [
  '.global-command-dialog','.global-command-shell','.command-default-section','.command-result-section','.command-result-grid',
  '.command-search-summary','.search-result.keyboard-active','.quick-create-section','.notification-inbox',
  '.notification-group','.notification-item-premium','.notification-unread-dot'
]) assert.ok(css.includes(cls),`premium global-action style missing: ${cls}`);

assert.match(css,/@media\(max-width:600px\)[\s\S]*?\.global-command-dialog\{width:calc\(100vw - 16px\)/,'mobile command layer must stay inside the viewport');
assert.match(css,/@media\(max-width:600px\)[\s\S]*?\.quick-create-panel \.quick-create-action-grid\{grid-template-columns:1fr\}/,'mobile quick-create actions must stack clearly');

console.log('Premium Global Search + Notifications + Quick Create 6.9.1 checks passed.');
