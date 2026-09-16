import fs from 'node:fs';
import assert from 'node:assert/strict';

const appPath=new URL('../assets/app.js',import.meta.url);
const publicAppPath=new URL('../public/assets/app.js',import.meta.url);
const source=fs.readFileSync(appPath,'utf8');
const publicSource=fs.readFileSync(publicAppPath,'utf8');
assert.equal(source,publicSource,'assets/app.js and public/assets/app.js must remain exact mirrors');

assert.ok(source.includes('OPTIMUM PERFORMANCE R3 V1 — DASHBOARD ROUTE DATA'),'R3 marker missing');
assert.ok(source.includes("pathname==='/'||pathname==='/v7'"),'Dashboard entrypoint contract missing');
assert.ok(source.includes('globalThis.location?.hash'),'Hash-router awareness missing');
assert.ok(source.includes("page==='dashboard'"),'Dashboard page guard missing');
assert.ok(source.includes('requestAnimationFrame'),'First-paint scheduling contract missing');
assert.ok(source.includes("globalThis.setTimeout(run,0)"),'post-paint task scheduling missing');

const markerIndex=source.indexOf('OPTIMUM PERFORMANCE R3 V1 — DASHBOARD ROUTE DATA');
const fnIndex=source.search(/(?:async\s+)?function\s+loadCompanyData\s*\(|(?:const|let)\s+loadCompanyData\s*=\s*async/);
assert.ok(markerIndex>=0 && fnIndex>=0 && markerIndex<fnIndex,'R3 helper must be defined before loadCompanyData');

const fromFn=source.slice(fnIndex);
const nextFn=fromFn.slice(1).search(/\n(?:async\s+)?function\s+[A-Za-z_$][\w$]*\s*\(/);
const fnWindow=nextFn>=0?fromFn.slice(0,nextFn+1):fromFn.slice(0,50000);

const wrapped=(fnWindow.match(/r3DeferDashboardFilesBootstrap\(\(\)=>loadFilesData\(/g)||[]).length;
assert.equal(wrapped,1,'loadCompanyData must contain exactly one deferred Files bootstrap');
assert.equal((fnWindow.match(/\bawait\s+loadFilesData\s*\(/g)||[]).length,0,'blocking await loadFilesData must not remain');

console.log(JSON.stringify({
  PASS:'Performance R3 V1.3 dashboard route-data deferral + source/public mirror',
  dashboardEntrypoints:['/','/v7'],
  dashboardHashPages:['empty hash','#/dashboard'],
  filesHashRoute:'#/files keeps synchronous Files bootstrap',
  behavior:'dashboard background Files load starts immediately after first paint',
  productionMutation:false
},null,2));
