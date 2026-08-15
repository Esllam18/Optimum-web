from pathlib import Path
from playwright.sync_api import sync_playwright
import json

ROOT=Path(__file__).resolve().parents[1]
JS=(ROOT/'assets/engineering.js').read_text(encoding='utf-8')
CSS=(ROOT/'assets/styles.css').read_text(encoding='utf-8')

LOCAL_STORAGE_SHIM="""(() => {
  const values={};
  const storage={
    get length(){return Object.keys(values).length}, key(i){return Object.keys(values)[i]??null},
    getItem(k){return Object.prototype.hasOwnProperty.call(values,k)?String(values[k]):null},
    setItem(k,v){values[k]=String(v)}, removeItem(k){delete values[k]}, clear(){for(const k of Object.keys(values))delete values[k]}
  };
  Object.defineProperty(window,'localStorage',{configurable:true,value:storage});
})()"""

def harness(mode='owner'):
    module_js=JS.replace('</script>','<\\/script>')
    schemas={
      'SUBCAB-22U':[
        {'key':'boxNo','type':'text','label_ar':'رقم الكابينة','label_en':'Cabinet no.','required':True},
        {'key':'networkLevel','type':'select','options':['main','secondary','terminal'],'label_ar':'مستوى الشبكة','label_en':'Network level','required':True},
        {'key':'capacity','type':'number','label_ar':'السعة','label_en':'Capacity','boq':True},
        {'key':'ports','type':'number','label_ar':'المنافذ','label_en':'Ports'},
        {'key':'cabinetU','type':'number','label_ar':'مقاس U','label_en':'Cabinet U'},
        {'key':'notes','type':'textarea','label_ar':'ملاحظات','label_en':'Notes'},
      ],
      'MH-TEL':[
        {'key':'boxNo','type':'text','label_ar':'الرقم','label_en':'Number','required':True},
        {'key':'lengthM','type':'number','label_ar':'الطول م','label_en':'Length m'},
        {'key':'widthM','type':'number','label_ar':'العرض م','label_en':'Width m'},
        {'key':'heightM','type':'number','label_ar':'العمق/الارتفاع م','label_en':'Depth/height m'},
        {'key':'notes','type':'textarea','label_ar':'ملاحظات','label_en':'Notes'},
      ],
      'DUCT-4W-7/3.5':[
        {'key':'networkLevel','type':'select','options':['main','secondary','drop'],'label_ar':'مستوى المسار','label_en':'Route level','required':True},
        {'key':'installation','type':'select','options':['underground','aerial','indoor'],'label_ar':'طريقة التنفيذ','label_en':'Installation','required':True},
        {'key':'ways','type':'number','label_ar':'عدد الطرق','label_en':'Ways','boq':True},
        {'key':'diameter','type':'text','label_ar':'القطر','label_en':'Diameter'},
        {'key':'cableCode','type':'catalog','catalog_symbol':'fiber_cable','label_ar':'الكابل الداخلي','label_en':'Inner cable'},
        {'key':'fiberCores','type':'number','label_ar':'عدد كور الكابل','label_en':'Fiber cores'},
        {'key':'numberOfCables','type':'number','label_ar':'عدد الكابلات','label_en':'Cable count'},
        {'key':'spareLengthM','type':'number','label_ar':'طول احتياطي م','label_en':'Spare length m'},
        {'key':'connectorCount','type':'number','label_ar':'عدد الكونكتورات','label_en':'Connector count'},
        {'key':'openBundle','type':'number','label_ar':'فتح الباندل','label_en':'Open bundle'},
        {'key':'endBundle','type':'number','label_ar':'نهاية الباندل','label_en':'End bundle'},
        {'key':'notes','type':'textarea','label_ar':'ملاحظات','label_en':'Notes'},
      ],
      'FO-24C':[
        {'key':'networkLevel','type':'select','options':['main','secondary','drop'],'label_ar':'مستوى المسار','label_en':'Route level','required':True},
        {'key':'installation','type':'select','options':['underground','aerial','indoor'],'label_ar':'طريقة التنفيذ','label_en':'Installation','required':True},
        {'key':'fiberCores','type':'number','label_ar':'عدد الكور','label_en':'Fiber cores','boq':True},
        {'key':'numberOfCables','type':'number','label_ar':'عدد الكابلات','label_en':'Cable count'},
        {'key':'spareLengthM','type':'number','label_ar':'طول احتياطي م','label_en':'Spare length m'},
        {'key':'connectorCount','type':'number','label_ar':'عدد الكونكتورات','label_en':'Connector count'},
        {'key':'notes','type':'textarea','label_ar':'ملاحظات','label_en':'Notes'},
      ]
    }
    schemas_json=json.dumps(schemas,ensure_ascii=False)
    return f'''<!doctype html><html lang="ar" dir="rtl" data-theme="dark"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>{CSS}</style></head><body>
<div class="app-shell"><aside class="sidebar" id="test-sidebar">SIDEBAR</aside><main class="main-column"><header class="topbar" id="test-topbar">TOPBAR</header><div class="page"><div id="app"></div></div></main></div><div id="overlay"></div>
<script type="module">{module_js}
const MODE={json.dumps(mode)};
const SCHEMAS={schemas_json};
const now='2026-08-15T01:00:00Z';
const previous='2026-08-14T22:00:00Z';
const catalog=[
{{id:'cat-sub',company_id:null,code:'SUBCAB-22U',category:'node',family:'cabinet',symbol_key:'sub_cabinet',name_ar:'كابينة فرعية 22U',name_en:'22U Sub Cabinet',unit:'ea',sort_order:1,is_active:true,default_properties:{{color:'#2563eb',palette_family:'cabinet'}},attribute_schema:SCHEMAS['SUBCAB-22U']}},
{{id:'cat-mh',company_id:null,code:'MH-TEL',category:'node',family:'civil',symbol_key:'manhole',name_ar:'غرفة اتصالات',name_en:'Telecom Manhole',unit:'ea',sort_order:2,is_active:true,default_properties:{{color:'#64748b',palette_family:'civil'}},attribute_schema:SCHEMAS['MH-TEL']}},
{{id:'cat-duct',company_id:null,code:'DUCT-4W-7/3.5',category:'route',family:'microduct',symbol_key:'microduct',name_ar:'ميكرو دكت 4 مسار',name_en:'4-way Microduct',unit:'m',sort_order:10,is_active:true,default_properties:{{ways:4,diameter:'7/3.5',color:'#22c55e',palette_family:'microduct'}},attribute_schema:SCHEMAS['DUCT-4W-7/3.5']}},
{{id:'cat-fiber',company_id:null,code:'FO-24C',category:'route',family:'fiber',symbol_key:'fiber_cable',name_ar:'كابل فايبر 24 كور',name_en:'24-core Fiber Cable',unit:'m',sort_order:11,is_active:true,default_properties:{{cores:24,color:'#f59e0b',palette_family:'fiber'}},attribute_schema:SCHEMAS['FO-24C']}},
{{id:'cat-custom',company_id:'c1',code:'COMPANY-BOX',category:'node',family:'company',symbol_key:'generic',name_ar:'عنصر شركة',name_en:'Company item',unit:'ea',sort_order:90,is_active:true,default_properties:{{color:'#8b5cf6',palette_family:'company'}},attribute_schema:[{{key:'assetNo',label_ar:'رقم الأصل',label_en:'Asset no.',type:'text',required:true,boq:false}}]}}
];
const snapshot=normalizeEngineeringSnapshot({{
 generalNotes:'ملاحظة عامة على الرسم',
 nodes:[
  {{id:'n1',catalogCode:'SUBCAB-22U',x:270,y:360,width:150,height:96,label:'CAB-M01',properties:{{boxNo:'CAB-M01',networkLevel:'main',capacity:144,ports:144,cabinetU:22,notes:'راجع تثبيت الكابينة'}}}},
  {{id:'n2',catalogCode:'MH-TEL',x:680,y:360,width:86,height:86,label:'MH-01',properties:{{boxNo:'MH-01',lengthM:1.2,widthM:1.2,heightM:1.5,notes:''}}}}
 ],
 routes:[{{id:'r1',catalogCode:'DUCT-4W-7/3.5',sourceNodeId:'n1',targetNodeId:'n2',points:[{{x:270,y:360}},{{x:680,y:360}}],label:'R-CAB01-MH01',manualLength:42,properties:{{networkLevel:'main',installation:'underground',ways:4,diameter:'7/3.5',cableCode:'FO-24C',fiberCores:24,numberOfCables:1,spareLengthM:8,connectorCount:2,fromLabel:'CAB-M01',toLabel:'MH-01',notes:'اختبار المسار'}}}}],
 annotations:[{{id:'a1',x:460,y:250,text:'ملاحظة تنفيذ',size:18,align:'start'}}]
}});
const drawing={{id:'d1',company_id:'c1',project_id:'p1',site_id:'s1',cabinet_id:'cab1',folder_id:'f1',cde_document_id:'doc1',source_document_id:null,drawing_no:'P001-FIBER-001',title:'Secondary Fiber Network',discipline:'fiber',drawing_type:'secondary_network',status:'draft',current_revision_id:'rev1',created_by:'u1',updated_by:'u2',created_at:previous,updated_at:now,archived_at:null,last_change_at:now,last_changed_by:'u2',last_change_summary:{{total:2,counts:{{nodes_added:0,nodes_removed:0,nodes_changed:1,routes_added:0,routes_removed:0,routes_changed:1,annotations_added:0,annotations_removed:0,annotations_changed:0,settings_changed:0}},objects:{{nodes:{{added:[],removed:[],changed:['n1']}},routes:{{added:[],removed:[],changed:['r1']}},annotations:{{added:[],removed:[],changed:[]}}}},settings:[]}}}};
const revision={{id:'rev1',company_id:'c1',drawing_id:'d1',revision_number:1,revision_code:'R1',status:'draft',snapshot,sheet_settings:{{width:1600,height:1000,grid:20,meterPerGrid:1,showGrid:true,snap:true,legend:true,titleBlock:true,scale:'NTS',titleBlockData:{{client:'Client A',consultant:'Consultant B',designer:'Engineer A',checkedBy:'Engineer B',approvedBy:'Manager C',logos:[]}}}},boq_snapshot:[],change_note:'تم تعديل مسار وكابينة',change_summary:drawing.last_change_summary,lock_version:3,created_by:'u1',created_at:previous,updated_at:now}};
const summary={{drawings:[drawing],revisions:[revision],catalog,cabinets:[{{id:'cab1',company_id:'c1',project_id:'p1',site_id:'s1',code:'CAB-12',name:'Cabinet 12',status:'active',root_folder_id:'f1',archived_at:null}}],studio_drawings:[{{id:'d1',cabinet_id:'cab1',cde_document_id:'doc1',last_change_at:now,last_change_summary:drawing.last_change_summary,last_changed_by:'u2',last_changed_by_name:'محمود السيد',last_viewed_at:previous,has_unseen_changes:true,updated_at:now}}],stats:{{revision_count:1,boq_count:2,open_mark_count:1}}}};
let context={{cabinet:{{id:'cab1',code:'CAB-12',name:'Cabinet 12',status:'active',root_folder_id:'f1'}},cde_document:{{id:'doc1',display_name:'P001-FIBER-001 — Secondary Fiber Network',control_status:'working',current_version_id:'v2',version_count:2}},task_links:[],change_events:[{{id:'e1',revision_id:'rev1',event_type:'saved',change_summary:drawing.last_change_summary,created_at:now,actor_id:'u2',actor_name:'محمود السيد'}},{{id:'e0',revision_id:'rev1',event_type:'created',change_summary:{{created:true}},created_at:previous,actor_id:'u1',actor_name:'Admin'}}],last_viewed_at:previous,has_unseen_changes:true,unseen_change_summary:drawing.last_change_summary,last_changed_by_name:'محمود السيد',can_manage_catalog:MODE==='owner',can_create_task:MODE==='owner'}};
const capabilities={{context_read_only:false,can_edit:MODE==='owner',can_review:MODE==='owner'||MODE==='reviewer',can_publish:MODE==='owner',can_manage_catalog:MODE==='owner',can_create_task:MODE==='owner'}};
const tables={{engineering_revision_boq:[],engineering_review_marks:[{{id:'m1',revision_id:'rev1',body:'راجع نقطة الربط',status:'open',x:520,y:330,created_at:previous}}],engineering_review_mark_updates:[],engineering_assets:[],engineering_document_links:[]}};
const captured={{rpcs:[],uploads:[],catalog:null,task:null,viewed:false,errors:[],toasts:[],derivedDocs:0}};window.__captured=captured;
function clone(v){{return structuredClone(v)}}
function permission(key){{
 const view=new Set(['drawings.view','drawings.export','boq.view','files.view']);
 if(MODE==='owner')return true;
 if(MODE==='reviewer')return view.has(key)||key==='drawings.review';
 return view.has(key);
}}
const api={{
 user:{{id:'u1',email:'admin@optimum.test',user_metadata:{{full_name:'Admin User'}}}},
 select:async(table,opts={{}})=>clone(tables[table]||[]),
 rpc:async(name,params={{}})=>{{captured.rpcs.push({{name,params:clone(params)}});
   if(name==='engineering_studio_directory'||name==='engineering_directory_snapshot')return clone(summary);
   if(name==='engineering_drawing_360')return {{drawing:clone(drawing),revision:clone(revision),revisions:[clone(revision)],boq:[],marks:clone(tables.engineering_review_marks),mark_updates:[],assets:[],links:[],capabilities:clone(capabilities)}};
   if(name==='engineering_studio_context')return clone(context);
   if(name==='mark_engineering_drawing_viewed'){{captured.viewed=true;return;}}
   if(name==='upsert_engineering_catalog_item'){{captured.catalog=clone(params);catalog.push({{id:'company-new',company_id:'c1',code:params.p_code,category:params.p_category,family:params.p_family,symbol_key:params.p_symbol_key,name_ar:params.p_name_ar,name_en:params.p_name_en,unit:params.p_unit,default_properties:params.p_default_properties,attribute_schema:params.p_attribute_schema,sort_order:100,is_active:true}});summary.catalog=catalog;return 'company-new';}}
   if(name==='create_engineering_task'){{captured.task=clone(params);context.task_links=[{{id:'l1',task_id:'t1',revision_id:'rev1',target_kind:params.p_target_kind,target_id:params.p_target_id,x:params.p_x,y:params.p_y,task:{{title:params.p_title,status:'todo',priority:params.p_priority,due_at:params.p_due_at}}}}];return 't1';}}
   if(name==='save_engineering_draft_v2'){{revision.lock_version+=1;revision.snapshot=clone(params.p_snapshot);revision.sheet_settings=clone(params.p_sheet_settings);revision.change_summary=clone(params.p_change_summary||{{}});return {{revision_id:'rev1',drawing_id:'d1',lock_version:revision.lock_version,saved_at:new Date().toISOString()}};}}
   if(name==='begin_engineering_cde_sync')return {{drawing_id:'d1',revision_id:'rev1',document_id:'doc1',version_id:'v3',version_number:3,storage_bucket:'company-files',storage_path:'c1/p1/doc1/v3/drawing.svg'}};
   if(name==='begin_document_upload'){{captured.derivedDocs+=1;const n=captured.derivedDocs;return {{document_id:`derived-${{n}}`,version_id:`derived-v${{n}}`,version_number:1,storage_bucket:'company-files',storage_path:`c1/p1/derived-${{n}}/v1/file`}};}}
   if(name==='begin_new_version_upload'){{captured.derivedDocs+=1;const n=captured.derivedDocs;return {{document_id:params.p_document_id,version_id:`derived-v${{n}}`,version_number:n,storage_bucket:'company-files',storage_path:`c1/p1/${{params.p_document_id}}/v${{n}}/file`}};}}
   if(name==='finalize_document_upload')return {{}};
   if(name==='link_engineering_revision_cde_version')return;
   if(name==='link_engineering_document')return;
   if(name==='update_engineering_drawing_identity'){{drawing.drawing_no=params.p_drawing_no;drawing.title=params.p_title;return;}}
   if(name==='archive_engineering_catalog_item')return;
   if(name==='resolve_engineering_review_mark'){{tables.engineering_review_marks=tables.engineering_review_marks.map(x=>x.id===params.p_mark_id?{{...x,status:'resolved'}}:x);return;}}
   return {{}};
 }},
 createSignedUrl:async()=> 'data:text/plain;base64,WA==',
 uploadObject:async(bucket,path,blob)=>{{captured.uploads.push({{bucket,path,size:blob.size,type:blob.type}});}},
 deleteObject:async()=>{{}}
}};
const overlay=document.querySelector('#overlay');
function closeOverlay(){{overlay.innerHTML='';}}
function overlayHtml(kind,opts){{const large=opts.large?(kind==='dialog'?'dialog-lg':'drawer-wide'):'';return `<div class="overlay open"><section class="${{kind}} ${{large}} ${{opts.extraClass||''}}"><header class="${{kind}}-head"><div class="${{kind}}-head-copy"><h2>${{opts.title||''}}</h2><p>${{opts.subtitle||''}}</p></div><button type="button" data-action="close-overlay">×</button></header><div class="${{kind}}-body">${{opts.body||''}}</div></section></div>`;}}
function openDialog(opts){{overlay.innerHTML=overlayHtml('dialog',opts);}}
function openDrawer(opts){{overlay.innerHTML=overlayHtml('drawer',opts);}}
function formDataObject(form){{const out={{}};for(const el of form.elements){{if(!el.name)continue;if(el.type==='checkbox')out[el.name]=el.checked;else if(el.type==='radio'){{if(el.checked)out[el.name]=el.value;}}else out[el.name]=el.value;}}return out;}}
const root=document.querySelector('#app');
let module;
const render=()=>{{root.innerHTML=module.page();requestAnimationFrame(()=>{{}});}};
const icon=(name,size=18)=>`<span class="test-icon" data-icon="${{name}}" style="width:${{size}}px;height:${{size}}px">◇</span>`;
const esc=(v='')=>String(v).replace(/[&<>"']/g,c=>({{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}}[c]));
const state={{companyId:'c1',company:{{id:'c1',name:'Optimum Engineering'}},profile:{{id:'u1',full_name:'Admin User'}},user:{{id:'u1'}},prefs:{{locale:'ar'}},projects:[{{id:'p1',code:'P001',name:'مشروع الألياف'}}],sites:[{{id:'s1',project_id:'p1',code:'S01',name:'موقع 1'}}],folders:[{{id:'f1',project_id:'p1',site_id:'s1',code:'02',name:'Drawings',trashed_at:null}},{{id:'fboq',project_id:'p1',site_id:'s1',code:'05.01',name:'BOQ & Quantities',trashed_at:null}},{{id:'fqa',project_id:'p1',site_id:'s1',code:'04',name:'QA/QC & Inspections',trashed_at:null}}],documents:[{{id:'doc1',project_id:'p1',site_id:'s1',folder_id:'f1',display_name:'Drawing canonical file',state:'active'}}],selectedProjectId:'p1',selectedSiteId:'s1'}};
const deps={{api,state,can:permission,L:(ar,en)=>ar,e:esc,icon,toast:(kind,msg)=>captured.toasts.push({{kind,msg}}),formError:(err,label)=>captured.errors.push(String(label||'')+': '+String(err?.message||err)),openDialog,openDrawer,closeOverlay,render,pageHeader:()=>'',emptyState:(ic,t,b,a='')=>`<div class="empty-state"><strong>${{t}}</strong><p>${{b}}</p>${{a}}</div>`,formatDateTime:(v)=>String(v||''),loadFilesData:async()=>{{}},openDocumentDetails:()=>{{captured.openDocument=true}}}};
module=createEngineeringModule(deps);window.__module=module;
document.addEventListener('click',async(ev)=>{{const el=ev.target.closest('[data-action]');if(!el)return;ev.preventDefault();if(el.dataset.action==='close-overlay'){{closeOverlay();return;}}try{{await module.handleAction(el.dataset.action,el);}}catch(err){{captured.errors.push(String(err?.message||err));}}}});
document.addEventListener('submit',async(ev)=>{{const form=ev.target.closest('form[data-form]');if(!form)return;ev.preventDefault();try{{await module.handleSubmit(form.dataset.form,form,formDataObject(form));}}catch(err){{captured.errors.push(String(err?.message||err));}}}});
document.addEventListener('input',(ev)=>{{try{{module.handleInput(ev);}}catch(err){{captured.errors.push(String(err?.message||err));}}}});
document.addEventListener('change',(ev)=>{{try{{module.handleChange(ev);}}catch(err){{captured.errors.push(String(err?.message||err));}}}});
document.addEventListener('keydown',(ev)=>module.keydown(ev));
await module.load();await module.openDrawing('d1','rev1');render();window.__point6Ready=true;
</script></body></html>'''

