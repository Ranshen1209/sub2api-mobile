import SwiftUI
import UIKit

enum ColorPalette {
    static let primary = Color(light: 0x9181bd, dark: 0xa896c8)
    static let primaryDark = Color(light: 0x7a6aac, dark: 0x8a78b6)
    static let primarySoft = Color(light: 0xc8bee0, dark: 0x3f3553)
    static let page = Color(light: 0xf5f1fa, dark: 0x14101c)
    static let card = Color(light: 0xfaf7fd, dark: 0x1d1828)
    static let mutedCard = Color(light: 0xefe9f7, dark: 0x2a2336)
    static let text = Color(light: 0x16181a, dark: 0xf0ecf8)
    static let textStrong = Color(light: 0x3a3548, dark: 0xe6e0f3)
    static let subtext = Color(light: 0x6f6982, dark: 0xb1aac4)
    static let mutedText = Color(light: 0x7a7388, dark: 0x8c869b)
    static let faintText = Color(light: 0x8c8499, dark: 0x6e687f)
    static let placeholder = Color(light: 0x9b94ad, dark: 0x6e687f)
    static let accentBg = Color(light: 0xe9defb, dark: 0x322746)
    static let accentText = Color(light: 0x5c3da3, dark: 0xc8b4f0)
    static let border = Color(light: 0xddd2ed, dark: 0x2e2840)
    static let borderSoft = Color(light: 0xe6dfee, dark: 0x251f33)
    static let barTrack = Color(light: 0xe3dbef, dark: 0x2e2840)
    static let danger = Color(light: 0xc25d35, dark: 0xd97a52)
    static let dangerBg = Color(light: 0xfbf1eb, dark: 0x3a2418)
    static let warning = Color(light: 0xc79a45, dark: 0xd4a85a)
    static let darkButton = Color(light: 0x1b1d1f, dark: 0x0c0a14)
}

private extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xff) / 255.0,
            green: CGFloat((hex >> 8) & 0xff) / 255.0,
            blue: CGFloat(hex & 0xff) / 255.0,
            alpha: 1
        )
    }
}
