import fs from 'node:fs';
import path from 'node:path';

const root=path.resolve(path.dirname(new URL(import.meta.url).pathname),'..');
const read=(p)=>fs.readFileSync(path.join(root,p),'utf8');
const app=read('assets/app.js');
const access=read('assets/access-engine.js');
const org=read('assets/organization-os.js');
const css=read('assets/styles.css');
const failures=[];
const expect=(ok,label)=>{if(!ok)failures.push(label);};
const has=(src,...parts)=>parts.every((p)=>src.includes(p));

expect(has(app,"const projectViewKey = 'optimum.projects.view.v3'",'function parseAppRoute()','setEntityRoute','restoreEntityWorkspaceFromRoute'),'deep-link Project/Site/Cabinet route contract');
expect(has(app,'function openWorkspace({title,subtitle=\'\',body=\'\',kind=\'\',id=\'\'})','entity-workspace-wrap','close-entity-workspace'),'full 360 workspace surface');
expect(has(css,'.entity-workspace-body{min-height:0;overflow-y:auto','.entity-workspace{','.entity-breadcrumbs'),'viewport-safe workspace scroll');
expect(has(app,'function projectsPage()','project-portfolio-toolbar','project-view-toggle','project-portfolio-attention'),'decision-first project portfolio');
expect(has(app,'function projectCard(p)','pdc-project-card')&&has(app,'data-action="project-view"','project-view-${e(state.projectView)}'),'project cards/list view contract');
expect(has(app,'async function openProjectDetails(id,{syncRoute=true}={})','project360-context','project-pulse-grid','project-relationship-tree','Project → Site → Cabinet'),'Project 360 operating context');
expect(has(app,"...(can('tasks.view')?", "...(can('files.view')?", "can('drawings.view')"),'permission-filtered project counts and actions');
expect(has(app,'async function openSiteDetails(id,{syncRoute=true}={})','site-context-hero','site-pulse-grid','site-cabinets-panel','delivery-unit-card'),'Site 360 operating context');
expect(has(app,'async function openCabinetDetails(id,{syncRoute=true}={})','cabinet-context-hero','cabinet-record-grid','cabinet-context-explainer'),'Cabinet 360 operating record');
expect(has(app,"cabinetTypeLabel","كابينة ألياف","كابينة توزيع","كابينة شارع"),'localized cabinet types');
expect(has(app,"cabinetFolderLabel","الرسومات ورسومات التنفيذ النهائية","الحصر والكميات والمستخلصات","الشهادات والفحص والتسليم"),'localized cabinet record areas');
expect(has(app,'function openProjectDialog(project=null)','entity-blueprint-section','Ownership & lifecycle','Schedule & progress'),'Project create/edit information architecture');
expect(has(app,'function openSiteDialog(projectId,site=null)','Advanced location details','entity-form-footer'),'Site create/edit information architecture');
expect(has(app,'function openCabinetDialog(siteId,cabinet=null)','cabinet-seed-note-calm','Cabinet workspace is auto-provisioned'),'Cabinet create/edit information architecture');
expect(has(app,'function setBusy(form, busy)','form-operation-status','aria-busy'),'immediate form operation feedback');
expect(has(css,'.form-operation-status{position:sticky','form[aria-busy="true"]'),'visible operation feedback CSS');
expect(has(org,'async function member360(id)','member360-dialog','member360-loading',"can('audit.view')?`<button"),'centered Member 360 and permission-aware Activity tab');
expect(has(css,'.member360-dialog.dialog-lg','.member360-dialog .dialog-body{overflow-y:auto'),'Member 360 scroll contract');
expect(has(access,'async function viewAsUser(id)','access-preview-dialog','access-preview-v2','access-preview-secondary'),'redesigned effective-access preview');
expect(has(access,'function validateScopeRows(form)','scope-row-invalid','scope-inline-error','scope_target'),'inline role scope validation before RPC');
expect(has(access,'member-access-advanced')||has(app,'member-access-advanced'),'member creation advanced access UI');
expect(has(css,'html[lang="ar"] .permission-technical-key{display:none}'),'Arabic mode hides technical permission keys');
expect(has(app,"engineering:L('الهندسة','Engineering')",'brandingChoiceLabel','payFrequencyLabel'),'Arabic localization helpers for modules and settings choices');
expect(has(app,'function navAllowed(page)','companyNav.filter(([p])=>keys.includes(p)&&navAllowed(p))'),'permission-aware navigation hiding');
expect(has(app,'global_search',".filter((row)=>{const target=globalEntityMeta(row.entity_type).route;return !target||navAllowed(target);})"),'permission-aware global-search result filtering');
expect(has(css,'@media(max-width:760px)','height:100dvh','grid-template-columns:1fr'),'mobile composition contract');

for (const mirror of ['public/assets/app.js','public/assets/access-engine.js','public/assets/organization-os.js','public/assets/styles.css']) {
  expect(fs.existsSync(path.join(root,mirror)),`runtime mirror exists: ${mirror}`);
}

if(failures.length){console.error(`FAIL Point 3 premium: ${failures.length} contract(s)`);failures.forEach((x)=>console.error(` - ${x}`));process.exit(1);}
console.log('PASS Point 3: Project 360 / Site 360 / Cabinet 360 + Point 2 carry-over contracts verified');
