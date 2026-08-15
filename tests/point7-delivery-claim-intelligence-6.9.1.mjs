import fs from 'node:fs';
import assert from 'node:assert/strict';

const app=fs.readFileSync('assets/app.js','utf8');
const appMirror=fs.readFileSync('public/assets/app.js','utf8');
const styles=fs.readFileSync('assets/styles.css','utf8');
const publicStyles=fs.readFileSync('public/assets/styles.css','utf8');
const nextStyles=fs.readFileSync('app/globals.css','utf8');
const platformStyles=fs.readFileSync('platform-console/assets/styles.css','utf8');
const migration=fs.readFileSync('supabase/migrations/20260815071500_point7_delivery_claim_intelligence.sql','utf8');

for(const marker of [
  "activity:'audit.view', delivery:'files.view'",
  "['delivery','archive',()=>L('التسليم والمستخلصات','Delivery & Claims')]",
  "delivery_directory_query",
  "delivery_closeout_map",
  "delivery-package-card",
  "delivery-closeout-map",
  "refresh-delivery-package",
  "approve-claim",
  "reject-claim",
  "review-claim-item",
  "review-claim-item-reject",
  "claim-smart-discovery",
  "claim-event-timeline",
  "claim-stale-warning",
  "cabinet-closeout-panel",
  "open-delivery-project",
  "data-form=\"claim-reject\"",
  "data-form=\"claim-item-reject\""
]) assert.ok(app.includes(marker),`Point 7 app missing ${marker}`);

for(const marker of [
  '.delivery-guide','.delivery-center-grid','.delivery-package-card','.delivery-closeout-map',
  '.delivery-closeout-cabinet','.cabinet-closeout-panel','.claim-stale-warning',
  '.claim-smart-discovery','.claim-event-timeline','.claim-item-state'
]) assert.ok(styles.includes(marker),`Point 7 CSS missing ${marker}`);

for(const marker of [
  'site_claim_package_events','refresh_site_delivery_package','review_site_claim_item',
  'approve_site_claim_package','reject_site_claim_package','site_claim_package_intelligence',
  'cabinet_closeout_snapshot','delivery_closeout_map','document_requirements',
  'document_requirement_links','selected_version_id','notify_company_members',
  'Evidence changed after submission'
]) assert.ok(migration.includes(marker),`Point 7 migration missing ${marker}`);

assert.ok(migration.includes("drl.document_id"),'Delivery refresh must reference the canonical CDE document link');
assert.ok(!/insert\s+into\s+public\.documents/i.test(migration),'Delivery intelligence must not duplicate CDE documents');
assert.ok(!/storage_path/i.test(migration),'Claim/Delivery tables must not copy storage paths');
assert.ok(migration.includes("i.selected_version_id is not null and d.current_version_id is distinct from i.selected_version_id"),'Approval must detect changed evidence versions');
assert.ok(migration.includes("v_bad>0"),'Approval must block rejected evidence');
assert.ok(migration.includes("v_reason is null"),'Package return must require a reason');
assert.ok(migration.includes("'collecting','ready','submitted','rejected'"),'Evidence review must support submitted packages');

assert.equal(app,appMirror,'assets/app.js mirror drifted from public/assets/app.js');
assert.equal(styles,publicStyles,'styles mirror drifted from public/assets/styles.css');
assert.equal(styles,nextStyles,'styles mirror drifted from app/globals.css');
assert.equal(styles,platformStyles,'styles mirror drifted from platform-console/assets/styles.css');

// Point 6.1 layout closure is intentionally part of the Point 7 baseline.
const engineering=fs.readFileSync('assets/engineering.js','utf8');
for(const marker of [
  "paletteWidth:Math.max(190,Math.min(380,num(localStorage.getItem('optimum.cad.paletteWidth')||232,232)))",
  "inspectorWidth:Math.max(220,Math.min(390,num(localStorage.getItem('optimum.cad.inspectorWidth')||258,258)))",
  "routeDockHeight:Math.max(88,Math.min(150,num(localStorage.getItem('optimum.cad.routeDockHeight')||96,96)))",
  'cad-toolbar-classic-r3',
  'cad-toolbar-r2-actions'
]) assert.ok(engineering.includes(marker),`Point 6.1 compact CAD layout missing ${marker}`);
for(const marker of ['Point 6.1 — Classic CAD workspace geometry','.cad-route-dock-r2']) assert.ok(styles.includes(marker),`Point 6.1 style missing ${marker}`);

console.log('PASS Point 7 Delivery & Claim Intelligence: CDE-native evidence, closeout map, review lifecycle, stale-version guard, novice UX, permissions, mirrors, and Point 6.1 layout closure');
