import Foundation
import Observation
import Testing
@testable import SwiftRouter

@Suite("Router State Tests")
struct RouterStateTests {
    @Suite("Observation Regression")
    struct ObservationRegression {
        struct TestState: Equatable {
            var count = 0
        }

        enum TestTab: TabSelection {
            typealias State = TestState

            case users

            struct Stack: TabStack {
                let users = TestRoute.self
            }
        }

        enum TestRoute: TabRoute {
            typealias State = TestState
            typealias Tab = TestTab

            case profile

            static var tab: TestTab { .users }
        }

        final class ChangeCounter: @unchecked Sendable {
            var value = 0
        }

        @Test("Reading shared router state does not invalidate observation")
        func readingSharedRouterStateDoesNotInvalidateObservation() {
            let tabRouter = TabRouter(initial: TestTab.users, state: TestState())
            let router = tabRouter.users
            let changes = ChangeCounter()

            withObservationTracking {
                _ = router.state
            } onChange: {
                changes.value += 1
            }

            #expect(changes.value == 0)

            router.state = TestState(count: 1)

            #expect(changes.value == 1)
        }
    }

    @Suite("Value-Type State")
    struct ValueTypeState {
        @Suite("Stack Router")
        struct StackRouter {
            struct TestState: Equatable {
                var matchedID = ""
                var search = ""
                var tags: [String] = []
                var showSettingsSheet = false
            }

            enum TestRoute: FromURLRoute {
                typealias State = TestState

                case user(String)
                case search(String, [String])
                case currentUser

                static func from(route: RouteMatch<Self>) {
                    route.update { state in
                        state.matchedID = "current"
                    }

                    route.screen("users/:id") { url in
                        let id = url.param("id")
                        route.update { state in
                            state.matchedID = id
                        }
                        TestRoute.user(id)
                    }

                    route.screen("users/current", .currentUser)

                    route.screen("users/empty") { _ in
                        route.update { state in
                            state.matchedID = "empty"
                        }
                        []
                    }

                    route.screen("search") { url in
                        let query = url.query("q")
                        let tags = url.query(all: "tag")
                        route.update { state in
                            state.search = query
                            state.tags = tags
                        }
                        TestRoute.search(query, tags)
                    }
                }

            }

