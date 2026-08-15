begin;

-- Point 10 — Site Execution & Daily Progress
-- Field execution remains linked to canonical Projects/Sites/Cabinets, Tasks, CDE and Engineering.
-- These tables store field-specific observations/workflow only; they do not duplicate source documents/drawings/tasks.

create table if not exists public.site_daily_logs(
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  site_id uuid not null references public.sites(id) on delete cascade,
  log_date date not null,
  status text not null default 'draft' check(status in('draft','submitted','approved','returned')),
  summary text,
  work_completed text,
  tomorrow_plan text,
  safety_note text,
  weather_note text,
  manpower jsonb not null default '{}'::jsonb,
  equipment jsonb not null default '[]'::jsonb,
  reviewer_note text,
  submitted_at timestamptz,
  submitted_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null,
  report_document_id uuid references public.documents(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  unique(company_id,site_id,log_date)
);
create index if not exists site_daily_logs_site_date_idx on public.site_daily_logs(site_id,log_date desc);
create index if not exists site_daily_logs_company_status_idx on public.site_daily_logs(company_id,status,log_date desc);

create table if not exists public.site_inspection_templates(
  id uuid primary key default gen_random_uuid(),
  company_id uuid references public.companies(id) on delete cascade,
  code text not null,
  name_ar text not null,
  name_en text not null,
  description_ar text,
  description_en text,
  applies_to text not null default 'site' check(applies_to in('site','cabinet','drawing','task')),
  items jsonb not null default '[]'::jsonb,
  is_active boolean not null default true,
  is_default boolean not null default false,
  sort_order integer not null default 100,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique nulls not distinct(company_id,code)
);

create table if not exists public.site_inspections(
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  site_id uuid not null references public.sites(id) on delete cascade,
  cabinet_id uuid references public.site_cabinets(id) on delete set null,
  drawing_id uuid references public.engineering_drawings(id) on delete set null,
  task_id uuid references public.tasks(id) on delete set null,
  template_id uuid references public.site_inspection_templates(id) on delete set null,
  title text not null,
  status text not null default 'in_progress' check(status in('in_progress','passed','failed','needs_review','closed')),
  overall_note text,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);
create index if not exists site_inspections_site_idx on public.site_inspections(site_id,created_at desc);
create index if not exists site_inspections_cabinet_idx on public.site_inspections(cabinet_id,created_at desc) where cabinet_id is not null;

create table if not exists public.site_inspection_items(
  id uuid primary key default gen_random_uuid(),
  inspection_id uuid not null references public.site_inspections(id) on delete cascade,
  item_key text not null,
  label_ar text not null,
  label_en text not null,
  result text not null default 'pending' check(result in('pending','pass','fail','na')),
  note text,
  evidence_document_id uuid references public.documents(id) on delete set null,
  sort_order integer not null default 100,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  unique(inspection_id,item_key)
);

create table if not exists public.site_field_issues(
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  site_id uuid not null references public.sites(id) on delete cascade,
  cabinet_id uuid references public.site_cabinets(id) on delete set null,
  drawing_id uuid references public.engineering_drawings(id) on delete set null,
  task_id uuid references public.tasks(id) on delete set null,
  document_id uuid references public.documents(id) on delete set null,
  title text not null,
  description text,
  severity text not null default 'medium' check(severity in('low','medium','high','critical')),
  status text not null default 'open' check(status in('open','in_progress','ready_for_review','closed','cancelled')),
  assigned_to uuid references auth.users(id) on delete set null,
  due_at timestamptz,
  location_note text,
  resolution_note text,
  closed_at timestamptz,
  closed_by uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);
create index if not exists site_field_issues_site_status_idx on public.site_field_issues(site_id,status,severity,created_at desc);

create table if not exists public.site_constraints(
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  site_id uuid not null references public.sites(id) on delete cascade,
  cabinet_id uuid references public.site_cabinets(id) on delete set null,
  task_id uuid references public.tasks(id) on delete set null,
  constraint_type text not null check(constraint_type in('material','permit','client','design','access','weather','technical','resource','other')),
  title text not null,
  description text,
  impact text,
  status text not null default 'open' check(status in('open','mitigating','resolved','cancelled')),
  owner_user_id uuid references auth.users(id) on delete set null,
  started_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolution_note text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);
create index if not exists site_constraints_site_status_idx on public.site_constraints(site_id,status,started_at desc);

create table if not exists public.site_daily_log_events(
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  log_id uuid not null references public.site_daily_logs(id) on delete cascade,
  event_type text not null,
  actor_id uuid references auth.users(id) on delete set null,
  note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists site_daily_log_events_log_idx on public.site_daily_log_events(log_id,created_at desc);

-- Seed concise built-in inspection templates. Company-specific copies can be added later.
insert into public.site_inspection_templates(company_id,code,name_ar,name_en,description_ar,description_en,applies_to,items,is_default,sort_order)
values
(null,'cabinet-readiness','فحص جاهزية الكابينة','Cabinet Readiness','فحص سريع قبل إغلاق أعمال الكابينة.','Fast field check before cabinet closeout.','cabinet',
 '[{"key":"physical","label_ar":"التركيب والحالة الفيزيائية","label_en":"Physical installation","required":true},{"key":"labeling","label_ar":"الترقيم والملصقات","label_en":"Labels and identification","required":true},{"key":"connections","label_ar":"التوصيلات والربط","label_en":"Connections","required":true},{"key":"drawing","label_ar":"مطابقة الرسم/As-Built","label_en":"Drawing / As-Built match","required":true},{"key":"evidence","label_ar":"الصور والأدلة المطلوبة","label_en":"Required photo evidence","required":true}]'::jsonb,true,10),
(null,'route-quality','فحص جودة المسار','Route Quality','فحص التنفيذ والمسار قبل الإغلاق.','Field quality check for route execution.','site',
 '[{"key":"alignment","label_ar":"المسار والتنفيذ مطابقان","label_en":"Route alignment matches","required":true},{"key":"depth","label_ar":"الأبعاد/العمق مناسب","label_en":"Depth / dimensions acceptable","required":true},{"key":"protection","label_ar":"الحماية والإغلاق","label_en":"Protection and closure","required":true},{"key":"labels","label_ar":"الترقيم والتعريف","label_en":"Labels and identification","required":true},{"key":"evidence","label_ar":"تم توثيق الحالة بالصور","label_en":"Photo evidence captured","required":true}]'::jsonb,true,20),
(null,'handover-readiness','فحص جاهزية التسليم','Handover Readiness','تأكد من اكتمال الأعمال والأدلة قبل التسليم.','Confirm field work and evidence before handover.','site',
 '[{"key":"tasks","label_ar":"المهام الميدانية مقفلة","label_en":"Field tasks closed","required":true},{"key":"issues","label_ar":"لا توجد مشاكل حرجة مفتوحة","label_en":"No critical open issues","required":true},{"key":"drawings","label_ar":"الرسم الحالي محفوظ ومحدث","label_en":"Current drawing saved and current","required":true},{"key":"evidence","label_ar":"الأدلة المطلوبة مكتملة","label_en":"Required evidence complete","required":true},{"key":"cleanup","label_ar":"تنظيف وتجهيز الموقع","label_en":"Site cleanup and readiness","required":true}]'::jsonb,true,30)
on conflict(company_id,code) do update set name_ar=excluded.name_ar,name_en=excluded.name_en,description_ar=excluded.description_ar,description_en=excluded.description_en,items=excluded.items,is_active=true,is_default=excluded.is_default,sort_order=excluded.sort_order,updated_at=now();

-- RLS
alter table public.site_daily_logs enable row level security;
alter table public.site_inspection_templates enable row level security;
alter table public.site_inspections enable row level security;
alter table public.site_inspection_items enable row level security;
alter table public.site_field_issues enable row level security;
alter table public.site_constraints enable row level security;
alter table public.site_daily_log_events enable row level security;

create policy site_daily_logs_select on public.site_daily_logs for select to authenticated using(
  app_private.user_has_resource_permission(auth.uid(),company_id,'projects.view',project_id,site_id,null,null)
);
create policy site_inspection_templates_select on public.site_inspection_templates for select to authenticated using(
  company_id is null or app_private.is_company_member(company_id)
);
create policy site_inspections_select on public.site_inspections for select to authenticated using(
  app_private.user_has_resource_permission(auth.uid(),company_id,'projects.view',project_id,site_id,null,null)
);
create policy site_inspection_items_select on public.site_inspection_items for select to authenticated using(
  exists(select 1 from public.site_inspections i where i.id=inspection_id and app_private.user_has_resource_permission(auth.uid(),i.company_id,'projects.view',i.project_id,i.site_id,null,null))
);
create policy site_field_issues_select on public.site_field_issues for select to authenticated using(
  app_private.user_has_resource_permission(auth.uid(),company_id,'projects.view',project_id,site_id,null,null)
);
create policy site_constraints_select on public.site_constraints for select to authenticated using(
  app_private.user_has_resource_permission(auth.uid(),company_id,'projects.view',project_id,site_id,null,null)
);
create policy site_daily_log_events_select on public.site_daily_log_events for select to authenticated using(
  exists(select 1 from public.site_daily_logs l where l.id=log_id and app_private.user_has_resource_permission(auth.uid(),l.company_id,'projects.view',l.project_id,l.site_id,null,null))
);

revoke all on public.site_daily_logs,public.site_inspection_templates,public.site_inspections,public.site_inspection_items,public.site_field_issues,public.site_constraints,public.site_daily_log_events from anon,authenticated;
grant select on public.site_daily_logs,public.site_inspection_templates,public.site_inspections,public.site_inspection_items,public.site_field_issues,public.site_constraints,public.site_daily_log_events to authenticated;
grant all on public.site_daily_logs,public.site_inspection_templates,public.site_inspections,public.site_inspection_items,public.site_field_issues,public.site_constraints,public.site_daily_log_events to service_role;

-- Helpers
create or replace function app_private.site_execution_can_edit(p_company uuid,p_project uuid,p_site uuid)
returns boolean language sql stable security definer set search_path='public','app_private','pg_temp' as $$
  select auth.uid() is not null and app_private.user_has_resource_permission(auth.uid(),p_company,'tasks.edit',p_project,p_site,null,null)
$$;
revoke all on function app_private.site_execution_can_edit(uuid,uuid,uuid) from public,anon,authenticated;

create or replace function app_private.record_site_daily_event(p_log uuid,p_type text,p_note text default null,p_metadata jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare l public.site_daily_logs%rowtype; v_id uuid;
begin
  select * into l from public.site_daily_logs where id=p_log;
  if not found then raise exception 'Daily log not found'; end if;
  insert into public.site_daily_log_events(company_id,log_id,event_type,actor_id,note,metadata)
  values(l.company_id,l.id,p_type,auth.uid(),nullif(trim(p_note),''),coalesce(p_metadata,'{}'::jsonb)) returning id into v_id;
  return v_id;
end $$;
revoke all on function app_private.record_site_daily_event(uuid,text,text,jsonb) from public,anon,authenticated;

create or replace function app_private.resolve_site_report_folder(p_project uuid,p_site uuid)
returns uuid language sql stable security definer set search_path='public','pg_temp' as $$
  select f.id from public.folders f
  where f.project_id=p_project and f.site_id is not distinct from p_site and f.trashed_at is null and f.hidden_at is null
  order by
    case when lower(coalesce(f.code,'')) in ('01','06.03') then 0
         when lower(coalesce(f.name,'')) ~ 'report|daily|site|عام|تقارير|موقع' then 1
         else 10 end,
    f.sort_order,f.created_at
  limit 1
$$;
revoke all on function app_private.resolve_site_report_folder(uuid,uuid) from public,anon,authenticated;

-- Ensure/open daily log.
create or replace function public.ensure_site_daily_log(p_company_id uuid,p_site_id uuid,p_log_date date default current_date)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare s public.sites%rowtype; l public.site_daily_logs%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into s from public.sites where id=p_site_id and company_id=p_company_id and archived_at is null;
  if not found then raise exception 'Site not found'; end if;
  if not app_private.user_has_resource_permission(auth.uid(),p_company_id,'projects.view',s.project_id,s.id,null,null) then raise exception 'Permission denied'; end if;
  insert into public.site_daily_logs(company_id,project_id,site_id,log_date,created_by,updated_by)
  values(p_company_id,s.project_id,s.id,coalesce(p_log_date,current_date),auth.uid(),auth.uid())
  on conflict(company_id,site_id,log_date) do nothing;
  select * into l from public.site_daily_logs where company_id=p_company_id and site_id=s.id and log_date=coalesce(p_log_date,current_date);
  return to_jsonb(l);
end $$;

create or replace function public.save_site_daily_log(p_log_id uuid,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare l public.site_daily_logs%rowtype;
begin
  select * into l from public.site_daily_logs where id=p_log_id for update; if not found then raise exception 'Daily log not found'; end if;
  if not app_private.site_execution_can_edit(l.company_id,l.project_id,l.site_id) then raise exception 'Permission denied'; end if;
  if l.status='approved' then raise exception 'Approved daily report is read-only'; end if;
  update public.site_daily_logs set
    summary=case when p_payload?'summary' then nullif(trim(p_payload->>'summary'),'') else summary end,
    work_completed=case when p_payload?'work_completed' then nullif(trim(p_payload->>'work_completed'),'') else work_completed end,
    tomorrow_plan=case when p_payload?'tomorrow_plan' then nullif(trim(p_payload->>'tomorrow_plan'),'') else tomorrow_plan end,
    safety_note=case when p_payload?'safety_note' then nullif(trim(p_payload->>'safety_note'),'') else safety_note end,
    weather_note=case when p_payload?'weather_note' then nullif(trim(p_payload->>'weather_note'),'') else weather_note end,
    manpower=case when p_payload?'manpower' then coalesce(p_payload->'manpower','{}'::jsonb) else manpower end,
    equipment=case when p_payload?'equipment' then coalesce(p_payload->'equipment','[]'::jsonb) else equipment end,
    updated_by=auth.uid(),updated_at=now()
  where id=l.id returning * into l;
  perform app_private.record_site_daily_event(l.id,'updated',null,jsonb_build_object('fields',coalesce(p_payload,'{}'::jsonb)));
  return to_jsonb(l);
end $$;

-- Inspection creation and result save.
create or replace function public.create_site_inspection(
  p_company_id uuid,p_site_id uuid,p_template_id uuid default null,p_cabinet_id uuid default null,p_drawing_id uuid default null,p_task_id uuid default null,p_title text default null
) returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare s public.sites%rowtype;t public.site_inspection_templates%rowtype;i public.site_inspections%rowtype;it jsonb;n integer:=0;
begin
  select * into s from public.sites where id=p_site_id and company_id=p_company_id and archived_at is null;if not found then raise exception 'Site not found';end if;
  if not app_private.site_execution_can_edit(p_company_id,s.project_id,s.id) then raise exception 'Permission denied';end if;
  if p_template_id is not null then select * into t from public.site_inspection_templates where id=p_template_id and is_active and (company_id is null or company_id=p_company_id);if not found then raise exception 'Inspection template not found';end if;end if;
  insert into public.site_inspections(company_id,project_id,site_id,cabinet_id,drawing_id,task_id,template_id,title,created_by,updated_by)
  values(p_company_id,s.project_id,s.id,p_cabinet_id,p_drawing_id,p_task_id,p_template_id,coalesce(nullif(trim(p_title),''),coalesce(t.name_ar,'Site inspection')),auth.uid(),auth.uid()) returning * into i;
  for it in select * from jsonb_array_elements(coalesce(t.items,'[]'::jsonb)) loop
    n:=n+1;
    insert into public.site_inspection_items(inspection_id,item_key,label_ar,label_en,sort_order)
    values(i.id,coalesce(nullif(it->>'key',''),'item_'||n),coalesce(nullif(it->>'label_ar',''),it->>'label_en','بند فحص'),coalesce(nullif(it->>'label_en',''),it->>'label_ar','Inspection item'),n*10);
  end loop;
  return jsonb_build_object('inspection',to_jsonb(i),'items',(select coalesce(jsonb_agg(to_jsonb(x) order by x.sort_order),'[]'::jsonb) from public.site_inspection_items x where x.inspection_id=i.id));
end $$;

create or replace function public.save_site_inspection(p_inspection_id uuid,p_results jsonb,p_overall_note text default null,p_complete boolean default false)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare i public.site_inspections%rowtype;r jsonb;v_fail integer;v_pending integer;
begin
  select * into i from public.site_inspections where id=p_inspection_id for update;if not found then raise exception 'Inspection not found';end if;
  if not app_private.site_execution_can_edit(i.company_id,i.project_id,i.site_id) then raise exception 'Permission denied';end if;
  for r in select * from jsonb_array_elements(coalesce(p_results,'[]'::jsonb)) loop
    update public.site_inspection_items set
      result=case when r->>'result' in('pending','pass','fail','na') then r->>'result' else result end,
      note=case when r?'note' then nullif(trim(r->>'note'),'') else note end,
      evidence_document_id=case when r?'evidence_document_id' then nullif(r->>'evidence_document_id','')::uuid else evidence_document_id end,
      updated_by=auth.uid(),updated_at=now()
    where inspection_id=i.id and item_key=r->>'item_key';
  end loop;
  select count(*) filter(where result='fail'),count(*) filter(where result='pending') into v_fail,v_pending from public.site_inspection_items where inspection_id=i.id;
  update public.site_inspections set overall_note=nullif(trim(p_overall_note),''),status=case when p_complete then case when v_fail>0 then 'failed' when v_pending>0 then 'needs_review' else 'passed' end else 'in_progress' end,completed_at=case when p_complete then now() else null end,updated_by=auth.uid(),updated_at=now() where id=i.id returning * into i;
  if p_complete and v_fail>0 then perform app_private.notify_company_members(i.company_id,auth.uid(),'inspection_failed','فشل فحص ميداني','Field inspection failed','يوجد بند أو أكثر لم يجتز الفحص ويحتاج مراجعة.','One or more inspection items failed and need review.','site_inspection',i.id);end if;
  return jsonb_build_object('inspection',to_jsonb(i),'items',(select coalesce(jsonb_agg(to_jsonb(x) order by x.sort_order),'[]'::jsonb) from public.site_inspection_items x where x.inspection_id=i.id));
end $$;

-- Issues / Snags.
create or replace function public.create_site_field_issue(p_company_id uuid,p_site_id uuid,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare s public.sites%rowtype;i public.site_field_issues%rowtype;
begin
  select * into s from public.sites where id=p_site_id and company_id=p_company_id and archived_at is null;if not found then raise exception 'Site not found';end if;
  if not app_private.site_execution_can_edit(p_company_id,s.project_id,s.id) then raise exception 'Permission denied';end if;
  if char_length(trim(coalesce(p_payload->>'title','')))<2 then raise exception 'Issue title is required';end if;
  insert into public.site_field_issues(company_id,project_id,site_id,cabinet_id,drawing_id,task_id,document_id,title,description,severity,assigned_to,due_at,location_note,created_by,updated_by)
  values(p_company_id,s.project_id,s.id,nullif(p_payload->>'cabinet_id','')::uuid,nullif(p_payload->>'drawing_id','')::uuid,nullif(p_payload->>'task_id','')::uuid,nullif(p_payload->>'document_id','')::uuid,trim(p_payload->>'title'),nullif(trim(p_payload->>'description'),''),case when p_payload->>'severity' in('low','medium','high','critical') then p_payload->>'severity' else 'medium' end,nullif(p_payload->>'assigned_to','')::uuid,nullif(p_payload->>'due_at','')::timestamptz,nullif(trim(p_payload->>'location_note'),''),auth.uid(),auth.uid()) returning * into i;
  if i.severity in('high','critical') then perform app_private.notify_company_members(i.company_id,auth.uid(),'site_issue','مشكلة ميدانية تحتاج متابعة','Field issue needs attention',i.title,i.title,'site_field_issue',i.id);end if;
  return to_jsonb(i);
end $$;

create or replace function public.update_site_field_issue(p_issue_id uuid,p_status text,p_note text default null,p_assigned_to uuid default null)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare i public.site_field_issues%rowtype;
begin
  select * into i from public.site_field_issues where id=p_issue_id for update;if not found then raise exception 'Issue not found';end if;
  if not app_private.site_execution_can_edit(i.company_id,i.project_id,i.site_id) then raise exception 'Permission denied';end if;
  if p_status not in('open','in_progress','ready_for_review','closed','cancelled') then raise exception 'Invalid issue status';end if;
  update public.site_field_issues set status=p_status,resolution_note=case when p_note is not null then nullif(trim(p_note),'') else resolution_note end,assigned_to=coalesce(p_assigned_to,assigned_to),closed_at=case when p_status='closed' then now() else null end,closed_by=case when p_status='closed' then auth.uid() else null end,updated_by=auth.uid(),updated_at=now() where id=i.id returning * into i;
  return to_jsonb(i);
end $$;

-- Constraints.
create or replace function public.save_site_constraint(p_company_id uuid,p_site_id uuid,p_constraint_id uuid,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare s public.sites%rowtype;c public.site_constraints%rowtype;v_type text:=coalesce(p_payload->>'constraint_type','other');
begin
  select * into s from public.sites where id=p_site_id and company_id=p_company_id and archived_at is null;if not found then raise exception 'Site not found';end if;
  if not app_private.site_execution_can_edit(p_company_id,s.project_id,s.id) then raise exception 'Permission denied';end if;
  if v_type not in('material','permit','client','design','access','weather','technical','resource','other') then v_type:='other';end if;
  if p_constraint_id is null then
    insert into public.site_constraints(company_id,project_id,site_id,cabinet_id,task_id,constraint_type,title,description,impact,owner_user_id,created_by,updated_by)
    values(p_company_id,s.project_id,s.id,nullif(p_payload->>'cabinet_id','')::uuid,nullif(p_payload->>'task_id','')::uuid,v_type,trim(p_payload->>'title'),nullif(trim(p_payload->>'description'),''),nullif(trim(p_payload->>'impact'),''),nullif(p_payload->>'owner_user_id','')::uuid,auth.uid(),auth.uid()) returning * into c;
  else
    update public.site_constraints set constraint_type=v_type,title=trim(p_payload->>'title'),description=nullif(trim(p_payload->>'description'),''),impact=nullif(trim(p_payload->>'impact'),''),owner_user_id=nullif(p_payload->>'owner_user_id','')::uuid,updated_by=auth.uid(),updated_at=now() where id=p_constraint_id and company_id=p_company_id and site_id=p_site_id returning * into c;
    if c.id is null then raise exception 'Constraint not found';end if;
  end if;
  return to_jsonb(c);
end $$;

create or replace function public.resolve_site_constraint(p_constraint_id uuid,p_note text)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare c public.site_constraints%rowtype;
begin
  select * into c from public.site_constraints where id=p_constraint_id for update;if not found then raise exception 'Constraint not found';end if;
  if not app_private.site_execution_can_edit(c.company_id,c.project_id,c.site_id) then raise exception 'Permission denied';end if;
  update public.site_constraints set status='resolved',resolved_at=now(),resolution_note=nullif(trim(p_note),''),updated_by=auth.uid(),updated_at=now() where id=c.id returning * into c;
  return to_jsonb(c);
end $$;

-- Daily report lifecycle.
create or replace function public.submit_site_daily_log(p_log_id uuid,p_note text default null)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare l public.site_daily_logs%rowtype;
begin
  select * into l from public.site_daily_logs where id=p_log_id for update;if not found then raise exception 'Daily log not found';end if;
  if not app_private.site_execution_can_edit(l.company_id,l.project_id,l.site_id) then raise exception 'Permission denied';end if;
  if l.status not in('draft','returned') then raise exception 'Daily report cannot be submitted in current state';end if;
  update public.site_daily_logs set status='submitted',submitted_at=now(),submitted_by=auth.uid(),reviewer_note=null,updated_by=auth.uid(),updated_at=now() where id=l.id returning * into l;
  perform app_private.record_site_daily_event(l.id,'submitted',p_note,'{}'::jsonb);
  perform app_private.notify_company_members(l.company_id,auth.uid(),'daily_report_submitted','تقرير الموقع اليومي جاهز للمراجعة','Daily site report ready for review','تم إرسال تقرير الموقع اليومي للمراجعة.','The daily site report was submitted for review.','site_daily_log',l.id);
  return to_jsonb(l);
end $$;

create or replace function public.review_site_daily_log(p_log_id uuid,p_decision text,p_note text default null)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare l public.site_daily_logs%rowtype;v_manage boolean;
begin
  select * into l from public.site_daily_logs where id=p_log_id for update;if not found then raise exception 'Daily log not found';end if;
  v_manage:=app_private.user_has_resource_permission(auth.uid(),l.company_id,'tasks.manage',l.project_id,l.site_id,null,null) or app_private.user_has_resource_permission(auth.uid(),l.company_id,'files.manage',l.project_id,l.site_id,null,null);
  if not v_manage then raise exception 'Permission denied';end if;
  if l.status<>'submitted' then raise exception 'Only submitted reports can be reviewed';end if;
  if p_decision not in('approved','returned') then raise exception 'Invalid decision';end if;
  if p_decision='returned' and nullif(trim(p_note),'') is null then raise exception 'Return reason is required';end if;
  update public.site_daily_logs set status=p_decision,reviewed_at=now(),reviewed_by=auth.uid(),reviewer_note=nullif(trim(p_note),''),updated_by=auth.uid(),updated_at=now() where id=l.id returning * into l;
  perform app_private.record_site_daily_event(l.id,case when p_decision='approved' then 'approved' else 'returned' end,p_note,'{}'::jsonb);
  perform app_private.notify_company_members(l.company_id,auth.uid(),case when p_decision='approved' then 'daily_report_approved' else 'daily_report_returned' end,case when p_decision='approved' then 'تم اعتماد تقرير الموقع اليومي' else 'تم إرجاع تقرير الموقع اليومي' end,case when p_decision='approved' then 'Daily site report approved' else 'Daily site report returned' end,coalesce(nullif(trim(p_note),''),'تم تحديث حالة تقرير الموقع.'),coalesce(nullif(trim(p_note),''),'The daily site report status changed.'),'site_daily_log',l.id);
  return to_jsonb(l);
end $$;

create or replace function public.link_site_daily_report_document(p_log_id uuid,p_document_id uuid)
returns void language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare l public.site_daily_logs%rowtype;d public.documents%rowtype;
begin
  select * into l from public.site_daily_logs where id=p_log_id for update;if not found then raise exception 'Daily log not found';end if;
  if not app_private.site_execution_can_edit(l.company_id,l.project_id,l.site_id) then raise exception 'Permission denied';end if;
  select * into d from public.documents where id=p_document_id and company_id=l.company_id and project_id=l.project_id and site_id is not distinct from l.site_id and state='active';if not found then raise exception 'Document not found';end if;
  update public.site_daily_logs set report_document_id=d.id,updated_by=auth.uid(),updated_at=now() where id=l.id;
  perform app_private.record_site_daily_event(l.id,'report_synced',null,jsonb_build_object('document_id',d.id));
end $$;

-- One canonical workspace snapshot for the field execution UI.
create or replace function public.site_execution_workspace(p_company_id uuid,p_site_id uuid,p_work_date date default current_date,p_limit integer default 40)
returns jsonb language plpgsql stable security definer set search_path='public','app_private','pg_temp' as $$
declare s public.sites%rowtype;p public.projects%rowtype;l public.site_daily_logs%rowtype;v_date date:=coalesce(p_work_date,current_date);v_can_edit boolean;v_can_review boolean;
begin
  if auth.uid() is null then raise exception 'Authentication required';end if;
  select * into s from public.sites where id=p_site_id and company_id=p_company_id and archived_at is null;if not found then raise exception 'Site not found';end if;
  if not app_private.user_has_resource_permission(auth.uid(),p_company_id,'projects.view',s.project_id,s.id,null,null) then raise exception 'Permission denied';end if;
  select * into p from public.projects where id=s.project_id;
  select * into l from public.site_daily_logs where company_id=p_company_id and site_id=s.id and log_date=v_date;
  v_can_edit:=app_private.site_execution_can_edit(p_company_id,p.id,s.id);
  v_can_review:=app_private.user_has_resource_permission(auth.uid(),p_company_id,'tasks.manage',p.id,s.id,null,null) or app_private.user_has_resource_permission(auth.uid(),p_company_id,'files.manage',p.id,s.id,null,null);
  return jsonb_build_object(
    'date',v_date,
    'site',jsonb_build_object('id',s.id,'code',s.code,'name',s.name,'status',s.status,'target_end_date',s.target_end_date,'manager_user_id',s.manager_user_id),
    'project',jsonb_build_object('id',p.id,'code',p.code,'name',p.name,'status',p.status,'target_end_date',p.target_end_date),
    'daily_log',case when l.id is null then null else to_jsonb(l) end,
    'report_folder_id',app_private.resolve_site_report_folder(p.id,s.id),
    'capabilities',jsonb_build_object('can_edit',v_can_edit,'can_review_report',v_can_review,'can_upload',app_private.user_has_resource_permission(auth.uid(),p_company_id,'files.upload',p.id,s.id,null,null),'can_create_task',app_private.user_has_resource_permission(auth.uid(),p_company_id,'tasks.create',p.id,s.id,null,null)),
    'templates',coalesce((select jsonb_agg(to_jsonb(t) order by t.sort_order,t.name_en) from public.site_inspection_templates t where t.is_active and (t.company_id is null or t.company_id=p_company_id)),'[]'::jsonb),
    'inspections',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'title',i.title,'status',i.status,'cabinet_id',i.cabinet_id,'drawing_id',i.drawing_id,'task_id',i.task_id,'template_id',i.template_id,'started_at',i.started_at,'completed_at',i.completed_at,'overall_note',i.overall_note,'items',(select coalesce(jsonb_agg(to_jsonb(ii) order by ii.sort_order),'[]'::jsonb) from public.site_inspection_items ii where ii.inspection_id=i.id)) order by i.created_at desc) from (select * from public.site_inspections where company_id=p_company_id and site_id=s.id and created_at::date between v_date-6 and v_date order by created_at desc limit p_limit) i),'[]'::jsonb),
    'issues',coalesce((select jsonb_agg(to_jsonb(i) order by case i.severity when 'critical' then 0 when 'high' then 1 when 'medium' then 2 else 3 end,i.created_at desc) from (select * from public.site_field_issues where company_id=p_company_id and site_id=s.id and status not in('closed','cancelled') order by created_at desc limit p_limit) i),'[]'::jsonb),
    'constraints',coalesce((select jsonb_agg(to_jsonb(c) order by c.started_at desc) from (select * from public.site_constraints where company_id=p_company_id and site_id=s.id and status not in('resolved','cancelled') order by started_at desc limit p_limit) c),'[]'::jsonb),
    'tasks_today',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'title',t.title,'status',t.status,'priority',t.priority,'due_at',t.due_at,'progress',t.progress,'cabinet_id',null) order by t.due_at nulls last) from public.tasks t where t.company_id=p_company_id and t.site_id=s.id and app_private.can_view_task(t.id) and t.status not in('done','cancelled') and (t.due_at::date<=v_date or t.start_at::date=v_date)),'[]'::jsonb),
    'documents_today',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'display_name',d.display_name,'document_type',d.document_type,'created_at',d.created_at,'current_version_id',d.current_version_id,'folder_id',d.folder_id) order by d.created_at desc) from (select * from public.documents where company_id=p_company_id and site_id=s.id and state='active' and created_at::date=v_date order by created_at desc limit p_limit) d),'[]'::jsonb),
    'drawings_today',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'drawing_no',d.drawing_no,'title',d.title,'status',d.status,'cabinet_id',d.cabinet_id,'updated_at',d.updated_at,'last_change_at',d.last_change_at) order by coalesce(d.last_change_at,d.updated_at) desc) from (select * from public.engineering_drawings where company_id=p_company_id and site_id=s.id and archived_at is null and coalesce(last_change_at,updated_at)::date=v_date order by coalesce(last_change_at,updated_at) desc limit p_limit) d),'[]'::jsonb),
    'completed_tasks',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'title',t.title,'completed_at',t.completed_at) order by t.completed_at desc) from (select * from public.tasks where company_id=p_company_id and site_id=s.id and status='done' and completed_at::date=v_date order by completed_at desc limit p_limit) t),'[]'::jsonb),
    'events',case when l.id is null then '[]'::jsonb else coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'event_type',e.event_type,'actor_id',e.actor_id,'note',e.note,'metadata',e.metadata,'created_at',e.created_at) order by e.created_at desc) from public.site_daily_log_events e where e.log_id=l.id),'[]'::jsonb) end,
    'progress',jsonb_build_object(
      'tasks_done_today',(select count(*) from public.tasks t where t.company_id=p_company_id and t.site_id=s.id and t.status='done' and t.completed_at::date=v_date),
      'tasks_open',(select count(*) from public.tasks t where t.company_id=p_company_id and t.site_id=s.id and t.status not in('done','cancelled') and app_private.can_view_task(t.id)),
      'tasks_overdue',(select count(*) from public.tasks t where t.company_id=p_company_id and t.site_id=s.id and t.status not in('done','cancelled') and t.due_at<now() and app_private.can_view_task(t.id)),
      'inspections_done',(select count(*) from public.site_inspections i where i.company_id=p_company_id and i.site_id=s.id and i.completed_at::date=v_date),
      'inspections_failed',(select count(*) from public.site_inspections i where i.company_id=p_company_id and i.site_id=s.id and i.status='failed' and i.completed_at::date=v_date),
      'issues_open',(select count(*) from public.site_field_issues i where i.company_id=p_company_id and i.site_id=s.id and i.status not in('closed','cancelled')),
      'critical_issues',(select count(*) from public.site_field_issues i where i.company_id=p_company_id and i.site_id=s.id and i.status not in('closed','cancelled') and i.severity='critical'),
      'constraints_open',(select count(*) from public.site_constraints c where c.company_id=p_company_id and c.site_id=s.id and c.status not in('resolved','cancelled')),
      'documents_added',(select count(*) from public.documents d where d.company_id=p_company_id and d.site_id=s.id and d.state='active' and d.created_at::date=v_date),
      'drawings_changed',(select count(*) from public.engineering_drawings d where d.company_id=p_company_id and d.site_id=s.id and d.archived_at is null and coalesce(d.last_change_at,d.updated_at)::date=v_date)
    )
  );
