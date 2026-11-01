# Plan — tool-git-book-reader

macOS/iOS/visionOS app đọc GitBook (Swift/SwiftUI), Xcode project (MarkdownUI, deployment target 26.2).

## Baseline audit (00:44, 28-10-2026)
- ⚠️ **Không build được trong môi trường này**: máy chỉ có Command Line Tools, `xcodebuild` yêu cầu Xcode đầy đủ → chỉ review tĩnh được
- Cấu trúc: GitBookReader/ (App, Models, Views, Services, Extensions, Resources) + xcodeproj
- Đã có commit refactor gần đây: split god-view ContentView, i18n, error handling

## Audit lần 2 (31-10-2026)
- Vẫn không có Xcode đầy đủ → dùng `swiftc -typecheck` (CLT SDK) với stub MarkdownUI để kiểm tra type toàn bộ source: **pass, 0 lỗi 0 warning**
- Phát hiện & sửa **lỗi biên dịch**: `MarkdownReaderView` ghi vào `@Published private(set)` của `GitHubService` (5 lỗi)
- Phát hiện & sửa **lỗi điều hướng**: `FileNodeRowView` dùng `NavigationLink(value:)` nhưng không có `navigationDestination(for: FileNode.self)` → click file không có tác dụng
- Phát hiện & sửa **lỗi breadcrumb**: `pruneEmptyDirectories` không gán `parent` cho file ở thư mục con → breadcrumb thiếu đường dẫn
- Cải thiện: parse URL GitHub (www/scheme/.git/trailing slash), 403 → rateLimitExceeded khi fetch raw content, xoá code chết, doc comments, `displayName` nhất quán, dọn marker Preview rỗng

## Roadmap
### P0
- [x] Review tĩnh mã Swift: force unwrap, error handling, memory leak (closure retain), race condition
- [x] Rà các file lớn (god objects) còn sót — không còn, file lớn nhất ~330 dòng (GitHubService)
- [x] Thêm unit-test target (GitHubService URL parsing, buildTree, MarkdownContentProcessor) — SwiftPM package `Package.swift` + `Tests/`, 20 test pass (chạy được qua harness stub XCTest vì CLT này hỏng SwiftPM manifest; `swift test` cần Xcode/CLT lành)

### P1 (chất lượng)
- [x] Đối chiếu README với tính năng thực tế — đã cập nhật requirements/platforms, kiến trúc cache dùng chung, mục Known Limitations
- [x] Chuẩn hoá cấu trúc MVVM nếu phát hiện View chứa business logic — MarkdownReaderView đã tách trạng thái loading riêng, service được inject
- [x] Đối chiếu Localizable.xcstrings: kiểm tra đủ key en/vi (đã thêm 4 key `cache.*` cho banner offline/truncated)

### P2
- [x] Ghi chú build instructions (yêu cầu Xcode version) — README đã ghi rõ Xcode 26+, lưu ý CLT không build được

## Self-review log
- _0:44 (28-10-2026)_ Audit lần 1: không có toolchain build; chuyển sang review tĩnh.
- _(31-10-2026)_ Audit lần 2: type-check bằng swiftc + stub MarkdownUI pass; sửa 3 lỗi (biên dịch, NavigationLink, breadcrumb); refactor GitHubService; cập nhật README/plan.
- _(01-11-2026)_ Hoàn tất phiên gián đoạn: fix cleanMarkdownText giữ `-` trong từ khi TTS, `\n` escape không còn phá code block; thêm OfflineCacheStore (sửa 2 bug: thiếu tạo thư mục `files/`, collision tên file cache) + InfoBannerView (truncated/offline, có VoiceOver + Dynamic Type) wire vào sidebar; thêm 4 key `cache.*` en/vi; SwiftPM test 20/20 pass; typecheck toàn app pass 0 lỗi.
