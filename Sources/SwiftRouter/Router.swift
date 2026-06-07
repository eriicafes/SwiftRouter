//
//  Router.swift
//  SwiftRouter
//
//  Created by Eric Afes on 04/06/2026.
//

import Foundation
import Observation

enum RouterState<State> {
    case value(State)
    case ref(initial: State, get: () -> State?, set: (State) -> Void)

    mutating func get() -> State {
        switch self {
        case .value(let state): return state
        case .ref(let initial, let get, _): return get() ?? initial
        }
    }

    mutating func set(_ state: State) {
        switch self {
        case .value: self = .value(state)
        case .ref(_, _, let set): set(state)
        }
    }
}

@Observable
/// A stack router that owns navigation state for a single route type.
public final class Router<T: Route> {
    public typealias State = T.State

    fileprivate var rootRoute: T?

    var _state: RouterState<T.State>
    /// Shared state owned by this router.
    public var state: T.State {
        get { _state.get() }
        set { _state.set(newValue) }
    }
    /// The pushed routes above the root view.
    public var navigationPath: [T] = []

    /// The current route, including the root route when the stack is empty.
    public var route: T? {
        navigationPath.last ?? rootRoute
    }

    /// Data derived from the root route.
    public var data: T.Data {
        switch T.data(route: rootRoute) {
        case .data(_, let value):
            return value
        }
    }

    init(state: RouterState<T.State>, stack: [T]) {
        self._state = state
        apply(stack: stack)
    }

    /// Creates a router with shared state and an initial stack derived from that state.
    public init(
        _ state: T.State,
        @RouteBuilder<T> _ stack: (T.State) -> [T]
    ) {
        self._state = .value(state)
        apply(stack: stack(state))
    }

    /// Creates a router with shared state and an optional initial stack.
    public convenience init(
        _ state: T.State,
        @RouteBuilder<T> _ stack: () -> [T] = { [] }
    ) {
        self.init(state, { _ in return stack() })
    }

    /// Creates a router with an optional initial stack.
    public convenience init(
        @RouteBuilder<T> _ stack: () -> [T] = { [] }
    ) where T.State == Void {
        self.init((), stack)
    }

    /// Pushes a route onto the top of the navigation stack.
    public func push(_ route: T) {
        navigationPath.append(route)
    }

    /// Pops the current route, or clears the stack when `root` is `true`.
    public func back(root: Bool = false) {
        if root {
            navigationPath.removeAll()
            return
        }
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    /// Navigates to an existing route in the stack, or pushes it if not found.
    public func go(to route: T) {
        guard let index = navigationPath.lastIndex(of: route) else {
            navigationPath.append(route)
            return
        }
        navigationPath.removeSubrange(navigationPath.index(after: index)...)
    }

    /// Replaces the current route with a new route.
    public func replace(_ route: T) {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
        navigationPath.append(route)
    }

    private func apply(stack: [T]) {
        if let first = stack.first,
            case .data(let root, _) = T.data(route: first),
            root
        {
            rootRoute = first
            navigationPath = Array(stack.dropFirst())
        } else {
            rootRoute = nil
            navigationPath = stack
        }
    }
}

extension Router: URLRouter where T: FromURLRoute {
    private func destination(path: String) -> (
        updateState: (inout T.State) -> Void, route: T
    )? {
        let match = RouteMatch<T>.match(path, route: T.self)
        guard let value = match.stack.last else {
            return nil
        }
        return (match.updateState, value)
    }

    /// Parses a path and pushes the matched route.
    @discardableResult
    public func push(path: String) -> Bool {
        guard let destination = destination(path: path) else {
            return false
        }
        destination.updateState(&state)
        push(destination.route)
        return true
    }

    /// Parses a path and navigates to the matched route, or pushes it if not found.
    @discardableResult
    public func go(path: String) -> Bool {
        guard let destination = destination(path: path) else {
            return false
        }
        destination.updateState(&state)
        go(to: destination.route)
        return true
    }

    /// Parses a path and replaces the current route with the matched route.
    @discardableResult
    public func replace(path: String) -> Bool {
        guard let destination = destination(path: path) else {
            return false
        }
        destination.updateState(&state)
        replace(destination.route)
        return true
    }

    /// Parses a URL and updates the router from it.
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

    /// Parses a path and updates the router from it.
    @discardableResult
    public func hydrate(path: String, replace: Bool = false) -> Bool {
        if !replace && route != nil {
            return push(path: path)
        }

        let match = RouteMatch.match(path, route: T.self)
        let isRoot = path == "/" || path.starts(with: "/?")
        guard !match.stack.isEmpty || isRoot else {
            return false
        }

        match.updateState(&state)
        apply(stack: match.stack)
        return true
    }
}

extension Router where T: IntoURLRoute {
    /// Generates a URL path string for the current route.
    public func string() -> String {
        return self.route?.into(route: RouteURL(state: state)) ?? "/"
    }
}
