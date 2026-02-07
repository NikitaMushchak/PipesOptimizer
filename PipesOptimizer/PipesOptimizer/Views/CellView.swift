import SwiftUI

struct CellView: View {
    let cell: GridCell
    let onTap: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button(action: onTap) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(backgroundColor)

                    PipeSegmentsShape(directions: cell.connections)
                        .stroke(pipeColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .padding(4)
                        .allowsHitTesting(false)

                    if cell.isJunction {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                    }

                    iconLayer
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("grid-cell")
            .accessibilityValue(cell.accessibilityState)
            .accessibilityIdentifier("cell_r\(cell.coordinate.row)_c\(cell.coordinate.column)")

            stateMarkers
                .allowsHitTesting(false)
        }
    }

    private var backgroundColor: Color {
        switch cell.nodeType {
        case .empty:
            return Color(uiColor: .systemBackground)
        case .source:
            return Color.blue.opacity(0.18)
        case .consumer:
            return Color.green.opacity(0.18)
        case .pipe:
            return Color(uiColor: .systemGray6)
        }
    }

    private var pipeColor: Color {
        cell.isJunction ? .orange : .blue
    }

    @ViewBuilder
    private var iconLayer: some View {
        switch cell.nodeType {
        case .source:
            Image(systemName: "drop.fill")
                .foregroundStyle(.blue)
                .font(.system(size: 12, weight: .bold))
                .accessibilityHidden(true)
        case .consumer:
            Image(systemName: "circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 10, weight: .bold))
                .accessibilityHidden(true)
        case .empty, .pipe:
            EmptyView()
        }
    }

    @ViewBuilder
    private var stateMarkers: some View {
        VStack(alignment: .leading, spacing: 0) {
            if cell.nodeType == .source {
                AccessibilityMarker(identifier: "source_cell_r\(cell.coordinate.row)_c\(cell.coordinate.column)")
            }

            if cell.nodeType == .consumer {
                AccessibilityMarker(identifier: "consumer_cell_r\(cell.coordinate.row)_c\(cell.coordinate.column)")
            }

            if cell.nodeType == .pipe || cell.isJunction {
                AccessibilityMarker(identifier: "pipe_cell_r\(cell.coordinate.row)_c\(cell.coordinate.column)")
            }

            if cell.isJunction {
                AccessibilityMarker(identifier: "junction_cell_r\(cell.coordinate.row)_c\(cell.coordinate.column)")
            }
        }
    }
}

private struct PipeSegmentsShape: Shape {
    let directions: Set<GridDirection>

    func path(in rect: CGRect) -> Path {
        guard !directions.isEmpty else {
            return Path()
        }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()

        for direction in directions {
            let endpoint: CGPoint
            switch direction {
            case .up:
                endpoint = CGPoint(x: center.x, y: rect.minY)
            case .down:
                endpoint = CGPoint(x: center.x, y: rect.maxY)
            case .left:
                endpoint = CGPoint(x: rect.minX, y: center.y)
            case .right:
                endpoint = CGPoint(x: rect.maxX, y: center.y)
            }

            path.move(to: center)
            path.addLine(to: endpoint)
        }

        return path
    }
}

private struct AccessibilityMarker: View {
    let identifier: String

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier(identifier)
            .accessibilityLabel(identifier)
    }
}