end $$;

-- End-of-day readiness and report export payload (queries canonical data, stores no copies).
create or replace function public.site_end_of_day_review(p_company_id uuid,p_site_id uuid,p_work_date date default current_date)
returns jsonb language plpgsql stable security definer set search_path='public','app_private','pg_temp' as $$
declare x jsonb; l jsonb; p jsonb; v_score integer:=0;v_total integer:=7;
begin
  x:=public.site_execution_workspace(p_company_id,p_site_id,p_work_date,60);
  l:=x->'daily_log';p:=x->'progress';
  if l is not null then v_score:=v_score+1;end if;
  if coalesce(nullif(l->>'summary',''),'')<>'' or coalesce((p->>'tasks_done_today')::int,0)>0 then v_score:=v_score+1;end if;
  if coalesce((p->>'critical_issues')::int,0)=0 then v_score:=v_score+1;end if;
  if coalesce((p->>'inspections_failed')::int,0)=0 then v_score:=v_score+1;end if;
  if coalesce((p->>'documents_added')::int,0)>0 or coalesce((p->>'drawings_changed')::int,0)>0 or coalesce((p->>'tasks_done_today')::int,0)>0 then v_score:=v_score+1;end if;
  if coalesce(nullif(l->>'tomorrow_plan',''),'')<>'' then v_score:=v_score+1;end if;
  if (l->>'status') in ('submitted','approved') then v_score:=v_score+1;end if;
  return jsonb_build_object('score',v_score,'total',v_total,'percent',round(v_score::numeric/v_total*100),'workspace',x,
    'checks',jsonb_build_array(
      jsonb_build_object('key','log','done',l is not null),
      jsonb_build_object('key','work','done',coalesce(nullif(l->>'summary',''),'')<>'' or coalesce((p->>'tasks_done_today')::int,0)>0),
      jsonb_build_object('key','critical','done',coalesce((p->>'critical_issues')::int,0)=0),
      jsonb_build_object('key','inspection','done',coalesce((p->>'inspections_failed')::int,0)=0),
      jsonb_build_object('key','evidence','done',coalesce((p->>'documents_added')::int,0)>0 or coalesce((p->>'drawings_changed')::int,0)>0 or coalesce((p->>'tasks_done_today')::int,0)>0),
      jsonb_build_object('key','tomorrow','done',coalesce(nullif(l->>'tomorrow_plan',''),'')<>''),
      jsonb_build_object('key','submit','done',(l->>'status') in ('submitted','approved'))
    ));