def no_overflow(page,label):
    v=page.evaluate('({doc:document.documentElement.scrollWidth,body:document.body.scrollWidth,inner:window.innerWidth})')
    assert v['doc']<=v['inner']+3 and v['body']<=v['inner']+3, f'{label}: horizontal overflow {v}'

def owner_flow(browser):
    page=browser.new_page(viewport={'width':1600,'height':1000})
    errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
    page.evaluate(LOCAL_STORAGE_SHIM)
    page.set_content(harness('owner'),wait_until='domcontentloaded',timeout=30000)
    page.wait_for_function('window.__point6Ready===true',timeout=30000)
    page.wait_for_timeout(150)
    assert not errors,errors
    assert page.locator('html.engineering-studio-active').count()==1
    assert page.locator('.engineering-editor-shell').count()==1
    # Full-screen Studio hides the normal app shell chrome.
    assert page.locator('#test-sidebar').evaluate("e=>getComputedStyle(e).display")=='none'
    assert page.locator('#test-topbar').evaluate("e=>getComputedStyle(e).display")=='none'
    # Beginner-first UX is visible and explains the workflow instead of exposing raw CAD complexity.
    assert page.locator('.cad-beginner-coach').count()==1
    coach=page.locator('.cad-beginner-coach').inner_text()
    assert 'أول مرة' in coach and ('احفظ' in coach or 'الحفظ' in coach)
    assert page.locator('.cad-toolbar-r2').count()==1
    # Final CAD closure: core toolbar controls are direct, while Routes stay out of the board until requested.
    assert page.locator('.cad-panel-strip [data-action="engineering-toggle-route-dock"]').count()==1
    assert page.locator('.cad-route-dock-r2').count()==0
    assert page.locator('.cad-toolbar-more').count()==0
    page.locator('[data-action="engineering-tool"][data-tool="route"]').click();page.wait_for_timeout(50)
    assert page.locator('.cad-route-dock-r2').count()==1
    page.locator('.cad-panel-strip [data-action="engineering-toggle-route-dock"]').click();page.wait_for_timeout(40)
    assert page.locator('.cad-route-dock-r2').count()==0
    page.locator('[data-action="engineering-tool"][data-tool="select"]').click();page.wait_for_timeout(30)
    assert page.locator('.cad-cde-chip').inner_text().strip().find('محفوظ')>=0
    # Unseen changes are visible and exact changed objects are highlighted.
    assert page.locator('.cad-change-intelligence').count()==1
    assert 'ما الذي تغير' in page.locator('.cad-change-intelligence').inner_text()
    assert page.evaluate("document.querySelector('[data-eng-node=\"n1\"]')?.getAttribute('class')?.includes('changed-since-view')===true")
    assert page.evaluate("document.querySelector('[data-eng-route=\"r1\"]')?.getAttribute('class')?.includes('changed-since-view')===true")
    page.locator('[data-action="engineering-change-history"]').click()
    page.locator('.cad-change-history').wait_for(state='visible',timeout=3000)
    hist=page.locator('.cad-change-history').inner_text()
    assert 'محمود السيد' in hist and ('حفظ' in hist or 'تعديلات' in hist)
    page.locator('[data-action="close-overlay"]').first.click()

    # Company Catalog Builder: regression for AR/EN labels and BOQ flag.
    page.locator('[data-action="engineering-catalog-manager"]').click()
    page.locator('.cad-catalog-manager').wait_for(state='visible',timeout=3000)
    page.locator('[data-action="engineering-catalog-new"]').click()
    form=page.locator('form[data-form="engineering-catalog-item"]');form.wait_for(state='visible',timeout=3000)
    form.locator('[name="code"]').fill('CUSTOM-MH')
    form.locator('[name="category"]').select_option('node')
    form.locator('[name="family"]').fill('civil')
    form.locator('[name="name_ar"]').fill('غرفة مخصصة')
    form.locator('[name="name_en"]').fill('Custom chamber')
    form.locator('[name="symbol_key"]').select_option('manhole')
    form.locator('[name="attr_key_0"]').fill('depthM')
    form.locator('[name="attr_label_ar_0"]').fill('العمق')
    form.locator('[name="attr_label_en_0"]').fill('Depth')
    form.locator('[name="attr_type_0"]').select_option('number')
    form.locator('[name="attr_required_0"]').check()
    form.locator('[name="attr_takeoff_0"]').check()
    form.locator('button.btn-primary').last.click()
    page.wait_for_function("window.__captured.catalog!==null",timeout=3000)
    cat=page.evaluate('window.__captured.catalog')
    assert cat['p_attribute_schema'][0]['label_ar']=='العمق'
    assert cat['p_attribute_schema'][0]['label_en']=='Depth'
    assert cat['p_attribute_schema'][0]['boq'] is True
    page.wait_for_timeout(80);page.locator('[data-action="close-overlay"]').first.click()

    # Type-specific element creation: Manhole must not show unrelated cabinet/splitter fields.
    # Use internal editor state and a synthetic pending point, then click a Manhole palette tile.
    page.evaluate("window.__module.state.catalogCode='MH-TEL';window.__module.state.pendingPoint={x:850,y:540};window.__module.state.tool='node';window.__module.state.showPalette=true;window.__module.state.dirty=false;window.__module.state.selected=null;window.__module.state.selection=[];window.__module.state.sideTab='properties';")
    page.locator('#app').evaluate("(el)=>el.innerHTML=window.__module.page()")
    # page() schedules viewport restoration/bindCanvas on the next animation frame.
    # Wait for the actual canvas handler instead of racing the browser frame.
    page.wait_for_function("document.querySelector('#engineering-canvas')?.dataset.bound==='1'",timeout=3000)
    # Trigger the real node dialog through the canvas flow by clicking the SVG.
    canvas=page.locator('#engineering-canvas')
    box=canvas.bounding_box();assert box
    page.mouse.click(box['x']+box['width']*.60,box['y']+box['height']*.55)
    nform=page.locator('form[data-form="engineering-node-create"]');nform.wait_for(state='visible',timeout=3000)
    ntext=nform.inner_text()
    assert 'الطول م' in ntext and 'العرض م' in ntext and ('العمق' in ntext or 'الارتفاع' in ntext)
    assert 'ODF' not in ntext and 'Splitter' not in ntext and 'السبلتر' not in ntext
    page.locator('[data-action="close-overlay"]').first.click()
    page.evaluate("window.__module.state.tool='select';window.__module.state.selected={kind:'route',id:'r1'};window.__module.state.showInspector=true;")
    page.locator('#app').evaluate("(el)=>el.innerHTML=window.__module.page()")

    # Route editor must load CURRENT route data before any edit.
    page.locator('[data-action="engineering-edit-route-data"]').click()
    rform=page.locator('form[data-form="engineering-route-data"]');rform.wait_for(state='visible',timeout=3000)
    assert page.locator('.cad-route-data-dialog').count()==1
    assert rform.locator('[name="guided_label"]').input_value()=='R-CAB01-MH01'
    assert abs(float(rform.locator('[name="guided_manual_length"]').input_value())-42)<0.01
    assert rform.locator('[name="schema_0"]').input_value()=='main'
    assert rform.locator('[name="schema_1"]').input_value()=='underground'
    raw=rform.locator('[name="route_json"]').input_value()
    assert 'R-CAB01-MH01' in raw and 'underground' in raw and '42' in raw
    # Beginner default is the guided form. Apply a real edit through it.
    rform.locator('[name="guided_label"]').fill('R-UPDATED')
    rform.locator('[name="guided_manual_length"]').fill('51.25')
    rform.locator('[name="schema_0"]').select_option('secondary')
    rform.locator('[name="schema_11"]').fill('تم تحديث بيانات المسار')
    rform.locator('button.btn-primary').last.click();page.wait_for_timeout(80)
    route=page.evaluate("window.__module.state.snapshot.routes.find(x=>x.id==='r1')")
    assert route['label']=='R-UPDATED' and abs(route['manualLength']-51.25)<0.01 and route['properties']['networkLevel']=='secondary'

    # Drawing -> Task preserves drawing/revision/target context.
    page.evaluate("window.__module.state.selected={kind:'route',id:'r1'};document.querySelector('#app').innerHTML=window.__module.page()")
    page.locator('[data-action="engineering-create-task-from-selection"]').click()
    tform=page.locator('form[data-form="engineering-task"]');tform.wait_for(state='visible',timeout=3000)
    tform.locator('[name="title"]').fill('مراجعة مسار R-UPDATED')
    tform.locator('[name="priority"]').select_option('high')
    tform.locator('button.btn-primary').last.click()
    page.wait_for_function('window.__captured.task!==null',timeout=3000)
    task=page.evaluate('window.__captured.task')
    assert task['p_drawing_id']=='d1' and task['p_revision_id']=='rev1' and task['p_target_kind']=='route' and task['p_target_id']=='r1'

    # Takeoff has trace-to-drawing and trace selects exact source objects.
    page.locator('[data-action="engineering-open-boq"]').first.click()
    page.locator('.engineering-takeoff-workspace').wait_for(state='visible',timeout=3000)
    trace=page.locator('[data-action="engineering-trace-boq"]').first
    assert trace.count()==1
    nodes=trace.get_attribute('data-nodes') or '';routes=trace.get_attribute('data-routes') or ''
    assert nodes or routes
    trace.click();page.wait_for_timeout(80)
    assert page.evaluate('window.__module.state.selection.length')>0

    # Notes center explains persistence and exposes review records.
    page.locator('[data-action="engineering-open-notes"]').click();page.wait_for_timeout(100)
    page.locator('.notes-center-summary').wait_for(state='visible',timeout=3000)
    nt=page.locator('#overlay').inner_text()
    assert 'ملاحظات عامة' in nt and 'بيان تعديل' in nt and 'قائمة ملاحظات المراجعة' in nt
    assert page.locator('.review-register-card').count()>=1
    page.locator('[data-action="close-overlay"]').first.click()

    # Frame is professional and includes sign-off fields; adaptive logo slots are available.
    page.locator('[data-action="engineering-frame-settings"]').click()
    f=page.locator('form[data-form="engineering-frame-settings"]');f.wait_for(state='visible',timeout=3000)
    for name in ['designer','checked_by','approved_by']:
        assert f.locator(f'[name="{name}"]').count()==1
    assert f.locator('[data-eng-frame-logo-input]').count()==4
    page.locator('[data-action="close-overlay"]').first.click()
    svgtext=page.locator('#engineering-canvas').text_content() or ''
    assert 'DRAWN BY' in svgtext and 'CHECKED BY' in svgtext and 'APPROVED BY' in svgtext

    # Derived engineering artifacts are not UI-only: takeoff and validation are uploaded to CDE.
    before=page.evaluate('window.__captured.uploads.length')
    page.locator('[data-action="engineering-sync-derived"]').click()
    page.wait_for_function('window.__module.state.derivedLastSyncedAt!==null',timeout=5000)
    after=page.evaluate('window.__captured.uploads.length')
    assert after>=before+2
    rpc_names=page.evaluate('window.__captured.rpcs.map(x=>x.name)')
    assert 'begin_document_upload' in rpc_names and 'link_engineering_document' in rpc_names
    assert page.locator('.cad-derived-chip').inner_text().strip()

    # Readiness is the novice user's final answer to “am I done?” and links directly to missing actions.
    page.locator('[data-action="engineering-save"]').first.click()
    page.wait_for_function('window.__module.state.dirty===false && window.__module.state.saving===false',timeout=5000)
    page.locator('[data-action="engineering-readiness"]').click()
    page.locator('.cad-readiness-dialog').wait_for(state='visible',timeout=3000)
    readiness=page.locator('.cad-readiness-dialog').inner_text()
    assert 'جاهزية الرسم' in readiness and '6/6' in readiness and 'مكتمل' in readiness
    assert page.locator('.cad-readiness-list article').count()==6
    page.screenshot(path='/mnt/data/optimum-point6-readiness.png',full_page=True)
    page.locator('[data-action="close-overlay"]').first.click()

    no_overflow(page,'Point6 owner desktop')
    page.screenshot(path='/mnt/data/optimum-point6-studio-desktop.png',full_page=True)
    # Screens for review surfaces
    page.locator('[data-action="engineering-change-history"]').click();page.wait_for_timeout(60);page.screenshot(path='/mnt/data/optimum-point6-change-history.png',full_page=True);page.locator('[data-action="close-overlay"]').first.click()
    page.locator('[data-action="engineering-catalog-manager"]').click();page.wait_for_timeout(60);page.screenshot(path='/mnt/data/optimum-point6-catalog-manager.png',full_page=True);page.locator('[data-action="close-overlay"]').first.click()
    page.evaluate("window.__module.state.selected={kind:'route',id:'r1'};document.querySelector('#app').innerHTML=window.__module.page()")
    page.locator('[data-action="engineering-edit-route-data"]').click();page.wait_for_timeout(60);page.screenshot(path='/mnt/data/optimum-point6-route-data-editor.png',full_page=True);page.locator('[data-action="close-overlay"]').first.click()
    page.locator('[data-action="engineering-open-boq"]').first.click();page.wait_for_timeout(60);page.screenshot(path='/mnt/data/optimum-point6-takeoff.png',full_page=True);page.locator('[data-action="close-overlay"]').first.click()
    page.locator('[data-action="engineering-frame-settings"]').click();page.wait_for_timeout(60);page.screenshot(path='/mnt/data/optimum-point6-frame.png',full_page=True);page.locator('[data-action="close-overlay"]').first.click()

    # Leaving the Studio returns to a beginner-friendly engineering register, not a technical dashboard.
    page.locator('[data-action="engineering-back"]').first.click();page.wait_for_timeout(120)
    page.locator('.cad-register-hero').wait_for(state='visible',timeout=3000)
    register_text=page.locator('.cad-register-hero').inner_text()
    assert 'استوديو الهندسة' in register_text and ('حدد السياق' in register_text or 'اختر' in register_text)
    no_overflow(page,'Point6 engineering register')
    page.screenshot(path='/mnt/data/optimum-point6-register-desktop.png',full_page=True)
    assert page.evaluate('window.__captured.errors').__len__()==0, page.evaluate('window.__captured.errors')
    print('point6-owner-studio: PASS')
    page.close()

