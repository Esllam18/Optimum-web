-- Optimum 6.9.1 — Point 7 Delivery & Claim Intelligence
-- Closeout map, evidence synchronization, review decisions, lifecycle history,
-- stale-version detection, and notification-aware approvals.

begin;

alter table public.site_claim_packages
  add column if not exists submitted_by uuid references public.profiles(id) on delete set null,
  add column if not exists approved_by uuid references public.profiles(id) on delete set null,
  add column if not exists rejected_at timestamptz,
  add column if not exists rejected_by uuid references public.profiles(id) on delete set null,
  add column if not exists rejection_reason text,
  add column if not exists review_note text;

alter table public.site_claim_items
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by uuid references public.profiles(id) on delete set null,
  add column if not exists decision_note text;

create table if not exists public.site_claim_package_events(
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  package_id uuid not null references public.site_claim_packages(id) on delete cascade,
  event_type text not null,
  actor_id uuid references public.profiles(id) on delete set null,
  note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint site_claim_package_events_type_check check(event_type in(
    'created','requirements_synced','evidence_collected','versions_frozen','submitted',
    'approved','rejected','reopened','evidence_accepted','evidence_rejected','evidence_removed'
  ))
);
create index if not exists site_claim_package_events_package_idx on public.site_claim_package_events(package_id,created_at desc);

alter table public.site_claim_package_events enable row level security;
drop policy if exists site_claim_package_events_select on public.site_claim_package_events;
create policy site_claim_package_events_select on public.site_claim_package_events for select to authenticated using(
  exists(
    select 1 from public.site_claim_packages p
    where p.id=package_id
      and app_private.resource_permission_for_row(p.company_id,'files.view',p.project_id,p.site_id,null,null)
  )
);
revoke all on public.site_claim_package_events from anon,authenticated;
grant select on public.site_claim_package_events to authenticated;
grant all on public.site_claim_package_events to service_role;

drop trigger if exists audit_site_claim_package_events on public.site_claim_package_events;
create trigger audit_site_claim_package_events after insert or update or delete on public.site_claim_package_events
for each row execute function app_private.write_audit_event();

create or replace function app_private.record_site_claim_event(
  p_package_id uuid,
  p_event_type text,
  p_note text default null,
  p_metadata jsonb default '{}'::jsonb
) returns uuid
language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare p public.site_claim_packages%rowtype; v_id uuid;
begin
  select * into p from public.site_claim_packages where id=p_package_id;
  if not found then raise exception 'Claim package not found'; end if;
  insert into public.site_claim_package_events(company_id,package_id,event_type,actor_id,note,metadata)
  values(p.company_id,p.id,p_event_type,auth.uid(),nullif(trim(coalesce(p_note,'')),''),coalesce(p_metadata,'{}'::jsonb))
  returning id into v_id;
  return v_id;
end $$;
revoke all on function app_private.record_site_claim_event(uuid,text,text,jsonb) from public,anon,authenticated;

-- Stamp actor/timestamps consistently even when the existing lifecycle RPCs are used.
create or replace function app_private.stamp_site_claim_lifecycle()
returns trigger language plpgsql security definer set search_path='public','pg_temp'
as $$
begin
  if new.status is distinct from old.status then
    if new.status='submitted' then
      new.submitted_at:=coalesce(new.submitted_at,now());
      new.submitted_by:=coalesce(new.submitted_by,auth.uid());
    elsif new.status='approved' then
      new.approved_at:=coalesce(new.approved_at,now());
      new.approved_by:=coalesce(new.approved_by,auth.uid());
    elsif new.status='rejected' then
      new.rejected_at:=coalesce(new.rejected_at,now());
      new.rejected_by:=coalesce(new.rejected_by,auth.uid());
    end if;
  end if;
  return new;
end $$;
drop trigger if exists site_claim_packages_lifecycle_stamp on public.site_claim_packages;
create trigger site_claim_packages_lifecycle_stamp before update on public.site_claim_packages
for each row execute function app_private.stamp_site_claim_lifecycle();

