import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const mig1Path='supabase/migrations/20260816115956_production_certification_r3_site_claim_notification_schema_fix.sql';
const mig2Path='supabase/migrations/20260816120100_production_certification_r3_site_claim_export_event_constraint_fix.sql';
const mig1=fs.readFileSync(mig1Path,'utf8');
const mig2=fs.readFileSync(mig2Path,'utf8');
const pkg=JSON.parse(fs.readFileSync('package.json','utf8'));

assert.match(
  mig1,
  /create or replace function app_private\.capture_site_claim_lifecycle_event\(\)/i,
  'R3 claim lifecycle trigger function source sync missing'
);

assert.match(
  mig1,
  /perform app_private\.notify_company_members\(/i,
  'Site-claim lifecycle notifications must call app_private.notify_company_members'
);

assert.doesNotMatch(
  mig1,
  /perform public\.notify_company_members\(/i,
  'Broken public.notify_company_members call must never return'
);

for(const state of ['submitted','approved','rejected']) {
  assert.ok(mig1.includes(`'${state}'`),`Lifecycle notification coverage missing ${state}`);
}

const requiredEvents = [
  'created',
  'requirements_synced',
  'evidence_collected',
  'versions_frozen',
  'submitted',
  'approved',
  'rejected',
  'reopened',
  'evidence_accepted',
  'evidence_rejected',
  'evidence_removed',
  'package_exported'
];

for(const eventType of requiredEvents) {
  assert.ok(
    mig2.includes(`'${eventType}'::text`),
    `site_claim_package_events constraint missing ${eventType}`
  );
}

const eventArrayMatch = mig2.match(/check\s*\(event_type\s*=\s*any\s*\(array\[([\s\S]*?)\]\)\)/i);
assert.ok(eventArrayMatch,'R3 event-type CHECK array not found');
const actualEvents=[...eventArrayMatch[1].matchAll(/'([^']+)'::text/g)].map(m=>m[1]);
assert.deepEqual(
  [...new Set(actualEvents)].sort(),
  [...requiredEvents].sort(),
  'R3 event-type constraint must stay closed to the certified event vocabulary'
);

const migrationsDir='supabase/migrations';
const allSql=fs.readdirSync(migrationsDir)
  .filter(name=>name.endsWith('.sql'))
  .map(name=>fs.readFileSync(path.join(migrationsDir,name),'utf8'))
  .join('\n');

assert.match(
  allSql,
  /record_site_claim_event\(p\.id\s*,\s*'package_exported'/i,
  'record_site_claim_export must still emit package_exported'
);

assert.ok(pkg.scripts?.['test:certificationr3'],'test:certificationr3 script missing');
assert.match(pkg.scripts?.['test:release']||'',/test:certificationr3/,
  'Full release gate must include Production Certification R3');

console.log('PASS Production Certification R3: site-claim submit notifications resolve the private helper, export event vocabulary is aligned, and lifecycle regressions are blocked');
