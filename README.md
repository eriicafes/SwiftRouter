# SwiftRouter

`SwiftRouter` is a lightweight Swift package for driving navigation with typed routes, shared app state, and optional URL-based deep linking.

## Features

- Typed stack navigation with `push`, `replace`, `go`, and `back`
- Shared route state that updates as paths are matched
- URL hydration for deep links, universal links, and custom schemes
- URL generation for routes and tab selections
- A clean navigation model

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
    .package(url: "https://github.com/eriicafes/SwiftRouter.git", branch: "main")
]
```

Then include it in your target:

```swift
.target(
    name: "YourApp",
    dependencies: ["SwiftRouter"]
)
```

## Core Concepts

### Route

A `Route` is the typed value that represents a screen in a navigation stack.

```swift
import SwiftRouter

enum SimpleRoute: Route {
    case home
    case user(String)
}
```

Routes can also expose:

- `State`: shared mutable state owned by the router
- `Data`: data derived from the root route

### Router Shape

SwiftRouter is built around two shapes:

- One `Router<Route>` for apps that use a single navigation stack
- One `TabRouter<Tab>` for apps that use tabs, with one `Router<Route>` inside each tab stack

It is recommended to have a single stack router, or a tab router that can have stack routers in its tabs.

### Root Route Data

The root route of a navigation stack does not have to be one of your route cases. If you want to represent that root as a route case, implement `data(route:)` on the route and mark that case as the root so its data can be exposed through `router.data`.

```swift
enum AppRoute: Route {
    struct State {
        var selectedUserID = ""
    }

    case home(String)
    case settings

    static func data(route: AppRoute?) -> RouteData<String> {
        switch route {
        case .home(let title):
            return .data(root: true, title)
        default:
            return .data(root: false, "")
        }
    }
}
```

If the first route in the initial stack returns `.data(root: true, value)`, SwiftRouter removes that route from `navigationPath` and stores it separately as the root route.

```swift
let router = Router<AppRoute>(.init()) {
    AppRoute.home("Home")
}

router.navigationPath.isEmpty
router.data == "Home"
```

That means the stack can be empty while the root route's data is still available through `router.data`.

If you do not have an explicit root route, you can still react to the root path by using `screen(root:)` in `FromURLRoute` and updating state when `/` matches:

```swift
enum AppRoute: FromURLRoute {
    struct State {
        var showSheet = false
    }

    case user(String)

    static func from(route: RouteMatch<Self>) {
        route.screen(root: { url in
            route.update { state in
                state.showSheet = url.query("sheet") == "true"
            }
        })

        route.screen(":id") { url in
            Self.user(url.param("id"))
        }
    }
}
```

## Stack Router

You can initialize a stack router in a few different ways.

```swift
// No state
enum RouteWithoutState: Route {
    case home
}

let router = Router<RouteWithoutState>()

// State, no stack
enum RouteWithState: Route {
    struct State {
        var showSheet = false
    }

    case home
    case settings
}

let stateRouter = Router<RouteWithState>(.init())

// State and stack
let stateAndStackRouter = Router<RouteWithState>(.init()) {
    RouteWithState.settings
}
```

Available properties:

- `router.navigationPath`: pushed routes
- `router.route`: current route
- `router.state`: shared state
- `router.data`: root route data

## Tab Router

Use `TabRouter` when navigation is split across tabs.

```swift
enum AppTab: TabSelection {
    case home
    case users

    struct Stack: TabStack {
        let users = UsersRoute.self
    }
}

enum UsersRoute: TabRoute {
    typealias Tab = AppTab

    case home
    case user(String)

    static var tab: AppTab { .users }
}

let router = TabRouter(initial: AppTab.home)
router.tab = .users
router.users.push(.user("42"))
```

`TabRouter` caches nested routers, so repeated access to the same tab stack returns the same `Router` instance.

You can pass the tab router through the environment and read it from tab content:

```swift
@main
struct ExampleApp: App {
    @State private var router = TabRouter(initial: AppTab.home)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
        }
    }
}

struct RootView: View {
    @Environment(TabRouter<AppTab>.self) private var router

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.tab) {
            Tab("Home", value: AppTab.home) {
                HomeView()
            }

            Tab("Users", value: AppTab.users) {
                UsersView()
            }
        }
    }
}

struct UsersView: View {
    @Environment(TabRouter<AppTab>.self) private var router

    var body: some View {
        Button("Open User") {
            router.users.push(.user("42"))
        }
    }
}
```

## Navigation

### Push

`push(_:)` appends a route to the top of the stack:

```swift
let router = Router<AppRoute>(.init())

router.push(.user("42"))
router.push(.user("100"))

