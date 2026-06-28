import SwiftUI

struct ListCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(14)
        .background(ColorPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ColorPalette.borderSoft))
    }
}

struct Badge: View {
    let text: String
    var tone: BadgeTone = .muted

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(tone.foreground)
            .background(tone.background)
            .clipShape(Capsule())
    }
}

enum BadgeTone {
    case success
    case danger
    case warning
    case muted

    var foreground: Color {
        switch self {
        case .success: ColorPalette.accentText
        case .danger: ColorPalette.danger
        case .warning: ColorPalette.warning
        case .muted: ColorPalette.mutedText
        }
    }

    var background: Color {
        switch self {
        case .success: ColorPalette.accentBg
        case .danger: ColorPalette.dangerBg
        case .warning: ColorPalette.mutedCard
        case .muted: ColorPalette.mutedCard
        }
    }
}
