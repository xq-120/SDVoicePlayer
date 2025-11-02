//
//  SDStringExtension.swift
//  SDVoicePlayer
//
//  Created by uzzi on 2025/10/25.
//

import Foundation
import CommonCrypto

internal extension String {
    /// 原生md5
    var md5: String {
        guard let data = data(using: .utf8) else {
            return self
        }
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))

        #if swift(>=5.0)
        _ = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            return CC_MD5(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        #else
        _ = data.withUnsafeBytes { bytes in
            return CC_MD5(bytes, CC_LONG(data.count), &digest)
        }
        #endif

        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    func appendingPathComponent(_ str: String) -> String {
        return (self as NSString).appendingPathComponent(str)
    }
    
    /// 获取URL中资源的文件扩展名.
    /// 比如 "http://www.example.com/somepath/test.txt",返回txt。
    func extensionName() -> String? {
        var file: String = ""
        if var idx = self.lastIndex(of: "/") {
            idx = self.index(idx, offsetBy: 1)
            file = String(self[idx...])
        }
        
        if var idx = file.lastIndex(of: ".") {
            idx = file.index(idx, offsetBy: 1)
            let ext = String(file[idx...])
            return ext.count == 0 ? nil : ext
        }
        
        return nil
    }
}
