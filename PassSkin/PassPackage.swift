import UIKit
import ZIPFoundation

enum PassStyle: String, CaseIterable {
    case boardingPass, coupon, eventTicket, generic, storeCard

    var arabicName: String {
        switch self {
        case .boardingPass: return "بطاقة صعود"
        case .coupon: return "كوبون"
        case .eventTicket: return "تذكرة"
        case .generic: return "بطاقة عامة"
        case .storeCard: return "بطاقة متجر / ولاء"
        }
    }
}

enum PassError: LocalizedError {
    case notAPass
    case unreadable

    var errorDescription: String? {
        switch self {
        case .notAPass: return "الملف ليس بطاقة Wallet (pkpass)."
        case .unreadable: return "تعذّر فتح البطاقة."
        }
    }
}

/// بطاقة مفكوكة في مجلد مؤقت، جاهزة للتعديل.
struct PassPackage {
    let directory: URL
    var json: [String: Any]
    let style: PassStyle

    // MARK: - فتح ملف pkpass

    static func load(from fileURL: URL) throws -> PassPackage {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("pass-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)

        do {
            try fm.unzipItem(at: fileURL, to: work)
        } catch {
            throw PassError.unreadable
        }

        var passDir = work

        // ملف pkpasses = مجموعة بطاقات → نأخذ أول وحدة
        if !fm.fileExists(atPath: work.appendingPathComponent("pass.json").path) {
            let inner = (try? fm.contentsOfDirectory(at: work, includingPropertiesForKeys: nil)) ?? []
            guard let firstPass = inner.first(where: { $0.pathExtension.lowercased() == "pkpass" }) else {
                throw PassError.notAPass
            }
            let innerDir = work.appendingPathComponent("inner")
            try fm.createDirectory(at: innerDir, withIntermediateDirectories: true)
            try fm.unzipItem(at: firstPass, to: innerDir)
            passDir = innerDir
        }

        let jsonURL = passDir.appendingPathComponent("pass.json")
        guard let data = try? Data(contentsOf: jsonURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let style = PassStyle.allCases.first(where: { obj[$0.rawValue] != nil }) else {
            throw PassError.notAPass
        }

        return PassPackage(directory: passDir, json: obj, style: style)
    }

    // MARK: - معلومات للعرض

    var organizationName: String { json["organizationName"] as? String ?? "" }
    var logoText: String? { json["logoText"] as? String }
    var passDescription: String { json["description"] as? String ?? "" }

    var backgroundColor: UIColor? { UIColor(passColor: json["backgroundColor"] as? String) }
    var foregroundColor: UIColor? { UIColor(passColor: json["foregroundColor"] as? String) }
    var labelColor: UIColor? { UIColor(passColor: json["labelColor"] as? String) }

    var primaryField: (label: String, value: String)? {
        guard let structure = json[style.rawValue] as? [String: Any],
              let fields = structure["primaryFields"] as? [[String: Any]],
              let first = fields.first else { return nil }
        let label = first["label"] as? String ?? ""
        let value = first["value"].map { "\($0)" } ?? ""
        return (label, value)
    }

    /// يجيب الصورة الحالية من البطاقة (يدور على @3x ثم @2x ثم العادية، وبعدين مجلدات اللغات).
    func existingImage(named name: String) -> UIImage? {
        let candidates = ["\(name)@3x.png", "\(name)@2x.png", "\(name).png"]
        var dirs = [directory]
        let subdirs = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        dirs += subdirs.filter { $0.pathExtension == "lproj" }
        for dir in dirs {
            for file in candidates {
                let url = dir.appendingPathComponent(file)
                if let img = UIImage(contentsOfFile: url.path) { return img }
            }
        }
        return nil
    }
}

extension UIColor {
    /// يحوّل "rgb(12, 34, 56)" أو "#RRGGBB" إلى لون.
    convenience init?(passColor: String?) {
        guard let raw = passColor?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }

        if raw.hasPrefix("#") {
            let hex = String(raw.dropFirst())
            guard hex.count == 6, let v = UInt32(hex, radix: 16) else { return nil }
            self.init(red: CGFloat((v >> 16) & 0xFF) / 255,
                      green: CGFloat((v >> 8) & 0xFF) / 255,
                      blue: CGFloat(v & 0xFF) / 255, alpha: 1)
            return
        }

        let nums = raw
            .replacingOccurrences(of: "rgba", with: "")
            .replacingOccurrences(of: "rgb", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "() "))
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard nums.count >= 3 else { return nil }
        self.init(red: nums[0] / 255, green: nums[1] / 255, blue: nums[2] / 255, alpha: 1)
    }
}
