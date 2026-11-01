import Foundation
import XCTest
@testable import GitBookReaderCore

/// Unit tests cho phần logic thuần của app: parse URL GitHub, dựng cây
/// sidebar, xử lý Markdown và cache offline.
///
/// Toàn bộ dữ liệu network được thay bằng fixture (không gọi mạng).
@MainActor
final class GitBookReaderCoreTests: XCTestCase {

    // MARK: - extractOwnerAndRepo

    func testExtractOwnerAndRepoFullHTTPSUrl() {
        let result = GitHubService.extractOwnerAndRepo(from: "https://github.com/apple/swift")
        XCTAssertEqual(result?.0, "apple")
        XCTAssertEqual(result?.1, "swift")
    }

    func testExtractOwnerAndRepoBareHost() {
        let result = GitHubService.extractOwnerAndRepo(from: "github.com/apple/swift")
        XCTAssertEqual(result?.0, "apple")
        XCTAssertEqual(result?.1, "swift")
    }

    func testExtractOwnerAndRepoWwwHost() {
        let result = GitHubService.extractOwnerAndRepo(from: "www.github.com/apple/swift")
        XCTAssertEqual(result?.0, "apple")
        XCTAssertEqual(result?.1, "swift")
    }

    func testExtractOwnerAndRepoStripsGitSuffix() {
        let result = GitHubService.extractOwnerAndRepo(from: "https://github.com/apple/swift.git")
        XCTAssertEqual(result?.0, "apple")
        XCTAssertEqual(result?.1, "swift")
    }

    func testExtractOwnerAndRepoTrailingSlashAndWhitespace() {
        let result = GitHubService.extractOwnerAndRepo(from: "  https://github.com/apple/swift/ \n")
        XCTAssertEqual(result?.0, "apple")
        XCTAssertEqual(result?.1, "swift")
    }

    func testExtractOwnerAndRepoExtraPathSegments() {
        let result = GitHubService.extractOwnerAndRepo(from: "https://github.com/apple/swift/tree/main/Docs")
        XCTAssertEqual(result?.0, "apple")
        XCTAssertEqual(result?.1, "swift")
    }

    func testExtractOwnerAndRepoRejectsNonGitHub() {
        XCTAssertNil(GitHubService.extractOwnerAndRepo(from: "https://gitlab.com/apple/swift"))
        XCTAssertNil(GitHubService.extractOwnerAndRepo(from: "not a url"))
    }

    func testExtractOwnerAndRepoRejectsMissingRepo() {
        XCTAssertNil(GitHubService.extractOwnerAndRepo(from: "https://github.com/apple"))
        XCTAssertNil(GitHubService.extractOwnerAndRepo(from: "https://github.com/apple/"))
    }

    // MARK: - buildTree

    private func item(_ path: String, type: String) -> GitTreeItem {
        GitTreeItem(path: path, mode: "100644", type: type, sha: "sha-\(path)", size: 10, url: "https://example.com")
    }

    func testBuildTreeKeepsDirectoriesAndMarkdownOnly() throws {
        let nodes = GitHubService.buildTree(
            from: [
                item("README.md", type: "blob"),
                item("notes.txt", type: "blob"),
                item("docs", type: "tree"),
                item("docs/guide.md", type: "blob"),
                item("docs/img/logo.png", type: "blob"),
            ],
            owner: "apple",
            repo: "swift",
            branch: "main"
        )

        // notes.txt và logo.png bị lọc; thư mục `docs` có con nên được giữ.
        XCTAssertEqual(nodes.map(\.name), ["docs", "README.md"]) // folders first, A→Z

        let docs = try XCTUnwrap(nodes.first { $0.name == "docs" })
        XCTAssertEqual(docs.children?.map(\.name), ["guide.md"])
    }

    func testBuildTreePrunesEmptyDirectories() {
        let nodes = GitHubService.buildTree(
            from: [
                item("README.md", type: "blob"),
                item("empty-dir", type: "tree"),
                item("empty-dir/inner", type: "tree"),
                item("only-images", type: "tree"),
                item("only-images/a.png", type: "blob"),
            ],
            owner: "a",
            repo: "b",
            branch: "main"
        )

        XCTAssertEqual(nodes.map(\.name), ["README.md"])
    }

