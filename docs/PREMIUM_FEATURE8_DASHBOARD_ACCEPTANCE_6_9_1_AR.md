# Optimum 6.9.1 — Point 9 / Premium Decision Dashboard Acceptance

الحالة: **PASS**

## الهدف
تحويل الصفحة الرئيسية من لوحة إحصاءات عامة ومكررة إلى Decision Cockpit هادئ يوضح خلال ثوانٍ ما يحتاج قرارًا، وما يجب تنفيذه الآن، وأي مشروع يستحق النظر، مع احترام الصلاحيات والسياق الحقيقي للبيانات.

## ما تم حذفه أو دمجه
- إزالة الـ Welcome hero الكبير من Dashboard.
- إزالة شبكة KPIs العامة: المشاريع/المواقع/الأعضاء/الملفات/المهام.
- إزالة Quick Actions المكررة؛ الإنشاء أصبح مسؤولية Global Action Layer.
- إزالة Storage ring الكبيرة.
- إزالة Workspace Policy strip الدائمة؛ الخطة والسعة أصبحت Workspace Health صغيرة وقرارية.
- عدم تكرار Work OS dashboard بالكامل داخل الصفحة الرئيسية.
- إخفاء Recent Activity من شاشة الهاتف فقط لأنها منخفضة الأولوية وتزيد طول الصفحة، مع بقائها متاحة في سجل النشاط.

## ما تم إضافته
- Decision signals تظهر فقط عند وجود سبب حقيقي للتدخل:
  - عمل متأخر/متوقف/مستحق اليوم.
  - Notification غير مقروء ويحتاج قرارًا.
  - مشروع تجاوز Target End ولم يصل 100%.
  - مشكلات وصول مؤسسي لمن يملك صلاحية معالجتها.
  - وصول أحد حدود الباقة للسعة.
- Focus Queue للعمل الحالي مع deep-link إلى Work Item 360.
- Project Pulse مختصر مع الحالة والموعد والتقدم وdeep-link إلى Project 360.
- Attention Inbox preview يستخدم نفس notification/entity contract للنظام.
- Workspace Health بسيط لمن يملك صلاحيات تشغيلية/إدارية فقط.
- Recent Activity مختصر على Desktop/Tablet لمن يملك audit.view.

## الصلاحيات
- لا تظهر Notifications بدون notifications.view.
- لا تظهر مساحة السعة الإدارية للمستخدم المحدود.
- لا يظهر Activity بدون audit.view.
- Projects/Work تختفي أو تظهر طبقًا للصلاحيات الفعلية.
- لا توجد أرقام Claims/CDE مخترعة؛ Dashboard يستخدم فقط البيانات التي يحملها النظام بثقة.

## الاختبارات
- `npm run test:premiumf8` — PASS.
- `npm run test:browser:dashboard` — Owner Desktop / Limited / 390px Mobile — PASS.
- Deep links: Work Item 360 / Project 360 / Notification entity navigation — PASS.
- Browser Core / Organization / Limited / Mobile — PASS.
- Adaptive Policy / Platform Desktop & Mobile — PASS.
- Work owner/limited/premium/mobile — PASS.
- Projects/CDE owner/limited/mobile — PASS.
- Site Delivery owner/limited/mobile/premium — PASS.
- CAD desktop/mobile/archived — PASS, horizontal overflow = 0px.
- Full `npm run test:release` — PASS.
- Production zero-dependency build/runtime — PASS.

## الأدلة البصرية
- `/mnt/data/optimum691-feature8-dashboard-desktop-proof.png`
- `/mnt/data/optimum691-feature8-dashboard-mobile-proof.png`

## قرار القبول
**Point 9 — Dashboard = PASS**

لا يتم رفع هذا الـcheckpoint وحده إلى Production قبل إغلاق Point 10 وإجراء الاعتماد النهائي متعدد الميزات.
