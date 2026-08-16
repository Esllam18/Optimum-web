import fs from 'node:fs';

const path='package.json';
const pkg=JSON.parse(fs.readFileSync(path,'utf8'));
pkg.scripts ||= {};
pkg.scripts['test:certificationr2']='node tests/production-certification-r2.mjs';

let release=String(pkg.scripts['test:release']||'');
if(!release) throw new Error('test:release is missing');
if(!release.includes('test:certificationr2')){
  const anchor='&& npm run test:production-runtime';
  release=release.includes(anchor)
    ? release.replace(anchor,'&& npm run test:certificationr2 && npm run test:production-runtime')
    : `${release} && npm run test:certificationr2`;
}
pkg.scripts['test:release']=release;

fs.writeFileSync(path,`${JSON.stringify(pkg,null,2)}\n`,'utf8');
console.log('package.json R2 certification gate verified.');
