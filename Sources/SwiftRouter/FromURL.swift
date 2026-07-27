//
//  FromURL.swift
//  SwiftRouter
//
//  Created by Eric Afes on 04/06/2026.
//

import Foundation

/// Parsed path and query input passed into URL matching handlers.
public final class RouteURLInput {
    private let params: [String: String]
    private let queryItems: [URLQueryItem]?

    init(params: [String: String], queryItems: [URLQueryItem]?) {
        self.params = params
        self.queryItems = queryItems
    }

    /// Returns a matched path parameter or a fallback value.
    public func param(_ key: String, fallback: String = "") -> String {
        params[key] ?? fallback
    }

    /// Returns the first value for a query item or a fallback value.
    public func query(_ key: String, fallback: String = "") -> String {
        queryItems?.first { $0.name == key }?.value ?? fallback
    }

    /// Returns all values for a query item.
    public func query(all key: String) -> [String] {
        queryItems?
            .filter { $0.name == key }
            .compactMap(\.value) ?? []
    }
}

/// Input used to match routes from a URL path.
public final class RouteMatch<T: FromURLRoute> {
    private let segments: [String]
    private let queryItems: [URLQueryItem]?
    private var segmentMatch: [Int: Bool] = [:]
    private var handler: () -> [T] = { [] }
    private var updates: [(inout T.State) -> Void] = []
    private var matchedRoot = false

    init(_ url: String) {
        let components = URLComponents(string: url)
        let path = components?.path ?? url
        self.segments =
            path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        self.queryItems = components?.queryItems
    }

    /// Applies a state update when the current match succeeds.
    @discardableResult
    public func update(_ fn: @escaping (inout T.State) -> Void) -> [T] {
        updates.append(fn)
        return []
    }

    /// Matches the root path and runs a side-effect handler.
    public func screen(root handler: @escaping ((RouteURLInput) -> Void)) {
        _screen(
            "",
            { url, _ in
                handler(url)
                return []
            })
    }

    /// Matches a fixed path and returns a single route.
    public func screen(
        _ pattern: String,
        _ route: T
    ) {
        _screen(pattern, { _, _ in [route] })
    }

    /// Matches a path and builds one or more routes from the parsed input.
    public func screen(
        _ pattern: String,
        @RouteBuilder<T> _ stack: @escaping (RouteURLInput) -> [T]
    ) {
        _screen(
            pattern,
            { url, _ in
                return stack(url)
            })
    }

    /// Matches a path prefix and builds routes using the remaining unmatched path.
    public func screen(
        _ pattern: String,
        @RouteBuilder<T> _ stack: @escaping (RouteURLInput, String) -> [T]
    ) {
        _screen(
            pattern,
            matchRest: true,
            { url, rest in
                return stack(url, rest)
            })
    }

    /// Matches a path prefix and delegates the remaining path to another route type.
    public func screen<Sub: FromURLRoute>(
        _ pattern: String,
        fallback: Bool = false,
        join sub: Sub.Type,
        _ map: @escaping (Sub) -> T,
        @RouteBuilder<T> _ stack: @escaping (RouteURLInput) -> [T] = { _ in [] }
    ) where Sub.State == T.State {
        _screen(
            pattern,
            matchRest: true,
            { url, rest in
                let pushStack = stack(url)
                let match = RouteMatch<Sub>.match(rest, route: sub)
                if match.stack.isEmpty && !fallback {
                    return []
                }
                self.update { state in match.updateState(&state) }
                return pushStack + match.stack.map(map)
            })
    }

    private func _screen(
        _ pattern: String,
        matchRest: Bool = false,
        _ handler: @escaping (RouteURLInput, String) -> [T]
    ) {
        let result = _match(
            pattern,
            segments: segments,
            segmentMatch: segmentMatch,
            queryItems: queryItems,
            matchRest: matchRest
        )
        guard let result = result else {
            return
        }
        let matchedRoot = pattern == "" || pattern == "/"
        if self.matchedRoot && matchedRoot {
            return
        }
        self.matchedRoot = matchedRoot
        self.segmentMatch = result.nextSegmentMatch
        self.handler = { handler(result.input, result.rest) }
    }

    static func match(_ url: String, route: T.Type) -> (
        updateState: (inout T.State) -> Void,
        stack: [T]
    ) {
        let route = RouteMatch<T>(url)
        T.from(route: route)

        let stack = route.handler()
        let updateState: (inout T.State) -> Void = { state in
            route.updates.forEach({ $0(&state) })
        }
        return (updateState: updateState, stack: stack)
    }
}

/// Input used to match tabs from a URL path.
public final class TabRouteMatch<T: FromURLTabSelection> {
    private let segments: [String]
    private let queryItems: [URLQueryItem]?
    private var segmentMatch: [Int: Bool] = [:]
    private var handler:
        () -> (
            tab: T?,
            router:
                (
                    ObjectIdentifier,
                    (RouterState<T.State>) -> any URLRouter<T.State>,
                    String
                )?
        ) = { (tab: nil, router: nil) }
    private var updates: [(inout T.State) -> Void] = []

