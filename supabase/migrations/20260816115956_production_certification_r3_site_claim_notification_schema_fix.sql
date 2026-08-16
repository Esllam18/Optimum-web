create or replace function app_private.capture_site_claim_lifecycle_event()
returns trigger
language plpgsql
security definer
set search_path='public','app_private','pg_temp'
as $$
declare
  v_event text;
  v_note text;
  v_type text;
  v_title_ar text;
  v_title_en text;
  v_body_ar text;
  v_body_en text;
begin
  if new.locked_at is not null and old.locked_at is null then
    perform app_private.record_site_claim_event(new.id,'versions_frozen',null,jsonb_build_object('locked_at',new.locked_at));
  end if;

  if new.status is distinct from old.status then
    v_event:=case new.status
      when 'submitted' then 'submitted'
      when 'approved' then 'approved'
      when 'rejected' then 'rejected'
      when 'collecting' then 'reopened'
      else null
    end;

    if v_event is not null then
      v_note:=case when new.status='rejected' then new.rejection_reason else new.review_note end;
      perform app_private.record_site_claim_event(
        new.id,
        v_event,
        v_note,
        jsonb_build_object('from',old.status,'to',new.status)
      );
    end if;

    if new.status in('submitted','approved','rejected') then
      v_type:='site_claim.'||new.status;
      v_title_ar:=case new.status
        when 'submitted' then 'تم تقديم حزمة تسليم'
        when 'approved' then 'تم اعتماد حزمة تسليم'
        else 'تم إرجاع حزمة تسليم للتعديل'
      end;
      v_title_en:=case new.status
        when 'submitted' then 'Delivery package submitted'
        when 'approved' then 'Delivery package approved'
        else 'Delivery package returned for changes'
      end;
      v_body_ar:=new.package_no||' · '||new.title||case when new.status='rejected' and coalesce(new.rejection_reason,'')<>'' then ' · '||new.rejection_reason else '' end;
      v_body_en:=new.package_no||' · '||new.title||case when new.status='rejected' and coalesce(new.rejection_reason,'')<>'' then ' · '||new.rejection_reason else '' end;

      perform app_private.notify_company_members(
        new.company_id,
        auth.uid(),
        v_type,
        v_title_ar,
        v_title_en,
        v_body_ar,
        v_body_en,
        'site_claim_package',
        new.id
      );
    end if;
  end if;

  return new;
end;
$$;
