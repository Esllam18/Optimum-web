# Optimum 6.9.1 — Feature 5 Premium Engineering / CAD Acceptance

## الحالة
**FEATURE 5 — PASS**

> هذا قبول مرحلي لمساحة Engineering/CAD على خط Optimum 6.9، وليس اعتماد Production نهائي للتطبيق كله.

## النطاق
- Engineering register
- Drawing Studio / CAD editor
- Element library
- Properties / validation inspector
- Routes & cables dock
- Minimap / zoom / fit
- Notes & review
- Revision governance
- Takeoff / BOQ
- Save to Files / export
- Archived read-only context
- Desktop + compact mobile workspace

## الهدف
إبقاء الشيت هو مركز تجربة الرسم، وتقليل المساحة المأخوذة من الأدوات، مع الحفاظ على كل القدرات الهندسية الحالية ودقة الرسم والتصدير والمراجعات والتكامل مع Projects / Sites / CDE.

## أهم قرارات إعادة التشكيل
- Mobile أصبح Canvas-first بدل محاولة عرض Palette + Canvas + Inspector + Routes في نفس الوقت.
- عند فتح الرسم على viewport مضغوط يتم إخفاء اللوحات الثانوية تلقائيًا ثم Fit للشيت.
- Elements / Properties / Routes تعمل كلوحة واحدة في كل مرة على Mobile مع backdrop واضح للإغلاق.
- Fit range على Mobile يسمح بإظهار كامل الشيت والفريم بدل قصه خارج الشاشة.
- Route Dock الافتراضي على Desktop أصبح أقل ارتفاعًا ويظل قابلًا للـresize.
- الحفاظ على Tool / Edit / View / Panel hierarchy وعلى Save to Files / Export كإجراءات رئيسية.
- الحفاظ على Validation / Smart Fix / Auto Layout / Route Optimizer / Review / Revision History / Frame setup.
- لا تغيير لعقود Supabase أو revision locking أو DXF/SVG/print contracts.

## Governance / Integration
محفوظ بالكامل:
- Project / Site context.
- CDE linked documents and Save to Files.
- Drawing revision lifecycle.
- optimistic lock / expected lock version.
- approved/archived read-only behavior.
- Notes & review register.
- Takeoff / BOQ generation.
- DXF / SVG / print exports.

## Responsive / Performance
- CAD desktop RTL: no horizontal overflow.
- CAD mobile RTL: no horizontal overflow.
- Mobile panels use single-panel presentation rather than a wide multi-column canvas.
- Full-sheet framing is performed after compact viewport mount.
- Reduced default route dock footprint increases usable canvas area.

## Acceptance gates
PASS:
- `npm run test:premiumf5`
- `npm run test:browser:cad`
- `npm run test:release`
- CAD desktop RTL
- CAD mobile RTL
- CAD archived read-only
- Production build
- Zero-dependency runtime
- CDE / Site Delivery / Platform / Auth regression contracts

## Visual proof
- `/mnt/data/optimum691-feature5-cad-desktop-proof.png`
- `/mnt/data/optimum691-feature5-cad-mobile-proof-final.png`
- `/mnt/data/optimum691-feature5-cad-mobile-elements-proof.png`
- `/mnt/data/optimum691-feature5-cad-mobile-properties-proof.png`
- `/mnt/data/optimum691-feature5-cad-mobile-routes-proof.png`

## القرار
**FEATURE 5 — PASS**

المحطة التالية: Site Delivery + Claim Intelligence.
