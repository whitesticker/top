import SwiftUI
import WidgetKit

/// Shared small/medium layout for metrics with two independent rates
/// (Network's down/up, Disk's read/write) rather than one headline number.
struct MetricDualWidgetView: View {
    let title: String
    let systemImage: String
    let leftLabel: String
    let leftValue: String
    let leftColor: Color
    let rightLabel: String
    let rightValue: String
    let rightColor: Color
    var subtitle: String? = nil

    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.secondary)

            if family == .systemMedium {
                HStack(alignment: .top, spacing: 16) {
                    valueColumn(label: leftLabel, value: leftValue, color: leftColor)
                    valueColumn(label: rightLabel, value: rightValue, color: rightColor)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    valueColumn(label: leftLabel, value: leftValue, color: leftColor)
                    valueColumn(label: rightLabel, value: rightValue, color: rightColor)
                }
            }

            if family == .systemMedium, let subtitle {
                Spacer(minLength: 0)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func valueColumn(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }
}
