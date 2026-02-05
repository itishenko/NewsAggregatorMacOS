//
//  AppCoordinator.swift
//  NewsAggregator
//
//  Created on 13.01.2026
//

import Cocoa

class AppCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var window: NSWindow?
    
    let dependencyContainer: DependencyContainer
    
    init(window: NSWindow, dependencyContainer: DependencyContainer? = nil) {
        self.window = window
        self.dependencyContainer = dependencyContainer ?? DependencyContainer()
    }
    
    func start() {
        showNewsList()
    }
    
    private func showNewsList() {
        let coordinator = NewsListCoordinator(
            window: window,
            dependencyContainer: dependencyContainer
        )
        coordinator.parentCoordinator = self
        addChildCoordinator(coordinator)
        coordinator.start()
    }
}
