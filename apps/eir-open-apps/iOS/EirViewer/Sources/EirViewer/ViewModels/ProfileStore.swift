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
    func addProfile(displayName: String, fileURL: URL) -> PersonProfile? {
        errorMessage = nil
        let doc: EirDocument
        do {
            doc = try EirParser.parse(url: fileURL)
        } catch {
            let detail = "\(error)"
            errorMessage = "Failed to load: \(detail)"
            // Write to log file for debugging
            let log = "[ProfileStore] Failed to parse \(fileURL.path):\n\(detail)\n"
            try? log.write(toFile: "/tmp/eirviewer_error.log", atomically: true, encoding: .utf8)
            return nil
        }

        let patient = doc.metadata.patient
        let name = displayName.isEmpty ? (patient?.name ?? fileURL.deletingPathExtension().lastPathComponent) : displayName

        let profile = PersonProfile(
            id: UUID(),
            displayName: name,
            fileURL: fileURL,
            patientName: patient?.name,
            personalNumber: patient?.personalNumber,
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
