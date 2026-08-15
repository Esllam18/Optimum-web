begin;

-- Point 11 — Project Control & Management Intelligence
-- Dynamic, permission-aware management read models over canonical Optimum data.
-- Only authored management briefs are persisted; project health/trends remain live calculations.

create table if not exists public.project_control_briefs(
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  week_start date not null,
  status text not null default 'draft' check(status in('draft','submitted','approved','returned')),
  executive_summary text,
  decisions_needed text,
  next_week_plan text,
  management_note text,
  report_document_id uuid references public.documents(id) on delete set null,
  submitted_at timestamptz,
  submitted_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewer_note text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  unique(project_id,week_start)
);
create index if not exists project_control_briefs_company_week_idx on public.project_control_briefs(company_id,week_start desc,status);

create table if not exists public.project_control_brief_events(
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  brief_id uuid not null references public.project_control_briefs(id) on delete cascade,
  event_type text not null,
  actor_id uuid references auth.users(id) on delete set null,
  note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists project_control_brief_events_brief_idx on public.project_control_brief_events(brief_id,created_at desc);

alter table public.project_control_briefs enable row level security;
alter table public.project_control_brief_events enable row level security;

create policy project_control_briefs_select on public.project_control_briefs for select to authenticated using(
  app_private.user_has_resource_permission(auth.uid(),company_id,'projects.view',project_id,null,null,null)
);
create policy project_control_brief_events_select on public.project_control_brief_events for select to authenticated using(
  exists(select 1 from public.project_control_briefs b where b.id=brief_id and app_private.user_has_resource_permission(auth.uid(),b.company_id,'projects.view',b.project_id,null,null,null))
);

revoke all on public.project_control_briefs,public.project_control_brief_events from anon,authenticated;
grant select on public.project_control_briefs,public.project_control_brief_events to authenticated;
grant all on public.project_control_briefs,public.project_control_brief_events to service_role;

create index if not exists point11_tasks_project_health_idx on public.tasks(project_id,status,due_at) where project_id is not null;
create index if not exists point11_milestones_project_health_idx on public.work_milestones(project_id,status,due_at) where project_id is not null;
create index if not exists point11_issues_project_health_idx on public.site_field_issues(project_id,status,severity,created_at desc);
create index if not exists point11_constraints_project_health_idx on public.site_constraints(project_id,status,started_at desc);
create index if not exists point11_inspections_project_health_idx on public.site_inspections(project_id,status,created_at desc);
create index if not exists point11_daily_logs_project_health_idx on public.site_daily_logs(project_id,status,log_date desc);

create or replace function app_private.project_control_metrics(p_project_id uuid)
returns jsonb language plpgsql stable security definer set search_path='public','app_private','pg_temp' as $$
declare
  p public.projects%rowtype;
  v_task_total int:=0; v_task_done int:=0; v_overdue int:=0; v_blocked int:=0; v_high_open int:=0;
  v_missed int:=0; v_at_risk int:=0; v_milestone_overdue int:=0;
  v_issue_open int:=0; v_issue_high int:=0; v_issue_critical int:=0;
  v_constraints int:=0; v_constraints_aged int:=0;
  v_failed_inspections int:=0; v_review_inspections int:=0;
  v_doc_overdue int:=0; v_doc_rejected int:=0;
  v_daily_returned int:=0; v_daily_pending int:=0;
  v_cabinets int:=0; v_cabinets_complete int:=0;
  v_req_total int:=0; v_req_ready int:=0;
  v_sites int:=0; v_sites_late int:=0;
  v_drawings_review int:=0;
  v_task_pct numeric:=null; v_req_pct numeric:=null; v_cab_pct numeric:=null; v_exec numeric:=null;
  v_expected numeric:=null; v_variance numeric:=null;
  v_pen_overdue numeric:=0;v_pen_blocked numeric:=0;v_pen_milestone numeric:=0;v_pen_issue numeric:=0;v_pen_constraint numeric:=0;v_pen_inspection numeric:=0;v_pen_cde numeric:=0;v_pen_daily numeric:=0;v_pen_schedule numeric:=0;
  v_score numeric:=100; v_band text:='stable';
begin
  select * into p from public.projects where id=p_project_id;
  if not found then raise exception 'Project not found'; end if;

  select count(*),count(*) filter(where t.status='done'),count(*) filter(where t.status not in('done','cancelled') and t.due_at<now()),count(*) filter(where t.status='blocked'),count(*) filter(where t.status not in('done','cancelled') and t.priority in('high','urgent'))
  into v_task_total,v_task_done,v_overdue,v_blocked,v_high_open
  from public.tasks t where t.project_id=p.id and app_private.can_view_task(t.id);

  select count(*) filter(where m.status='missed'),count(*) filter(where m.status='at_risk'),count(*) filter(where m.status in('planned','at_risk') and m.due_at<now())
  into v_missed,v_at_risk,v_milestone_overdue
  from public.work_milestones m where m.project_id=p.id and app_private.user_has_resource_permission(auth.uid(),p.company_id,'tasks.view',p.id,null,null,null);

  select count(*) filter(where i.status not in('closed','cancelled')),count(*) filter(where i.status not in('closed','cancelled') and i.severity='high'),count(*) filter(where i.status not in('closed','cancelled') and i.severity='critical')
  into v_issue_open,v_issue_high,v_issue_critical
  from public.site_field_issues i where i.project_id=p.id and app_private.user_has_resource_permission(auth.uid(),p.company_id,'projects.view',p.id,i.site_id,null,null);

  select count(*) filter(where c.status not in('resolved','cancelled')),count(*) filter(where c.status not in('resolved','cancelled') and c.started_at<now()-interval '7 days')
  into v_constraints,v_constraints_aged from public.site_constraints c
  where c.project_id=p.id and app_private.user_has_resource_permission(auth.uid(),p.company_id,'projects.view',p.id,c.site_id,null,null);

  select count(*) filter(where i.status='failed'),count(*) filter(where i.status='needs_review')
  into v_failed_inspections,v_review_inspections from public.site_inspections i
  where i.project_id=p.id and i.created_at>=now()-interval '30 days' and app_private.user_has_resource_permission(auth.uid(),p.company_id,'projects.view',p.id,i.site_id,null,null);

  select count(*) filter(where d.control_status='in_review' and d.review_due_at is not null and d.review_due_at<now()),count(*) filter(where d.control_status='rejected')
  into v_doc_overdue,v_doc_rejected from public.documents d
  where d.project_id=p.id and d.state='active' and app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.view',p.id,d.site_id,d.folder_id,null);

  select count(*) filter(where l.status='returned'),count(*) filter(where l.status='submitted')
  into v_daily_returned,v_daily_pending from public.site_daily_logs l
  where l.project_id=p.id and l.log_date>=current_date-30 and app_private.user_has_resource_permission(auth.uid(),p.company_id,'projects.view',p.id,l.site_id,null,null);

  select count(*),count(*) filter(where c.status='completed') into v_cabinets,v_cabinets_complete
  from public.site_cabinets c where c.project_id=p.id and c.archived_at is null and app_private.user_has_resource_permission(auth.uid(),p.company_id,'projects.view',p.id,c.site_id,null,null);

  select count(*) filter(where r.is_required),coalesce(sum(case when r.is_required then least((select count(*) from public.document_requirement_links l join public.documents d on d.id=l.document_id where l.requirement_id=r.id and d.state='active'),greatest(r.min_items,1)) else 0 end),0)
  into v_req_total,v_req_ready
  from public.document_requirements r where r.project_id=p.id and app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.view',p.id,r.site_id,null,null);

  select count(*),count(*) filter(where s.target_end_date is not null and s.target_end_date<current_date and coalesce(s.status,'active') not in('completed','archived'))
  into v_sites,v_sites_late from public.sites s where s.project_id=p.id and s.archived_at is null and app_private.user_has_resource_permission(auth.uid(),p.company_id,'projects.view',p.id,s.id,null,null);

  select count(*) into v_drawings_review from public.engineering_drawings d
  where d.project_id=p.id and d.archived_at is null and d.status='in_review' and app_private.user_has_resource_permission(auth.uid(),p.company_id,'drawings.view',p.id,d.site_id,d.folder_id,d.id);

  if v_task_total>0 then v_task_pct:=round(v_task_done*100.0/v_task_total,1); end if;
  if v_req_total>0 then v_req_pct:=round(v_req_ready*100.0/v_req_total,1); end if;
  if v_cabinets>0 then v_cab_pct:=round(v_cabinets_complete*100.0/v_cabinets,1); end if;

  select round(avg(x),1) into v_exec from unnest(array[v_task_pct,v_req_pct,v_cab_pct]::numeric[]) x where x is not null;
  if v_exec is null then v_exec:=coalesce(p.progress_percent,0); end if;

  if p.planned_start_date is not null and p.target_end_date is not null and p.target_end_date>p.planned_start_date then
    v_expected:=round(greatest(0,least(100,100.0*(current_date-p.planned_start_date)/(p.target_end_date-p.planned_start_date))),1);
    v_variance:=round(v_exec-v_expected,1);
  end if;

  v_pen_overdue:=least(18,v_overdue*2);
  v_pen_blocked:=least(12,v_blocked*3);
  v_pen_milestone:=least(15,v_missed*7+v_at_risk*4+v_milestone_overdue*2);
  v_pen_issue:=least(15,v_issue_critical*6+v_issue_high*3);
  v_pen_constraint:=least(12,v_constraints_aged*4+v_constraints);
  v_pen_inspection:=least(10,v_failed_inspections*3+v_review_inspections);
  v_pen_cde:=least(8,v_doc_rejected*3+v_doc_overdue*2);
  v_pen_daily:=least(5,v_daily_returned*2+v_daily_pending);
  v_pen_schedule:=case when v_variance is not null and v_variance<0 then least(15,round(abs(v_variance)*0.5,1)) else 0 end;
  v_score:=greatest(0,round(100-v_pen_overdue-v_pen_blocked-v_pen_milestone-v_pen_issue-v_pen_constraint-v_pen_inspection-v_pen_cde-v_pen_daily-v_pen_schedule,1));
  v_band:=case when v_score>=85 then 'stable' when v_score>=70 then 'watch' when v_score>=50 then 'at_risk' else 'critical' end;

  return jsonb_build_object(
    'score',v_score,'band',v_band,
    'execution_progress_pct',v_exec,'declared_progress_pct',coalesce(p.progress_percent,0),'expected_progress_pct',v_expected,'schedule_variance_pct',v_variance,
    'progress_sources',jsonb_build_object('tasks_pct',v_task_pct,'requirements_pct',v_req_pct,'cabinets_pct',v_cab_pct,'fallback',case when v_task_pct is null and v_req_pct is null and v_cab_pct is null then 'declared_project_progress' else null end),
    'tasks',jsonb_build_object('total',v_task_total,'done',v_task_done,'overdue',v_overdue,'blocked',v_blocked,'high_open',v_high_open),
    'milestones',jsonb_build_object('missed',v_missed,'at_risk',v_at_risk,'overdue',v_milestone_overdue),
    'field',jsonb_build_object('issues_open',v_issue_open,'issues_high',v_issue_high,'issues_critical',v_issue_critical,'constraints_open',v_constraints,'constraints_aged',v_constraints_aged,'failed_inspections',v_failed_inspections,'needs_review_inspections',v_review_inspections,'daily_returned',v_daily_returned,'daily_pending_review',v_daily_pending),
    'cde',jsonb_build_object('overdue_reviews',v_doc_overdue,'rejected',v_doc_rejected,'requirements_total',v_req_total,'requirements_ready',v_req_ready),
    'delivery',jsonb_build_object('cabinets_total',v_cabinets,'cabinets_complete',v_cabinets_complete),
    'sites',jsonb_build_object('total',v_sites,'late',v_sites_late),
    'drawings',jsonb_build_object('in_review',v_drawings_review),
    'drivers',jsonb_build_array(
      jsonb_build_object('key','overdue_tasks','count',v_overdue,'penalty',v_pen_overdue),
      jsonb_build_object('key','blocked_tasks','count',v_blocked,'penalty',v_pen_blocked),
      jsonb_build_object('key','milestones','count',v_missed+v_at_risk+v_milestone_overdue,'penalty',v_pen_milestone),
      jsonb_build_object('key','field_issues','count',v_issue_high+v_issue_critical,'penalty',v_pen_issue),
      jsonb_build_object('key','constraints','count',v_constraints,'penalty',v_pen_constraint),
      jsonb_build_object('key','inspections','count',v_failed_inspections+v_review_inspections,'penalty',v_pen_inspection),
      jsonb_build_object('key','cde','count',v_doc_rejected+v_doc_overdue,'penalty',v_pen_cde),
      jsonb_build_object('key','daily_reports','count',v_daily_returned+v_daily_pending,'penalty',v_pen_daily),
      jsonb_build_object('key','schedule','count',case when v_variance is not null and v_variance<0 then round(abs(v_variance)) else 0 end,'penalty',v_pen_schedule)
    )
  );
end $$;
revoke all on function app_private.project_control_metrics(uuid) from public,anon,authenticated;

create or replace function public.project_control_portfolio(p_company_id uuid,p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path='public','app_private','pg_temp' as $$
declare v_projects jsonb;v_team jsonb:='[]'::jsonb;v_trend jsonb:='[]'::jsonb;v_decisions jsonb:='[]'::jsonb;
begin
  if auth.uid() is null or not app_private.is_company_member(p_company_id) or not app_private.user_has_company_permission(auth.uid(),p_company_id,'projects.view') then raise exception 'Permission denied'; end if;

  select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'code',q.code,'name',q.name,'status',q.status,'project_type',q.project_type,'client_name',q.client_name,'manager_user_id',q.manager_user_id,'manager_name',q.manager_name,'planned_start_date',q.planned_start_date,'target_end_date',q.target_end_date,'updated_at',q.updated_at,'metrics',q.metrics) order by (q.metrics->>'score')::numeric asc,q.target_end_date nulls last,q.name),'[]'::jsonb)
  into v_projects
  from (
    select p.*,pr.full_name manager_name,app_private.project_control_metrics(p.id) metrics
    from public.projects p left join public.profiles pr on pr.id=p.manager_user_id
    where p.company_id=p_company_id and p.archived_at is null and p.status<>'archived'
      and app_private.user_has_resource_permission(auth.uid(),p.company_id,'projects.view',p.id,null,null,null)
    order by p.updated_at desc limit greatest(1,least(coalesce(p_limit,100),200))
  ) q;

  if app_private.user_has_company_permission(auth.uid(),p_company_id,'tasks.view_workload') or app_private.user_has_company_permission(auth.uid(),p_company_id,'tasks.manage') then
    select coalesce(jsonb_agg(x order by x.overdue desc,x.open_count desc),'[]'::jsonb) into v_team from (
      select t.owner_user_id user_id,coalesce(p.full_name,'—') name,count(*) filter(where t.status not in('done','cancelled')) open_count,count(*) filter(where t.status not in('done','cancelled') and t.due_at<now()) overdue,count(*) filter(where t.status='blocked') blocked
      from public.tasks t left join public.profiles p on p.id=t.owner_user_id
      where t.company_id=p_company_id and t.owner_user_id is not null and app_private.can_view_task(t.id)
      group by t.owner_user_id,p.full_name having count(*) filter(where t.status not in('done','cancelled'))>0
      order by overdue desc,open_count desc limit 8
    ) x;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('week_start',w.week_start,'tasks_done',w.tasks_done,'issues_opened',w.issues_opened,'issues_closed',w.issues_closed,'documents_added',w.documents_added,'approved_reports',w.approved_reports) order by w.week_start),'[]'::jsonb) into v_trend
  from (
    select g::date week_start,
      (select count(*) from public.tasks t where t.company_id=p_company_id and t.completed_at>=g and t.completed_at<g+interval '7 days' and app_private.can_view_task(t.id)) tasks_done,
      (select count(*) from public.site_field_issues i where i.company_id=p_company_id and i.created_at>=g and i.created_at<g+interval '7 days' and app_private.user_has_resource_permission(auth.uid(),i.company_id,'projects.view',i.project_id,i.site_id,null,null)) issues_opened,
      (select count(*) from public.site_field_issues i where i.company_id=p_company_id and i.closed_at>=g and i.closed_at<g+interval '7 days' and app_private.user_has_resource_permission(auth.uid(),i.company_id,'projects.view',i.project_id,i.site_id,null,null)) issues_closed,
      (select count(*) from public.documents d where d.company_id=p_company_id and d.created_at>=g and d.created_at<g+interval '7 days' and d.state='active' and app_private.user_has_resource_permission(auth.uid(),d.company_id,'files.view',d.project_id,d.site_id,d.folder_id,null)) documents_added,
      (select count(*) from public.site_daily_logs l where l.company_id=p_company_id and l.status='approved' and l.reviewed_at>=g and l.reviewed_at<g+interval '7 days' and app_private.user_has_resource_permission(auth.uid(),l.company_id,'projects.view',l.project_id,l.site_id,null,null)) approved_reports
    from generate_series(date_trunc('week',current_date)::date-interval '35 days',date_trunc('week',current_date)::date,interval '7 days') g
  ) w;

  select coalesce(jsonb_agg(row_to_json(d)::jsonb order by d.severity_rank,d.created_at nulls last) filter(where d.entity_id is not null),'[]'::jsonb) into v_decisions
  from (
    select 'milestone' entity_type,m.id entity_id,m.project_id,null::uuid site_id,m.title,'milestone' action_kind,case when m.status='missed' or (m.due_at<now() and m.status<>'achieved') then 'critical' else 'warning' end severity,case when m.status='missed' then 1 else 2 end severity_rank,m.due_at created_at
    from public.work_milestones m where m.company_id=p_company_id and m.status in('missed','at_risk','planned') and (m.status in('missed','at_risk') or m.due_at<now()) and (m.project_id is null or app_private.user_has_resource_permission(auth.uid(),m.company_id,'projects.view',m.project_id,null,null,null))
    union all
    select 'site_field_issue',i.id,i.project_id,i.site_id,i.title,'field_issue',case when i.severity='critical' then 'critical' else 'warning' end,case when i.severity='critical' then 1 else 2 end,i.created_at from public.site_field_issues i where i.company_id=p_company_id and i.status not in('closed','cancelled') and i.severity in('high','critical') and app_private.user_has_resource_permission(auth.uid(),i.company_id,'projects.view',i.project_id,i.site_id,null,null)
    union all
    select 'site_constraint',c.id,c.project_id,c.site_id,c.title,'constraint',case when c.started_at<now()-interval '7 days' then 'critical' else 'warning' end,case when c.started_at<now()-interval '7 days' then 1 else 2 end,c.started_at from public.site_constraints c where c.company_id=p_company_id and c.status not in('resolved','cancelled') and app_private.user_has_resource_permission(auth.uid(),c.company_id,'projects.view',c.project_id,c.site_id,null,null)
    union all
    select 'site_daily_log',l.id,l.project_id,l.site_id,coalesce(p.name,'')||' — '||l.log_date::text,'daily_report','warning',2,l.updated_at from public.site_daily_logs l join public.projects p on p.id=l.project_id where l.company_id=p_company_id and l.status='returned' and app_private.user_has_resource_permission(auth.uid(),l.company_id,'projects.view',l.project_id,l.site_id,null,null)
  ) d limit 30;

  return jsonb_build_object(
    'generated_at',now(),'projects',v_projects,'team_bottlenecks',v_team,'trend',v_trend,'decisions',v_decisions,
    'summary',jsonb_build_object(
      'projects',jsonb_array_length(v_projects),
      'stable',(select count(*) from jsonb_array_elements(v_projects) j where j#>>'{metrics,band}'='stable'),
      'watch',(select count(*) from jsonb_array_elements(v_projects) j where j#>>'{metrics,band}'='watch'),
      'at_risk',(select count(*) from jsonb_array_elements(v_projects) j where j#>>'{metrics,band}'='at_risk'),
      'critical',(select count(*) from jsonb_array_elements(v_projects) j where j#>>'{metrics,band}'='critical'),
      'decisions',jsonb_array_length(v_decisions)
    ),
    'capabilities',jsonb_build_object('view_workload',app_private.user_has_company_permission(auth.uid(),p_company_id,'tasks.view_workload') or app_private.user_has_company_permission(auth.uid(),p_company_id,'tasks.manage'))
  );
end $$;

create or replace function public.project_control_project(p_project_id uuid)
returns jsonb language plpgsql stable security definer set search_path='public','app_private','pg_temp' as $$
declare p public.projects%rowtype;v_sites jsonb;v_milestones jsonb;v_risks jsonb;v_team jsonb:='[]'::jsonb;v_trend jsonb;v_week date:=date_trunc('week',current_date)::date;
begin
  select * into p from public.projects where id=p_project_id;
  if not found or not app_private.user_has_resource_permission(auth.uid(),p.company_id,'projects.view',p.id,null,null,null) then raise exception 'Permission denied'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',s.id,'code',s.code,'name',s.name,'status',s.status,'target_end_date',s.target_end_date,'manager_user_id',s.manager_user_id,'manager_name',pr.full_name,
    'tasks_open',(select count(*) from public.tasks t where t.site_id=s.id and t.status not in('done','cancelled') and app_private.can_view_task(t.id)),
    'tasks_overdue',(select count(*) from public.tasks t where t.site_id=s.id and t.status not in('done','cancelled') and t.due_at<now() and app_private.can_view_task(t.id)),
    'issues_open',(select count(*) from public.site_field_issues i where i.site_id=s.id and i.status not in('closed','cancelled')),
    'critical_issues',(select count(*) from public.site_field_issues i where i.site_id=s.id and i.status not in('closed','cancelled') and i.severity='critical'),
    'constraints_open',(select count(*) from public.site_constraints c where c.site_id=s.id and c.status not in('resolved','cancelled')),
    'failed_inspections',(select count(*) from public.site_inspections i where i.site_id=s.id and i.status='failed' and i.created_at>=now()-interval '30 days'),
    'cabinets_total',(select count(*) from public.site_cabinets c where c.site_id=s.id and c.archived_at is null),
    'cabinets_complete',(select count(*) from public.site_cabinets c where c.site_id=s.id and c.archived_at is null and c.status='completed'),
    'last_report_status',(select l.status from public.site_daily_logs l where l.site_id=s.id order by l.log_date desc limit 1)
  ) order by (case when s.target_end_date<current_date and coalesce(s.status,'active') not in('completed','archived') then 0 else 1 end),s.name),'[]'::jsonb)
  into v_sites from public.sites s left join public.profiles pr on pr.id=s.manager_user_id
  where s.project_id=p.id and s.archived_at is null and app_private.user_has_resource_permission(auth.uid(),p.company_id,'projects.view',p.id,s.id,null,null);

  select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'title',m.title,'description',m.description,'due_at',m.due_at,'status',m.status,'weight',m.weight,'owner_user_id',m.owner_user_id,'owner_name',pr.full_name,'overdue',m.due_at<now() and m.status not in('achieved','cancelled')) order by m.due_at nulls last,m.title),'[]'::jsonb)
  into v_milestones from public.work_milestones m left join public.profiles pr on pr.id=m.owner_user_id where m.project_id=p.id and app_private.user_has_resource_permission(auth.uid(),p.company_id,'tasks.view',p.id,null,null,null);

  select coalesce(jsonb_agg(x order by x.rank,x.created_at desc),'[]'::jsonb) into v_risks from (
    select 1 rank,'site_field_issue' entity_type,i.id entity_id,i.site_id,i.title,case when i.severity='critical' then 'critical' else 'warning' end severity,i.created_at,coalesce(i.description,'') detail from public.site_field_issues i where i.project_id=p.id and i.status not in('closed','cancelled') and i.severity in('high','critical') and app_private.user_has_resource_permission(auth.uid(),i.company_id,'projects.view',i.project_id,i.site_id,null,null)
    union all select 2,'site_constraint',c.id,c.site_id,c.title,'warning',c.started_at,coalesce(c.impact,c.description,'') from public.site_constraints c where c.project_id=p.id and c.status not in('resolved','cancelled') and app_private.user_has_resource_permission(auth.uid(),c.company_id,'projects.view',c.project_id,c.site_id,null,null)
    union all select 3,'task',t.id,t.site_id,t.title,case when t.status='blocked' or t.priority='urgent' then 'warning' else 'neutral' end,coalesce(t.due_at,t.updated_at),coalesce(t.blocked_reason,'') from public.tasks t where t.project_id=p.id and t.status not in('done','cancelled') and (t.status='blocked' or t.due_at<now()) and app_private.can_view_task(t.id)
    union all select 4,'document',d.id,d.site_id,d.display_name,'warning',coalesce(d.review_due_at,d.updated_at),case when d.control_status='rejected' then 'rejected' else 'overdue_review' end from public.documents d where d.project_id=p.id and d.state='active' and (d.control_status='rejected' or (d.control_status='in_review' and d.review_due_at<now())) and app_private.user_has_resource_permission(auth.uid(),d.company_id,'files.view',d.project_id,d.site_id,d.folder_id,null)
  ) x limit 40;

  if app_private.user_has_company_permission(auth.uid(),p.company_id,'tasks.view_workload') or app_private.user_has_company_permission(auth.uid(),p.company_id,'tasks.manage') then
    select coalesce(jsonb_agg(x order by x.overdue desc,x.open_count desc),'[]'::jsonb) into v_team from (
      select t.owner_user_id user_id,coalesce(pr.full_name,'—') name,count(*) filter(where t.status not in('done','cancelled')) open_count,count(*) filter(where t.status not in('done','cancelled') and t.due_at<now()) overdue,count(*) filter(where t.status='blocked') blocked
      from public.tasks t left join public.profiles pr on pr.id=t.owner_user_id where t.project_id=p.id and t.owner_user_id is not null and app_private.can_view_task(t.id)
      group by t.owner_user_id,pr.full_name having count(*) filter(where t.status not in('done','cancelled'))>0 order by overdue desc,open_count desc limit 10
    ) x;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('week_start',g::date,
    'tasks_done',(select count(*) from public.tasks t where t.project_id=p.id and t.completed_at>=g and t.completed_at<g+interval '7 days' and app_private.can_view_task(t.id)),
    'issues_opened',(select count(*) from public.site_field_issues i where i.project_id=p.id and i.created_at>=g and i.created_at<g+interval '7 days' and app_private.user_has_resource_permission(auth.uid(),i.company_id,'projects.view',i.project_id,i.site_id,null,null)),
    'issues_closed',(select count(*) from public.site_field_issues i where i.project_id=p.id and i.closed_at>=g and i.closed_at<g+interval '7 days' and app_private.user_has_resource_permission(auth.uid(),i.company_id,'projects.view',i.project_id,i.site_id,null,null)),
    'documents_added',(select count(*) from public.documents d where d.project_id=p.id and d.created_at>=g and d.created_at<g+interval '7 days' and d.state='active' and app_private.user_has_resource_permission(auth.uid(),d.company_id,'files.view',d.project_id,d.site_id,d.folder_id,null)),
    'reports_approved',(select count(*) from public.site_daily_logs l where l.project_id=p.id and l.status='approved' and l.reviewed_at>=g and l.reviewed_at<g+interval '7 days')
  ) order by g),'[]'::jsonb) into v_trend from generate_series(v_week-interval '35 days',v_week,interval '7 days') g;

  return jsonb_build_object(
    'project',to_jsonb(p),'manager_name',(select full_name from public.profiles where id=p.manager_user_id),
    'metrics',app_private.project_control_metrics(p.id),'sites',v_sites,'milestones',v_milestones,'risks',v_risks,'team_bottlenecks',v_team,'trend',v_trend,
    'brief',(select to_jsonb(b) from public.project_control_briefs b where b.project_id=p.id and b.week_start=v_week),
    'capabilities',jsonb_build_object('manage',app_private.user_has_resource_permission(auth.uid(),p.company_id,'projects.edit',p.id,null,null,null),'view_workload',app_private.user_has_company_permission(auth.uid(),p.company_id,'tasks.view_workload') or app_private.user_has_company_permission(auth.uid(),p.company_id,'tasks.manage'))
  );
