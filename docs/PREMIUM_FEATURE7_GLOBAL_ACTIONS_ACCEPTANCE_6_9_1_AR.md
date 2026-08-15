# Optimum 6.9.1 — Point 8 Acceptance
## Global Search + Notifications + Command / Quick Create

**الحالة:** PASS  
**الخط الإنتاجي:** Optimum 6.9 — لا يوجد انتقال إلى V7.  
**النشر:** هذا الـCheckpoint غير منشور بعد على Production؛ الموقع الحي ما زال نسخة 6.9 السابقة للتحسينات الـPremium.

## الهدف
تحويل البحث الشامل والإشعارات والإنشاء السريع من أدوات منفصلة ومتزاحمة إلى **Global Action Layer** واحدة هادئة وسريعة ومبنية على الصلاحيات، مع الحفاظ على عقود البحث والـdeep links الحالية.

## ما تم تبسيطه أو إلغاؤه
- لم تعد إجراءات الإنشاء تتكرر أعلى نتائج البحث أثناء الكتابة.
- Quick Create لم يعد يعرض روابط تنقل أو Setup تحت اسم “Create”.
- أزيلت قائمة الإشعارات المسطحة التي تساوي بين كل التحديثات.
- لم تتم إضافة Priority وهمية إلى قاعدة البيانات؛ تصنيف Attention واجهي وشفاف مشتق فقط من `notification.type` الحالي.
- لم تتم إضافة أنواع بحث غير مدعومة في `global_search` الحالي، لذلك لا يوجد Claim/Cabinet search وهمي.

## ما تم إضافته وتحسينه
### 1. Command Layer
- `Ctrl/Cmd + K` يفتح طبقة واحدة: Search / Go to / Create.
- الحالة الافتراضية مقسمة إلى **Create** و **Go to**.
- البحث الفعلي يعرض النتائج فقط بدون تكرار Quick Create.
- النتائج مجمعة حسب الكيان: Projects, Sites, Work, Documents, Folders, Engineering Drawings.
- Team member search الحالي محفوظ ومتكامل داخل نفس الطبقة.
- حد نتائج RPC خُفض إلى 30 لتقليل العمل غير الضروري في الواجهة.
- Debounce أصبح 180ms.
- أضيف `commandSearchEpoch` لمنع استجابة بحث أقدم وأبطأ من استبدال نتائج Query أحدث.
- Arrow Up/Down + Enter مدعومة بالكامل داخل نتائج الأوامر.

### 2. Quick Create
- الإجراءات تظهر فقط عندما تكون الصلاحية الفعلية متاحة.
- Work: New work.
- Projects: Create project.
- Organization: Add member / Create role / Create organization unit حسب الصلاحيات.
- على الموبايل لا يوجد Trigger إضافي مزاحم؛ Command هو طبقة الإجراء الأساسية.

### 3. Attention Inbox
- الإشعارات أصبحت ثلاث مجموعات مفهومة:
  - Needs attention
  - Updates
  - Earlier
- Unread state واضح بصريًا ولا يعتمد على اللون فقط.
- الكيان والوقت ظاهرين بدون Metadata زائدة.
- Mark all read يظهر فقط عندما يوجد Unread.
- فتح Notification غير مقروء يحدث `read_at` في الـbackend ثم يحدث الحالة المحلية فورًا لتصحيح عداد الجرس بدون Refresh.
- Deep links الحالية إلى Project/Task/Document/... محفوظة.

### 4. Responsive / UX
- Command dialog على الهاتف له هامش فعلي 8px ولا يخرج خارج viewport.
- تمت معالجة حالة scrollbar في الـoverlay التي كانت تزحزح الحوار 4px خارج الشاشة في الاختبار الأول.
- Quick Create actions تتكدس بوضوح على الهاتف.
- Notification drawer داخل 390px بدون horizontal overflow.

## عقود Backend المحفوظة
- `global_search`
- `resolve_entity_context`
- `mark_all_notifications_read`
- جدول `notifications`
- Permissions / entitlements الحالية
- Organization member search
- Project / Site / Folder / Document / Task / Engineering deep links

لم يتطلب Point 8 Migration جديدة على Supabase.

## اختبارات القبول
### Premium Point 8
- `npm run test:premiumf7` — PASS
- `npm run test:browser:global` — PASS Desktop + Mobile

### Cross-feature browser regression
- `npm run test:browser:core` — PASS
- `npm run test:browser:policy` — PASS
- `npm run test:browser:work` — PASS
- `npm run test:browser:excellence` — PASS
- `npm run test:browser:pdc` — PASS
- `npm run test:browser:site` — PASS بعد إعادة تشغيل runner منفصل إثر EPIPE من Playwright، بدون Assertion من التطبيق
- `npm run test:browser:cad` — PASS، desktop/mobile/archived overflow = 0px

### Release
- `npm run test:release` — PASS
- System contract audit: 252 actions / 57 forms / 116 RPCs — PASS
- Free-plan auth baseline — PASS
- Production build — PASS
- Zero-dependency runtime bundle — PASS

## Visual proofs
- `/mnt/data/optimum691-feature7-global-command-desktop-proof.png`
- `/mnt/data/optimum691-feature7-global-command-mobile-proof.png`
- `/mnt/data/optimum691-feature7-attention-inbox-desktop-proof.png`
- `/mnt/data/optimum691-feature7-attention-inbox-mobile-proof.png`

## قرار القبول
**POINT 8 / FEATURE 7 = PASS.**

الانتقال المسموح التالي: **Point 9 — Dashboard**.
