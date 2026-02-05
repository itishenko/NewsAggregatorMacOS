//
//  ImageCacheService.swift
//  NewsAggregator
//
//  Created on 13.01.2026
//

import Cocoa

class ImageCacheService: ImageCacheServiceProtocol {
    
    private let memoryCache = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let ioQueue = DispatchQueue(label: "com.newsaggregator.imagecache.io", qos: .userInitiated, attributes: .concurrent)
    private let urlSession: URLSession
    private var activeDownloads: [String: URLSessionDataTask] = [:]
    private var downloadCompletions: [String: [(NSImage?) -> Void]] = [:]
    private let downloadLock = NSLock()
    
    private let maxCacheSize = CGSize(width: 200, height: 200)
    
    init() {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ImageCache")
        
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        // Configure memory cache
        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
        
        // Configure URLSession with caching
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024, diskPath: "ImageDownloadCache")
        urlSession = URLSession(configuration: config)
    }
    
    deinit {
        urlSession.invalidateAndCancel()
    }
    
    // MARK: - Public Methods
    
    func loadImage(from urlString: String, completion: @escaping (NSImage?) -> Void) {
        let key = cacheKey(for: urlString)
        
        if let cachedImage = memoryCache.object(forKey: key as NSString) {
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }
        
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            
            if let diskImage = self.loadFromDisk(key: key) {
                self.memoryCache.setObject(diskImage, forKey: key as NSString)
                DispatchQueue.main.async {
                    completion(diskImage)
                }
                return
            }
            
            self.downloadImage(from: urlString, key: key, completion: completion)
        }
    }
    
    func clearCache() {
        clearMemoryCache()
        clearDiskCache()
    }
    
    func getCacheSize() -> Int64 {
        var totalSize: Int64 = 0
        
        ioQueue.sync {
            if let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
                for file in files {
                    if let resourceValues = try? file.resourceValues(forKeys: [.fileSizeKey]),
                       let fileSize = resourceValues.fileSize {
                        totalSize += Int64(fileSize)
                    }
                }
            }
        }
        
        return totalSize
    }
    
    func preloadImages(from urlStrings: [String]) {
        for urlString in urlStrings {
            loadImage(from: urlString) { _ in }
        }
    }
    
    // MARK: - Private Methods
    
    private func cacheKey(for urlString: String) -> String {
        if let data = urlString.data(using: .utf8) {
            return data.base64EncodedString()
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "+", with: "-")
        }
        return urlString.replacingOccurrences(of: "/", with: "_")
    }
    
    private func loadFromDisk(key: String) -> NSImage? {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        guard let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe),
              let image = NSImage(data: data) else {
            return nil
        }
        return image
    }
    
    private func saveToDisk(image: NSImage, key: String) {
        let optimizedImage = optimizeImage(image, maxSize: maxCacheSize)
        
        ioQueue.async(flags: .barrier) { [weak self] in
            guard let self = self,
                  let tiffData = optimizedImage.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffData),
                  let data = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
                return
            }
            
            let fileURL = self.cacheDirectory.appendingPathComponent(key)
            try? data.write(to: fileURL, options: .atomic)
        }
    }
    
    private func optimizeImage(_ image: NSImage, maxSize: CGSize) -> NSImage {
        if image.size.width <= maxSize.width && image.size.height <= maxSize.height {
            return image
        }
        
        let aspectRatio = image.size.width / image.size.height
        var newSize = maxSize
        
        if aspectRatio > 1 {
            newSize.height = maxSize.width / aspectRatio
        } else {
            newSize.width = maxSize.height * aspectRatio
        }
        
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        newImage.unlockFocus()
        
        return newImage
    }
    
    private func downloadImage(from urlString: String, key: String, completion: @escaping (NSImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        downloadLock.lock()
        if activeDownloads[key] != nil {
            if downloadCompletions[key] == nil {
                downloadCompletions[key] = []
            }
            downloadCompletions[key]?.append(completion)
            downloadLock.unlock()
            return
        }
        
        let task = urlSession.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            var completions: [(NSImage?) -> Void] = []
            var finalImage: NSImage?
            
            self.downloadLock.lock()
            completions = self.downloadCompletions[key] ?? []
            self.downloadCompletions.removeValue(forKey: key)
            self.activeDownloads.removeValue(forKey: key)
            self.downloadLock.unlock()
            
            if let data = data, let image = NSImage(data: data) {
                let optimizedImage = self.optimizeImage(image, maxSize: self.maxCacheSize)
                self.memoryCache.setObject(optimizedImage, forKey: key as NSString)
                self.saveToDisk(image: optimizedImage, key: key)
                finalImage = optimizedImage
            }
            
            DispatchQueue.main.async {
                for completion in completions {
                    completion(finalImage)
                }
            }
        }
        
        downloadCompletions[key] = [completion]
        activeDownloads[key] = task
        downloadLock.unlock()
        
        task.resume()
    }
    
    private func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
    
    private func clearDiskCache() {
        ioQueue.async { [weak self] in
            guard let self = self,
                  let files = try? self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil) else {
                return
            }
            
            files.forEach { file in
                try? self.fileManager.removeItem(at: file)
            }
        }
    }
}
