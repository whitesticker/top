import SwiftUI

/// Small pill badge shared by the small metric widgets and the all-in-one
/// grid (e.g. a temperature or memory-pressure status label).
struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}

/// Shared threshold classifiers so every widget (small gauges and the
/// all-in-one grid) agrees on what counts as "Normal" vs "Warm"/"Hot" or
/// "Busy", rather than each view picking its own cutoffs.
enum WidgetStatus {
    static func pressure(_ pressure: Double) -> (label: String, color: Color) {
        if pressure < 0.6 { return ("Normal", DashColors.statusGood) }
        if pressure < 0.8 { return ("Warning", DashColors.statusWarning) }
        return ("Critical", DashColors.statusCritical)
    }

    static func temperature(_ celsius: Double) -> (label: String, color: Color) {
        if celsius <= 0 { return ("—", .secondary) }
        if celsius < 65 { return ("Normal", DashColors.statusGood) }
        if celsius < 85 { return ("Warm", DashColors.statusWarning) }
        return ("Hot", DashColors.statusCritical)
    }

    static func load(_ fraction: Double) -> (label: String, color: Color) {
        if fraction < 0.5 { return ("Normal", DashColors.statusGood) }
        if fraction < 0.85 { return ("Busy", DashColors.statusWarning) }
        return ("High", DashColors.statusCritical)
    }
}