def permission_flow(browser,mode):
    page=browser.new_page(viewport={'width':1280,'height':900})
    page.evaluate(LOCAL_STORAGE_SHIM)
    page.set_content(harness(mode),wait_until='domcontentloaded',timeout=30000)
    page.wait_for_function('window.__point6Ready===true',timeout=30000);page.wait_for_timeout(120)
    assert page.locator('.engineering-readonly').count()==1
    assert page.locator('.cad-master-library').count()==0
    assert page.locator('[data-action="engineering-tool"][data-tool="node"]').count()==0
    assert page.locator('[data-action="engineering-tool"][data-tool="route"]').count()==0
    assert page.locator('[data-action="engineering-frame-settings"]').count()==0
    assert page.locator('[data-action="engineering-save"]').count()==0
    if mode=='reviewer':
        assert page.locator('[data-action="engineering-tool"][data-tool="review"]').count()==1
    else:
        assert page.locator('[data-action="engineering-tool"][data-tool="review"]').count()==0
    no_overflow(page,f'Point6 {mode}')
    print(f'point6-{mode}: PASS')
    page.close()

def mobile_flow(browser):
    page=browser.new_page(viewport={'width':390,'height':844})
    page.evaluate(LOCAL_STORAGE_SHIM)
    page.set_content(harness('owner'),wait_until='domcontentloaded',timeout=30000)
    page.wait_for_function('window.__point6Ready===true',timeout=30000);page.wait_for_timeout(160)
    assert page.locator('.cad-mobile-layout').count()==1
    assert page.locator('html.engineering-studio-active').count()==1
    no_overflow(page,'Point6 mobile')
    page.screenshot(path='/mnt/data/optimum-point6-mobile.png',full_page=True)
    print('point6-mobile: PASS')
    page.close()

with sync_playwright() as p:
    browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
    owner_flow(browser)
    permission_flow(browser,'reviewer')
    permission_flow(browser,'viewer')
    mobile_flow(browser)
    browser.close()
print('Point 6 Engineering Studio dedicated browser acceptance passed.')
