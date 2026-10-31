import SwiftUI

// MARK: - RecentHistorySheet

struct RecentHistorySheet: View {
    let recentRepos: [String]
    let onRemoveRecent: (String) -> Void
    let onSelectRecent: (String) -> Void
    let onClearAll: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showClearConfirmation = false

    // MARK: - Computed Properties

    private var filteredRepos: [String] {
        if searchText.isEmpty {
            return recentRepos
        }
        return recentRepos.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if filteredRepos.isEmpty {
                    emptyState
                } else {
                    repoList
                }
            }
            .navigationTitle(String(localized: "history.title"))
            .searchable(text: $searchText, prompt: String(localized: "history.searchPrompt"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .destructiveAction) {
                    if !recentRepos.isEmpty {
                        Button(String(localized: "history.clearAll"), role: .destructive) {
                            showClearConfirmation = true
                        }
                        .confirmationDialog(
                            String(localized: "history.clearConfirmation.title"),
                            isPresented: $showClearConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button(String(localized: "history.clearAll"), role: .destructive) {
                                onClearAll()
                            }
                            Button(String(localized: "common.cancel"), role: .cancel) {}
                        } message: {
                            Text(String(localized: "history.clearConfirmation.message"))
                        }
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 400)
        #endif
    }

    // MARK: - Subviews

    private var emptyState: some View {
        EmptyStateView(
            icon: "clock.arrow.circlepath",
            title: String(localized: "history.empty"),
            message: String(localized: "history.emptyMessage")
        )
    }

    private var repoList: some View {
        List {
            ForEach(filteredRepos, id: \.self) { repo in
                repoRow(for: repo)
            }
            .onDelete { indexSet in
                let reposToDelete = indexSet.map { filteredRepos[$0] }
                reposToDelete.forEach { onRemoveRecent($0) }
            }
        }
    }

    private func repoRow(for repo: String) -> some View {
        Button(action: { onSelectRecent(repo) }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(URL(string: repo)?.lastPathComponent ?? repo)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(repo)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityLabel(repo)
    }
}
