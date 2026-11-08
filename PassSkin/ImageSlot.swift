import UIKit

/// أماكن الصور في بطاقة Wallet.
enum ImageSlot: String, CaseIterable, Identifiable {
    case logo, strip, background, thumbnail, icon, footer

    var id: String { rawValue }

    var arabicName: String {
        switch self {
        case .logo: return "الشعار"
        case .strip: return "الصورة العريضة (البانر)"
        case .background: return "الخلفية"
        case .thumbnail: return "الصورة الجانبية"
        case .icon: return "أيقونة الإشعارات"
        case .footer: return "صورة أسفل البطاقة"
        }
    }

    var hint: String {
        switch self {
        case .logo: return "تظهر أعلى يسار البطاقة"
        case .strip: return "تظهر بعرض البطاقة تحت الشعار"
        case .background: return "Wallet يضيف عليها تمويه (blur)"
        case .thumbnail: return "صورة مربعة بجانب البيانات"
        case .icon: return "تظهر في الإشعارات وشاشة القفل"
        case .footer: return "شريط صغير فوق الباركود"
        }
    }

    /// الصور المتاحة لكل نوع بطاقة (حسب توثيق Apple).
    static func slots(for style: PassStyle) -> [ImageSlot] {
        switch style {
        case .storeCard, .coupon: return [.strip, .logo, .icon]
        case .eventTicket: return [.strip, .background, .thumbnail, .logo, .icon]
        case .generic: return [.thumbnail, .logo, .icon]
        case .boardingPass: return [.footer, .logo, .icon]
        }
    }

    /// المقاس بالنقاط (@1x).
    func pointSize(for style: PassStyle) -> CGSize {
        switch self {
        case .logo: return CGSize(width: 160, height: 50)
        case .icon: return CGSize(width: 38, height: 38)
        case .thumbnail: return CGSize(width: 90, height: 90)
        case .background: return CGSize(width: 180, height: 220)
        case .footer: return CGSize(width: 286, height: 15)
        case .strip:
            return style == .eventTicket
                ? CGSize(width: 375, height: 98)
                : CGSize(width: 375, height: 144)
        }
    }

    /// الشعار يحافظ على نسبته (fit)، الباقي يتقص ويعبّي المساحة (fill).
    var fitsInsteadOfFills: Bool { self == .logo }
}

enum ImageChange {
    case replace(UIImage)
    case remove
}

enum ImageRenderer {
    /// يطلع PNG بالمقاس المطلوب × scale.
    static func png(from image: UIImage, slot: ImageSlot, style: PassStyle, scale: CGFloat) -> Data? {
        let box = slot.pointSize(for: style)
        let src = image.size
        guard src.width > 0, src.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        if slot.fitsInsteadOfFills {
            let r = min(box.width / src.width, box.height / src.height)
            let size = CGSize(width: (src.width * r * scale).rounded(),
                              height: (src.height * r * scale).rounded())
            return UIGraphicsImageRenderer(size: size, format: format).pngData { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        }

        let target = CGSize(width: box.width * scale, height: box.height * scale)
        let r = max(target.width / src.width, target.height / src.height)
        let drawn = CGSize(width: src.width * r, height: src.height * r)
        let origin = CGPoint(x: (target.width - drawn.width) / 2, y: (target.height - drawn.height) / 2)
        return UIGraphicsImageRenderer(size: target, format: format).pngData { _ in
            image.draw(in: CGRect(origin: origin, size: drawn))
        }
    }
}