end $$;

create or replace function public.site_weekly_progress(p_company_id uuid,p_site_id uuid,p_week_start date)
returns jsonb language plpgsql stable security definer set search_path='public','app_private','pg_temp' as $$
declare s public.sites%rowtype;v_start date:=date_trunc('week',coalesce(p_week_start,current_date)::timestamp)::date;v_end date:=v_start+6;
begin
  select * into s from public.sites where id=p_site_id and company_id=p_company_id;if not found then raise exception 'Site not found';end if;
  if not app_private.user_has_resource_permission(auth.uid(),p_company_id,'projects.view',s.project_id,s.id,null,null) then raise exception 'Permission denied';end if;
  return jsonb_build_object('week_start',v_start,'week_end',v_end,
    'days',coalesce((select jsonb_agg(jsonb_build_object('date',d.work_date,'tasks_done',(select count(*) from public.tasks t where t.site_id=s.id and t.status='done' and t.completed_at::date=d.work_date),'inspections',(select count(*) from public.site_inspections i where i.site_id=s.id and i.completed_at::date=d.work_date),'issues_created',(select count(*) from public.site_field_issues i where i.site_id=s.id and i.created_at::date=d.work_date),'documents',(select count(*) from public.documents x where x.site_id=s.id and x.state='active' and x.created_at::date=d.work_date),'report_status',(select l.status from public.site_daily_logs l where l.site_id=s.id and l.log_date=d.work_date)) order by d.work_date) from (select generate_series(v_start,v_end,'1 day'::interval)::date as work_date)d),'[]'::jsonb),
    'summary',jsonb_build_object(
      'tasks_done',(select count(*) from public.tasks t where t.site_id=s.id and t.status='done' and t.completed_at::date between v_start and v_end),
      'inspections',(select count(*) from public.site_inspections i where i.site_id=s.id and i.completed_at::date between v_start and v_end),
      'failed_inspections',(select count(*) from public.site_inspections i where i.site_id=s.id and i.status='failed' and i.completed_at::date between v_start and v_end),
      'issues_created',(select count(*) from public.site_field_issues i where i.site_id=s.id and i.created_at::date between v_start and v_end),
      'issues_closed',(select count(*) from public.site_field_issues i where i.site_id=s.id and i.closed_at::date between v_start and v_end),
      'documents_added',(select count(*) from public.documents d where d.site_id=s.id and d.state='active' and d.created_at::date between v_start and v_end),
      'approved_reports',(select count(*) from public.site_daily_logs l where l.site_id=s.id and l.log_date between v_start and v_end and l.status='approved')
    ));
