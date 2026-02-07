import SwiftUI

struct GridView: View {
    let grid: Grid
    let cellProvider: (GridCoordinate) -> GridCell
    let onCellTap: (GridCoordinate) -> Void

    private let spacing: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            let cellSide = min(
                (geometry.size.width - spacing * CGFloat(grid.columns - 1)) / CGFloat(grid.columns),
                (geometry.size.height - spacing * CGFloat(grid.rows - 1)) / CGFloat(grid.rows)
            )

            let gridWidth = cellSide * CGFloat(grid.columns) + spacing * CGFloat(grid.columns - 1)
            let gridHeight = cellSide * CGFloat(grid.rows) + spacing * CGFloat(grid.rows - 1)

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(uiColor: .secondarySystemBackground))

                VStack(spacing: spacing) {
                    ForEach(0..<grid.rows, id: \ .self) { row in
                        HStack(spacing: spacing) {
                            ForEach(0..<grid.columns, id: \ .self) { column in
                                let coordinate = GridCoordinate(row: row, column: column)
                                CellView(cell: cellProvider(coordinate)) {
                                    onCellTap(coordinate)
                                }
                                .frame(width: cellSide, height: cellSide)
                            }
                        }
                    }
                }
                .frame(width: gridWidth, height: gridHeight)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}
