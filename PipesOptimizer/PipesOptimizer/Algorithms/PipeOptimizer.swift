import Foundation

struct PipeOptimizer {
    struct Configuration: Sendable {
        var junctionPenalty: Double
        var seed: UInt64
    }

    private let configuration: Configuration

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    func optimize(grid: Grid, source: GridCoordinate, consumers: Set<GridCoordinate>) -> PipeSolution {
        let normalizedConsumers = consumers.filter { $0 != source }
        guard !normalizedConsumers.isEmpty else {
            return .empty
        }

        let orderedConsumers = normalizedConsumers.sorted()
        let terminals = [source] + orderedConsumers

        let mstEdges = buildMST(for: terminals)
        let connectionOrder = buildConnectionOrder(for: terminals, mstEdges: mstEdges)

        var networkEdges: Set<GridEdge> = []
        var degreeMap: [GridCoordinate: Int] = [:]
        var networkNodes: Set<GridCoordinate> = [source]

        for terminalIndex in connectionOrder {
            let terminal = terminals[terminalIndex]
            if networkNodes.contains(terminal) {
                continue
            }

            let path = shortestAttachmentPath(
                from: terminal,
                toAnyOf: networkNodes,
                grid: grid,
                existingEdges: networkEdges,
                degreeMap: degreeMap
            )

            addPath(path, networkEdges: &networkEdges, degreeMap: &degreeMap, networkNodes: &networkNodes)
        }

        let connectionMap = PipeSolution.buildConnectionMap(from: networkEdges)
        let junctions = Set(connectionMap.compactMap { coordinate, directions in
            directions.count > 2 ? coordinate : nil
        })

        let pipeCells = Set(connectionMap.keys.filter { coordinate in
            coordinate != source && !normalizedConsumers.contains(coordinate)
        })

        return PipeSolution(
            pipeEdges: networkEdges,
            pipeCells: pipeCells,
            junctions: junctions,
            connectionMap: connectionMap,
            metrics: PipeMetrics(totalLength: networkEdges.count, junctionCount: junctions.count)
        )
    }
}

private extension PipeOptimizer {
    struct MSTEdge {
        let u: Int
        let v: Int
        let weight: Int
    }

    struct CandidateState {
        let index: Int
        let cost: Double
        let steps: Int
    }

    func buildMST(for terminals: [GridCoordinate]) -> [MSTEdge] {
        guard terminals.count > 1 else {
            return []
        }

        var inTree: Set<Int> = [0]
        var mstEdges: [MSTEdge] = []

        while inTree.count < terminals.count {
            var best: MSTEdge?

            for u in inTree.sorted() {
                for v in 0..<terminals.count where !inTree.contains(v) {
                    let edge = MSTEdge(u: u, v: v, weight: terminals[u].manhattanDistance(to: terminals[v]))
                    if let currentBest = best {
                        if isBetterMSTEdge(edge, than: currentBest, terminals: terminals) {
                            best = edge
                        }
                    } else {
                        best = edge
                    }
                }
            }

            guard let chosen = best else {
                break
            }

            inTree.insert(chosen.u)
            inTree.insert(chosen.v)
            mstEdges.append(chosen)
        }

        return mstEdges
    }

    func buildConnectionOrder(for terminals: [GridCoordinate], mstEdges: [MSTEdge]) -> [Int] {
        var adjacency: [Int: [(neighbor: Int, weight: Int)]] = [:]
        for edge in mstEdges {
            adjacency[edge.u, default: []].append((edge.v, edge.weight))
            adjacency[edge.v, default: []].append((edge.u, edge.weight))
        }

        var order: [Int] = []
        var queue: [Int] = [0]
        var visited: Set<Int> = [0]
        var head = 0

        while head < queue.count {
            let node = queue[head]
            head += 1

            let sortedNeighbors = (adjacency[node] ?? []).sorted { lhs, rhs in
                if lhs.weight != rhs.weight {
                    return lhs.weight < rhs.weight
                }

                return tieKey(for: terminals[lhs.neighbor]) < tieKey(for: terminals[rhs.neighbor])
            }

            for entry in sortedNeighbors where !visited.contains(entry.neighbor) {
                visited.insert(entry.neighbor)
                queue.append(entry.neighbor)
                order.append(entry.neighbor)
            }
        }

        return order
    }