end $$;



create or replace function public.resolve_site_execution_context(p_entity_type text,p_entity_id uuid)
returns jsonb language plpgsql stable security definer set search_path='public','app_private','pg_temp' as $$
declare v_company uuid;v_project uuid;v_site uuid;v_cabinet uuid;v_date date;
begin
  if auth.uid() is null then raise exception 'Authentication required';end if;
  if p_entity_type='site_daily_log' then select company_id,project_id,site_id,null::uuid,log_date into v_company,v_project,v_site,v_cabinet,v_date from public.site_daily_logs where id=p_entity_id;
  elsif p_entity_type='site_inspection' then select company_id,project_id,site_id,cabinet_id,started_at::date into v_company,v_project,v_site,v_cabinet,v_date from public.site_inspections where id=p_entity_id;
  elsif p_entity_type='site_field_issue' then select company_id,project_id,site_id,cabinet_id,created_at::date into v_company,v_project,v_site,v_cabinet,v_date from public.site_field_issues where id=p_entity_id;
  elsif p_entity_type='site_constraint' then select company_id,project_id,site_id,cabinet_id,started_at::date into v_company,v_project,v_site,v_cabinet,v_date from public.site_constraints where id=p_entity_id;
  else raise exception 'Unsupported field entity';end if;
  if v_site is null then raise exception 'Field entity not found';end if;
  if not app_private.user_has_resource_permission(auth.uid(),v_company,'projects.view',v_project,v_site,null,null) then raise exception 'Permission denied';end if;
  return jsonb_build_object('type',p_entity_type,'entity_id',p_entity_id,'company_id',v_company,'project_id',v_project,'site_id',v_site,'cabinet_id',v_cabinet,'work_date',v_date);
