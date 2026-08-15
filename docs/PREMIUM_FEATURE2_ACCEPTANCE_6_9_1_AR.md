# Optimum 6.9 — Feature 2 Premium Acceptance

## النطاق
Projects + Project 360 + Sites + Site Delivery 360 + Cabinets + Cabinet 360 + نماذج الإنشاء/التعديل، مع الحفاظ على الربط القائم مع CDE وWork وCAD وSite Claim.

## الهدف
تحويل المشروع والموقع والكابينة إلى سلسلة سياق واضحة: Portfolio → Project 360 → Site 360 → Cabinet 360، وتقليل العناصر الاستعراضية لصالح مؤشرات تشغيلية وإجراءات مباشرة، دون تغيير عقود البيانات أو الصلاحيات أو منطق الـClaim Intelligence.

## ما تم تحسينه
- تحويل Portfolio من Hero تسويقي كبير إلى شريط هادئ ومضغوط للمحفظة.
- تصحيح عدّاد Active ليحسب المشاريع النشطة فعليًا بدل كل غير المؤرشف.
- إبراز Planned / On Hold كحالة تحتاج انتباه بدل إخفائها داخل إجمالي عام.
- تبسيط بطاقات المشاريع وتقليل الحركة والفراغ والوصف الافتراضي غير المفيد.
- إعادة بناء Project 360 حول Project Pulse: Sites / Open Work / Overdue / Documents.
- نقل Cabinets / Drawings / Claims / Blocked إلى شريط سياق ثانوي بدلاً من ستة KPI متساوية الأهمية.
- تصغير Project Health من دائرة كبيرة إلى chip واضح مع الحفاظ على عقد 6.8.
- تحسين Site rows لتعرض الحالة والسياق والكابينات وحالة المستخلص بشكل أكثر قابلية للمسح البصري.
- إعادة بناء Site 360 حول Cabinets + Open Work + Overdue + Documents، مع إبقاء Drawings/Storage كبيانات ثانوية.
- الإبقاء على Final Site Claim مرتبطًا بالموقع دون إعادة تصميم منطق المستخلص قبل Feature 6.
- جعل Cabinet workspace هو محور Cabinet 360 والإبقاء على بنية المجلدات القياسية الستة.
- تصحيح تسمية زر العمل في Site/Cabinet إلى Project Work لأن Work OS الحالي يدعم Project filter فقط؛ لم يتم ادعاء Site/Cabinet scoped work قبل دعمه فعليًا.
- إعادة تنظيم نماذج Project/Site/Cabinet إلى أقسام: الهوية، المسؤولية/التشغيل، الجدول، وتفاصيل متقدمة اختيارية.
- نقل الإحداثيات والمنطقة الزمنية إلى Advanced location details في Site، والإحداثيات والملاحظات إلى Advanced في Cabinet.
- الحفاظ على Workspace Blueprint في إنشاء المشروع وعلى auto-provisioned Cabinet workspace.
- تحسين responsive وتقليل intrinsic width، مع عدم وجود horizontal overflow في 390px.

## ما لم يتم تغييره عمدًا
- Supabase RPC contracts وحقول save_project / save_site / save_site_cabinet.
- صلاحيات create/edit/archive/reactivate والـread-only behavior.
- منطق Final Site Claim ومتطلبات المستخلص؛ مؤجل لFeature 6.
- Work OS filter model؛ ما زال Project-scoped ويُعرض للمستخدم بوضوح.
- روابط Files / Documents / CAD / Claims الحالية.

## اختبارات ثابتة جديدة
- `tests/premium-project-context-6.9.1.mjs`
- npm script: `test:premiumf2`
- أضيف إلى `test:release`.

## Browser Gate دائم جديد
- flow: `premiumf2` في `tests/browser-workflows-5.3.py`
- أضيف إلى `test:browser:pdc`.
- يتحقق من Portfolio/Project/Site/Cabinet على Mobile 390px وDesktop، وسلسلة التنقل، وعدد مؤشرات Pulse، ومجلدات Cabinet، والنماذج، وعدم وجود overflow.

## نتيجة القبول
- `npm run test:release`: PASS
- PDC owner / limited / mobile: PASS
- Site Delivery owner / limited / mobile: PASS
- Premium F2 browser: PASS
- Core / Organization / Limited / Mobile / Premium F1: PASS
- Adaptive policy / Platform desktop / Platform mobile: PASS
- Work owner / limited / excellence / mobile: PASS
- CAD desktop RTL / mobile RTL / archived read-only: PASS
- Production build + zero-dependency runtime: PASS

## القرار
**FEATURE 2 — PASS**

هذا قبول لFeature 2 فقط، وليس اعتمادًا نهائيًا لكل التطبيق أو Production Approved.
