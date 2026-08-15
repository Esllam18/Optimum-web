begin;

-- CAD production hardening: resource-scoped reads/writes, lightweight register,
-- and lazy drawing context so the register never downloads every revision snapshot.

create or replace function app_private.can_view_engineering_drawing(p_drawing_id uuid)
returns boolean
language sql
stable
security definer
set search_path='public','app_private','pg_temp'
as $$
  select exists(
    select 1
    from public.engineering_drawings d
    where d.id=p_drawing_id
      and app_private.user_has_resource_permission(
        auth.uid(),d.company_id,'drawings.view',d.project_id,d.site_id,d.folder_id,d.id
      )
  );
$$;

-- Make direct Data API reads honor resource scope as well as company membership.
drop policy if exists engineering_drawings_select on public.engineering_drawings;
create policy engineering_drawings_select on public.engineering_drawings
for select to authenticated
using (app_private.user_has_resource_permission(auth.uid(),company_id,'drawings.view',project_id,site_id,folder_id,id));

drop policy if exists engineering_revisions_select on public.engineering_revisions;
create policy engineering_revisions_select on public.engineering_revisions
for select to authenticated
using (exists(select 1 from public.engineering_drawings d where d.id=drawing_id and app_private.can_view_engineering_drawing(d.id)));

drop policy if exists engineering_boq_select on public.engineering_revision_boq;
create policy engineering_boq_select on public.engineering_revision_boq
for select to authenticated
using (exists(
  select 1 from public.engineering_revisions r
  join public.engineering_drawings d on d.id=r.drawing_id
  where r.id=revision_id
    and app_private.user_has_resource_permission(auth.uid(),d.company_id,'boq.view',d.project_id,d.site_id,d.folder_id,d.id)
));

drop policy if exists engineering_marks_select on public.engineering_review_marks;
create policy engineering_marks_select on public.engineering_review_marks
for select to authenticated
using (app_private.can_view_engineering_drawing(drawing_id));

drop policy if exists engineering_mark_updates_select on public.engineering_review_mark_updates;
create policy engineering_mark_updates_select on public.engineering_review_mark_updates
for select to authenticated
using (exists(select 1 from public.engineering_review_marks m where m.id=mark_id and app_private.can_view_engineering_drawing(m.drawing_id)));

drop policy if exists engineering_assets_select on public.engineering_assets;
create policy engineering_assets_select on public.engineering_assets
for select to authenticated
using (app_private.can_view_engineering_drawing(drawing_id) and (state='ready' or uploaded_by=auth.uid()));

drop policy if exists engineering_document_links_select on public.engineering_document_links;
create policy engineering_document_links_select on public.engineering_document_links
for select to authenticated
using (app_private.can_view_engineering_drawing(drawing_id));


-- Storage cleanup must obey drawing resource scope as well; upload-owner cleanup stays allowed.
drop policy if exists engineering_assets_storage_delete on storage.objects;
create policy engineering_assets_storage_delete on storage.objects for delete to authenticated using(
  bucket_id='engineering-assets' and exists(
    select 1
    from public.engineering_assets a
    join public.engineering_drawings d on d.id=a.drawing_id
    where a.storage_path=objects.name
      and (
        a.uploaded_by=auth.uid()
        or app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.edit',d.project_id,d.site_id,d.folder_id,d.id)
      )
  )
);

-- Central resource-write guard for child tables used by SECURITY DEFINER RPCs.
create or replace function app_private.enforce_engineering_resource_write()
returns trigger
language plpgsql
security definer
set search_path='public','app_private','pg_temp'
as $$
declare
  v_drawing_id uuid;
  d public.engineering_drawings%rowtype;
  v_ok boolean:=false;
