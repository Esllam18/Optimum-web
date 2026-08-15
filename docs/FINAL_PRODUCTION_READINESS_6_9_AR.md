# Optimum 6.9.0 — حالة الجاهزية النهائية للإنتاج

**التاريخ:** 12 أغسطس 2026  
**الحالة:** Release Candidate — Free Plan Hardened. الكود وقاعدة البيانات جاهزان للرفع، وميزة Supabase Leaked Password Protection غير متاحة على الخطة المجانية وتم تصنيفها كـ platform limitation مقبولة مع ضوابط تعويضية.

## ما تم إغلاقه

- جميع اختبارات `npm run test:release` ناجحة، بما فيها Core وOrganization وAccess وWork وCDE وCAD وSite Delivery وClaims وPlatform Console.
- Browser regression ناجح على Desktop / Mobile / RTL / Limited permissions.
- CAD: Desktop + Mobile + Archived read-only ناجح، وقياس overflow = 0px.
- Production runtime مبني كحزمة Node static بدون runtime npm dependencies.
- Client وPlatform Console لهما Health endpoints، CSP، HSTS، ETag، compression، 304 caching وSPA deep-link fallback.
- لا يوجد Service Role أو Secret Supabase key في أي frontend bundle.
- آخر migrations الحية موجودة في الريبو بنفس أرقام الـledger.
- Live authenticated Supabase smoke نجح للـOwner ولـEngineer محدود الصلاحيات.
- Mutation smoke داخل transactions مع Rollback أثبت السماح/المنع حسب الصلاحيات.
- RPCs الخاصة بـ`service_role` غير قابلة للتنفيذ بواسطة `anon` أو `authenticated`.
- Supabase Performance Advisor لا يحتوي Performance WARN؛ رسائل unused indexes INFO فقط.

## Supabase Free Plan — القرار الأمني

`Leaked Password Protection` ميزة مدفوعة في Supabase وليست متاحة على Free. لذلك لا تعتبر Blocker للرفع في هذه النسخة. بدلًا منها تم تثبيت ضوابط تعويضية داخل Optimum نفسه:

1. لا يوجد Public Sign-up؛ الحسابات تُنشأ فقط من Platform/Company administration.
2. كلمات المرور المؤقتة مولدة cryptographically وبطول قوي وتُعرض مرة واحدة، مع إجبار تغييرها في أول دخول.
3. First-login / recovery password policy أصبحت **12 حرفًا على الأقل** وتلزم: uppercase + lowercase + digit + special symbol.
4. نفس السياسة مطبقة **server-side** داخل `identity-provisioning` و`identity-provisioning-v55` وليس في الواجهة فقط.
5. Edge Functions الخاصة بالهوية `verify_jwt=true`، مع origin allow-list.
6. RLS / resource-scoped permissions / member-security privacy controls تظل طبقة الحماية الأساسية للبيانات.

ميزة leaked-password detection نفسها غير موجودة على Free، لذلك يبقى هذا **Accepted Platform Risk** وليس ادعاءً بأنها مفعلة. عند الترقية مستقبلًا إلى Pro يمكن تفعيلها بدون إعادة تصميم التطبيق.

## Security Advisor — التفسير

تحذيرات `authenticated_security_definer_function_executable` متوقعة في هذه المعمارية لأن التطبيق يستخدم RPC command/query surface مقصودة. تم فحص الـsurface بحثًا عن Functions قابلة للمستخدم بدون auth/permission guards؛ لم يظهر مسار غير مصرح به. `invitation_preview` فقط متاح للـanon بشكل مقصود ويعمل بتوكن طويل مخزن كـSHA-256، و`resolve_engineering_review_mark` wrapper لوظيفة update المحمية.

## قرار الإصدار

- **Code gate:** PASS
- **Database / RLS / RPC gate:** PASS
- **Browser / Responsive / RTL gate:** PASS
- **Production bundle gate:** PASS
- **Reproducibility / migration source gate:** PASS
- **Secret scan:** PASS
- **Free-plan password hardening:** PASS
- **Leaked Password Protection:** ACCEPTED PLATFORM LIMITATION — Free Plan
- **Final production approval:** ينتظر فقط ضبط الدومين/Origins النهائي وتشغيل post-deploy smoke على النسخة المنشورة.

لا توجد حاجة للاشتراك في Supabase Pro لإكمال رفع هذه النسخة.
