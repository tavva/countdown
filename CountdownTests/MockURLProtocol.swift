// ABOUTME: Mock URL protocol for intercepting HTTP requests in tests.
// ABOUTME: Uses an actor for thread-safe handler storage.

import Foundation

actor MockRequestHandler {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private var handler: Handler?

    func set(_ handler: @escaping Handler) {
        self.handler = handler
    }

    func handle(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        guard let handler else {
            fatalError("MockRequestHandler: no handler set")
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
