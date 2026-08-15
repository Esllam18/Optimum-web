# Optimum 6.9.1 — Core Point 9–10 R1
## Product Consolidation + Role-aware Home + Site Claim Package

**الحالة النهائية:** REVIEW READY / LIVE BACKEND VERIFIED / FULL RELEASE PASS / BROWSER PASS  
**Baseline:** Point 11 Management Intelligence R1  
**Frontend Production deployment:** **NO — لم يتم نشر الواجهة تلقائيًا**  
**Supabase migrations:** **APPLIED LIVE + VERIFIED**

---

# 1) لماذا هذه النقطة؟

بعد Points 8–11 تراكمت محركات مفيدة، لكن جزءًا منها ظهر كوجهات مستقلة في الـSidebar:
- مركز التشغيل.
- التحكم بالمشاريع.
- مساحة الموقع.

هذا زاد تعقيد المنتج بصريًا.

Core Point 9–10 ترجع Optimum إلى الخطة الأصلية:
- **الرئيسية هي مركز الدخول الوحيد حسب الدور.**
- Project Control يعيش داخل Project 360.
- Site Supervisor Workspace تصبح Home للمشرف.
- محركات Operations / Project Control / Site Execution تبقى موجودة وقوية، لكن لا تزاحم المستخدم كوحدات مستقلة.
- المستخلص يعود إلى معناه الصحيح الحالي: **حزمة مستندات Site واحدة**، بلا تسعير أو Commercial automation.

---

# 2) Navigation Consolidation

تم إزالة الوجهات التالية من التنقل المرئي:
- مركز التشغيل.
- التحكم بالمشاريع.
- مساحة الموقع.

لم يتم حذف المحركات أو البيانات.

Deep links القديمة بقيت متاحة داخليًا للتوافق مع bookmarks والاختبارات، لكنها لا تظهر للمستخدم كـModules منفصلة.

الـSidebar النهائي أصبح أبسط، بينما الوظائف القديمة تظهر فقط في السياق الصحيح.

---

# 3) Role-aware Home

## Owner / Manager
الرئيسية تعرض:
- قرارات تحتاج تدخلًا.
- قائمة التركيز.
- Project Health / Pulse summary.
- ما الذي تغير؟
- صندوق الانتباه.
- سعة مساحة العمل عند الصلاحية.

Project Health في Home مجرد Summary.
التحليل الكامل يبقى داخل Project 360.

## Site Supervisor
الرئيسية نفسها تتحول إلى:
**مساحة مشرف الموقع**

وتعرض:
- Site الحالي.
- المهام.
- الرسومات.
- الحصر.
- الفحوصات.
- المشاكل والعوائق.
- الأدلة والملفات.
- Daily / End-of-Day execution.
- Cabinets.

لا يحتاج المشرف فتح Module منفصل باسم “مساحة الموقع”.

## Personal / Engineer
الرئيسية تبقى مركزة على العمل المسموح للمستخدم فقط.

---

# 4) Project Control داخل Project 360

Project 360 تحتوي الآن مدخلًا واضحًا:
**تحكم المشروع**

ومن داخل المشروع يمكن فتح:
- Health / Pulse.
- Progress.
- Risks.
- Milestones.
- Team bottlenecks.
- Weekly Brief.

ولا توجد حاجة إلى صفحة “التحكم بالمشاريع” مستقلة في الـSidebar.

---

# 5) Operations Engine بعد الدمج

Operations Center لم تُحذف.

محركاتها ما زالت تغذي:
- My Day / Focus.
- Approvals.
- What Changed.
- Notifications.
- Calendar layers.
- Follow / Watch.

تم إصلاح Contract حقيقي أثناء Browser QA:
`operations-center.js` أصبح يExpose read-only `state` للـRole-aware Home، حتى تعرض الرئيسية “ما الذي تغير؟” من المصدر الحقيقي بدل إعادة حسابه أو نسخه.

---

# 6) المستخلص — التعريف الحالي الصحيح

**المستخلص = حزمة مستندات Site واحدة.**

الـSite قد تحتوي Cabinet واحدة أو أكثر.

في هذه المرحلة لا نهتم بمحتوى المستند المالي أو طريقة إعداده.
Optimum يجمع ما تم إنتاجه ورفعه أثناء العمل.

الأنواع الأساسية الحالية:
- أمر التكليف.
- بيان أمر التكليف.
- As-Built.
- الحصر الحالي الخارج من CAD كما هو.
- Test Sheet.
- شهادة الجودة.
- شهادة الضمان.
- الفاتورة المرفوعة كما هي.
- مستندات Project إضافية.
- مستندات داعمة إضافية.

---

# 7) ما لم يتم بناؤه عمدًا

