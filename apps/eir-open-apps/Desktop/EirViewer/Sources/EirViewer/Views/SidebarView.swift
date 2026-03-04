import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var documentVM: DocumentViewModel
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var chatThreadStore: ChatThreadStore
    @EnvironmentObject var chatVM: ChatViewModel
    @Binding var selectedTab: NavTab

    @State private var showingShareToiPhone = false
    @State private var renamingProfileID: UUID?
    @State private var renameText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - People Section
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("People")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textSecondary)
                        .textCase(.uppercase)

                    Spacer()

                    Button {
                        NotificationCenter.default.post(name: .showAddPersonSheet, object: nil)
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 4)

                ForEach(profileStore.profiles) { profile in
                    PersonRow(
                        profile: profile,
                        isSelected: profile.id == profileStore.selectedProfileID
                    )
                    .onTapGesture {
                        profileStore.selectProfile(profile.id)
                    }
                    .contextMenu {
                        Button("Rename...") {
                            renameText = profile.displayName
                            renamingProfileID = profile.id
                        }
                        Divider()
                        Button("Remove", role: .destructive) {
                            profileStore.removeProfile(profile.id)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }

            // MARK: - Active Profile Info
            if let profile = profileStore.selectedProfile {
                Divider()
                    .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 4) {
                    if let pnr = profile.personalNumber {
                        Label(pnr, systemImage: "person.text.rectangle")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    if let dob = profile.birthDate {
                        Label("Born: \(dob)", systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.horizontal)
            }

            Divider()
                .padding(.vertical, 8)

            // MARK: - Navigation
            VStack(spacing: 2) {
                ForEach(NavTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .frame(width: 20)
                            Text(tab.rawValue)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            selectedTab == tab
                                ? AppColors.primary.opacity(0.12)
                                : Color.clear
                        )
                        .foregroundColor(
                            selectedTab == tab
                                ? AppColors.primary
                                : AppColors.text
                        )
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)

            // MARK: - Conversations (when Chat tab active)
            if selectedTab == .chat {
                Divider()
                    .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Conversations")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textSecondary)
                            .textCase(.uppercase)

                        Spacer()

                        Button {
                            if let profileID = profileStore.selectedProfileID {
                                chatVM.newConversation(
                                    chatThreadStore: chatThreadStore,
                                    profileID: profileID
                                )
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .help("New conversation")
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 2)

                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(chatThreadStore.threads) { thread in
                                ThreadRow(
                                    thread: thread,
                                    isSelected: thread.id == chatThreadStore.selectedThreadID
                                )
                                .onTapGesture {
                                    chatThreadStore.selectThread(thread.id)
                                }
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        chatThreadStore.deleteThread(thread.id)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
            }

            Spacer()

            // MARK: - Export Info
            if let info = documentVM.document?.metadata.exportInfo {
                VStack(alignment: .leading, spacing: 4) {
                    if let total = info.totalEntries {
                        Label("\(total) entries", systemImage: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    if let range = info.dateRange {
                        Label(
                            "\(range.start ?? "?") – \(range.end ?? "?")",
                            systemImage: "calendar"
                        )
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding()
            }

            Divider()

            if profileStore.selectedProfile != nil {
                Button {
                    showingShareToiPhone = true
                } label: {
                    Label("Share to iPhone", systemImage: "iphone.and.arrow.left.and.arrow.right")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            Button {
                NotificationCenter.default.post(name: .showAddPersonSheet, object: nil)
            } label: {
                Label("Add Person...", systemImage: "person.badge.plus")
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showingShareToiPhone) {
            ShareToiPhoneView()
        }
        .frame(minWidth: 200)
        .alert("Rename Person", isPresented: Binding(
            get: { renamingProfileID != nil },
            set: { if !$0 { renamingProfileID = nil } }
        )) {
            TextField("Display name", text: $renameText)
            Button("Cancel", role: .cancel) {
                renamingProfileID = nil
            }
            Button("Rename") {
                if let id = renamingProfileID {
                    profileStore.renameProfile(id, to: renameText)
                }
                renamingProfileID = nil
            }
        } message: {
            Text("Enter a new display name for this person.")
        }
    }
}

// MARK: - Thread Row

private struct ThreadRow: View {
    let thread: ChatThread
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(thread.title)
                    .font(.callout)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(AppColors.text)
                    .lineLimit(1)

                Text(formattedDate)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? AppColors.primarySoft : Color.clear)
        .cornerRadius(6)
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: thread.updatedAt, relativeTo: Date())
    }
}
