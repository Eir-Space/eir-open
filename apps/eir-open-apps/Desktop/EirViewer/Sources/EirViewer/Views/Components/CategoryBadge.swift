import SwiftUI

struct CategoryBadge: View {
    let category: String

    var body: some View {
        Text(category)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(AppColors.categoryColor(for: category).opacity(0.12))
            .foregroundColor(AppColors.categoryColor(for: category))
            .clipShape(Capsule())
    }
}
