import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { join, relative, resolve } from 'node:path';

const root = process.cwd();

async function walk(dir) {
  const rows=[];
  for (const entry of await readdir(dir,{withFileTypes:true})) {
    const full=join(dir,entry.name);
    if(entry.isDirectory()) rows.push(...await walk(full));
    else if(entry.isFile()) rows.push(full);
  }
  return rows;
}

async function verifyIntegrity(dir) {
  const manifest=JSON.parse(await readFile(join(dir,'integrity.json'),'utf8'));
  const files=(await walk(dir)).filter(f=>!f.endsWith('integrity.json'));
  assert.equal(Object.keys(manifest).length,files.length,`${dir}: integrity file count drift`);
  for(const file of files){
    const key=relative(dir,file).replaceAll('\\','/');
    const body=await readFile(file);
    assert.equal(manifest[key]?.bytes,body.length,`${dir}: size mismatch ${key}`);
    assert.equal(manifest[key]?.sha256,createHash('sha256').update(body).digest('hex'),`${dir}: sha mismatch ${key}`);
  }
}

async function waitFor(url, timeout=8000){
  const started=Date.now();
  while(Date.now()-started<timeout){
    try{const r=await fetch(url);if(r.ok)return r;}catch{}
    await new Promise(r=>setTimeout(r,80));
  }
  throw new Error(`Timed out waiting for ${url}`);
}

async function withServer({cwd,port,env={}},fn){
  const child=spawn(process.execPath,['server.mjs'],{cwd,env:{...process.env,...env,HOST:'127.0.0.1',PORT:String(port),PLATFORM_PORT:String(port)},stdio:['ignore','pipe','pipe']});
  let logs=''; child.stdout.on('data',d=>logs+=d);child.stderr.on('data',d=>logs+=d);
  try{await waitFor(`http://127.0.0.1:${port}/health`);await fn(`http://127.0.0.1:${port}`);}catch(e){e.message+=`\nserver logs:\n${logs}`;throw e;}finally{child.kill('SIGTERM');await new Promise(r=>{child.once('exit',r);setTimeout(r,1500);});}
}

const dist=resolve(root,'dist');
const platformDist=resolve(root,'dist-platform');
await verifyIntegrity(dist);
await verifyIntegrity(platformDist);

const distPkg=JSON.parse(await readFile(join(dist,'package.json'),'utf8'));
assert.equal(distPkg.scripts.start,'node server.mjs');
assert.ok(!distPkg.dependencies,'production bundle must not require runtime npm dependencies');

await withServer({cwd:dist,port:4213},async(base)=>{
  const health=await fetch(`${base}/health`);assert.equal(health.status,200);assert.equal((await health.json()).release,'6.9.0');
  const home=await fetch(`${base}/`);assert.equal(home.status,200);assert.match(home.headers.get('content-security-policy')||'',/object-src 'none'/);assert.match(home.headers.get('permissions-policy')||'',/camera=\(\)/);assert.match(home.headers.get('strict-transport-security')||'',/max-age=31536000/);
  const platform=await fetch(`${base}/platform`);assert.equal(platform.status,200);assert.match(await platform.text(),/data-app="platform"/);
  const spa=await fetch(`${base}/work/deep-link`);assert.equal(spa.status,200);assert.match(await spa.text(),/<div id="app"/);
  const asset=await fetch(`${base}/assets/app.js?v=6.9.0`,{headers:{'Accept-Encoding':'br'}});assert.equal(asset.status,200);assert.equal(asset.headers.get('cache-control'),'public, max-age=300, must-revalidate');assert.ok(asset.headers.get('etag'));
  const conditional=await fetch(`${base}/assets/app.js?v=6.9.0`,{headers:{'If-None-Match':asset.headers.get('etag')}});assert.equal(conditional.status,304);
  assert.equal((await fetch(`${base}/assets/does-not-exist.js`)).status,404);
  assert.equal((await fetch(`${base}/`,{method:'POST'})).status,405);
});

await withServer({cwd:platformDist,port:4214,env:{OPTIMUM_CLIENT_APP_URL:'https://client.optimum.example/'}},async(base)=>{
  const health=await fetch(`${base}/health`);assert.equal(health.status,200);assert.equal((await health.json()).service,'optimum-platform-console');
  const page=await fetch(`${base}/`);assert.equal(page.status,200);const html=await page.text();assert.match(html,/https:\/\/client\.optimum\.example\//);assert.match(page.headers.get('content-security-policy')||'',/script-src 'self'/);
});

console.log('Optimum 6.9 zero-dependency production runtime bundle: PASS');
