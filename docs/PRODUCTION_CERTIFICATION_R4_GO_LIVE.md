# Optimum — Production Certification R4 / Go-Live Hardening

## Certified parent
- Parent branch: `audit/production-certification-r3-lifecycle`
- Parent SHA: `62693915e7b19d6d484513e1b3eeb191a1c98192`
- Production `main` remained unchanged at `7e22e367e5cb66f59422af03423d4769e66cc1fd`.

## Live R4 production audit

### Runtime / database health
- Active lock waiters: 0
- Invalid / not-ready / not-live indexes: 0
- Tenant tables containing `company_id` with RLS disabled: 0
- Core tenant-scope invariant violations: 0
- Duplicate active company memberships: 0
- Multiple active owners per company: 0

### Authenticated performance benchmark
Measured under a real `authenticated` JWT context with RLS active:
- `work_cockpit_snapshot`: ~266.6 ms average
- `work_delivery_snapshot`: ~239.4 ms average
- `work_task_query`: ~5.3 ms average

These measurements are materially better than historical `pg_stat_statements`
means for the two snapshot functions.

### Planner maintenance
`ANALYZE` was run on the core tenant/work/CDE/site-claim tables after the
transactional certification work to refresh planner statistics.

## Security hardening finding

`authenticated` had `USAGE` on `app_private` and inherited EXECUTE grants on
13 volatile SECURITY DEFINER helpers.

Important checks before remediation:
- `anon` has no USAGE on `app_private`.
- No RLS policy directly references a volatile `app_private` helper.
- No public SECURITY INVOKER function references a volatile `app_private` helper.
- Public business RPCs that use internal mutators are SECURITY DEFINER.

Therefore direct authenticated execution of volatile private mutators was
unnecessary and represented avoidable privilege surface.

## Live remediation

Migration:
`20260816121231 production_certification_r4_internal_mutator_grant_lockdown`

The migration revokes direct execution from:
- PUBLIC
- anon
- authenticated

for functions that are simultaneously:
- in schema `app_private`
- SECURITY DEFINER
- VOLATILE

It intentionally does **not** revoke stable/immutable permission predicates or
read helpers used by RLS and normal authenticated reads.

## Post-fix verification
- Authenticated volatile private mutators remaining executable: 0
- `save_project()` under authenticated JWT: PASS
- `save_site()` under authenticated JWT: PASS
- The write test ran inside a transaction and was rolled back.
- Final tenant/RLS/index/invariant audit: all zero violations.

## Go-live status
After R1 → R4:
- deployment/runtime contract: certified
- protected role policy: certified
- role-by-role permissions/RLS: certified
- fresh-company lifecycle through claim export: certified
- production DB/security/performance hardening: certified

After this R4 branch passes Full Release and Live Preview certification, the
next step is a guarded fast-forward promotion to `main`, followed by a final
Production URL smoke/integrity check.
