// ABOUTME: Persists OAuth tokens to Application Support so they survive in-place app updates.
// ABOUTME: The macOS legacy Keychain ACLs are signature-pinned, which forced a re-login on every release; a file in Application Support stays valid across binary swaps. Runs a one-shot migration from the old Keychain on first launch of this version.

import Foundation

enum TokenStore {
    /// File where OAuth token data is stored. Lives at
    /// `~/Library/Application Support/Countdown/google-oauth.json`.
    private static var fileURL: URL? {
        guard let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        return support
            .appendingPathComponent("Countdown", isDirectory: true)
            .appendingPathComponent("google-oauth.json")
    }

    static func save(_ data: Data) {
        guard let url = fileURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            // File protection isn't enforced on macOS, but `.atomic` ensures
            // partial writes never leave the file half-updated.
        } catch {
            // Silent failure — the user can re-authenticate as a recovery path.
        }
    }

    static func load() -> Data? {
        guard let url = fileURL else { return nil }
        return try? Data(contentsOf: url)
    }

    static func delete() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Reads the legacy keychain entry one final time and writes it into
    /// the file store, then removes the keychain entry. Returns the data
    /// that was migrated, or nil if there was nothing to migrate.
    /// Reading from the legacy keychain may surface a system "Allow access"
    /// prompt because the new binary's signing hash isn't on the keychain
    /// item's trust list — that one prompt is the cost of moving off the
    /// keychain forever.
    static func migrateFromKeychain(service: String, account: String) -> Data? {
        guard let data = try? Keychain.load(service: service, account: account) else {
            return nil
        }
        save(data)
        try? Keychain.delete(service: service, account: account)
        return data
    }
}
