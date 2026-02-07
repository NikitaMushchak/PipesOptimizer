import Foundation

enum GridNodeType: String, Sendable {
    case empty
    case source
    case consumer
    case pipe
}

enum GridDirection: CaseIterable, Hashable, Sendable {
    case up
    case down
    case left
    case right

    var rowOffset: Int {
        switch self {
        case .up: return -1
        case .down: return 1
        case .left, .right: return 0
        }
    }

    var columnOffset: Int {
        switch self {
        case .left: return -1
        case .right: return 1
        case .up, .down: return 0
        }
    }

    var opposite: GridDirection {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }
}

struct GridCoordinate: Hashable, Comparable, Sendable {
    let row: Int
    let column: Int

    static func < (lhs: GridCoordinate, rhs: GridCoordinate) -> Bool {
        if lhs.row == rhs.row {
            return lhs.column < rhs.column
        }
        return lhs.row < rhs.row
    }

    func manhattanDistance(to other: GridCoordinate) -> Int {
        abs(row - other.row) + abs(column - other.column)
    }

    func moved(_ direction: GridDirection, in grid: Grid) -> GridCoordinate? {
        let candidate = GridCoordinate(row: row + direction.rowOffset, column: column + direction.columnOffset)
        return grid.contains(candidate) ? candidate : nil
    }
}

extension GridCoordinate: Identifiable {
    var id: String {
        "r\(row)_c\(column)"
    }
}

struct GridEdge: Hashable, Sendable {
    let a: GridCoordinate
    let b: GridCoordinate

    init(_ first: GridCoordinate, _ second: GridCoordinate) {
        if first <= second {
            a = first
            b = second
        } else {
            a = second
            b = first
        }
    }

    func contains(_ coordinate: GridCoordinate) -> Bool {
        a == coordinate || b == coordinate
    }

    func other(than coordinate: GridCoordinate) -> GridCoordinate? {
        if a == coordinate { return b }
        if b == coordinate { return a }
        return nil
    }
}

struct Grid: Hashable, Sendable {
    let rows: Int
    let columns: Int

    init(rows: Int, columns: Int) {
        precondition(rows > 0 && columns > 0, "Grid dimensions must be positive.")
        self.rows = rows
        self.columns = columns
    }

    var cellCount: Int {
        rows * columns
    }

    func contains(_ coordinate: GridCoordinate) -> Bool {
        coordinate.row >= 0
            && coordinate.row < rows
            && coordinate.column >= 0
            && coordinate.column < columns
    }

    func index(of coordinate: GridCoordinate) -> Int {
        coordinate.row * columns + coordinate.column
    }

    func coordinate(for index: Int) -> GridCoordinate {
        GridCoordinate(row: index / columns, column: index % columns)
    }
}

struct PipeMetrics: Equatable, Sendable {
    let totalLength: Int
    let junctionCount: Int
}

struct PipeSolution: Equatable, Sendable {
    let pipeEdges: Set<GridEdge>
    let pipeCells: Set<GridCoordinate>
    let junctions: Set<GridCoordinate>
    let connectionMap: [GridCoordinate: Set<GridDirection>]
    let metrics: PipeMetrics

    static let empty = PipeSolution(
        pipeEdges: [],
        pipeCells: [],
        junctions: [],
        connectionMap: [:],
        metrics: PipeMetrics(totalLength: 0, junctionCount: 0)
    )

    func isFullyConnected(source: GridCoordinate, consumers: Set<GridCoordinate>) -> Bool {
        if consumers.isEmpty {
            return true
        }

        var adjacency: [GridCoordinate: Set<GridCoordinate>] = [:]
        for edge in pipeEdges {
            adjacency[edge.a, default: []].insert(edge.b)
            adjacency[edge.b, default: []].insert(edge.a)
        }

        var visited: Set<GridCoordinate> = [source]
        var queue: [GridCoordinate] = [source]
        var head = 0

        while head < queue.count {
            let current = queue[head]
            head += 1
            for neighbor in adjacency[current] ?? [] where !visited.contains(neighbor) {
                visited.insert(neighbor)
                queue.append(neighbor)
            }
        }

        return consumers.isSubset(of: visited)
    }

