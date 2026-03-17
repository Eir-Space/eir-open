import Foundation
import CryptoKit

/// Encrypted file-based storage that replaces UserDefaults for sensitive data.
/// Uses AES-GCM encryption with a key stored in the iOS Keychain.
/// All files are written with NSFileProtectionComplete (encrypted when device is locked).
enum EncryptedStore {
    private static let keychainKey = "eir_encryption_key"

    // MARK: - Public API

    /// Save Codable data to an encrypted file.
    static func save<T: Encodable>(_ value: T, forKey key: String) {
        do {
            let json = try JSONEncoder().encode(value)
            let encrypted = try encrypt(json)
            let url = fileURL(for: key)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try encrypted.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            // Silently fail like UserDefaults
        }
    }

    /// Load Codable data from an encrypted file.
    static func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        let url = fileURL(for: key)
        guard let encrypted = try? Data(contentsOf: url) else { return nil }
        guard let json = try? decrypt(encrypted) else {
            // Decryption failed — possibly corrupted. Try reading as plain JSON
            // for migration from old unencrypted UserDefaults data.
            return try? JSONDecoder().decode(type, from: encrypted)
        }
        return try? JSONDecoder().decode(type, from: json)
    }

    /// Remove an encrypted file.
    static func remove(forKey key: String) {
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }

    /// Migrate a value from UserDefaults to encrypted storage, then remove from UserDefaults.
    static func migrateFromUserDefaults<T: Codable>(_ type: T.Type, userDefaultsKey: String, encryptedKey: String? = nil) {
        let key = encryptedKey ?? userDefaultsKey
        // Skip if already migrated
        if FileManager.default.fileExists(atPath: fileURL(for: key).path) { return }

        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let value = try? JSONDecoder().decode(type, from: data) else { return }

        save(value, forKey: key)
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    /// Set file protection on a file URL.
    static func protectFile(at url: URL) {
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
    }

    // MARK: - Encryption

    private static func getOrCreateKey() throws -> SymmetricKey {
        if let existing = KeychainService.get(key: keychainKey),
           let keyData = Data(base64Encoded: existing) {
            return SymmetricKey(data: keyData)
        }

        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        KeychainService.set(key: keychainKey, value: keyData.base64EncodedString())
        return key
    }

    private static func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw EncryptionError.sealFailed
        }
        return combined
    }

    private static func decrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }

    // MARK: - File Paths

    private static var storeDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("EirViewer")
            .appendingPathComponent("encrypted")
    }

    private static func fileURL(for key: String) -> URL {
        // Sanitize key for filesystem
        let safe = key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return storeDirectory.appendingPathComponent("\(safe).enc")
    }

    enum EncryptionError: Error {
        case sealFailed
    }
}
