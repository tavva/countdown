// ABOUTME: Listens on a localhost port for the OAuth redirect callback.
// ABOUTME: Extracts the authorisation code from the browser redirect and sends a success page.

import Foundation
import Network

/// Thread-safe one-shot flag to prevent resuming a continuation twice.
private final class ContinuationGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var _resumed = false

    /// Returns true if this is the first call; false on subsequent calls.
    func tryResume() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !_resumed else { return false }
        _resumed = true
        return true
    }

    func markResumed() {
        lock.lock()
        _resumed = true
        lock.unlock()
    }
}

final class RedirectListener: @unchecked Sendable {
    private let listener: NWListener
    let port: UInt16
    private var pendingConnection: NWConnection?

    init() async throws {
        let nwListener = try NWListener(using: .tcp, on: .any)
        self.listener = nwListener

        // NWListener requires newConnectionHandler before start()
        nwListener.newConnectionHandler = { [weak nwListener] connection in
            // Stash the connection — waitForCode() will process it
            // This is a workaround: we can't set the real handler until
            // waitForCode is called, but NWListener requires one before start.
            _ = nwListener
        }

        port = try await withCheckedThrowingContinuation { continuation in
            nwListener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let assignedPort = nwListener.port?.rawValue {
                        continuation.resume(returning: assignedPort)
                    } else {
                        continuation.resume(throwing: GoogleAuthError.listenerFailed)
                    }
                case .failed(let error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            nwListener.start(queue: .main)
        }

        // Now that we're ready, set the real connection handler that stashes
        // connections for waitForCode to pick up
        nwListener.newConnectionHandler = { [weak self] connection in
            self?.pendingConnection = connection
        }
    }

    func waitForCode(expectedState: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let guard_ = ContinuationGuard()

            // Check if a connection already arrived
            if let connection = pendingConnection {
                pendingConnection = nil
                guard_.markResumed()
                handle(connection: connection, expectedState: expectedState, continuation: continuation)
                return
            }

            // Otherwise wait for next connection
            listener.newConnectionHandler = { [weak self] connection in
                guard guard_.tryResume() else {
                    connection.cancel()
                    return
                }
                self?.listener.newConnectionHandler = nil
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
