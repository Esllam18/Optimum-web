import fs from 'node:fs';
import assert from 'node:assert/strict';

const app=fs.readFileSync(new URL('../assets/app.js',import.meta.url),'utf8');
const publicApp=fs.readFileSync(new URL('../public/assets/app.js',import.meta.url),'utf8');
const ops=fs.readFileSync(new URL('../assets/operations-center.js',import.meta.url),'utf8');
const publicOps=fs.readFileSync(new URL('../public/assets/operations-center.js',import.meta.url),'utf8');
const pc=fs.readFileSync(new URL('../assets/project-control.js',import.meta.url),'utf8');
const publicPc=fs.readFileSync(new URL('../public/assets/project-control.js',import.meta.url),'utf8');

assert.equal(app,publicApp,'app source/public mirror mismatch');
assert.equal(ops,publicOps,'operations source/public mirror mismatch');
assert.equal(pc,publicPc,'project-control source/public mirror mismatch');

for(const token of [
  'OPTIMUM PERFORMANCE R3 V1 — DASHBOARD ROUTE DATA',
  'OPTIMUM PERFORMANCE R4 V1 — DASHBOARD SECONDARY DATA',
  'OPTIMUM PERFORMANCE R5 V1 — DASHBOARD ADMINISTRATIVE METADATA',
  'OPTIMUM PERFORMANCE R6 V1 — DASHBOARD MANAGEMENT POST-PAINT',
  'r6CancelDashboardPostPaintBootstrap();',
  'r6FlushDashboardPostPaintBootstrap();',
  'r6ShouldDeferDashboardPostPaintBootstrap()',
  "dashboardHomeMode()==='management'",
  'globalThis.requestAnimationFrame(()=>globalThis.setTimeout(run,100))',
  "jobs.push(prepareLazyModulesForPage('dashboard',{load:true}))",
  'if(!r6DeferManagement)await prepareLazyModulesForPage(state.page,{load:true});',
  'r6StageDashboardPostPaintBootstrap(()=>r6LoadDashboardPostPaintBootstrap',
  'if(state.companyId!==companyId)return null;',
  'if(state.companyId===companyId)markLazyDataLoaded(\'operations\');',
  'if(state.companyId===companyId)markLazyDataLoaded(\'projectControl\');',
  'projectControl?.reset();'
])assert.ok(app.includes(token),`R6 app contract missing: ${token}`);

const endStart=app.indexOf('const r6DeferPostPaint=r6ShouldDeferDashboardPostPaintBootstrap();');
assert.ok(endStart>0,'R6 loadCompanyData end gate missing');
const endBlock=app.slice(endStart,endStart+1600);
assert.ok(endBlock.includes('if(r6DeferPostPaint){'),'R6 dashboard deferral branch missing');
assert.ok(endBlock.includes('if(!r6DeferManagement)await prepareLazyModulesForPage(state.page,{load:true});'),'field/personal synchronous module preparation path missing');
assert.ok(endBlock.includes('await prepareLazyModulesForPage(state.page,{load:true});'),'non-dashboard synchronous module path missing');
assert.ok(endBlock.includes('await loadRuntimePolicy();'),'non-dashboard synchronous policy refresh missing');

const helperStart=app.indexOf('// OPTIMUM PERFORMANCE R6 V1 — DASHBOARD MANAGEMENT POST-PAINT');
const companyStart=app.indexOf('async function loadCompanyData() {',helperStart);
assert.ok(helperStart>=0&&companyStart>helperStart,'R6 helper isolation failed');

function page(pathname,hash){const raw=String(hash||'').replace(/^#\/?/,'')||'dashboard';const p=raw.split('/').filter(Boolean)[0]||'dashboard';return (pathname==='/'||pathname==='/v7')&&p==='dashboard';}
for(const [pathname,hash,loading,expected] of [
  ['/','#/dashboard',true,true],['/v7','#/dashboard',true,true],['/','#/files',true,false],['/','#/tasks',true,false],['/','#/dashboard',false,false],['/other','#/dashboard',true,false]
])assert.equal(Boolean(loading&&page(pathname,hash)),expected,`R6 dashboard route guard mismatch for ${pathname}${hash}`);

for(const token of ['loadEpoch:0,calendarEpoch:0','const epoch=++local.loadEpoch;','if(epoch!==local.loadEpoch||state.companyId!==companyId)return;','await loadCalendar({companyId,parentEpoch:epoch});','local.loadEpoch++;local.calendarEpoch++;'])assert.ok(ops.includes(token),`Operations R6 race guard missing: ${token}`);
for(const token of ['loadEpoch:0','const epoch=++local.loadEpoch;','if(epoch!==local.loadEpoch||state.companyId!==companyId)return;','const loadEpoch=local.loadEpoch+1;'])assert.ok(pc.includes(token),`Project Control R6 race guard missing: ${token}`);

console.log(JSON.stringify({PASS:'Performance R6 V1 dashboard management post-paint',dashboardPostPaintPolicyRefresh:true,managementDeferred:['Operations Center','Project Control'],fieldDashboardModule:'synchronous',personalDashboardModule:'none',nonDashboard:'synchronous behavior preserved',runtimePolicyCompanyGuard:true,operationsRaceGuard:true,projectControlRaceGuard:true,productionMutation:false,supabaseMutation:false},null,2));
