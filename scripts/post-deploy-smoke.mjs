import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';

const clientUrl = (process.env.OPTIMUM_CLIENT_URL || process.argv[2] || '').replace(/\/$/,'');
const platformUrl = (process.env.OPTIMUM_PLATFORM_URL || process.argv[3] || '').replace(/\/$/,'');
const expectedCommit = (process.env.OPTIMUM_EXPECTED_COMMIT || process.argv[4] || '').trim();

if (!clientUrl) {
  console.error('Usage: OPTIMUM_CLIENT_URL=https://app.example.com [OPTIMUM_PLATFORM_URL=https://platform.example.com] [OPTIMUM_EXPECTED_COMMIT=<sha>] node scripts/post-deploy-smoke.mjs');
  process.exit(2);
}

async function get(url, init={}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15_000);
  try {
    return await fetch(url, { redirect:'manual', signal:controller.signal, ...init });
  } finally {
    clearTimeout(timer);
  }
}

function assertSecurityHeaders(res, label) {
  const required = [
    'x-content-type-options',
    'x-frame-options',
    'referrer-policy',
    'permissions-policy',
    'content-security-policy',
    'cross-origin-opener-policy',
    'cross-origin-resource-policy',
    'strict-transport-security'
  ];
  for (const key of required) {
    assert.ok(res.headers.get(key), `${label}: missing ${key}`);
  }
  const csp = res.headers.get('content-security-policy') || '';
  assert.match(csp, /object-src 'none'/, `${label}: CSP object-src must remain none`);
  assert.match(csp, /frame-ancestors 'none'/, `${label}: CSP frame-ancestors must remain none`);
  assert.match(csp, /wzcaquxuvqfbstpxujsj\.supabase\.co/, `${label}: Supabase origin missing from CSP`);
}

async function smokeHealth(base) {
  const health = await get(`${base}/health`);
  assert.equal(health.status, 200, 'health must return 200');
  assert.match(health.headers.get('cache-control') || '', /no-store/, 'health must not be cached');
  const payload = await health.json();
  assert.equal(payload.ok, true, 'health ok flag');
  assert.equal(payload.service, 'optimum', 'health service mismatch');
  assert.equal(payload.release, '6.9.0', 'health release mismatch');
  assert.equal(payload.baseline, '6.9.1-production-certification-r1', 'health baseline mismatch');
  if (expectedCommit) {
    assert.equal(payload.commit, expectedCommit, 'health commit does not match expected deployment commit');
  }
  return payload;
}

async function smokeClient(base) {
  const healthPayload = await smokeHealth(base);

  const home = await get(`${base}/`);
  assert.equal(home.status, 200, 'client home must return 200');
  assertSecurityHeaders(home, 'client');
  assert.match(home.headers.get('cache-control') || '', /no-store/, 'client HTML must not be cached');
  assert.match(await home.text(), /<div id="app"/, 'client app mount missing');

  const integrityRes = await get(`${base}/integrity.json`);
  assert.equal(integrityRes.status, 200, 'integrity manifest must return 200');
  assert.match(integrityRes.headers.get('cache-control') || '', /no-store/, 'integrity manifest must not be cached');
  const integrity = await integrityRes.json();

  const expectedApp = integrity?.['assets/app.js'];
  assert.ok(expectedApp?.sha256 && Number.isFinite(Number(expectedApp?.bytes)), 'integrity manifest missing assets/app.js');

  const asset = await get(`${base}/assets/app.js`);
  assert.equal(asset.status, 200, 'client asset must return 200');
  assert.match(asset.headers.get('cache-control') || '', /public/, 'client asset cache policy missing');
  const assetBody = Buffer.from(await asset.arrayBuffer());
  assert.equal(assetBody.length, Number(expectedApp.bytes), 'live app.js byte count differs from integrity manifest');
  assert.equal(
    createHash('sha256').update(assetBody).digest('hex'),
    expectedApp.sha256,
    'live app.js hash differs from integrity manifest'
  );

  const missing = await get(`${base}/assets/__optimum_missing__.js`);
  assert.equal(missing.status, 404, 'missing asset must return 404');

  return healthPayload;
}

async function smokePlatform(base) {
  const platform = await get(base);
  assert.equal(platform.status, 200, 'platform shell must return 200');
  assertSecurityHeaders(platform, 'platform');
  assert.match(platform.headers.get('cache-control') || '', /no-store/, 'platform HTML must not be cached');
  assert.match(await platform.text(), /data-app="platform"/, 'platform shell missing');
}

const health = await smokeClient(clientUrl);
await smokePlatform(platformUrl || `${clientUrl}/platform`);

console.log(JSON.stringify({
  ok: true,
  release: health.release,
  baseline: health.baseline,
  commit: health.commit,
  client: clientUrl,
  platform: platformUrl || `${clientUrl}/platform`,
  integrity: 'verified'
}, null, 2));