router.navigationPath
// [.user("42"), .user("100")]
```

### Replace

`replace(_:)` removes the current top route and puts a new route in its place:

```swift
let router = Router<AppRoute>(.init()) {
    AppRoute.user("42")
}

router.replace(.user("100"))
router.navigationPath
// [.user("100")]
```

### Go

`go(to:)` looks for the route in the current stack. If it finds it, everything after that route is removed. If it does not find it, the route is pushed:

```swift
let router = Router<AppRoute>(.init()) {
    AppRoute.user("42")
    AppRoute.user("100")
}

router.go(to: .user("42"))
router.navigationPath
// [.user("42")]

router.go(to: .user("7"))
router.navigationPath
// [.user("42"), .user("7")]
```

### Back

`back()` removes the current top route if the stack is not empty:

```swift
let router = Router<AppRoute>(.init()) {
    AppRoute.user("42")
    AppRoute.user("100")
}

router.back()
router.navigationPath
// [.user("42")]
```

`back(root: true)` clears the pushed stack and returns to the root route:

```swift
let router = Router<AppRoute>(.init()) {
    AppRoute.home("Home")
    AppRoute.user("42")
    AppRoute.user("100")
}

router.back(root: true)
router.navigationPath
// []

router.data
// "Home"
```

### Path-Based Navigation

Path-based navigation parses a path into a route first. If parsing succeeds, state is updated and then the matching navigation method is applied.

`push(path:)` appends the matched route:

```swift
let router = Router<UsersRoute>(.init())

router.push(path: "/42")
router.navigationPath
// [.user("42")]
```

`go(path:)` walks back to a matched route if it already exists, or pushes it if it does not:

```swift
let router = Router<UsersRoute>(.init())
router.push(.user("42"))
router.push(.search("swift", ["ios"]))

router.go(path: "/42")
router.navigationPath
// [.user("42")]
```

`replace(path:)` swaps the current top route with the matched route:

```swift
let router = Router<UsersRoute>(.init())
router.push(.user("42"))

router.replace(path: "/search?q=swift&tag=ios")
router.navigationPath
// [.search("swift", ["ios"])]
```

On `TabRouter`, these same methods can also switch tabs when the path matches a different tab:

```swift
let router = TabRouter(initial: AppTab.home)

router.push(path: "/users/42")
router.tab
// .users

router.users.route
// .user("42")
```

`go(path:)` and `replace(path:)` behave the same way for tabs: they select the matched tab, then forward the remaining path into that tab's stack router.

### Hydrate

Hydrate sets the router from a parsed path. When `replace` is `true`, it replaces the current stack. When `replace` is `false` and the router already has a current route, it behaves like pushing the matched destination.

```swift
let router = Router<UsersRoute>(.init())

router.hydrate(path: "/42")
router.navigationPath
// [.user("42")]

router.hydrate(path: "/search?q=swift", replace: true)
router.navigationPath
// [.search("swift", [])]
```

In SwiftUI you would usually call it from `onOpenURL`:

```swift
@State private var router = Router<UsersRoute>(.init())

var body: some View {
    UsersView(router: router)
        .onOpenURL { url in
            router.hydrate(url: url)
        }
}
```

If a path does not match, the state and stack stay unchanged.

## URL Parsing

SwiftRouter can parse URLs into navigation state, and turn navigation state back into URLs.

### Parse From URL

Conform a route to `FromURLRoute` to decode paths into routes and state updates.

```swift
enum UsersRoute: FromURLRoute {
    struct State {
        var selectedUserID = ""
        var search = ""
        var tags: [String] = []
    }

    case home
    case user(String)
    case search(String, [String])

    static func from(route: RouteMatch<Self>) {
        route.screen("", .home)

        route.screen(":id") { url in
            let id = url.param("id")
            route.update { state in
                state.selectedUserID = id
            }
            Self.user(id)
        }

        route.screen("search") { url in
            let query = url.query("q")
            let tags = url.query(all: "tag")
            route.update { state in
                state.search = query
                state.tags = tags
            }
            Self.search(query, tags)
        }
    }
}
```

`RouteURLInput` available methods:

- `url.param("id")`: reads a matched path parameter.
- `url.query("q")`: reads the first value for a query item.
- `url.query(all: "tag")`: reads all values for a repeated query item.

Parse into a router from a path or URL:

```swift
let router = Router<UsersRoute>(.init())

router.hydrate(path: "/search?q=swift&tag=ios&tag=swiftui")
router.hydrate(url: URL(string: "myapp://search?q=swift")!)
router.hydrate(
    url: URL(string: "https://example.com/search?q=swift")!,
    replace: true
)
```

When hydrate is replacing the stack, one match can also produce more than one route:

```swift
enum AppRoute: FromURLRoute {
    struct State {
        var selectedUserID = ""
        var showFilters = false
    }

