import fs from 'node:fs';
import assert from 'node:assert/strict';

const migrationPath='supabase/migrations/20260816121231_production_certification_r4_internal_mutator_grant_lockdown.sql';
const sql=fs.readFileSync(migrationPath,'utf8');
const pkg=JSON.parse(fs.readFileSync('package.json','utf8'));

assert.match(
  sql,
  /n\.nspname='app_private'/i,
  'R4 grant lockdown must be scoped to app_private only'
);

assert.match(
  sql,
  /p\.prosecdef/i,
  'R4 grant lockdown must target SECURITY DEFINER functions'
);

assert.match(
  sql,
  /p\.provolatile='v'/i,
  'R4 grant lockdown must target volatile mutators only'
);

assert.match(
  sql,
  /revoke all on function %s from public, anon, authenticated/i,
  'R4 must revoke direct execution from PUBLIC, anon and authenticated'
);

assert.doesNotMatch(
  sql,
  /p\.provolatile\s*(?:<>|!=)\s*'v'|p\.provolatile\s+in/i,
  'R4 must not broaden the lockdown beyond volatile private mutators'
);

assert.ok(
  pkg.scripts?.['test:certificationr4'],
  'test:certificationr4 script missing'
);

assert.match(
  pkg.scripts?.['test:release']||'',
  /test:certificationr4/,
  'Full release gate must include Production Certification R4'
);

console.log(
  'PASS Production Certification R4: internal volatile SECURITY DEFINER mutators are locked from direct authenticated execution without broadening into stable RLS/read predicates'
);
