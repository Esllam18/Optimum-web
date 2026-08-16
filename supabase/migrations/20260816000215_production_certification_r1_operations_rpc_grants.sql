begin;

-- Production Certification R1: authenticated-only Operations RPCs.
-- These functions already enforce company membership internally; this migration
-- closes the default PUBLIC execute grant so anon cannot invoke the surface.

revoke all on function public.toggle_entity_follow(uuid,text,uuid,boolean) from public, anon;
grant execute on function public.toggle_entity_follow(uuid,text,uuid,boolean) to authenticated;

revoke all on function public.operations_center_mark_seen(uuid) from public, anon;
grant execute on function public.operations_center_mark_seen(uuid) to authenticated;

revoke all on function public.save_operations_calendar_layers(uuid,jsonb) from public, anon;
grant execute on function public.save_operations_calendar_layers(uuid,jsonb) to authenticated;

revoke all on function public.operations_center_snapshot(uuid,integer) from public, anon;
grant execute on function public.operations_center_snapshot(uuid,integer) to authenticated;

revoke all on function public.operations_calendar_feed(uuid,timestamptz,timestamptz,uuid) from public, anon;
grant execute on function public.operations_calendar_feed(uuid,timestamptz,timestamptz,uuid) to authenticated;

commit;
