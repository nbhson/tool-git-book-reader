# Plan — tool-git-book-reader

macOS app đọc GitBook (Swift/SwiftUI), Xcode project.

## Baseline audit (00:44, 28-10-2026)
- ⚠️ **Không build được trong môi trường này**: máy chỉ có Command Line Tools, `xcodebuild` yêu cầu Xcode đầy đủ → chỉ review tĩnh được
- Cấu trúc: GitBookReader/ (App, Models, Views, Services, Extensions, Resources) + xcodeproj
- Đã có commit refactor gần đây: split god-view ContentView, i18n, error handling

## Roadmap
### P0
- [ ] Review tĩnh mã Swift: force unwrap, error handling, memory leak (closure retain), race condition
- [ ] Rà các file lớn (god objects) còn sót

### P1 (chất lượng)
- [ ] Đối chiếu README với tính năng thực tế
- [ ] Chuẩn hoá cấu trúc MVVM nếu phát hiện View chứa business logic

### P2
- [ ] Ghi chú build instructions (yêu cầu Xcode version)

## Self-review log
- _0:44_ Audit lần 1: không có toolchain build; chuyển sang review tĩnh.
