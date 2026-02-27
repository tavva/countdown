// ABOUTME: Tests for Keychain storage operations.
// ABOUTME: Verifies save, load, update, and delete of token data.

import Testing
import Foundation
@testable import Countdown

@Suite("Keychain")
struct KeychainTests {
    let service = "com.countdown.test.\(UUID().uuidString)"
    let account = "test-account"

    @Test func saveAndLoad() throws {
        let data = Data("test-token".utf8)
        try Keychain.save(data, service: service, account: account)
        let loaded = try Keychain.load(service: service, account: account)
        #expect(loaded == data)
        try Keychain.delete(service: service, account: account)
    }

    @Test func loadNonexistentThrows() {
        #expect(throws: KeychainError.itemNotFound) {
            try Keychain.load(service: service, account: account)
        }
    }

    @Test func saveOverwritesExisting() throws {
        let first = Data("first".utf8)
        let second = Data("second".utf8)
        try Keychain.save(first, service: service, account: account)
        try Keychain.save(second, service: service, account: account)
        let loaded = try Keychain.load(service: service, account: account)
        #expect(loaded == second)
        try Keychain.delete(service: service, account: account)
    }

    @Test func deleteRemovesItem() throws {
        let data = Data("delete-me".utf8)
        try Keychain.save(data, service: service, account: account)
        try Keychain.delete(service: service, account: account)
        #expect(throws: KeychainError.itemNotFound) {
            try Keychain.load(service: service, account: account)
        }
    }

    @Test func deleteNonexistentDoesNotThrow() throws {
        try Keychain.delete(service: service, account: account)
    }
}
