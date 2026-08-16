import fs from 'node:fs';

const file='package.json';
const pkg=JSON.parse(fs.readFileSync(file,'utf8'));

pkg.scripts ||= {};
pkg.scripts['test:certificationr4']='node tests/production-certification-r4.mjs';

let release=String(pkg.scripts['test:release']||'');
if(!release) throw new Error('test:release is missing');

if(!release.includes('test:certificationr4')){
  const anchor='&& npm run test:production-runtime';
  release=release.includes(anchor)
    ? release.replace(anchor,'&& npm run test:certificationr4 && npm run test:production-runtime')
    : `${release} && npm run test:certificationr4`;
}

pkg.scripts['test:release']=release;
fs.writeFileSync(file,`${JSON.stringify(pkg,null,2)}\n`,'utf8');

console.log('package.json updated with Production Certification R4 gate.');
