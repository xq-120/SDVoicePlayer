//
//  SDResourceDownloadOperationToken.swift
//  SDVoicePlayer
//
//  Created by uzzi on 2025/10/19.
//

import Foundation

class SDResourceDownloadOperationToken {
    var completedBlock: ((_ resourceURL: String, _ filePath: String?, _ error: Error?) -> Void)?
    var progressBlock: ((_ resourceURL: String, _ progress: Float) -> Void)?
    var convertBlock: ((_ resourceURL: String, _ filePath: String) -> String?)?
}
