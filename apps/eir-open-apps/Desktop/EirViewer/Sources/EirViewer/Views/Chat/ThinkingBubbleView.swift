import SwiftUI

struct ThinkingBubbleView: View {
    var agentName: String?
    var toolNames: [String]

    @State private var dotCount = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    private var toolLabel: String {
        guard let name = toolNames.first else { return "Thinking" }
        switch name {
        case "search_records": return "Searching records"
        case "get_record_detail": return "Reading record"
        case "summarize_health": return "Summarizing"
        case "find_clinics": return "Finding clinics"
        case "update_memory": return "Saving to memory"
        case "name_agent": return "Setting name"
        case "update_user_profile": return "Updating profile"
        default: return "Working"
        }
    }

    private var dots: String {
        String(repeating: ".", count: (dotCount % 3) + 1)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(agentName ?? "Assistant")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)

                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)

                    Text("\(toolLabel)\(dots)")
                        .font(.callout)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppColors.card)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColors.border, lineWidth: 0.5)
                )
            }
            Spacer()
        }
        .onReceive(timer) { _ in
            dotCount += 1
        }
    }
}
