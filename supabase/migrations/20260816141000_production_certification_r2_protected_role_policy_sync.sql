begin;

create or replace function app_private.sync_company_protected_role_permissions(p_company_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_roles integer:=0;
  v_permissions integer:=0;
begin
  if not exists(select 1 from public.companies where id=p_company_id) then
    raise exception 'Company not found';
  end if;

  if exists(
    select 1
    from (values ('owner'),('admin'),('manager'),('engineer'),('supervisor'),('viewer')) expected(slug)
    left join public.roles r
      on r.company_id=p_company_id
     and r.slug=expected.slug
     and r.is_protected
    group by expected.slug
    having count(r.id)<>1
  ) then
    raise exception 'Protected role baseline is incomplete or duplicated for company %',p_company_id;
  end if;

  delete from public.role_permissions rp
  using public.roles r
  where rp.role_id=r.id
    and r.company_id=p_company_id
    and r.is_protected
    and r.slug in ('owner','admin','manager','engineer','supervisor','viewer');

  insert into public.role_permissions(role_id,permission_key,allowed)
  select r.id,p.key,true
  from public.roles r
  cross join public.permissions p
  where r.company_id=p_company_id
    and r.is_protected
    and r.slug in ('owner','admin','manager','engineer','supervisor','viewer')
    and (
      r.slug='owner'
      or (r.slug='admin' and p.key<>'company.manage')
      or (r.slug='manager' and p.key=any(array[
        'company.view','members.view','roles.view','projects.view','projects.create','projects.edit','projects.archive','audit.view',
        'files.view','files.upload','files.create_folder','files.rename','files.move','files.archive','files.restore','files.download','files.manage',
        'search.use','notifications.view','tasks.view','tasks.view_all','tasks.create','tasks.assign','tasks.edit','tasks.manage','tasks.comment',
        'tasks.attach','tasks.complete','tasks.claim','tasks.recurring','drawings.view','drawings.create','drawings.edit','drawings.publish','drawings.compare',
        'drawings.export','drawings.review','boq.view','boq.edit','catalog.manage','branding.view','roles.templates.use'
      ]::text[]))
      or (r.slug='engineer' and p.key=any(array[
        'company.view','members.view','projects.view','files.view','files.upload','files.create_folder','files.rename','files.move','files.download',
        'search.use','notifications.view','tasks.view','tasks.create','tasks.edit','tasks.comment','tasks.attach','tasks.complete','tasks.claim',
        'drawings.view','drawings.create','drawings.edit','drawings.compare','drawings.export','drawings.review','boq.view','boq.edit','branding.view'
      ]::text[]))
      or (r.slug='supervisor' and p.key=any(array[
        'company.view','members.view','projects.view','files.view','files.upload','files.create_folder','files.download','search.use','notifications.view',
        'tasks.view','tasks.create','tasks.edit','tasks.comment','tasks.attach','tasks.complete','tasks.claim','drawings.view','drawings.create','drawings.edit',
        'drawings.compare','drawings.export','drawings.review','boq.view','boq.edit','branding.view'
      ]::text[]))
      or (r.slug='viewer' and p.key=any(array[
        'company.view','projects.view','files.view','files.download','search.use','notifications.view','tasks.view','drawings.view','drawings.export','boq.view','branding.view'
      ]::text[]))
    );

  select count(*) into v_roles
  from public.roles
  where company_id=p_company_id
    and is_protected
    and slug in ('owner','admin','manager','engineer','supervisor','viewer');

  select count(*) into v_permissions
  from public.role_permissions rp
  join public.roles r on r.id=rp.role_id
  where r.company_id=p_company_id
    and r.is_protected
    and r.slug in ('owner','admin','manager','engineer','supervisor','viewer')
    and rp.allowed;

  return jsonb_build_object('company_id',p_company_id,'protected_roles',v_roles,'allowed_permissions',v_permissions);
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
