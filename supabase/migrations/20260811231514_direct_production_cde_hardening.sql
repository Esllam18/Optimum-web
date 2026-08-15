-- Direct production CDE hardening: scoped capabilities, one-shot document directory,
-- archived-context immutability, and safe restore semantics.

create or replace function public.document_directory_query(
  p_company_id uuid,
  p_project_ids uuid[] default null,
  p_per_project_limit integer default 100
)
returns table(
  id uuid,
  project_id uuid,
  site_id uuid,
  folder_id uuid,
  display_name text,
  document_type text,
  control_status text,
  system_code text,
  version_count integer,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path='public','app_private','pg_temp'
as $$
  with ranked as (
    select d.id,d.project_id,d.site_id,d.folder_id,d.display_name,d.document_type,d.control_status,
           d.system_code,d.version_count,d.updated_at,
           row_number() over(partition by d.project_id order by d.updated_at desc,d.id) rn
    from public.documents d
    where d.company_id=p_company_id
      and d.state='active'
      and (p_project_ids is null or d.project_id=any(p_project_ids))
      and app_private.user_has_resource_permission(auth.uid(),p_company_id,'files.view',d.project_id,d.site_id,d.folder_id,null)
  )
  select id,project_id,site_id,folder_id,display_name,document_type,control_status,system_code,version_count,updated_at
  from ranked
  where rn<=greatest(1,least(coalesce(p_per_project_limit,100),200))
  order by updated_at desc;
$$;
revoke all on function public.document_directory_query(uuid,uuid[],integer) from public,anon;
grant execute on function public.document_directory_query(uuid,uuid[],integer) to authenticated;

create or replace function public.file_workspace_capabilities(
  p_company_id uuid,
  p_project_id uuid,
  p_site_id uuid default null,
  p_folder_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path='public','app_private','pg_temp'
as $$
declare
  v_uid uuid:=auth.uid();
  v_operational boolean;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.projects p where p.id=p_project_id and p.company_id=p_company_id) then raise exception 'Project not found'; end if;
  if p_site_id is not null and not exists(select 1 from public.sites s where s.id=p_site_id and s.project_id=p_project_id and s.company_id=p_company_id) then raise exception 'Invalid site'; end if;
  if not app_private.user_has_resource_permission(v_uid,p_company_id,'files.view',p_project_id,p_site_id,p_folder_id,null) then raise exception 'Permission denied'; end if;
  v_operational:=app_private.project_context_operational(p_project_id,p_site_id);
  return jsonb_build_object(
    'operational',v_operational,
    'can_create_folder',v_operational and app_private.user_has_resource_permission(v_uid,p_company_id,'files.create_folder',p_project_id,p_site_id,p_folder_id,null),
    'can_upload',v_operational and p_folder_id is not null and app_private.user_has_resource_permission(v_uid,p_company_id,'files.upload',p_project_id,p_site_id,p_folder_id,null),
    'can_manage',v_operational and app_private.user_has_resource_permission(v_uid,p_company_id,'files.manage',p_project_id,p_site_id,p_folder_id,null),
    'folder_caps',coalesce((select jsonb_agg(jsonb_build_object(
      'id',f.id,
      'can_rename',v_operational and not f.is_system and app_private.user_has_resource_permission(v_uid,p_company_id,'files.rename',f.project_id,f.site_id,f.id,null),
      'can_move',v_operational and not f.is_system and app_private.user_has_resource_permission(v_uid,p_company_id,'files.move',f.project_id,f.site_id,f.id,null),
      'can_archive',v_operational and not f.is_system and app_private.user_has_resource_permission(v_uid,p_company_id,'files.archive',f.project_id,f.site_id,f.id,null)
    )) from public.folders f where f.company_id=p_company_id and f.project_id=p_project_id and f.site_id is not distinct from p_site_id and f.trashed_at is null and app_private.user_has_resource_permission(v_uid,p_company_id,'files.view',f.project_id,f.site_id,f.id,null)),'[]'::jsonb)
  );
end;
$$;
revoke all on function public.file_workspace_capabilities(uuid,uuid,uuid,uuid) from public,anon;
grant execute on function public.file_workspace_capabilities(uuid,uuid,uuid,uuid) to authenticated;

create or replace function public.document_action_capabilities(p_document_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path='public','app_private','pg_temp'
as $$
declare
  v_uid uuid:=auth.uid();
  d public.documents%rowtype;
  v_operational boolean;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  select * into d from public.documents where id=p_document_id;
  if not found or not app_private.user_has_resource_permission(v_uid,d.company_id,'files.view',d.project_id,d.site_id,d.folder_id,null) then raise exception 'Permission denied'; end if;
  v_operational:=app_private.project_context_operational(d.project_id,d.site_id) and d.state='active';
  return jsonb_build_object(
    'operational',v_operational,
    'can_download',app_private.user_has_resource_permission(v_uid,d.company_id,'files.download',d.project_id,d.site_id,d.folder_id,null),
    'can_upload',v_operational and app_private.user_has_resource_permission(v_uid,d.company_id,'files.upload',d.project_id,d.site_id,d.folder_id,null),
    'can_manage',v_operational and app_private.user_has_resource_permission(v_uid,d.company_id,'files.manage',d.project_id,d.site_id,d.folder_id,null),
    'can_rename',v_operational and app_private.user_has_resource_permission(v_uid,d.company_id,'files.rename',d.project_id,d.site_id,d.folder_id,null),
    'can_move',v_operational and app_private.user_has_resource_permission(v_uid,d.company_id,'files.move',d.project_id,d.site_id,d.folder_id,null),
    'can_archive',v_operational and app_private.user_has_resource_permission(v_uid,d.company_id,'files.archive',d.project_id,d.site_id,d.folder_id,null)
  );
end;
$$;
revoke all on function public.document_action_capabilities(uuid) from public,anon;
grant execute on function public.document_action_capabilities(uuid) to authenticated;

create or replace function public.create_folder(p_project_id uuid,p_site_id uuid,p_parent_id uuid,p_name text,p_code text default null)
returns uuid language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare v_company uuid;v_id uuid;v_name text:=trim(coalesce(p_name,''));v_code text:=nullif(trim(coalesce(p_code,'')),'');
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if char_length(v_name)<1 or char_length(v_name)>160 then raise exception 'Folder name is required and must be 160 characters or fewer'; end if;
  if v_code is not null and char_length(v_code)>80 then raise exception 'Folder code is too long'; end if;
  select company_id into v_company from public.projects where id=p_project_id and archived_at is null;
  if v_company is null or not app_private.project_context_operational(p_project_id,p_site_id) then raise exception 'Project or site is not active'; end if;
  if p_parent_id is not null and not exists(select 1 from public.folders f where f.id=p_parent_id and f.company_id=v_company and f.project_id=p_project_id and f.site_id is not distinct from p_site_id and f.trashed_at is null) then raise exception 'Invalid parent folder'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),v_company,'files.create_folder',p_project_id,p_site_id,p_parent_id,null) then raise exception 'Permission denied'; end if;
  insert into public.folders(company_id,project_id,site_id,parent_id,name,code,is_system,created_by) values(v_company,p_project_id,p_site_id,p_parent_id,v_name,v_code,false,auth.uid()) returning id into v_id;
  perform app_private.notify_resource_members(v_company,auth.uid(),'folder.created','تم إنشاء مجلد جديد','A new folder was created',v_name,v_name,'folder',v_id,'files.view',p_project_id,p_site_id,v_id,null);
  return v_id;
