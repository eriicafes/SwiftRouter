//
//  Route.swift
//  SwiftRouter
//
//  Created by Eric Afes on 04/06/2026.
//

import Foundation

// MARK: - Core Types

/// A typed route value that represents a screen in a navigation stack.
public protocol Route: Hashable {
    /// Shared state owned by the router.
    associatedtype State = Void
    /// Data exposed from the root route.
    associatedtype Data = Void
    /// Extracts the current root route data or returns a fallback.
    static func data(route: Self?) -> RouteData<Data>
}

extension Route where Data == Void {
    public static func data(route: Self?) -> RouteData<Void> { .data(root: false, ()) }
}

/// A type representing the selected tab in a `TabRouter`.
public protocol TabSelection: Hashable {
    /// Shared state owned by the tab router.
    associatedtype State = Void
    /// The collection of stack routers available inside the tab router.
    associatedtype Stack = Void
}

/// A namespace type describing the stack routers available for a tab selection.
public protocol TabStack { init() }

/// A route type associated with a specific tab in a `TabRouter`.
public protocol TabRoute: Route where State == Tab.State {
    /// The tab selection type for this route.
    associatedtype Tab: TabSelection
    /// The tab this route belongs to.
    static var tab: Tab { get }
}

// MARK: - URL Types

/// A route type that can be parsed from a URL path.
public protocol FromURLRoute: Route {
    /// Matches the route type from a URL path.
    static func from(route: RouteMatch<Self>)
}

/// A route type that can build a URL path.
public protocol IntoURLRoute: Route {
    /// Builds a path string for this route.
    func into(route: RouteURL<Self>) -> String
}

/// A route type that can both parse from URLs and build URLs.
public protocol URLRoute: FromURLRoute, IntoURLRoute {}

/// A tab selection type that can be parsed from a URL path.
public protocol FromURLTabSelection: TabSelection {
    /// Matches the tab selection from a URL path.
    static func from(route: TabRouteMatch<Self>)
}

/// A tab selection type that can build a URL path.
public protocol IntoURLTabSelection: TabSelection {
    /// Builds a path string for this tab selection.
    func into(route: TabRouteURL<Self>) -> String
}

/// A tab selection type that can both parse from URLs and build URLs.
public protocol URLTabSelection: FromURLTabSelection, IntoURLTabSelection {}

/// URL-based router.
public protocol URLRouter<State> {
    associatedtype State
    /// Shared state owned by the router.
    var state: State { get set }
    /// Parses a path and pushes the matched route.
    @discardableResult
    func push(path: String) -> Bool
    /// Parses a path and navigates to the matched route, or pushes it if not found.
    @discardableResult
    func go(path: String) -> Bool
    /// Parses a path and replaces the current route with the matched route.
    @discardableResult
    func replace(path: String) -> Bool
    /// Parses a URL and updates the router from it.
    @discardableResult
    func hydrate(url: URL, replace: Bool) -> Bool
    /// Parses a path and updates the router from it.
    @discardableResult
    func hydrate(path: String, replace: Bool) -> Bool
}

public extension URLRouter {
    /// Parses a URL and updates the router from it.
    @discardableResult
    func hydrate(url: URL) -> Bool {
        hydrate(url: url, replace: false)
    }
    /// Parses a path and updates the router from it.
    @discardableResult
    func hydrate(path: String) -> Bool {
        hydrate(path: path, replace: false)
    }
}

// MARK: - Utility Types

/// Root route metadata exposed through `Router.data`.
public enum RouteData<Value> {
    /// A data value and whether it came from an explicit root route.
    case data(root: Bool, Value)
}

/// Builds route stack.
@resultBuilder
public enum RouteBuilder<T: Route> {
    /// Wraps a single route value.
    public static func buildExpression(_ expression: T) -> [T] {
        [expression]
    }

    /// Passes through an existing route array.
    public static func buildExpression(_ expression: [T]) -> [T] {
        expression
    }

    /// Handles optional route arrays.
    public static func buildOptional(_ component: [T]?) -> [T] {
        component ?? []
    }

    /// Handles the first conditional branch.
    public static func buildEither(first component: [T]) -> [T] {
        component
    }

    /// Handles the second conditional branch.
    public static func buildEither(second component: [T]) -> [T] {
        component
    }

    /// Flattens multiple route arrays into a single stack.
    public static func buildBlock(_ components: [T]...) -> [T] {
        components.flatMap { $0 }
    }
}
