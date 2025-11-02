//
//  SDResourceCacheManager.swift
//  SDVoicePlayer
//
//  Created by uzzi on 2025/9/7.
//

import Foundation

public class SDResourceCacheManager: NSObject {
    public static let shared = SDResourceCacheManager()
    
    private let ioQueue = DispatchQueue.init(label: "com.VoicePlayer.cacheSerialQueue")
    
    private override init() {
        super.init()
        
        ioQueue.setAsSpecific()
        
        let cachedPath = SDVoiceUtils.getResourceCachedDirectory()
        try? FileManager.default.createDirectory(at: URL.init(fileURLWithPath: cachedPath), withIntermediateDirectories: true)
        
        let downloadedPath = SDVoiceUtils.getResourceDownloadedDirectory()
        try? FileManager.default.createDirectory(at: URL.init(fileURLWithPath: downloadedPath), withIntermediateDirectories: true)
    }
    
    // MARK: Cache
    public func isResourceCached(url: String, transformerKey: String? = nil) -> Bool {
        let filePath = SDVoiceUtils.mappedResourceCachedFilePath(url: url)
        return ioQueue.syncSafe({ FileManager.default.fileExists(atPath: filePath) })
    }
    
    public func getCachedResourceFilePath(for url: String, transformerKey: String? = nil) -> String? {
        var filePath: String? = nil
        if isResourceCached(url: url, transformerKey: transformerKey) {
            filePath = SDVoiceUtils.mappedResourceCachedFilePath(url: url, appendKey: transformerKey)
        }
        return filePath
    }
    
    public func getCachedResourceFilePath(for url: String, transformerKey: String? = nil, completion: ((String?) -> Void)?) {
        ioQueue.async {
            let filePath = self.getCachedResourceFilePath(for: url, transformerKey: transformerKey)
            DispatchQueue.main.async {
                completion?(filePath)
            }
        }
    }
    
    public func storeCache(resourceURL: String, transformerKey: String? = nil, srcPath: String, completion: ((_ destPath: String?, _ error: Error?) -> Void)?) {
        storeCache(srcPath: srcPath, destPath: SDVoiceUtils.mappedResourceCachedFilePath(url: resourceURL, appendKey: transformerKey), completion: completion)
    }
    
    public func storeCache(srcPath: String, destPath: String, completion: ((_ destPath: String?, _ error: Error?) -> Void)?) {
        ioQueue.async {
            let srcLoc = URL.init(fileURLWithPath: srcPath)
            let destLoc = URL.init(fileURLWithPath: destPath)
            do {
                try FileManager.default.moveItem(at: srcLoc, to: destLoc)
                DispatchQueue.main.async {
                    completion?(destPath, nil)
                }
            } catch let error {
                DispatchQueue.main.async {
                    completion?(nil, error)
                }
            }
        }
    }
    
    public func clearAllCache() {
        ioQueue.async {
            let folderPath = SDVoiceUtils.getResourceCachedDirectory()
            do {
                // 获取文件夹中的所有内容
                let filePaths = try FileManager.default.contentsOfDirectory(atPath: folderPath)
                // 遍历删除
                for filePath in filePaths {
                    let fullPath = (folderPath as NSString).appendingPathComponent(filePath)
                    try FileManager.default.removeItem(atPath: fullPath)
                }
            } catch {
                print("删除文件出错: \(error)")
            }
        }
    }
}
