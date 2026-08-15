# Optimum 6.9.0 — Supabase Free Plan Security Baseline

هذه النسخة مصممة لتكون قابلة للنشر على Supabase Free بدون اعتبار Leaked Password Protection بوابة مانعة، لأنها غير متاحة على الخطة المجانية.

الضوابط التعويضية الملزمة في Optimum:
- Invite/admin-provisioned accounts only; no public signup.
- Cryptographically generated temporary credentials with mandatory first-login change.
- 12+ character new-password policy.
- Uppercase + lowercase + number + special symbol required.
- Policy enforced client-side and Edge Function server-side.
- JWT required on identity Edge Functions.
- Origin allow-list on identity flows.
- RLS/resource-level authorization remains authoritative for application data.

المخاطرة المقبولة: النظام لا يستطيع مقارنة كلمة المرور المختارة مع قاعدة بيانات كلمات المرور المسربة الخاصة بـSupabase/HIBP على Free. يجب تنبيه المستخدمين بعدم إعادة استخدام كلمات المرور، ويمكن تفعيل الميزة الأصلية لاحقًا عند الترقية إلى Pro.
