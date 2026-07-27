# swift-router

## 0.2.0

### Minor Changes

- 96d3369: Added primary associated type on `URLRouter` for shared `state`
- 96d3369: Add changeset versioning
- 96d3369: Added deep linking for custom schemes and universal links
- 96d3369: Add agent skills
- 96d3369: Added URL parsing from and into routes
- 96d3369: Added support for root route
- 96d3369: Added `Router` and `TabRouter`

### Patch Changes

- 96d3369: Fixed `RouterState.get()` to be non-mutating, which addressed the SwiftUI Observation hang when switching tabs.
