# Optimum — Production Certification R3 / Fresh Company Lifecycle

## Certified base
- Parent branch: `audit/production-certification-r2`
- Parent SHA: `c41061fb9689983d1c0d220d4f598da268000d3d`
- Production `main` remained unchanged at `7e22e367e5cb66f59422af03423d4769e66cc1fd`.

## Live transactional lifecycle
A complete fresh-company lifecycle was executed against production Supabase inside a transaction and rolled back.

Covered path:
1. Platform Admin JWT context.
2. `platform_create_company()` on Enterprise plan.
3. Six protected roles seeded at 55 / 54 / 46 / 28 / 26 / 12.
4. Owner invitation acceptance and 55 effective permissions.
5. Project creation + Project 360.
6. Site creation + Site 360 + automatic final claim package.
7. Cabinet creation + cabinet workspace root + Cabinet 360.
8. Task creation + task detail.
9. Site daily log.
10. CDE upload reservation + ready current version.
11. Claim requirement + evidence linking.
12. Claim 360 at 100% required readiness and 100% cabinet coverage.
13. Freeze exact versions.
14. Export manifest: ready, zero missing requirements, one pinned item, no commercial fields.
15. Submit package.
16. Record export and verify export history in manifest.
17. Platform / invitation / task audit events.

Final rollback verification:
- company rows remaining: 0
- project rows remaining: 0
- site rows remaining: 0
- cabinet rows remaining: 0
- document rows remaining: 0
- task rows remaining: 0

## Production defects found and fixed live

### 1. Site-claim submit notification schema mismatch
`app_private.capture_site_claim_lifecycle_event()` called a non-existent:
`public.notify_company_members(...)`

The real helper is:
`app_private.notify_company_members(...)`

Live migration:
`20260816115956 production_certification_r3_site_claim_notification_schema_fix`

### 2. Export event CHECK constraint drift
`record_site_claim_export()` emitted:
`package_exported`

but `site_claim_package_events_type_check` did not permit it.

Live migration:
`20260816120100 production_certification_r3_site_claim_export_event_constraint_fix`

The CHECK remains closed to the certified event vocabulary; only the missing official event was added.

## Result
After both fixes, the full transactional fresh-company lifecycle passed end-to-end through claim export and rolled back cleanly.