end $$;

create or replace function public.project_control_weekly_brief(p_project_id uuid,p_week_start date default date_trunc('week',current_date)::date)
returns jsonb language plpgsql stable security definer set search_path='public','app_private','pg_temp' as $$
declare p public.projects%rowtype;v_start date:=coalesce(p_week_start,date_trunc('week',current_date)::date);v_end date:=v_start+6;
begin
  select * into p from public.projects where id=p_project_id;
  if not found or not app_private.user_has_resource_permission(auth.uid(),p.company_id,'projects.view',p.id,null,null,null) then raise exception 'Permission denied'; end if;
  return jsonb_build_object(
    'project',jsonb_build_object('id',p.id,'code',p.code,'name',p.name),'week_start',v_start,'week_end',v_end,'metrics',app_private.project_control_metrics(p.id),
    'completed_tasks',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'title',t.title,'site_id',t.site_id,'completed_at',t.completed_at) order by t.completed_at desc) from (select * from public.tasks where project_id=p.id and completed_at>=v_start and completed_at<v_start+7 and app_private.can_view_task(id) order by completed_at desc limit 15)t),'[]'::jsonb),
    'drawings_changed',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'drawing_no',d.drawing_no,'title',d.title,'site_id',d.site_id,'status',d.status,'updated_at',d.updated_at) order by d.updated_at desc) from (select * from public.engineering_drawings where project_id=p.id and archived_at is null and updated_at>=v_start and updated_at<v_start+7 and app_private.user_has_resource_permission(auth.uid(),company_id,'drawings.view',project_id,site_id,folder_id,id) order by updated_at desc limit 12)d),'[]'::jsonb),
    'issues_closed',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'title',i.title,'site_id',i.site_id,'severity',i.severity,'closed_at',i.closed_at) order by i.closed_at desc) from (select * from public.site_field_issues where project_id=p.id and closed_at>=v_start and closed_at<v_start+7 order by closed_at desc limit 12)i),'[]'::jsonb),
    'decisions_needed',coalesce((select jsonb_agg(x order by x.rank,x.created_at) from (
      select 1 rank,'site_field_issue' entity_type,i.id entity_id,i.site_id,i.title,i.created_at from public.site_field_issues i where i.project_id=p.id and i.status not in('closed','cancelled') and i.severity in('critical','high') and app_private.user_has_resource_permission(auth.uid(),i.company_id,'projects.view',i.project_id,i.site_id,null,null)
      union all select 2,'site_constraint',c.id,c.site_id,c.title,c.started_at from public.site_constraints c where c.project_id=p.id and c.status not in('resolved','cancelled') and app_private.user_has_resource_permission(auth.uid(),c.company_id,'projects.view',c.project_id,c.site_id,null,null)
      union all select 3,'task',t.id,t.site_id,t.title,coalesce(t.due_at,t.updated_at) from public.tasks t where t.project_id=p.id and t.status not in('done','cancelled') and (t.status='blocked' or t.due_at<now()) and app_private.can_view_task(t.id)
      limit 20
    )x),'[]'::jsonb),
    'next_week',coalesce((select jsonb_agg(x order by x.due_at) from (
      select 'milestone' entity_type,m.id entity_id,null::uuid site_id,m.title,m.due_at from public.work_milestones m where m.project_id=p.id and m.status not in('achieved','cancelled') and m.due_at>=v_start+7 and m.due_at<v_start+14
      union all select 'task',t.id,t.site_id,t.title,t.due_at from public.tasks t where t.project_id=p.id and t.status not in('done','cancelled') and t.due_at>=v_start+7 and t.due_at<v_start+14 and app_private.can_view_task(t.id)
      limit 25
    )x),'[]'::jsonb),
    'authored',(select to_jsonb(b) from public.project_control_briefs b where b.project_id=p.id and b.week_start=v_start),
    'can_manage',app_private.user_has_resource_permission(auth.uid(),p.company_id,'projects.edit',p.id,null,null,null)
  );
