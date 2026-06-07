# SwiftRouter

`SwiftRouter` is a lightweight Swift package for driving SwiftUI navigation with typed routes, shared app state, and deep linking.

## Features

- Typed navigation
- Shared router state
- Deep linking for custom schemes and universal links
- URL generation from routes

## Requirements

- Swift 6.0+
- iOS 17+
- macOS 14+
- tvOS 17+
- watchOS 10+

## Installation

Add `SwiftRouter` to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/eriicafes/SwiftRouter.git", from: "0.1.1")
]
```

Then include it in your target:

```swift
.target(
    name: "YourApp",
    dependencies: ["SwiftRouter"]
)
```

## AI Skills

Install the SwiftRouter agent skills with:

```sh
npx skills add eriicafes/SwiftRouter
```

## Core Concepts

### Route

A `Route` is the typed value that represents a screen in a navigation stack.

```swift
import SwiftRouter

enum AppRoute: Route {
    case settings
    case users(id: String)
}
```

### Tab Selection

A `TabSelection` is the type that represents the selected tab in a `TabRouter`.

```swift
enum AppTab: TabSelection {
    case home
    case users
}
```

### Tab Route

A `TabRoute` is a route that belongs to a specific tab.

```swift
enum UsersRoute: TabRoute {
    case add
    case user(id: String)

    static var tab: AppTab { .users }
}
```

> It is recommended to have a single [Stack Router](#stack-router), or a [Tab Router](#tab-router) that can have stack routers in its tabs.

### Root Route Data

The base view should not be one of your route cases, since it is the view rendered when the stack is empty.

However, if you do represent the root as a route case, implement `data(route:)` on the route and mark that case as the root so its data can be exposed through `router.data`. See [Root Route in Views](#root-route-in-views) for how to structure the view around that pattern. Root data is mainly useful when parsing from a URL with [FromURLRoute](#parse-from-url) and that root route carries dynamic data for the base view.

```swift
enum AppRoute: Route {
    case home(title: String)
    case settings
    case users(id: String)

    static func data(route: AppRoute?) -> RouteData<String> {
        guard case let .home(title) = route else {
            // Fallback when there is no explicit root route in the stack.
            return .data(root: false, "Home")
        }
        return .data(root: true, title)
    }
}
```

If the first route in the initial stack returns `.data(root: true, value)`, SwiftRouter removes that route from `navigationPath` and stores it separately as the root route.

```swift
let router = Router<AppRoute>(.init()) {
    AppRoute.home(title: "Dashboard")
}

router.navigationPath
// []
router.data
// "Dashboard"
```

## Stack Router

The default state for a route is `Void`. If the route `State` is `Void`, it can be omitted when creating the router. If the route has its own state type, pass that state when creating the router.

```swift
// No state
enum AppRoute: Route {
    case settings
    case users(id: String)
}

let router = Router<AppRoute>()

// State
enum StatefulAppRoute: Route {
    struct State {
        var showSheet = false
    }

    case settings
    case users(id: String)
}

let stateRouter = Router<StatefulAppRoute>(.init())
```

Available properties:

- `router.navigationPath`: pushed routes
- `router.route`: current route
- `router.state`: shared state
- `router.data`: root route data

## Tab Router

A tab router is initialized with an initial tab.

Like `Router`, the default state for a tab selection is `Void`. If the tab selection `State` is `Void`, it can be omitted when creating the tab router. If the tab selection has its own state type, pass that state when creating the router.

If a tab has stacks, define a `Stack` type conforming to `TabStack` and add a property for each route type.

```swift
enum AppTab: TabSelection {
    struct State {
        var showSheet = false
    }

    case home
    case users

    struct Stack: TabStack {
        let users = UsersRoute.self
    }
}

enum UsersRoute: TabRoute {
    typealias State = AppTab.State

    case add
    case user(id: String)

    static var tab: AppTab { .users }
}

let router = TabRouter(.init(), initial: AppTab.home)
router.tab = .users
router.users.push(.add)
```

`TabRouter` creates a nested stack the first time it is accessed.

## Navigation

You can mutate `navigationPath` directly, but SwiftRouter provides useful methods to mutate it.

### Push

`push(_:)` appends a route to the top of the stack:

```swift
let router = Router<AppRoute>(.init())