    func shortestAttachmentPath(
        from start: GridCoordinate,
        toAnyOf targets: Set<GridCoordinate>,
        grid: Grid,
        existingEdges: Set<GridEdge>,
        degreeMap: [GridCoordinate: Int]
    ) -> [GridCoordinate] {
        if targets.contains(start) {
            return [start]
        }

        let total = grid.cellCount
        let epsilon = 1e-9

        var distances = Array(repeating: Double.infinity, count: total)
        var steps = Array(repeating: Int.max, count: total)
        var predecessors = Array(repeating: -1, count: total)
        var visited = Array(repeating: false, count: total)

        let startIndex = grid.index(of: start)
        distances[startIndex] = 0
        steps[startIndex] = 0

        var targetIndex = -1

        for _ in 0..<total {
            var bestState: CandidateState?

            for index in 0..<total where !visited[index] && distances[index].isFinite {
                let state = CandidateState(index: index, cost: distances[index], steps: steps[index])
                if let currentBest = bestState {
                    if isBetterCandidate(state, than: currentBest, grid: grid) {
                        bestState = state
                    }
                } else {
                    bestState = state
                }
            }

            guard let currentState = bestState else {
                break
            }

            visited[currentState.index] = true
            let currentCoordinate = grid.coordinate(for: currentState.index)

            if targets.contains(currentCoordinate) && currentCoordinate != start {
                targetIndex = currentState.index
                break
            }

            for direction in GridDirection.allCases {
                guard let neighbor = currentCoordinate.moved(direction, in: grid) else {
                    continue
                }

                let neighborIndex = grid.index(of: neighbor)
                if visited[neighborIndex] {
                    continue
                }

                let edge = GridEdge(currentCoordinate, neighbor)
                let isNewEdge = !existingEdges.contains(edge)

                let additionalCost: Double
                let additionalSteps: Int

                if isNewEdge {
                    let junctionPenalty = Double(
                        junctionDelta(for: currentCoordinate, degreeMap: degreeMap)
                            + junctionDelta(for: neighbor, degreeMap: degreeMap)
                    ) * configuration.junctionPenalty

                    additionalCost = 1.0 + junctionPenalty
                    additionalSteps = 1
                } else {
                    additionalCost = 0
                    additionalSteps = 0
                }

                let candidateCost = distances[currentState.index] + additionalCost
                let candidateSteps = steps[currentState.index] + additionalSteps

                let shouldReplace: Bool
                if candidateCost + epsilon < distances[neighborIndex] {
                    shouldReplace = true
                } else if abs(candidateCost - distances[neighborIndex]) <= epsilon {
                    if candidateSteps < steps[neighborIndex] {
                        shouldReplace = true
                    } else if candidateSteps == steps[neighborIndex] {
                        let currentPredecessorIndex = predecessors[neighborIndex]
                        if currentPredecessorIndex == -1 {
                            shouldReplace = true
                        } else {
                            let currentPredecessor = grid.coordinate(for: currentPredecessorIndex)
                            shouldReplace = tieKey(for: currentCoordinate) < tieKey(for: currentPredecessor)
                        }
                    } else {
                        shouldReplace = false
                    }
                } else {
                    shouldReplace = false
                }

                if shouldReplace {
                    distances[neighborIndex] = candidateCost
                    steps[neighborIndex] = candidateSteps
                    predecessors[neighborIndex] = currentState.index
                }
            }
        }

        guard targetIndex != -1 else {
            return fallbackPath(from: start, to: bestFallbackTarget(from: start, targets: targets))
        }

        var reversedPath: [GridCoordinate] = []
        var cursor = targetIndex

        while cursor != -1 {
            reversedPath.append(grid.coordinate(for: cursor))
            if cursor == startIndex {
                break
            }
            cursor = predecessors[cursor]
        }

        guard reversedPath.last == start else {
            return fallbackPath(from: start, to: bestFallbackTarget(from: start, targets: targets))
        }

        return Array(reversedPath.reversed())
    }

