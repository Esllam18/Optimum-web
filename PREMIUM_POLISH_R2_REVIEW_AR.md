# Optimum 6.9.1 — Premium Polish & Experience Cleanup R2

**الحالة:** REVIEW READY  
**القاعدة:** Premium Polish Dashboard + Tasks R1  
**Production:** لم يتم استبداله بهذه النسخة بعد  
**الهدف:** تنضيف الهوية والـShell، إزالة التكرار، رفع جودة Dashboard وTasks، وتقوية UX بدون إضافة Feature جديدة أو كسر العقود الحالية.

## ما تم في R2

### 1. Brand / Shell
- فصل هوية **Optimum** عن هوية الشركة/Workspace.
- Optimum product mark ظاهر في الأماكن المناسبة بدون تكرار مزعج.
- Company switcher أصبح واضحًا كـ **مساحة الشركة / Company Workspace**.
- في حالة وجود شركة واحدة، لا يظهر الـswitcher كأنه Dropdown بلا وظيفة.
- Topbar subtitle أصبح سياقيًا بدل تكرار اسم الشركة.
- Account menu أصبح: Optimum identity + Settings + Switch company عند الحاجة + Sign out فقط.
- **Platform Console لا يظهر في Account menu** ولا يتسرب إلى تجربة المستخدم العادي.
- تحديث هوية favicon في Platform surfaces إلى الهوية المعتمدة.

### 2. Dashboard R2
- تقليل التكرار بين Management Decisions وFocus Queue وAttention Inbox.
- قرارات الإدارة تعرض فقط الإشارات الإدارية التي تحتاج تدخلًا فعليًا.
- Overdue/Blocked task urgency تبقى في Focus Queue بدل تكرارها في أكثر من Card.
- Notification urgency تبقى في Attention Inbox بدل تكرارها كقرار إداري.
- عدم إظهار بطاقة “كل شيء سليم” لمجرد ملء المساحة.
- Hero أبسط: الشركة + الدور + Source-of-truth context، بدون تكرار أرقام موجودة أسفل الصفحة.
- Desktop/Mobile وRTL/LTR تمت مراجعتها.

### 3. Tasks R2
- Hero أبسط وملخصه: Open / In Progress / Due Today.
- Needs Attention مستقل لـ Overdue / Blocked / Reviews / Approvals.
- Daily rail يعرض Focus / Today / Tomorrow / Unscheduled بدل تكرار Overdue/Blocked.
- Board cards تعرض **نص الحالة + نص الأولوية** إلى جانب اللون، فلا تعتمد UX على اللون فقط.
- ألوان دلالية للحالة والأولوية مع accent واضح للكروت والأعمدة.
- Work 360 drawer يحمل هوية Optimum ويأخذ tone من حالة/أولوية المهمة.

### 4. Error / Reliability polish
- تحسين رسالة تعذر الاتصال لتكون مفهومة وتوضح أن البيانات المكتوبة لن تضيع.
- الحفاظ على كل backend/RPC/permissions contracts الحالية.
- لم تتم إضافة runtime dependency جديدة.

## الاختبارات
- `npm run test:polishr2` — PASS
- `npm run test:brand` — PASS
- `npm run test:premiumf8` — PASS
- `npm run test:point4` — PASS
- Browser Premium Dashboard — PASS
- Browser Point 4 Simple Owner — PASS
- Browser Foundation Responsive — PASS
- **`npm run test:release` — FULL PASS**

### Full Release Contract
- Actions: **354**
- Forms: **73**
- RPCs: **175**
- Foundation V2: PASS
- Feature 0: PASS
- Points 2 → Core Point 9–10: PASS
- CDE / CAD / Site Delivery / Platform Console hardening: PASS
- Production runtime build: PASS
- Zero runtime npm dependencies: PASS
- Engineering DXF certification: PASS — **AC1015 / 76 entities**

## Visual acceptance
تمت مراجعة:
- Dashboard Desktop
- Dashboard Mobile
- Tasks Desktop
- Tasks Board
- Tasks Mobile
- Account Menu
- Work 360 drawer

## قرار الإصدار
**R2 جاهز للمراجعة كـ checkpoint، لكنه لم يُرفع فوق Production الحالي.**  
الخطوة التالية هي استكمال Premium Polish لباقي الأسطح والحالات (empty/error/loading + باقي الصفحات) ثم Preview مستقل قبل استبدال Production.
