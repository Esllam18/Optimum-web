begin;

-- Optimum 6.9 Site Delivery production hardening.
-- Keeps archived project/site contexts readable, but seals every cabinet/claim mutation.
-- Claim completeness is based on ready canonical document versions, matching freeze semantics.

create or replace function public.site_claim_package_360(p_package_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path='public','app_private','pg_temp'
as $$
declare
  p public.site_claim_packages%rowtype;
  v_required integer:=0;
  v_satisfied integer:=0;
  v_req_pct integer:=0;
  v_cabinets integer:=0;
  v_covered integer:=0;
  v_cab_pct integer:=0;
  v_overall integer:=0;
  v_invalid integer:=0;
  v_operational boolean:=false;
  v_can_manage boolean:=false;
begin
  select * into p from public.site_claim_packages where id=p_package_id;
  if not found then raise exception 'Claim package not found'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.view',p.project_id,p.site_id,null,null) then
    raise exception 'Permission denied';
  end if;

  v_operational:=app_private.project_context_operational(p.project_id,p.site_id);
  v_can_manage:=v_operational and app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.manage',p.project_id,p.site_id,null,null);

  with ready_rollup as (
    select r.id,
      count(i.id) filter(where i.status<>'rejected' and d.state='active')::integer item_count,
      count(i.id) filter(where i.status<>'rejected' and d.state='active' and d.current_version_id is not null and v.upload_state='ready')::integer ready_count
    from public.site_claim_requirements r
    left join public.site_claim_items i on i.requirement_id=r.id
    left join public.documents d on d.id=i.document_id
    left join public.document_versions v on v.id=d.current_version_id
    where r.package_id=p.id
    group by r.id
  )
  select count(*) filter(where r.is_required),
         count(*) filter(where r.is_required and coalesce(rr.ready_count,0)>=r.min_items)
  into v_required,v_satisfied
  from public.site_claim_requirements r
  left join ready_rollup rr on rr.id=r.id
  where r.package_id=p.id;

  v_req_pct:=case when v_required=0 then 100 else round(v_satisfied::numeric/v_required*100) end;

  select count(*) into v_cabinets
  from public.site_cabinets c
  where c.site_id=p.site_id and c.archived_at is null and c.status<>'archived';

  select count(distinct i.cabinet_id) into v_covered
  from public.site_claim_items i
  join public.site_cabinets c on c.id=i.cabinet_id
  join public.documents d on d.id=i.document_id
  join public.document_versions v on v.id=d.current_version_id
  where i.package_id=p.id and i.status<>'rejected'
    and c.archived_at is null and c.status<>'archived'
    and d.state='active' and v.upload_state='ready';

  v_cab_pct:=case when v_cabinets=0 then 100 else round(v_covered::numeric/v_cabinets*100) end;
  v_overall:=round(v_req_pct*0.7+v_cab_pct*0.3);

  select count(*) into v_invalid
  from public.site_claim_items i
  left join public.documents d on d.id=i.document_id
  left join public.document_versions v on v.id=d.current_version_id
  where i.package_id=p.id and i.status<>'rejected'
    and (d.id is null or d.state<>'active' or d.current_version_id is null or v.id is null or v.upload_state<>'ready');

  return jsonb_build_object(
    'package',to_jsonb(p),
    'site',(select jsonb_build_object('id',s.id,'code',s.code,'name',s.name,'status',s.status,'archived_at',s.archived_at) from public.sites s where s.id=p.site_id),
    'project',(select jsonb_build_object('id',x.id,'code',x.code,'name',x.name,'status',x.status,'archived_at',x.archived_at) from public.projects x where x.id=p.project_id),
    'progress',jsonb_build_object(
      'required_percent',v_req_pct,'cabinet_coverage_percent',v_cab_pct,'overall_percent',v_overall,
      'required_total',v_required,'required_satisfied',v_satisfied,
      'cabinet_total',v_cabinets,'cabinet_covered',v_covered,'invalid_items',v_invalid
    ),
    'requirements',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',r.id,'requirement_key',r.requirement_key,'label_ar',r.label_ar,'label_en',r.label_en,
        'category',r.category,'is_required',r.is_required,'min_items',r.min_items,'sort_order',r.sort_order,'notes',r.notes,
        'item_count',coalesce(rr.item_count,0),'ready_count',coalesce(rr.ready_count,0),
        'satisfied',(coalesce(rr.ready_count,0)>=r.min_items),
        'items',coalesce((
          select jsonb_agg(jsonb_build_object(
            'id',i.id,'document_id',d.id,'display_name',d.display_name,'document_type',d.document_type,
            'control_status',d.control_status,'current_version_id',d.current_version_id,
            'selected_version_id',i.selected_version_id,'version_ready',(d.current_version_id is not null and v.upload_state='ready'),
            'cabinet_id',i.cabinet_id,'cabinet_code',c.code,'cabinet_name',c.name,
            'inclusion_mode',i.inclusion_mode,'status',i.status,'folder_id',d.folder_id
          ) order by i.created_at)
          from public.site_claim_items i
          join public.documents d on d.id=i.document_id
          left join public.document_versions v on v.id=d.current_version_id
          left join public.site_cabinets c on c.id=i.cabinet_id
          where i.requirement_id=r.id
            and app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.view',p.project_id,p.site_id,d.folder_id,null)
        ),'[]'::jsonb)
      ) order by r.sort_order,r.created_at)
      from public.site_claim_requirements r
      left join lateral (
        select count(i.id) filter(where i.status<>'rejected' and d.state='active')::integer item_count,
               count(i.id) filter(where i.status<>'rejected' and d.state='active' and d.current_version_id is not null and v.upload_state='ready')::integer ready_count
        from public.site_claim_items i
        left join public.documents d on d.id=i.document_id
        left join public.document_versions v on v.id=d.current_version_id
        where i.requirement_id=r.id
      ) rr on true
      where r.package_id=p.id
    ),'[]'::jsonb),
    'context_read_only',not v_operational,
    'can_manage',v_can_manage
  );