    case user(String)
    case filters

    static func from(route: RouteMatch<Self>) {
        route.screen("shortcut") { _ in
            route.update { state in
                state.selectedUserID = "42"
                state.showFilters = true
            }
            Self.user("42")
            Self.filters
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

You can also nest a child `FromURLRoute` inside a parent route:

```swift
enum AppRoute: FromURLRoute {
    typealias State = UsersRoute.State

    case users(UsersRoute)

    static func from(route: RouteMatch<Self>) {
        route.screen("users", join: UsersRoute.self, AppRoute.users)
    }
}
```

#### Tabs

Tab parsing works through the tab selection type:

```swift
enum AppTab: URLTabSelection {
    case home
    case users

    struct Stack: TabStack {
        let users = UsersRoute.self
    }

    static func from(route: TabRouteMatch<Self>) {
        route.tab("", .home)
        route.tab("users", UsersRoute.self)
    }

    func into(route: TabRouteURL<Self>) -> String {
        switch self {
        case .home:
            return route.path()
        case .users:
            return route.path("users", join: UsersRoute.self)
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
enum UsersRoute: IntoURLRoute {
    struct State {
        var search = ""
        var tags: [String] = []
    }

    case home
    case search(String, [String])

    func into(route: RouteURL<Self>) -> String {
        switch self {
        case .home:
            return route.path("home")
        case .search(let query, let tags):
            route.query("q", query)
            route.query("tag", tags)
            return route.path("search")
        }
    }
}
```

Nested routes can compose URLs with `join`:

```swift
enum AppRoute: IntoURLRoute {
    typealias State = UsersRoute.State

    case users(UsersRoute)

    func into(route: RouteURL<Self>) -> String {
        switch self {
        case .users(let usersRoute):
            return route.path("users", join: usersRoute)
        }
    }
}
```

Then:

```swift
let router = Router<AppRoute>(.init(search: "swift", tags: ["ios"]))
router.push(.users(.search("swift", ["ios"])))

let path = router.string()
// "/users/search?q=swift&tag=ios"
```

`RouteURL` available methods:

- `path(_:)` for normalized path construction
- `query(_:_:replace:)` for single query values
- `query(_:_:replace:)` for repeated query values

#### Tabs

Tab URLs are generated from the selected tab, which can delegate URL building to the active route inside that tab's stack:

```swift
enum AppTab: URLTabSelection {
    case home
    case users

    struct Stack: TabStack {
        let users = UsersRoute.self
    }

    static func from(route: TabRouteMatch<Self>) {
        route.tab("", .home)
        route.tab("users", UsersRoute.self)
    }

    func into(route: TabRouteURL<Self>) -> String {
        switch self {
        case .home:
            return route.path()
        case .users:
            return route.path("users", join: UsersRoute.self)
        }
    }
}
```

Then:

```swift
let router = TabRouter(initial: AppTab.users)
router.users.push(.user("42"))

let path = router.string()
// "/users/42"
```

### Conforming Your Routes

You can conform your routes in one direction or both:

- Use `FromURLRoute` if your route only needs to parse URLs into routes and state.
- Use `IntoURLRoute` if your route only needs to turn routes into URLs.
- Use `URLRoute` if your route needs to do both.

```swift
enum UsersRoute: URLRoute {
    struct State {
        var selectedUserID = ""
        var search = ""
        var tags: [String] = []
    }

    case home
    case user(String)
    case search(String, [String])

    static func from(route: RouteMatch<Self>) {
        route.screen("", .home)

        route.screen(":id") { url in
            let id = url.param("id")
            route.update { state in
                state.selectedUserID = id
            }
            Self.user(id)
        }

        route.screen("search") { url in
            let query = url.query("q")
            let tags = url.query(all: "tag")
            route.update { state in
                state.search = query
                state.tags = tags
            }
            Self.search(query, tags)
        }
    }

    func into(route: RouteURL<Self>) -> String {
        switch self {
        case .home:
            return route.path()
        case .user(let id):
            return route.path(id)
        case .search(let query, let tags):
            route.query("q", query)
            route.query("tag", tags)
            return route.path("search")
        }
    }
}
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

@State private var router = Router<AppRoute>(.init())

var body: some View {
    @Bindable var router = router

    HomeView()
        .sheet(isPresented: $router.state.showSheet) {
            SettingsView()
        }
}
```

## Testing

Run the package tests with:

```bash
swift test
```
