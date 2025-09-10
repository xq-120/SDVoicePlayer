//
//  SDVoiceCacheManager.swift
//  SDVoicePlayer
//
//  Created by 薛权 on 2025/9/7.
//

import Foundation

class SDVoiceCacheManager: NSObject {
    public static let shared = SDVoiceCacheManager()
    
    private let ioQueue = DispatchQueue.init(label: "com.VoicePlayer.cacheSerialQueue")
    
    private override init() {
        super.init()
        
        ioQueue.setAsSpecific()
        
        let folderPath = SDVoiceUtils.getCacheVoiceDirectory()
        if !FileManager.default.fileExists(atPath: folderPath) {
            try? FileManager.default.createDirectory(at: URL.init(fileURLWithPath: folderPath), withIntermediateDirectories: true)
        }
    }
    
    // MARK: Cache
    @objc public func isVoiceCached(url: String) -> Bool {
        let filePath = SDVoiceUtils.mappedVoiceFilePath(url: url)
        return ioQueue.syncSafe({ FileManager.default.fileExists(atPath: filePath) })
    }
    
    @objc public func getCachedVoice(for url: String) -> String? {
        var filePath: String? = nil
        if isVoiceCached(url: url) {
            filePath = SDVoiceUtils.mappedVoiceFilePath(url: url)
        }
        return filePath
    }
    
    @objc public func getCachedVoice(for url: String, completion: ((String?) -> Void)?) {
        ioQueue.async {
            let filePath = self.getCachedVoice(for: url)
            completion?(filePath)
        }
    }
    
    @objc public func clearAllCache() {
        ioQueue.async { [weak self] in
            guard let self = self else {return}
            let folderPath = SDVoiceUtils.getCacheVoiceDirectory()
            do {
                // 获取文件夹中的所有内容
                let filePaths = try FileManager.default.contentsOfDirectory(atPath: folderPath)
                // 遍历删除
                for filePath in filePaths {
                    let fullPath = (folderPath as NSString).appendingPathComponent(filePath)
                    try FileManager.default.removeItem(atPath: fullPath)
                }
                print("文件夹中的文件已全部删除 ✅")
            } catch {
                print("删除文件出错: \(error)")
            }
        }
    }
}