end $$;

-- Operations Center bridge: Point 10 events remain field-owned but surface in the unified operating layer.
create or replace function public.site_operations_feed(p_company_id uuid,p_since timestamptz default null,p_limit integer default 40)
returns jsonb language plpgsql stable security definer set search_path='public','app_private','pg_temp' as $$
declare v_since timestamptz:=coalesce(p_since,now()-interval '7 days');
begin
  if not app_private.is_company_member(p_company_id) then raise exception 'Permission denied';end if;
  p_limit:=greatest(10,least(coalesce(p_limit,40),120));
  return jsonb_build_object(
    'changes',coalesce((select jsonb_agg(x.item order by x.at desc) from (
      select e.created_at at,jsonb_build_object('entity_type','site_daily_log','entity_id',l.id,'title',coalesce(s.code,'')||' · '||to_char(l.log_date,'YYYY-MM-DD'),'project_id',l.project_id,'site_id',l.site_id,'created_at',e.created_at,'actor_id',e.actor_id,'action','field.'||e.event_type,'metadata',coalesce(e.metadata,'{}'::jsonb)||jsonb_build_object('note',e.note)) item
      from public.site_daily_log_events e join public.site_daily_logs l on l.id=e.log_id join public.sites s on s.id=l.site_id
      where e.company_id=p_company_id and e.created_at>v_since and app_private.user_has_resource_permission(auth.uid(),p_company_id,'projects.view',l.project_id,l.site_id,null,null)
      union all
      select i.updated_at,jsonb_build_object('entity_type','site_inspection','entity_id',i.id,'title',i.title,'project_id',i.project_id,'site_id',i.site_id,'created_at',i.updated_at,'actor_id',i.updated_by,'action','field.inspection.'||i.status,'metadata',jsonb_build_object('status',i.status,'cabinet_id',i.cabinet_id))
      from public.site_inspections i where i.company_id=p_company_id and i.updated_at>v_since and app_private.user_has_resource_permission(auth.uid(),p_company_id,'projects.view',i.project_id,i.site_id,null,null)
      union all
      select i.updated_at,jsonb_build_object('entity_type','site_field_issue','entity_id',i.id,'title',i.title,'project_id',i.project_id,'site_id',i.site_id,'created_at',i.updated_at,'actor_id',i.updated_by,'action','field.issue.'||i.status,'metadata',jsonb_build_object('status',i.status,'severity',i.severity,'cabinet_id',i.cabinet_id))
      from public.site_field_issues i where i.company_id=p_company_id and i.updated_at>v_since and app_private.user_has_resource_permission(auth.uid(),p_company_id,'projects.view',i.project_id,i.site_id,null,null)
      union all
      select c.updated_at,jsonb_build_object('entity_type','site_constraint','entity_id',c.id,'title',c.title,'project_id',c.project_id,'site_id',c.site_id,'created_at',c.updated_at,'actor_id',c.updated_by,'action','field.constraint.'||c.status,'metadata',jsonb_build_object('status',c.status,'constraint_type',c.constraint_type))
      from public.site_constraints c where c.company_id=p_company_id and c.updated_at>v_since and app_private.user_has_resource_permission(auth.uid(),p_company_id,'projects.view',c.project_id,c.site_id,null,null)
      order by at desc limit p_limit
    ) x),'[]'::jsonb),
    'approvals',coalesce((select jsonb_agg(jsonb_build_object('kind','site_daily_log','entity_type','site_daily_log','entity_id',l.id,'title','Daily report · '||s.code||' · '||to_char(l.log_date,'YYYY-MM-DD'),'project_id',l.project_id,'site_id',l.site_id,'at',l.submitted_at,'action_kind','daily_report_review','status',l.status) order by l.submitted_at)
      from public.site_daily_logs l join public.sites s on s.id=l.site_id
      where l.company_id=p_company_id and l.status='submitted' and (app_private.user_has_resource_permission(auth.uid(),p_company_id,'tasks.manage',l.project_id,l.site_id,null,null) or app_private.user_has_resource_permission(auth.uid(),p_company_id,'files.manage',l.project_id,l.site_id,null,null))),'[]'::jsonb)
  );