-- Record all existing lifecycle transitions without rewriting the stable legacy RPCs.
create or replace function app_private.capture_site_claim_lifecycle_event()
returns trigger language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare v_event text; v_note text; v_type text; v_title_ar text; v_title_en text; v_body_ar text; v_body_en text;
begin
  if new.locked_at is not null and old.locked_at is null then
    perform app_private.record_site_claim_event(new.id,'versions_frozen',null,jsonb_build_object('locked_at',new.locked_at));
  end if;
  if new.status is distinct from old.status then
    v_event:=case new.status when 'submitted' then 'submitted' when 'approved' then 'approved' when 'rejected' then 'rejected' when 'collecting' then 'reopened' else null end;
    if v_event is not null then
      v_note:=case when new.status='rejected' then new.rejection_reason else new.review_note end;
      perform app_private.record_site_claim_event(new.id,v_event,v_note,jsonb_build_object('from',old.status,'to',new.status));
    end if;
    if new.status in('submitted','approved','rejected') then
      v_type:='site_claim.'||new.status;
      v_title_ar:=case new.status when 'submitted' then 'تم تقديم حزمة تسليم' when 'approved' then 'تم اعتماد حزمة تسليم' else 'تم إرجاع حزمة تسليم للتعديل' end;
      v_title_en:=case new.status when 'submitted' then 'Delivery package submitted' when 'approved' then 'Delivery package approved' else 'Delivery package returned for changes' end;
      v_body_ar:=new.package_no||' · '||new.title||case when new.status='rejected' and coalesce(new.rejection_reason,'')<>'' then ' · '||new.rejection_reason else '' end;
      v_body_en:=new.package_no||' · '||new.title||case when new.status='rejected' and coalesce(new.rejection_reason,'')<>'' then ' · '||new.rejection_reason else '' end;
      perform public.notify_company_members(new.company_id,auth.uid(),v_type,v_title_ar,v_title_en,v_body_ar,v_body_en,'site_claim_package',new.id);
    end if;
  end if;
  return new;
end $$;
drop trigger if exists site_claim_packages_lifecycle_event on public.site_claim_packages;
create trigger site_claim_packages_lifecycle_event after update on public.site_claim_packages
for each row execute function app_private.capture_site_claim_lifecycle_event();

create or replace function public.refresh_site_delivery_package(p_package_id uuid)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare p public.site_claim_packages%rowtype; v_added_req integer:=0; v_added_links integer:=0; v_auto jsonb:='{}'::jsonb;
begin
  select * into p from public.site_claim_packages where id=p_package_id;
  if not found then raise exception 'Claim package not found'; end if;
  if not app_private.project_context_operational(p.project_id,p.site_id) then raise exception 'Project or site is archived'; end if;
  if p.locked_at is not null or p.status in('submitted','approved','archived') then raise exception 'Claim package is locked'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.manage',p.project_id,p.site_id,null,null) then raise exception 'Permission denied'; end if;

  with requirement_rollup as(
    select dr.requirement_key,
      max(dr.label_ar) label_ar,max(dr.label_en) label_en,
      max(dr.document_type) document_type,
      bool_or(dr.is_required) is_required,
      greatest(
        max(case when dr.cabinet_id is null then dr.min_items else 0 end),
        coalesce(sum(case when dr.cabinet_id is not null then dr.min_items else 0 end),0)
      )::integer min_items,
      min(dr.sort_order) sort_order
    from public.document_requirements dr
    left join public.site_cabinets c on c.id=dr.cabinet_id
    where dr.company_id=p.company_id and dr.project_id=p.project_id
      and (dr.site_id=p.site_id or (dr.site_id is null and dr.cabinet_id is null))
      and (dr.cabinet_id is null or c.site_id=p.site_id)
    group by dr.requirement_key
  ), inserted as(
    insert into public.site_claim_requirements(company_id,package_id,requirement_key,label_ar,label_en,category,is_required,min_items,sort_order,notes,created_by)
    select p.company_id,p.id,r.requirement_key,r.label_ar,r.label_en,
      case r.document_type when 'drawing' then 'drawings' when 'inspection' then 'inspection' when 'certificate' then 'handover' when 'photo' then 'photos' when 'boq' then 'quantity' else 'evidence' end,
      r.is_required,greatest(r.min_items,case when r.is_required then 1 else 0 end),coalesce(r.sort_order,100),
      'Synced from CDE document requirements',auth.uid()
    from requirement_rollup r
    where not exists(select 1 from public.site_claim_requirements cr where cr.package_id=p.id and cr.requirement_key=r.requirement_key)
    returning id
  ) select count(*) into v_added_req from inserted;

  with candidates as(
    select distinct cr.id requirement_id,drl.document_id,dr.cabinet_id
    from public.document_requirements dr
    join public.document_requirement_links drl on drl.requirement_id=dr.id
    join public.site_claim_requirements cr on cr.package_id=p.id and cr.requirement_key=dr.requirement_key
    join public.documents d on d.id=drl.document_id and d.state='active' and d.site_id=p.site_id
    left join public.site_cabinets c on c.id=dr.cabinet_id
    where dr.company_id=p.company_id and dr.project_id=p.project_id
      and (dr.site_id=p.site_id or (dr.site_id is null and dr.cabinet_id is null))
      and (dr.cabinet_id is null or c.site_id=p.site_id)
      and d.current_version_id is not null
      and app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.manage',p.project_id,p.site_id,d.folder_id,null)
  ), inserted as(
    insert into public.site_claim_items(company_id,package_id,requirement_id,document_id,cabinet_id,inclusion_mode,status,added_by)
    select p.company_id,p.id,c.requirement_id,c.document_id,coalesce(c.cabinet_id,app_private.cabinet_for_folder(d.folder_id)),'auto','included',auth.uid()
    from candidates c join public.documents d on d.id=c.document_id
    where not exists(select 1 from public.site_claim_items i where i.package_id=p.id and i.requirement_id=c.requirement_id and i.document_id=c.document_id)
    returning id
  ) select count(*) into v_added_links from inserted;

  begin
    v_auto:=public.auto_collect_site_claim(p.id);
  exception when others then
    v_auto:=jsonb_build_object('added',0,'warning',sqlerrm);
  end;

  perform app_private.record_site_claim_event(p.id,'requirements_synced',null,jsonb_build_object('requirements_added',v_added_req,'linked_evidence_added',v_added_links,'auto_collect',v_auto));
  return jsonb_build_object('requirements_added',v_added_req,'linked_evidence_added',v_added_links,'auto_collect',v_auto);