end;
$$;

create or replace function public.cabinet_360(p_cabinet_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path='public','app_private','pg_temp'
as $$
declare
  c public.site_cabinets%rowtype;
  v_ready integer:=0;
  v_total integer:=4;
  v_parent_operational boolean:=false;
  v_operational boolean:=false;
begin
  select * into c from public.site_cabinets where id=p_cabinet_id;
  if not found then raise exception 'Cabinet not found'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),c.company_id,'projects.view',c.project_id,c.site_id,null,null) then
    raise exception 'Permission denied';
  end if;

  v_parent_operational:=app_private.project_context_operational(c.project_id,c.site_id);
  v_operational:=v_parent_operational and c.archived_at is null and c.status<>'archived';

  with recursive df as(
    select id,code,name from public.folders where id=c.root_folder_id and trashed_at is null
    union all
    select f.id,f.code,f.name from public.folders f join df p on f.parent_id=p.id where f.trashed_at is null
  ),cats as(
    select exists(select 1 from public.documents d join df on df.id=d.folder_id where d.state='active' and df.code='C01') drawings,
      exists(select 1 from public.documents d join df on df.id=d.folder_id where d.state='active' and df.code='C02') qty,
      exists(select 1 from public.documents d join df on df.id=d.folder_id where d.state='active' and df.code='C03') sketches,
      exists(select 1 from public.documents d join df on df.id=d.folder_id where d.state='active' and df.code='C04') handover
  ) select (drawings::int+qty::int+sketches::int+handover::int) into v_ready from cats;

  return jsonb_build_object(
    'cabinet',to_jsonb(c),
    'project',(select jsonb_build_object('id',p.id,'code',p.code,'name',p.name,'status',p.status,'archived_at',p.archived_at) from public.projects p where p.id=c.project_id),
    'site',(select jsonb_build_object('id',s.id,'code',s.code,'name',s.name,'status',s.status,'archived_at',s.archived_at) from public.sites s where s.id=c.site_id),
    'root_folder',(select jsonb_build_object('id',f.id,'name',f.name,'code',f.code) from public.folders f where f.id=c.root_folder_id),
    'folders',coalesce((select jsonb_agg(jsonb_build_object('id',f.id,'code',f.code,'name',f.name,'sort_order',f.sort_order) order by f.sort_order) from public.folders f where f.parent_id=c.root_folder_id and f.trashed_at is null),'[]'::jsonb),
    'stats',jsonb_build_object(
      'documents',(with recursive df as(select id from public.folders where id=c.root_folder_id union all select f.id from public.folders f join df on f.parent_id=df.id where f.trashed_at is null) select count(*) from public.documents d where d.folder_id in(select id from df) and d.state='active' and app_private.user_has_resource_permission(auth.uid(),c.company_id,'files.view',c.project_id,c.site_id,d.folder_id,null)),
      'drawings',(with recursive df as(select id from public.folders where id=c.root_folder_id union all select f.id from public.folders f join df on f.parent_id=df.id where f.trashed_at is null) select count(*) from public.engineering_drawings d where d.folder_id in(select id from df) and d.archived_at is null and app_private.can_view_engineering_drawing(d.id)),
      'open_tasks',(with recursive df as(select id from public.folders where id=c.root_folder_id union all select f.id from public.folders f join df on f.parent_id=df.id where f.trashed_at is null) select count(*) from public.tasks t where t.folder_id in(select id from df) and t.status not in('done','cancelled') and app_private.can_view_task(t.id)),
      'claim_items',(select count(*) from public.site_claim_items i where i.cabinet_id=c.id and i.status<>'rejected'),
      'readiness_percent',round(v_ready::numeric/greatest(v_total,1)*100)
    ),
    'context_read_only',not v_operational,
    'can_manage',v_operational and app_private.user_has_resource_permission(auth.uid(),c.company_id,'projects.edit',c.project_id,c.site_id,null,null),
    'can_archive',v_parent_operational and app_private.user_has_resource_permission(auth.uid(),c.company_id,'projects.archive',c.project_id,c.site_id,null,null)
  );
