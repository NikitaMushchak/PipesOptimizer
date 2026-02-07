import Foundation
internal import Combine

@MainActor
final class PipeOptimizerViewModel: ObservableObject {
    @Published private(set) var gridState: GridState
    @Published private(set) var solution: PipeSolution
    @Published private(set) var isOptimizing = false

    @Published var junctionPenalty: Double

    let settings: GridSettings

    private var sourceGenerator: SeededGenerator

    init(settings: GridSettings = GridSettings()) {
        self.settings = settings
        junctionPenalty = settings.junctionPenalty
        sourceGenerator = SeededGenerator(seed: settings.sourceSeed)

        let initialSource = PipeOptimizerViewModel.randomCoordinate(in: settings.grid, using: &sourceGenerator, avoiding: nil)
        gridState = GridState(grid: settings.grid, source: initialSource)
        solution = .empty
    }

    var grid: Grid {
        gridState.grid
    }

    var totalLength: Int {
        solution.metrics.totalLength
    }

    var junctionCount: Int {
        solution.metrics.junctionCount
    }

    var consumerCount: Int {
        gridState.consumers.count
    }

    func cell(at coordinate: GridCoordinate) -> GridCell {
        gridState.cell(at: coordinate)
    }

    func handleCellTap(at coordinate: GridCoordinate) {
        guard !isOptimizing else {
            return
        }

        guard coordinate != gridState.source else {
            return
        }

        if gridState.consumers.contains(coordinate) {
            gridState.consumers.remove(coordinate)
        } else {
            gridState.consumers.insert(coordinate)
        }

        resetNetwork()
    }

    func optimize() {
        guard !isOptimizing else {
            return
        }

        let grid = gridState.grid
        let source = gridState.source
        let consumers = gridState.consumers

        guard !consumers.isEmpty else {
            resetNetwork()
            return
        }

        let optimizerConfiguration = PipeOptimizer.Configuration(
            junctionPenalty: junctionPenalty,
            seed: settings.optimizerSeed
        )

        isOptimizing = true

        Task {
            let computedSolution = await Task.detached(priority: .userInitiated) {
                PipeOptimizer(configuration: optimizerConfiguration)
                    .optimize(grid: grid, source: source, consumers: consumers)
            }.value

            solution = computedSolution
            gridState.apply(solution: computedSolution)
            isOptimizing = false
        }
    }

    func clear() {
        guard !isOptimizing else {
            return
        }

        let previousSource = gridState.source
        gridState.source = PipeOptimizerViewModel.randomCoordinate(
            in: gridState.grid,
            using: &sourceGenerator,
            avoiding: previousSource
        )
        gridState.consumers.removeAll()

        resetNetwork()
    }

    private func resetNetwork() {
        solution = .empty
        gridState.clearNetwork()
    }

    private static func randomCoordinate(
        in grid: Grid,
        using generator: inout SeededGenerator,
        avoiding forbidden: GridCoordinate?
    ) -> GridCoordinate {
        if grid.cellCount == 1 {
            return GridCoordinate(row: 0, column: 0)
        }

        while true {
            let index = generator.nextInt(upperBound: grid.cellCount)
            let candidate = grid.coordinate(for: index)
            if candidate != forbidden {
                return candidate
            }
        }
    }
}

private struct SeededGenerator: Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xD00DFEED : seed
    }

    mutating func nextInt(upperBound: Int) -> Int {
        precondition(upperBound > 0, "Upper bound must be positive.")
        return Int(next() % UInt64(upperBound))
    }

    private mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
