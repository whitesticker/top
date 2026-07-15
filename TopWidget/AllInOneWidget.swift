import SwiftUI
import WidgetKit

/// The large widget: every metric in one glance, roughly mirroring the
/// menu bar app's own compact-card language but laid out for a fixed
/// ~370x370 canvas instead of a vertical menu list.
struct AllInOneWidgetView: View {
    let snapshot: SystemSnapshot?

    var body: some View {
        if let snapshot {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    MiniStat(title: "CPU", systemImage: "cpu", value: Fmt.percent(snapshot.cpu.totalUsage), tint: .blue)
                    MiniStat(
                        title: "GPU",
                        systemImage: "cube.transparent",
                        value: snapshot.gpu.available ? Fmt.percent(snapshot.gpu.utilization) : "n/a",
                        tint: .purple
                    )
                }
                HStack(spacing: 8) {
                    MiniStat(title: "Memory", systemImage: "memorychip", value: Fmt.percent(snapshot.memory.pressure), tint: .yellow)
                    MiniStat(
                        title: "Battery",
                        systemImage: "battery.100",
                        value: snapshot.power.hasBattery ? Fmt.percent(snapshot.power.percentage) : "AC",
                        tint: .green
                    )
                }
                HStack(spacing: 8) {
                    MiniStat(title: "↓ Down", systemImage: "network", value: Fmt.speed(snapshot.network.downBytesPerSec), tint: .accentColor)
                    MiniStat(title: "↑ Up", systemImage: "network", value: Fmt.speed(snapshot.network.upBytesPerSec), tint: .orange)
                }
                HStack(spacing: 8) {
                    MiniStat(title: "Disk R", systemImage: "internaldrive", value: Fmt.speed(snapshot.disk.readBytesPerSec), tint: .green)
                    MiniStat(title: "Disk W", systemImage: "internaldrive", value: Fmt.speed(snapshot.disk.writeBytesPerSec), tint: .pink)
                }
                HStack(spacing: 8) {
                    MiniStat(title: "CPU Temp", systemImage: "thermometer.medium", value: Fmt.temp(snapshot.sensors.cpuTemp), tint: .red)
                    MiniStat(title: "GPU Temp", systemImage: "thermometer.medium", value: Fmt.temp(snapshot.sensors.gpuTemp), tint: .red)
                }
            }
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            Text("Open top to start monitoring")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding()
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

private struct MiniStat: View {
    let title: String
    let systemImage: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .semibold))
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundColor(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }
}

struct AllInOneWidget: Widget {
    let kind = "AllInOneWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            AllInOneWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("System Overview")
        .description("CPU, GPU, Memory, Network, Disk, Sensors, and Battery at a glance.")
        .supportedFamilies([.systemLarge])
    }
}
