import Foundation
import Darwin
import AppKit

// On-demand "who's using the most X right now" lookups, used by each
// section's detail popover (via `.task`, only while that popover is open).
// Deliberately NOT sampled on SystemMonitor's continuous per-second polling
// loop like every other monitor in this app: walking every process on the
// system and reading its task/rusage info is meaningfully more expensive
// than the handful of sysctl/mach calls the other monitors make, and would
// cost that overhead forever in the background even when nobody's looking.
//
// CPU and disk I/O are rates, so each of those takes two live samples ~0.2s
// apart and reports the delta -- a single instantaneous reading isn't
// meaningful for either (same reason CPUMonitor needs two tick samples).
// Memory is an instantaneous gauge (resident size), so no delta is needed.
//
// Network has no equivalent public per-process API on macOS without extra
// entitlements (unlike CPU/memory/disk, which libproc exposes cleanly), so
// it shells out to the `nettop` command-line tool and parses its CSV-ish
// output -- best-effort, and returns an empty list if parsing fails rather
// than showing wrong numbers.
final class ProcessMonitor {
    struct TopProcess: Sendable, Identifiable {
        var id: pid_t { pid }
        var pid: pid_t
        var name: String
        var value: Double
    }

    // MARK: - CPU

    func topCPUProcesses(count: Int = 5) -> [TopProcess] {
        let before = allCPUTicks()
        Thread.sleep(forTimeInterval: 0.2)
        let after = allCPUTicks()

        guard !before.isEmpty, !after.isEmpty else { return [] }
        let beforeByPID = Dictionary(uniqueKeysWithValues: before)

        var deltas: [(pid: pid_t, delta: UInt64)] = []
        for (pid, ticks) in after {
            guard let prevTicks = beforeByPID[pid], ticks >= prevTicks else { continue }
            let delta = ticks - prevTicks
            guard delta > 0 else { continue }
            deltas.append((pid, delta))
        }

        return deltas.sorted { $0.delta > $1.delta }.prefix(count).compactMap { entry in
            guard let name = processName(pid: entry.pid) else { return nil }
            let seconds = machTicksToSeconds(entry.delta)
            let percent = (seconds / 0.2) * 100
            return TopProcess(pid: entry.pid, name: name, value: percent)
        }
    }

    private func allCPUTicks() -> [(pid_t, UInt64)] {
        allPIDs().compactMap { pid in
            guard let info = taskInfo(pid: pid) else { return nil }
            return (pid, info.pti_total_user + info.pti_total_system)
        }
    }

    // MARK: - Memory

    func topMemoryProcesses(count: Int = 5) -> [TopProcess] {
        var entries: [(pid: pid_t, bytes: UInt64)] = []
        for pid in allPIDs() {
            guard let info = taskInfo(pid: pid), info.pti_resident_size > 0 else { continue }
            entries.append((pid, info.pti_resident_size))
        }

        return entries.sorted { $0.bytes > $1.bytes }.prefix(count).compactMap { entry in
            guard let name = processName(pid: entry.pid) else { return nil }
            return TopProcess(pid: entry.pid, name: name, value: Double(entry.bytes))
        }
    }

    // MARK: - Disk

    func topDiskProcesses(count: Int = 5) -> [TopProcess] {
        let before = allDiskIOBytes()
        Thread.sleep(forTimeInterval: 0.2)
        let after = allDiskIOBytes()

        guard !before.isEmpty, !after.isEmpty else { return [] }

        var deltas: [(pid: pid_t, delta: UInt64)] = []
        for (pid, cur) in after {
            guard let prev = before[pid], cur >= prev else { continue }
            let delta = cur - prev
            guard delta > 0 else { continue }
            deltas.append((pid, delta))
        }

        return deltas.sorted { $0.delta > $1.delta }.prefix(count).compactMap { entry in
            guard let name = processName(pid: entry.pid) else { return nil }
            let bytesPerSec = Double(entry.delta) / 0.2
            return TopProcess(pid: entry.pid, name: name, value: bytesPerSec)
        }
    }

    private func allDiskIOBytes() -> [pid_t: UInt64] {
        var result: [pid_t: UInt64] = [:]
        for pid in allPIDs() {
            guard let bytes = diskIOBytes(pid: pid) else { continue }
            result[pid] = bytes
        }
        return result
    }

    // MARK: - Network (best-effort via `nettop`)

    func topNetworkProcesses(count: Int = 5) -> [TopProcess] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        task.arguments = ["-P", "-x", "-l", "2", "-J", "bytes_in,bytes_out"]

        let outPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = Pipe()

