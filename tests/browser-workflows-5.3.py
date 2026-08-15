import asyncio, json, os, re, subprocess, time, sys, zipfile
from pathlib import Path
from urllib.parse import urlparse, parse_qs
import mimetypes
from playwright.async_api import async_playwright

USER='11111111-1111-4111-8111-111111111111'
USER2='12111111-1111-4111-8111-111111111112'
COMPANY='22222222-2222-4222-8222-222222222222'
MEMBERSHIP='33333333-3333-4333-8333-333333333333'
MEMBERSHIP2='34333333-3333-4333-8333-333333333334'
UNIT='35333333-3333-4333-8333-333333333335'
OWNER_ROLE='44444444-4444-4444-8444-444444444444'
ENGINEER_ROLE='55555555-5555-4555-8555-555555555555'
CUSTOM_ROLE='66666666-6666-4666-8666-666666666666'
TPL='77777777-7777-4777-8777-777777777777'
TASK='90909090-9090-4090-8090-909090909090'
SITE='a1a1a1a1-a1a1-41a1-81a1-a1a1a1a1a1a1'
FOLDER='b1b1b1b1-b1b1-41b1-81b1-b1b1b1b1b1b1'
FOLDER2='b2b2b2b2-b2b2-42b2-82b2-b2b2b2b2b2b2'
DOC='c1c1c1c1-c1c1-41c1-81c1-c1c1c1c1c1c1'
VERSION='d1d1d1d1-d1d1-41d1-81d1-d1d1d1d1d1d1'
BLUEPRINT='e1e1e1e1-e1e1-41e1-81e1-e1e1e1e1e1e1'
CABINET='e2e2e2e2-e2e2-42e2-82e2-e2e2e2e2e2e2'
CLAIM='f2f2f2f2-f2f2-42f2-82f2-f2f2f2f2f2f2'
CLAIM_REQ='a3a3a3a3-a3a3-43a3-83a3-a3a3a3a3a3a3'
CAB_ROOT='b4b4b4b4-b4b4-44b4-84b4-b4b4b4b4b4b4'
SITE_FOLDER='b3b3b3b3-b3b3-43b3-83b3-b3b3b3b3b3b3'
SITE_DOC='c3c3c3c3-c3c3-43c3-83c3-c3c3c3c3c3c3'
SITE_VERSION='d3d3d3d3-d3d3-43d3-83d3-d3d3d3d3d3d3'
CDE_TEMPLATE='f5f5f5f5-f5f5-45f5-85f5-f5f5f5f5f5f5'
CDE_CUSTOM_TEMPLATE='f6f6f6f6-f6f6-46f6-86f6-f6f6f6f6f6f6'
CDE_REQUIREMENT='f7f7f7f7-f7f7-47f7-87f7-f7f7f7f7f7f7'
OPS_DRAWING='abababab-abab-4bab-8bab-abababababab'
P10_LOG='10101010-1010-4010-8010-101010101010'
P10_INSPECTION='11101010-1010-4010-8010-101010101011'
P10_ISSUE='12101010-1010-4010-8010-101010101012'
P10_CONSTRAINT='13101010-1010-4010-8010-101010101013'
P10_REPORT_DOC='14101010-1010-4010-8010-101010101014'
P11_PROJECT3='18111111-1111-4111-8111-111111111118'
P11_BRIEF='19111111-1111-4111-8111-111111111119'
P11_REPORT_DOC='20111111-1111-4111-8111-111111111120'
P910_INVOICE_DOC='30101010-1010-4010-8010-101010101030'
P910_INVOICE_VER='31101010-1010-4110-8110-101010101031'
P910_TAKEOFF_DOC='32101010-1010-4210-8210-101010101032'
P910_TAKEOFF_VER='33101010-1010-4310-8310-101010101033'

def p11_metrics(score,band,progress,expected,overdue=0,blocked=0,critical=0,constraints=0,failed=0,cde=0,daily=0):
 return {'score':score,'band':band,'execution_progress_pct':progress,'declared_progress_pct':progress,'expected_progress_pct':expected,'schedule_variance_pct':round(progress-expected,1),'progress_sources':{'tasks_pct':progress,'requirements_pct':max(0,progress-5),'cabinets_pct':max(0,progress-10),'fallback':None},'tasks':{'total':20,'done':round(progress/5),'overdue':overdue,'blocked':blocked,'high_open':overdue+blocked},'milestones':{'missed':1 if band=='critical' else 0,'at_risk':1 if band in ('watch','at_risk','critical') else 0,'overdue':1 if band in ('at_risk','critical') else 0},'field':{'issues_open':critical+2,'issues_high':1 if critical else 0,'issues_critical':critical,'constraints_open':constraints,'constraints_aged':max(0,constraints-1),'failed_inspections':failed,'needs_review_inspections':1 if failed else 0,'daily_returned':daily,'daily_pending_review':1 if daily else 0},'cde':{'overdue_reviews':cde,'rejected':0,'requirements_total':10,'requirements_ready':round(progress/10)},'delivery':{'cabinets_total':10,'cabinets_complete':round(progress/10)},'sites':{'total':2,'late':1 if band in ('at_risk','critical') else 0},'drawings':{'in_review':1 if band!='stable' else 0},'drivers':[{'key':'overdue_tasks','count':overdue,'penalty':min(18,overdue*2)},{'key':'blocked_tasks','count':blocked,'penalty':min(12,blocked*3)},{'key':'field_issues','count':critical,'penalty':min(15,critical*6)},{'key':'constraints','count':constraints,'penalty':min(12,constraints*2)},{'key':'inspections','count':failed,'penalty':min(10,failed*3)},{'key':'cde','count':cde,'penalty':min(8,cde*2)},{'key':'daily_reports','count':daily,'penalty':min(5,daily*2)},{'key':'schedule','count':max(0,round(expected-progress)),'penalty':min(15,max(0,(expected-progress)*0.5))}]}

P11_CRITICAL=p11_metrics(46,'critical',48,72,overdue=6,blocked=2,critical=2,constraints=3,failed=1,cde=2,daily=1)
P11_WATCH=p11_metrics(76,'watch',64,70,overdue=2,blocked=0,critical=0,constraints=1,failed=0,cde=1,daily=0)
P11_STABLE=p11_metrics(92,'stable',82,78)

permissions=[
 ('company.view','company','عرض بيانات الشركة','View company'),('company.manage','company','تعديل إعدادات الشركة','Manage company'),
 ('members.view','members','عرض أعضاء الشركة','View members'),('members.invite','members','إنشاء حسابات أعضاء','Invite members'),('members.manage','members','إدارة الأعضاء','Manage members'),
 ('roles.view','roles','عرض الأدوار','View roles'),('roles.create','roles','إنشاء أدوار','Create roles'),('roles.manage','roles','إدارة الأدوار','Manage roles'),('roles.delete','roles','حذف الأدوار','Delete roles'),('roles.templates.use','roles','استخدام قوالب الأدوار','Use role templates'),
 ('branding.view','branding','عرض هوية الشركة','View branding'),('branding.manage','branding','تعديل هوية الشركة','Manage branding'),
 ('compensation.view','compensation','عرض الرواتب','View compensation'),('compensation.manage','compensation','إدارة الرواتب','Manage compensation'),
 ('audit.view','audit','عرض سجل النشاط','View audit'),
 ('search.use','search','استخدام البحث الشامل','Use global search'),
 ('projects.view','projects','عرض المشاريع','View projects'),('projects.create','projects','إنشاء المشاريع','Create projects'),('projects.edit','projects','تعديل المشاريع','Edit projects'),('projects.archive','projects','أرشفة المشاريع','Archive projects'),
 ('tasks.view','tasks','عرض العمل','View work'),('tasks.create','tasks','إنشاء العمل','Create work'),('tasks.claim','tasks','استلام عمل مفتوح','Claim open work'),('tasks.edit','tasks','تعديل العمل','Edit work'),('tasks.complete','tasks','إكمال العمل','Complete work'),('tasks.assign','tasks','إسناد العمل','Assign work'),('tasks.comment','tasks','التعليق','Comment'),('tasks.attach','tasks','المرفقات','Attach'),('tasks.manage','tasks','إدارة العمل','Manage work'),('tasks.view_all','tasks','عرض كل العمل','View all work'),('tasks.approve','tasks','اعتماد العمل','Approve work'),('tasks.manage_templates','tasks','إدارة القوالب','Manage templates'),('tasks.manage_milestones','tasks','إدارة المراحل','Manage milestones'),('tasks.manage_automations','tasks','إدارة الأتمتة','Manage automations'),('tasks.view_workload','tasks','عرض الأحمال','View workload'),
]
entitlement_by_module={'company':'module.company','members':'module.members','roles':'module.roles','branding':'module.branding','compensation':'module.hr','audit':'module.audit','search':'module.search','projects':'module.projects','tasks':'module.tasks'}
perms=[{'key':k,'module':m,'description_ar':ar,'description_en':en,'entitlement_key':entitlement_by_module[m],'scope_mode':'resource' if m=='projects' else 'company'} for k,m,ar,en in permissions]
entitlement_defs={
 'module.company':('company','إدارة الشركة','Company management'),'module.members':('members','الفريق','Team'),'module.roles':('roles','الأدوار والصلاحيات','Roles & permissions'),'module.branding':('branding','هوية الشركة','Company branding'),'module.hr':('hr','بيانات الموارد البشرية','HR data'),'module.audit':('audit','سجل النشاط','Activity audit'),'feature.advanced_audit':('audit','السجل المتقدم','Advanced audit'),'module.search':('search','البحث الشامل','Global search'),'module.projects':('projects','المشاريع والمواقع','Projects & sites'),'module.tasks':('tasks','العمل والتسليم','Work & delivery')
}
entitlements=[{'key':key,'module':module,'name_ar':ar,'name_en':en,'description_ar':'','description_en':'','scope_mode':'resource' if module=='projects' else 'company','is_active':True,'sort_order':i+1} for i,(key,(module,ar,en)) in enumerate(entitlement_defs.items())]
plan_entitlements=[{'plan_id':'plan1','entitlement_key':ent['key'],'enabled':True,'limits':{}} for ent in entitlements]
role_perms=[{'role_id':OWNER_ROLE,'permission_key':p['key'],'allowed':True} for p in perms]
role_perms += [{'role_id':ENGINEER_ROLE,'permission_key':k,'allowed':True} for k in ['members.view','roles.view','company.view','branding.view','tasks.view','tasks.claim','tasks.edit','tasks.complete','tasks.comment','tasks.attach']]
role_perms += [{'role_id':CUSTOM_ROLE,'permission_key':'audit.view','allowed':True}]
roles=[
 {'id':OWNER_ROLE,'company_id':COMPANY,'slug':'owner','name_ar':'صاحب الشركة','name_en':'Owner','description_ar':'الدور الأعلى','description_en':'Top role','color':'#4f46e5','icon':'shield','is_protected':True,'sort_order':1},
 {'id':ENGINEER_ROLE,'company_id':COMPANY,'slug':'engineer','name_ar':'مهندس','name_en':'Engineer','description_ar':'عمل هندسي','description_en':'Engineering work','color':'#0ea5e9','icon':'briefcase','is_protected':True,'sort_order':2},
 {'id':CUSTOM_ROLE,'company_id':COMPANY,'slug':'claims-tracker','name_ar':'متابع مستخلصات','name_en':'Claims Tracker','description_ar':'متابعة مالية','description_en':'Financial tracking','color':'#f59e0b','icon':'shield','is_protected':False,'sort_order':3},
]
projects=[
 {'id':'abababab-abab-4bab-8bab-ababababab01','company_id':COMPANY,'code':'ALPHA','name':'Alpha Project','description':'First test project','status':'active','created_by':USER,'created_at':'2026-08-01T00:00:00Z','updated_at':'2026-08-06T00:00:00Z','archived_at':None},
 {'id':'abababab-abab-4bab-8bab-ababababab02','company_id':COMPANY,'code':'BETA','name':'Beta Project','description':'Second test project','status':'planned','created_by':USER,'created_at':'2026-08-01T00:00:00Z','updated_at':'2026-08-05T00:00:00Z','archived_at':None},
]
sites_pdc=[{'id':SITE,'company_id':COMPANY,'project_id':projects[0]['id'],'code':'SITE-01','name':'Alpha Main Site','description':'Primary delivery site','status':'active','manager_user_id':USER2,'address':'New Cairo','latitude':30.020000,'longitude':31.490000,'timezone':'Africa/Cairo','start_date':'2026-08-01','target_end_date':'2026-12-31','created_by':USER,'created_at':'2026-08-01T00:00:00Z','updated_at':'2026-08-07T00:00:00Z','archived_at':None}]
project_blueprints_pdc=[{'id':BLUEPRINT,'company_id':None,'code':'standard-engineering','name_ar':'هندسي قياسي','name_en':'Standard Engineering','description_ar':'هيكل هندسي عام','description_en':'General engineering workspace','project_type':'engineering','folder_template_id':'f0f0f0f0-f0f0-40f0-80f0-f0f0f0f0f0f0','is_active':True,'is_default':True,'created_at':'2026-08-01T00:00:00Z'}]
folders_pdc=[{'id':FOLDER,'company_id':COMPANY,'project_id':projects[0]['id'],'site_id':None,'parent_id':None,'name':'01 — Drawings','code':'01','depth':0,'sort_order':10,'is_system':True,'child_count':1,'document_count':1,'created_by':USER,'created_at':'2026-08-01T00:00:00Z','updated_at':'2026-08-07T00:00:00Z','archived_at':None,'trashed_at':None},{'id':FOLDER2,'company_id':COMPANY,'project_id':projects[0]['id'],'site_id':None,'parent_id':FOLDER,'name':'Electrical','code':'ELE','depth':1,'sort_order':20,'is_system':True,'child_count':0,'document_count':0,'created_by':USER,'created_at':'2026-08-01T00:00:00Z','updated_at':'2026-08-07T00:00:00Z','archived_at':None,'trashed_at':None}]
document_pdc={'id':DOC,'company_id':COMPANY,'project_id':projects[0]['id'],'site_id':None,'folder_id':FOLDER,'display_name':'Electrical Shop Drawing A-102','system_code':'ALPHA-ELE-001','document_type':'drawing','description':'Issued electrical shop drawing','tags':['electrical','shop-drawing'],'state':'active','current_version_id':VERSION,'version_count':2,'control_status':'in_review','discipline':'Electrical','owner_user_id':USER2,'review_due_at':'2026-08-10T10:00:00Z','document_date':'2026-08-08','expires_at':'2026-09-01T23:59:59Z','issuer':'Alpha Consultant','approved_at':None,'approved_by':None,'created_by':USER2,'created_at':'2026-08-05T00:00:00Z','updated_at':'2026-08-08T08:00:00Z'}
version_pdc={'id':VERSION,'company_id':COMPANY,'document_id':DOC,'version_number':2,'version_label':'v2','revision_code':'R2','restored_from_version_id':None,'original_filename':'A-102-R2.pdf','storage_bucket':'company-files','storage_path':f'{COMPANY}/{projects[0]["id"]}/project/{DOC}/{VERSION}/A-102-R2.pdf','mime_type':'application/pdf','size_bytes':2457600,'checksum_sha256':'abc123','upload_state':'ready','change_note':'Review revision','uploaded_by':USER2,'uploader_name':'Engineer User','created_at':'2026-08-08T08:00:00Z','finalized_at':'2026-08-08T08:01:00Z'}

site_folders_delivery=[
 {'id':CAB_ROOT,'company_id':COMPANY,'project_id':projects[0]['id'],'site_id':SITE,'parent_id':None,'name':'CAB-01 — Cabinet One','code':'CAB-01','depth':0,'sort_order':30,'is_system':True,'child_count':6,'document_count':1,'created_by':USER,'created_at':'2026-08-08T00:00:00Z','updated_at':'2026-08-08T00:00:00Z','trashed_at':None},
 {'id':SITE_FOLDER,'company_id':COMPANY,'project_id':projects[0]['id'],'site_id':SITE,'parent_id':CAB_ROOT,'name':'Drawings & As-Built','code':'C01','depth':1,'sort_order':10,'is_system':True,'child_count':0,'document_count':1,'created_by':USER,'created_at':'2026-08-08T00:00:00Z','updated_at':'2026-08-08T00:00:00Z','trashed_at':None}
]
site_document_pdc={'id':SITE_DOC,'company_id':COMPANY,'project_id':projects[0]['id'],'site_id':SITE,'folder_id':SITE_FOLDER,'display_name':'CAB-01 As-Built Drawing','system_code':'ALPHA-CAB01-AB-001','document_type':'drawing','description':'Cabinet as-built','tags':['as-built','cabinet'],'state':'active','current_version_id':SITE_VERSION,'version_count':1,'control_status':'approved','discipline':'Fiber','owner_user_id':USER2,'review_due_at':None,'document_date':'2026-08-08','expires_at':None,'issuer':'Site QA','approved_at':'2026-08-08T12:00:00Z','approved_by':USER,'created_by':USER2,'created_at':'2026-08-08T09:00:00Z','updated_at':'2026-08-08T12:00:00Z'}
site_version_pdc={'id':SITE_VERSION,'company_id':COMPANY,'document_id':SITE_DOC,'version_number':1,'version_label':'v1','revision_code':'AB','restored_from_version_id':None,'original_filename':'CAB-01-AsBuilt.pdf','storage_bucket':'company-files','storage_path':f'{COMPANY}/{projects[0]["id"]}/{SITE}/{SITE_DOC}/{SITE_VERSION}/CAB-01-AsBuilt.pdf','mime_type':'application/pdf','size_bytes':1250000,'checksum_sha256':'cab123','upload_state':'ready','change_note':'As-built','uploaded_by':USER2,'uploader_name':'Engineer User','created_at':'2026-08-08T09:00:00Z','finalized_at':'2026-08-08T09:01:00Z'}
claim_requirements_fixture=[
 {'id':CLAIM_REQ,'requirement_key':'as_built_drawings','label_ar':'رسومات As-Built','label_en':'As-Built Drawings','category':'technical','is_required':True,'min_items':1,'sort_order':60,'item_count':1,'satisfied':True,'items':[{'id':'a4a4a4a4-a4a4-44a4-84a4-a4a4a4a4a4a4','document_id':SITE_DOC,'display_name':site_document_pdc['display_name'],'document_type':'drawing','control_status':'approved','current_version_id':SITE_VERSION,'selected_version_id':None,'cabinet_id':CABINET,'cabinet_code':'CAB-01','cabinet_name':'Cabinet One','inclusion_mode':'auto','status':'included','folder_id':SITE_FOLDER}]},
 {'id':'a5a5a5a5-a5a5-45a5-85a5-a5a5a5a5a5a5','requirement_key':'quantity_survey','label_ar':'الحصر والكميات','label_en':'Quantity Survey / Takeoff','category':'quantity','is_required':True,'min_items':1,'sort_order':30,'item_count':0,'satisfied':False,'items':[]}
]
claim_payload={'package':{'id':CLAIM,'company_id':COMPANY,'project_id':projects[0]['id'],'site_id':SITE,'package_no':'SITE-01-FINAL','title':'Final Site Claim / Delivery Package','claim_type':'final','status':'collecting','locked_at':None,'created_by':USER,'created_at':'2026-08-08T00:00:00Z','updated_at':'2026-08-08T00:00:00Z'},'site':{'id':SITE,'code':'SITE-01','name':'Alpha Main Site'},'project':{'id':projects[0]['id'],'code':'ALPHA','name':'Alpha Project'},'progress':{'required_percent':17,'cabinet_coverage_percent':100,'overall_percent':42,'required_total':6,'required_satisfied':1,'cabinet_total':1,'cabinet_covered':1},'requirements':claim_requirements_fixture,'can_manage':True}


def point910_claim_requirements():
 rows=[]
 defs=[
  ('work_order','أمر التكليف','Work Order','project',DOC,None),
  ('work_order_statement','بيان أمر التكليف','Work Order Statement','project',DOC,None),
  ('as_built_drawings','رسومات As-Built','As-Built Drawings','technical',SITE_DOC,CABINET),
  ('quantity_survey','الحصر','Takeoff / Quantity Survey','quantity',P910_TAKEOFF_DOC,CABINET),
  ('test_sheet','Test Sheet','Test Sheet','quality',SITE_DOC,CABINET),
  ('quality_certificate','شهادة الجودة','Quality Certificate','quality',SITE_DOC,None),
  ('warranty_certificate','شهادة الضمان','Warranty Certificate','quality',SITE_DOC,None),
  ('invoice','الفاتورة','Invoice','commercial',P910_INVOICE_DOC,None),
 ]
 for idx,(key,ar,en,cat,doc_id,cab) in enumerate(defs):
  rows.append({'id':f'91000000-0000-4000-8000-{idx+1:012d}','requirement_key':key,'label_ar':ar,'label_en':en,'category':cat,'is_required':True,'min_items':1,'sort_order':(idx+1)*10,'item_count':1,'ready_count':1,'satisfied':True,'items':[{'id':f'92000000-0000-4000-8000-{idx+1:012d}','document_id':doc_id,'display_name':en,'document_type':'drawing' if key=='as_built_drawings' else 'boq' if key=='quantity_survey' else 'invoice' if key=='invoice' else 'certificate' if 'certificate' in key or key=='test_sheet' else 'general','control_status':'approved','current_version_id':SITE_VERSION if doc_id==SITE_DOC else VERSION if doc_id==DOC else P910_TAKEOFF_VER if doc_id==P910_TAKEOFF_DOC else P910_INVOICE_VER,'selected_version_id':(SITE_VERSION if doc_id==SITE_DOC else VERSION if doc_id==DOC else P910_TAKEOFF_VER if doc_id==P910_TAKEOFF_DOC else P910_INVOICE_VER) if captured.get('point910_frozen') else None,'cabinet_id':cab,'cabinet_code':'CAB-01' if cab else None,'cabinet_name':'Cabinet One' if cab else None,'inclusion_mode':'auto','status':'included','folder_id':SITE_FOLDER if doc_id!=DOC else FOLDER}]})
 return rows

def point910_manifest():
 frozen=bool(captured.get('point910_frozen'))
 exports=[]
 if captured.get('point910_export'):
  exports=[captured['point910_export']]
 return {
  'package':{'id':CLAIM,'package_no':'SITE-01-FINAL','title':'Site Claim Package','status':'collecting','locked_at':'2026-08-15T16:30:00Z' if frozen else None,'project_id':projects[0]['id'],'site_id':SITE},
  'project':{'id':projects[0]['id'],'code':'ALPHA','name':'Alpha Project'},
  'site':{'id':SITE,'code':'SITE-01','name':'Alpha Main Site'},
  'missing_required':0,
  'ready_for_export':frozen,
  'requirements':[{'id':r['id'],'key':r['requirement_key'],'label_ar':r['label_ar'],'label_en':r['label_en'],'category':r['category'],'required':True,'min_items':1,'ready_count':1} for r in point910_claim_requirements()],
  'items':[
   {'item_id':'93000000-0000-4000-8000-000000000001','document_id':DOC,'display_name':'أمر التكليف','document_type':'general','requirement_key':'work_order','label_ar':'أمر التكليف','label_en':'Work Order','category':'project','scope_kind':'project','cabinet_id':None,'cabinet_code':None,'cabinet_name':None,'version_id':VERSION,'version_number':2,'revision_code':'R2','original_filename':'Work-Order.pdf','storage_bucket':'company-files','storage_path':version_pdc['storage_path'],'mime_type':'application/pdf','size_bytes':2048,'selected_version_id':VERSION if frozen else None,'current_version_id':VERSION},
   {'item_id':'93000000-0000-4000-8000-000000000002','document_id':P910_INVOICE_DOC,'display_name':'فاتورة الموقع','document_type':'invoice','requirement_key':'invoice','label_ar':'الفاتورة','label_en':'Invoice','category':'commercial','scope_kind':'site','cabinet_id':None,'cabinet_code':None,'cabinet_name':None,'version_id':P910_INVOICE_VER,'version_number':1,'revision_code':None,'original_filename':'SITE-01-Invoice.pdf','storage_bucket':'company-files','storage_path':f'{COMPANY}/{projects[0]["id"]}/{SITE}/{P910_INVOICE_DOC}/{P910_INVOICE_VER}/invoice.pdf','mime_type':'application/pdf','size_bytes':1024,'selected_version_id':P910_INVOICE_VER if frozen else None,'current_version_id':P910_INVOICE_VER},
   {'item_id':'93000000-0000-4000-8000-000000000003','document_id':SITE_DOC,'display_name':'CAB-01 As-Built Drawing','document_type':'drawing','requirement_key':'as_built_drawings','label_ar':'رسومات As-Built','label_en':'As-Built Drawings','category':'technical','scope_kind':'cabinet','cabinet_id':CABINET,'cabinet_code':'CAB-01','cabinet_name':'Cabinet One','version_id':SITE_VERSION,'version_number':1,'revision_code':'AB','original_filename':'CAB-01-AsBuilt.pdf','storage_bucket':'company-files','storage_path':site_version_pdc['storage_path'],'mime_type':'application/pdf','size_bytes':3072,'selected_version_id':SITE_VERSION if frozen else None,'current_version_id':SITE_VERSION},
  ],
  'exports':exports,
 }

company={'id':COMPANY,'name':'Optimum Test','slug':'optimum-test','legal_name':'Optimum Test LLC','short_code':'OPT','official_email':'office@example.com','phone':'01000000000','whatsapp':'01000000000','country_code':'EG','city':'Cairo','address':'Test address','website':'https://example.com','industry':'Construction','registration_number':'REG-1','tax_number':'TAX-1','primary_contact_name':'Owner User','primary_contact_email':'owner@example.com','primary_contact_phone':'01000000000','billing_contact_name':'Finance','billing_contact_email':'finance@example.com','billing_contact_phone':'01000000001','technical_contact_name':'Tech','technical_contact_email':'tech@example.com','technical_contact_phone':'01000000002','timezone':'Africa/Cairo','default_locale':'ar','created_at':'2026-08-01T00:00:00Z'}
profile2={'id':USER2,'full_name':'Engineer User','phone':'01000000003','whatsapp':'01000000003','timezone':'Africa/Cairo','avatar_path':None}
membership2={'id':MEMBERSHIP2,'company_id':COMPANY,'user_id':USER2,'role_id':ENGINEER_ROLE,'status':'active','joined_at':'2026-08-02T00:00:00Z','employee_code':'ENG-001','job_title':'Electrical Engineer','department':'Engineering','invited_email':'engineer@example.com','manager_user_id':USER,'lifecycle_stage':'active','employment_type':'full_time','work_mode':'hybrid','weekly_capacity_hours':40,'experience_level':'senior','skills':['CAD','QA'],'alternate_manager_user_id':None,'primary_site_id':None,'work_schedule':{},'access_ends_at':None}
profile={'id':USER,'full_name':'Owner User','phone':'01000000000','whatsapp':'01000000000','timezone':'Africa/Cairo','avatar_path':None}
membership={'id':MEMBERSHIP,'company_id':COMPANY,'user_id':USER,'role_id':OWNER_ROLE,'status':'active','joined_at':'2026-08-01T00:00:00Z','employee_code':'OWN-001','job_title':'Owner','department':'Management','invited_email':'owner@example.com','manager_user_id':None,'lifecycle_stage':'active','employment_type':'full_time','work_mode':'onsite','weekly_capacity_hours':40,'experience_level':'lead','skills':['Management'],'alternate_manager_user_id':None,'primary_site_id':None,'work_schedule':{},'access_ends_at':None}
subscription={'company_id':COMPANY,'plan_id':'plan1','status':'active','starts_at':'2026-08-01T00:00:00Z','current_period_ends_at':'2026-09-01T00:00:00Z','billing_cycle':'monthly','payment_status':'paid','max_members_override':25,'max_projects_override':10,'max_storage_bytes_override':10737418240}
branding={'company_id':COMPANY,'app_name':'Optimum Test','tagline':'Work better','primary_color':'#4f46e5','accent_color':'#14b8a6','neutral_color':'#64748b','default_theme':'system','sidebar_style':'glass','radius_style':'rounded','density':'comfortable','logo_shape':'rounded','logo_path':None}
activities=[
 {'id':1,'action':'role.updated','entity_type':'role','entity_id':CUSTOM_ROLE,'metadata':{'permissions':3,'slug':'claims-tracker'},'created_at':'2026-08-06T09:00:00Z','actor_id':USER,'actor_name':'Owner User','actor_avatar_path':None},
 {'id':2,'action':'company.settings_updated','entity_type':'company','entity_id':COMPANY,'metadata':{'fields':['name','branding']},'created_at':'2026-08-06T08:00:00Z','actor_id':USER,'actor_name':'Owner User','actor_avatar_path':None},
]

work_task={'id':TASK,'task_number':42,'company_id':COMPANY,'project_id':projects[0]['id'],'site_id':None,'folder_id':None,'document_id':None,'title':'Review shop drawing','description':'Review and approve revision','status':'in_progress','priority':'high','visibility':'company','open_unassigned':False,'claimed_by':None,'start_at':'2026-08-08T08:00:00Z','due_at':'2026-08-09T12:00:00Z','progress':40,'created_by':USER,'updated_by':USER,'created_at':'2026-08-07T20:00:00Z','updated_at':'2026-08-07T21:00:00Z','task_type':'review','owner_user_id':USER2,'reviewer_user_id':USER,'approver_user_id':None,'estimated_minutes':240,'actual_minutes':60,'required_skills':['CAD'],'labels':['drawing'],'sla_due_at':'2026-08-09T10:00:00Z','source_type':'drawing','source_id':None,'lock_version':3,'milestone_id':None,'owner_name':'Engineer User','project_name':'Alpha Project','risk':{'score':35,'level':'medium','reasons':{'downstream':1}},'comment_count':1,'attachment_count':0,'blocker_count':0,'downstream_count':1,'can_edit':True,'can_complete':True,'can_claim':False}
work_activity={'id':99,'action':'task.status_changed','entity_type':'task','entity_id':TASK,'metadata':{'from':'todo','to':'in_progress'},'created_at':'2026-08-07T21:00:00Z','actor_id':USER2,'actor_name':'Engineer User','actor_avatar_path':None,'entity_title':'Review shop drawing','human_key':'task_status_changed'}
workflow_template={'id':'91919191-9191-4191-8191-919191919191','company_id':COMPANY,'name':'Drawing Review Workflow','description':'Execution → Review → Approval','definition':[{'title':'Prepare drawing','task_type':'task','priority':'medium','offset_days':0,'duration_days':1,'estimated_minutes':120,'depends_on':[]},{'title':'Review drawing','task_type':'review','priority':'high','offset_days':1,'duration_days':1,'estimated_minutes':60,'depends_on':[0]},{'title':'Approve drawing','task_type':'approval','priority':'high','offset_days':2,'duration_days':0,'estimated_minutes':30,'depends_on':[1]}],'is_active':True,'created_by':USER,'updated_by':USER,'created_at':'2026-08-08T00:00:00Z','updated_at':'2026-08-08T00:00:00Z'}
work_cockpit={'timezone':'Africa/Cairo','today':'2026-08-08','personal':{'open':1,'due_today':1,'overdue':0,'blocked':0,'reviews':1,'approvals':0,'upcoming':1},'focus':[work_task],'manager':{'enabled':True,'unassigned':0,'high_risk':1,'attention':[work_task],'overloaded':[{'user_id':USER2,'name':'Engineer User','capacity_hours':40,'planned_minutes':2640,'utilization':110}]}}
capacity_plan={'timezone':'Africa/Cairo','from':'2026-08-08','days':[{'date':'2026-08-08','dow':6},{'date':'2026-08-09','dow':0},{'date':'2026-08-10','dow':1}], 'members':[{'membership_id':MEMBERSHIP,'user_id':USER,'name':'Owner User','job_title':'Owner','department':'Management','weekly_capacity_hours':40,'skills':['Management']},{'membership_id':MEMBERSHIP2,'user_id':USER2,'name':'Engineer User','job_title':'Electrical Engineer','department':'Engineering','weekly_capacity_hours':40,'skills':['CAD','QA']}], 'cells':[{'membership_id':MEMBERSHIP,'user_id':USER,'date':'2026-08-08','is_work_day':False,'holiday':False,'on_leave':False,'capacity_minutes':0,'planned_minutes':0,'work_items':0,'utilization':0},{'membership_id':MEMBERSHIP2,'user_id':USER2,'date':'2026-08-08','is_work_day':False,'holiday':False,'on_leave':False,'capacity_minutes':0,'planned_minutes':120,'work_items':1,'utilization':999},{'membership_id':MEMBERSHIP,'user_id':USER,'date':'2026-08-09','is_work_day':True,'holiday':False,'on_leave':False,'capacity_minutes':480,'planned_minutes':0,'work_items':0,'utilization':0},{'membership_id':MEMBERSHIP2,'user_id':USER2,'date':'2026-08-09','is_work_day':True,'holiday':False,'on_leave':False,'capacity_minutes':480,'planned_minutes':240,'work_items':1,'utilization':50},{'membership_id':MEMBERSHIP,'user_id':USER,'date':'2026-08-10','is_work_day':True,'holiday':False,'on_leave':False,'capacity_minutes':480,'planned_minutes':0,'work_items':0,'utilization':0},{'membership_id':MEMBERSHIP2,'user_id':USER2,'date':'2026-08-10','is_work_day':True,'holiday':False,'on_leave':True,'capacity_minutes':0,'planned_minutes':0,'work_items':0,'utilization':0}]}
dependency_graph={'nodes':[dict(work_task,impact_score=61,downstream_count=1,blocker_count=0),{**work_task,'id':'92929292-9292-4292-8292-929292929292','task_number':43,'title':'Approve shop drawing','status':'todo','owner_user_id':USER,'owner_name':'Owner User','risk':{'score':20,'level':'low','reasons':{}},'impact_score':20,'downstream_count':0,'blocker_count':1}], 'edges':[{'id':'93939393-9393-4393-8393-939393939393','blocker_task_id':TASK,'blocked_task_id':'92929292-9292-4292-8292-929292929292','dependency_type':'finish_to_start'}]}
plans=[{'id':'plan1','code':'starter','name_ar':'البداية','name_en':'Starter','max_members':25,'max_projects':10,'max_storage_bytes':10737418240,'sort_order':1,'is_active':True}]
templates=[{'id':TPL,'code':'project-manager','name_ar':'مدير مشروع','name_en':'Project Manager','description_ar':'إدارة المشروع','description_en':'Manage project','color':'#7c3aed','icon':'briefcase','category':'management','is_active':True,'is_recommended':True,'sort_order':1}]
template_perms=[{'template_id':TPL,'permission_key':'members.view','allowed':True},{'template_id':TPL,'permission_key':'audit.view','allowed':True}]


