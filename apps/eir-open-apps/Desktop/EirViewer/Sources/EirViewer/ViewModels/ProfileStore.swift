import Foundation
import SwiftUI

@MainActor
class ProfileStore: ObservableObject {
    @Published var profiles: [PersonProfile] = []
    @Published var selectedProfileID: UUID?
    @Published var errorMessage: String?

    private let profilesKey = "eir_person_profiles"
    private let selectedIDKey = "eir_selected_profile_id"

    init() {
        loadFromDefaults()
    }

    var selectedProfile: PersonProfile? {
        profiles.first(where: { $0.id == selectedProfileID })
    }

    @discardableResult
    func addProfile(displayName: String, personalNumber: String? = nil, fileURL: URL) -> PersonProfile? {
        errorMessage = nil
        let doc: EirDocument
        do {
            doc = try EirParser.parse(url: fileURL)
        } catch {
            let detail = "\(error)"
            errorMessage = "Failed to load: \(detail)"
            let log = "[ProfileStore] Failed to parse \(fileURL.path):\n\(detail)\n"
            try? log.write(toFile: "/tmp/eirviewer_error.log", atomically: true, encoding: .utf8)
            return nil
        }

        let patient = doc.metadata.patient
        let name = displayName.isEmpty ? (patient?.name ?? fileURL.deletingPathExtension().lastPathComponent) : displayName
        let pnr = personalNumber ?? patient?.personalNumber

        let profile = PersonProfile(
            id: UUID(),
            displayName: name,
            fileURL: fileURL,
            patientName: patient?.name,
            personalNumber: pnr,
            birthDate: patient?.birthDate,
            totalEntries: doc.entries.count,
            addedAt: Date()
        )

        profiles.append(profile)
        saveToDefaults()
        return profile
    }

    func selectProfile(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        selectedProfileID = id
        saveToDefaults()
    }

    func removeProfile(_ id: UUID) {
        profiles.removeAll(where: { $0.id == id })
        if selectedProfileID == id {
            selectedProfileID = profiles.first?.id
        }
        saveToDefaults()
    }

    func renameProfile(_ id: UUID, to newName: String) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].displayName = newName
        saveToDefaults()
    }

    func updateProfile(_ id: UUID, displayName: String, personalNumber: String?) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].displayName = displayName
        profiles[index].personalNumber = personalNumber
        saveToDefaults()
    }

    /// Replace the .eir file for an existing profile and update entry count.
    func replaceFile(_ id: UUID, with newFileURL: URL) -> Bool {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return false }
        guard let doc = try? EirParser.parse(url: newFileURL) else { return false }

        // Copy file to a stable location in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let eirDir = appSupport.appendingPathComponent("EirViewer/profiles")
        try? FileManager.default.createDirectory(at: eirDir, withIntermediateDirectories: true)
        let destURL = eirDir.appendingPathComponent("\(id.uuidString).eir")
        try? FileManager.default.removeItem(at: destURL)
        do {
            try FileManager.default.copyItem(at: newFileURL, to: destURL)
        } catch {
            errorMessage = "Could not copy file: \(error.localizedDescription)"
            return false
        }

        profiles[index] = PersonProfile(
            id: id,
            displayName: profiles[index].displayName,
            fileURL: destURL,
            patientName: doc.metadata.patient?.name,
            personalNumber: profiles[index].personalNumber ?? doc.metadata.patient?.personalNumber,
            birthDate: doc.metadata.patient?.birthDate,
            totalEntries: doc.entries.count,
            addedAt: profiles[index].addedAt
        )
        saveToDefaults()
        return true
    }

    /// Find a profile matching by display name (case-insensitive, diacritics-insensitive, bidirectional contains).
    func findMatchingProfile(name: String) -> PersonProfile? {
        let normalizedName = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return profiles.first { profile in
            let normalizedProfile = profile.displayName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return normalizedProfile.contains(normalizedName) ||
                   normalizedName.contains(normalizedProfile) ||
                   profile.displayName.localizedCaseInsensitiveContains(name) ||
                   name.localizedCaseInsensitiveContains(profile.displayName)
        }
    }

    // MARK: - Persistence

    private func saveToDefaults() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(profiles) {
            UserDefaults.standard.set(data, forKey: profilesKey)
        }
        if let id = selectedProfileID {
            UserDefaults.standard.set(id.uuidString, forKey: selectedIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedIDKey)
        }
    }

    private func loadFromDefaults() {
        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([PersonProfile].self, from: data) {
            profiles = decoded
        }
        if let idString = UserDefaults.standard.string(forKey: selectedIDKey) {
            selectedProfileID = UUID(uuidString: idString)
        }
    }
}
