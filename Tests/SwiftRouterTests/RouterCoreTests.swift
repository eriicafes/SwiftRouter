import Foundation
import Testing
@testable import SwiftRouter

@Suite("Router Core Tests")
struct RouterCoreTests {
    @Suite("Stack Router")
    struct StackRouter {
        struct TestState: Equatable {
            var lastVisited = ""
        }

        enum TestRoute: Route {
            typealias State = TestState
            typealias Data = String

            case home
            case detail(String)

            static func data(route: TestRoute?) -> RouteData<String> {
                switch route {
                case .home:
                    return .data(root: true, "home")
                case .detail(let id):
                    return .data(root: false, id)
                case nil:
                    return .data(root: false, "")
                }
            }
        }

        @Test("Extracts the root route and exposes root data from it")
        func extractsRootRouteAndExposesRootData() {
            let router = Router<TestRoute>(TestState()) {
                TestRoute.home
                TestRoute.detail("42")
            }

            #expect(router.route == TestRoute.detail("42"))
            #expect(router.navigationPath == [TestRoute.detail("42")])
            #expect(
                router.data == "home",
                "Expected root route data to come from the extracted root route"
            )
        }

        @Test(
            "Falls back to a nil current route when initialized with an empty stack"
        )
        func startsWithoutACurrentRouteWhenTheStackIsEmpty() {
            let router = Router<TestRoute>(TestState())

            #expect(router.route == nil)
            #expect(router.navigationPath.isEmpty)
        }
    }

    @Suite("Tab Router")
    struct TabRouterSuite {
        struct TestState: Equatable {
            var matchedID = ""
        }

        enum TestTab: TabSelection {
            typealias State = TestState

            case home
            case users

            struct Stack: TabStack {
                let users = TestUsersRoute.self
            }
        }

        enum TestUsersRoute: TabRoute {
            typealias State = TestState

            case user(String)

            static var tab: TestTab { .users }
        }

        @Test("Reuses the same router instance for repeated tab stack access")
        func reusesTheSameTabStackRouter() {
            let router = TabRouter(TestState(), initial: TestTab.home)

            let first = router.users
            let second = router.users

            first.push(.user("42"))

            #expect(first === second)
            #expect(second.navigationPath == [.user("42")])
        }
    }
}
