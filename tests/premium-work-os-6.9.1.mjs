import fs from 'node:fs';
import assert from 'node:assert/strict';
const read=p=>fs.readFileSync(p,'utf8');
const pkg=JSON.parse(read('package.json'));
const work=read('assets/work-os.js');
const pubWork=read('public/assets/work-os.js');
const app=read('assets/app.js');
const styles=read('assets/styles.css');
assert.equal(pkg.version,'6.9.0','Point 4 must stay on the 6.9 runtime line');
assert.equal(work,pubWork,'work-os.js root/public drift');
assert.equal(app,read('public/assets/app.js'),'app.js root/public drift');
assert.equal(styles,read('public/assets/styles.css'),'styles root/public drift');
assert.equal(styles,read('app/globals.css'),'styles root/app drift');
assert.equal(styles,read('platform-console/assets/styles.css'),'styles root/platform drift');

// Point 4: simple execution is the default surface.
for(const marker of ['simple-work-home','simple-quick-add','simple-work-tabs','simple-task-line','simple-next-action','simple-advanced-tools'])
  assert.ok(work.includes(marker),`Point 4 simple work surface missing ${marker}`);
for(const label of ["L('اليوم','Today')","L('القادمة','Upcoming')","L('كل مهامي','All my work')","L('المكتملة','Completed')","L('فريقي','My team')"])
  assert.ok(work.includes(label),`Point 4 tab missing ${label}`);
assert.match(work,/data-form="workos-quick-task"/,'one-line quick add missing');
assert.match(work,/workos-toggle-focus/,'Today Focus contract missing');
assert.match(work,/مهام إضافية متاحة|Optional extra tasks/,'optional bonus task surface missing');
assert.match(work,/سأتولى هذه|I’ll take it/,'bonus claim action missing');
for(const marker of ['simple-day-rail','simple-layout-toggle','simple-board','workos-plan-day','workos-start-task','workos-how-to','task-howto','simple-composer-more'])
  assert.ok(work.includes(marker),`Point 4 R2 experience missing ${marker}`);
assert.match(work,/رتّب يومي|Plan my day/,'advisory day planning missing');
assert.match(work,/كيف تنفذ المهمة|How to execute this task/,'execution guidance missing');

// Smart assistance is optional and user-controlled.
assert.match(work,/smartBreakdownSuggestions/,'smart task decomposition missing');
assert.match(work,/workos-smart-breakdown/,'smart breakdown action missing');
assert.match(work,/لن ينفذ أي خطوة تلقائيًا|Nothing is executed automatically/,'AI assistance must be advisory, not autonomous');
assert.match(work,/add_task_checklist_item/,'smart breakdown must use the canonical checklist contract');

// Context cascade: Project -> Site -> Cabinet, with cabinet mapped to its canonical root folder.
for(const marker of ['site_cabinets','cabinetOptions','cabinetForFolder','cabinet_folder_id','focusContext'])
  assert.ok(work.includes(marker),`Point 4 context cascade missing ${marker}`);
assert.match(app,/site-open-work[\s\S]{0,500}focusContext/,'Site -> Tasks context action missing');
assert.match(app,/cabinet-open-work[\s\S]{0,500}focusContext/,'Cabinet -> Tasks context action missing');
assert.match(app,/project-open-work[\s\S]{0,400}focusContext/,'Project -> Tasks context action missing');

// Immediate mutation feedback and the Point 3 overlay-focus regression.
for(const type of ['workos-quick-task','workos-task','workos-smart-breakdown','workos-status'])
  assert.ok(app.includes(`'${type}':L(`),`Immediate busy label missing for ${type}`);
assert.match(app,/const target=had&&overlayReturnFocus\?\.isConnected\?overlayReturnFocus:null;overlayReturnFocus=null;if\(target\)setTimeout/,'overlay focus race regression is not fixed safely');
assert.doesNotMatch(app,/setTimeout\(\(\)=>overlayReturnFocus\.focus\(\),0\);overlayReturnFocus=null/,'unsafe delayed focus regression returned');

// Clean user-facing language: “Work OS” remains an internal module name only.
for(const forbidden of ['إعداد Work OS','إدارة Work OS','تم تحديث Work OS تلقائيًا'])
  assert.ok(!work.includes(forbidden),`Internal Work OS wording leaked to user UI: ${forbidden}`);
assert.match(work,/إعدادات المهام المتقدمة|Advanced task settings/,'advanced task settings label missing');

// Existing powerful engines stay intact underneath the simple UI.
for(const marker of ['workos-calendar-shell','data-workos-drag-task','expected_lock_version','Smart Assignment 2.0','capacityPlannerView','dependencyGraphView','workflowTemplateDialog','work_assignment_candidates','save_work_item','work_calendar_feed'])
  assert.ok(work.includes(marker),`Underlying Work capability regressed: ${marker}`);
assert.match(work,/function taskFilters\(\)\{return \{scope:local\.task\.scope,status:local\.task\.status,project_id:local\.task\.project_id,task_type:local\.task\.task_type,risk:local\.task\.risk,due:local\.task\.due,assignee_user_id:local\.task\.assignee_user_id,search:local\.task\.search\};\}/,'canonical task query contract drifted');
assert.doesNotMatch(work,/function taskFilters\(\)[^\n]*site_id/,'do not fake a site filter in the backend task query');

// Calm detail: no “all clear” risk card; attention appears only when it matters.
assert.match(work,/if\(!reasons\.length\)return '';/,'task detail must suppress empty risk noise');
assert.match(work,/تحتاج انتباهًا|NEEDS ATTENTION/,'risk attention label is missing');

// Point 4 responsive composition.
for(const cls of ['.simple-work-home','.simple-quick-add','.simple-task-line','.point4-task-dialog','.smart-breakdown-dialog'])
  assert.ok(styles.includes(cls),`Point 4 style missing ${cls}`);
assert.match(styles,/@media\(max-width:760px\)[\s\S]*\.simple-task-line/,'Point 4 mobile task composition missing');
assert.ok(styles.includes('content-visibility:auto') && styles.includes('scroll-snap-type:inline proximity'),'legacy performance/board containment regressed');

console.log('PASS Point 4 Simple Work 6.9.1: simple task UX, context cascade, smart breakdown, immediate progress, preserved engines, focus-race regression guard');
