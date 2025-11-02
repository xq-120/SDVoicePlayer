//
//  SDVoiceUtils.swift
//  SDVoicePlayer
//
//  Created by uzzi on 2025/9/7.
//

import Foundation

class SDVoiceUtils {
    static func getResourceHomeDirectory() -> String {
        let resourceHomePath = "\(NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!)".appendingPathComponent("com.download.uzzi")
        return resourceHomePath
    }
    
    static func getResourceCachedDirectory() -> String {
        let folderPath = getResourceHomeDirectory().appendingPathComponent("Cached")
        return folderPath
    }
    
    static func getResourceDownloadedDirectory() -> String {
        let folderPath = getResourceHomeDirectory().appendingPathComponent("Downloaded")
        return folderPath
    }
    
    // 文件名规则：url.md5 + "_" + appendKey + "." + url.extensionName()
    static func mappedResourceCachedFilePath(url: String, appendKey: String? = nil) -> String {
        let extname = url.extensionName()
        let filename = url.md5 + (appendKey == nil ? "" : "_\(appendKey!)")
        let fileFullName = filename + (extname == nil ? "" : ".\(extname!)")
        let filePath = getResourceCachedDirectory().appendingPathComponent(fileFullName)
        return filePath
    }
    
    // 文件名规则：url.md5 + "." + url.extensionName()
    static func mappedResourceDownloadedFilePath(url: String) -> String {
        let extname = url.extensionName()
        let filename = url.md5
        let fileFullName = filename + (extname == nil ? "" : ".\(extname!)")
        let filePath = getResourceDownloadedDirectory().appendingPathComponent(fileFullName)
        return filePath
    }
}
