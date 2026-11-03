// ABOUTME: Provides the URLSession the app uses for its Google API calls.
// ABOUTME: It keeps no response cache, so polling doesn't pile up cached bodies in memory.

import Foundation

extension URLSession {
    /// A session that never stores or reads cached responses.
    ///
    /// Every calendar poll asks for a different time window, so each response
    /// is a new URL that would never be reused. With a cache, those responses
    /// accumulated in memory for as long as the app ran.
    static let uncached: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()
}
