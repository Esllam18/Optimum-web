-- Point 5 R2 — Arabic terminology polish for built-in CDE templates.
-- Only Optimum-owned templates are touched. Company templates remain unchanged.

update public.folder_template_nodes n
set name_ar = case
  when ft.template_kind='engineering' and n.code='02.06' then 'رسومات كما نُفذ (As-Built)'
  when ft.template_kind='telecom' and n.code='03.06' then 'رسومات كما نُفذ (As-Built)'
  when ft.template_kind='telecom' and n.code='08' then 'رسومات كما نُفذ والتسليم'
  when ft.template_kind='construction' and n.code='02.03' then 'أعمال MEP (ميكانيكا وكهرباء وسباكة)'
  when ft.template_kind='construction' and n.code='02.04' then 'رسومات الورشة (Shop Drawings)'
  when ft.template_kind='construction' and n.code='02.05' then 'رسومات كما نُفذ (As-Built)'
  when ft.template_kind='construction' and n.code='04' then 'الجودة وضبط الجودة والفحوصات'
  when ft.template_kind='construction' and n.code='06' then 'التسليم ورسومات كما نُفذ'
  when ft.template_kind='general' and n.code='05' then 'الرسومات ورسومات كما نُفذ'
  when ft.template_kind='general' and n.code='08' then 'رسومات كما نُفذ (As-Built)'
  else n.name_ar
end
from public.folder_templates ft
where n.template_id=ft.id
  and ft.company_id is null
  and (
    (ft.template_kind='engineering' and n.code='02.06') or
    (ft.template_kind='telecom' and n.code in ('03.06','08')) or
    (ft.template_kind='construction' and n.code in ('02.03','02.04','02.05','04','06')) or
    (ft.template_kind='general' and n.code in ('05','08'))
  );

update public.document_requirements
set label_ar='رسومات كما نُفذ (As-Built)'
where label_ar='رسومات As-Built';
