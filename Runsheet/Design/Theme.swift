import SwiftUI
import UIKit

// Flighty-inspired palette, same tokens as the web app's styles.css.
enum RS {
    static let bg = dyn(0xF2F2F7, 0x000000)
    static let card = dyn(0xFFFFFF, 0x1C1C1E)
    static let fill = dyn(0xEFEFF4, 0x2C2C2E)
    static let fill2 = dyn(0xE3E3E8, 0x3A3A3C)
    static let text = dyn(0x1C1C1E, 0xF2F2F7)
    static let text2 = dyn(0x6C6C70, 0xAEAEB2)
    static let text3 = dyn(0x8E8E93, 0x8E8E93)
    static let line = dyn(0xE5E5EA, 0x38383A)
    static let accent = dyn(0xE8590C, 0xFF6B1A)
    static let accentText = dyn(0xC2410C, 0xFF9A5C)
    static let onAccent = dyn(0xFFFFFF, 0x1C0A00)
    /// Selected option in segmented controls; the dark card colour was nearly invisible on the track.
    static let segOn = dyn(0xFFFFFF, 0x636366)
    /// Deeper orange for filled buttons in light mode, so white text passes contrast.
    static let accentFill = dyn(0xC2410C, 0xFF6B1A)

    static let blue = dyn(0x0A60C9, 0x6AB0FF)
    static let blueBg = dyn(0xE8F1FC, 0x0A84FF, darkAlpha: 0.18)
    static let amber = dyn(0x9A5200, 0xFFB547)
    static let amberBg = dyn(0xFFF3E0, 0xFF9F0A, darkAlpha: 0.16)
    static let green = dyn(0x1E7A45, 0x4CD683)
    static let greenBg = dyn(0xE7F6EC, 0x30D158, darkAlpha: 0.16)
    static let grey = dyn(0x3A3A3C, 0xD1D1D6)
    static let greyBg = dyn(0xEFEFF4, 0x2C2C2E)

    static let sea = dyn(0xB9DCEB, 0x0C2431)
    static let shallow = dyn(0xCBE6F1, 0x12323F)
    static let land = dyn(0xF3F1EC, 0x2A2A2D)
    static let inland = dyn(0xECE9E1, 0x252528)
    static let label = dyn(0x6C6C70, 0x9A9AA0)
    static let pinRing = dyn(0xFFFFFF, 0x1C1C1E)

    static func dyn(_ light: UInt, _ dark: UInt, darkAlpha: CGFloat = 1) -> Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .dark ? UIColor(hex: dark, alpha: darkAlpha) : UIColor(hex: light)
        })
    }

    static let catColors: [String: UInt] = [
        "stunt-jumps": 0xE8590C, "nine1nine": 0x0A84FF, "curiosity": 0xAF52DE, "jack-of-hearts": 0xE0245E,
        "magazine": 0xFF9F0A, "sculpture": 0x8E8E93, "delights": 0xFF2D55, "under-the-bridge": 0x5AC8FA, "book-swap": 0xA2845E,
        "1010-mural": 0xFFCC00, "unique-playlist": 0x64D2FF, "animal-crackers": 0xBF5AF2, "arcade-machine": 0x5E5CE6,
        "safe": 0x30A46C, "atm-towable": 0x34C759, "bank": 0x248A3D, "big-bank": 0x1F7A36, "payday-loans": 0x7CB342,
        "mission": 0xD4A017, "side": 0x6E56CF, "contact": 0x7D7AFF, "safehouse": 0x00A3A3,
        "ammu-nation": 0xB23A48, "pay-n-spray": 0x2E86DE, "purchasable-garage": 0x576574, "garage": 0x576574,
    ]
    static func color(_ cat: String) -> Color { Color(UIColor(hex: catColors[cat] ?? 0x8E8E93)) }
}

extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

extension BoardStatus {
    var fg: Color { switch self { case .live: RS.blue; case .closing: RS.amber; case .ready: RS.green; case .money: RS.grey } }
    var bg: Color { switch self { case .live: RS.blueBg; case .closing: RS.amberBg; case .ready: RS.greenBg; case .money: RS.greyBg } }
}

extension Font {
    static let rsEyebrow = Font.system(size: 11, weight: .semibold).width(.expanded)
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight, design: .monospaced) }
}
