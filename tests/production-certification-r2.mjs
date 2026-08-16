import fs from 'node:fs';
import assert from 'node:assert/strict';

const finalMigration='supabase/migrations/20260816112626_production_certification_r2_1_role_policy_cumulative_correction.sql';
const sql=fs.readFileSync(finalMigration,'utf8');
const pkg=JSON.parse(fs.readFileSync('package.json','utf8'));

const expected = {
  manager: [
    'company.view','members.view','roles.view','projects.view','projects.create','projects.edit','projects.archive','audit.view',
    'files.view','files.upload','files.create_folder','files.rename','files.move','files.archive','files.restore','files.download','files.manage',
    'search.use','notifications.view',
    'tasks.view','tasks.view_all','tasks.create','tasks.assign','tasks.edit','tasks.complete','tasks.claim','tasks.comment','tasks.attach','tasks.manage',
    'drawings.view','drawings.create','drawings.edit','drawings.publish','drawings.compare','drawings.export','drawings.review','boq.view','boq.edit','catalog.manage',
    'branding.view','roles.templates.use',
    'tasks.approve','tasks.manage_templates','tasks.manage_milestones','tasks.manage_automations','tasks.view_workload'
  ],
  engineer: [
    'company.view','members.view','projects.view',
    'files.view','files.upload','files.create_folder','files.rename','files.move','files.download','search.use','notifications.view',
    'tasks.view','tasks.create','tasks.edit','tasks.complete','tasks.claim','tasks.comment','tasks.attach',
    'drawings.view','drawings.create','drawings.edit','drawings.compare','drawings.export','drawings.review','boq.view','boq.edit',
    'branding.view','roles.templates.use'
  ],
  supervisor: [
    'company.view','members.view','projects.view',
    'files.view','files.upload','files.create_folder','files.download','search.use','notifications.view',
    'tasks.view','tasks.create','tasks.edit','tasks.complete','tasks.claim','tasks.comment','tasks.attach',
    'drawings.view','drawings.create','drawings.edit','drawings.compare','drawings.export','drawings.review','boq.view','boq.edit',
    'branding.view','roles.templates.use'
  ],
  viewer: [
    'company.view','projects.view','files.view','files.download','search.use','notifications.view','tasks.view',
    'drawings.view','drawings.export','boq.view','branding.view','roles.templates.use'
  ]
};

const expectedCounts={owner:55,admin:54,manager:46,engineer:28,supervisor:26,viewer:12};

function extractArray(role) {
  const re=new RegExp(`when '${role}' then array\\[([\\s\\S]*?)\\]::text\\[\\]`,'i');
  const match=sql.match(re);
  assert.ok(match,`Canonical array missing for ${role}`);
  return [...match[1].matchAll(/'([^']+)'/g)].map(m=>m[1]);
}

for(const [role,keys] of Object.entries(expected)) {
  const actual=extractArray(role);
  assert.equal(new Set(actual).size,actual.length,`Duplicate permission in ${role} policy`);
  assert.deepEqual([...actual].sort(),[...keys].sort(),`Canonical permission set mismatch for ${role}`);
  assert.equal(actual.length,expectedCounts[role],`Canonical count mismatch for ${role}`);
}

assert.match(sql,/when 'owner' then \([\s\S]*?array_agg\(p\.key order by p\.key\)/i,'Owner must track full permission catalog');
assert.match(sql,/when 'admin' then \([\s\S]*?where p\.key<>'company\.manage'/i,'Admin must track catalog except company.manage');

for(const [role,count] of Object.entries(expectedCounts)) {
  assert.ok(sql.includes(`('${role}',${count})`),`Runtime expected count missing for ${role}`);
}

for(const role of ['manager','engineer','supervisor','viewer']) {
  assert.ok(!extractArray(role).includes('tasks.recurring'),`Deprecated tasks.recurring must not be in canonical ${role} policy`);
}
assert.match(
  sql,
  /if exists\(select 1 from public\.permissions where key='tasks\.recurring'\) then[\s\S]*?raise exception 'Deprecated\/non-catalog task permission tasks\.recurring must not exist'/i,
  'Runtime guard must reject deprecated tasks.recurring from the permission catalog'
);
for(const key of ['tasks.approve','tasks.manage_templates','tasks.manage_milestones','tasks.manage_automations','tasks.view_workload']) {
  assert.ok(expected.manager.includes(key),`Manager must include ${key}`);
}
for(const role of ['engineer','supervisor','viewer']) {
  assert.ok(expected[role].includes('roles.templates.use'),`${role} must include roles.templates.use`);
}
for(const key of ['drawings.create','drawings.edit','boq.edit']) {
  assert.ok(expected.supervisor.includes(key),`Point 9 Site Supervisor must include ${key}`);
}

assert.match(sql,/perform app_private\.sync_company_protected_role_permissions\(p_company_id\)/i,'Fresh company seed must call canonical sync helper');
assert.match(sql,/for v_company in select id from public\.companies loop[\s\S]*?sync_company_protected_role_permissions\(v_company\)/i,'Existing company backfill must use same helper');
assert.match(sql,/r\.is_protected=true[\s\S]*?r\.slug in \('owner','admin','manager','engineer','supervisor','viewer'\)/i,'Normalization must be restricted to six protected roles');
assert.doesNotMatch(sql,/delete from public\.(member_role_addons|member_permission_overrides|resource_)/i,'Member/add-on/resource override layers must remain untouched');
assert.match(sql,/revoke all on function app_private\.protected_role_permission_keys\(text\)[\s\S]*?from public,anon,authenticated/i);
assert.match(sql,/revoke all on function app_private\.sync_company_protected_role_permissions\(uuid\)[\s\S]*?from public,anon,authenticated/i);
assert.match(sql,/revoke all on function app_private\.seed_company_roles\(uuid\)[\s\S]*?from public,anon,authenticated/i);

assert.equal(pkg.scripts?.['test:certificationr2'],'node tests/production-certification-r2.mjs');
assert.match(pkg.scripts?.['test:release']||'',/test:certificationr2/);

console.log('PASS Production Certification R2.1: cumulative protected-role policy 55/54/46/28/26/12, stale-seed regressions blocked, fresh/existing company source-of-truth unified');