router.push(.users(id: "42"))
router.push(.users(id: "100"))

router.navigationPath
// [.users(id: "42"), .users(id: "100")]
```

### Replace

`replace(_:)` swaps the current route with a new route:

```swift
let router = Router<AppRoute>(.init()) {
    AppRoute.users(id: "42")
}

router.replace(.users(id: "100"))
router.navigationPath
// [.users(id: "100")]
```

### Go

`go(to:)` looks for the route in the current stack. If it finds it, everything after that route is removed. If it does not find it, the route is pushed:

```swift
let router = Router<AppRoute>(.init()) {
    AppRoute.users(id: "42")
    AppRoute.users(id: "100")
}

router.go(to: .users(id: "42"))
router.navigationPath
// [.users(id: "42")]

router.go(to: .users(id: "7"))
router.navigationPath
// [.users(id: "42"), .users(id: "7")]
```

### Back

`back()` removes the current route if the stack is not empty:

```swift
let router = Router<AppRoute>(.init()) {
    AppRoute.users(id: "42")
    AppRoute.users(id: "100")
}

router.back()
router.navigationPath
// [.users(id: "42")]
```

`back(root: true)` clears the pushed stack and returns to the root route:

```swift
let router = Router<AppRoute>(.init()) {
    AppRoute.users(id: "42")
    AppRoute.users(id: "100")
}

router.back(root: true)
router.navigationPath
// []
```

### Path-Based Navigation

Path-based navigation parses a path into a route first. If parsing succeeds, state is updated and then the matching navigation method is applied.

`push(path:)` appends the matched route:

```swift
let router = Router<UsersRoute>(.init())

router.push(path: "/42")
router.navigationPath
// [.user(id: "42")]
```

`go(path:)` walks back to a matched route if it already exists, or pushes it if it does not:

```swift
let router = Router<UsersRoute>(.init())
router.push(.user(id: "42"))
router.push(.search("swift"))

router.go(path: "/42")
router.navigationPath
// [.user(id: "42")]
```

`replace(path:)` swaps the current route with the matched route:

```swift
let router = Router<UsersRoute>(.init())
router.push(.user(id: "42"))

router.replace(path: "/search?q=swift")
router.navigationPath
// [.search("swift")]
```

On `TabRouter`, these same methods can also switch tabs when the path matches a different tab. The relative path is then used to call the matching stack router method:

```swift
let router = TabRouter(initial: AppTab.home)

router.push(path: "/users/42")
router.tab
// .users

router.users.route
// .user(id: "42")
```

### Hydrate

Hydrate sets the router from a parsed path. When `replace` is `true`, it replaces the current stack. When `replace` is `false` and the router already has a current route, it pushes the matched destination.

```swift
let router = Router<UsersRoute>(.init())

router.hydrate(path: "/42")
router.navigationPath
// [.user(id: "42")]

router.hydrate(path: "/search?q=swift", replace: true)
router.navigationPath
// [.search("swift")]
```

In SwiftUI you would usually call it from `onOpenURL`:

```swift
@State private var router = Router<UsersRoute>(.init())

var body: some View {
    UsersView()
        .environment(router)
        .onOpenURL { url in
            router.hydrate(url: url)
        }
}
```

If a path does not match, the state and stack stay unchanged.

## Views

Once a router is configured, you usually pass it through the environment and bind `NavigationStack` to its `navigationPath`. With tab navigation, each tab can read its matching stack router from the environment:

```swift
// Routes.swift
import SwiftRouter

enum AppTab: TabSelection {
    case home
    case users

    struct Stack: TabStack {
        let users = UsersRoute.self
    }
}

enum UsersRoute: TabRoute {
    case add
    case user(id: String)

    static var tab: AppTab { .users }
}
```

```swift
// ContentView.swift
struct ContentView: View {
    @State private var router = TabRouter(initial: AppTab.home)

