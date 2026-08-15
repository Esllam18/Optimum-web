import fs from 'node:fs';
import assert from 'node:assert/strict';

const files=[
  'assets/styles.css',
  'public/assets/styles.css',
  'app/globals.css',
  'platform-console/assets/styles.css'
];
for(const file of files){
  const css=fs.readFileSync(file,'utf8');
  assert.equal(css.includes('\\\\n'),false,`${file} must not contain serialized literal \\n tokens`);
  assert.match(css,/dashboard-attention-empty\.r7\s*\{/);
  assert.match(css,/dashboard-decision-bar\.r7\.count-1/);
}
assert.equal(fs.readFileSync('assets/styles.css','utf8'),fs.readFileSync('public/assets/styles.css','utf8'));
assert.equal(fs.readFileSync('assets/styles.css','utf8'),fs.readFileSync('app/globals.css','utf8'));
assert.equal(fs.readFileSync('assets/styles.css','utf8'),fs.readFileSync('platform-console/assets/styles.css','utf8'));
console.log('PASS Optimum Premium Polish R7.1: CSS serialization, mirror integrity and compact dashboard states');
