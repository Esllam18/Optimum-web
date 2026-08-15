import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {join} from 'node:path';

const root=fileURLToPath(new URL('..',import.meta.url));
const read=(p)=>readFile(join(root,p),'utf8');
const app=await read('assets/app.js');
const css=await read('assets/styles.css');
const org=await read('assets/organization-os.js');
const access=await read('assets/access-engine.js');
const roleHardening=await read('supabase/migrations/20260814165217_point2_legacy_role_delegation_hardening.sql');
const pkg=JSON.parse(await read('package.json'));
const fn=(source,name)=>{const start=source.indexOf(`function ${name}(`);assert.ok(start>=0,`Missing function ${name}`);const end=source.indexOf('\nfunction ',start+10);return source.slice(start,end<0?source.length:end);};
const team=fn(app,'teamPage');
const roles=fn(app,'rolesPage');
const settings=fn(app,'settingsPage');
const settingsHome=fn(app,'settingsOverviewPanel');
const accessHealth=fn(app,'settingsAccessHealthPanel');
const roleEditor=fn(app,'roleEditorDialog');
const roleLive=fn(app,'updateRoleEditorLive');
const roleDraft=fn(access,'openRoleDraft');
const roleDraftLive=fn(access,'updateRoleDraftImpact');
const accessChange=fn(access,'handleChange');
const orgPage=fn(org,'page');
const roleInsights=fn(org,'roleInsights');
const roleSummary=fn(access,'rolesSummary');

assert.equal(pkg.version,'6.9.0','Premium organization/access must remain on the 6.9 runtime line');

// 1–4 Team: people-first directory, contextual detail, explicit access model.
for(const c of ['team-directory-shell','team-directory-toolbar-v2','team-person-row','team-more-filters','teamUnitFilter','teamAccessFilter','org-attention-queue','custom-access-chip','owner-protection-chip']) assert.ok(app.includes(c),`Missing Team V2 contract: ${c}`);
assert.ok(!team.includes('team-overview-strip'),'Team must not restore decorative KPI strips');
assert.ok(!team.includes('team-member-facts'),'Daily directory must not preload manager/access fact blocks');
assert.ok(team.includes("savedViewControls('team')"),'Saved views remain supported under More filters');
assert.ok(css.includes('content-visibility:auto'),'Large people/role lists must use browser rendering containment');

// 5 Member 360: one source of truth, four intent tabs; Access Editor is a subordinate edit surface.
for(const c of ['MEMBER 360°','member360-tabs','data-member360-panel="overview"','data-member360-panel="access"','data-member360-panel="organization"','data-member360-panel="activity"','orgos-member-tab','member360-protection']) assert.ok(org.includes(c),`Missing Member 360 V2 contract: ${c}`);
assert.ok(access.includes("L('محرر الوصول','ACCESS EDITOR')"),'Access 360 duplication must be renamed to Access Editor');
assert.ok(org.includes("L('آخر مالك محمي','Last owner protected')"),'Last owner protection must be visible before mutation');

// 6–7 Organization / Unit 360: structure is primary; attention is conditional.
for(const c of ['Organization items need a decision','organizationChart()','UNIT 360','unit360-v2','units without manager']) assert.ok(org.includes(c),`Missing Organization V2 contract: ${c}`);
assert.ok(!orgPage.includes('orgos-kpis'),'Organization page must not duplicate people KPIs');
assert.ok(!orgPage.includes('orgos-readiness'),'Organization structure must not open with a decorative readiness card');
assert.ok(roleInsights.includes('orgos-insights'),'Deep access findings remain available on demand');

// 8–11 Roles: capability-first cards, custom/system distinction, usage and impact preview.
for(const c of ['roleCapabilityLevel','role-capability-card','role-capability-grid','System protected','Custom','role-impact-mini']) assert.ok(app.includes(c),`Missing capability-first role contract: ${c}`);
assert.ok(!roles.includes('role-overview-strip'),'Roles must not restore decorative KPI strips');
assert.ok(!roles.includes('role-stats-calm'),'Role cards must not lead with raw permission/module counts');
for(const c of ['data-role-impact','members affected','No members are affected yet','permission changes']) assert.ok(app.includes(c)||access.includes(c),`Missing live impact preview contract: ${c}`);
// The production role path is AccessEngine Draft → Impact → Publish. Keep the legacy app editor as a compatibility fallback only.
assert.ok(roleDraft.includes('data-role-impact'),'Real role draft editor must render impact preview');
assert.ok(roleDraft.includes('updateRoleDraftImpact'),'Real role draft editor must initialize impact preview');
assert.ok(roleDraftLive.includes('removed')&&roleDraftLive.includes('added'),'Real role draft impact must compare old and new permissions');
assert.ok(roleDraftLive.includes('role-impact-delta')&&roleDraftLive.includes('permissionLabel'),'Live impact preview must name changed permissions, not only count them');
assert.ok(accessChange.includes('access55-role-draft')&&accessChange.includes('updateRoleDraftImpact'),'Permission checkbox changes must refresh the real role-draft impact preview');
assert.ok(roleEditor.includes('data-role-impact')&&roleLive.includes('removed'),'Legacy role editor fallback must remain compatible until its route is retired explicitly');

