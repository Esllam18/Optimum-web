import assert from 'node:assert/strict';
import fs from 'node:fs';
const app=fs.readFileSync('assets/app.js','utf8');
const mirror=fs.readFileSync('public/assets/app.js','utf8');
const edge=fs.readFileSync('supabase/functions/identity-provisioning/index.ts','utf8');
const edge55=fs.readFileSync('supabase/functions/identity-provisioning-v55/index.ts','utf8');
for (const [name,text] of [['app',app],['public mirror',mirror]]) {
  assert.match(text,/function passwordPolicyValid\(value=''\)/,`${name}: explicit password policy missing`);
  assert.match(text,/value\.length >= 12[^;]*&& \/\[a-z\]\//,`${name}: 12-char policy missing`);
  assert.match(text,/minlength="12"/,`${name}: password input minimum not 12`);
  assert.match(text,/Upper and lower case/,`${name}: mixed-case rule missing`);
  assert.match(text,/At least one number/,`${name}: numeric rule missing`);
  assert.match(text,/A special symbol/,`${name}: symbol rule missing`);
}
assert.match(edge,/strongPassword\(v: string\).*v\.length >= 12/, 'identity-provisioning server policy must require 12 chars');
assert.match(edge55,/const strong=\(value:string\)=>value\.length>=12/, 'identity-provisioning-v55 server policy must require 12 chars');
assert.match(edge,/randomPassword\(\)[\s\S]*crypto\.getRandomValues/, 'temporary passwords must remain cryptographically generated');
assert.match(edge55,/verify_jwt|Authentication required|Bearer /, 'verified identity flow must require authenticated access');
console.log('Free-plan auth baseline 6.9: PASS');
