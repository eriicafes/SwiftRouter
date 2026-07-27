import Foundation
import Testing
@testable import SwiftRouter

@Suite("Router Navigation Tests")
struct RouterNavigationTests {
    struct TestState: Equatable {
        var matchedID = ""
        var search = ""
        var tags: [String] = []
    }

    enum TestUsersRoute: FromURLRoute {
        typealias State = TestState

        case home
        case user(String)

        static func from(route: RouteMatch<Self>) {
            route.screen("home", .home)
            route.screen(":id") { url in
                let id = url.param("id")
                route.update { state in
                    state.matchedID = id
                }

                TestUsersRoute.user(id)
            }
        }

    }

    enum TestRoute: FromURLRoute {
        typealias State = TestState

        case users(TestUsersRoute)
        case filters(String, [String])

        static func from(route: RouteMatch<Self>) {
            route.screen("users", join: TestUsersRoute.self, TestRoute.users)
            route.screen("filters") { url in
                let query = url.query("q")
                let tags = url.query(all: "tag")
                route.update { state in
                    state.search = query
                    state.tags = tags
                }

                TestRoute.filters(query, tags)
            }
        }
    }

    @Test("Mutates the stack with routes")
    func mutatesTheStackWithRoutes() {
        let router = Router<TestRoute>(state: TestState()) {
            TestRoute.users(.user("one"))
            TestRoute.users(.user("two"))
        }

        router.push(.users(.user("three")))
        #expect(
            router.navigationPath == [
                .users(.user("one")), .users(.user("two")),
                .users(.user("three")),
            ])

        router.go(to: .users(.user("two")))
        #expect(
            router.navigationPath == [
                .users(.user("one")), .users(.user("two")),
            ])

        router.go(to: .users(.user("missing")))
        #expect(
            router.navigationPath == [
                .users(.user("one")), .users(.user("two")),
                .users(.user("missing")),
            ])

        router.replace(.users(.user("updated")))
        #expect(
            router.navigationPath == [
                .users(.user("one")), .users(.user("two")),
                .users(.user("updated")),
            ])

        router.back()
        #expect(
            router.navigationPath == [
                .users(.user("one")), .users(.user("two")),
            ])

        router.back(root: true)
        #expect(router.navigationPath.isEmpty)
        #expect(router.route == nil)
    }

    @Test("Mutates the stack and state from URL paths")
    func mutatesTheStackAndStateFromURLPaths() {
        let router = Router<TestRoute>(state: TestState())

        #expect(router.push(path: "/users/41"))
        #expect(
            router.state
                == TestState(
                    matchedID: "41",
                    search: "",
                    tags: []
                ))
        #expect(router.navigationPath == [.users(.user("41"))])

        #expect(router.push(path: "/filters?q=swift&tag=ios"))
        #expect(
            router.state
                == TestState(
                    matchedID: "41",
                    search: "swift",
                    tags: ["ios"]
                ))
        #expect(
            router.navigationPath == [
                .users(.user("41")), .filters("swift", ["ios"]),
            ])

        #expect(router.go(path: "/users/41"))
        #expect(router.navigationPath == [.users(.user("41"))])

        #expect(router.replace(path: "/users/home"))
        #expect(router.navigationPath == [.users(.home)])
    }

    @Test("Leaves state and stack untouched when path navigation fails")
    func leavesStateAndStackUntouchedWhenPathNavigationFails() {
        let router = Router<TestRoute>(state: TestState())
        #expect(router.push(path: "/users/41"))

        let originalState = router.state
        let originalPath = router.navigationPath

        #expect(!router.replace(path: "/filters/extra"))
        #expect(router.state == originalState)
        #expect(router.navigationPath == originalPath)
    }
}
