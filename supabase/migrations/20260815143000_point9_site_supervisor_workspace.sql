begin;

-- Point 9 — Site Supervisor Workspace
-- The protected supervisor role becomes the field execution role. Access scopes
-- still decide *where* the supervisor may operate; these permissions decide *what*
-- they can do inside that scope.
update public.roles
set name_ar='مشرف موقع', name_en='Site Supervisor'
where slug='supervisor' and is_protected=true;

insert into public.role_permissions(role_id,permission_key,allowed)
select r.id,p.key,true
from public.roles r
join public.permissions p on p.key in (
  'company.view','members.view','projects.view',
  'files.view','files.upload','files.create_folder','files.download',
  'search.use','notifications.view',
  'tasks.view','tasks.create','tasks.edit','tasks.complete','tasks.claim','tasks.comment','tasks.attach',
  'drawings.view','drawings.create','drawings.edit','drawings.compare','drawings.export','drawings.review',
  'boq.view','boq.edit','branding.view'
)
where r.slug='supervisor'
on conflict(role_id,permission_key) do update set allowed=true;

-- Keep the built-in seed function aligned for future companies.
create or replace function app_private.seed_company_roles(p_company_id uuid)
returns table(owner_role_id uuid) language plpgsql security definer set search_path=public,pg_temp as $$
declare v_owner uuid;v_admin uuid;v_manager uuid;v_engineer uuid;v_supervisor uuid;v_viewer uuid;
begin
 insert into public.roles(company_id,name_ar,name_en,slug,is_default,is_protected) values(p_company_id,'صاحب الشركة','Owner','owner',true,true) returning id into v_owner;
 insert into public.roles(company_id,name_ar,name_en,slug,is_default,is_protected) values(p_company_id,'مدير النظام','Admin','admin',true,true) returning id into v_admin;
 insert into public.roles(company_id,name_ar,name_en,slug,is_default,is_protected) values(p_company_id,'مدير','Manager','manager',true,true) returning id into v_manager;
 insert into public.roles(company_id,name_ar,name_en,slug,is_default,is_protected) values(p_company_id,'مهندس','Engineer','engineer',true,true) returning id into v_engineer;
 insert into public.roles(company_id,name_ar,name_en,slug,is_default,is_protected) values(p_company_id,'مشرف موقع','Site Supervisor','supervisor',true,true) returning id into v_supervisor;
 insert into public.roles(company_id,name_ar,name_en,slug,is_default,is_protected) values(p_company_id,'مشاهد','Viewer','viewer',true,true) returning id into v_viewer;
 insert into public.role_permissions select v_owner,key,true from public.permissions;
 insert into public.role_permissions select v_admin,key,true from public.permissions where key<>'company.manage';
 insert into public.role_permissions select v_manager,key,true from public.permissions where key in ('company.view','members.view','roles.view','projects.view','projects.create','projects.edit','projects.archive','audit.view','files.view','files.upload','files.create_folder','files.rename','files.move','files.archive','files.restore','files.download','files.manage','search.use','notifications.view','tasks.view','tasks.view_all','tasks.create','tasks.assign','tasks.edit','tasks.manage','tasks.comment','tasks.attach','tasks.complete','tasks.claim','tasks.recurring','drawings.view','drawings.create','drawings.edit','drawings.publish','drawings.compare','drawings.export','drawings.review','boq.view','boq.edit','catalog.manage','branding.view','roles.templates.use');
 insert into public.role_permissions select v_engineer,key,true from public.permissions where key in ('company.view','members.view','projects.view','files.view','files.upload','files.create_folder','files.rename','files.move','files.download','search.use','notifications.view','tasks.view','tasks.create','tasks.edit','tasks.comment','tasks.attach','tasks.complete','tasks.claim','drawings.view','drawings.create','drawings.edit','drawings.compare','drawings.export','drawings.review','boq.view','boq.edit','branding.view');
 insert into public.role_permissions select v_supervisor,key,true from public.permissions where key in ('company.view','members.view','projects.view','files.view','files.upload','files.create_folder','files.download','search.use','notifications.view','tasks.view','tasks.create','tasks.edit','tasks.comment','tasks.attach','tasks.complete','tasks.claim','drawings.view','drawings.create','drawings.edit','drawings.compare','drawings.export','drawings.review','boq.view','boq.edit','branding.view');
 insert into public.role_permissions select v_viewer,key,true from public.permissions where key in ('company.view','projects.view','files.view','files.download','search.use','notifications.view','tasks.view','drawings.view','drawings.export','boq.view','branding.view');
 owner_role_id:=v_owner;return next;
end;$$;

