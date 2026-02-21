import SwiftUI

struct AgentConfigCard: View {
    let title: String
    let defaultContent: String
    @Binding var content: String
    @State private var isExpanded = false
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 16)

                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.text)

                    Spacer()

                    if !isExpanded {
                        // Preview first line
                        Text(previewText)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                            .frame(maxWidth: 200, alignment: .trailing)
                    }
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .padding(.vertical, 4)

                TextEditor(text: $content)
                    .font(.system(.caption, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 150, maxHeight: 300)
                    .padding(8)
                    .background(AppColors.background)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppColors.border, lineWidth: 1)
                    )

                HStack {
                    Spacer()
                    Button("Reset to Default") {
                        content = defaultContent
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.red)
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 4)
    }

    private var previewText: String {
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let firstContent = lines.first(where: { !$0.hasPrefix("#") }) ?? lines.first ?? ""
        return String(firstContent.prefix(50))
    }
}
