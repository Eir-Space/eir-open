import Foundation
import SwiftUI

enum HealthActionCategory: String, Codable, CaseIterable, Identifiable {
    case movement
    case breath
    case recovery
    case hydration
    case focus
    case sleep
    case planning
    case nutrition

    var id: String { rawValue }

    var title: String {
        switch self {
        case .movement: return "Movement"
        case .breath: return "Breathing"
        case .recovery: return "Recovery"
        case .hydration: return "Hydration"
        case .focus: return "Focus"
        case .sleep: return "Sleep"
        case .planning: return "Planning"
        case .nutrition: return "Nutrition"
        }
    }

    var systemImage: String {
        switch self {
        case .movement: return "figure.walk"
        case .breath: return "wind"
        case .recovery: return "figure.cooldown"
        case .hydration: return "drop.fill"
        case .focus: return "brain.head.profile"
        case .sleep: return "moon.stars.fill"
        case .planning: return "calendar.badge.clock"
        case .nutrition: return "leaf.fill"
        }
    }

    var tint: Color {
        switch self {
        case .movement: return Color(hex: "197278")
        case .breath: return Color(hex: "386FA4")
        case .recovery: return Color(hex: "7C5CFC")
        case .hydration: return Color(hex: "2A9D8F")
        case .focus: return Color(hex: "A44A3F")
        case .sleep: return Color(hex: "355070")
        case .planning: return Color(hex: "8D6A9F")
        case .nutrition: return Color(hex: "5F8D4E")
        }
    }

    var softTint: Color {
        tint.opacity(0.14)
    }
}

enum HealthActionSource: String, Codable {
    case records
    case starter

    var title: String {
        switch self {
        case .records: return "From your health story"
        case .starter: return "Works even without records"
        }
    }
}

enum HealthActionCadence: String, Codable, CaseIterable, Identifiable {
    case once
    case daily
    case weekdays
    case weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .once: return "One time"
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .weekly: return "Weekly"
        }
    }
}

struct HealthAction: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let summary: String
    let insight: String
    let category: HealthActionCategory
    let durationMinutes: Int
    let benefits: [String]
    let steps: [String]
    let source: HealthActionSource
    let linkedEntryIDs: [String]

    var durationLabel: String {
        "\(durationMinutes) min"
    }
}

struct HealthActionSchedule: Codable, Hashable {
    var date: Date
    var cadence: HealthActionCadence
    var notificationsEnabled: Bool
    var calendarEnabled: Bool
    var calendarEventIdentifier: String?
}

struct HealthActionState: Codable, Hashable {
    var isPinned: Bool = false
    var completionDayStamps: [String] = []
    var schedule: HealthActionSchedule?
}
