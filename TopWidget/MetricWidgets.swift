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
                tint: DashColors.cpuLine,
                statusPill: cpu.map { WidgetStatus.load($0.totalUsage) }
            )
        }
        .configurationDisplayName("CPU")
        .description("Current CPU usage.")
        .supportedFamilies([.systemSmall])
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
                tint: DashColors.gpuLine,
                statusPill: (gpu?.available == true) ? gpu.map { WidgetStatus.load($0.utilization) } : nil
            )
        }
        .configurationDisplayName("GPU")
        .description("Current GPU usage.")
        .supportedFamilies([.systemSmall])
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
                subtitle: memory.map { "\(Fmt.bytesBinary($0.used)) / \(Fmt.bytesBinary($0.total))\nSwap \(Fmt.bytesBinary($0.swapUsed))" },
                fraction: memory?.pressure,
                tint: memory.map { WidgetStatus.pressure($0.pressure).color } ?? DashColors.accent,
                statusPill: memory.map { WidgetStatus.pressure($0.pressure) }
            )
        }
        .configurationDisplayName("Memory")
        .description("Current memory pressure and usage.")
        .supportedFamilies([.systemSmall])
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
                leftColor: DashColors.download,
                leftMagnitude: network?.downBytesPerSec ?? 0,
                rightLabel: "Up",
                rightValue: network.map { Fmt.speed($0.upBytesPerSec) } ?? "—",
                rightColor: DashColors.upload,
                rightMagnitude: network?.upBytesPerSec ?? 0,
                subtitle: network.flatMap { net -> String? in
                    var parts: [String] = []
                    if !net.primaryInterface.isEmpty { parts.append(net.primaryInterface) }
                    if !net.primaryIP.isEmpty { parts.append(net.primaryIP) }
                    return parts.isEmpty ? nil : parts.joined(separator: " · ")
                }
            )
        }
        .configurationDisplayName("Network")
        .description("Live download/upload speed.")
        .supportedFamilies([.systemSmall])
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
                leftColor: DashColors.diskRead,
                leftMagnitude: disk?.readBytesPerSec ?? 0,
                rightLabel: "Write",
                rightValue: disk.map { Fmt.speed($0.writeBytesPerSec) } ?? "—",
                rightColor: DashColors.diskWrite,
                rightMagnitude: disk?.writeBytesPerSec ?? 0,
                subtitle: mainVolume.map { "\($0.name)\n\(Fmt.bytes($0.used)) / \(Fmt.bytes($0.total))" }
            )
        }
        .configurationDisplayName("Disk")
        .description("Live disk read/write speed.")
        .supportedFamilies([.systemSmall])
    }
}

struct SensorsWidget: Widget {
    let kind = "SensorsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            let sensors = entry.snapshot?.sensors
            let hottestFan = sensors?.fans.max { $0.rpm < $1.rpm }
            MetricGaugeWidgetView(
                title: "Sensors",
                systemImage: "thermometer.medium",
                value: sensors.map { Fmt.temp($0.cpuTemp) } ?? "—",
                subtitle: {
                    var lines: [String] = []
                    if let sensors { lines.append("GPU \(Fmt.temp(sensors.gpuTemp))") }
                    if let hottestFan, hottestFan.rpm > 0 { lines.append(Fmt.rpm(hottestFan.rpm)) }
                    return lines.isEmpty ? nil : lines.joined(separator: "\n")
                }(),
                fraction: sensors.map { min(1, max(0, $0.cpuTemp / 100)) },
                tint: sensors.map { WidgetStatus.temperature($0.cpuTemp).color } ?? DashColors.statusCritical,
                statusPill: sensors.map { WidgetStatus.temperature($0.cpuTemp) }
            )
        }
        .configurationDisplayName("Sensors")
        .description("CPU and GPU temperature.")
        .supportedFamilies([.systemSmall])
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
                subtitle: power.flatMap { power -> String? in
                    guard power.hasBattery else { return nil }
                    var lines: [String] = []
                    if power.isCharging {
                        lines.append(power.timeToFullMinutes >= 0 ? "\(Fmt.minutes(power.timeToFullMinutes)) to full" : "Charging")
                    } else if power.timeToEmptyMinutes >= 0 {
                        lines.append("\(Fmt.minutes(power.timeToEmptyMinutes)) remaining")
                    }
                    if power.health > 0 { lines.append("Health \(Fmt.percent(power.health)) · \(power.cycleCount) cycles") }
                    return lines.isEmpty ? nil : lines.joined(separator: "\n")
                },
                fraction: (power?.hasBattery == true) ? power?.percentage : nil,
                tint: DashColors.statusGood,
                statusPill: power.flatMap { power -> (label: String, color: Color)? in
                    guard power.hasBattery else { return nil }
                    if power.isCharging { return ("Charging", DashColors.statusGood) }
                    if power.isPluggedIn { return ("Plugged In", DashColors.accent) }
                    return power.percentage < 0.2 ? ("Low", DashColors.statusCritical) : nil
                }
            )
        }
        .configurationDisplayName("Battery")
        .description("Battery charge and time remaining.")
        .supportedFamilies([.systemSmall])
    }
}