end $$;

create or replace function public.site_execution_calendar_feed(p_company_id uuid,p_from timestamptz,p_to timestamptz)
returns jsonb language plpgsql stable security definer set search_path='public','app_private','pg_temp' as $$
begin
  if not app_private.is_company_member(p_company_id) then raise exception 'Permission denied';end if;
  if p_to<=p_from or p_to-p_from>interval '370 days' then raise exception 'Invalid calendar range';end if;
  return coalesce((select jsonb_agg(x.item order by x.at) from (
    select i.started_at at,jsonb_build_object('kind','field_inspection','id',i.id,'title',i.title,'status',i.status,'start_at',i.started_at,'end_at',coalesce(i.completed_at,i.started_at),'all_day',false,'project_id',i.project_id,'site_id',i.site_id,'entity_type','site_inspection') item
    from public.site_inspections i where i.company_id=p_company_id and i.started_at>=p_from and i.started_at<p_to and app_private.user_has_resource_permission(auth.uid(),p_company_id,'projects.view',i.project_id,i.site_id,null,null)
    union all
    select l.log_date::timestamptz,jsonb_build_object('kind','daily_report','id',l.id,'title','Daily report · '||s.code,'status',l.status,'start_at',l.log_date::timestamptz,'end_at',l.log_date::timestamptz,'all_day',true,'project_id',l.project_id,'site_id',l.site_id,'entity_type','site_daily_log')
    from public.site_daily_logs l join public.sites s on s.id=l.site_id where l.company_id=p_company_id and l.log_date>=p_from::date and l.log_date<p_to::date and app_private.user_has_resource_permission(auth.uid(),p_company_id,'projects.view',l.project_id,l.site_id,null,null)
    union all
    select i.due_at,jsonb_build_object('kind','field_issue_due','id',i.id,'title',i.title,'status',i.status,'start_at',i.due_at,'end_at',i.due_at,'all_day',false,'project_id',i.project_id,'site_id',i.site_id,'entity_type','site_field_issue')
    from public.site_field_issues i where i.company_id=p_company_id and i.due_at>=p_from and i.due_at<p_to and i.status not in('closed','cancelled') and app_private.user_has_resource_permission(auth.uid(),p_company_id,'projects.view',i.project_id,i.site_id,null,null)
  )x),'[]'::jsonb);
