import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    // MARK: - State
    @StateObject private var service = GitHubService()
    @State private var urlString: String = "https://github.com/nbhson"
    @State private var searchText: String = ""
    @State private var isSearchRepoVisible = false
    @State private var selectedFile: FileNode?

    @EnvironmentObject private var settings: BookSettings

    // MARK: - Computed Properties

    private var filteredNodes: [FileNode] {
        FileNode.filterTree(nodes: service.rootNodes, searchText: searchText)
    }

    private var isLoading: Bool { service.isLoading }
    private var errorMessage: String? { service.errorMessage }
    private var rootNodes: [FileNode] { service.rootNodes }

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            sidebarView
                .navigationTitle("GitBook")
                .toolbar { toolbarContent }
        } detail: {
            detailView
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(spacing: 0) {
            RepositoryHeaderView(
                urlString: $urlString,
                isSearchRepoVisible: $isSearchRepoVisible,
                recentRepos: service.recentRepos,
                onRemoveRecent: { service.removeFromHistory($0) },
                onLoadRepository: { url in
                    selectedFile = nil
                    service.loadRepository(urlString: url)
                },
                onSelectRecent: { repo in
                    urlString = repo
                    selectedFile = nil
                    service.loadRepository(urlString: repo)
                }
            )

            Divider()

            sidebarListView
        }
    }

    private var sidebarListView: some View {
        List(selection: $selectedFile) {
            if isLoading {
                LoadingView(message: String(localized: "loading.repository"))
                    .listRowBackground(Color.clear)
            } else if let error = errorMessage {
                ErrorView(
                    title: String(localized: "error.loadFailed"),
                    message: error,
                    retryAction: { service.loadRepository(urlString: urlString) }
                )
                .listRowBackground(Color.clear)
            } else if filteredNodes.isEmpty && !rootNodes.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: String(localized: "search.noResults"),
                    message: String(localized: "search.noResultsMessage")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredNodes) { node in
                    FileNodeRowView(node: node, selectedFile: $selectedFile)
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, prompt: String(localized: "search.placeholder"))
        .refreshable {
            service.refreshRepository(urlString: urlString)
        }
    }

    // MARK: - Detail View

    private var detailView: some View {
        VStack(spacing: 0) {
            BreadcrumbView(
                selectedFile: $selectedFile,
                rootName: urlString.components(separatedBy: "/").last ?? "Repo"
            )

            Divider()

            contentArea
        }
        .navigationTitle(selectedFile?.name ?? String(localized: "common.home"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private var contentArea: some View {
        if let file = selectedFile {
            if file.isDirectory {
                FolderGridView(nodes: file.children ?? [], selectedFile: $selectedFile)
            } else {
                MarkdownReaderView(file: file)
            }
        } else if rootNodes.isEmpty {
            EmptyStateView(
                icon: "folder.badge.magnifyingglass",
                title: String(localized: "empty.enterURL"),
                message: String(localized: "empty.enterURLMessage")
            )
        } else {
            FolderGridView(nodes: rootNodes, selectedFile: $selectedFile)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            themeToggleButton
        }

        ToolbarItem(placement: .automatic) {
            refreshButton
        }
    }

    private var themeToggleButton: some View {
        Button {
            withAnimation {
                settings.readingTheme = settings.readingTheme == .dark ? .light : .dark
            }
        } label: {
            Image(systemName: settings.readingTheme == .dark ? "moon.fill" : "sun.max.fill")
                .foregroundColor(settings.readingTheme == .dark ? .blue : .orange)
        }
        .help(String(localized: "toolbar.toggleTheme"))
    }

    private var refreshButton: some View {
        Button {
            service.refreshRepository(urlString: urlString)
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(urlString.isEmpty)
        .help(String(localized: "toolbar.refresh"))
    }
}

// MARK: - Preview

