import fs from 'node:fs';
import assert from 'node:assert/strict';

const app=fs.readFileSync('assets/app.js','utf8');
const appMirror=fs.readFileSync('public/assets/app.js','utf8');
const styles=fs.readFileSync('assets/styles.css','utf8');
const publicStyles=fs.readFileSync('public/assets/styles.css','utf8');
const nextStyles=fs.readFileSync('app/globals.css','utf8');
const platformStyles=fs.readFileSync('platform-console/assets/styles.css','utf8');
const operations=fs.readFileSync('assets/operations-center.js','utf8');
const migration=fs.readFileSync('supabase/migrations/20260815215000_point9_10_consolidated_home_site_claim_package.sql','utf8');

// Navigation consolidation: engines survive, standalone navigation duplication does not.
for(const marker of [
  "requestedPage=parts[0]||'dashboard'",
  "const page=requestedPage;",
  'function dashboardHomeMode()',
  "if(mode==='field'&&siteSupervisor?.page)",
  'function dashboardControlSummary()',
  'function dashboardChangeDigest()',
  'project-control-inline-entry',
  'data-action="pc-weekly-brief"'
]) assert.ok(app.includes(marker),`Consolidated Home missing ${marker}`);
for(const forbidden of [
  "['operations','activity',()=>L('مركز التشغيل','Operations Center')]",
  "['field','hardHat',()=>L('مساحة الموقع','Field Workspace')]",
  "['control','activity',()=>L('التحكم بالمشاريع','Project Control')]"
]) assert.ok(!app.includes(forbidden),`Duplicate standalone navigation remains: ${forbidden}`);

assert.ok(operations.includes('state:local'),'role-aware Home must be able to read the canonical Operations snapshot');

// Site claim package current phase: classification + canonical links + frozen export ZIP.
for(const marker of [
  'claim-upload-classification','claim_mode','claim_requirement',
  'set_document_claim_classification','refresh_site_claim_package_v2','site_claim_package_export_manifest','record_site_claim_export',
  'prepareSiteClaimPackage','buildSiteClaimPackageZip','createStoredZip','claimManifestIndexHtml','MANIFEST.json','INDEX.html',
  'prepare-site-claim','download-site-claim','print-site-claim-index','classify-document-claim',
  "L('تجهيز حزمة المستخلص','Prepare claim package')",
  "L('هذه المرحلة لتجميع المستندات فقط','This phase is document assembly only')",
  "L('لا أسعار، لا بنود تعاقدية، ولا إنشاء فاتورة تلقائيًا.",
  "L('مستخلصات المواقع','Site Claim Packages')"
]) assert.ok(app.includes(marker),`Site claim package UI/runtime missing ${marker}`);

for(const marker of [
  "add column if not exists claim_inclusion_mode",
  "add column if not exists claim_requirement_key",
  'create table if not exists public.site_claim_exports',
  'alter table public.site_claim_exports enable row level security',
  'create or replace function app_private.site_claim_requirement_for_document',
  'create or replace function public.set_document_claim_classification',
  'create or replace function public.refresh_site_claim_package_v2',
  'create or replace function public.site_claim_package_export_manifest',
  'create or replace function public.record_site_claim_export',
  "('work_order_statement','بيان أمر التكليف'",
  "('quantity_survey','الحصر'",
  "('test_sheet','Test Sheet'",
  "('quality_certificate','شهادة الجودة'",
  "('warranty_certificate','شهادة الضمان'",
  "('invoice','الفاتورة'",
  "d.site_id is null or cp.site_id=d.site_id",
  'selected_version_id',
  'ready_for_export'
]) assert.ok(migration.includes(marker),`Site claim migration missing ${marker}`);

// Current scope is document assembly only — no commercial price/rate engine should be introduced here.
for(const forbidden of [/unit_rate/i,/unit_price/i,/vat_amount/i,/discount_amount/i,/commercial_total/i,/invoice_total/i])
  assert.ok(!forbidden.test(migration),`Commercial pricing must not be added in current claim phase: ${forbidden}`);

for(const marker of [
  '.role-aware-home','.home-control-summary','.home-change-list','.project-control-inline-entry',
  '.claim-upload-classification','.claim-site-package-hero','.claim-scope-summary','.claim-missing-panel',
  '.claim-primary-action-bar','.claim-export-history'
]) assert.ok(styles.includes(marker),`Core 9–10 premium CSS missing ${marker}`);

assert.equal(app,appMirror,'app mirror drift');
assert.equal(styles,publicStyles,'public styles mirror drift');
assert.equal(styles,nextStyles,'Next styles mirror drift');
assert.equal(styles,platformStyles,'Platform styles mirror drift');



const hardening=fs.readFileSync('supabase/migrations/20260815220500_point9_10_site_claim_future_seed_fix.sql','utf8');
assert.ok(hardening.includes('ensure_default_site_claim_package'),'future sites must receive the clarified claim-package seed');
for(const key of ['work_order_statement','test_sheet','quality_certificate','warranty_certificate','invoice'])
  assert.ok(hardening.includes(`'${key}'`),`future claim seed missing ${key}`);
assert.ok(hardening.includes("requirement_key in('contract','sketches','handover_certificate','approvals','photos')"),'legacy requirements must not become required again for future sites');
assert.ok(app.includes("item.mode!=='version'"),'new document versions must not silently reset claim classification');

console.log('PASS Core Point 9–10: role-aware Home consolidation + CDE-native site claim package assembly, frozen versions, Index/Manifest/ZIP, no commercial pricing');