end $$;

create or replace function public.save_project_control_brief(p_project_id uuid,p_week_start date,p_payload jsonb,p_submit boolean default false)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare p public.projects%rowtype;b public.project_control_briefs%rowtype;existing public.project_control_briefs%rowtype;v_start date:=coalesce(p_week_start,date_trunc('week',current_date)::date);
begin
  select * into p from public.projects where id=p_project_id;
  if not found or not app_private.user_has_resource_permission(auth.uid(),p.company_id,'projects.edit',p.id,null,null,null) then raise exception 'Permission denied'; end if;
  select * into existing from public.project_control_briefs where project_id=p.id and week_start=v_start;
  if found and existing.status in('submitted','approved') then raise exception 'Brief is locked for review'; end if;
  insert into public.project_control_briefs(company_id,project_id,week_start,status,executive_summary,decisions_needed,next_week_plan,management_note,submitted_at,submitted_by,created_by,updated_by)
  values(p.company_id,p.id,v_start,case when p_submit then 'submitted' else 'draft' end,nullif(trim(p_payload->>'executive_summary'),''),nullif(trim(p_payload->>'decisions_needed'),''),nullif(trim(p_payload->>'next_week_plan'),''),nullif(trim(p_payload->>'management_note'),''),case when p_submit then now() else null end,case when p_submit then auth.uid() else null end,auth.uid(),auth.uid())
  on conflict(project_id,week_start) do update set executive_summary=excluded.executive_summary,decisions_needed=excluded.decisions_needed,next_week_plan=excluded.next_week_plan,management_note=excluded.management_note,status=case when p_submit then 'submitted' else public.project_control_briefs.status end,submitted_at=case when p_submit then now() else public.project_control_briefs.submitted_at end,submitted_by=case when p_submit then auth.uid() else public.project_control_briefs.submitted_by end,updated_by=auth.uid(),updated_at=now()
  returning * into b;
  insert into public.project_control_brief_events(company_id,brief_id,event_type,actor_id,note) values(p.company_id,b.id,case when p_submit then 'submitted' else 'saved' end,auth.uid(),nullif(trim(p_payload->>'management_note'),''));
  return to_jsonb(b);
