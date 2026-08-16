begin;

create or replace function app_private.protected_role_permission_keys(p_slug text)
returns text[]
language sql
stable
security definer
set search_path='public','pg_temp'
as $$
  select case lower(trim(coalesce(p_slug,'')))
    when 'owner' then (
      select coalesce(array_agg(p.key order by p.key),array[]::text[])
      from public.permissions p
    )
    when 'admin' then (
      select coalesce(array_agg(p.key order by p.key),array[]::text[])
      from public.permissions p
      where p.key<>'company.manage'
    )
    when 'manager' then array[
      'company.view','members.view','roles.view','projects.view','projects.create','projects.edit','projects.archive','audit.view',
      'files.view','files.upload','files.create_folder','files.rename','files.move','files.archive','files.restore','files.download','files.manage',
      'search.use','notifications.view',
      'tasks.view','tasks.view_all','tasks.create','tasks.assign','tasks.edit','tasks.complete','tasks.claim','tasks.comment','tasks.attach','tasks.manage',
      'drawings.view','drawings.create','drawings.edit','drawings.publish','drawings.compare','drawings.export','drawings.review','boq.view','boq.edit','catalog.manage',
      'branding.view','roles.templates.use',
      'tasks.approve','tasks.manage_templates','tasks.manage_milestones','tasks.manage_automations','tasks.view_workload'
    ]::text[]
    when 'engineer' then array[
      'company.view','members.view','projects.view',
      'files.view','files.upload','files.create_folder','files.rename','files.move','files.download','search.use','notifications.view',
      'tasks.view','tasks.create','tasks.edit','tasks.complete','tasks.claim','tasks.comment','tasks.attach',
      'drawings.view','drawings.create','drawings.edit','drawings.compare','drawings.export','drawings.review','boq.view','boq.edit',
      'branding.view','roles.templates.use'
    ]::text[]
    when 'supervisor' then array[
      'company.view','members.view','projects.view',
      'files.view','files.upload','files.create_folder','files.download','search.use','notifications.view',
      'tasks.view','tasks.create','tasks.edit','tasks.complete','tasks.claim','tasks.comment','tasks.attach',
      'drawings.view','drawings.create','drawings.edit','drawings.compare','drawings.export','drawings.review','boq.view','boq.edit',
      'branding.view','roles.templates.use'
    ]::text[]
    when 'viewer' then array[
      'company.view','projects.view','files.view','files.download','search.use','notifications.view','tasks.view',
      'drawings.view','drawings.export','boq.view','branding.view','roles.templates.use'
    ]::text[]
    else array[]::text[]
  end;
$$;

revoke all on function app_private.protected_role_permission_keys(text)
from public,anon,authenticated;

create or replace function app_private.sync_company_protected_role_permissions(p_company_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_slug text;
  v_keys text[];
  v_expected integer;
  v_actual integer;
  v_counts jsonb:='{}'::jsonb;
begin
  if not exists(select 1 from public.companies where id=p_company_id) then
    raise exception 'Company not found';
  end if;

  if (select count(*) from public.permissions)<>55 then
    raise exception 'Protected role policy certification expects exactly 55 permissions; catalog changed';
  end if;

  if exists(select 1 from public.permissions where key='tasks.recurring') then
    raise exception 'Deprecated/non-catalog task permission tasks.recurring must not exist';
  end if;

  if exists(
    select 1
    from (values ('owner'),('admin'),('manager'),('engineer'),('supervisor'),('viewer')) expected(slug)
    left join public.roles r
      on r.company_id=p_company_id
     and r.slug=expected.slug
     and r.is_protected=true
    group by expected.slug
    having count(r.id)<>1
  ) then
    raise exception 'Protected role baseline is incomplete or duplicated for company %',p_company_id;
  end if;

  for v_slug,v_expected in
    select * from (values
      ('owner',55),('admin',54),('manager',46),('engineer',28),('supervisor',26),('viewer',12)
    ) x(slug,expected_count)
  loop
    v_keys:=app_private.protected_role_permission_keys(v_slug);
    if cardinality(v_keys)<>v_expected then
      raise exception 'Canonical policy count mismatch for role %: expected %, got %',v_slug,v_expected,cardinality(v_keys);
    end if;
    if exists(
      select 1 from unnest(v_keys) k
      left join public.permissions p on p.key=k
      where p.key is null
    ) then
      raise exception 'Canonical policy contains an unknown permission for role %',v_slug;
    end if;
  end loop;

  delete from public.role_permissions rp
  using public.roles r
  where rp.role_id=r.id
    and r.company_id=p_company_id
    and r.is_protected=true
    and r.slug in ('owner','admin','manager','engineer','supervisor','viewer');

  insert into public.role_permissions(role_id,permission_key,allowed)
  select r.id,k,true
  from public.roles r
  cross join lateral unnest(app_private.protected_role_permission_keys(r.slug)) k
  where r.company_id=p_company_id
    and r.is_protected=true
    and r.slug in ('owner','admin','manager','engineer','supervisor','viewer');

  for v_slug,v_expected in
    select * from (values
      ('owner',55),('admin',54),('manager',46),('engineer',28),('supervisor',26),('viewer',12)
    ) x(slug,expected_count)
  loop
    select count(*) into v_actual
    from public.role_permissions rp
    join public.roles r on r.id=rp.role_id
    where r.company_id=p_company_id
      and r.is_protected=true
      and r.slug=v_slug
      and rp.allowed=true;
    if v_actual<>v_expected then
      raise exception 'Protected role sync mismatch for %: expected %, got %',v_slug,v_expected,v_actual;
    end if;
    v_counts:=v_counts||jsonb_build_object(v_slug,v_actual);
  end loop;

  return jsonb_build_object(
    'company_id',p_company_id,
    'permission_counts',v_counts,
    'policy_version','r2.1-cumulative'
  );
end;
$$;

revoke all on function app_private.sync_company_protected_role_permissions(uuid)
from public,anon,authenticated;

create or replace function app_private.seed_company_roles(p_company_id uuid)
returns table(owner_role_id uuid)
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_owner uuid;
begin
  insert into public.roles(company_id,name_ar,name_en,slug,is_default,is_protected)
  values(p_company_id,'صاحب الشركة','Owner','owner',true,true)
  returning id into v_owner;

  insert into public.roles(company_id,name_ar,name_en,slug,is_default,is_protected) values
    (p_company_id,'مدير النظام','Admin','admin',true,true),
    (p_company_id,'مدير','Manager','manager',true,true),
    (p_company_id,'مهندس','Engineer','engineer',true,true),
    (p_company_id,'مشرف موقع','Site Supervisor','supervisor',true,true),
    (p_company_id,'مشاهد','Viewer','viewer',true,true);

  perform app_private.sync_company_protected_role_permissions(p_company_id);
  owner_role_id:=v_owner;
  return next;
end;
$$;

revoke all on function app_private.seed_company_roles(uuid)
from public,anon,authenticated;

do $$
declare
  v_company uuid;
begin
  for v_company in select id from public.companies loop
    perform app_private.sync_company_protected_role_permissions(v_company);
  end loop;
end;
$$;

commit;
