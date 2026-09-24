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
  'r9CancelDashboardMemberRoster();',
  'r9ShouldDeferDashboardMemberRoster()',
  "r9StartDashboardMemberRoster({companyId:state.companyId,f})",
  'r9StageDashboardMemberRoster({companyId:state.companyId,f,promise:r9MemberRosterPromise});',
  'state.r9MemberRosterReady=false;',
  'state.r9MemberRosterReady=true;',
  'await r9ResolveDashboardMemberRoster()',
  'r9RosterIds(roster)'
])assert.ok(app.includes(token),`R9 app contract missing: ${token}`);

const companyStart=app.indexOf('async function loadCompanyData() {');
const companyEnd=app.indexOf('\nasync function loadFilesData',companyStart);
const company=app.slice(companyStart,companyEnd);
const rosterStart=company.indexOf("const r9MemberRosterPromise=r9StartDashboardMemberRoster({companyId:state.companyId,f});");
const shellAwait=company.indexOf('const [subs,roles,brandingRows]=await Promise.all([');
const policyAwait=company.indexOf('await r7RuntimePolicyPromise;');
assert.ok(rosterStart>=0&&shellAwait>rosterStart,'R9 member roster request must start before essential shell wait');
assert.ok(!company.slice(shellAwait,policyAwait).includes("api.select('company_memberships'"),'company_memberships must not be in the first awaited dashboard shell batch');
assert.ok(company.includes('if(r9DeferMemberRoster){'),'R9 defer decision missing');
assert.ok(company.includes('members=await r9MemberRosterPromise;'),'R9 synchronous fallback missing');
assert.ok(company.includes('const {memberIds,membershipIds}=r9RosterIds(members);'),'R9 sync roster ID derivation missing');

const r5Start=app.indexOf('async function r5LoadDashboardAdministrativeMetadata');
const r5End=app.indexOf('// OPTIMUM PERFORMANCE R6 V1',r5Start);
const r5=app.slice(r5Start,r5End);
assert.ok(r5.includes('state.r9MemberRosterReady===false?await r9ResolveDashboardMemberRoster():state.members'),'R5 must share deferred R9 roster');
assert.ok(r5.includes('effectiveMembershipIds'),'R5 compensation must use resolved roster IDs');

const r7Start=app.indexOf('async function r7LoadDashboardDirectoryMetadata');
const r7End=app.indexOf('// OPTIMUM PERFORMANCE R8 V1',r7Start);
const r7=app.slice(r7Start,r7End);
assert.ok(r7.includes('state.r9MemberRosterReady===false?await r9ResolveDashboardMemberRoster():state.members'),'R7 must share deferred R9 roster');
assert.ok(r7.includes('const {memberIds,membershipIds}=r9RosterIds(roster);'),'R7 must derive directory IDs after roster resolution');

const helperStart=app.indexOf('// OPTIMUM PERFORMANCE R9 V1 — DASHBOARD MEMBER ROSTER NON-BLOCKING');
const helperEnd=app.indexOf('// OPTIMUM PERFORMANCE R5 V1',helperStart);
const helper=app.slice(helperStart,helperEnd);
for(const token of [
  'return state.loading&&r3IsDashboardBootstrapRoute()&&r5HasAuthoritativeRuntimePolicy();',
  "api.select('company_memberships',{filters:{company_id:f},order:'created_at.asc'})",
  'if(!context||context.companyId!==state.companyId)return [];',
  'if(context.companyId!==state.companyId)return [];'
])assert.ok(helper.includes(token),`R9 helper contract missing: ${token}`);

console.log(JSON.stringify({PASS:'Performance R9 V1 dashboard member roster',memberRosterRequest:'starts early but is not awaited before first paint on authoritative dashboard',sharedConsumers:['R5 compensation','R7 directory'],synchronousFallback:'non-dashboard or no authoritative runtime policy',staleCompanyGuard:true,roles:'remain synchronous for dashboard mode/hero',subscription:'remains synchronous',branding:'remains synchronous',projectsSites:'remain synchronous',productionMutation:false,supabaseMutation:false},null,2));