end $$;

-- Grants
revoke all on function public.ensure_site_daily_log(uuid,uuid,date),public.save_site_daily_log(uuid,jsonb),public.create_site_inspection(uuid,uuid,uuid,uuid,uuid,uuid,text),public.save_site_inspection(uuid,jsonb,text,boolean),public.create_site_field_issue(uuid,uuid,jsonb),public.update_site_field_issue(uuid,text,text,uuid),public.save_site_constraint(uuid,uuid,uuid,jsonb),public.resolve_site_constraint(uuid,text),public.submit_site_daily_log(uuid,text),public.review_site_daily_log(uuid,text,text),public.link_site_daily_report_document(uuid,uuid),public.site_execution_workspace(uuid,uuid,date,integer),public.site_end_of_day_review(uuid,uuid,date),public.site_weekly_progress(uuid,uuid,date) from public,anon;
grant execute on function public.ensure_site_daily_log(uuid,uuid,date),public.save_site_daily_log(uuid,jsonb),public.create_site_inspection(uuid,uuid,uuid,uuid,uuid,uuid,text),public.save_site_inspection(uuid,jsonb,text,boolean),public.create_site_field_issue(uuid,uuid,jsonb),public.update_site_field_issue(uuid,text,text,uuid),public.save_site_constraint(uuid,uuid,uuid,jsonb),public.resolve_site_constraint(uuid,text),public.submit_site_daily_log(uuid,text),public.review_site_daily_log(uuid,text,text),public.link_site_daily_report_document(uuid,uuid),public.site_execution_workspace(uuid,uuid,date,integer),public.site_end_of_day_review(uuid,uuid,date),public.site_weekly_progress(uuid,uuid,date) to authenticated;


revoke all on function public.site_operations_feed(uuid,timestamptz,integer),public.site_execution_calendar_feed(uuid,timestamptz,timestamptz),public.resolve_site_execution_context(text,uuid) from public,anon;
grant execute on function public.site_operations_feed(uuid,timestamptz,integer),public.site_execution_calendar_feed(uuid,timestamptz,timestamptz),public.resolve_site_execution_context(text,uuid) to authenticated;

commit;
