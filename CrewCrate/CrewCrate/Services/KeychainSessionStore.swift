import Foundation
import Security

nonisolated protocol AuthSessionStore: Sendable {
    func load() throws -> AuthSession?
    func save(_ session: AuthSession) throws
    func clear() throws
}
nonisolated struct KeychainSessionStore: AuthSessionStore {
    private var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "CrewCrate.Supabase.volklcrfpyfddrekulna", kSecAttrAccount as String: "session"] }
    func load() throws -> AuthSession? {
        var q = query; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw AuthError.storage }
        return try JSONDecoder().decode(AuthSession.self, from: data)
    }
    func save(_ session: AuthSession) throws {
        let values: [String: Any] = [kSecValueData as String: try JSONEncoder().encode(session), kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let result = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if result == errSecItemNotFound {
            guard SecItemAdd(query.merging(values) { _, new in new } as CFDictionary, nil) == errSecSuccess else { throw AuthError.storage }
        } else if result != errSecSuccess { throw AuthError.storage }
    }
    func clear() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw AuthError.storage }
    }
}