ROOT=Path(__file__).resolve().parents[1]
async def local_route(route, request):
 url=urlparse(request.url)
 base=ROOT/'platform-console' if url.hostname=='platform.test' else ROOT
 rel=url.path.lstrip('/') or 'index.html'
 target=(base/rel).resolve()
 if not str(target).startswith(str(base.resolve())) or not target.is_file():
  await route.fulfill(status=404,body='not found'); return
 mime=mimetypes.guess_type(str(target))[0] or 'application/octet-stream'
 await route.fulfill(status=200,content_type=mime,body=target.read_bytes())

captured={'actor':'owner','disabled_entitlements':set(),'client_role':None,'client_member':None,'settings':[],'platform_template':None,'platform_company':None,'storage_uploads':[],'saved_views':[],'bulk_calls':[],'work_settings':[],'work_calls':[],'workflow_calls':[],'pdc_calls':[],'cde_calls':[],'global_actions_enabled':False,'platform_premium':False,'point7_review':False,'operations_calls':[],'operations_followed':False,'point910':False,'point910_frozen':False,'point910_export':None,'point910_calls':[]}

def enable_pdc_contracts():
 if captured.get('pdc_enabled'): return
 captured['pdc_enabled']=True
 if 'module.files' not in entitlement_defs:
  entitlement_defs['module.files']=('files','مساحة المستندات','Document workspace')
  entitlements.append({'key':'module.files','module':'files','name_ar':'مساحة المستندات','name_en':'Document workspace','description_ar':'','description_en':'','scope_mode':'resource','is_active':True,'sort_order':len(entitlements)+1})
  plan_entitlements.append({'plan_id':'plan1','entitlement_key':'module.files','enabled':True,'limits':{}})
 if 'feature.file_versioning' not in entitlement_defs:
  entitlement_defs['feature.file_versioning']=('files','إصدارات الملفات','File versioning')
  entitlements.append({'key':'feature.file_versioning','module':'files','name_ar':'إصدارات الملفات','name_en':'File versioning','description_ar':'','description_en':'','scope_mode':'resource','is_active':True,'sort_order':len(entitlements)+1})
  plan_entitlements.append({'plan_id':'plan1','entitlement_key':'feature.file_versioning','enabled':True,'limits':{}})
 file_defs=[('files.view','عرض الملفات','View files'),('files.upload','رفع الملفات','Upload files'),('files.create_folder','إنشاء المجلدات','Create folders'),('files.rename','إعادة التسمية','Rename files'),('files.move','نقل الملفات','Move files'),('files.archive','نقل للسلة','Move to trash'),('files.restore','استعادة','Restore'),('files.download','تنزيل','Download'),('files.manage','إدارة متقدمة','Manage files')]
 existing={x['key'] for x in perms}
 for k,ar,en in file_defs:
  if k not in existing: perms.append({'key':k,'module':'files','description_ar':ar,'description_en':en,'entitlement_key':'module.files','scope_mode':'resource'})
 owner_existing={(x['role_id'],x['permission_key']) for x in role_perms}
 for k,_,_ in file_defs:
  if (OWNER_ROLE,k) not in owner_existing: role_perms.append({'role_id':OWNER_ROLE,'permission_key':k,'allowed':True})
 for k in ['projects.view','files.view','files.rename','files.move','files.download']:
  if (ENGINEER_ROLE,k) not in owner_existing: role_perms.append({'role_id':ENGINEER_ROLE,'permission_key':k,'allowed':True})
 # enrich project fixture for Project 360 and cards
 projects[0].update({'document_template_id':CDE_TEMPLATE,'project_type':'engineering','client_name':'Alpha Client','manager_user_id':USER,'planned_start_date':'2026-08-01','target_end_date':'2026-12-31','progress_percent':58,'blueprint_id':BLUEPRINT})
 projects[1].update({'project_type':'construction','client_name':'Beta Client','manager_user_id':USER2,'planned_start_date':'2026-09-01','target_end_date':'2027-03-31','progress_percent':12,'blueprint_id':BLUEPRINT})

def enable_point9_contracts():
 enable_pdc_contracts()
 # Treat the limited engineer fixture as the scoped Site Supervisor for this flow.
 roles[1]['slug']='supervisor'; roles[1]['name_ar']='مشرف موقع'; roles[1]['name_en']='Site Supervisor'
 needed=[
  'drawings.view','drawings.create','drawings.edit','drawings.compare','drawings.export','drawings.review','boq.view','boq.edit','files.upload','files.create_folder','files.download','tasks.create','tasks.edit','tasks.complete'
 ]
 existing={x['key'] for x in perms}
 for key in needed:
  if key not in existing:
   perms.append({'key':key,'module':'projects','description_ar':key,'description_en':key,'entitlement_key':'module.projects','scope_mode':'resource'})
 role_existing={(x['role_id'],x['permission_key']) for x in role_perms}
 for key in needed:
  if (ENGINEER_ROLE,key) not in role_existing: role_perms.append({'role_id':ENGINEER_ROLE,'permission_key':key,'allowed':True})

def enable_point10_contracts():
 enable_point9_contracts()
 captured['point10_enabled']=True

def enable_global_action_contracts():
 enable_pdc_contracts()
 captured['global_actions_enabled']=True
 if 'module.notifications' not in entitlement_defs:
  entitlement_defs['module.notifications']=('notifications','صندوق الانتباه','Attention inbox')
  entitlements.append({'key':'module.notifications','module':'notifications','name_ar':'صندوق الانتباه','name_en':'Attention inbox','description_ar':'','description_en':'','scope_mode':'company','is_active':True,'sort_order':len(entitlements)+1})
  plan_entitlements.append({'plan_id':'plan1','entitlement_key':'module.notifications','enabled':True,'limits':{}})
 existing={x['key'] for x in perms}
 if 'notifications.view' not in existing:
  perms.append({'key':'notifications.view','module':'notifications','description_ar':'عرض صندوق الانتباه','description_en':'View attention inbox','entitlement_key':'module.notifications','scope_mode':'company'})
 owner_existing={(x['role_id'],x['permission_key']) for x in role_perms}
 if (OWNER_ROLE,'notifications.view') not in owner_existing:
  role_perms.append({'role_id':OWNER_ROLE,'permission_key':'notifications.view','allowed':True})

def enable_dashboard_contracts():
 enable_global_action_contracts()
 captured['dashboard_enabled']=True
 # Make the dashboard fixture exercise a real schedule signal, without inventing a new backend aggregate.
 projects[0].update({'target_end_date':'2026-08-01','progress_percent':58,'status':'active'})

def session():
 limited=captured.get('actor')=='engineer'
 return {'access_token':'mock-access','refresh_token':'mock-refresh','expires_at':4102444800,'user':{'id':USER2 if limited else USER,'email':'engineer@example.com' if limited else 'owner@example.com','user_metadata':{'full_name':'Engineer User' if limited else 'Owner User'}}}

def table_payload(table, platform=False):
 data={
  'profiles':[profile,profile2], 'account_security':[{'user_id':USER,'must_change_password':False},{'user_id':USER2,'must_change_password':False}],
  'company_memberships':[membership,membership2], 'platform_admins':([] if captured.get('actor')=='engineer' else [{'user_id':USER,'role':'owner','is_active':True}]),
  'service_plans':plans, 'companies':[company], 'company_subscriptions':[subscription], 'roles':roles,
  'permissions':perms, 'entitlements':entitlements, 'service_plan_entitlements':plan_entitlements, 'company_entitlement_overrides':[], 'company_invitations':[], 'projects':projects, 'sites':sites_pdc if captured.get('pdc_enabled') else [], 'project_blueprints':project_blueprints_pdc if captured.get('pdc_enabled') else [], 'folder_templates':[], 'folder_template_nodes':[], 'favorites':[], 'company_branding':[branding],
  'role_templates':templates, 'role_template_permissions':template_perms, 'role_permissions':role_perms,
  'member_permission_overrides':([{'membership_id':MEMBERSHIP2,'permission_key':'files.manage','allowed':True,'reason':'Point 2 custom access QA'},{'membership_id':MEMBERSHIP2,'permission_key':'projects.archive','allowed':False,'reason':'Point 2 custom access QA'}] if captured.get('point2_custom_access') else []), 'member_compensation':[], 'audit_events':activities,
  'organization_units':[{'id':UNIT,'company_id':COMPANY,'parent_id':None,'unit_type':'department','code':'ENG','name_ar':'الهندسة','name_en':'Engineering','description':'Engineering department','color':'#4f46e5','icon':'users','manager_user_id':USER,'sort_order':1,'is_active':True}],
  'organization_unit_memberships':[{'unit_id':UNIT,'membership_id':MEMBERSHIP2,'is_primary':True,'title':'Engineer','joined_at':'2026-08-02'}],
  'role_addons':[], 'role_addon_permissions':[], 'member_role_addons':[], 'access_scope_rules':[], 'access_governance_settings':[{'company_id':COMPANY,'require_second_approval':False,'require_second_approval_for_owner':True,'high_risk_permissions':['members.manage']}],
  'company_work_settings':[{'company_id':COMPANY,'timezone':'Africa/Cairo','work_days':[0,1,2,3,4],'workday_start':'09:00:00','workday_end':'17:00:00','default_weekly_hours':40,'holidays':[],'notification_defaults':{'approval':True,'security':True,'task_due':True,'task_assigned':True}}],
  'member_work_preferences':[{'membership_id':MEMBERSHIP2,'company_id':COMPANY,'default_project_ids':[projects[0]['id']],'notification_preferences':{'task_assigned':True},'calendar_preferences':{'show_team':True}}],
  'workspace_saved_views':captured['saved_views'],
  'notifications':([
    {'id':1001,'company_id':COMPANY,'user_id':USER,'type':'project_review_required','title_ar':'مراجعة مشروع Alpha مطلوبة','title_en':'Alpha project review required','body_ar':'راجع حالة المشروع قبل اجتماع التسليم.','body_en':'Review the project status before the delivery meeting.','entity_type':'project','entity_id':projects[0]['id'],'read_at':None,'created_at':'2026-08-13T21:30:00Z'},
    {'id':1002,'company_id':COMPANY,'user_id':USER,'type':'document_uploaded','title_ar':'تم رفع إصدار جديد','title_en':'A new document version was uploaded','body_ar':'تم تحديث رسم الكهرباء في مساحة المستندات.','body_en':'The electrical drawing was updated in the document workspace.','entity_type':'document','entity_id':DOC,'read_at':None,'created_at':'2026-08-13T20:10:00Z'},
    {'id':1003,'company_id':COMPANY,'user_id':USER,'type':'task_completed','title_ar':'تم إكمال مهمة مراجعة','title_en':'Review work item completed','body_ar':'اكتملت مراجعة المستند.','body_en':'The document review was completed.','entity_type':'task','entity_id':TASK,'read_at':'2026-08-13T19:00:00Z','created_at':'2026-08-13T18:45:00Z'}
  ] if captured.get('global_actions_enabled') else []),
  'work_milestones':[], 'task_templates':[], 'work_workflow_templates':[workflow_template], 'work_automation_rules':[], 'work_automation_runs':[],
  'platform_audit_events':[{'id':1,'actor_id':USER,'action':'platform.company_created','metadata':{'company':'Optimum Test'},'created_at':'2026-08-06T08:00:00Z'}],
 }
 return data.get(table,[])