        do {
            try task.run()
        } catch {
            return []
        }
        task.waitUntilExit()

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return Self.parseNettopTopProcesses(output, count: count)
    }

    // `nettop -P -x -l 2 -J bytes_in,bytes_out` prints one CSV header +
    // process rows per sample, sampling twice one second apart. Use the
    // last block: its byte columns reflect that real one-second interval,
    // not a cumulative counter since an arbitrary start point.
    static func parseNettopTopProcesses(_ output: String, count: Int = 5) -> [TopProcess] {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard let lastHeaderIndex = lines.lastIndex(where: { $0.hasPrefix("time,") }) else {
            return []
        }
        let header = lines[lastHeaderIndex].split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard let nameIdx = header.firstIndex(of: "time"),
              let inIdx = header.firstIndex(of: "bytes_in"),
              let outIdx = header.firstIndex(of: "bytes_out") else { return [] }

        var entries: [TopProcess] = []
        for line in lines[(lastHeaderIndex + 1)...] {
            if line.hasPrefix("time,") { break }
            let cols = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard cols.count > inIdx, cols.count > outIdx, cols.count > nameIdx else { continue }
            guard let bytesIn = Double(cols[inIdx]), let bytesOut = Double(cols[outIdx]) else { continue }
            let total = bytesIn + bytesOut
            guard total > 0 else { continue }
            // nettop's process column looks like "Safari.123" (name.pid) --
            // strip the trailing ".<pid>" and recover the pid for icon lookup.
            var nameParts = cols[nameIdx].split(separator: ".")
            var pid: pid_t = 0
            if nameParts.count > 1, let parsedPID = Int32(nameParts.last!) {
                pid = parsedPID
                nameParts.removeLast()
            }
            let display = nameParts.joined(separator: ".")
            guard !display.isEmpty else { continue }
            entries.append(TopProcess(pid: pid, name: display, value: total))
        }

        return entries.sorted { $0.value > $1.value }.prefix(count).map { $0 }
    }

    // MARK: - Icons

    // Prefers the real app icon (matches Dock/Finder) for foreground/GUI
    // apps; falls back to the generic executable icon Activity Monitor
    // shows for background daemons that aren't registered running apps.
    static func icon(for pid: pid_t) -> NSImage? {
        if let app = NSRunningApplication(processIdentifier: pid), let icon = app.icon {
            return icon
        }
        var pathBuf = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let len = proc_pidpath(pid, &pathBuf, UInt32(pathBuf.count))
        guard len > 0 else { return nil }
        return NSWorkspace.shared.icon(forFile: String(cString: pathBuf))
    }

    // MARK: - libproc helpers

    private func allPIDs() -> [pid_t] {
        let bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bufferSize > 0 else { return [] }
        let capacity = Int(bufferSize) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: capacity)
        let actualSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, bufferSize)
        guard actualSize > 0 else { return [] }
        let count = Int(actualSize) / MemoryLayout<pid_t>.size
        return pids.prefix(count).filter { $0 > 0 }
    }

    private func processName(pid: pid_t) -> String? {
        var nameBuf = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let len = proc_name(pid, &nameBuf, UInt32(nameBuf.count))
        guard len > 0 else { return nil }
        return String(cString: nameBuf)
    }

    private func taskInfo(pid: pid_t) -> proc_taskinfo? {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let result = withUnsafeMutablePointer(to: &info) { ptr -> Int32 in
            proc_pidinfo(pid, PROC_PIDTASKINFO, 0, ptr, size)
        }
        guard result == size else { return nil }
        return info
    }

    private func diskIOBytes(pid: pid_t) -> UInt64? {
        // `rusage_info_t` is `UnsafeMutableRawPointer?` and the C signature
        // is nominally "pointer to that" (a double pointer) -- but the real
        // ABI (matching how Apple's own examples call this) is that the
        // kernel writes `sizeof(rusage_info_v4)` bytes directly at the
        // address you pass, not through a second level of indirection. This
        // reinterprets the pointer to `info` itself, matching the C idiom
        // `(rusage_info_t *)&info`. An earlier version instead created a
        // separate 8-byte pointer variable and passed *its* address, so the
        // kernel wrote a ~200-byte struct into that 8-byte stack slot --
        // a stack buffer overflow that crashed the app (SIGABRT,
        // `__stack_chk_fail`).
        var info = rusage_info_v4()
        let result: Int32 = withUnsafeMutablePointer(to: &info) { infoPtr -> Int32 in
            infoPtr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { reboundPtr in
                proc_pid_rusage(pid, RUSAGE_INFO_V4, reboundPtr)
            }
        }
        guard result == 0 else { return nil }
        return info.ri_diskio_bytesread + info.ri_diskio_byteswritten
    }

    private func machTicksToSeconds(_ ticks: UInt64) -> Double {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        guard timebase.denom > 0 else { return 0 }
        let nanos = ticks * UInt64(timebase.numer) / UInt64(timebase.denom)
        return Double(nanos) / 1_000_000_000
    }
}
