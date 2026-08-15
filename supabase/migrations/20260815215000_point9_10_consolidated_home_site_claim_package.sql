-- Optimum 6.9.1 — Core Point 9–10 consolidation
-- Role-aware Home + Site Claim Package assembly foundation.
begin;

alter table public.documents
  add column if not exists claim_inclusion_mode text not null default 'auto',
  add column if not exists claim_requirement_key text;

do $$ begin
  if not exists(select 1 from pg_constraint where conname='documents_claim_inclusion_mode_check') then
    alter table public.documents add constraint documents_claim_inclusion_mode_check
      check(claim_inclusion_mode in ('auto','include','exclude'));
  end if;
end $$;

create index if not exists documents_claim_classification_idx
  on public.documents(project_id,site_id,claim_inclusion_mode,claim_requirement_key)
  where state='active';

create table if not exists public.site_claim_exports(
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  package_id uuid not null references public.site_claim_packages(id) on delete cascade,
  file_count integer not null default 0 check(file_count>=0),
  manifest_hash text,
  note text,
  exported_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index if not exists site_claim_exports_package_idx on public.site_claim_exports(package_id,created_at desc);

alter table public.site_claim_exports enable row level security;
drop policy if exists site_claim_exports_select on public.site_claim_exports;
create policy site_claim_exports_select on public.site_claim_exports for select to authenticated using(
  exists(
    select 1 from public.site_claim_packages p
    where p.id=package_id
      and app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.view',p.project_id,p.site_id,null,null)
  )
);

revoke all on public.site_claim_exports from anon,authenticated;
grant select on public.site_claim_exports to authenticated;
grant all on public.site_claim_exports to service_role;

-- Current phase: the claim is a site document package, not a commercial valuation engine.
-- Keep older keys for backwards compatibility but stop requiring items that are outside the clarified scope.
update public.site_claim_requirements
set is_required=false
where requirement_key in ('contract','sketches','handover_certificate','approvals','photos')
  and package_id in(select id from public.site_claim_packages where claim_type='final' and status<>'archived');

insert into public.site_claim_requirements(company_id,package_id,requirement_key,label_ar,label_en,category,is_required,min_items,sort_order,notes,created_by)
select p.company_id,p.id,x.key,x.ar,x.en,x.category,x.required,1,x.sort_order,'Core site claim package requirement',p.created_by
from public.site_claim_packages p
cross join (values
  ('work_order','أمر التكليف','Work Order','project',true,10),
  ('work_order_statement','بيان أمر التكليف','Work Order Statement','project',true,20),
  ('as_built_drawings','رسومات As-Built','As-Built Drawings','technical',true,30),
  ('quantity_survey','الحصر','Takeoff / Quantity Survey','quantity',true,40),
  ('test_sheet','Test Sheet','Test Sheet','quality',true,50),
  ('quality_certificate','شهادة الجودة','Quality Certificate','quality',true,60),
  ('warranty_certificate','شهادة الضمان','Warranty Certificate','quality',true,70),
  ('invoice','الفاتورة','Invoice','commercial',true,80),
  ('project_documents','مستندات المشروع الأخرى','Other Project Documents','project',false,90),
  ('supporting','مستندات داعمة أخرى','Other Supporting Documents','supporting',false,100)
) as x(key,ar,en,category,required,sort_order)
where p.claim_type='final' and p.status<>'archived'
on conflict(package_id,requirement_key) do update set
  label_ar=excluded.label_ar,
  label_en=excluded.label_en,
  category=excluded.category,
  is_required=excluded.is_required,
  sort_order=excluded.sort_order,
  notes=excluded.notes,
  updated_at=now();

create or replace function app_private.site_claim_requirement_for_document(p_document_id uuid)
returns text language plpgsql stable security definer set search_path='public','app_private','pg_temp'
as $$
declare d public.documents%rowtype; inferred text;
begin
  select * into d from public.documents where id=p_document_id;
  if not found then return null; end if;
  if d.claim_requirement_key is not null and trim(d.claim_requirement_key)<>'' then return d.claim_requirement_key; end if;
  begin
    inferred:=app_private.infer_site_claim_requirement(d.id);
  exception when undefined_function then
    inferred:=null;
  end;
  if inferred is not null then return inferred; end if;
  if lower(coalesce(d.document_type,''))='boq' then return 'quantity_survey'; end if;
  if lower(coalesce(d.document_type,''))='drawing' and (coalesce(d.tags,'{}'::text[]) && array['as-built','as_built','asbuilt']) then return 'as_built_drawings'; end if;
  return null;
end $$;

create or replace function public.set_document_claim_classification(
  p_document_id uuid,
  p_mode text default 'auto',
  p_requirement_key text default null
) returns jsonb
language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare
  d public.documents%rowtype;
  p public.site_claim_packages%rowtype;
  r public.site_claim_requirements%rowtype;
  v_mode text:=lower(trim(coalesce(p_mode,'auto')));
  v_key text:=nullif(lower(trim(coalesce(p_requirement_key,''))), '');
  v_linked integer:=0;
begin
  select * into d from public.documents where id=p_document_id and state='active';
  if not found then raise exception 'Document not found'; end if;
  if v_mode not in('auto','include','exclude') then raise exception 'Invalid claim inclusion mode'; end if;
  if not (
    app_private.user_has_resource_permission(auth.uid(),d.company_id,'files.upload',d.project_id,d.site_id,d.folder_id,null)
    or app_private.user_has_resource_permission(auth.uid(),d.company_id,'files.manage',d.project_id,d.site_id,d.folder_id,null)
  ) then raise exception 'Permission denied'; end if;

  update public.documents
  set claim_inclusion_mode=v_mode,
      claim_requirement_key=case when p_requirement_key is not null then v_key else claim_requirement_key end,
      updated_at=now()
  where id=d.id
  returning * into d;

  if v_mode='exclude' then
    delete from public.site_claim_items i
    using public.site_claim_packages cp
    where i.document_id=d.id and cp.id=i.package_id
      and cp.locked_at is null and cp.status in('collecting','rejected')
      and i.inclusion_mode in('auto','upload');
    return jsonb_build_object('document_id',d.id,'mode',v_mode,'linked',0);
  end if;

  if v_key is null then v_key:=app_private.site_claim_requirement_for_document(d.id); end if;
  if v_mode='include' and v_key is null then v_key:='supporting'; end if;
  if v_key is null then return jsonb_build_object('document_id',d.id,'mode',v_mode,'linked',0,'reason','no_requirement_inferred'); end if;

  for p in
    select cp.* from public.site_claim_packages cp
    where cp.project_id=d.project_id
      and cp.claim_type='final' and cp.status in('collecting','rejected') and cp.locked_at is null
      and (d.site_id is null or cp.site_id=d.site_id)
  loop
    if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.view',p.project_id,p.site_id,d.folder_id,null) then continue; end if;
    select * into r from public.site_claim_requirements where package_id=p.id and requirement_key=v_key;
    if not found then
      insert into public.site_claim_requirements(company_id,package_id,requirement_key,label_ar,label_en,category,is_required,min_items,sort_order,notes,created_by)
      values(p.company_id,p.id,v_key,case v_key when 'supporting' then 'مستندات داعمة أخرى' else v_key end,case v_key when 'supporting' then 'Other Supporting Documents' else v_key end,'supporting',false,1,500,'Created from document classification',auth.uid())
      returning * into r;
    end if;
    insert into public.site_claim_items(company_id,package_id,requirement_id,document_id,cabinet_id,inclusion_mode,status,added_by)
    values(p.company_id,p.id,r.id,d.id,case when d.site_id is null then null else app_private.cabinet_for_folder(d.folder_id) end,case when v_mode='include' then 'upload' else 'auto' end,'included',auth.uid())
    on conflict(package_id,requirement_id,document_id) do update set
      inclusion_mode=excluded.inclusion_mode,
      cabinet_id=coalesce(excluded.cabinet_id,site_claim_items.cabinet_id),
      status='included',selected_version_id=null,updated_at=now();
    v_linked:=v_linked+1;
  end loop;
  return jsonb_build_object('document_id',d.id,'mode',v_mode,'requirement_key',v_key,'linked',v_linked);
end $$;

create or replace function public.refresh_site_claim_package_v2(p_package_id uuid)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare p public.site_claim_packages%rowtype; d record; v_key text; v_links integer:=0; v_base jsonb:='{}'::jsonb;
begin
  select * into p from public.site_claim_packages where id=p_package_id;
  if not found then raise exception 'Claim package not found'; end if;
  if p.locked_at is not null or p.status in('submitted','approved','archived') then raise exception 'Claim package is locked'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.manage',p.project_id,p.site_id,null,null) then raise exception 'Permission denied'; end if;

  begin v_base:=public.refresh_site_delivery_package(p.id); exception when others then v_base:=jsonb_build_object('warning',sqlerrm); end;

  for d in
    select doc.* from public.documents doc
    join public.document_versions v on v.id=doc.current_version_id and v.upload_state='ready'
    where doc.project_id=p.project_id and doc.state='active'
      and (doc.site_id=p.site_id or doc.site_id is null)
      and doc.claim_inclusion_mode<>'exclude'
      and app_private.user_has_resource_permission(auth.uid(),doc.company_id,'files.view',doc.project_id,doc.site_id,doc.folder_id,null)
  loop
    v_key:=app_private.site_claim_requirement_for_document(d.id);
    if d.claim_inclusion_mode='include' and v_key is null then v_key:='supporting'; end if;
    if v_key is null then continue; end if;
    if exists(select 1 from public.site_claim_requirements r where r.package_id=p.id and r.requirement_key=v_key) then
      insert into public.site_claim_items(company_id,package_id,requirement_id,document_id,cabinet_id,inclusion_mode,status,added_by)
      select p.company_id,p.id,r.id,d.id,case when d.site_id is null then null else app_private.cabinet_for_folder(d.folder_id) end,case when d.claim_inclusion_mode='include' then 'upload' else 'auto' end,'included',auth.uid()
      from public.site_claim_requirements r where r.package_id=p.id and r.requirement_key=v_key
      on conflict(package_id,requirement_id,document_id) do update set status='included',updated_at=now();
      v_links:=v_links+1;
    end if;
  end loop;

  delete from public.site_claim_items i using public.documents d
  where i.package_id=p.id and i.document_id=d.id and d.claim_inclusion_mode='exclude'
    and i.inclusion_mode in('auto','upload');

  return jsonb_build_object('base',v_base,'classified_documents_scanned',v_links);
end $$;

create or replace function public.site_claim_package_export_manifest(p_package_id uuid)
returns jsonb language plpgsql stable security definer set search_path='public','app_private','pg_temp'
as $$
declare p public.site_claim_packages%rowtype; v_missing integer:=0;
begin
  select * into p from public.site_claim_packages where id=p_package_id;
  if not found then raise exception 'Claim package not found'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.view',p.project_id,p.site_id,null,null) then raise exception 'Permission denied'; end if;

  select count(*) into v_missing
  from public.site_claim_requirements r
  where r.package_id=p.id and r.is_required and
    (select count(*) from public.site_claim_items i join public.documents d on d.id=i.document_id
      left join public.document_versions v on v.id=coalesce(i.selected_version_id,d.current_version_id)
      where i.requirement_id=r.id and i.status<>'rejected' and d.state='active' and v.upload_state='ready')<r.min_items;

  return jsonb_build_object(
    'package',jsonb_build_object('id',p.id,'package_no',p.package_no,'title',p.title,'status',p.status,'locked_at',p.locked_at,'project_id',p.project_id,'site_id',p.site_id),
    'project',(select jsonb_build_object('id',pr.id,'code',pr.code,'name',pr.name) from public.projects pr where pr.id=p.project_id),
    'site',(select jsonb_build_object('id',s.id,'code',s.code,'name',s.name) from public.sites s where s.id=p.site_id),
    'missing_required',v_missing,
    'ready_for_export',(p.locked_at is not null and v_missing=0),
    'requirements',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'key',r.requirement_key,'label_ar',r.label_ar,'label_en',r.label_en,'category',r.category,'required',r.is_required,'min_items',r.min_items,'ready_count',(select count(*) from public.site_claim_items i join public.documents d on d.id=i.document_id left join public.document_versions v on v.id=coalesce(i.selected_version_id,d.current_version_id) where i.requirement_id=r.id and i.status<>'rejected' and d.state='active' and v.upload_state='ready')) order by r.sort_order,r.created_at) from public.site_claim_requirements r where r.package_id=p.id),'[]'::jsonb),
    'items',coalesce((select jsonb_agg(jsonb_build_object(
      'item_id',i.id,'document_id',d.id,'display_name',d.display_name,'document_type',d.document_type,
      'requirement_key',r.requirement_key,'label_ar',r.label_ar,'label_en',r.label_en,'category',r.category,
      'scope_kind',case when d.site_id is null then 'project' when i.cabinet_id is not null then 'cabinet' else 'site' end,
      'cabinet_id',c.id,'cabinet_code',c.code,'cabinet_name',c.name,
      'version_id',v.id,'version_number',v.version_number,'revision_code',v.revision_code,'original_filename',v.original_filename,
      'storage_bucket',v.storage_bucket,'storage_path',v.storage_path,'mime_type',v.mime_type,'size_bytes',v.size_bytes,
      'selected_version_id',i.selected_version_id,'current_version_id',d.current_version_id
    ) order by case when d.site_id is null then 1 when i.cabinet_id is null then 2 else 3 end,coalesce(c.code,''),r.sort_order,d.display_name)
    from public.site_claim_items i
    join public.site_claim_requirements r on r.id=i.requirement_id
    join public.documents d on d.id=i.document_id and d.state='active'
    join public.document_versions v on v.id=coalesce(i.selected_version_id,d.current_version_id) and v.upload_state='ready'
    left join public.site_cabinets c on c.id=i.cabinet_id
    where i.package_id=p.id and i.status<>'rejected'),'[]'::jsonb),
    'exports',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'file_count',x.file_count,'manifest_hash',x.manifest_hash,'exported_by',x.exported_by,'exported_by_name',pr.full_name,'created_at',x.created_at) order by x.created_at desc) from public.site_claim_exports x left join public.profiles pr on pr.id=x.exported_by where x.package_id=p.id),'[]'::jsonb)
  );
