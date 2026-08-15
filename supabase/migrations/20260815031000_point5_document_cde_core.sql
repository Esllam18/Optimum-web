begin;

-- Point 5: Document & CDE Core
-- Adds admin-managed information architectures, richer document/version metadata,
-- generic document requirements, and complete read models for real preview/download.

alter table public.folder_templates
  add column if not exists template_kind text not null default 'general',
  add column if not exists is_builtin boolean not null default false,
  add column if not exists naming_rules jsonb not null default '{}'::jsonb,
  add column if not exists requirements jsonb not null default '[]'::jsonb;

alter table public.projects
  add column if not exists document_template_id uuid references public.folder_templates(id) on delete set null;

alter table public.folders
  add column if not exists hidden_at timestamptz,
  add column if not exists hidden_by uuid references public.profiles(id) on delete set null;

alter table public.documents
  add column if not exists document_date date,
  add column if not exists expires_at timestamptz,
  add column if not exists issuer text;

alter table public.document_versions
  add column if not exists revision_code text,
  add column if not exists restored_from_version_id uuid references public.document_versions(id) on delete set null;

create index if not exists projects_document_template_idx on public.projects(document_template_id) where document_template_id is not null;
create index if not exists folders_hidden_idx on public.folders(project_id,site_id,hidden_at) where hidden_at is not null;
create index if not exists documents_expiry_idx on public.documents(company_id,expires_at) where expires_at is not null and state='active';
create index if not exists document_versions_revision_idx on public.document_versions(document_id,revision_code) where revision_code is not null;
create index if not exists document_versions_restored_idx on public.document_versions(restored_from_version_id) where restored_from_version_id is not null;