end $$;

create or replace function public.review_site_claim_item(p_item_id uuid,p_status text,p_note text default null)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare i public.site_claim_items%rowtype; p public.site_claim_packages%rowtype; v_status text:=lower(trim(coalesce(p_status,'')));
begin
  if v_status not in('included','accepted','rejected') then raise exception 'Invalid evidence decision'; end if;
  select * into i from public.site_claim_items where id=p_item_id;
  if not found then raise exception 'Claim item not found'; end if;
  select * into p from public.site_claim_packages where id=i.package_id;
  if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.manage',p.project_id,p.site_id,null,null) then raise exception 'Permission denied'; end if;
  if p.status not in('collecting','ready','submitted','rejected') then raise exception 'Package cannot be reviewed in its current state'; end if;
  update public.site_claim_items set status=v_status,reviewed_at=now(),reviewed_by=auth.uid(),decision_note=nullif(trim(coalesce(p_note,'')),'') where id=i.id returning * into i;
  perform app_private.record_site_claim_event(p.id,case when v_status='accepted' then 'evidence_accepted' when v_status='rejected' then 'evidence_rejected' else 'evidence_collected' end,p_note,jsonb_build_object('item_id',i.id,'document_id',i.document_id));
  return to_jsonb(i);
end $$;

create or replace function public.approve_site_claim_package(p_package_id uuid,p_note text default null)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare p public.site_claim_packages%rowtype; v_bad integer; v_stale integer;
begin
  select * into p from public.site_claim_packages where id=p_package_id for update;
  if not found then raise exception 'Claim package not found'; end if;
  if not app_private.project_context_operational(p.project_id,p.site_id) then raise exception 'Project or site is archived'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.manage',p.project_id,p.site_id,null,null) then raise exception 'Permission denied'; end if;
  if p.status<>'submitted' then raise exception 'Only submitted packages can be approved'; end if;
  select count(*) into v_bad from public.site_claim_items where package_id=p.id and status='rejected';
  if v_bad>0 then raise exception 'Rejected evidence must be corrected before approval'; end if;
  select count(*) into v_stale from public.site_claim_items i join public.documents d on d.id=i.document_id where i.package_id=p.id and i.selected_version_id is not null and d.current_version_id is distinct from i.selected_version_id;
  if v_stale>0 then raise exception 'Evidence changed after submission; review the updated versions first'; end if;
  update public.site_claim_packages set status='approved',approved_at=now(),approved_by=auth.uid(),review_note=nullif(trim(coalesce(p_note,'')),'') where id=p.id returning * into p;
  return to_jsonb(p);
end $$;

