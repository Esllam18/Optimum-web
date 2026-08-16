import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { access, readFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import {
  CSS_FILES,
  parseTopLevelCss,
  splitCssForDelivery
} from '../scripts/performance-r2-css-delivery.mjs';

const root=resolve(process.cwd());
const read=(relative)=>readFile(join(root,...relative.split('/')),'utf8');
const bytes=(value)=>Buffer.byteLength(value,'utf8');
const sha=(value)=>createHash('sha256').update(value).digest('hex');

const sourceIndex=await read('index.html');
const publicIndex=await read('public/index.html');
const platformIndex=await read('platform.html');
const publicPlatform=await read('public/platform.html');
const canonical=await read('assets/styles.css');
const canonicalNormalized=canonical.replace(/\r\n?/g,'\n');
const publicCanonical=await read('public/assets/styles.css');
const globals=await read('app/globals.css');
const app=await read('assets/app.js');
const publicApp=await read('public/assets/app.js');
const integrity=JSON.parse(await read('public/integrity.json'));
const manifest=JSON.parse(await read(`public/assets/${CSS_FILES.manifest}`));

assert.equal(canonical,publicCanonical,'canonical CSS mirror must remain byte-identical as text');
assert.equal(canonical,globals,'app/globals.css must remain the canonical CSS mirror');
assert.equal(app,publicApp,'app source/public mirror must remain exact');

assert.match(sourceIndex,/href=["']\.\/assets\/styles\.css\?v=6\.9\.0["']/,'source index must retain full CSS for local/dev safety');
assert.doesNotMatch(sourceIndex,/data-css-delivery=["']r2["']/,'source index must not activate split CSS mode');
assert.match(platformIndex,/href=["']\.\/assets\/styles\.css\?v=6\.9\.0["']/,'Platform Console must keep canonical full CSS in R2');
assert.match(publicPlatform,/href=["']\.\/assets\/styles\.css\?v=6\.9\.0["']/,'built Platform Console must keep canonical full CSS in R2');

assert.match(publicIndex,/data-css-delivery=["']r2["']/,'built client must activate R2 CSS delivery');
assert.match(publicIndex,/data-optimum-core-style/,'built client must mark the core stylesheet');
assert.match(publicIndex,/styles-core\.css\?v=6\.9\.0/,'built client must cold-load core CSS');
assert.doesNotMatch(publicIndex,/rel=["']stylesheet["'][^>]*styles\.css\?v=6\.9\.0/,'built client must not render-block on full canonical CSS');
assert.match(publicIndex,/rel=["']preload["'][^>]*styles\.css\?v=6\.9\.0[^>]*as=["']style["']/,'built client must preload canonical CSS without render blocking');

const expectedFiles=[
  CSS_FILES.core,CSS_FILES.engineering,CSS_FILES.work,CSS_FILES.management,
  CSS_FILES.field,CSS_FILES.platform,CSS_FILES.manifest
];
for(const file of expectedFiles){
  await access(join(root,'public','assets',file));
  assert.ok(integrity[`assets/${file}`],`integrity manifest must include ${file}`);
}


const distIndex=await read('dist/index.html');
const distPlatform=await read('dist/platform.html');
assert.match(distIndex,/data-css-delivery=["']r2["']/,'portable production bundle must activate R2 CSS delivery');
assert.match(distIndex,/styles-core\.css\?v=6\.9\.0/,'portable production bundle must cold-load core CSS');
assert.match(distIndex,/rel=["']preload["'][^>]*styles\.css\?v=6\.9\.0[^>]*as=["']style["']/,'portable bundle must preload canonical CSS safely');
assert.match(distPlatform,/href=["']\.\/assets\/styles\.css\?v=6\.9\.0["']/,'portable integrated platform page must keep canonical full CSS');
for(const file of expectedFiles.slice(0,-1)){
  await access(join(root,'dist','assets',file));
}
await access(join(root,'dist','assets',CSS_FILES.manifest));

assert.equal(manifest.version,'r2');
assert.equal(manifest.canonical.normalizedBytes,bytes(canonicalNormalized));
assert.equal(manifest.canonical.normalizedSha256,sha(canonicalNormalized));
assert.equal(manifest.coverage.selectors,manifest.coverage.emittedSelectors,'every canonical selector must be assigned exactly once');

const core=await read(`public/assets/${CSS_FILES.core}`);
const engineering=await read(`public/assets/${CSS_FILES.engineering}`);
const work=await read(`public/assets/${CSS_FILES.work}`);
const management=await read(`public/assets/${CSS_FILES.management}`);
const field=await read(`public/assets/${CSS_FILES.field}`);
const platformCss=await read(`public/assets/${CSS_FILES.platform}`);

assert.equal(bytes(core),manifest.chunks.core.bytes);
assert.equal(bytes(engineering),manifest.chunks.engineering.bytes);
assert.equal(bytes(work),manifest.chunks.work.bytes);
assert.equal(bytes(management),manifest.chunks.management.bytes);
assert.equal(bytes(field),manifest.chunks.field.bytes);
assert.equal(bytes(platformCss),manifest.chunks.platform.bytes);

assert.ok(manifest.client.coreKiB<=700,`R2 hard gate: core CSS must be <=700 KiB, actual ${manifest.client.coreKiB}`);
assert.ok(manifest.client.initialReductionPercent>=20,`R2 hard gate: cold CSS reduction must be >=20%, actual ${manifest.client.initialReductionPercent}%`);
assert.ok(manifest.client.deferredRouteKiB>=120,`R2 hard gate: client route CSS deferred must be >=120 KiB, actual ${manifest.client.deferredRouteKiB}`);
for(const [name,body] of Object.entries({engineering,work,management,field})){
  assert.ok(bytes(body)>1024,`R2 ${name} chunk is unexpectedly tiny (${bytes(body)} bytes)`);
}

assert.match(app,/const lazyStyleFiles=\{/);
assert.match(app,/engineering:'styles-engineering\.css'/);
assert.match(app,/work:'styles-work\.css'/);
assert.match(app,/operations:'styles-management\.css'/);
assert.match(app,/projectControl:'styles-management\.css'/);
assert.match(app,/siteSupervisor:'styles-field\.css'/);
assert.match(app,/function importLazyStyle\(key\)/);
assert.match(app,/function ensureFullCssFallback/);
assert.match(app,/function scheduleCanonicalCssCompletion/);
assert.match(app,/requestIdleCallback/);
assert.match(app,/Promise\.all\(\[importer\(\),importLazyStyle\(key\)\]\)/);
assert.match(app,/data-optimum-route-style/);
assert.match(app,/styles\.css\?v=6\.9\.0/,'full canonical CSS fallback must remain available');

const synthetic=`
:root{--x:1}
.core,.engineering-shell{color:red}
@media(max-width:700px){
  .engineering-shell .btn{color:blue}
  .work-only{content:"} safe"}
  .core{display:block}
}
@keyframes spin{from{opacity:0}to{opacity:1}}
.platform-only{display:grid}
.unknown-dead{display:none}
`;
assert.ok(parseTopLevelCss(synthetic).length>=5);
const syntheticSources={
  core:['const x="core btn";'],
  engineering:['const x="engineering-shell";'],
  work:['const x="work-only";'],
  management:[''],
  field:[''],
  platform:['const x="platform-only";']
};
const split=splitCssForDelivery(synthetic,syntheticSources);
assert.match(split.outputs.core,/@keyframes spin/);
assert.match(split.outputs.core,/\.unknown-dead/);
assert.match(split.outputs.engineering,/@media/);
assert.match(split.outputs.engineering,/\.engineering-shell/);
assert.match(split.outputs.work,/\.work-only/);
assert.match(split.outputs.platform,/\.platform-only/);
assert.equal(split.stats.selectors,split.stats.emittedSelectors);

console.log(JSON.stringify({
  PASS:'Performance R2 critical CSS & route styles',
  canonicalKiB:Number((bytes(canonicalNormalized)/1024).toFixed(1)),
  coreKiB:manifest.client.coreKiB,
  initialReductionPercent:manifest.client.initialReductionPercent,
  deferredRouteKiB:manifest.client.deferredRouteKiB,
  chunks:Object.fromEntries(Object.entries(manifest.chunks).map(([name,value])=>[name,Number((value.bytes/1024).toFixed(1))])),
  coverage:manifest.coverage,
  goal600KiB:manifest.client.coreKiB<=600
},null,2));