end $$;

create or replace function public.review_project_control_brief(p_brief_id uuid,p_decision text,p_note text default null)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare b public.project_control_briefs%rowtype;
begin
  select * into b from public.project_control_briefs where id=p_brief_id;
  if not found or not app_private.user_has_resource_permission(auth.uid(),b.company_id,'projects.edit',b.project_id,null,null,null) then raise exception 'Permission denied'; end if;
  if b.status<>'submitted' then raise exception 'Brief is not awaiting review'; end if;
  if p_decision not in('approved','returned') then raise exception 'Invalid decision'; end if;
  if p_decision='returned' and coalesce(trim(p_note),'')='' then raise exception 'Return note is required'; end if;
  update public.project_control_briefs set status=p_decision,reviewed_at=now(),reviewed_by=auth.uid(),reviewer_note=nullif(trim(p_note),''),updated_by=auth.uid(),updated_at=now() where id=b.id returning * into b;
  insert into public.project_control_brief_events(company_id,brief_id,event_type,actor_id,note) values(b.company_id,b.id,p_decision,auth.uid(),nullif(trim(p_note),''));
  return to_jsonb(b);
end $$;

create or replace function public.link_project_control_brief_document(p_brief_id uuid,p_document_id uuid)
returns jsonb language plpgsql security definer set search_path='public','app_private','pg_temp' as $$
declare b public.project_control_briefs%rowtype;d public.documents%rowtype;
begin
  select * into b from public.project_control_briefs where id=p_brief_id;
  if not found or not app_private.user_has_resource_permission(auth.uid(),b.company_id,'projects.edit',b.project_id,null,null,null) then raise exception 'Permission denied'; end if;
  select * into d from public.documents where id=p_document_id and project_id=b.project_id and state='active';
  if not found then raise exception 'Invalid report document'; end if;
  update public.project_control_briefs set report_document_id=d.id,updated_by=auth.uid(),updated_at=now() where id=b.id returning * into b;
  insert into public.project_control_brief_events(company_id,brief_id,event_type,actor_id,metadata) values(b.company_id,b.id,'cde_linked',auth.uid(),jsonb_build_object('document_id',d.id));
  return to_jsonb(b);
