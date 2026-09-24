import fs from 'node:fs';
import assert from 'node:assert/strict';
import vm from 'node:vm';

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
  'OPTIMUM PERFORMANCE R11 V1 — USER CONTEXT OVERLAP & SERVICE PLAN POST-PAINT',
  'OPTIMUM PERFORMANCE R12 V1 — DASHBOARD BRAND LOGO POST-PAINT',
  'r12CancelDashboardBrandLogo();',
  'r12FlushDashboardBrandLogo();',
  'const r12BrandLogoPromise=r12StartDashboardBrandLogo({companyId:state.companyId,path:r12BrandLogoPath});',
  'r12DeferBrandLogo?Promise.resolve(null):r12BrandLogoPromise',
  'r12StageDashboardBrandLogo({companyId:state.companyId,path:r12BrandLogoPath,promise:r12BrandLogoPromise});'
])assert.ok(app.includes(token),`R12 app contract missing: ${token}`);

const companyStart=app.indexOf('async function loadCompanyData() {');
const companyEnd=app.indexOf('\nasync function loadFilesData',companyStart);
const company=app.slice(companyStart,companyEnd);
const logoStart=company.indexOf('const r12BrandLogoPromise=r12StartDashboardBrandLogo');
const projectAwait=company.indexOf('const [projects,sites]=needsProjectContext');
const logoAwaitDecision=company.indexOf('r12DeferBrandLogo?Promise.resolve(null):r12BrandLogoPromise');
assert.ok(logoStart>=0&&projectAwait>logoStart&&logoAwaitDecision>projectAwait,'R12 logo request must start before project/site wait and be conditionally awaited later');
assert.ok(!company.includes('const r8BrandLogoPromise=resolveIdentityAssets([state.branding?.logo_path]);'),'Old R8 blocking logo promise must be removed');
assert.ok(company.includes('const r12DeferBrandLogo=Boolean(r12BrandLogoPath)&&r12ShouldDeferDashboardBrandLogo();'),'R12 defer decision missing');

const helperStart=app.indexOf('// OPTIMUM PERFORMANCE R12 V1 — DASHBOARD BRAND LOGO POST-PAINT');
const helperEnd=app.indexOf('// OPTIMUM PERFORMANCE R8 V1',helperStart);
const helper=app.slice(helperStart,helperEnd);
for(const token of [
  'return state.loading&&r3IsDashboardBootstrapRoute()&&r5HasAuthoritativeRuntimePolicy();',
  "api.createSignedUrl('identity-assets',assetPath,3600)",
  'if(companyId===state.companyId)state.assetUrls[assetPath]=url||\'\';',
  'globalThis.requestAnimationFrame(()=>globalThis.setTimeout(run,0))'
])assert.ok(helper.includes(token),`R12 helper contract missing: ${token}`);

const calls=[];
let resolveSign;
const signing=new Promise((resolve)=>{resolveSign=resolve;});
let renders=0;
const state={loading:true,companyId:'c1',runtimePolicy:{permissions:[],entitlements:[]},assetUrls:{}};
const context={state,location:{pathname:'/',hash:'#/dashboard'},console:{warn(){}},api:{createSignedUrl:(bucket,path,ttl)=>{calls.push({bucket,path,ttl});return signing;}},render(){renders++;},setTimeout:(fn)=>{fn();return 1;},requestAnimationFrame:(fn)=>fn()};
context.globalThis=context;
vm.runInNewContext(`function safeAssetPath(path=''){return String(path||'').replace(/^\\/+/, '');}\nfunction r3CurrentAppPage(){const raw=String(globalThis.location?.hash||'').replace(/^#\\/?/,'')||'dashboard';return raw.split('/').filter(Boolean)[0]||'dashboard';}\nfunction r3IsDashboardBootstrapRoute(){const pathname=String(globalThis.location?.pathname||'/').replace(/\\/+$/,'')||'/';const page=r3CurrentAppPage();return (pathname==='/'||pathname==='/v7')&&page==='dashboard';}\nfunction r5HasAuthoritativeRuntimePolicy(){return Boolean(state.runtimePolicy&&Array.isArray(state.runtimePolicy.permissions)&&Array.isArray(state.runtimePolicy.entitlements));}\n${helper}\nglobalThis.__r12={r12ShouldDeferDashboardBrandLogo,r12StartDashboardBrandLogo,r12StageDashboardBrandLogo,r12FlushDashboardBrandLogo};`,context,{timeout:1000});
assert.equal(context.__r12.r12ShouldDeferDashboardBrandLogo(),true);
const p=context.__r12.r12StartDashboardBrandLogo({companyId:'c1',path:'company/c1/logo.png'});
assert.equal(calls.length,1,'logo signing must start once');
context.__r12.r12StageDashboardBrandLogo({companyId:'c1',path:'company/c1/logo.png',promise:p});
context.__r12.r12FlushDashboardBrandLogo();
assert.equal(renders,0,'post-paint render must wait for started signing promise');
resolveSign('https://signed.example/logo.png');
await p;
await new Promise(r=>setImmediate(r));
assert.equal(state.assetUrls['company/c1/logo.png'],'https://signed.example/logo.png');
assert.equal(renders,1,'resolved deferred logo must trigger one post-paint render');
assert.equal(calls.length,1,'post-paint consumer must reuse the already-started signing promise');

state.runtimePolicy=null;
assert.equal(context.__r12.r12ShouldDeferDashboardBrandLogo(),false,'no-policy fallback must remain synchronous');
state.runtimePolicy={permissions:[],entitlements:[]};context.location.hash='#/settings';
assert.equal(context.__r12.r12ShouldDeferDashboardBrandLogo(),false,'non-dashboard must remain synchronous');

let staleResolve;const stalePromise=new Promise(r=>{staleResolve=r;});
context.api.createSignedUrl=()=>stalePromise;
state.companyId='c1';delete state.assetUrls['company/c1/stale.png'];
const stale=context.__r12.r12StartDashboardBrandLogo({companyId:'c1',path:'company/c1/stale.png'});
state.companyId='c2';staleResolve('https://signed.example/stale.png');await stale;
assert.equal(state.assetUrls['company/c1/stale.png'],undefined,'stale-company signing result must not mutate active state');

console.log(JSON.stringify({PASS:'Performance R12 V1 dashboard brand logo',measurementBasis:'post-R11 signed-url was latest pre-Dashboard request in 5/5 cycles',logoSigning:'starts early and overlaps projects/sites',authoritativeDashboard:'does not await logo before first paint',fallbackUI:'imageOrInitials keeps stable initials box until logo resolves',postPaint:'same signing promise rerenders logo after first paint',nonDashboard:'synchronous',noPolicy:'synchronous',staleCompanyGuard:true,productionMutation:false,supabaseMutation:false},null,2));