async def mock_route(route, request):
 url=urlparse(request.url); path=url.path
 try: body=json.loads(request.post_data or '{}')
 except: body={}
 if '/storage/v1/object/' in path:
  if '/sign/' in path:
   await route.fulfill(status=200,content_type='application/json',body=json.dumps({'signedURL':'/storage/v1/object/sign/mock'})); return
  captured['storage_uploads'].append(path)
  await route.fulfill(status=200,content_type='application/json',body='{}'); return
 if '/functions/v1/identity-provisioning' in path:
  if body.get('action')=='create_member':
   captured['client_member']=body
   payload={'ok':True,'company_id':COMPANY,'membership_id':'99999999-9999-4999-8999-999999999999','user_id':'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','email':body['member']['email'],'temporary_password':'Tmp!Pass12345','temporary_password_expires_at':'2026-08-08T00:00:00Z','existing_account':False,'email_delivery':'not_configured'}
  elif body.get('action')=='create_company':
   captured['platform_company']=body
   payload={'ok':True,'company_id':'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','membership_id':'cccccccc-cccc-4ccc-8ccc-cccccccccccc','user_id':'dddddddd-dddd-4ddd-8ddd-dddddddddddd','email':body['owner']['email'],'temporary_password':'Tmp!Owner12345','temporary_password_expires_at':'2026-08-08T00:00:00Z','existing_account':False,'email_delivery':'not_configured'}
  else: payload={'ok':True}
  await route.fulfill(status=200,content_type='application/json',body=json.dumps(payload)); return
 if '/rest/v1/rpc/' in path:
  name=path.rsplit('/',1)[-1]
  if name=='workspace_runtime_policy':
   disabled=set(captured.get('disabled_entitlements') or set())
   effective_entitlements=[{**ent,'enabled':ent['key'] not in disabled,'source':'plan','limits':{}} for ent in entitlements]
   actor_role=ENGINEER_ROLE if captured.get('actor')=='engineer' else OWNER_ROLE
   actor_keys={rp['permission_key'] for rp in role_perms if rp['role_id']==actor_role and rp['allowed']}
   effective_permissions=[perm['key'] for perm in perms if perm['key'] in actor_keys and perm['entitlement_key'] not in disabled]
   payload={'company_id':COMPANY,'operational':True,'platform_admin':False,'plan_id':'plan1','plan_code':'starter','permissions':effective_permissions,'entitlements':effective_entitlements,'limits':{'max_members':25,'max_projects':10,'max_storage_bytes':10737418240},'usage':{'active_members':2,'active_projects':len(projects),'storage_bytes':0}}
  elif name=='global_search':
   query=str(body.get('p_query') or '').lower()
   search_rows=[
    {'entity_type':'project','entity_id':projects[0]['id'],'title':'Alpha Project','subtitle':'ALPHA · Active','project_id':projects[0]['id'],'site_id':None,'folder_id':None},
    {'entity_type':'site','entity_id':SITE,'title':'Alpha Main Site','subtitle':'SITE-01 · Alpha Project','project_id':projects[0]['id'],'site_id':SITE,'folder_id':None},
    {'entity_type':'document','entity_id':DOC,'title':'Electrical Shop Drawing A-102','subtitle':'ALPHA-ELE-001 · Electrical','project_id':projects[0]['id'],'site_id':None,'folder_id':FOLDER},
    {'entity_type':'task','entity_id':TASK,'title':'Review shop drawing','subtitle':'Alpha Project · High priority','project_id':projects[0]['id'],'site_id':None,'folder_id':None}
   ]
   payload=[row for row in search_rows if query in ('alpha','al') or query in (row['title']+' '+str(row['subtitle'])).lower()]
  elif name=='organization_health_snapshot': payload={'score':88,'steps':[{'key':'identity','done':True,'route':'settings','label_ar':'هوية وبيانات الشركة','label_en':'Company identity'},{'key':'branding','done':True,'route':'settings','label_ar':'الهوية البصرية','label_en':'Branding'},{'key':'work','done':True,'route':'organization','label_ar':'أيام وساعات العمل','label_en':'Work schedule'},{'key':'roles','done':True,'route':'roles','label_ar':'الأدوار والصلاحيات','label_en':'Roles & permissions'},{'key':'structure','done':True,'route':'organization','label_ar':'الهيكل التنظيمي','label_en':'Organization structure'},{'key':'team','done':True,'route':'team','label_ar':'الفريق','label_en':'Team'},{'key':'governance','done':True,'route':'roles','label_ar':'حوكمة الوصول','label_en':'Access governance'},{'key':'projects','done':True,'route':'projects','label_ar':'المشاريع','label_en':'Projects'}],'issues':[{'code':'members_no_manager','severity':'warning','route':'team','count':1,'title_ar':'أعضاء بدون مدير مباشر','title_en':'Members without direct manager','detail_ar':'راجع المدير المباشر.','detail_en':'Review the direct manager.'}],'metrics':{'roles':3,'empty_roles':0,'members':2,'active_members':2,'units':1,'projects':2,'pending_first_login':0,'expiring_access':0,'expired_invitations':0,'heavy_overrides':0,'storage_bytes':0},'generated_at':'2026-08-07T16:00:00Z'}
  elif name=='organization_runtime_revision': payload=[{'revision':1,'last_kind':'bootstrap','updated_at':'2026-08-07T16:00:00Z'}]
  elif name=='member_access_snapshot':
   mid=body.get('p_membership_id'); mm=membership2 if mid==MEMBERSHIP2 else membership; pp=profile2 if mid==MEMBERSHIP2 else profile; rr=next(r for r in roles if r['id']==mm['role_id'])
   payload={'membership':mm,'profile':pp,'role':rr,'effective_permissions':[x['permission_key'] for x in role_perms if x['role_id']==rr['id']],'blocked_by_entitlement':[],'scope_rules':[],'addons':[],'organization_units':[{'id':UNIT,'type':'department','name_ar':'الهندسة','name_en':'Engineering','primary':True}] if mid==MEMBERSHIP2 else [],'pages':{'dashboard':True,'team':True,'roles':True,'settings':True}}
  elif name=='member_security_snapshot': payload={'last_sign_in_at':'2026-08-07T12:00:00Z','created_at':'2026-08-01T00:00:00Z','email_confirmed_at':'2026-08-01T00:10:00Z','must_change_password':False,'temporary_password_expires_at':None}
  elif name=='save_workspace_saved_view':
   view={'id':'88888888-8888-4888-8888-888888888888','company_id':COMPANY,'user_id':USER2 if captured.get('actor')=='engineer' else USER,'view_key':body.get('p_view_key'),'name':body.get('p_name'),'filters':body.get('p_filters') or {},'is_default':bool(body.get('p_is_default')),'created_at':'2026-08-07T16:00:00Z','updated_at':'2026-08-07T16:00:00Z'}; captured['saved_views'][:]=[x for x in captured['saved_views'] if x['id']!=view['id']]+[view]; payload=view
  elif name=='delete_workspace_saved_view': captured['saved_views'][:]=[x for x in captured['saved_views'] if x['id']!=body.get('p_view_id')]; payload=True
  elif name in ('bulk_set_member_role','bulk_set_member_status','bulk_restore_member_access'): captured['bulk_calls'].append((name,body)); payload={'ok':True,'changed':len(body.get('p_membership_ids') or body.get('p_items') or [])}
  elif name=='save_company_work_settings': captured['work_settings'].append(body); payload={'company_id':COMPANY,**(body.get('p_payload') or {})}
  elif name=='save_member_work_preferences': payload={'membership_id':body.get('p_membership_id'),'company_id':COMPANY,**(body.get('p_payload') or {})}
  elif name=='work_cockpit_snapshot':
   payload={**work_cockpit,'manager':({**work_cockpit['manager'],'enabled':captured.get('actor')!='engineer'} if captured.get('actor')!='engineer' else {'enabled':False,'unassigned':0,'high_risk':0,'attention':[],'overloaded':[]})}
  elif name=='work_capacity_plan': payload=capacity_plan
  elif name=='work_dependency_graph': payload=dependency_graph
  elif name=='save_work_workflow_template': captured['workflow_calls'].append((name,body)); payload=workflow_template['id']
  elif name=='instantiate_work_workflow_template': captured['workflow_calls'].append((name,body)); payload={'template_id':body.get('p_template_id'),'task_ids':[TASK,'92929292-9292-4292-8292-929292929292'],'count':2}
  elif name=='work_task_query': payload={'items':[work_task],'total':1,'offset':0,'limit':60,'has_more':False}
  elif name=='work_delivery_snapshot': payload={'open':1,'due_today':0,'overdue':0,'blocked':0,'high_risk':0,'completed_week':2,'attention':[work_task],'workload':[{'user_id':USER2,'membership_id':MEMBERSHIP2,'name':'Engineer User','capacity_hours':40,'planned_minutes':240,'utilization':10}],'milestones':[]}
  elif name=='project_control_portfolio':
   payload={'generated_at':'2026-08-15T15:00:00Z','summary':{'projects':3,'stable':1,'watch':1,'at_risk':0,'critical':1,'decisions':3},'projects':[{'id':projects[0]['id'],'code':'ALPHA','name':'Alpha Project','status':'active','project_type':'engineering','client_name':'Alpha Client','manager_user_id':USER,'manager_name':'Owner User','planned_start_date':'2026-06-01','target_end_date':'2026-10-31','updated_at':'2026-08-15T12:00:00Z','metrics':P11_CRITICAL},{'id':projects[1]['id'],'code':'BETA','name':'Beta Project','status':'active','project_type':'engineering','client_name':'Beta Client','manager_user_id':USER2,'manager_name':'Engineer User','planned_start_date':'2026-06-15','target_end_date':'2026-11-30','updated_at':'2026-08-15T11:00:00Z','metrics':P11_WATCH},{'id':P11_PROJECT3,'code':'GAMMA','name':'Gamma Project','status':'active','project_type':'engineering','client_name':'Gamma Client','manager_user_id':USER,'manager_name':'Owner User','planned_start_date':'2026-05-01','target_end_date':'2026-09-30','updated_at':'2026-08-15T10:00:00Z','metrics':P11_STABLE}],'team_bottlenecks':[{'user_id':USER2,'name':'Engineer User','open_count':12,'overdue':4,'blocked':2},{'user_id':USER,'name':'Owner User','open_count':5,'overdue':1,'blocked':0}],'trend':[{'week_start':'2026-07-06','tasks_done':8,'issues_opened':5,'issues_closed':2,'documents_added':7,'approved_reports':2},{'week_start':'2026-07-13','tasks_done':10,'issues_opened':4,'issues_closed':3,'documents_added':9,'approved_reports':3},{'week_start':'2026-07-20','tasks_done':11,'issues_opened':4,'issues_closed':4,'documents_added':10,'approved_reports':4},{'week_start':'2026-07-27','tasks_done':13,'issues_opened':3,'issues_closed':5,'documents_added':12,'approved_reports':4},{'week_start':'2026-08-03','tasks_done':15,'issues_opened':3,'issues_closed':6,'documents_added':13,'approved_reports':5},{'week_start':'2026-08-10','tasks_done':17,'issues_opened':2,'issues_closed':7,'documents_added':15,'approved_reports':6}],'decisions':[{'entity_type':'milestone','entity_id':'21111111-1111-4111-8111-111111111121','project_id':projects[0]['id'],'site_id':None,'title':'Site A handover milestone','action_kind':'milestone','severity':'critical','severity_rank':1,'created_at':'2026-08-14T08:00:00Z'},{'entity_type':'site_field_issue','entity_id':P10_ISSUE,'project_id':projects[0]['id'],'site_id':SITE,'title':'Critical cabinet issue','action_kind':'field_issue','severity':'critical','severity_rank':1,'created_at':'2026-08-15T10:00:00Z'},{'entity_type':'site_constraint','entity_id':P10_CONSTRAINT,'project_id':projects[0]['id'],'site_id':SITE,'title':'Material delivery blocked','action_kind':'constraint','severity':'warning','severity_rank':2,'created_at':'2026-08-13T10:00:00Z'}],'capabilities':{'view_workload':True}}
  elif name=='project_control_project':
   payload={'project':{**projects[0],'project_type':'engineering','client_name':'Alpha Client','manager_user_id':USER,'planned_start_date':'2026-06-01','target_end_date':'2026-10-31','progress_percent':52},'manager_name':'Owner User','metrics':P11_CRITICAL,'sites':[{'id':SITE,'code':'SITE-01','name':'Alpha Main Site','status':'active','target_end_date':'2026-09-30','manager_user_id':USER2,'manager_name':'Engineer User','tasks_open':9,'tasks_overdue':4,'issues_open':3,'critical_issues':1,'constraints_open':2,'failed_inspections':1,'cabinets_total':6,'cabinets_complete':2,'last_report_status':'submitted'},{'id':'22111111-1111-4111-8111-111111111122','code':'SITE-02','name':'Alpha Secondary Site','status':'active','target_end_date':'2026-10-15','manager_user_id':USER,'manager_name':'Owner User','tasks_open':4,'tasks_overdue':1,'issues_open':1,'critical_issues':0,'constraints_open':0,'failed_inspections':0,'cabinets_total':4,'cabinets_complete':3,'last_report_status':'approved'}],'milestones':[{'id':'21111111-1111-4111-8111-111111111121','title':'Site A handover','description':'Handover readiness','due_at':'2026-08-14T00:00:00Z','status':'missed','weight':30,'owner_user_id':USER2,'owner_name':'Engineer User','overdue':True},{'id':'23111111-1111-4111-8111-111111111123','title':'As-Built approval','description':'Final drawings','due_at':'2026-08-28T00:00:00Z','status':'at_risk','weight':20,'owner_user_id':USER,'owner_name':'Owner User','overdue':False}],'risks':[{'rank':1,'entity_type':'site_field_issue','entity_id':P10_ISSUE,'site_id':SITE,'title':'Critical cabinet issue','severity':'critical','created_at':'2026-08-15T10:00:00Z','detail':'CAB-01 requires rework'},{'rank':2,'entity_type':'site_constraint','entity_id':P10_CONSTRAINT,'site_id':SITE,'title':'Material delivery blocked','severity':'warning','created_at':'2026-08-13T10:00:00Z','detail':'Awaiting supplier delivery'},{'rank':3,'entity_type':'task','entity_id':TASK,'site_id':SITE,'title':'Review shop drawing','severity':'warning','created_at':'2026-08-14T12:00:00Z','detail':'Overdue'}],'team_bottlenecks':[{'user_id':USER2,'name':'Engineer User','open_count':12,'overdue':4,'blocked':2}],'trend':[{'week_start':'2026-07-06','tasks_done':3,'issues_opened':3,'issues_closed':1,'documents_added':4,'reports_approved':1},{'week_start':'2026-07-13','tasks_done':4,'issues_opened':2,'issues_closed':1,'documents_added':5,'reports_approved':2},{'week_start':'2026-07-20','tasks_done':5,'issues_opened':2,'issues_closed':2,'documents_added':6,'reports_approved':2},{'week_start':'2026-07-27','tasks_done':5,'issues_opened':2,'issues_closed':3,'documents_added':7,'reports_approved':3},{'week_start':'2026-08-03','tasks_done':6,'issues_opened':1,'issues_closed':3,'documents_added':7,'reports_approved':3},{'week_start':'2026-08-10','tasks_done':7,'issues_opened':1,'issues_closed':4,'documents_added':8,'reports_approved':4}],'brief':None,'capabilities':{'manage':True,'view_workload':True}}
  elif name=='project_control_weekly_brief':
   status=captured.get('p11_brief_status'); linked=captured.get('p11_report_linked',False)
   authored=None if not captured.get('p11_brief_created') else {'id':P11_BRIEF,'company_id':COMPANY,'project_id':projects[0]['id'],'week_start':'2026-08-10','status':status or 'draft','executive_summary':captured.get('p11_summary','Alpha is under pressure but recovery actions are defined.'),'decisions_needed':captured.get('p11_decisions','Approve material escalation and Site A recovery plan.'),'next_week_plan':captured.get('p11_next','Close CAB-01 issue and recover handover milestone.'),'management_note':captured.get('p11_note','Management intervention required.'),'report_document_id':P11_REPORT_DOC if linked else None,'reviewer_note':captured.get('p11_reviewer_note')}
   payload={'project':{'id':projects[0]['id'],'code':'ALPHA','name':'Alpha Project'},'week_start':'2026-08-10','week_end':'2026-08-16','metrics':P11_CRITICAL,'completed_tasks':[{'id':'24111111-1111-4111-8111-111111111124','title':'Complete CAB-02 installation','site_id':SITE,'completed_at':'2026-08-14T11:00:00Z'},{'id':'25111111-1111-4111-8111-111111111125','title':'Upload Site A test certificate','site_id':SITE,'completed_at':'2026-08-13T10:00:00Z'}],'drawings_changed':[{'id':OPS_DRAWING,'drawing_no':'ALPHA-SITE01-CAB01-001','title':'CAB-01 As-Built','site_id':SITE,'status':'draft','updated_at':'2026-08-15T10:15:00Z'}],'issues_closed':[{'id':'26111111-1111-4111-8111-111111111126','title':'Close chamber snag','site_id':SITE,'severity':'medium','closed_at':'2026-08-14T09:00:00Z'}],'decisions_needed':[{'rank':1,'entity_type':'site_field_issue','entity_id':P10_ISSUE,'site_id':SITE,'title':'Critical cabinet issue','created_at':'2026-08-15T10:00:00Z'},{'rank':2,'entity_type':'site_constraint','entity_id':P10_CONSTRAINT,'site_id':SITE,'title':'Material delivery blocked','created_at':'2026-08-13T10:00:00Z'}],'next_week':[{'entity_type':'milestone','entity_id':'23111111-1111-4111-8111-111111111123','site_id':None,'title':'As-Built approval','due_at':'2026-08-28T00:00:00Z'}],'authored':authored,'can_manage':True}
  elif name=='save_project_control_brief':
   captured.setdefault('p11_calls',[]).append((name,body)); captured['p11_brief_created']=True; captured['p11_brief_status']='submitted' if body.get('p_submit') else 'draft'; pay=body.get('p_payload') or {}; captured['p11_summary']=pay.get('executive_summary'); captured['p11_decisions']=pay.get('decisions_needed'); captured['p11_next']=pay.get('next_week_plan'); captured['p11_note']=pay.get('management_note'); payload={'id':P11_BRIEF,'status':captured['p11_brief_status']}
  elif name=='review_project_control_brief':
   captured.setdefault('p11_calls',[]).append((name,body)); captured['p11_brief_status']=body.get('p_decision'); captured['p11_reviewer_note']=body.get('p_note'); payload={'id':P11_BRIEF,'status':captured['p11_brief_status'],'reviewer_note':captured.get('p11_reviewer_note')}
  elif name=='resolve_project_control_folder': payload=FOLDER
  elif name=='link_project_control_brief_document': captured.setdefault('p11_calls',[]).append((name,body)); captured['p11_report_linked']=True; payload={'id':P11_BRIEF,'report_document_id':body.get('p_document_id')}
  elif name=='site_supervisor_workspace':
   payload={
    'generated_at':'2026-08-15T13:00:00Z','role_slug':'supervisor','is_site_supervisor':True,
    'sites':[{'id':SITE,'project_id':projects[0]['id'],'code':'SITE-01','name':'Alpha Main Site','manager_user_id':USER2,'status':'active','target_end_date':'2026-12-31','project_code':'ALPHA','project_name':'Alpha Project'}],
    'site':{'id':SITE,'company_id':COMPANY,'project_id':projects[0]['id'],'code':'SITE-01','name':'Alpha Main Site','status':'active','manager_user_id':USER2,'address':'New Cairo','target_end_date':'2026-12-31'},
    'project':{'id':projects[0]['id'],'code':'ALPHA','name':'Alpha Project','status':'active'},
    'tasks':[{'id':TASK,'title':'مراجعة كابينة CAB-01','status':'in_progress','priority':'high','due_at':'2026-08-15T15:00:00Z','folder_id':None,'project_id':projects[0]['id'],'site_id':SITE,'task_type':'field','action_role':'execute'}],
    'cabinets':[{'id':CABINET,'code':'CAB-01','name':'Cabinet One','cabinet_type':'fiber_cabinet','status':'active','location_label':'Zone A','root_folder_id':CAB_ROOT,'requirement_count':3,'requirement_ready':2,'drawing_count':1,'last_drawing_at':'2026-08-15T10:00:00Z'}],
    'drawings':[{'id':OPS_DRAWING,'drawing_no':'ALPHA-SITE01-CAB01-001','title':'CAB-01 As-Built','status':'active','cabinet_id':CABINET,'current_revision_id':'rev-point9','updated_at':'2026-08-15T10:15:00Z','last_change_at':'2026-08-15T10:15:00Z','cabinet_code':'CAB-01','cabinet_name':'Cabinet One','revision_code':'R1','revision_status':'draft','cde_document_id':SITE_DOC,'my_drawing':True}],
    'documents':[{'id':SITE_DOC,'display_name':'CAB-01 Test Certificate.pdf','document_type':'certificate','control_status':'approved','folder_id':SITE_FOLDER,'updated_at':'2026-08-15T09:00:00Z','current_version_id':SITE_VERSION,'revision_code':'1','original_filename':'CAB-01-Test-Certificate-R1.pdf','version_created_at':'2026-08-15T09:00:00Z','expires_at':None}],
    'stats':{'tasks_open':1,'tasks_overdue':0,'tasks_today':1,'cabinets':1,'requirements_total':3,'requirements_ready':2,'drawings':1,'draft_drawings':1},
    'capabilities':{'can_create_drawing':True,'can_edit_drawing':True,'can_edit_takeoff':True,'can_upload':True,'can_create_task':True,'can_complete_task':True}
   }
  elif name=='site_execution_workspace':
   payload={
    'date':'2026-08-15','site':{'id':SITE,'code':'SITE-01','name':'Alpha Main Site','status':'active','target_end_date':'2026-12-31','manager_user_id':USER2},
    'project':{'id':projects[0]['id'],'code':'ALPHA','name':'Alpha Project','status':'active','target_end_date':'2026-12-31'},
    'daily_log':{'id':P10_LOG,'company_id':COMPANY,'project_id':projects[0]['id'],'site_id':SITE,'log_date':'2026-08-15','status':'draft','summary':'','work_completed':'تم تركيب واختبار CAB-01','tomorrow_plan':'استكمال المسار','safety_note':'لا توجد ملاحظات سلامة','weather_note':'طقس مستقر','manpower':{'crew_count':6,'work_hours':8},'equipment':[],'report_document_id':(P10_REPORT_DOC if captured.get('point10_report_linked') else None),'created_at':'2026-08-15T07:00:00Z','updated_at':'2026-08-15T12:00:00Z'},
    'report_folder_id':SITE_FOLDER,
    'capabilities':{'can_edit':True,'can_review_report':captured.get('actor')!='engineer','can_upload':True,'can_create_task':True},
    'templates':[{'id':'15101010-1010-4010-8010-101010101015','code':'cabinet-readiness','name_ar':'فحص جاهزية الكابينة','name_en':'Cabinet Readiness','description_ar':'فحص سريع قبل الإغلاق','description_en':'Fast pre-closeout field check','applies_to':'cabinet','items':[{'key':'physical','label_ar':'التركيب والحالة الفيزيائية','label_en':'Physical installation','required':True},{'key':'evidence','label_ar':'الصور والأدلة المطلوبة','label_en':'Required evidence','required':True}]}],
    'inspections':[{'id':P10_INSPECTION,'title':'فحص CAB-01','status':'in_progress','cabinet_id':CABINET,'drawing_id':OPS_DRAWING,'task_id':None,'template_id':'15101010-1010-4010-8010-101010101015','started_at':'2026-08-15T09:00:00Z','completed_at':None,'overall_note':'','items':[{'id':'i1','inspection_id':P10_INSPECTION,'item_key':'physical','label_ar':'التركيب والحالة الفيزيائية','label_en':'Physical installation','result':'pass','note':'سليم','sort_order':10},{'id':'i2','inspection_id':P10_INSPECTION,'item_key':'evidence','label_ar':'الصور والأدلة المطلوبة','label_en':'Required evidence','result':'pending','note':'','sort_order':20}]}],
    'issues':[{'id':P10_ISSUE,'title':'إعادة تثبيت ملصق CAB-01','description':'الملصق يحتاج تثبيت أفضل','severity':'medium','status':'open','cabinet_id':CABINET,'assigned_to':USER2,'due_at':'2026-08-16T12:00:00Z','created_at':'2026-08-15T10:00:00Z','updated_at':'2026-08-15T10:00:00Z'}],
    'constraints':[{'id':P10_CONSTRAINT,'constraint_type':'material','title':'انتظار وصلة نهائية','description':'المورد في الطريق','impact':'يؤخر إغلاق المسار','status':'open','started_at':'2026-08-15T10:30:00Z','updated_at':'2026-08-15T10:30:00Z'}],
    'tasks_today':[{'id':TASK,'title':'مراجعة كابينة CAB-01','status':'in_progress','priority':'high','due_at':'2026-08-15T15:00:00Z','progress':60}],
    'documents_today':[{'id':SITE_DOC,'display_name':'CAB-01 Test Certificate.pdf','document_type':'certificate','created_at':'2026-08-15T09:00:00Z','current_version_id':SITE_VERSION,'folder_id':SITE_FOLDER}],
    'drawings_today':[{'id':OPS_DRAWING,'drawing_no':'ALPHA-SITE01-CAB01-001','title':'CAB-01 As-Built','status':'active','cabinet_id':CABINET,'updated_at':'2026-08-15T10:15:00Z','last_change_at':'2026-08-15T10:15:00Z'}],
    'completed_tasks':[{'id':'16101010-1010-4010-8010-101010101016','title':'تركيب الكابينة','completed_at':'2026-08-15T11:00:00Z'}],
    'events':[{'id':'17101010-1010-4010-8010-101010101017','event_type':'saved','actor_id':USER2,'note':'تحديث سجل اليوم','metadata':{},'created_at':'2026-08-15T12:00:00Z'}],
    'progress':{'tasks_done_today':1,'tasks_open':1,'tasks_overdue':0,'inspections_done':0,'inspections_failed':0,'issues_open':1,'critical_issues':0,'constraints_open':1,'documents_added':1,'drawings_changed':1}
   }
  elif name=='site_end_of_day_review':
   payload={'score':5,'total':7,'percent':71,'checks':[{'key':'log','done':True},{'key':'work','done':True},{'key':'critical','done':True},{'key':'inspection','done':False},{'key':'evidence','done':True},{'key':'tomorrow','done':True},{'key':'submit','done':False}]}
  elif name=='site_weekly_progress':
   payload={'week_start':'2026-08-09','week_end':'2026-08-15','summary':{'tasks_done':8,'inspections':4,'failed_inspections':1,'issues_created':3,'issues_closed':2,'documents_added':12,'approved_reports':4},'days':[{'date':'2026-08-15','tasks_done':1,'inspections':1,'issues_created':1,'documents':1,'report_status':'draft'}]}
  elif name=='ensure_site_daily_log': payload={'id':P10_LOG,'company_id':COMPANY,'project_id':projects[0]['id'],'site_id':SITE,'log_date':'2026-08-15','status':'draft'}
  elif name=='save_site_daily_log': captured.setdefault('point10_calls',[]).append((name,body)); payload={'id':P10_LOG,'status':'draft'}
  elif name=='submit_site_daily_log': captured.setdefault('point10_calls',[]).append((name,body)); payload={'id':P10_LOG,'status':'submitted'}
  elif name=='review_site_daily_log': captured.setdefault('point10_calls',[]).append((name,body)); payload={'id':P10_LOG,'status':body.get('p_decision')}
  elif name=='create_site_inspection': captured.setdefault('point10_calls',[]).append((name,body)); payload={'inspection':{'id':P10_INSPECTION},'items':[]}
  elif name=='save_site_inspection': captured.setdefault('point10_calls',[]).append((name,body)); payload={'inspection':{'id':P10_INSPECTION,'status':'passed' if body.get('p_complete') else 'in_progress'},'items':[]}
  elif name=='create_site_field_issue': captured.setdefault('point10_calls',[]).append((name,body)); payload={'id':P10_ISSUE,'status':'open'}
  elif name=='update_site_field_issue': captured.setdefault('point10_calls',[]).append((name,body)); payload={'id':P10_ISSUE,'status':body.get('p_status')}
  elif name=='save_site_constraint': captured.setdefault('point10_calls',[]).append((name,body)); payload={'id':P10_CONSTRAINT,'status':'open'}
  elif name=='resolve_site_constraint': captured.setdefault('point10_calls',[]).append((name,body)); payload={'id':P10_CONSTRAINT,'status':'resolved'}
  elif name=='link_site_daily_report_document': captured.setdefault('point10_calls',[]).append((name,body)); captured['point10_report_linked']=True; payload=None
  elif name=='resolve_site_execution_context': payload={'type':body.get('p_entity_type'),'entity_id':body.get('p_entity_id'),'company_id':COMPANY,'project_id':projects[0]['id'],'site_id':SITE,'cabinet_id':CABINET,'work_date':'2026-08-15'}
  elif name=='site_operations_feed':
   payload={'changes':[{'entity_type':'site_inspection','entity_id':P10_INSPECTION,'title':'فحص CAB-01','project_id':projects[0]['id'],'site_id':SITE,'created_at':'2026-08-15T11:00:00Z','actor_id':USER2,'action':'field.inspection.in_progress','metadata':{'status':'in_progress','cabinet_id':CABINET}},{'entity_type':'site_field_issue','entity_id':P10_ISSUE,'title':'إعادة تثبيت ملصق CAB-01','project_id':projects[0]['id'],'site_id':SITE,'created_at':'2026-08-15T10:00:00Z','actor_id':USER2,'action':'field.issue.open','metadata':{'severity':'medium'}}],'approvals':([] if captured.get('actor')=='engineer' else [{'kind':'site_daily_log','entity_type':'site_daily_log','entity_id':P10_LOG,'title':'Daily report · SITE-01 · 2026-08-15','project_id':projects[0]['id'],'site_id':SITE,'at':'2026-08-15T13:00:00Z','action_kind':'daily_report_review','status':'submitted'}])}
  elif name=='site_execution_calendar_feed':
   payload=[{'kind':'field_inspection','id':P10_INSPECTION,'title':'فحص CAB-01','status':'in_progress','start_at':'2026-08-15T09:00:00Z','end_at':'2026-08-15T09:00:00Z','all_day':False,'project_id':projects[0]['id'],'site_id':SITE,'entity_type':'site_inspection'},{'kind':'daily_report','id':P10_LOG,'title':'Daily report · SITE-01','status':'draft','start_at':'2026-08-15T00:00:00Z','end_at':'2026-08-15T00:00:00Z','all_day':True,'project_id':projects[0]['id'],'site_id':SITE,'entity_type':'site_daily_log'}]
  elif name=='operations_center_snapshot':
   engineer=captured.get('actor')=='engineer'
   payload={
    'generated_at':'2026-08-15T11:40:00Z','last_seen_at':'2026-08-14T10:00:00Z',
    'calendar_layers':{'tasks':True,'reviews':True,'documents':True,'drawings':True,'delivery':True,'projects':True},
    'tasks':[{'kind':'task','entity_type':'task','entity_id':TASK,'title':'مراجعة مخطط الكابينة','status':'in_progress','priority':'high','due_at':'2026-08-15T15:00:00Z','project_id':projects[0]['id'],'site_id':SITE,'task_type':'review','action_role':'execute' if engineer else 'review'}],
    'approvals':([] if engineer else [
      {'kind':'document','entity_type':'document','entity_id':DOC,'title':'Electrical Shop Drawing A-102','project_id':projects[0]['id'],'site_id':None,'at':'2026-08-15T09:00:00Z','action_kind':'document_review','status':'in_review'},
      {'kind':'site_claim_package','entity_type':'site_claim_package','entity_id':CLAIM,'title':'حزمة تسليم الموقع','project_id':projects[0]['id'],'site_id':SITE,'at':'2026-08-15T08:00:00Z','action_kind':'delivery_review','status':'submitted'}
    ]),
    'notifications':([] if engineer else [
      {'id':1001,'type':'project_review_required','title_ar':'مراجعة مشروع Alpha مطلوبة','title_en':'Alpha project review required','body_ar':'راجع حالة المشروع قبل اجتماع التسليم.','body_en':'Review the project status before the delivery meeting.','entity_type':'project','entity_id':projects[0]['id'],'created_at':'2026-08-15T10:30:00Z'},
      {'id':1002,'type':'document_uploaded','title_ar':'تم رفع إصدار جديد','title_en':'A new document version was uploaded','body_ar':'تم تحديث رسم الكهرباء.','body_en':'The electrical drawing was updated.','entity_type':'document','entity_id':DOC,'created_at':'2026-08-15T10:00:00Z'}
    ]),
    'changes':[
      {'entity_type':'engineering_drawing','entity_id':OPS_DRAWING,'title':'CAB-01 As-Built','project_id':projects[0]['id'],'site_id':SITE,'created_at':'2026-08-15T10:15:00Z','actor_id':USER2,'action':'saved','metadata':{'nodes_changed':2}},
      {'entity_type':'document','entity_id':DOC,'title':'Electrical Shop Drawing A-102','project_id':projects[0]['id'],'site_id':None,'created_at':'2026-08-15T10:00:00Z','actor_id':USER2,'action':'document.version_uploaded','metadata':{'version_number':3,'revision_code':'R3'}}
    ],
    'follows':([{'entity_type':'engineering_drawing','entity_id':OPS_DRAWING,'created_at':'2026-08-15T10:20:00Z'}] if captured.get('operations_followed') else [])
   }
  elif name=='operations_calendar_feed':
   payload=[
    {'kind':'task','id':TASK,'title':'مراجعة مخطط الكابينة','status':'in_progress','start_at':'2026-08-15T09:00:00Z','end_at':'2026-08-15T15:00:00Z','all_day':False,'project_id':projects[0]['id'],'site_id':SITE,'entity_type':'task'},
    {'kind':'document_review','id':DOC,'title':'Electrical Shop Drawing A-102','status':'in_review','start_at':'2026-08-16T09:00:00Z','end_at':'2026-08-16T09:00:00Z','all_day':False,'project_id':projects[0]['id'],'entity_type':'document'},
    {'kind':'drawing_change','id':OPS_DRAWING,'title':'CAB-01 As-Built','status':'draft','start_at':'2026-08-15T10:15:00Z','end_at':'2026-08-15T10:15:00Z','all_day':False,'project_id':projects[0]['id'],'site_id':SITE,'entity_type':'engineering_drawing'},
    {'kind':'delivery_review','id':CLAIM,'title':'حزمة تسليم الموقع','status':'submitted','start_at':'2026-08-17T08:00:00Z','end_at':'2026-08-17T08:00:00Z','all_day':False,'project_id':projects[0]['id'],'site_id':SITE,'entity_type':'site_claim_package'},
    {'kind':'project_target','id':projects[0]['id'],'title':'Alpha Project','status':'active','start_at':'2026-08-20T00:00:00Z','end_at':'2026-08-20T00:00:00Z','all_day':True,'project_id':projects[0]['id'],'entity_type':'project'}
   ]
  elif name=='operations_center_mark_seen': captured['operations_calls'].append((name,body)); payload='2026-08-15T11:40:00Z'
  elif name=='save_operations_calendar_layers': captured['operations_calls'].append((name,body)); payload=body.get('p_layers') or {}
  elif name=='toggle_entity_follow':
   captured['operations_calls'].append((name,body)); captured['operations_followed']=not captured.get('operations_followed'); payload=captured['operations_followed']
  elif name=='work_calendar_feed': payload=[{'kind':'task','id':TASK,'title':'Review shop drawing','task_type':'review','status':'in_progress','priority':'high','start_at':'2026-08-08T08:00:00Z','end_at':'2026-08-09T12:00:00Z','all_day':False,'project_id':projects[0]['id'],'owner_user_id':USER2,'risk':{'score':35,'level':'medium'}},{'kind':'holiday','id':None,'title':'Test Holiday','status':'holiday','start_at':'2026-08-10T00:00:00Z','end_at':'2026-08-11T00:00:00Z','all_day':True}]
  elif name=='work_activity_feed': payload={'items':[work_activity],'total':1,'offset':0,'limit':60,'has_more':False}
  elif name=='work_runtime_revision': payload=[{'revision':7,'updated_at':'2026-08-07T21:00:00Z'}]
  elif name=='work_leave_requests': payload={'items':[],'total':0,'offset':0,'limit':100,'has_more':False,'can_manage':captured.get('actor')!='engineer'}
  elif name=='work_task_detail': payload={'task':work_task,'risk':work_task['risk'],'capabilities':{'edit':True,'complete':True,'claim':False,'comment':True,'attach':True,'assign':captured.get('actor')!='engineer'},'assignments':[{'id':'a1','user_id':USER2,'role_id':None,'assigned_by':USER,'name':'Engineer User'}],'watchers':[],'checklist':[{'id':'c1','task_id':TASK,'body':'Check dimensions','position':0,'is_completed':False,'created_at':'2026-08-07T20:00:00Z'}],'comments':[{'id':'cm1','task_id':TASK,'author_id':USER2,'author_name':'Engineer User','body':'Started review','created_at':'2026-08-07T20:30:00Z'}],'attachments':[],'events':[{'id':1,'task_id':TASK,'actor_id':USER2,'actor_name':'Engineer User','event_type':'task.status_changed','created_at':'2026-08-07T21:00:00Z'}],'blockers':[],'downstream':[],'milestone':None}
  elif name=='work_assignment_candidates': payload=[{'membership_id':MEMBERSHIP2,'user_id':USER2,'full_name':'Engineer User','job_title':'Electrical Engineer','experience_level':'senior','skills':['CAD','QA'],'weekly_capacity':40,'planned_minutes':240,'utilization_percent':10,'on_leave':False,'permission_ok':True,'site_match':True,'skill_match_count':1,'score':95,'reasons':[{'key':'permission','ok':True},{'key':'capacity','ok':True,'utilization':10}]}]
  elif name in ('save_work_item','save_task_dependency','delete_task_dependency','save_work_milestone','save_member_leave_period','cancel_member_leave_period','save_task_template','save_work_automation_rule','test_work_automation_rule','set_task_status','add_task_comment','add_task_checklist_item'):
   captured['work_calls'].append((name,body)); payload={'id':TASK,'lock_version':4,'ok':True,'matches':True,'trigger':'task.created','actions':[]}
  elif name=='file_workspace_snapshot':
   folder_id=body.get('p_folder_id'); docs=[]
   if folder_id==FOLDER: docs=[{**document_pdc,'version_number':version_pdc['version_number'],'version_label':version_pdc['version_label'],'original_filename':version_pdc['original_filename'],'mime_type':version_pdc['mime_type'],'size_bytes':version_pdc['size_bytes'],'upload_state':'ready','change_note':version_pdc['change_note'],'uploaded_by':USER2,'finalized_at':version_pdc['finalized_at']}]
   if body.get('p_site_id')==SITE:
    if folder_id==SITE_FOLDER: docs=[{**site_document_pdc,'version_number':1,'version_label':'v1','original_filename':site_version_pdc['original_filename'],'mime_type':'application/pdf','size_bytes':site_version_pdc['size_bytes'],'upload_state':'ready','change_note':'As-built','uploaded_by':USER2,'finalized_at':site_version_pdc['finalized_at']}]
    payload={'project':{'id':projects[0]['id'],'code':'ALPHA','name':'Alpha Project','status':'active','archived_at':None},'site':sites_pdc[0],'folders':site_folders_delivery,'documents':docs}
   else: payload={'project':{'id':projects[0]['id'],'code':'ALPHA','name':'Alpha Project','status':'active','archived_at':None},'site':None,'folders':folders_pdc,'documents':docs}
  elif name=='document_directory_query':
   payload=[{**document_pdc,**{k:version_pdc.get(k) for k in ['version_number','version_label','revision_code','original_filename','storage_bucket','storage_path','mime_type','size_bytes','upload_state','change_note','uploaded_by','uploader_name','finalized_at']}},{**site_document_pdc,**{k:site_version_pdc.get(k) for k in ['version_number','version_label','revision_code','original_filename','storage_bucket','storage_path','mime_type','size_bytes','upload_state','change_note','uploaded_by','uploader_name','finalized_at']}}]
  elif name=='folder_template_catalog':
   payload=[
    {'id':CDE_TEMPLATE,'company_id':None,'name_ar':'الهيكل الهندسي الأساسي','name_en':'Optimum Engineering Core','description_ar':'هيكل هندسي واضح','description_en':'Clear engineering structure','is_default':True,'is_active':True,'template_kind':'engineering','is_builtin':True,'naming_rules':{'pattern':'{project}-{site}-{cabinet}-{discipline}-{type}-{revision}','enforce':False},'requirements':[],'nodes':[{'id':'n01','parent_id':None,'code':'01','name_ar':'عام','name_en':'General','sort_order':10,'allows_children':True},{'id':'n02','parent_id':None,'code':'02','name_ar':'الرسومات','name_en':'Drawings','sort_order':20,'allows_children':True},{'id':'n0201','parent_id':'n02','code':'02.01','name_ar':'اسكتشات','name_en':'Sketches','sort_order':10,'allows_children':True},{'id':'n0202','parent_id':'n02','code':'02.02','name_ar':'تخطيط','name_en':'Planning','sort_order':20,'allows_children':True},{'id':'n0203','parent_id':'n02','code':'02.03','name_ar':'مدني','name_en':'Civil','sort_order':30,'allows_children':True},{'id':'n0204','parent_id':'n02','code':'02.04','name_ar':'كهرباء','name_en':'Electrical','sort_order':40,'allows_children':True},{'id':'n0205','parent_id':'n02','code':'02.05','name_ar':'مدني وكهرباء','name_en':'Civil & Electrical','sort_order':50,'allows_children':True},{'id':'n0206','parent_id':'n02','code':'02.06','name_ar':'رسومات كما نُفذ (As-Built)','name_en':'As-Built','sort_order':60,'allows_children':True}]},
    {'id':'f1f1f1f1-f1f1-41f1-81f1-f1f1f1f1f1f1','company_id':None,'name_ar':'تسليم الاتصالات والفايبر','name_en':'Telecom / Fiber Delivery','description_ar':'من المسح حتى الاختبار والتسليم','description_en':'Survey through testing and handover','is_default':False,'is_active':True,'template_kind':'telecom','is_builtin':True,'naming_rules':{'pattern':'{project}-{site}-{cabinet}-{type}-{revision}','enforce':False},'requirements':[],'nodes':[{'id':'tn1','parent_id':None,'code':'01','name_ar':'المسح والتخطيط','name_en':'Survey & Planning','sort_order':10,'allows_children':True},{'id':'tn2','parent_id':None,'code':'02','name_ar':'الرسومات','name_en':'Drawings','sort_order':20,'allows_children':True},{'id':'tn3','parent_id':None,'code':'03','name_ar':'الاختبارات والتشغيل','name_en':'Testing & Commissioning','sort_order':30,'allows_children':True}]},
    {'id':'f2f2f2f2-f2f2-42f2-82f2-f2f2f2f2f2f2','company_id':None,'name_ar':'الإنشاءات والتسليم','name_en':'Construction Control & Handover','description_ar':'رسومات وQA/QC ومستخلاصات وتسليم','description_en':'Drawings, QA/QC, payment and handover','is_default':False,'is_active':True,'template_kind':'construction','is_builtin':True,'naming_rules':{},'requirements':[],'nodes':[{'id':'kn1','parent_id':None,'code':'01','name_ar':'الرسومات','name_en':'Drawings','sort_order':10,'allows_children':True},{'id':'kn2','parent_id':None,'code':'02','name_ar':'QA/QC والفحوصات','name_en':'QA/QC & Inspections','sort_order':20,'allows_children':True},{'id':'kn3','parent_id':None,'code':'03','name_ar':'التسليم وAs-Built','name_en':'Handover & As-Built','sort_order':30,'allows_children':True}]},
    {'id':'f3f3f3f3-f3f3-43f3-83f3-f3f3f3f3f3f3','company_id':None,'name_ar':'بداية مشروع مبسطة','name_en':'Lean Project Starter','description_ar':'هيكل خفيف للبدء السريع','description_en':'Lean project starter','is_default':False,'is_active':True,'template_kind':'lean','is_builtin':True,'naming_rules':{},'requirements':[],'nodes':[{'id':'ln1','parent_id':None,'code':'01','name_ar':'عام','name_en':'General','sort_order':10,'allows_children':True},{'id':'ln2','parent_id':None,'code':'02','name_ar':'الرسومات','name_en':'Drawings','sort_order':20,'allows_children':True},{'id':'ln3','parent_id':None,'code':'03','name_ar':'التسليم','name_en':'Handover','sort_order':30,'allows_children':True}]},
    {'id':CDE_CUSTOM_TEMPLATE,'company_id':COMPANY,'name_ar':'قالب الشركة','name_en':'Company Delivery','description_ar':'قالب مخصص','description_en':'Custom template','is_default':False,'is_active':True,'template_kind':'custom','is_builtin':False,'naming_rules':{},'requirements':[],'nodes':[{'id':'cn1','parent_id':None,'code':'01','name_ar':'التسليم','name_en':'Handover','sort_order':10,'allows_children':True}]}
   ]
  elif name=='document_requirements_snapshot': payload=[{'id':CDE_REQUIREMENT,'requirement_key':'as_built','label_ar':'رسومات As-Built','label_en':'As-Built Drawings','document_type':'drawing','discipline':'as-built','min_items':1,'is_required':True,'sort_order':10,'linked_count':1,'ready_count':1},{'id':'f8f8f8f8-f8f8-48f8-88f8-f8f8f8f8f8f8','requirement_key':'test_certificate','label_ar':'شهادة اختبار','label_en':'Test Certificate','document_type':'certificate','discipline':None,'min_items':1,'is_required':True,'sort_order':20,'linked_count':0,'ready_count':0}]
  elif name in ('apply_folder_template','save_folder_template_v2','set_folder_hidden','update_document_metadata','link_document_requirement'):
   captured['cde_calls'].append((name,body)); payload={'ok':True,'created_folders':6,'template_id':body.get('p_template_id') or CDE_CUSTOM_TEMPLATE,'node_count':6}
  elif name=='begin_document_upload_v2':
   captured['cde_calls'].append((name,body))
   if 'project-control-brief' in (body.get('p_tags') or []):
    payload={'document_id':P11_REPORT_DOC,'version_id':'27111111-1111-4111-8111-111111111127','version_number':1,'storage_bucket':'company-files','storage_path':f'{COMPANY}/{projects[0]["id"]}/project/{P11_REPORT_DOC}/27111111-1111-4111-8111-111111111127/weekly-brief.html'}
   elif body.get('p_document_type')=='report':
    payload={'document_id':P10_REPORT_DOC,'version_id':'d5101010-1010-4510-8510-101010101010','version_number':1,'storage_bucket':'company-files','storage_path':f'{COMPANY}/{projects[0]["id"]}/site/{SITE}/{P10_REPORT_DOC}/d5101010-1010-4510-8510-101010101010/daily-report.html'}
   else:
    payload={'document_id':'c5c5c5c5-c5c5-45c5-85c5-c5c5c5c5c5c5','version_id':'d5d5d5d5-d5d5-45d5-85d5-d5d5d5d5d5d5','version_number':1,'storage_bucket':'company-files','storage_path':f'{COMPANY}/{projects[0]["id"]}/project/c5c5c5c5-c5c5-45c5-85c5-c5c5c5c5c5c5/d5d5d5d5-d5d5-45d5-85d5-d5d5d5d5d5d5/upload.pdf'}
  elif name=='begin_new_version_upload_v2':
   captured['cde_calls'].append((name,body))
   if body.get('p_document_id')==P11_REPORT_DOC:
    payload={'document_id':P11_REPORT_DOC,'version_id':'28111111-1111-4111-8111-111111111128','version_number':2,'storage_bucket':'company-files','storage_path':f'{COMPANY}/{projects[0]["id"]}/project/{P11_REPORT_DOC}/28111111-1111-4111-8111-111111111128/weekly-brief-v2.html'}
   elif body.get('p_document_id')==P10_REPORT_DOC:
    payload={'document_id':P10_REPORT_DOC,'version_id':'d6101010-1010-4610-8610-101010101010','version_number':2,'storage_bucket':'company-files','storage_path':f'{COMPANY}/{projects[0]["id"]}/site/{SITE}/{P10_REPORT_DOC}/d6101010-1010-4610-8610-101010101010/daily-report-v2.html'}
   else:
    payload={'document_id':body.get('p_document_id') or DOC,'version_id':'d6d6d6d6-d6d6-46d6-86d6-d6d6d6d6d6d6','version_number':3,'storage_bucket':'company-files','storage_path':f'{COMPANY}/{projects[0]["id"]}/project/{DOC}/d6d6d6d6-d6d6-46d6-86d6-d6d6d6d6d6d6/restore.pdf'}
  elif name in ('finalize_document_upload','abort_document_upload'):
   captured['cde_calls'].append((name,body)); payload=None
  elif name=='company_storage_metrics': payload={'used_bytes':7340032,'uploading_bytes':0,'document_count':4,'version_count':7,'max_storage_bytes':10737418240}
  elif name=='company_storage_intelligence': payload={'used_bytes':7340032,'trash_bytes':1048576,'old_version_bytes':2097152,'max_storage_bytes':10737418240,'by_project':[{'id':projects[0]['id'],'code':'ALPHA','name':'Alpha Project','bytes':7340032}],'by_type':[{'document_type':'drawing','documents':3,'bytes':6291456}],'largest_files':[{'id':DOC,'display_name':document_pdc['display_name'],'project_id':projects[0]['id'],'site_id':None,'folder_id':FOLDER,'size_bytes':2457600}]}
  elif name=='trash_query': payload={'folders':[{'id':'f9f9f9f9-f9f9-49f9-89f9-f9f9f9f9f9f9','name':'Old Correspondence','code':'09','project_id':projects[0]['id'],'site_id':None,'parent_id':None,'trashed_at':'2026-08-07T10:00:00Z','trashed_by':USER,'trash_batch_id':'ba1ba1ba-1111-4111-8111-ba1ba1ba1ba1','trash_origin':'direct','project_name':'Alpha Project','site_name':None,'trashed_by_name':'Owner User'}],'documents':[{'id':'c9c9c9c9-c9c9-49c9-89c9-c9c9c9c9c9c9','display_name':'Old Report.pdf','document_type':'report','project_id':projects[0]['id'],'site_id':None,'folder_id':FOLDER,'trashed_at':'2026-08-07T11:00:00Z','trashed_by':USER,'trash_origin':'direct','project_name':'Alpha Project','site_name':None,'trashed_by_name':'Owner User','size_bytes':524288}],'hidden_descendants':3}
  elif name in ('document_search_v2','document_picker_query'): payload=[document_pdc if name=='document_search_v2' else {'id':DOC,'display_name':document_pdc['display_name'],'document_type':'drawing','control_status':'in_review','folder_id':FOLDER,'site_id':None,'system_code':'ALPHA-ELE-001','version_count':2}]
  elif name=='project_360': payload={'project':projects[0],'blueprint':{'id':BLUEPRINT,'code':'standard-engineering','name_ar':'هندسي قياسي','name_en':'Standard Engineering'},'manager_name':'Owner User','stats':{'sites':1,'cabinets':1,'claim_packages':1,'folders':2,'documents':4,'storage_bytes':7340032,'open_tasks':8,'overdue_tasks':2,'blocked_tasks':1,'drawings':5,'milestones':3},'sites':[{**sites_pdc[0],'manager_name':'Engineer User','cabinets':1,'claim_status':'collecting'}],'health':{'score':82,'archived':False},'recent_activity':[],'can_manage':captured.get('actor')!='engineer'}
  elif name=='site_360':
   manager=captured.get('actor')!='engineer'; payload={'site':sites_pdc[0],'project':{'id':projects[0]['id'],'code':'ALPHA','name':'Alpha Project'},'manager_name':'Engineer User','stats':{'folders':8,'documents':2,'storage_bytes':3145728,'open_tasks':4,'overdue_tasks':1,'drawings':3,'cabinets':1},'cabinets':[{'id':CABINET,'code':'CAB-01','name':'Cabinet One','cabinet_type':'fiber_cabinet','status':'active','description':'Main cabinet','location_label':'Zone A','root_folder_id':CAB_ROOT,'archived_at':None,'claim_items':1}],'claim_package':{**claim_payload,'can_manage':manager},'can_create_cabinet':manager,'can_manage_cabinets':manager,'can_manage_claim':manager,'can_edit_site':manager,'can_archive_site':manager}
  elif name=='cabinet_360':
   manager=captured.get('actor')!='engineer'; payload={'cabinet':{'id':CABINET,'company_id':COMPANY,'project_id':projects[0]['id'],'site_id':SITE,'code':'CAB-01','name':'Cabinet One','cabinet_type':'fiber_cabinet','status':'active','description':'Main cabinet','location_label':'Zone A','root_folder_id':CAB_ROOT,'archived_at':None},'project':{'id':projects[0]['id'],'code':'ALPHA','name':'Alpha Project'},'site':{'id':SITE,'code':'SITE-01','name':'Alpha Main Site'},'root_folder':{'id':CAB_ROOT,'name':'CAB-01 — Cabinet One','code':'CAB-01'},'folders':[{'id':SITE_FOLDER,'code':'C01','name':'Drawings & As-Built','sort_order':10},{'id':'b5b5b5b5-b5b5-45b5-85b5-b5b5b5b5b5b5','code':'C02','name':'Quantity Survey','sort_order':20},{'id':'b6b6b6b6-b6b6-46b6-86b6-b6b6b6b6b6b6','code':'C03','name':'Sketches','sort_order':30},{'id':'b7b7b7b7-b7b7-47b7-87b7-b7b7b7b7b7b7','code':'C04','name':'Handover & Inspection','sort_order':40},{'id':'b8b8b8b8-b8b8-48b8-88b8-b8b8b8b8b8b8','code':'C05','name':'Photos','sort_order':50},{'id':'b9b9b9b9-b9b9-49b9-89b9-b9b9b9b9b9b9','code':'C06','name':'Supporting Documents','sort_order':60}],'stats':{'documents':1,'drawings':1,'open_tasks':2,'claim_items':1,'readiness_percent':75},'can_manage':manager,'can_archive':manager}
  elif name=='site_claim_package_360':
   if captured.get('point910'):
    reqs=point910_claim_requirements(); frozen=bool(captured.get('point910_frozen'))
    payload={**claim_payload,'package':{**claim_payload['package'],'title':'Site Claim Package','status':'collecting','locked_at':'2026-08-15T16:30:00Z' if frozen else None},'progress':{'required_percent':100,'cabinet_coverage_percent':100,'overall_percent':100,'required_total':8,'required_satisfied':8,'cabinet_total':1,'cabinet_covered':1,'invalid_items':0},'requirements':reqs,'can_manage':True}
   elif captured.get('point7_review'):
    review_reqs=[]
    for r in claim_requirements_fixture:
     rr={**r,'satisfied':True,'ready_count':max(1,r.get('min_items',1)),'item_count':max(1,r.get('min_items',1))}
     if r['requirement_key']=='as_built_drawings':
      rr['items']=[{**r['items'][0],'selected_version_id':'d0d0d0d0-d0d0-40d0-80d0-d0d0d0d0d0d0','status':'included'}]
     else:
      rr['items']=[{'id':'a6a6a6a6-a6a6-46a6-86a6-a6a6a6a6a6a6','document_id':SITE_DOC,'display_name':'CAB-01 Quantity Takeoff.xlsx','document_type':'boq','control_status':'approved','current_version_id':SITE_VERSION,'selected_version_id':SITE_VERSION,'cabinet_id':CABINET,'cabinet_code':'CAB-01','cabinet_name':'Cabinet One','inclusion_mode':'auto','status':'accepted','folder_id':SITE_FOLDER}]
     review_reqs.append(rr)
    payload={**claim_payload,'package':{**claim_payload['package'],'status':'submitted','locked_at':'2026-08-15T05:00:00Z','submitted_at':'2026-08-15T05:10:00Z'},'progress':{'required_percent':100,'cabinet_coverage_percent':100,'overall_percent':100,'required_total':2,'required_satisfied':2,'cabinet_total':1,'cabinet_covered':1,'invalid_items':0},'requirements':review_reqs,'can_manage':captured.get('actor')!='engineer'}
   else: payload={**claim_payload,'can_manage':captured.get('actor')!='engineer'}
  elif name=='site_claim_package_intelligence':
   if captured.get('point910'):
    payload={'stale_evidence':[],'rejected_evidence':[],'suggestions':[],'events':([{'id':'p910exp','event_type':'package_exported','actor_id':USER,'actor_name':'Owner User','note':'Prepared package','metadata':{},'created_at':'2026-08-15T16:35:00Z'}] if captured.get('point910_export') else []),'can_manage':True}
   else:
    payload={'stale_evidence':([{'item_id':'a4a4a4a4-a4a4-44a4-84a4-a4a4a4a4a4a4','document_id':SITE_DOC,'display_name':'CAB-01 As-Built Drawing','selected_version_id':'d0d0d0d0-d0d0-40d0-80d0-d0d0d0d0d0d0','current_version_id':SITE_VERSION,'cabinet_id':CABINET}] if captured.get('point7_review') else []),'rejected_evidence':[],'suggestions':[],'events':([{'id':'ev2','event_type':'submitted','actor_id':USER,'actor_name':'Owner User','note':'Ready for consultant review','metadata':{},'created_at':'2026-08-15T05:10:00Z'},{'id':'ev1','event_type':'versions_frozen','actor_id':USER,'actor_name':'Owner User','note':None,'metadata':{},'created_at':'2026-08-15T05:00:00Z'}] if captured.get('point7_review') else []),'can_manage':captured.get('actor')!='engineer'}
  elif name=='delivery_directory_query':
   if captured.get('point910'):
    payload={'items':[{'id':CLAIM,'company_id':COMPANY,'project_id':projects[0]['id'],'site_id':SITE,'package_no':'SITE-01-FINAL','title':'Site Claim Package','claim_type':'final','status':'collecting','project_code':'ALPHA','project_name':'Alpha Project','site_code':'SITE-01','site_name':'Alpha Main Site','required_total':8,'required_ready':8,'required_percent':100,'invalid_items':0,'stale_items':0,'readiness_percent':100,'updated_at':'2026-08-15T16:00:00Z'}],'total':1,'offset':0,'limit':100,'has_more':False,'counts':{'packages':1,'collecting':1,'ready':0,'submitted':0,'approved':0,'rejected':0,'stale':0,'cabinets':1}}
   else:
    payload={'items':[{'id':CLAIM,'company_id':COMPANY,'project_id':projects[0]['id'],'site_id':SITE,'package_no':'SITE-01-FINAL','title':'Final Site Claim / Delivery Package','claim_type':'final','status':'submitted' if captured.get('point7_review') else 'collecting','project_code':'ALPHA','project_name':'Alpha Project','site_code':'SITE-01','site_name':'Alpha Main Site','required_total':2,'required_ready':2 if captured.get('point7_review') else 1,'required_percent':100 if captured.get('point7_review') else 50,'invalid_items':0,'stale_items':1 if captured.get('point7_review') else 0,'readiness_percent':90 if captured.get('point7_review') else 48,'updated_at':'2026-08-15T05:10:00Z'}],'total':1,'offset':0,'limit':100,'has_more':False,'counts':{'packages':1,'collecting':0 if captured.get('point7_review') else 1,'ready':0,'submitted':1 if captured.get('point7_review') else 0,'approved':0,'rejected':0,'stale':1 if captured.get('point7_review') else 0,'cabinets':1}}
  elif name=='delivery_closeout_map':
   payload={'project':{'id':projects[0]['id'],'code':'ALPHA','name':'Alpha Project'},'sites':[{'id':SITE,'code':'SITE-01','name':'Alpha Main Site','status':'active','package_id':CLAIM,'package_status':'submitted' if captured.get('point7_review') else 'collecting','cabinets':[{'id':CABINET,'code':'CAB-01','name':'Cabinet One','status':'active','required_total':3,'required_ready':2}]}]}
  elif name=='cabinet_closeout_snapshot':
   payload={'cabinet':{'id':CABINET,'code':'CAB-01','name':'Cabinet One','status':'active','site_id':SITE,'project_id':projects[0]['id']},'package_id':CLAIM,'required_total':3,'required_ready':2,'readiness_percent':67,'requirements':[{'id':CDE_REQUIREMENT,'requirement_key':'as_built','label_ar':'رسومات كما نُفذ','label_en':'As-Built Drawings','is_required':True,'min_items':1,'ready_count':1},{'id':'r2','requirement_key':'test_certificate','label_ar':'شهادة الاختبار','label_en':'Test Certificate','is_required':True,'min_items':1,'ready_count':1},{'id':'r3','requirement_key':'handover','label_ar':'محضر التسليم','label_en':'Handover Record','is_required':True,'min_items':1,'ready_count':0}]}
  elif name=='document_360':
   if body.get('p_document_id')==SITE_DOC:
    manager=captured.get('actor')!='engineer'; payload={'document':site_document_pdc,'project':{'id':projects[0]['id'],'code':'ALPHA','name':'Alpha Project'},'site':{'id':SITE,'code':'SITE-01','name':'Alpha Main Site'},'folder':{'id':SITE_FOLDER,'name':'Drawings & As-Built','code':'C01'},'cabinet':{'id':CABINET,'code':'CAB-01','name':'Cabinet One','status':'active'},'owner_name':'Engineer User','versions':[site_version_pdc],'linked_tasks':[],'linked_drawings':[],'claim_links':[{'item_id':'a4a4a4a4-a4a4-44a4-84a4-a4a4a4a4a4a4','package_id':CLAIM,'package_no':'SITE-01-FINAL','package_status':'collecting','requirement_id':CLAIM_REQ,'requirement_key':'as_built_drawings','label_ar':'رسومات As-Built','label_en':'As-Built Drawings','selected_version_id':None,'cabinet_id':CABINET}],'claim_options':([{'package_id':CLAIM,'package_no':'SITE-01-FINAL','package_status':'collecting','requirement_id':'a5a5a5a5-a5a5-45a5-85a5-a5a5a5a5a5a5','requirement_key':'quantity_survey','label_ar':'الحصر والكميات','label_en':'Quantity Survey / Takeoff','sort_order':30}] if manager else []),'recent_activity':[]}
   else:
    p910doc={**document_pdc,'claim_inclusion_mode':'auto','claim_requirement_key':'work_order'} if captured.get('point910') else document_pdc
    payload={'document':p910doc,'project':{'id':projects[0]['id'],'code':'ALPHA','name':'Alpha Project'},'site':None,'folder':{'id':FOLDER,'name':'01 — Drawings','code':'01'},'cabinet':None,'owner_name':'Engineer User','versions':[version_pdc,{**version_pdc,'id':'d2d2d2d2-d2d2-42d2-82d2-d2d2d2d2d2d2','version_number':1,'version_label':'v1','revision_code':'R1','storage_path':f'{COMPANY}/{projects[0]["id"]}/project/{DOC}/d2d2d2d2-d2d2-42d2-82d2-d2d2d2d2d2d2/A-102-R1.pdf','original_filename':'A-102-R1.pdf','size_bytes':2200000,'created_at':'2026-08-05T08:00:00Z','finalized_at':'2026-08-05T08:01:00Z'}],'linked_tasks':[{'id':TASK,'task_number':42,'title':'Review shop drawing','status':'in_progress','priority':'high','due_at':'2026-08-09T12:00:00Z'}],'linked_drawings':[],'claim_links':[],'requirement_links':[{'requirement_id':CDE_REQUIREMENT,'requirement_key':'as_built','label_ar':'رسومات As-Built','label_en':'As-Built Drawings','is_required':True}],'claim_options':[],'recent_activity':[],'context_read_only':False,'can_manage':captured.get('actor')!='engineer','can_download':True,'can_upload':captured.get('actor')!='engineer','can_rename':True,'can_move':True,'can_archive':captured.get('actor')!='engineer'}
  elif name=='resolve_entity_context':
   typ=body.get('p_entity_type'); eid=body.get('p_entity_id')
   if typ in ('project','projects'): payload={'type':'project','project_id':eid,'page':'projects'}
   elif typ in ('site','sites'): payload={'type':'site','project_id':projects[0]['id'],'site_id':eid,'page':'projects'}
   elif typ in ('folder','folders'): payload={'type':'folder','project_id':projects[0]['id'],'site_id':None,'folder_id':eid,'page':'files'}
   elif typ in ('document','documents'): payload={'type':'document','project_id':projects[0]['id'],'site_id':SITE if eid==SITE_DOC else None,'folder_id':SITE_FOLDER if eid==SITE_DOC else FOLDER,'document_id':eid,'page':'files'}
   elif typ in ('site_cabinet','cabinet','site_cabinets'): payload={'type':'site_cabinet','project_id':projects[0]['id'],'site_id':SITE,'cabinet_id':eid,'folder_id':CAB_ROOT,'page':'projects'}
   elif typ in ('site_claim_package','claim_package','site_claim_packages'): payload={'type':'site_claim_package','project_id':projects[0]['id'],'site_id':SITE,'claim_package_id':eid,'page':'projects'}
   elif typ in ('task','tasks'): payload={'type':'task','project_id':projects[0]['id'],'task_id':eid,'page':'tasks'}
   else: payload={'type':typ,'project_id':projects[0]['id'],'page':'engineering','drawing_id':eid}
  elif name=='set_document_claim_classification':
   captured['point910_calls'].append((name,body)); payload={'document_id':body.get('p_document_id'),'mode':body.get('p_mode'),'requirement_key':body.get('p_requirement_key'),'linked':1}
  elif name=='refresh_site_claim_package_v2':
   captured['point910_calls'].append((name,body)); payload={'base':{'requirements_added':0},'classified_documents_scanned':3}
  elif name=='site_claim_package_export_manifest':
   captured['point910_calls'].append((name,body)); payload=point910_manifest()
  elif name=='record_site_claim_export':
   captured['point910_calls'].append((name,body)); captured['point910_export']={'id':'94000000-0000-4000-8000-000000000001','file_count':body.get('p_file_count',0),'manifest_hash':body.get('p_manifest_hash'),'exported_by':USER,'exported_by_name':'Owner User','created_at':'2026-08-15T16:35:00Z'}; payload=captured['point910_export']
  elif name=='freeze_site_claim_package' and captured.get('point910'):
   captured['point910_calls'].append((name,body)); captured['point910_frozen']=True; payload={'id':CLAIM,'locked_at':'2026-08-15T16:30:00Z'}
  elif name=='refresh_site_delivery_package': captured['pdc_calls'].append((name,body)); payload={'requirements_added':1,'linked_evidence_added':2,'auto_collect':{'added':1}}
  elif name in ('review_site_claim_item','approve_site_claim_package','reject_site_claim_package'):
   captured['pdc_calls'].append((name,body)); payload={'ok':True,'id':body.get('p_item_id') or body.get('p_package_id')}
  elif name in ('save_project','save_site','set_document_control_status','archive_project','reactivate_project','archive_site','reactivate_site','rename_document','move_document','rename_folder','move_folder','restore_document','restore_folder','trash_document','trash_folder','save_site_cabinet','archive_site_cabinet','reactivate_site_cabinet','add_document_to_site_claim','remove_site_claim_item','freeze_site_claim_package','reopen_site_claim_package','submit_site_claim_package','save_site_claim_requirement','refresh_site_delivery_package','review_site_claim_item','approve_site_claim_package','reject_site_claim_package'):
   captured['pdc_calls'].append((name,body)); payload={'id':CABINET if name=='save_site_cabinet' else (body.get('p_document_id') or body.get('p_project_id') or body.get('p_site_id') or projects[0]['id']),'ok':True}
  elif name=='auto_collect_site_claim': captured['pdc_calls'].append((name,body)); payload={'added':3,'suggested':3}
  elif name=='site_claim_suggestions': payload=[]
  elif name=='project_archive_impact': payload={'project_id':projects[0]['id'],'name':'Alpha Project','active_sites':1,'open_tasks':8,'blocked_tasks':1,'active_drawings':5,'documents':4,'storage_bytes':7340032,'milestones':3}
  elif name=='site_archive_impact': payload={'site_id':SITE,'name':'Alpha Main Site','open_tasks':4,'active_drawings':3,'documents':2,'storage_bytes':3145728}
  elif name=='cleanup_stale_uploads': payload=0
  elif name=='company_activity_feed': payload=activities
  elif name=='platform_company_directory':
   base_company={**company,'company_id':COMPANY,'company_name':company['name'],'company_slug':company['slug'],'status':'active','plan_id':'plan1','plan_code':'starter','plan_name_ar':'البداية','plan_name_en':'Starter','member_count':2,'project_count':len(projects),'storage_bytes':0,'max_members':25,'max_projects':10,'max_storage_bytes':10737418240,'created_at':company['created_at'],'billing_cycle':'monthly','agreed_price':1000,'currency':'EGP','payment_status':'paid','onboarding_status':'ready','owner_user_id':USER,'owner_name':'Owner User','owner_email':'owner@example.com','owner_phone':'01000000000','owner_must_change_password':False,'branding_logo_path':None,'branding_app_name':'Optimum Test','salary_amount':None}
   if captured.get('platform_premium'):
    payload=[base_company,{**base_company,'company_id':'abababab-abab-4bab-8bab-abababababab','company_name':'Atlas Contracting','branding_app_name':'Atlas','company_slug':'atlas-contracting','status':'trial','owner_name':'Atlas Owner','owner_email':'atlas@example.com','owner_must_change_password':True,'current_period_ends_at':'2026-08-20T12:00:00Z','member_count':1,'project_count':0},{**base_company,'company_id':'cdcdcdcd-cdcd-4dcd-8dcd-cdcdcdcdcdcd','company_name':'Delta Engineering','branding_app_name':'Delta','company_slug':'delta-engineering','status':'active','payment_status':'overdue','owner_name':'Delta Owner','owner_email':'delta@example.com','member_count':23,'project_count':9,'storage_bytes':9663676416}]
   else: payload=[base_company]
  elif name=='platform_company_overview': payload=[]
  elif name=='save_role_draft':
   captured['client_role']=body
   payload={'draft':{'id':'12121212-1212-4212-8212-121212121212','company_id':COMPANY,'role_id':body.get('p_payload',{}).get('role_id'),'snapshot':body.get('p_payload',{}),'change_note':body.get('p_payload',{}).get('change_note'),'status':'draft'},'validation':{'blocked_by_plan':[]}}
  elif name=='role_draft_impact':
   payload={'draft_id':body.get('p_draft_id'),'affected_members':0,'gained_permissions':captured.get('client_role',{}).get('p_payload',{}).get('permission_keys',[]),'lost_permissions':[],'blocked_by_plan':[],'requires_approval':False}
  elif name=='platform_save_role_template_definition':
   captured['platform_template']=body
   payload={'ok':True,'template_id':TPL,'permission_count':len(body.get('p_payload',{}).get('permission_keys',[])),'permission_keys':body.get('p_payload',{}).get('permission_keys',[])}
  elif name=='save_company_workspace_settings':
   captured['settings'].append(body)
   payload={'company':{**company,**body.get('p_company',{})},'branding':{**branding,**body.get('p_branding',{})}}
  elif name=='save_workspace_settings_draft':
   captured['settings'].append(body)
   payload={'draft':{'id':'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'},'changed_company_fields':list(body.get('p_company',{}).keys()),'changed_branding_fields':list(body.get('p_branding',{}).keys())}
  elif name=='publish_workspace_settings_draft': payload={'ok':True,'version':1}
  elif name in ('save_member_hr_profile','save_member_control_profile'): payload={'ok':True}
  elif name in ('company_storage_metrics','work_dashboard_metrics'): payload={'used_bytes':0,'storage_bytes':0,'document_count':0,'version_count':0}
  else: payload=[] if name.endswith('_feed') else {'ok':True}
  await route.fulfill(status=200,content_type='application/json',body=json.dumps(payload)); return
 if '/rest/v1/' in path:
  table=path.split('/rest/v1/',1)[1].split('?',1)[0]
  rows=table_payload(table)
  qs=parse_qs(url.query)
  # Honor the identity-scoped filters used during bootstrap so limited-role tests
  # do not accidentally inherit another user's profile/membership/admin row.
  if table=='profiles' and qs.get('id'):
   raw=qs['id'][0]
   if raw.startswith('eq.'):
    wanted=raw[3:]
    rows=[x for x in rows if str(x.get('id'))==wanted]
   elif raw.startswith('in.(') and raw.endswith(')'):
    wanted={x.strip() for x in raw[4:-1].split(',') if x.strip()}
    rows=[x for x in rows if str(x.get('id')) in wanted]
  elif table in ('account_security','company_memberships','platform_admins') and qs.get('user_id'):
   wanted=qs['user_id'][0].removeprefix('eq.')
   rows=[x for x in rows if str(x.get('user_id'))==wanted]
  await route.fulfill(status=200,content_type='application/json',body=json.dumps(rows)); return
 if '/auth/v1/user' in path:
  await route.fulfill(status=200,content_type='application/json',body=json.dumps(session()['user'])); return
 if '/auth/v1/logout' in path:
  await route.fulfill(status=204,body=''); return
 if '/auth/v1/' in path:
  await route.fulfill(status=200,content_type='application/json',body=json.dumps(session())); return
 await route.fulfill(status=404,body='not mocked')

