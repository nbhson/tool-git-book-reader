// swift-tools-version:6.0
import PackageDescription

/// SwiftPM package dùng **chỉ để chạy unit-test** cho phần logic thuần của app
/// (parse URL, buildTree, MarkdownContentProcessor, OfflineCacheStore).
///
/// Target trỏ trực tiếp vào các file source thật của app trong `GitBookReader/`
/// (không copy), nên test luôn chạy đúng code đang ship. Chỉ những file không
/// phụ thuộc SwiftUI/MarkdownUI được biên dịch; toàn bộ app vẫn build bằng
/// Xcode project như cũ — package này KHÔNG thay thế target app.
///
/// Chạy: `swift test`
let package = Package(
    name: "GitBookReaderCore",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "GitBookReaderCore", targets: ["GitBookReaderCore"])
    ],
    targets: [
        .target(
            name: "GitBookReaderCore",
            path: "GitBookReader",
            sources: [
                "Extensions/MarkdownContentProcessor.swift",
                "Models/GitHubError.swift",
                "Models/GitHubModels.swift",
                "Services/GitHubService.swift",
                "Services/OfflineCacheStore.swift",
            ]
        ),
        .testTarget(
            name: "GitBookReaderCoreTests",
            dependencies: ["GitBookReaderCore"],
            path: "Tests/GitBookReaderCoreTests"
        ),
    ]
)
