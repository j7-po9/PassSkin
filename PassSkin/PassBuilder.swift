import Foundation
import CryptoKit
import ZIPFoundation

/// يبني ملف pkpass جديد: نفس البيانات والباركود + صور المستخدم + توقيعك.
enum PassBuilder {

    static func build(from package: PassPackage, changes: [ImageSlot: ImageChange]) throws -> Data {
        let fm = FileManager.default
        let out = fm.temporaryDirectory.appendingPathComponent("build-\(UUID().uuidString)")
        try fm.copyItem(at: package.directory, to: out)
        defer { try? fm.removeItem(at: out) }

        // 1) نشيل التوقيع القديم وأي ملفات زايدة
        for name in ["manifest.json", "signature", "__MACOSX"] {
            try? fm.removeItem(at: out.appendingPathComponent(name))
        }
        for name in (try? fm.contentsOfDirectory(atPath: out.path)) ?? [] where name.lowercased().hasSuffix(".pkpass") {
            try? fm.removeItem(at: out.appendingPathComponent(name))
        }

        // 2) الصور
        var changes = changes
        // في التذاكر: لو فيه strip، Wallet يتجاهل الخلفية والصورة الجانبية
        if package.style == .eventTicket,
           changes[.background] != nil || changes[.thumbnail] != nil,
           changes[.strip] == nil {
            changes[.strip] = .remove
        }

        for (slot, change) in changes {
            removeImage(slot.rawValue, in: out)
            if case .replace(let image) = change {
                let variants: [(String, CGFloat)] = [("", 1), ("@2x", 2), ("@3x", 3)]
                for (suffix, scale) in variants {
                    guard let png = ImageRenderer.png(from: image, slot: slot, style: package.style, scale: scale) else { continue }
                    try png.write(to: out.appendingPathComponent("\(slot.rawValue)\(suffix).png"))
                }
            }
        }

        // 3) pass.json — نربطها بشهادتك ونفصلها عن خادم الجهة الأصلية
        var json = package.json
        json["passTypeIdentifier"] = Config.passTypeIdentifier
        json["teamIdentifier"] = Config.teamIdentifier
        json["serialNumber"] = UUID().uuidString
        for key in ["webServiceURL", "authenticationToken", "nfc"] {
            json.removeValue(forKey: key)
        }
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
        try jsonData.write(to: out.appendingPathComponent("pass.json"))

        // 4) manifest.json = SHA1 لكل ملف
        var manifest: [String: String] = [:]
        for rel in fm.subpaths(atPath: out.path) ?? [] {
            let url = out.appendingPathComponent(rel)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else { continue }
            if (rel as NSString).lastPathComponent.hasPrefix(".") {
                try? fm.removeItem(at: url)
                continue
            }
            let data = try Data(contentsOf: url)
            manifest[rel] = Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
        let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])
        try manifestData.write(to: out.appendingPathComponent("manifest.json"))

        // 5) التوقيع
        let signature = try PassSigner.sign(manifest: manifestData)
        try signature.write(to: out.appendingPathComponent("signature"))

        // 6) نضغطها pkpass
        let zipURL = fm.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pkpass")
        try fm.zipItem(at: out, to: zipURL, shouldKeepParent: false, compressionMethod: .deflate)
        defer { try? fm.removeItem(at: zipURL) }
        return try Data(contentsOf: zipURL)
    }

    /// يحذف الصورة بكل مقاساتها من الجذر ومن مجلدات اللغات.
    private static func removeImage(_ name: String, in dir: URL) {
        let fm = FileManager.default
        var dirs = [dir]
        let subs = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        dirs += subs.filter { $0.pathExtension == "lproj" }
        for d in dirs {
            for suffix in ["", "@2x", "@3x"] {
                try? fm.removeItem(at: d.appendingPathComponent("\(name)\(suffix).png"))
            }
        }
    }
}
