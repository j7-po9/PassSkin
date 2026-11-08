# بطاقتي — PassSkin

تطبيق iOS يغيّر صور بطاقات Wallet (بطاقات المتاجر، الولاء، العضوية، التذاكر) بدون تسجيل وبدون إدخال أي معلومة.

## طريقة عمله
1. المستخدم يشارك البطاقة من Wallet إلى التطبيق (أو يختار ملف `.pkpass`)
2. يختار صور جديدة: الشعار / البانر / الخلفية / الصورة الجانبية / الأيقونة
3. يضغط «أضف إلى Wallet» → تنضاف نسخة بنفس الباركود والبيانات وبالشكل الجديد

## بناء الـ IPA (بدون Mac)
1. ارفع المجلد كامل على مستودع GitHub (خاص)
2. تبويب **Actions** → **Build IPA** → **Run workflow**
3. بعد ما يخلص (~5–10 دقايق) نزّل `PassSkin-unsigned-ipa` من أسفل الصفحة
4. وقّعه ووزّعه بنفس طريقتك المعتادة

على Mac: `brew install xcodegen && xcodegen generate` ثم افتح `PassSkin.xcodeproj`.

## الشهادة (لازم عشان Wallet يقبل البطاقة)
1. developer.apple.com → Identifiers → **Pass Type IDs** → سوّ واحد (مثلاً `pass.com.yourstore.passskin`)
2. سوّ له شهادة ونزّلها، وصدّرها من Keychain كـ `pass.p12`
3. نزّل **Apple WWDR G4** من https://www.apple.com/certificateauthority/ وسمّه `AppleWWDRCAG4.cer`
4. حط الملفين في `PassSkin/Resources/`
5. عدّل `PassSkin/Config.swift`: `passTypeIdentifier` و `teamIdentifier` و `p12Password`

> لو طلع خطأ في قراءة pass.p12، حوّله إلى PEM:
> ```
> openssl pkcs12 -in pass.p12 -clcerts -nokeys -out passcert.pem -legacy
> openssl pkcs12 -in pass.p12 -nocerts -nodes -out passkey.pem -legacy
> ```
> وحط `passcert.pem` و `passkey.pem` بدال الـ p12.

بدال ما ترفع الشهادة مع الكود، تقدر تحطها في GitHub Secrets:
`PASS_P12_BASE64` و `WWDR_CER_BASE64` (الناتج من `base64 -i pass.p12`).

⚠️ المفتاح الخاص يكون داخل التطبيق، فأي أحد عنده الـ IPA يقدر يستخرجه. لو بتوزعه على نطاق واسع، الأفضل تنقل التوقيع لسيرفر.

## ملاحظات
- بطاقات البنك (Apple Pay) ما يمكن تغيير شكلها — قيد من Apple
- النسخة الجديدة ما توصلها تحديثات الجهة الأصلية (مثل تغيير البوابة أو الرصيد)
- بعض البطاقات الجهة مانعة مشاركتها من Wallet، وهذي ما تظهر لها خيار المشاركة

## الملفات
| الملف | الوظيفة |
|---|---|
| `PassPackage.swift` | فك ملف pkpass وقراءة بياناته |
| `ImageSlot.swift` | أماكن الصور ومقاساتها وتجهيزها @1x/@2x/@3x |
| `PassBuilder.swift` | بناء البطاقة الجديدة + manifest + الضغط |
| `PassSigner.swift` | التوقيع PKCS#7 عبر OpenSSL |
| `EditorView.swift` | شاشة التعديل والمعاينة والإضافة لـ Wallet |
| `Config.swift` | إعدادات الشهادة |
