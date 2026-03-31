import Foundation

@MainActor
final class ActionsViewModel: ObservableObject {
    @Published private(set) var actions: [HealthAction] = []
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    private var states: [String: HealthActionState] = [:]
    private var currentProfileID: UUID?
    private var currentDocumentSignature: String?

    var featuredAction: HealthAction? {
        let pinned = actions.first(where: { state(for: $0).isPinned })
        return pinned ?? scheduledActions.first ?? actions.first
    }

    var scheduledActions: [HealthAction] {
        actions.filter { state(for: $0).schedule != nil }
    }

    var libraryActions: [HealthAction] {
        actions.filter { $0.id != featuredAction?.id }
    }

    var completedTodayCount: Int {
        actions.filter(isCompletedToday).count
    }

    func sync(profileID: UUID?, document: EirDocument?) {
        let signature = documentSignature(document)
        if currentProfileID == profileID, currentDocumentSignature == signature, !actions.isEmpty {
            return
        }

        currentProfileID = profileID
        currentDocumentSignature = signature
        loadStates()
        actions = HealthActionGenerator.generateActions(document: document)
    }

    func state(for action: HealthAction) -> HealthActionState {
        states[action.id] ?? HealthActionState()
    }

    func isCompletedToday(_ action: HealthAction) -> Bool {
        state(for: action).completionDayStamps.contains(dayStamp(for: Date()))
    }

    func togglePinned(_ action: HealthAction) {
        var next = state(for: action)
        next.isPinned.toggle()
        states[action.id] = next
        saveStates()
    }

    func toggleCompletedToday(_ action: HealthAction) {
        var next = state(for: action)
        let stamp = dayStamp(for: Date())
        let wasCompleted = next.completionDayStamps.contains(stamp)
        if next.completionDayStamps.contains(stamp) {
            next.completionDayStamps.removeAll { $0 == stamp }
        } else {
            next.completionDayStamps.append(stamp)
            next.completionDayStamps = Array(next.completionDayStamps.suffix(21))
        }
        states[action.id] = next
        saveStates()
        if !wasCompleted, let currentProfileID {
            StateActionLearningEngine.recordActionCompletion(profileID: currentProfileID, actionID: action.id)
        }
        objectWillChange.send()
    }

    func applySchedule(
        for action: HealthAction,
        date: Date,
        cadence: HealthActionCadence,
        notificationsEnabled: Bool,
        calendarEnabled: Bool
    ) async {
        errorMessage = nil
        statusMessage = nil

        var next = state(for: action)
        let existingCalendarID = next.schedule?.calendarEventIdentifier

        do {
            var schedule = HealthActionSchedule(
                date: date,
                cadence: cadence,
                notificationsEnabled: notificationsEnabled,
                calendarEnabled: calendarEnabled,
                calendarEventIdentifier: existingCalendarID
            )

            if notificationsEnabled {
                try await HealthActionScheduler.scheduleNotifications(for: action, schedule: schedule, profileID: currentProfileID)
            } else {
                HealthActionScheduler.removeNotifications(for: action, profileID: currentProfileID)
            }

            if calendarEnabled {
                schedule.calendarEventIdentifier = try await HealthActionScheduler.upsertCalendarEvent(
                    for: action,
                    schedule: schedule,
                    existingIdentifier: existingCalendarID
                )
            } else {
                await HealthActionScheduler.removeCalendarEvent(identifier: existingCalendarID)
                schedule.calendarEventIdentifier = nil
            }

            next.schedule = schedule
            next.isPinned = true
            states[action.id] = next
            saveStates()
            statusMessage = "Set for later."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearSchedule(for action: HealthAction) async {
        errorMessage = nil
        statusMessage = nil

        let existing = state(for: action).schedule
        HealthActionScheduler.removeNotifications(for: action, profileID: currentProfileID)
        await HealthActionScheduler.removeCalendarEvent(identifier: existing?.calendarEventIdentifier)

        var next = state(for: action)
        next.schedule = nil
        states[action.id] = next
        saveStates()
        statusMessage = "Removed from later."
    }

    private func saveStates() {
        EncryptedStore.save(states, forKey: storageKey)
    }

    private func loadStates() {
        states = EncryptedStore.load([String: HealthActionState].self, forKey: storageKey) ?? [:]
    }

    private var storageKey: String {
        if let currentProfileID {
            return "eir_actions_state_\(currentProfileID.uuidString)"
        }
        return "eir_actions_state_global"
    }

    private func dayStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func documentSignature(_ document: EirDocument?) -> String {
        guard let document else { return "none" }
        let ids = document.entries.prefix(6).map(\.id).joined(separator: "|")
        return "\(document.entries.count)|\(ids)"
    }
}