    var body: some View {
        TabView(selection: $router.tab) {
            Tab("Home", value: AppTab.home) {
                HomeView()
            }

            Tab("Users", value: AppTab.users) {
                UsersView()
                    .environment(router.users)
            }
        }
        .environment(router)
    }
}
```

```swift
// Screens/UsersView.swift
struct UsersView: View {
    @Environment(Router<UsersRoute>.self) private var router

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.navigationPath) {
            UsersListView()
                .navigationDestination(for: UsersRoute.self) { route in
                    switch route {
                    case .add:
                        AddUserView()
                    case .user(id: let id):
                        UserDetailView(id: id)
                    }
                }
        }
    }
}
```

### Root Route in Views

When the root route is represented as a route case, SwiftRouter exposes its data through `router.data` so the base view can read from it directly while pushed routes are still handled through `navigationDestination`:

```swift
// Routes.swift
import SwiftRouter

enum AppRoute: Route {
    case home(title: String)
    case settings
    case users(id: String)

    static func data(route: AppRoute?) -> RouteData<String> {
        guard case let .home(title) = route else {
            return .data(root: false, "Home")
        }
        return .data(root: true, title)
    }
}

extension AppRoute: FromURLRoute {
    static func from(route: RouteMatch<Self>) {
        route.screen(root: { url in
            let title = url.query("title", fallback: "Home")
            Self.home(title: title)
        })

        // Other route parsing goes here.
    }
}
```

```swift
// ContentView.swift
struct ContentView: View {
    @State private var router = Router<AppRoute>()

    var body: some View {
        NavigationStack(path: $router.navigationPath) {
            HomeView(title: router.data)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .home(let title):
                        HomeView(title: title)
                    case .settings:
                        SettingsView()
                    case .users(id: let id):
                        UserDetailView(id: id)
                    }
                }
        }
    }
}
```

## URL Parsing

SwiftRouter can parse URLs into navigation state, and turn navigation state back into URLs.

You can conform your routes in one direction or both:

- Use `FromURLRoute` or `FromURLTabSelection` if your route only needs to parse URLs into routes and state.
- Use `IntoURLRoute` or `IntoURLTabSelection` if your route only needs to turn routes into URLs.
- Use `URLRoute` or `URLTabSelection` if your route needs to do both.

Prefer putting URL conformances in extensions so the route definition stays focused on the route shape.

### Parse From URL

Conform a route to `FromURLRoute` to decode paths into routes and state updates.

```swift
enum AppRoute: Route {
    case settings
    case users(UsersRoute)
}

enum UsersRoute: Route {
    case add
    case user(id: String)
    case search(String)
}
```

```swift
extension AppRoute: FromURLRoute {
    static func from(route: RouteMatch<Self>) {
        route.screen(root: { _ in
            print("Matched root path")
        })
        route.screen("settings", .settings)
        route.screen("users", join: UsersRoute.self, Self.users)
    }
}

extension UsersRoute: FromURLRoute {
    static func from(route: RouteMatch<Self>) {
        route.screen("add", .add)
        route.screen(":id") { url in
            Self.user(id: url.param("id"))
        }
        route.screen("search") { url in
            let query = url.query("q")
            Self.search(query)
        }
    }
}
```

`RouteURLInput` available methods:

- `param(_:fallback:)` reads a matched path parameter.
- `query(_:fallback:)` reads the first value for a query item.
- `query(all:)` reads all values for a query item.

Parse into a router from a path or URL:

```swift
let router = Router<AppRoute>()

router.hydrate(path: "/users/search?q=swift")
router.hydrate(url: URL(string: "myapp://users/search?q=swift")!)
router.hydrate(
    url: URL(string: "https://example.com/users/search?q=swift")!,
    replace: true
)
```

When hydrate is replacing the stack, one match can also produce more than one route:

```swift
extension UsersRoute: FromURLRoute {
    static func from(route: RouteMatch<Self>) {
        route.screen("add", .add)
        route.screen(":id") { url in
            let id = url.param("id")
            Self.search(id)  // Added search route.
            Self.user(id: id)
        }
        route.screen("search") { url in
            let query = url.query("q")
            Self.search(query)
        }
    }
}
```

Returning an empty stack from a match is treated as a failed navigation or hydration:

```swift
enum AppRoute: FromURLRoute {
    static func from(route: RouteMatch<Self>) {
        route.screen("draft") { _ in
            []
        }
    }
}
```

#### Tabs

Tab parsing works through the tab selection type:

```swift
enum AppTab: TabSelection {
    case home
    case users

