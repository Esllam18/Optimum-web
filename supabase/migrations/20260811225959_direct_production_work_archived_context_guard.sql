create or replace function app_private.task_context_operational(p_task_id uuid)
returns boolean language sql stable security definer set search_path='public','app_private','pg_temp' as $$
  select exists(select 1 from public.tasks t where t.id=p_task_id and (t.project_id is null or app_private.project_context_operational(t.project_id,t.site_id)));
$$;

create or replace function app_private.can_edit_task(p_task_id uuid)
returns boolean language sql stable security definer set search_path='public','app_private','pg_temp' as $$
 select exists(select 1 from public.tasks t left join public.company_memberships m on m.company_id=t.company_id and m.user_id=auth.uid() and m.status='active' where t.id=p_task_id and m.id is not null and app_private.company_is_operational(t.company_id) and app_private.task_context_operational(t.id) and app_private.work_permission_for_row(t.company_id,case when app_private.has_company_permission(t.company_id,'tasks.manage') then 'tasks.manage' else 'tasks.edit' end,t.project_id,t.site_id,t.folder_id,t.document_id) and (app_private.has_company_permission(t.company_id,'tasks.manage') or (app_private.has_company_permission(t.company_id,'tasks.edit') and (t.created_by=auth.uid() or t.owner_user_id=auth.uid() or t.claimed_by=auth.uid() or exists(select 1 from public.task_assignments a where a.task_id=t.id and a.user_id=auth.uid()) or exists(select 1 from public.task_assignments a where a.task_id=t.id and a.role_id=m.role_id)))));
$$;

create or replace function app_private.can_complete_task(p_task_id uuid)
returns boolean language sql stable security definer set search_path='public','app_private','pg_temp' as $$
 select exists(select 1 from public.tasks t left join public.company_memberships m on m.company_id=t.company_id and m.user_id=auth.uid() and m.status='active' where t.id=p_task_id and m.id is not null and app_private.company_is_operational(t.company_id) and app_private.task_context_operational(t.id) and app_private.work_permission_for_row(t.company_id,case when app_private.has_company_permission(t.company_id,'tasks.manage') then 'tasks.manage' else 'tasks.complete' end,t.project_id,t.site_id,t.folder_id,t.document_id) and (app_private.has_company_permission(t.company_id,'tasks.manage') or (app_private.has_company_permission(t.company_id,'tasks.complete') and (t.created_by=auth.uid() or t.owner_user_id=auth.uid() or t.claimed_by=auth.uid() or exists(select 1 from public.task_assignments a where a.task_id=t.id and a.user_id=auth.uid()) or exists(select 1 from public.task_assignments a where a.task_id=t.id and a.role_id=m.role_id)))));
$$;

create or replace function public.claim_task(p_task_id uuid)
returns void language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare v_task public.tasks%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_task from public.tasks where id=p_task_id for update;
  if not found or v_task.visibility<>'company' or not v_task.open_unassigned then raise exception 'Task is not open for claiming'; end if;
  if not app_private.task_context_operational(p_task_id) then raise exception 'Archived project or site work is read-only'; end if;
  if not app_private.work_permission_for_row(v_task.company_id,'tasks.claim',v_task.project_id,v_task.site_id,v_task.folder_id,v_task.document_id) then raise exception 'Permission denied for this work scope'; end if;
  if v_task.claimed_by is not null and v_task.claimed_by<>auth.uid() then raise exception 'Task was claimed by another member'; end if;
  update public.tasks set claimed_by=auth.uid(),owner_user_id=auth.uid(),open_unassigned=false,updated_by=auth.uid() where id=p_task_id;
  insert into public.task_assignments(company_id,task_id,user_id,assigned_by) values(v_task.company_id,p_task_id,auth.uid(),auth.uid()) on conflict do nothing;
  insert into public.task_events(company_id,task_id,actor_id,event_type) values(v_task.company_id,p_task_id,auth.uid(),'task.claimed');
  perform app_private.notify_task_stakeholders(p_task_id,auth.uid(),'task_assigned','تم استلام مهمة','Work item claimed',v_task.title,v_task.title);
  perform app_private.bump_work_runtime(v_task.company_id);
end;
$$;

