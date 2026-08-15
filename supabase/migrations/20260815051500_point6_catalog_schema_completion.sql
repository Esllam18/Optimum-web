-- Point 6 catalog schema completion — built-in items only.
-- Company-defined items are intentionally untouched.

update public.engineering_catalog_items
set attribute_schema='[
 {"key":"networkLevel","type":"select","options":["main","secondary","drop"],"label_ar":"مستوى المسار","label_en":"Route level","required":true},
 {"key":"installation","type":"select","options":["underground","aerial","indoor"],"label_ar":"طريقة التنفيذ","label_en":"Installation","required":true},
 {"key":"ways","type":"number","label_ar":"عدد الطرق","label_en":"Ways","boq":true},
 {"key":"diameter","type":"text","label_ar":"القطر","label_en":"Diameter"},
 {"key":"cableCode","type":"catalog","catalog_symbol":"fiber_cable","label_ar":"الكابل الداخلي","label_en":"Inner cable"},
 {"key":"fiberCores","type":"number","label_ar":"عدد كور الكابل","label_en":"Fiber cores"},
 {"key":"numberOfCables","type":"number","label_ar":"عدد الكابلات","label_en":"Cable count"},
 {"key":"spareLengthM","type":"number","label_ar":"طول احتياطي م","label_en":"Spare length m"},
 {"key":"connectorCount","type":"number","label_ar":"عدد الكونكتورات","label_en":"Connector count"},
 {"key":"openBundle","type":"number","label_ar":"فتح الباندل","label_en":"Open bundle"},
 {"key":"endBundle","type":"number","label_ar":"نهاية الباندل","label_en":"End bundle"},
 {"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}
]'::jsonb
where company_id is null and symbol_key='microduct';

update public.engineering_catalog_items
set attribute_schema='[
 {"key":"networkLevel","type":"select","options":["main","secondary","drop"],"label_ar":"مستوى المسار","label_en":"Route level","required":true},
 {"key":"installation","type":"select","options":["underground","aerial","indoor"],"label_ar":"طريقة التنفيذ","label_en":"Installation","required":true},
 {"key":"fiberCores","type":"number","label_ar":"عدد الكور","label_en":"Fiber cores","boq":true},
 {"key":"numberOfCables","type":"number","label_ar":"عدد الكابلات","label_en":"Cable count"},
 {"key":"spareLengthM","type":"number","label_ar":"طول احتياطي م","label_en":"Spare length m"},
 {"key":"connectorCount","type":"number","label_ar":"عدد الكونكتورات","label_en":"Connector count"},
 {"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}
]'::jsonb
where company_id is null and symbol_key='fiber_cable';

update public.engineering_catalog_items
set attribute_schema='[
 {"key":"networkLevel","type":"select","options":["main","secondary","drop"],"label_ar":"مستوى المسار","label_en":"Route level","required":true},
 {"key":"installation","type":"select","options":["underground","indoor","surface"],"label_ar":"طريقة التنفيذ","label_en":"Installation","required":true},
 {"key":"diameter","type":"text","label_ar":"القطر","label_en":"Diameter","required":true},
 {"key":"ways","type":"number","label_ar":"عدد المواسير / الطرق","label_en":"Duct / way count","boq":true},
 {"key":"cableCode","type":"catalog","catalog_symbol":"fiber_cable","label_ar":"الكابل داخل الماسورة","label_en":"Cable inside conduit"},
 {"key":"numberOfCables","type":"number","label_ar":"عدد الكابلات","label_en":"Cable count"},
 {"key":"spareLengthM","type":"number","label_ar":"طول احتياطي م","label_en":"Spare length m"},
 {"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}
]'::jsonb
where company_id is null and symbol_key in('conduit','hdpe_duct');

update public.engineering_catalog_items
set attribute_schema='[
 {"key":"networkLevel","type":"select","options":["main","secondary","drop"],"label_ar":"مستوى المسار","label_en":"Route level","required":true},
 {"key":"installation","type":"select","options":["underground"],"label_ar":"طريقة التنفيذ","label_en":"Installation","required":true},
 {"key":"surfaceType","type":"select","options":["soil","sidewalk","road"],"label_ar":"نوع السطح","label_en":"Surface type","required":true},
 {"key":"widthM","type":"number","label_ar":"عرض الحفر م","label_en":"Trench width m"},
 {"key":"depthM","type":"number","label_ar":"عمق الحفر م","label_en":"Trench depth m"},
 {"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}
]'::jsonb
where company_id is null and symbol_key='trench';

