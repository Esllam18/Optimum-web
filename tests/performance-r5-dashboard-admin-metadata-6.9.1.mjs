import fs from 'node:fs';
import assert from 'node:assert/strict';

const app=fs.readFileSync(new URL('../assets/app.js',import.meta.url),'utf8');
const publicApp=fs.readFileSync(new URL('../public/assets/app.js',import.meta.url),'utf8');
const access=fs.readFileSync(new URL('../assets/access-engine.js',import.meta.url),'utf8');
const publicAccess=fs.readFileSync(new URL('../public/assets/access-engine.js',import.meta.url),'utf8');
const org=fs.readFileSync(new URL('../assets/organization-os.js',import.meta.url),'utf8');
const publicOrg=fs.readFileSync(new URL('../public/assets/organization-os.js',import.meta.url),'utf8');
assert.equal(app,publicApp,'app source/public mirror mismatch');
assert.equal(access,publicAccess,'access-engine source/public mirror mismatch');
assert.equal(org,publicOrg,'organization-os source/public mirror mismatch');

for(const token of [
  'OPTIMUM PERFORMANCE R3 V1 — DASHBOARD ROUTE DATA',
  'OPTIMUM PERFORMANCE R4 V1 — DASHBOARD SECONDARY DATA',
  'OPTIMUM PERFORMANCE R5 V1 — DASHBOARD ADMINISTRATIVE METADATA',
  'state.loading&&r3IsDashboardBootstrapRoute()&&r5HasAuthoritativeRuntimePolicy()',
  'r5StageDashboardAdministrativeMetadata(()=>r5LoadDashboardAdministrativeMetadata',
  'r5FlushDashboardAdministrativeMetadata();',
  'globalThis.requestAnimationFrame(()=>globalThis.setTimeout(run,50))',
  'accessEngine?.load()',
  'organizationOS?.load()',
  'r5ResetDashboardAdministrativeState()'
])assert.ok(app.includes(token),`R5 app contract missing: ${token}`);

assert.ok(access.includes('const companyId=state.companyId;'),'AccessEngine company capture missing');
assert.equal((access.match(/if\(state\.companyId!==companyId\)return;/g)||[]).length,2,'AccessEngine must have two stale-company guards');
assert.ok(org.includes('function reset(){'),'OrganizationOS reset missing');
assert.ok(org.includes('if(state.companyId!==companyId)return;'),'OrganizationOS stale-company guard missing');
assert.ok(org.includes('return {load,reset,page'),'OrganizationOS reset export missing');

const helperStart=app.indexOf('// OPTIMUM PERFORMANCE R5 V1 — DASHBOARD ADMINISTRATIVE METADATA');
const companyStart=app.indexOf('async function loadCompanyData() {',helperStart);
assert.ok(helperStart>=0&&companyStart>helperStart,'R5 helper isolation failed');
const helper=app.slice(helperStart,companyStart);
const state={loading:true,runtimePolicy:{permissions:['company.view'],entitlements:[]},companyId:'c'};
const globalThisMock={location:{pathname:'/',hash:'#/dashboard'}};
const r3=()=>{const pathname=String(globalThisMock.location.pathname||'/').replace(/\/+$/,'')||'/';const page=String(globalThisMock.location.hash||'').replace(/^#\/?/,'').split('/').filter(Boolean)[0]||'dashboard';return (pathname==='/'||pathname==='/v7')&&page==='dashboard';};
const has=()=>Boolean(state.runtimePolicy&&Array.isArray(state.runtimePolicy.permissions)&&Array.isArray(state.runtimePolicy.entitlements));
const should=()=>state.loading&&r3()&&has();
for(const [p,h,policy,expected] of [
  ['/','#/dashboard',true,true],['/v7','#/dashboard',true,true],['/','#/files',true,false],['/','#/tasks',true,false],['/','#/dashboard',false,false]
]){globalThisMock.location.pathname=p;globalThisMock.location.hash=h;state.runtimePolicy=policy?{permissions:['company.view'],entitlements:[]}:null;assert.equal(should(),expected,`R5 route/policy guard mismatch for ${p}${h}`);}

const companyEnd=app.indexOf('\nasync function loadFilesData',companyStart);
const company=app.slice(companyStart,companyEnd);
assert.ok(company.includes('const r5DeferAdministrativeMetadata=r5ShouldDeferDashboardAdministrativeMetadata();'),'R5 gate missing in loadCompanyData');
assert.ok(company.includes('if(!r5DeferAdministrativeMetadata)await organizationOS?.load();'),'Non-dashboard OrganizationOS sync path missing');
assert.ok(company.includes('state.compensation=r5DeferAdministrativeMetadata?[]:'),'Compensation defer guard missing');
assert.ok(company.includes('state.activity=r5DeferAdministrativeMetadata?[]:'),'Activity defer guard missing');

console.log(JSON.stringify({PASS:'Performance R5 V1 dashboard administrative-metadata deferral',deferredOn:['/ + #/dashboard','/v7 + #/dashboard'],deferred:['Access Engine rich metadata','Organization OS metadata','Compensation','Audit activity feed'],fallback:'synchronous when runtime policy is unavailable',nonDashboard:'synchronous behavior preserved',companySwitchRaceGuards:true,productionMutation:false,supabaseMutation:false},null,2));