async def initialize(page, scope, actor='owner'):
 captured['actor']=actor
 initial={f'optimum.session.v2.{scope}':json.dumps(session()),'optimum.company.v1':COMPANY}
 script=f"""(() => {{
   const values = {json.dumps(initial)};
   const storage = {{
     get length() {{ return Object.keys(values).length; }},
     key(index) {{ return Object.keys(values)[index] ?? null; }},
     getItem(key) {{ return Object.prototype.hasOwnProperty.call(values,key) ? String(values[key]) : null; }},
     setItem(key,value) {{ values[key]=String(value); }},
     removeItem(key) {{ delete values[key]; }},
     clear() {{ for (const key of Object.keys(values)) delete values[key]; }}
   }};
   Object.defineProperty(window,'localStorage',{{configurable:true,value:storage}});
 }})();"""
 await page.evaluate(script)
 await page.route('https://wzcaquxuvqfbstpxujsj.supabase.co/**',mock_route)


async def wait_until(predicate, timeout=5.0, label='condition'):
 end=time.monotonic()+timeout
 while time.monotonic()<end:
  if predicate(): return
  await asyncio.sleep(0.05)
 raise AssertionError(f'Timed out waiting for {label}')

async def client_flow(browser):
 page=await browser.new_page(viewport={'width':1500,'height':1000})
 await initialize(page,'client')
 await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/roles"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('[data-action="new-role"]').click()
 form=page.locator('form[data-form="access55-role-draft"]')
 await form.locator('[name="name_ar"]').fill('اختبار تشغيل')
 await form.locator('[name="name_en"]').fill('Operational Test')
 await form.locator('[name="slug"]').fill('operational-test')
 await form.locator('[name="change_note"]').fill('Browser regression check')
 checks=form.locator('input[name="permission"]')
 for i in range(3): await checks.nth(i).evaluate("el=>{el.checked=true;el.dispatchEvent(new Event('change',{bubbles:true}));}")
 await form.locator('button[type="submit"]').click()
 await page.locator('.impact-summary-grid').wait_for(state='visible',timeout=5000)
 assert captured['client_role'], 'client role draft RPC was not called'
 assert len(captured['client_role']['p_payload']['permission_keys'])==3
 assert await page.locator('.impact-summary-grid').count()==1
 await page.locator('[data-action="close-overlay"]').first.click()

 # Phase 5.7.0: role members stay in Role Studio and open an in-context dialog.
 before_hash=await page.evaluate('location.hash')
 owner_button=page.locator(f'[data-action="show-role-members"][data-id="{OWNER_ROLE}"]')
 await owner_button.click()
 assert await page.locator('.role-members-dialog').count()==1
 assert await page.evaluate('location.hash')==before_hash
 assert await page.locator('.role-member-row').count()==1
 assert await page.locator('[data-action="invite-member-for-role"]').count()==0, 'Owner must not be assignable from member provisioning'
 await page.locator('[data-action="close-overlay"]').first.click()
 # A normal assignable role opens the same dialog and can seed the create-member form.
 role_button=page.locator(f'[data-action="show-role-members"][data-id="{ENGINEER_ROLE}"]')
 await role_button.click()
 assert await page.locator('.role-members-dialog').count()==1
 assert await page.locator('.role-member-row').count()==1
 assert 'Engineer User' in await page.locator('.role-member-row').first.inner_text()
 await page.locator('[data-action="invite-member-for-role"]').click()
 member_from_role=page.locator('form[data-form="provision-member"]')
 checked=await member_from_role.locator('input[name="role_id"]:checked').get_attribute('value')
 assert checked==ENGINEER_ROLE
 await page.locator('[data-action="close-overlay"]').first.click()
 # Team navigation remains available as an explicit secondary action and keeps the role filter.
 await role_button.click()
 await page.locator('[data-action="open-role-members-team"]').click()
 assert await page.evaluate('location.hash')=='#/team'
 assert await page.locator('#team-role-filter').input_value()==ENGINEER_ROLE

 await page.locator('[data-action="invite-member"]').first.click()
 member_form=page.locator('form[data-form="provision-member"]')
 assert await member_form.locator('.member-role-option').count()>=2
 # The employee summary is now after the form sections, not a sticky side panel.
 order=await member_form.evaluate("f => [...f.children].map(x=>x.className)")
 assert order[-1].find('provision-side')>=0
 await member_form.locator('[name="full_name"]').fill('New Member')
 await member_form.locator('[name="email"]').fill('new.member@example.com')
 await member_form.locator('input[name="role_id"]').nth(0).evaluate("el=>{el.checked=true;el.dispatchEvent(new Event('change',{bubbles:true}));}")
 await member_form.locator('button[type="submit"]').click()
 await page.locator('.credentials-dialog').wait_for(state='visible',timeout=7000)
 await wait_until(lambda: bool(captured['client_member']),label='member provisioning capture')
 assert captured['client_member']['action']=='create_member'
 assert captured['client_member']['role_id']
 assert await page.locator('.credentials-dialog').count()==1
 await page.locator('[data-action="close-overlay"]').first.click()

 await page.locator('[data-nav="settings"]').click()
 await page.locator('[data-action="settings-tab"][data-tab="company"]').first.click()
 company_form=page.locator('form[data-form="company-settings"]')
 await company_form.locator('[name="name"]').fill('Optimum Updated')
 before_settings=len(captured['settings'])
 await company_form.locator('button[type="submit"]').click()
 await wait_until(lambda: len(captured['settings'])>before_settings,label='workspace settings save')
 assert captured['settings'][-1]['p_company']['name']=='Optimum Updated'

 await page.locator('[data-nav="activity"]').click()
 await page.locator('[data-workos-activity-search]').wait_for(state='attached',timeout=5000)
 assert await page.locator('[data-workos-activity-search]').count()==1
 assert await page.locator('.workos-activity-filters').count()==1
 assert await page.locator('.workos-activity-list').count()==1
 await page.screenshot(path='/mnt/data/optimum53-client-proof.png',full_page=True)
 await page.close()

