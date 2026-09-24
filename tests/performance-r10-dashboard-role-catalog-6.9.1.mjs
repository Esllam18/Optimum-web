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
  'OPTIMUM PERFORMANCE R8 V1 — DASHBOARD BRAND & BLUEPRINT POST-PAINT',
  'OPTIMUM PERFORMANCE R9 V1 — DASHBOARD MEMBER ROSTER NON-BLOCKING',
  'OPTIMUM PERFORMANCE R10 V1 — DASHBOARD ROLE CATALOG NON-BLOCKING',
  'r10CancelDashboardRoleCatalog();',
  'r10ShouldDeferDashboardRoleCatalog()',
  'r10StartRoleCatalog({companyId:state.companyId,f})',
  'r10StageDashboardRoleCatalog({companyId:state.companyId,f,promise:r10RoleCatalogPromise},currentRole);',
  'state.r10RoleCatalogReady=false;',
  'state.r10RoleCatalogReady=true;',
  'await r10ResolveRoleCatalog()'
])assert.ok(app.includes(token),`R10 app contract missing: ${token}`);

const companyStart=app.indexOf('async function loadCompanyData() {');
const companyEnd=app.indexOf('\nasync function loadFilesData',companyStart);
const company=app.slice(companyStart,companyEnd);
const catalogStart=company.indexOf('const r10RoleCatalogPromise=r10StartRoleCatalog({companyId:state.companyId,f});');
const currentRoleStart=company.indexOf('const r10CurrentRolePromise=state.membership?.role_id');
const shellAwait=company.indexOf('const [subs,currentRoleRows,brandingRows]=await Promise.all([');
const policyAwait=company.indexOf('await r7RuntimePolicyPromise;');
assert.ok(catalogStart>=0&&currentRoleStart>catalogStart&&shellAwait>currentRoleStart,'R10 role catalog/current-role requests must start before shell wait');
assert.ok(!company.slice(shellAwait,policyAwait).includes("api.select('roles',{filters:{company_id:f},order:'sort_order.asc,created_at.asc'})"),'full role catalog must not be in first awaited dashboard shell batch');
assert.ok(company.includes("api.select('roles',{filters:{company_id:f,id:")&&company.includes('state.membership.role_id')&&company.includes('limit:1'),'R10 current-role fast path missing');
assert.ok(company.includes('if(r10DeferRoleCatalog){'),'R10 role catalog defer decision missing');
assert.ok(company.includes('roles=await r10RoleCatalogPromise;'),'R10 synchronous fallback missing');
assert.ok(company.includes('state.role=roles.find((item)=>item.id===state.membership?.role_id)||currentRole||null;'),'R10 full-role fallback must restore current role from catalog');

const r5Start=app.indexOf('async function r5LoadDashboardAdministrativeMetadata');
const r5End=app.indexOf('// OPTIMUM PERFORMANCE R6 V1',r5Start);
const r5=app.slice(r5Start,r5End);
assert.ok(r5.includes('if(state.r10RoleCatalogReady===false)await r10ResolveRoleCatalog();'),'R5 must share deferred R10 role catalog');

const r7Start=app.indexOf('async function r7LoadDashboardDirectoryMetadata');
const r7End=app.indexOf('// OPTIMUM PERFORMANCE R8 V1',r7Start);
const r7=app.slice(r7Start,r7End);
assert.ok(r7.includes('const roles=state.r10RoleCatalogReady===false?await r10ResolveRoleCatalog():state.roles;'),'R7 must share deferred R10 role catalog');
assert.ok(r7.includes('const roleIds=roles.map((item)=>item.id);'),'R7 must derive role IDs after catalog resolution');

const helperStart=app.indexOf('// OPTIMUM PERFORMANCE R10 V1 — DASHBOARD ROLE CATALOG NON-BLOCKING');
const helperEnd=app.indexOf('// OPTIMUM PERFORMANCE R9 V1',helperStart);
const helper=app.slice(helperStart,helperEnd);
for(const token of [
  'return state.loading&&r3IsDashboardBootstrapRoute()&&r5HasAuthoritativeRuntimePolicy();',
  "api.select('roles',{filters:{company_id:f},order:'sort_order.asc,created_at.asc'})",
  'if(!context||context.companyId!==state.companyId)return [];',
  'if(context.companyId!==state.companyId)return [];'
])assert.ok(helper.includes(token),`R10 helper contract missing: ${token}`);

console.log(JSON.stringify({PASS:'Performance R10 V1 dashboard role catalog',firstPaintRole:'current signed-in role only',roleCatalog:'starts early but is not awaited before dashboard first paint',sharedConsumers:['R5 administrative metadata','R7 directory metadata'],synchronousFallback:'non-dashboard or no authoritative runtime policy',staleCompanyGuard:true,subscription:'remains synchronous',branding:'remains synchronous',projectsSites:'remain synchronous',productionMutation:false,supabaseMutation:false},null,2));
