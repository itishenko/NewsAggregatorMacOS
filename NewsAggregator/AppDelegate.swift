//
//  AppDelegate.swift
//  NewsAggregator
//
//  Created by Ivan Tishchenko on 05.02.2026.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var window: NSWindow!
    var coordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.regular)
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "NewsAggregator"
        window.center()
        window.setFrameAutosaveName("MainWindow")
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 300)
        
        let dependencyContainer = DependencyContainer()
        coordinator = AppCoordinator(window: window, dependencyContainer: dependencyContainer)
        coordinator?.start()
        
        window.setContentSize(NSSize(width: 900, height: 700))
        window.center()
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

}

