//
//  IntoURL.swift
//  SwiftRouter
//
//  Created by Eric Afes on 04/06/2026.
//

import Foundation

/// Input used to build path and query output for a route.
public final class RouteURL<T: IntoURLRoute> {
    private var queryItems: [URLQueryItem] = []
    /// Shared state available while building the URL.
    public var state: T.State

    /// Creates a URL builder with the current router state.
    public init(state: T.State) {
        self.state = state
    }

    /// Appends or replaces a single query value.
    public func query(_ key: String, _ value: String, replace: Bool = false) {
        if replace {
            queryItems.removeAll { $0.name == key }
        }
        queryItems.append(URLQueryItem(name: key, value: value))
    }

    /// Appends or replaces repeated query values.
    public func query(
        _ key: String,
        _ values: [String],
        replace: Bool = false
    ) {
        if replace {
            queryItems.removeAll { $0.name == key }
        }
        queryItems.append(
            contentsOf: values.map { value in
                URLQueryItem(name: key, value: value.description)
            }
        )
    }

    /// Builds a normalized path from path components and accumulated query items.
    public func path(_ components: String...) -> String {
        return _path(queryItems: queryItems, components: components)
    }

    /// Builds a path by joining another route's URL output onto the current path.
    public func path<Sub: IntoURLRoute>(_ components: String..., join: Sub) -> String
    where Sub.State == T.State {
        return _join(
            state: state, queryItems: queryItems, components: components,
            join: join)
    }
}

/// Input used to build path and query output for a tab selection.
public final class TabRouteURL<Tab: IntoURLTabSelection> {
    private var queryItems: [URLQueryItem] = []
    private let router: TabRouter<Tab>
    /// Shared state available while building the URL.
    public var state: Tab.State

    /// Creates a URL builder with the current tab router and shared state.
    public init(_ router: TabRouter<Tab>, state: Tab.State) {
        self.router = router
        self.state = state
    }

    /// Appends or replaces a single query value.
    public func query(_ key: String, _ value: String, replace: Bool = false) {
        if replace {
            queryItems.removeAll { $0.name == key }
        }
        queryItems.append(URLQueryItem(name: key, value: value))
    }

    /// Appends or replaces repeated query values.
    public func query(
        _ key: String,
        _ values: [String],
        replace: Bool = false
    ) {
        if replace {
            queryItems.removeAll { $0.name == key }
        }
        queryItems.append(
            contentsOf: values.map { value in
                URLQueryItem(name: key, value: value.description)
            }
        )
    }

    /// Builds a normalized path from path components and accumulated query items.
    public func path(_ components: String...) -> String {
        return _path(queryItems: queryItems, components: components)
    }

    /// Builds a path by joining the active route from a tab stack onto the current path.
    public func path<Route: TabRoute & IntoURLRoute>(
        _ components: String..., join: Route.Type
    ) -> String
    where Route.Tab == Tab {
        let router = router.stack(join)
        guard let route = router.route else {
            return _path(queryItems: queryItems, components: components)
        }
        return _join(
            state: state, queryItems: queryItems, components: components,
            join: route)
    }
}

private func _path(queryItems: [URLQueryItem], components: [String]) -> String {
    let rawPath = "/" + _normalize(components).joined(separator: "/")
    guard var input = URLComponents(string: rawPath) else {
        return rawPath
    }
    input.queryItems = queryItems.isEmpty ? nil : queryItems
    return input.string ?? rawPath
}

private func _join<Sub: IntoURLRoute>(
    state: Sub.State, queryItems: [URLQueryItem], components: [String],
    join: Sub
) -> String {
    if components.isEmpty, queryItems.isEmpty {
        return join.into(route: RouteURL<Sub>(state: state))
    }

    let joined = join.into(route: RouteURL<Sub>(state: state))
    let joinedComponents = URLComponents(string: joined)
    let joinedPath = joinedComponents?.path ?? joined

    let rawPath =
        "/" + _normalize(components + [joinedPath]).joined(separator: "/")
    guard var input = URLComponents(string: rawPath) else {
        return rawPath
    }
    let queryItems = queryItems + (joinedComponents?.queryItems ?? [])
    input.queryItems = queryItems.isEmpty ? nil : queryItems
    return input.string ?? rawPath
}

private func _normalize(_ components: [String]) -> [String] {
    components
        .flatMap {
            $0.split(separator: "/", omittingEmptySubsequences: true)
                .map(String.init)
        }
}
