import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const root=process.cwd();
const read=(rel)=>fs.readFileSync(path.join(root,rel),'utf8');
const platform=read('assets/platform.js');
const platformPublic=read('public/assets/platform.js');
const platformStandalone=read('platform-console/assets/platform.js');
const css=read('assets/styles.css');
const cssPublic=read('public/assets/styles.css');
const cssGlobals=read('app/globals.css');
const cssStandalone=read('platform-console/assets/styles.css');

assert.equal(platform,platformPublic,'public platform runtime mirror must match');
assert.equal(platform,platformStandalone,'standalone platform runtime mirror must match');
assert.equal(css,cssPublic,'public stylesheet mirror must match');
assert.equal(css,cssGlobals,'globals stylesheet mirror must match');
assert.equal(css,cssStandalone,'standalone platform stylesheet mirror must match');

for(const needle of [
  'function platformCompanyAttention(c)',
  'function platformAttentionItems()',
  'function platformDecisionSignal(',
  'function platformFootprint()',
  'platform-ops-cockpit','platform-decision-bar','platform-tenant-pulse','platform-attention-queue','platform-footprint',
  'platform-tenant-directory','platform-entity-link','platform-company-control-actions','platform-audit-center','platform-library-note',
  "L('مركز تحكم الشركة','Company control center')",
  "data-action=\"company-entitlements\"",
  "data-action=\"company-branding\"",
  "data-action=\"edit-company\""
]) assert.ok(platform.includes(needle),`Premium platform runtime missing ${needle}`);

for(const forbidden of ['class="platform-hero"','class="grid grid-4 platform-stats"','class="role-library-summary grid grid-4"','class="activity-kpi-grid"']) {
  assert.ok(!platform.includes(forbidden),`Legacy platform clutter must be removed: ${forbidden}`);
}

for(const needle of [
  'Point 10 / Feature 9 — Premium Platform Operations Console (6.9.1)',
  '.platform-ops-cockpit','.platform-decision-signal','.platform-ops-grid','.platform-attention-row',
  '.platform-inline-attention','.platform-company-control-actions','.platform-entity-link',
  '@media(max-width:700px)'
]) assert.ok(css.includes(needle),`Premium platform styles missing ${needle}`);

// Critical platform operations remain intact.
for(const needle of [
  "data-form=\"create-company\"",
  "data-form=\"edit-company\"",
  "data-form=\"role-template\"",
  "action:'create_company'",
  "reset_temporary_password",
  "set_company_entitlement_override",
  "platform_save_role_template_definition",
  "audit-export"
]) assert.ok(platform.includes(needle),`Critical platform operation missing ${needle}`);

console.log('Premium Point 10 Platform Console static acceptance: PASS');