end;
$$;

create or replace function public.rename_folder(p_folder_id uuid,p_name text)
returns void language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare f public.folders%rowtype;v_name text:=trim(coalesce(p_name,''));
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if char_length(v_name)<1 or char_length(v_name)>160 then raise exception 'Folder name is required and must be 160 characters or fewer'; end if;
  select * into f from public.folders where id=p_folder_id and trashed_at is null;
  if not found then raise exception 'Folder not found'; end if;
  if f.is_system then raise exception 'System folders cannot be renamed'; end if;
  if not app_private.project_context_operational(f.project_id,f.site_id) then raise exception 'Project or site is archived'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),f.company_id,'files.rename',f.project_id,f.site_id,f.id,null) then raise exception 'Permission denied'; end if;
  update public.folders set name=v_name where id=f.id;
  perform app_private.notify_resource_members(f.company_id,auth.uid(),'folder.renamed','تم تعديل اسم مجلد','A folder was renamed',v_name,v_name,'folder',f.id,'files.view',f.project_id,f.site_id,f.id,null);
end;
$$;

create or replace function public.rename_document(p_document_id uuid,p_display_name text)
returns void language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare d public.documents%rowtype;v_name text:=trim(coalesce(p_display_name,''));
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if char_length(v_name)<1 or char_length(v_name)>240 then raise exception 'Document name is required and must be 240 characters or fewer'; end if;
  select * into d from public.documents where id=p_document_id and state='active';if not found then raise exception 'Document not found'; end if;
  if not app_private.project_context_operational(d.project_id,d.site_id) then raise exception 'Project or site is archived'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),d.company_id,'files.rename',d.project_id,d.site_id,d.folder_id,null) then raise exception 'Permission denied'; end if;
  update public.documents set display_name=v_name where id=d.id;
  perform app_private.notify_resource_members(d.company_id,auth.uid(),'document.renamed','تم تعديل اسم ملف','A file was renamed',v_name,v_name,'document',d.id,'files.view',d.project_id,d.site_id,d.folder_id,null);
