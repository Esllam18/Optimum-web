export function createOperationsCenter({api,state,can,L,e,icon,getProfile,formatDate,formatDateTime,relativeTime,pageHeader,emptyState,render,toast,formError,navigateToEntity,replaceRoute,i18n}){
  const defaultLayers={tasks:true,reviews:true,documents:true,drawings:true,delivery:true,projects:true};
  const local={
    snapshot:{tasks:[],approvals:[],notifications:[],changes:[],follows:[],calendar_layers:{...defaultLayers},last_seen_at:null},
    calendar:{events:[],cursor:new Date(new Date().getFullYear(),new Date().getMonth(),1),mode:'month'},
    view:'today',loading:false,loadedKey:'',refreshing:false,importantOnly:true,calendarLoading:false
  };
  const arr=(v)=>Array.isArray(v)?v:[];
  const entityLabel=(type)=>({task:L('مهمة','Task'),document:L('مستند','Document'),engineering_drawing:L('رسم هندسي','Drawing'),site_claim_package:L('حزمة تسليم','Delivery package'),site_daily_log:L('تقرير موقع يومي','Daily site report'),site_inspection:L('فحص ميداني','Field inspection'),site_field_issue:L('مشكلة ميدانية','Field issue'),site_constraint:L('عائق تنفيذ','Execution constraint'),project:L('مشروع','Project'),site:L('موقع','Site'),site_cabinet:L('كابينة','Cabinet'),access_change_request:L('طلب وصول','Access request')}[type]||L('عنصر','Item'));
  const entityIcon=(type)=>({task:'checkSquare',document:'file',engineering_drawing:'drafting',site_claim_package:'archive',site_daily_log:'file',site_inspection:'shield',site_field_issue:'alert',site_constraint:'pause',project:'briefcase',site:'map',site_cabinet:'box',access_change_request:'shield'}[type]||'activity');
  const actionNotification=(n)=>/(assigned|assignment|due|overdue|approval|review|rejected|blocked|security|invite|action|required|failed|returned)/i.test(String(n?.type||''));
  const notificationTitle=(n)=>i18n.locale==='ar'?(n?.title_ar||n?.title_en):(n?.title_en||n?.title_ar);
  const notificationBody=(n)=>i18n.locale==='ar'?(n?.body_ar||n?.body_en):(n?.body_en||n?.body_ar);
  const todayStart=()=>{const d=new Date();d.setHours(0,0,0,0);return d;};
  const tomorrowStart=()=>{const d=todayStart();d.setDate(d.getDate()+1);return d;};
  const isToday=(value)=>{if(!value)return false;const d=new Date(value);return d>=todayStart()&&d<tomorrowStart();};
  const isOverdue=(t)=>Boolean(t?.due_at&&new Date(t.due_at)<new Date());
  const importance=(c)=>/(approved|rejected|returned|submitted|published|restored|created|status_changed|version_uploaded|document\.version_uploaded|issue|inspection|constraint|field\.|revision)/i.test(String(c?.action||''));
  const profileName=(id)=>id?(getProfile(id)?.full_name||L('مستخدم','User')):L('النظام','System');
  const projectName=(id)=>state.projects.find(x=>x.id===id)?.name||'';
  const statusLabel=(value)=>({
    in_review:L('قيد المراجعة','In review'),submitted:L('مُرسلة للمراجعة','Submitted'),approved:L('معتمدة','Approved'),rejected:L('مُعادة للتعديل','Returned'),
    collecting:L('جمع الأدلة','Collecting'),ready:L('جاهزة','Ready'),todo:L('مطلوبة','To do'),in_progress:L('قيد التنفيذ','In progress'),blocked:L('متوقفة','Blocked'),done:L('مكتملة','Done'),
    draft:L('مسودة','Draft'),working:L('قيد العمل','Working'),active:L('نشط','Active'),pending:L('معلّق','Pending')
  })[String(value||'').toLowerCase()]||String(value||'').replaceAll('_',' ');
  const siteName=(id)=>state.sites.find(x=>x.id===id)?.name||'';
  const followKey=(type,id)=>`${type}:${id}`;
  const followsSet=()=>new Set(arr(local.snapshot.follows).map(x=>followKey(x.entity_type,x.entity_id)));
  const isFollowed=(type,id)=>followsSet().has(followKey(type,id));
  const contextLine=(row)=>[projectName(row.project_id),siteName(row.site_id)].filter(Boolean).join(' · ');
  const currentGreeting=()=>{const h=new Date().getHours();return h<12?L('صباح الخير','Good morning'):h<18?L('مساء الخير','Good afternoon'):L('مساء الخير','Good evening');};
  const calendarRange=()=>{const c=new Date(local.calendar.cursor);const from=new Date(c.getFullYear(),c.getMonth(),1);from.setDate(from.getDate()-((from.getDay()+6)%7));const to=new Date(from);to.setDate(to.getDate()+42);return {from,to};};
  const calendarLayer=(kind)=>({task:'tasks',milestone:'tasks',leave:'tasks',holiday:'tasks',document_review:'reviews',document_expiry:'documents',drawing_change:'drawings',delivery_review:'delivery',field_inspection:'reviews',daily_report:'delivery',field_issue_due:'delivery',project_target:'projects',site_target:'projects'}[kind]||'tasks');
  const visibleCalendarEvents=()=>arr(local.calendar.events).filter(ev=>local.snapshot.calendar_layers?.[calendarLayer(ev.kind)]!==false);
  const attentionCount=()=>arr(local.snapshot.approvals).length+arr(local.snapshot.notifications).filter(actionNotification).length+arr(local.snapshot.tasks).filter(isOverdue).length;
  const markSeen=async()=>{try{await api.rpc('operations_center_mark_seen',{p_company_id:state.companyId});}catch{/* non-blocking */}};

  async function loadCalendar(){
    if(!state.companyId)return;
    local.calendarLoading=true;render();
    try{const {from,to}=calendarRange();const [base,field]=await Promise.all([api.rpc('operations_calendar_feed',{p_company_id:state.companyId,p_from:from.toISOString(),p_to:to.toISOString(),p_user_id:null}),api.rpc('site_execution_calendar_feed',{p_company_id:state.companyId,p_from:from.toISOString(),p_to:to.toISOString()}).catch(()=>[])]);local.calendar.events=[...arr(base),...arr(field)];}
    catch(err){local.calendar.events=[];console.warn('[Operations] calendar feed failed',err);}
    finally{local.calendarLoading=false;render();}
  }
  async function load({force=false,mark=true}={}){
    if(!state.companyId)return;
    const key=`${state.companyId}:${api.user?.id||''}`;
    if(local.loading||(!force&&local.loadedKey===key))return;
    local.loading=true;render();
    try{
      const [snap,fieldFeed]=await Promise.all([api.rpc('operations_center_snapshot',{p_company_id:state.companyId,p_limit:50}),api.rpc('site_operations_feed',{p_company_id:state.companyId,p_since:local.snapshot.last_seen_at||null,p_limit:50}).catch(()=>({changes:[],approvals:[]}))]);
      local.snapshot={...local.snapshot,...(snap||{}),tasks:arr(snap?.tasks),approvals:[...arr(snap?.approvals),...arr(fieldFeed?.approvals)],notifications:arr(snap?.notifications),changes:[...arr(fieldFeed?.changes),...arr(snap?.changes)].sort((a,b)=>new Date(b.created_at)-new Date(a.created_at)).slice(0,80),follows:arr(snap?.follows),calendar_layers:{...defaultLayers,...(snap?.calendar_layers||{})}};
      local.loadedKey=key;
      await loadCalendar();
      if(mark)markSeen();
    }catch(err){formError(err,L('تعذر تحميل مركز التشغيل','Could not load Operations Center'));}
    finally{local.loading=false;local.refreshing=false;render();}
  }
  function reset(){local.loadedKey='';local.snapshot={tasks:[],approvals:[],notifications:[],changes:[],follows:[],calendar_layers:{...defaultLayers},last_seen_at:null};local.calendar.events=[];}

  function metric(ic,value,label,tone='') {return `<article class="ops-metric ${tone}"><span>${icon(ic,17)}</span><div><b>${value}</b><small>${e(label)}</small></div></article>`;}
  function taskRow(t,{compact=false}={}){
    const role=t.action_role==='approve'?L('بانتظار اعتمادك','Needs your approval'):t.action_role==='review'?L('بانتظار مراجعتك','Needs your review'):isOverdue(t)?L('متأخرة','Overdue'):isToday(t.due_at)?L('اليوم','Today'):L('مهمة نشطة','Active task');
    return `<button class="ops-work-row ${isOverdue(t)?'is-overdue':''}" data-action="ops-open-entity" data-type="task" data-id="${e(t.entity_id)}"><span class="ops-row-icon">${icon('checkSquare',15)}</span><span class="ops-row-copy"><strong>${e(t.title)}</strong><small>${e(role)}${contextLine(t)?` · ${e(contextLine(t))}`:''}${t.due_at?` · ${e(relativeTime(t.due_at))}`:''}</small></span>${compact?'':`<span class="ops-priority priority-${e(t.priority||'medium')}">${e(({urgent:L('عاجلة','Urgent'),high:L('مهمة','High'),medium:L('عادية','Normal'),low:L('منخفضة','Low')})[t.priority]||t.priority||'')}</span>`}${icon('chevron',13)}</button>`;
  }
  function approvalRow(a){
    const copy=({approval:L('اعتماد مهمة','Task approval'),review:L('مراجعة مهمة','Task review'),document_review:L('مراجعة مستند','Document review'),delivery_review:L('مراجعة حزمة تسليم','Delivery review'),access_review:L('مراجعة طلب وصول','Access review'),daily_report_review:L('مراجعة تقرير الموقع','Daily report review')})[a.action_kind]||L('يحتاج قرارًا','Needs decision');
    return `<article class="ops-decision-row"><span class="ops-row-icon tone-warning">${icon(entityIcon(a.entity_type),16)}</span><button data-action="ops-open-approval" data-kind="${e(a.kind)}" data-id="${e(a.entity_id)}"><strong>${e(a.title)}</strong><small>${e(copy)}${contextLine(a)?` · ${e(contextLine(a))}`:''}</small></button><span class="ops-decision-state">${e(statusLabel(a.status))}</span>${icon('chevron',13)}</article>`;
  }
  function notificationRow(n){return `<article class="ops-inbox-row ${actionNotification(n)?'needs-action':''}"><span class="ops-row-icon">${icon(actionNotification(n)?'alert':'bell',16)}</span><button data-action="ops-open-notification" data-id="${e(n.id)}"><strong>${e(notificationTitle(n))}</strong>${notificationBody(n)?`<p>${e(notificationBody(n))}</p>`:''}<small>${e(relativeTime(n.created_at))}</small></button>${n.entity_type&&n.entity_id?icon('chevron',13):''}</article>`;}
  function changeText(c){
    const action=String(c.action||'');
    if(action==='document.version_uploaded')return L('تم رفع إصدار جديد','New document version uploaded');
    if(/field\.inspection\.failed/i.test(action))return L('فحص ميداني لم يجتز','Field inspection failed');
    if(/field\.inspection/i.test(action))return L('تم تحديث فحص ميداني','Field inspection updated');
    if(/field\.issue/i.test(action))return L('تم تحديث مشكلة ميدانية','Field issue updated');
    if(/field\.constraint/i.test(action))return L('تم تحديث عائق تنفيذ','Execution constraint updated');
    if(/field\.submitted/i.test(action))return L('تم إرسال تقرير الموقع للمراجعة','Daily site report submitted');
    if(/field\.approved/i.test(action))return L('تم اعتماد تقرير الموقع','Daily site report approved');
    if(/field\.returned/i.test(action))return L('تم إرجاع تقرير الموقع','Daily site report returned');
    if(/approved/i.test(action))return L('تم الاعتماد','Approved');
    if(/rejected/i.test(action))return L('تم الإرجاع أو الرفض','Returned or rejected');
    if(/submitted/i.test(action))return L('تم الإرسال للمراجعة','Submitted for review');
    if(/saved|updated|changed/i.test(action))return L('تم التعديل','Updated');
    if(/created/i.test(action))return L('تم الإنشاء','Created');
    return action.replaceAll('_',' ').replaceAll('.',' · ')||L('تم التحديث','Updated');
  }
  function changeRow(c){
    const canFollow=['project','site','site_cabinet','engineering_drawing','document'].includes(c.entity_type),followed=canFollow&&isFollowed(c.entity_type,c.entity_id);
    return `<article class="ops-change-row entity-${e(c.entity_type)} ${importance(c)?'important':''}"><span class="ops-change-line"></span><span class="ops-row-icon">${icon(entityIcon(c.entity_type),15)}</span><button class="ops-change-main" data-action="ops-open-entity" data-type="${e(c.entity_type)}" data-id="${e(c.entity_id)}"><strong>${e(c.title||entityLabel(c.entity_type))}</strong><p>${e(changeText(c))}${contextLine(c)?` · ${e(contextLine(c))}`:''}</p><small>${e(profileName(c.actor_id))} · ${e(relativeTime(c.created_at))}</small></button>${canFollow?`<button class="icon-btn ops-follow ${followed?'active':''}" data-action="ops-toggle-follow" data-type="${e(c.entity_type)}" data-id="${e(c.entity_id)}" title="${followed?L('إلغاء المتابعة','Unfollow'):L('متابعة التغييرات','Follow changes')}">${icon('star',14)}</button>`:''}</article>`;
  }
  function miniChangeRow(c){return `<button class="ops-mini-change entity-${e(c.entity_type)}" data-action="ops-open-entity" data-type="${e(c.entity_type)}" data-id="${e(c.entity_id)}"><span class="ops-row-icon">${icon(entityIcon(c.entity_type),14)}</span><span><strong>${e(c.title||entityLabel(c.entity_type))}</strong><small>${e(changeText(c))} · ${e(relativeTime(c.created_at))}</small></span>${icon('chevron',12)}</button>`;}
  function followLabel(f){
    if(f.entity_type==='project')return state.projects.find(x=>x.id===f.entity_id)?.name||L('مشروع متابَع','Followed project');
    if(f.entity_type==='site')return state.sites.find(x=>x.id===f.entity_id)?.name||L('موقع متابَع','Followed site');
    if(f.entity_type==='engineering_drawing')return state.engineeringDrawings.find(x=>x.id===f.entity_id)?.title||L('رسم متابَع','Followed drawing');
    if(f.entity_type==='document')return state.documents.find(x=>x.id===f.entity_id)?.display_name||L('مستند متابَع','Followed document');
    return L('عنصر متابَع','Followed item');
  }
  function followCards(){const rows=arr(local.snapshot.follows).slice(0,8);if(!rows.length)return `<div class="ops-follow-empty">${icon('star',17)}<span>${L('اضغط النجمة بجوار أي تغيير مهم لمتابعة هذا العنصر هنا.','Use the star beside an important change to keep that item here.')}</span></div>`;return `<div class="ops-follow-grid">${rows.map(f=>`<button data-action="ops-open-entity" data-type="${e(f.entity_type)}" data-id="${e(f.entity_id)}"><span>${icon(entityIcon(f.entity_type),15)}</span><strong>${e(followLabel(f))}</strong><small>${e(entityLabel(f.entity_type))}</small></button>`).join('')}</div>`;}

  function sourceRail(){
    const approvals=arr(local.snapshot.approvals),changes=arr(local.snapshot.changes),tasks=arr(local.snapshot.tasks);
    const count=(types)=>approvals.filter(x=>types.includes(x.entity_type)).length+changes.filter(x=>types.includes(x.entity_type)&&importance(x)).length;
    const modules=[
      ['tasks','checkSquare',L('المهام','Tasks'),tasks.length,L('تكليفاتك ومواعيدك','Assignments & due dates')],
      ['files','file',L('الملفات','Files'),count(['document']),L('مراجعات وإصدارات CDE','CDE reviews & versions')],
      ['engineering','drafting',L('الرسومات','Drawings'),count(['engineering_drawing']),L('المراجعات والتغييرات','Revisions & changes')],
      ['delivery','archive',L('التسليم','Delivery'),count(['site_claim_package']),L('الأدلة والقرارات','Evidence & decisions')],
      ['projects','briefcase',L('المشاريع والمواقع','Projects & sites'),count(['project','site','site_cabinet']),L('السياق والتنفيذ','Context & execution')],
      ['field','hardHat',L('مساحة الموقع','Field Workspace'),count(['site','site_cabinet','engineering_drawing']),L('الرسم والحصر وتنفيذ الموقع','Drawing, takeoff & field execution')]
    ];
    return `<section class="ops-source-rail"><div class="ops-source-intro"><span>${icon('link',17)}</span><div><strong>${L('كل Optimum متصل هنا','Your Optimum work is connected here')}</strong><small>${L('لا ننسخ البيانات؛ كل بطاقة تفتح المصدر الحقيقي للمهمة أو الملف أو الرسم أو التسليم.','Nothing is duplicated; every card opens the real task, file, drawing, or delivery source.')}</small></div></div><div class="ops-source-grid">${modules.filter(([nav])=>(nav!=='tasks'||can('tasks.view'))&&(nav!=='field'||can('drawings.edit'))).map(([nav,ic,label,value,copy])=>`<button class="ops-source-${nav}" data-nav="${nav}"><span>${icon(ic,17)}</span><div><strong>${e(label)}</strong><small>${e(copy)}</small></div><b>${Number(value)||0}</b>${icon('chevron',12)}</button>`).join('')}</div></section>`;
  }

  function todayAgenda(){
    const now=new Date(),events=visibleCalendarEvents().filter(ev=>{const d=new Date(ev.start_at);return d.toDateString()===now.toDateString();}).slice(0,5);
    if(!events.length)return `<div class="ops-calm ops-agenda-empty">${icon('calendar',18)}<div><strong>${L('اليوم هادئ على التقويم','Your calendar is clear today')}</strong><small>${L('أي موعد من المهام أو المراجعات أو التسليم سيظهر هنا تلقائيًا.','Task, review, and delivery dates will appear here automatically.')}</small></div></div>`;
    return `<div class="ops-agenda-list">${events.map(ev=>`<button data-action="ops-open-entity" data-type="${e(ev.entity_type||(ev.kind==='task'?'task':''))}" data-id="${e(ev.id||'')}" ${ev.id?'':'disabled'}><i class="kind-${e(ev.kind||'task')}"></i><span><strong>${e(ev.title||entityLabel(ev.entity_type))}</strong><small>${e(new Intl.DateTimeFormat(i18n.locale==='ar'?'ar-EG':'en-GB',{hour:'2-digit',minute:'2-digit'}).format(new Date(ev.start_at)))} · ${e(entityLabel(ev.entity_type||(ev.kind==='task'?'task':'')))}</small></span>${ev.id?icon('chevron',12):''}</button>`).join('')}</div>`;
  }

  function todayView(){
    const tasks=arr(local.snapshot.tasks),today=tasks.filter(t=>isToday(t.due_at)||isOverdue(t)).slice(0,8),approvals=arr(local.snapshot.approvals).slice(0,5),changes=arr(local.snapshot.changes).filter(importance).slice(0,6),unread=arr(local.snapshot.notifications);
    return `<div class="ops-today-layout"><section class="ops-main-column"><section class="ops-section ops-focus-section"><header><div><span class="eyebrow">${L('التركيز الآن','FOCUS NOW')}</span><h3>${L('ابدأ بما يحتاج منك تصرفًا','Start with what needs your action')}</h3><p>${L('كل صف يفتح المهمة الأصلية بكل سياق المشروع والموقع والملفات المرتبطة.','Every row opens the original task with its project, site, and linked-file context.')}</p></div><button class="btn btn-ghost btn-sm" data-nav="tasks">${L('فتح المهام','Open tasks')}</button></header><div class="ops-work-list">${today.length?today.map(t=>taskRow(t)).join(''):emptyState('checkSquare',L('لا يوجد ضغط اليوم','Nothing pressing today'),L('لا توجد مهام متأخرة أو مستحقة اليوم.','No overdue tasks or tasks due today.'))}</div></section><section class="ops-section"><header><div><span class="eyebrow">${L('القرارات','DECISIONS')}</span><h3>${L('بانتظار مراجعتك أو اعتمادك','Waiting for your review or approval')}</h3><p>${L('راجع القرار من مصدره الحقيقي قبل الاعتماد؛ Optimum لا يفصل القرار عن مستنداته وسياقه.','Review decisions in their source workspace so context and evidence stay attached.')}</p></div><button class="btn btn-ghost btn-sm" data-action="ops-view" data-view="approvals">${L('عرض الكل','View all')}</button></header>${approvals.length?`<div class="ops-decision-list">${approvals.map(approvalRow).join('')}</div>`:emptyState('check',L('لا توجد قرارات معلقة','No pending decisions'),L('كل المراجعات والاعتمادات المسندة لك مغلقة حاليًا.','All reviews and approvals assigned to you are currently clear.'))}</section></section><aside class="ops-side-column"><section class="ops-side-card ops-agenda-card"><header><div><span class="eyebrow">${L('جدول اليوم','TODAY SCHEDULE')}</span><h3>${L('المواعيد في سياق واحد','Dates with their real context')}</h3></div><button data-action="ops-view" data-view="calendar">${L('التقويم','Calendar')}</button></header>${todayAgenda()}</section><section class="ops-side-card"><header><div><span class="eyebrow">${L('منذ آخر زيارة','SINCE LAST VISIT')}</span><h3>${L('ما الذي تغير؟','What changed?')}</h3></div><button data-action="ops-view" data-view="changes">${L('الكل','All')}</button></header>${changes.length?`<div class="ops-mini-changes">${changes.map(miniChangeRow).join('')}</div>`:`<div class="ops-calm">${icon('check',18)}<div><strong>${L('لا تغييرات مهمة جديدة','No important new changes')}</strong><small>${L('أنت متابع لآخر حالة.','You are up to date.')}</small></div></div>`}</section><section class="ops-side-card"><header><div><span class="eyebrow">${L('أتابع','WATCHING')}</span><h3>${L('المهم بالنسبة لي','Things I care about')}</h3></div><button data-action="ops-view" data-view="inbox">${unread.filter(actionNotification).length?`${unread.filter(actionNotification).length} ${L('تحتاج إجراء','need action')}`:L('الصندوق','Inbox')}</button></header>${followCards()}</section></aside></div>`;
  }
  function inboxView(){
    const overdue=arr(local.snapshot.tasks).filter(isOverdue),notifications=arr(local.snapshot.notifications),action=notifications.filter(actionNotification),updates=notifications.filter(n=>!actionNotification(n));
    return `<div class="ops-stack"><section class="ops-section"><header><div><span class="eyebrow">${L('يحتاج إجراء','ACTION REQUIRED')}</span><h3>${L('صندوق عمل واحد بدل التنقل بين الوحدات','One action inbox instead of jumping between modules')}</h3></div>${notifications.length?`<button class="btn btn-ghost btn-sm" data-action="ops-mark-all-read">${icon('check',13)} ${L('تعليم الإشعارات كمقروءة','Mark notifications read')}</button>`:''}</header><div class="ops-inbox-grid">${arr(local.snapshot.approvals).map(approvalRow).join('')}${overdue.map(t=>taskRow(t,{compact:true})).join('')}${action.map(notificationRow).join('')||emptyState('check',L('الصندوق هادئ','Inbox is clear'),L('لا شيء يحتاج قرارًا مباشرًا منك الآن.','Nothing needs a direct decision from you right now.'))}</div></section><section class="ops-section"><header><div><span class="eyebrow">${L('للعلم','FYI')}</span><h3>${L('تحديثات بدون مقاطعة يومك','Updates without interrupting your day')}</h3></div></header><div class="ops-inbox-grid">${updates.map(notificationRow).join('')||`<div class="ops-calm wide">${icon('bell',17)}<span>${L('لا توجد تحديثات جديدة.','No new updates.')}</span></div>`}</div></section></div>`;
  }
  function approvalsView(){const rows=arr(local.snapshot.approvals);return `<section class="ops-section ops-approvals-center"><header><div><span class="eyebrow">${L('مركز الاعتمادات','APPROVALS CENTER')}</span><h3>${L('كل القرارات المطلوبة منك في مكان واحد','Every decision assigned to you in one place')}</h3><p>${L('افتح العنصر في مساحته الأصلية لاتخاذ القرار مع كل السياق والمستندات.','Open the item in its source workspace to decide with full context and evidence.')}</p></div></header>${rows.length?`<div class="ops-decision-list large">${rows.map(approvalRow).join('')}</div>`:emptyState('shield',L('لا توجد موافقات معلقة','No pending approvals'),L('لا توجد مراجعات أو اعتمادات مسندة إليك الآن.','No reviews or approvals are assigned to you right now.'))}</section>`;}
  function changesView(){let rows=arr(local.snapshot.changes);if(local.importantOnly)rows=rows.filter(importance);return `<section class="ops-section ops-change-center"><header><div><span class="eyebrow">${L('مركز التغييرات','CHANGE CENTER')}</span><h3>${L('اعرف ما تغير بدون قراءة سجل تقني','Understand what changed without reading audit logs')}</h3><p>${local.snapshot.last_seen_at?`${L('منذ','Since')} ${e(formatDateTime(local.snapshot.last_seen_at))}`:''}</p></div><label class="ops-switch"><input type="checkbox" data-ops-important ${local.importantOnly?'checked':''}/><span></span>${L('المهم فقط','Important only')}</label></header><div class="ops-change-list">${rows.length?rows.map(changeRow).join(''):emptyState('activity',L('لا توجد تغييرات في هذا النطاق','No changes in this range'),L('يمكنك إظهار كل التحديثات بدل المهم فقط.','You can show all updates instead of important changes only.'))}</div></section>`;}
  function layerControls(){const map=[['tasks','checkSquare',L('المهام','Tasks')],['reviews','shield',L('المراجعات','Reviews')],['documents','file',L('المستندات','Documents')],['drawings','drafting',L('الرسومات','Drawings')],['delivery','archive',L('التسليم','Delivery')],['projects','briefcase',L('المشاريع','Projects')]];return `<div class="ops-calendar-layers">${map.filter(([key])=>key!=='tasks'||can('tasks.view')).map(([key,ic,label])=>`<label class="ops-layer ${local.snapshot.calendar_layers?.[key]!==false?'active':''}"><input type="checkbox" data-ops-layer="${key}" ${local.snapshot.calendar_layers?.[key]!==false?'checked':''}/>${icon(ic,13)}<span>${e(label)}</span></label>`).join('')}</div>`;}
  function calendarEventButton(ev){const type=ev.entity_type||(ev.kind==='task'?'task':null);const open=type&&ev.id;return `<${open?'button':'div'} class="ops-calendar-event kind-${e(ev.kind||'task')}" ${open?`data-action="ops-open-entity" data-type="${e(type)}" data-id="${e(ev.id)}"`:''}><i></i><span>${e(ev.title||entityLabel(type))}</span></${open?'button':'div'}>`;}
  function calendarView(){
    const events=visibleCalendarEvents(),c=local.calendar.cursor,y=c.getFullYear(),m=c.getMonth(),first=new Date(y,m,1),offset=(first.getDay()+6)%7,start=new Date(y,m,1-offset),cells=[];
    for(let i=0;i<42;i++){const d=new Date(start);d.setDate(start.getDate()+i);const dayEvents=events.filter(ev=>{const x=new Date(ev.start_at);return x.getFullYear()===d.getFullYear()&&x.getMonth()===d.getMonth()&&x.getDate()===d.getDate();});const today=new Date();const isTodayCell=today.toDateString()===d.toDateString();cells.push(`<div class="ops-calendar-cell ${d.getMonth()===m?'':'outside'} ${isTodayCell?'today':''}"><header><span>${d.getDate()}</span>${dayEvents.length?`<b>${dayEvents.length}</b>`:''}</header><div>${dayEvents.slice(0,4).map(calendarEventButton).join('')}${dayEvents.length>4?`<small>+${dayEvents.length-4}</small>`:''}</div></div>`);}
    const label=new Intl.DateTimeFormat(i18n.locale==='ar'?'ar-EG':'en-GB',{month:'long',year:'numeric'}).format(first);
    return `<section class="ops-section ops-calendar"><header class="ops-calendar-head"><div><span class="eyebrow">${L('التقويم الموحد','UNIFIED CALENDAR')}</span><h3>${L('شغّل فقط الطبقات التي تحتاجها','Turn on only the layers you need')}</h3><p>${L('المهام والمراجعات والمستندات والرسومات والتسليم ومواعيد المشاريع في مكان واحد.','Tasks, reviews, documents, drawings, delivery, and project dates in one place.')}</p></div><button class="btn btn-secondary btn-sm" data-nav="calendar">${L('تقويم المهام الكامل','Full work calendar')}</button></header>${layerControls()}<div class="ops-calendar-toolbar"><button class="icon-btn" data-action="ops-calendar-prev">${icon('chevronLeft',15)}</button><button class="btn btn-ghost btn-sm" data-action="ops-calendar-today">${L('اليوم','Today')}</button><h3>${e(label)}</h3><button class="icon-btn" data-action="ops-calendar-next">${icon('chevron',15)}</button></div>${local.calendarLoading?`<div class="ops-loading-inline"><span class="busy-dot"></span>${L('جارٍ تحديث التقويم…','Updating calendar…')}</div>`:`<div class="ops-calendar-weekdays">${(i18n.locale==='ar'?['الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد']:['Mon','Tue','Wed','Thu','Fri','Sat','Sun']).map(x=>`<span>${x}</span>`).join('')}</div><div class="ops-calendar-grid">${cells.join('')}</div>`}</section>`;
  }
  function page(){
    if(local.loading&&!local.loadedKey)return `${pageHeader(L('مركز التشغيل','Operations Center'),L('كل ما يحتاج منك إجراء اليوم في مكان واحد.','Everything that needs your action today, in one place.'))}<div class="ops-page-loading"><span class="busy-dot"></span><strong>${L('نجمع يومك من Optimum…','Building your day from Optimum…')}</strong></div>`;
    const tasks=arr(local.snapshot.tasks),today=tasks.filter(t=>isToday(t.due_at)).length,overdue=tasks.filter(isOverdue).length,approvals=arr(local.snapshot.approvals).length,changes=arr(local.snapshot.changes).filter(importance).length;
    const views=[['today','home',L('يومي','My day')],['inbox','bell',L('صندوق العمل','Inbox')],['approvals','shield',L('الاعتمادات','Approvals')],['changes','activity',L('ما الذي تغير؟','What changed?')],['calendar','calendar',L('التقويم','Calendar')]];
    const body=local.view==='inbox'?inboxView():local.view==='approvals'?approvalsView():local.view==='changes'?changesView():local.view==='calendar'?calendarView():todayView();
    return `${pageHeader(L('مركز التشغيل','Operations Center'),L('ابدأ يومك من هنا: المطلوب منك، القرارات، التغييرات، والمواعيد — وكل شيء يفتح مصدره الحقيقي داخل Optimum.','Start here: work, decisions, changes, and dates — every item opens its real source inside Optimum.'),`<button class="btn btn-secondary" data-action="ops-refresh" ${local.refreshing?'disabled':''}>${icon('refresh',14)} ${local.refreshing?L('جارٍ التحديث…','Refreshing…'):L('تحديث','Refresh')}</button>`)}<section class="ops-welcome ops-command-hero"><div class="ops-hero-copy"><span class="eyebrow">${L('مساحة تشغيلك الشخصية','YOUR OPERATING SPACE')}</span><h2>${e(currentGreeting())}، ${e((state.profile?.full_name||'').split(' ')[0]||L('أهلًا','welcome'))}</h2><p>${attentionCount()?L(`عندك ${attentionCount()} عناصر تحتاج انتباهك. رتّبنا المهم أولًا وربطنا كل عنصر بمصدره.`,`You have ${attentionCount()} items needing attention. Important work is first and linked to its source.`):L('لا يوجد شيء عاجل الآن. تقدر تكمل شغلك بهدوء، وكل التحديثات المهمة ستظهر هنا.','Nothing urgent right now. Keep working calmly; important updates will surface here.')}</p>${attentionCount()?`<button class="btn btn-primary ops-hero-action" data-action="ops-view" data-view="inbox">${icon('arrowRight',14)} ${L('ابدأ من صندوق العمل','Open my action inbox')}</button>`:''}</div><div class="ops-metrics">${metric('checkSquare',today,L('اليوم','Due today'))}${metric('alert',overdue,L('متأخرة','Overdue'),overdue?'danger':'')}${metric('shield',approvals,L('قرارات','Decisions'),approvals?'warning':'')}${metric('activity',changes,L('تغييرات مهمة','Important changes'),changes?'info':'')}</div></section>${sourceRail()}<nav class="ops-tabs" aria-label="${L('أقسام مركز التشغيل','Operations Center sections')}">${views.map(([key,ic,label])=>`<button class="${local.view===key?'active':''}" data-action="ops-view" data-view="${key}">${icon(ic,15)}<span>${e(label)}</span>${key==='inbox'&&attentionCount()?`<b>${attentionCount()}</b>`:''}</button>`).join('')}</nav>${body}`;
  }

  async function openApproval(kind,id){if(kind==='access_change_request'){replaceRoute('roles');render();toast('info',L('افتح قسم طلبات الوصول للمراجعة','Open access requests to review'));return;}await navigateToEntity(kind,id);}
  async function openNotification(id){const n=arr(local.snapshot.notifications).find(x=>String(x.id)===String(id));if(!n)return;const readAt=new Date().toISOString();await api.update('notifications',{id:`eq.${n.id}`},{read_at:readAt},{returning:false}).catch(()=>{});local.snapshot.notifications=local.snapshot.notifications.filter(x=>String(x.id)!==String(id));const globalN=arr(state.notifications).find(x=>String(x.id)===String(id));if(globalN)globalN.read_at=readAt;render();if(n.entity_type&&n.entity_id)await navigateToEntity(n.entity_type,n.entity_id);}
  async function handleAction(action,el){
    if(!action?.startsWith('ops-'))return false;
    if(action==='ops-view'){local.view=el.dataset.view||'today';render();if(local.view==='calendar'&&!local.calendar.events.length)loadCalendar();return true;}
    if(action==='ops-refresh'){local.refreshing=true;local.loadedKey='';render();await load({force:true,mark:false});return true;}
    if(action==='ops-open-entity'){await navigateToEntity(el.dataset.type,el.dataset.id);return true;}
    if(action==='ops-open-approval'){await openApproval(el.dataset.kind,el.dataset.id);return true;}
    if(action==='ops-open-notification'){await openNotification(el.dataset.id);return true;}
    if(action==='ops-mark-all-read'){await api.rpc('mark_all_notifications_read',{p_company_id:state.companyId});const readAt=new Date().toISOString();arr(state.notifications).forEach(n=>{if(!n.read_at)n.read_at=readAt;});local.snapshot.notifications=[];render();toast('success',L('تم تعليم الإشعارات كمقروءة','Notifications marked read'));return true;}
    if(action==='ops-toggle-follow'){const followed=await api.rpc('toggle_entity_follow',{p_company_id:state.companyId,p_entity_type:el.dataset.type,p_entity_id:el.dataset.id,p_follow:null});const key=followKey(el.dataset.type,el.dataset.id);local.snapshot.follows=arr(local.snapshot.follows).filter(f=>followKey(f.entity_type,f.entity_id)!==key);if(followed)local.snapshot.follows.push({entity_type:el.dataset.type,entity_id:el.dataset.id,created_at:new Date().toISOString()});render();toast('success',followed?L('تمت إضافة المتابعة','Now following'):L('تم إلغاء المتابعة','Unfollowed'));return true;}
    if(action==='ops-calendar-prev'){local.calendar.cursor=new Date(local.calendar.cursor.getFullYear(),local.calendar.cursor.getMonth()-1,1);await loadCalendar();return true;}
    if(action==='ops-calendar-next'){local.calendar.cursor=new Date(local.calendar.cursor.getFullYear(),local.calendar.cursor.getMonth()+1,1);await loadCalendar();return true;}
    if(action==='ops-calendar-today'){const d=new Date();local.calendar.cursor=new Date(d.getFullYear(),d.getMonth(),1);await loadCalendar();return true;}
    return false;
  }
  async function handleChange(ev){
    if(ev.target.matches('[data-ops-important]')){local.importantOnly=ev.target.checked;render();return true;}
    if(ev.target.matches('[data-ops-layer]')){const key=ev.target.dataset.opsLayer;local.snapshot.calendar_layers={...local.snapshot.calendar_layers,[key]:ev.target.checked};render();try{local.snapshot.calendar_layers=await api.rpc('save_operations_calendar_layers',{p_company_id:state.companyId,p_layers:local.snapshot.calendar_layers});render();}catch(err){formError(err,L('تعذر حفظ طبقات التقويم','Could not save calendar layers'));}return true;}
    return false;
  }
  const help=()=>[
    L('ابدأ من «يومي»: سنجمع لك المهام والقرارات والتغييرات المهمة بدل أن تبحث عنها في كل وحدة.','Start with My Day: Optimum combines your work, decisions, and important changes so you do not hunt across modules.'),
    L('صندوق العمل يفرق بين ما يحتاج إجراء منك وبين تحديثات للعلم فقط.','The Inbox separates action-required items from FYI updates.'),
    L('في «ما الذي تغير؟» استخدم النجمة لمتابعة مشروع أو رسم أو مستند مهم بالنسبة لك.','In What Changed, use the star to follow a project, drawing, or document you care about.'),
    L('في التقويم شغّل أو أخفِ الطبقات حسب ما تحتاج بدل إغراق الشهر بكل الأحداث.','In Calendar, turn layers on or off instead of flooding the month with every event.')
  ];
  return {page,load,reset,handleAction,handleChange,help,state:local,get attentionCount(){return attentionCount();}};
}