-- ---------------------------------------------------------------------------
-- Generic document requirements / evidence foundation.
-- It deliberately references canonical CDE documents instead of copying files.
-- ---------------------------------------------------------------------------
create table if not exists public.document_requirements(
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  site_id uuid references public.sites(id) on delete cascade,
  cabinet_id uuid references public.site_cabinets(id) on delete cascade,
  requirement_key text not null,
  label_ar text not null,
  label_en text not null,
  document_type text,
  discipline text,
  min_items integer not null default 1 check(min_items >= 0),
  is_required boolean not null default true,
  sort_order integer not null default 0,
  source text not null default 'template',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.document_requirement_links(
  requirement_id uuid not null references public.document_requirements(id) on delete cascade,
  document_id uuid not null references public.documents(id) on delete cascade,
  linked_by uuid references public.profiles(id) on delete set null,
  linked_at timestamptz not null default now(),
  primary key(requirement_id,document_id)
);

create unique index if not exists document_requirements_scope_key_unique on public.document_requirements(
  project_id,
  coalesce(site_id,'00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(cabinet_id,'00000000-0000-0000-0000-000000000000'::uuid),
  lower(requirement_key)
);
create index if not exists document_requirement_links_document_idx on public.document_requirement_links(document_id);

alter table public.document_requirements enable row level security;
alter table public.document_requirement_links enable row level security;

drop policy if exists document_requirements_select on public.document_requirements;
create policy document_requirements_select on public.document_requirements for select to authenticated
using(app_private.user_has_resource_permission(auth.uid(),company_id,'files.view',project_id,site_id,null,null));

drop policy if exists document_requirement_links_select on public.document_requirement_links;
create policy document_requirement_links_select on public.document_requirement_links for select to authenticated
using(exists(
  select 1 from public.document_requirements r
  where r.id=requirement_id
    and app_private.user_has_resource_permission(auth.uid(),r.company_id,'files.view',r.project_id,r.site_id,null,null)
));

grant select on public.document_requirements,public.document_requirement_links to authenticated;

-- ---------------------------------------------------------------------------
-- Built-in information architecture templates.
-- Existing projects are never destructively rewritten. The templates are used
-- for new projects or explicitly applied in missing-only mode by an admin.
-- ---------------------------------------------------------------------------
do $$
declare t_eng uuid;t_tel uuid;t_con uuid;t_lean uuid;p uuid;
begin
  update public.folder_templates set is_default=false where company_id is null and is_default=true;

  select id into t_eng from public.folder_templates where company_id is null and name_en='Optimum Engineering Core' limit 1;
  if t_eng is null then
    insert into public.folder_templates(company_id,name_ar,name_en,description_ar,description_en,is_default,is_active,template_kind,is_builtin,naming_rules,requirements)
    values(null,'الهيكل الهندسي الأساسي','Optimum Engineering Core','هيكل مبسط للمشروعات الهندسية مع رسومات وشهادات ومستخلصات وتسليم.','A clean engineering structure for drawings, technical records, certificates, commercial records, and handover.',true,true,'engineering',true,
      '{"pattern":"{project}-{site}-{cabinet}-{discipline}-{type}-{revision}","enforce":false}'::jsonb,
      '[{"key":"as_built","label_ar":"رسومات As-Built","label_en":"As-Built Drawings","document_type":"drawing","discipline":"as-built","min_items":1,"required":true},{"key":"test_certificate","label_ar":"شهادة اختبار","label_en":"Test Certificate","document_type":"certificate","min_items":1,"required":true},{"key":"handover","label_ar":"محضر / شهادة تسليم","label_en":"Handover Record","document_type":"handover","min_items":1,"required":true}]'::jsonb)
    returning id into t_eng;

    insert into public.folder_template_nodes(template_id,code,name_ar,name_en,sort_order,is_system,allows_children) values
      (t_eng,'01','عام','General',10,true,true),
      (t_eng,'02','الرسومات','Drawings',20,true,true),
      (t_eng,'03','المستندات الفنية','Technical Documents',30,true,true),
      (t_eng,'04','الشهادات والفحوصات','Certificates & Inspections',40,true,true),
      (t_eng,'05','التجاري والمستخلصات','Commercial & Payment',50,true,true),
      (t_eng,'06','التسليم والأدلة','Handover & Evidence',60,true,true);
    select id into p from public.folder_template_nodes where template_id=t_eng and code='02';
    insert into public.folder_template_nodes(template_id,parent_id,code,name_ar,name_en,sort_order,is_system,allows_children) values
      (t_eng,p,'02.01','اسكتشات','Sketches',10,true,true),(t_eng,p,'02.02','تخطيط','Planning',20,true,true),
      (t_eng,p,'02.03','مدني','Civil',30,true,true),(t_eng,p,'02.04','كهرباء','Electrical',40,true,true),
      (t_eng,p,'02.05','مدني وكهرباء','Civil & Electrical',50,true,true),(t_eng,p,'02.06','As-Built','As-Built',60,true,true);
    select id into p from public.folder_template_nodes where template_id=t_eng and code='03';
    insert into public.folder_template_nodes(template_id,parent_id,code,name_ar,name_en,sort_order,is_system,allows_children) values
      (t_eng,p,'03.01','المواصفات','Specifications',10,true,true),(t_eng,p,'03.02','طرق التنفيذ','Method Statements',20,true,true),
      (t_eng,p,'03.03','اعتمادات المواد','Material Submittals',30,true,true),(t_eng,p,'03.04','الاستفسارات الفنية','RFIs',40,true,true);
    select id into p from public.folder_template_nodes where template_id=t_eng and code='04';
    insert into public.folder_template_nodes(template_id,parent_id,code,name_ar,name_en,sort_order,is_system,allows_children) values
      (t_eng,p,'04.01','شهادات الاختبار','Test Certificates',10,true,true),(t_eng,p,'04.02','طلبات الفحص','Inspection Requests',20,true,true),(t_eng,p,'04.03','شهادات ومحاضر التسليم','Handover Certificates',30,true,true);
    select id into p from public.folder_template_nodes where template_id=t_eng and code='05';
    insert into public.folder_template_nodes(template_id,parent_id,code,name_ar,name_en,sort_order,is_system,allows_children) values
      (t_eng,p,'05.01','الحصر والكميات','BOQ & Quantities',10,true,true),(t_eng,p,'05.02','المستخلصات','Payment Certificates',20,true,true),(t_eng,p,'05.03','العقود والتغييرات','Contracts & Variations',30,true,true);
    select id into p from public.folder_template_nodes where template_id=t_eng and code='06';
    insert into public.folder_template_nodes(template_id,parent_id,code,name_ar,name_en,sort_order,is_system,allows_children) values
      (t_eng,p,'06.01','الصور','Photos',10,true,true),(t_eng,p,'06.02','الاعتمادات','Approvals',20,true,true),(t_eng,p,'06.03','مستندات داعمة','Supporting Documents',30,true,true);
  else
    update public.folder_templates set is_default=true,is_active=true,is_builtin=true,template_kind='engineering' where id=t_eng;
  end if;

  select id into t_tel from public.folder_templates where company_id is null and name_en='Telecom / Fiber Delivery' limit 1;
  if t_tel is null then
    insert into public.folder_templates(company_id,name_ar,name_en,description_ar,description_en,is_active,template_kind,is_builtin,naming_rules,requirements)
    values(null,'تسليم الاتصالات والفايبر','Telecom / Fiber Delivery','هيكل للمشروعات التي تتدرج من المسح والتخطيط إلى المدني والفايبر والاختبارات والتسليم.','Telecom/fiber delivery from survey and planning through civil/fiber work, testing, as-built and handover.',true,'telecom',true,
      '{"pattern":"{project}-{site}-{cabinet}-{discipline}-{type}-{revision}","enforce":false}'::jsonb,
      '[{"key":"survey","label_ar":"مخرجات المسح","label_en":"Survey Evidence","document_type":"report","min_items":1,"required":true},{"key":"as_built","label_ar":"رسومات As-Built","label_en":"As-Built Drawings","document_type":"drawing","discipline":"as-built","min_items":1,"required":true},{"key":"test_result","label_ar":"نتيجة اختبار","label_en":"Test Result","document_type":"certificate","min_items":1,"required":true}]'::jsonb)
    returning id into t_tel;
    insert into public.folder_template_nodes(template_id,code,name_ar,name_en,sort_order,is_system,allows_children) values
      (t_tel,'01','عام','General',10,true,true),(t_tel,'02','المسح والتخطيط','Survey & Planning',20,true,true),(t_tel,'03','الرسومات','Drawings',30,true,true),(t_tel,'04','الأعمال المدنية','Civil Works',40,true,true),(t_tel,'05','الفايبر والاتصالات','Fiber & Telecom',50,true,true),(t_tel,'06','الطاقة والكهرباء','Power & Electrical',60,true,true),(t_tel,'07','الاختبارات والتشغيل','Testing & Commissioning',70,true,true),(t_tel,'08','As-Built والتسليم','As-Built & Handover',80,true,true),(t_tel,'09','المستخلص والأدلة','Claim & Evidence',90,true,true);
    select id into p from public.folder_template_nodes where template_id=t_tel and code='03';
    insert into public.folder_template_nodes(template_id,parent_id,code,name_ar,name_en,sort_order,is_system,allows_children) values
      (t_tel,p,'03.01','اسكتشات','Sketches',10,true,true),(t_tel,p,'03.02','تخطيط','Planning',20,true,true),(t_tel,p,'03.03','مدني','Civil',30,true,true),(t_tel,p,'03.04','كهرباء','Electrical',40,true,true),(t_tel,p,'03.05','مدني وكهرباء','Civil & Electrical',50,true,true),(t_tel,p,'03.06','As-Built','As-Built',60,true,true);
  end if;

  select id into t_con from public.folder_templates where company_id is null and name_en='Construction Control & Handover' limit 1;
  if t_con is null then
    insert into public.folder_templates(company_id,name_ar,name_en,description_ar,description_en,is_active,template_kind,is_builtin,naming_rules,requirements)
    values(null,'الإنشاءات والتسليم','Construction Control & Handover','هيكل لضبط الرسومات والـQA/QC والمواد والمستخلصات والتسليم.','Construction document control for drawings, QA/QC, material submittals, commercial records and handover.',true,'construction',true,
      '{"pattern":"{project}-{site}-{discipline}-{type}-{revision}","enforce":false}'::jsonb,
      '[{"key":"approved_drawing","label_ar":"رسم معتمد","label_en":"Approved Drawing","document_type":"drawing","min_items":1,"required":true},{"key":"inspection","label_ar":"سجل فحص","label_en":"Inspection Record","document_type":"certificate","min_items":1,"required":true},{"key":"handover","label_ar":"محضر تسليم","label_en":"Handover Record","document_type":"handover","min_items":1,"required":true}]'::jsonb)
    returning id into t_con;
    insert into public.folder_template_nodes(template_id,code,name_ar,name_en,sort_order,is_system,allows_children) values
      (t_con,'01','عام ومراسلات','General & Correspondence',10,true,true),(t_con,'02','الرسومات','Drawings',20,true,true),(t_con,'03','المواد والموردون','Materials & Submittals',30,true,true),(t_con,'04','QA/QC والفحوصات','QA/QC & Inspections',40,true,true),(t_con,'05','التجاري والمستخلصات','Commercial & Payment',50,true,true),(t_con,'06','التسليم وAs-Built','Handover & As-Built',60,true,true);
    select id into p from public.folder_template_nodes where template_id=t_con and code='02';
    insert into public.folder_template_nodes(template_id,parent_id,code,name_ar,name_en,sort_order,is_system,allows_children) values
      (t_con,p,'02.01','معماري','Architectural',10,true,true),(t_con,p,'02.02','مدني وإنشائي','Civil & Structural',20,true,true),(t_con,p,'02.03','MEP','MEP',30,true,true),(t_con,p,'02.04','Shop Drawings','Shop Drawings',40,true,true),(t_con,p,'02.05','As-Built','As-Built',50,true,true);
  end if;

  select id into t_lean from public.folder_templates where company_id is null and name_en='Lean Project Starter' limit 1;
  if t_lean is null then
    insert into public.folder_templates(company_id,name_ar,name_en,description_ar,description_en,is_active,template_kind,is_builtin,naming_rules,requirements)
    values(null,'بداية مشروع مبسطة','Lean Project Starter','أقل هيكل ممكن لفريق يريد البدء بسرعة ثم التوسع لاحقًا.','Minimal structure for teams that want to start quickly and expand later.',true,'lean',true,
      '{"pattern":"{project}-{type}-{revision}","enforce":false}'::jsonb,'[]'::jsonb)
    returning id into t_lean;
    insert into public.folder_template_nodes(template_id,code,name_ar,name_en,sort_order,is_system,allows_children) values
      (t_lean,'01','عام','General',10,true,true),(t_lean,'02','الرسومات','Drawings',20,true,true),(t_lean,'03','فني','Technical',30,true,true),(t_lean,'04','شهادات وفحوصات','Certificates & Inspections',40,true,true),(t_lean,'05','التسليم','Handover',50,true,true);
  end if;

  -- Project blueprints expose the new architectures during project creation.
  insert into public.project_blueprints(company_id,code,name_ar,name_en,description_ar,description_en,project_type,folder_template_id,defaults,naming_rules,is_active,is_default)
  values
    (null,'optimum-engineering-core','هندسي — Optimum Core','Engineering — Optimum Core','هيكل هندسي واضح وقابل للتوسع.','Clear extensible engineering structure.','engineering',t_eng,'{}'::jsonb,'{}'::jsonb,true,true),
    (null,'telecom-fiber-core','اتصالات وفايبر','Telecom / Fiber','هيكل تسليم اتصالات وفايبر.','Telecom/fiber delivery structure.','telecom',t_tel,'{}'::jsonb,'{}'::jsonb,true,false),
    (null,'construction-control-core','إنشاءات وتسليم','Construction & Handover','هيكل ضبط مستندات الإنشاء والتسليم.','Construction document-control structure.','construction',t_con,'{}'::jsonb,'{}'::jsonb,true,false),
    (null,'lean-project-starter','مشروع مبسط','Lean Project Starter','أبسط نقطة بداية.','Minimal project start.','general',t_lean,'{}'::jsonb,'{}'::jsonb,true,false)
  on conflict do nothing;
end $$;

-- ---------------------------------------------------------------------------
-- Admin folder-template catalog and builder.
-- ---------------------------------------------------------------------------
create or replace function public.folder_template_catalog(p_company_id uuid)
returns jsonb language plpgsql stable security definer set search_path='public','app_private','pg_temp'
as $$
begin
  if auth.uid() is null or not app_private.user_has_company_permission(auth.uid(),p_company_id,'files.view') then raise exception 'Permission denied'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',t.id,'company_id',t.company_id,'name_ar',t.name_ar,'name_en',t.name_en,
      'description_ar',t.description_ar,'description_en',t.description_en,'is_default',t.is_default,
      'is_active',t.is_active,'template_kind',t.template_kind,'is_builtin',t.is_builtin,
      'naming_rules',t.naming_rules,'requirements',t.requirements,
      'nodes',coalesce((select jsonb_agg(jsonb_build_object('id',n.id,'parent_id',n.parent_id,'code',n.code,'name_ar',n.name_ar,'name_en',n.name_en,'sort_order',n.sort_order,'allows_children',n.allows_children) order by n.sort_order,n.created_at) from public.folder_template_nodes n where n.template_id=t.id),'[]'::jsonb)
    ) order by (t.company_id is not null) desc,t.is_default desc,t.name_en)
    from public.folder_templates t
    where t.is_active and (t.company_id is null or t.company_id=p_company_id)
  ),'[]'::jsonb);
