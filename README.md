# GitBookReader

GitBookReader is a cross-platform SwiftUI app for browsing and reading Markdown documentation directly from GitHub repositories.

## Features

- 📖 Browse any GitHub repository as a book (folders and Markdown files)
- 🌓 Multiple reading themes (System / Light / Dark / Sepia)
- 🔠 Adjustable font size
- 🔊 Built-in text-to-speech (Vietnamese voice preferred)
- 🕘 Recent repository history
- 🔍 Full-text file search with live filtering
- 🧭 Breadcrumb navigation and folder grid view
- 🌐 Multi-language support (English & Vietnamese)
- ♿ Accessibility support (VoiceOver labels, Dynamic Type)

## Requirements

- Xcode 15+ (Swift 5.9+)
- macOS 26.2+ / iOS 26.2+ / visionOS 26.2+
- Internet connection (GitHub API)

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| [MarkdownUI](https://github.com/gonzalezreal/MarkdownUI) | >= 2.4.1 | Markdown rendering |

Dependencies are managed via Swift Package Manager, which is already configured in `GitBookReader.xcodeproj`.

## Getting Started

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd tool-git-book-reader
   ```

2. Open the Xcode project:
   ```bash
   open GitBookReader.xcodeproj
   ```

3. Let Xcode resolve the Swift Package (MarkdownUI).

4. Press `Cmd + R` to build and run.

## Project Structure

```
GitBookReader/
├── GitBookReaderApp.swift     # App entry point
├── Models/
│   ├── BookSettings.swift     # Reading theme & font size preferences
│   ├── GitHubError.swift      # Custom error types
│   └── GitHubModels.swift     # API response models & FileNode
├── Views/
│   ├── ContentView.swift      # Root split view (sidebar + detail)
│   ├── RepositoryHeaderView.swift # Search & recent repos header
│   ├── FileNodeRowView.swift  # Recursive file tree row
│   ├── BreadcrumbView.swift   # Path navigation bar
│   ├── FolderGridView.swift   # Folder/file grid display
│   ├── MarkdownReaderView.swift # Markdown reader with TTS
│   ├── RecentHistorySheet.swift # Repository history modal
│   ├── LoadingView.swift      # Loading indicator
│   ├── ErrorView.swift        # Error display with retry
│   └── EmptyStateView.swift   # Empty state placeholder
├── Services/
│   ├── GitHubService.swift    # GitHub API client with caching & retry
│   └── SpeechManager.swift    # Text-to-speech manager
├── Extensions/
│   ├── Color+Adaptive.swift   # Cross-platform color helpers
│   ├── FileNode+Tree.swift    # Tree search & display helpers
│   └── MarkdownContentProcessor.swift # Markdown pre-processing
└── Resources/
    └── Localizable.xcstrings  # English & Vietnamese strings
```

## Architecture

- **MVVM-inspired**: `GitHubService` acts as the model layer (fetching + caching), views are pure UI.
- **`@MainActor`**: Services are marked `@MainActor` for SwiftUI safety.
- **Error handling**: Typed `GitHubError` enum with localized descriptions.
- **Caching**: `NSCache` for fetched Markdown files (memory-only, auto-evicts).
- **Retry logic**: Automatic retry (up to 3 attempts) for transient network failures.

## Contributing

1. Create a feature branch from `main`.
2. Make your changes with clear, atomic commits.
3. Ensure the app builds without warnings on both macOS and iOS targets.
4. Submit a pull request.

## License

This project is licensed under the MIT License.
