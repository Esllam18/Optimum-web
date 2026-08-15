create table if not exists public.entity_follows (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  entity_type text not null check (entity_type in ('project','site','site_cabinet','engineering_drawing','document')),
  entity_id uuid not null,
  created_at timestamptz not null default now(),
  unique(company_id,user_id,entity_type,entity_id)
);

alter table public.entity_follows enable row level security;
drop policy if exists entity_follows_select_own on public.entity_follows;
create policy entity_follows_select_own on public.entity_follows for select to authenticated
using (user_id=auth.uid() and app_private.is_company_member(company_id));
drop policy if exists entity_follows_insert_own on public.entity_follows;
create policy entity_follows_insert_own on public.entity_follows for insert to authenticated
with check (user_id=auth.uid() and app_private.is_company_member(company_id));
drop policy if exists entity_follows_delete_own on public.entity_follows;
create policy entity_follows_delete_own on public.entity_follows for delete to authenticated
using (user_id=auth.uid() and app_private.is_company_member(company_id));

create table if not exists public.operations_user_state (
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  last_seen_at timestamptz not null default now(),
  calendar_layers jsonb not null default '{"tasks":true,"reviews":true,"documents":true,"drawings":true,"delivery":true,"projects":true}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key(company_id,user_id)
);
alter table public.operations_user_state enable row level security;
drop policy if exists operations_state_own on public.operations_user_state;
create policy operations_state_own on public.operations_user_state for all to authenticated
using (user_id=auth.uid() and app_private.is_company_member(company_id))
with check (user_id=auth.uid() and app_private.is_company_member(company_id));

create or replace function public.toggle_entity_follow(
  p_company_id uuid,
  p_entity_type text,
  p_entity_id uuid,
  p_follow boolean default null
) returns boolean
language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare v_exists boolean; v_next boolean;
begin
  if not app_private.is_company_member(p_company_id) then raise exception 'Permission denied'; end if;
  if p_entity_type not in ('project','site','site_cabinet','engineering_drawing','document') then raise exception 'Unsupported entity type'; end if;
  select exists(select 1 from public.entity_follows where company_id=p_company_id and user_id=auth.uid() and entity_type=p_entity_type and entity_id=p_entity_id) into v_exists;
  v_next:=coalesce(p_follow,not v_exists);
  if v_next then
    insert into public.entity_follows(company_id,user_id,entity_type,entity_id)
    values(p_company_id,auth.uid(),p_entity_type,p_entity_id)
    on conflict do nothing;
  else
    delete from public.entity_follows where company_id=p_company_id and user_id=auth.uid() and entity_type=p_entity_type and entity_id=p_entity_id;
  end if;
  return v_next;
end $$;

grant execute on function public.toggle_entity_follow(uuid,text,uuid,boolean) to authenticated;

create or replace function public.operations_center_mark_seen(p_company_id uuid)
returns timestamptz
language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare v_now timestamptz:=now();
begin
  if not app_private.is_company_member(p_company_id) then raise exception 'Permission denied'; end if;
  insert into public.operations_user_state(company_id,user_id,last_seen_at,updated_at)
  values(p_company_id,auth.uid(),v_now,v_now)
  on conflict(company_id,user_id) do update set last_seen_at=excluded.last_seen_at,updated_at=excluded.updated_at;
  return v_now;
end $$;
grant execute on function public.operations_center_mark_seen(uuid) to authenticated;

create or replace function public.save_operations_calendar_layers(p_company_id uuid,p_layers jsonb)
returns jsonb
language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare v_layers jsonb;
begin
  if not app_private.is_company_member(p_company_id) then raise exception 'Permission denied'; end if;
  v_layers:=jsonb_build_object(
    'tasks',coalesce((p_layers->>'tasks')::boolean,true),
    'reviews',coalesce((p_layers->>'reviews')::boolean,true),
    'documents',coalesce((p_layers->>'documents')::boolean,true),
    'drawings',coalesce((p_layers->>'drawings')::boolean,true),
    'delivery',coalesce((p_layers->>'delivery')::boolean,true),
    'projects',coalesce((p_layers->>'projects')::boolean,true)
  );
  insert into public.operations_user_state(company_id,user_id,calendar_layers,updated_at)
  values(p_company_id,auth.uid(),v_layers,now())
  on conflict(company_id,user_id) do update set calendar_layers=excluded.calendar_layers,updated_at=excluded.updated_at;
  return v_layers;
