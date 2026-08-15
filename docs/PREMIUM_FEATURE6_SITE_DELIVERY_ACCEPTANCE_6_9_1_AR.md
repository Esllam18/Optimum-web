# Optimum 6.9.1 — النقطة 7: Site Delivery + Claim Intelligence

## حالة القبول

**PASS — مغلقة وظيفيًا وبصريًا وتقنيًا في الـcheckpoint الحالي.**

هذا القبول لا يعني أن نسخة الـPremium الحالية رُفعت إلى Production؛ هو قبول للـworking checkpoint قبل مرحلة النشر النهائية.

## الهدف

تحويل Site Delivery من مجموعة مؤشرات وتقارير متفرقة إلى مسار تشغيل واضح:

**وحدة تسليم → دليل Canonical في CDE → متطلب Claim → Freeze Snapshot → Submit/Review → Approval**

بحيث يعرف المستخدم فورًا:

1. ما الذي ينقص التسليم؟
2. ما الذي يعطل الجاهزية؟
3. ما الدليل المرتبط بكل متطلب؟
4. ما حالة الإصدار المستخدم؟
5. ما الخطوة التالية الآمنة؟

## ما تم تحسينه

### Site Delivery 360
- Hero أصغر وأهدأ مع سياق المشروع/المدير/المنطقة الزمنية.
- شريط جاهزية خطي بدل تكرار Progress ring كبيرة.
- أربع إشارات قرار فقط: وحدات التسليم، الأدلة الأساسية، جاهزية المستخلص، عوائق التسليم.
- Cabinets أعيد تقديمها كـDelivery Units مرتبطة مباشرة بعدد الأدلة في المستخلص.
- Final Claim card أصبحت تعرض **Next Action** والمفقود وتغطية الكابينات بدل KPIs متكررة.
- CTA للمستندات أصبح "أدلة ومستندات الموقع" لتوضيح دوره في مسار التسليم.

### Claim 360
- Hero يوضح أن CDE هو المصدر الوحيد للحقيقة وأن Freeze يثبت الإصدارات ولا ينسخ الملفات.
- إضافة **Next Action decision card** تتغير حسب lifecycle:
  - Collect missing evidence
  - Fix invalid versions
  - Freeze versions
  - Submit
  - Reopen after rejection
  - Await review
  - Approved record
- Lifecycle أصبح واضحًا: تجميع الأدلة → تجميد الإصدارات → التقديم والمراجعة → الاعتماد.
- Mobile lifecycle يعرض الأربع مراحل 2×2 بدون مرحلة مخفية أو horizontal overflow.
- Decision metrics مقتصرة على: Missing required، Cabinet coverage، Submission snapshot.
- Evidence checklist ترتب المتطلبات الأساسية الناقصة أولًا، ثم المكتمل والاختياري.
- كل مستند يوضح هل الإصدار الحالي Ready أو أن نسخة التسليم Frozen.
- Auto collect / Freeze / Submit / Reopen ظلت contextual ومحمية بالصلاحيات والحالة.

## ما لم يتم تغييره عمدًا

- لا نسخ للمستندات داخل Claim؛ `document_id` يظل Canonical reference للـCDE.
- Freeze semantics و`selected_version_id` لم تتغير.
- Archived project/site contexts تظل Read-only.
- Owner/limited permissions لم تتغير.
- RPC contracts الحالية لم تتغير.
- Cabinet standard six-folder workspace لم يتغير.

## التوافق والـRegression

تم الحفاظ على العقود القديمة، بما فيها:
- `SITE DELIVERY 360`
- `SITE DELIVERY PACKAGE`
- `CABINET 360`
- `site_360`
- `cabinet_360`
- `site_claim_package_360`
- `add_document_to_site_claim`
- `auto_collect_site_claim`
- `freeze_site_claim_package`
- `reopen_site_claim_package`
- `submit_site_claim_package`

## Gates المنفذة

### Static / Contract
- `npm run test:premiumf6` — PASS
- `npm run test:site69` — PASS
- `node tests/site-delivery-production-hardening-6.9.mjs` — PASS
- `npm run test:release` — PASS
- Production zero-dependency build/runtime — PASS

### Browser
- Site owner — PASS
- Site limited — PASS
- Site mobile — PASS
- Premium Site Delivery desktop/mobile — PASS
- Project/PDC owner/limited/mobile — PASS
- Premium Project Context — PASS
- Premium CDE — PASS
- Work owner/limited — PASS
- Work excellence/mobile — PASS
- CAD desktop RTL — PASS, overflow 0px
- CAD mobile RTL — PASS, overflow 0px
- CAD archived/read-only — PASS, overflow 0px

## أدلة بصرية

- `/mnt/data/optimum691-feature6-site-delivery-desktop-proof.png`
- `/mnt/data/optimum691-feature6-site-delivery-mobile-proof.png`
- `/mnt/data/optimum691-feature6-claim360-desktop-proof.png`
- `/mnt/data/optimum691-feature6-claim360-mobile-proof.png`

## قرار القبول

**Point 7 / Feature 6 — Site Delivery + Claim Intelligence: PASS.**

الخطوة التالية حسب الخطة: **Point 8 — Global Search + Notifications + Command / Quick Create.**
