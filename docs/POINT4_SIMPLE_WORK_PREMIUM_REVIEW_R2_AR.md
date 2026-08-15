# Optimum 6.9.1 — Point 4 Premium Review R2
## المهام — Daily Work Canvas + Intelligent Assistance

**الحالة:** REVIEW READY / TECHNICAL PASS  
**سبب R2:** المستخدم لم يعتمد R1 بصريًا ووظيفيًا؛ R2 إعادة بناء لتقوية التجربة، وليست Patch تجميلي.  
**Production deployment:** NOT DEPLOYED automatically.

---

## ما الذي كان ناقصًا في R1؟

R1 نجحت في إزالة زحام Work OS، لكنها أصبحت هادئة أكثر من اللازم:
- فراغ بصري كبير.
- لا يوجد إحساس قوي بـ“يوم العمل”.
- الذكاء موجود لكنه مدفون داخل التفاصيل.
- Team / Board / Calendar / Context لم تكن جزءًا من تجربة يومية واحدة.
- قائمة المهام كانت أقرب إلى List محسنة من كونها مساحة تنفيذ فعلية.

R2 تعالج هذا بدون العودة إلى Dashboard مزدحمة.

---

## 1) Today Workspace

صفحة **اليوم** أصبحت مساحة تنفيذ حقيقية.

المهام تُقسم تلقائيًا إلى:
- **تركيز اليوم**
- **متأخرة**
- **مستحقة اليوم**
- **بدون موعد**

لا يتم تكرار المهمة في أكثر من قسم.

الهدف: المستخدم لا يحتاج قراءة قائمة طويلة ليعرف ماذا يفعل.

---

## 2) My Day Rail

على Desktop توجد لوحة صغيرة ثابتة باسم **يومي**، وليست Dashboard.

تعرض فقط:
- عدد مهام Focus.
- مستحق اليوم.
- المتأخر.
- المتوقف.

وتحتها:
- **رتّب يومي**
- **أفضل خطوة تالية**
- وصول سريع للتقويم.

على Mobile يعاد ترتيبها أسفل المهام المهمة بدل الضغط على مساحة الشاشة.

---

## 3) Plan My Day — اقتراح ذكي غير ملزم

زر **رتّب يومي** يرتب اقتراحًا يصل إلى خمس مهام فقط بناءً على:
- التأخير.
- الموعد اليوم.
- الأولوية.
- Blocking.
- Review / Approval.
- downstream impact.

هذا يغير **Today Focus المحلي فقط**.

لا يغيّر:
- Priority في قاعدة البيانات.
- Assignment.
- Due date.
- Status.

ويمكن للمستخدم تغيير النجوم أو مسح Focus بالكامل في أي وقت.

---

## 4) Quick Composer 2.0

إضافة المهمة أصبحت أقرب لتجربة Notion/Todo apps:

تكتب:
**اكتب المهمة واضغط Enter…**

والخيارات السريعة بجانبها:
- الموعد.
- الأولوية.

وعند الحاجة فقط تفتح **تفاصيل**:
- المسؤول.
- المشروع.
- الموقع.
- الكابينة.
- تاريخ محدد.

لو المهمة تُنشأ من Project / Site / Cabinet، السياق يظل موروثًا تلقائيًا.

---

## 5) Tasks grouped by meaning

### Upcoming
لا تصبح قائمة زمنية طويلة.

تقسم إلى:
- غدًا.
- هذا الأسبوع.
- لاحقًا.

### All my work
تقسم إلى:
- قيد التنفيذ.
- مطلوبة.
- متوقفة.

### Team
تقسم حسب الشخص، وتظهر بجوار كل شخص إشارة بسيطة للمتأخر والمتوقف.

---

## 6) List / Board — اختيار المستخدم

أضيف View toggle بسيط:

- **List**: العرض الافتراضي والأهدأ.
- **Board**: To do / In progress / Blocked / Done.

Board ليست Cockpit جديدة ولا تجبر المستخدم على Kanban.

هي مجرد طريقة عرض اختيارية لنفس البيانات.

---

## 7) Task rows أصبحت أكثر فائدة بدون زحام

السطر الواحد يعرض:
- Checkbox / completion.
- اسم المهمة.
- Project / Site / Cabinet كـcontext chips.
- Priority فقط عندما تكون مهمة/عاجلة.
- Status عند الحاجة.
- Due date.
- Progress صغير إذا كان هناك تقدم فعلي.
- Owner في Team view.

إجراءات Hover/Inline:
- **ابدأ المهمة**.
- **قسّمها إلى خطوات**.
- **أضف/أزل من تركيز اليوم**.

---

## 8) Start task مباشرة

المهمة في To do يمكن بدء تنفيذها من السطر نفسه.

يظهر Pending state فورًا.

يتم تحويلها إلى:
**قيد التنفيذ**