create or replace function public.reject_site_claim_package(p_package_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare p public.site_claim_packages%rowtype; v_reason text:=nullif(trim(coalesce(p_reason,'')),'');
begin
  if v_reason is null then raise exception 'Rejection reason is required'; end if;
  select * into p from public.site_claim_packages where id=p_package_id for update;
  if not found then raise exception 'Claim package not found'; end if;
  if not app_private.project_context_operational(p.project_id,p.site_id) then raise exception 'Project or site is archived'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.manage',p.project_id,p.site_id,null,null) then raise exception 'Permission denied'; end if;
  if p.status not in('ready','submitted') then raise exception 'Package is not in review'; end if;
  update public.site_claim_packages set status='rejected',rejected_at=now(),rejected_by=auth.uid(),rejection_reason=v_reason where id=p.id returning * into p;
  return to_jsonb(p);
end $$;

create or replace function public.site_claim_package_intelligence(p_package_id uuid)
returns jsonb language plpgsql stable security definer set search_path='public','app_private','pg_temp'
as $$
declare p public.site_claim_packages%rowtype; v_manage boolean:=false; v_suggestions jsonb:='[]'::jsonb;
begin
  select * into p from public.site_claim_packages where id=p_package_id;
  if not found then raise exception 'Claim package not found'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.view',p.project_id,p.site_id,null,null) then raise exception 'Permission denied'; end if;
  v_manage:=app_private.project_context_operational(p.project_id,p.site_id) and app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.manage',p.project_id,p.site_id,null,null);
  if v_manage and p.locked_at is null and p.status in('collecting','rejected') then
    begin v_suggestions:=public.site_claim_suggestions(p.id); exception when others then v_suggestions:='[]'::jsonb; end;
  end if;
  return jsonb_build_object(
    'stale_evidence',coalesce((select jsonb_agg(jsonb_build_object('item_id',i.id,'document_id',d.id,'display_name',d.display_name,'selected_version_id',i.selected_version_id,'current_version_id',d.current_version_id,'cabinet_id',i.cabinet_id) order by d.display_name) from public.site_claim_items i join public.documents d on d.id=i.document_id where i.package_id=p.id and i.selected_version_id is not null and d.current_version_id is distinct from i.selected_version_id),'[]'::jsonb),
    'rejected_evidence',coalesce((select jsonb_agg(jsonb_build_object('item_id',i.id,'document_id',d.id,'display_name',d.display_name,'note',i.decision_note,'reviewed_at',i.reviewed_at,'reviewed_by',i.reviewed_by) order by i.reviewed_at desc nulls last) from public.site_claim_items i join public.documents d on d.id=i.document_id where i.package_id=p.id and i.status='rejected'),'[]'::jsonb),
    'suggestions',v_suggestions,
    'events',coalesce((select jsonb_agg(jsonb_build_object('id',ev.id,'event_type',ev.event_type,'actor_id',ev.actor_id,'actor_name',pr.full_name,'note',ev.note,'metadata',ev.metadata,'created_at',ev.created_at) order by ev.created_at desc) from public.site_claim_package_events ev left join public.profiles pr on pr.id=ev.actor_id where ev.package_id=p.id limit 40),'[]'::jsonb),
    'can_manage',v_manage
  );
end $$;

create or replace function public.cabinet_closeout_snapshot(p_cabinet_id uuid)
returns jsonb language plpgsql stable security definer set search_path='public','app_private','pg_temp'
as $$
declare c public.site_cabinets%rowtype; v_total integer:=0; v_ready integer:=0; v_package uuid;
begin
  select * into c from public.site_cabinets where id=p_cabinet_id;
  if not found then raise exception 'Cabinet not found'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),c.company_id,'projects.view',c.project_id,c.site_id,null,null) then raise exception 'Permission denied'; end if;
  select cp.id into v_package from public.site_claim_packages cp where cp.site_id=c.site_id and cp.claim_type='final' and cp.status<>'archived' order by cp.created_at limit 1;
  with rr as(
    select dr.id,dr.min_items,dr.is_required,
      count(drl.document_id) filter(where d.state='active' and d.current_version_id is not null and v.upload_state='ready')::integer ready_count
    from public.document_requirements dr
    left join public.document_requirement_links drl on drl.requirement_id=dr.id
    left join public.documents d on d.id=drl.document_id
    left join public.document_versions v on v.id=d.current_version_id
    where dr.company_id=c.company_id and dr.project_id=c.project_id and dr.site_id=c.site_id and dr.cabinet_id=c.id
    group by dr.id,dr.min_items,dr.is_required
  ) select count(*) filter(where is_required),count(*) filter(where is_required and ready_count>=min_items) into v_total,v_ready from rr;
  return jsonb_build_object(
    'cabinet',jsonb_build_object('id',c.id,'code',c.code,'name',c.name,'status',c.status,'site_id',c.site_id,'project_id',c.project_id),
    'package_id',v_package,
    'required_total',v_total,'required_ready',v_ready,'readiness_percent',case when v_total=0 then 0 else round(v_ready::numeric/v_total*100) end,
    'requirements',coalesce((select jsonb_agg(jsonb_build_object('id',dr.id,'requirement_key',dr.requirement_key,'label_ar',dr.label_ar,'label_en',dr.label_en,'is_required',dr.is_required,'min_items',dr.min_items,'ready_count',(select count(*) from public.document_requirement_links l join public.documents d on d.id=l.document_id join public.document_versions v on v.id=d.current_version_id and v.upload_state='ready' where l.requirement_id=dr.id and d.state='active')) order by dr.sort_order,dr.created_at) from public.document_requirements dr where dr.company_id=c.company_id and dr.project_id=c.project_id and dr.site_id=c.site_id and dr.cabinet_id=c.id),'[]'::jsonb)
  );