update public.engineering_catalog_items
set attribute_schema='[
 {"key":"nodeNo","type":"text","label_ar":"رقم النقطة","label_en":"Point no.","required":true},
 {"key":"networkLevel","type":"select","options":["main","secondary","distribution","customer"],"label_ar":"مستوى الشبكة","label_en":"Network level","required":true},
 {"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}
]'::jsonb
where company_id is null and symbol_key in('branch_point','junction');

update public.engineering_catalog_items
set attribute_schema='[
 {"key":"buildingNo","type":"text","label_ar":"رقم المبنى / الفيلا","label_en":"Building / villa no.","required":true},
 {"key":"floors","type":"number","label_ar":"عدد الأدوار","label_en":"Floors"},
 {"key":"units","type":"number","label_ar":"عدد الوحدات","label_en":"Units"},
 {"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}
]'::jsonb
where company_id is null and symbol_key in('building','villa');

update public.engineering_catalog_items
set attribute_schema='[
 {"key":"baseType","type":"text","label_ar":"نوع القاعدة","label_en":"Base type"},
 {"key":"lengthM","type":"number","label_ar":"الطول م","label_en":"Length m"},
 {"key":"widthM","type":"number","label_ar":"العرض م","label_en":"Width m"},
 {"key":"heightM","type":"number","label_ar":"الارتفاع م","label_en":"Height m"},
 {"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}
]'::jsonb
where company_id is null and symbol_key='cabinet_base';

update public.engineering_catalog_items
set attribute_schema='[
 {"key":"outletNo","type":"text","label_ar":"رقم النقطة / المخرج","label_en":"Outlet no.","required":true},
 {"key":"locationCode","type":"text","label_ar":"الغرفة / الموقع","label_en":"Room / location"},
 {"key":"ports","type":"number","label_ar":"عدد المنافذ","label_en":"Ports","boq":true},
 {"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}
]'::jsonb
where company_id is null and symbol_key in('faceplate','wall_outlet');

update public.engineering_catalog_items
set attribute_schema='[
 {"key":"loopNo","type":"text","label_ar":"رقم حلقة الاحتياطي","label_en":"Loop no.","required":true},
 {"key":"spareLengthM","type":"number","label_ar":"الطول الاحتياطي م","label_en":"Spare length m","required":true,"boq":true},
 {"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}
]'::jsonb
where company_id is null and symbol_key='spare_loop';

update public.engineering_catalog_items
set attribute_schema='[
 {"key":"boxNo","type":"text","label_ar":"رقم البوكس","label_en":"Box no.","required":true},
 {"key":"splitterRatio","type":"text","label_ar":"نسبة السبلتر","label_en":"Splitter ratio"},
 {"key":"ports","type":"number","label_ar":"عدد المنافذ","label_en":"Ports"},
 {"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}
]'::jsonb
where company_id is null and symbol_key='splitter_box';

update public.engineering_catalog_items
set attribute_schema='[
 {"key":"boxNo","type":"text","label_ar":"رقم الكابينة","label_en":"Cabinet no.","required":true},
 {"key":"networkLevel","type":"select","options":["main","secondary"],"label_ar":"مستوى الشبكة","label_en":"Network level","required":true},
 {"key":"capacity","type":"number","label_ar":"السعة","label_en":"Capacity","boq":true},
 {"key":"ports","type":"number","label_ar":"المنافذ","label_en":"Ports"},
 {"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}
]'::jsonb
where company_id is null and symbol_key='tdm_sub_cabinet';

update public.engineering_catalog_items
set attribute_schema='[
 {"key":"ports","type":"number","label_ar":"عدد المنافذ","label_en":"Ports","boq":true},
 {"key":"rackU","type":"number","label_ar":"مقاس U","label_en":"Rack U"},
 {"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}
]'::jsonb
where company_id is null and symbol_key='patch_panel';

update public.engineering_catalog_items
set attribute_schema='[
 {"key":"capacity","type":"number","label_ar":"سعة اللحامات","label_en":"Splice capacity","boq":true},
 {"key":"notes","type":"textarea","label_ar":"ملاحظات","label_en":"Notes"}
]'::jsonb
where company_id is null and symbol_key='splice_tray';
