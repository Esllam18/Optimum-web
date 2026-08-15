import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const root=process.cwd();
const read=(rel)=>fs.readFileSync(path.join(root,rel),'utf8');
const platform=read('assets/platform.js');
const platformPublic=read('public/assets/platform.js');
const platformConsole=read('platform-console/assets/platform.js');
const html=read('platform-console/index.html');
const server=read('platform-console/server.mjs');
const migration=read('supabase/migrations/20260812125055_phase6_9_platform_console_production_hardening.sql');
const pkg=JSON.parse(read('package.json'));

assert.equal(platform,platformPublic,'public platform.js must mirror canonical asset');
assert.equal(platform,platformConsole,'standalone platform.js must mirror canonical asset');

for(const needle of [
  "supportedIdentityImages=new Map([['image/jpeg','jpg'],['image/png','png'],['image/webp','webp']])",
  'dataEpoch: 0, detailEpoch: 0','const epoch=++state.dataEpoch','const detailEpoch=++state.detailEpoch','function clearPlatformData()',
  "document.querySelector('meta[name=\"optimum-client-app-url\"]')?.content",
  'branding_neutral_color','branding_favicon_path','branding_cover_path','branding_radius_style','branding_density','branding_logo_shape',
  'name="country_code"','name="address"','name="timezone"','name="default_locale"','name="primary_contact_name"',
  'primary_contact_name:data.primary_contact_name','country_code:data.country_code','address:data.address','timezone:data.timezone','default_locale:data.default_locale'
]) assert.ok(platform.includes(needle),`Platform production hardening missing ${needle}`);
assert.ok(!platform.includes('image/svg+xml" />') && !platform.includes('image/svg+xml,image/'), 'Platform uploads must not accept SVG identity images');

assert.ok(html.includes('<meta name="optimum-client-app-url" content="__OPTIMUM_CLIENT_APP_URL__" />'),'Standalone console must use CSP-safe meta configuration');
assert.ok(!html.includes('<script>window.OPTIMUM_CLIENT_APP_URL'),'Standalone console must not depend on inline script blocked by CSP');
assert.ok(server.includes("script-src 'self'"),'Standalone console must retain strict script CSP');
assert.ok(server.includes('escapeHtmlAttr(clientAppUrl)'),'Injected client URL must be escaped as an HTML attribute');

for(const needle of [
  'drop function if exists public.platform_company_directory()','member_counts as materialized','project_counts as materialized','storage_counts as materialized','owner_members as materialized',
  'address text','website text','billing_contact_name text','technical_contact_name text','internal_notes text','timezone text','default_locale text',
  'branding_favicon_path text','branding_cover_path text','branding_neutral_color text','branding_sidebar_style text','branding_radius_style text','branding_density text','branding_logo_shape text',
  "where app_private.is_platform_admin()","revoke all on function public.platform_company_directory() from public,anon",
  "'platform.company_entitlement_override'",'Unknown entitlement key','Entitlement limits must be a JSON object'
]) assert.ok(migration.includes(needle),`Platform DB hardening missing ${needle}`);

assert.ok(pkg.scripts['test:release']?.includes('platform-console-production-hardening-6.9.mjs'),'Platform hardening gate must run in test:release');
console.log('Phase 6.9 Platform Console production hardening static checks passed.');
