import SwiftUI
import WidgetKit

/// Small-widget layout for metrics with two independent rates (Network's
/// down/up, Disk's read/write) rather than one headline number. A relative
/// split bar shows which side is currently dominant.
struct MetricDualWidgetView: View {
    let title: String
    let systemImage: String
    let leftLabel: String
    let leftValue: String
    let leftColor: Color
    let leftMagnitude: Double
    let rightLabel: String
    let rightValue: String
    let rightColor: Color
    let rightMagnitude: Double
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.secondary)

            Spacer(minLength: 0)

            SplitBar(leftMagnitude: leftMagnitude, leftColor: leftColor, rightMagnitude: rightMagnitude, rightColor: rightColor)
                .frame(height: 8)

            valueRow(label: leftLabel, value: leftValue, color: leftColor, systemImage: "arrow.down")
            valueRow(label: rightLabel, value: rightValue, color: rightColor, systemImage: "arrow.up")

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func valueRow(label: String, value: String, color: Color, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }
}

/// A rounded two-color bar whose segments are sized by relative share of
/// `leftMagnitude`/`rightMagnitude` -- raw same-unit values (e.g. bytes/sec),
/// not pre-normalized fractions; the split is computed here.
private struct SplitBar: View {
    let leftMagnitude: Double
    let leftColor: Color
    let rightMagnitude: Double
    let rightColor: Color

    var body: some View {
        GeometryReader { geo in
            let total = max(leftMagnitude + rightMagnitude, 0.001)
            let leftWidth = geo.size.width * (leftMagnitude / total)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                HStack(spacing: 0) {
                    Capsule().fill(leftColor).frame(width: max(leftWidth, 3))
                    Capsule().fill(rightColor)
                }
            }
        }
    }
}
