import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: PipeOptimizerViewModel

    init(settings: GridSettings = GridSettings()) {
        _viewModel = StateObject(wrappedValue: PipeOptimizerViewModel(settings: settings))
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Pipe Optimizer")
                .font(.title2.weight(.semibold))

            GridView(
                grid: viewModel.grid,
                cellProvider: { coordinate in
                    viewModel.cell(at: coordinate)
                },
                onCellTap: { coordinate in
                    viewModel.handleCellTap(at: coordinate)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 12)

            statusRow

            ControlPanelView(
                isOptimizing: viewModel.isOptimizing,
                onOptimize: {
                    viewModel.optimize()
                },
                onClear: {
                    viewModel.clear()
                }
            )
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var statusRow: some View {
        HStack(spacing: 16) {
            Text("Length: \(viewModel.totalLength)")
                .accessibilityIdentifier("status_totalLength")
                .accessibilityValue("\(viewModel.totalLength)")

            Text("Junctions: \(viewModel.junctionCount)")
                .accessibilityIdentifier("status_junctionCount")
                .accessibilityValue("\(viewModel.junctionCount)")

            Text("Consumers: \(viewModel.consumerCount)")
                .accessibilityIdentifier("status_consumerCount")
                .accessibilityValue("\(viewModel.consumerCount)")
        }
        .font(.subheadline.monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

#Preview {
    ContentView()
}
