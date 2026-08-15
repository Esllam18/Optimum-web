# Optimum 6.9.0 — Production Deployment Runbook

## 1) المتطلبات

- Node.js 20.9 أو أحدث.
- HTTPS أمام التطبيق في الإنتاج.
- Supabase project الحالي ومهاجراته مطبقة حتى `20260812132231_phase6_9_member_security_scope_fix`.
- لا تحتاج `npm install` لتشغيل حزم `dist` أو `dist-platform`.

## 2) Client deployment

ارفع محتويات مجلد `dist/` إلى الخادم، ثم:

```bash
cd dist
HOST=127.0.0.1 PORT=4173 node server.mjs
```

ضع Nginx/Cloudflare/Load Balancer أمامه واربط HTTPS بالدومين النهائي. Health check:

```text
GET /health
```

ويجب أن يعيد JSON يحتوي `ok: true` و`release: 6.9.0`.

## 3) Platform Console

يوجد خياران:

- **مدمج:** `/platform` من نفس Client bundle.
- **منفصل:** ارفع `dist-platform/` وشغله على process/domain منفصل. Platform Console يستخدم `PLATFORM_PORT` (وليس `PORT`). مثال:

```bash
cd dist-platform
HOST=127.0.0.1 PLATFORM_PORT=4174 OPTIMUM_CLIENT_APP_URL=https://app.example.com/ node server.mjs
```

عند الفصل مرّر `OPTIMUM_CLIENT_APP_URL` لعنوان التطبيق الرئيسي.

## 4) لا تضع Secrets في الواجهة

المسموح في frontend فقط هو Supabase **publishable key**. لا تضف `sb_secret_*` أو `service_role` أو database password لأي ملف داخل `dist` أو `dist-platform`.

## 5) Post-deploy smoke

من source checkpoint:

```bash
OPTIMUM_CLIENT_URL=https://app.example.com \
OPTIMUM_PLATFORM_URL=https://platform.example.com \
node scripts/post-deploy-smoke.mjs
```

ولو Platform مدمج في نفس الدومين:

```bash
OPTIMUM_CLIENT_URL=https://app.example.com node scripts/post-deploy-smoke.mjs
```

الاختبار يفحص health، release version، security headers، SPA deep links، ETag/cache، 404 assets وPlatform shell.

## 6) Supabase بعد النشر

- افتح Security Advisor وتأكد أن لا توجد findings جديدة غير المراجعة المقصودة الخاصة بـSECURITY DEFINER RPC architecture.
- على Supabase Free: Leaked Password Protection غير متاحة وتم قبولها كـ platform limitation مع سياسة Optimum التعويضية (12+ حرف، uppercase/lowercase/digit/symbol، first-login mandatory). عند الترقية إلى Pro فعّلها كتحسين إضافي، وليست blocker للرفع الحالي.
- راقب Auth/Postgres/Edge logs في أول فترة تشغيل.
- لا تحذف unused indexes بناءً على INFO فقط؛ اجمع usage evidence أولًا.

## 7) Rollback

Rollback للواجهة: استبدل مجلد الحزمة بالإصدار السابق وأعد تشغيل process.  
Rollback لقاعدة البيانات لا يتم تلقائيًا بعكس migrations؛ أي rollback schema/data يجب أن يكون migration جديدة مدروسة. النسخة الحالية تتضمن مصادر migrations الحية في source checkpoint لإعادة البناء والاسترجاع.