async def platform_flow(browser):
 page=await browser.new_page(viewport={'width':1500,'height':1000})
 await initialize(page,'platform')
 await page.route('https://platform.test/**',local_route)
 html=(ROOT/'platform-console/index.html').read_text().replace('<head>','<head><base href="https://platform.test/"><script>location.hash="#/role-templates"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('[data-action="new-role-template"]').click()
 form=page.locator('form[data-form="role-template"]')
 await form.locator('[name="code"]').fill('ops-test')
 await form.locator('[name="name_ar"]').fill('قالب تشغيل')
 await form.locator('[name="name_en"]').fill('Operational template')
 checks=form.locator('input[name="permission"]')
 await checks.nth(0).evaluate("el=>{el.checked=true;el.dispatchEvent(new Event('change',{bubbles:true}));}"); await checks.nth(1).evaluate("el=>{el.checked=true;el.dispatchEvent(new Event('change',{bubbles:true}));}")
 await form.locator('button[type="submit"]').click(); await wait_until(lambda: bool(captured['platform_template']),label='platform role template save')
 assert captured['platform_template'] and len(captured['platform_template']['p_payload']['permission_keys'])==2

 await page.locator('[data-nav="companies"]').click()
 await page.locator('[data-action="create-company"]').click()
 create=page.locator('form[data-form="create-company"]')
 # Fill every required control using its semantic type, then dispatch the real submit handler.
 await create.evaluate("""f => {
   for (const el of f.querySelectorAll('input[required]')) {
     if (el.type === 'email') el.value = el.name === 'owner_email' ? 'owner2@example.com' : 'office2@example.com';
     else if (el.type === 'checkbox') el.checked = true;
     else el.value = el.name === 'slug' ? 'company-two' : el.name === 'company_name' ? 'Company Two' : el.name === 'owner_name' ? 'Owner Two' : 'Test';
     el.dispatchEvent(new Event('input',{bubbles:true}));
   }
   for (const el of f.querySelectorAll('select[required]')) if (!el.value && el.options.length) el.value = el.options[0].value;
   f.querySelector('[name="company_name"]').value='Company Two';
   f.querySelector('[name="slug"]').value='company-two';
   f.querySelector('[name="owner_name"]').value='Owner Two';
   f.querySelector('[name="owner_email"]').value='owner2@example.com';
   f.dispatchEvent(new Event('submit',{bubbles:true,cancelable:true}));
 }""")
 await wait_until(lambda: bool(captured['platform_company']),timeout=7,label='platform company provisioning')
 assert captured['platform_company'] and captured['platform_company']['action']=='create_company'
 assert captured['platform_company']['company']['slug']=='company-two'
 await page.screenshot(path='/mnt/data/optimum53-platform-proof.png',full_page=True)
 await page.close()

async def platform_mobile_flow(browser):
 page=await browser.new_page(viewport={'width':390,'height':844})
 await initialize(page,'platform')
 await page.route('https://platform.test/**',local_route)
 html=(ROOT/'platform-console/index.html').read_text().replace('<head>','<head><base href="https://platform.test/"><script>location.hash="#/companies"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.platform-main').wait_for(state='visible',timeout=7000)
 await page.wait_for_timeout(180)
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 assert await page.locator('.platform-mobile-menu').is_visible()
 await page.locator('.platform-mobile-menu').click()
 await page.locator('.platform-shell.mobile-open .platform-sidebar').wait_for(state='visible',timeout=3000)
 box=await page.locator('.platform-sidebar').bounding_box()
 assert box and box['width']<=337 and box['x']>=-2 and box['x']+box['width']<=392
 await page.locator('[data-nav="companies"]').click()
 await page.wait_for_timeout(180)
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 # Premium tenant flow: open Company Control 360 first, then edit company/subscription.
 await page.locator('[data-action="company-details"]').first.click()
 await page.locator('.platform-company-control-actions [data-action="edit-company"]').wait_for(state='visible',timeout=5000)
 await page.locator('.platform-company-control-actions [data-action="edit-company"]').click()
 form=page.locator('form[data-form="edit-company"]')
 await form.wait_for(state='visible',timeout=3000)
 for name in ['country_code','address','timezone','default_locale','primary_contact_name','billing_contact_name','technical_contact_name']:
  assert await form.locator(f'[name="{name}"]').count()==1
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 dialog=page.locator('.dialog').last
 box=await dialog.bounding_box()
 assert box and box['width']<=392 and box['x']>=-2 and box['x']+box['width']<=392
 await page.screenshot(path='/mnt/data/optimum69-platform-mobile-proof.png',full_page=True)
 await page.close()

async def premium69_platform_final_flow(browser):
 captured['platform_premium']=True
 # Desktop: operations cockpit -> tenant control -> role library -> readable audit.
 page=await browser.new_page(viewport={'width':1500,'height':1000})
 await initialize(page,'platform')
 await page.route('https://platform.test/**',local_route)
 html=(ROOT/'platform-console/index.html').read_text().replace('<head>','<head><base href="https://platform.test/"><script>location.hash="#/dashboard"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.platform-ops-cockpit').wait_for(state='visible',timeout=7000)
 assert await page.locator('.platform-hero').count()==0, 'legacy platform hero must be removed'
 assert await page.locator('.platform-stats').count()==0, 'generic platform KPI grid must be removed'
 assert await page.locator('.platform-decision-signal').count()>=2, 'real operational signals must be visible'
 assert await page.locator('.platform-tenant-pulse').count()==1
 assert await page.locator('.platform-attention-queue').count()==1
 assert await page.locator('.platform-footprint').count()==1
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.screenshot(path='/mnt/data/optimum691-feature9-platform-desktop-proof.png',full_page=True)

 await page.locator('.platform-sidebar [data-nav="companies"]').click()
 await page.locator('.platform-tenant-directory').wait_for(state='visible',timeout=4000)
 assert await page.locator('.platform-inline-attention').count()==1
 # Table exposes one clear management entry per tenant; deep controls live in Company Control 360.
 rows=page.locator('.platform-company-row')
 assert await rows.count()>=3
 first=rows.first
 assert await first.locator('[data-action="edit-company"]').count()==0
 assert await first.locator('[data-action="company-entitlements"]').count()==0
 await first.locator('[data-action="company-details"]').last.click()
 await page.locator('.platform-company-control-actions').wait_for(state='visible',timeout=5000)
 for action in ['company-entitlements','company-branding','edit-company']:
  assert await page.locator(f'.platform-company-control-actions [data-action="{action}"]').count()==1
 # Deep control surfaces must be real, not decorative links.
 await page.locator('.platform-company-control-actions [data-action="company-entitlements"]').click()
 await page.locator('.platform-entitlement-row').first.wait_for(state='visible',timeout=4000)
 await page.locator('button[data-dismiss]').click()
 await first.locator('[data-action="company-details"]').last.click()
 await page.locator('.platform-company-control-actions [data-action="company-branding"]').wait_for(state='visible',timeout=5000)
 await page.locator('.platform-company-control-actions [data-action="company-branding"]').click()
 assert await page.locator('form[data-form="platform-branding"]').count()==1
 await page.locator('button[data-dismiss]').click()

 await page.locator('.platform-sidebar [data-nav="role-templates"]').click()
 await page.locator('.platform-role-template-grid').wait_for(state='visible',timeout=4000)
 assert await page.locator('.role-library-summary').count()==0, 'role vanity KPI summary must be removed'
 assert await page.locator('.platform-library-note,.platform-inline-attention').count()>=1

 await page.locator('.platform-sidebar [data-nav="audit"]').click()
 await page.locator('.platform-audit-center').wait_for(state='visible',timeout=4000)
 assert await page.locator('.activity-kpi-grid').count()==0, 'audit vanity KPI cards must be removed'
 assert await page.locator('[data-audit-search]').count()==1
 assert await page.locator('.activity-timeline').count()==1
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.close()

 # Mobile: cockpit and company control must fit without horizontal scroll.
 mobile=await browser.new_page(viewport={'width':390,'height':844})
 await initialize(mobile,'platform')
 await mobile.route('https://platform.test/**',local_route)
 html=(ROOT/'platform-console/index.html').read_text().replace('<head>','<head><base href="https://platform.test/"><script>location.hash="#/dashboard"</script>',1)
 await mobile.set_content(html,wait_until='domcontentloaded')
 await mobile.locator('.platform-ops-cockpit').wait_for(state='visible',timeout=7000)
 await mobile.wait_for_timeout(220)
 assert await mobile.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 for selector in ['.platform-ops-intro','.platform-decision-bar','.platform-tenant-pulse','.platform-footprint']:
  box=await mobile.locator(selector).bounding_box(); assert box and box['x']>=-2 and box['x']+box['width']<=392, selector
 await mobile.screenshot(path='/mnt/data/optimum691-feature9-platform-mobile-proof.png',full_page=True)
 await mobile.locator('.platform-mobile-menu').click()
 await mobile.locator('.platform-sidebar [data-nav="companies"]').click()
 await mobile.locator('.platform-tenant-directory').wait_for(state='visible',timeout=4000)
 await mobile.locator('.platform-company-row [data-action="company-details"]').first.click()
 await mobile.locator('.platform-company-control-actions').wait_for(state='visible',timeout=5000)
 assert await mobile.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 controls=await mobile.locator('.platform-company-control-actions').bounding_box(); assert controls and controls['x']>=-2 and controls['x']+controls['width']<=392
 await mobile.close()
 captured['platform_premium']=False

async def organization_os_flow(browser):
 captured['disabled_entitlements']=set()
 page=await browser.new_page(viewport={'width':1500,'height':1000})
 await initialize(page,'client')
 await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/organization"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.orgos-chart').wait_for(state='visible',timeout=7000)
 assert await page.locator('.orgos-unit-card').count()==1
 assert await page.locator('.org-attention-queue').count()>=1
 await page.locator('[data-action="orgos-tab"][data-tab="health"]').click()
 assert await page.locator('.orgos-health-issue').count()==1
 await page.locator('[data-action="orgos-tab"][data-tab="work"]').click()
 assert await page.locator('form[data-form="orgos-work-settings"]').count()==1
 work=page.locator('form[data-form="orgos-work-settings"]')
 await work.locator('[name="default_weekly_hours"]').fill('42')
 before_work=len(captured['work_settings']); await work.locator('button[type="submit"]').click(); await wait_until(lambda: len(captured['work_settings'])>before_work,label='work settings save')
 assert captured['work_settings'] and captured['work_settings'][-1]['p_payload']['default_weekly_hours']==42

 await page.locator('[data-nav="team"]').click(); await page.locator('[data-orgos-saved-view="team"]').wait_for(state='attached',timeout=5000)
 assert await page.locator('[data-orgos-saved-view="team"]').count()==1
 assert await page.locator(f'[data-team-member] [data-orgos-member-select][value="{MEMBERSHIP2}"]').count()==1
 await page.locator(f'[data-action="orgos-member360"][data-id="{MEMBERSHIP2}"]').evaluate("el=>el.click()")
 await page.locator('.member360-v2').wait_for(state='visible',timeout=5000)
 text=await page.locator('.member360-v2').inner_text()
 assert 'Engineer User' in text
 assert await page.locator('.member360-tabs button').count()==4
 await page.locator('[data-action="orgos-member-tab"][data-tab="access"]').click()
 assert await page.locator('[data-member360-panel="access"].active').count()==1
 await page.locator('[data-action="close-overlay"]').first.click()

 cb=page.locator(f'[data-orgos-member-select][value="{MEMBERSHIP2}"]')
 await cb.check(); await page.locator('.orgos-bulk-bar.active').wait_for(state='visible',timeout=3000)
 assert await page.locator('.orgos-bulk-bar.active').count()==1
 await page.locator('[data-action="orgos-bulk-suspend"]').click(); await wait_until(lambda: bool(captured['bulk_calls']) and captured['bulk_calls'][-1][0]=='bulk_set_member_status',label='bulk suspend')
 assert captured['bulk_calls'][-1][0]=='bulk_set_member_status'
 await page.locator('.orgos-undo-bar').wait_for(state='visible',timeout=5000)
 assert await page.locator('.orgos-undo-bar').count()==1
 await page.locator('[data-action="orgos-undo-bulk"]').click(); await wait_until(lambda: bool(captured['bulk_calls']) and captured['bulk_calls'][-1][0]=='bulk_restore_member_access',label='bulk undo')
 assert captured['bulk_calls'][-1][0]=='bulk_restore_member_access'

 assert await page.locator('.quick-create-trigger').count()==1
 await page.locator('.quick-create-trigger').click(); await page.locator('.quick-create-panel').wait_for(state='visible',timeout=3000)
 assert await page.locator('.quick-create-panel [data-action="invite-member"]').count()==1
 assert await page.locator('.quick-create-panel [data-action="access55-new-role"]').count()==1
 assert await page.locator('.quick-create-panel [data-action="access55-new-unit"]').count()==1
 assert await page.locator('.quick-create-panel [data-action="new-project"]').count()==1
 await page.locator('[data-action="close-overlay"]').first.click()

 await page.locator('[data-action="orgos-save-view"][data-view="team"]').click()
 sv=page.locator('form[data-form="orgos-save-view"]')
 await sv.locator('[name="name"]').fill('My team')
 await sv.locator('button[type="submit"]').click(); await wait_until(lambda: bool(captured['saved_views']),label='saved view save')
 assert captured['saved_views'] and captured['saved_views'][0]['name']=='My team'

 await page.locator('.command-trigger').click(); await page.locator('#command-search').fill('Engineer'); await page.locator('.orgos-command-members').wait_for(state='visible',timeout=5000)
 assert await page.locator(f'[data-action="orgos-member360"][data-id="{MEMBERSHIP2}"]').count()>=1
 await page.locator('[data-action="close-overlay"]').first.click()
 await page.locator('[data-nav="roles"]').click(); await page.locator('.orgos-insights').wait_for(state='attached',timeout=5000)
 assert await page.locator('.orgos-insights').count()==1
 assert await page.locator('[data-orgos-saved-view="roles"]').count()==1
 await page.screenshot(path='/mnt/data/optimum58-organization-os-proof.png',full_page=True)
 await page.close()

async def limited_permission_flow(browser):
 captured['disabled_entitlements']=set()
 page=await browser.new_page(viewport={'width':1500,'height':1000})
 await initialize(page,'client',actor='engineer')
 await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/team"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('[data-nav="team"]').wait_for(state='attached',timeout=5000)
 assert await page.locator('[data-nav="organization"]').count()==0, 'Organization OS must be hidden without company.manage'
 assert await page.locator('.quick-create-trigger').count()==0, 'Quick Create must be hidden when no create permission is effective'
 assert await page.locator('[data-action="invite-member"]').count()==0, 'Invite member must be hidden without members.invite'
 # The limited member can inspect their own access from the overflow menu, but not another member's access.
 own=page.locator(f'[data-team-member]:has([data-action="orgos-member360"][data-id="{MEMBERSHIP2}"])')
 other=page.locator(f'[data-team-member]:has([data-action="orgos-member360"][data-id="{MEMBERSHIP}"])')
 assert await own.locator('.team-person-menu-trigger').count()==1
 await own.locator('.team-person-menu-trigger').click(); await page.locator('.team-member-menu-pop').wait_for(state='visible',timeout=2000)
 assert await page.locator('.team-member-menu-pop [data-action="access55-view-user"]').count()==1
 assert await page.locator('.team-member-menu-pop [data-action="access55-member"]').count()==0
 await page.locator('.page-header h2').click(position={'x':5,'y':5}); await page.wait_for_timeout(80)
 await other.locator('.team-person-menu-trigger').click(); await page.locator('.team-member-menu-pop').wait_for(state='visible',timeout=2000)
 assert await page.locator('.team-member-menu-pop [data-action="access55-view-user"]').count()==0
 assert await page.locator('.team-member-menu-pop [data-action="access55-member"]').count()==0
 await page.locator('.page-header h2').click(position={'x':5,'y':5}); await page.wait_for_timeout(80)
 await own.locator('[data-action="orgos-member360"]').evaluate("el=>el.click()")
 await page.locator('.member360-v2').wait_for(state='visible',timeout=5000)
 assert await page.locator('.member360-v2 [data-action="access55-member"]').count()==0
 assert await page.locator('.member360-v2 [data-action="edit-member"]').count()==0
 await page.locator('[data-action="orgos-member-tab"][data-tab="access"]').click()
 assert await page.locator('.member360-v2 [data-action="access55-view-user"]').count()==1
 await page.locator('[data-action="close-overlay"]').first.click()
 await page.locator('[data-nav="roles"]').click()
 await page.locator('[data-nav="roles"]').wait_for(state='attached',timeout=3000)
 assert await page.locator('[data-action="new-role"]').count()==0
 assert await page.locator('[data-action="access55-new-role"]').count()==0
 await page.screenshot(path='/mnt/data/optimum58-limited-permission-proof.png',full_page=True)
 await page.close()

async def mobile_responsive_flow(browser):
 captured['disabled_entitlements']=set()
 page=await browser.new_page(viewport={'width':390,'height':844})
 await initialize(page,'client')
 await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/team"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.mobile-nav').wait_for(state='visible',timeout=5000)
 assert await page.locator('.sidebar.open').count()==0
 await page.locator('.mobile-nav').click(); await page.locator('.sidebar.open').wait_for(state='visible',timeout=2500)
 await page.locator('[data-nav="organization"]').click(); await page.locator('.orgos-chart').wait_for(state='visible',timeout=5000)
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 2')
 # Open a wide Member 360 drawer on a phone-sized viewport and ensure it stays inside the viewport.
 await page.locator('.mobile-nav').click(); await page.locator('.sidebar.open').wait_for(state='visible',timeout=2500)
 await page.locator('[data-nav="team"]').click(); await page.locator(f'[data-action="orgos-member360"][data-id="{MEMBERSHIP2}"]').evaluate("el=>el.click()")
 drawer=page.locator('.drawer').last
 await drawer.wait_for(state='visible',timeout=5000)
 await page.wait_for_timeout(240)  # drawer animation is 180ms; verify the settled geometry.
 box=await drawer.bounding_box(); assert box and box['width']<=392 and box['x']>=-2 and box['x']+box['width']<=392
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 2')
 await page.screenshot(path='/mnt/data/optimum58-mobile-proof.png',full_page=True)
 await page.close()

async def adaptive_policy_flow(browser):
 captured['disabled_entitlements']=set()
 page=await browser.new_page(viewport={'width':1500,'height':1000})
 await initialize(page,'client')
 await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/team"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('[data-nav="team"]').wait_for(state='attached',timeout=5000)
 assert await page.locator('[data-nav="team"]').count()==1
 assert await page.locator('.command-trigger').count()==1
 # Real DOM filtering: authored card display rules must not defeat the hidden attribute.
 await page.locator('#team-search').fill('not-a-real-member')
 await page.locator('#team-filter-empty').wait_for(state='visible',timeout=3000)
 assert await page.locator('.team-person-row:visible').count()==0
 assert await page.locator('#team-filter-empty:visible').count()==1
 await page.locator('#team-search').fill('')
 await page.locator('[data-nav="roles"]').click()
 await page.locator('#role-search').fill('claims')
 await page.wait_for_function("()=>document.querySelectorAll('.role-capability-card:not([hidden])').length===1",timeout=3000)
 assert await page.locator('.role-capability-card:visible').count()==1
 await page.locator('[data-nav="projects"]').click()
 await page.locator('#project-search').fill('alpha')
 await page.wait_for_function("()=>document.querySelectorAll('.project-card:not([hidden])').length===1",timeout=3000)
 assert await page.locator('.project-card:visible').count()==1
 # A Platform Console feature change must reshape an already-open workspace when focus returns.
 await page.locator('[data-nav="team"]').click()
 captured['disabled_entitlements']={'module.members','module.search'}
 await page.evaluate("window.dispatchEvent(new Event('focus'))")
 await page.wait_for_function("()=>!document.querySelector('[data-nav=\"team\"]') && location.hash==='#/dashboard'",timeout=6000)
 assert await page.locator('[data-nav="team"]').count()==0, 'disabled Team feature must disappear from navigation'
 assert await page.locator('.command-trigger').count()==0, 'disabled Search feature must remove the command UI'
 assert await page.evaluate('location.hash')=='#/dashboard', 'current route must fall back when its feature is disabled'
 captured['disabled_entitlements']=set()
 await page.close()


async def work_os_flow(browser):
 page=await browser.new_page(viewport={'width':1500,'height':1000})
 await initialize(page,'client','owner')
 await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/tasks"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.workos-cockpit').wait_for(state='visible',timeout=7000)
 assert await page.locator('.workos-signal-grid').count()==1
 await page.locator('.workos-workspace-tabs [data-action="workos-workspace-view"][data-view="tasks"]').first.click()
 await page.locator('.workos-kpis').wait_for(state='visible',timeout=5000)
 assert await page.locator('.workos-task-card').count()==1
 assert await page.locator('[data-action="workos-admin"]').count()==1
 # Deep task drawer + atomic optimistic edit.
 await page.locator('.workos-task-card [data-action="open-task"]').first.click()
 await page.locator('.workos-detail').wait_for(state='visible',timeout=5000)
 assert await page.locator('[data-action="workos-detail-tab"]').count()==5
 await page.locator('[data-action="workos-detail-tab"][data-tab="activity"]').click()
 assert await page.locator('.workos-detail .workos-timeline').count()==1
 await page.locator('[data-action="workos-detail-tab"][data-tab="overview"]').click()
 await page.locator('.workos-detail [data-action="edit-task"]').click()
 form=page.locator('form[data-form="workos-task"]')
 await form.wait_for(state='visible',timeout=3000)
 assert await form.get_attribute('data-lock-version')=='3'
 await form.locator('[name="title"]').fill('Review shop drawing safely')
 before=len(captured['work_calls'])
 await form.locator('button[type="submit"]').click()
 await wait_until(lambda: len(captured['work_calls'])>before,label='atomic work save')
 save=[x for x in captured['work_calls'][before:] if x[0]=='save_work_item'][-1][1]['p_payload']
 assert save['expected_lock_version']==3 and save['title']=='Review shop drawing safely'
 # Smart assignment explains and ranks candidates.
 await page.locator('[data-action="new-task"]').first.click()
 newform=page.locator('form[data-form="workos-task"]')
 await newform.locator('[name="title"]').fill('Inspect site cabinet')
 await newform.locator('[name="required_skills"]').fill('CAD')
 await newform.locator('[data-action="workos-smart-assign"]').click()
 await page.locator('.workos-candidates').wait_for(state='visible',timeout=4000)
 assert '95' in (await page.locator('.candidate-score').first.inner_text())
 await page.locator('[data-action="workos-use-candidate"]').first.click()
 await page.locator('form[data-form="workos-task"]').wait_for(state='visible',timeout=3000)
 await page.locator('[data-action="close-overlay"]').first.click()
 # Operational calendar views.
 await page.locator('[data-nav="calendar"]').click()
 await page.locator('.workos-calendar-shell').wait_for(state='visible',timeout=5000)
 for view in ['week','day','agenda','capacity','month']:
  btn=page.locator(f'[data-action="workos-calendar-view"][data-view="{view}"]')
  assert await btn.count()==1
  await btn.click()
  await page.wait_for_timeout(80)
 # Activity feed uses server-backed filter UI and task deep link.
 await page.locator('[data-nav="activity"]').click()
 await page.locator('.workos-activity-list').wait_for(state='visible',timeout=5000)
 assert await page.locator('[data-workos-activity-search]').count()==1
 await page.locator('.workos-activity-open').first.click()
 await page.locator('.workos-detail').wait_for(state='visible',timeout=4000)
 await page.locator('[data-action="close-overlay"]').first.click()
 await page.screenshot(path='/mnt/data/optimum66-work-os-proof.png',full_page=True)
 await page.close()

async def work_os_limited_flow(browser):
 page=await browser.new_page(viewport={'width':1360,'height':900})
 await initialize(page,'client','engineer')
 await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/tasks"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.workos-cockpit').wait_for(state='visible',timeout=7000)
 assert await page.locator('.workos-workspace-tabs [data-action="workos-workspace-view"][data-view="capacity"]').count()==0
 assert await page.locator('[data-action="workos-admin"]').count()==0
 await page.locator('.workos-workspace-tabs [data-action="workos-workspace-view"][data-view="tasks"]').first.click()
 await page.locator('.workos-kpis').wait_for(state='visible',timeout=5000)
 await page.locator('.workos-task-card [data-action="open-task"]').first.click()
 await page.locator('.workos-detail').wait_for(state='visible',timeout=4000)
 await page.locator('.workos-detail [data-action="edit-task"]').click()
 form=page.locator('form[data-form="workos-task"]')
 await form.wait_for(state='visible',timeout=3000)
 assert await form.locator('[name="owner_user_id"]').is_disabled()
 await page.locator('[data-action="close-overlay"]').first.click()
 await page.locator('[data-nav="calendar"]').click()
 await page.locator('.workos-calendar-shell').wait_for(state='visible',timeout=4000)
 assert await page.locator('[data-action="workos-calendar-view"][data-view="capacity"]').count()==0
 await page.close()

async def work_excellence_flow(browser):
 page=await browser.new_page(viewport={'width':1536,'height':1024})
 await initialize(page,'client','owner')
 await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/tasks"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded')
 # Work Cockpit is the default daily operating surface.
 await page.locator('.workos-cockpit').wait_for(state='visible',timeout=7000)
 assert await page.locator('.workos-signal').count()>=6
 assert await page.locator('.workos-focus-card').count()==1
 assert await page.locator('.workos-manager-pulse').count()==1
 # Risk Center is actionable, not a KPI-only page.
 await page.locator('.workos-workspace-tabs [data-action="workos-workspace-view"][data-view="risks"]').click()
 await page.locator('.workos-risk-center').wait_for(state='visible',timeout=4000)
 assert await page.locator('.workos-risk-card').count()>=1
 # Dependency graph is directly navigable to work items.
 await page.locator('.workos-workspace-tabs [data-action="workos-workspace-view"][data-view="dependencies"]').click()
 await page.locator('.workos-dependency-map').wait_for(state='visible',timeout=4000)
 assert await page.locator('.workos-graph-node').count()==2
 # Capacity planner combines people, work days and availability.
 await page.locator('.workos-workspace-tabs [data-action="workos-workspace-view"][data-view="capacity"]').click()
 await page.locator('.workos-capacity-matrix').wait_for(state='visible',timeout=4000)
 assert await page.locator('.workos-cap-member').count()==2
 assert await page.locator('.workos-cap-cell.leave').count()>=1
 # Work Item 360 has real tabs.
 await page.locator('.workos-workspace-tabs [data-action="workos-workspace-view"][data-view="tasks"]').click()
 await page.locator('.workos-task-card [data-action="open-task"]').first.click()
 await page.locator('.workos-detail').wait_for(state='visible',timeout=4000)
 assert await page.locator('[data-action="workos-detail-tab"]').count()>=5
 for tab in ['people','dependencies','files','activity','overview']:
  b=page.locator(f'[data-action="workos-detail-tab"][data-tab="{tab}"]')
  assert await b.count()==1
  await b.click()
 await page.locator('.workos-detail [data-action="edit-task"]').click()
 form=page.locator('form[data-form="workos-task"]'); await form.wait_for(state='visible',timeout=3000)
 await form.locator('[data-action="workos-smart-assign"]').click()
 await page.locator('.workos-candidates.smart-v2').wait_for(state='visible',timeout=4000)
 assert await page.locator('[data-action="workos-smart-strategy"]').count()==3
 await page.locator('[data-action="workos-smart-strategy"][data-strategy="capacity"]').click()
 assert '95' in (await page.locator('.candidate-score').first.inner_text())
 await page.locator('[data-action="close-overlay"]').first.click()
 # Work OS setup: workflow templates + visual automation builder.
 await page.locator('[data-action="workos-admin"]').click()
 await page.locator('[data-action="workos-admin-tab"][data-tab="workflows"]').click()
 await page.locator('.workos-workflow-gallery').wait_for(state='visible',timeout=3000)
 assert await page.locator('[data-action="workos-new-workflow-template"]').count()==1
 await page.locator('[data-action="workos-new-workflow-template"]').click()
 await page.locator('form[data-form="workos-workflow-template"]').wait_for(state='visible',timeout=3000)
 assert await page.locator('.workflow-step-card').count()==3
 before=await page.locator('.workflow-step-card').count(); await page.locator('[data-action="workos-add-workflow-step"]').click(); assert await page.locator('.workflow-step-card').count()==before+1
 await page.locator('[data-action="close-overlay"]').first.click()
 # reopen setup for automation because workflow dialog replaced the admin overlay.
 await page.locator('[data-action="workos-admin"]').click()
 await page.locator('[data-action="workos-admin-tab"][data-tab="automation"]').click()
 await page.locator('[data-action="workos-new-automation"]').click()
 await page.locator('form[data-form="workos-automation"]').wait_for(state='visible',timeout=3000)
 assert await page.locator('.automation-builder-block').count()==3
 assert await page.locator('form[data-form="workos-automation"] [name="actions_json"]').count()==0
 # Calendar events are draggable and rescheduling calls atomic save with lock version.
 await page.locator('[data-action="close-overlay"]').first.click()
 await page.locator('[data-nav="calendar"]').click(); await page.locator('.workos-calendar-shell').wait_for(state='visible',timeout=4000)
 draggable=page.locator('[data-workos-drag-task]').first; assert await draggable.count()==1
 target=page.locator('[data-workos-drop-date]').last
 before_calls=len(captured['work_calls'])
 js="() => { const src=document.querySelector('[data-workos-drag-task]'); const zones=[...document.querySelectorAll('[data-workos-drop-date]')]; const dst=zones[zones.length-1]; const dt=new DataTransfer(); src.dispatchEvent(new DragEvent('dragstart',{bubbles:true,dataTransfer:dt})); dst.dispatchEvent(new DragEvent('dragover',{bubbles:true,cancelable:true,dataTransfer:dt})); dst.dispatchEvent(new DragEvent('drop',{bubbles:true,cancelable:true,dataTransfer:dt})); setTimeout(()=>src.dispatchEvent(new DragEvent('dragend',{bubbles:true,dataTransfer:dt})),50); }"
 await page.evaluate(js)
 await wait_until(lambda: len(captured['work_calls'])>before_calls,timeout=5,label='calendar atomic reschedule')
 saves=[x for x in captured['work_calls'][before_calls:] if x[0]=='save_work_item']
 assert saves and saves[-1][1]['p_payload']['expected_lock_version']==3
 await page.screenshot(path='/mnt/data/optimum67-work-excellence-proof.png',full_page=True)
 await page.close()

async def work_mobile_excellence_flow(browser):
 page=await browser.new_page(viewport={'width':390,'height':844})
 await initialize(page,'client','owner')
 await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/tasks"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.workos-cockpit').wait_for(state='visible',timeout=7000)
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.locator('.workos-focus-card [data-action="open-task"]').first.click()
 drawer=page.locator('.drawer').last; await drawer.wait_for(state='visible',timeout=4000); await page.wait_for_timeout(240)
 box=await drawer.bounding_box(); assert box and box['width']<=392 and box['x']>=-2 and box['x']+box['width']<=392
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.screenshot(path='/mnt/data/optimum67-work-mobile-proof.png',full_page=True)
 await page.close()

async def pdc_owner_flow(browser):
 enable_pdc_contracts()
 captured['actor']='owner'; captured['pdc_calls'].clear()
 page=await browser.new_page(viewport={'width':1536,'height':1024})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/projects"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.project-portfolio-toolbar').wait_for(state='visible',timeout=8000)
 assert await page.locator('.pdc-project-card').count()==2
 await page.locator('.pdc-project-card [data-action="open-project"]').first.click()
 await page.locator('.project360-context').wait_for(state='visible',timeout=4000)
 assert '82%' in await page.locator('.project-health-orb').inner_text()
 assert await page.locator('.project-relationship-tree [data-action="open-site"]').count()==1
 await page.locator('.project-relationship-tree [data-action="open-site"]').click(); await page.locator('.site-delivery-hero').wait_for(state='visible',timeout=4000)
 assert 'Alpha Main Site' in await page.locator('.entity-workspace').inner_text()
 await page.locator('[data-action="close-entity-workspace"]').first.click()
 # open exact project CDE
 await page.locator('.pdc-project-card [data-action="open-project-files"]').first.click(); await page.locator('.cde-workspace').wait_for(state='visible',timeout=6000)
 assert await page.locator('.folder-tree-panel').count()==1
 await page.locator(f'[data-action="open-folder"][data-id="{FOLDER}"]').first.click()
 await page.locator('.cde-document-card').wait_for(state='visible',timeout=5000)
 assert 'Electrical Shop Drawing A-102' in await page.locator('.cde-document-card').inner_text()
 # server-side search
 await page.locator('#file-search').fill('Electrical Shop'); await page.wait_for_timeout(500)
 assert await page.locator('.cde-search-caption').count()==1
 # Document 360 and direct linked Work
 await page.locator(f'[data-action="open-document"][data-id="{DOC}"]').first.click(); await page.locator('.document360-hero').wait_for(state='visible',timeout=4000)
 assert await page.locator('.document360-links').count()==1
 assert await page.locator('[data-action="set-document-control"]').count()==5
 before=len(captured['pdc_calls']); await page.locator('[data-action="set-document-control"][data-status="approved"]').click(); await wait_until(lambda: len(captured['pdc_calls'])>before,label='document control status')
 assert captured['pdc_calls'][-1][0]=='set_document_control_status'
 await page.wait_for_timeout(700)
 await page.locator('[data-action="close-overlay"]').first.click()
 # Storage intelligence is real/actionable.
 await page.locator('[data-action="open-storage-intelligence"]').click(); await page.locator('.storage-intelligence-hero').wait_for(state='visible',timeout=3000)
 assert '7.0 MB' in await page.locator('.storage-intelligence-hero').inner_text()
 await page.locator('[data-action="close-overlay"]').first.click()
 # Smart Trash server view.
 await page.locator('[data-nav="trash"]').click(); await page.locator('.trash-control').wait_for(state='visible',timeout=4000)
 assert 'Old Correspondence' in await page.locator('.page').inner_text()
 # Blueprint create and command RPC capture.
 await page.locator('[data-nav="projects"]').click(); await page.locator('[data-action="new-project"]').first.click()
 form=page.locator('form[data-form="project"]'); await form.wait_for(state='visible',timeout=3000)
 assert await form.locator('.blueprint-choice').count()>=1
 await form.locator('[name="name"]').fill('PDC Browser Project'); await form.locator('[name="code"]').fill('PDC-BR')
 before=len(captured['pdc_calls']); await form.locator('button[type="submit"]').click(); await wait_until(lambda: len(captured['pdc_calls'])>before,label='save project RPC')
 assert captured['pdc_calls'][-1][0]=='save_project' and captured['pdc_calls'][-1][1]['p_payload']['blueprint_id']==BLUEPRINT
 await page.screenshot(path='/mnt/data/optimum68-project-document-control-proof.png',full_page=True)
 await page.close()

async def pdc_limited_flow(browser):
 enable_pdc_contracts(); captured['actor']='engineer'; captured['pdc_calls'].clear()
 page=await browser.new_page(viewport={'width':1440,'height':960})
 await initialize(page,'client','engineer'); await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/projects"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.project-portfolio-toolbar').wait_for(state='visible',timeout=8000)
 assert await page.locator('[data-action="new-project"]').count()==0
 await page.locator('.pdc-project-card [data-action="open-project"]').first.click(); await page.locator('.project360-context').wait_for(state='visible',timeout=4000)
 assert await page.locator('[data-action="archive-project"]').count()==0
 assert await page.locator('[data-action="edit-project"]').count()==0
 await page.locator('[data-action="close-entity-workspace"]').first.click()
 await page.locator('.pdc-project-card [data-action="open-project-files"]').first.click(); await page.locator('.cde-workspace').wait_for(state='visible',timeout=5000)
 # Permission-aware UI: actions the limited user cannot perform are absent, not dead buttons.
 assert await page.locator('[data-action="upload-files"]').count()==0
 assert await page.locator('[data-action="create-folder"]').count()==0
 await page.locator(f'[data-action="open-folder"][data-id="{FOLDER}"]').first.click(); await page.locator('.cde-document-card').wait_for(state='visible',timeout=5000)
 await page.locator(f'[data-action="open-document"][data-id="{DOC}"]').first.click(); await page.locator('.document360-hero').wait_for(state='visible',timeout=4000)
 assert await page.locator('[data-action="set-document-control"]').count()==0
 assert await page.locator('[data-action="rename-document"]').count()==1
 assert await page.locator('[data-action="move-document"]').count()==1
 assert await page.locator('[data-action="trash-document"]').count()==0
 await page.screenshot(path='/mnt/data/optimum68-limited-document-control-proof.png',full_page=True)
 await page.close()

async def pdc_mobile_flow(browser):
 enable_pdc_contracts(); captured['actor']='owner'
 page=await browser.new_page(viewport={'width':390,'height':844})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/projects"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded'); await page.locator('.project-portfolio-toolbar').wait_for(state='visible',timeout=8000)
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.locator('.pdc-project-card [data-action="open-project"]').first.click(); workspace=page.locator('.entity-workspace'); await workspace.wait_for(state='visible',timeout=4000); await page.wait_for_timeout(240)
 box=await workspace.bounding_box(); assert box and box['width']<=392 and box['x']>=-2 and box['x']+box['width']<=392
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.locator('[data-action="close-entity-workspace"]').first.click(); await page.locator('.pdc-project-card [data-action="open-project-files"]').first.click(); await page.locator('.cde-workspace').wait_for(state='visible',timeout=5000)
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.locator(f'[data-action="open-folder"][data-id="{FOLDER}"]').first.click(); await page.locator('.cde-document-card').wait_for(state='visible',timeout=5000); await page.locator(f'[data-action="open-document"][data-id="{DOC}"]').first.click(); drawer=page.locator('.drawer').last; await drawer.wait_for(state='visible',timeout=4000); await page.wait_for_timeout(240)
 box=await drawer.bounding_box(); assert box and box['width']<=392 and box['x']>=-2 and box['x']+box['width']<=392
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.screenshot(path='/mnt/data/optimum68-project-document-mobile-proof.png',full_page=True)
 await page.close()


async def site69_owner_flow(browser):
 enable_pdc_contracts(); captured['actor']='owner'; captured['pdc_calls'].clear()
 page=await browser.new_page(viewport={'width':1536,'height':1024})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/projects"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded'); await page.locator('.project-portfolio-toolbar').wait_for(state='visible',timeout=8000)
 # Site Delivery 360
 await page.locator('.pdc-project-card [data-action="open-project"]').first.click(); await page.locator('.project360-context').wait_for(state='visible',timeout=4000)
 await page.locator(f'[data-action="open-site"][data-id="{SITE}"]').click(); await page.locator('.site-delivery-hero').wait_for(state='visible',timeout=4000)
 assert await page.locator('.cabinet-card').count()==1
 assert await page.locator('[data-action="new-cabinet"]').count()==1
 assert '42%' in await page.locator('.site-delivery-hero').inner_text()
 # Cabinet 360
 await page.locator(f'[data-action="open-cabinet"][data-id="{CABINET}"]').click(); await page.locator('.cabinet-context-hero').wait_for(state='visible',timeout=4000)
 assert await page.locator('.cabinet-record-area').count()==6
 assert await page.locator('[data-action="edit-cabinet"]').count()==1
 assert await page.locator('[data-action="archive-cabinet"]').count()==1
 await page.locator('[data-action="close-entity-workspace"]').first.click()
 # Claim package and auto collect
 await page.locator('.pdc-project-card [data-action="open-project"]').first.click(); await page.locator(f'[data-action="open-site"][data-id="{SITE}"]').click(); await page.locator('.site-delivery-hero').wait_for(state='visible',timeout=4000)
 await page.locator(f'[data-action="open-claim-package"][data-id="{CLAIM}"]').click(); await page.locator('.claim360-hero').wait_for(state='visible',timeout=4000)
 assert await page.locator('.claim-requirement').count()>=2
 assert await page.locator('[data-action="refresh-delivery-package"]').count()==1
 before=len(captured['point910_calls']); await page.locator('[data-action="refresh-delivery-package"]').click(); await wait_until(lambda: len(captured['point910_calls'])>before,label='refresh delivery package')
 assert captured['point910_calls'][-1][0]=='refresh_site_claim_package_v2'
 await page.locator('.claim360-hero').wait_for(state='visible',timeout=4000)
 # Included canonical document deep-link -> Document 360 -> add to another claim requirement.
 await page.locator(f'[data-action="navigate-entity"][data-type="document"][data-id="{SITE_DOC}"]').click(); await page.locator('.document360-hero').wait_for(state='visible',timeout=6000)
 assert await page.locator('.document-cabinet-context').count()==1
 assert await page.locator('.drawer').last.locator('[data-action="classify-document-claim"]').count()>=1
 await page.locator('.drawer').last.locator('[data-action="classify-document-claim"]').click(); form=page.locator('form[data-form="document-claim-classification"]'); await form.wait_for(state='visible',timeout=3000)
 await form.locator('[name="claim_mode"]').select_option('include')
 if await form.locator('[name="claim_requirement"]').count(): await form.locator('[name="claim_requirement"]').select_option('quantity_survey')
 before=len(captured['point910_calls']); await form.locator('button[type="submit"]').click(); await wait_until(lambda: len(captured['point910_calls'])>before,label='classify document for site claim')
 assert captured['point910_calls'][-1][0]=='set_document_claim_classification'
 assert captured['point910_calls'][-1][1].get('p_mode')=='include'
 # Create Cabinet command from Site 360.
 await page.locator('[data-action="close-overlay"]').first.click()
 await page.locator('[data-nav="projects"]').click(); await page.locator('.pdc-project-card [data-action="open-project"]').first.click(); await page.locator(f'[data-action="open-site"][data-id="{SITE}"]').click(); await page.locator('.site-delivery-hero').wait_for(state='visible',timeout=4000)
 await page.locator('[data-action="new-cabinet"]').click(); form=page.locator('form[data-form="site-cabinet"]'); await form.wait_for(state='visible',timeout=3000)
 await form.locator('[name="code"]').fill('CAB-02'); await form.locator('[name="name"]').fill('Cabinet Two')
 before=len(captured['pdc_calls']); await form.locator('button[type="submit"]').click(); await wait_until(lambda: len(captured['pdc_calls'])>before,label='save site cabinet')
 assert captured['pdc_calls'][-1][0]=='save_site_cabinet'
 await page.screenshot(path='/mnt/data/optimum69-site-delivery-claim-proof.png',full_page=True)
 await page.close()

async def site69_limited_flow(browser):
 enable_pdc_contracts(); captured['actor']='engineer'; captured['pdc_calls'].clear()
 page=await browser.new_page(viewport={'width':1440,'height':960})
 await initialize(page,'client','engineer'); await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/projects"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded'); await page.locator('.project-portfolio-toolbar').wait_for(state='visible',timeout=8000)
 await page.locator('.pdc-project-card [data-action="open-project"]').first.click(); await page.locator(f'[data-action="open-site"][data-id="{SITE}"]').click(); await page.locator('.site-delivery-hero').wait_for(state='visible',timeout=4000)
 assert await page.locator('[data-action="new-cabinet"]').count()==0
 assert await page.locator('[data-action="edit-site"]').count()==0
 assert await page.locator('[data-action="archive-site"]').count()==0
 await page.locator(f'[data-action="open-cabinet"][data-id="{CABINET}"]').click(); await page.locator('.cabinet-context-hero').wait_for(state='visible',timeout=4000)
 assert await page.locator('[data-action="edit-cabinet"]').count()==0
 assert await page.locator('[data-action="archive-cabinet"]').count()==0
 await page.locator('[data-action="close-entity-workspace"]').first.click()
 await page.locator('.pdc-project-card [data-action="open-project"]').first.click(); await page.locator(f'[data-action="open-site"][data-id="{SITE}"]').click(); await page.locator(f'[data-action="open-claim-package"][data-id="{CLAIM}"]').click(); await page.locator('.claim360-hero').wait_for(state='visible',timeout=4000)
 assert await page.locator('[data-action="refresh-delivery-package"]').count()==0
 assert await page.locator('[data-action="add-claim-requirement"]').count()==0
 assert await page.locator('[data-action="freeze-claim"]').count()==0
 await page.locator(f'[data-action="navigate-entity"][data-type="document"][data-id="{SITE_DOC}"]').click(); await page.locator('.document360-hero').wait_for(state='visible',timeout=6000)
 assert await page.locator('.document-cabinet-context').count()==1
 assert await page.locator('.drawer').last.locator('[data-action="classify-document-claim"]').count()==0
 # Proof screenshot should show the stable read-only Site Delivery surface rather than a nested portal transition.
 await page.locator('[data-action="close-overlay"]').first.click()
 await page.locator('[data-nav="projects"]').click(); await page.locator('.pdc-project-card [data-action="open-project"]').first.click(); await page.locator(f'[data-action="open-site"][data-id="{SITE}"]').click(); await page.locator('.site-delivery-hero').wait_for(state='visible',timeout=4000); await page.wait_for_timeout(320)
 await page.screenshot(path='/mnt/data/optimum69-site-delivery-limited-proof.png',full_page=True)
 await page.close()

async def site69_mobile_flow(browser):
 enable_pdc_contracts(); captured['actor']='owner'
 page=await browser.new_page(viewport={'width':390,'height':844})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/projects"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded'); await page.locator('.project-portfolio-toolbar').wait_for(state='visible',timeout=8000)
 await page.locator('.pdc-project-card [data-action="open-project"]').first.click(); await page.locator(f'[data-action="open-site"][data-id="{SITE}"]').click(); workspace=page.locator('.entity-workspace'); await page.locator('.site-delivery-hero').wait_for(state='visible',timeout=4000); await page.wait_for_timeout(180)
 box=await workspace.bounding_box(); assert box and box['width']<=392 and box['x']>=-2 and box['x']+box['width']<=392; assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.locator(f'[data-action="open-cabinet"][data-id="{CABINET}"]').click(); await page.locator('.cabinet-context-hero').wait_for(state='visible',timeout=4000); await page.wait_for_timeout(180)
 box=await page.locator('.entity-workspace').bounding_box(); assert box and box['width']<=392 and box['x']>=-2 and box['x']+box['width']<=392; assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.locator('[data-action="close-entity-workspace"]').first.click(); await page.locator('.pdc-project-card [data-action="open-project"]').first.click(); await page.locator(f'[data-action="open-site"][data-id="{SITE}"]').click(); await page.locator(f'[data-action="open-claim-package"][data-id="{CLAIM}"]').click(); await page.locator('.claim360-hero').wait_for(state='visible',timeout=4000); await page.wait_for_timeout(180)
 box=await page.locator('.drawer').last.bounding_box(); assert box and box['width']<=392 and box['x']>=-2 and box['x']+box['width']<=392; assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.screenshot(path='/mnt/data/optimum69-site-delivery-mobile-proof.png',full_page=True)
 await page.close()



async def premium69_site_delivery_flow(browser):
 enable_pdc_contracts(); captured['actor']='owner'; captured['pdc_calls'].clear()
 # Desktop: Site Delivery should behave like a delivery decision surface, not a KPI dashboard.
 page=await browser.new_page(viewport={'width':1536,'height':1024})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/projects"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded'); await page.locator('.project-portfolio-toolbar').wait_for(state='visible',timeout=8000)
 await page.locator('.pdc-project-card [data-action="open-project"]').first.click(); await page.locator(f'[data-action="open-site"][data-id="{SITE}"]').click(); await page.locator('.site-delivery-hero-premium').wait_for(state='visible',timeout=5000)
 assert await page.locator('.delivery-signal-grid > article').count()==4
 assert '1/6' in await page.locator('.delivery-signal-grid').inner_text()
 assert '42%' in await page.locator('.site-claim-readiness').inner_text()
 assert await page.locator('.site-claim-next-card').count()==1
 assert await page.locator('.delivery-unit-card').count()==1
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.screenshot(path='/mnt/data/optimum691-feature6-site-delivery-desktop-proof.png',full_page=True)
 # Claim 360: next action, lifecycle, evidence-first ordering, and canonical document links.
 await page.locator(f'[data-action="open-claim-package"][data-id="{CLAIM}"]').click(); await page.locator('.claim-site-package-hero').wait_for(state='visible',timeout=5000)
 assert await page.locator('.claim-scope-summary > article').count()==4
 assert await page.locator('.claim-missing-panel').count()==1
 assert await page.locator('.claim-primary-action-bar').count()==1
 assert await page.locator('.claim-evidence-list .claim-requirement').count()>=2
 assert await page.locator('[data-action="refresh-delivery-package"]').count()==1
 assert await page.locator('[data-action="prepare-site-claim"]').count()==1
 first_req=await page.locator('.claim-evidence-list .claim-requirement').first.get_attribute('class')
 assert 'is-missing' in first_req, 'missing required evidence must sort first'
 assert await page.locator(f'[data-action="navigate-entity"][data-type="document"][data-id="{SITE_DOC}"]').count()==1
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.screenshot(path='/mnt/data/optimum691-feature6-claim360-desktop-proof.png',full_page=True)
 await page.close()

 # Mobile: same information hierarchy must remain usable with zero page overflow.
 page=await browser.new_page(viewport={'width':390,'height':844})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/projects"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded'); await page.locator('.project-portfolio-toolbar').wait_for(state='visible',timeout=8000)
 await page.locator('.pdc-project-card [data-action="open-project"]').first.click(); await page.locator(f'[data-action="open-site"][data-id="{SITE}"]').click(); await page.locator('.site-delivery-hero-premium').wait_for(state='visible',timeout=5000); await page.wait_for_timeout(220)
 workspace=page.locator('.entity-workspace'); box=await workspace.bounding_box(); assert box and box['width']<=392 and box['x']>=-2 and box['x']+box['width']<=392
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.screenshot(path='/mnt/data/optimum691-feature6-site-delivery-mobile-proof.png',full_page=True)
 await page.locator(f'[data-action="open-claim-package"][data-id="{CLAIM}"]').click(); await page.locator('.claim-site-package-hero').wait_for(state='visible',timeout=5000); await page.wait_for_timeout(220)
 box=await page.locator('.drawer').last.bounding_box(); assert box and box['width']<=392 and box['x']>=-2 and box['x']+box['width']<=392
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 assert await page.locator('.claim-primary-action-bar').count()==1
 assert await page.locator('.claim-missing-panel').count()==1
 assert await page.locator('.claim-evidence-list').count()==1
 await page.screenshot(path='/mnt/data/optimum691-feature6-claim360-mobile-proof.png',full_page=True)
 await page.close()


async def point10_site_execution_flow(browser):
 enable_point10_contracts(); captured['actor']='engineer'; captured['point10_calls']=[]; captured['point10_report_linked']=False; captured['cde_calls'].clear(); captured['storage_uploads'].clear()
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/field"</script>',1)
 page=await browser.new_page(viewport={'width':1536,'height':1024})
 await initialize(page,'client','engineer'); await page.route('https://client.test/**',local_route); await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.field-execution-strip').wait_for(state='visible',timeout=9000)
 assert 'تنفيذ اليوم' in await page.locator('.field-execution-strip').inner_text()
 assert await page.locator('.field-exec-metric').count()>=6
 assert await page.locator('[data-action="field-daily-log"]').count()>=1
 assert await page.locator('[data-action="field-new-inspection"]').count()>=1
 assert await page.locator('[data-action="field-new-issue"]').count()>=1
 assert await page.locator('[data-action="field-new-constraint"]').count()>=1
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.screenshot(path='/mnt/data/optimum-point10-site-execution-desktop.png',full_page=True)
 # Daily report editor is beginner-first and prefilled from canonical execution data.
 await page.locator('[data-action="field-daily-log"]').first.click(); await page.locator('[data-form="field-daily-log"]').wait_for(state='visible',timeout=4000)
 assert 'تم تركيب واختبار CAB-01' in await page.locator('[data-form="field-daily-log"] textarea[name="work_completed"]').input_value()
 await page.screenshot(path='/mnt/data/optimum-point10-daily-log.png',full_page=True)
 # Saving is not a UI-only success: it writes the log, uploads a real report blob through the CDE pipeline, finalizes it, and links the canonical document.
 await page.locator('[data-form="field-daily-log"] textarea[name="summary"]').fill('تم إنهاء أعمال الكابينة ومراجعة الرسم والحصر')
 calls_before=len(captured['cde_calls']); uploads_before=len(captured['storage_uploads'])
 await page.locator('[data-form="field-daily-log"] button[type="submit"]').click()
 await wait_until(lambda:any(x[0]=='save_site_daily_log' for x in captured['point10_calls']),label='point10 daily log save')
 await wait_until(lambda:any(x[0]=='begin_document_upload_v2' and x[1].get('p_document_type')=='report' for x in captured['cde_calls'][calls_before:]),label='point10 report cde reservation')
 await wait_until(lambda:len(captured['storage_uploads'])>uploads_before,label='point10 report binary upload')
 await wait_until(lambda:any(x[0]=='finalize_document_upload' for x in captured['cde_calls'][calls_before:]),label='point10 report finalize')
 await wait_until(lambda:any(x[0]=='link_site_daily_report_document' for x in captured['point10_calls']),label='point10 report canonical link')
 assert any('daily-report' in x and x.endswith('.html') for x in captured['storage_uploads']), captured['storage_uploads']
 await page.locator('[data-action="close-overlay"]').last.click(); await page.wait_for_timeout(80)
 # A later save uses the existing CDE document as a new version instead of overwriting history.
 await page.locator('[data-action="field-daily-log"]').first.click(); await page.locator('[data-form="field-daily-log"]').wait_for(state='visible',timeout=4000)
 version_calls=len(captured['cde_calls']); version_uploads=len(captured['storage_uploads'])
 await page.locator('[data-form="field-daily-log"] textarea[name="tomorrow_plan"]').fill('استكمال توثيق المسار وتسليم الفحص')
 await page.locator('[data-form="field-daily-log"] button[type="submit"]').click()
 await wait_until(lambda:any(x[0]=='begin_new_version_upload_v2' and x[1].get('p_document_id')==P10_REPORT_DOC for x in captured['cde_calls'][version_calls:]),label='point10 report new version')
 await wait_until(lambda:len(captured['storage_uploads'])>version_uploads,label='point10 report version binary upload')
 await page.locator('[data-action="close-overlay"]').last.click(); await page.wait_for_timeout(80)
 # Inspection detail exposes pass/fail/NA, current results, and canonical CDE evidence linking.
 await page.locator(f'[data-action="field-open-inspection"][data-id="{P10_INSPECTION}"]').first.click(); await page.locator('.field-inspection-items').wait_for(state='visible',timeout=4000)
 assert await page.locator('.field-inspection-item').count()==2
 assert await page.locator('.field-inspection-item.pass').count()>=1
 assert await page.locator('.field-inspection-evidence-guide').count()==1
 await page.screenshot(path='/mnt/data/optimum-point10-inspection.png',full_page=True)
 evidence_selects=page.locator('[data-inspection-evidence]')
 assert await evidence_selects.count()==2
 await evidence_selects.nth(1).select_option(DOC)
 inspection_calls=len(captured['point10_calls'])
 await page.locator('[data-form="field-inspection-save"] button[type="submit"]').click()
 await wait_until(lambda:any(x[0]=='save_site_inspection' for x in captured['point10_calls'][inspection_calls:]),label='point10 inspection evidence save')
 saved=[x for x in captured['point10_calls'][inspection_calls:] if x[0]=='save_site_inspection'][-1][1]
 assert any(r.get('item_key')=='evidence' and r.get('evidence_document_id')==DOC for r in saved.get('p_results',[])), saved
 # Async form handling still refreshes execution state after the save RPC returns; wait for the inspection drawer to finish closing.
 await page.locator('[data-form="field-inspection-save"]').wait_for(state='detached',timeout=5000)
 # End-of-day review explains exactly what is missing.
 await page.locator('[data-action="field-end-day"]').click(); await page.locator('.field-eod-hero').wait_for(state='visible',timeout=4000)
 assert '5/7' in await page.locator('.field-eod-hero').inner_text()
 assert await page.locator('.field-eod-checks').count()==1
 await page.screenshot(path='/mnt/data/optimum-point10-end-of-day.png',full_page=True)
 await page.locator('[data-action="close-overlay"]').last.click(); await page.wait_for_timeout(60)
 # Weekly summary reads real daily signals instead of a manual percentage.
 await page.locator('[data-action="field-weekly"]').click(); await page.locator('.field-weekly-metrics').wait_for(state='visible',timeout=4000)
 assert '8' in await page.locator('.field-weekly-metrics').inner_text()
 await page.screenshot(path='/mnt/data/optimum-point10-weekly-summary.png',full_page=True)
 await page.locator('[data-action="close-overlay"]').last.click(); await page.close()
 # Mobile execution workspace remains usable in the field.
 page=await browser.new_page(viewport={'width':390,'height':844})
 await initialize(page,'client','engineer'); await page.route('https://client.test/**',local_route); await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.field-execution-strip').wait_for(state='visible',timeout=9000); await page.wait_for_timeout(120)
 ov=await page.evaluate('({doc:document.documentElement.scrollWidth,body:document.body.scrollWidth,inner:window.innerWidth})')
 assert ov['doc']<=ov['inner']+3 and ov['body']<=ov['inner']+3,ov
 await page.screenshot(path='/mnt/data/optimum-point10-site-execution-mobile.png',full_page=True)
 await page.close(); captured['actor']='owner'

async def point9_site_supervisor_flow(browser):
 enable_point9_contracts(); captured['actor']='engineer'
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/field"</script>',1)
 page=await browser.new_page(viewport={'width':1536,'height':1024})
 await initialize(page,'client','engineer'); await page.route('https://client.test/**',local_route); await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.field-hero').wait_for(state='visible',timeout=9000)
 assert 'مساحة مشرف الموقع' in await page.locator('.page-header').inner_text()
 assert 'كل يوم الموقع في مكان واحد' in await page.locator('.field-hero').inner_text()
 assert await page.locator('.field-metric').count()==5
 assert await page.locator('.field-action-grid > button').count()>=5
 assert await page.locator('.field-cabinet-card').count()==1
 assert await page.locator('.field-drawing-row').count()==1
 assert await page.locator('.field-doc-row').count()==1
 assert '67%' in await page.locator('.field-cabinet-card').inner_text()
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.screenshot(path='/mnt/data/optimum-point9-site-supervisor-desktop.png',full_page=True)
 # Context-aware drawing creation: project/site are prefilled from the field workspace.
 await page.locator('[data-action="field-new-drawing"]').first.click(); await page.locator('.cad-new-drawing').wait_for(state='visible',timeout=4000)
 assert await page.locator('#engineering-project-select').input_value()==projects[0]['id']
 assert await page.locator('#engineering-site-select').input_value()==SITE
 await page.locator('[data-action="close-overlay"]').last.click(); await page.wait_for_timeout(80)
 # Context-aware task creation uses the same project/site without asking again.
 await page.locator('[data-action="field-new-task"]').click(); await page.locator('.task-dialog').wait_for(state='visible',timeout=4000)
 assert await page.locator('.task-dialog select[name="project_id"]').input_value()==projects[0]['id']
 assert await page.locator('.task-dialog select[name="site_id"]').input_value()==SITE
 await page.locator('[data-action="close-overlay"]').last.click(); await page.close()
 # Mobile field workspace is touch-friendly and contained.
 page=await browser.new_page(viewport={'width':390,'height':844})
 await initialize(page,'client','engineer'); await page.route('https://client.test/**',local_route); await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.field-hero').wait_for(state='visible',timeout=9000); await page.wait_for_timeout(120)
 assert await page.locator('.field-action-grid').count()==1
 assert await page.locator('.field-cabinet-card').count()==1
 overflow=await page.evaluate('({doc:document.documentElement.scrollWidth,body:document.body.scrollWidth,inner:window.innerWidth})')
 assert overflow['doc']<=overflow['inner']+3 and overflow['body']<=overflow['inner']+3, overflow
 await page.screenshot(path='/mnt/data/optimum-point9-site-supervisor-mobile.png',full_page=True)
 await page.close(); captured['actor']='owner'

async def point8_operations_center_flow(browser):
 enable_global_action_contracts(); enable_pdc_contracts(); captured['actor']='owner'; captured['operations_calls'].clear(); captured['operations_followed']=False
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/operations"</script>',1)
 page=await browser.new_page(viewport={'width':1536,'height':1024})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route); await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.ops-welcome').wait_for(state='visible',timeout=9000)
 assert 'مركز التشغيل' in await page.locator('.page').inner_text()
 assert await page.locator('.ops-metric').count()==4
 assert await page.locator('.ops-work-row').count()>=1
 assert await page.locator('.ops-tabs button').count()==5
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.screenshot(path='/mnt/data/optimum-point8-operations-desktop.png',full_page=True)
 # Inbox separates action-required and FYI updates.
 await page.locator('.ops-tabs [data-action="ops-view"][data-view="inbox"]').click(); await page.wait_for_timeout(100)
 assert await page.locator('.ops-inbox-row').count()==2
 assert await page.locator('.ops-inbox-row.needs-action').count()==1
 await page.screenshot(path='/mnt/data/optimum-point8-inbox-desktop.png',full_page=True)
 # Approvals center is a decision surface, not a disabled menu.
 await page.locator('.ops-tabs [data-action="ops-view"][data-view="approvals"]').click(); await page.wait_for_timeout(80)
 assert await page.locator('.ops-decision-row').count()>=2
 # Change center + follow.
 await page.locator('.ops-tabs [data-action="ops-view"][data-view="changes"]').click(); await page.wait_for_timeout(80)
 assert await page.locator('.ops-change-row').count()>=1
 star=page.locator('[data-action="ops-toggle-follow"]').first; await star.click(); await page.wait_for_timeout(100)
 assert any(x[0]=='toggle_entity_follow' for x in captured['operations_calls'])
 await page.screenshot(path='/mnt/data/optimum-point8-changes-desktop.png',full_page=True)
 await page.locator('.ops-tabs [data-action="ops-view"][data-view="today"]').click(); await page.wait_for_timeout(60)
 assert await page.locator('.ops-follow-grid').count()==1
 # Unified calendar layers persist through the real contract.
 await page.locator('.ops-tabs [data-action="ops-view"][data-view="calendar"]').click(); await page.locator('.ops-calendar').wait_for(state='visible',timeout=3000)
 assert await page.locator('[data-ops-layer]').count()==6
 assert await page.locator('.ops-calendar-event').count()>=3
 layer=page.locator('.ops-layer:has([data-ops-layer="drawings"])'); await layer.click(); await page.wait_for_timeout(100)
 assert any(x[0]=='save_operations_calendar_layers' and x[1].get('p_layers',{}).get('drawings') is False for x in captured['operations_calls'])
 await page.screenshot(path='/mnt/data/optimum-point8-calendar-desktop.png',full_page=True)
 # English is first-class: switch locale through the real shell and verify Point 8 rerenders, not a mixed-language overlay.
 await page.locator('[data-action="utility-menu"]').click(); await page.locator('.utility-menu-pop [data-action="toggle-locale"]').click(); await page.wait_for_timeout(140)
 assert await page.locator('html').get_attribute('dir')=='ltr'
 assert 'Operations Center' in await page.locator('.page-header').inner_text()
 assert 'UNIFIED CALENDAR' in await page.locator('.ops-calendar').inner_text()
 await page.screenshot(path='/mnt/data/optimum-point8-operations-english.png',full_page=True)
 await page.close()
 # Limited mobile: backend snapshot supplies only allowed work; layout remains simple and contained.
 captured['actor']='engineer'; captured['operations_calls'].clear()
 page=await browser.new_page(viewport={'width':390,'height':844})
 await initialize(page,'client','engineer'); await page.route('https://client.test/**',local_route); await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.ops-welcome').wait_for(state='visible',timeout=9000); await page.wait_for_timeout(160)
 assert await page.locator('.ops-work-row').count()>=1
 await page.locator('.ops-tabs [data-action="ops-view"][data-view="approvals"]').click(); await page.wait_for_timeout(60)
 assert await page.locator('.ops-decision-row').count()==0
 overflow=await page.evaluate('({doc:document.documentElement.scrollWidth,body:document.body.scrollWidth,inner:window.innerWidth})')
 assert overflow['doc']<=overflow['inner']+3 and overflow['body']<=overflow['inner']+3, overflow
 await page.screenshot(path='/mnt/data/optimum-point8-operations-mobile.png',full_page=True)
 await page.close(); captured['actor']='owner'

