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
