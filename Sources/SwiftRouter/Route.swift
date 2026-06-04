//
//  Route.swift
//  SwiftRouter
//
//  Created by Eric Afes on 04/06/2026.
//

import Foundation

public protocol Route: Hashable {
    associatedtype State = Void
    associatedtype Data = Void
    static func data(route: Self?) -> RouteData<Data>
}

extension Route where Data == Void {
    public static func data(route: Self?) -> RouteData<Void> { .data(root: false, ()) }
}

public protocol URLRouter {
    @discardableResult
    func push(path: String) -> Bool
    @discardableResult
    func go(path: String) -> Bool
    @discardableResult
    func replace(path: String) -> Bool
    @discardableResult
    func hydrate(url: URL, replace: Bool) -> Bool
    @discardableResult
    func hydrate(path: String, replace: Bool) -> Bool
}

public extension URLRouter {
    @discardableResult
    func hydrate(url: URL) -> Bool {
        hydrate(url: url, replace: false)
    }
    @discardableResult
    func hydrate(path: String) -> Bool {
        hydrate(path: path, replace: false)
    }
}

public protocol URLRoute: FromURLRoute, IntoURLRoute {}

public protocol URLTabSelection: FromURLTabSelection, IntoURLTabSelection {}

public protocol TabSelection: Hashable {
    associatedtype State = Void
    associatedtype Stack = Void
}

public protocol TabStack { init() }

public protocol TabRoute: Route where State == Tab.State {
    associatedtype Tab: TabSelection
    static var tab: Tab { get }
}

public enum RouteData<Value> {
    case data(root: Bool, Value)
}

@resultBuilder
public enum RouteBuilder<T: Route> {
    public static func buildExpression(_ expression: T) -> [T] {
        [expression]
    }

    public static func buildExpression(_ expression: [T]) -> [T] {
        expression
    }

    public static func buildOptional(_ component: [T]?) -> [T] {
        component ?? []
    }

    public static func buildEither(first component: [T]) -> [T] {
        component
    }

    public static func buildEither(second component: [T]) -> [T] {
        component
    }

    public static func buildBlock(_ components: [T]...) -> [T] {
        components.flatMap { $0 }
    }
}
