-- Point 6 — Engineering Studio Core
-- Full-screen engineering workspace foundations: change intelligence, company catalog schemas,
-- CDE linkage, cabinet scope, engineering issues/tasks, and notification-aware saving.

alter table public.engineering_catalog_items
  add column if not exists family text,
  add column if not exists description_ar text,
  add column if not exists description_en text,
  add column if not exists attribute_schema jsonb not null default '[]'::jsonb;

update public.engineering_catalog_items
set family=coalesce(nullif(family,''),nullif(default_properties->>'palette_family',''),category,'general')
where family is null or family='';


-- Meaningful built-in attribute schemas: keep each item focused on data it actually owns.
update public.engineering_catalog_items c set attribute_schema=case
  when c.symbol_key in('main_cabinet','sub_cabinet','fdt') then '[{"key":"boxNo","type":"text","label_ar":"رقم الكابينة","label_en":"Cabinet no.","required":true},{"key":"networkLevel","type":"select","label_ar":"المستوى","label_en":"Network level","options":["main","secondary","distribution"]},{"key":"capacity","type":"number","label_ar":"السعة","label_en":"Capacity","takeoff":true},{"key":"ports","type":"number","label_ar":"المنافذ","label_en":"Ports"},{"key":"cabinetU","type":"number","label_ar":"حجم U","label_en":"U size"},{"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}]'::jsonb
  when c.symbol_key in('termination_box','fat','odb') then '[{"key":"boxNo","type":"text","label_ar":"رقم البوكس","label_en":"Box no.","required":true},{"key":"networkLevel","type":"select","label_ar":"المستوى","label_en":"Network level","options":["secondary","distribution","customer"]},{"key":"capacity","type":"number","label_ar":"السعة / الكور","label_en":"Capacity / cores","takeoff":true},{"key":"ports","type":"number","label_ar":"المنافذ","label_en":"Ports"},{"key":"villaNo","type":"text","label_ar":"رقم المبنى/الفيلا","label_en":"Building / villa no."},{"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}]'::jsonb
  when c.symbol_key in('manhole','handhole','chamber') then '[{"key":"boxNo","type":"text","label_ar":"رقم الغرفة","label_en":"Chamber no.","required":true},{"key":"lengthM","type":"number","label_ar":"الطول م","label_en":"Length m"},{"key":"widthM","type":"number","label_ar":"العرض م","label_en":"Width m"},{"key":"heightM","type":"number","label_ar":"العمق/الارتفاع م","label_en":"Depth / height m"},{"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}]'::jsonb
  when c.symbol_key='pole' then '[{"key":"boxNo","type":"text","label_ar":"رقم العمود","label_en":"Pole no.","required":true},{"key":"heightM","type":"number","label_ar":"الارتفاع م","label_en":"Height m"},{"key":"poleType","type":"text","label_ar":"نوع العمود","label_en":"Pole type"},{"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}]'::jsonb
  when c.symbol_key in('joint','closure','tdm') then '[{"key":"boxNo","type":"text","label_ar":"الرقم","label_en":"No."},{"key":"coreRange","type":"text","label_ar":"مدى الكور","label_en":"Core range"},{"key":"capacity","type":"number","label_ar":"السعة","label_en":"Capacity"},{"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}]'::jsonb
  when c.symbol_key='odf' then '[{"key":"ports","type":"number","label_ar":"المنافذ","label_en":"Ports","required":true},{"key":"odfPort","type":"text","label_ar":"منفذ / نطاق","label_en":"Port / range"},{"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}]'::jsonb
  when c.symbol_key='splitter' then '[{"key":"splitterPort","type":"text","label_ar":"منفذ السبلتر","label_en":"Splitter port"},{"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}]'::jsonb
  when c.symbol_key='lgx' then '[{"key":"cabinetU","type":"number","label_ar":"حجم U","label_en":"U size"},{"key":"ports","type":"number","label_ar":"المنافذ","label_en":"Ports"},{"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}]'::jsonb
  when c.symbol_key='microduct' then '[{"key":"networkLevel","type":"select","label_ar":"المستوى","label_en":"Network level","options":["main","secondary","distribution"]},{"key":"installation","type":"select","label_ar":"طريقة التنفيذ","label_en":"Installation","options":["underground","aerial","indoor","surface"]},{"key":"ways","type":"number","label_ar":"عدد المسارات","label_en":"Ways","takeoff":true},{"key":"diameter","type":"text","label_ar":"القطر","label_en":"Diameter"},{"key":"cableCode","type":"catalog","catalog_symbol":"fiber_cable","label_ar":"الكابل الداخلي","label_en":"Inner cable"},{"key":"numberOfCables","type":"number","label_ar":"عدد الكابلات","label_en":"Number of cables"},{"key":"spareLengthM","type":"number","label_ar":"طول الاحتياطي م","label_en":"Spare length m"},{"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}]'::jsonb
  when c.symbol_key='fiber_cable' then '[{"key":"networkLevel","type":"select","label_ar":"المستوى","label_en":"Network level","options":["main","secondary","distribution"]},{"key":"installation","type":"select","label_ar":"طريقة التنفيذ","label_en":"Installation","options":["underground","aerial","indoor","surface"]},{"key":"fiberCores","type":"number","label_ar":"عدد الكور","label_en":"Fiber cores","takeoff":true},{"key":"spareLengthM","type":"number","label_ar":"طول الاحتياطي م","label_en":"Spare length m"},{"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}]'::jsonb
  when c.symbol_key='suspension_wire' then '[{"key":"installation","type":"select","label_ar":"طريقة التنفيذ","label_en":"Installation","options":["aerial"]},{"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}]'::jsonb
  else c.attribute_schema end