**لا يوجد الآن:**
- أسعار بنود.
- Unit Rates.
- Quantity × Rate.
- Contract item mapping.
- VAT / Tax / Discount.
- Commercial valuation.
- Invoice generation.

الحصر الحالي يدخل كملف.
الفاتورة تدخل كملف مرفوع.

هذه حدود المرحلة ومثبتة في الـUI والـStatic/Production guards.

---

# 8) تصنيف المستند عند الرفع

Quick Upload وDocument 360 يدعمان:

### تلقائي
Optimum يحاول استنتاج علاقته بالمستخلص من نوعه وسياقه.

### أضف للمستخلص
المستخدم يؤكد دخوله ويمكنه تحديد نوع المستند.

### استبعد
الملف يبقى في CDE، لكنه لا يدخل المستخلص.

**لا يتم إنشاء نسخة ثانية من الملف.**

الملف canonical في CDE، والمستخلص يحتفظ Reference فقط.

---

# 9) حماية Version Upload

تم Hardening مهم:

رفع Version جديدة لمستند موجود **لا يغير تصنيف المستند للمستخلص تلقائيًا**.

التصنيف يظل ثابتًا ما لم يغيره المستخدم صراحة من Document 360.

وعند اختيار `Automatic` بدون نوع صريح، يتم مسح النوع اليدوي القديم والعودة إلى inference الحقيقي.

---

# 10) Future Site Seed

تم تحديث:
`app_private.ensure_default_site_claim_package`

أي Site جديدة مستقبلًا تحصل على نفس نموذج المستخلص الحالي، وليس الـrequirements القديمة.

Required:
- work_order
- work_order_statement
- as_built_drawings
- quantity_survey
- test_sheet
- quality_certificate
- warranty_certificate
- invoice

Optional:
- project_documents
- supporting

المتطلبات القديمة التي لم تعد جزءًا إلزاميًا من التعريف الحالي تم جعلها Optional للتوافق مع البيانات السابقة.

---

# 11) Claim Readiness

شاشة المستخلص تعرض:
- Project scope.
- Site scope.
- Cabinet scope.
- عدد الملفات.
- جاهزية المتطلبات.
- **ما الذي ينقص؟**

بدل مطالبة المستخدم بالبحث داخل المجلدات.

إذا نقص مستند:
Optimum يحدد نوعه مباشرة.

إذا اكتملت المستندات:
يظهر أن الحزمة جاهزة للتجهيز.

---

# 12) تجهيز المستخلص

زر:
**تجهيز حزمة المستخلص**

ينفذ:

1. Refresh للـrequirements والملفات المصنفة.
2. Freeze للـVersions الحالية.
3. قراءة Export Manifest الدقيق.
4. تحميل الملفات canonical من CDE.
5. إنشاء `INDEX.html`.
6. إنشاء `MANIFEST.json`.
7. إنشاء ZIP منظم.
8. تنزيل ZIP.
9. تسجيل عملية التجهيز في `site_claim_exports`.

---

# 13) ZIP Structure

Browser Acceptance نزّلت ZIP حقيقية وفتحتها باستخدام Python `zipfile`.

تم التحقق فعليًا من وجود:

```text
INDEX.html
MANIFEST.json
01 - مستندات المشروع / Project Documents
02 - مستندات الموقع / Site Documents
03 - الكبائن / Cabinets
```

والـManifest احتوت:
- Package ID الصحيح.
- العناصر الفعلية.
- Exact version IDs.
- Storage paths.
- Scope.
- Cabinet context.

الـZIP ليست UI mock.

نسخة الاختبار المعتمدة مرفقة مع Artifacts.

---

# 14) Frozen Versions

بعد تجهيز الحزمة:

المستخلص يستخدم **الإصدارات المثبتة**.

إذا رُفعت Version أحدث لاحقًا:
- الحزمة القديمة لا تتغير في صمت.
- يمكن إنشاء حزمة جديدة بعد المراجعة.

وهو نفس مبدأ Version Control المستخدم في CDE.

---

# 15) Export History

تم إنشاء:
`site_claim_exports`

يحتفظ بـ:
- Package.
- وقت التجهيز.
- المستخدم.
- عدد الملفات.
- Manifest hash عندما يكون متاحًا.
- Note.

الجدول:
**RLS = true**

ولا يسمح للعميل بالكتابة المباشرة؛ الكتابة عبر RPC محمية فقط.

---

# 16) Live Supabase

تم تطبيق Live:

1. `point9_10_consolidated_home_site_claim_package`
2. `point9_10_site_claim_future_seed_fix`

