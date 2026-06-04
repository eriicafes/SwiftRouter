//
//  IntoURL.swift
//  SwiftRouter
//
//  Created by Eric Afes on 04/06/2026.
//

import Foundation

public protocol IntoURLRoute: Route {
    func into(route: RouteURL<Self>) -> String
}

public final class RouteURL<T: IntoURLRoute> {
    private var queryItems: [URLQueryItem] = []
    public var state: T.State

    public init(state: T.State) {
        self.state = state
    }

    public func query(_ key: String, _ value: String, replace: Bool = false) {
        if replace {
            queryItems.removeAll { $0.name == key }
        }
        queryItems.append(URLQueryItem(name: key, value: value))
    }

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

    public func path(_ components: String...) -> String {
        return _path(queryItems: queryItems, components: components)
    }

    public func path<Sub: IntoURLRoute>(_ components: String..., join: Sub) -> String
    where Sub.State == T.State {
        return _join(
            state: state, queryItems: queryItems, components: components,
            join: join)
    }
}

public protocol IntoURLTabSelection: TabSelection {
    func into(route: TabRouteURL<Self>) -> String
}

public final class TabRouteURL<Tab: IntoURLTabSelection> {
    private var queryItems: [URLQueryItem] = []
    private let router: TabRouter<Tab>
    public var state: Tab.State

    public init(_ router: TabRouter<Tab>, state: Tab.State) {
        self.router = router
        self.state = state
    }

    public func query(_ key: String, _ value: String, replace: Bool = false) {
        if replace {
            queryItems.removeAll { $0.name == key }
        }
        queryItems.append(URLQueryItem(name: key, value: value))
    }

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

    public func path(_ components: String...) -> String {
        return _path(queryItems: queryItems, components: components)
    }

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
