import SwiftUI

struct MetricTile: View {
    let title: String
    let value: String
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(ColorPalette.mutedText)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(ColorPalette.textStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(ColorPalette.faintText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .liquidGlassCard(cornerRadius: 16)
    }
}