create or replace function public.add_task_comment(p_task_id uuid,p_body text)
returns uuid language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare v_task public.tasks%rowtype;v_id uuid;v_body text:=trim(coalesce(p_body,''));
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_task from public.tasks where id=p_task_id;
  if not found or not app_private.can_view_task(p_task_id) or not app_private.task_context_operational(p_task_id) or not app_private.work_permission_for_row(v_task.company_id,'tasks.comment',v_task.project_id,v_task.site_id,v_task.folder_id,v_task.document_id) then raise exception 'Permission denied'; end if;
  if char_length(v_body)<1 then raise exception 'Comment is required'; end if;
  insert into public.task_comments(company_id,task_id,author_id,body) values(v_task.company_id,p_task_id,auth.uid(),v_body) returning id into v_id;
  insert into public.task_events(company_id,task_id,actor_id,event_type,metadata) values(v_task.company_id,p_task_id,auth.uid(),'task.comment_added',jsonb_build_object('comment_id',v_id,'body',left(v_body,300)));
  perform app_private.notify_task_stakeholders(p_task_id,auth.uid(),'task_comment','تعليق جديد على مهمة','New work comment',v_task.title,v_task.title);
  perform app_private.bump_work_runtime(v_task.company_id); return v_id;
end;
$$;

create or replace function public.begin_task_attachment_upload(p_task_id uuid,p_original_filename text,p_mime_type text,p_size_bytes bigint,p_comment_id uuid default null)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare v_task public.tasks%rowtype;v_id uuid:=gen_random_uuid();v_path text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_task from public.tasks where id=p_task_id;
  if not found or not app_private.can_view_task(p_task_id) or not app_private.task_context_operational(p_task_id) or not app_private.work_permission_for_row(v_task.company_id,'tasks.attach',v_task.project_id,v_task.site_id,v_task.folder_id,v_task.document_id) then raise exception 'Permission denied for this work scope'; end if;
  if p_size_bytes<=0 or p_size_bytes>104857600 then raise exception 'Invalid attachment size'; end if;
  if p_comment_id is not null and not exists(select 1 from public.task_comments c where c.id=p_comment_id and c.task_id=p_task_id and c.deleted_at is null) then raise exception 'Invalid task comment'; end if;
  v_path:=v_task.company_id::text||'/'||p_task_id::text||'/'||v_id::text||'/'||app_private.safe_storage_filename(p_original_filename);
  insert into public.task_attachments(id,company_id,task_id,comment_id,storage_path,original_filename,mime_type,size_bytes,uploaded_by) values(v_id,v_task.company_id,p_task_id,p_comment_id,v_path,p_original_filename,coalesce(nullif(p_mime_type,''),'application/octet-stream'),p_size_bytes,auth.uid());
  return jsonb_build_object('attachment_id',v_id,'storage_bucket','task-attachments','storage_path',v_path);
end;
$$;

create or replace function public.finalize_task_attachment_upload(p_attachment_id uuid)
returns void language plpgsql security definer set search_path='public','storage','app_private','pg_temp' as $$
declare v_att public.task_attachments%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_att from public.task_attachments where id=p_attachment_id and upload_state='uploading' for update;
  if not found then raise exception 'Attachment reservation not found'; end if;
  if v_att.uploaded_by<>auth.uid() and not app_private.has_company_permission(v_att.company_id,'tasks.manage') then raise exception 'Permission denied'; end if;
  if not app_private.task_context_operational(v_att.task_id) then raise exception 'Archived project or site work is read-only'; end if;
  if not exists(select 1 from storage.objects where bucket_id=v_att.storage_bucket and name=v_att.storage_path) then raise exception 'Uploaded object was not found'; end if;
  update public.task_attachments set upload_state='ready',finalized_at=now() where id=p_attachment_id;
  insert into public.task_events(company_id,task_id,actor_id,event_type,metadata) values(v_att.company_id,v_att.task_id,auth.uid(),'task.attachment_added',jsonb_build_object('attachment_id',v_att.id,'filename',v_att.original_filename));
  perform app_private.bump_work_runtime(v_att.company_id);
end;
$$;

create or replace function public.save_task_dependency(p_blocker_task_id uuid,p_blocked_task_id uuid)
returns uuid language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare v_company uuid;v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select company_id into v_company from public.tasks where id=p_blocked_task_id;
  if v_company is null or not app_private.can_edit_task(p_blocked_task_id) then raise exception 'Permission denied'; end if;
  if not app_private.can_view_task(p_blocker_task_id) or not app_private.task_context_operational(p_blocker_task_id) then raise exception 'You cannot link this dependency'; end if;
  insert into public.task_dependencies(company_id,blocker_task_id,blocked_task_id,created_by) values(v_company,p_blocker_task_id,p_blocked_task_id,auth.uid()) on conflict(blocker_task_id,blocked_task_id) do update set blocker_task_id=excluded.blocker_task_id returning id into v_id;
  perform app_private.bump_work_runtime(v_company); return v_id;
end;
$$;