end $$;

create or replace function public.resolve_project_control_folder(p_project_id uuid)
returns uuid language plpgsql stable security definer set search_path='public','app_private','pg_temp' as $$
declare p public.projects%rowtype;v_id uuid;
begin
  select * into p from public.projects where id=p_project_id;
  if not found or not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.view',p.id,null,null,null) then raise exception 'Permission denied'; end if;
  select f.id into v_id from public.folders f where f.project_id=p.id and f.site_id is null and f.trashed_at is null and f.hidden_at is null
  order by case when lower(coalesce(f.name,'')) similar to '%(report|general|management|control)%' or coalesce(f.name,'') similar to '%(تقارير|عام|إدارة|متابعة)%' then 0 else 1 end,f.depth nulls first,f.sort_order,f.created_at limit 1;
  return v_id;
end $$;

revoke all on function public.project_control_portfolio(uuid,integer),public.project_control_project(uuid),public.project_control_weekly_brief(uuid,date),public.save_project_control_brief(uuid,date,jsonb,boolean),public.review_project_control_brief(uuid,text,text),public.link_project_control_brief_document(uuid,uuid),public.resolve_project_control_folder(uuid) from public,anon;
grant execute on function public.project_control_portfolio(uuid,integer),public.project_control_project(uuid),public.project_control_weekly_brief(uuid,date),public.save_project_control_brief(uuid,date,jsonb,boolean),public.review_project_control_brief(uuid,text,text),public.link_project_control_brief_document(uuid,uuid),public.resolve_project_control_folder(uuid) to authenticated;

commit;
