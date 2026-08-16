alter table public.site_claim_package_events
  drop constraint if exists site_claim_package_events_type_check;

alter table public.site_claim_package_events
  add constraint site_claim_package_events_type_check
  check (event_type = any (array[
    'created'::text,
    'requirements_synced'::text,
    'evidence_collected'::text,
    'versions_frozen'::text,
    'submitted'::text,
    'approved'::text,
    'rejected'::text,
    'reopened'::text,
    'evidence_accepted'::text,
    'evidence_rejected'::text,
    'evidence_removed'::text,
    'package_exported'::text
  ]));
