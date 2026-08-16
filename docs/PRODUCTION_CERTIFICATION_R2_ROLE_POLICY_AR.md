# Optimum — Production Certification R2.1 Protected Role Cumulative Policy Correction

## Why R2.0 stopped
The first R2 gate failed on `tasks.approve`. The failure was valid: it exposed that the latest `seed_company_roles()` implementation was not a complete cumulative role policy.

Historical migrations had added capabilities after earlier seed definitions:
- Phase 3 established execution task permissions.
- Phase 4 added engineering/CAD permissions.
- Phase 5.2 added branding and `roles.templates.use`.
- Phase 6.0 added `tasks.approve`, template/milestone/automation management, and workload visibility to roles that already had `tasks.manage`.
- Point 9 expanded the protected Supervisor into the Site Supervisor field-execution role.

Therefore the latest seed function by itself could not be treated as the canonical historical policy.

## Live R2.1 correction
Remote Supabase migration version:
`20260816112626`

Migration name:
`production_certification_r2_1_role_policy_cumulative_correction`

Final cumulative protected-role counts:
- Owner: 55
- Admin: 54
- Manager: 46
- Engineer: 28
- Site Supervisor: 26
- Viewer: 12

Important corrections:
- `tasks.recurring` is not a live permission and is excluded.
- Manager receives all five Phase 6.0 advanced task permissions.
- Engineer, Site Supervisor, and Viewer retain `roles.templates.use`.
- Site Supervisor retains Point 9 drawing create/edit and BOQ edit capabilities.

## Single source of truth
`app_private.protected_role_permission_keys(slug)` defines the canonical matrix.
`app_private.sync_company_protected_role_permissions(company_id)` applies it.
`app_private.seed_company_roles(company_id)` creates protected roles and then calls the same sync helper.
Existing companies are normalized by the same helper.

Normalization is restricted to the six protected roles. It does not delete or rewrite:
- custom roles
- member role add-ons
- member permission overrides
- resource/project/site/document access scopes

## Live verification
All existing companies were verified after R2.1 at:
55 / 54 / 46 / 28 / 26 / 12.

A fresh company was also inserted inside a transaction, seeded using `seed_company_roles()`, verified at the same six counts, and rolled back. A follow-up query confirmed zero dry-run company rows remained.

## Git safety
R2.0 failed before commit/push.
Remote `audit/production-certification-r2` did not exist at the time of R2.1 recovery preparation.
Production `main` remained at:
`7e22e367e5cb66f59422af03423d4769e66cc1fd`.
