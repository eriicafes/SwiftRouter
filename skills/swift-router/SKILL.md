---
name: swift-router
description: Use when building or modifying navigation with SwiftRouter — covers Route, TabSelection, TabRoute, stack routers, tab routers, root route data, route state, and URL parsing for deep links, universal links, and custom schemes.
---

# SwiftRouter

## When to Use

Use this skill when the user wants to:

- create or modify navigation with `SwiftRouter`
- define `Route`, `TabSelection`, or `TabRoute` types
- add deep linking with `URLRoute` or `URLTabSelection`
- wire a `Router` or `TabRouter` into SwiftUI views
- model root route data or mutate router state from matched URLs

## Core Guidance

Prefer one stack router for the app, or one tab router with one stack router per tab. Do not model arbitrary nested stack routers.

Use enums for `Route` types and struct types for state unless a concrete need suggests otherwise.

For tabbed apps, use `TabSelection` for the selected tab and `TabRoute` for routes owned by a specific tab.

## Stack Routers

The default state for a router is `Void`, so if a route uses `Void` state you can initialize the router without passing state. If the route has its own state type, pass that state when creating the router. You can also initialize the router with default routes in its stack.

The router initializer uses a result builder, so you can return one route or multiple routes when building the initial stack.

```swift
let router = Router<AppRoute>()
let statefulRouter = Router<AppRouteWithState>(.init())
```

Prefer starting with an empty stack unless you intentionally need initial routes.

Use:

- `push(_:)` to append a route
- `go(to:)` to walk back to an existing route or append it
- `replace(_:)` to swap the current top route
- `back()` to pop one route
- `back(root: true)` to clear the stack

## Tab Routers

Like `Router`, the default state for a tab router is `Void`, so state can be omitted when the tab selection uses `Void`. If the tab selection has its own state type, pass that state when creating the router. A tab router is initialized with an initial tab, and its stack routers can then build their own stacks.

```swift
let tabRouter = TabRouter(initial: AppTab.home)
let statefulTabRouter = TabRouter(AppTab.State(), initial: AppTab.home)

tabRouter.users.push(.add)
```

Stack routers are accessed through dynamic member lookup, like `tabRouter.users`. Those router instances are cached, so repeated access to the same tab stack returns the same `Router`.

State is shared through those stack routers, so `tabRouter.state` and `tabRouter.users.state` read and write the same underlying state.

## Root Route

The root route does not have to be one of the route cases. If you want an explicit root route case, implement `data(route:)` and mark that case as `root: true`. SwiftRouter removes that route from the pushed stack, but its data stays available through `router.data`.

```swift
enum AppRoute: Route {
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

## Views

Use `Router` and `TabRouter` as observable state. In views, prefer local `@Bindable` access instead of building manual `Binding` values.

Create the router as state at the root of the feature or app, then add it as environment to the immediate view that should expose it to subviews.

For tabbed apps, let stack views access the tab router itself from environment. If needed, you can also pass the stack router as environment to the matching tab item.

Prefer defining app routes in `Routes.swift`, and putting screens in a `Screens/` directory.

```swift
// Routes.swift
import SwiftRouter

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
```

```swift
// ContentView.swift
struct ContentView: View {
    @State private var router = TabRouter(AppTab.State(), initial: AppTab.home)

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
                    case .user(let id):
                        UserDetailView(id: id)
                    }
                }
        }
    }
}
```

Router state can drive app state beyond navigation, like sheets.

```swift
// Screens/HomeView.swift
struct HomeView: View {
    @Environment(TabRouter<AppTab>.self) private var router

    var body: some View {
        @Bindable var router = router

        HomeContentView()
            .sheet(isPresented: $router.state.showSheet) {
                SettingsView()
            }
    }
}
```

## URL Parsing

Prefer putting URL conformance in an extension so the core type definition stays focused on the route shape.

Route cases can hold plain values like `String`, but they can also hold another route as an associated value when you want nested route composition.

### Stack Router

For stack routes, use `FromURLRoute` or `IntoURLRoute` when only one direction is needed, or `URLRoute` when both are needed.

`screen` callbacks use a result builder, so a match can return one route or multiple routes.
Returning multiple routes from a match only matters when `hydrate` is replacing the stack, or when hydrate runs on an empty stack.
Use `Self.case(...)` in the result builder callbacks.

```swift
enum AppRoute: Route {
    case settings
    case users(UsersRoute)
}

enum UsersRoute: Route {
    case add
    case user(id: String)
}
```

Use `FromURLRoute` to parse URLs into routes and state updates.
Use `route.update` inside `from` to mutate state from matched input, and read path/query values from `RouteURLInput`.

```swift
extension AppRoute: FromURLRoute {
    static func from(route: RouteMatch<Self>) {
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
    }
}
```

When there is no explicit root route and you need to mutate state, use `screen(root:)`.

```swift
enum AppRoute: FromURLRoute {
    struct State {
        var showSheet = false
    }

    case user(id: String)

    static func from(route: RouteMatch<Self>) {
        route.screen(root: { url in
            route.update { state in
                state.showSheet = url.query("sheet") == "true"
            }
        })
        route.screen(":id") { url in
            Self.user(id: url.param("id"))
        }
    }
}
```

Use `IntoURLRoute` to generate URLs from routes.
Read state from `route.state` inside `into` when URL generation depends on state, and write query values with `route.query(...)`.

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
        case .user(let id):
            return route.path(id)
        }
    }
}
```

### Tab Router

For tab routes, use `FromURLTabSelection` or `IntoURLTabSelection` when only one direction is needed, or `URLTabSelection` when both are needed. Delegate URL generation to the child stacks.

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

Use `FromURLTabSelection` to parse URLs into tab selection and nested stack routes.
Use `route.update` inside `from` to mutate state from matched input, and read path/query values from `RouteURLInput`.

```swift
extension AppTab: FromURLTabSelection {
    static func from(route: TabRouteMatch<Self>) {
        route.tab("", .home)
        route.tab("users", UsersRoute.self)
    }
}
```

```swift
extension UsersRoute: FromURLRoute {
    static func from(route: RouteMatch<Self>) {
        route.screen("add", .add)
        route.screen(":id") { url in
            Self.user(id: url.param("id"))
        }
    }
}
```

Use `IntoURLTabSelection` to generate URLs from the selected tab and active nested stack route.
Read state from `route.state` inside `into` when URL generation depends on state, and write query values with `route.query(...)`.

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
```

```swift
extension UsersRoute: IntoURLRoute {
    func into(route: RouteURL<Self>) -> String {
        switch self {
        case .add:
            return route.path("add")
        case .user(let id):
            return route.path(id)
        }
    }
}
```

Routers can also do string navigation with `push(path:)`, `go(path:)`, and `replace(path:)`.

Use `hydrate(url:)` or `hydrate(path:)` for deep links. Custom schemes treat the URL host as part of the route path; universal links use the URL path and query.
