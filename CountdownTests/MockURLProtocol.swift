// ABOUTME: Mock URL protocol for intercepting HTTP requests in tests.
// ABOUTME: Uses an actor for thread-safe handler storage, keyed by URL host for cross-suite isolation.

import Foundation

actor MockRequestHandler {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private var handlers: [String: Handler] = [:]
    private var defaultHandler: Handler?

    func set(_ handler: @escaping Handler) {
        defaultHandler = handler
    }

    func set(forHost host: String, _ handler: @escaping Handler) {
        handlers[host] = handler
    }

    func handle(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let host = request.url?.host ?? ""
        if let handler = handlers[host] {
            return try handler(request)
        }
        guard let handler = defaultHandler else {
            fatalError("MockRequestHandler: no handler set for host '\(host)'")
        }
        return try handler(request)
    }
}

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    static let requestHandler = MockRequestHandler()

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Task {
            do {
                let (response, data) = try await Self.requestHandler.handle(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}
}
