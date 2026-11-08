import Foundation
import OpenSSL

/// يوقّع manifest.json بتوقيع PKCS#7 منفصل (detached) — نفس اللي يطلبه Wallet.
enum PassSigner {

    enum SignError: LocalizedError {
        case missingCertificate
        case missingWWDR
        case badCertificate(String)
        case signingFailed

        var errorDescription: String? {
            switch self {
            case .missingCertificate:
                return "شهادة البطاقات غير موجودة داخل التطبيق.\nحط pass.p12 (أو passcert.pem + passkey.pem) في مجلد Resources وعدّل Config.swift."
            case .missingWWDR:
                return "شهادة Apple الوسيطة (AppleWWDRCAG4.cer) غير موجودة في مجلد Resources."
            case .badCertificate(let detail):
                return "تعذّر قراءة الشهادة: \(detail)"
            case .signingFailed:
                return "فشل توقيع البطاقة."
            }
        }
    }

    static var isConfigured: Bool {
        let b = Bundle.main
        let hasP12 = b.url(forResource: Config.p12FileName, withExtension: "p12") != nil
        let hasPEM = b.url(forResource: Config.certPEMName, withExtension: "pem") != nil
            && b.url(forResource: Config.keyPEMName, withExtension: "pem") != nil
        let hasWWDR = wwdrURL() != nil
        return (hasP12 || hasPEM) && hasWWDR
    }

    private static func wwdrURL() -> URL? {
        Bundle.main.url(forResource: Config.wwdrFileName, withExtension: "cer")
            ?? Bundle.main.url(forResource: Config.wwdrFileName, withExtension: "pem")
    }

    private static var providersLoaded = false

    /// OpenSSL 3 يحتاج مزوّد legacy لبعض ملفات p12 القديمة المصدّرة من Keychain.
    private static func loadProviders() {
        guard !providersLoaded else { return }
        providersLoaded = true
        _ = OSSL_PROVIDER_load(nil, "default")
        _ = OSSL_PROVIDER_load(nil, "legacy")
    }

    static func sign(manifest: Data) throws -> Data {
        loadProviders()

        guard let wwdrURL = wwdrURL() else { throw SignError.missingWWDR }
        let wwdrData = try Data(contentsOf: wwdrURL)

        let (cert, key) = try loadSigningIdentity()
        defer {
            X509_free(cert)
            EVP_PKEY_free(key)
        }

        guard let wwdr = readX509(wwdrData) else {
            throw SignError.badCertificate("AppleWWDRCAG4")
        }
        defer { X509_free(wwdr) }

        let flags = PKCS7_BINARY | PKCS7_DETACHED | PKCS7_PARTIAL

        return try manifest.withUnsafeBytes { raw -> Data in
            guard let dataBIO = BIO_new_mem_buf(raw.baseAddress, Int32(raw.count)) else {
                throw SignError.signingFailed
            }
            defer { _ = BIO_free(dataBIO) }

            guard let p7 = PKCS7_sign(cert, key, nil, nil, flags) else {
                throw SignError.signingFailed
            }
            defer { PKCS7_free(p7) }

            guard PKCS7_add_certificate(p7, wwdr) == 1,
                  PKCS7_final(p7, dataBIO, flags) == 1 else {
                throw SignError.signingFailed
            }

            let length = i2d_PKCS7(p7, nil)
            guard length > 0 else { throw SignError.signingFailed }

            var out = [UInt8](repeating: 0, count: Int(length))
            let written = out.withUnsafeMutableBufferPointer { buf -> Int32 in
                var p = buf.baseAddress
                return i2d_PKCS7(p7, &p)
            }
            guard written == length else { throw SignError.signingFailed }
            return Data(out)
        }
    }

    // MARK: - تحميل الشهادة والمفتاح

    private static func loadSigningIdentity() throws -> (OpaquePointer, OpaquePointer) {
        let b = Bundle.main

        // PEM
        if let certURL = b.url(forResource: Config.certPEMName, withExtension: "pem"),
           let keyURL = b.url(forResource: Config.keyPEMName, withExtension: "pem") {
            let certData = try Data(contentsOf: certURL)
            let keyData = try Data(contentsOf: keyURL)
            guard let cert = readX509(certData) else {
                throw SignError.badCertificate("passcert.pem")
            }
            guard let key = readPrivateKey(keyData, password: Config.keyPassword) else {
                X509_free(cert)
                throw SignError.badCertificate("passkey.pem")
            }
            return (cert, key)
        }

        // P12
        if let p12URL = b.url(forResource: Config.p12FileName, withExtension: "p12") {
            let p12Data = try Data(contentsOf: p12URL)
            let p12: OpaquePointer? = p12Data.withUnsafeBytes { raw in
                var p = raw.bindMemory(to: UInt8.self).baseAddress
                return d2i_PKCS12(nil, &p, raw.count)
            }
            guard let p12 else { throw SignError.badCertificate("pass.p12") }
            defer { PKCS12_free(p12) }

            var key: OpaquePointer?
            var cert: OpaquePointer?
            guard PKCS12_parse(p12, Config.p12Password, &key, &cert, nil) == 1,
                  let key, let cert else {
                throw SignError.badCertificate("pass.p12 — تأكد من كلمة المرور في Config.swift")
            }
            return (cert, key)
        }

        throw SignError.missingCertificate
    }

    /// يقرأ شهادة X509 سواء كانت DER (.cer) أو PEM.
    private static func readX509(_ data: Data) -> OpaquePointer? {
        let der: OpaquePointer? = data.withUnsafeBytes { raw in
            var p = raw.bindMemory(to: UInt8.self).baseAddress
            return d2i_X509(nil, &p, raw.count)
        }
        if let der { return der }

        return data.withUnsafeBytes { raw in
            guard let bio = BIO_new_mem_buf(raw.baseAddress, Int32(raw.count)) else { return nil }
            defer { _ = BIO_free(bio) }
            return PEM_read_bio_X509(bio, nil, nil, nil)
        }
    }

    private static func readPrivateKey(_ data: Data, password: String?) -> OpaquePointer? {
        data.withUnsafeBytes { raw in
            guard let bio = BIO_new_mem_buf(raw.baseAddress, Int32(raw.count)) else { return nil }
            defer { _ = BIO_free(bio) }
            if let password {
                return password.withCString { pw in
                    PEM_read_bio_PrivateKey(bio, nil, nil, UnsafeMutableRawPointer(mutating: UnsafeRawPointer(pw)))
                }
            }
            return PEM_read_bio_PrivateKey(bio, nil, nil, nil)
        }
    }
}
