//
//  SDVoiceUtils.swift
//  SDVoicePlayer
//
//  Created by 薛权 on 2025/9/7.
//

import Foundation

class SDVoiceUtils {
    static func getResourceCacheDirectory() -> String {
        let folderPath = "\(NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!)".appendingPathComponent("Voice")
        return folderPath
    }
    
    static func getResourceExtensionName(url: String) -> String? {
        let url = url
        var file: String = ""
        if var idx = url.lastIndex(of: "/") {
            idx = url.index(idx, offsetBy: 1)
            file = String(url[idx...])
        }
        if var idx = file.lastIndex(of: ".") {
            idx = file.index(idx, offsetBy: 1)
            let ext = String(file[idx...])
            return ext.count == 0 ? nil : ext
        } else {
            return nil
        }
    }
    
    static func mappedResourceFilePath(url: String) -> String {
        let filename = url.md5
        let filePath = getResourceCacheDirectory().appendingPathComponent(filename)
        return filePath
    }
}