end;
$$;

create or replace function public.trash_document(p_document_id uuid)
returns void language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare d public.documents%rowtype;b uuid:=gen_random_uuid();
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into d from public.documents where id=p_document_id and state<>'trashed' for update;if not found then raise exception 'Document not found';end if;
  if not app_private.project_context_operational(d.project_id,d.site_id) then raise exception 'Archived project or site documents are read-only'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),d.company_id,'files.archive',d.project_id,d.site_id,d.folder_id,null) then raise exception 'Permission denied';end if;
  update public.documents set state='trashed',trashed_at=now(),trashed_by=auth.uid(),trash_batch_id=b,trash_origin='direct',trash_root_folder_id=null where id=d.id;
  perform app_private.notify_resource_members(d.company_id,auth.uid(),'document.trashed','تم نقل ملف إلى السلة','A file was moved to trash',d.display_name,d.display_name,'document',d.id,'files.view',d.project_id,d.site_id,d.folder_id,null);
end;
$$;

create or replace function public.trash_folder(p_folder_id uuid)
returns void language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare f public.folders%rowtype;b uuid:=gen_random_uuid();
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into f from public.folders where id=p_folder_id and trashed_at is null for update;if not found then raise exception 'Folder not found';end if;
  if f.is_system then raise exception 'System folders cannot be deleted';end if;
  if not app_private.project_context_operational(f.project_id,f.site_id) then raise exception 'Archived project or site folders are read-only'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),f.company_id,'files.archive',f.project_id,f.site_id,f.id,null) then raise exception 'Permission denied';end if;
  with recursive d as(select id from public.folders where id=f.id union all select x.id from public.folders x join d on x.parent_id=d.id)
  update public.documents set state='trashed',trashed_at=now(),trashed_by=auth.uid(),trash_batch_id=b,trash_origin='ancestor',trash_root_folder_id=f.id where folder_id in(select id from d) and state<>'trashed';
  with recursive d as(select id from public.folders where id=f.id union all select x.id from public.folders x join d on x.parent_id=d.id)
  update public.folders set trashed_at=now(),trashed_by=auth.uid(),trash_batch_id=b,trash_origin=case when id=f.id then 'direct' else 'ancestor' end,trash_root_folder_id=f.id where id in(select id from d) and trashed_at is null;
  perform app_private.notify_resource_members(f.company_id,auth.uid(),'folder.trashed','تم نقل مجلد إلى السلة','A folder was moved to trash',f.name,f.name,'folder',f.id,'files.view',f.project_id,f.site_id,f.id,null);
end;
$$;

create or replace function public.restore_document(p_document_id uuid)
returns void language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare v_doc public.documents%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_doc from public.documents where id=p_document_id and state='trashed' for update;
  if not found then raise exception 'Document not found in trash'; end if;
  if v_doc.trash_origin='ancestor' then raise exception 'Restore the containing folder instead'; end if;
  if not app_private.project_context_operational(v_doc.project_id,v_doc.site_id) then raise exception 'Reactivate the project or site before restoring documents'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),v_doc.company_id,'files.restore',v_doc.project_id,v_doc.site_id,v_doc.folder_id,null) then raise exception 'Permission denied'; end if;
  if exists(select 1 from public.folders where id=v_doc.folder_id and trashed_at is not null) then raise exception 'Restore the containing folder first'; end if;
  update public.documents set state='active',trashed_at=null,trashed_by=null,trash_batch_id=null,trash_origin=null,trash_root_folder_id=null where id=p_document_id;
