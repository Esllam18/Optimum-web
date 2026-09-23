import fs from 'node:fs';
import assert from 'node:assert/strict';

const appPath=new URL('../assets/app.js',import.meta.url);
const publicAppPath=new URL('../public/assets/app.js',import.meta.url);
const source=fs.readFileSync(appPath,'utf8');
const publicSource=fs.readFileSync(publicAppPath,'utf8');
assert.equal(source,publicSource,'assets/app.js and public/assets/app.js must remain exact mirrors');

assert.ok(source.includes('OPTIMUM PERFORMANCE R3 V1 — DASHBOARD ROUTE DATA'),'R3 marker missing');
assert.ok(source.includes('OPTIMUM PERFORMANCE R4 V1 — DASHBOARD SECONDARY DATA'),'R4 marker missing');
assert.ok(source.includes('state.loading&&r3IsDashboardBootstrapRoute()'),'R4 must defer only during loading on the dashboard entrypoint');
assert.ok(source.includes('r4StageDashboardSecondaryBootstrap(()=>r4LoadDashboardSecondaryData())'),'R4 staged bootstrap missing');
assert.ok(source.includes('r4FlushDashboardSecondaryBootstrap();'),'R4 flush after user-context load missing');
assert.ok(source.includes("globalThis.requestAnimationFrame(()=>globalThis.setTimeout(run,0))"),'R4 post-render scheduling contract missing');
assert.ok(source.includes('await Promise.all([loadNotificationsData(),workPromise])'),'R4 notification/work parallel background load missing');
assert.ok(source.includes("page==='tasks'||page==='calendar'"),'R4 task/calendar race guard missing');
assert.ok(source.includes('r4CancelDashboardSecondaryBootstrap();\n  state.loading = true;'),'A fresh user-context load must cancel stale R4 work');

const companyStart=source.indexOf('async function loadCompanyData() {');
const companyEnd=source.indexOf('\nasync function loadFilesData',companyStart);
assert.ok(companyStart>=0&&companyEnd>companyStart,'loadCompanyData isolation failed');
const company=source.slice(companyStart,companyEnd);
const gateAt=company.indexOf('if(r4ShouldDeferDashboardSecondaryBootstrap())');
const stageAt=company.indexOf('r4StageDashboardSecondaryBootstrap(()=>r4LoadDashboardSecondaryData())');
const elseAt=company.indexOf('}else{',gateAt);
const blockingNotifications=company.indexOf('await loadNotificationsData()',gateAt);
assert.ok(gateAt>=0&&stageAt>gateAt&&elseAt>stageAt,'R4 deferred branch structure invalid');
assert.ok(blockingNotifications>elseAt,'Blocking notifications load must exist only in the synchronous non-deferred branch');
assert.ok(company.includes("if(state.page==='tasks'||state.page==='calendar')await ensureWorkOS({load:true});"),'Tasks/calendar synchronous behavior must remain unchanged outside deferred dashboard bootstrap');

const helperStart=source.indexOf('// OPTIMUM PERFORMANCE R4 V1 — DASHBOARD SECONDARY DATA');
const helperEnd=source.indexOf('async function loadCompanyData() {',helperStart);
assert.ok(helperStart>=0&&helperEnd>helperStart,'R4 helper isolation failed');
const helper=source.slice(helperStart,helperEnd);
assert.ok(helper.includes('pending.companyId!==state.companyId'),'R4 company-change cancellation guard missing');
assert.ok(helper.includes("console.warn('[Optimum R4] deferred dashboard secondary bootstrap failed'"),'R4 background error containment missing');

console.log(JSON.stringify({
  PASS:'Performance R4 V1 dashboard secondary-data deferral + mirror contract',
  deferredOn:['/ + #/dashboard','/v7 + #/dashboard'],
  deferredRequests:['notifications','dashboard work query','dashboard work delivery snapshot'],
  taskCalendarRaceGuard:true,
  nonDashboardSynchronousBehavior:'preserved',
  productionMutation:false,
  supabaseMutation:false
},null,2));
