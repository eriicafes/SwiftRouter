import Foundation
import Testing
@testable import SwiftRouter

@Suite("Router Into-URL Tests")
struct RouterIntoURLTests {
    @Suite("Stack Router")
    struct StackRouter {
        struct TestState: Equatable {
            var search = ""
            var tags: [String] = []
        }

        enum TestUsersRoute: IntoURLRoute {
            typealias State = TestState

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

        enum TestRoute: IntoURLRoute {
            typealias State = TestState

            case search(String, [String])
            case users(TestUsersRoute)

            func into(route: RouteURL<Self>) -> String {
                switch self {
                case .search(let query, let tags):
                    return route.path(
                        "/users/", join: TestUsersRoute.search(query, tags))
                case .users(let usersRoute):
                    return route.path("users", join: usersRoute)
                }
            }
        }

        @Test(
            "Normalizes path components and merges parent and child query items"
        )
        func normalizesPathsAndMergesQueries() {
            let router = Router<TestRoute>(
                TestState(search: "swift", tags: ["ios", "swiftui"])
            ) {
                TestRoute.search("swift", ["ios", "swiftui"])
            }

            #expect(
                RouteURL<TestRoute>(state: TestState()).path(
                    "/users/", "search/") == "/users/search")
            #expect(
                router.string() == "/users/search?q=swift&tag=ios&tag=swiftui")
        }

        @Test("Appends query values by default and replaces them when requested")
        func appendsQueryValuesByDefaultAndReplacesThemWhenRequested() {
            let route = RouteURL<TestRoute>(state: TestState())

            route.query("q", "swift")
            route.query("q", "beam")
            route.query("tag", ["ios", "swiftui"])
            route.query("tag", ["macos"])

            #expect(
                route.path("users", "search")
                    == "/users/search?q=swift&q=beam&tag=ios&tag=swiftui&tag=macos"
            )

            route.query("q", "beam", replace: true)
            route.query("tag", ["beam"], replace: true)

            #expect(route.path("users", "search") == "/users/search?q=beam&tag=beam")
        }

        @Test("Builds the expected URL from the current route")
        func buildsTheExpectedURLFromTheCurrentRoute() {
            let router = Router<TestRoute>(
                TestState(search: "swift", tags: ["ios", "swiftui"])
            ) {
                TestRoute.users(.search("swift", ["ios", "swiftui"]))
            }

            #expect(
                router.string() == "/users/search?q=swift&tag=ios&tag=swiftui")
        }

        @Test("Falls back to the root path when no current route exists")
        func fallsBackToTheRootPathWhenNoCurrentRouteExists() {
            let router = Router<TestRoute>(TestState())

            #expect(router.string() == "/")
        }
    }

    @Suite("Tab Router")
    struct TabRouterSuite {
        struct TestState: Equatable {
            var search = ""
            var tags: [String] = []
        }

        enum TestUsersRoute: IntoURLRoute, TabRoute {
            typealias State = TestState

            case home
            case search(String, [String])

            static var tab: TestTab { .users }

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

        enum TestTab: IntoURLTabSelection {
            typealias State = TestState

            case home
            case users

            struct Stack: TabStack {
                let users = TestUsersRoute.self
            }

            func into(route: TabRouteURL<Self>) -> String {
                switch self {
                case .home:
                    return route.path()
                case .users:
                    return route.path("users", join: TestUsersRoute.self)
                }
            }
        }

        @Test("Builds the expected URL from the selected tab and nested route")
        func buildsTheExpectedURLFromTheSelectedTabAndNestedRoute() {
            let router = TabRouter(
                TestState(search: "swift", tags: ["ios", "swiftui"]),
                initial: TestTab.users
            )
            router.users.push(.search("swift", ["ios", "swiftui"]))

            #expect(
                router.string() == "/users/search?q=swift&tag=ios&tag=swiftui")
        }

        @Test("Appends tab query values by default and replaces them when requested")
        func appendsTabQueryValuesByDefaultAndReplacesThemWhenRequested() {
            let router = TabRouter(TestState(), initial: TestTab.home)
            let route = TabRouteURL(router, state: TestState())

            route.query("q", "swift")
            route.query("q", "beam")
            route.query("tag", ["ios", "swiftui"])
            route.query("tag", ["macos"])

            #expect(
                route.path("users")
                    == "/users?q=swift&q=beam&tag=ios&tag=swiftui&tag=macos"
            )

            route.query("q", "beam", replace: true)
            route.query("tag", ["beam"], replace: true)

            #expect(route.path("users") == "/users?q=beam&tag=beam")
        }

        @Test(
            "Falls back to the tab root path when the selected tab has no nested route"
        )
        func fallsBackToTheTabRootPathWhenTheSelectedTabHasNoNestedRoute() {
            let router = TabRouter(TestState(), initial: TestTab.users)

            #expect(router.string() == "/users")
        }

        @Test("Builds the root path when the selected tab is the base path")
        func buildsTheRootPathWhenTheSelectedTabIsTheBasePath() {
            let router = TabRouter(TestState(), initial: TestTab.home)

            #expect(router.string() == "/")
        }
    }
}