end;
$$;

create or replace function public.site_360(p_site_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path='public','app_private','pg_temp'
as $$
declare
  v_uid uuid:=auth.uid();
  s public.sites%rowtype;
  p public.projects%rowtype;
  v_package uuid;
  v_claim jsonb;
  v_unscoped_files boolean:=false;
  v_unscoped_tasks boolean:=false;
  v_unscoped_drawings boolean:=false;
  v_folders integer:=0;
  v_documents integer:=0;
  v_storage_bytes bigint:=0;
  v_open_tasks integer:=0;
  v_overdue_tasks integer:=0;
  v_drawings integer:=0;
  v_cabinets integer:=0;
  v_cabinets_json jsonb:='[]'::jsonb;
  v_operational boolean:=false;
  v_project_operational boolean:=false;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  select * into s from public.sites where id=p_site_id;
  if not found then raise exception 'Site not found'; end if;
  select * into p from public.projects where id=s.project_id;
  if not app_private.user_has_resource_permission(v_uid,s.company_id,'projects.view',s.project_id,s.id,null,null) then raise exception 'Permission denied'; end if;

  v_operational:=app_private.project_context_operational(s.project_id,s.id);
  v_project_operational:=app_private.project_context_operational(s.project_id,null);
  v_unscoped_files:=app_private.user_permission_is_unscoped(v_uid,s.company_id,'files.view');
  v_unscoped_tasks:=app_private.has_company_permission(s.company_id,'tasks.view_all') and app_private.user_permission_is_unscoped(v_uid,s.company_id,'tasks.view');
  v_unscoped_drawings:=app_private.user_permission_is_unscoped(v_uid,s.company_id,'drawings.view');

  select id into v_package from public.site_claim_packages where site_id=s.id and claim_type='final' and status<>'archived' order by created_at limit 1;
  if v_package is not null and app_private.user_has_resource_permission(v_uid,s.company_id,'files.view',s.project_id,s.id,null,null) then
    v_claim:=public.site_claim_package_360(v_package);
  end if;

  select count(*) into v_folders from public.folders f where f.site_id=s.id and f.trashed_at is null and (v_unscoped_files or app_private.user_has_resource_permission(v_uid,s.company_id,'files.view',s.project_id,s.id,f.id,null));
  select count(*) into v_documents from public.documents d where d.site_id=s.id and d.state='active' and (v_unscoped_files or app_private.user_has_resource_permission(v_uid,s.company_id,'files.view',s.project_id,s.id,d.folder_id,null));
  select coalesce(sum(v.size_bytes),0) into v_storage_bytes from public.document_versions v join public.documents d on d.id=v.document_id where d.site_id=s.id and v.upload_state='ready' and (v_unscoped_files or app_private.user_has_resource_permission(v_uid,s.company_id,'files.view',s.project_id,s.id,d.folder_id,null));
  select count(*) filter(where t.status not in('done','cancelled')),count(*) filter(where t.status not in('done','cancelled') and t.due_at<now()) into v_open_tasks,v_overdue_tasks from public.tasks t where t.site_id=s.id and (v_unscoped_tasks or app_private.can_view_task(t.id));
  select count(*) into v_drawings from public.engineering_drawings d where d.site_id=s.id and d.archived_at is null and (v_unscoped_drawings or app_private.user_has_resource_permission(v_uid,d.company_id,'drawings.view',d.project_id,d.site_id,d.folder_id,d.id));
  select count(*) into v_cabinets from public.site_cabinets c where c.site_id=s.id and c.archived_at is null and c.status<>'archived';

  with claim_counts as (
    select i.cabinet_id,count(*)::integer claim_items
    from public.site_claim_items i
    where i.cabinet_id is not null and i.status<>'rejected'
      and exists(select 1 from public.site_claim_packages cp where cp.id=i.package_id and cp.site_id=s.id)
    group by i.cabinet_id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'code',c.code,'name',c.name,'cabinet_type',c.cabinet_type,'status',c.status,
    'description',c.description,'location_label',c.location_label,'root_folder_id',c.root_folder_id,
    'archived_at',c.archived_at,'claim_items',coalesce(cc.claim_items,0)
  ) order by c.archived_at nulls first,c.code),'[]'::jsonb)
  into v_cabinets_json
  from public.site_cabinets c left join claim_counts cc on cc.cabinet_id=c.id where c.site_id=s.id;

  return jsonb_build_object(
    'site',to_jsonb(s),
    'project',jsonb_build_object('id',p.id,'code',p.code,'name',p.name,'status',p.status,'archived_at',p.archived_at),
    'manager_name',(select full_name from public.profiles where id=s.manager_user_id),
    'stats',jsonb_build_object('folders',v_folders,'documents',v_documents,'storage_bytes',v_storage_bytes,'open_tasks',v_open_tasks,'overdue_tasks',v_overdue_tasks,'drawings',v_drawings,'cabinets',v_cabinets),
    'cabinets',v_cabinets_json,
    'claim_package',coalesce(v_claim,'null'::jsonb),
    'context_read_only',not v_operational,
    'can_create_cabinet',v_operational and app_private.user_has_resource_permission(v_uid,s.company_id,'projects.edit',s.project_id,s.id,null,null) and app_private.user_has_resource_permission(v_uid,s.company_id,'files.create_folder',s.project_id,s.id,null,null),
    'can_manage_cabinets',v_operational and app_private.user_has_resource_permission(v_uid,s.company_id,'projects.edit',s.project_id,s.id,null,null),
    'can_manage_claim',v_operational and app_private.user_has_resource_permission(v_uid,s.company_id,'files.manage',s.project_id,s.id,null,null),
    'can_edit_site',v_operational and app_private.user_has_resource_permission(v_uid,s.company_id,'projects.edit',s.project_id,s.id,null,null),
    'can_archive_site',v_project_operational and app_private.user_has_resource_permission(v_uid,s.company_id,'projects.archive',s.project_id,s.id,null,null)
  );