async def point7_delivery_intelligence_flow(browser):
 enable_pdc_contracts(); captured['actor']='owner'; captured['point7_review']=True; captured['pdc_calls'].clear()
 page=await browser.new_page(viewport={'width':1536,'height':1024})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/delivery"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.delivery-center-grid').wait_for(state='visible',timeout=9000)
 assert await page.locator('.delivery-guide > div').count()==3
 assert await page.locator('.delivery-package-card').count()==1
 assert 'إصدار تغيّر' in await page.locator('.delivery-package-card').inner_text()
 await page.locator('#delivery-project-filter').select_option(projects[0]['id']); await page.locator('.delivery-closeout-map').wait_for(state='visible',timeout=5000)
 assert await page.locator('.delivery-closeout-cabinet').count()==1
 assert '67%' in await page.locator('.delivery-closeout-cabinet').inner_text()
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.screenshot(path='/mnt/data/optimum-point7-delivery-center-desktop.png',full_page=True)
 await page.locator('.delivery-package-card').click(); await page.locator('.claim-site-package-hero').wait_for(state='visible',timeout=5000)
 assert await page.locator('.claim-stale-warning').count()==1
 assert await page.locator('.claim-event-timeline article').count()>=2
 assert await page.locator('[data-action="approve-claim"]').count()==1
 assert await page.locator('[data-action="reject-claim"]').count()==1
 assert await page.locator('[data-action="review-claim-item"]').count()>=1
 await page.wait_for_timeout(260)
 await page.screenshot(path='/mnt/data/optimum-point7-claim360-review.png',full_page=True)
 await page.locator('[data-action="review-claim-item"]').first.click(); await page.wait_for_timeout(100)
 assert any(x[0]=='review_site_claim_item' and x[1].get('p_status')=='accepted' for x in captured['pdc_calls'])
 await page.close()

 # Limited user: delivery is visible, management decisions are not.
 captured['actor']='engineer'; captured['pdc_calls'].clear()
 page=await browser.new_page(viewport={'width':390,'height':844})
 await initialize(page,'client','engineer'); await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/delivery"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded'); await page.locator('.delivery-center-grid').wait_for(state='visible',timeout=9000)
 await page.locator('.delivery-package-card').click(); await page.locator('.claim-site-package-hero').wait_for(state='visible',timeout=5000)
 assert await page.locator('[data-action="approve-claim"]').count()==0
 assert await page.locator('[data-action="reject-claim"]').count()==0
 assert await page.locator('[data-action="refresh-delivery-package"]').count()==0
 await page.wait_for_timeout(260)
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 box=await page.locator('.drawer').last.bounding_box(); assert box and box['width']<=392 and box['x']>=-2 and box['x']+box['width']<=392
 await page.screenshot(path='/mnt/data/optimum-point7-delivery-mobile-limited.png',full_page=True)
 await page.close()
 captured['actor']='owner'; captured['point7_review']=False


