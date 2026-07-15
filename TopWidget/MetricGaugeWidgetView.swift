import SwiftUI
import WidgetKit

/// Shared small/medium layout for metrics that boil down to one headline
/// number and an optional 0...1 fraction (CPU, GPU, Memory, Battery,
/// Sensors' CPU temp). Medium adds a secondary detail line; small stays to
/// just the essentials so it's legible at that size.
struct MetricGaugeWidgetView: View {
    let title: String
    let systemImage: String
    let value: String
    var subtitle: String? = nil
    var fraction: Double? = nil
    var tint: Color = .accentColor

    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 30, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            if let fraction {
                ProgressView(value: min(max(fraction, 0), 1))
                    .tint(tint)
            }

            if family == .systemMedium, let subtitle {
                Spacer(minLength: 0)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
