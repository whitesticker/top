import SwiftUI

// MARK: - Dashboard

/// Root view shown inside the menu bar NSPopover. A fixed-size, no-scroll,
/// two-column dashboard: everything visible at once, like iStat Menus'
/// compact panels.
struct DashboardView: View {
    @EnvironmentObject var monitor: SystemMonitor

    private let panelWidth: CGFloat = 340
    private let columnGap: CGFloat = 8

    var body: some View {
        VStack(spacing: 6) {
            DateTimeSection(date: monitor.snapshot.date)

            HStack(alignment: .top, spacing: columnGap) {
                CPUSection(cpu: monitor.snapshot.cpu, history: monitor.cpuHistory)
                GPUSection(gpu: monitor.snapshot.gpu, history: monitor.gpuHistory)
            }

            HStack(alignment: .top, spacing: columnGap) {
                MemorySection(memory: monitor.snapshot.memory, history: monitor.memHistory)
                NetworkSection(
                    network: monitor.snapshot.network,
                    downHistory: monitor.netDownHistory,
                    upHistory: monitor.netUpHistory
                )
            }

            DiskSection(
                disk: monitor.snapshot.disk,
                readHistory: monitor.diskReadHistory,
                writeHistory: monitor.diskWriteHistory
            )

            HStack(alignment: .top, spacing: columnGap) {
                SensorsSection(sensors: monitor.snapshot.sensors)
                PowerSection(power: monitor.snapshot.power)
            }
        }
        .padding(8)
        .frame(width: panelWidth)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Date & Time

private struct DateTimeSection: View {
    let date: Date

    private var combinedString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm:ss a · EEE, MMM d"
        return f.string(from: date)
    }

    var body: some View {
        Text(combinedString)
            .font(.system(size: 11, weight: .medium))
            .monospacedDigit()
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
    }
}

// MARK: - CPU

private struct CPUSection: View {
    let cpu: CPUSample
    let history: [Double]

