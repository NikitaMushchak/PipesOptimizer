import SwiftUI

struct ControlPanelView: View {
    let isOptimizing: Bool
    let onOptimize: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOptimize) {
                Label("Optimize", systemImage: "point.3.connected.trianglepath.dotted")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isOptimizing)
            .accessibilityIdentifier("optimize_button")

            Button(action: onClear) {
                Label("Clear", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isOptimizing)
            .accessibilityIdentifier("clear_button")
        }
        .overlay(alignment: .trailing) {
            if isOptimizing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding(.trailing, 8)
                    .accessibilityIdentifier("optimize_progress")
            }
        }
    }
}
