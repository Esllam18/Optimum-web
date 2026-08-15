import fs from 'node:fs';
import assert from 'node:assert/strict';

const app=fs.readFileSync('assets/app.js','utf8');
const css=fs.readFileSync('assets/styles.css','utf8');
const sql=fs.readFileSync('supabase/migrations/20260815031000_point5_document_cde_core.sql','utf8');
const pkg=JSON.parse(fs.readFileSync('package.json','utf8'));

const appMarkers=[
  'function filesPage()','cde-onboarding','cde-home-tabs','cde-requirements-summary',
  'openCdeArchitectureManager','openFolderTemplateEditor','save_folder_template_v2','apply_folder_template',
  'begin_document_upload_v2','begin_new_version_upload_v2','storage_path','uploadReserved',
  'function openDocumentDetails','Versions & revisions','restoreDocumentVersion','openVersionComparison',
  'document_requirements_snapshot','update_document_metadata','cde-selection-bar','openBulkMoveDocuments'
];
for(const marker of appMarkers) assert.ok(app.includes(marker),`missing Point 5 client contract: ${marker}`);

const cssMarkers=[
  '.cde-onboarding','.cde-attention-strip','.cde-home-tabs','.cde-requirements-summary',
  '.cde-template-grid','.cde-builder-help','.cde-drop-zone','.upload-review-row',
  '.document-facts','.version-history-guide','.cde-version-compare','.cde-selection-bar'
];
for(const marker of cssMarkers) assert.ok(css.includes(marker),`missing Point 5 premium style: ${marker}`);

const sqlMarkers=[
  'Optimum Engineering Core','Telecom / Fiber Delivery','Construction Control & Handover','Lean Project Starter',
  "'اسكتشات','Sketches'","'تخطيط','Planning'","'مدني','Civil'","'كهرباء','Electrical'","'مدني وكهرباء','Civil & Electrical'","'As-Built','As-Built'",
  'folder_template_catalog','save_folder_template_v2','apply_folder_template','document_requirements','document_requirement_links',
  'begin_document_upload_v2','begin_new_version_upload_v2','revision_code','restored_from_version_id',
  'storage_bucket text,storage_path text','document_360','document_requirements_snapshot'
];
for(const marker of sqlMarkers) assert.ok(sql.includes(marker),`missing Point 5 database contract: ${marker}`);


assert.ok(sql.includes('drop function if exists public.document_directory_query(uuid,integer);'),'directory return-shape migration must drop the old same-signature RPC before recreation');
assert.ok(sql.includes('app_private.apply_document_requirements_missing'),'folder templates must instantiate their evidence/requirements foundation');
assert.match(sql,/instantiate_default_folders[\s\S]{0,1800}apply_document_requirements_missing/,'new project/site folder instantiation must include document requirements');
assert.match(sql,/begin_document_upload_v2[\s\S]{0,1200}Authentication required[\s\S]{0,700}Original filename is invalid/,'new document upload must validate authentication and filenames before storage reservation');
assert.match(sql,/begin_new_version_upload_v2[\s\S]{0,900}Authentication required[\s\S]{0,500}Original filename is invalid/,'new-version upload must validate authentication and filenames before storage reservation');
assert.doesNotMatch(sql,/current_setting\('request\.headers'[\s\S]{0,160}folder_template_nodes/,'template folder persistence must not depend on request-language headers');

assert.match(app,/v\.storage_path\?`<button class="icon-btn" data-action="preview-version"/,'historical open must require a real storage path');
assert.match(app,/v\.storage_path\?[\s\S]{0,500}data-action="download-version"/,'historical download must require a real storage path');
assert.match(app,/p_restored_from_version_id:v\.id/,'restore must preserve its historical source');
assert.match(app,/await fetch\(url\)[\s\S]{0,500}begin_new_version_upload_v2/,'restore must read old bytes then reserve a new version');
assert.match(app,/await uploadReserved\(file,reservation/,'restore/upload must use the real storage upload pipeline');
assert.doesNotMatch(app,/fake upload|mock upload|simulate upload/i,'Point 5 must not contain fake upload UI paths');
assert.deepEqual(Object.keys(pkg.dependencies||{}).sort(),['next','react','react-dom'],'Point 5 must not add runtime dependencies beyond the existing app shell');

console.log('PASS Point 5 Document & CDE Core: templates, novice UX, real storage, version history/restore, requirements, and premium UI contracts verified');
