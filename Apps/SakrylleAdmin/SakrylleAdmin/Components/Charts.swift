import SakrylleShared
import SwiftUI

struct LineTrendChart: View {
    let points: [Double]
    var color: Color = ColorPalette.primary

    var body: some View {
        GeometryReader { proxy in
            let maxValue = max(points.max() ?? 1, 1)
            Path { path in
                for index in points.indices {
                    let x = proxy.size.width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
                    let y = proxy.size.height - proxy.size.height * CGFloat(points[index] / maxValue)
                    if index == points.startIndex {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        }
        .frame(height: 120)
        .background(ColorPalette.mutedCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct BarChart: View {
    let values: [(String, Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(values, id: \.0) { label, value in
                let maxValue = max(values.map(\.1).max() ?? 1, 1)
                HStack {
                    Text(label).font(.caption).frame(width: 84, alignment: .leading)
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorPalette.primary)
                            .frame(width: proxy.size.width * CGFloat(value / maxValue))
                    }
                    .frame(height: 8)
                    Text(formatCompactNumber(value))
                        .font(.caption)
                        .foregroundStyle(ColorPalette.mutedText)
                        .frame(width: 54, alignment: .trailing)
                }
            }
        }
    }
}
