import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const appPath='assets/app.js';
const app=fs.readFileSync(appPath,'utf8');
const pkg=JSON.parse(fs.readFileSync('package.json','utf8'));

function staticImports(file){
  const body=fs.readFileSync(file,'utf8');
  const rows=[];
  const re=/^import\s+(?:[\s\S]*?\s+from\s+)?['"]([^'"]+)['"];?/gm;
  let m;
  while((m=re.exec(body))){
    const spec=m[1].split('?')[0];
    if(spec.startsWith('.')) rows.push(spec);
  }
  return rows;
}
function resolveLocal(from,spec){
  let target=path.resolve(path.dirname(from),spec);
  if(!path.extname(target)) target+='.js';
  return target;
}

const startupStaticSpecs=staticImports(appPath);
const deferred=[
  ['engineering.js','engineering'],
  ['work-os.js','work'],
  ['operations-center.js','operations'],
  ['project-control.js','projectControl'],
  ['site-supervisor.js','siteSupervisor']
];

for(const [file] of deferred){
  assert.ok(!startupStaticSpecs.includes(`./${file}`),
    `${file} must not be a static startup import`);
  assert.ok(app.includes(`import('./${file}?v=6.9.0')`),
    `${file} must be available through dynamic import`);
}

for(const file of ['access-engine.js','organization-os.js']){
  assert.ok(startupStaticSpecs.includes(`./${file}`),
    `${file} must remain in the core authorization/organization graph`);
}

for(const marker of [
  'prepareLazyModulesForPage',
  'loadDashboardWorkData',
  'prefetchLazyNavigation',
  'activateRoute',
  'lazyModuleDataCompany',
  "state.page==='tasks'||state.page==='calendar'",
  "dashboardHomeMode()",
  "ensureEngineering({load:true})",
  "ensureWorkOS({load:true})",
  "ensureSiteSupervisor({load:true})"
]) assert.ok(app.includes(marker),`Performance R1 missing ${marker}`);

assert.ok(!app.includes("if (can('drawings.view')) await engineering.load();"),
  'Engineering must not auto-load solely because the user has drawings permission');
assert.ok(!app.includes('if(await engineering.handleAction(action,el))return;'),
  'Engineering click delegation must tolerate the lazy module being absent');
assert.ok(!app.includes('if(await engineering.handleChange(ev))return;'),
  'Engineering change delegation must tolerate the lazy module being absent');
assert.ok(!app.includes('if(engineering.handleInput(ev))return;'),
  'Engineering input delegation must tolerate the lazy module being absent');

const root=path.resolve(appPath);
const seen=new Set();
let staticBytes=0;
function walk(file){
  const normalized=path.normalize(file);
  if(seen.has(normalized))return;
  seen.add(normalized);
  assert.ok(fs.existsSync(normalized),`Static graph file missing: ${path.relative(process.cwd(),normalized)}`);
  staticBytes+=fs.statSync(normalized).size;
  for(const spec of staticImports(normalized))walk(resolveLocal(normalized,spec));
}
walk(root);

const deferredBytes=deferred.reduce((sum,[file])=>{
  const p=path.resolve('assets',file);
  assert.ok(fs.existsSync(p),`Deferred module missing: ${file}`);
  return sum+fs.statSync(p).size;
},0);

const maxCriticalBytes=820*1024;
assert.ok(staticBytes<maxCriticalBytes,
  `Critical static JS graph is ${(staticBytes/1024).toFixed(1)} KiB; expected < ${(maxCriticalBytes/1024).toFixed(0)} KiB`);
assert.ok(deferredBytes>700*1024,
  `Deferred module split is only ${(deferredBytes/1024).toFixed(1)} KiB; expected a meaningful >700 KiB split`);

assert.equal(pkg.scripts?.['test:performance-r1'],
  'node tests/performance-r1-lazy-modules-6.9.1.mjs');
assert.match(pkg.scripts?.['test:release']||'',/test:performance-r1/,
  'Full Release must include Performance R1');

console.log(JSON.stringify({
  PASS:'Performance R1 lazy modules',
  criticalStaticGraphKiB:Number((staticBytes/1024).toFixed(1)),
  deferredModulesKiB:Number((deferredBytes/1024).toFixed(1)),
  staticGraphFiles:[...seen].map(x=>path.relative(process.cwd(),x).replaceAll('\\','/')),
  deferredFiles:deferred.map(([file])=>file)
},null,2));
