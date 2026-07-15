import SwiftUI
import WidgetKit

/// The big widget: a 2-column grid of "hero cards", one per major metric,
/// each carrying its own small graphic (ring gauge, sparkline, thermometer)
/// rather than a bare number -- mirrors the visual language of the
/// menu-bar-utility widget style (icon + label header, big bold value, a
/// glanceable graphic underneath).
struct AllInOneWidgetView: View {
    let snapshot: SystemSnapshot?

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    private let rows = 3
    private let outerMargin: CGFloat = 15
    private let gap: CGFloat = 8

    var body: some View {
        if let snapshot {
            GeometryReader { geo in
                let cardHeight = (geo.size.height - outerMargin * 2 - gap * CGFloat(rows - 1)) / CGFloat(rows)
                LazyVGrid(columns: columns, spacing: gap) {
                    cpuCard(snapshot).frame(height: cardHeight)
                    memoryCard(snapshot).frame(height: cardHeight)
                    gpuCard(snapshot).frame(height: cardHeight)
                    diskCard(snapshot).frame(height: cardHeight)
                    sensorsCard(snapshot).frame(height: cardHeight)
                    networkCard(snapshot).frame(height: cardHeight)
                }
                .padding(outerMargin)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            Text("Open top to start monitoring")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding()
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }

    private func cpuCard(_ snapshot: SystemSnapshot) -> some View {
        HeroCard(title: "Processor Load", systemImage: "cpu") {
            VStack(alignment: .leading, spacing: 6) {
                Text(Fmt.percent(snapshot.cpu.totalUsage))
                    .font(.system(size: 22, weight: .bold))
                    .monospacedDigit()
                Sparkline(values: snapshot.widgetHistory.cpu, color: DashColors.cpuLine)
                    .frame(height: 28)
            }
        }
    }

    private func memoryCard(_ snapshot: SystemSnapshot) -> some View {
        HeroCard(title: "Memory", systemImage: "memorychip") {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Fmt.percent(snapshot.memory.pressure))
                        .font(.system(size: 22, weight: .bold))
                        .monospacedDigit()
                    Text("\(Fmt.bytesBinary(snapshot.memory.used)) / \(Fmt.bytesBinary(snapshot.memory.total))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                RingGauge(fraction: snapshot.memory.pressure, tint: WidgetStatus.pressure(snapshot.memory.pressure).color) {
                    EmptyView()
                }
                .frame(width: 34, height: 34)
            }
        }
    }

    private func gpuCard(_ snapshot: SystemSnapshot) -> some View {
        HeroCard(title: "GPU", systemImage: "cube.transparent") {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.gpu.available ? Fmt.percent(snapshot.gpu.utilization) : "n/a")
                        .font(.system(size: 22, weight: .bold))
                        .monospacedDigit()
                    if !snapshot.gpu.name.isEmpty {
                        Text(snapshot.gpu.name)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: 0)
                RingGauge(fraction: snapshot.gpu.available ? snapshot.gpu.utilization : nil, tint: DashColors.gpuLine) {
                    EmptyView()
                }
                .frame(width: 34, height: 34)
            }
        }
    }

    private func diskCard(_ snapshot: SystemSnapshot) -> some View {
        let mainVolume = snapshot.disk.volumes.max { $0.total < $1.total }
        let usedFraction = mainVolume.flatMap { $0.total > 0 ? Double($0.used) / Double($0.total) : nil }
        return HeroCard(title: "Disk", systemImage: "internaldrive") {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(usedFraction.map { Fmt.percent($0) } ?? "—")
                        .font(.system(size: 22, weight: .bold))
                        .monospacedDigit()
                    if let mainVolume {
                        Text("\(Fmt.bytes(mainVolume.used)) / \(Fmt.bytes(mainVolume.total))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: 0)
                RingGauge(fraction: usedFraction, tint: DashColors.diskRead) {
                    EmptyView()
                }
                .frame(width: 34, height: 34)
            }
        }
    }

    private func sensorsCard(_ snapshot: SystemSnapshot) -> some View {
        let temp = snapshot.sensors.cpuTemp
        return HeroCard(title: "Processor Temp", systemImage: "cpu") {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Fmt.temp(temp))
                        .font(.system(size: 22, weight: .bold))
                        .monospacedDigit()
                    StatusPill(text: WidgetStatus.temperature(temp).label, color: WidgetStatus.temperature(temp).color)
                }
                Spacer(minLength: 0)
                ThermometerGlyph(fraction: min(1, max(0, temp / 100)), color: WidgetStatus.temperature(temp).color)
                    .frame(width: 20, height: 34)
            }
        }
    }

    private func networkCard(_ snapshot: SystemSnapshot) -> some View {
        HeroCard(title: "Network Activity", systemImage: "network") {
            VStack(alignment: .leading, spacing: 6) {
                DualSparkline(
                    down: snapshot.widgetHistory.netDown,
                    downColor: DashColors.download,
                    up: snapshot.widgetHistory.netUp,
                    upColor: DashColors.upload
                )
                .frame(height: 28)
                HStack(spacing: 10) {
                    Label(Fmt.speed(snapshot.network.downBytesPerSec), systemImage: "arrow.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(DashColors.download)
                    Label(Fmt.speed(snapshot.network.upBytesPerSec), systemImage: "arrow.up")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(DashColors.upload)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        }
    }

}

/// Shared card chrome: icon+title header over caller-provided content.
private struct HeroCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(8)
        .background(
            // ContainerRelativeShape rather than a hardcoded RoundedRectangle
            // radius -- it automatically matches whatever corner radius the
            // system gives the surrounding widget, so the inner cards' and
            // outer widget's rounding always agree, on any widget size.
            ContainerRelativeShape()
                .fill(DashColors.cardBackground)
        )
    }
}

