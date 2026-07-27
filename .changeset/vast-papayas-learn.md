---
"swift-router": patch
---

Fixed `RouterState.get()` to be non-mutating, which addressed the SwiftUI Observation hang when switching tabs.