where c.company_id is null and (c.attribute_schema='[]'::jsonb or c.attribute_schema is null);

alter table public.engineering_drawings
  add column if not exists cabinet_id uuid references public.site_cabinets(id) on delete set null,
  add column if not exists cde_document_id uuid references public.documents(id) on delete set null,
  add column if not exists last_change_at timestamptz,
  add column if not exists last_change_summary jsonb not null default '{}'::jsonb,
  add column if not exists last_changed_by uuid references public.profiles(id) on delete set null;

alter table public.engineering_revisions
  add column if not exists cde_document_version_id uuid references public.document_versions(id) on delete set null,
  add column if not exists change_summary jsonb not null default '{}'::jsonb;

create table if not exists public.engineering_revision_events(
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  drawing_id uuid not null references public.engineering_drawings(id) on delete cascade,
  revision_id uuid references public.engineering_revisions(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  event_type text not null check(event_type in('created','saved','revision_created','submitted','published','restored','cde_synced','note_added','issue_created')),
  change_summary jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists engineering_revision_events_drawing_created_idx on public.engineering_revision_events(drawing_id,created_at desc);

create table if not exists public.engineering_drawing_views(
  drawing_id uuid not null references public.engineering_drawings(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  last_viewed_at timestamptz not null default now(),
  primary key(drawing_id,user_id)
);

create table if not exists public.engineering_task_links(
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  drawing_id uuid not null references public.engineering_drawings(id) on delete cascade,
  revision_id uuid references public.engineering_revisions(id) on delete set null,
  task_id uuid not null references public.tasks(id) on delete cascade,
  target_kind text check(target_kind in('node','route','annotation','mark','sheet')),
  target_id text,
  x numeric,
  y numeric,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(task_id,drawing_id)
);
create index if not exists engineering_task_links_drawing_idx on public.engineering_task_links(drawing_id,created_at desc);

alter table public.engineering_revision_events enable row level security;
alter table public.engineering_drawing_views enable row level security;
alter table public.engineering_task_links enable row level security;

drop policy if exists engineering_revision_events_select on public.engineering_revision_events;
create policy engineering_revision_events_select on public.engineering_revision_events for select using(app_private.can_view_engineering_drawing(drawing_id));
drop policy if exists engineering_drawing_views_select on public.engineering_drawing_views;
create policy engineering_drawing_views_select on public.engineering_drawing_views for select using(user_id=auth.uid() and app_private.can_view_engineering_drawing(drawing_id));
drop policy if exists engineering_task_links_select on public.engineering_task_links;
create policy engineering_task_links_select on public.engineering_task_links for select using(app_private.can_view_engineering_drawing(drawing_id) and app_private.can_view_task(task_id));

create or replace function app_private.engineering_folder_for_scope(p_project_id uuid,p_site_id uuid default null,p_cabinet_id uuid default null)
returns uuid language plpgsql stable security definer set search_path=public,app_private,pg_temp as $$
declare v_folder uuid;
begin
  if p_cabinet_id is not null then
    select root_folder_id into v_folder from public.site_cabinets
    where id=p_cabinet_id and project_id=p_project_id and site_id is not distinct from p_site_id and archived_at is null;
    if v_folder is not null then return v_folder; end if;
  end if;
  select f.id into v_folder
  from public.folders f
  where f.project_id=p_project_id and f.site_id is not distinct from p_site_id
    and f.trashed_at is null and f.hidden_at is null
    and (f.code='02' or f.code like '02.%' or lower(f.name) in('drawings','drawing') or f.name like '%رسومات%')
  order by case when f.code='02' then 0 when lower(f.name)='drawings' or f.name like '%رسومات%' then 1 else 2 end,f.depth,f.sort_order,f.created_at
  limit 1;
  if v_folder is not null then return v_folder; end if;
  select f.id into v_folder from public.folders f
  where f.project_id=p_project_id and f.site_id is not distinct from p_site_id and f.trashed_at is null and f.hidden_at is null
  order by f.depth,f.sort_order,f.created_at limit 1;
  return v_folder;
end $$;

create or replace function public.upsert_engineering_catalog_item(
  p_id uuid,p_company_id uuid,p_code text,p_family text,p_category text,p_symbol_key text,p_name_ar text,p_name_en text,
  p_unit text,p_description_ar text default null,p_description_en text default null,p_default_properties jsonb default '{}'::jsonb,
  p_attribute_schema jsonb default '[]'::jsonb,p_sort_order integer default 100
) returns uuid language plpgsql security definer set search_path=public,app_private,pg_temp as $$
declare v_id uuid:=coalesce(p_id,gen_random_uuid());
begin
  if auth.uid() is null or not app_private.has_company_permission(p_company_id,'catalog.manage') then raise exception 'Permission denied'; end if;
  if char_length(trim(coalesce(p_code,'')))<1 or char_length(trim(coalesce(p_code,'')))>80 then raise exception 'Catalog code is required'; end if;
  if char_length(trim(coalesce(p_name_en,p_name_ar,'')))<1 then raise exception 'Catalog name is required'; end if;
  if jsonb_typeof(coalesce(p_default_properties,'{}'::jsonb))<>'object' or jsonb_typeof(coalesce(p_attribute_schema,'[]'::jsonb))<>'array' then raise exception 'Invalid catalog schema'; end if;
  if p_id is not null and exists(select 1 from public.engineering_catalog_items where id=p_id and company_id is null) then raise exception 'Built-in catalog items cannot be edited; copy them first'; end if;
  insert into public.engineering_catalog_items(id,company_id,code,category,family,symbol_key,name_ar,name_en,unit,description_ar,description_en,default_properties,attribute_schema,sort_order,is_active,created_by)
  values(v_id,p_company_id,lower(trim(p_code)),coalesce(nullif(trim(p_category),''),'general'),coalesce(nullif(trim(p_family),''),nullif(trim(p_category),''),'general'),coalesce(nullif(trim(p_symbol_key),''),'generic'),nullif(trim(p_name_ar),''),nullif(trim(p_name_en),''),coalesce(nullif(trim(p_unit),''),'ea'),nullif(trim(p_description_ar),''),nullif(trim(p_description_en),''),coalesce(p_default_properties,'{}'::jsonb),coalesce(p_attribute_schema,'[]'::jsonb),coalesce(p_sort_order,100),true,auth.uid())
  on conflict(id) do update set code=excluded.code,category=excluded.category,family=excluded.family,symbol_key=excluded.symbol_key,name_ar=excluded.name_ar,name_en=excluded.name_en,unit=excluded.unit,description_ar=excluded.description_ar,description_en=excluded.description_en,default_properties=excluded.default_properties,attribute_schema=excluded.attribute_schema,sort_order=excluded.sort_order,is_active=true,updated_at=now()
  where engineering_catalog_items.company_id=p_company_id;
  return v_id;
end $$;

create or replace function public.archive_engineering_catalog_item(p_item_id uuid)
returns void language plpgsql security definer set search_path=public,app_private,pg_temp as $$
declare v_company uuid;
begin
  select company_id into v_company from public.engineering_catalog_items where id=p_item_id;
  if v_company is null then raise exception 'Built-in catalog items cannot be archived'; end if;
  if not app_private.has_company_permission(v_company,'catalog.manage') then raise exception 'Permission denied'; end if;
  update public.engineering_catalog_items set is_active=false,updated_at=now() where id=p_item_id and company_id=v_company;
end $$;

create or replace function public.create_engineering_drawing_v2(
  p_company_id uuid,p_project_id uuid,p_site_id uuid,p_cabinet_id uuid,p_folder_id uuid,p_drawing_no text,p_title text,
  p_discipline text default 'fiber',p_drawing_type text default 'secondary_network',p_snapshot jsonb default null,p_sheet_settings jsonb default null
) returns jsonb language plpgsql security definer set search_path=public,app_private,pg_temp as $$
declare v_drawing uuid;v_revision uuid;v_snapshot jsonb;v_settings jsonb;v_folder uuid:=p_folder_id;
begin
  if auth.uid() is null or not app_private.user_has_resource_permission(auth.uid(),p_company_id,'drawings.create',p_project_id,p_site_id,p_folder_id,null) then raise exception 'Permission denied'; end if;
  if not app_private.project_context_operational(p_project_id,p_site_id) then raise exception 'Project or site is archived'; end if;
  if p_cabinet_id is not null and not exists(select 1 from public.site_cabinets c where c.id=p_cabinet_id and c.company_id=p_company_id and c.project_id=p_project_id and c.site_id is not distinct from p_site_id and c.archived_at is null) then raise exception 'Cabinet scope is invalid'; end if;
  if v_folder is null then v_folder:=app_private.engineering_folder_for_scope(p_project_id,p_site_id,p_cabinet_id); end if;
  v_snapshot:=coalesce(p_snapshot,'{"version":1,"nodes":[],"routes":[],"annotations":[]}'::jsonb);
  v_settings:=coalesce(p_sheet_settings,jsonb_build_object('paper','A3','orientation','landscape','width',1600,'height',1000,'grid',20,'scale','NTS','titleBlock',true,'legend',true));
  insert into public.engineering_drawings(company_id,project_id,site_id,cabinet_id,folder_id,drawing_no,title,discipline,drawing_type,created_by,updated_by,last_change_at,last_changed_by,last_change_summary)
  values(p_company_id,p_project_id,p_site_id,p_cabinet_id,v_folder,trim(p_drawing_no),trim(p_title),coalesce(nullif(trim(p_discipline),''),'fiber'),coalesce(nullif(trim(p_drawing_type),''),'secondary_network'),auth.uid(),auth.uid(),now(),auth.uid(),jsonb_build_object('created',true)) returning id into v_drawing;
  insert into public.engineering_revisions(company_id,drawing_id,revision_number,revision_code,snapshot,sheet_settings,created_by,change_note,change_summary)
  values(p_company_id,v_drawing,1,'R0',v_snapshot,v_settings,auth.uid(),'Initial engineering draft',jsonb_build_object('created',true)) returning id into v_revision;
  update public.engineering_drawings set current_revision_id=v_revision where id=v_drawing;
  insert into public.engineering_revision_events(company_id,drawing_id,revision_id,actor_id,event_type,change_summary) values(p_company_id,v_drawing,v_revision,auth.uid(),'created',jsonb_build_object('created',true));
  insert into public.audit_events(company_id,actor_id,action,entity_type,entity_id,metadata) values(p_company_id,auth.uid(),'engineering.drawing_created','engineering_drawing',v_drawing,jsonb_build_object('drawing_no',trim(p_drawing_no),'revision_id',v_revision,'cabinet_id',p_cabinet_id));
  perform app_private.notify_company_members(p_company_id,auth.uid(),'engineering.drawing_created','تم إنشاء رسم هندسي جديد','New engineering drawing created',coalesce(trim(p_drawing_no),'')||' — '||coalesce(trim(p_title),''),coalesce(trim(p_drawing_no),'')||' — '||coalesce(trim(p_title),''),'engineering_drawing',v_drawing);
  return jsonb_build_object('drawing_id',v_drawing,'revision_id',v_revision,'folder_id',v_folder);
end $$;

create or replace function public.save_engineering_draft_v2(
  p_revision_id uuid,p_snapshot jsonb,p_sheet_settings jsonb,p_boq jsonb default '[]'::jsonb,p_change_note text default null,
  p_expected_lock_version integer default null,p_change_summary jsonb default '{}'::jsonb,p_notify boolean default true
) returns jsonb language plpgsql security definer set search_path=public,app_private,pg_temp as $$
declare r public.engineering_revisions%rowtype;d public.engineering_drawings%rowtype;v_new_lock integer;item jsonb;v_summary jsonb:=coalesce(p_change_summary,'{}'::jsonb);v_has_change boolean;
begin
  select * into r from public.engineering_revisions where id=p_revision_id for update;if not found then raise exception 'Revision not found'; end if;
  select * into d from public.engineering_drawings where id=r.drawing_id;
  if not app_private.user_has_resource_permission(auth.uid(),r.company_id,'drawings.edit',d.project_id,d.site_id,d.folder_id,d.id) then raise exception 'Permission denied'; end if;
  if not app_private.project_context_operational(d.project_id,d.site_id) then raise exception 'Project or site is archived'; end if;
  if r.status<>'draft' then raise exception 'Only draft revisions can be edited'; end if;
  if p_expected_lock_version is not null and r.lock_version<>p_expected_lock_version then raise exception 'Revision changed by another user'; end if;
  if jsonb_typeof(p_snapshot)<>'object' or jsonb_typeof(coalesce(p_sheet_settings,'{}'::jsonb))<>'object' or jsonb_typeof(coalesce(p_boq,'[]'::jsonb))<>'array' or jsonb_typeof(v_summary)<>'object' then raise exception 'Invalid engineering payload'; end if;
  v_has_change:=v_summary<>'{}'::jsonb;
  update public.engineering_revisions set snapshot=p_snapshot,sheet_settings=coalesce(p_sheet_settings,'{}'::jsonb),boq_snapshot=coalesce(p_boq,'[]'::jsonb),change_note=coalesce(nullif(trim(p_change_note),''),change_note),change_summary=v_summary,lock_version=lock_version+1 where id=p_revision_id returning lock_version into v_new_lock;
  delete from public.engineering_revision_boq where revision_id=p_revision_id;
  for item in select value from jsonb_array_elements(coalesce(p_boq,'[]'::jsonb)) loop
    insert into public.engineering_revision_boq(company_id,revision_id,item_code,category,description_ar,description_en,unit,quantity,source_kind,metadata)
    values(r.company_id,p_revision_id,coalesce(nullif(item->>'code',''),'CUSTOM'),coalesce(nullif(item->>'category',''),'other'),coalesce(nullif(item->>'description_ar',''),item->>'name_ar','بند هندسي'),coalesce(nullif(item->>'description_en',''),item->>'name_en','Engineering item'),coalesce(nullif(item->>'unit',''),'ea'),greatest(coalesce((item->>'quantity')::numeric,0),0),case when item->>'source_kind' in ('auto','manual','adjustment') then item->>'source_kind' else 'auto' end,coalesce(item->'metadata','{}'::jsonb))
    on conflict(revision_id,item_code,source_kind) do update set quantity=excluded.quantity,description_ar=excluded.description_ar,description_en=excluded.description_en,unit=excluded.unit,category=excluded.category,metadata=excluded.metadata;
  end loop;
  update public.engineering_drawings set updated_by=auth.uid(),current_revision_id=p_revision_id,status='draft',last_change_at=case when v_has_change then now() else last_change_at end,last_changed_by=case when v_has_change then auth.uid() else last_changed_by end,last_change_summary=case when v_has_change then v_summary else last_change_summary end where id=r.drawing_id;
  if v_has_change then
    insert into public.engineering_revision_events(company_id,drawing_id,revision_id,actor_id,event_type,change_summary) values(r.company_id,r.drawing_id,p_revision_id,auth.uid(),'saved',v_summary);
    insert into public.audit_events(company_id,actor_id,action,entity_type,entity_id,metadata) values(r.company_id,auth.uid(),'engineering.revision_saved','engineering_drawing',r.drawing_id,jsonb_build_object('revision_id',p_revision_id,'change_summary',v_summary));
    if p_notify then perform app_private.notify_company_members(r.company_id,auth.uid(),'engineering.drawing_updated','تم تعديل رسم هندسي','Engineering drawing updated',coalesce(d.drawing_no,'')||' — '||coalesce(d.title,''),coalesce(d.drawing_no,'')||' — '||coalesce(d.title,''),'engineering_drawing',r.drawing_id); end if;
  end if;
  return jsonb_build_object('revision_id',p_revision_id,'lock_version',v_new_lock,'saved_at',now(),'change_summary',v_summary);
end $$;

create or replace function public.mark_engineering_drawing_viewed(p_drawing_id uuid)
returns void language plpgsql security definer set search_path=public,app_private,pg_temp as $$
declare d public.engineering_drawings%rowtype;
begin
  select * into d from public.engineering_drawings where id=p_drawing_id;if not found or not app_private.can_view_engineering_drawing(p_drawing_id) then raise exception 'Permission denied';end if;
  insert into public.engineering_drawing_views(drawing_id,user_id,company_id,last_viewed_at) values(d.id,auth.uid(),d.company_id,now()) on conflict(drawing_id,user_id) do update set last_viewed_at=excluded.last_viewed_at;
end $$;

create or replace function public.begin_engineering_cde_sync(
  p_drawing_id uuid,p_revision_id uuid,p_original_filename text,p_mime_type text,p_size_bytes bigint,p_change_note text default null
) returns jsonb language plpgsql security definer set search_path=public,app_private,pg_temp as $$
declare d public.engineering_drawings%rowtype;r public.engineering_revisions%rowtype;v_doc uuid;v_ver uuid:=gen_random_uuid();v_number integer;v_path text;v_limit bigint;v_usage bigint;
begin
  select * into d from public.engineering_drawings where id=p_drawing_id for update;
  if not found or not app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.edit',d.project_id,d.site_id,d.folder_id,d.id) then raise exception 'Permission denied';end if;
  select * into r from public.engineering_revisions where id=p_revision_id and drawing_id=d.id;if not found then raise exception 'Revision not found';end if;
  if d.folder_id is null then d.folder_id:=app_private.engineering_folder_for_scope(d.project_id,d.site_id,d.cabinet_id); update public.engineering_drawings set folder_id=d.folder_id where id=d.id;end if;
  if d.folder_id is null then raise exception 'No CDE folder is available for this drawing';end if;
  if p_size_bytes<=0 or p_size_bytes>1073741824 then raise exception 'Invalid file size';end if;
  perform pg_advisory_xact_lock(hashtextextended(d.company_id::text,6810));
  select max_storage_bytes into v_limit from app_private.effective_company_limits(d.company_id);
  select coalesce(sum(size_bytes),0) into v_usage from public.document_versions where company_id=d.company_id and upload_state in('uploading','ready');
  if v_limit is not null and v_usage+p_size_bytes>v_limit then raise exception 'Storage limit reached';end if;
  v_doc:=d.cde_document_id;
  if v_doc is null then
    v_doc:=gen_random_uuid();v_number:=1;
    insert into public.documents(id,company_id,project_id,site_id,folder_id,display_name,document_type,description,tags,control_status,discipline,created_by,owner_user_id)
    values(v_doc,d.company_id,d.project_id,d.site_id,d.folder_id,coalesce(nullif(trim(d.drawing_no||' — '||d.title),''),d.title),'drawing','Canonical Engineering Studio drawing',['engineering',d.drawing_no,d.discipline],case when r.status='approved' then 'approved' else 'working' end,d.discipline,auth.uid(),auth.uid());
    update public.engineering_drawings set cde_document_id=v_doc where id=d.id;
    insert into public.engineering_document_links(company_id,drawing_id,revision_id,document_id,relation_type,created_by) values(d.company_id,d.id,r.id,v_doc,'export',auth.uid()) on conflict do nothing;
  else
    select coalesce(max(version_number),0)+1 into v_number from public.document_versions where document_id=v_doc;
  end if;
  v_path:=d.company_id::text||'/'||d.project_id::text||'/'||coalesce(d.site_id::text,'project')||'/'||v_doc::text||'/'||v_ver::text||'/'||app_private.safe_storage_filename(p_original_filename);
  insert into public.document_versions(id,company_id,document_id,version_number,version_label,revision_code,original_filename,storage_path,mime_type,size_bytes,change_note,uploaded_by)
  values(v_ver,d.company_id,v_doc,v_number,'v'||v_number,r.revision_code,p_original_filename,v_path,coalesce(nullif(p_mime_type,''),'image/svg+xml'),p_size_bytes,nullif(trim(p_change_note),''),auth.uid());
  return jsonb_build_object('document_id',v_doc,'version_id',v_ver,'version_number',v_number,'storage_bucket','company-files','storage_path',v_path,'created_document',d.cde_document_id is null);
end $$;

create or replace function public.set_engineering_cde_document(p_drawing_id uuid,p_document_id uuid)
returns void language plpgsql security definer set search_path=public,app_private,pg_temp as $$
declare d public.engineering_drawings%rowtype;doc public.documents%rowtype;
begin
  select * into d from public.engineering_drawings where id=p_drawing_id for update;if not found or not app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.edit',d.project_id,d.site_id,d.folder_id,d.id) then raise exception 'Permission denied';end if;
  select * into doc from public.documents where id=p_document_id and state='active';if not found or doc.company_id<>d.company_id or doc.project_id<>d.project_id or doc.site_id is distinct from d.site_id then raise exception 'Document scope mismatch';end if;
  update public.engineering_drawings set cde_document_id=p_document_id where id=d.id;
  insert into public.engineering_document_links(company_id,drawing_id,revision_id,document_id,relation_type,created_by) values(d.company_id,d.id,d.current_revision_id,p_document_id,'export',auth.uid()) on conflict do nothing;
end $$;

create or replace function public.link_engineering_revision_cde_version(p_revision_id uuid,p_version_id uuid)
returns void language plpgsql security definer set search_path=public,app_private,pg_temp as $$
declare r public.engineering_revisions%rowtype;d public.engineering_drawings%rowtype;v public.document_versions%rowtype;
begin
 select * into r from public.engineering_revisions where id=p_revision_id;select * into d from public.engineering_drawings where id=r.drawing_id;
 if d.id is null or not app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.edit',d.project_id,d.site_id,d.folder_id,d.id) then raise exception 'Permission denied';end if;
 select * into v from public.document_versions where id=p_version_id and upload_state='ready';if not found or d.cde_document_id is null or v.document_id<>d.cde_document_id then raise exception 'CDE version mismatch';end if;
 update public.engineering_revisions set cde_document_version_id=v.id where id=r.id;
 insert into public.engineering_revision_events(company_id,drawing_id,revision_id,actor_id,event_type,change_summary) values(d.company_id,d.id,r.id,auth.uid(),'cde_synced',jsonb_build_object('document_id',d.cde_document_id,'version_id',v.id));
end $$;

create or replace function public.create_engineering_task(
  p_drawing_id uuid,p_revision_id uuid,p_title text,p_description text default null,p_priority text default 'medium',p_due_at timestamptz default null,
  p_assignee_user_ids uuid[] default array[]::uuid[],p_target_kind text default 'sheet',p_target_id text default null,p_x numeric default null,p_y numeric default null
) returns uuid language plpgsql security definer set search_path=public,app_private,pg_temp as $$
declare d public.engineering_drawings%rowtype;v_task uuid;
begin
  select * into d from public.engineering_drawings where id=p_drawing_id;if not found or not app_private.can_view_engineering_drawing(p_drawing_id) then raise exception 'Permission denied';end if;
  v_task:=public.create_task(d.company_id,trim(p_title),nullif(trim(p_description),''),case when p_priority in('low','medium','high','urgent') then p_priority::public.task_priority else 'medium'::public.task_priority end,d.project_id,d.site_id,d.folder_id,d.cde_document_id,null,p_due_at,'company'::public.task_visibility,false,coalesce(p_assignee_user_ids,array[]::uuid[]),array[]::uuid[],'[]'::jsonb,null,1,null);
  update public.tasks set source_type='engineering_drawing',source_id=d.id where id=v_task;
  insert into public.engineering_task_links(company_id,drawing_id,revision_id,task_id,target_kind,target_id,x,y,created_by) values(d.company_id,d.id,p_revision_id,v_task,case when p_target_kind in('node','route','annotation','mark','sheet') then p_target_kind else 'sheet' end,p_target_id,p_x,p_y,auth.uid());
  insert into public.engineering_revision_events(company_id,drawing_id,revision_id,actor_id,event_type,change_summary) values(d.company_id,d.id,p_revision_id,auth.uid(),'issue_created',jsonb_build_object('task_id',v_task,'target_kind',p_target_kind,'target_id',p_target_id));
  return v_task;
end $$;

-- Additive Studio read models. Existing 6.9 directory / Drawing 360 RPCs remain intact for compatibility.
create or replace function public.engineering_studio_directory(p_company_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,app_private,pg_temp as $$
declare v_base jsonb;
begin
  if auth.uid() is null or not app_private.user_has_company_permission(auth.uid(),p_company_id,'drawings.view') then raise exception 'Permission denied'; end if;
  v_base:=public.engineering_directory_snapshot(p_company_id);
  return coalesce(v_base,'{}'::jsonb)||jsonb_build_object(
    'cabinets',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'project_id',c.project_id,'site_id',c.site_id,'code',c.code,'name',c.name,'status',c.status,'root_folder_id',c.root_folder_id,'archived_at',c.archived_at) order by c.name) from public.site_cabinets c where c.company_id=p_company_id and c.archived_at is null),'[]'::jsonb),
    'studio_drawings',coalesce((select jsonb_agg(to_jsonb(q) order by q.updated_at desc) from(
      select d.id,d.project_id,d.site_id,d.cabinet_id,d.folder_id,d.cde_document_id,d.last_change_at,d.last_change_summary,d.last_changed_by,d.updated_at,
        c.name cabinet_name,pr.full_name last_changed_by_name,coalesce(v.last_viewed_at,'epoch'::timestamptz) last_viewed_at,
        (d.last_change_at is not null and d.last_change_at>coalesce(v.last_viewed_at,'epoch'::timestamptz) and d.last_changed_by is distinct from auth.uid()) has_unseen_changes
      from public.engineering_drawings d
      left join public.site_cabinets c on c.id=d.cabinet_id
      left join public.profiles pr on pr.id=d.last_changed_by
      left join public.engineering_drawing_views v on v.drawing_id=d.id and v.user_id=auth.uid()
      where d.company_id=p_company_id and d.archived_at is null and app_private.user_has_resource_permission(auth.uid(),d.company_id,'drawings.view',d.project_id,d.site_id,d.folder_id,d.id)
    )q),'[]'::jsonb),
    'catalog_schema_version',2
  );
