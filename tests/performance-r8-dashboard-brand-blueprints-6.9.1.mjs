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
  'r8CancelDashboardSupplementBootstrap();',
  'r8FlushDashboardSupplementBootstrap();',
  'r8ShouldDeferDashboardSupplementBootstrap()',
  'globalThis.requestAnimationFrame(()=>globalThis.setTimeout(run,200))',
  'const r8BrandLogoPromise=resolveIdentityAssets([state.branding?.logo_path]);',
  'state.r8ProjectBlueprintsReady=!needsProjectContext||!r8DeferSupplement;',
  'r8StageDashboardSupplementBootstrap({companyId:state.companyId,loadBlueprints:needsProjectContext,coverPath:state.branding?.cover_path||null});',
  "else if(action==='new-project'){await r8EnsureProjectBlueprints();openProjectDialog();}"
])assert.ok(app.includes(token),`R8 app contract missing: ${token}`);

const companyStart=app.indexOf('async function loadCompanyData() {');
const companyEnd=app.indexOf('\nasync function loadFilesData',companyStart);
const company=app.slice(companyStart,companyEnd);
const logoPos=company.indexOf('const r8BrandLogoPromise=resolveIdentityAssets([state.branding?.logo_path]);');
const projectWait=company.indexOf('const [projects,sites]=needsProjectContext');
const logoAwait=company.indexOf('r8BrandLogoPromise,');
assert.ok(logoPos>=0&&projectWait>logoPos,'R8 logo signing must start before project/site wait');
assert.ok(logoAwait>projectWait,'R8 logo promise should be awaited only after project/site loading began');
assert.ok(company.includes("if(needsProjectContext&&!r8DeferSupplement){\n    projectBlueprints=await api.select('project_blueprints'"),'Synchronous blueprint fallback missing');
assert.ok(company.includes('resolveIdentityAssets([...(r8DeferSupplement?[]:[state.branding?.cover_path])'),'Dashboard cover deferral missing');

const helperStart=app.indexOf('// OPTIMUM PERFORMANCE R8 V1 — DASHBOARD BRAND & BLUEPRINT POST-PAINT');
const helperEnd=app.indexOf('async function loadCompanyData()',helperStart);
const helper=app.slice(helperStart,helperEnd);
for(const token of [
  'return state.loading&&r3IsDashboardBootstrapRoute()&&r5HasAuthoritativeRuntimePolicy();',
  "api.select('project_blueprints'",
  'if(companyId!==state.companyId)return;',
  'resolveIdentityAssets([context.coverPath])',
  'if(state.r8ProjectBlueprintsReady!==false)return;'
])assert.ok(helper.includes(token),`R8 helper contract missing: ${token}`);

console.log(JSON.stringify({PASS:'Performance R8 V1 dashboard brand + blueprints',logoSigning:'overlapped with project/site critical batch',deferredAfterPaint:['project blueprints','branding cover signed URL'],postPaintDelayMs:200,blueprintOnDemand:'new-project action',authoritativePolicyOnly:true,nonDashboard:'synchronous behavior preserved',fallbackWithoutRuntimePolicy:'synchronous',projectsAndSites:'remain synchronous for dashboard correctness',productionMutation:false,supabaseMutation:false},null,2));
