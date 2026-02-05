//
//  NewsListViewController.swift
//  NewsAggregator
//
//  Created on 13.01.2026
//

import Cocoa

class NewsListViewController: NSViewController {
    
    // MARK: - Properties
    
    private let viewModel: NewsListViewModel
    private let imageCacheService: ImageCacheServiceProtocol
    
    private lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .windowBackgroundColor
        return scrollView
    }()
    
    private lazy var tableView: NSTableView = {
        let tableView = NSTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.style = .plain
        tableView.rowSizeStyle = .default
        tableView.headerView = nil
        tableView.rowHeight = 80
        tableView.selectionHighlightStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("NewsColumn"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        
        return tableView
    }()
    
    private lazy var toolbar: NSToolbar = {
        let toolbar = NSToolbar(identifier: "NewsListToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        return toolbar
    }()
    
    private lazy var progressIndicator: NSProgressIndicator = {
        let indicator = NSProgressIndicator()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.style = .spinning
        indicator.isDisplayedWhenStopped = false
        return indicator
    }()
    
    private lazy var testLabel: NSTextField = {
        let label = NSTextField(labelWithString: "NewsAggregator Loading...")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .labelColor
        label.alignment = .center
        return label
    }()
    
    // MARK: - Init
    
    init(viewModel: NewsListViewModel, imageCacheService: ImageCacheServiceProtocol) {
        self.viewModel = viewModel
        self.imageCacheService = imageCacheService
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupViewModel()
        
        viewModel.loadNews()
        
        // Trigger initial UI update
        let count = viewModel.numberOfItems()
        if count > 0 {
            testLabel.isHidden = true
            scrollView.isHidden = false
            tableView.reloadData()
        } else {
            testLabel.isHidden = false
            testLabel.stringValue = "Нет новостей. Нажмите 'Обновить'"
            scrollView.isHidden = true
        }
        
        let shouldRefresh = viewModel.shouldAutoRefresh()
        
        if viewModel.numberOfItems() == 0 {
            viewModel.showFirstLaunchMessage()
            viewModel.refreshNews()
        } else if shouldRefresh {
            viewModel.refreshNews()
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        setupToolbar()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        scrollView.documentView = tableView
        
        view.addSubview(testLabel)
        view.addSubview(scrollView)
        view.addSubview(progressIndicator)
        
        NSLayoutConstraint.activate([
            testLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            testLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            progressIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressIndicator.topAnchor.constraint(equalTo: view.topAnchor, constant: 20)
        ])
    }
    
    private func setupViewModel() {
        viewModel.onNewsUpdated = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let count = self.viewModel.numberOfItems()
                
                if count > 0 {
                    self.testLabel.isHidden = true
                    self.scrollView.isHidden = false
                } else {
                    self.testLabel.isHidden = false
                    self.testLabel.stringValue = "Нет новостей. Нажмите 'Обновить'"
                    self.scrollView.isHidden = true
                }
                
                self.tableView.reloadData()
            }
        }
        
        viewModel.onDisplayModeChanged = { [weak self] in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }
        
        viewModel.onShowError = { [weak self] error in
            DispatchQueue.main.async {
                self?.viewModel.showError(message: error)
            }
        }
        
        viewModel.onRefreshStarted = { [weak self] in
            DispatchQueue.main.async {
                self?.progressIndicator.startAnimation(nil)
            }
        }
        
        viewModel.onRefreshCompleted = { [weak self] in
            DispatchQueue.main.async {
                self?.progressIndicator.stopAnimation(nil)
            }
        }
    }
    
    private func setupToolbar() {
        view.window?.toolbar = toolbar
        view.window?.title = "Новости"
    }
    
    // MARK: - Actions
    
    @objc private func handleRefresh() {
        viewModel.refreshNews()
    }
    
    @objc private func toggleDisplayMode() {
        viewModel.toggleDisplayMode()
    }
    
    @objc private func openSettings() {
        viewModel.showSettings()
    }
}

// MARK: - NSTableViewDataSource

extension NewsListViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel.numberOfItems()
    }
}

// MARK: - NSTableViewDelegate

extension NewsListViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let newsItem = viewModel.getNewsItem(at: row) else { return nil }
        
        let newsItemData = NewsItemData(from: newsItem)
        let cellView = NewsItemCellView()
        cellView.configure(
            with: newsItemData,
            imageCacheService: imageCacheService,
            onImageTap: { [weak self] in
                self?.viewModel.showNewsDetail(at: row)
            }
        )
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return viewModel.displayMode == .normal ? 80 : 120
    }
}

// MARK: - NSToolbarDelegate

extension NewsListViewController: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .refreshItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Обновить"
            item.toolTip = "Обновить новости"
            item.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
            item.target = self
            item.action = #selector(handleRefresh)
            return item
            
        case .settingsItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Настройки"
            item.toolTip = "Открыть настройки"
            item.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
            item.target = self
            item.action = #selector(openSettings)
            return item
            
        default:
            return nil
        }
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.refreshItem, .flexibleSpace, .settingsItem]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.refreshItem, .settingsItem, .flexibleSpace, .space]
    }
}

// MARK: - Custom Toolbar Item Identifiers

extension NSToolbarItem.Identifier {
    static let refreshItem = NSToolbarItem.Identifier("RefreshItem")
    static let settingsItem = NSToolbarItem.Identifier("SettingsItem")
}

// MARK: - NewsItemCellView

class NewsItemCellView: NSTableCellView {
    
    private let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    private let descriptionLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    private let sourceLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11)
        label.textColor = .tertiaryLabelColor
        return label
    }()
    
    private let imageButton: NSButton = {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyUpOrDown
        button.wantsLayer = true
        button.layer?.cornerRadius = 4
        button.layer?.masksToBounds = true
        return button
    }()
    
    private var onImageTap: (() -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        imageButton.target = self
        imageButton.action = #selector(handleImageTap)
        
        addSubview(imageButton)
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(sourceLabel)
        
        NSLayoutConstraint.activate([
            imageButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            imageButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageButton.widthAnchor.constraint(equalToConstant: 60),
            imageButton.heightAnchor.constraint(equalToConstant: 60),
            
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: imageButton.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            sourceLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 4),
            sourceLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            sourceLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            sourceLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with newsItem: NewsItemData, imageCacheService: ImageCacheServiceProtocol, onImageTap: @escaping () -> Void) {
        self.onImageTap = onImageTap
        imageButton.toolTip = "Открыть новость"
        
        titleLabel.stringValue = newsItem.title
        descriptionLabel.stringValue = newsItem.itemDescription
        sourceLabel.stringValue = "\(newsItem.sourceName) • \(formatDate(newsItem.pubDate))"
        
        let placeholder = NSImage(systemSymbolName: "photo", accessibilityDescription: "Placeholder")
        imageButton.image = placeholder
        
        if let imageURL = newsItem.imageURL {
            imageCacheService.loadImage(from: imageURL) { [weak self] image in
                self?.imageButton.image = image ?? placeholder
            }
        }
    }
    
    @objc private func handleImageTap() {
        onImageTap?()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
