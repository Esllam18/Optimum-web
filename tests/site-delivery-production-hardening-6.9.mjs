import fs from 'node:fs';
import assert from 'node:assert/strict';

const read=p=>fs.readFileSync(p,'utf8');
const app=read('assets/app.js');
const publicApp=read('public/assets/app.js');
const css=read('assets/styles.css');
const migration=read('supabase/migrations/20260812123851_phase6_9_site_delivery_production_hardening.sql');
const claimCore=read('supabase/migrations/20260815215000_point9_10_consolidated_home_site_claim_package.sql');
const claimSeed=read('supabase/migrations/20260815220500_point9_10_site_claim_future_seed_fix.sql');
const pkg=JSON.parse(read('package.json'));

assert.equal(pkg.version,'6.9.0');
assert.equal(app,publicApp,'root/public app drift');
for(const peer of ['public/assets/styles.css','app/globals.css','platform-console/assets/styles.css']) assert.equal(css,read(peer),`styles drift: ${peer}`);

// Client: race-safe, truthful archived context, editable requirement authoring, and lifecycle controls.
for(const needle of [
  'deliveryDetailEpoch','activeClaimPackage','delivery-readonly-banner','claim-site-package-hero','claim-phase-boundary','claim-missing-panel','claim-primary-action-bar','claim-status-warning',
  'edit-claim-requirement','ready_count','version_ready','invalid_items','context_read_only','createStoredZip','MANIFEST.json','INDEX.html'
]) assert.ok(app.includes(needle),`delivery client hardening missing ${needle}`);
for(const category of ['commercial','technical','quantity','handover','approval','evidence','supporting']) assert.ok(app.includes(`['${category}'`),`existing requirement category not preserved: ${category}`);
for(const action of ['new-cabinet','edit-cabinet','archive-cabinet','reactivate-cabinet','add-claim-requirement','edit-claim-requirement','prepare-site-claim','download-site-claim','print-site-claim-index','classify-document-claim','submit-claim']) assert.ok(app.includes(`'${action}'`),`action policy missing ${action}`);

// UI: premium site-claim/read-only treatment must be present and responsive.
for(const cls of ['.delivery-readonly-banner','.claim-status-warning','.claim-site-package-hero','.claim-phase-boundary','.claim-scope-summary','.claim-missing-panel','.claim-primary-action-bar','.claim-requirement-head-actions']) assert.ok(css.includes(cls),`delivery style missing ${cls}`);
assert.match(css,/\.claim-scope-summary\{[^}]*display:grid/);
assert.match(css,/@media\(max-width:760px\)/s);

// Backend: read models must expose context capability and readiness aligned with freeze semantics.
for(const needle of [
  'create or replace function public.site_claim_package_360','context_read_only','ready_count','version_ready','invalid_items',
  "v.upload_state='ready'",'create or replace function public.cabinet_360','create or replace function public.site_360'
]) assert.ok(migration.includes(needle),`delivery read-model hardening missing ${needle}`);


// Clarified Site Claim Package: canonical CDE references, explicit inclusion, frozen versions and export manifest/ZIP.
for(const needle of [
  'claim_inclusion_mode','claim_requirement_key','site_claim_exports','set_document_claim_classification',
  'refresh_site_claim_package_v2','site_claim_package_export_manifest','record_site_claim_export',
  "'work_order_statement'","'quantity_survey'","'test_sheet'","'quality_certificate'","'warranty_certificate'","'invoice'"
]) assert.ok(claimCore.includes(needle),`site claim package core missing ${needle}`);
for(const needle of ['ensure_default_site_claim_package','work_order_statement','test_sheet','invoice']) assert.ok(claimSeed.includes(needle),`future site claim seed missing ${needle}`);
assert.ok(claimCore.includes('enable row level security'),'claim export history must be protected by RLS');
assert.ok(claimCore.includes("grant execute on function public.set_document_claim_classification"),'classification RPC must be granted explicitly');
assert.ok(claimCore.includes("revoke all on function app_private.site_claim_requirement_for_document"),'private classifier must not be client callable');

// Every mutating claim/cabinet path must seal archived contexts.
for(const fn of [
  'save_site_claim_requirement','add_document_to_site_claim','remove_site_claim_item','auto_collect_site_claim',
  'freeze_site_claim_package','reopen_site_claim_package','submit_site_claim_package','archive_site_cabinet'
]) {
  const start=migration.indexOf(`create or replace function public.${fn}`);
  assert.ok(start>=0,`migration missing ${fn}`);
  const next=migration.indexOf('create or replace function public.',start+30);
  const block=migration.slice(start,next<0?migration.length:next);
  assert.ok(block.includes('app_private.project_context_operational'),`${fn} missing archived-context guard`);
}
assert.ok(migration.includes('Document does not have a ready current version'),'manual claim inclusion must reject unfinished uploads');
assert.ok(migration.includes('Frozen package contains invalid pinned versions'),'submission must validate pinned versions');
assert.ok(migration.includes("from public,anon"),'RPC grants must explicitly revoke anon/public access');

console.log('Phase 6.9 Site Delivery production hardening checks passed.');
