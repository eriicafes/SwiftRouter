//
//  TabRouter.swift
//  SwiftRouter
//
//  Created by Eric Afes on 04/06/2026.
//

import Foundation
import Observation

@Observable
@dynamicMemberLookup
/// A router that coordinates tab selection and per-tab stack routers.
public final class TabRouter<Tab: TabSelection> {
    public typealias State = Tab.State

    fileprivate var tabStack: Tab.Stack?
    fileprivate var routers: [ObjectIdentifier: Any] = [:]

    /// Shared state for the tab router and its child stack routers.
    public var state: Tab.State
    /// The currently selected tab.
    public var tab: Tab

    /// Creates a tab router with shared state and an initial tab.
    public init(initial: Tab, state: Tab.State) {
        self.state = state
        self.tab = initial
    }

    /// Creates a tab router with an initial tab.
    public convenience init(initial: Tab) where Tab.State == Void {
        self.init(initial: initial, state: ())
    }

    func stack<Route: TabRoute>(_ route: Route.Type) -> Router<Route>
    where Route.Tab == Tab, Route.State == Tab.State {
        let key = ObjectIdentifier(route)
        if let router = routers[key] as? Router<Route> {
            return router
        }

        let router = Router<Route>(state: routerState(), stack: [])
        routers[key] = router
        return router
    }

    private func routerState() -> RouterState<Tab.State> {
        .shared(with: self, state: \.state)
    }
}

extension TabRouter where Tab.Stack: TabStack {
    /// Returns a stack router using the tab stack's dynamic member lookup.
    public subscript<Route: TabRoute>(
        dynamicMember keyPath: KeyPath<Tab.Stack, Route.Type>
    ) -> Router<Route>
    where Route.Tab == Tab {
        let tabStack = self.tabStack ?? Tab.Stack()
        if self.tabStack == nil {
            self.tabStack = tabStack
        }
        return stack(tabStack[keyPath: keyPath])
    }
}

extension TabRouter: URLRouter where Tab: FromURLTabSelection {
    private func destination(path: String) -> (
        updateState: (inout Tab.State) -> Void,
        tab: Tab,
        nested: (router: any URLRouter<Tab.State>, path: String)?
    )? {
        let match = TabRouteMatch<Tab>.match(path, tab: Tab.self)
        guard let tab = match.tab else {
            return nil
        }

        guard let (key, matchedRouter, path) = match.router
        else {
            return (
                updateState: match.updateState, tab: tab, nested: nil
            )
        }

        var router: any URLRouter<Tab.State> {
            if let cachedRouter = routers[key] as? any URLRouter<Tab.State> {
                return cachedRouter
            }
            let newRouter = matchedRouter(routerState())
            routers[key] = newRouter
            return newRouter
        }
        return (
            updateState: match.updateState,
            tab: tab, nested: (router: router, path: path)
        )
    }

    /// Parses a path and pushes the matched route.
    @discardableResult
    public func push(path: String) -> Bool {
        guard let destination = destination(path: path) else {
            return false
        }
        if let nested = destination.nested,
            !nested.router.push(path: nested.path)
        {
            return false
        }
        destination.updateState(&state)
        tab = destination.tab
        return true
    }

    /// Parses a path and navigates to the matched route, or pushes it if not found.
    @discardableResult
    public func go(path: String) -> Bool {
        guard let destination = destination(path: path) else {
            return false
        }
        if let nested = destination.nested,
            !nested.router.go(path: nested.path)
        {
            return false
        }
        destination.updateState(&state)
        tab = destination.tab
        return true
    }

    /// Parses a path and replaces the current route with the matched route.
    @discardableResult
    public func replace(path: String) -> Bool {
        guard let destination = destination(path: path) else {
            return false
        }
        if let nested = destination.nested,
            !nested.router.replace(path: nested.path)
        {
            return false
        }
        destination.updateState(&state)
        tab = destination.tab
        return true
    }

    /// Parses a URL and updates the tab router from it.
    @discardableResult
    public func hydrate(url: URL, replace: Bool = false) -> Bool {
        var components =
            URLComponents(url: url, resolvingAgainstBaseURL: true)
            ?? URLComponents()
        let scheme = components.scheme?.lowercased()
        let host = components.host

        components.scheme = nil
        components.host = nil

        var path = components.string ?? components.path

        if scheme != "http",
            scheme != "https",
            let host,
            !host.isEmpty
        {
            path = "/" + host + path
        }

        return hydrate(path: path, replace: replace)
    }

    /// Parses a path and updates the tab router from it.
    @discardableResult
    public func hydrate(path: String, replace: Bool = false) -> Bool {
        let match = TabRouteMatch.match(path, tab: Tab.self)
        guard let tab = match.tab else {
            return false
        }
        if let (key, matchedRouter, path) = match.router {
            if let router = routers[key] as? any URLRouter<Tab.State> {
                guard router.hydrate(path: path, replace: replace) else {
                    return false
                }
            } else {
                routers[key] = matchedRouter(routerState())
            }
        }
        match.updateState(&state)
        self.tab = tab
        return true
    }
}

extension TabRouter where Tab: IntoURLTabSelection {
    /// Generates a URL path string for the current tab and active stack route.
    public func string() -> String {
        return tab.into(route: TabRouteURL(self, state: state))
    }
}