    func addPath(
        _ path: [GridCoordinate],
        networkEdges: inout Set<GridEdge>,
        degreeMap: inout [GridCoordinate: Int],
        networkNodes: inout Set<GridCoordinate>
    ) {
        guard path.count > 1 else {
            if let only = path.first {
                networkNodes.insert(only)
            }
            return
        }

        for coordinate in path {
            networkNodes.insert(coordinate)
        }

        for index in 0..<(path.count - 1) {
            let edge = GridEdge(path[index], path[index + 1])
            let (inserted, _) = networkEdges.insert(edge)
            if inserted {
                degreeMap[edge.a, default: 0] += 1
                degreeMap[edge.b, default: 0] += 1
            }
        }
    }

    func junctionDelta(for coordinate: GridCoordinate, degreeMap: [GridCoordinate: Int]) -> Int {
        degreeMap[coordinate, default: 0] == 2 ? 1 : 0
    }

    func fallbackPath(from start: GridCoordinate, to target: GridCoordinate) -> [GridCoordinate] {
        var path: [GridCoordinate] = [start]

        var current = start

        // Deterministic L-path orientation based on seed for reproducibility.
        let preferHorizontalFirst = (tieKey(for: start) ^ tieKey(for: target)) & 1 == 0

        if preferHorizontalFirst {
            while current.column != target.column {
                let step = current.column < target.column ? 1 : -1
                current = GridCoordinate(row: current.row, column: current.column + step)
                path.append(current)
            }
            while current.row != target.row {
                let step = current.row < target.row ? 1 : -1
                current = GridCoordinate(row: current.row + step, column: current.column)
                path.append(current)
            }
        } else {
            while current.row != target.row {
                let step = current.row < target.row ? 1 : -1
                current = GridCoordinate(row: current.row + step, column: current.column)
                path.append(current)
            }
            while current.column != target.column {
                let step = current.column < target.column ? 1 : -1
                current = GridCoordinate(row: current.row, column: current.column + step)
                path.append(current)
            }
        }

        return path
    }

    func bestFallbackTarget(from start: GridCoordinate, targets: Set<GridCoordinate>) -> GridCoordinate {
        targets.min { lhs, rhs in
            let lhsDistance = start.manhattanDistance(to: lhs)
            let rhsDistance = start.manhattanDistance(to: rhs)

            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }

            return tieKey(for: lhs) < tieKey(for: rhs)
        } ?? start
    }

    func isBetterMSTEdge(_ lhs: MSTEdge, than rhs: MSTEdge, terminals: [GridCoordinate]) -> Bool {
        if lhs.weight != rhs.weight {
            return lhs.weight < rhs.weight
        }

        let lhsTie = tieKey(for: terminals[lhs.u]) ^ tieKey(for: terminals[lhs.v])
        let rhsTie = tieKey(for: terminals[rhs.u]) ^ tieKey(for: terminals[rhs.v])

        if lhsTie != rhsTie {
            return lhsTie < rhsTie
        }

        if lhs.u != rhs.u {
            return lhs.u < rhs.u
        }

        return lhs.v < rhs.v
    }

    func isBetterCandidate(_ lhs: CandidateState, than rhs: CandidateState, grid: Grid) -> Bool {
        let epsilon = 1e-9

        if lhs.cost + epsilon < rhs.cost {
            return true
        }

        if abs(lhs.cost - rhs.cost) <= epsilon {
            if lhs.steps != rhs.steps {
                return lhs.steps < rhs.steps
            }

            let lhsCoordinate = grid.coordinate(for: lhs.index)
            let rhsCoordinate = grid.coordinate(for: rhs.index)
            return tieKey(for: lhsCoordinate) < tieKey(for: rhsCoordinate)
        }

        return false
    }

    func tieKey(for coordinate: GridCoordinate) -> UInt64 {
        var value = configuration.seed
        value ^= UInt64(bitPattern: Int64(coordinate.row)) &* 0x9E3779B185EBCA87
        value ^= UInt64(bitPattern: Int64(coordinate.column)) &* 0xC2B2AE3D27D4EB4F
        return splitMix64(value)
    }

    func splitMix64(_ x: UInt64) -> UInt64 {
        var z = x &+ 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
