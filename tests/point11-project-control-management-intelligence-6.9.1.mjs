import fs from 'node:fs';
import assert from 'node:assert/strict';

const app=fs.readFileSync('assets/app.js','utf8');
const appMirror=fs.readFileSync('public/assets/app.js','utf8');
const pc=fs.readFileSync('assets/project-control.js','utf8');
const pcMirror=fs.readFileSync('public/assets/project-control.js','utf8');
const styles=fs.readFileSync('assets/styles.css','utf8');
const publicStyles=fs.readFileSync('public/assets/styles.css','utf8');
const nextStyles=fs.readFileSync('app/globals.css','utf8');
const platformStyles=fs.readFileSync('platform-console/assets/styles.css','utf8');
const migration=fs.readFileSync('supabase/migrations/20260815193000_point11_project_control_management_intelligence.sql','utf8');

for(const marker of [
  "import { createProjectControl } from './project-control.js?v=6.9.0'",
  "control:'projects.view'",
  'projectControl = createProjectControl',
  'projectControl?.handleAction',
  'projectControl?.handleChange',
  'projectControl?.handleSubmit',
]) assert.ok(app.includes(marker),`Point 11 app integration missing ${marker}`);


// Core 9–10 consolidation: Project Control stays canonical but lives in management Home + Project 360.
assert.ok(app.includes('function dashboardControlSummary()'),'Management Home must include Project Control summary');
assert.ok(app.includes('project-control-inline-entry'),'Project 360 must expose its control workspace inline');
assert.ok(app.includes('data-action="pc-open-project"'),'Project 360/Home must drill into Project Control');
assert.ok(app.includes('data-action="pc-weekly-brief"'),'Project 360 must expose Weekly Brief');
assert.ok(!app.includes("['control','activity',()=>L('التحكم بالمشاريع','Project Control')]"),'Project Control must not remain a standalone sidebar destination');

for(const marker of [
  'project_control_portfolio','project_control_project','project_control_weekly_brief',
  'save_project_control_brief','review_project_control_brief','link_project_control_brief_document',
  "L('الصورة الإدارية في دقيقة واحدة','Management clarity in one minute')",
  "L('قرارات تحتاج تدخل الإدارة','Decisions that need management')",
  "L('تقدم تنفيذي','Execution progress')",
  "L('الملخص الأسبوعي للمشروع','Weekly Project Brief')",
  'begin_document_upload_v2','begin_new_version_upload_v2','finalize_document_upload',
  'pc-brief-save','pc-brief-submit','saveBrief',
  'syncBriefToCde','text/html'
]) assert.ok(pc.includes(marker),`Point 11 project-control module missing ${marker}`);

assert.ok(!pc.includes("icon('chart'"),'Project Control must not reference a missing chart icon');
assert.ok(!pc.includes("icon('dot'"),'Project Control must not reference a missing dot icon');
assert.ok(!pc.includes('document.activeElement?.dataset?.pcSubmit'),'Brief submit intent must never depend on activeElement');
assert.ok(!/health_score\s*[:=]\s*(100|90|80|75|70)\b/.test(pc),'UI must not hardcode a fake project health score');

for(const marker of [
  'create table if not exists public.project_control_briefs',
  'create table if not exists public.project_control_brief_events',
  'alter table public.project_control_briefs enable row level security',
  'alter table public.project_control_brief_events enable row level security',
  'create or replace function app_private.project_control_metrics',
  'create or replace function public.project_control_portfolio',
  'create or replace function public.project_control_project',
  'create or replace function public.project_control_weekly_brief',
  'create or replace function public.save_project_control_brief',
  'create or replace function public.review_project_control_brief',
  'create or replace function public.link_project_control_brief_document',
  'create or replace function public.resolve_project_control_folder',
  'schedule_variance_pct','execution_progress_pct','expected_progress_pct','score','band',
  'overdue_tasks','blocked_tasks','field_issues','constraints','inspections','cde','daily_reports','schedule',
  'report_document_id uuid references public.documents(id)',
  'grant execute on function public.project_control_portfolio',
  'public.project_control_project(uuid)',
  'public.project_control_weekly_brief(uuid,date)',
  'to authenticated'
]) assert.ok(migration.includes(marker),`Point 11 migration missing ${marker}`);

// Dynamic project health stays derived from canonical execution sources; only authored management briefs are persisted.
assert.ok(!/create table if not exists public\.project_(health|control_snapshot|metrics_snapshot)/i.test(migration),'Point 11 must not persist duplicated health/metrics snapshots');
for(const source of ['public.tasks','public.site_field_issues','public.site_constraints','public.site_inspections','public.documents','public.site_daily_logs','public.site_cabinets'])
  assert.ok(migration.includes(source),`Project Control metrics should derive from canonical source ${source}`);

for(const marker of [
  '.pc-control-room','.pc-hero','.pc-decision-center','.pc-projects-panel','.pc-health-ring',
  '.pc-project-main','.pc-progress-band','.pc-driver-grid','.pc-detail-grid','.pc-brief','.pc-trend-chart'
]) assert.ok(styles.includes(marker),`Point 11 premium/responsive CSS missing ${marker}`);

assert.equal(app,appMirror,'app mirror drift');
assert.equal(pc,pcMirror,'project-control mirror drift');
assert.equal(styles,publicStyles,'public styles mirror drift');
assert.equal(styles,nextStyles,'Next styles mirror drift');
assert.equal(styles,platformStyles,'Platform styles mirror drift');

console.log('PASS Point 11 Project Control & Management Intelligence: explainable health, portfolio control, drill-down, bottlenecks, decisions, weekly brief CDE versioning, localization, and canonical integration');
