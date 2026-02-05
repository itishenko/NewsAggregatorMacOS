//
//  SettingsViewController.swift
//  NewsAggregator
//
//  Created on 13.01.2026
//

import Cocoa

class SettingsViewController: NSViewController {
    
    // MARK: - Properties
    
    private let viewModel: SettingsViewModel
    
    private enum Section: Int, CaseIterable {
        case refresh
        case sources
        case cache
        case about
    }
    
    private lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        return scrollView
    }()
    
    private static let lineHeight: CGFloat = 20
    
    private lazy var tableView: NSTableView = {
        let tableView = NSTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.style = .plain
        tableView.rowSizeStyle = .default
        tableView.headerView = nil
        tableView.usesAutomaticRowHeights = false
        tableView.rowHeight = 44
        tableView.intercellSpacing = NSSize(width: 0, height: Self.lineHeight)
        tableView.selectionHighlightStyle = .regular
        tableView.delegate = self
        tableView.dataSource = self
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SettingsColumn"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        
        return tableView
    }()
    
    private lazy var closeButton: NSButton = {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.title = "Закрыть"
        button.bezelStyle = .rounded
        button.target = self
        button.action = #selector(closeSettings)
        return button
    }()
    
    // MARK: - Init
    
    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupViewModel()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        scrollView.documentView = tableView
        
        view.addSubview(scrollView)
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: closeButton.topAnchor, constant: -16),
            
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
    }
    
    private func setupViewModel() {
        viewModel.onSourcesUpdated = { [weak self] in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
                self?.viewModel.notifySettingsChanged()
            }
        }
        
        viewModel.onSettingsUpdated = { [weak self] in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
                self?.viewModel.notifySettingsChanged()
            }
        }
        
        viewModel.onCacheCleared = { [weak self] in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
                self?.viewModel.showAlert(title: "", message: "Кэш успешно очищен")
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func closeSettings() {
        viewModel.dismiss()
    }
}

// MARK: - NSTableViewDataSource

extension SettingsViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        var count = 0
        for section in Section.allCases {
            count += numberOfRowsInSection(section.rawValue)
        }
        return count
    }
    
    private func numberOfRowsInSection(_ section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        
        switch sectionType {
        case .refresh:
            return 1
        case .sources:
            return viewModel.numberOfSources() + 1 // +1 for Add button
        case .cache:
            return 2
        case .about:
            return 1
        }
    }
}

// MARK: - NSTableViewDelegate

extension SettingsViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var currentRow = row
        
        for section in Section.allCases {
            let rowsInSection = numberOfRowsInSection(section.rawValue)
            if currentRow < rowsInSection {
                return createCellView(for: section, row: currentRow)
            }
            currentRow -= rowsInSection
        }
        
        return nil
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 else { return }
        
        var currentRow = selectedRow
        
        for section in Section.allCases {
            let rowsInSection = numberOfRowsInSection(section.rawValue)
            if currentRow < rowsInSection {
                handleSelection(for: section, row: currentRow)
                break
            }
            currentRow -= rowsInSection
        }
        
        tableView.deselectRow(selectedRow)
    }
    
    private func createCellView(for section: Section, row: Int) -> NSView? {
        switch section {
        case .refresh:
            return createRefreshCell()
        case .sources:
            if row < viewModel.numberOfSources() {
                return createSourceCell(at: row)
            } else {
                return createAddSourceCell()
            }
        case .cache:
            if row == 0 {
                return createCacheSizeCell()
            } else {
                return createClearCacheCell()
            }
        case .about:
            return createAboutCell()
        }
    }
    
    private func handleSelection(for section: Section, row: Int) {
        switch section {
        case .refresh:
            viewModel.showRefreshIntervalPicker()
        case .sources:
            if row == viewModel.numberOfSources() {
                viewModel.showAddSourceDialog()
            }
        case .cache:
            if row == 1 {
                viewModel.showClearCacheConfirmation()
            }
        case .about:
            break
        }
    }
    
    // MARK: - Cell Creation
    
    private func createRefreshCell() -> NSView {
        let cell = TwoLabelCellView()
        cell.configure(title: "Частота обновления", detail: "\(viewModel.settings.refreshIntervalMinutes) мин")
        return cell
    }
    
    private func createSourceCell(at index: Int) -> NSView {
        guard let source = viewModel.getSource(at: index) else {
            return NSView()
        }
        
        let cell = SourceSwitchCellView()
        cell.configure(
            sourceName: source.name,
            isEnabled: source.isEnabled,
            index: index,
            onToggle: { [weak self] index in
                self?.viewModel.toggleSource(at: index)
            }
        )
        return cell
    }
    
    private func createAddSourceCell() -> NSView {
        let cell = SingleLabelCellView()
        cell.configure(title: "Добавить источник", color: .systemBlue)
        return cell
    }
    
    private func createCacheSizeCell() -> NSView {
        let cell = TwoLabelCellView()
        cell.configure(title: "Размер кэша", detail: viewModel.getCacheSize())
        return cell
    }
    
    private func createClearCacheCell() -> NSView {
        let cell = SingleLabelCellView()
        cell.configure(title: "Очистить кэш", color: .systemRed)
        return cell
    }
    
    private func createAboutCell() -> NSView {
        let cell = TwoLabelCellView()
        cell.configure(title: "Последнее обновление", detail: viewModel.getLastUpdatedString())
        return cell
    }
}

// MARK: - Custom Cell Views

class TwoLabelCellView: NSTableCellView {
    private let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13)
        return label
    }()
    
    private let detailLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        return label
    }()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        addSubview(titleLabel)
        addSubview(detailLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            detailLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            detailLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8)
        ])
    }
    
    func configure(title: String, detail: String) {
        titleLabel.stringValue = title
        detailLabel.stringValue = detail
    }
}

class SingleLabelCellView: NSTableCellView {
    private let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13)
        return label
    }()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    func configure(title: String, color: NSColor = .labelColor) {
        titleLabel.stringValue = title
        titleLabel.textColor = color
    }
}

class SourceSwitchCellView: NSTableCellView {
    private let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13)
        return label
    }()
    
    private let switchControl: NSSwitch = {
        let switchControl = NSSwitch()
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        return switchControl
    }()
    
    private var toggleHandler: ((Int) -> Void)?
    private var index: Int = 0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        addSubview(titleLabel)
        addSubview(switchControl)
        
        switchControl.target = self
        switchControl.action = #selector(switchToggled)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            switchControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            switchControl.centerYAnchor.constraint(equalTo: centerYAnchor),
            switchControl.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8)
        ])
    }
    
    func configure(sourceName: String, isEnabled: Bool, index: Int, onToggle: @escaping (Int) -> Void) {
        titleLabel.stringValue = sourceName
        switchControl.state = isEnabled ? .on : .off
        self.index = index
        self.toggleHandler = onToggle
    }
    
    @objc private func switchToggled() {
        toggleHandler?(index)
    }
}
