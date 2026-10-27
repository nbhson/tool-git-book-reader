import SwiftUI

// MARK: - RepositoryHeaderView

struct RepositoryHeaderView: View {
    @Binding var urlString: String
    @Binding var isSearchRepoVisible: Bool
    let recentRepos: [String]
    let onRemoveRecent: (String) -> Void
    let onLoadRepository: (String) -> Void
    let onSelectRecent: (String) -> Void

    @State private var showAllHistory = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toggleButton

            if isSearchRepoVisible {
                searchSection
            }
        }
        .sheet(isPresented: $showAllHistory) {
            RecentHistorySheet(
                recentRepos: recentRepos,
                onRemoveRecent: onRemoveRecent,
                onSelectRecent: { repo in
                    onSelectRecent(repo)
                    showAllHistory = false
                },
                onClearAll: {
                    recentRepos.forEach { onRemoveRecent($0) }
                }
            )
        }
    }

    // MARK: - Subviews

    private var toggleButton: some View {
        Button(action: {
            withAnimation {
                isSearchRepoVisible.toggle()
            }
        }) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)

                Text(String(localized: "sidebar.searchAndLoad"))
                    .font(.headline)

                Spacer()

                Image(systemName: isSearchRepoVisible ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "sidebar.searchAndLoad"))
        .accessibilityHint(isSearchRepoVisible
            ? String(localized: "accessibility.collapseSearch")
            : String(localized: "accessibility.expandSearch"))
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !recentRepos.isEmpty {
                recentReposSection
            }

            urlInputField
            loadButton
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    private var recentReposSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "sidebar.recentRepos"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if recentRepos.count > 5 {
                    Button(String(localized: "sidebar.viewAll \(recentRepos.count)")) {
                        showAllHistory = true
                    }
                    .font(.caption)
                    .buttonStyle(.link)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recentRepos.prefix(5), id: \.self) { repoUrl in
                        RecentRepoChip(
                            repoUrl: repoUrl,
                            onSelect: { onSelectRecent(repoUrl) },
                            onRemove: { onRemoveRecent(repoUrl) }
                        )
                    }
                }
            }
        }
    }

    private var urlInputField: some View {
        HStack {
            Image(systemName: "link")
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            TextField(String(localized: "sidebar.urlPlaceholder"), text: $urlString)
                .textFieldStyle(.plain)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .onSubmit {
                    onLoadRepository(urlString)
                }
                .accessibilityLabel(String(localized: "accessibility.urlInput"))

            if !urlString.isEmpty {
                Button(action: { urlString = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "accessibility.clearInput"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.adaptiveBackground)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
    }

    private var loadButton: some View {
        Button(action: {
            onLoadRepository(urlString)
        }) {
            Text(String(localized: "sidebar.loadRepository"))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(Color.accentColor)
        .foregroundColor(.white)
        .clipShape(Capsule())
        .accessibilityLabel(String(localized: "sidebar.loadRepository"))
    }
}

// MARK: - RecentRepoChip

private struct RecentRepoChip: View {
    let repoUrl: String
    let onSelect: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onSelect) {
                Text(URL(string: repoUrl)?.lastPathComponent ?? repoUrl)
                    .font(.caption)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "accessibility.removeRecent"))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview

