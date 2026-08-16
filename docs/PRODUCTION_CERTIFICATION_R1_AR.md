# Optimum — Production Certification R1

## Baseline
- Production source: `main`
- Approved baseline SHA before this audit: `7e22e367e5cb66f59422af03423d4769e66cc1fd`
- Product UI baseline: Optimum 6.9.1 Premium Polish R7.1
- Deployment: Vercel static output (`public/`)
- Backend: live Supabase project `wzcaquxuvqfbstpxujsj`

## Findings closed in R1
1. **Vercel/static contract gap**
   - The portable server and post-deploy smoke expected `/health`, `/platform`, and security headers.
   - The Vercel deployment previously had no rewrites or security headers.
   - R1 adds the missing Vercel rewrites, security headers, and cache policies.

2. **Stale integrity manifest**
   - The source `integrity.json` was older than the R7.1 runtime files.
   - R1 removes the stale root manifest as a source of truth.
   - `build.mjs` now regenerates `public/integrity.json` from the actual deployment artifact on every build.

3. **Post-deploy certification alignment**
   - The old smoke test assumed the portable Node server's arbitrary extensionless SPA fallback.
   - The Vercel app uses hash routing, so R1 removes that false assumption.
   - Live smoke now verifies `/health`, `/platform`, security headers, caching, a real 404, and SHA-256 of live `assets/app.js` against the generated integrity manifest.

## Live backend checks completed before patch
- Key tenant/security tables verified with RLS enabled: companies, memberships, roles, role_permissions, projects, sites, site_cabinets, documents, document_versions, tasks, task_assignments, platform_admins, platform_audit_events, account_security, site_claim_exports.
- Sensitive platform/site-claim functions checked: security-definer where required, anonymous execute revoked, authenticated execute available.
- Platform directory/mutation migration confirms `app_private.is_platform_admin()` guard.
- Recent Point 6–11 / consolidated 9–10 migrations are present in the live migration ledger.

## R1 scope boundary
This closes **deployment/runtime hardening** only. The comprehensive production audit is not yet declared finished. The next certification pass is the role-by-role browser lifecycle: Platform Admin, Owner, Manager, Engineer, Site Supervisor, and limited member, followed by fresh-company onboarding through claim export.


## Additional live security/data sweep
- Found five Operations `SECURITY DEFINER` RPCs with inherited anonymous EXECUTE because their original migration granted `authenticated` without revoking PUBLIC.
- Internal membership guards meant this was not an active data leak, but the callable surface was broader than necessary.
- Applied live migration `20260816000215 production_certification_r1_operations_rpc_grants` and verified anonymous EXECUTE is now removed from all five Operations RPCs.
- The only anonymous `SECURITY DEFINER` RPC left is `invitation_preview(text)`, intentionally token-scoped for pre-login invitations; its live definition hashes the supplied token and returns only invitation preview fields.
- Cross-tenant/data invariants checked live: membership-role company scope, project/site/cabinet scope, task project/site scope, document project/site/version scope, duplicate active memberships, and multiple active owners. All returned zero violations.
- One trial company (`nahda-benisuef`) has zero members/owner. It is recorded as a cleanup candidate; no destructive data change was made during certification.