باستخدام canonical `set_task_status` contract.

لا يحتاج المستخدم فتح Edit Form فقط ليقول “بدأت”.

---

## 9) كيف أنفذها؟

داخل Task Detail أضيف زر:

**كيف أنفذها؟**

يعرض Guidance عمليًا مبنيًا على نوع المهمة وسياقها.

أمثلة:
- مراجعة الرسومات.
- جاهزية الموقع.
- التنفيذ.
- الاختبار.
- Evidence.
- Review / Handover.

أو للمستندات:
- Collect sources.
- Verify version/completeness.
- Draft.
- Review.
- Final link.

الإرشاد:
- غير إلزامي.
- لا يغير المهمة.
- يمكن تحويله لاحقًا إلى Checklist فقط بموافقة المستخدم.

---

## 10) Smart Breakdown مستمر

**ساعدني أقسمها** ما زال موجودًا.

الفرق الآن أن الذكاء له مسارين واضحين:
- **كيف أنفذها؟** → شرح.
- **ساعدني أقسمها** → Subtasks/Checklist قابلة للاختيار والتعديل.

لا يوجد Automatic execution.

---

## 11) Next Best Action

أفضل خطوة تالية أصبحت جزءًا من My Day بدل Card كبيرة في منتصف الواجهة.

يعرض:
- اسم المهمة.
- سبب الاقتراح.
- زر **ابدأ الآن**.

الهدف أن يساعد، لا أن يحتل الصفحة.

---

## 12) Optional Extra Tasks

المهام الإضافية لا تختلط مع التكليفات الأساسية.

تبقى Collapsible section:
**مهام إضافية متاحة**

والمستخدم يمكنه استلامها فقط إذا سمحت الصلاحيات والسياسة.

---

## 13) Calendar

Calendar R1 improvements محفوظة بالكامل:
- Day / Week / Month / Agenda.
- Drag-to-reschedule.
- Immediate “جارٍ تحديث الموعد…”.
- Canonical save contract.
- rollback-safe behavior عند الفشل.

---

## 14) Permission-aware UI

R2 لم تتراجع عن قاعدة Point 3/4:

- لا صلاحية → العنصر مختفٍ.
- صلاحية + شرط يمنع → Disabled + سبب.
- Approval required → يظهر مع حالته.
- Backend / RLS / RPC authoritative دائمًا.

Team view والأدوات الإدارية لا تظهر للمستخدم المحدود.

---

## 15) Localization

R2 UI الجديدة مكتوبة عربي/English من المصدر.

لا يوجد:
- Work OS wording للمستخدم.
- Raw permission keys في الواجهة اليومية.
- خلط عربي/إنجليزي في labels الجديدة.

الأسماء والأكواد المدخلة من المستخدم قد تبقى باللغة التي كتبها بها.

---

## 16) Responsive

Browser QA تم على:
- Desktop.
- 390px Mobile.

تم التحقق من:
- no horizontal overflow.
- Today layout.
- task rows.
- Day Rail.
- Permission-aware mobile.
- Board remains desktop/tablet friendly.
- Composer details تتحول إلى viewport-safe panel على الشاشات الصغيرة.

---

## 17) Point 3 focus crash

إصلاح:
`Cannot read properties of null (reading 'focus')`

ما زال داخل R2 وRegression test ما زال PASS.

---

## 18) Validation

### Point 4 Browser QA
- `simple-owner` — PASS.
- `calendar-progress` — PASS.
- `context-focus-regression` — PASS.
- `mobile-permissions` — PASS.

الـsimple-owner flow الآن يغطي أيضًا:
- Day planner.
- Today Focus.
- List/Board.
- Team grouping.
- How-to guidance.
- Smart breakdown.
- Quick Add.
- Essentials-first edit.

### Full `npm run test:release`
**PASS بالكامل.**

يشمل:
- Foundation.
- Point 2.
- Point 3.
- Point 4.
- CDE.
- CAD.
- Site Delivery / Claims.
- Global Actions.
- Dashboard.
- Platform Console.
- Production hardening.
- Production build.
- Zero-dependency production runtime.

### System contract audit
- **266 actions**
- **57 forms**
- **116 RPCs**

---

## 19) R2 size delta vs R1

| Asset | Raw delta | Gzip delta |
|---|---:|---:|
| work-os.js | +11,515 B | +2,518 B |
| styles.css | +17,553 B | +2,351 B |
| **Total** | **+29,068 B** | **+4,869 B** |

لا توجد Runtime npm dependency جديدة.

---

## 20) Acceptance

**R1:** NOT USER APPROVED  
**R2 technical:** PASS  
**R2 browser:** PASS  
**Full release:** PASS  
**Visual review:** READY FOR USER  
**Production:** NOT DEPLOYED  
**Point 5:** لا ننتقل إليها قبل اعتماد المستخدم لـPoint 4.
