create or replace function public.project_action_capabilities(p_project_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path='public','app_private','pg_temp'
as $$
declare
  v_uid uuid := auth.uid();
  v_project public.projects%rowtype;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  select * into v_project
  from public.projects
  where id=p_project_id;

  if not found or not app_private.user_has_resource_permission(
    v_uid,v_project.company_id,'projects.view',v_project.id,null,null,null
  ) then
    raise exception 'Permission denied';
  end if;

  return jsonb_build_object(
    'can_edit',app_private.user_has_resource_permission(v_uid,v_project.company_id,'projects.edit',v_project.id,null,null,null),
    'can_create_site',app_private.user_has_resource_permission(v_uid,v_project.company_id,'projects.create',v_project.id,null,null,null),
    'can_archive',app_private.user_has_resource_permission(v_uid,v_project.company_id,'projects.archive',v_project.id,null,null,null),
    'archived',v_project.archived_at is not null or v_project.status='archived'
  );
end;
$$;

revoke all on function public.project_action_capabilities(uuid) from public,anon;
grant execute on function public.project_action_capabilities(uuid) to authenticated;
