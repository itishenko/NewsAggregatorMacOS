//
//  NewsListCoordinator.swift
//  NewsAggregator
//
//  Created on 13.01.2026
//

import Cocoa

class NewsListCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var window: NSWindow?
    
    weak var parentCoordinator: AppCoordinator?
    
    private let dependencyContainer: DependencyContainer
    private var newsListViewController: NewsListViewController?
    
    init(window: NSWindow?, dependencyContainer: DependencyContainer) {
        self.window = window
        self.dependencyContainer = dependencyContainer
    }
    
    func start() {
        let viewModel = NewsListViewModel(
            newsRepository: dependencyContainer.newsRepository,
            sourceRepository: dependencyContainer.sourceRepository,
            settingsRepository: dependencyContainer.settingsRepository,
            newsService: dependencyContainer.newsService
        )
        viewModel.coordinator = self
        
        let viewController = NewsListViewController(
            viewModel: viewModel,
            imageCacheService: dependencyContainer.imageCacheService
        )
        newsListViewController = viewController
        
        window?.contentViewController = viewController
    }
    
    // MARK: - Navigation Methods
    
    func showSettings(onSettingsChanged: @escaping () -> Void) {
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "Настройки"
        settingsWindow.minSize = NSSize(width: 400, height: 400)
        
        let coordinator = SettingsCoordinator(
            window: settingsWindow,
            dependencyContainer: dependencyContainer
        )
        coordinator.parentCoordinator = self
        coordinator.onSettingsChanged = onSettingsChanged
        addChildCoordinator(coordinator)
        coordinator.start()
        
        // Фиксируем размер: после contentViewController окно может схлопнуться
        settingsWindow.setContentSize(NSSize(width: 600, height: 500))
        
        if let mainWindow = window {
            mainWindow.beginSheet(settingsWindow) { [weak self, weak coordinator] _ in
                guard let self = self, let coordinator = coordinator else { return }
                self.removeChildCoordinator(coordinator)
            }
        }
    }
    
    func showNewsDetail(url: URL, newsItemIndex: Int, onMarkAsRead: @escaping (Int) -> Void) {
        onMarkAsRead(newsItemIndex)
        NSWorkspace.shared.open(url)
    }
    
    func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Ошибка"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func showFirstLaunchMessage() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let alert = NSAlert()
            alert.messageText = "Добро пожаловать!"
            alert.informativeText = "Нажмите кнопку обновления для загрузки новостей"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