    static func buildConnectionMap(from edges: Set<GridEdge>) -> [GridCoordinate: Set<GridDirection>] {
        var map: [GridCoordinate: Set<GridDirection>] = [:]

        for edge in edges {
            let direction: GridDirection
            if edge.a.row == edge.b.row {
                direction = edge.a.column < edge.b.column ? .right : .left
            } else {
                direction = edge.a.row < edge.b.row ? .down : .up
            }

            map[edge.a, default: []].insert(direction)
            map[edge.b, default: []].insert(direction.opposite)
        }

        return map
    }
}

struct GridCell: Hashable, Sendable {
    let coordinate: GridCoordinate
    let nodeType: GridNodeType
    let connections: Set<GridDirection>
    let isJunction: Bool

    var accessibilityState: String {
        switch nodeType {
        case .source:
            return "source"
        case .consumer:
            return "consumer"
        case .pipe:
            return isJunction ? "junction" : "pipe"
        case .empty:
            return "empty"
        }
    }
}

struct GridSettings: Hashable, Sendable {
    static let defaultRows = 20
    static let defaultColumns = 30

    // Tune this parameter to penalize creating new junctions.
    static let defaultJunctionPenalty = 1.25

    static let defaultOptimizerSeed: UInt64 = 0xD15EA5E5
    static let defaultSourceSeed: UInt64 = 0xC0FFEE

    let grid: Grid
    let junctionPenalty: Double
    let optimizerSeed: UInt64
    let sourceSeed: UInt64

    init(
        rows: Int = GridSettings.defaultRows,
        columns: Int = GridSettings.defaultColumns,
        junctionPenalty: Double = GridSettings.defaultJunctionPenalty,
        optimizerSeed: UInt64 = GridSettings.defaultOptimizerSeed,
        sourceSeed: UInt64 = GridSettings.defaultSourceSeed
    ) {
        grid = Grid(rows: rows, columns: columns)
        self.junctionPenalty = junctionPenalty
        self.optimizerSeed = optimizerSeed
        self.sourceSeed = sourceSeed
    }
}

struct GridState: Sendable {
    let grid: Grid
    var source: GridCoordinate
    var consumers: Set<GridCoordinate>
    var pipeEdges: Set<GridEdge>
    var pipeCells: Set<GridCoordinate>
    var junctions: Set<GridCoordinate>
    var connectionMap: [GridCoordinate: Set<GridDirection>]

    init(grid: Grid, source: GridCoordinate, consumers: Set<GridCoordinate> = []) {
        self.grid = grid
        self.source = source
        self.consumers = consumers
        pipeEdges = []
        pipeCells = []
        junctions = []
        connectionMap = [:]
    }

    mutating func clearNetwork() {
        pipeEdges = []
        pipeCells = []
        junctions = []
        connectionMap = [:]
    }

    mutating func apply(solution: PipeSolution) {
        pipeEdges = solution.pipeEdges
        pipeCells = solution.pipeCells
        junctions = solution.junctions
        connectionMap = solution.connectionMap
    }

    func nodeType(at coordinate: GridCoordinate) -> GridNodeType {
        if coordinate == source {
            return .source
        }
        if consumers.contains(coordinate) {
            return .consumer
        }
        if connectionMap[coordinate] != nil {
            return .pipe
        }
        return .empty
    }

    func cell(at coordinate: GridCoordinate) -> GridCell {
        GridCell(
            coordinate: coordinate,
            nodeType: nodeType(at: coordinate),
            connections: connectionMap[coordinate] ?? [],
            isJunction: junctions.contains(coordinate)
        )
    }
}
