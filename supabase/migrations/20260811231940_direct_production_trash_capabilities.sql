create or replace function public.trash_query(p_company_id uuid,p_query text default null,p_project_id uuid default null,p_site_id uuid default null,p_limit integer default 100,p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path='public','app_private','pg_temp' as $$
declare q text:=trim(coalesce(p_query,''));
begin
  if auth.uid() is null or not app_private.user_has_company_permission(auth.uid(),p_company_id,'files.view') then raise exception 'Permission denied'; end if;
  return jsonb_build_object(
    'folders',coalesce((select jsonb_agg(x order by x.trashed_at desc) from (
      select f.id,f.name,f.code,f.project_id,f.site_id,f.parent_id,f.trashed_at,f.trashed_by,f.trash_batch_id,f.trash_origin,p.name project_name,s.name site_name,pr.full_name trashed_by_name,
        (app_private.project_context_operational(f.project_id,f.site_id) and app_private.user_has_resource_permission(auth.uid(),p_company_id,'files.restore',f.project_id,f.site_id,f.id,null)) can_restore
      from public.folders f join public.projects p on p.id=f.project_id left join public.sites s on s.id=f.site_id left join public.profiles pr on pr.id=f.trashed_by
      where f.company_id=p_company_id and f.trashed_at is not null and f.trash_origin<>'ancestor' and not f.is_system
        and (p_project_id is null or f.project_id=p_project_id) and (p_site_id is null or f.site_id=p_site_id)
        and (q='' or f.name ilike '%'||q||'%' or coalesce(f.code,'') ilike '%'||q||'%')
        and app_private.user_has_resource_permission(auth.uid(),p_company_id,'files.view',f.project_id,f.site_id,f.id,null)
      order by f.trashed_at desc limit greatest(1,least(coalesce(p_limit,100),200)) offset greatest(coalesce(p_offset,0),0)
    )x),'[]'::jsonb),
    'documents',coalesce((select jsonb_agg(x order by x.trashed_at desc) from (
      select d.id,d.display_name,d.document_type,d.project_id,d.site_id,d.folder_id,d.trashed_at,d.trashed_by,d.trash_origin,p.name project_name,s.name site_name,pr.full_name trashed_by_name,
        (select size_bytes from public.document_versions v where v.id=d.current_version_id) size_bytes,
        (app_private.project_context_operational(d.project_id,d.site_id) and app_private.user_has_resource_permission(auth.uid(),p_company_id,'files.restore',d.project_id,d.site_id,d.folder_id,null)) can_restore
      from public.documents d join public.projects p on p.id=d.project_id left join public.sites s on s.id=d.site_id left join public.profiles pr on pr.id=d.trashed_by
      where d.company_id=p_company_id and d.state='trashed' and d.trash_origin<>'ancestor'
        and (p_project_id is null or d.project_id=p_project_id) and (p_site_id is null or d.site_id=p_site_id)
        and (q='' or d.display_name ilike '%'||q||'%')
        and app_private.user_has_resource_permission(auth.uid(),p_company_id,'files.view',d.project_id,d.site_id,d.folder_id,null)
      order by d.trashed_at desc limit greatest(1,least(coalesce(p_limit,100),200)) offset greatest(coalesce(p_offset,0),0)
    )x),'[]'::jsonb),
    'hidden_descendants',(select count(*) from public.folders f where f.company_id=p_company_id and f.trashed_at is not null and f.trash_origin='ancestor')+(select count(*) from public.documents d where d.company_id=p_company_id and d.state='trashed' and d.trash_origin='ancestor')
  );
end;
$$;
revoke all on function public.trash_query(uuid,text,uuid,uuid,integer,integer) from public,anon;
grant execute on function public.trash_query(uuid,text,uuid,uuid,integer,integer) to authenticated;
