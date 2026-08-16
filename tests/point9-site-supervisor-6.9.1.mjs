import fs from 'node:fs';
import assert from 'node:assert/strict';

const app=fs.readFileSync('assets/app.js','utf8');
const appMirror=fs.readFileSync('public/assets/app.js','utf8');
const field=fs.readFileSync('assets/site-supervisor.js','utf8');
const fieldMirror=fs.readFileSync('public/assets/site-supervisor.js','utf8');
const eng=fs.readFileSync('assets/engineering.js','utf8');
const engMirror=fs.readFileSync('public/assets/engineering.js','utf8');
const ops=fs.readFileSync('assets/operations-center.js','utf8');
const opsMirror=fs.readFileSync('public/assets/operations-center.js','utf8');
const styles=fs.readFileSync('assets/styles.css','utf8');
const publicStyles=fs.readFileSync('public/assets/styles.css','utf8');
const nextStyles=fs.readFileSync('app/globals.css','utf8');
const platformStyles=fs.readFileSync('platform-console/assets/styles.css','utf8');
const migration=fs.readFileSync('supabase/migrations/20260815143000_point9_site_supervisor_workspace.sql','utf8');

for(const marker of [
  "import { createSiteSupervisorWorkspace } from './site-supervisor.js?v=6.9.0'",
  "field:'projects.view'",
  'function fieldWorkspaceAllowed()',
  'siteSupervisor = createSiteSupervisorWorkspace',
  'field:siteSupervisor?.page',
  'if(await siteSupervisor?.handleAction(action,el))return',
  'if(await siteSupervisor?.handleChange(ev))return',
  'siteSupervisor?.reset()',
]) assert.ok(app.includes(marker),`Point 9 app integration missing ${marker}`);


// Core 9–10 consolidation: Site Supervisor Workspace is the supervisor Home, not another sidebar module.
assert.ok(app.includes("if(mode==='field'&&siteSupervisor?.page)"),'Supervisor Home must render Site Supervisor Workspace');
assert.ok(app.includes("if(dashboardHomeMode()==='field')siteSupervisor?.load()"),'Supervisor Home must load field workspace data');
assert.ok(!app.includes("['field','hardHat',()=>L('مساحة الموقع','Field Workspace')]"),'Field Workspace must not remain a standalone sidebar destination');

for(const marker of [
  'site_supervisor_workspace',
  "L('مساحة مشرف الموقع','Site Supervisor Workspace')",
  "L('كل يوم الموقع في مكان واحد','Your whole site day in one place')",
  "L('الرسم والحصر','DRAWING & TAKEOFF')",
  "L('اختصارات الموقع','SITE SHORTCUTS')",
  'field-new-drawing','field-open-takeoff','field-upload','field-new-task','field-open-cabinet',
  "L('مشرف الموقع ينفذ ويوثق','The Site Supervisor executes and documents')"
]) assert.ok(field.includes(marker),`Site Supervisor module missing ${marker}`);

for(const marker of [
  "openNewDrawing:async(scope={})",
  'scope.projectId||state.selectedProjectId',
  'scope.cabinetId||',
  'openTakeoff:async(id,{takeoff=false}={})'
]) assert.ok(eng.includes(marker),`Engineering field-context API missing ${marker}`);

for(const marker of [
  "set name_ar='مشرف موقع', name_en='Site Supervisor'",
  "r.slug='supervisor'",
  "'drawings.create'","'drawings.edit'","'boq.edit'","'files.upload'","'tasks.create'","'tasks.edit'","'tasks.complete'",
  'create or replace function public.site_supervisor_workspace',
  'app_private.user_has_resource_permission',
  'app_private.can_view_task',
  "'can_create_drawing'","'can_edit_takeoff'","'can_upload'"
]) assert.ok(migration.includes(marker),`Point 9 migration missing ${marker}`);

// Supervisor must remain scoped: no global publish/catalog/company management privileges are granted by default.
const supervisorSeed=migration.match(/insert into public\.role_permissions select v_supervisor[\s\S]*?;\n/)?.[0]||'';
assert.ok(supervisorSeed,'Supervisor seed block missing');
for(const forbidden of ["'catalog.manage'","'drawings.publish'","'company.manage'","'roles.manage'"])
  assert.ok(!supervisorSeed.includes(forbidden),`Site Supervisor should not receive ${forbidden} by default`);

for(const marker of [
  '.field-hero','.field-metrics','.field-action-grid','.field-main-grid','.field-cabinet-grid','.field-drawing-row','.field-doc-row',
  '.ops-change-list{grid-template-columns:repeat(2',
  '.ops-source-grid>.ops-source-engineering',
  '.cad-master-route-dock.cad-route-dock-r2>header',
  'justify-content:center!important',
  '--cad-route-dock-h:76px'
]) assert.ok(styles.includes(marker),`Point 9 premium/CAD CSS missing ${marker}`);

// Route library should be on demand and the explanatory header removed, not a second persistent strip.
assert.ok(eng.includes('showRouteDock:false'),'Route dock must start hidden');
assert.ok(eng.includes("if(eng.tool==='route')eng.showRouteDock=true"),'Route tool must reveal route dock');
const normalizedStyles=styles.split('\r\n').join('\n');
assert.ok(normalizedStyles.includes('.cad-master-route-dock.cad-route-dock-r2>header,\n.cad-master-route-dock.cad-route-dock-r2>.engineering-quick-dock-head{display:none!important}'),'Route explanatory header must be hidden');

// Operations R3 must use entity/module styling rather than a sparse technical timeline.
assert.ok(ops.includes('class="ops-source-${nav}"'),'Operations source cards need module-aware styling');
assert.ok(ops.includes('entity-${e(c.entity_type)}'),'Change rows need entity-aware styling');

assert.equal(app,appMirror,'app mirror drift');
assert.equal(field,fieldMirror,'site-supervisor mirror drift');
assert.equal(eng,engMirror,'engineering mirror drift');
assert.equal(ops,opsMirror,'operations-center mirror drift');
assert.equal(styles,publicStyles,'public styles mirror drift');
assert.equal(styles,nextStyles,'Next styles mirror drift');
assert.equal(styles,platformStyles,'Platform styles mirror drift');

console.log('PASS Point 9 Site Supervisor Workspace: scoped field role, drawing/takeoff/files/tasks integration, premium UI, Operations R3, and CAD board-first closure');
