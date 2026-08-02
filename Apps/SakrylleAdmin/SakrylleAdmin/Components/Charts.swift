import SakrylleShared
import SwiftUI

struct LineTrendChart: View {
    let points: [Double]
    var color: Color = ColorPalette.primary

    var body: some View {
        GeometryReader { proxy in
            let maxValue = max(points.max() ?? 1, 1)
            let minValue = min(points.min() ?? 0, 0)
            let valueRange = max(maxValue - minValue, 1)
            let inset = CGSize(width: 10, height: 12)
            let plotWidth = max(proxy.size.width - inset.width * 2, 1)
            let plotHeight = max(proxy.size.height - inset.height * 2, 1)
            let chartPoints = makeChartPoints(in: proxy.size, inset: inset, plotWidth: plotWidth, plotHeight: plotHeight, minValue: minValue, valueRange: valueRange)

            ZStack {
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        Divider()
                            .overlay(ColorPalette.borderSoft.opacity(0.45))
                        Spacer(minLength: 0)
                    }
                    Divider()
                        .overlay(ColorPalette.borderSoft.opacity(0.45))
                }
                .padding(.horizontal, inset.width)
                .padding(.vertical, inset.height)

                Path { path in
                    guard let first = chartPoints.first, let last = chartPoints.last else { return }
                    path.move(to: CGPoint(x: first.x, y: proxy.size.height - inset.height))
                    path.addLine(to: first)
                    addSmoothLines(to: &path, points: chartPoints)
                    path.addLine(to: CGPoint(x: last.x, y: proxy.size.height - inset.height))
                    path.addLine(to: CGPoint(x: proxy.size.width - inset.width, y: proxy.size.height - inset.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.22), color.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Path { path in
                    guard let first = chartPoints.first else { return }
                    path.move(to: first)
                    addSmoothLines(to: &path, points: chartPoints)
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))

                if points.count <= 10 {
                    ForEach(Array(chartPoints.enumerated()), id: \.offset) { _, point in
                        Circle()
                            .fill(ColorPalette.card)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().stroke(color, lineWidth: 2))
                            .position(point)
                    }
                }
            }
        }
        .frame(height: 132)
        .background(ColorPalette.mutedCard.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ColorPalette.borderSoft.opacity(0.82), lineWidth: 1)
        )
    }

    private func makeChartPoints(in size: CGSize, inset: CGSize, plotWidth: CGFloat, plotHeight: CGFloat, minValue: Double, valueRange: Double) -> [CGPoint] {
        points.indices.map { index in
            CGPoint(
                x: inset.width + plotWidth * CGFloat(index) / CGFloat(max(points.count - 1, 1)),
                y: inset.height + plotHeight - plotHeight * CGFloat((points[index] - minValue) / valueRange)
            )
        }
    }

    private func addSmoothLines(to path: inout Path, points: [CGPoint]) {
        guard points.count > 1 else { return }
        guard points.count > 2 else {
            path.addLine(to: points[1])
            return
        }
        for index in 0..<(points.count - 1) {
            let current = points[index]
            let next = points[index + 1]
            let previous = index > 0 ? points[index - 1] : current
            let following = index + 2 < points.count ? points[index + 2] : next
            let control1 = CGPoint(
                x: current.x + (next.x - previous.x) / 6,
                y: current.y + (next.y - previous.y) / 6
            )
            let control2 = CGPoint(
                x: next.x - (following.x - current.x) / 6,
                y: next.y - (following.y - current.y) / 6
            )
            path.addCurve(to: next, control1: control1, control2: control2)
        }
    }
}

struct BarChart: View {
    let values: [(String, Double)]

    var body: some View {
        let maxValue = max(values.map(\.1).max() ?? 1, 1)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(values, id: \.0) { label, value in
                HStack {
                    Text(label).font(.caption).frame(width: 84, alignment: .leading)
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
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
