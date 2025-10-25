//
//  SDResourceManager.swift
//  SDVoicePlayer
//
//  Created by uzzi on 2025/10/18.
//

import Foundation

public class SDResourceManager: NSObject {
    
    @objc public static let shared = SDResourceManager()
    
    let cacheManager =  SDResourceCacheManager.shared
    
    let downloadManager = SDResourceDownloadManager.shared
    
    override init() {
        super.init()
        
    }
    
    @objc public func isResourceCached(url: String) -> Bool {
        return cacheManager.isResourceCached(url: url)
    }
    
    @objc public func getCachedVoice(for url: String) -> String? {
        return cacheManager.getCachedResourceFilePath(for: url)
    }
    
    @objc public func loadResource(resourceURL: String,
                      progress: ((_ resourceURL: String, _ progress: Float) -> Void)? = nil,
                      convert: ((_ resourceURL: String, _ filePath: String) -> String?)? = nil,
                      completion: ((_ resourceURL: String, _ filePath: String?, _ error: Error?) -> Void)?) {
        downloadManager.download(resourceURL: resourceURL, progress: progress, convert: convert) { resourceURL, filePath, error in
            
        }
    }
    
    @objc public func cancelDownload(resourceURL: String) {
        downloadManager.cancelDownload(resourceURL: resourceURL)
    }
}
