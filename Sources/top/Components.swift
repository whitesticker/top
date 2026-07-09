import SwiftUI

// MARK: - Shared visual constants

enum DashStyle {
    static let cardCorner: CGFloat = 8
    static let cardPadding: CGFloat = 10
    static let sectionSpacing: CGFloat = 10
    static let headerFont: Font = .system(size: 11, weight: .semibold)
    static let labelFont: Font = .system(size: 10, weight: .regular)
    static let valueFont: Font = .system(size: 11, weight: .medium)
}

// MARK: - Section card

/// A titled card with an SF Symbol icon, used to group one metric category.
/// When `detail` is supplied, the whole card becomes clickable: tapping it
/// opens a secondary popover (anchored to the card) showing the expanded
/// view, iStat-Menus-style -- e.g. tapping the compact Sensors card (which
/// only shows a couple of highlighted readings) opens a popover listing
/// every individual sensor.
struct SectionCard<Content: View, Detail: View>: View {
    let title: String
    let systemImage: String
    var detail: (() -> Detail)? = nil
    @ViewBuilder var content: Content

    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 14)
                Text(title)
                    .font(DashStyle.headerFont)
                    .foregroundColor(.primary)
                Spacer()
                if detail != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            content
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(DashStyle.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DashStyle.cardCorner, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashStyle.cardCorner, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard detail != nil else { return }
            showDetail = true
        }
        .popover(isPresented: $showDetail, arrowEdge: .trailing) {
            if let detail {
                detail()
            }
        }
    }
}

extension SectionCard where Detail == EmptyView {
    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.detail = nil
        self.content = content()
    }
}

// MARK: - Detail popover shell

/// Consistent chrome for a section's expanded detail popover: title header
/// plus scrollable content (detail lists, like all sensors or all disk
/// volumes, can be arbitrarily long, unlike the fixed-size main dashboard).
struct DetailPanel<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    content
                }
            }
            .frame(maxHeight: 360)
        }
        .padding(12)
        .frame(width: 260)
    }
}

// MARK: - Sparkline

/// Draws a `[Double]` series as a small filled line chart. Normalizes against
/// its own max unless an explicit `maxValue` is supplied. Handles empty or
/// near-zero data safely (no division by zero).
struct Sparkline: View {
    var values: [Double]
    var maxValue: Double? = nil
    var color: Color = .accentColor
    var lineWidth: CGFloat = 1.2

    private var effectiveMax: Double {
        let m = maxValue ?? (values.max() ?? 0)
        return m > 0.0001 ? m : 1.0
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let points = normalizedPoints(width: w, height: h)

            ZStack {
                if points.count > 1 {
                    // Filled area under the line.
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: h))
                        for p in points { path.addLine(to: p) }
                        path.addLine(to: CGPoint(x: points.last!.x, y: h))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.35), color.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Stroke line on top.
                    Path { path in
                        path.move(to: points[0])
                        for p in points.dropFirst() { path.addLine(to: p) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                } else {
                    // Not enough data yet: draw a flat baseline.
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: h))
                        path.addLine(to: CGPoint(x: w, y: h))
                    }
                    .stroke(color.opacity(0.25), lineWidth: lineWidth)
                }
            }
        }
    }

    private func normalizedPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let m = effectiveMax
        let n = values.count
        let stepX = width / CGFloat(n - 1)
        return values.enumerated().map { idx, v in
            let clamped = max(0, min(v / m, 1))
            let x = CGFloat(idx) * stepX
            let y = height - (CGFloat(clamped) * height)
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Usage bar

/// A horizontal capsule bar showing `fraction` (0...1) filled, with an
/// optional color threshold ramp (green/yellow/red) or a fixed tint.
struct UsageBar: View {
    var fraction: Double
    var color: Color? = nil
    var height: CGFloat = 6
    var trackColor: Color = Color.primary.opacity(0.08)

    private var clamped: Double { max(0, min(fraction, 1)) }

    private var resolvedColor: Color {
        if let c = color { return c }
        if clamped < 0.6 { return .green }
        if clamped < 0.8 { return .yellow }
        return .red
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)
                Capsule()
                    .fill(resolvedColor)
                    .frame(width: geo.size.width * CGFloat(clamped))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Stat row

/// A compact label/value row: label on the left (secondary), value on the
/// right (monospaced digits, primary).
struct StatRow: View {
    var label: String
    var value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(DashStyle.labelFont)
                .foregroundColor(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(DashStyle.valueFont)
                .foregroundColor(valueColor)
                .monospacedDigit()
        }
    }
}

/// A tiny label/value pair stacked vertically, sized for use inside a
/// 2-column grid (e.g. memory / battery detail stats) where a full-width
/// `StatRow` would waste horizontal space.
struct TinyStat: View {
    var label: String
    var value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 8.5))
                .foregroundColor(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(valueColor)
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A tight 2x2 grid of `TinyStat`s, used to replace four stacked full-width
/// `StatRow`s in space-constrained cards (Memory, Battery).
struct StatGrid2x2: View {
    var items: [(String, String)]

    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 8) {
                    if row * 2 < items.count {
                        TinyStat(label: items[row * 2].0, value: items[row * 2].1)
                    }
                    if row * 2 + 1 < items.count {
                        TinyStat(label: items[row * 2 + 1].0, value: items[row * 2 + 1].1)
                    }
                }
            }
        }
    }
}

// MARK: - Mini core bar (vertical, for per-core CPU display)

/// A small vertical usage bar for a single CPU core, used in a dense grid.
struct CoreBar: View {
    var fraction: Double
    var width: CGFloat = 6

    private var clamped: Double { max(0, min(fraction, 1)) }

    private var barColor: Color {
        if clamped < 0.6 { return .green }
        if clamped < 0.85 { return .yellow }
        return .red
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.primary.opacity(0.08))
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(barColor)
                    .frame(height: geo.size.height * CGFloat(clamped))
            }
        }
        .frame(width: width)
    }
}

// MARK: - Gauge ring (for memory pressure etc.)

/// A small circular gauge showing `fraction` (0...1) with a colored arc and
/// a centered percentage label. Built with Path/trim (no Swift Charts).
struct RingGauge: View {
    var fraction: Double
    var color: Color? = nil
    var lineWidth: CGFloat = 6
    var label: String? = nil

    private var clamped: Double { max(0, min(fraction, 1)) }

    private var resolvedColor: Color {
        if let c = color { return c }
        if clamped < 0.6 { return .green }
        if clamped < 0.8 { return .yellow }
        return .red
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(clamped))
                .stroke(resolvedColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label ?? Fmt.percent(clamped))
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
        }
    }
}