end $$;

create or replace function public.engineering_studio_context(p_drawing_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,app_private,pg_temp as $$
declare d public.engineering_drawings%rowtype;v_last_viewed timestamptz;
begin
  select * into d from public.engineering_drawings where id=p_drawing_id;
  if not found or not app_private.can_view_engineering_drawing(p_drawing_id) then raise exception 'Permission denied';end if;
  select last_viewed_at into v_last_viewed from public.engineering_drawing_views where drawing_id=d.id and user_id=auth.uid();
  return jsonb_build_object(
    'cabinet',(select jsonb_build_object('id',c.id,'code',c.code,'name',c.name,'status',c.status,'root_folder_id',c.root_folder_id) from public.site_cabinets c where c.id=d.cabinet_id),
    'cde_document',(select jsonb_build_object('id',doc.id,'display_name',doc.display_name,'control_status',doc.control_status,'current_version_id',doc.current_version_id,'version_count',doc.version_count) from public.documents doc where doc.id=d.cde_document_id),
    'task_links',coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'task_id',l.task_id,'revision_id',l.revision_id,'target_kind',l.target_kind,'target_id',l.target_id,'x',l.x,'y',l.y,'task',jsonb_build_object('title',t.title,'status',t.status,'priority',t.priority,'due_at',t.due_at)) order by l.created_at desc) from public.engineering_task_links l join public.tasks t on t.id=l.task_id where l.drawing_id=d.id and app_private.can_view_task(t.id)),'[]'::jsonb),
    'change_events',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'revision_id',e.revision_id,'event_type',e.event_type,'change_summary',e.change_summary,'created_at',e.created_at,'actor_id',e.actor_id,'actor_name',p.full_name) order by e.created_at desc) from (select * from public.engineering_revision_events where drawing_id=d.id order by created_at desc limit 100)e left join public.profiles p on p.id=e.actor_id),'[]'::jsonb),
    'last_viewed_at',v_last_viewed,
    'has_unseen_changes',(d.last_change_at is not null and d.last_change_at>coalesce(v_last_viewed,'epoch'::timestamptz) and d.last_changed_by is distinct from auth.uid()),
    'unseen_change_summary',case when d.last_change_at is not null and d.last_change_at>coalesce(v_last_viewed,'epoch'::timestamptz) and d.last_changed_by is distinct from auth.uid() then d.last_change_summary else '{}'::jsonb end,
    'last_changed_by_name',(select full_name from public.profiles where id=d.last_changed_by),
    'can_manage_catalog',app_private.has_company_permission(d.company_id,'catalog.manage'),
    'can_create_task',app_private.has_company_permission(d.company_id,'tasks.create')
  );
