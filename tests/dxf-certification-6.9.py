from pathlib import Path
import subprocess, tempfile, json, ezdxf

root=Path(__file__).resolve().parents[1]
node_code=r'''
import fs from 'node:fs';
import {normalizeEngineeringSnapshot,exportEngineeringDxf} from './assets/engineering.js';
const catalog=[
{code:'CAB-144',category:'node',symbol_key:'sub_cabinet',name_ar:'كابينة',name_en:'Cabinet',unit:'ea',default_properties:{cores:144,ports:36,color:'#2563eb'}},
{code:'TB-24C',category:'node',symbol_key:'termination_box',name_ar:'بوكس 24',name_en:'Termination Box 24C',unit:'ea',default_properties:{cores:24,color:'#ef4444'}},
{code:'DUCT-4W',category:'route',symbol_key:'microduct',name_ar:'دكت 4',name_en:'4-way Microduct',unit:'m',default_properties:{ways:4,color:'#f59e0b',dxf_layer:'MICRODUCT'}}
];
const snap=normalizeEngineeringSnapshot({nodes:[
{id:'n1',catalogCode:'CAB-144',x:220,y:220,label:'CAB-01',properties:{networkLevel:'main',boxNo:'CAB01',capacity:144,ports:36}},
{id:'n2',catalogCode:'TB-24C',x:780,y:420,label:'TB-01',properties:{networkLevel:'terminal',boxNo:'TB01',capacity:24}}
],routes:[{id:'r1',catalogCode:'DUCT-4W',points:[{x:220,y:220},{x:500,y:220},{x:500,y:420},{x:780,y:420}],label:'R-CAB01-TB01',manualLength:31.5,sourceNodeId:'n1',targetNodeId:'n2',properties:{networkLevel:'secondary',installation:'underground',pathStyle:'orthogonal',cableCode:'FO-24C',fiberCores:24,ways:4,fromLabel:'CAB-01',toLabel:'TB-01'}}],annotations:[{id:'a1',x:400,y:150,text:'TEST ROUTE / مسار اختبار',size:18}]});
const settings={width:1600,height:1000,titleBlock:true,framePanelWidth:330,scale:'1:100',catalog,titleBlockData:{client:'Client A',consultant:'Consultant B',designer:'Engineer A',checkedBy:'Engineer B',approvedBy:'Manager C',cabinetNo:'CAB-01'}};
fs.writeFileSync(process.argv[1],exportEngineeringDxf(snap,{drawingNo:'P001-FIBER-001',title:'Fiber Secondary Network',project:'Alpha',site:'Site A',revision:'R2',status:'ISSUED',company:'Optimum'},settings));
'''
with tempfile.TemporaryDirectory() as td:
    dxf=Path(td)/'drawing.dxf'
    result=subprocess.run(['node','--input-type=module','-e',node_code,str(dxf)],cwd=root,capture_output=True,text=True)
    if result.returncode:
        raise AssertionError(f'Node DXF generator failed: {result.stderr}')
    doc=ezdxf.readfile(dxf)
    msp=doc.modelspace()
    layers={layer.dxf.name for layer in doc.layers}
    entity_types={e.dxftype() for e in msp}
    texts=[e.dxf.text for e in msp if e.dxftype()=='TEXT']
    required_text=['PROJECT','P001-FIBER-001','PORT 36','TYPE CAB-144','DRAWN / CHECKED / APPROVED','R-CAB01-TB01']
    assert doc.dxfversion=='AC1015', doc.dxfversion
    assert {'FRAME','TITLE_TEXT','NODE_CABINET','NODE_TERMINAL','ROUTE_TEXT','MICRODUCT'} <= layers, layers
    assert {'LINE','LWPOLYLINE','TEXT'} <= entity_types, entity_types
    assert any(e.dxftype()=='LWPOLYLINE' and e.dxf.layer=='MICRODUCT' for e in msp)
    for value in required_text:
        assert any(value in text for text in texts), f'missing DXF text: {value}'
    # Round-trip semantic counts: the certified file must retain at least the two node symbols and one route polyline.
    node_entities=[e for e in msp if e.dxf.layer in {'NODE_CABINET','NODE_TERMINAL'}]
    route_entities=[e for e in msp if e.dxf.layer=='MICRODUCT']
    assert len(node_entities)>=4, len(node_entities)
    assert len(route_entities)>=1, len(route_entities)
    print(json.dumps({'PASS':'DXF certification','version':doc.dxfversion,'entities':len(msp),'layers':sorted(layers),'texts_checked':required_text},ensure_ascii=False))
