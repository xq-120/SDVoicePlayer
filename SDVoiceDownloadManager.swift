//
//  SDVoiceDownloadManager.swift
//  SDVoicePlayer
//
//  Created by 薛权 on 2025/9/7.
//

import Foundation

class SDVoiceDownloadManager: NSObject, URLSessionDownloadDelegate {
    public static let shared = SDVoiceDownloadManager()
    
    public var maxDownloads = 3 {
        didSet {
            queue.maxConcurrentOperationCount = maxDownloads
        }
    }
    
    private var queue = OperationQueue.init()
    
    private lazy var session: URLSession = URLSession.init(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    
    private override init() {
        super.init()
        queue.maxConcurrentOperationCount = maxDownloads
    }
    
    public func download(voice: URL?, progressBlk: ((_ voiceURL: String?, _ progress: Float) -> Void)?, completion: ((_ voiceURL: String?, _ filePath: String?, _ error: Error?) -> Void)?) {
        if voice == nil {
            return
        }
        
        let op = SDVoiceDownloadOperation.init(voiceURL: voice, progress: progressBlk, completion: completion, session: session)
        queue.addOperation(op)
    }
    
    public func cancelDownload(voice: URL?) {
        if voice == nil {
            return
        }
    }
    
    public func cancelAllDownload() {
        
    }
    
    // MARK: URLSessionDownloadDelegate
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
    }
}
