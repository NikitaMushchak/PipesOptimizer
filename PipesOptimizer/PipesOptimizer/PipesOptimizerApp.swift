import SwiftUI

@main
struct PipesOptimizerApp: App {
    private let settings: GridSettings = {
        let arguments = ProcessInfo.processInfo.arguments
        let isUITesting = arguments.contains("-ui-testing")

        let sourceSeed: UInt64 = isUITesting ? 0xABCDEF : UInt64.random(in: UInt64.min...UInt64.max)
        let optimizerSeed: UInt64 = isUITesting ? 0x12345678 : GridSettings.defaultOptimizerSeed

        return GridSettings(
            rows: GridSettings.defaultRows,
            columns: GridSettings.defaultColumns,
            junctionPenalty: GridSettings.defaultJunctionPenalty,
            optimizerSeed: optimizerSeed,
            sourceSeed: sourceSeed
        )
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(settings: settings)
        }
    }
}
