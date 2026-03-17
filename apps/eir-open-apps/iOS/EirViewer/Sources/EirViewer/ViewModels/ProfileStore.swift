import Foundation
import SwiftUI

extension Notification.Name {
    static let profileDidLoad = Notification.Name("profileDidLoad")
}

@MainActor
class ProfileStore: ObservableObject {
    @Published var profiles: [PersonProfile] = []
    @Published var selectedProfileID: UUID?
    @Published var errorMessage: String?

    private let profilesKey = "eir_person_profiles"
    private let selectedIDKey = "eir_selected_profile_id"

    init() {
        migrateIfNeeded()
        loadFromStore()
    }

    var selectedProfile: PersonProfile? {
        profiles.first(where: { $0.id == selectedProfileID })
    }

    @discardableResult
    func addProfile(displayName: String, fileURL: URL) -> PersonProfile? {
        errorMessage = nil

        // Start security-scoped access for files from fileImporter
        let didStartAccess = fileURL.startAccessingSecurityScopedResource()
        defer { if didStartAccess { fileURL.stopAccessingSecurityScopedResource() } }

        let doc: EirDocument
        do {
            doc = try EirParser.parse(url: fileURL)
        } catch {
            let detail = "\(error)"
            errorMessage = "Failed to load: \(detail)"
            return nil
        }

        // Copy file to Documents so it persists across app restarts
        let localURL: URL
        do {
            localURL = try copyToDocumentsIfNeeded(fileURL)
        } catch {
            errorMessage = "Failed to save file: \(error.localizedDescription)"
            return nil
        }

        // Set file protection
        EncryptedStore.protectFile(at: localURL)

        let patient = doc.metadata.patient
        let name = displayName.isEmpty ? (patient?.name ?? fileURL.deletingPathExtension().lastPathComponent) : displayName

        let profile = PersonProfile(
            id: UUID(),
            displayName: name,
            fileName: localURL.lastPathComponent,
            patientName: patient?.name,
            personalNumber: patient?.personalNumber,
            birthDate: patient?.birthDate,
            totalEntries: doc.entries.count,
            addedAt: Date()
        )

        profiles.append(profile)
        saveToStore()
        return profile
    }

    func selectProfile(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        selectedProfileID = id
        saveToStore()
        NotificationCenter.default.post(name: .profileDidLoad, object: id)
    }

    func removeProfile(_ id: UUID) {
        // Remove the file from Documents
        if let profile = profiles.first(where: { $0.id == id }) {
            try? FileManager.default.removeItem(at: profile.fileURL)
        }
        profiles.removeAll(where: { $0.id == id })
        if selectedProfileID == id {
            selectedProfileID = profiles.first?.id
        }
        saveToStore()
    }

    func renameProfile(_ id: UUID, to newName: String) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].displayName = newName
        saveToStore()
    }

    /// Find a profile whose display name or patient name matches (case-insensitive).
    func findMatchingProfile(name: String) -> PersonProfile? {
        let lower = name.lowercased()
        return profiles.first { profile in
            profile.displayName.lowercased() == lower ||
            profile.patientName?.lowercased() == lower
        }
    }

    /// Replace an existing profile's .eir file with new data and update metadata.
    func replaceFile(_ profileID: UUID, with fileURL: URL) {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else { return }

        let profile = profiles[index]
        let destURL = profile.fileURL

        do {
            // Remove old file and copy new one
            try? FileManager.default.removeItem(at: destURL)
            try FileManager.default.copyItem(at: fileURL, to: destURL)
            EncryptedStore.protectFile(at: destURL)

            // Update entry count from the new file
            let doc = try EirParser.parse(url: destURL)
            profiles[index] = PersonProfile(
                id: profile.id,
                displayName: profile.displayName,
                fileName: profile.fileName,
                patientName: doc.metadata.patient?.name ?? profile.patientName,
                personalNumber: doc.metadata.patient?.personalNumber ?? profile.personalNumber,
                birthDate: doc.metadata.patient?.birthDate ?? profile.birthDate,
                totalEntries: doc.entries.count,
                addedAt: profile.addedAt
            )
            saveToStore()

            // Notify to reload the updated profile
            if selectedProfileID == profileID {
                NotificationCenter.default.post(name: .profileDidLoad, object: profileID)
            }
        } catch {
            errorMessage = "Failed to update profile: \(error.localizedDescription)"
        }
    }

    // MARK: - File Copy

    private func copyToDocumentsIfNeeded(_ url: URL) throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let docsPath = docs.path

        // Already in Documents — no copy needed
        if url.path.hasPrefix(docsPath) {
            return url
        }

        let destURL = docs.appendingPathComponent(url.lastPathComponent)

        // Avoid overwriting — add UUID suffix if file already exists
        let finalURL: URL
        if FileManager.default.fileExists(atPath: destURL.path) {
            let stem = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            finalURL = docs.appendingPathComponent("\(stem)-\(UUID().uuidString.prefix(8)).\(ext)")
        } else {
            finalURL = destURL
        }

        try FileManager.default.copyItem(at: url, to: finalURL)
        return finalURL
    }

    // MARK: - Encrypted Persistence

    private func saveToStore() {
        EncryptedStore.save(profiles, forKey: profilesKey)
        if let id = selectedProfileID {
            EncryptedStore.save(id.uuidString, forKey: selectedIDKey)
        } else {
            EncryptedStore.remove(forKey: selectedIDKey)
        }
    }

    private func loadFromStore() {
        if let decoded = EncryptedStore.load([PersonProfile].self, forKey: profilesKey) {
            // Validate that each profile's file still exists
            profiles = decoded.filter { profile in
                FileManager.default.fileExists(atPath: profile.fileURL.path)
            }
        }
        if let idString = EncryptedStore.load(String.self, forKey: selectedIDKey) {
            selectedProfileID = UUID(uuidString: idString)
        }
    }

    /// Migrate from plain UserDefaults to encrypted storage (one-time).
    private func migrateIfNeeded() {
        if let data = UserDefaults.standard.data(forKey: profilesKey) {
            if let decoded = try? JSONDecoder().decode([PersonProfile].self, from: data) {
                EncryptedStore.save(decoded, forKey: profilesKey)
            }
            UserDefaults.standard.removeObject(forKey: profilesKey)
        }
        if let idString = UserDefaults.standard.string(forKey: selectedIDKey) {
            EncryptedStore.save(idString, forKey: selectedIDKey)
            UserDefaults.standard.removeObject(forKey: selectedIDKey)
        }
    }
}