// 12–15 Settings remains configuration-only and split Personal / Organization.
for(const c of ['settings-command-center','settings-nav-group','Personal','Organization']) assert.ok(settings.includes(c),`Missing Settings IA contract: ${c}`);
for(const c of ['My settings','Organization settings','settings-home-grid']) assert.ok(settingsHome.includes(c),`Missing Settings home separation: ${c}`);
assert.ok(!settingsHome.includes('settings-insight-grid'),'Settings must not become another KPI dashboard');
for(const c of ['access-governance-heading','access-governance-launchpad','access-protection-chip']) assert.ok(accessHealth.includes(c),`Missing human-readable access governance contract: ${c}`);
for(const c of ['branding-workbench','brand-live-preview','data-live-settings=\"branding\"','Live preview']) assert.ok(app.includes(c),`Missing live branding workbench contract: ${c}`);
for(const c of ['access55-governance','Second approval for high-risk access','Second approval for offboarding','save_access_governance_settings']) assert.ok(access.includes(c),`Missing human-readable security governance contract: ${c}`);

// 16–18 Attention, bulk on selection, performance and integration.
assert.ok(team.includes('orgos-bulk-bar')||app.includes('organizationOS?.bulkBar()'),'Bulk actions must remain contextual and selection-driven');
assert.ok(app.includes("broadcastOrganizationChange('roles')")||app.includes('broadcastOrganizationChange'),'Organization/access changes must continue cross-session integration');
assert.ok(org.includes('organization_runtime_revision')&&org.includes('syncRemote'),'Cross-session organization revision sync must remain intact');
for(const c of ['access-role-tools-v2','No pending access reviews']) assert.ok(roleSummary.includes(c),`Role tooling must stay quiet when no action is pending: ${c}`);

// 19 Responsive composition and drawers.
for(const c of ['@media(max-width:900px)','@media(max-width:640px)','.team-person-row','.member360-identity','.role-capability-grid','.team-more-panel']) assert.ok(css.includes(c),`Missing Point 2 responsive guard: ${c}`);

// 20 Integration and safety contracts are not replaced by UI-only behavior.
for(const c of ['save_member_control_profile','canDelegateRoleClient','member_access_snapshot','access55-member','access55-offboard']) assert.ok(app.includes(c)||access.includes(c)||org.includes(c),`Missing organization integration contract: ${c}`);
assert.ok(access.includes('p_member:{role_id:data.role_id'),'Access Editor must submit the base role to the existing backend contract');
assert.ok(access.includes('require_second_approval_high_risk'),'High-risk access governance must remain enforced');

// Runtime mirrors are mandatory.
assert.equal(app,await read('public/assets/app.js'),'app runtime mirror drift');
assert.equal(org,await read('public/assets/organization-os.js'),'organization runtime mirror drift');
assert.equal(access,await read('public/assets/access-engine.js'),'access runtime mirror drift');
assert.equal(css,await read('public/assets/styles.css'),'public CSS mirror drift');
assert.equal(css,await read('app/globals.css'),'Next CSS mirror drift');
assert.equal(css,await read('platform-console/assets/styles.css'),'platform CSS mirror drift');


// Point 2 live security hardening: legacy compatibility RPCs must enforce the same delegation/protected-role invariants.
for(const rpc of ['create_company_role','update_company_role','replace_role_permissions','save_company_role_definition']) assert.ok(roleHardening.includes(`function public.${rpc}`),`Missing legacy role hardening for ${rpc}`);
assert.ok((roleHardening.match(/can_delegate_permissions/g)||[]).length>=4,'Every legacy role mutation path must enforce permission delegation');
assert.ok(roleHardening.includes("r.is_protected or r.slug='owner'")&&roleHardening.includes("v_is_protected or v_slug='owner'")&&roleHardening.includes("v_role.is_protected or v_role.slug='owner'"),'Legacy role mutation paths must protect all system/protected roles, not Owner only');

console.log('PASS Point 2 V2: 20 organization/team/roles/permissions/settings contracts verified');
