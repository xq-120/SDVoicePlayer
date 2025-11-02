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
            downloadQueue.maxConcurrentOperationCount = maxDownloads
        }
    }
    
    private var downloadQueue = OperationQueue.init()
    
    private lazy var session: URLSession = URLSession.init(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    
    private var operationDict: [String: SDResourceDownloadOperation] = [:]
    
    private var lock: NSLock = NSLock.init()
    
    private override init() {
        super.init()
        downloadQueue.maxConcurrentOperationCount = maxDownloads
    }
    
    public func download(resourceURL: String,
                         progress: ((_ resourceURL: String, _ progress: Float) -> Void)? = nil,
                         completion: ((_ resourceURL: String, _ filePath: String?, _ error: Error?) -> Void)?) {
        if resourceURL.isEmpty {
            completion?(resourceURL, nil, NSError.getPlayerErrorWithCode(code: .invalidURL))
            return
        }
        if let op = getDownloadOperation(with: resourceURL) {
            op.addHandler(progress: progress, completion: completion)
        } else {
            let op = SDResourceDownloadOperation.init(resourceURL: resourceURL, progress: progress, completion: completion, session: session)
            op.completionBlock = { [weak self] in
                guard let self = self else { return }
                removeDownloadOperation(with: resourceURL)
            }
            downloadQueue.addOperation(op)
            setDownloadOperation(operation: op, with: resourceURL)
        }
    }
    
    private func getDownloadOperation(with resourceURL: String) -> SDResourceDownloadOperation? {
        lock.withLock {
            return operationDict[resourceURL]
        }
    }
    
    private func setDownloadOperation(operation: SDResourceDownloadOperation, with resourceURL: String) {
        lock.withLock {
            operationDict[resourceURL] = operation
        }
    }
    
    private func removeDownloadOperation(with resourceURL: String) {
        lock.withLock {
            operationDict[resourceURL] = nil
        }
    }
    
    public func cancelDownload(resourceURL: String) {
        let operation = getDownloadOperation(with: resourceURL)
        operation?.cancel()
    }
    
    public func cancelAllDownload() {
        var ops: [String: SDResourceDownloadOperation] = [:]
        lock.withLock {
            ops = operationDict
        }
        for (_, v) in ops {
            v.cancel()
        }
    }
    
    func operation(with task: URLSessionTask) -> SDResourceDownloadOperation? {
        var returnOperation: SDResourceDownloadOperation?
        
        for case let operation as SDResourceDownloadOperation in downloadQueue.operations {
            var operationTask: URLSessionTask?
            operation.lock.withLock {
                operationTask = operation.downloadTask
            }
            if operationTask?.taskIdentifier == task.taskIdentifier {
                returnOperation = operation
                break
            }
        }
        
        return returnOperation
    }
    
    // MARK: URLSessionDownloadDelegate
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let operation = operation(with: task)
        operation?.urlSession(session, task: task, didCompleteWithError: error)
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let operation = operation(with: downloadTask)
        operation?.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let operation = operation(with: downloadTask)
        operation?.urlSession(session, downloadTask: downloadTask, didWriteData: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }
}
