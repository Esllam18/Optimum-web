import fs from 'node:fs';
import assert from 'node:assert/strict';

const app=fs.readFileSync('assets/app.js','utf8');
const appMirror=fs.readFileSync('public/assets/app.js','utf8');
const ops=fs.readFileSync('assets/operations-center.js','utf8');
const opsMirror=fs.readFileSync('public/assets/operations-center.js','utf8');
const eng=fs.readFileSync('assets/engineering.js','utf8');
const engMirror=fs.readFileSync('public/assets/engineering.js','utf8');
const styles=fs.readFileSync('assets/styles.css','utf8');
const publicStyles=fs.readFileSync('public/assets/styles.css','utf8');
const nextStyles=fs.readFileSync('app/globals.css','utf8');
const platformStyles=fs.readFileSync('platform-console/assets/styles.css','utf8');
const migration=fs.readFileSync('supabase/migrations/20260815114000_point8_operations_center.sql','utf8');

for(const marker of [
  "operations:()=>import('./operations-center.js?v=6.9.0')",
  "dashboard:'company.view', operations:'company.view'",
  "operationsCenter=mod.createOperationsCenter",
  "if(await operationsCenter?.handleAction(action,el))return",
  "if(await operationsCenter?.handleChange(ev))return",
  "operationsCenter?.reset()"
]) assert.ok(app.includes(marker),`Point 8 app integration missing ${marker}`);


// Core 9–10 consolidation: the Operations engine remains live but is embedded into the role-aware Home, not duplicated in navigation.
assert.ok(app.includes('function dashboardHomeMode()'),'Role-aware Home must exist');
assert.ok(app.includes('function dashboardChangeDigest()'),'Operations changes must be embedded in Home');
assert.ok(app.includes("const jobs=[ensureOperationsCenter({load,force})]"),'Management Home must activate canonical Operations on demand');
assert.ok(app.includes("jobs.push(ensureProjectControl({load,force}))"),'Management Home must activate Project Control on demand when permitted');
assert.ok(!app.includes("['operations','activity',()=>L('مركز التشغيل','Operations Center')]"),'Operations Center must not remain a standalone sidebar destination');

for(const marker of [
  'operations_center_snapshot','operations_calendar_feed','operations_center_mark_seen',
  'save_operations_calendar_layers','toggle_entity_follow','mark_all_notifications_read',
  "L('يومي','My day')","L('صندوق العمل','Inbox')","L('الاعتمادات','Approvals')",
  "L('ما الذي تغير؟','What changed?')","L('التقويم','Calendar')",
  "L('مساحة تشغيلك الشخصية','YOUR OPERATING SPACE')",
  'ops-toggle-follow','data-ops-layer','ops-mark-all-read','ops-open-approval'
]) assert.ok(ops.includes(marker),`Operations Center module missing ${marker}`);

// Beginner-first wording: no raw implementation jargon is used as the product name.
assert.ok(!/Work OS|Cockpit/i.test(ops),'Operations Center should not expose old Work OS/Cockpit jargon');
assert.ok(ops.includes("L('ابدأ من «يومي»"),'Operations Center help must explicitly teach the novice starting point');
assert.ok(ops.includes("L('صندوق العمل يفرق"),'Operations Center help must explain action vs FYI notifications');

for(const marker of [
  '.ops-welcome','.ops-metrics','.ops-tabs','.ops-today-layout','.ops-work-row',
  '.ops-decision-row','.ops-inbox-row','.ops-change-row','.ops-follow-grid',
  '.ops-calendar-layers','.ops-calendar-grid','.ops-calendar-event'
]) assert.ok(styles.includes(marker),`Point 8 CSS missing ${marker}`);

for(const marker of [
  'create table if not exists public.entity_follows',
  'create table if not exists public.operations_user_state',
  'alter table public.entity_follows enable row level security',
  'alter table public.operations_user_state enable row level security',
  'create or replace function public.toggle_entity_follow',
  'create or replace function public.operations_center_mark_seen',
  'create or replace function public.save_operations_calendar_layers',
  'create or replace function public.operations_center_snapshot',
  'create or replace function public.operations_calendar_feed',
  'app_private.can_view_task',
  'app_private.user_has_resource_permission',
  'engineering_revision_events','site_claim_package_events','document_versions','task_events',
  'work_calendar_feed'
]) assert.ok(migration.includes(marker),`Point 8 migration missing ${marker}`);

// The unified feed must respect source-level permissions instead of copying data into a parallel operations table.
assert.ok(!/create table if not exists public\.operations_(events|inbox|approvals)/i.test(migration),'Point 8 must aggregate canonical sources, not duplicate them');
assert.ok(migration.includes("user_id=auth.uid()"),'Follow/state RLS must be scoped to the current user');

// CAD final closure requested by the user: old/direct toolbar feel, board-first, routes on demand.
for(const marker of [
  "showRouteDock:false",
  'cad-toolbar-classic-r3',
  'cad-panel-strip',
  "if(eng.tool==='route')eng.showRouteDock=true",
  "if(eng.tool==='node')eng.showPalette=true",
  "data-action=\"engineering-toggle-route-dock\"",
  "L('حفظ في الملفات','Save to Files')"
]) assert.ok(eng.includes(marker),`CAD final layout closure missing ${marker}`);
assert.ok(!eng.includes('cad-toolbar-more'), 'CAD toolbar must not hide core controls inside the R2 More menu');
assert.ok(styles.includes('.cad-toolbar-classic-r3 .cad-panel-strip'),'CAD direct panel controls need the compact classic styling');

assert.equal(app,appMirror,'app mirror drift');
assert.equal(ops,opsMirror,'operations-center mirror drift');
assert.equal(eng,engMirror,'engineering mirror drift');
assert.equal(styles,publicStyles,'public styles mirror drift');
assert.equal(styles,nextStyles,'Next styles mirror drift');
assert.equal(styles,platformStyles,'Platform styles mirror drift');

console.log('PASS Point 8 Operations Center: canonical unified work, approvals, changes, follows, calendar layers, beginner UX, localization, permissions, and CAD final layout closure');
