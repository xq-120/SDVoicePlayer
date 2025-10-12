//
//  SDResourceDownloadManager.swift
//  SDVoicePlayer
//
//  Created by uzzi on 2025/9/7.
//

import Foundation

class SDResourceDownloadManager: NSObject, URLSessionDownloadDelegate {
    public static let shared = SDResourceDownloadManager()
    
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
    
    public func download(resourceURL: URL,
                         progress: ((_ resourceURL: String?, _ progress: Float) -> Void)? = nil,
                         convert: ((_ resourceURL: String?, _ filePath: String?) -> String?)? = nil,
                         completion: ((_ resourceURL: String?, _ filePath: String?, _ error: Error?) -> Void)?) {
        let op = SDResourceDownloadOperation.init(resourceURL: resourceURL, progress: progress, completion: completion, session: session)
        queue.addOperation(op)
    }
    
    public func cancelDownload(voice: URL) {
        
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