    var body: some View {
        SectionCard(title: "CPU", systemImage: "cpu", detail: {
            CPUDetail(cpu: cpu, history: history)
        }) {
            HStack(alignment: .firstTextBaseline) {
                Text(Fmt.percent(cpu.totalUsage))
                    .font(.system(size: 18, weight: .semibold))
                    .monospacedDigit()
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("U \(Fmt.percent(cpu.user))")
                    Text("S \(Fmt.percent(cpu.system))")
                }
                .font(.system(size: 8.5))
                .foregroundColor(.secondary)
                .monospacedDigit()
            }

            Sparkline(values: history, maxValue: 1.0, color: DashColors.cpuLine)
                .frame(height: 20)

            if !cpu.perCore.isEmpty {
                HStack(spacing: 2) {
                    ForEach(Array(cpu.perCore.enumerated()), id: \.offset) { _, v in
                        CoreBar(fraction: v, width: 4)
                    }
                }
                .frame(height: 16)
            }

            if cpu.pCoreCount > 0 {
                HStack {
                    Text("P \(Fmt.percent(cpu.performanceCoreUsage))")
                    Spacer()
                    Text("E \(Fmt.percent(cpu.efficiencyCoreUsage))")
                }
                .font(.system(size: 8.5))
                .foregroundColor(.secondary)
                .monospacedDigit()
            }

            Text(String(format: "Load %.1f %.1f %.1f", cpu.load1, cpu.load5, cpu.load15))
                .font(.system(size: 8.5))
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Every logical core's usage individually, plus the same sparkline/load
/// info as the compact card at a larger size.
struct CPUDetail: View {
    let cpu: CPUSample
    let history: [Double]

    var body: some View {
        DetailPanel(title: "CPU", systemImage: "cpu") {
            HStack {
                StatRow(label: "Total", value: Fmt.percent(cpu.totalUsage))
            }
            StatRow(label: "User", value: Fmt.percent(cpu.user))
            StatRow(label: "System", value: Fmt.percent(cpu.system))
            StatRow(label: "Idle", value: Fmt.percent(cpu.idle))
            Sparkline(values: history, maxValue: 1.0, color: DashColors.cpuLine)
                .frame(height: 40)
            if cpu.pCoreCount > 0 {
                Divider()
                StatRow(label: "Performance cores", value: "\(cpu.pCoreCount)")
                StatRow(label: "Efficiency cores", value: "\(cpu.eCoreCount)")
                StatRow(label: "P-core usage", value: Fmt.percent(cpu.performanceCoreUsage))
                StatRow(label: "E-core usage", value: Fmt.percent(cpu.efficiencyCoreUsage))
            }
            if !cpu.perCore.isEmpty {
                Divider()
                Text("Per-core").font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 6) {
                    ForEach(Array(cpu.perCore.enumerated()), id: \.offset) { i, v in
                        VStack(spacing: 2) {
                            CoreBar(fraction: v, width: 10)
                                .frame(height: 28)
                            Text("\(i)")
                                .font(.system(size: 7))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            Divider()
            StatRow(label: "Load avg (1m)", value: String(format: "%.2f", cpu.load1))
            StatRow(label: "Load avg (5m)", value: String(format: "%.2f", cpu.load5))
            StatRow(label: "Load avg (15m)", value: String(format: "%.2f", cpu.load15))
            Divider()
            TopProcessList(
                sample: { ProcessMonitor().topCPUProcesses() },
                format: { String(format: "%.0f%%", $0) }
            )
        }
    }
}

// MARK: - GPU

private struct GPUSection: View {
    let gpu: GPUSample
    let history: [Double]

    var body: some View {
        SectionCard(title: "GPU", systemImage: "cube.transparent", detail: {
            GPUDetail(gpu: gpu, history: history)
        }) {
            if gpu.available {
                Text(Fmt.percent(gpu.utilization))
                    .font(.system(size: 18, weight: .semibold))
                    .monospacedDigit()
                Text(gpu.name.isEmpty ? "GPU" : gpu.name)
                    .font(.system(size: 8.5))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Sparkline(values: history, maxValue: 1.0, color: DashColors.gpuLine)
                    .frame(height: 20)
                Spacer(minLength: 0)
            } else {
                Text("n/a")
                    .font(DashStyle.labelFont)
                    .foregroundColor(.secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GPUDetail: View {
    let gpu: GPUSample
    let history: [Double]

    var body: some View {
        DetailPanel(title: "GPU", systemImage: "cube.transparent") {
            if gpu.available {
                StatRow(label: "Name", value: gpu.name.isEmpty ? "GPU" : gpu.name)
                StatRow(label: "Utilization", value: Fmt.percent(gpu.utilization))
                Sparkline(values: history, maxValue: 1.0, color: DashColors.gpuLine)
                    .frame(height: 40)
            } else {
                Text("No GPU data available").font(DashStyle.labelFont).foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Memory

private struct MemorySection: View {
    let memory: MemorySample
    let history: [Double]

    private var pressureColor: Color {
        if memory.pressure < 0.6 { return DashColors.statusGood }
        if memory.pressure < 0.8 { return DashColors.statusWarning }
        return DashColors.statusCritical
    }

    var body: some View {
        SectionCard(title: "Memory", systemImage: "memorychip", detail: {
            MemoryDetail(memory: memory, history: history, pressureColor: pressureColor)
        }) {
            HStack(alignment: .center, spacing: 8) {
                RingGauge(fraction: memory.pressure, color: pressureColor, lineWidth: 4)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(Fmt.bytes(memory.used)) /")
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                    Text(Fmt.bytes(memory.total))
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                }
                Spacer()
            }

            StatGrid2x2(items: [
                ("App", Fmt.bytes(memory.app)),
                ("Wired", Fmt.bytes(memory.wired)),
                ("Compressed", Fmt.bytes(memory.compressed)),
                ("Cached", Fmt.bytes(memory.cached)),
            ])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MemoryDetail: View {
    let memory: MemorySample
    let history: [Double]
    let pressureColor: Color

    var body: some View {
        DetailPanel(title: "Memory", systemImage: "memorychip") {
            StatRow(label: "Used", value: Fmt.bytes(memory.used))
            StatRow(label: "Total", value: Fmt.bytes(memory.total))
            StatRow(label: "Pressure", value: Fmt.percent(memory.pressure), valueColor: pressureColor)
            Sparkline(values: history, maxValue: 1.0, color: pressureColor)
                .frame(height: 40)
            Divider()
            StatRow(label: "App", value: Fmt.bytes(memory.app))
            StatRow(label: "Wired", value: Fmt.bytes(memory.wired))
            StatRow(label: "Compressed", value: Fmt.bytes(memory.compressed))
            StatRow(label: "Cached", value: Fmt.bytes(memory.cached))
            StatRow(label: "Free", value: Fmt.bytes(memory.free))
            Divider()
            StatRow(label: "Swap used", value: Fmt.bytes(memory.swapUsed))
            StatRow(label: "Swap total", value: Fmt.bytes(memory.swapTotal))
            Divider()
            TopProcessList(
                sample: { ProcessMonitor().topMemoryProcesses() },
                format: { Fmt.bytes($0) }
            )
        }
    }
}

// MARK: - Network

private struct NetworkSection: View {
    let network: NetworkSample
    let downHistory: [Double]
    let upHistory: [Double]

    /// Interface name in the normal secondary style, IP address bolded so
    /// it's the one thing that jumps out on this line.
    private var ipLine: Text {
        let iface = network.primaryInterface.isEmpty ? "—" : network.primaryInterface
        let ip = network.primaryIP.isEmpty ? "—" : network.primaryIP
        return Text("\(iface) · ").foregroundColor(.secondary)
            + Text(ip).fontWeight(.bold).foregroundColor(.primary)
    }

    var body: some View {
        SectionCard(title: "Network", systemImage: "network", detail: {
            NetworkDetail(network: network)
        }) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(DashColors.download)
                        Text(Fmt.speed(network.downBytesPerSec))
                            .font(.system(size: 10.5, weight: .semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    Sparkline(values: downHistory, color: DashColors.download)
                        .frame(height: 16)
                }
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(DashColors.upload)
                        Text(Fmt.speed(network.upBytesPerSec))
                            .font(.system(size: 10.5, weight: .semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    Sparkline(values: upHistory, color: DashColors.upload)
                        .frame(height: 16)
                }
            }

            ipLine
                .font(.system(size: 8.5))
                .lineLimit(1)
                .truncationMode(.middle)

            Text("↓\(Fmt.bytes(network.sessionDown)) ↑\(Fmt.bytes(network.sessionUp)) session")
                .font(.system(size: 8.5))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// All interfaces (not just the primary one) with their live rates and IPs.
struct NetworkDetail: View {
    let network: NetworkSample

    var body: some View {
        DetailPanel(title: "Network", systemImage: "network") {
            StatRow(label: "Download", value: Fmt.speed(network.downBytesPerSec))
            StatRow(label: "Upload", value: Fmt.speed(network.upBytesPerSec))
            Divider()
            StatRow(label: "Session ↓", value: Fmt.bytes(network.sessionDown))
            StatRow(label: "Session ↑", value: Fmt.bytes(network.sessionUp))
            StatRow(label: "Total ↓ (boot)", value: Fmt.bytes(network.totalDown))
            StatRow(label: "Total ↑ (boot)", value: Fmt.bytes(network.totalUp))
            if !network.interfaces.isEmpty {
                Divider()
                Text("Interfaces").font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary)
                ForEach(Array(network.interfaces.enumerated()), id: \.offset) { _, iface in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(iface.name).font(.system(size: 10, weight: .medium))
                            Spacer()
                            Text(iface.ipv4.isEmpty ? "—" : iface.ipv4)
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        Text("↓\(Fmt.speed(iface.downBytesPerSec)) ↑\(Fmt.speed(iface.upBytesPerSec))")
                            .font(.system(size: 8.5))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            Divider()
            TopProcessList(
                label: "Top processes (total data)",
                sample: { ProcessMonitor().topNetworkProcesses() },
                format: { Fmt.bytes($0) }
            )
        }
    }
}

// MARK: - Disk

private struct DiskSection: View {
    let disk: DiskSample
    let readHistory: [Double]
    let writeHistory: [Double]

    /// Top 2 volumes by total capacity — most people only care about their
    /// main drive(s); long lists of small/system volumes get cut.
    private var topVolumes: [DiskVolumeSample] {
        Array(disk.volumes.sorted { $0.total > $1.total }.prefix(2))
    }

    var body: some View {
        SectionCard(title: "Disk", systemImage: "internaldrive", detail: {
            DiskDetail(disk: disk, readHistory: readHistory, writeHistory: writeHistory)
        }) {
            if disk.volumes.isEmpty {
                Text("No volumes found")
                    .font(DashStyle.labelFont)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(topVolumes.enumerated()), id: \.offset) { _, vol in
                    VolumeRow(volume: vol)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(DashColors.diskRead)
                Text(Fmt.speed(disk.readBytesPerSec))
                    .font(.system(size: 9.5, weight: .medium))
                    .monospacedDigit()
                Spacer(minLength: 6)
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(DashColors.diskWrite)
                Text(Fmt.speed(disk.writeBytesPerSec))
                    .font(.system(size: 9.5, weight: .medium))
                    .monospacedDigit()
                Spacer()
                Sparkline(values: readHistory, color: DashColors.diskRead)
                    .frame(width: 40, height: 14)
                Sparkline(values: writeHistory, color: DashColors.diskWrite)
                    .frame(width: 40, height: 14)
            }
        }
    }
}

struct VolumeRow: View {
    let volume: DiskVolumeSample

    private var fraction: Double {
        volume.total > 0 ? Double(volume.used) / Double(volume.total) : 0
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: volume.isInternal ? "internaldrive" : "externaldrive")
                .font(.system(size: 8.5))
                .foregroundColor(.secondary)
            Text(volume.name.isEmpty ? "Volume" : volume.name)
                .font(.system(size: 9.5, weight: .medium))
                .lineLimit(1)
                .frame(width: 78, alignment: .leading)
            UsageBar(fraction: fraction, height: 5)
            Text("\(Fmt.bytes(volume.used))/\(Fmt.bytes(volume.total))")
                .font(.system(size: 8.5))
                .foregroundColor(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.vertical, 1)
    }
}

/// Every volume (not just the top 2 by size), plus fuller throughput info.
struct DiskDetail: View {
    let disk: DiskSample
    let readHistory: [Double]
    let writeHistory: [Double]

    var body: some View {
        DetailPanel(title: "Disk", systemImage: "internaldrive") {
            StatRow(label: "Read", value: Fmt.speed(disk.readBytesPerSec))
            StatRow(label: "Write", value: Fmt.speed(disk.writeBytesPerSec))
            HStack(spacing: 8) {
                Sparkline(values: readHistory, color: DashColors.diskRead).frame(height: 30)
                Sparkline(values: writeHistory, color: DashColors.diskWrite).frame(height: 30)
            }
            if disk.volumes.isEmpty {
                Text("No volumes found").font(DashStyle.labelFont).foregroundColor(.secondary)
            } else {
                Divider()
                Text("Volumes (\(disk.volumes.count))").font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary)
                ForEach(Array(disk.volumes.enumerated()), id: \.offset) { _, vol in
                    VolumeRow(volume: vol)
                }
            }
            Divider()
            TopProcessList(
                sample: { ProcessMonitor().topDiskProcesses() },
                format: { Fmt.speed($0) }
            )
        }
    }
}

// MARK: - Sensors

private struct SensorsSection: View {
    let sensors: SensorSample

    /// At most one curated extra data point: the hottest sensor besides the
    /// CPU/GPU highlights. We do NOT iterate/list the full raw sensor array
    /// (that was the original bug — 186 rows on some Macs).
    private var hottestOther: TemperatureSample? {
        sensors.temperatures
            .filter { $0.celsius > 0 }
            .max(by: { $0.celsius < $1.celsius })
    }

    var body: some View {
        SectionCard(title: "Sensors", systemImage: "thermometer.medium", detail: {
            SensorsDetail(sensors: sensors)
        }) {
            if sensors.cpuTemp <= 0 && sensors.gpuTemp <= 0 && sensors.fans.isEmpty {
                Text("No sensor data")
                    .font(DashStyle.labelFont)
                    .foregroundColor(.secondary)
            } else {
                HStack {
                    if sensors.cpuTemp > 0 {
                        HighlightStat(label: "CPU", value: Fmt.temp(sensors.cpuTemp))
                    }
                    if sensors.gpuTemp > 0 {
                        HighlightStat(label: "GPU", value: Fmt.temp(sensors.gpuTemp))
                    }
                    Spacer(minLength: 0)
                }

                if let hot = hottestOther {
                    Text("\(SensorNames.displayName(for: hot.label)): \(Fmt.temp(hot.celsius))")
                        .font(.system(size: 8.5))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if !sensors.fans.isEmpty {
                    ForEach(Array(sensors.fans.enumerated()), id: \.offset) { _, f in
                        StatRow(label: f.label, value: Fmt.rpm(f.rpm))
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Every individual temperature sensor and fan -- the full raw list the
/// compact card deliberately omits (that was the original scroll-length
/// bug: up to ~186 raw SMC keys on some Macs). Safe here since this panel
/// only appears on demand. Temperatures render as a compact heat-map grid
/// (tile color ramps green/yellow/red with the reading) rather than a
/// tall vertical list, since there can be dozens of them.
struct SensorsDetail: View {
    let sensors: SensorSample

    private var sortedTemps: [TemperatureSample] {
        sensors.temperatures.sorted { $0.celsius > $1.celsius }
    }

    private func heatColor(_ celsius: Double) -> Color {
        if celsius < 45 { return DashColors.statusGood }
        if celsius < 65 { return DashColors.statusWarning }
        return DashColors.statusCritical
    }

    var body: some View {
        DetailPanel(title: "Sensors", systemImage: "thermometer.medium", width: 420) {
            if sensors.fans.isEmpty && sortedTemps.isEmpty {
                Text("No sensor data").font(DashStyle.labelFont).foregroundColor(.secondary)
            }
            if !sensors.fans.isEmpty {
                Text("Fans").font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary)
                ForEach(Array(sensors.fans.enumerated()), id: \.offset) { _, f in
                    StatRow(label: f.label, value: Fmt.rpm(f.rpm))
                }
                Divider()
            }
            if !sortedTemps.isEmpty {
                Text("Temperatures (\(sortedTemps.count))").font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
                    ForEach(Array(sortedTemps.enumerated()), id: \.offset) { _, t in
                        VStack(spacing: 1) {
                            Text(SensorNames.displayName(for: t.label))
                                .font(.system(size: 7.5))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(Fmt.temp(t.celsius))
                                .font(.system(size: 10.5, weight: .semibold))
                                .monospacedDigit()
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 2)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(heatColor(t.celsius).opacity(0.22))
                        )
                    }
                }
            }
        }
    }
}

struct HighlightStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 8.5))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
        }
        .padding(.trailing, 10)
    }
}

// MARK: - Battery & Power

private struct PowerSection: View {
    let power: PowerSample

    private var levelColor: Color {
        if power.isCharging { return DashColors.statusGood }
        if power.percentage < 0.2 { return DashColors.statusCritical }
        if power.percentage < 0.4 { return DashColors.statusWarning }
        return DashColors.statusGood
    }

    var body: some View {
        SectionCard(title: "Battery", systemImage: "battery.100", detail: {
            PowerDetail(power: power)
        }) {
            if power.hasBattery {
                HStack(spacing: 4) {
                    if power.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                            .foregroundColor(DashColors.statusGood)
                    }
                    Text(Fmt.percent(power.percentage))
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                    Spacer(minLength: 4)
                    Text(timeLabel)
                        .font(.system(size: 8.5))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                UsageBar(fraction: power.percentage, color: levelColor, height: 5)

                StatGrid2x2(items: [
                    ("Cycles", "\(power.cycleCount)"),
                    ("Health", Fmt.percent(power.health)),
                    ("Draw", Fmt.watts(power.powerWatts)),
                    ("Temp", Fmt.temp(power.temperature)),
                ])
            } else {
                Text("On AC power / no battery")
                    .font(DashStyle.labelFont)
                    .foregroundColor(.secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timeLabel: String {
        if power.isCharging {
            return power.timeToFullMinutes >= 0 ? "\(Fmt.minutes(power.timeToFullMinutes)) to full" : "Calculating…"
        } else {
            return power.timeToEmptyMinutes >= 0 ? "\(Fmt.minutes(power.timeToEmptyMinutes)) left" : "Calculating…"
        }
    }
}

struct PowerDetail: View {
    let power: PowerSample

    var body: some View {
        DetailPanel(title: "Battery & Power", systemImage: "battery.100") {
            if power.hasBattery {
                StatRow(label: "Charge", value: Fmt.percent(power.percentage))
                StatRow(label: "Status", value: power.isCharging ? "Charging" : (power.isPluggedIn ? "Plugged in" : "On battery"))
                StatRow(label: "Time to full", value: power.timeToFullMinutes >= 0 ? Fmt.minutes(power.timeToFullMinutes) : "—")
                StatRow(label: "Time to empty", value: power.timeToEmptyMinutes >= 0 ? Fmt.minutes(power.timeToEmptyMinutes) : "—")
                Divider()
                StatRow(label: "Cycle count", value: "\(power.cycleCount)")
                StatRow(label: "Health", value: Fmt.percent(power.health))
                StatRow(label: "Power draw", value: Fmt.watts(power.powerWatts))
                StatRow(label: "Battery temp", value: Fmt.temp(power.temperature))
                Divider()
                // macOS has no public per-process "energy impact" API (the
                // private mechanism behind Activity Monitor's Energy tab
                // isn't accessible to third-party apps) -- CPU usage is the
                // closest available proxy, since it's usually what's
                // actually driving battery drain.
                TopProcessList(
                    label: "Heaviest CPU users (energy proxy)",
                    sample: { ProcessMonitor().topCPUProcesses() },
                    format: { String(format: "%.0f%%", $0) }
                )
            } else {
                Text("On AC power / no battery").font(DashStyle.labelFont).foregroundColor(.secondary)
            }
        }
    }
}

