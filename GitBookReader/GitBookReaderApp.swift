//
//  GitBookReaderApp.swift
//  GitBookReader
//

import SwiftUI

@main
struct GitBookReaderApp: App {
    // MARK: - State
    @StateObject private var settings = BookSettings()

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .preferredColorScheme(settings.preferredColorScheme)
        }
    }
}
