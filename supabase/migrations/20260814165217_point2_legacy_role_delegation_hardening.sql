-- Point 2 security hardening: keep legacy role RPC compatibility while enforcing
-- the same delegation and protected-role invariants as the Draft -> Impact -> Publish path.

create or replace function public.create_company_role(
  p_company_id uuid,
  p_name_ar text,
  p_name_en text,
  p_slug text,
  p_description_ar text default null,
  p_description_en text default null,
  p_color text default '#4f46e5',
  p_icon text default 'shield',
  p_permission_keys text[] default array[]::text[],
  p_template_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare v_id uuid; v_permissions text[]:=coalesce(p_permission_keys,array[]::text[]);
begin
  if not (app_private.has_company_permission(p_company_id,'roles.create') or app_private.has_company_permission(p_company_id,'roles.manage') or app_private.is_platform_admin()) then
    raise exception 'Role creation permission denied';
  end if;
  if trim(p_name_ar)='' or trim(p_name_en)='' or p_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception 'Invalid role details';
  end if;
  if exists(select 1 from unnest(v_permissions) k where not exists(select 1 from public.permissions p where p.key=k)) then
    raise exception 'Invalid permission key';
  end if;
  if not app_private.can_delegate_permissions(p_company_id,v_permissions) then
    raise exception 'You cannot grant permissions that you do not hold';
  end if;

  insert into public.roles(company_id,name_ar,name_en,slug,description_ar,description_en,color,icon,is_default,is_protected,source_template_id,created_by)
  values(p_company_id,trim(p_name_ar),trim(p_name_en),lower(trim(p_slug)),nullif(trim(p_description_ar),''),nullif(trim(p_description_en),''),p_color,p_icon,false,false,p_template_id,auth.uid())
  returning id into v_id;

  insert into public.role_permissions(role_id,permission_key,allowed)
  select v_id,key,true from unnest(v_permissions) key on conflict do nothing;

  insert into public.audit_events(company_id,actor_id,action,entity_type,entity_id,metadata)
  values(p_company_id,auth.uid(),'role.created','role',v_id,jsonb_build_object('slug',p_slug,'template_id',p_template_id));
  return v_id;
end $$;

create or replace function public.update_company_role(
  p_role_id uuid,
  p_name_ar text,
  p_name_en text,
  p_description_ar text,
  p_description_en text,
  p_color text,
  p_icon text,
  p_permission_keys text[]
)
returns void
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare r public.roles%rowtype; v_permissions text[]:=coalesce(p_permission_keys,array[]::text[]);
begin
  select * into r from public.roles where id=p_role_id for update;
  if not found then raise exception 'Role not found'; end if;
  if r.is_protected or r.slug='owner' then raise exception 'Protected role cannot be edited'; end if;
  if not (app_private.has_company_permission(r.company_id,'roles.manage') or app_private.is_platform_admin()) then
    raise exception 'Role management permission denied';
  end if;
  if exists(select 1 from unnest(v_permissions) k where not exists(select 1 from public.permissions p where p.key=k)) then
    raise exception 'Invalid permission key';
  end if;
  if not app_private.can_delegate_permissions(r.company_id,v_permissions) then
    raise exception 'You cannot grant permissions that you do not hold';
  end if;

  update public.roles
  set name_ar=trim(p_name_ar),name_en=trim(p_name_en),description_ar=nullif(trim(p_description_ar),''),
      description_en=nullif(trim(p_description_en),''),color=p_color,icon=p_icon,updated_at=now()
  where id=p_role_id;

  delete from public.role_permissions where role_id=p_role_id;
  insert into public.role_permissions(role_id,permission_key,allowed)
  select p_role_id,key,true from unnest(v_permissions) key;

  insert into public.audit_events(company_id,actor_id,action,entity_type,entity_id,metadata)
  values(r.company_id,auth.uid(),'role.updated','role',p_role_id,jsonb_build_object('permissions',cardinality(v_permissions)));
end $$;

create or replace function public.replace_role_permissions(p_role_id uuid,p_permission_keys text[])
returns void
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_company_id uuid;
  v_slug text;
  v_is_protected boolean;
  v_permissions text[]:=coalesce(p_permission_keys,array[]::text[]);
begin
  select company_id,slug,is_protected
  into v_company_id,v_slug,v_is_protected
  from public.roles
  where id=p_role_id
  for update;

  if v_company_id is null then raise exception 'Role not found'; end if;
  if not (app_private.has_company_permission(v_company_id,'roles.manage') or app_private.is_platform_admin()) then raise exception 'Permission denied'; end if;
  if v_is_protected or v_slug='owner' then raise exception 'Protected role permissions are fixed'; end if;
  if exists(select 1 from unnest(v_permissions) k where not exists(select 1 from public.permissions p where p.key=k)) then
    raise exception 'Invalid permission key';
  end if;
  if not app_private.can_delegate_permissions(v_company_id,v_permissions) then
    raise exception 'You cannot grant permissions that you do not hold';
  end if;

  delete from public.role_permissions where role_id=p_role_id;
  insert into public.role_permissions(role_id,permission_key,allowed)
  select p_role_id,k,true from unnest(v_permissions) k;

  insert into public.audit_events(company_id,actor_id,action,entity_type,entity_id,metadata)
  values(v_company_id,auth.uid(),'role.permissions_replaced','role',p_role_id,jsonb_build_object('permissions',v_permissions));
end $$;

create or replace function public.save_company_role_definition(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_role public.roles%rowtype;
  v_role_id uuid:=nullif(p_payload->>'role_id','')::uuid;
  v_company_id uuid:=nullif(p_payload->>'company_id','')::uuid;
  v_permissions text[]:=array[]::text[];
  v_count integer:=0;
  v_is_new boolean:=v_role_id is null;
  v_slug text;
  v_color text:=coalesce(nullif(p_payload->>'color',''),'#4f46e5');
  v_icon text:=coalesce(nullif(trim(p_payload->>'icon'),''),'shield');
begin
  select coalesce(array_agg(distinct value order by value),array[]::text[])
  into v_permissions
  from jsonb_array_elements_text(coalesce(p_payload->'permission_keys','[]'::jsonb));

  if exists(select 1 from unnest(v_permissions) k left join public.permissions p on p.key=k where p.key is null) then raise exception 'Unknown permission key'; end if;
  if cardinality(v_permissions)=0 and coalesce((p_payload->>'allow_empty')::boolean,false)=false then raise exception 'Select at least one permission'; end if;
  if v_color !~ '^#[0-9A-Fa-f]{6}$' then raise exception 'Invalid role color'; end if;
  if char_length(v_icon)>40 then raise exception 'Invalid role icon'; end if;

  if v_is_new then
    if v_company_id is null then raise exception 'Company is required'; end if;
    if not (app_private.has_company_permission(v_company_id,'roles.create') or app_private.has_company_permission(v_company_id,'roles.manage') or app_private.is_platform_admin()) then raise exception 'Role creation permission denied'; end if;
    v_slug:=lower(trim(coalesce(p_payload->>'slug','')));
    if trim(coalesce(p_payload->>'name_ar',''))='' or trim(coalesce(p_payload->>'name_en',''))='' or v_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then raise exception 'Invalid role details'; end if;
  else
    select * into v_role from public.roles where id=v_role_id for update;
    if not found then raise exception 'Role not found'; end if;
    if v_role.is_protected or v_role.slug='owner' then raise exception 'Protected role cannot be edited'; end if;
    v_company_id:=v_role.company_id;
    if not (app_private.has_company_permission(v_company_id,'roles.manage') or app_private.is_platform_admin()) then raise exception 'Role management permission denied'; end if;
  end if;

  if not app_private.can_delegate_permissions(v_company_id,v_permissions) then raise exception 'You cannot grant permissions that you do not hold'; end if;

  if v_is_new then
    insert into public.roles(company_id,name_ar,name_en,slug,description_ar,description_en,color,icon,is_default,is_protected,source_template_id,created_by)
    values(v_company_id,trim(p_payload->>'name_ar'),trim(p_payload->>'name_en'),v_slug,
           nullif(trim(coalesce(p_payload->>'description_ar','')),''),
           nullif(trim(coalesce(p_payload->>'description_en','')),''),
           v_color,v_icon,false,false,nullif(p_payload->>'template_id','')::uuid,auth.uid())
    returning * into v_role;
    v_role_id:=v_role.id;
  else
    update public.roles
    set name_ar=trim(coalesce(p_payload->>'name_ar',name_ar)),
        name_en=trim(coalesce(p_payload->>'name_en',name_en)),
        description_ar=case when p_payload ? 'description_ar' then nullif(trim(coalesce(p_payload->>'description_ar','')),'') else description_ar end,
        description_en=case when p_payload ? 'description_en' then nullif(trim(coalesce(p_payload->>'description_en','')),'') else description_en end,
        color=v_color,icon=v_icon,updated_at=now()
    where id=v_role_id
    returning * into v_role;
  end if;

  delete from public.role_permissions where role_id=v_role_id;
  insert into public.role_permissions(role_id,permission_key,allowed)
  select v_role_id,k,true from unnest(v_permissions) k;
  get diagnostics v_count=row_count;

  insert into public.audit_events(company_id,actor_id,action,entity_type,entity_id,metadata)
  values(v_company_id,auth.uid(),case when v_is_new then 'role.created' else 'role.updated' end,'role',v_role_id,
         jsonb_build_object('permissions',v_count,'permission_keys',to_jsonb(v_permissions),'slug',v_role.slug,'source','organization_control_center'));

  return jsonb_build_object('ok',true,'role_id',v_role_id,'permission_count',v_count,'permission_keys',to_jsonb(v_permissions),'role',to_jsonb(v_role));
end $$;
