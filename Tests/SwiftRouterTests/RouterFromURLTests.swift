import Foundation
import Testing
@testable import SwiftRouter

@Suite("Router From-URL Tests")
struct RouterFromURLTests {
        @Suite("Stack Router")
        struct StackRouter {
            struct TestState: Equatable {
                var matchedID = ""
                var search = ""
                var tags: [String] = []
            }

        enum TestUsersRoute: FromURLRoute {
            typealias State = TestState

            case home
            case user(String)
            case search(String, [String])

            static func from(route: RouteMatch<Self>) {
                route.screen("", .home)
                route.screen(":id") { url in
                    let id = url.param("id")

                    TestUsersRoute.user(id)
                }
                route.screen("search") { url in
                    let query = url.query("q")
                    let tags = url.query(all: "tag")
                    route.update { state in
                        state.search = query
                        state.tags = tags
                    }

                    TestUsersRoute.search(query, tags)
                }
            }

        }

        enum TestRoute: FromURLRoute {
            typealias State = TestState

            case users(TestUsersRoute)
            case filters(String, [String])
            case settings(String)
            case shortcut

            static func from(route: RouteMatch<Self>) {
                route.screen(
                    "users", join: TestUsersRoute.self, TestRoute.users)
                route.screen("filters") { url in
                    let query = url.query("q")
                    let tags = url.query(all: "tag")
                    route.update { state in
                        state.search = query
                        state.tags = tags
                    }

                    TestRoute.filters(query, tags)
                }
                route.screen("shortcut") { _ in
                    route.update { state in
                        state.matchedID = "42"
                        state.search = "swift"
                        state.tags = ["ios"]
                    }
                    TestRoute.users(.user("42"))
                    TestRoute.filters("swift", ["ios"])
                }
                route.screen("settings") { _, rest in
                    TestRoute.settings(rest)
                }
            }

        }

