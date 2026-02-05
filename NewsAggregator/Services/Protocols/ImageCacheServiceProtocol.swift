//
//  ImageCacheServiceProtocol.swift
//  NewsAggregator
//
//  Created on 13.01.2026
//

import Cocoa

protocol ImageCacheServiceProtocol {
    func loadImage(from urlString: String, completion: @escaping (NSImage?) -> Void)
    func clearCache()
    func getCacheSize() -> Int64
}