    init(_ url: String) {
        let components = URLComponents(string: url)
        let path = components?.path ?? url
        self.segments =
            path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        self.queryItems = components?.queryItems
    }

    /// Applies a state update when the current tab match succeeds.
    public func update(_ fn: @escaping (inout T.State) -> Void) {
        updates.append(fn)
    }

    /// Matches a fixed path and selects a tab directly.
    public func tab(
        _ pattern: String,
        _ tab: T
    ) {
        _tab(pattern, { _, _ in (tab, nil) })
    }

    /// Matches a path and resolves a tab from parsed input.
    public func tab(
        _ pattern: String,
        _ handler: @escaping (RouteURLInput) -> T?
    ) {
        _tab(
            pattern,
            { url, _ in
                guard let tab = handler(url) else {
                    return (nil, nil)
                }
                return (tab, nil)
            })
    }

    /// Matches a path prefix and delegates the remaining path to a tab route type.
    public func tab<Route: TabRoute & FromURLRoute>(
        _ pattern: String,
        _ route: Route.Type,
        _ handler: ((RouteURLInput) -> Void)? = nil
    ) where Route.Tab == T {
        _tab(
            pattern,
            matchRest: true,
            { url, rest in
                handler?(url)
                let match = RouteMatch<Route>.match(rest, route: route)
                let isRoot = rest == "/" || rest.starts(with: "/?")
                guard !match.stack.isEmpty || isRoot else {
                    return (nil, nil)
                }
                self.update { state in match.updateState(&state) }
                let router: (RouterState<T.State>) -> any URLRouter<T.State> = {
                    Router<Route>(state: $0, stack: match.stack)
                }
                return (Route.tab, (ObjectIdentifier(route), router, rest))
            })
    }

    private func _tab(
        _ pattern: String,
        matchRest: Bool = false,
        _ handler: @escaping (RouteURLInput, String) -> (
            tab: T?,
            router:
                (
                    ObjectIdentifier,
                    (RouterState<T.State>) -> any URLRouter<T.State>,
                    String
                )?
        )
    ) {
        let result = _match(
            pattern,
            segments: segments,
            segmentMatch: segmentMatch,
            queryItems: queryItems,
            matchRest: matchRest
        )
        guard let result = result else {
            return
        }
        self.segmentMatch = result.nextSegmentMatch
        self.handler = { handler(result.input, result.rest) }
    }

    static func match(_ url: String, tab: T.Type) -> (
        updateState: (inout T.State) -> Void,
        tab: T?,
        router:
            (
                ObjectIdentifier,
                (RouterState<T.State>) -> any URLRouter<T.State>,
                String
            )?
    ) {
        let route = TabRouteMatch<T>(url)
        T.from(route: route)

        let (tab, router) = route.handler()
        let updateState: (inout T.State) -> Void = { state in
            route.updates.forEach({ $0(&state) })
        }
        return (updateState: updateState, tab: tab, router: router)
    }
}

private func _match(
    _ pattern: String,
    segments: [String],
    segmentMatch: [Int: Bool],
    queryItems: [URLQueryItem]?,
    matchRest: Bool = false
) -> (input: RouteURLInput, rest: String, nextSegmentMatch: [Int: Bool])? {
    let patternSegments =
        pattern
        .split(separator: "/", omittingEmptySubsequences: true)
        .map(String.init)

    if matchRest {
        if patternSegments.count > segments.count { return nil }
    } else {
        if patternSegments.count != segments.count { return nil }
    }

    var params: [String: String] = [:]
    var nextSegmentMatch: [Int: Bool] = [:]
    var prevSegmentLost: Bool = false

    for index in patternSegments.indices {
        let pattern = patternSegments[index]
        let value = segments[index]
        let isStatic = !pattern.hasPrefix(":")
        let hasNextSegment = index < patternSegments.count - 1

        if isStatic && pattern != value { return nil }
        if let isPreviousStatic = segmentMatch[index], !prevSegmentLost {
            if isPreviousStatic && !isStatic { return nil }
            if isPreviousStatic == isStatic {
                if !hasNextSegment { return nil }
            } else {
                prevSegmentLost = true
            }
        }
        if !isStatic {
            params[String(pattern.dropFirst())] = value
        }
        nextSegmentMatch[index] = isStatic
    }

    let restPath =
        "/"
        + segments
        .dropFirst(patternSegments.count)
        .joined(separator: "/")

    var rest: String {
        guard let queryItems, !queryItems.isEmpty else {
            return restPath
        }
        var components = URLComponents()
        components.path = restPath
        components.queryItems = queryItems
        return components.string ?? restPath
    }

    let input = RouteURLInput(params: params, queryItems: queryItems)
    return (input, rest, nextSegmentMatch)
}
