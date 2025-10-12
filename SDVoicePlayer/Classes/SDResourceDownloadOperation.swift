//
//  SDResourceDownloadOperation.swift
//  SDVoicePlayer
//
//  Created by uzzi on 2025/9/7.
//

import Foundation

class SDResourceDownloadOperation: Operation, URLSessionDownloadDelegate, @unchecked Sendable {
    var resourceURL: URL
    
    var progressBlk: ((_ resourceURL: String?, _ progress: Float) -> Void)?
    
    var convertBlk: ((_ resourceURL: String?, _ filePath: String?) -> String?)?
    
    var completionBlk: ((_ resourceURL: String?, _ filePath: String?, _ error: Error?) -> Void)?
    
    private weak var session: URLSession?
    
    private var downloadTask: URLSessionDownloadTask?
    
    private let lock = NSRecursiveLock()
    
    private var _executing: Bool = false
    
    private var _finished: Bool = false

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
    
    init(resourceURL: URL,
         progress: ((_: String?, _: Float) -> Void)? = nil,
         convert: ((_ resourceURL: String?, _ filePath: String?) -> String?)? = nil,
         completion: ((_: String?, _: String?, _: Error?) -> Void)? = nil,
         session: URLSession? = nil) {
        self.resourceURL = resourceURL
        self.progressBlk = progress
        self.convertBlk = convert
        self.completionBlk = completion
        self.session = session
    }
    
    override func start() {
        lock.withLock {
            if isCancelled || session == nil {
                if !isFinished {
                    isFinished = true
                }
                let error = session == nil ? NSError.getErrorWithCode(code: .unknown) : NSError.getErrorWithCode(code: .downloadCancelled)
                completionBlk?(resourceURL.absoluteString, nil, error)
                return
            }
            
            isExecuting = true
            
            downloadTask = session?.downloadTask(with: resourceURL)
        }
        
        downloadTask?.resume()
    }
    
    override func cancel() {
        lock.withLock {
            if isCancelled || isFinished {
                return
            }
            super.cancel() //super.cancel() 是线程安全，随便在哪个线程调用都行。自己扩展的逻辑要保证线程安全。
            
            downloadTask?.cancel()
            downloadTask = nil
        
            if isExecuting { isExecuting = false }
            if !isFinished { isFinished = true }
            
            //通知外部已经取消。
            completionBlk?(resourceURL.absoluteString, nil, NSError.getErrorWithCode(code: .downloadCancelled))
            
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
            progressBlk = nil
            convertBlk = nil
            completionBlk = nil
        }
    }
    
    // MARK: URLSessionDownloadDelegate
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if isFinished {return}
        
        let completionBlk = completionBlk
        let resourceURL = resourceURL
        if error != nil {
            DispatchQueue.main.async {
                completionBlk?(resourceURL.absoluteString, nil, NSError.getErrorWithCode(code: .downloadFailed))
            }
            done()
        } else {
            var destLoc: String = SDVoiceUtils.mappedResourceFilePath(url: resourceURL.absoluteString)
            if let convertBlk = convertBlk, let convertedPath = convertBlk(resourceURL.absoluteString, destLoc) {
                //替换掉之前的缓存
                try? FileManager.default.moveItem(atPath: convertedPath, toPath: destLoc)
            }
            DispatchQueue.main.async {
                completionBlk?(resourceURL.absoluteString, destLoc, nil)
            }
            done()
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let destLoc = URL.init(fileURLWithPath: SDVoiceUtils.mappedResourceFilePath(url: resourceURL.absoluteString))
        try? FileManager.default.moveItem(at: location, to: destLoc)
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = min(1, Float(totalBytesWritten) / Float(totalBytesExpectedToWrite))
        self.progressBlk?(resourceURL.absoluteString, progress)
    }
}
