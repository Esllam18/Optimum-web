# Performance R2 — Critical CSS & Safe Route Styles

## الهدف
خفض CSS المحمّل في أول فتح لتطبيق العميل بدون تغيير الشكل، الصلاحيات، الـbackend أو Supabase.

## قواعد الأمان
- `assets/styles.css` تظل المصدر القانوني الوحيد ولا يعاد تنسيقها أو serialize لها.
- `app/globals.css` و`public/assets/styles.css` يظلان مرآة للملف القانوني.
- `index.html` المصدرية تظل تحمل CSS الكاملة لضمان local/dev fallback.
- التحويل إلى R2 يحدث فقط داخل build artifact (`public/index.html` و`dist/index.html`).
- Platform Console تظل على CSS الكاملة في R2.
- أي selector غير مثبت أنه مملوك لوحدة واحدة يبقى Core.
- `@keyframes`, `@font-face` وأي at-rule غير آمن للتقسيم يبقى Core.
- فشل تحميل أي route stylesheet يفعل fallback إلى `styles.css` الكاملة.
- لا يوجد أي تعديل في Supabase أو RLS أو business logic.

## مجموعات CSS المؤجلة
- Engineering
- Work / Tasks / Calendar
- Management: Operations Center + Project Control
- Field: Site Supervisor
- Platform-only CSS يُستبعد من Client core لكن Platform Console نفسها تستمر بالـCSS الكاملة.

## Gates
- Core CSS <= 700 KiB hard gate.
- Cold CSS reduction >= 20%.
- Client route CSS deferred >= 120 KiB.
- selector coverage = 100%.
- Full Release يجب أن يظل PASS.
- Performance R1 يجب أن يظل PASS.
- Preview browser/network certification مطلوبة قبل أي Production promotion.

الهدف الطموح للـCore هو <= 600 KiB، لكن لا يتم التضحية بالـvisual fidelity للوصول للرقم.
