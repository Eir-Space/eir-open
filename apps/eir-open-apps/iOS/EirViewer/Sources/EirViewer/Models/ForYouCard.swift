import Foundation
import SwiftUI

enum ForYouCardKind: String, Hashable {
    case action
    case meditation
    case quiz
    case reading
    case reflection
    case soundscape

    var label: String {
        switch self {
        case .action: return "Action"
        case .meditation: return "Meditation"
        case .quiz: return "Quiz"
        case .reading: return "Read"
        case .reflection: return "Reflect"
        case .soundscape: return "Soundscape"
        }
    }
}

enum ForYouCardTheme: String, CaseIterable, Hashable {
    case ember
    case tide
    case aurora
    case coral
    case velvet
    case meadow

    var gradient: [Color] {
        switch self {
        case .ember:
            return [Color(hex: "23130F"), Color(hex: "7C3A2D"), Color(hex: "F5B27C")]
        case .tide:
            return [Color(hex: "0C1B2D"), Color(hex: "175676"), Color(hex: "8FE3F7")]
        case .aurora:
            return [Color(hex: "16132E"), Color(hex: "5F4BB6"), Color(hex: "E7D7FF")]
        case .coral:
            return [Color(hex: "2C1618"), Color(hex: "A44A3F"), Color(hex: "FFD7C9")]
        case .velvet:
            return [Color(hex: "171224"), Color(hex: "6441A5"), Color(hex: "E9D5FF")]
        case .meadow:
            return [Color(hex: "102116"), Color(hex: "3C7A57"), Color(hex: "D4F4DD")]
        }
    }

    var accent: Color {
        switch self {
        case .ember: return Color(hex: "F5B27C")
        case .tide: return Color(hex: "8FE3F7")
        case .aurora: return Color(hex: "DAB8FF")
        case .coral: return Color(hex: "FFC1AD")
        case .velvet: return Color(hex: "F1D7FF")
        case .meadow: return Color(hex: "C4F3D3")
        }
    }

    var textColor: Color {
        Color.white
    }

    var deepTone: Color {
        switch self {
        case .ember: return Color(hex: "7C3A2D")
        case .tide: return Color(hex: "175676")
        case .aurora: return Color(hex: "5F4BB6")
        case .coral: return Color(hex: "A44A3F")
        case .velvet: return Color(hex: "6441A5")
        case .meadow: return Color(hex: "3C7A57")
        }
    }

    static func generatedTheme(for kind: ForYouCardKind, offset: Int) -> ForYouCardTheme {
        let palette: [ForYouCardTheme]
        switch kind {
        case .action:
            palette = [.ember, .meadow, .coral]
        case .meditation, .soundscape:
            palette = [.tide, .meadow, .aurora]
        case .quiz:
            palette = [.aurora, .velvet, .ember]
        case .reading:
            palette = [.coral, .ember, .velvet]
        case .reflection:
            palette = [.velvet, .aurora, .tide]
        }
        return palette[offset % palette.count]
    }
}

struct ForYouQuizOption: Identifiable, Hashable {
    let id: String
    let title: String
    let feedback: String
    let isCorrect: Bool
}

struct ForYouQuiz: Hashable {
    let question: String
    let options: [ForYouQuizOption]
    let successTitle: String
}

struct ForYouReading: Hashable {
    let kicker: String
    let paragraphs: [String]
}

struct ForYouBreathing: Hashable {
    let inhaleSeconds: Int
    let exhaleSeconds: Int
    let rounds: Int

    var totalSeconds: Int {
        (inhaleSeconds + exhaleSeconds) * rounds
    }
}

struct ForYouReflection: Hashable {
    let prompt: String
    let placeholder: String
}

struct ForYouCard: Identifiable, Hashable {
    let id: String
    let sortOrder: Int
    let kind: ForYouCardKind
    let theme: ForYouCardTheme
    let eyebrow: String
    let title: String
    let summary: String
    let durationLabel: String?
    let symbolName: String
    let action: HealthAction?
    let quiz: ForYouQuiz?
    let reading: ForYouReading?
    let reflection: ForYouReflection?
    let breathing: ForYouBreathing?
}