end $$;

create or replace function public.save_folder_template_v2(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare
  v_company uuid:=nullif(p_payload->>'company_id','')::uuid;
  v_id uuid:=nullif(p_payload->>'id','')::uuid;
  v_template public.folder_templates%rowtype;
  v_node jsonb;v_node_id uuid;v_parent_id uuid;v_key text;v_parent_key text;v_map jsonb:='{}'::jsonb;
begin
  if auth.uid() is null or v_company is null or not app_private.user_has_company_permission(auth.uid(),v_company,'files.manage') then raise exception 'Permission denied'; end if;
  if nullif(trim(p_payload->>'name_ar'),'') is null or nullif(trim(p_payload->>'name_en'),'') is null then raise exception 'Template name is required'; end if;
  if jsonb_array_length(coalesce(p_payload->'nodes','[]'::jsonb))=0 then raise exception 'At least one folder is required'; end if;

  if v_id is null then
    insert into public.folder_templates(company_id,name_ar,name_en,description_ar,description_en,is_default,is_active,template_kind,is_builtin,naming_rules,requirements,created_by)
    values(v_company,trim(p_payload->>'name_ar'),trim(p_payload->>'name_en'),nullif(trim(p_payload->>'description_ar'),''),nullif(trim(p_payload->>'description_en'),''),coalesce((p_payload->>'is_default')::boolean,false),true,coalesce(nullif(p_payload->>'template_kind',''),'custom'),false,coalesce(p_payload->'naming_rules','{}'::jsonb),coalesce(p_payload->'requirements','[]'::jsonb),auth.uid()) returning * into v_template;
  else
    select * into v_template from public.folder_templates where id=v_id and company_id=v_company for update;
    if not found then raise exception 'Only company templates can be edited'; end if;
    update public.folder_templates set name_ar=trim(p_payload->>'name_ar'),name_en=trim(p_payload->>'name_en'),description_ar=nullif(trim(p_payload->>'description_ar'),''),description_en=nullif(trim(p_payload->>'description_en'),''),is_default=coalesce((p_payload->>'is_default')::boolean,is_default),template_kind=coalesce(nullif(p_payload->>'template_kind',''),template_kind),naming_rules=coalesce(p_payload->'naming_rules',naming_rules),requirements=coalesce(p_payload->'requirements',requirements),updated_at=now() where id=v_template.id returning * into v_template;
    delete from public.folder_template_nodes where template_id=v_template.id;
  end if;

  if v_template.is_default then update public.folder_templates set is_default=false where company_id=v_company and id<>v_template.id; end if;

  for v_node in select value from jsonb_array_elements(p_payload->'nodes') loop
    v_key:=coalesce(nullif(v_node->>'key',''),gen_random_uuid()::text);
    v_parent_key:=nullif(v_node->>'parent_key','');
    v_parent_id:=null;
    if v_parent_key is not null then
      v_parent_id:=nullif(v_map->>v_parent_key,'')::uuid;
      if v_parent_id is null then raise exception 'Parent folder must appear before its child'; end if;
    end if;
    insert into public.folder_template_nodes(template_id,parent_id,code,name_ar,name_en,sort_order,is_system,allows_children)
    values(v_template.id,v_parent_id,nullif(trim(v_node->>'code'),''),trim(v_node->>'name_ar'),coalesce(nullif(trim(v_node->>'name_en'),''),trim(v_node->>'name_ar')),coalesce((v_node->>'sort_order')::int,0),true,true)
    returning id into v_node_id;
    v_map:=jsonb_set(v_map,array[v_key],to_jsonb(v_node_id::text),true);
  end loop;

  return jsonb_build_object('template',to_jsonb(v_template),'node_count',jsonb_array_length(p_payload->'nodes'));
end $$;

-- Missing-only application: never deletes or moves existing project files/folders.
create or replace function app_private.apply_folder_template_missing(p_project_id uuid,p_site_id uuid,p_template_id uuid)
returns integer language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare
  v_project public.projects%rowtype;v_site public.sites%rowtype;v_node public.folder_template_nodes%rowtype;
  v_parent_folder uuid;v_existing uuid;v_created integer:=0;
begin
  select * into v_project from public.projects where id=p_project_id;if not found then raise exception 'Project not found';end if;
  if p_site_id is not null then select * into v_site from public.sites where id=p_site_id and project_id=p_project_id;if not found then raise exception 'Site not found';end if;end if;
  if not exists(select 1 from public.folder_templates t where t.id=p_template_id and t.is_active and (t.company_id is null or t.company_id=v_project.company_id)) then raise exception 'Template not available';end if;

  for v_node in
    with recursive tree as(
      select n.*,0 lvl from public.folder_template_nodes n where n.template_id=p_template_id and n.parent_id is null
      union all
      select n.*,t.lvl+1 from public.folder_template_nodes n join tree t on n.parent_id=t.id
    ) select * from tree order by lvl,sort_order,id
  loop
    v_parent_folder:=null;
    if v_node.parent_id is not null then
      select f.id into v_parent_folder from public.folders f where f.project_id=p_project_id and f.site_id is not distinct from p_site_id and f.template_node_id=v_node.parent_id and f.trashed_at is null order by f.created_at limit 1;
    end if;
    select f.id into v_existing from public.folders f
      where f.project_id=p_project_id and f.site_id is not distinct from p_site_id and f.parent_id is not distinct from v_parent_folder and f.trashed_at is null
        and (f.template_node_id=v_node.id or (v_node.code is not null and lower(coalesce(f.code,''))=lower(v_node.code)) or lower(f.name)=lower(coalesce(v_node.name_en,v_node.name_ar)))
      order by (f.template_node_id=v_node.id) desc,f.created_at limit 1;
    if v_existing is null then
      insert into public.folders(company_id,project_id,site_id,parent_id,template_node_id,name,code,depth,sort_order,is_system,created_by)
      values(v_project.company_id,p_project_id,p_site_id,v_parent_folder,v_node.id,coalesce(nullif(trim(v_node.name_en),''),v_node.name_ar),v_node.code,case when v_parent_folder is null then 0 else coalesce((select depth+1 from public.folders where id=v_parent_folder),0) end,v_node.sort_order,true,auth.uid())
      returning id into v_existing;
      v_created:=v_created+1;
    elsif (select template_node_id from public.folders where id=v_existing) is null then
      update public.folders set template_node_id=v_node.id where id=v_existing;
    end if;
  end loop;
  return v_created;
end $$;

create or replace function app_private.apply_document_requirements_missing(p_project_id uuid,p_site_id uuid,p_template_id uuid)
returns integer language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare
  p public.projects%rowtype;v_req jsonb;v_created integer:=0;
begin
  select * into p from public.projects where id=p_project_id;if not found then raise exception 'Project not found';end if;
  if p_site_id is not null and not exists(select 1 from public.sites s where s.id=p_site_id and s.project_id=p.id) then raise exception 'Site not found';end if;
  if not exists(select 1 from public.folder_templates t where t.id=p_template_id and t.is_active and (t.company_id is null or t.company_id=p.company_id)) then raise exception 'Template not available';end if;
  for v_req in select value from jsonb_array_elements(coalesce((select requirements from public.folder_templates where id=p_template_id),'[]'::jsonb)) loop
    if nullif(trim(v_req->>'key'),'') is null then continue;end if;
    insert into public.document_requirements(company_id,project_id,site_id,cabinet_id,requirement_key,label_ar,label_en,document_type,discipline,min_items,is_required,sort_order,source,created_by)
    values(p.company_id,p.id,p_site_id,null,trim(v_req->>'key'),coalesce(nullif(trim(v_req->>'label_ar'),''),trim(v_req->>'key')),coalesce(nullif(trim(v_req->>'label_en'),''),trim(v_req->>'key')),nullif(trim(v_req->>'document_type'),''),nullif(trim(v_req->>'discipline'),''),greatest(0,coalesce((v_req->>'min_items')::int,1)),coalesce((v_req->>'required')::boolean,true),coalesce((v_req->>'sort_order')::int,0),'template',auth.uid())
    on conflict do nothing;
    if found then v_created:=v_created+1;end if;
  end loop;
  return v_created;
end $$;

create or replace function public.apply_folder_template(p_project_id uuid,p_site_id uuid,p_template_id uuid)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare p public.projects%rowtype;v_created integer;v_requirements integer;
begin
  if auth.uid() is null then raise exception 'Authentication required';end if;
  select * into p from public.projects where id=p_project_id;if not found then raise exception 'Project not found';end if;
  if p_site_id is not null and not exists(select 1 from public.sites s where s.id=p_site_id and s.project_id=p.id) then raise exception 'Site not found';end if;
  if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.manage',p.id,p_site_id,null,null) then raise exception 'Permission denied';end if;
  if not app_private.project_context_operational(p.id,p_site_id) then raise exception 'Project or site is archived';end if;
  v_created:=app_private.apply_folder_template_missing(p.id,p_site_id,p_template_id);
  v_requirements:=app_private.apply_document_requirements_missing(p.id,p_site_id,p_template_id);
  if p_site_id is null then update public.projects set document_template_id=p_template_id where id=p.id; end if;
  return jsonb_build_object('created_folders',v_created,'created_requirements',v_requirements,'template_id',p_template_id,'project_id',p.id,'site_id',p_site_id);
end $$;

-- New projects/sites inherit an explicitly selected document architecture first,
-- then the project blueprint, then company/global defaults.
create or replace function app_private.instantiate_default_folders(p_project_id uuid,p_site_id uuid default null)
returns void language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare v_company uuid;v_template uuid;v_blueprint uuid;begin
  select p.company_id,p.document_template_id,p.blueprint_id into v_company,v_template,v_blueprint from public.projects p where p.id=p_project_id;
  if v_company is null then return;end if;
  if v_template is null and v_blueprint is not null then select folder_template_id into v_template from public.project_blueprints where id=v_blueprint;end if;
  if v_template is null then select id into v_template from public.folder_templates where company_id=v_company and is_default and is_active order by created_at limit 1;end if;
  if v_template is null then select id into v_template from public.folder_templates where company_id is null and is_default and is_active order by created_at limit 1;end if;
  if v_template is null then return;end if;
  perform app_private.apply_folder_template_missing(p_project_id,p_site_id,v_template);
  perform app_private.apply_document_requirements_missing(p_project_id,p_site_id,v_template);
end $$;

-- Hide empty legacy/system branches without deleting history.
create or replace function public.set_folder_hidden(p_folder_id uuid,p_hidden boolean)
returns void language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare f public.folders%rowtype;v_docs integer;begin
  select * into f from public.folders where id=p_folder_id and trashed_at is null for update;if not found then raise exception 'Folder not found';end if;
  if not app_private.user_has_resource_permission(auth.uid(),f.company_id,'files.manage',f.project_id,f.site_id,f.id,null) then raise exception 'Permission denied';end if;
  if p_hidden then
    with recursive d as(select id from public.folders where id=f.id union all select x.id from public.folders x join d on x.parent_id=d.id where x.trashed_at is null)
    select count(*) into v_docs from public.documents where state='active' and folder_id in(select id from d);
    if v_docs>0 then raise exception 'Only empty folder branches can be hidden';end if;
    with recursive d as(select id from public.folders where id=f.id union all select x.id from public.folders x join d on x.parent_id=d.id where x.trashed_at is null)
    update public.folders set hidden_at=now(),hidden_by=auth.uid() where id in(select id from d);
  else
    with recursive d as(select id from public.folders where id=f.id union all select x.id from public.folders x join d on x.parent_id=d.id where x.trashed_at is null)
    update public.folders set hidden_at=null,hidden_by=null where id in(select id from d);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Rich upload/version metadata. Existing functions remain available for
-- backwards compatibility; Point 5 client uses the v2 contracts.
-- ---------------------------------------------------------------------------
create or replace function public.begin_document_upload_v2(
  p_folder_id uuid,p_display_name text,p_original_filename text,p_mime_type text,p_size_bytes bigint,
  p_document_type text default 'general',p_description text default null,p_tags text[] default array[]::text[],
  p_change_note text default null,p_discipline text default null,p_revision_code text default null,
  p_document_date date default null,p_expires_at timestamptz default null,p_issuer text default null
) returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare f public.folders%rowtype;v_doc uuid:=gen_random_uuid();v_ver uuid:=gen_random_uuid();v_limit bigint;v_usage bigint;v_path text;v_name text:=trim(coalesce(p_display_name,''));v_original text:=trim(coalesce(p_original_filename,''));begin
  if auth.uid() is null then raise exception 'Authentication required';end if;
  if char_length(v_name)<1 or char_length(v_name)>240 then raise exception 'Document name is required and must be 240 characters or fewer';end if;
  if char_length(v_original)<1 or char_length(v_original)>500 then raise exception 'Original filename is invalid';end if;
  select * into f from public.folders where id=p_folder_id and trashed_at is null and hidden_at is null;if not found then raise exception 'Folder not found';end if;
  if not app_private.project_context_operational(f.project_id,f.site_id) then raise exception 'Project or site is archived';end if;
  if not app_private.user_has_resource_permission(auth.uid(),f.company_id,'files.upload',f.project_id,f.site_id,f.id,null) then raise exception 'Permission denied';end if;
  if p_size_bytes<=0 or p_size_bytes>1073741824 then raise exception 'Invalid file size';end if;
  perform pg_advisory_xact_lock(hashtextextended(f.company_id::text,6810));
  select max_storage_bytes into v_limit from app_private.effective_company_limits(f.company_id);
  select coalesce(sum(size_bytes),0) into v_usage from public.document_versions where company_id=f.company_id and upload_state in('uploading','ready');
  if v_limit is not null and v_usage+p_size_bytes>v_limit then raise exception 'Storage limit reached';end if;
  v_path:=f.company_id::text||'/'||f.project_id::text||'/'||coalesce(f.site_id::text,'project')||'/'||v_doc::text||'/'||v_ver::text||'/'||app_private.safe_storage_filename(v_original);
  insert into public.documents(id,company_id,project_id,site_id,folder_id,display_name,document_type,description,tags,discipline,document_date,expires_at,issuer,created_by,owner_user_id)
  values(v_doc,f.company_id,f.project_id,f.site_id,f.id,v_name,coalesce(nullif(trim(p_document_type),''),'general'),nullif(trim(p_description),''),coalesce(p_tags,array[]::text[]),nullif(trim(p_discipline),''),p_document_date,p_expires_at,nullif(trim(p_issuer),''),auth.uid(),auth.uid());
  insert into public.document_versions(id,company_id,document_id,version_number,version_label,revision_code,original_filename,storage_path,mime_type,size_bytes,change_note,uploaded_by)
  values(v_ver,f.company_id,v_doc,1,'v1',nullif(trim(p_revision_code),''),v_original,v_path,coalesce(nullif(p_mime_type,''),'application/octet-stream'),p_size_bytes,nullif(trim(p_change_note),''),auth.uid());
  return jsonb_build_object('document_id',v_doc,'version_id',v_ver,'version_number',1,'storage_bucket','company-files','storage_path',v_path);
end $$;

create or replace function public.begin_new_version_upload_v2(
  p_document_id uuid,p_original_filename text,p_mime_type text,p_size_bytes bigint,p_change_note text default null,
  p_revision_code text default null,p_restored_from_version_id uuid default null
) returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare d public.documents%rowtype;v_ver uuid:=gen_random_uuid();v_number integer;v_limit bigint;v_usage bigint;v_path text;v_source public.document_versions%rowtype;v_original text:=trim(coalesce(p_original_filename,''));begin
  if auth.uid() is null then raise exception 'Authentication required';end if;
  if char_length(v_original)<1 or char_length(v_original)>500 then raise exception 'Original filename is invalid';end if;
  select * into d from public.documents where id=p_document_id and state='active' for update;if not found then raise exception 'Document not found';end if;
  if not app_private.project_context_operational(d.project_id,d.site_id) then raise exception 'Project or site is archived';end if;
  if not app_private.user_has_resource_permission(auth.uid(),d.company_id,'files.upload',d.project_id,d.site_id,d.folder_id,null) then raise exception 'Permission denied';end if;
  if not app_private.company_entitlement_enabled(d.company_id,'feature.file_versioning') then raise exception 'File versioning is not enabled for this company';end if;
  if p_size_bytes<=0 or p_size_bytes>1073741824 then raise exception 'Invalid file size';end if;
  if p_restored_from_version_id is not null then select * into v_source from public.document_versions where id=p_restored_from_version_id and document_id=d.id and upload_state='ready';if not found then raise exception 'Source version not found';end if;end if;
  perform pg_advisory_xact_lock(hashtextextended(d.company_id::text,6810));
  select max_storage_bytes into v_limit from app_private.effective_company_limits(d.company_id);
  select coalesce(sum(size_bytes),0) into v_usage from public.document_versions where company_id=d.company_id and upload_state in('uploading','ready');
  if v_limit is not null and v_usage+p_size_bytes>v_limit then raise exception 'Storage limit reached';end if;
  select coalesce(max(version_number),0)+1 into v_number from public.document_versions where document_id=d.id;
  v_path:=d.company_id::text||'/'||d.project_id::text||'/'||coalesce(d.site_id::text,'project')||'/'||d.id::text||'/'||v_ver::text||'/'||app_private.safe_storage_filename(v_original);
  insert into public.document_versions(id,company_id,document_id,version_number,version_label,revision_code,restored_from_version_id,original_filename,storage_path,mime_type,size_bytes,change_note,uploaded_by)
  values(v_ver,d.company_id,d.id,v_number,'v'||v_number,coalesce(nullif(trim(p_revision_code),''),v_source.revision_code),p_restored_from_version_id,v_original,v_path,coalesce(nullif(p_mime_type,''),'application/octet-stream'),p_size_bytes,nullif(trim(p_change_note),''),auth.uid());
  return jsonb_build_object('document_id',d.id,'version_id',v_ver,'version_number',v_number,'storage_bucket','company-files','storage_path',v_path);
end $$;

create or replace function public.update_document_metadata(p_document_id uuid,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare d public.documents%rowtype;begin
  select * into d from public.documents where id=p_document_id and state='active' for update;if not found then raise exception 'Document not found';end if;
  if not app_private.user_has_resource_permission(auth.uid(),d.company_id,'files.manage',d.project_id,d.site_id,d.folder_id,null) then raise exception 'Permission denied';end if;
  if not app_private.project_context_operational(d.project_id,d.site_id) then raise exception 'Project or site is archived';end if;
  update public.documents set
    document_type=coalesce(nullif(trim(p_payload->>'document_type'),''),document_type),
    discipline=nullif(trim(p_payload->>'discipline'),''),
    document_date=nullif(p_payload->>'document_date','')::date,
    expires_at=nullif(p_payload->>'expires_at','')::timestamptz,
    issuer=nullif(trim(p_payload->>'issuer'),''),
    system_code=case when p_payload ? 'system_code' then nullif(trim(p_payload->>'system_code'),'') else system_code end,
    description=case when p_payload ? 'description' then nullif(trim(p_payload->>'description'),'') else description end,
    tags=case when p_payload ? 'tags' then coalesce(array(select jsonb_array_elements_text(p_payload->'tags')),array[]::text[]) else tags end,
    owner_user_id=case when p_payload ? 'owner_user_id' then nullif(p_payload->>'owner_user_id','')::uuid else owner_user_id end
  where id=d.id returning * into d;
  return to_jsonb(d)-'search_vector';
end $$;

-- Complete directory: current version includes secure storage identity so real
-- open/download buttons can work without an extra hidden lookup.
-- PostgreSQL requires DROP when the TABLE return shape changes for the same signature.
drop function if exists public.document_directory_query(uuid,integer);
create function public.document_directory_query(p_company_id uuid,p_limit integer default 1200)
returns table(
  id uuid,company_id uuid,project_id uuid,site_id uuid,folder_id uuid,display_name text,system_code text,document_type text,description text,tags text[],state public.document_state,current_version_id uuid,version_count integer,created_by uuid,created_at timestamptz,updated_at timestamptz,control_status text,discipline text,owner_user_id uuid,review_due_at timestamptz,approved_at timestamptz,approved_by uuid,document_date date,expires_at timestamptz,issuer text,
  version_number integer,version_label text,revision_code text,original_filename text,storage_bucket text,storage_path text,mime_type text,size_bytes bigint,upload_state public.upload_state,change_note text,uploaded_by uuid,uploader_name text,finalized_at timestamptz
)
language sql stable security definer set search_path='public','app_private','pg_temp'
as $$
  select d.id,d.company_id,d.project_id,d.site_id,d.folder_id,d.display_name,d.system_code,d.document_type,d.description,d.tags,d.state,d.current_version_id,d.version_count,d.created_by,d.created_at,d.updated_at,d.control_status,d.discipline,d.owner_user_id,d.review_due_at,d.approved_at,d.approved_by,d.document_date,d.expires_at,d.issuer,
    v.version_number,v.version_label,v.revision_code,v.original_filename,v.storage_bucket,v.storage_path,v.mime_type,v.size_bytes,v.upload_state,v.change_note,v.uploaded_by,p.full_name,v.finalized_at
  from public.documents d
  left join public.document_versions v on v.id=d.current_version_id
  left join public.profiles p on p.id=v.uploaded_by
  join public.folders f on f.id=d.folder_id
  where d.company_id=p_company_id and d.state='active' and f.hidden_at is null
    and app_private.user_has_resource_permission(auth.uid(),p_company_id,'files.view',d.project_id,d.site_id,d.folder_id,null)
  order by d.updated_at desc
  limit greatest(1,least(coalesce(p_limit,1200),2500));
$$;

-- Rich Document 360 with real storage paths on every historical version.
create or replace function public.document_360(p_document_id uuid)
returns jsonb language plpgsql stable security definer set search_path='public','app_private','pg_temp'
as $$
declare d public.documents%rowtype;v_cab uuid;v_operational boolean;begin
  select * into d from public.documents where id=p_document_id;
  if not found or not app_private.user_has_resource_permission(auth.uid(),d.company_id,'files.view',d.project_id,d.site_id,d.folder_id,null) then raise exception 'Permission denied';end if;
  v_cab:=app_private.cabinet_for_folder(d.folder_id);v_operational:=app_private.project_context_operational(d.project_id,d.site_id);
  return jsonb_build_object(
    'document',to_jsonb(d)-'search_vector',
    'project',(select jsonb_build_object('id',p.id,'code',p.code,'name',p.name,'status',p.status,'archived_at',p.archived_at,'document_template_id',p.document_template_id) from public.projects p where p.id=d.project_id),
    'site',(select jsonb_build_object('id',s.id,'code',s.code,'name',s.name,'status',s.status,'archived_at',s.archived_at) from public.sites s where s.id=d.site_id),
    'folder',(select jsonb_build_object('id',f.id,'name',f.name,'code',f.code) from public.folders f where f.id=d.folder_id),
    'cabinet',(select jsonb_build_object('id',c.id,'code',c.code,'name',c.name,'status',c.status) from public.site_cabinets c where c.id=v_cab),
    'owner_name',(select full_name from public.profiles where id=d.owner_user_id),
    'versions',coalesce((select jsonb_agg(jsonb_build_object('id',v.id,'version_number',v.version_number,'version_label',v.version_label,'revision_code',v.revision_code,'restored_from_version_id',v.restored_from_version_id,'original_filename',v.original_filename,'storage_bucket',v.storage_bucket,'storage_path',v.storage_path,'mime_type',v.mime_type,'size_bytes',v.size_bytes,'checksum_sha256',v.checksum_sha256,'upload_state',v.upload_state,'change_note',v.change_note,'uploaded_by',v.uploaded_by,'uploader_name',p.full_name,'created_at',v.created_at,'finalized_at',v.finalized_at) order by v.version_number desc) from public.document_versions v left join public.profiles p on p.id=v.uploaded_by where v.document_id=d.id),'[]'::jsonb),
    'linked_tasks',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'task_number',t.task_number,'title',t.title,'status',t.status,'priority',t.priority,'due_at',t.due_at)) from public.tasks t where t.document_id=d.id and app_private.can_view_task(t.id)),'[]'::jsonb),
    'linked_drawings',coalesce((select jsonb_agg(jsonb_build_object('id',ed.id,'drawing_no',ed.drawing_no,'title',ed.title,'revision_id',l.revision_id,'relation_type',l.relation_type)) from public.engineering_document_links l join public.engineering_drawings ed on ed.id=l.drawing_id where l.document_id=d.id and app_private.can_view_engineering_drawing(ed.id)),'[]'::jsonb),
    'claim_links',coalesce((select jsonb_agg(jsonb_build_object('item_id',i.id,'package_id',p.id,'package_no',p.package_no,'package_status',p.status,'requirement_id',r.id,'requirement_key',r.requirement_key,'label_ar',r.label_ar,'label_en',r.label_en,'selected_version_id',i.selected_version_id,'cabinet_id',i.cabinet_id)) from public.site_claim_items i join public.site_claim_packages p on p.id=i.package_id join public.site_claim_requirements r on r.id=i.requirement_id where i.document_id=d.id),'[]'::jsonb),
    'requirement_links',coalesce((select jsonb_agg(jsonb_build_object('requirement_id',r.id,'requirement_key',r.requirement_key,'label_ar',r.label_ar,'label_en',r.label_en,'is_required',r.is_required)) from public.document_requirement_links l join public.document_requirements r on r.id=l.requirement_id where l.document_id=d.id),'[]'::jsonb),
    'recent_activity',case when app_private.user_has_company_permission(auth.uid(),d.company_id,'audit.view') then coalesce((select jsonb_agg(x order by x.created_at desc) from(select a.id,a.action,a.actor_id,a.metadata,a.created_at from public.audit_events a where a.company_id=d.company_id and(a.entity_id=d.id or a.metadata#>>'{after,document_id}'=d.id::text) order by a.created_at desc limit 30)x),'[]'::jsonb) else '[]'::jsonb end,
    'context_read_only',not v_operational,
    'can_manage',v_operational and app_private.user_has_resource_permission(auth.uid(),d.company_id,'files.manage',d.project_id,d.site_id,d.folder_id,null),
    'can_download',app_private.user_has_resource_permission(auth.uid(),d.company_id,'files.download',d.project_id,d.site_id,d.folder_id,null),
    'can_upload',v_operational and app_private.user_has_resource_permission(auth.uid(),d.company_id,'files.upload',d.project_id,d.site_id,d.folder_id,null),
    'can_rename',v_operational and app_private.user_has_resource_permission(auth.uid(),d.company_id,'files.rename',d.project_id,d.site_id,d.folder_id,null),
    'can_move',v_operational and app_private.user_has_resource_permission(auth.uid(),d.company_id,'files.move',d.project_id,d.site_id,d.folder_id,null),
    'can_archive',v_operational and app_private.user_has_resource_permission(auth.uid(),d.company_id,'files.archive',d.project_id,d.site_id,d.folder_id,null)
  );
end $$;

create or replace function public.document_requirements_snapshot(p_project_id uuid,p_site_id uuid default null,p_cabinet_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='public','app_private','pg_temp'
as $$
declare p public.projects%rowtype;begin
  select * into p from public.projects where id=p_project_id;if not found then raise exception 'Project not found';end if;
  if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.view',p.id,p_site_id,null,null) then raise exception 'Permission denied';end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
    'id',r.id,'requirement_key',r.requirement_key,'label_ar',r.label_ar,'label_en',r.label_en,'document_type',r.document_type,'discipline',r.discipline,'min_items',r.min_items,'is_required',r.is_required,'sort_order',r.sort_order,
    'linked_count',(select count(*) from public.document_requirement_links l join public.documents d on d.id=l.document_id where l.requirement_id=r.id and d.state='active' and d.current_version_id is not null),
    'ready_count',(select count(*) from public.document_requirement_links l join public.documents d on d.id=l.document_id join public.document_versions v on v.id=d.current_version_id where l.requirement_id=r.id and d.state='active' and v.upload_state='ready')
  ) order by r.sort_order,r.created_at) from public.document_requirements r where r.project_id=p.id and r.site_id is not distinct from p_site_id and r.cabinet_id is not distinct from p_cabinet_id),'[]'::jsonb);