end $$;

create or replace function public.delivery_closeout_map(p_project_id uuid)
returns jsonb language plpgsql stable security definer set search_path='public','app_private','pg_temp'
as $$
declare p public.projects%rowtype;
begin
  select * into p from public.projects where id=p_project_id;
  if not found then raise exception 'Project not found'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'projects.view',p.id,null,null,null) then raise exception 'Permission denied'; end if;
  return jsonb_build_object(
    'project',jsonb_build_object('id',p.id,'code',p.code,'name',p.name),
    'sites',coalesce((select jsonb_agg(jsonb_build_object(
      'id',s.id,'code',s.code,'name',s.name,'status',s.status,
      'package_id',cp.id,'package_status',cp.status,
      'cabinets',coalesce((select jsonb_agg(jsonb_build_object(
        'id',c.id,'code',c.code,'name',c.name,'status',c.status,
        'required_total',(select count(*) from public.document_requirements dr where dr.cabinet_id=c.id and dr.is_required),
        'required_ready',(select count(*) from public.document_requirements dr where dr.cabinet_id=c.id and dr.is_required and (select count(*) from public.document_requirement_links l join public.documents d on d.id=l.document_id join public.document_versions v on v.id=d.current_version_id and v.upload_state='ready' where l.requirement_id=dr.id and d.state='active')>=dr.min_items)
      ) order by c.code) from public.site_cabinets c where c.site_id=s.id and c.archived_at is null),'[]'::jsonb)
    ) order by s.name) from public.sites s left join lateral(select cp0.* from public.site_claim_packages cp0 where cp0.site_id=s.id and cp0.claim_type='final' and cp0.status<>'archived' order by cp0.created_at limit 1)cp on true where s.project_id=p.id and app_private.user_has_resource_permission(auth.uid(),p.company_id,'projects.view',p.id,s.id,null,null)),'[]'::jsonb)
  );
end $$;

