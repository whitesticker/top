import SwiftUI
import WidgetKit

struct CPUWidget: Widget {
    let kind = "CPUWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            let cpu = entry.snapshot?.cpu
            MetricGaugeWidgetView(
                title: "CPU",
                systemImage: "cpu",
                value: cpu.map { Fmt.percent($0.totalUsage) } ?? "—",
                subtitle: cpu.map { "User \(Fmt.percent($0.user)) · System \(Fmt.percent($0.system))\nLoad \(String(format: "%.1f", $0.load1))" },
                fraction: cpu?.totalUsage,
                tint: .blue
            )
        }
        .configurationDisplayName("CPU")
        .description("Current CPU usage.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct GPUWidget: Widget {
    let kind = "GPUWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            let gpu = entry.snapshot?.gpu
            MetricGaugeWidgetView(
                title: "GPU",
                systemImage: "cube.transparent",
                value: gpu.map { $0.available ? Fmt.percent($0.utilization) : "n/a" } ?? "—",
                subtitle: gpu?.name,
                fraction: (gpu?.available == true) ? gpu?.utilization : nil,
                tint: .purple
            )
        }
        .configurationDisplayName("GPU")
        .description("Current GPU usage.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MemoryWidget: Widget {
    let kind = "MemoryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            let memory = entry.snapshot?.memory
            MetricGaugeWidgetView(
                title: "Memory",
                systemImage: "memorychip",
                value: memory.map { Fmt.percent($0.pressure) } ?? "—",
                subtitle: memory.map { "\(Fmt.bytes($0.used)) / \(Fmt.bytes($0.total))" },
                fraction: memory?.pressure,
                tint: memory.map { pressureColor($0.pressure) } ?? .accentColor
            )
        }
        .configurationDisplayName("Memory")
        .description("Current memory pressure and usage.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NetworkWidget: Widget {
    let kind = "NetworkWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            let network = entry.snapshot?.network
            MetricDualWidgetView(
                title: "Network",
                systemImage: "network",
                leftLabel: "Down",
                leftValue: network.map { Fmt.speed($0.downBytesPerSec) } ?? "—",
                leftColor: .accentColor,
                rightLabel: "Up",
                rightValue: network.map { Fmt.speed($0.upBytesPerSec) } ?? "—",
                rightColor: .orange,
                subtitle: network.flatMap { $0.primaryIP.isEmpty ? nil : $0.primaryIP }
            )
        }
        .configurationDisplayName("Network")
        .description("Live download/upload speed.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DiskWidget: Widget {
    let kind = "DiskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            let disk = entry.snapshot?.disk
            let mainVolume = disk?.volumes.max { $0.total < $1.total }
            MetricDualWidgetView(
                title: "Disk",
                systemImage: "internaldrive",
                leftLabel: "Read",
                leftValue: disk.map { Fmt.speed($0.readBytesPerSec) } ?? "—",
                leftColor: .green,
                rightLabel: "Write",
                rightValue: disk.map { Fmt.speed($0.writeBytesPerSec) } ?? "—",
                rightColor: .pink,
                subtitle: mainVolume.map { "\(Fmt.bytes($0.used)) / \(Fmt.bytes($0.total))" }
            )
        }
        .configurationDisplayName("Disk")
        .description("Live disk read/write speed.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SensorsWidget: Widget {
    let kind = "SensorsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            let sensors = entry.snapshot?.sensors
            MetricGaugeWidgetView(
                title: "Sensors",
                systemImage: "thermometer.medium",
                value: sensors.map { Fmt.temp($0.cpuTemp) } ?? "—",
                subtitle: sensors.map { "GPU \(Fmt.temp($0.gpuTemp))" },
                tint: .red
            )
        }
        .configurationDisplayName("Sensors")
        .description("CPU and GPU temperature.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct BatteryWidget: Widget {
    let kind = "BatteryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            let power = entry.snapshot?.power
            MetricGaugeWidgetView(
                title: "Battery",
                systemImage: "battery.100",
                value: power.map { $0.hasBattery ? Fmt.percent($0.percentage) : "AC" } ?? "—",
                subtitle: power.flatMap { power in
                    guard power.hasBattery else { return nil }
                    if power.isCharging {
                        return power.timeToFullMinutes >= 0 ? "\(Fmt.minutes(power.timeToFullMinutes)) to full" : "Charging"
                    }
                    return power.timeToEmptyMinutes >= 0 ? "\(Fmt.minutes(power.timeToEmptyMinutes)) remaining" : nil
                },
                fraction: (power?.hasBattery == true) ? power?.percentage : nil,
                tint: .green
            )
        }
        .configurationDisplayName("Battery")
        .description("Battery charge and time remaining.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private func pressureColor(_ pressure: Double) -> Color {
    if pressure < 0.6 { return .green }
    if pressure < 0.8 { return .yellow }
    return .red
}