end $$;

create or replace function public.record_site_claim_export(p_package_id uuid,p_file_count integer,p_manifest_hash text default null,p_note text default null)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare p public.site_claim_packages%rowtype; x public.site_claim_exports%rowtype;
begin
  select * into p from public.site_claim_packages where id=p_package_id;
  if not found then raise exception 'Claim package not found'; end if;
  if p.locked_at is null then raise exception 'Freeze package versions before export'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.manage',p.project_id,p.site_id,null,null) then raise exception 'Permission denied'; end if;
  insert into public.site_claim_exports(company_id,package_id,file_count,manifest_hash,note,exported_by)
  values(p.company_id,p.id,greatest(0,coalesce(p_file_count,0)),nullif(trim(coalesce(p_manifest_hash,'')),''),nullif(trim(coalesce(p_note,'')),''),auth.uid()) returning * into x;
  perform app_private.record_site_claim_event(p.id,'package_exported',p_note,jsonb_build_object('export_id',x.id,'file_count',x.file_count,'manifest_hash',x.manifest_hash));
  return to_jsonb(x);
end $$;

revoke all on function app_private.site_claim_requirement_for_document(uuid) from public,anon,authenticated;
revoke all on function public.set_document_claim_classification(uuid,text,text),public.refresh_site_claim_package_v2(uuid),public.site_claim_package_export_manifest(uuid),public.record_site_claim_export(uuid,integer,text,text) from public,anon;
grant execute on function public.set_document_claim_classification(uuid,text,text),public.refresh_site_claim_package_v2(uuid),public.site_claim_package_export_manifest(uuid),public.record_site_claim_export(uuid,integer,text,text) to authenticated;

commit;
