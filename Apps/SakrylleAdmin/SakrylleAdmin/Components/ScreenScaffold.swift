import SwiftUI

struct ScreenScaffold<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.largeTitle.bold())
                            .foregroundStyle(ColorPalette.text)
                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(ColorPalette.subtext)
                        }
                    }
                    content
                }
                .padding()
            }
            .background(ColorPalette.page.ignoresSafeArea())
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(.white)
            .background(configuration.isPressed ? ColorPalette.primaryDark : ColorPalette.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
