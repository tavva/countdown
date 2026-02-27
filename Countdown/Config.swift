// ABOUTME: Loads Google OAuth client credentials from a bundled plist.
// ABOUTME: Returns nil when the plist is missing so the UI can show setup instructions.

import Foundation

struct Config {
    let clientID: String
    let clientSecret: String

    static func load(from name: String = "Config") -> Config? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let clientID = dict["GOOGLE_CLIENT_ID"] as? String,
              let clientSecret = dict["GOOGLE_CLIENT_SECRET"] as? String,
              !clientID.isEmpty,
              !clientSecret.isEmpty
        else {
            return nil
        }
        return Config(clientID: clientID, clientSecret: clientSecret)
    }
}
