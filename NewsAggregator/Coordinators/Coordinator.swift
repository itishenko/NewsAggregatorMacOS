//
//  Coordinator.swift
//  NewsAggregator
//
//  Created on 13.01.2026
//

import Cocoa

protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }
    var window: NSWindow? { get set }
    
    func start()
}

extension Coordinator {
    func addChildCoordinator(_ coordinator: Coordinator) {
        childCoordinators.append(coordinator)
    }
    
    func removeChildCoordinator(_ coordinator: Coordinator) {
        childCoordinators.removeAll { $0 === coordinator }
    }
}