end $$;
grant execute on function public.save_operations_calendar_layers(uuid,jsonb) to authenticated;

create or replace function public.operations_center_snapshot(p_company_id uuid,p_limit integer default 30)
returns jsonb
language plpgsql stable security definer set search_path='public','app_private','pg_temp'
as $$
declare
  v_since timestamptz;
  v_layers jsonb;
  v_result jsonb;
begin
  if not app_private.is_company_member(p_company_id) then raise exception 'Permission denied'; end if;
  p_limit:=greatest(5,least(coalesce(p_limit,30),100));
  select last_seen_at,calendar_layers into v_since,v_layers from public.operations_user_state where company_id=p_company_id and user_id=auth.uid();
  v_since:=coalesce(v_since,now()-interval '7 days');
  v_layers:=coalesce(v_layers,'{"tasks":true,"reviews":true,"documents":true,"drawings":true,"delivery":true,"projects":true}'::jsonb);

  with my_tasks as (
    select t.*
    from public.tasks t
    where t.company_id=p_company_id and t.status not in ('done','cancelled')
      and app_private.can_view_task(t.id)
      and (
        t.owner_user_id=auth.uid() or t.reviewer_user_id=auth.uid() or t.approver_user_id=auth.uid() or t.claimed_by=auth.uid()
        or exists(select 1 from public.task_assignments a where a.task_id=t.id and a.user_id=auth.uid())
      )
    order by (case when t.due_at<now() then 0 when t.due_at<now()+interval '1 day' then 1 else 2 end),
             (case t.priority when 'urgent' then 0 when 'high' then 1 when 'medium' then 2 else 3 end),
             t.due_at nulls last
    limit p_limit
  ), task_json as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'kind','task','entity_type','task','entity_id',id,'title',title,'status',status,'priority',priority,
      'due_at',due_at,'project_id',project_id,'site_id',site_id,'task_type',task_type,
      'action_role',case when approver_user_id=auth.uid() then 'approve' when reviewer_user_id=auth.uid() then 'review' else 'execute' end
    )),'[]'::jsonb) value from my_tasks
  ), approvals as (
    select * from (
      select 'task'::text kind,t.id entity_id,t.title,t.project_id,t.site_id,t.due_at at_time,
             case when t.approver_user_id=auth.uid() then 'approval' else 'review' end action_kind,
             t.status::text status
      from public.tasks t
      where t.company_id=p_company_id and t.status not in ('done','cancelled') and app_private.can_view_task(t.id)
        and (t.approver_user_id=auth.uid() or t.reviewer_user_id=auth.uid())
      union all
      select 'document',d.id,d.display_name,d.project_id,d.site_id,d.review_due_at,'document_review',d.control_status
      from public.documents d
      where d.company_id=p_company_id and d.state='active' and d.control_status='in_review'
        and app_private.user_has_resource_permission(auth.uid(),p_company_id,'files.manage',d.project_id,d.site_id,d.folder_id,null)
      union all
      select 'site_claim_package',p.id,p.title,p.project_id,p.site_id,p.submitted_at,'delivery_review',p.status
      from public.site_claim_packages p
      where p.company_id=p_company_id and p.status='submitted'
        and app_private.user_has_resource_permission(auth.uid(),p_company_id,'files.manage',p.project_id,p.site_id,null,null)
      union all
      select 'access_change_request',r.id,coalesce(r.request_type,'Access request'),null::uuid,null::uuid,r.requested_at,'access_review',r.status
      from public.access_change_requests r
      where r.company_id=p_company_id and r.status='pending' and app_private.has_company_permission(p_company_id,'company.manage')
    ) q order by at_time nulls last limit p_limit
  ), approvals_json as (
    select coalesce(jsonb_agg(jsonb_build_object('kind',kind,'entity_type',kind,'entity_id',entity_id,'title',title,'project_id',project_id,'site_id',site_id,'at',at_time,'action_kind',action_kind,'status',status)),'[]'::jsonb) value from approvals
  ), unread_json as (
    select coalesce(jsonb_agg(jsonb_build_object('id',id,'type',type,'title_ar',title_ar,'title_en',title_en,'body_ar',body_ar,'body_en',body_en,'entity_type',entity_type,'entity_id',entity_id,'created_at',created_at) order by created_at desc),'[]'::jsonb) value
    from (select * from public.notifications where company_id=p_company_id and user_id=auth.uid() and read_at is null order by created_at desc limit p_limit) n
  ), changes as (
    select * from (
      select 'engineering_drawing'::text entity_type,e.drawing_id entity_id,d.title,d.project_id,d.site_id,e.created_at,e.actor_id,
             e.event_type action,e.change_summary metadata
      from public.engineering_revision_events e join public.engineering_drawings d on d.id=e.drawing_id
      where e.company_id=p_company_id and e.created_at>v_since
        and app_private.user_has_resource_permission(auth.uid(),p_company_id,'drawings.view',d.project_id,d.site_id,d.folder_id,d.id)
      union all
      select 'site_claim_package',e.package_id,p.title,p.project_id,p.site_id,e.created_at,e.actor_id,e.event_type,e.metadata
      from public.site_claim_package_events e join public.site_claim_packages p on p.id=e.package_id
      where e.company_id=p_company_id and e.created_at>v_since
        and app_private.user_has_resource_permission(auth.uid(),p_company_id,'files.view',p.project_id,p.site_id,null,null)
      union all
      select 'document',d.id,d.display_name,d.project_id,d.site_id,v.created_at,v.uploaded_by,'document.version_uploaded',jsonb_build_object('version_number',v.version_number,'revision_code',v.revision_code,'change_note',v.change_note)
      from public.document_versions v join public.documents d on d.id=v.document_id
      where v.company_id=p_company_id and v.upload_state='ready' and v.created_at>v_since
        and app_private.user_has_resource_permission(auth.uid(),p_company_id,'files.view',d.project_id,d.site_id,d.folder_id,null)
      union all
      select 'task',e.task_id,t.title,t.project_id,t.site_id,e.created_at,e.actor_id,e.event_type,e.metadata
      from public.task_events e join public.tasks t on t.id=e.task_id
      where e.company_id=p_company_id and e.created_at>v_since and app_private.can_view_task(t.id)
    ) x order by created_at desc limit p_limit
  ), changes_json as (
    select coalesce(jsonb_agg(jsonb_build_object('entity_type',entity_type,'entity_id',entity_id,'title',title,'project_id',project_id,'site_id',site_id,'created_at',created_at,'actor_id',actor_id,'action',action,'metadata',metadata)),'[]'::jsonb) value from changes
  ), follows_json as (
    select coalesce(jsonb_agg(jsonb_build_object('entity_type',entity_type,'entity_id',entity_id,'created_at',created_at)),'[]'::jsonb) value
    from public.entity_follows where company_id=p_company_id and user_id=auth.uid()
  )
  select jsonb_build_object(
    'generated_at',now(),'last_seen_at',v_since,'calendar_layers',v_layers,
    'tasks',(select value from task_json),
    'approvals',(select value from approvals_json),
    'notifications',(select value from unread_json),
    'changes',(select value from changes_json),
    'follows',(select value from follows_json)
  ) into v_result;
  return v_result;