async def point910_consolidated_home_claim_flow(browser):
 enable_point9_contracts(); enable_global_action_contracts()
 captured['point910']=True; captured['point910_frozen']=False; captured['point910_export']=None; captured['point910_calls'].clear(); captured['point7_review']=False

 # A) Management Home: operations/project-control engines are embedded, not sidebar destinations.
 captured['actor']='owner'
 page=await browser.new_page(viewport={'width':1536,'height':1024})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/dashboard"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.dashboard-cockpit.management').wait_for(state='visible',timeout=10000)
 await page.locator('.home-control-summary').wait_for(state='visible',timeout=10000)
 await page.locator('.home-changes').wait_for(state='visible',timeout=10000)
 assert await page.locator('[data-nav="operations"]').count()==0
 assert await page.locator('[data-nav="control"]').count()==0
 assert await page.locator('[data-nav="field"]').count()==0
 assert await page.locator('.home-control-project').count()>=1
 assert await page.locator('.home-change-list button').count()>=1
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.screenshot(path='/mnt/data/optimum-core910-role-aware-home-management.png',full_page=True)
 # Localization contract: the consolidated Home is native English/LTR too, not Arabic copy in a flipped shell.
 await page.locator('[data-action="utility-menu"]').click(); await page.locator('.utility-menu-pop [data-action="toggle-locale"]').click(); await page.wait_for_timeout(220)
 assert await page.locator('html').get_attribute('dir')=='ltr'
 await page.locator('.dashboard-cockpit.management').wait_for(state='visible',timeout=7000)
 assert 'MANAGEMENT HOME' in (await page.locator('.dashboard-cockpit.management').inner_text()).upper()
 await page.screenshot(path='/mnt/data/optimum-core910-role-aware-home-english.png',full_page=True)
 await page.locator('[data-action="utility-menu"]').click(); await page.locator('.utility-menu-pop [data-action="toggle-locale"]').click(); await page.wait_for_timeout(220)
 assert await page.locator('html').get_attribute('dir')=='rtl'

 # Management control belongs inside Project 360.
 await page.locator('[data-nav="projects"]').first.click(); await page.locator('.project-portfolio-toolbar').wait_for(state='visible',timeout=8000)
 await page.locator('.pdc-project-card [data-action="open-project"]').first.click(); await page.locator('.project360-context').wait_for(state='visible',timeout=5000)
 assert await page.locator('.project-control-inline-entry').count()==1
 assert await page.locator('.project-control-inline-entry [data-action="pc-open-project"]').count()==1
 assert await page.locator('.project-control-inline-entry [data-action="pc-weekly-brief"]').count()==1
 await page.close()

 # B) Site Supervisor: the same Home becomes the field workspace; no extra nav module.
 captured['actor']='engineer'
 page=await browser.new_page(viewport={'width':1536,'height':1024})
 await initialize(page,'client','engineer'); await page.route('https://client.test/**',local_route); await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.role-aware-home.field-home .field-hero').wait_for(state='visible',timeout=10000)
 assert await page.locator('[data-nav="field"]').count()==0
 assert 'كل يوم الموقع في مكان واحد' in await page.locator('.field-hero').inner_text()
 assert await page.locator('.field-action-grid').count()==1
 await page.screenshot(path='/mnt/data/optimum-core910-role-aware-home-supervisor.png',full_page=True)
 await page.close()

 # C) Site Claim Package: canonical documents -> freeze exact versions -> structured ZIP.
 captured['actor']='owner'; captured['point910_calls'].clear(); captured['point910_frozen']=False; captured['point910_export']=None
 page=await browser.new_page(viewport={'width':1536,'height':1024})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route)
 claim_html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/delivery"</script>',1)
 await page.set_content(claim_html,wait_until='domcontentloaded')
 await page.locator('.delivery-center-grid').wait_for(state='visible',timeout=10000)
 page_text=await page.locator('.page').inner_text()
 assert 'مستخلصات المواقع' in page_text
 assert 'لا تسعير' in page_text or 'تجميع المستندات' in page_text
 # The clarified claim workflow is fully localized in English as well.
 await page.locator('[data-action="utility-menu"]').click(); await page.locator('.utility-menu-pop [data-action="toggle-locale"]').click(); await page.wait_for_timeout(220)
 assert await page.locator('html').get_attribute('dir')=='ltr'
 await page.locator('.delivery-center-grid').wait_for(state='visible',timeout=7000)
 english_claim=(await page.locator('.page').inner_text()).lower()
 assert 'site claim packages' in english_claim and ('no pricing' in english_claim or 'document assembly' in english_claim)
 await page.locator('[data-action="utility-menu"]').click(); await page.locator('.utility-menu-pop [data-action="toggle-locale"]').click(); await page.wait_for_timeout(220)
 assert await page.locator('html').get_attribute('dir')=='rtl'
 await page.locator('.delivery-center-grid').wait_for(state='visible',timeout=7000)
 await page.locator('.delivery-package-card').first.click(); await page.locator('.claim-site-package-hero').wait_for(state='visible',timeout=7000)
 drawer=page.locator('.drawer').last
 assert await drawer.locator('.claim-phase-boundary').count()==1
 assert await drawer.locator('.claim-missing-panel').count()==1
 assert await drawer.locator('.claim-primary-action-bar').count()==1
 assert '8' in await page.locator('.claim-site-package-hero').inner_text() or '100%' in await page.locator('.drawer').last.inner_text()
 await page.screenshot(path='/mnt/data/optimum-core910-site-claim-package.png',full_page=True)

 zip_path='/mnt/data/optimum-core910-site-claim-package.zip'
 try: os.unlink(zip_path)
 except FileNotFoundError: pass
 async with page.expect_download(timeout=30000) as download_info:
  await page.locator('[data-action="prepare-site-claim"]').click()
 download=await download_info.value
 await download.save_as(zip_path)
 await wait_until(lambda: any(x[0]=='record_site_claim_export' for x in captured['point910_calls']),timeout=8,label='record site claim export')
 calls=[x[0] for x in captured['point910_calls']]
 for required in ['refresh_site_claim_package_v2','freeze_site_claim_package','site_claim_package_export_manifest','record_site_claim_export']:
  assert required in calls, (required,calls)
 assert captured['point910_frozen'] is True
 assert captured['point910_export'] and captured['point910_export']['file_count']==3
 with zipfile.ZipFile(zip_path) as z:
  names=z.namelist()
  assert 'INDEX.html' in names,names
  assert 'MANIFEST.json' in names,names
  assert any(n.startswith('01 - ') and ('مستندات المشروع' in n or 'Project Documents' in n) for n in names),names
  assert any(n.startswith('02 - ') and ('مستندات الموقع' in n or 'Site Documents' in n) for n in names),names
  assert any(n.startswith('03 - ') and ('الكبائن' in n or 'Cabinets' in n) for n in names),names
  manifest=json.loads(z.read('MANIFEST.json').decode('utf-8'))
  assert manifest['package']['id']==CLAIM
  assert len(manifest['items'])==3
 await page.locator('.claim-export-history').wait_for(state='visible',timeout=7000)
 assert 'Owner User' in await page.locator('.claim-export-history').inner_text()

 # D) Document 360 classification is explicit and never duplicates the CDE file.
 await page.locator('[data-action="close-overlay"]').first.click(); await page.wait_for_timeout(80)
 await page.locator('[data-nav="projects"]').first.click(); await page.locator('.project-portfolio-toolbar').wait_for(state='visible',timeout=8000)
 await page.locator('.pdc-project-card [data-action="open-project-files"]').first.click(); await page.locator('.cde-workspace').wait_for(state='visible',timeout=6000)
 await page.locator(f'[data-action="open-folder"][data-id="{FOLDER}"]').first.click(); await page.locator('.cde-document-card').wait_for(state='visible',timeout=5000)
 await page.locator(f'[data-action="open-document"][data-id="{DOC}"]').first.click(); await page.locator('.document360-hero').wait_for(state='visible',timeout=5000)
 assert await page.locator('[data-action="classify-document-claim"]').count()==1
 await page.locator('[data-action="classify-document-claim"]').click(); form=page.locator('form[data-form="document-claim-classification"]'); await form.wait_for(state='visible',timeout=3000)
 await form.locator('[name="claim_mode"]').select_option('exclude')
 before=len(captured['point910_calls']); await form.locator('button[type="submit"]').click(); await wait_until(lambda: len(captured['point910_calls'])>before,timeout=5,label='claim classification')
 classify=[x for x in captured['point910_calls'] if x[0]=='set_document_claim_classification'][-1]
 assert classify[1].get('p_mode')=='exclude'
 await page.close()

 # E) Mobile remains contained and the claim drawer is usable.
 captured['actor']='owner'
 page=await browser.new_page(viewport={'width':390,'height':844})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route); await page.set_content(claim_html,wait_until='domcontentloaded')
 await page.locator('.delivery-center-grid').wait_for(state='visible',timeout=10000)
 await page.locator('.delivery-package-card').first.click(); await page.locator('.claim-site-package-hero').wait_for(state='visible',timeout=7000); await page.wait_for_timeout(300)
 overflow=await page.evaluate('({doc:document.documentElement.scrollWidth,body:document.body.scrollWidth,inner:window.innerWidth})')
 assert overflow['doc']<=overflow['inner']+3 and overflow['body']<=overflow['inner']+3,overflow
 box=await page.locator('.drawer').last.bounding_box(); assert box and box['x']>=-2 and box['x']+box['width']<=392,box
 await page.screenshot(path='/mnt/data/optimum-core910-site-claim-mobile.png',full_page=True)
 await page.close()
 captured['actor']='owner'; captured['point910']=False


async def premium69_project_context_flow(browser):
 enable_pdc_contracts(); captured['actor']='owner'; captured['pdc_calls'].clear()
 # Mobile is the hardest width for context drawers and structured forms.
 page=await browser.new_page(viewport={'width':390,'height':844})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/projects"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded'); await page.locator('.project-portfolio-toolbar').wait_for(state='visible',timeout=8000)
 metrics=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})')
 assert metrics['scroll']<=metrics['inner']+3, f'Premium F2 mobile portfolio overflow: {metrics}'
 assert await page.locator('.pdc-project-card').count()>=2
 # Project context prioritizes pulse, truthful scope, and site navigation.
 await page.locator('.pdc-project-card [data-action="open-project"]').first.click(); await page.locator('.project360-context').wait_for(state='visible',timeout=5000)
 assert await page.locator('.project-health-chip').count()==1
 assert await page.locator('.project-pulse-grid article').count()==4
 assert await page.locator('.project-context-strip').count()==1
 assert await page.locator('.project-relationship-tree [data-action="open-site"]').count()==1
 metrics=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})'); assert metrics['scroll']<=metrics['inner']+3
 # Site context stays operational; claim intelligence remains linked but not merged into the context redesign.
 await page.locator(f'[data-action="open-site"][data-id="{SITE}"]').click(); await page.locator('.site-context-hero').wait_for(state='visible',timeout=5000)
 assert await page.locator('.site-pulse-grid article').count()==4
 assert await page.locator('.site-context-grid').count()==1
 assert await page.locator(f'[data-action="open-cabinet"][data-id="{CABINET}"]').count()==1
 metrics=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})'); assert metrics['scroll']<=metrics['inner']+3
 await page.locator(f'[data-action="open-cabinet"][data-id="{CABINET}"]').click(); await page.locator('.cabinet-context-hero').wait_for(state='visible',timeout=5000)
 assert await page.locator('.cabinet-record-grid .cabinet-record-area').count()==6
 assert await page.locator('.entity-quick-actions [data-action="cabinet-open-work"]').count()==1
 metrics=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})'); assert metrics['scroll']<=metrics['inner']+3
 await page.screenshot(path='/mnt/data/optimum691-feature2-context-mobile-proof.png',full_page=True)
 # Form information architecture keeps core fields visible and advanced location data optional.
 await page.locator('[data-action="close-entity-workspace"]').first.click(); await page.locator('[data-action="new-project"]').first.click()
 form=page.locator('form[data-form="project"]'); await form.wait_for(state='visible',timeout=4000)
 assert await form.locator('.entity-form-section').count()>=3 and await form.locator('.blueprint-picker').count()==1 and await form.locator('.entity-form-advanced').count()==1
 await page.locator('[data-action="close-overlay"]').first.click()
 await page.locator('.pdc-project-card [data-action="open-project"]').first.click(); await page.locator('.project360-context').wait_for(state='visible',timeout=4000)
 await page.locator('[data-action="new-site"]').click(); site_form=page.locator('form[data-form="site"]'); await site_form.wait_for(state='visible',timeout=4000)
 assert await site_form.locator('.entity-form-section').count()==2 and await site_form.locator('.entity-form-advanced').count()==1
 await page.locator('[data-action="close-overlay"]').first.click()
 await page.locator('.pdc-project-card [data-action="open-project"]').first.click(); await page.locator(f'[data-action="open-site"][data-id="{SITE}"]').click(); await page.locator('.site-context-hero').wait_for(state='visible',timeout=4000)
 await page.locator('[data-action="new-cabinet"]').click(); cab_form=page.locator('form[data-form="site-cabinet"]'); await cab_form.wait_for(state='visible',timeout=4000)
 assert await cab_form.locator('.entity-form-section').count()==1 and await cab_form.locator('.entity-form-advanced').count()==1 and await cab_form.locator('.cabinet-seed-note-calm').count()==1
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.close()
 # Desktop width also stays contained and portfolio strip remains compact.
 page=await browser.new_page(viewport={'width':1500,'height':1000})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route)
 await page.set_content(html,wait_until='domcontentloaded'); await page.locator('.project-portfolio-toolbar').wait_for(state='visible',timeout=8000)
 metrics=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})'); assert metrics['scroll']<=metrics['inner']+3, f'Premium F2 desktop overflow: {metrics}'
 await page.locator('.pdc-project-card [data-action="open-project"]').first.click(); await page.locator('.project360-context').wait_for(state='visible',timeout=5000)
 assert await page.locator('.project-pulse-grid').count()==1
 await page.screenshot(path='/mnt/data/optimum691-feature2-context-desktop-proof.png',full_page=True)
 await page.close()

async def premium69_cde_information_flow(browser):
 enable_pdc_contracts(); captured['actor']='owner'; captured['pdc_calls'].clear(); captured['cde_calls'].clear(); captured['storage_uploads'].clear()
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/projects"</script>',1)

 # Desktop first: Point 5 is the primary proof for real CDE actions.
 page=await browser.new_page(viewport={'width':1500,'height':1000})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route); await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.project-portfolio-toolbar').wait_for(state='visible',timeout=15000)
 await page.locator('.pdc-project-card [data-action="open-project-files"]').first.click(); await page.locator('.cde-workspace').wait_for(state='visible',timeout=6000)
 assert await page.locator('.cde-onboarding').count()==1 and await page.locator('.cde-home-tabs button').count()==5
 assert await page.locator('.cde-requirements-summary').count()==1
 assert await page.locator('.cde-attention-strip').count()>=1
 metrics=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})'); assert metrics['scroll']<=metrics['inner']+3, f'Point 5 desktop overflow: {metrics}'
 await page.screenshot(path='/mnt/data/optimum-point5-cde-home-desktop.png',full_page=True)

 # Architecture catalog: built-in templates + company template + novice builder.
 await page.locator('[data-action="cde-architecture"]').first.click(); await page.locator('.cde-architecture-manager').wait_for(state='visible',timeout=4000)
 assert await page.locator('.cde-template-card').count()>=5
 assert await page.locator('.cde-template-tree').first.locator('.cde-template-node').count()>=4
 await page.screenshot(path='/mnt/data/optimum-point5-architecture-desktop.png',full_page=True)
 await page.locator('[data-action="cde-template-new"]').click(); await page.locator('form[data-form="folder-template"]').wait_for(state='visible',timeout=3000)
 assert await page.locator('.cde-builder-help').count()==1 and await page.locator('.cde-template-text').count()==1
 await page.locator('[data-action="close-overlay"]').first.click()

 # Quick Upload: real reservation -> Storage upload -> finalize flow with progress state.
 await page.locator('[data-action="upload-files"]').first.click(); form=page.locator('form[data-form="upload-files"]'); await form.wait_for(state='visible',timeout=3000)
 assert await form.locator('.cde-drop-zone').count()==1 and await form.locator('#upload-folder').count()==1
 await form.locator('#upload-input').set_input_files(files=[{'name':'CAB-12-Test-Certificate-R1.pdf','mimeType':'application/pdf','buffer':b'%PDF-1.4 mock point5'}])
 await form.locator('.upload-review-row').wait_for(state='visible',timeout=3000)
 assert await form.locator('.upload-doc-type').count()==1 and await form.locator('.upload-revision').count()==1
 upload_metrics=await form.locator('.upload-review-row').evaluate('(el)=>({scroll:el.scrollWidth,client:el.clientWidth})'); assert upload_metrics['scroll']<=upload_metrics['client']+3, f'Point 5 upload row overflow: {upload_metrics}'
 await page.screenshot(path='/mnt/data/optimum-point5-quick-upload-desktop.png',full_page=True)
 before_calls=len(captured['cde_calls']); before_uploads=len(captured['storage_uploads'])
 await form.locator('#upload-submit').click()
 await wait_until(lambda: any(x[0]=='begin_document_upload_v2' for x in captured['cde_calls'][before_calls:]),label='point5 v2 upload reservation')
 await wait_until(lambda: len(captured['storage_uploads'])>before_uploads,label='point5 storage upload')
 await page.wait_for_timeout(350)
 assert any(x[0]=='finalize_document_upload' for x in captured['cde_calls']), 'Point 5 upload did not finalize'

 # Current document exposes actual open/download only because storage_path is present.
 await page.locator(f'[data-action="open-folder"][data-id="{FOLDER}"]').first.click(); await page.locator('.cde-document-card').wait_for(state='visible',timeout=5000)
 card=page.locator(f'.cde-document-card:has([data-action="open-document"][data-id="{DOC}"])').first
 assert await card.locator('[data-action="preview-version"]').count()==1 and await card.locator('[data-action="download-version"]').count()==1
 await card.locator(f'[data-action="open-document"][data-id="{DOC}"]').first.click(); await page.locator('.document-version-history').wait_for(state='visible',timeout=4000)
 assert await page.locator('.version-row').count()==2 and await page.locator('.version-history-guide').count()==1
 assert await page.locator('.document-primary-actions [data-action="preview-version"]').count()==1
 assert await page.locator('.document-primary-actions [data-action="download-version"]').count()==1
 assert await page.locator('.document-facts').count()==1
 await page.screenshot(path='/mnt/data/optimum-point5-document360-desktop.png',full_page=True)

 # Compare two historical versions using secure storage identities.
 await page.locator('[data-action="compare-versions"]').click(); await page.locator('.cde-version-compare').wait_for(state='visible',timeout=4000)
 assert await page.locator('.cde-version-compare>section').count()==2
 await page.screenshot(path='/mnt/data/optimum-point5-version-compare-desktop.png',full_page=True)
 await page.locator('[data-action="close-overlay"]').first.click(); await page.wait_for_timeout(180)

 # Re-open and restore old version as a NEW version; never rewrites history.
 await page.locator(f'[data-action="open-document"][data-id="{DOC}"]').first.click(); await page.locator('.document-version-history').wait_for(state='visible',timeout=3000)
 old_restore=page.locator('.version-row:has(.version-number:text("v1")) [data-action="restore-version"]')
 assert await old_restore.count()==1
 restore_before=len(captured['cde_calls']); await old_restore.click()
 await wait_until(lambda: any(x[0]=='begin_new_version_upload_v2' and x[1].get('p_restored_from_version_id') for x in captured['cde_calls'][restore_before:]),label='restore as new version')
 await wait_until(lambda: len(captured['storage_uploads'])>=2,label='restored bytes upload')

 # Metadata editor is live and writes through its RPC.
 await page.locator('[data-action="edit-document-metadata"]').first.click(); meta=page.locator('form[data-form="document-metadata"]'); await meta.wait_for(state='visible',timeout=3000)
 await meta.locator('input[name="issuer"]').fill('Updated Consultant')
 meta_before=len(captured['cde_calls']); await meta.locator('button[type="submit"]').click()
 await wait_until(lambda: any(x[0]=='update_document_metadata' for x in captured['cde_calls'][meta_before:]),label='document metadata update')
 await page.wait_for_timeout(250)
 metrics=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})'); assert metrics['scroll']<=metrics['inner']+3, f'Point 5 Document 360 desktop overflow: {metrics}'
 await page.close()

 # Mobile: novice guidance, browse, version history and controls stay usable at 390px.
 page=await browser.new_page(viewport={'width':390,'height':844})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route); await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.project-portfolio-toolbar').wait_for(state='visible',timeout=15000); await page.locator('.pdc-project-card [data-action="open-project-files"]').first.click(); await page.locator('.cde-workspace').wait_for(state='visible',timeout=6000)
 assert await page.locator('.cde-onboarding').is_visible() and await page.locator('.cde-folder-browser-summary').is_visible()
 metrics=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})'); assert metrics['scroll']<=metrics['inner']+3, f'Point 5 mobile home overflow: {metrics}'
 await page.locator(f'[data-action="open-folder"][data-id="{FOLDER}"]').first.click(); await page.locator('.cde-document-card').wait_for(state='visible',timeout=4000); await page.locator(f'[data-action="open-document"][data-id="{DOC}"]').first.click(); await page.locator('.document-version-history').wait_for(state='visible',timeout=4000)
 assert await page.locator('.version-row').count()==2
 metrics=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})'); assert metrics['scroll']<=metrics['inner']+3, f'Point 5 mobile document overflow: {metrics}'
 await page.screenshot(path='/mnt/data/optimum-point5-document360-mobile.png',full_page=True)
 await page.locator('[data-action="close-overlay"]').first.click(); await page.evaluate("location.hash='#/trash'"); await page.locator('.trash-control').wait_for(state='visible',timeout=5000)
 assert await page.locator('.recovery-overview-strip>article').count()==4
 metrics=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})'); assert metrics['scroll']<=metrics['inner']+3, f'Point 5 mobile recovery overflow: {metrics}'
 await page.close()


async def premium69_work_os_flow(browser):
 # Desktop: calm daily cockpit + compact work controls.
 page=await browser.new_page(viewport={'width':1500,'height':1000})
 await initialize(page,'client','owner')
 await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/tasks"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.workos-cockpit').wait_for(state='visible',timeout=8000)
 assert await page.locator('.workos-today-header').count()==1
 assert await page.locator('.workos-attention-strip .workos-signal').count()==6
 metrics=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})'); assert metrics['scroll']<=metrics['inner']+3, f'Premium Work cockpit overflow: {metrics}'
 await page.screenshot(path='/mnt/data/optimum691-feature4-work-cockpit-desktop-proof.png',full_page=True)
 await page.locator('[data-action="workos-workspace-view"][data-view="tasks"]').first.click()
 await page.locator('.workos-action-kpis').wait_for(state='visible',timeout=4000)
 assert await page.locator('.workos-action-kpis .workos-kpi').count()==4
 assert await page.locator('.workos-more-filters').count()==1
 assert await page.locator('.workos-task-card .workos-task-main>p').count()==0
 assert await page.locator('.workos-task-context').count()>=1
 metrics=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})'); assert metrics['scroll']<=metrics['inner']+3, f'Premium Work tasks overflow: {metrics}'
 await page.screenshot(path='/mnt/data/optimum691-feature4-work-tasks-desktop-proof.png',full_page=True)
 # Setup keeps power but presents automations as readable WHEN / IF / THEN.
 await page.locator('[data-action="workos-admin"]').click(); await page.locator('[data-action="workos-admin-tab"][data-tab="automation"]').click(); await page.locator('[data-action="workos-new-automation"]').click()
 await page.locator('form[data-form="workos-automation"]').wait_for(state='visible',timeout=4000)
 assert await page.locator('.automation-builder-block').count()==3
 assert await page.locator('.automation-builder-block .eyebrow').all_inner_texts()==['WHEN','IF','THEN']
 await page.locator('[data-action="close-overlay"]').first.click(); await page.close()
 # Activity is readable-first, with technical audit as an explicit mode.
 page=await browser.new_page(viewport={'width':1500,'height':1000})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route)
 activity_html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/activity"</script>',1)
 await page.set_content(activity_html,wait_until='domcontentloaded'); await page.locator('.workos-activity-toolbar').wait_for(state='visible',timeout=8000)
 assert await page.locator('.workos-activity-mode [data-action="workos-activity-mode"]').count()==2
 assert await page.locator('.workos-activity-list.feed-mode').count()==1
 await page.locator('[data-action="workos-activity-mode"][data-mode="audit"]').click(); assert await page.locator('.workos-activity-list.audit-mode').count()==1
 metrics=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})'); assert metrics['scroll']<=metrics['inner']+3, f'Premium Work activity overflow: {metrics}'
 await page.screenshot(path='/mnt/data/optimum691-feature4-activity-desktop-proof.png',full_page=True); print('FV2 desktop done',flush=True)
 await page.close()
 # Mobile: daily cockpit and task workspace remain contained at 390px.
 page=await browser.new_page(viewport={'width':390,'height':844})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route); await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.workos-cockpit').wait_for(state='visible',timeout=8000)
 metrics=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})'); assert metrics['scroll']<=metrics['inner']+3, f'Premium Work mobile cockpit overflow: {metrics}'
 assert await page.locator('.workos-attention-strip .workos-signal').count()==6
 await page.locator('[data-action="workos-workspace-view"][data-view="tasks"]').first.click(); await page.locator('.workos-action-kpis').wait_for(state='visible',timeout=4000)
 assert await page.locator('.workos-action-kpis .workos-kpi').count()==4
 metrics=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})'); assert metrics['scroll']<=metrics['inner']+3, f'Premium Work mobile tasks overflow: {metrics}'
 await page.screenshot(path='/mnt/data/optimum691-feature4-work-mobile-proof.png',full_page=True); await page.close()

async def premium69_organization_access_flow(browser):
 captured['disabled_entitlements']=set(); captured['point2_custom_access']=True
 # Desktop Team: people-first directory, custom access, Member 360 and contextual bulk actions.
 page=await browser.new_page(viewport={'width':1500,'height':1000})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/team"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded'); await page.locator('.team-directory-shell').wait_for(state='visible',timeout=8000)
 assert await page.locator('.team-overview-strip').count()==0
 assert await page.locator('.team-person-row').count()==2
 assert await page.locator('.team-more-filters').count()==1
 assert await page.locator('.org-attention-queue').count()>=1
 assert await page.locator('.custom-access-chip').count()>=1
 await page.locator(f'[data-action="orgos-member360"][data-id="{MEMBERSHIP2}"]').first.evaluate("el=>el.click()"); await page.locator('.member360-v2').wait_for(state='visible',timeout=5000)
 assert await page.locator('.member360-tabs button').count()==4
 assert await page.locator('.member360-overview-grid .member360-section').count()==2
 overview_scroll=await page.locator('.member360-dialog .dialog-body').evaluate("el=>({overflow:getComputedStyle(el).overflowY,scrollHeight:el.scrollHeight,clientHeight:el.clientHeight})")
 assert overview_scroll['overflow'] in ('auto','scroll'), f'Member 360 dialog is not scroll-enabled: {overview_scroll}'
 await page.screenshot(path='/mnt/data/optimum-point2-member360-overview-r5.png',full_page=True)
 await page.locator('[data-action="orgos-member-tab"][data-tab="access"]').click(); await page.locator('[data-member360-panel="access"].active .member360-access-state').wait_for(state='visible',timeout=3000); await page.wait_for_timeout(260)
 access_box=await page.locator('[data-member360-panel="access"].active').bounding_box(); assert access_box and access_box['height']>=120, f'Member 360 access panel collapsed: {access_box}'
 await page.screenshot(path='/mnt/data/optimum-point2-team-member360-desktop.png',full_page=True)
 await page.locator('[data-action="close-overlay"]').first.click(); await page.wait_for_timeout(220)
 assert await page.locator('.owner-protection-chip').count()>=1
 owner_row=page.locator(f'[data-team-member]:has([data-action="orgos-member360"][data-id="{MEMBERSHIP}"])'); assert await owner_row.locator('[data-action="access55-member"]').count()==0
 await page.locator(f'[data-action="orgos-member-access"][data-id="{MEMBERSHIP2}"]').evaluate("el=>el.click()"); await page.locator('[data-member360-panel="access"].active .member360-access-state').wait_for(state='visible',timeout=4000); await page.locator('[data-action="close-overlay"]').first.evaluate("el=>el.click()"); await page.wait_for_timeout(220)
 # Member overflow menu is portalled, fully visible, and closes by clicking outside.
 menu_trigger=page.locator(f'[data-team-member]:has([data-action="orgos-member360"][data-id="{MEMBERSHIP2}"]) .team-person-menu-trigger')
 await menu_trigger.click(); await page.locator('.team-member-menu-pop').wait_for(state='visible',timeout=2000)
 menu_box=await page.locator('.team-member-menu-pop').bounding_box(); assert menu_box and menu_box['x']>=6 and menu_box['y']>=6 and menu_box['x']+menu_box['width']<=1494 and menu_box['y']+menu_box['height']<=994, f'Member menu clipped: {menu_box}'
 await page.locator('.page-header h2').click(position={'x':5,'y':5}); await page.wait_for_timeout(100); assert await page.locator('.team-member-menu-pop').count()==0
 # More filters include organization unit + access model and dismiss when clicking outside; bulk appears only after selection.
 await page.locator('.team-more-filters>summary').click(); assert await page.locator('#team-unit-filter').count()==1 and await page.locator('#team-access-filter').count()==1
 assert await page.locator('.team-more-filters[open]').count()==1
 await page.locator('.page-header h2').click(position={'x':5,'y':5}); await page.wait_for_timeout(100); assert await page.locator('.team-more-filters[open]').count()==0
 assert await page.locator('.orgos-bulk-bar.active').count()==0
 cb=page.locator(f'[data-orgos-member-select][value="{MEMBERSHIP2}"]'); await cb.check(); await page.locator('.orgos-bulk-bar.active').wait_for(state='visible',timeout=3000)
 await page.screenshot(path='/mnt/data/optimum-point2-team-desktop.png',full_page=True)
 # Organization: structure first + Unit 360, not readiness KPIs.
 await page.locator('[data-nav="organization"]').click(); await page.locator('.orgos-chart').wait_for(state='visible',timeout=5000)
 assert await page.locator('.orgos-readiness').count()==0 and await page.locator('.orgos-kpis').count()==0
 await page.locator('.orgos-unit-card').first.click(); await page.locator('.unit360-v2').wait_for(state='visible',timeout=4000); await page.wait_for_timeout(280)
 assert await page.locator('.unit360-projects').count()==1; assert await page.locator('.unit360-projects [data-action="open-project"]').count()>=1
 await page.screenshot(path='/mnt/data/optimum-point2-unit360-desktop.png',full_page=True); await page.locator('[data-action="close-overlay"]').first.click()
 # Roles: capability-first and live impact preview.
 await page.locator('[data-nav="roles"]').click(); await page.locator('.role-capability-list').wait_for(state='visible',timeout=5000)
 assert await page.locator('.role-overview-strip').count()==0
 assert await page.locator('.role-capability-card').count()==3
 assert await page.locator('.role-capability').count()>=6
 editable=page.locator('.role-capability-card [data-action="edit-role"]').first; await editable.click(); await page.locator('[data-role-impact]').wait_for(state='visible',timeout=4000); await page.wait_for_timeout(220)
 assert await page.locator('[data-role-impact]').count()==1
 role_scroll=await page.locator('.role-draft-dialog .dialog-body').evaluate("el=>{const overflow=getComputedStyle(el).overflowY;el.scrollTop=el.scrollHeight;const maxScroll=el.scrollTop;el.scrollTop=0;return {overflow,maxScroll,scrollHeight:el.scrollHeight,clientHeight:el.clientHeight}}")
 assert role_scroll['overflow'] in ('auto','scroll') and role_scroll['maxScroll']>0, f'Role draft must scroll: {role_scroll}'
 role_form=page.locator('form[data-form="access55-role-draft"]'); checked_perm=role_form.locator('input[name="permission"]:checked').first; await checked_perm.evaluate("el=>{el.checked=false;el.dispatchEvent(new Event('change',{bubbles:true}))}"); await page.wait_for_timeout(120); assert await page.locator('[data-role-impact].warning').count()==1; impact_text=await page.locator('[data-role-impact]').inner_text(); assert ('إزالة' in impact_text or 'removed' in impact_text.lower())
 await page.screenshot(path='/mnt/data/optimum-point2-role-impact-desktop.png',full_page=True); await page.locator('[data-action="close-overlay"]').first.click()
 # Settings: Personal and Organization remain distinct, configuration only.
 await page.locator('[data-nav="settings"]').click(); await page.locator('.settings-command-center').wait_for(state='visible',timeout=5000)
 assert await page.locator('.settings-nav-group').count()>=2
 assert await page.locator('.settings-insight-grid').count()==0 and await page.locator('.settings-home-health').count()==0
 await page.screenshot(path='/mnt/data/optimum-point2-settings-desktop.png',full_page=True)
 # Profile image is presented in full rather than center-cropped.
 await page.locator('[data-action="settings-tab"][data-tab="profile"]').first.click(); await page.locator('.profile-premium-form').wait_for(state='visible',timeout=4000)
 if await page.locator('img.profile-photo-large').count():
  fit=await page.locator('img.profile-photo-large').evaluate("el=>getComputedStyle(el).objectFit"); assert fit=='contain', f'Profile image should be fully visible, got object-fit={fit}'
 # Security settings: human-readable governance, protection context and existing second-approval backend path.
 await page.locator('[data-action="settings-tab"][data-tab="access"]').first.click(); await page.locator('.access-governance-heading').wait_for(state='visible',timeout=4000)
 assert await page.locator('.access-protection-chip').count()==1
 assert await page.locator('form[data-form="access55-governance"] .governance-toggle').count()>=2
 security_text=(await page.locator('form[data-form="access55-governance"]').inner_text()).lower(); assert ('موافقة ثانية' in security_text or 'second approval' in security_text)
 await page.screenshot(path='/mnt/data/optimum-point2-security-settings-desktop.png',full_page=True)
 # Branding: live preview must react before save; the organization-wide scope is explicit.
 await page.locator('[data-action="settings-tab"][data-tab="branding"]').first.click(); await page.locator('.branding-workbench').wait_for(state='visible',timeout=4000)
 assert await page.locator('.brand-live-preview').count()==1
 brand_form=page.locator('form[data-form="company-branding"]'); name_input=brand_form.locator('input[name="app_name"]'); await name_input.fill('Optimum Preview QA'); await name_input.dispatch_event('input'); await page.wait_for_timeout(100)
 assert 'Optimum Preview QA' in await page.locator('.brand-live-preview').inner_text()
 primary=brand_form.locator('input[name="primary_color"]'); await primary.evaluate("el=>{el.value='#3157d5';el.dispatchEvent(new Event('input',{bubbles:true}));el.dispatchEvent(new Event('change',{bubbles:true}))}"); await page.wait_for_timeout(100)
 preview_primary=await page.locator('.brand-live-preview').evaluate("el=>getComputedStyle(el).getPropertyValue('--preview-primary').trim()"); assert preview_primary.lower()=='#3157d5', f'Brand preview color did not update: {preview_primary}'
 assert await brand_form.locator('.settings-save-dock button[type="submit"]:not([disabled])').count()==1
 await page.screenshot(path='/mnt/data/optimum-point2-branding-desktop.png',full_page=True)
 metrics=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})'); assert metrics['scroll']<=metrics['inner']+3, f'Point 2 desktop overflow: {metrics}'
 await page.close()

 # Mobile: Team, Member 360, Roles and Settings fit 390px with intentional composition.
 for route,ready in [('team','.team-directory-shell'),('organization','.orgos-chart'),('roles','.role-capability-list'),('settings','.settings-command-center')]:
  page=await browser.new_page(viewport={'width':390,'height':844}); await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route)
  route_html=(ROOT/'index.html').read_text().replace('<head>',f'<head><base href="https://client.test/"><script>location.hash="#/{route}"</script>',1)
  await page.set_content(route_html,wait_until='domcontentloaded'); await page.locator(ready).wait_for(state='visible',timeout=8000); await page.wait_for_timeout(220)
  metrics=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})'); assert metrics['scroll']<=metrics['inner']+3, f'Point 2 mobile overflow on {route}: {metrics}'
  if route=='team':
   await page.locator(f'[data-action="orgos-member360"][data-id="{MEMBERSHIP2}"]').first.evaluate("el=>el.click()"); await page.locator('.member360-v2').wait_for(state='visible',timeout=4000); await page.wait_for_timeout(220)
   box=await page.locator('.member360-dialog').last.bounding_box(); assert box and box['x']>=6 and box['x']+box['width']<=384
   mobile_scroll=await page.locator('.member360-dialog .dialog-body').evaluate("el=>{el.scrollTop=el.scrollHeight;const maxScroll=el.scrollTop;el.scrollTop=0;return {overflow:getComputedStyle(el).overflowY,maxScroll,scrollHeight:el.scrollHeight,clientHeight:el.clientHeight}}")
   assert mobile_scroll['overflow'] in ('auto','scroll') and mobile_scroll['maxScroll']>0, f'Member 360 mobile must scroll: {mobile_scroll}'
   await page.screenshot(path='/mnt/data/optimum-point2-member360-mobile.png',full_page=True)
  elif route=='roles': await page.screenshot(path='/mnt/data/optimum-point2-roles-mobile.png',full_page=True)
  elif route=='organization': await page.screenshot(path='/mnt/data/optimum-point2-organization-mobile.png',full_page=True)
  elif route=='settings': await page.screenshot(path='/mnt/data/optimum-point2-settings-mobile.png',full_page=True)
  await page.close()
 captured['point2_custom_access']=False

