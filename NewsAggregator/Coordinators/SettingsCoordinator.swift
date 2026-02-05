//
//  SettingsCoordinator.swift
//  NewsAggregator
//
//  Created on 13.01.2026
//

import Cocoa

class SettingsCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var window: NSWindow?
    
    weak var parentCoordinator: NewsListCoordinator?
    
    private let dependencyContainer: DependencyContainer
    var onSettingsChanged: (() -> Void)?
    
    private var settingsViewController: SettingsViewController?
    
    init(window: NSWindow?, dependencyContainer: DependencyContainer) {
        self.window = window
        self.dependencyContainer = dependencyContainer
    }
    
    func start() {
        let viewModel = SettingsViewModel(
            sourceRepository: dependencyContainer.sourceRepository,
            settingsRepository: dependencyContainer.settingsRepository,
            imageCacheService: dependencyContainer.imageCacheService
        )
        viewModel.coordinator = self
        
        let viewController = SettingsViewController(viewModel: viewModel)
        settingsViewController = viewController
        
        window?.contentViewController = viewController
        // Окно показывается через beginSheet в NewsListCoordinator
    }
    
    // MARK: - Navigation Methods
    
    func dismiss() {
        if let window = window, let sheetParent = window.sheetParent {
            sheetParent.endSheet(window)
        } else {
            window?.close()
        }
        parentCoordinator?.removeChildCoordinator(self)
    }
    
    func showRefreshIntervalPicker(currentInterval: Int, onIntervalSelected: @escaping (Int) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Частота обновления"
        alert.informativeText = "Выберите интервал автообновления"
        
        let intervals = [5, 15, 30, 60]
        for interval in intervals {
            alert.addButton(withTitle: "\(interval) минут")
        }
        alert.addButton(withTitle: "Отмена")
        
        let response = alert.runModal()
        let buttonIndex = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        
        if buttonIndex >= 0 && buttonIndex < intervals.count {
            onIntervalSelected(intervals[buttonIndex])
        }
    }
    
    func showAddSourceDialog(onSourceAdded: @escaping (String, String) -> Bool) {
        let alert = NSAlert()
        alert.messageText = "Добавить источник"
        alert.informativeText = "Введите данные нового источника новостей"
        
        let nameField = NSTextField(frame: NSRect(x: 0, y: 30, width: 300, height: 24))
        nameField.placeholderString = "Название"
        
        let urlField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        urlField.placeholderString = "RSS URL"
        
        let stackView = NSStackView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        stackView.orientation = .vertical
        stackView.spacing = 6
        stackView.addArrangedSubview(nameField)
        stackView.addArrangedSubview(urlField)
        
        alert.accessoryView = stackView
        alert.addButton(withTitle: "Добавить")
        alert.addButton(withTitle: "Отмена")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let name = nameField.stringValue
            let url = urlField.stringValue
            
            if onSourceAdded(name, url) {
                showAlert(title: "Успешно", message: "Источник добавлен")
            } else {
                showAlert(title: "Ошибка", message: "Проверьте введённые данные")
            }
        }
    }
    
    func showClearCacheConfirmation(onConfirm: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "Очистить кэш?"
        alert.informativeText = "Это действие удалит все кэшированные изображения"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Очистить")
        alert.addButton(withTitle: "Отмена")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            onConfirm()
        }
    }
    
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