    func testBuildTreeSetsParentForBreadcrumb() throws {
        let nodes = GitHubService.buildTree(
            from: [
                item("docs", type: "tree"),
                item("docs/deep", type: "tree"),
                item("docs/deep/file.md", type: "blob"),
            ],
            owner: "a",
            repo: "b",
            branch: "main"
        )

        let file = try XCTUnwrap(nodes.first?.children?.first?.children?.first)
        XCTAssertEqual(file.breadcrumbPath.map(\.name), ["docs", "deep", "file.md"])
    }

    func testBuildTreeBuildsEncodedDownloadUrl() throws {
        let nodes = GitHubService.buildTree(
            from: [
                item("docs", type: "tree"),
                item("docs/my file.md", type: "blob"),
            ],
            owner: "a",
            repo: "b",
            branch: "main"
        )

        let file = try XCTUnwrap(nodes.first?.children?.first)
        XCTAssertEqual(
            file.downloadUrl?.absoluteString,
            "https://raw.githubusercontent.com/a/b/main/docs/my%20file.md"
        )
    }

    // MARK: - MarkdownContentProcessor

    func testProcessPreservesEscapedNewlineInsideCodeBlock() {
        let content = """
        Before with escaped \\n newline.

        ```swift
        let s = "line1\\nline2"
        print("\\tTab inside code")
        ```
        """

        let processed = MarkdownContentProcessor.process(content)

        // Toàn bộ code block phải được giữ nguyên verbatim.
        XCTAssertTrue(processed.contains("let s = \"line1\\nline2\""))
        XCTAssertTrue(processed.contains("print(\"\\tTab inside code\")"))
    }

    func testProcessStillConvertsEscapedNewlinesOutsideCode() {
        let processed = MarkdownContentProcessor.process("Paragraph one.\\nParagraph two.")
        XCTAssertTrue(processed.contains("Paragraph one.\nParagraph two."))
    }

    func testProcessAddsBlankLineBeforeHeadingsOutsideCode() {
        let processed = MarkdownContentProcessor.process("Intro text\n## Heading")
        XCTAssertTrue(processed.contains("Intro text\n\n## Heading"))
    }

    func testProcessLeavesUnterminatedCodeBlockVerbatim() {
        let content = "Text\\nbefore\n```swift\nlet s = \"a\\nb\""
        let processed = MarkdownContentProcessor.process(content)

        XCTAssertTrue(processed.contains("Text\nbefore"))
        XCTAssertTrue(processed.contains("let s = \"a\\nb\""))
    }

    // MARK: - OfflineCacheStore

    private var tempRoot: URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("OfflineCacheStoreTests-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testTreeRoundTrip() throws {
        let store = OfflineCacheStore(rootDirectory: tempRoot)
        let items = [item("README.md", type: "blob")]
        let truncated = true

        store.saveTree(owner: "a", repo: "b", branch: "main", items: items, truncated: truncated)
        let loaded = try XCTUnwrap(store.loadTree(owner: "a", repo: "b"))

        XCTAssertEqual(loaded.branch, "main")
        XCTAssertEqual(loaded.truncated, truncated)
        XCTAssertEqual(loaded.items.map(\.path), ["README.md"])
    }

    func testFileRoundTrip() throws {
        let store = OfflineCacheStore(rootDirectory: tempRoot)
        let url = URL(string: "https://raw.githubusercontent.com/a/b/main/README.md")!

        store.saveFile(downloadUrl: url, content: "# Hello")
        XCTAssertEqual(store.loadFile(downloadUrl: url), "# Hello")
    }

    func testFileNamesDoNotCollideOnPunctuation() throws {
        let store = OfflineCacheStore(rootDirectory: tempRoot)
        let urlA = URL(string: "https://raw.githubusercontent.com/a/b/main/my-file.md")!
        let urlB = URL(string: "https://raw.githubusercontent.com/a/b/main/my_file.md")!

        store.saveFile(downloadUrl: urlA, content: "dashed")
        store.saveFile(downloadUrl: urlB, content: "underscored")

        XCTAssertEqual(store.loadFile(downloadUrl: urlA), "dashed")
        XCTAssertEqual(store.loadFile(downloadUrl: urlB), "underscored")
    }

    func testClearAllRemovesEverything() throws {
        let root = tempRoot
        let store = OfflineCacheStore(rootDirectory: root)
        store.saveTree(owner: "a", repo: "b", branch: "main", items: [], truncated: false)
        store.saveFile(
            downloadUrl: URL(string: "https://raw.githubusercontent.com/a/b/main/x.md")!,
            content: "x"
        )

        store.clearAll()

        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }
}