        @Test("Decodes query items and preserves nested route matches")
        func decodesQueryItemsAndPreservesNestedRouteMatches() {
            let router = Router<TestRoute>(TestState())

            #expect(
                router.hydrate(path: "/filters?q=swift&tag=ios&tag=swiftui"))
            #expect(
                router.state
                    == TestState(
                        matchedID: "",
                        search: "swift",
                        tags: ["ios", "swiftui"]
                    ))
            #expect(
                router.navigationPath == [
                    .filters("swift", ["ios", "swiftui"])
                ])

            #expect(router.hydrate(path: "/users/search?q=swift&tag=ios"))
            #expect(router.route == TestRoute.users(.search("swift", ["ios"])))
        }

        @Test("Matches a joined route at its base path")
        func matchesAJoinedRouteAtItsBasePath() {
            let router = Router<TestRoute>(TestState())

            #expect(router.hydrate(path: "/users"))
            #expect(router.route == .users(.home))
            #expect(
                router.state
                    == TestState(
                        matchedID: "",
                        search: "",
                        tags: []
                    ))
        }

        @Test("Matches a route that consumes the remaining path")
        func matchesARouteThatConsumesTheRemainingPath() {
            let router = Router<TestRoute>(TestState())

            #expect(router.hydrate(path: "/settings/about/info"))
            #expect(router.route == .settings("/about/info"))
        }

        @Test(
            "Hydrates all matched routes when a screen returns two routes and the stack is empty"
        )
        func
            hydratesAllMatchedRoutesWhenAScreenReturnsTwoRoutesAndTheStackIsEmpty()
        {
            let router = Router<TestRoute>(TestState())

            #expect(router.hydrate(path: "/shortcut"))
            #expect(
                router.navigationPath == [
                    .users(.user("42")),
                    .filters("swift", ["ios"]),
                ])
            #expect(router.route == .filters("swift", ["ios"]))
            #expect(
                router.state
                    == TestState(
                        matchedID: "42",
                        search: "swift",
                        tags: ["ios"]
                    ))
        }

        @Test(
            "Pushes onto the stack when hydrate is not set to replace and a path already exists"
        )
        func
            pushesOntoTheStackWhenHydrateIsSetNotToReplaceAndAPathAlreadyExists()
        {
            let router = Router<TestRoute>(TestState()) {
                TestRoute.users(.user("42"))
            }

            #expect(router.hydrate(path: "/filters?q=swift&tag=ios"))
            #expect(
                router.navigationPath == [
                    .users(.user("42")),
                    .filters("swift", ["ios"]),
                ])
            #expect(router.route == .filters("swift", ["ios"]))
            #expect(
                router.state
                    == TestState(
                        matchedID: "",
                        search: "swift",
                        tags: ["ios"]
                    ))
        }

        @Test(
            "Pushes only the last matched route when hydrate is set not to replace and a screen returns two routes"
        )
        func
            pushesOnlyTheLastMatchedRouteWhenHydrateIsSetNotToReplaceAndAScreenReturnsTwoRoutes()
        {
            let router = Router<TestRoute>(TestState()) {
                TestRoute.users(.home)
            }

            #expect(router.hydrate(path: "/shortcut"))
            #expect(
                router.navigationPath == [
                    .users(.home),
                    .filters("swift", ["ios"]),
                ])
            #expect(router.route == .filters("swift", ["ios"]))
            #expect(
                router.state
                    == TestState(
                        matchedID: "42",
                        search: "swift",
                        tags: ["ios"]
                    ))
        }

        @Test("Replaces the stack when hydrate is set to replace")
        func replacesTheStackWhenHydrateIsSetToReplace() {
            let router = Router<TestRoute>(TestState()) {
                TestRoute.users(.user("42"))
            }

            #expect(
                router.hydrate(path: "/filters?q=swift&tag=ios", replace: true))
            #expect(router.navigationPath == [.filters("swift", ["ios"])])
        }

        @Test(
            "Pushes only the last matched route when navigate matches a screen that returns two routes"
        )
        func
            pushesOnlyTheLastMatchedRouteWhenNavigateMatchesAScreenThatReturnsTwoRoutes()
        {
            let router = Router<TestRoute>(TestState())

            #expect(router.push(path: "/shortcut"))
            #expect(router.navigationPath == [.filters("swift", ["ios"])])
            #expect(router.route == .filters("swift", ["ios"]))
            #expect(
                router.state
                    == TestState(
                        matchedID: "42",
                        search: "swift",
                        tags: ["ios"]
                    ))
        }

        @Test("Leaves state and stack untouched when hydration fails")
        func leavesStateUntouchedWhenHydrationFails() {
            let router = Router<TestRoute>(TestState()) {
                TestRoute.users(.user("existing"))
            }
            router.state = TestState(
                matchedID: "existing",
                search: "swift",
                tags: ["ios"]
            )

            let originalState = router.state
            let originalPath = router.navigationPath

            #expect(!router.hydrate(path: "/users/42/edit"))
            #expect(router.state == originalState)
            #expect(router.navigationPath == originalPath)
        }

        @Test("Hydrates custom-scheme URLs using the host and ignores the host for universal links")
        func hydratesCustomSchemeURLsAndUniversalLinks() {
            let router = Router<TestRoute>(TestState())

            #expect(router.hydrate(url: URL(string: "myapp://users/42")!))
            #expect(router.route == .users(.user("42")))

            #expect(
                router.hydrate(
                    url: URL(string: "https://example.com/users/search?q=swift&tag=ios")!,
                    replace: true
                ))
            #expect(router.route == .users(.search("swift", ["ios"])))
        }
    }

    @Suite("Tab Router")
    struct TabRouterSuite {
        struct TestState: Equatable {
            var matchedID = ""
            var search = ""
            var tags: [String] = []
            var showSettingsSheet = false
        }

        enum TestTab: FromURLTabSelection {
            typealias State = TestState

            case home
            case users
            case settings

            struct Stack: TabStack {
                let users = TestUsersRoute.self
                let settings = TestSettingsRoute.self
            }

            static func from(route: TabRouteMatch<Self>) {
                route.tab("", .home)
                route.tab("users", TestUsersRoute.self)
                route.tab("settings", TestSettingsRoute.self) { url in
                    route.update { state in
                        state.showSettingsSheet = url.query("sheet") == "true"
                    }
                }
            }

        }

        enum TestUsersRoute: FromURLRoute, TabRoute {
            typealias State = TestState

            case user(String)
            case search(String, [String])

            static var tab: TestTab { .users }

            static func from(route: RouteMatch<Self>) {
                route.screen(":id") { url in
                    let id = url.param("id")
                    route.update { state in
                        state.matchedID = id
                    }

                    TestUsersRoute.user(id)
                }
                route.screen("search") { url in
                    let query = url.query("q")
                    let tags = url.query(all: "tag")
                    route.update { state in
                        state.search = query
                        state.tags = tags
                    }

                    TestUsersRoute.search(query, tags)
                }
            }

        }

        enum TestSettingsRoute: FromURLRoute, TabRoute {
            typealias State = TestState

            case about

            static var tab: TestTab { .settings }

            static func from(route: RouteMatch<Self>) {
                route.screen("about", .about)
            }

        }

        @Test(
            "Hydrates nested tab routes and preserves the nested router stack")
        func hydratesNestedTabRoutes() {
            let router = TabRouter(TestState(), initial: TestTab.home)

            #expect(
                router.hydrate(
                    path: "/users/search?q=swift&tag=ios&tag=swiftui"))
            #expect(router.tab == TestTab.users)
            #expect(
                router.state
                    == TestState(
                        matchedID: "",
                        search: "swift",
                        tags: ["ios", "swiftui"],
                        showSettingsSheet: false
                    ))

            #expect(
                router.users.navigationPath == [
                    .search("swift", ["ios", "swiftui"])
                ])
        }

        @Test(
            "Pushes onto the nested stack when hydrate is not set to replace and a tab path already exists"
        )
        func
            pushesOntoTheNestedStackWhenHydrateIsSetNotToReplaceAndATabPathAlreadyExists()
        {
            let router = TabRouter(TestState(), initial: TestTab.home)

            router.tab = .users
            router.users.push(.user("42"))
            #expect(router.hydrate(path: "/users/search?q=swift&tag=ios"))

            #expect(
                router.users.navigationPath == [
                    .user("42"),
                    .search("swift", ["ios"]),
                ])
            #expect(router.tab == TestTab.users)
            #expect(
                router.state
                    == TestState(
                        matchedID: "",
                        search: "swift",
                        tags: ["ios"],
                        showSettingsSheet: false
                    ))
        }

        @Test("Replaces the selected tab stack when hydrate is set to replace")
        func replacesTheSelectedTabStackWhenHydrateIsSetToReplace() {
            let router = TabRouter(TestState(), initial: TestTab.home)

            #expect(router.hydrate(path: "/users/42"))
            #expect(
                router.hydrate(
                    path: "/users/search?q=swift&tag=ios", replace: true))

            #expect(router.users.navigationPath == [.search("swift", ["ios"])])
        }

        @Test(
            "Reuses stored nested routers when hydrating and navigating within a tab"
        )
        func reusesStoredNestedRouters() {
            let router = TabRouter(TestState(), initial: TestTab.home)

            #expect(router.hydrate(path: "/users/42"))
            #expect(router.push(path: "/users/search?q=swift&tag=ios"))

            #expect(
                router.users.navigationPath == [
                    .user("42"), .search("swift", ["ios"]),
                ])
            #expect(
                router.state
                    == TestState(
                        matchedID: "42",
                        search: "swift",
                        tags: ["ios"],
                        showSettingsSheet: false
                    ))
        }

        @Test(
            "Leaves tab selection untouched when hydration fails to match a route"
        )
        func leavesTabSelectionUntouchedWhenHydrationFailsToMatchARoute() {
            let router = TabRouter(TestState(), initial: TestTab.home)

            #expect(!router.hydrate(path: "/missing"))
            #expect(router.tab == TestTab.home)

            #expect(!router.hydrate(path: "/users/missing/unknown"))
            #expect(router.tab == TestTab.home)
        }

        @Test(
            "Leaves tab selection, nested stack, and state untouched when tab navigation fails"
        )
        func leavesTabStateUntouchedWhenNavigationFails() {
            let router = TabRouter(TestState(), initial: TestTab.home)
            #expect(router.hydrate(path: "/users/42"))

            let originalTab = router.tab
            let originalState = router.state
            let originalPath = router.users.navigationPath

            #expect(!router.go(path: "/users/42/edit"))
            #expect(router.tab == originalTab)
            #expect(router.state == originalState)
            #expect(
                router.users.navigationPath == originalPath
            )
        }

        @Test("Hydrates custom-scheme tab URLs using the host and ignores the host for universal links")
        func hydratesCustomSchemeTabURLsAndUniversalLinks() {
            let router = TabRouter(TestState(), initial: TestTab.home)

            #expect(router.hydrate(url: URL(string: "myapp://users/42")!))
            #expect(router.tab == .users)
            #expect(router.users.route == .user("42"))

            #expect(
                router.hydrate(
                    url: URL(string: "https://example.com/users/search?q=swift&tag=ios")!,
                    replace: true
                ))
            #expect(router.tab == .users)
            #expect(router.users.route == .search("swift", ["ios"]))
        }
    }
}