create or replace function public.site_supervisor_workspace(
  p_company_id uuid,
  p_site_id uuid default null,
  p_limit integer default 24
) returns jsonb
language plpgsql stable security definer
set search_path='public','app_private','pg_temp'
as $$
declare
  v_uid uuid:=auth.uid();
  v_site uuid:=p_site_id;
  v_role_slug text;
  v_site_row public.sites%rowtype;
  v_project public.projects%rowtype;
  v_result jsonb;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not app_private.is_company_member(p_company_id) then raise exception 'Permission denied'; end if;
  if not app_private.has_company_permission(p_company_id,'projects.view') then raise exception 'Permission denied'; end if;
  p_limit:=greatest(8,least(coalesce(p_limit,24),60));

  select r.slug into v_role_slug
  from public.company_memberships m join public.roles r on r.id=m.role_id
  where m.company_id=p_company_id and m.user_id=v_uid and m.status='active';

  if v_site is not null and not exists(
    select 1 from public.sites s where s.id=v_site and s.company_id=p_company_id and s.archived_at is null
      and app_private.user_has_resource_permission(v_uid,p_company_id,'projects.view',s.project_id,s.id,null,null)
  ) then raise exception 'Site unavailable'; end if;

  if v_site is null then
    select s.id into v_site
    from public.sites s
    where s.company_id=p_company_id and s.archived_at is null
      and app_private.user_has_resource_permission(v_uid,p_company_id,'projects.view',s.project_id,s.id,null,null)
    order by (s.manager_user_id=v_uid) desc,
      exists(select 1 from public.tasks t where t.site_id=s.id and t.status not in('done','cancelled') and app_private.can_view_task(t.id)
        and (t.owner_user_id=v_uid or t.reviewer_user_id=v_uid or t.approver_user_id=v_uid or t.claimed_by=v_uid or exists(select 1 from public.task_assignments a where a.task_id=t.id and a.user_id=v_uid))) desc,
      s.updated_at desc nulls last,s.created_at desc
    limit 1;
  end if;

  if v_site is null then
    return jsonb_build_object('role_slug',v_role_slug,'is_site_supervisor',v_role_slug='supervisor','sites','[]'::jsonb,'site',null,'project',null,'tasks','[]'::jsonb,'cabinets','[]'::jsonb,'drawings','[]'::jsonb,'documents','[]'::jsonb,'stats',jsonb_build_object());
  end if;

  select * into v_site_row from public.sites where id=v_site;
  select * into v_project from public.projects where id=v_site_row.project_id;

  with accessible_sites as (
    select s.id,s.project_id,s.code,s.name,s.manager_user_id,s.status,s.target_end_date,p.code project_code,p.name project_name
    from public.sites s join public.projects p on p.id=s.project_id
    where s.company_id=p_company_id and s.archived_at is null
      and app_private.user_has_resource_permission(v_uid,p_company_id,'projects.view',s.project_id,s.id,null,null)
    order by (s.id=v_site) desc,(s.manager_user_id=v_uid) desc,s.name
  ), my_tasks as (
    select t.id,t.title,t.status,t.priority,t.due_at,t.folder_id,t.project_id,t.site_id,t.task_type,
      case when t.approver_user_id=v_uid then 'approve' when t.reviewer_user_id=v_uid then 'review' else 'execute' end action_role
    from public.tasks t
    where t.company_id=p_company_id and t.site_id=v_site and t.status not in('done','cancelled') and app_private.can_view_task(t.id)
      and (t.owner_user_id=v_uid or t.reviewer_user_id=v_uid or t.approver_user_id=v_uid or t.claimed_by=v_uid or exists(select 1 from public.task_assignments a where a.task_id=t.id and a.user_id=v_uid))
    order by (t.due_at<now()) desc,(case t.priority when 'urgent' then 0 when 'high' then 1 when 'medium' then 2 else 3 end),t.due_at nulls last
    limit p_limit
  ), cabinet_req as (
    select c.id,
      count(r.id) filter(where r.is_required)::int requirement_count,
      count(r.id) filter(where r.is_required and (select count(*) from public.document_requirement_links l where l.requirement_id=r.id)>=r.min_items)::int requirement_ready
    from public.site_cabinets c
    left join public.document_requirements r on r.cabinet_id=c.id and r.site_id=c.site_id
    where c.site_id=v_site and c.archived_at is null and c.status<>'archived'
    group by c.id
  ), cabinet_drawings as (
    select d.cabinet_id,count(*)::int drawing_count,max(d.updated_at) last_drawing_at
    from public.engineering_drawings d
    where d.site_id=v_site and d.cabinet_id is not null and d.archived_at is null
      and app_private.user_has_resource_permission(v_uid,p_company_id,'drawings.view',d.project_id,d.site_id,d.folder_id,d.id)
    group by d.cabinet_id
  ), cabinets as (
    select c.id,c.code,c.name,c.cabinet_type,c.status,c.location_label,c.root_folder_id,
      coalesce(cr.requirement_count,0) requirement_count,coalesce(cr.requirement_ready,0) requirement_ready,
      coalesce(cd.drawing_count,0) drawing_count,cd.last_drawing_at
    from public.site_cabinets c
    left join cabinet_req cr on cr.id=c.id
    left join cabinet_drawings cd on cd.cabinet_id=c.id
    where c.site_id=v_site and c.archived_at is null and c.status<>'archived'
    order by c.code
  ), drawings as (
    select d.id,d.drawing_no,d.title,d.status,d.cabinet_id,d.current_revision_id,d.updated_at,d.last_change_at,
      c.code cabinet_code,c.name cabinet_name,r.revision_code,r.status revision_status,
      d.cde_document_id,
      (d.updated_by=v_uid or d.created_by=v_uid) my_drawing
    from public.engineering_drawings d
    left join public.site_cabinets c on c.id=d.cabinet_id
    left join public.engineering_revisions r on r.id=d.current_revision_id
    where d.site_id=v_site and d.archived_at is null
      and app_private.user_has_resource_permission(v_uid,p_company_id,'drawings.view',d.project_id,d.site_id,d.folder_id,d.id)
    order by d.updated_at desc limit p_limit
  ), recent_docs as (
    select d.id,d.display_name,d.document_type,d.control_status,d.folder_id,d.updated_at,d.current_version_id,
      v.revision_code,v.original_filename,v.created_at version_created_at,
      case when d.expires_at is not null then d.expires_at else null end expires_at
    from public.documents d
    left join public.document_versions v on v.id=d.current_version_id
    where d.site_id=v_site and d.state='active'
      and app_private.user_has_resource_permission(v_uid,p_company_id,'files.view',d.project_id,d.site_id,d.folder_id,null)
    order by greatest(d.updated_at,coalesce(v.created_at,d.updated_at)) desc limit 12
  ), req_stats as (
    select count(*) filter(where r.is_required)::int total,
      count(*) filter(where r.is_required and (select count(*) from public.document_requirement_links l where l.requirement_id=r.id)>=r.min_items)::int ready
    from public.document_requirements r where r.site_id=v_site
  ), task_stats as (
    select count(*)::int open_count,count(*) filter(where due_at<now())::int overdue_count,count(*) filter(where due_at>=date_trunc('day',now()) and due_at<date_trunc('day',now())+interval '1 day')::int today_count from my_tasks
  ), drawing_stats as (
    select count(*)::int drawing_count,count(*) filter(where revision_status='draft')::int draft_count from drawings
  )
  select jsonb_build_object(
    'generated_at',now(),
    'role_slug',v_role_slug,
    'is_site_supervisor',v_role_slug='supervisor',
    'sites',(select coalesce(jsonb_agg(to_jsonb(accessible_sites)),'[]'::jsonb) from accessible_sites),
    'site',to_jsonb(v_site_row),
    'project',jsonb_build_object('id',v_project.id,'code',v_project.code,'name',v_project.name,'status',v_project.status),
    'tasks',(select coalesce(jsonb_agg(to_jsonb(my_tasks)),'[]'::jsonb) from my_tasks),
    'cabinets',(select coalesce(jsonb_agg(to_jsonb(cabinets)),'[]'::jsonb) from cabinets),
    'drawings',(select coalesce(jsonb_agg(to_jsonb(drawings)),'[]'::jsonb) from drawings),
    'documents',(select coalesce(jsonb_agg(to_jsonb(recent_docs)),'[]'::jsonb) from recent_docs),
    'stats',jsonb_build_object(
      'tasks_open',(select open_count from task_stats),'tasks_overdue',(select overdue_count from task_stats),'tasks_today',(select today_count from task_stats),
      'cabinets',(select count(*) from cabinets),'requirements_total',(select total from req_stats),'requirements_ready',(select ready from req_stats),
      'drawings',(select drawing_count from drawing_stats),'draft_drawings',(select draft_count from drawing_stats)
    ),
    'capabilities',jsonb_build_object(
      'can_create_drawing',app_private.user_has_resource_permission(v_uid,p_company_id,'drawings.create',v_project.id,v_site,null,null),
      'can_edit_drawing',app_private.user_has_resource_permission(v_uid,p_company_id,'drawings.edit',v_project.id,v_site,null,null),
      'can_edit_takeoff',app_private.user_has_resource_permission(v_uid,p_company_id,'boq.edit',v_project.id,v_site,null,null),
      'can_upload',app_private.user_has_resource_permission(v_uid,p_company_id,'files.upload',v_project.id,v_site,null,null),
      'can_create_task',app_private.user_has_resource_permission(v_uid,p_company_id,'tasks.create',v_project.id,v_site,null,null),
      'can_complete_task',app_private.user_has_resource_permission(v_uid,p_company_id,'tasks.complete',v_project.id,v_site,null,null)
    )
  ) into v_result;

  return v_result;
end $$;

revoke all on function public.site_supervisor_workspace(uuid,uuid,integer) from public,anon;
grant execute on function public.site_supervisor_workspace(uuid,uuid,integer) to authenticated;

commit;
