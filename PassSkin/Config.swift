import Foundation

/// ⚙️ الإعدادات — عدّلها لما تجهز شهادة Pass Type ID.
enum Config {
    /// نفس الـ Identifier اللي سويته في developer.apple.com (يبدأ بـ pass.)
    static let passTypeIdentifier = "pass.com.yourstore.passskin"

    /// Team ID حق حساب المطور (10 حروف/أرقام)
    static let teamIdentifier = "XXXXXXXXXX"

    // الملفات داخل مجلد PassSkin/Resources — يكفي واحد من الخيارين:

    /// الخيار 1: ملف p12 (اسمه pass.p12)
    static let p12FileName = "pass"
    static let p12Password = ""

    /// الخيار 2: ملفات PEM (passcert.pem + passkey.pem)
    static let certPEMName = "passcert"
    static let keyPEMName = "passkey"
    static let keyPassword: String? = nil

    /// شهادة Apple الوسيطة WWDR G4 (اسمها AppleWWDRCAG4.cer)
    static let wwdrFileName = "AppleWWDRCAG4"
}
