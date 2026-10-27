import SwiftUI
import MarkdownUI

// MARK: - MarkdownReaderView

struct MarkdownReaderView: View {
    // MARK: - Properties
    let file: FileNode

    @StateObject private var service = GitHubService()
    @StateObject private var speechManager = SpeechManager()
    @State private var markdownText = ""
    @State private var loadAttempted = false

    @EnvironmentObject private var settings: BookSettings

    // MARK: - Body

    var body: some View {
        ZStack {
            settings.backgroundColor.ignoresSafeArea()

            contentArea
        }
        .navigationTitle(file.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarContent }
        .task(id: file.id) {
            await loadContent()
        }
        .onDisappear {
            speechManager.stop()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if service.isLoading {
                    LoadingView(message: String(localized: "loading.content"))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 50)
                } else if let error = service.errorMessage {
                    ErrorView(
                        title: String(localized: "error.loadFailed"),
                        message: error,
                        retryAction: {
                            Task { await loadContent() }
                        }
                    )
                } else if !markdownText.isEmpty {
                    markdownContent
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .refreshable {
            await loadContent(forceReload: true)
        }
    }

    private var markdownContent: some View {
        Markdown(markdownText)
            .markdownTheme(.gitHub)
            .padding()
            .textSelection(.enabled)
            .scaleEffect(settings.fontSizeMultiplier, anchor: .topLeading)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 16) {
                speechButton
                settingsMenu
            }
        }
    }

    private var speechButton: some View {
        Button {
            speechManager.toggleSpeech(text: markdownText)
        } label: {
            Image(systemName: speechManager.isSpeaking ? "speaker.wave.3.fill" : "speaker.slash.fill")
                .foregroundColor(speechManager.isSpeaking ? .accentColor : .primary)
        }
        .disabled(markdownText.isEmpty)
        .help(String(localized: "reader.speechToggle"))
        .accessibilityLabel(speechManager.isSpeaking
            ? String(localized: "accessibility.stopReading")
            : String(localized: "accessibility.startReading"))
    }

    private var settingsMenu: some View {
        Menu {
            fontSizeSection
            themeSection
        } label: {
            Image(systemName: "textformat.size")
        }
        .accessibilityLabel(String(localized: "accessibility.readerSettings"))
    }

    private var fontSizeSection: some View {
        Section(String(localized: "settings.fontSize")) {
            Button(String(localized: "settings.increaseFontSize")) {
                settings.fontSizeMultiplier = min(settings.fontSizeMultiplier + 0.2, 2.0)
            }
            Button(String(localized: "settings.decreaseFontSize")) {
                settings.fontSizeMultiplier = max(settings.fontSizeMultiplier - 0.2, 0.6)
            }
            Button(String(localized: "settings.resetFontSize")) {
                settings.fontSizeMultiplier = 1.0
            }
        }
    }

    private var themeSection: some View {
        Section(String(localized: "settings.theme")) {
            ForEach(BookSettings.Theme.allCases) { theme in
                Button {
                    settings.readingTheme = theme
                } label: {
                    HStack {
                        Text(theme.displayName)

                        if settings.readingTheme == theme {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadContent(forceReload: Bool = false) async {
        guard let url = file.downloadUrl else { return }

        if forceReload {
            service.clearCache()
        }

        service.isLoading = true
        service.errorMessage = nil

        do {
            let content = try await service.fetchRawContent(downloadUrl: url)
            let processed = MarkdownContentProcessor.process(content)
            markdownText = processed
            service.isLoading = false
        } catch {
            service.errorMessage = error.localizedDescription
            service.isLoading = false
        }
    }
}
