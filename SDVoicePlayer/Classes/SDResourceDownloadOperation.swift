//
//  SDResourceDownloadOperation.swift
//  SDVoicePlayer
//
//  Created by uzzi on 2025/9/7.
//

import Foundation

class SDResourceDownloadOperation: Operation, URLSessionDownloadDelegate, @unchecked Sendable {
    
    var resourceURL: String
    
    private weak var session: URLSession?
    
    internal var downloadTask: URLSessionDownloadTask?
    
    internal let lock = NSRecursiveLock()
    
    private var _executing: Bool = false
    
    private var _finished: Bool = false
    
    private var callbackTokens: [SDResourceDownloadOperationToken] = []

    override private(set) var isExecuting: Bool {
        get { _executing }
        set {
            willChangeValue(forKey: "isExecuting")
            _executing = newValue
            didChangeValue(forKey: "isExecuting")
        }
    }

    override private(set) var isFinished: Bool {
        get { _finished }
        set {
            willChangeValue(forKey: "isFinished")
            _finished = newValue
            didChangeValue(forKey: "isFinished")
        }
    }
    
    override var isAsynchronous: Bool {
        return true
    }
    
    init(resourceURL: String,
         progress: ((_ resourceURL: String, _ progress: Float) -> Void)? = nil,
         completion: ((_ resourceURL: String, _ filePath: String?, _ error: Error?) -> Void)? = nil,
         session: URLSession? = nil) {
        self.resourceURL = resourceURL
        self.session = session
        super.init()
        self.addHandler(progress: progress, completion: completion)
    }
    
    func addHandler(progress: ((_ resourceURL: String, _ progress: Float) -> Void)? = nil,
                    completion: ((_ resourceURL: String, _ filePath: String?, _ error: Error?) -> Void)? = nil) {
        let token = SDResourceDownloadOperationToken.init()
        token.progressBlock = progress
        token.completedBlock = completion
        lock.withLock {
            callbackTokens.append(token)
        }
    }
    
    override func start() {
        lock.withLock {
            let taskURL: URL! = URL.init(string: resourceURL)
            if isCancelled || taskURL == nil || session == nil {
                if !isFinished {
                    isFinished = true
                }
                var error: Error? = nil
                if isCancelled {
                    error = NSError.getPlayerErrorWithCode(code: .downloadCancelled)
                } else if taskURL == nil {
                    error = NSError.getPlayerErrorWithCode(code: .invalidURL)
                } else {
                    error = NSError.getPlayerErrorWithCode(code: .unknown)
                }
                callCompletion(url: resourceURL, destLoc: nil, error: error)
                return
            }
            
            isExecuting = true
            
            downloadTask = session?.downloadTask(with: taskURL)
        }
        
        downloadTask?.resume()
    }
    
    override func cancel() {
        lock.withLock {
            if isCancelled || isFinished {
                return
            }
            super.cancel()
            
            downloadTask?.cancel()
            downloadTask = nil
        
            if isExecuting { isExecuting = false }
            if !isFinished { isFinished = true }
            
            //通知外部已经取消。
            callCompletion(url: resourceURL, destLoc: nil, error: NSError.getPlayerErrorWithCode(code: .downloadCancelled))
            
            reset()
        }
    }
    
    func done() {
        isFinished = true
        isExecuting = false
        reset()
    }
    
    func reset() {
        lock.withLock {
            downloadTask = nil
            callbackTokens.removeAll()
        }
    }
    
    // MARK: CallBack
    func callProgress(url: String, progress: Float) {
        lock.lock()
        let tokens = callbackTokens
        lock.unlock()
        for token in tokens {
            token.progressBlock?(url, progress)
        }
    }
    
    func callCompletion(url: String, destLoc: String?, error: Error?) {
        lock.lock()
        let tokens = callbackTokens
        lock.unlock()
        for token in tokens {
            token.completedBlock?(url, destLoc, error)
        }
    }
    
    // MARK: URLSessionDownloadDelegate
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if isFinished {return}
        
        let resourceURL = resourceURL
        if error != nil {
            callCompletion(url: resourceURL, destLoc: nil, error: NSError.getPlayerErrorWithCode(code: .downloadFailed))
            done()
        } else {
            let destLoc: String = SDVoiceUtils.mappedResourceDownloadedFilePath(url: resourceURL)
            if FileManager.default.fileExists(atPath: destLoc) {
                callCompletion(url: resourceURL, destLoc: destLoc, error: nil)
            } else {
                callCompletion(url: resourceURL, destLoc: nil, error: NSError.getPlayerErrorWithCode(code: .downloadFailed))
            }
            done()
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let destLoc = URL.init(fileURLWithPath: SDVoiceUtils.mappedResourceDownloadedFilePath(url: resourceURL))
        do {
            try FileManager.default.moveItem(at: location, to: destLoc)
        } catch let err {
            print("下载完成，移到文件失败:\(err)")
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else {
            return
        }
        let progress = min(1, Float(totalBytesWritten) / Float(totalBytesExpectedToWrite))
        callProgress(url: resourceURL, progress: progress)
    }
}