Live verification أكد:
- documents.claim_inclusion_mode موجود.
- documents.claim_requirement_key موجود.
- site_claim_exports عليها RLS.
- public classification/refresh/manifest/export RPCs موجودة.
- authenticated grants صحيحة.
- private document classifier غير متاحة مباشرة للعميل.
- private future-site seed غير متاحة للعميل.
- الحزم الحالية تم تحديث requirements الخاصة بها.
- Future site seed يحتوي Work Order Statement / Test Sheet / Invoice وغيرها.

---

# 17) Browser Acceptance — Core Point 9–10

آخر تشغيل **بعد Final Full Release**:

# PASS

يغطي:

### Management Home
- Role-aware Home.
- لا Operations/Control/Field nav.
- Project management summary.
- What Changed.
- No horizontal overflow.

### English / LTR
- Management Home native English.
- Direction = LTR.

### Project 360
- Project Control inline.
- Weekly Brief entry.

### Site Supervisor
- Dashboard تتحول إلى Site Workspace.
- لا Field nav مستقلة.
- Field actions موجودة.

### Site Claim
- Clarified phase boundary.
- Readiness.
- Missing items.
- Prepare package.
- Actual ZIP download.
- ZIP integrity.
- Manifest integrity.
- Freeze exact versions.
- Export history.

### Document 360
- Explicit claim classification.
- Exclude tested via RPC.

### English Claim UI
- Site Claim Packages.
- No-pricing/document-assembly message.
- LTR.

### Mobile
- 390px.
- Claim drawer usable.
- No page horizontal overflow.

---

# 18) Legacy / Cross-feature Regression

بعد الدمج تم تشغيل:

- Point 3 Project/Site/Cabinet — PASS.
- Point 4 Tasks — PASS (كل Flow منفصل؛ long Playwright batch واجه EPIPE مرة، وكل flows المنفصلة PASS).
- Point 5 CDE Upload/Version/Restore — PASS.
- Point 6 Engineering Owner/Reviewer/Viewer/Mobile — PASS.
- Point 7 Delivery regression — PASS.
- Point 8 Operations — PASS.
- Point 9 Site Supervisor — PASS.
- Point 10 Site Execution — PASS.
- Point 11 Project Control — PASS.
- Site Delivery Owner/Limited/Mobile/Premium — PASS.
- Global Search/Actions — PASS.
- Dashboard — PASS.
- CAD Desktop/Mobile/Archived — PASS / **0px overflow**.

الاختبارات القديمة التي كانت تطلب `add-document-claim` أو `claim-lifecycle` أو أسماء CSS القديمة تم تحديثها لاختبار السلوك الجديد الأقوى بدل إعادة UI ملغاة.

---

# 19) Full Release FINAL

آخر:

`npm run test:release`

# **FULL PASS**

### System Contract Audit
- **354 actions**
- **73 forms**
- **175 RPCs**

لا يوجد:
- Action بلا Handler.
- Form بلا Handler.
- RPC frontend بلا عقد Migration معروف.

### Engineering regression داخل نفس Release
- 500 nodes.
- 499 routes.
- Validation ≈ **243 ms**
- Takeoff ≈ **40 ms**
- DXF ≈ **442 ms**
- Independent DXF certification = **PASS**
- AC1015 / 76 entities.

Production build: **PASS**  
Zero-dependency production runtime: **PASS**  
No runtime npm dependency added.

---

# 20) Runtime Mirror Integrity

Final SHA checks:

- `assets/app.js` = `public/assets/app.js`
- `assets/operations-center.js` = public mirror
- `assets/project-control.js` = public mirror
- `assets/site-supervisor.js` = public mirror
- `assets/engineering.js` = public mirror
- `assets/styles.css` = `public/assets/styles.css`
- `assets/styles.css` = `app/globals.css`
- `assets/styles.css` = `platform-console/assets/styles.css`

---

# 21) Runtime delta vs Point 11 R1

| Asset | Raw delta | Gzip delta |
|---|---:|---:|
| app.js | +27,824 B | +8,849 B |
| operations-center.js | +12 B | +5 B |
| project-control.js | +28 B | +7 B |
| site-supervisor.js | +0 B | +0 B |
| styles.css | +10,382 B | +1,344 B |
| **Total** | **+38,246 B** | **+10,205 B** |

لا توجد Runtime npm dependency جديدة.

---

# 22) النتيجة التنظيمية

بهذه النقطة نرجع للخطة الأساسية:

- لا Module جديد باسم Point 11 أو 12.
- محركات 8–11 السابقة أصبحت Extensions داخل الأماكن الطبيعية.
- Home حسب الدور.
- Project intelligence داخل Project 360.
- Field execution داخل Home المشرف.
- مستخلص الموقع عاد إلى Site document package البسيطة المطلوبة حاليًا.

# **CORE POINT 9–10 = COMPLETE / READY FOR USER REVIEW**

Frontend production deployment remains **NO**.
