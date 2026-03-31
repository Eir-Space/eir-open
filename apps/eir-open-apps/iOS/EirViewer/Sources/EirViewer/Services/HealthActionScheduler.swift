import EventKit
import Foundation
import UserNotifications

enum HealthActionScheduler {
    static func scheduleNotifications(
        for action: HealthAction,
        schedule: HealthActionSchedule,
        profileID: UUID?
    ) async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await requestNotificationAccess(center: center)
        guard granted else {
            throw SchedulerError.notificationsDenied
        }

        let identifiers = notificationIdentifiers(for: action, schedule: schedule, profileID: profileID)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        for request in buildNotificationRequests(for: action, schedule: schedule, identifiers: identifiers) {
            try await center.add(request)
        }
    }

    static func removeNotifications(for action: HealthAction, profileID: UUID?) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: notificationIdentifiers(for: action, schedule: nil, profileID: profileID)
        )
    }

    static func upsertCalendarEvent(
        for action: HealthAction,
        schedule: HealthActionSchedule,
        existingIdentifier: String?
    ) async throws -> String? {
        let store = EKEventStore()
        let granted = try await requestCalendarAccess(store: store)
        guard granted else {
            throw SchedulerError.calendarDenied
        }

        if let existingIdentifier,
           let existing = store.event(withIdentifier: existingIdentifier) {
            try? store.remove(existing, span: .futureEvents, commit: false)
        }

        let event = EKEvent(eventStore: store)
        event.title = action.title
        event.notes = ([action.summary] + action.steps).joined(separator: "\n")
        event.calendar = store.defaultCalendarForNewEvents
        event.startDate = schedule.date
        event.endDate = schedule.date.addingTimeInterval(TimeInterval(max(action.durationMinutes, 1) * 60))

        if let recurrence = recurrenceRule(for: schedule) {
            event.recurrenceRules = [recurrence]
        }

        try store.save(event, span: .futureEvents)
        return event.eventIdentifier
    }

    static func removeCalendarEvent(identifier: String?) async {
        guard let identifier else { return }
        let store = EKEventStore()
        if let event = store.event(withIdentifier: identifier) {
            try? store.remove(event, span: .futureEvents)
        }
    }

    private static func requestNotificationAccess(center: UNUserNotificationCenter) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private static func requestCalendarAccess(store: EKEventStore) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            if #available(iOS 17.0, *) {
                store.requestFullAccessToEvents { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            } else {
                store.requestAccess(to: .event) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    private static func notificationIdentifiers(
        for action: HealthAction,
        schedule: HealthActionSchedule?,
        profileID: UUID?
    ) -> [String] {
        let prefix = "eir.action.\(profileID?.uuidString ?? "global").\(action.id)"
        switch schedule?.cadence {
        case .weekdays:
            return (2 ... 6).map { "\(prefix).\($0)" }
        default:
            return ["\(prefix).default"]
        }
    }

    private static func buildNotificationRequests(
        for action: HealthAction,
        schedule: HealthActionSchedule,
        identifiers: [String]
    ) -> [UNNotificationRequest] {
        let content = UNMutableNotificationContent()
        content.title = action.title
        content.body = action.summary
        content.sound = .default

        let calendar = Calendar.current

        switch schedule.cadence {
        case .once:
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: schedule.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            return [UNNotificationRequest(identifier: identifiers[0], content: content, trigger: trigger)]
        case .daily:
            let components = calendar.dateComponents([.hour, .minute], from: schedule.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            return [UNNotificationRequest(identifier: identifiers[0], content: content, trigger: trigger)]
        case .weekdays:
            let hm = calendar.dateComponents([.hour, .minute], from: schedule.date)
            return [2, 3, 4, 5, 6].enumerated().map { offset, weekday in
                var components = DateComponents()
                components.weekday = weekday
                components.hour = hm.hour
                components.minute = hm.minute
                return UNNotificationRequest(
                    identifier: identifiers[offset],
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                )
            }
        case .weekly:
            var components = calendar.dateComponents([.weekday, .hour, .minute], from: schedule.date)
            if components.weekday == nil {
                components.weekday = calendar.component(.weekday, from: schedule.date)
            }
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            return [UNNotificationRequest(identifier: identifiers[0], content: content, trigger: trigger)]
        }
    }

    private static func recurrenceRule(for schedule: HealthActionSchedule) -> EKRecurrenceRule? {
        let calendar = Calendar.current
        switch schedule.cadence {
        case .once:
            return nil
        case .daily:
            return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        case .weekdays:
            let weekdays: [EKRecurrenceDayOfWeek] = [.init(.monday), .init(.tuesday), .init(.wednesday), .init(.thursday), .init(.friday)]
            return EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                daysOfTheWeek: weekdays,
                daysOfTheMonth: nil,
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: nil
            )
        case .weekly:
            let weekday = calendar.component(.weekday, from: schedule.date)
            let mapped = ekWeekday(from: weekday)
            return EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                daysOfTheWeek: [.init(mapped)],
                daysOfTheMonth: nil,
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: nil
            )
        }
    }

    private static func ekWeekday(from calendarWeekday: Int) -> EKWeekday {
        switch calendarWeekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        default: return .saturday
        }
    }

    enum SchedulerError: LocalizedError {
        case notificationsDenied
        case calendarDenied

        var errorDescription: String? {
            switch self {
            case .notificationsDenied:
                return "Notifications are not enabled for Eir yet."
            case .calendarDenied:
                return "Calendar access is not enabled for Eir yet."
            }
        }
    }
}
