//
//  SDVoiceUtils.swift
//  SDVoicePlayer
//
//  Created by uzzi on 2025/9/7.
//

import Foundation

class SDVoiceUtils {
    static func getResourceCacheDirectory() -> String {
        let folderPath = "\(NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!)".appendingPathComponent("Voice")
        return folderPath
    }
    
    static func mappedResourceFilePath(url: String) -> String {
        let filename = url.md5
        let filePath = getResourceCacheDirectory().appendingPathComponent(filename)
        return filePath
    }
}
