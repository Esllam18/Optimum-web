begin;

-- Final production RLS performance pass: initialize auth.uid() once per statement
-- instead of re-evaluating it for every candidate row.
drop policy if exists engineering_drawings_select on public.engineering_drawings;
create policy engineering_drawings_select on public.engineering_drawings
for select to authenticated
using (
  app_private.user_has_resource_permission(
    (select auth.uid()), company_id, 'drawings.view', project_id, site_id, folder_id, id
  )
);

drop policy if exists engineering_boq_select on public.engineering_revision_boq;
create policy engineering_boq_select on public.engineering_revision_boq
for select to authenticated
using (
  exists(
    select 1
    from public.engineering_revisions r
    join public.engineering_drawings d on d.id = r.drawing_id
    where r.id = revision_id
      and app_private.user_has_resource_permission(
        (select auth.uid()), d.company_id, 'boq.view', d.project_id, d.site_id, d.folder_id, d.id
      )
  )
);

drop policy if exists engineering_assets_select on public.engineering_assets;
create policy engineering_assets_select on public.engineering_assets
for select to authenticated
using (
  app_private.can_view_engineering_drawing(drawing_id)
  and (state = 'ready' or uploaded_by = (select auth.uid()))
);

commit;