/// A single-series bar sparkline (recent history, oldest to newest). Bar
/// width is computed from the available width via GeometryReader -- a bare
/// `Capsule()` with no explicit frame has no well-defined width inside an
/// `HStack`, which is what produced the garbled dash/dot rendering before.
private struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let bars = values.isEmpty ? [0] : values
            let maxVal = max(values.max() ?? 0, 0.05)
            let spacing: CGFloat = 2
            let barWidth = max((geo.size.width - spacing * CGFloat(bars.count - 1)) / CGFloat(bars.count), 2)
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, v in
                    Capsule()
                        .fill(color.opacity(values.isEmpty ? 0.2 : 0.4 + 0.6 * (v / maxVal)))
                        .frame(width: barWidth, height: max(CGFloat(v / maxVal) * geo.size.height, 3))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
    }
}

/// A mirrored two-series bar chart (down on top, up on bottom of each
/// column) for network throughput history. Same fixed-bar-width approach
/// as `Sparkline`, split into two half-height stacks per column.
private struct DualSparkline: View {
    let down: [Double]
    let downColor: Color
    let up: [Double]
    let upColor: Color

    var body: some View {
        GeometryReader { geo in
            let count = max(max(down.count, up.count), 1)
            let maxVal = max(down.max() ?? 0, up.max() ?? 0, 1)
            let spacing: CGFloat = 2
            let barWidth = max((geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count), 2)
            let halfHeight = max((geo.size.height - 2) / 2, 1)
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<count, id: \.self) { idx in
                    VStack(spacing: 2) {
                        Capsule()
                            .fill(downColor)
                            .frame(width: barWidth, height: max(CGFloat((idx < down.count ? down[idx] : 0) / maxVal) * halfHeight, 2))
                        Capsule()
                            .fill(upColor)
                            .frame(width: barWidth, height: max(CGFloat((idx < up.count ? up[idx] : 0) / maxVal) * halfHeight, 2))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

private struct ThermometerGlyph: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(color)
                    .frame(height: max(geo.size.height * fraction, geo.size.width))
            }
        }
    }
}

struct AllInOneWidget: Widget {
    let kind = "AllInOneWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            AllInOneWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("System Overview")
        .description("CPU, GPU, Memory, Disk, Sensors, and Network at a glance.")
        .supportedFamilies([.systemLarge, .systemExtraLarge])
        // WidgetKit imposes its own automatic content margins on top of
        // whatever padding our own view applies, and those aren't
        // guaranteed equal on all four edges. Disabling them means the
        // explicit `outerMargin` padding in AllInOneWidgetView is the only
        // margin in effect, so all four borders end up genuinely uniform.
        .contentMarginsDisabled()
    }
}