async def point11_project_control_flow(browser):
 captured['actor']='owner'; captured['p11_calls']=[]; captured['p11_brief_created']=False; captured['p11_brief_status']=None; captured['p11_report_linked']=False; captured['p11_reviewer_note']=None; captured['cde_calls'].clear(); captured['storage_uploads'].clear()
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/control"</script>',1)
 page=await browser.new_page(viewport={'width':1536,'height':960})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route); await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.pc-control-room').wait_for(state='visible',timeout=10000); print('P11 loaded control',flush=True)
 assert await page.locator('.pc-project-row').count()==3
 assert await page.locator('.pc-project-row.critical').count()==1
 assert await page.locator('.pc-project-row.watch').count()==1
 assert await page.locator('.pc-project-row.stable').count()==1
 assert await page.locator('.pc-decision-center .pc-decision-row').count()==3
 assert await page.locator('.pc-health-ring').count()>=3
 overflow=await page.evaluate('({doc:document.documentElement.scrollWidth,body:document.body.scrollWidth,inner:window.innerWidth})'); assert overflow['doc']<=1539 and overflow['body']<=1539,overflow
 await page.screenshot(path='/mnt/data/optimum-point11-control-desktop.png',full_page=True); print('P11 desktop shot',flush=True)
 # Drill into the critical project and inspect explainable health/progress/risk sources.
 await page.locator('.pc-project-row.critical [data-action="pc-open-project"]').click()
 await page.locator('.premium-drawer .pc-detail').wait_for(state='visible',timeout=7000); await page.wait_for_timeout(250); print('P11 detail open',flush=True)
 assert await page.locator('.premium-drawer .pc-progress-band').count()==1
 assert await page.locator('.premium-drawer .pc-driver-grid article').count()>=2
 assert await page.locator('.premium-drawer .pc-site-table button').count()==2
 assert await page.locator('.premium-drawer .pc-milestone-list article').count()==2
 assert await page.locator('.premium-drawer .pc-risk-list button').count()>=2
 await page.screenshot(path='/mnt/data/optimum-point11-project-detail.png',full_page=True)
 # Weekly brief: save V1 in CDE, submit as V2, then exercise management review.
 await page.locator('.premium-drawer [data-action="pc-weekly-brief"]').click()
 await page.locator('.premium-drawer .pc-brief').wait_for(state='visible',timeout=7000); print('P11 brief open',flush=True)
 await page.locator('textarea[name="executive_summary"]').fill('خطة الاسترداد واضحة لكن Site A يحتاج تدخل الإدارة.')
 await page.locator('textarea[name="decisions_needed"]').fill('اعتماد تصعيد المواد وخطة استرداد Site A.')
 await page.locator('textarea[name="next_week_plan"]').fill('إغلاق مشكلة CAB-01 واسترداد معلم التسليم.')
 # Draft save creates the canonical CDE brief document (V1).
 create_calls=len(captured['cde_calls']); create_uploads=len(captured['storage_uploads'])
 await page.locator('[data-action="pc-brief-save"]').click(); print('P11 draft save clicked',flush=True)
 await wait_until(lambda:any(x[0]=='save_project_control_brief' and not x[1].get('p_submit') for x in captured['p11_calls']),label='point11 brief draft save')
 await wait_until(lambda:any(x[0]=='begin_document_upload_v2' and 'project-control-brief' in (x[1].get('p_tags') or []) for x in captured['cde_calls'][create_calls:]),label='point11 brief CDE V1 reservation')
 await wait_until(lambda:len(captured['storage_uploads'])>create_uploads,label='point11 brief V1 binary upload')
 assert captured.get('p11_report_linked') is True; print('P11 CDE V1 linked',flush=True)
 # Submit is a second save and must create a NEW VERSION of the same canonical CDE document.
 version_calls=len(captured['cde_calls']); version_uploads=len(captured['storage_uploads'])
 await page.locator('.premium-drawer [data-action="pc-brief-submit"]').wait_for(state='visible',timeout=5000)
 await page.locator('.premium-drawer [data-action="pc-brief-submit"]').click(); print('P11 submit clicked',flush=True)
 await wait_until(lambda:any(x[0]=='save_project_control_brief' and x[1].get('p_submit') for x in captured['p11_calls']),label='point11 brief submit')
 await wait_until(lambda:any(x[0]=='begin_new_version_upload_v2' and x[1].get('p_document_id')==P11_REPORT_DOC for x in captured['cde_calls'][version_calls:]),label='point11 brief CDE V2 reservation')
 await wait_until(lambda:len(captured['storage_uploads'])>version_uploads,label='point11 brief V2 binary upload')
 assert captured.get('p11_report_linked') is True; print('P11 CDE V2 linked',flush=True)
 await page.locator('.premium-drawer [data-action="pc-brief-approve"]').wait_for(state='visible',timeout=5000)
 await page.screenshot(path='/mnt/data/optimum-point11-weekly-brief.png',full_page=True)
 # First reviewer path: Return with a required note.
 await page.locator('.premium-drawer [data-action="pc-brief-return"]').click(); await page.locator('[data-form="pc-brief-return"]').wait_for(state='visible',timeout=3000)
 await page.locator('[data-form="pc-brief-return"] textarea[name="note"]').fill('وضح خطة استرداد المعلم بالأيام والمسؤول.')
 await page.locator('[data-form="pc-brief-return"] button[type="submit"]').click(); print('P11 return submitted',flush=True)
 await wait_until(lambda:captured.get('p11_brief_status')=='returned' and captured.get('p11_reviewer_note'),label='point11 brief returned'); print('P11 returned',flush=True)
 # Returned brief becomes editable; resubmission versions the same CDE report again (V3).
 await page.locator('.premium-drawer .pc-brief-form').wait_for(state='visible',timeout=5000)
 await page.locator('textarea[name="executive_summary"]').fill('خطة الاسترداد محددة بالأيام والمسؤول وتم تحديثها بعد ملاحظة الإدارة.')
 resubmit_calls=len(captured['cde_calls']); resubmit_uploads=len(captured['storage_uploads'])
 await page.locator('.premium-drawer [data-action="pc-brief-submit"]').click(); print('P11 resubmit clicked',flush=True)
 await wait_until(lambda:sum(1 for x in captured['p11_calls'] if x[0]=='save_project_control_brief' and x[1].get('p_submit'))>=2,label='point11 brief resubmit')
 await wait_until(lambda:any(x[0]=='begin_new_version_upload_v2' and x[1].get('p_document_id')==P11_REPORT_DOC for x in captured['cde_calls'][resubmit_calls:]),label='point11 brief CDE V3 reservation')
 await wait_until(lambda:len(captured['storage_uploads'])>resubmit_uploads,label='point11 brief V3 binary upload')
 await page.locator('.premium-drawer [data-action="pc-brief-approve"]').wait_for(state='visible',timeout=5000)
 await page.locator('.premium-drawer [data-action="pc-brief-approve"]').click(); print('P11 approve clicked',flush=True)
 await wait_until(lambda:captured.get('p11_brief_status')=='approved',label='point11 brief approved'); print('P11 approved',flush=True)
 # English is a full rerender, not mixed Arabic/English. Close the brief drawer cleanly first.
 close_btn=page.locator('.premium-drawer [data-action="close-overlay"]')
 if await close_btn.count():
  await close_btn.click(); await page.locator('.premium-drawer').wait_for(state='detached',timeout=2000)
 print('P11 drawer closed for locale',flush=True)
 await page.locator('[data-action="utility-menu"]').click(); await page.locator('.utility-menu-pop [data-action="toggle-locale"]').click(); await page.wait_for_timeout(220)
 assert await page.locator('html').get_attribute('dir')=='ltr'; print('P11 english switched',flush=True)
 assert await page.get_by_text('Management clarity in one minute').count()>=1
 await page.screenshot(path='/mnt/data/optimum-point11-control-english.png',full_page=True)
 await page.close()
 # Mobile portfolio remains readable and contained.
 mobile=await browser.new_page(viewport={'width':390,'height':844})
 await initialize(mobile,'client','owner'); await mobile.route('https://client.test/**',local_route); await mobile.set_content(html,wait_until='domcontentloaded')
 await mobile.locator('.pc-control-room').wait_for(state='visible',timeout=10000); await mobile.wait_for_timeout(200); print('P11 mobile loaded',flush=True)
 mo=await mobile.evaluate('({doc:document.documentElement.scrollWidth,body:document.body.scrollWidth,inner:window.innerWidth})'); assert mo['doc']<=393 and mo['body']<=393,mo
 assert await mobile.locator('.pc-project-row').count()==3
 await mobile.screenshot(path='/mnt/data/optimum-point11-control-mobile.png',full_page=True)
 await mobile.close()
 print('POINT11 Project Control desktop/brief/review/English/mobile done',flush=True)

async def premium69_global_actions_flow(browser):
 enable_global_action_contracts(); captured['disabled_entitlements']=set()
 # Desktop: one calm global action layer, grouped search, keyboard navigation and attention inbox.
 page=await browser.new_page(viewport={'width':1500,'height':1000})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route)
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/dashboard"</script>',1)
 await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.command-trigger').wait_for(state='visible',timeout=8000)
 assert await page.locator('.notification-button').count()==1
 assert await page.locator('.notification-count').inner_text()=='2'
 await page.locator('.command-trigger').click(); await page.locator('.global-command-shell[data-command-state="default"]').wait_for(state='visible',timeout=4000)
 assert await page.locator('.command-default-section').count()>=2
 assert await page.locator('.quick-create-section').count()>=3
 assert await page.locator('#command-results [data-action="new-task"]').count()==1
 assert await page.locator('#command-results [data-action="new-project"]').count()==1
 assert await page.locator('#command-results [data-action="invite-member"]').count()==1
 await page.locator('#command-search').fill('Alpha')
 await page.locator('.global-command-shell[data-command-state="results"]').wait_for(state='visible',timeout=6000)
 assert await page.locator('.command-create-section').count()==0, 'active search must not repeat create actions above results'
 assert await page.locator('.command-result-section[data-result-type="project"]').count()==1
 assert await page.locator('.command-result-section[data-result-type="site"]').count()==1
 assert await page.locator('.command-result-section[data-result-type="document"]').count()==1
 assert await page.locator('.command-result-section[data-result-type="task"]').count()==1
 await page.locator('#command-search').press('ArrowDown')
 assert await page.locator('#command-results button.keyboard-active').count()==1
 await page.screenshot(path='/mnt/data/optimum691-feature7-global-command-desktop-proof.png',full_page=True)
 await page.locator('#command-search').press('Enter')
 await page.locator('.project360-context').wait_for(state='visible',timeout=7000)
 await page.locator('[data-action="close-entity-workspace"]').first.click()
 # Strict Quick Create remains permission-aware and contains creation actions, not navigation/setup noise.
 await page.locator('.quick-create-trigger').click(); await page.locator('.quick-create-panel').wait_for(state='visible',timeout=4000)
 assert await page.locator('.quick-create-panel .quick-create-section').count()>=3
 assert await page.locator('.quick-create-panel [data-action="workos-go-calendar"]').count()==0
 assert await page.locator('.quick-create-panel [data-action="orgos-go"]').count()==0
 await page.locator('[data-action="close-overlay"]').first.click()
 # Attention Inbox: actionable unread, informational unread, then earlier/read.
 await page.locator('.notification-button').click(); await page.locator('.notification-inbox').wait_for(state='visible',timeout=4000)
 assert await page.locator('.notification-group.tone-attention .notification-item-premium').count()==1
 assert await page.locator('.notification-group.tone-updates .notification-item-premium').count()==1
 assert await page.locator('.notification-group.tone-earlier .notification-item-premium').count()==1
 await page.screenshot(path='/mnt/data/optimum691-feature7-attention-inbox-desktop-proof.png',full_page=True)
 await page.locator('.notification-group.tone-attention [data-action="open-notification"]').click()
 await page.locator('.project360-context').wait_for(state='visible',timeout=7000)
 await page.locator('[data-action="close-entity-workspace"]').first.click()
 desktop=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})'); assert desktop['scroll']<=desktop['inner']+3, f'Premium global desktop overflow: {desktop}'
 await page.close()
 # Mobile: the command layer is the single primary action surface and never exceeds 390px.
 page=await browser.new_page(viewport={'width':390,'height':844})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route); await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.command-trigger').wait_for(state='visible',timeout=8000)
 assert await page.locator('.quick-create-trigger:visible').count()==0, 'mobile should use the command layer instead of a duplicate quick-create trigger'
 await page.locator('.command-trigger').click(); dialog=page.locator('.global-command-dialog'); await dialog.wait_for(state='visible',timeout=4000); await page.wait_for_timeout(180)
 box=await dialog.bounding_box(); assert box and box['width']<=390 and box['x']>=6 and box['x']+box['width']<=384
 metrics=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})'); assert metrics['scroll']<=metrics['inner']+3, f'Premium global mobile command overflow: {metrics}'
 await page.locator('#command-search').fill('Alpha'); await page.locator('.global-command-shell[data-command-state="results"]').wait_for(state='visible',timeout=6000)
 metrics=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})'); assert metrics['scroll']<=metrics['inner']+3, f'Premium global mobile results overflow: {metrics}'
 await page.screenshot(path='/mnt/data/optimum691-feature7-global-command-mobile-proof.png',full_page=True)
 await page.locator('[data-action="close-overlay"]').first.click(); await page.locator('.notification-button').click(); drawer=page.locator('.drawer').last; await drawer.wait_for(state='visible',timeout=4000); await page.wait_for_timeout(220)
 box=await drawer.bounding_box(); assert box and box['width']<=392 and box['x']>=-2 and box['x']+box['width']<=392
 assert await page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 3')
 await page.screenshot(path='/mnt/data/optimum691-feature7-attention-inbox-mobile-proof.png',full_page=True)
 await page.close()

async def premium69_dashboard_flow(browser):
 enable_dashboard_contracts(); captured['disabled_entitlements']=set()
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/dashboard"</script>',1)
 # Owner desktop: decision cockpit, deep links, and no legacy dashboard clutter.
 page=await browser.new_page(viewport={'width':1500,'height':1000})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route); await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.dashboard-cockpit').wait_for(state='visible',timeout=9000)
 assert await page.locator('.welcome-banner').count()==0
 assert await page.locator('.dashboard-cockpit .stat-card').count()==0
 assert await page.locator('.dashboard-cockpit .quick-actions').count()==0
 assert await page.locator('.dashboard-cockpit .storage-ring').count()==0
 assert await page.locator('.dashboard-cockpit .policy-runtime-strip').count()==0
 decision_count=await page.locator('.dashboard-decision-signal').count(); assert 1<=decision_count<=3, f'R2 management decisions should be compact, got {decision_count}'
 assert await page.locator('.dashboard-decision-label').count()==1
 assert await page.locator('.dashboard-focus-row').count()>=1
 assert await page.locator('.home-control-project').count()>=2
 assert await page.locator('.home-changes').count()==1
 assert await page.locator('.dashboard-attention-preview').count()==1
 assert await page.locator('.dashboard-workspace-health').count()==1
 assert await page.locator('.dashboard-activity-preview').count()==0
 assert await page.locator('.dashboard-focus-row').count()>=1, 'operational urgency must stay in Focus Queue instead of duplicating management decisions'
 await page.screenshot(path='/mnt/data/optimum691-feature8-dashboard-desktop-proof.png',full_page=True)
 # Focus queue opens Work Item 360.
 await page.locator('.dashboard-focus-row').first.click()
 await page.locator('.workos-detail.work360').wait_for(state='visible',timeout=7000)
 await page.locator('[data-action="close-overlay"]').first.click()
 # Management pulse opens the canonical project-control drill-down; Project 360 remains one click away inside it.
 await page.locator('.home-control-project').first.click()
 await page.locator('.pc-detail').wait_for(state='visible',timeout=7000)
 assert await page.locator('.pc-detail [data-action="pc-open-entity"][data-type="project"]').count()==1
 await page.locator('[data-action="close-overlay"]').first.click()
 # Attention preview uses the existing notification/entity navigation contract.
 await page.locator('.dashboard-notification-row').first.click()
 await page.locator('.project360-context').wait_for(state='visible',timeout=7000)
 await page.locator('[data-action="close-entity-workspace"]').first.click()
 desktop=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})')
 assert desktop['scroll']<=desktop['inner']+3, f'Premium dashboard desktop overflow: {desktop}'
 await page.close()
 # Limited actor: only sections backed by effective permissions are visible; no admin/notification/audit rail leaks.
 page=await browser.new_page(viewport={'width':1280,'height':900})
 await initialize(page,'client','engineer'); await page.route('https://client.test/**',local_route); await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.dashboard-cockpit').wait_for(state='visible',timeout=9000)
 assert await page.locator('.dashboard-focus-row').count()>=1
 assert await page.locator('.dashboard-project-row').count()>=1
 assert await page.locator('.dashboard-attention-preview').count()==0, 'limited actor must not see notifications without notifications.view'
 assert await page.locator('.dashboard-workspace-health').count()==0, 'limited actor must not see admin capacity controls'
 assert await page.locator('.dashboard-activity-preview').count()==0, 'limited actor must not see audit preview without audit.view'
 assert await page.locator('.home-changes').count()<=1, 'permission-filtered personal changes may remain visible'
 limited=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth})')
 assert limited['scroll']<=limited['inner']+3, f'Premium dashboard limited overflow: {limited}'
 await page.close()
 # Mobile owner: all dashboard surfaces stack inside 390px and remain actionable.
 page=await browser.new_page(viewport={'width':390,'height':844})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route); await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.dashboard-cockpit').wait_for(state='visible',timeout=9000); await page.wait_for_timeout(180)
 mobile_decisions=await page.locator('.dashboard-decision-signal').count(); assert 1<=mobile_decisions<=3, f'R2 mobile decisions should stay compact, got {mobile_decisions}'
 metrics=await page.evaluate('({scroll:document.documentElement.scrollWidth,inner:window.innerWidth,body:document.body.scrollWidth})')
 assert metrics['scroll']<=metrics['inner']+3 and metrics['body']<=metrics['inner']+3, f'Premium dashboard mobile overflow: {metrics}'
 first_signal=page.locator('.dashboard-decision-signal').first
 box=await first_signal.bounding_box(); assert box and box['x']>=0 and box['x']+box['width']<=390
 await page.screenshot(path='/mnt/data/optimum691-feature8-dashboard-mobile-proof.png',full_page=True)
 await page.close()

async def premium_foundation_v2_flow(browser):
 enable_dashboard_contracts(); captured['disabled_entitlements']=set()
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/dashboard"</script>',1)
 # Desktop: shell, collapse persistence, utility consolidation, drawer and theme/locale behavior.
 page=await browser.new_page(viewport={'width':1500,'height':1000})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route); await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.dashboard-cockpit').wait_for(state='visible',timeout=9000)
 print('FV2 desktop loaded',flush=True)
 assert await page.locator('.sidebar-collapse-btn').count()==1
 assert await page.locator('.sidebar .nav-group').count()==3
 assert await page.locator('.sidebar .nav-section-label:visible').count()==3
 expanded=await page.locator('.sidebar').bounding_box(); assert expanded and expanded['width']>220
 await page.locator('[data-action="sidebar-collapse"]').click(); await page.wait_for_timeout(260)
 print('FV2 collapsed',flush=True)
 assert await page.locator('.app-shell.sidebar-collapsed').count()==1
 collapsed=await page.locator('.sidebar').bounding_box(); assert collapsed and 70<=collapsed['width']<=82, collapsed
 assert await page.evaluate("localStorage.getItem('optimum.shell.sidebarCollapsed.v2')")=='1'
 assert await page.locator('.sidebar.collapsed .nav-label:visible').count()==0
 await page.screenshot(path='/mnt/data/optimum-foundation-v2-sidebar-collapsed.png',full_page=True)
 await page.locator('[data-action="sidebar-collapse"]').click(); await page.wait_for_timeout(220)
 assert await page.locator('.app-shell.sidebar-collapsed').count()==0
 # Topbar utilities are consolidated into one popover.
 assert await page.locator('.topbar [data-action="help"]').count()==0
 assert await page.locator('.topbar [data-action="toggle-locale"]').count()==0
 assert await page.locator('.topbar [data-action="toggle-theme"]').count()==0
 # Account avatar is personal/workspace UX only; the private Platform Console must never leak into this menu.
 await page.locator('[data-action="account-menu"]').click(); await page.locator('.account-menu-premium').wait_for(state='visible',timeout=3000)
 assert await page.locator('.account-menu-premium').get_by_text('Optimum').count()>=1
 assert await page.locator('.account-menu-premium').get_by_text(re.compile('Platform Console|لوحة المنصة',re.I)).count()==0
 await page.locator('[data-action="account-menu"]').click(); await page.wait_for_timeout(80)
 await page.locator('[data-action="utility-menu"]').click(); await page.locator('.utility-menu-pop').wait_for(state='visible',timeout=3000)
 print('FV2 utility open',flush=True)
 assert await page.locator('.utility-menu-pop .menu-item').count()==4
 old_theme=await page.locator('html').get_attribute('data-theme')
 await page.locator('.utility-menu-pop [data-action="toggle-theme"]').click(); await page.wait_for_timeout(160)
 new_theme=await page.locator('html').get_attribute('data-theme'); assert new_theme!=old_theme
 await page.locator('[data-action="utility-menu"]').click(); await page.locator('.utility-menu-pop [data-action="toggle-theme"]').click(); await page.wait_for_timeout(120)
 old_density=await page.locator('html').get_attribute('data-density')
 await page.locator('[data-action="utility-menu"]').click(); await page.locator('.utility-menu-pop [data-action="toggle-density"]').click(); await page.wait_for_timeout(120)
 new_density=await page.locator('html').get_attribute('data-density'); assert new_density!=old_density
 assert await page.evaluate("JSON.parse(localStorage.getItem('optimum.preferences.v1')||'{}').density") in ['comfortable','compact']
 await page.locator('[data-action="utility-menu"]').click(); await page.locator('.utility-menu-pop [data-action="toggle-density"]').click(); await page.wait_for_timeout(90)
 # Drawer is a floating premium layer and closes with Escape.
 await page.locator('.dashboard-focus-row').first.click(); await page.locator('.premium-drawer').wait_for(state='visible',timeout=7000); await page.wait_for_timeout(280)
 print('FV2 drawer desktop',flush=True)
 assert await page.evaluate("document.querySelector('.premium-drawer')?.contains(document.activeElement)")
 db=await page.locator('.premium-drawer').bounding_box(); assert db and db['width']>=500 and db['x']>=8 and db['x']+db['width']<=1492
 radius=await page.locator('.premium-drawer').evaluate("el=>getComputedStyle(el).borderRadius"); assert float(radius.replace('px',''))>=20
 await page.screenshot(path='/mnt/data/optimum-foundation-v2-drawer-desktop.png',full_page=True)
 await page.keyboard.press('Escape'); await page.wait_for_timeout(25); assert await page.locator('.premium-drawer-wrap.is-closing').count()==1
 await page.wait_for_timeout(260); assert await page.locator('.premium-drawer').count()==0
 # English + light mode are first-class, not a dark-theme afterthought.
 if await page.locator('html').get_attribute('data-theme')!='light':
  await page.locator('[data-action="utility-menu"]').click(); await page.locator('.utility-menu-pop [data-action="toggle-theme"]').click(); await page.wait_for_timeout(170)
 assert await page.locator('html').get_attribute('data-theme')=='light'
 await page.locator('[data-action="utility-menu"]').click(); await page.locator('.utility-menu-pop [data-action="toggle-locale"]').click(); await page.wait_for_timeout(170)
 assert await page.locator('html').get_attribute('dir')=='ltr'
 font=await page.locator('body').evaluate("el=>getComputedStyle(el).fontFamily"); assert 'Inter' in font
 await page.screenshot(path='/mnt/data/optimum-foundation-v2-english-light.png',full_page=True)
 await page.close()

async def premium_foundation_v2_mobile_flow(browser):
 enable_dashboard_contracts(); captured['disabled_entitlements']=set()
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/dashboard"</script>',1)
 page=await browser.new_page(viewport={'width':390,'height':844})
 await initialize(page,'client','owner'); await page.route('https://client.test/**',local_route); await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.dashboard-cockpit').wait_for(state='visible',timeout=9000)
 print('FV2 mobile loaded',flush=True)
 await page.locator('[data-action="mobile-menu"]').click(); await page.wait_for_timeout(260)
 sb=await page.locator('.sidebar.open').bounding_box(); assert sb and 260<=sb['width']<=345 and sb['x']>=0 and sb['x']+sb['width']<=390
 assert await page.locator('.sidebar-scrim').count()==1
 await page.screenshot(path='/mnt/data/optimum-foundation-v2-mobile-nav.png',full_page=True)
 await page.locator('.sidebar-scrim').click(position={'x':12,'y':420}); await page.wait_for_timeout(150)
 await page.locator('.dashboard-focus-row').first.click(); await page.locator('.premium-drawer').wait_for(state='visible',timeout=7000); await page.wait_for_timeout(300)
 db=await page.locator('.premium-drawer').bounding_box(); print('FV2 mobile drawer box',db,flush=True); assert db and db['x']>=7 and db['x']+db['width']<=383 and db['y']>=7 and db['y']+db['height']<=837
 assert await page.locator('.drawer-handle').count()==1
 overflow=await page.evaluate('({doc:document.documentElement.scrollWidth,body:document.body.scrollWidth,inner:window.innerWidth})'); assert overflow['doc']<=393 and overflow['body']<=393, overflow
 await page.screenshot(path='/mnt/data/optimum-foundation-v2-drawer-mobile.png',full_page=True)
 print('FV2 mobile done',flush=True)
 await page.close()

async def premium_foundation_v2_responsive_flow(browser):
 enable_dashboard_contracts(); captured['disabled_entitlements']=set()
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/"><script>location.hash="#/dashboard"</script>',1)
 # Laptop breakpoint keeps the persistent shell without horizontal overflow.
 laptop=await browser.new_page(viewport={'width':1024,'height':768})
 await initialize(laptop,'client','owner'); await laptop.route('https://client.test/**',local_route); await laptop.set_content(html,wait_until='domcontentloaded')
 await laptop.locator('.dashboard-cockpit').wait_for(state='visible',timeout=9000)
 lb=await laptop.locator('.sidebar').bounding_box(); assert lb and 210<=lb['width']<=240,lb
 lo=await laptop.evaluate('({doc:document.documentElement.scrollWidth,body:document.body.scrollWidth,inner:window.innerWidth})'); assert lo['doc']<=1027 and lo['body']<=1027,lo
 await laptop.screenshot(path='/mnt/data/optimum-foundation-v2-laptop-1024.png',full_page=True)
 await laptop.close()
 # Tablet switches to overlay navigation and remains contained.
 tablet=await browser.new_page(viewport={'width':768,'height':1024})
 await initialize(tablet,'client','owner'); await tablet.route('https://client.test/**',local_route); await tablet.set_content(html,wait_until='domcontentloaded')
 await tablet.locator('.dashboard-cockpit').wait_for(state='visible',timeout=9000)
 assert await tablet.locator('[data-action="mobile-menu"]:visible').count()==1
 to=await tablet.evaluate('({doc:document.documentElement.scrollWidth,body:document.body.scrollWidth,inner:window.innerWidth})'); assert to['doc']<=771 and to['body']<=771,to
 await tablet.locator('[data-action="mobile-menu"]').click(); await tablet.wait_for_timeout(260)
 tb=await tablet.locator('.sidebar.open').bounding_box(); assert tb and tb['width']<=310 and tb['x']>=0 and tb['x']+tb['width']<=768,tb
 await tablet.screenshot(path='/mnt/data/optimum-foundation-v2-tablet-768.png',full_page=True)
 await tablet.close()
 print('FV2 responsive laptop/tablet done',flush=True)

async def premium_foundation_v2_auth_flow(browser):
 html=(ROOT/'index.html').read_text().replace('<head>','<head><base href="https://client.test/">',1)
 page=await browser.new_page(viewport={'width':1500,'height':900})
 await page.evaluate("Object.defineProperty(window,'localStorage',{configurable:true,value:{getItem:()=>null,setItem:()=>{},removeItem:()=>{},clear:()=>{},key:()=>null,length:0}})")
 await page.route('https://wzcaquxuvqfbstpxujsj.supabase.co/**',mock_route)
 await page.route('https://client.test/**',local_route); await page.set_content(html,wait_until='domcontentloaded')
 await page.locator('.auth-shell').wait_for(state='visible',timeout=9000)
 assert await page.locator('html').get_attribute('data-theme')=='dark'
 overflow=await page.evaluate('({doc:document.documentElement.scrollWidth,body:document.body.scrollWidth,inner:window.innerWidth})'); assert overflow['doc']<=1503 and overflow['body']<=1503,overflow
 await page.screenshot(path='/mnt/data/optimum-foundation-v2-auth-dark.png',full_page=True)
 await page.locator('[data-action="toggle-theme"]').click(); await page.wait_for_timeout(120)
 assert await page.locator('html').get_attribute('data-theme')=='light'
 await page.locator('[data-action="toggle-locale"]').click(); await page.wait_for_timeout(120)
 assert await page.locator('html').get_attribute('dir')=='ltr'
 await page.set_viewport_size({'width':390,'height':844}); await page.wait_for_timeout(180)
 mobile=await page.evaluate('({doc:document.documentElement.scrollWidth,body:document.body.scrollWidth,inner:window.innerWidth})'); assert mobile['doc']<=393 and mobile['body']<=393,mobile
 await page.screenshot(path='/mnt/data/optimum-foundation-v2-auth-mobile-light.png',full_page=True)
 await page.close(); print('FV2 auth dark/light/mobile done',flush=True)

async def main():
 flow=(sys.argv[1] if len(sys.argv)>1 else os.environ.get('OPTIMUM_BROWSER_FLOW','all')).strip().lower()
 flows={'client':client_flow,'orgos':organization_os_flow,'limited':limited_permission_flow,'mobile':mobile_responsive_flow,'premium69':premium69_organization_access_flow,'premiumf2':premium69_project_context_flow,'premiumcde':premium69_cde_information_flow,'policy':adaptive_policy_flow,'platform':platform_flow,'platformmobile':platform_mobile_flow,'workos':work_os_flow,'worklimited':work_os_limited_flow,'excellence':work_excellence_flow,'workmobile':work_mobile_excellence_flow,'premiumwork':premium69_work_os_flow,'pdc':pdc_owner_flow,'pdclimited':pdc_limited_flow,'pdcmobile':pdc_mobile_flow,'site69':site69_owner_flow,'site69limited':site69_limited_flow,'site69mobile':site69_mobile_flow,'premiumsite':premium69_site_delivery_flow,'point7':point7_delivery_intelligence_flow,'point8':point8_operations_center_flow,'point9':point9_site_supervisor_flow,'point10':point10_site_execution_flow,'point11':point11_project_control_flow,'point910':point910_consolidated_home_claim_flow,'premiumglobal':premium69_global_actions_flow,'premiumdashboard':premium69_dashboard_flow,'premiumplatform':premium69_platform_final_flow,'foundationv2':premium_foundation_v2_flow,'foundationv2mobile':premium_foundation_v2_mobile_flow,'foundationv2responsive':premium_foundation_v2_responsive_flow,'foundationv2auth':premium_foundation_v2_auth_flow}
 selected=list(flows) if flow=='all' else [x.strip() for x in flow.split(',') if x.strip()]
 unknown=[x for x in selected if x not in flows]
 if unknown: raise SystemExit(f'Unknown browser flow(s): {unknown}')
 async with async_playwright() as pw:
  browser=await pw.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
  for name in selected:
   print(f'BROWSER FLOW {name} START',flush=True)
   await flows[name](browser)
   print(f'BROWSER FLOW {name} PASS',flush=True)
  await browser.close()
 print(json.dumps({'ok':True,'flows':selected,'captured':{**captured,'disabled_entitlements':sorted(captured.get('disabled_entitlements') or [])}},ensure_ascii=False,indent=2))

asyncio.run(main())
