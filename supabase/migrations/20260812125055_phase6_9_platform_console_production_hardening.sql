begin;

-- Platform console production hardening:
-- 1) return every editable company/branding field so edit forms never blank/erase existing values,
-- 2) aggregate expensive counts once per company instead of correlated subqueries,
-- 3) audit entitlement overrides and validate their targets.

drop function if exists public.platform_company_directory();
create function public.platform_company_directory()
returns table(
  company_id uuid,
  company_name text,
  legal_name text,
  company_slug text,
  short_code text,
  official_email text,
  phone text,
  whatsapp text,
  country_code text,
  city text,
  address text,
  website text,
  industry text,
  registration_number text,
  tax_number text,
  primary_contact_name text,
  primary_contact_email text,
  primary_contact_phone text,
  billing_contact_name text,
  billing_contact_email text,
  billing_contact_phone text,
  technical_contact_name text,
  technical_contact_email text,
  technical_contact_phone text,
  internal_notes text,
  timezone text,
  default_locale text,
  status public.company_access_status,
  plan_id uuid,
  plan_code text,
  plan_name_ar text,
  plan_name_en text,
  member_count bigint,
  project_count bigint,
  storage_bytes bigint,
  max_members integer,
  max_projects integer,
  max_storage_bytes bigint,
  trial_ends_at timestamptz,
  current_period_ends_at timestamptz,
  created_at timestamptz,
  billing_cycle text,
  agreed_price numeric,
  currency text,
  payment_status text,
  last_payment_at timestamptz,
  next_payment_at timestamptz,
  onboarding_status text,
  owner_user_id uuid,
  owner_name text,
  owner_email text,
  owner_phone text,
  owner_must_change_password boolean,
  owner_password_expires_at timestamptz,
  owner_first_login_at timestamptz,
  branding_app_name text,
  branding_tagline text,
  branding_logo_path text,
  branding_favicon_path text,
  branding_cover_path text,
  branding_primary_color text,
  branding_accent_color text,
  branding_neutral_color text,
  branding_default_theme text,
  branding_sidebar_style text,
  branding_radius_style text,
  branding_density text,
  branding_logo_shape text
)
language sql
stable
security definer
set search_path='public','auth','pg_temp'
as $$
with
member_counts as materialized (
  select m.company_id,count(*)::bigint member_count
  from public.company_memberships m
  where m.status='active'
  group by m.company_id
),
project_counts as materialized (
  select p.company_id,count(*)::bigint project_count
  from public.projects p
  where p.archived_at is null
  group by p.company_id
),
storage_counts as materialized (
  select v.company_id,coalesce(sum(v.size_bytes),0)::bigint storage_bytes
  from public.document_versions v
  where v.upload_state='ready'
  group by v.company_id
),
owner_members as materialized (
  select distinct on(m.company_id) m.company_id,m.user_id
  from public.company_memberships m
  join public.roles r on r.id=m.role_id and r.slug='owner'
  order by m.company_id,m.created_at asc
)
select
  c.id,c.name,c.legal_name,c.slug,c.short_code,c.official_email,c.phone,c.whatsapp,c.country_code,c.city,
  c.address,c.website,c.industry,c.registration_number,c.tax_number,
  c.primary_contact_name,c.primary_contact_email,c.primary_contact_phone,
  c.billing_contact_name,c.billing_contact_email,c.billing_contact_phone,
  c.technical_contact_name,c.technical_contact_email,c.technical_contact_phone,
  c.internal_notes,c.timezone,c.default_locale,
  cs.status,sp.id,sp.code,sp.name_ar,sp.name_en,
  coalesce(mc.member_count,0),coalesce(pc.project_count,0),coalesce(sc.storage_bytes,0),
  coalesce(cs.max_members_override,sp.max_members),coalesce(cs.max_projects_override,sp.max_projects),coalesce(cs.max_storage_bytes_override,sp.max_storage_bytes),
  cs.trial_ends_at,cs.current_period_ends_at,c.created_at,
  cs.billing_cycle,cs.agreed_price,cs.currency,cs.payment_status,cs.last_payment_at,cs.next_payment_at,c.onboarding_status,
  om.user_id,owner_profile.full_name,owner_auth.email,owner_profile.phone,
  coalesce(owner_security.must_change_password,false),owner_security.temporary_password_expires_at,owner_security.first_login_completed_at,
  brand.app_name,brand.tagline,brand.logo_path,brand.favicon_path,brand.cover_path,
  brand.primary_color,brand.accent_color,brand.neutral_color,brand.default_theme,brand.sidebar_style,brand.radius_style,brand.density,brand.logo_shape
from public.companies c
join public.company_subscriptions cs on cs.company_id=c.id
join public.service_plans sp on sp.id=cs.plan_id
left join member_counts mc on mc.company_id=c.id
left join project_counts pc on pc.company_id=c.id
left join storage_counts sc on sc.company_id=c.id
left join owner_members om on om.company_id=c.id
left join public.profiles owner_profile on owner_profile.id=om.user_id
left join auth.users owner_auth on owner_auth.id=om.user_id
left join public.account_security owner_security on owner_security.user_id=om.user_id
left join public.company_branding brand on brand.company_id=c.id
where app_private.is_platform_admin()
order by c.created_at desc;
$$;

revoke all on function public.platform_company_directory() from public,anon;
grant execute on function public.platform_company_directory() to authenticated;

create or replace function public.set_company_entitlement_override(
  p_company_id uuid,
  p_entitlement_key text,
  p_enabled boolean,
  p_limits jsonb default '{}'::jsonb,
  p_reason text default null
) returns public.company_entitlement_overrides
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  o public.company_entitlement_overrides;
  v_key text:=trim(coalesce(p_entitlement_key,''));
  v_limits jsonb:=coalesce(p_limits,'{}'::jsonb);
  v_reason text:=nullif(trim(coalesce(p_reason,'')),'');
begin
  if not app_private.is_platform_admin() then raise exception 'Platform administrator permission required'; end if;
  if not exists(select 1 from public.companies where id=p_company_id) then raise exception 'Company not found'; end if;
  if v_key='' or not exists(select 1 from public.entitlements where key=v_key) then raise exception 'Unknown entitlement key'; end if;
  if jsonb_typeof(v_limits)<>'object' then raise exception 'Entitlement limits must be a JSON object'; end if;
  if char_length(coalesce(v_reason,''))>1000 then raise exception 'Entitlement override reason is too long'; end if;

  insert into public.company_entitlement_overrides(company_id,entitlement_key,enabled,limits,reason,updated_by)
  values(p_company_id,v_key,p_enabled,v_limits,v_reason,auth.uid())
  on conflict(company_id,entitlement_key) do update set
    enabled=excluded.enabled,
    limits=excluded.limits,
    reason=excluded.reason,
    updated_by=auth.uid(),
    updated_at=now()
  returning * into o;

  insert into public.platform_audit_events(actor_id,company_id,action,metadata)
  values(auth.uid(),p_company_id,'platform.company_entitlement_override',jsonb_build_object(
    'entitlement_key',v_key,
    'enabled',p_enabled,
    'limits',v_limits,
    'reason',v_reason
  ));
  return o;
end;
$$;

revoke all on function public.set_company_entitlement_override(uuid,text,boolean,jsonb,text) from public,anon;
grant execute on function public.set_company_entitlement_override(uuid,text,boolean,jsonb,text) to authenticated;

commit;
