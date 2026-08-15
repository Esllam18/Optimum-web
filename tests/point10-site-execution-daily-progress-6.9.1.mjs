import fs from 'node:fs';
import assert from 'node:assert/strict';

const app=fs.readFileSync('assets/app.js','utf8');
const appMirror=fs.readFileSync('public/assets/app.js','utf8');
const field=fs.readFileSync('assets/site-supervisor.js','utf8');
const fieldMirror=fs.readFileSync('public/assets/site-supervisor.js','utf8');
const ops=fs.readFileSync('assets/operations-center.js','utf8');
const opsMirror=fs.readFileSync('public/assets/operations-center.js','utf8');
const styles=fs.readFileSync('assets/styles.css','utf8');
const publicStyles=fs.readFileSync('public/assets/styles.css','utf8');
const nextStyles=fs.readFileSync('app/globals.css','utf8');
const platformStyles=fs.readFileSync('platform-console/assets/styles.css','utf8');
const migration=fs.readFileSync('supabase/migrations/20260815170000_point10_site_execution_daily_progress.sql','utf8');

for(const marker of [
  'siteSupervisor = createSiteSupervisorWorkspace',
  'formatDateTime,relativeTime',
  'openDialog,openDrawer,closeOverlay,getProfile',
  'if(await siteSupervisor?.handleSubmit(form))return',
  "['site_daily_log','site_inspection','site_field_issue','site_constraint'].includes(type)",
  'resolve_site_execution_context',
  "data-action=\"open-field-site\"",
  "L('تنفيذ الموقع اليومي','Daily site execution')"
]) assert.ok(app.includes(marker),`Point 10 app integration missing ${marker}`);

for(const marker of [
  'site_execution_workspace','site_end_of_day_review','site_weekly_progress',
  "L('تنفيذ اليوم','TODAY EXECUTION')",
  "L('راجع نهاية اليوم','Review day')",
  "L('ملخص الأسبوع','Weekly summary')",
  'field-new-inspection','field-new-issue','field-new-constraint','field-daily-log',
  'syncDailyReportToCde','begin_document_upload_v2','begin_new_version_upload_v2','link_site_daily_report_document',
  'field-inspection-result','field-complete-inspection','field-issue-status',
  'field-return-day-submit','field-issue-close-submit','field-resolve-constraint-submit',
  'openReasonDialog','openEntity(type,id,siteId,workDate=null)',
  'offlineDraftKey','navigator.onLine'
]) assert.ok(field.includes(marker),`Point 10 field module missing ${marker}`);

// Point 10 must not use native prompt/confirm for review-resolution workflows.
assert.ok(!field.includes('prompt('),'Point 10 should use premium dialogs instead of browser prompt()');
assert.ok(field.includes('data-inspection-evidence'),'Inspection items should link canonical CDE evidence');
assert.ok(field.includes('document_picker_query'),'Inspection evidence should use the canonical document picker');
assert.ok(field.includes('evidence_document_id'),'Inspection save should persist the canonical evidence document id');

for(const marker of [
  'site_operations_feed','site_execution_calendar_feed',
  "site_daily_log",'site_inspection','site_field_issue','site_constraint',
  "field_inspection",'daily_report','field_issue_due'
]) assert.ok(ops.includes(marker),`Point 10 Operations bridge missing ${marker}`);

for(const marker of [
  'create table if not exists public.site_daily_logs',
  'create table if not exists public.site_inspection_templates',
  'create table if not exists public.site_inspections',
  'create table if not exists public.site_inspection_items',
  'create table if not exists public.site_field_issues',
  'create table if not exists public.site_constraints',
  'create table if not exists public.site_daily_log_events',
  'alter table public.site_daily_logs enable row level security',
  'alter table public.site_inspections enable row level security',
  'alter table public.site_field_issues enable row level security',
  'create or replace function public.ensure_site_daily_log',
  'create or replace function public.save_site_daily_log',
  'create or replace function public.create_site_inspection',
  'create or replace function public.save_site_inspection',
  'create or replace function public.create_site_field_issue',
  'create or replace function public.update_site_field_issue',
  'create or replace function public.save_site_constraint',
  'create or replace function public.resolve_site_constraint',
  'create or replace function public.submit_site_daily_log',
  'create or replace function public.review_site_daily_log',
  'create or replace function public.link_site_daily_report_document',
  'create or replace function public.site_execution_workspace',
  'create or replace function public.site_end_of_day_review',
  'create or replace function public.site_weekly_progress',
  'create or replace function public.site_operations_feed',
  'create or replace function public.site_execution_calendar_feed',
  'create or replace function public.resolve_site_execution_context',
  'app_private.site_execution_can_edit',
  'app_private.user_has_resource_permission',
  'app_private.resolve_site_report_folder'
]) assert.ok(migration.includes(marker),`Point 10 migration missing ${marker}`);

for(const builtIn of ['cabinet-readiness','route-quality','handover-readiness'])
  assert.ok(migration.includes(`'${builtIn}'`),`Inspection template missing ${builtIn}`);

// Field data stays canonical: daily execution links to tasks/documents/drawings rather than copying their payloads into shadow source tables.
assert.ok(!/create table if not exists public\.site_(task|document|drawing)_copies/i.test(migration),'Point 10 must not duplicate canonical task/document/drawing data');
assert.ok(migration.includes('report_document_id uuid references public.documents(id)'), 'Daily report must link to a canonical CDE document');
assert.ok(migration.includes('evidence_document_id uuid references public.documents(id)'), 'Inspection evidence must link to canonical CDE documents');

for(const marker of [
  '.field-execution-strip','.field-exec-metrics','.field-execution-actions','.field-report-state',
  '.field-execution-grid','.field-execution-row','.field-action-grid-v10',
  '.field-report-compose-hero','.field-inspection-items','.field-inspection-item','.field-inspection-evidence-guide','.field-inspection-evidence',
  '.field-eod-hero','.field-eod-checks','.field-weekly-metrics','.field-week-grid'
]) assert.ok(styles.includes(marker),`Point 10 premium/responsive CSS missing ${marker}`);

assert.equal(app,appMirror,'app mirror drift');
assert.equal(field,fieldMirror,'site supervisor mirror drift');
assert.equal(ops,opsMirror,'operations center mirror drift');
assert.equal(styles,publicStyles,'public styles mirror drift');
assert.equal(styles,nextStyles,'Next styles mirror drift');
assert.equal(styles,platformStyles,'Platform styles mirror drift');

console.log('PASS Point 10 Site Execution & Daily Progress: daily log, inspections, snags, constraints, EOD readiness, weekly progress, CDE report versioning, Operations bridge, premium dialogs, localization, and canonical integration');
