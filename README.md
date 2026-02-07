# Pipe Optimizer

`Pipe Optimizer` is an iOS app (Swift + SwiftUI, iOS 17+) that builds a connected orthogonal pipe network from one `Source` to multiple `Consumers` on a rectangular grid.

## Features

- Configurable grid size (default `20x30`)
- Random source placement on app start and on `Clear`
- Tap interaction on cells:
  - empty cell -> add consumer
  - consumer cell -> remove consumer
  - source cell is immutable
- `Optimize` builds a connected network to all consumers
- `Clear` removes all consumers and pipes, and places a new source
- Status line with:
  - `totalLength`
  - `junctionCount`
  - `consumerCount`

## Architecture (MVVM)

- **Model**
  - `Grid`, `GridCoordinate`, `GridEdge`, `GridDirection`
  - `GridNodeType`, `GridCell`, `GridState`
  - `PipeSolution`, `PipeMetrics`, `GridSettings`
- **ViewModel**
  - `PipeOptimizerViewModel`
- **Views**
  - `ContentView`
  - `GridView`
  - `CellView`
  - `ControlPanelView`
- **Algorithm module**
  - `PipeOptimizer` (pure optimization logic)

## Optimization Algorithm

The exact optimization objective (minimum connected rectilinear network with optional Steiner-like points and branch penalty) is NP-hard, so this project uses a practical approximation.

### Steps

1. **Terminal graph**: build a complete graph on terminals (`source + consumers`) with Manhattan edge weights.
2. **MST**: build a minimum spanning tree using Prim's algorithm.
3. **Grid embedding**: root MST at source and connect terminals incrementally on grid.
4. **Incremental Steiner-like routing** (post-improvement): for each next terminal, run multi-source Dijkstra/BFS-like routing toward the already built network.
5. **Junction-aware cost**: routing cost is:
   - `+1` for each newly added pipe edge
   - `+lambda` when a step would create a new junction (degree transitions from 2 to 3)

This allows reuse of existing pipes and typically reduces both length and unnecessary branching.

## Why this approach

- Fast enough for `20x30` grids and dozens of consumers
- Deterministic with fixed seed
- Produces connected networks and allows natural pipe merging
- Better practical quality than naive independent source-to-consumer shortest paths

## What is not guaranteed

- Global optimum is **not** guaranteed (approximation only)
- Depending on placement, local routing can settle in a local minimum
- Different heuristics can outperform this one on specific layouts

## Tuning parameters

- **`lambda` (junction penalty)**:
  - set in `GridSettings.defaultJunctionPenalty`
  - file: `PipesOptimizer/PipesOptimizer/Models/GridModels.swift`
  - passed into optimizer from `PipeOptimizerViewModel`
- **Grid size**:
  - set in `GridSettings.defaultRows` / `GridSettings.defaultColumns`
  - file: `PipesOptimizer/PipesOptimizer/Models/GridModels.swift`
- **Seed / determinism**:
  - optimizer seed and source seed live in `GridSettings`
  - app-level defaults are created in `PipesOptimizer/PipesOptimizer/PipesOptimizerApp.swift`

## Test coverage

### Unit tests (`PipeOptimizerTests`)

- `testSingleConsumerStraightLine`
- `testTwoConsumersOppositeSides`
- `testJunctionPenaltyEffect`
- `testDeterminismWithSeed`

### UI tests (`PipeOptimizerUITests`)

Scenario:
- launch app
- tap 3 different cells (non-source)
- tap `Optimize`
- verify at least one pipe accessibility marker exists
- tap `Clear`
- verify consumers and pipes are gone (`consumerCount == 0` and no pipe markers)

## Accessibility

- Cell identifier: `cell_r{row}_c{col}`
- State markers:
  - `source_cell_r{row}_c{col}`
  - `consumer_cell_r{row}_c{col}`
  - `pipe_cell_r{row}_c{col}`
  - `junction_cell_r{row}_c{col}`

## How to run

1. Open `/Users/nikitamushchak/Documents/artifacts/PipesOptimizer/PipesOptimizer/PipesOptimizer.xcodeproj` in Xcode.
2. Select the `PipesOptimizer` scheme.
3. Choose an iOS simulator (iOS 17+ runtime).
4. Run the app.

## How to run tests

From terminal:

```bash
cd /Users/nikitamushchak/Documents/artifacts/PipesOptimizer/PipesOptimizer
xcodebuild test -scheme PipesOptimizer -destination 'platform=iOS Simulator,name=iPhone 16'
```

(If simulator name differs on your machine, replace `iPhone 16` accordingly.)