end $$;

create or replace function public.link_document_requirement(p_requirement_id uuid,p_document_id uuid)
returns void language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare r public.document_requirements%rowtype;d public.documents%rowtype;begin
  select * into r from public.document_requirements where id=p_requirement_id;if not found then raise exception 'Requirement not found';end if;
  select * into d from public.documents where id=p_document_id and state='active';if not found or d.company_id<>r.company_id or d.project_id<>r.project_id then raise exception 'Document not available';end if;
  if r.site_id is not null and d.site_id is distinct from r.site_id then raise exception 'Document is outside requirement scope';end if;
  if not app_private.user_has_resource_permission(auth.uid(),r.company_id,'files.manage',r.project_id,r.site_id,d.folder_id,null) then raise exception 'Permission denied';end if;
  insert into public.document_requirement_links(requirement_id,document_id,linked_by) values(r.id,d.id,auth.uid()) on conflict do nothing;
end $$;

-- Execute privileges
revoke all on function public.folder_template_catalog(uuid) from public,anon;
revoke all on function public.save_folder_template_v2(jsonb) from public,anon;
revoke all on function public.apply_folder_template(uuid,uuid,uuid) from public,anon;
revoke all on function public.set_folder_hidden(uuid,boolean) from public,anon;
revoke all on function public.begin_document_upload_v2(uuid,text,text,text,bigint,text,text,text[],text,text,text,date,timestamptz,text) from public,anon;
revoke all on function public.begin_new_version_upload_v2(uuid,text,text,bigint,text,text,uuid) from public,anon;
revoke all on function public.update_document_metadata(uuid,jsonb) from public,anon;
revoke all on function public.document_directory_query(uuid,integer) from public,anon;
revoke all on function public.document_360(uuid) from public,anon;
revoke all on function public.document_requirements_snapshot(uuid,uuid,uuid) from public,anon;
revoke all on function public.link_document_requirement(uuid,uuid) from public,anon;

grant execute on function public.folder_template_catalog(uuid) to authenticated;
grant execute on function public.save_folder_template_v2(jsonb) to authenticated;
grant execute on function public.apply_folder_template(uuid,uuid,uuid) to authenticated;
grant execute on function public.set_folder_hidden(uuid,boolean) to authenticated;
grant execute on function public.begin_document_upload_v2(uuid,text,text,text,bigint,text,text,text[],text,text,text,date,timestamptz,text) to authenticated;
grant execute on function public.begin_new_version_upload_v2(uuid,text,text,bigint,text,text,uuid) to authenticated;
grant execute on function public.update_document_metadata(uuid,jsonb) to authenticated;
grant execute on function public.document_directory_query(uuid,integer) to authenticated;
grant execute on function public.document_360(uuid) to authenticated;
grant execute on function public.document_requirements_snapshot(uuid,uuid,uuid) to authenticated;
grant execute on function public.link_document_requirement(uuid,uuid) to authenticated;

commit;