begin
  if auth.uid() is null then return case when tg_op='DELETE' then old else new end; end if;

  if tg_table_name='engineering_revisions' then
    v_drawing_id:=coalesce(new.drawing_id,old.drawing_id);
  elsif tg_table_name='engineering_revision_boq' then
    select r.drawing_id into v_drawing_id from public.engineering_revisions r where r.id=coalesce(new.revision_id,old.revision_id);
  elsif tg_table_name='engineering_review_marks' then
    v_drawing_id:=coalesce(new.drawing_id,old.drawing_id);
  elsif tg_table_name='engineering_review_mark_updates' then
    select m.drawing_id into v_drawing_id from public.engineering_review_marks m where m.id=coalesce(new.mark_id,old.mark_id);
  elsif tg_table_name='engineering_assets' then
    v_drawing_id:=coalesce(new.drawing_id,old.drawing_id);
  elsif tg_table_name='engineering_document_links' then
    v_drawing_id:=coalesce(new.drawing_id,old.drawing_id);
  else
    return case when tg_op='DELETE' then old else new end;
  end if;

  select * into d from public.engineering_drawings where id=v_drawing_id;
  if not found then raise exception 'Drawing scope is invalid'; end if;

  if tg_table_name in ('engineering_review_marks','engineering_review_mark_updates') then
    v_ok:=app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.review',d.project_id,d.site_id,d.folder_id,d.id);
  elsif tg_table_name='engineering_revision_boq' then
    v_ok:=app_private.user_has_resource_permission(auth.uid(),d.company_id,'boq.edit',d.project_id,d.site_id,d.folder_id,d.id)
      or app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.edit',d.project_id,d.site_id,d.folder_id,d.id);
  elsif tg_table_name='engineering_assets' then
    v_ok:=app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.edit',d.project_id,d.site_id,d.folder_id,d.id)
      or app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.export',d.project_id,d.site_id,d.folder_id,d.id);
  elsif tg_table_name='engineering_document_links' then
    v_ok:=app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.edit',d.project_id,d.site_id,d.folder_id,d.id)
      or app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.export',d.project_id,d.site_id,d.folder_id,d.id);
  elsif tg_table_name='engineering_revisions' then
    v_ok:=app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.edit',d.project_id,d.site_id,d.folder_id,d.id)
      or app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.publish',d.project_id,d.site_id,d.folder_id,d.id);
  end if;

  if not coalesce(v_ok,false) then raise exception 'Resource access scope does not allow this engineering operation'; end if;
  if tg_op<>'DELETE' and tg_table_name not in ('engineering_assets') and not app_private.project_context_operational(d.project_id,d.site_id) then
    raise exception 'Project or site is archived';
  end if;
  return case when tg_op='DELETE' then old else new end;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array['engineering_revisions','engineering_revision_boq','engineering_review_marks','engineering_review_mark_updates','engineering_assets','engineering_document_links'] loop
    execute format('drop trigger if exists engineering_resource_write_guard on public.%I',t);
    execute format('create trigger engineering_resource_write_guard before insert or update or delete on public.%I for each row execute function app_private.enforce_engineering_resource_write()',t);
  end loop;
end$$;

