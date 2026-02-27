// ABOUTME: Listens on a localhost port for the OAuth redirect callback.
// ABOUTME: Extracts the authorisation code from the browser redirect and sends a success page.

import Foundation
import Network

final class RedirectListener: @unchecked Sendable {
    private let listener: NWListener
    let port: UInt16

    init() throws {
        listener = try NWListener(using: .tcp, on: .any)
        listener.start(queue: .main)

        guard let assignedPort = listener.port?.rawValue else {
            throw GoogleAuthError.listenerFailed
        }
        self.port = assignedPort
    }

    func waitForCode(expectedState: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection: connection, expectedState: expectedState, continuation: continuation)
            }
        }
    }

    static func extractCode(from components: URLComponents?, expectedState: String) throws -> String {
        let queryItems = components?.queryItems ?? []
        let state = queryItems.first(where: { $0.name == "state" })?.value
        guard state == expectedState else { throw GoogleAuthError.stateMismatch }
        let code = queryItems.first(where: { $0.name == "code" })?.value
        guard let code else { throw GoogleAuthError.missingCode }
        return code
    }

    private func handle(
        connection: NWConnection,
        expectedState: String,
        continuation: CheckedContinuation<String, Error>
    ) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            defer {
                self?.listener.cancel()
            }

            guard let data, let request = String(data: data, encoding: .utf8) else {
                continuation.resume(throwing: GoogleAuthError.missingCode)
                connection.cancel()
                return
            }

            let firstLine = request.components(separatedBy: "\r\n").first ?? ""
            let path = firstLine.components(separatedBy: " ").dropFirst().first ?? ""
            let components = URLComponents(string: "http://localhost\(path)")

            let succeeded: Bool
            do {
                let code = try Self.extractCode(from: components, expectedState: expectedState)
                succeeded = true
                continuation.resume(returning: code)
            } catch {
                succeeded = false
                continuation.resume(throwing: error)
            }

            let html = succeeded
                ? "<html><body><h2>Authorisation successful. You may close this window.</h2></body></html>"
                : "<html><body><h2>Authorisation failed.</h2></body></html>"
            let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"

            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}
