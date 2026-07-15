import SwiftUI
import WidgetKit

/// Small-widget layout for metrics that boil down to one headline number and
/// an optional 0...1 fraction (CPU, GPU, Memory, Battery, Sensors). A ring
/// gauge carries the value graphically instead of a plain linear bar.
struct MetricGaugeWidgetView: View {
    let title: String
    let systemImage: String
    let value: String
    var subtitle: String? = nil
    var fraction: Double? = nil
    var tint: Color = DashColors.accent
    var statusPill: (label: String, color: Color)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.secondary)

            Spacer(minLength: 0)

            HStack {
                Spacer(minLength: 0)
                RingGauge(fraction: fraction, tint: tint) {
                    VStack(spacing: 0) {
                        Text(value)
                            .font(.system(size: 17, weight: .bold))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                }
                .frame(width: 64, height: 64)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            if let statusPill {
                StatusPill(text: statusPill.label, color: statusPill.color)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// A circular progress ring with arbitrary content centered inside it.
/// `fraction == nil` renders a dim static track (e.g. GPU unavailable).
struct RingGauge<Content: View>: View {
    let fraction: Double?
    var tint: Color = .accentColor
    var lineWidth: CGFloat = 6
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: lineWidth)
            if let fraction {
                Circle()
                    .trim(from: 0, to: max(0.02, min(1, fraction)))
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            content()
        }
    }
}