end $$;

revoke all on function public.upsert_engineering_catalog_item(uuid,uuid,text,text,text,text,text,text,text,text,text,jsonb,jsonb,integer) from public,anon;
grant execute on function public.upsert_engineering_catalog_item(uuid,uuid,text,text,text,text,text,text,text,text,text,jsonb,jsonb,integer) to authenticated;
revoke all on function public.archive_engineering_catalog_item(uuid) from public,anon; grant execute on function public.archive_engineering_catalog_item(uuid) to authenticated;
revoke all on function public.create_engineering_drawing_v2(uuid,uuid,uuid,uuid,uuid,text,text,text,text,jsonb,jsonb) from public,anon; grant execute on function public.create_engineering_drawing_v2(uuid,uuid,uuid,uuid,uuid,text,text,text,text,jsonb,jsonb) to authenticated;
revoke all on function public.save_engineering_draft_v2(uuid,jsonb,jsonb,jsonb,text,integer,jsonb,boolean) from public,anon; grant execute on function public.save_engineering_draft_v2(uuid,jsonb,jsonb,jsonb,text,integer,jsonb,boolean) to authenticated;
revoke all on function public.mark_engineering_drawing_viewed(uuid) from public,anon; grant execute on function public.mark_engineering_drawing_viewed(uuid) to authenticated;
revoke all on function public.begin_engineering_cde_sync(uuid,uuid,text,text,bigint,text) from public,anon; grant execute on function public.begin_engineering_cde_sync(uuid,uuid,text,text,bigint,text) to authenticated;
revoke all on function public.set_engineering_cde_document(uuid,uuid) from public,anon; grant execute on function public.set_engineering_cde_document(uuid,uuid) to authenticated;
revoke all on function public.link_engineering_revision_cde_version(uuid,uuid) from public,anon; grant execute on function public.link_engineering_revision_cde_version(uuid,uuid) to authenticated;
revoke all on function public.create_engineering_task(uuid,uuid,text,text,text,timestamptz,uuid[],text,text,numeric,numeric) from public,anon; grant execute on function public.create_engineering_task(uuid,uuid,text,text,text,timestamptz,uuid[],text,text,numeric,numeric) to authenticated;

revoke all on function public.engineering_studio_directory(uuid) from public,anon; grant execute on function public.engineering_studio_directory(uuid) to authenticated;
revoke all on function public.engineering_studio_context(uuid) from public,anon; grant execute on function public.engineering_studio_context(uuid) to authenticated;
