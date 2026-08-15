import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const read = (p) => fs.readFileSync(p, 'utf8');
const exists = (p) => fs.existsSync(p);
const pkg = JSON.parse(read('package.json'));
const lock = JSON.parse(read('package-lock.json'));

assert.equal(pkg.version, '6.9.0');
assert.ok(Number(process.versions.node.split('.')[0]) >= 20, 'Node 20+ is required');
assert.equal(lock.packages[''].dependencies.next, pkg.dependencies.next, 'lock/package Next range drift');
assert.equal(lock.packages[''].dependencies.react, pkg.dependencies.react, 'lock/package React drift');
assert.equal(lock.packages[''].dependencies['react-dom'], pkg.dependencies['react-dom'], 'lock/package ReactDOM drift');
assert.equal(lock.packages['node_modules/next']?.version, '16.3.0', 'Next lock must be deterministic at 16.3.0');
assert.equal(lock.packages['node_modules/react']?.version, '19.2.8');
assert.equal(lock.packages['node_modules/react-dom']?.version, '19.2.8');

for (const peer of ['public/assets/api.js','platform-console/assets/api.js']) {
  assert.equal(read('assets/api.js'), read(peer), `API runtime drift: ${peer}`);
}
for (const peer of ['public/assets/app.js']) assert.equal(read('assets/app.js'), read(peer), `App runtime drift: ${peer}`);
for (const peer of ['public/assets/engineering.js']) assert.equal(read('assets/engineering.js'), read(peer), `Engineering runtime drift: ${peer}`);
for (const peer of ['public/assets/platform.js','platform-console/assets/platform.js']) assert.equal(read('assets/platform.js'), read(peer), `Platform runtime drift: ${peer}`);
for (const peer of ['public/assets/styles.css','app/globals.css','platform-console/assets/styles.css']) assert.equal(read('assets/styles.css'), read(peer), `Styles drift: ${peer}`);

const api = read('assets/api.js');
assert.match(api, /ensureFreshSession/);
assert.match(api, /if \(this\.session\?\.access_token && retry\) await this\.ensureFreshSession\(\)/, 'proactive token rollover protection missing');
assert.match(api, /this\.refreshPromise/, 'concurrent refresh dedupe missing');

const frontend = [
  'assets/app.js','assets/api.js','assets/config.js','assets/engineering.js','assets/platform.js',
  'public/assets/app.js','public/assets/api.js','public/assets/config.js','public/assets/engineering.js','public/assets/platform.js',
  'platform-console/assets/api.js','platform-console/assets/config.js','platform-console/assets/platform.js'
].map(read).join('\n');
for (const secret of ['SUPABASE_SERVICE_ROLE_KEY','SUPABASE_SECRET_KEYS','SERVICE_ROLE']) {
  assert.ok(!frontend.includes(secret), `frontend must never contain ${secret}`);
}

const nextConfig = read('next.config.mjs');
for (const header of ['X-Content-Type-Options','X-Frame-Options','Referrer-Policy','Permissions-Policy']) {
  assert.ok(nextConfig.includes(header), `Next security header missing ${header}`);
}
const portable = read('server.mjs');
for (const header of ['X-Content-Type-Options','X-Frame-Options','Referrer-Policy','Permissions-Policy','Strict-Transport-Security','Content-Security-Policy']) {
  assert.ok(portable.includes(header), `Portable server security header missing ${header}`);
}
const platformServer = read('platform-console/server.mjs');
assert.ok(platformServer.includes("script-src 'self'"), 'Platform Console CSP must remain strict');
assert.ok(!platformServer.includes("script-src 'self' 'unsafe-inline'"), 'Platform Console scripts must not allow inline execution');
assert.equal(pkg.scripts.build, 'node scripts/build-production.mjs', 'canonical production build must be dependency-free');
assert.equal(pkg.scripts.start, 'node server.mjs', 'canonical production start must use hardened Node runtime');
assert.equal(pkg.scripts['build:next'], 'next build', 'optional Next build path should remain explicit');
assert.ok(exists('scripts/build-production.mjs'), 'production bundle builder is required');
assert.equal(pkg.scripts['test:postdeploy'], 'node scripts/post-deploy-smoke.mjs', 'post-deploy smoke command must remain available');
assert.ok(exists('scripts/post-deploy-smoke.mjs'), 'post-deploy smoke script is required');
assert.ok(exists('docs/FINAL_PRODUCTION_READINESS_6_9_AR.md'), 'final production readiness report is required');
assert.ok(exists('docs/DEPLOYMENT_RUNBOOK_6_9_AR.md'), 'deployment runbook is required');
assert.ok(exists('docs/RELEASE_GATE_6_9.json'), 'machine-readable release gate is required');

const requiredMigrations = [
  '20260811224030_direct_production_project_capabilities.sql',
  '20260811225959_direct_production_work_archived_context_guard.sql',
  '20260811231514_direct_production_cde_hardening.sql',
  '20260811231940_direct_production_trash_capabilities.sql',
  '20260812120144_phase6_9_cde_production_hardening.sql',
  '20260812122139_phase6_9_cad_production_hardening.sql',
  '20260812123851_phase6_9_site_delivery_production_hardening.sql',
  '20260812125055_phase6_9_platform_console_production_hardening.sql',
  '20260812125721_phase6_9_rls_performance_final.sql',
  '20260812131720_phase6_9_cad_directory_contract_fix.sql',
  '20260812132231_phase6_9_member_security_scope_fix.sql'
];
for (const name of requiredMigrations) {
  const file = path.join('supabase/migrations', name);
  assert.ok(exists(file), `production migration source missing: ${name}`);
  assert.ok(read(file).trim().length > 300, `production migration looks incomplete: ${name}`);
}

const directProject = read('supabase/migrations/20260811224030_direct_production_project_capabilities.sql');
const directWork = read('supabase/migrations/20260811225959_direct_production_work_archived_context_guard.sql');
const directCde = read('supabase/migrations/20260811231514_direct_production_cde_hardening.sql');
const directTrash = read('supabase/migrations/20260811231940_direct_production_trash_capabilities.sql');
assert.ok(directProject.includes('project_action_capabilities'));
for (const fn of ['task_context_operational','claim_task','add_task_comment','begin_task_attachment_upload','finalize_task_attachment_upload','save_task_dependency']) assert.ok(directWork.includes(fn), `recovered Work migration missing ${fn}`);
for (const fn of ['file_workspace_capabilities','document_action_capabilities','create_folder','rename_folder','rename_document','trash_document','trash_folder','restore_document','restore_folder','begin_document_upload']) assert.ok(directCde.includes(fn), `recovered CDE migration missing ${fn}`);
assert.ok(directTrash.includes('trash_query'));

const memberSecurityFix = read('supabase/migrations/20260812132231_phase6_9_member_security_scope_fix.sql');
assert.ok(memberSecurityFix.includes("'members.manage'"), 'member security inspection must require manage permission for other users');
assert.ok(!memberSecurityFix.includes("'members.view'"), 'members.view must not expose another member security snapshot');

assert.ok(!exists('supabase/functions/identity-provisioning-verified'), 'retired credential verifier source must not ship');
assert.ok(exists('supabase/functions/identity-provisioning/index.ts'), 'current identity provisioning source is required');

for (const hardening of [
  'cde-production-hardening-6.9.mjs','cad-production-hardening-6.9.mjs',
  'site-delivery-production-hardening-6.9.mjs','platform-console-production-hardening-6.9.mjs'
]) assert.ok(pkg.scripts['test:release'].includes(hardening), `release gate missing ${hardening}`);

console.log('Optimum 6.9 final production-readiness static contract: PASS');
