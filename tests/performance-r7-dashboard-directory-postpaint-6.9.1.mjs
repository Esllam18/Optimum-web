import fs from 'node:fs';
import assert from 'node:assert/strict';

const app=fs.readFileSync(new URL('../assets/app.js',import.meta.url),'utf8');
const publicApp=fs.readFileSync(new URL('../public/assets/app.js',import.meta.url),'utf8');
assert.equal(app,publicApp,'app source/public mirror mismatch');

for(const token of [
  'OPTIMUM PERFORMANCE R3 V1 — DASHBOARD ROUTE DATA',
  'OPTIMUM PERFORMANCE R4 V1 — DASHBOARD SECONDARY DATA',
  'OPTIMUM PERFORMANCE R5 V1 — DASHBOARD ADMINISTRATIVE METADATA',
  'OPTIMUM PERFORMANCE R6 V1 — DASHBOARD MANAGEMENT POST-PAINT',
  'OPTIMUM PERFORMANCE R7 V1 — DASHBOARD DIRECTORY POST-PAINT',
  'r7CancelDashboardDirectoryBootstrap();',
  'r7FlushDashboardDirectoryBootstrap();',
  'r7ShouldDeferDashboardDirectoryBootstrap()',
  'globalThis.requestAnimationFrame(()=>globalThis.setTimeout(run,150))',
  'r7RuntimePolicyPromise=loadRuntimePolicy()',
  'await r7RuntimePolicyPromise;',
  'r7ResetDashboardDirectoryState();',
  'r7StageDashboardDirectoryBootstrap({companyId:state.companyId,f,memberIds,roleIds,membershipIds});',
  'state.r7DashboardDirectoryReady!==false',
  'r7RouteNeedsDashboardDirectory(state.page)',
  'await r7EnsureDashboardDirectoryMetadata();'
])assert.ok(app.includes(token),`R7 app contract missing: ${token}`);

const companyStart=app.indexOf('async function loadCompanyData() {');
const companyEnd=app.indexOf('\nasync function loadFilesData',companyStart);
const company=app.slice(companyStart,companyEnd);
assert.ok(company.includes('const r7RuntimePolicyPromise=loadRuntimePolicy();'),'R7 policy overlap missing');
assert.ok(company.indexOf('const r7RuntimePolicyPromise=loadRuntimePolicy();')<company.indexOf('const [subs,roles,members,brandingRows]=await Promise.all(['),'Policy must start before essential company batch waits');
assert.ok(company.includes('const r7DeferDirectoryMetadata=r7ShouldDeferDashboardDirectoryBootstrap();'),'R7 defer decision missing');
assert.ok(company.includes("api.select('permissions',{order:'module.asc,key.asc'})"),'R7 permission fallback/deferred query missing');
assert.ok(company.includes("api.select('role_permissions'"),'R7 role permission query missing');
assert.ok(company.includes("api.select('member_permission_overrides'"),'R7 overrides query missing');
assert.ok(company.includes("api.select('account_security'"),'R7 member security query missing');
assert.ok(company.includes('Object.assign(state,{permissions,invitations,roleTemplates,roleTemplatePermissions,profiles,rolePermissions,overrides,memberSecurity,r7DashboardDirectoryReady:true});'),'Synchronous fallback assignment missing');

const helperStart=app.indexOf('// OPTIMUM PERFORMANCE R7 V1 — DASHBOARD DIRECTORY POST-PAINT');
const helperEnd=app.indexOf('async function loadCompanyData()',helperStart);
const helper=app.slice(helperStart,helperEnd);
for(const token of [
  "return state.loading&&r3IsDashboardBootstrapRoute()&&r5HasAuthoritativeRuntimePolicy();",
  "['team','roles','organization','settings','activity','operations']",
  'if(companyId!==state.companyId)return;',
  'if(r7DirectoryLoadPromise&&r7DirectoryLoadCompanyId===context.companyId)return r7DirectoryLoadPromise;',
  'await resolveIdentityAssets(profiles.map((item)=>item.avatar_path));'
])assert.ok(helper.includes(token),`R7 helper contract missing: ${token}`);

const route=app.slice(app.indexOf('async function activateRoute('),app.indexOf("window.addEventListener('hashchange'"));
assert.ok(route.includes('if(r7WaitForDirectory)await r7EnsureDashboardDirectoryMetadata();'),'R7 on-demand route hydration missing');

// Dashboard must not render a false organization-health warning while directory metadata is intentionally empty.
const signals=app.slice(app.indexOf('function dashboardDecisionSignals()'),app.indexOf('function dashboardTaskRow('));
assert.ok(signals.includes("state.r7DashboardDirectoryReady!==false"),'Dashboard health readiness guard missing');

console.log(JSON.stringify({PASS:'Performance R7 V1 dashboard directory post-paint',policyOverlap:true,deferredDirectory:['permissions','invitations','role templates','role-template permissions','profiles','role permissions','member overrides','member security'],authoritativePolicyOnly:true,onDemandHydration:['team','roles','organization','settings','activity','operations'],dashboardFalseWarningGuard:true,nonDashboard:'synchronous behavior preserved',fallbackWithoutRuntimePolicy:'synchronous',productionMutation:false,supabaseMutation:false},null,2));
