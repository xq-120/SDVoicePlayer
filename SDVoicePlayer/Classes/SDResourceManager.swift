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
    
    @objc public func isResourceCached(url: String, transformerKey: String? = nil) -> Bool {
        return cacheManager.isResourceCached(url: url, transformerKey: transformerKey)
    }
    
    @objc public func getCachedVoice(for url: String, transformerKey: String? = nil) -> String? {
        return cacheManager.getCachedResourceFilePath(for: url, transformerKey: transformerKey)
    }
    
    @objc public func loadResource(resourceURL: String,
                                   progress: ((_ resourceURL: String, _ progress: Float) -> Void)?,
                                   completion: ((_ resourceURL: String, _ filePath: String?, _ error: Error?) -> Void)?) {
        // 查找缓存
        if let storedFilePath = self.cacheManager.getCachedResourceFilePath(for: resourceURL) {
            completion?(resourceURL, storedFilePath, nil)
            return
        }
        
        // 进行下载
        downloadManager.download(resourceURL: resourceURL, progress: progress) { [weak self] resourceURL, filePath, error in
            guard let self = self else {return}
            
            if error != nil || filePath == nil {
                completion?(resourceURL, filePath, error)
                return
            }
            
            if let storedFilePath = self.cacheManager.getCachedResourceFilePath(for: resourceURL) {
                completion?(resourceURL, storedFilePath, error)
                return
            }
            
            self.cacheManager.storeCache(resourceURL: resourceURL, srcPath: filePath!) { destPath, error in
                completion?(resourceURL, destPath, error)
            }
        }
    }
    
    public func storeCache(resourceURL: String, transformerKey: String? = nil, srcPath: String, completion: ((_ destPath: String?, _ error: Error?) -> Void)?) {
        self.cacheManager.storeCache(srcPath: srcPath, destPath: SDVoiceUtils.mappedResourceCachedFilePath(url: resourceURL, appendKey: transformerKey), completion: completion)
    }
    
    @objc public func cancelDownload(resourceURL: String) {
        downloadManager.cancelDownload(resourceURL: resourceURL)
    }
}
