import SwiftUI

extension View {
    @ViewBuilder
    func fullScreenPageBackground() -> some View {
        if #available(iOS 26.0, *) {
            self
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    ColorPalette.page
                        .ignoresSafeArea()
                        .backgroundExtensionEffect()
                }
        } else {
            self
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ColorPalette.page.ignoresSafeArea())
        }
    }

    @ViewBuilder
    func fullScreenScrollEdges() -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        } else {
            self
        }
    }

    @ViewBuilder
    func edgeToEdgeToolbarChrome() -> some View {
        if #available(iOS 18.0, *) {
            self
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
                .toolbarBackgroundVisibility(.hidden, for: .tabBar)
        } else {
            self
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbarBackground(.hidden, for: .tabBar)
        }
    }

    @ViewBuilder
    func liquidGlassCard(cornerRadius: CGFloat = 8) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            self
                .background(ColorPalette.card.opacity(0.68), in: shape)
                .glassEffect(.regular.tint(ColorPalette.card.opacity(0.42)), in: shape)
                .overlay(shape.stroke(ColorPalette.borderSoft.opacity(0.7), lineWidth: 1))
        } else {
            self
                .background(ColorPalette.card, in: shape)
                .overlay(shape.stroke(ColorPalette.borderSoft, lineWidth: 1))
        }
    }
}

struct ScreenScaffold<Content: View>: View {
    let title: String
    let subtitle: String?
    let iconName: String?
    let maxContentWidth: CGFloat
    @ViewBuilder var content: Content

    init(_ title: String, subtitle: String? = nil, iconName: String? = nil, maxContentWidth: CGFloat = 1180, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.maxContentWidth = maxContentWidth
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center, spacing: 12) {
                            if let iconName {
                                Image(iconName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 54, height: 54)
                                    .padding(6)
                                    .liquidGlassCard(cornerRadius: 16)
                            }

                            Text(title)
                                .font(.largeTitle.bold())
                                .foregroundStyle(ColorPalette.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }
                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(ColorPalette.subtext)
                        }
                    }
                    content
                }
                .padding()
                .frame(maxWidth: maxContentWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, 12, for: .scrollContent)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .fullScreenScrollEdges()
            .fullScreenPageBackground()
            .edgeToEdgeToolbarChrome()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fullScreenPageBackground()
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26.0, *) {
            let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
            configuration.label
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(
                    configuration.isPressed ? ColorPalette.primaryDark.opacity(0.78) : ColorPalette.primary.opacity(0.9),
                    in: shape
                )
                .glassEffect(.regular.tint(ColorPalette.primary.opacity(0.42)).interactive(), in: shape)
                .opacity(configuration.isPressed ? 0.82 : 1)
        } else {
            configuration.label
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(configuration.isPressed ? ColorPalette.primaryDark : ColorPalette.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(ColorPalette.accentText)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                configuration.isPressed ? ColorPalette.accentBg.opacity(0.54) : ColorPalette.accentBg.opacity(0.72),
                in: shape
            )
            .overlay(shape.stroke(ColorPalette.primary.opacity(0.22), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}
