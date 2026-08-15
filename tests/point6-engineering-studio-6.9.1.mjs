import fs from 'node:fs';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {
  normalizeEngineeringSnapshot,
  validateEngineeringSnapshot,
  summarizeEngineeringTakeoff,
  summarizeEngineeringChanges,
  engineeringChangeObjectIds,
  exportEngineeringDxf,
  engineeringSnapshotSvg
} from '../assets/engineering.js';

const source=fs.readFileSync('assets/engineering.js','utf8');
const app=fs.readFileSync('assets/app.js','utf8');
const styles=fs.readFileSync('assets/styles.css','utf8');
const migration=fs.readFileSync('supabase/migrations/20260815043000_point6_engineering_studio_core.sql','utf8');

for (const marker of [
  'engineering-studio-active','engineering_studio_directory','engineering_studio_context',
  'create_engineering_drawing_v2','save_engineering_draft_v2','begin_engineering_cde_sync',
  'engineering-catalog-manager','engineering-edit-route-data','engineering-change-history',
  'engineering-create-task-from-selection','engineering-task-from-mark','engineering-trace-boq',
  'summarizeEngineeringChanges','changed-since-view','cad-cde-chip',
  'cad-beginner-coach','cad-toolbar-r2','cad-route-data-dialog','syncDerivedEngineeringArtifacts',
  'engineering-sync-derived','engineering-route-data-reset','safeValidationFixCodes','openSafeFixPreview','drawingReadiness','openDrawingReadiness','engineering-readiness'
]) assert.ok(source.includes(marker),`Point 6 missing ${marker}`);
assert.ok(app.includes("engineering-studio-active"),'App shell must know immersive studio mode');
for (const marker of [
  'html.engineering-studio-active .app-shell>.sidebar',
  'html.engineering-studio-active .main-column>.topbar',
  '.cad-change-intelligence','.cad-catalog-manager','.cad-route-data-dialog',
  '.cad-new-drawing','.review-register-card','.cad-premium-dialog','.cad-premium-drawer',
  '.cad-beginner-coach','.cad-toolbar-r2','.cad-route-r2-grid','.cad-guide-r2','.cad-readiness-chip','.cad-readiness-dialog'
]) assert.ok(styles.includes(marker),`Point 6 premium style missing ${marker}`);
for (const marker of [
  'engineering_revision_events','engineering_drawing_views','engineering_task_links',
  'attribute_schema','cabinet_id','cde_document_id','last_change_summary',
  'notify_company_members','create_engineering_task','begin_engineering_cde_sync'
]) assert.ok(migration.includes(marker),`Point 6 migration missing ${marker}`);
assert.ok(!source.includes("replace(/\\P/g,'\\n')"),'DXF text must not interpret every letter P as a paragraph break');
assert.ok(source.includes("replace(/\\\\P/g,'\\n')"),'DXF paragraph escape must match literal \\P');
assert.ok(!/\[['\"]dwg['\"]/.test(source),'Native DWG export must not be advertised without a real engine');

const catalog=[
  {code:'CAB-144',category:'node',symbol_key:'sub_cabinet',name_ar:'كابينة',name_en:'Cabinet',unit:'ea',default_properties:{cores:144,ports:36,color:'#2563eb'}},
  {code:'TB-24C',category:'node',symbol_key:'termination_box',name_ar:'بوكس 24',name_en:'Termination Box 24C',unit:'ea',default_properties:{cores:24,color:'#ef4444'}},
  {code:'DUCT-4W',category:'route',symbol_key:'microduct',name_ar:'دكت 4',name_en:'4-way Microduct',unit:'m',default_properties:{ways:4,color:'#f59e0b',dxf_layer:'MICRODUCT'}},
  {code:'FO-24C',category:'route',symbol_key:'fiber_cable',name_ar:'فايبر 24',name_en:'Fiber 24C',unit:'m',default_properties:{cores:24,color:'#16a34a',dxf_layer:'FIBER'}}
];
const previous=normalizeEngineeringSnapshot({nodes:[{id:'n1',catalogCode:'CAB-144',x:200,y:200,label:'CAB-01',properties:{networkLevel:'main',boxNo:'CAB01',capacity:144,ports:36}}]});
const current=normalizeEngineeringSnapshot({
  generalNotes:'Checked route',
  nodes:[
    {id:'n1',catalogCode:'CAB-144',x:220,y:200,label:'CAB-01',properties:{networkLevel:'main',boxNo:'CAB01',capacity:144,ports:36}},
    {id:'n2',catalogCode:'TB-24C',x:760,y:420,label:'TB-01',properties:{networkLevel:'terminal',boxNo:'TB01',capacity:24}}
  ],
  routes:[{id:'r1',catalogCode:'DUCT-4W',points:[{x:220,y:200},{x:500,y:200},{x:500,y:420},{x:760,y:420}],label:'CAB01-TB01',manualLength:31.5,sourceNodeId:'n1',targetNodeId:'n2',properties:{networkLevel:'secondary',installation:'underground',pathStyle:'orthogonal',cableCode:'FO-24C',fiberCores:24,ways:4,numberOfCables:1,connectorCount:2,fromLabel:'CAB-01',toLabel:'TB-01'}}],
  annotations:[{id:'a1',x:420,y:140,text:'Field note',size:16}]
});
const settings={width:1600,height:1000,titleBlock:true,framePanelWidth:330,scale:'1:100',catalog,titleBlockData:{cabinetNo:'CAB-01',designer:'Engineer A',checkedBy:'Engineer B',approvedBy:'Manager'}};
const validation=validateEngineeringSnapshot(current,catalog,settings);
assert.equal(validation.errorCount,0,'Certified Point 6 sample should have no validation errors');
const takeoff=summarizeEngineeringTakeoff(current,catalog,settings);
assert.equal(takeoff.summary.nodeCount,2);
assert.equal(takeoff.summary.routeCount,1);
assert.ok(takeoff.rows.some(x=>x.metadata?.routeIds?.includes('r1')),'BOQ rows must retain drawing traceability');
const changes=summarizeEngineeringChanges(previous,current,{},settings);
assert.ok(changes.total>=3,'Change intelligence should detect engineering changes');
const changed=engineeringChangeObjectIds(changes);
assert.ok(changed.nodes.has('n1')&&changed.nodes.has('n2')&&changed.routes.has('r1'));
const dxf=exportEngineeringDxf(current,{drawingNo:'P001-FIBER-001',title:'Fiber Network',project:'Alpha',site:'Site A',revision:'R2',status:'ISSUED',company:'Optimum'},settings);
for (const text of ['PROJECT','P001-FIBER-001','PORT 36','TYPE CAB-144','DRAWN / CHECKED / APPROVED']) assert.ok(dxf.includes(text),`DXF lost engineering text: ${text}`);
assert.ok(dxf.includes('MICRODUCT'),'DXF must preserve engineering route layers');
const svg=engineeringSnapshotSvg(current,{settings,catalog,metadata:{drawingNo:'P001-FIBER-001',project:'Alpha',site:'Site A'},changedIds:changed,locale:'en'});
assert.ok(svg.includes('changed-since-view'),'Changed objects must be visibly highlighted on reopen');
assert.ok(svg.includes('DRAWN BY')&&svg.includes('CHECKED BY')&&svg.includes('APPROVED BY'),'Professional frame must contain sign-off data');

// A practical heavy-drawing regression: validation, takeoff and DXF must stay bounded.
const heavyNodes=[];const heavyRoutes=[];
for(let i=0;i<500;i++){
  heavyNodes.push({id:`hn${i}`,catalogCode:i%5===0?'CAB-144':'TB-24C',x:80+(i%25)*55,y:80+Math.floor(i/25)*38,label:`N-${i}`,properties:{networkLevel:i%5===0?'main':'terminal',boxNo:`B${i}`,capacity:i%5===0?144:24,ports:i%5===0?36:null}});
  if(i>0)heavyRoutes.push({id:`hr${i}`,catalogCode:'DUCT-4W',points:[{x:heavyNodes[i-1].x,y:heavyNodes[i-1].y},{x:heavyNodes[i].x,y:heavyNodes[i].y}],label:`R-${i}`,manualLength:10,sourceNodeId:`hn${i-1}`,targetNodeId:`hn${i}`,properties:{networkLevel:'secondary',installation:'underground',pathStyle:'straight',cableCode:'FO-24C',fiberCores:24,ways:4,numberOfCables:1}});
}
const heavy=normalizeEngineeringSnapshot({nodes:heavyNodes,routes:heavyRoutes});
const t0=performance.now();validateEngineeringSnapshot(heavy,catalog,{width:1800,height:1200});const t1=performance.now();summarizeEngineeringTakeoff(heavy,catalog,{width:1800,height:1200});const t2=performance.now();exportEngineeringDxf(heavy,{drawingNo:'PERF-500'}, {width:1800,height:1200,titleBlock:false,catalog});const t3=performance.now();
assert.ok(t3-t0<8000,`Heavy CAD engineering pipeline took ${(t3-t0).toFixed(0)}ms`);
assert.ok(source.includes('attr_label_ar_${i}'), 'catalog attribute Arabic labels use a stable form key');
assert.ok(source.includes('attr_label_en_${i}'), 'catalog attribute English labels use a stable form key');
assert.ok(source.includes('attr_takeoff_${i}'), 'catalog BOQ/takeoff flag uses a stable form key');
assert.ok(!source.includes('data[`attr_ar_${i}`]'), 'legacy catalog Arabic form key is not read');
assert.ok(!source.includes('data[`attr_en_${i}`]'), 'legacy catalog English form key is not read');
assert.ok(!source.includes('data[`attr_boq_${i}`]'), 'legacy catalog BOQ form key is not read');
assert.ok(source.includes("localStorage.setItem('optimum.cad.guide.dismissed','1')"),'Beginner guide dismissal must persist');
assert.ok(source.includes("else if(action==='engineering-confirm-safe-fixes')applySafeFixes()"),'Safe validation fixes must require explicit confirmation');
assert.ok(!source.includes('Safe missing data will be completed and the network rearranged'),'Validation must not silently rearrange engineering topology');
assert.ok(source.includes("payload={label:String(data.guided_label||'')"),'Guided route editor must submit prefilled structured fields');
assert.ok(source.includes("buildExportPayload('xls')"),'Derived takeoff sync must use the professional workbook payload');
assert.ok(source.includes('validationArtifactPayload()'),'Derived validation report must be generated for CDE storage');
assert.ok(source.includes("title:L('جاهزية الرسم للإصدار','Drawing readiness')"),'Drawing readiness must explain issue readiness to novice users');
assert.ok(source.includes("key:'derived'"),'Drawing readiness must verify takeoff and validation files');

console.log(`PASS Point 6 Engineering Studio: contracts, CDE/change intelligence, catalog schema, BOQ trace, professional frame, DXF text integrity and 500-node performance (${(t1-t0).toFixed(0)}/${(t2-t1).toFixed(0)}/${(t3-t2).toFixed(0)}ms)`);