-- Enrich the existing directory while preserving the same jsonb contract/signature.
create or replace function public.delivery_directory_query(p_company_id uuid,p_project_id uuid default null,p_site_id uuid default null,p_status text default null,p_query text default null,p_limit integer default 50,p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path='public','app_private','pg_temp'
as $$
declare v_uid uuid:=auth.uid();v_limit integer:=greatest(1,least(coalesce(p_limit,50),100));v_offset integer:=greatest(coalesce(p_offset,0),0);v_query text:=trim(coalesce(p_query,''));v_status text:=nullif(trim(coalesce(p_status,'')),'');v_unscoped_files boolean:=false;v_unscoped_projects boolean:=false;v_result jsonb;
begin
  if v_uid is null or not app_private.has_company_permission(p_company_id,'files.view') then raise exception 'Permission denied'; end if;
  if v_status is not null and v_status not in('collecting','ready','submitted','approved','rejected','archived') then raise exception 'Invalid claim status'; end if;
  v_unscoped_files:=app_private.user_permission_is_unscoped(v_uid,p_company_id,'files.view');
  v_unscoped_projects:=app_private.has_company_permission(p_company_id,'projects.view') and app_private.user_permission_is_unscoped(v_uid,p_company_id,'projects.view');
  with visible_packages as materialized(
    select cp.*,pr.code project_code,pr.name project_name,s.code site_code,s.name site_name
    from public.site_claim_packages cp join public.projects pr on pr.id=cp.project_id join public.sites s on s.id=cp.site_id
    where cp.company_id=p_company_id and (p_project_id is null or cp.project_id=p_project_id) and (p_site_id is null or cp.site_id=p_site_id)
      and(v_unscoped_files or app_private.user_has_resource_permission(v_uid,p_company_id,'files.view',cp.project_id,cp.site_id,null,null))
  ), enriched as materialized(
    select vp.*,
      coalesce(q.required_total,0) required_total,coalesce(q.required_ready,0) required_ready,
      case when coalesce(q.required_total,0)=0 then 100 else round(q.required_ready::numeric/q.required_total*100) end required_percent,
      coalesce(q.invalid_items,0) invalid_items,coalesce(q.stale_items,0) stale_items,
      case when coalesce(q.required_total,0)=0 then 100 else round((q.required_ready::numeric/q.required_total*100)*.8 + (case when coalesce(q.invalid_items,0)+coalesce(q.stale_items,0)=0 then 100 else 50 end)*.2) end readiness_percent
    from visible_packages vp left join lateral(
      select
        count(*) filter(where r.is_required)::integer required_total,
        count(*) filter(where r.is_required and coalesce(ri.ready_count,0)>=r.min_items)::integer required_ready,
        coalesce(sum(ri.invalid_items),0)::integer invalid_items,
        coalesce(sum(ri.stale_items),0)::integer stale_items
      from public.site_claim_requirements r
      left join lateral(
        select count(i.id) filter(where i.status<>'rejected' and d.state='active' and v.upload_state='ready')::integer ready_count,
          count(i.id) filter(where i.status<>'rejected' and(d.id is null or d.state<>'active' or d.current_version_id is null or v.upload_state<>'ready'))::integer invalid_items,
          count(i.id) filter(where i.selected_version_id is not null and d.current_version_id is distinct from i.selected_version_id)::integer stale_items
        from public.site_claim_items i left join public.documents d on d.id=i.document_id left join public.document_versions v on v.id=d.current_version_id where i.requirement_id=r.id
      )ri on true where r.package_id=vp.id
    )q on true
  ),filtered as materialized(select * from enriched where(v_status is null or status=v_status) and(v_query='' or package_no ilike '%'||v_query||'%' or title ilike '%'||v_query||'%' or project_name ilike '%'||v_query||'%' or site_name ilike '%'||v_query||'%')),
  page as materialized(select * from filtered order by case status when 'rejected' then 1 when 'ready' then 2 when 'submitted' then 3 when 'collecting' then 4 else 5 end,updated_at desc,id limit v_limit offset v_offset),
  package_counts as(select count(*) packages,count(*) filter(where status='collecting') collecting,count(*) filter(where status='ready') ready,count(*) filter(where status='submitted') submitted,count(*) filter(where status='approved') approved,count(*) filter(where status='rejected') rejected,count(*) filter(where stale_items>0) stale from enriched),
  cabinet_count as(select count(*) cabinets from public.site_cabinets c where c.company_id=p_company_id and c.archived_at is null and(p_project_id is null or c.project_id=p_project_id) and(p_site_id is null or c.site_id=p_site_id) and(v_unscoped_projects or app_private.user_has_resource_permission(v_uid,p_company_id,'projects.view',c.project_id,c.site_id,null,null)))
  select jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(page)) from page),'[]'::jsonb),'total',(select count(*) from filtered),'offset',v_offset,'limit',v_limit,'has_more',(select count(*) from filtered)>v_offset+v_limit,'counts',jsonb_build_object('packages',(select packages from package_counts),'collecting',(select collecting from package_counts),'ready',(select ready from package_counts),'submitted',(select submitted from package_counts),'approved',(select approved from package_counts),'rejected',(select rejected from package_counts),'stale',(select stale from package_counts),'cabinets',(select cabinets from cabinet_count))) into v_result;
  return v_result;
end $$;

revoke all on function public.refresh_site_delivery_package(uuid),public.review_site_claim_item(uuid,text,text),public.approve_site_claim_package(uuid,text),public.reject_site_claim_package(uuid,text),public.site_claim_package_intelligence(uuid),public.cabinet_closeout_snapshot(uuid),public.delivery_closeout_map(uuid) from public,anon;
grant execute on function public.refresh_site_delivery_package(uuid),public.review_site_claim_item(uuid,text,text),public.approve_site_claim_package(uuid,text),public.reject_site_claim_package(uuid,text),public.site_claim_package_intelligence(uuid),public.cabinet_closeout_snapshot(uuid),public.delivery_closeout_map(uuid) to authenticated;

commit;