end $$;
grant execute on function public.operations_center_snapshot(uuid,integer) to authenticated;

create or replace function public.operations_calendar_feed(p_company_id uuid,p_from timestamptz,p_to timestamptz,p_user_id uuid default null)
returns jsonb
language plpgsql stable security definer set search_path='public','app_private','pg_temp'
as $$
declare v_base jsonb; v_extra jsonb;
begin
  if not app_private.is_company_member(p_company_id) then raise exception 'Permission denied'; end if;
  if p_to<=p_from or p_to-p_from>interval '370 days' then raise exception 'Invalid calendar range'; end if;
  v_base:=case when app_private.has_company_permission(p_company_id,'tasks.view') then public.work_calendar_feed(p_company_id,p_from,p_to,p_user_id) else '[]'::jsonb end;
  with events as (
    select jsonb_build_object('kind','document_review','id',d.id,'title',d.display_name,'status',d.control_status,'start_at',d.review_due_at,'end_at',d.review_due_at,'all_day',false,'project_id',d.project_id,'site_id',d.site_id,'entity_type','document') item
    from public.documents d where d.company_id=p_company_id and d.state='active' and d.review_due_at>=p_from and d.review_due_at<p_to
      and app_private.user_has_resource_permission(auth.uid(),p_company_id,'files.view',d.project_id,d.site_id,d.folder_id,null)
    union all
    select jsonb_build_object('kind','document_expiry','id',d.id,'title',d.display_name,'status','expiry','start_at',d.expires_at,'end_at',d.expires_at,'all_day',false,'project_id',d.project_id,'site_id',d.site_id,'entity_type','document')
    from public.documents d where d.company_id=p_company_id and d.state='active' and d.expires_at>=p_from and d.expires_at<p_to
      and app_private.user_has_resource_permission(auth.uid(),p_company_id,'files.view',d.project_id,d.site_id,d.folder_id,null)
    union all
    select jsonb_build_object('kind','project_target','id',p.id,'title',p.name,'status',p.status,'start_at',p.target_end_date::timestamptz,'end_at',p.target_end_date::timestamptz,'all_day',true,'project_id',p.id,'entity_type','project')
    from public.projects p where p.company_id=p_company_id and p.archived_at is null and p.target_end_date>=p_from::date and p.target_end_date<p_to::date
      and app_private.user_has_resource_permission(auth.uid(),p_company_id,'projects.view',p.id,null,null,null)
    union all
    select jsonb_build_object('kind','site_target','id',s.id,'title',s.name,'status',s.status,'start_at',s.target_end_date::timestamptz,'end_at',s.target_end_date::timestamptz,'all_day',true,'project_id',s.project_id,'site_id',s.id,'entity_type','site')
    from public.sites s where s.company_id=p_company_id and s.archived_at is null and s.target_end_date>=p_from::date and s.target_end_date<p_to::date
      and app_private.user_has_resource_permission(auth.uid(),p_company_id,'projects.view',s.project_id,s.id,null,null)
    union all
    select jsonb_build_object('kind','delivery_review','id',p.id,'title',p.title,'status',p.status,'start_at',p.submitted_at,'end_at',p.submitted_at,'all_day',false,'project_id',p.project_id,'site_id',p.site_id,'entity_type','site_claim_package')
    from public.site_claim_packages p where p.company_id=p_company_id and p.submitted_at>=p_from and p.submitted_at<p_to
      and app_private.user_has_resource_permission(auth.uid(),p_company_id,'files.view',p.project_id,p.site_id,null,null)
    union all
    select jsonb_build_object('kind','drawing_change','id',d.id,'title',d.title,'status',d.status,'start_at',d.last_change_at,'end_at',d.last_change_at,'all_day',false,'project_id',d.project_id,'site_id',d.site_id,'entity_type','engineering_drawing')
    from public.engineering_drawings d where d.company_id=p_company_id and d.archived_at is null and d.last_change_at>=p_from and d.last_change_at<p_to
      and app_private.user_has_resource_permission(auth.uid(),p_company_id,'drawings.view',d.project_id,d.site_id,d.folder_id,d.id)
  ) select coalesce(jsonb_agg(item order by item->>'start_at'),'[]'::jsonb) into v_extra from events;
  return coalesce(v_base,'[]'::jsonb)||coalesce(v_extra,'[]'::jsonb);
end $$;
grant execute on function public.operations_calendar_feed(uuid,timestamptz,timestamptz,uuid) to authenticated;