end;
$$;

create or replace function public.restore_folder(p_folder_id uuid)
returns void language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare v_folder public.folders%rowtype;v_batch uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_folder from public.folders where id=p_folder_id and trashed_at is not null for update;
  if not found then raise exception 'Folder not found in trash'; end if;
  if coalesce(v_folder.trash_origin,'direct')<>'direct' then raise exception 'Restore the top-level deleted folder instead'; end if;
  if not app_private.project_context_operational(v_folder.project_id,v_folder.site_id) then raise exception 'Reactivate the project or site before restoring folders'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),v_folder.company_id,'files.restore',v_folder.project_id,v_folder.site_id,v_folder.id,null) then raise exception 'Permission denied'; end if;
  if v_folder.parent_id is not null and exists(select 1 from public.folders where id=v_folder.parent_id and trashed_at is not null) then raise exception 'Restore the parent folder first'; end if;
  v_batch:=v_folder.trash_batch_id;if v_batch is null then raise exception 'Trash operation metadata is missing';end if;
  update public.documents set state='active',trashed_at=null,trashed_by=null,trash_batch_id=null,trash_origin=null,trash_root_folder_id=null where state='trashed' and trash_batch_id=v_batch and trash_origin='ancestor';
  update public.folders set trashed_at=null,trashed_by=null,trash_batch_id=null,trash_origin=null,trash_root_folder_id=null where trashed_at is not null and trash_batch_id=v_batch;
end;
$$;

create or replace function public.begin_document_upload(p_folder_id uuid,p_display_name text,p_original_filename text,p_mime_type text,p_size_bytes bigint,p_document_type text default 'general',p_description text default null,p_tags text[] default array[]::text[],p_change_note text default null)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare f public.folders%rowtype;v_doc uuid:=gen_random_uuid();v_ver uuid:=gen_random_uuid();v_limit bigint;v_usage bigint;v_path text;v_name text:=trim(coalesce(p_display_name,''));v_original text:=trim(coalesce(p_original_filename,''));
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if char_length(v_name)<1 or char_length(v_name)>240 then raise exception 'Document name is required and must be 240 characters or fewer'; end if;
  if char_length(v_original)<1 or char_length(v_original)>500 then raise exception 'Original filename is invalid'; end if;
  select * into f from public.folders where id=p_folder_id and trashed_at is null;if not found then raise exception 'Folder not found'; end if;
  if not app_private.project_context_operational(f.project_id,f.site_id) then raise exception 'Project or site is archived'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),f.company_id,'files.upload',f.project_id,f.site_id,f.id,null) then raise exception 'Permission denied'; end if;
  if p_size_bytes<=0 or p_size_bytes>1073741824 then raise exception 'Invalid file size'; end if;
  perform pg_advisory_xact_lock(hashtextextended(f.company_id::text,6810));
  select max_storage_bytes into v_limit from app_private.effective_company_limits(f.company_id);
  select coalesce(sum(size_bytes),0) into v_usage from public.document_versions where company_id=f.company_id and upload_state in('uploading','ready');
  if v_limit is not null and v_usage+p_size_bytes>v_limit then raise exception 'Storage limit reached'; end if;
  v_path:=f.company_id::text||'/'||f.project_id::text||'/'||coalesce(f.site_id::text,'project')||'/'||v_doc::text||'/'||v_ver::text||'/'||app_private.safe_storage_filename(v_original);
  insert into public.documents(id,company_id,project_id,site_id,folder_id,display_name,document_type,description,tags,created_by) values(v_doc,f.company_id,f.project_id,f.site_id,f.id,v_name,coalesce(nullif(trim(p_document_type),''),'general'),nullif(trim(p_description),''),coalesce(p_tags,array[]::text[]),auth.uid());
  insert into public.document_versions(id,company_id,document_id,version_number,version_label,original_filename,storage_path,mime_type,size_bytes,change_note,uploaded_by) values(v_ver,f.company_id,v_doc,1,'v1',v_original,v_path,coalesce(nullif(p_mime_type,''),'application/octet-stream'),p_size_bytes,nullif(trim(p_change_note),''),auth.uid());
  return jsonb_build_object('document_id',v_doc,'version_id',v_ver,'version_number',1,'storage_bucket','company-files','storage_path',v_path);
end;
$$;
