import assert from 'node:assert/strict';

const clientUrl = (process.env.OPTIMUM_CLIENT_URL || process.argv[2] || '').replace(/\/$/,'');
const platformUrl = (process.env.OPTIMUM_PLATFORM_URL || process.argv[3] || '').replace(/\/$/,'');
if (!clientUrl) {
  console.error('Usage: OPTIMUM_CLIENT_URL=https://app.example.com [OPTIMUM_PLATFORM_URL=https://platform.example.com] node scripts/post-deploy-smoke.mjs');
  process.exit(2);
}

async function get(url, init={}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 12_000);
  try { return await fetch(url,{redirect:'manual',signal:controller.signal,...init}); }
  finally { clearTimeout(timer); }
}

function assertSecurityHeaders(res,label){
  const required=['x-content-type-options','x-frame-options','referrer-policy','permissions-policy','content-security-policy'];
  for(const key of required) assert.ok(res.headers.get(key),`${label}: missing ${key}`);
  assert.match(res.headers.get('content-security-policy')||'',/object-src 'none'/,`${label}: CSP object-src must remain none`);
}

async function smokeClient(base){
  const health=await get(`${base}/health`);
  assert.equal(health.status,200,'client health must return 200');
  const payload=await health.json();
  assert.equal(payload.ok,true,'client health ok flag');
  assert.equal(payload.release,'6.9.0','client release mismatch');

  const home=await get(`${base}/`);
  assert.equal(home.status,200,'client home must return 200');
  assertSecurityHeaders(home,'client');
  assert.match(await home.text(),/<div id="app"/,'client app mount missing');

  const deep=await get(`${base}/work/post-deploy-check`);
  assert.equal(deep.status,200,'SPA deep link must return 200');
  assert.match(await deep.text(),/<div id="app"/,'SPA fallback is not the client shell');

  const asset=await get(`${base}/assets/app.js`,{headers:{'Accept-Encoding':'gzip'}});
  assert.equal(asset.status,200,'client asset must return 200');
  assert.ok(asset.headers.get('etag'),'client asset ETag missing');
  assert.match(asset.headers.get('cache-control')||'',/public/,'client asset cache policy missing');

  const missing=await get(`${base}/assets/__optimum_missing__.js`);
  assert.equal(missing.status,404,'missing asset must return 404');
}

async function smokePlatform(base){
  const health=await get(`${base}/health`);
  assert.equal(health.status,200,'platform health must return 200');
  const payload=await health.json();
  assert.equal(payload.ok,true,'platform health ok flag');
  assert.equal(payload.release,'6.9.0','platform release mismatch');

  const home=await get(`${base}/`);
  assert.equal(home.status,200,'platform home must return 200');
  assertSecurityHeaders(home,'platform');
  assert.match(await home.text(),/data-app="platform"/,'platform shell missing');
}

await smokeClient(clientUrl);
if (platformUrl) await smokePlatform(platformUrl);
else {
  const platform=await get(`${clientUrl}/platform`);
  assert.equal(platform.status,200,'integrated /platform must return 200');
  assert.match(await platform.text(),/data-app="platform"/,'integrated platform shell missing');
}

console.log(JSON.stringify({ok:true,release:'6.9.0',client:clientUrl,platform:platformUrl||`${clientUrl}/platform`},null,2));