end;
$$;

create or replace function public.save_site_claim_requirement(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path='public','app_private','pg_temp'
as $$
declare
  v_id uuid:=nullif(p_payload->>'id','')::uuid;
  v_package uuid:=nullif(p_payload->>'package_id','')::uuid;
  v_key text;
  v_label_ar text:=trim(coalesce(p_payload->>'label_ar',''));
  v_label_en text:=trim(coalesce(p_payload->>'label_en',''));
  v_min integer:=greatest(0,least(coalesce(nullif(p_payload->>'min_items','')::int,1),1000));
  v_sort integer:=greatest(0,least(coalesce(nullif(p_payload->>'sort_order','')::int,100),9999));
  p public.site_claim_packages%rowtype;
  r public.site_claim_requirements%rowtype;
begin
  select * into p from public.site_claim_packages where id=v_package;
  if not found then raise exception 'Claim package not found'; end if;
  if not app_private.project_context_operational(p.project_id,p.site_id) then raise exception 'Project or site is archived'; end if;
  if p.locked_at is not null or p.status in('submitted','approved','archived') then raise exception 'Claim package is locked'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.manage',p.project_id,p.site_id,null,null) then raise exception 'Permission denied'; end if;
  if v_label_ar='' or v_label_en='' then raise exception 'Arabic and English labels are required'; end if;

  if v_id is null then
    v_key:=lower(regexp_replace(trim(coalesce(p_payload->>'requirement_key','')),'[^a-zA-Z0-9_-]+','_','g'));
    if v_key='' then raise exception 'Requirement key is required'; end if;
    insert into public.site_claim_requirements(company_id,package_id,requirement_key,label_ar,label_en,category,is_required,min_items,sort_order,notes,created_by)
    values(p.company_id,p.id,v_key,v_label_ar,v_label_en,coalesce(nullif(trim(p_payload->>'category'),''),'supporting'),coalesce((p_payload->>'is_required')::boolean,true),v_min,v_sort,nullif(trim(p_payload->>'notes'),''),auth.uid())
    returning * into r;
  else
    select * into r from public.site_claim_requirements where id=v_id and package_id=p.id for update;
    if not found then raise exception 'Requirement not found'; end if;
    update public.site_claim_requirements set
      label_ar=v_label_ar,label_en=v_label_en,
      category=coalesce(nullif(trim(p_payload->>'category'),''),category),
      is_required=coalesce((p_payload->>'is_required')::boolean,is_required),
      min_items=v_min,sort_order=v_sort,
      notes=case when p_payload?'notes' then nullif(trim(p_payload->>'notes'),'') else notes end
    where id=r.id returning * into r;
  end if;
  return to_jsonb(r);
end;
$$;

create or replace function public.add_document_to_site_claim(
  p_document_id uuid,p_requirement_key text,p_package_id uuid default null,p_cabinet_id uuid default null,p_inclusion_mode text default 'manual'
) returns jsonb
language plpgsql
security definer
set search_path='public','app_private','pg_temp'
as $$
declare
  d public.documents%rowtype;
  p public.site_claim_packages%rowtype;
  r public.site_claim_requirements%rowtype;
  i public.site_claim_items%rowtype;
  v_package uuid:=p_package_id;
  v_cab uuid:=p_cabinet_id;
begin
  select * into d from public.documents where id=p_document_id and state='active';
  if not found or d.site_id is null then raise exception 'Only active site documents can be added to a site claim'; end if;
  if not app_private.project_context_operational(d.project_id,d.site_id) then raise exception 'Project or site is archived'; end if;
  if d.current_version_id is null or not exists(select 1 from public.document_versions v where v.id=d.current_version_id and v.upload_state='ready') then
    raise exception 'Document does not have a ready current version';
  end if;
  if not app_private.user_has_resource_permission(auth.uid(),d.company_id,'files.manage',d.project_id,d.site_id,d.folder_id,null) then raise exception 'Permission denied'; end if;
  if v_package is null then select id into v_package from public.site_claim_packages where site_id=d.site_id and claim_type='final' and status<>'archived' order by created_at limit 1; end if;
  select * into p from public.site_claim_packages where id=v_package and site_id=d.site_id;
  if not found then raise exception 'Claim package does not belong to document site'; end if;
  if p.locked_at is not null or p.status in('submitted','approved','archived') then raise exception 'Claim package is locked'; end if;
  select * into r from public.site_claim_requirements where package_id=p.id and requirement_key=p_requirement_key;
  if not found then raise exception 'Claim requirement not found'; end if;
  if v_cab is null then v_cab:=app_private.cabinet_for_folder(d.folder_id); end if;
  if v_cab is not null and not exists(select 1 from public.site_cabinets c where c.id=v_cab and c.site_id=d.site_id and c.archived_at is null and c.status<>'archived') then
    raise exception 'Cabinet does not belong to document site or is archived';
  end if;
  insert into public.site_claim_items(company_id,package_id,requirement_id,document_id,cabinet_id,inclusion_mode,status,added_by)
  values(d.company_id,p.id,r.id,d.id,v_cab,case when p_inclusion_mode in('manual','upload','auto') then p_inclusion_mode else 'manual' end,'included',auth.uid())
  on conflict(package_id,requirement_id,document_id) do update set cabinet_id=coalesce(excluded.cabinet_id,site_claim_items.cabinet_id),inclusion_mode=excluded.inclusion_mode,status='included',selected_version_id=null,updated_at=now()
  returning * into i;
  return to_jsonb(i);
end;
$$;

create or replace function public.remove_site_claim_item(p_item_id uuid)
returns void
language plpgsql
security definer
set search_path='public','app_private','pg_temp'
as $$
declare i public.site_claim_items%rowtype; p public.site_claim_packages%rowtype; d public.documents%rowtype;
begin
  select * into i from public.site_claim_items where id=p_item_id;
  select * into p from public.site_claim_packages where id=i.package_id;
  select * into d from public.documents where id=i.document_id;
  if i.id is null or p.id is null then raise exception 'Claim item not found'; end if;
  if not app_private.project_context_operational(p.project_id,p.site_id) then raise exception 'Project or site is archived'; end if;
  if p.locked_at is not null or p.status in('submitted','approved','archived') then raise exception 'Claim package is locked'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.manage',p.project_id,p.site_id,d.folder_id,null) then raise exception 'Permission denied'; end if;
  delete from public.site_claim_items where id=i.id;
end;
$$;

create or replace function public.site_claim_suggestions(p_package_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path='public','app_private','pg_temp'
as $$
declare p public.site_claim_packages%rowtype;
begin
  select * into p from public.site_claim_packages where id=p_package_id;
  if not found then raise exception 'Claim package not found'; end if;
  if not app_private.project_context_operational(p.project_id,p.site_id) then raise exception 'Project or site is archived'; end if;
  if p.locked_at is not null or p.status in('submitted','approved','archived') then raise exception 'Claim package is locked'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.manage',p.project_id,p.site_id,null,null) then raise exception 'Permission denied'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'document_id',q.id,'display_name',q.display_name,'folder_id',q.folder_id,'requirement_key',q.req_key,
      'requirement_label_ar',r.label_ar,'requirement_label_en',r.label_en,'cabinet_id',q.cabinet_id,'current_version_id',q.current_version_id
    ) order by r.sort_order,q.display_name)
    from(
      select d.*,app_private.infer_site_claim_requirement(d.id) req_key,app_private.cabinet_for_folder(d.folder_id) cabinet_id
      from public.documents d
      join public.document_versions v on v.id=d.current_version_id and v.upload_state='ready'
      where d.site_id=p.site_id and d.state='active'
        and app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.manage',p.project_id,p.site_id,d.folder_id,null)
    )q
    join public.site_claim_requirements r on r.package_id=p.id and r.requirement_key=q.req_key
    where q.req_key is not null
      and not exists(select 1 from public.site_claim_items i where i.package_id=p.id and i.requirement_id=r.id and i.document_id=q.id)
  ),'[]'::jsonb);
