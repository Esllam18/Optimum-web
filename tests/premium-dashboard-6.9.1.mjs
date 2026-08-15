import fs from 'node:fs';
import assert from 'node:assert/strict';
const read=p=>fs.readFileSync(p,'utf8');
const app=read('assets/app.js');
const css=read('assets/styles.css');
const pkg=JSON.parse(read('package.json'));
const dash=app.slice(app.indexOf('function dashboardTaskRelevant'),app.indexOf('function quickAction(',app.indexOf('function dashboardTaskRelevant')));

assert.equal(pkg.version,'6.9.0','premium dashboard must stay on the 6.9 production line');
assert.equal(app,read('public/assets/app.js'),'app mirror drift');
for(const peer of ['public/assets/styles.css','app/globals.css','platform-console/assets/styles.css']) assert.equal(css,read(peer),`style mirror drift: ${peer}`);

for(const needle of [
  'dashboardTaskRelevant','dashboardOpenTasks','dashboardLateProjects','dashboardDecisionSignals','dashboardTodaySection',
  'dashboardProjectPulse','dashboardNotificationPreview','dashboardWorkspaceHealth','dashboardActivityPreview',
  'dashboard-cockpit','dashboard-decision-bar','dashboard-content-grid','dashboard-focus-row','dashboard-project-row'
]) assert.ok(app.includes(needle),`premium dashboard contract missing: ${needle}`);

for(const permission of ["can('tasks.view')","can('notifications.view')","can('projects.view')","can('members.manage')","can('files.upload')","can('audit.view')"]) assert.ok(dash.includes(permission),`dashboard permission adaptation missing: ${permission}`);

assert.ok(!dash.includes('welcome-banner'),'dashboard must not restore the oversized legacy welcome hero');
assert.ok(!dash.includes('stat-card'),'dashboard must not restore generic KPI cards');
assert.ok(!dash.includes('quick-actions'),'dashboard must not duplicate the global create layer');
assert.ok(!dash.includes('storage-ring'),'dashboard must not restore the oversized storage ring');
assert.ok(!dash.includes('policy-runtime-strip'),'dashboard must not show the full policy strip permanently');
assert.ok(!dash.includes('workDashboardSection()'),'dashboard must not duplicate the Work OS dashboard section');

assert.match(dash,/state\.notifications\.filter\(\(item\)=>!item\.read_at&&notificationNeedsAction\(item\)\)/,'attention signal must use real unread actionable notifications');
assert.match(dash,/dashboardLateProjects\(\)/,'project schedule attention must derive from real project targets');
assert.match(dash,/limitReached\('storage'\)/,'workspace capacity signal must honor production plan limits');
assert.match(dash,/data-action="open-task"/,'focus queue must deep-link to work items');
assert.match(dash,/data-action="open-project"/,'project pulse must deep-link to Project 360');
assert.match(dash,/data-action="open-notification"/,'attention preview must deep-link through notifications');

for(const cls of [
  '.dashboard-cockpit','.dashboard-intro','.dashboard-decision-bar','.dashboard-decision-signal','.dashboard-content-grid',
  '.dashboard-panel','.dashboard-focus-row','.dashboard-project-row','.dashboard-notification-row','.dashboard-capacity-row'
]) assert.ok(css.includes(cls),`premium dashboard style missing: ${cls}`);
assert.match(css,/@media\(max-width:600px\)[\s\S]*?\.dashboard-decision-bar\{grid-template-columns:1fr/,'mobile dashboard decision signals must stack');
assert.match(css,/@media\(max-width:600px\)[\s\S]*?\.dashboard-side-column\{grid-template-columns:1fr\}/,'mobile dashboard side rail must collapse to one column');

console.log('Premium Decision Dashboard 6.9.1 checks passed.');