-- Lightweight register payload. No revision snapshot, BOQ row body, mark body,
-- asset metadata, or document-link list is downloaded until a drawing is opened.
create or replace function public.engineering_directory_snapshot(p_company_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path='public','app_private','pg_temp'
as $$
begin
  if auth.uid() is null or not app_private.user_has_company_permission(auth.uid(),p_company_id,'drawings.view') then
    raise exception 'Permission denied';
  end if;
  return jsonb_build_object(
    'drawings',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',d.id,'company_id',d.company_id,'project_id',d.project_id,'site_id',d.site_id,'folder_id',d.folder_id,
        'source_document_id',d.source_document_id,'drawing_no',d.drawing_no,'title',d.title,'discipline',d.discipline,
        'drawing_type',d.drawing_type,'status',d.status,'current_revision_id',d.current_revision_id,'created_by',d.created_by,
        'updated_by',d.updated_by,'created_at',d.created_at,'updated_at',d.updated_at,'archived_at',d.archived_at
      ) order by d.updated_at desc)
      from public.engineering_drawings d
      where d.company_id=p_company_id
        and app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.view',d.project_id,d.site_id,d.folder_id,d.id)
    ),'[]'::jsonb),
    'revisions',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',r.id,'company_id',r.company_id,'drawing_id',r.drawing_id,'revision_number',r.revision_number,
        'revision_code',r.revision_code,'status',r.status,'change_note',r.change_note,'lock_version',r.lock_version,
        'created_by',r.created_by,'created_at',r.created_at,'updated_at',r.updated_at,'submitted_at',r.submitted_at,'published_at',r.published_at
      ) order by r.revision_number desc)
      from public.engineering_revisions r
      join public.engineering_drawings d on d.id=r.drawing_id
      where d.company_id=p_company_id
        and app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.view',d.project_id,d.site_id,d.folder_id,d.id)
    ),'[]'::jsonb),
    'catalog',coalesce((
      select jsonb_agg(to_jsonb(c) order by c.sort_order,c.code)
      from public.engineering_catalog_items c
      where c.is_active and (c.company_id is null or c.company_id=p_company_id)
    ),'[]'::jsonb),
    'stats',jsonb_build_object(
      'revision_count',(select count(*) from public.engineering_revisions r join public.engineering_drawings d on d.id=r.drawing_id where d.company_id=p_company_id and app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.view',d.project_id,d.site_id,d.folder_id,d.id)),
      'boq_count',(select count(*) from public.engineering_revision_boq b join public.engineering_revisions r on r.id=b.revision_id join public.engineering_drawings d on d.id=r.drawing_id where d.company_id=p_company_id and app_private.user_has_resource_permission(auth.uid(),d.company_id,'boq.view',d.project_id,d.site_id,d.folder_id,d.id)),
      'open_mark_count',(select count(*) from public.engineering_review_marks m join public.engineering_drawings d on d.id=m.drawing_id where d.company_id=p_company_id and m.status in('open','reopened','in_progress') and app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.view',d.project_id,d.site_id,d.folder_id,d.id))
    )
  );
end;
$$;

create or replace function public.engineering_drawing_360(p_drawing_id uuid,p_revision_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path='public','app_private','pg_temp'
as $$
declare
  d public.engineering_drawings%rowtype;
  r public.engineering_revisions%rowtype;
  v_operational boolean;
  v_can_edit boolean;
  v_can_publish boolean;
  v_can_review boolean;
  v_can_export boolean;
begin
  select * into d from public.engineering_drawings where id=p_drawing_id;
  if not found or not app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.view',d.project_id,d.site_id,d.folder_id,d.id) then
    raise exception 'Permission denied';
  end if;
  select * into r from public.engineering_revisions
   where drawing_id=d.id and (p_revision_id is null or id=p_revision_id)
   order by case when id=d.current_revision_id then 0 else 1 end,revision_number desc limit 1;
  if not found then raise exception 'Revision not found'; end if;

  v_operational:=d.archived_at is null and app_private.project_context_operational(d.project_id,d.site_id);
  v_can_edit:=v_operational and app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.edit',d.project_id,d.site_id,d.folder_id,d.id);
  v_can_publish:=v_operational and app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.publish',d.project_id,d.site_id,d.folder_id,d.id);
  v_can_review:=v_operational and app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.review',d.project_id,d.site_id,d.folder_id,d.id);
  v_can_export:=app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.export',d.project_id,d.site_id,d.folder_id,d.id);

  return jsonb_build_object(
    'drawing',to_jsonb(d),
    'revision',to_jsonb(r),
    'revisions',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',x.id,'company_id',x.company_id,'drawing_id',x.drawing_id,'revision_number',x.revision_number,
        'revision_code',x.revision_code,'status',x.status,'change_note',x.change_note,'lock_version',x.lock_version,
        'created_by',x.created_by,'created_at',x.created_at,'updated_at',x.updated_at,'submitted_at',x.submitted_at,'published_at',x.published_at
      ) order by x.revision_number desc) from public.engineering_revisions x where x.drawing_id=d.id
    ),'[]'::jsonb),
    'boq',case when app_private.user_has_resource_permission(auth.uid(),d.company_id,'boq.view',d.project_id,d.site_id,d.folder_id,d.id) then coalesce((select jsonb_agg(to_jsonb(b) order by b.category,b.item_code) from public.engineering_revision_boq b where b.revision_id=r.id),'[]'::jsonb) else '[]'::jsonb end,
    'marks',coalesce((select jsonb_agg(to_jsonb(m) order by m.created_at desc) from public.engineering_review_marks m where m.revision_id=r.id),'[]'::jsonb),
    'mark_updates',coalesce((select jsonb_agg(to_jsonb(u) order by u.created_at) from public.engineering_review_mark_updates u join public.engineering_review_marks m on m.id=u.mark_id where m.revision_id=r.id),'[]'::jsonb),
    'assets',coalesce((select jsonb_agg(to_jsonb(a) order by a.created_at desc) from public.engineering_assets a where a.drawing_id=d.id and (a.state='ready' or a.uploaded_by=auth.uid())),'[]'::jsonb),
    'links',coalesce((select jsonb_agg(to_jsonb(l) order by l.created_at desc) from public.engineering_document_links l where l.drawing_id=d.id),'[]'::jsonb),
    'capabilities',jsonb_build_object(
      'context_read_only',not v_operational,
      'can_edit',v_can_edit,
      'can_publish',v_can_publish,
      'can_review',v_can_review,
      'can_export',v_can_export
    )
  );
end;
$$;

revoke all on function public.engineering_directory_snapshot(uuid) from public,anon;
grant execute on function public.engineering_directory_snapshot(uuid) to authenticated;
revoke all on function public.engineering_drawing_360(uuid,uuid) from public,anon;
grant execute on function public.engineering_drawing_360(uuid,uuid) to authenticated;
revoke all on function app_private.enforce_engineering_resource_write() from public,anon,authenticated;

commit;