end;
$$;

create or replace function public.auto_collect_site_claim(p_package_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public','app_private','pg_temp'
as $$
declare p public.site_claim_packages%rowtype; s jsonb; item jsonb; v_added integer:=0; v_req uuid;
begin
  select * into p from public.site_claim_packages where id=p_package_id for update;
  if not found then raise exception 'Claim package not found'; end if;
  if not app_private.project_context_operational(p.project_id,p.site_id) then raise exception 'Project or site is archived'; end if;
  if p.locked_at is not null or p.status in('submitted','approved','archived') then raise exception 'Claim package is locked'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.manage',p.project_id,p.site_id,null,null) then raise exception 'Permission denied'; end if;
  s:=public.site_claim_suggestions(p.id);
  for item in select value from jsonb_array_elements(s) loop
    select id into v_req from public.site_claim_requirements where package_id=p.id and requirement_key=item->>'requirement_key';
    insert into public.site_claim_items(company_id,package_id,requirement_id,document_id,cabinet_id,inclusion_mode,status,added_by)
    values(p.company_id,p.id,v_req,(item->>'document_id')::uuid,nullif(item->>'cabinet_id','')::uuid,'auto','included',auth.uid())
    on conflict(package_id,requirement_id,document_id) do nothing;
    if found then v_added:=v_added+1; end if;
  end loop;
  return jsonb_build_object('added',v_added,'suggested',jsonb_array_length(s));
end;
$$;

create or replace function public.freeze_site_claim_package(p_package_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public','app_private','pg_temp'
as $$
declare p public.site_claim_packages%rowtype; v_missing integer; v_bad integer;
begin
  select * into p from public.site_claim_packages where id=p_package_id for update;
  if not found then raise exception 'Claim package not found'; end if;
  if not app_private.project_context_operational(p.project_id,p.site_id) then raise exception 'Project or site is archived'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.manage',p.project_id,p.site_id,null,null) then raise exception 'Permission denied'; end if;
  if p.status in('submitted','approved','archived') then raise exception 'Claim package cannot be frozen in its current status'; end if;
  select count(*) into v_missing
  from public.site_claim_requirements r
  where r.package_id=p.id and r.is_required and (
    select count(*) from public.site_claim_items i
    join public.documents d on d.id=i.document_id
    join public.document_versions v on v.id=d.current_version_id
    where i.requirement_id=r.id and i.status<>'rejected' and d.state='active' and v.upload_state='ready'
  )<r.min_items;
  if v_missing>0 then raise exception 'Claim package is incomplete: % required requirement(s) are still missing',v_missing; end if;
  select count(*) into v_bad
  from public.site_claim_items i
  left join public.documents d on d.id=i.document_id
  left join public.document_versions v on v.id=d.current_version_id
  where i.package_id=p.id and i.status<>'rejected'
    and (d.id is null or d.state<>'active' or d.current_version_id is null or v.id is null or v.upload_state<>'ready');
  if v_bad>0 then raise exception 'Claim package contains documents without a ready current version'; end if;
  update public.site_claim_items i set selected_version_id=d.current_version_id
  from public.documents d where i.package_id=p.id and i.status<>'rejected' and d.id=i.document_id;
  update public.site_claim_packages set status='ready',locked_at=now(),locked_by=auth.uid() where id=p.id returning * into p;
  return to_jsonb(p);
end;
$$;

create or replace function public.reopen_site_claim_package(p_package_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public','app_private','pg_temp'
as $$
declare p public.site_claim_packages%rowtype;
begin
  select * into p from public.site_claim_packages where id=p_package_id for update;
  if not found then raise exception 'Claim package not found'; end if;
  if not app_private.project_context_operational(p.project_id,p.site_id) then raise exception 'Project or site is archived'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.manage',p.project_id,p.site_id,null,null) then raise exception 'Permission denied'; end if;
  if p.status in('submitted','approved','archived') then raise exception 'Submitted/approved packages cannot be reopened directly'; end if;
  update public.site_claim_items set selected_version_id=null where package_id=p.id;
  update public.site_claim_packages set status='collecting',locked_at=null,locked_by=null where id=p.id returning * into p;
  return to_jsonb(p);
end;
$$;

create or replace function public.submit_site_claim_package(p_package_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public','app_private','pg_temp'
as $$
declare p public.site_claim_packages%rowtype; v_bad integer;
begin
  select * into p from public.site_claim_packages where id=p_package_id for update;
  if not found then raise exception 'Claim package not found'; end if;
  if not app_private.project_context_operational(p.project_id,p.site_id) then raise exception 'Project or site is archived'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.manage',p.project_id,p.site_id,null,null) then raise exception 'Permission denied'; end if;
  if p.locked_at is null or p.status<>'ready' then raise exception 'Freeze the complete package before submission'; end if;
  select count(*) into v_bad from public.site_claim_items i
  left join public.document_versions v on v.id=i.selected_version_id
  where i.package_id=p.id and i.status<>'rejected' and (i.selected_version_id is null or v.id is null or v.upload_state<>'ready');
  if v_bad>0 then raise exception 'Frozen package contains invalid pinned versions'; end if;
  update public.site_claim_packages set status='submitted',submitted_at=now() where id=p.id returning * into p;
  return to_jsonb(p);
end;
$$;

create or replace function public.archive_site_cabinet(p_cabinet_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public','app_private','pg_temp'
as $$
declare c public.site_cabinets%rowtype;
begin
  select * into c from public.site_cabinets where id=p_cabinet_id for update;
  if not found then raise exception 'Cabinet not found'; end if;
  if not app_private.project_context_operational(c.project_id,c.site_id) then raise exception 'Project or site is archived'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),c.company_id,'projects.archive',c.project_id,c.site_id,null,null) then raise exception 'Permission denied'; end if;
  update public.site_cabinets set status='archived',archived_at=now() where id=c.id returning * into c;
  return to_jsonb(c);
end;
$$;

-- Explicit grants only for authenticated users; no anonymous claim/cabinet mutation surface.
revoke all on function public.site_claim_package_360(uuid) from public,anon;
grant execute on function public.site_claim_package_360(uuid) to authenticated;
revoke all on function public.cabinet_360(uuid) from public,anon;
grant execute on function public.cabinet_360(uuid) to authenticated;
revoke all on function public.site_360(uuid) from public,anon;
grant execute on function public.site_360(uuid) to authenticated;
revoke all on function public.save_site_claim_requirement(jsonb) from public,anon;
grant execute on function public.save_site_claim_requirement(jsonb) to authenticated;
revoke all on function public.add_document_to_site_claim(uuid,text,uuid,uuid,text) from public,anon;
grant execute on function public.add_document_to_site_claim(uuid,text,uuid,uuid,text) to authenticated;
revoke all on function public.remove_site_claim_item(uuid) from public,anon;
grant execute on function public.remove_site_claim_item(uuid) to authenticated;
revoke all on function public.site_claim_suggestions(uuid) from public,anon;
grant execute on function public.site_claim_suggestions(uuid) to authenticated;
revoke all on function public.auto_collect_site_claim(uuid) from public,anon;
grant execute on function public.auto_collect_site_claim(uuid) to authenticated;
revoke all on function public.freeze_site_claim_package(uuid) from public,anon;
grant execute on function public.freeze_site_claim_package(uuid) to authenticated;
revoke all on function public.reopen_site_claim_package(uuid) from public,anon;
grant execute on function public.reopen_site_claim_package(uuid) to authenticated;
revoke all on function public.submit_site_claim_package(uuid) from public,anon;
grant execute on function public.submit_site_claim_package(uuid) to authenticated;
revoke all on function public.archive_site_cabinet(uuid) from public,anon;
grant execute on function public.archive_site_cabinet(uuid) to authenticated;

commit;
