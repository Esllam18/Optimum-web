import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = (p) => fs.readFileSync(new URL(`../${p}`, import.meta.url), 'utf8');
const root = read('assets/engineering.js');
const pub = read('public/assets/engineering.js');
const css = read('assets/styles.css');
const migration = read('supabase/migrations/20260812122139_phase6_9_cad_production_hardening.sql');

assert.equal(root, pub, 'public CAD runtime must mirror root runtime exactly');
for (const needle of [
  "engineering_directory_snapshot",
  "engineering_drawing_360",
  "registerStats",
  "loadEpoch",
  "openEpoch",
  "loadDrawingContext",
  "ensureRevisionDetail",
  "drawingContextReadOnly",
  "context_read_only",
  "loadFilesData({refreshDirectory:true})"
]) assert.ok(root.includes(needle), `CAD production hardening missing ${needle}`);

assert.ok(!/\['markUpdates',api\.select\('engineering_review_mark_updates',[\s\S]{0,500}\['assets',api\.select\('engineering_assets',[\s\S]{0,500}\['links',api\.select\('engineering_document_links'/.test(root), 'register must not globally pull mark updates, assets and links');
assert.ok(root.includes("file.size>52428800") && root.includes("file.size>15728640"), 'reference upload must have client-side payload guards');
assert.ok(css.includes('.cad-readonly-context'), 'archived CAD context needs a visible read-only banner');

for (const needle of [
  'app_private.can_view_engineering_drawing',
  'app_private.user_has_resource_permission',
  'app_private.enforce_engineering_resource_write',
  'engineering_resource_write_guard',
  'engineering_directory_snapshot',
  'engineering_drawing_360',
  "'context_read_only',not v_operational",
  "grant execute on function public.engineering_directory_snapshot",
  "grant execute on function public.engineering_drawing_360"
]) assert.ok(migration.includes(needle), `CAD migration missing ${needle}`);

console.log('Phase 6.9 CAD production hardening checks passed.');
