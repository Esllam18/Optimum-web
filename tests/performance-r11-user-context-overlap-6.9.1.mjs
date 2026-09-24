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
  'OPTIMUM PERFORMANCE R11 V1 — USER CONTEXT OVERLAP & SERVICE PLAN POST-PAINT',
  'r11CancelDashboardUserContextTail();',
  'r11FlushDashboardUserContextTail();',
  'r11StartServicePlans({userId})',
  'r11StartCompaniesAfterSecurity({securityPromise,membershipsPromise})',
  'r11StageDashboardUserContextTail({userId:api.user?.id,companyId:state.companyId});',
  'globalThis.requestAnimationFrame(()=>globalThis.setTimeout(run,250))',
  'r11RouteNeedsServicePlans(state.page)',
  'r11EnsureServicePlans()'
])assert.ok(app.includes(token),`R11 app contract missing: ${token}`);

const userStart=app.indexOf('async function loadUserContext() {');
const userEnd=app.indexOf('async function loadRuntimePolicy()',userStart);
const user=app.slice(userStart,userEnd);
const securityStart=user.indexOf("const securityPromise=api.select('account_security'");
const membershipStart=user.indexOf("const membershipsPromise=api.select('company_memberships'");
const companyStart=user.indexOf('const r11CompaniesPromise=r11StartCompaniesAfterSecurity({securityPromise,membershipsPromise});');
const firstAwait=user.indexOf('const [profiles,securityRows,memberships,platformRows,companies] = await Promise.all([');
assert.ok(securityStart>=0&&membershipStart>=0&&companyStart>securityStart&&companyStart>membershipStart&&firstAwait>companyStart,'R11 company overlap request graph is not staged correctly');
assert.ok(!user.includes("state.companies = await api.select('companies'"),'Old serial companies query still blocks after user batch');
assert.ok(!user.includes("api.select('service_plans', { order:'sort_order.asc' })"),'Old blocking service-plans query remains in initial Promise.all');
assert.ok(user.includes('state.plans=await r11ServicePlansPromise;'),'No-membership synchronous plans fallback missing');

const helperStart=app.indexOf('// OPTIMUM PERFORMANCE R11 V1 — USER CONTEXT OVERLAP & SERVICE PLAN POST-PAINT');
const helperEnd=app.indexOf('// OPTIMUM PERFORMANCE R10 V1',helperStart);
const helper=app.slice(helperStart,helperEnd);
for(const token of [
  "api.select('service_plans',{order:'sort_order.asc'}).catch(()=>[])",
  'return Promise.all([securityPromise,membershipsPromise]).then(([securityRows,memberships])=>{',
  "if(securityRows?.[0]?.must_change_password||api.session?.recovery||!memberships.length)return [];",
  "return api.select('companies',{filters:{id:",
  "ids.join(',')",
  "order:'created_at.asc'});",
  'return state.loading&&r3IsDashboardBootstrapRoute()&&r5HasAuthoritativeRuntimePolicy();',
  "return String(page||'')==='settings';",
  'if(context.userId!==api.user?.id)return [];'
])assert.ok(helper.includes(token),`R11 helper contract missing: ${token}`);

const companyDataStart=app.indexOf('async function loadCompanyData() {');
const companyDataEnd=app.indexOf('\nasync function loadFilesData',companyDataStart);
const companyData=app.slice(companyDataStart,companyDataEnd);
const policyAwait=companyData.indexOf('await r7RuntimePolicyPromise;');
const planDecision=companyData.indexOf('const r11DeferServicePlans=r11ShouldDeferServicePlans();');
assert.ok(policyAwait>=0&&planDecision>policyAwait,'R11 must decide plan deferral only after authoritative runtime policy resolves');
assert.ok(companyData.includes('if(r11DeferServicePlans){'),'R11 dashboard plan deferral branch missing');
assert.ok(companyData.includes('await r11EnsureServicePlans();'),'R11 synchronous fallback missing');

const routeStart=app.indexOf('async function activateRoute(');
const routeEnd=app.indexOf("window.addEventListener('hashchange'",routeStart);
const route=app.slice(routeStart,routeEnd);
assert.ok(route.includes('r11WaitForServicePlans'),'R11 settings on-demand wait missing');
assert.ok(route.includes('r11WaitForServicePlans?r11EnsureServicePlans():Promise.resolve()'),'R11 settings on-demand hydration missing');

console.log(JSON.stringify({PASS:'Performance R11 V1 user-context overlap',companyQuery:'starts as soon as security + memberships resolve and before remaining user-context tail finishes',servicePlans:'starts immediately but is not a first-paint wait on authoritative dashboard',settings:'on-demand wait for service-plan catalog',securityGate:'company query still blocked by must-change-password/recovery',fallback:'service plans synchronous outside authoritative dashboard',productionMutation:false,supabaseMutation:false},null,2));
