import WidgetKit
import SwiftUI

@main
struct TopWidgetBundle: WidgetBundle {
    var body: some Widget {
        CPUWidget()
        GPUWidget()
        MemoryWidget()
        NetworkWidget()
        DiskWidget()
        SensorsWidget()
        BatteryWidget()
        AllInOneWidget()
    }
}