            @Test("Applies state updates when hydrate succeeds")
            func appliesStateUpdatesWhenHydrateSucceeds() {
                let router = Router<TestRoute>(state: TestState())

                #expect(
                    router.hydrate(path: "/search?q=swift&tag=ios&tag=swiftui"))
                #expect(
                    router.state
                        == TestState(
                            matchedID: "current",
                            search: "swift",
                            tags: ["ios", "swiftui"],
                            showSettingsSheet: false
                        ))
                #expect(
                    router.navigationPath == [
                        .search("swift", ["ios", "swiftui"])
                    ])
            }

            @Test("Does not commit updates when hydrate finds no route")
            func doesNotCommitUpdatesWhenHydrateFindsNoRoute() {
                let router = Router<TestRoute>(
                    state: TestState(
                        matchedID: "seed",
                        search: "existing",
                        tags: ["one"],
                        showSettingsSheet: false
                    )
                )

                let originalState = router.state

                #expect(!router.hydrate(path: "/missing"))
                #expect(router.state == originalState)
                #expect(router.navigationPath.isEmpty)
            }

            @Test(
                "Does not commit updates when hydrate matches a screen that returns an empty stack"
            )
            func
                doesNotCommitUpdatesWhenHydrateMatchesAScreenThatReturnsAnEmptyStack()
            {
                let router = Router<TestRoute>(
                    state: TestState(
                        matchedID: "seed",
                        search: "existing",
                        tags: ["one"],
                        showSettingsSheet: false
                    )
                ) {
                    TestRoute.user("seed")
                }

                let originalState = router.state
                let originalPath = router.navigationPath

                #expect(!router.hydrate(path: "/users/empty"))
                #expect(router.state == originalState)
                #expect(router.navigationPath == originalPath)
            }

            @Test("Does not commit state updates when navigate finds no route")
            func doesNotCommitStateUpdatesWhenNavigateFindsNoRoute() {
                let router = Router<TestRoute>(
                    state: TestState(
                        matchedID: "seed",
                        search: "existing",
                        tags: ["one"],
                        showSettingsSheet: false
                    )
                )

                let originalState = router.state

                #expect(!router.push(path: "/missing"))
                #expect(router.state == originalState)
                #expect(router.navigationPath.isEmpty)
            }

            @Test(
                "Does not commit state updates when navigate matches a screen that returns an empty stack"
            )
            func
                doesNotCommitStateUpdatesWhenNavigateMatchesAScreenThatReturnsAnEmptyStack()
            {
                let router = Router<TestRoute>(
                    state: TestState(
                        matchedID: "seed",
                        search: "existing",
                        tags: ["one"],
                        showSettingsSheet: false
                    )
                )

                let originalState = router.state

                #expect(!router.push(path: "/users/empty"))
                #expect(router.state == originalState)
                #expect(router.navigationPath.isEmpty)
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
                case settings

                struct Stack: TabStack {
                    let settings = TestSettingsRoute.self
                }

                static func from(route: TabRouteMatch<Self>) {
                    route.update { state in
                        state.matchedID = "current"
                    }
                    route.tab("/", .home)
                    route.tab("settings", TestSettingsRoute.self) { url in
                        route.update { state in
                            state.search = "settings"
                        }
                    }
                }

            }

            enum TestSettingsRoute: FromURLRoute, TabRoute {
                typealias State = TestState

                case about

                static var tab: TestTab { .settings }

                static func from(route: RouteMatch<Self>) {
                    route.screen("about") { url in
                        route.update { state in
                            state.showSettingsSheet =
                                url.query("sheet") == "true"
                        }
                        TestSettingsRoute.about
                    }
                    route.screen("draft") { _ in
                        []
                    }
                }

            }

            @Test("Applies state updates when hydrate succeeds")
            func appliesStateUpdatesWhenHydrateSucceeds() {
                let router = TabRouter(initial: TestTab.home, state: TestState())

                #expect(router.hydrate(path: "/settings/about?sheet=true"))
                #expect(router.tab == TestTab.settings)
                #expect(
                    router.state
                        == TestState(
                            matchedID: "current",
                            search: "settings",
                            tags: [],
                            showSettingsSheet: true
                        ))
                #expect(router.settings.state == router.state)
                #expect(router.settings.navigationPath == [.about])
            }

            @Test("Does not commit updates when hydrate finds no route")
            func doesNotCommitUpdatesWhenHydrateFindsNoRoute() {
                let router = TabRouter(
                    initial: TestTab.home,
                    state: TestState(
                        matchedID: "seed",
                        search: "",
                        tags: [],
                        showSettingsSheet: false
                    )
                )

                let originalState = router.state
                let originalTab = router.tab

                #expect(!router.hydrate(path: "/missing"))
                #expect(router.state == originalState)
                #expect(router.settings.state == originalState)
                #expect(router.tab == originalTab)
                #expect(router.settings.navigationPath.isEmpty)
            }

            @Test(
                "Does not commit updates when hydrate matches a screen that returns an empty stack"
            )
            func
                doesNotCommitUpdatesWhenHydrateMatchesAScreenThatReturnsAnEmptyStack()
            {
                let router = TabRouter(
                    initial: TestTab.home,
                    state: TestState(
                        matchedID: "seed",
                        search: "",
                        tags: [],
                        showSettingsSheet: false
                    )
                )

                let originalState = router.state
                let originalTab = router.tab

                #expect(!router.hydrate(path: "/settings/draft?sheet=true"))
                #expect(router.state == originalState)
                #expect(router.settings.state == originalState)
                #expect(router.tab == originalTab)
                #expect(router.settings.navigationPath.isEmpty)
            }

            @Test("Does not commit updates when navigate finds no route")
            func doesNotCommitUpdatesWhenNavigateFindsNoRoute() {
                let router = TabRouter(initial: TestTab.home, state: TestState())

                let originalState = router.state
                let originalTab = router.tab

                #expect(!router.push(path: "/missing"))
                #expect(router.state == originalState)
                #expect(router.settings.state == originalState)
                #expect(router.tab == originalTab)
                #expect(router.settings.navigationPath.isEmpty)
            }

            @Test(
                "Does not commit updates when navigate matches a screen that returns an empty stack"
            )
            func
                doesNotCommitUpdatesWhenNavigateMatchesAScreenThatReturnsAnEmptyStack()
            {
                let router = TabRouter(
                    initial: TestTab.home,
                    state: TestState(
                        matchedID: "seed",
                        search: "",
                        tags: [],
                        showSettingsSheet: false
                    )
                )

                let originalState = router.state
                let originalTab = router.tab

                #expect(!router.push(path: "/settings/draft?sheet=true"))
                #expect(router.state == originalState)
                #expect(router.settings.state == originalState)
                #expect(router.tab == originalTab)
                #expect(router.settings.navigationPath.isEmpty)
            }
        }
    }

    @Suite("Observable Class State")
    struct ObservableClassState {
        @Suite("Stack Router")
        struct StackRouter {
            @Observable
            final class TestState {
                var matchedID = ""
                var search = ""
                var tags: [String] = []
                var showSettingsSheet = false

                struct Snapshot: Equatable {
                    var matchedID: String
                    var search: String
                    var tags: [String]
                    var showSettingsSheet: Bool
                }

                init(
                    matchedID: String = "",
                    search: String = "",
                    tags: [String] = [],
                    showSettingsSheet: Bool = false
                ) {
                    self.matchedID = matchedID
                    self.search = search
                    self.tags = tags
                    self.showSettingsSheet = showSettingsSheet
                }

                var snapshot: Snapshot {
                    Snapshot(
                        matchedID: matchedID,
                        search: search,
                        tags: tags,
                        showSettingsSheet: showSettingsSheet
                    )
                }
            }

            enum TestRoute: FromURLRoute {
                typealias State = TestState

                case user(String)
                case search(String, [String])
                case currentUser

                static func from(route: RouteMatch<Self>) {
                    route.update { state in
                        state.matchedID = "current"
                    }

                    route.screen("users/:id") { url in
                        let id = url.param("id")
                        route.update { state in
                            state.matchedID = id
                        }
                        TestRoute.user(id)
                    }

                    route.screen("users/current", .currentUser)

                    route.screen("users/empty") { _ in
                        route.update { state in
                            state.matchedID = "empty"
                        }
                        []
                    }

                    route.screen("search") { url in
                        let query = url.query("q")
                        let tags = url.query(all: "tag")
                        route.update { state in
                            state.search = query
                            state.tags = tags
                        }
                        TestRoute.search(query, tags)
                    }
                }

            }

            @Test("Applies state updates when hydrate succeeds")
            func appliesStateUpdatesWhenHydrateSucceeds() {
                let state = TestState()
                let router = Router<TestRoute>(state: state)

                #expect(
                    router.hydrate(path: "/search?q=swift&tag=ios&tag=swiftui"))
                #expect(
                    state.snapshot
                        == TestState.Snapshot(
                            matchedID: "current",
                            search: "swift",
                            tags: ["ios", "swiftui"],
                            showSettingsSheet: false
                        ))
                #expect(
                    router.navigationPath == [
                        .search("swift", ["ios", "swiftui"])
                    ])
            }

            @Test("Does not commit updates when hydrate finds no route")
            func doesNotCommitUpdatesWhenHydrateFindsNoRoute() {
                let state = TestState(
                    matchedID: "seed",
                    search: "existing",
                    tags: ["one"],
                    showSettingsSheet: false
                )
                let router = Router<TestRoute>(state: state)

                let originalState = state.snapshot

                #expect(!router.hydrate(path: "/missing"))
                #expect(state.snapshot == originalState)
                #expect(router.navigationPath.isEmpty)
            }

            @Test(
                "Does not commit updates when hydrate matches a screen that returns an empty stack"
            )
            func
                doesNotCommitUpdatesWhenHydrateMatchesAScreenThatReturnsAnEmptyStack()
            {
                let state = TestState(
                    matchedID: "seed",
                    search: "existing",
                    tags: ["one"],
                    showSettingsSheet: false
                )
                let router = Router<TestRoute>(state: state) {
                    TestRoute.user("seed")
                }

                let originalState = state.snapshot
                let originalPath = router.navigationPath

                #expect(!router.hydrate(path: "/users/empty"))
                #expect(state.snapshot == originalState)
                #expect(router.navigationPath == originalPath)
            }

            @Test("Does not commit state updates when navigate finds no route")
            func doesNotCommitStateUpdatesWhenNavigateFindsNoRoute() {
                let state = TestState(
                    matchedID: "seed",
                    search: "existing",
                    tags: ["one"],
                    showSettingsSheet: false
                )
                let router = Router<TestRoute>(state: state)

                let originalState = state.snapshot

                #expect(!router.push(path: "/missing"))
                #expect(state.snapshot == originalState)
                #expect(router.navigationPath.isEmpty)
            }

            @Test(
                "Does not commit state updates when navigate matches a screen that returns an empty stack"
            )
            func
                doesNotCommitStateUpdatesWhenNavigateMatchesAScreenThatReturnsAnEmptyStack()
            {
                let state = TestState(
                    matchedID: "seed",
                    search: "existing",
                    tags: ["one"],
                    showSettingsSheet: false
                )
                let router = Router<TestRoute>(state: state)

                let originalState = state.snapshot

                #expect(!router.push(path: "/users/empty"))
                #expect(state.snapshot == originalState)
                #expect(router.navigationPath.isEmpty)
            }
        }

        @Suite("Tab Router")
        struct TabRouterSuite {
            @Observable
            final class TestState {
                var matchedID = ""
                var search = ""
                var tags: [String] = []
                var showSettingsSheet = false

                struct Snapshot: Equatable {
                    var matchedID: String
                    var search: String
                    var tags: [String]
                    var showSettingsSheet: Bool
                }

                var snapshot: Snapshot {
                    Snapshot(
                        matchedID: matchedID,
                        search: search,
                        tags: tags,
                        showSettingsSheet: showSettingsSheet
                    )
                }
            }

            enum TestTab: FromURLTabSelection {
                typealias State = TestState

                case home
                case settings

                struct Stack: TabStack {
                    let settings = TestSettingsRoute.self
                }

                static func from(route: TabRouteMatch<Self>) {
                    route.update { state in
                        state.matchedID = "current"
                    }
                    route.tab("/", .home)
                    route.tab("settings", TestSettingsRoute.self) { url in
                        route.update { state in
                            state.search = "settings"
                        }
                    }
                }

            }

            enum TestSettingsRoute: FromURLRoute, TabRoute {
                typealias State = TestState

                case about

                static var tab: TestTab { .settings }

                static func from(route: RouteMatch<Self>) {
                    route.screen("about") { url in
                        route.update { state in
                            state.showSettingsSheet =
                                url.query("sheet") == "true"
                        }
                        TestSettingsRoute.about
                    }
                    route.screen("draft") { _ in
                        []
                    }
                }

            }

            @Test("Applies state updates when hydrate succeeds")
            func appliesStateUpdatesWhenHydrateSucceeds() {
                let state = TestState()
                let router = TabRouter(initial: TestTab.home, state: state)

                #expect(router.hydrate(path: "/settings/about?sheet=true"))
                #expect(router.tab == TestTab.settings)
                #expect(
                    state.snapshot
                        == TestState.Snapshot(
                            matchedID: "current",
                            search: "settings",
                            tags: [],
                            showSettingsSheet: true
                        ))
                #expect(router.settings.state.snapshot == state.snapshot)
                #expect(router.settings.navigationPath == [.about])
            }

            @Test("Does not commit updates when hydrate finds no route")
            func doesNotCommitUpdatesWhenHydrateFindsNoRoute() {
                let state = TestState()
                state.matchedID = "seed"
                let router = TabRouter(initial: TestTab.home, state: state)

                let originalState = state.snapshot
                let originalTab = router.tab

                #expect(!router.hydrate(path: "/missing"))
                #expect(state.snapshot == originalState)
                #expect(router.settings.state.snapshot == originalState)
                #expect(router.tab == originalTab)
                #expect(router.settings.navigationPath.isEmpty)
            }

            @Test(
                "Does not commit updates when hydrate matches a screen that returns an empty stack"
            )
            func
                doesNotCommitUpdatesWhenHydrateMatchesAScreenThatReturnsAnEmptyStack()
            {
                let state = TestState()
                state.matchedID = "seed"
                let router = TabRouter(initial: TestTab.home, state: state)

                let originalState = state.snapshot
                let originalTab = router.tab

                #expect(!router.hydrate(path: "/settings/draft?sheet=true"))
                #expect(state.snapshot == originalState)
                #expect(router.settings.state.snapshot == originalState)
                #expect(router.tab == originalTab)
                #expect(router.settings.navigationPath.isEmpty)
            }

            @Test("Does not commit updates when navigate finds no route")
            func doesNotCommitUpdatesWhenNavigateFindsNoRoute() {
                let state = TestState()
                let router = TabRouter(initial: TestTab.home, state: state)

                let originalState = state.snapshot
                let originalTab = router.tab

                #expect(!router.push(path: "/missing"))
                #expect(state.snapshot == originalState)
                #expect(router.settings.state.snapshot == originalState)
                #expect(router.tab == originalTab)
                #expect(router.settings.navigationPath.isEmpty)
            }

            @Test(
                "Does not commit updates when navigate matches a screen that returns an empty stack"
            )
            func
                doesNotCommitUpdatesWhenNavigateMatchesAScreenThatReturnsAnEmptyStack()
            {
                let state = TestState()
                state.matchedID = "seed"
                let router = TabRouter(initial: TestTab.home, state: state)

                let originalState = state.snapshot
                let originalTab = router.tab

                #expect(!router.push(path: "/settings/draft?sheet=true"))
                #expect(state.snapshot == originalState)
                #expect(router.settings.state.snapshot == originalState)
                #expect(router.tab == originalTab)
                #expect(router.settings.navigationPath.isEmpty)
            }
        }
    }
}