    struct Stack: TabStack {
        let users = UsersRoute.self
    }
}

enum UsersRoute: TabRoute {
    case add
    case user(id: String)

    static var tab: AppTab { .users }
}
```

```swift
extension AppTab: FromURLTabSelection {
    static func from(route: TabRouteMatch<Self>) {
        route.tab("", .home)
        route.tab("users", UsersRoute.self)
    }
}

extension UsersRoute: FromURLRoute {
    static func from(route: RouteMatch<Self>) {
        route.screen("add", .add)
        route.screen(":id") { url in
            Self.user(id: url.param("id"))
        }
    }
}
```

Then a tab router can parse a path and switch to the matched tab:

```swift
let router = TabRouter(initial: AppTab.home)

router.hydrate(path: "/users/42")
router.tab
// .users
```

### Parse Into URL

Conform a route to `IntoURLRoute` to map it back into a path.

```swift
enum AppRoute: Route {
    case settings
    case users(UsersRoute)
}

enum UsersRoute: Route {
    case add
    case user(id: String)
    case search(String)
}
```

```swift
extension AppRoute: IntoURLRoute {
    func into(route: RouteURL<Self>) -> String {
        switch self {
        case .settings:
            return route.path("settings")
        case .users(let usersRoute):
            return route.path("users", join: usersRoute)
        }
    }
}

extension UsersRoute: IntoURLRoute {
    func into(route: RouteURL<Self>) -> String {
        switch self {
        case .add:
            return route.path("add")
        case .user(id: let id):
            return route.path(id)
        case .search(let query):
            route.query("q", query)
            return route.path("search")
        }
    }
}
```

Then:

```swift
let router = Router<AppRoute>()
router.push(.users(.search("swift")))

let path = router.string()
// "/users/search?q=swift"
```

`RouteURL` available methods:

- `path(_:)` for normalized path construction
- `query(_:_:replace:)` sets query values

#### Tabs

Tab URLs are generated from the selected tab, which can delegate URL building to the active route inside that tab's stack:

```swift
enum AppTab: TabSelection {
    case home
    case users

    struct Stack: TabStack {
        let users = UsersRoute.self
    }
}

enum UsersRoute: TabRoute {
    case add
    case user(id: String)

    static var tab: AppTab { .users }
}
```

```swift
extension AppTab: IntoURLTabSelection {
    func into(route: TabRouteURL<Self>) -> String {
        switch self {
        case .home:
            return route.path()
        case .users:
            return route.path("users", join: UsersRoute.self)
        }
    }
}

extension UsersRoute: IntoURLRoute {
    func into(route: RouteURL<Self>) -> String {
        switch self {
        case .add:
            return route.path("add")
        case .user(id: let id):
            return route.path(id)
        }
    }
}
```

Then:

```swift
let router = TabRouter(initial: AppTab.users)
router.users.push(.user(id: "42"))

let path = router.string()
// "/users/42"
```

## Observation

Both `Router` and `TabRouter` are marked with `@Observable`, so they integrate naturally with Swift Observation-based UI updates.

Router state can also drive app state beyond navigation, like sheets or other presentation flags.

```swift
enum AppRoute: FromURLRoute {
    struct State {
        var showSheet = false
    }

    static func from(route: RouteMatch<Self>) {
        route.screen(root: { url in
            route.update { state in
                state.showSheet = url.query("sheet") == "true"
            }
        })
    }
}

struct HomeView: View {
    @Environment(Router<AppRoute>.self) private var router

    var body: some View {
        @Bindable var router = router

        HomeContentView()
            .sheet(isPresented: $router.state.showSheet) {
                SettingsView()
            }
    }
}
```

## Testing

Run the package tests with:

```bash
swift test
```
