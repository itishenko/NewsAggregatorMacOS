//
//  Main.swift
//  NewsAggregator
//

import AppKit

@main
struct AppLauncher {
    static func main() {
        let app = NSApplication.shared
        app.delegate = AppDelegate()
        app.run()
    }
}
