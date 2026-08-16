import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');
const json = (relative) => JSON.parse(read(relative));

const vercel = json('vercel.json');
const build = read('build.mjs');
const postdeploy = read('scripts/post-deploy-smoke.mjs');
const pkg = json('package.json');
const config = read('assets/config.js');
const platformHardening = read('supabase/migrations/20260812125055_phase6_9_platform_console_production_hardening.sql');
const operationsGrantHardening = read('supabase/migrations/20260816000215_production_certification_r1_operations_rpc_grants.sql');

const rewrite = (source) => vercel.rewrites?.find((entry) => entry.source === source);
assert.equal(rewrite('/health')?.destination, '/health.json', 'Vercel /health rewrite missing');
assert.equal(rewrite('/healthz')?.destination, '/health.json', 'Vercel /healthz rewrite missing');
assert.equal(rewrite('/platform')?.destination, '/platform.html', 'Vercel /platform rewrite missing');

const globalHeaders = vercel.headers?.find((entry) => entry.source === '/(.*)')?.headers || [];
const headerMap = new Map(globalHeaders.map(({key, value}) => [key.toLowerCase(), value]));
for (const key of [
  'x-content-type-options',
  'x-frame-options',
  'referrer-policy',
  'permissions-policy',
  'content-security-policy',
  'cross-origin-opener-policy',
  'cross-origin-resource-policy',
  'strict-transport-security'
]) {
  assert.ok(headerMap.get(key), `Vercel global security header missing: ${key}`);
}
const csp = headerMap.get('content-security-policy') || '';
assert.match(csp, /object-src 'none'/, 'CSP object-src none missing');
assert.match(csp, /frame-ancestors 'none'/, 'CSP frame-ancestors none missing');
assert.match(csp, /wzcaquxuvqfbstpxujsj\.supabase\.co/, 'CSP Supabase origin missing');
assert.match(csp, /fonts\.googleapis\.com/, 'CSP Google Fonts stylesheet origin missing');
assert.match(csp, /fonts\.gstatic\.com/, 'CSP Google Fonts file origin missing');

assert.match(build, /createHash\('sha256'\)/, 'build must regenerate SHA-256 integrity');
assert.match(build, /health\.json/, 'build must generate health.json');
assert.match(build, /integrity\.json/, 'build must generate integrity.json');
assert.match(build, /writeFile\(/, 'build must write generated artifact metadata');
const sourceFilesStart = build.indexOf('const sourceFiles = [');
const sourceFilesEnd = sourceFilesStart >= 0 ? build.indexOf('];', sourceFilesStart) : -1;
assert.ok(sourceFilesStart >= 0 && sourceFilesEnd > sourceFilesStart, 'build sourceFiles declaration missing');
const sourceFilesBlock = build.slice(sourceFilesStart, sourceFilesEnd + 2);
assert.doesNotMatch(sourceFilesBlock, /integrity\.json/, 'build must not copy stale source integrity.json');
assert.equal(fs.existsSync(path.join(root, 'integrity.json')), false, 'stale root integrity.json must be removed');

assert.match(postdeploy, /integrity\.json/, 'postdeploy must verify integrity manifest');
assert.match(postdeploy, /createHash\('sha256'\)/, 'postdeploy must hash live app.js');
assert.match(postdeploy, /\/health/, 'postdeploy must check health route');
assert.match(postdeploy, /\/platform/, 'postdeploy must check integrated platform route');
assert.match(postdeploy, /VERCEL_AUTOMATION_BYPASS_SECRET/, 'postdeploy must support Vercel protected Preview automation');
assert.match(postdeploy, /x-vercel-protection-bypass/, 'postdeploy must send Vercel protection bypass header');
assert.match(postdeploy, /assertReachedDeployment/, 'postdeploy must distinguish Deployment Protection redirects from app failures');
assert.doesNotMatch(postdeploy, /work\/post-deploy-check/, 'legacy portable-server SPA deep-link assumption must be removed');

assert.equal(pkg.version, '6.9.0', 'legacy package version contract must remain 6.9.0');
assert.ok(pkg.scripts?.['test:certificationr1'], 'test:certificationr1 script missing');
assert.match(pkg.scripts?.['test:release'] || '', /test:certificationr1/, 'release gate must include certification R1');

assert.match(config, /sb_publishable_/, 'frontend must use a Supabase publishable key');
for (const relative of [
  'assets/config.js',
  'assets/api.js',
  'assets/app.js',
  'assets/platform.js',
  'assets/work-os.js'
]) {
  const runtime = read(relative);
  assert.doesNotMatch(runtime, /sb_secret_/i, `${relative}: secret Supabase key exposed`);
  assert.doesNotMatch(runtime, /SUPABASE_SERVICE_ROLE_KEY/, `${relative}: service role env name exposed in runtime`);
}

assert.match(platformHardening, /app_private\.is_platform_admin\(\)/, 'platform hardening must enforce platform admin gate');
assert.match(platformHardening, /revoke all on function public\.platform_company_directory\(\) from public,anon/i, 'platform directory anonymous execute revoke missing');
assert.match(platformHardening, /Platform administrator permission required/, 'platform mutation admin guard missing');

for (const fn of ['toggle_entity_follow','operations_center_mark_seen','save_operations_calendar_layers','operations_center_snapshot','operations_calendar_feed']) {
  assert.match(operationsGrantHardening, new RegExp(`revoke all on function public\\.${fn}\\(`, 'i'), `anonymous revoke missing for ${fn}`);
}
assert.match(operationsGrantHardening, /to authenticated/i, 'Operations RPC authenticated grants missing');

const healthPath = path.join(root, 'public', 'health.json');
const integrityPath = path.join(root, 'public', 'integrity.json');
assert.ok(fs.existsSync(healthPath), 'public/health.json missing after build');
assert.ok(fs.existsSync(integrityPath), 'public/integrity.json missing after build');

const health = JSON.parse(fs.readFileSync(healthPath, 'utf8'));
assert.equal(health.ok, true);
assert.equal(health.release, '6.9.0');
assert.equal(health.baseline, '6.9.1-production-certification-r1');

const integrity = JSON.parse(fs.readFileSync(integrityPath, 'utf8'));
for (const required of ['index.html','platform.html','health.json','assets/app.js','assets/styles.css','assets/platform.js','assets/work-os.js']) {
  assert.ok(integrity[required], `generated integrity missing ${required}`);
}
assert.equal(integrity['integrity.json'], undefined, 'integrity manifest must not hash itself');

for (const [relative, metadata] of Object.entries(integrity)) {
  const absolute = path.join(root, 'public', ...relative.split('/'));
  assert.ok(fs.existsSync(absolute), `integrity target missing: ${relative}`);
  const body = fs.readFileSync(absolute);
  assert.equal(body.length, metadata.bytes, `integrity byte mismatch: ${relative}`);
  assert.equal(createHash('sha256').update(body).digest('hex'), metadata.sha256, `integrity hash mismatch: ${relative}`);
}

for (const relative of ['assets/app.js','assets/styles.css','assets/platform.js','assets/work-os.js']) {
  assert.deepEqual(
    fs.readFileSync(path.join(root, relative)),
    fs.readFileSync(path.join(root, 'public', relative)),
    `runtime mirror mismatch: ${relative}`
  );
}

console.log(`PASS Production Certification R1: Vercel routing/headers, generated health, live-artifact integrity contract, secret scan, platform admin guard, and runtime mirrors (${Object.keys(integrity).length} integrity entries)`);
