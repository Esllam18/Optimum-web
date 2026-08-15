-- Optimum 6.9.1 — Core Point 9–10 hardening
-- Keep future site claim packages aligned with the clarified non-financial package scope,
-- and make explicit document classification semantics predictable.
begin;

create or replace function app_private.ensure_default_site_claim_package(p_site_id uuid,p_actor uuid)
returns uuid language plpgsql security definer set search_path='public','app_private','pg_temp'
as $$
declare s public.sites%rowtype; v_package uuid;
begin
  select * into s from public.sites where id=p_site_id;
  if not found then raise exception 'Site not found'; end if;

  select id into v_package
  from public.site_claim_packages
  where site_id=s.id and claim_type='final' and status<>'archived'
  order by created_at limit 1;

  if v_package is null then
    insert into public.site_claim_packages(company_id,project_id,site_id,package_no,title,claim_type,status,created_by)
    values(
      s.company_id,
      s.project_id,
      s.id,
      coalesce(nullif(s.code,''),left(s.id::text,8))||'-FINAL',
      'Site Claim Package',
      'final',
      'collecting',
      p_actor
    ) returning id into v_package;
  end if;

  -- Older package keys remain optional if they already exist, but are not part of the
  -- current required site-claim definition.
  update public.site_claim_requirements
  set is_required=false, updated_at=now()
  where package_id=v_package
    and requirement_key in('contract','sketches','handover_certificate','approvals','photos');

  insert into public.site_claim_requirements(
    company_id,package_id,requirement_key,label_ar,label_en,category,
    is_required,min_items,sort_order,notes,created_by
  ) values
    (s.company_id,v_package,'work_order','أمر التكليف','Work Order','project',true,1,10,'Core site claim package requirement',p_actor),
    (s.company_id,v_package,'work_order_statement','بيان أمر التكليف','Work Order Statement','project',true,1,20,'Core site claim package requirement',p_actor),
    (s.company_id,v_package,'as_built_drawings','رسومات As-Built','As-Built Drawings','technical',true,1,30,'Core site claim package requirement',p_actor),
    (s.company_id,v_package,'quantity_survey','الحصر','Takeoff / Quantity Survey','quantity',true,1,40,'Core site claim package requirement',p_actor),
    (s.company_id,v_package,'test_sheet','Test Sheet','Test Sheet','quality',true,1,50,'Core site claim package requirement',p_actor),
    (s.company_id,v_package,'quality_certificate','شهادة الجودة','Quality Certificate','quality',true,1,60,'Core site claim package requirement',p_actor),
    (s.company_id,v_package,'warranty_certificate','شهادة الضمان','Warranty Certificate','quality',true,1,70,'Core site claim package requirement',p_actor),
    (s.company_id,v_package,'invoice','الفاتورة','Invoice','commercial',true,1,80,'Core site claim package requirement',p_actor),
    (s.company_id,v_package,'project_documents','مستندات المشروع الأخرى','Other Project Documents','project',false,1,90,'Optional site claim package document',p_actor),
    (s.company_id,v_package,'supporting','مستندات داعمة أخرى','Other Supporting Documents','supporting',false,1,100,'Optional site claim package document',p_actor)
  on conflict(package_id,requirement_key) do update set
    label_ar=excluded.label_ar,
    label_en=excluded.label_en,
    category=excluded.category,
    is_required=excluded.is_required,
    min_items=excluded.min_items,
    sort_order=excluded.sort_order,
    notes=excluded.notes,
    updated_at=now();

  return v_package;
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

  -- This RPC represents an explicit classification change from Document 360/new upload.
  -- Blank requirement intentionally clears a previous explicit type so auto-inference can resume.
  update public.documents
  set claim_inclusion_mode=v_mode,
      claim_requirement_key=v_key,
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
  if v_key is null then
    return jsonb_build_object('document_id',d.id,'mode',v_mode,'linked',0,'reason','no_requirement_inferred');
  end if;

  for p in
    select cp.* from public.site_claim_packages cp
    where cp.project_id=d.project_id
      and cp.claim_type='final'
      and cp.status in('collecting','rejected')
      and cp.locked_at is null
      and (d.site_id is null or cp.site_id=d.site_id)
  loop
    if not app_private.user_has_resource_permission(auth.uid(),p.company_id,'files.view',p.project_id,p.site_id,d.folder_id,null) then
      continue;
    end if;

    select * into r
    from public.site_claim_requirements
    where package_id=p.id and requirement_key=v_key;

    if not found then
      insert into public.site_claim_requirements(
        company_id,package_id,requirement_key,label_ar,label_en,category,
        is_required,min_items,sort_order,notes,created_by
      ) values(
        p.company_id,p.id,v_key,
        case v_key when 'supporting' then 'مستندات داعمة أخرى' else v_key end,
        case v_key when 'supporting' then 'Other Supporting Documents' else v_key end,
        'supporting',false,1,500,'Created from explicit document classification',auth.uid()
      ) returning * into r;
    end if;

    insert into public.site_claim_items(
      company_id,package_id,requirement_id,document_id,cabinet_id,inclusion_mode,status,added_by
    ) values(
      p.company_id,p.id,r.id,d.id,
      case when d.site_id is null then null else app_private.cabinet_for_folder(d.folder_id) end,
      case when v_mode='include' then 'upload' else 'auto' end,
      'included',auth.uid()
    ) on conflict(package_id,requirement_id,document_id) do update set
      inclusion_mode=excluded.inclusion_mode,
      cabinet_id=coalesce(excluded.cabinet_id,site_claim_items.cabinet_id),
      status='included',
      selected_version_id=null,
      updated_at=now();
    v_linked:=v_linked+1;
  end loop;

  return jsonb_build_object('document_id',d.id,'mode',v_mode,'requirement_key',v_key,'linked',v_linked);
end $$;

revoke all on function app_private.ensure_default_site_claim_package(uuid,uuid) from public,anon,authenticated;
revoke all on function public.set_document_claim_classification(uuid,text,text) from public,anon;
grant execute on function public.set_document_claim_classification(uuid,text,text) to authenticated;

commit;
