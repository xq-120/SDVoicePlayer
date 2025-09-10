//
//  SDVoiceDownloadOperation.swift
//  SDVoicePlayer
//
//  Created by 薛权 on 2025/9/7.
//

import Foundation

class SDVoiceDownloadOperation: Operation, URLSessionDownloadDelegate, @unchecked Sendable {
    var voiceURL: URL?
    
    var progress: ((_ voiceURL: String?, _ progress: Float) -> Void)?
    
    var completion: ((_ voiceURL: String?, _ filePath: String?, _ error: Error?) -> Void)?
    
    private weak var session: URLSession?
    
    private var downloadTask: URLSessionDownloadTask?
    
    private let lock = NSRecursiveLock()
    
    private var _executing: Bool = false
    
    private var _finished: Bool = false

    override private(set) var isExecuting: Bool {
        get { lock.withLock { _executing } }
        set {
            lock.withLock {
                willChangeValue(forKey: "isExecuting")
                _executing = newValue
                didChangeValue(forKey: "isExecuting")
            }
        }
    }

    override private(set) var isFinished: Bool {
        get { lock.withLock { _finished } }
        set {
            lock.withLock {
                willChangeValue(forKey: "isFinished")
                _finished = newValue
                didChangeValue(forKey: "isFinished")
            }
        }
    }
    
    override var isAsynchronous: Bool {
        return true
    }
    
    init(voiceURL: URL? = nil, progress: ((_: String?, _: Float) -> Void)? = nil, completion: ((_: String?, _: String?, _: Error?) -> Void)? = nil, session: URLSession? = nil) {
        self.voiceURL = voiceURL
        self.progress = progress
        self.completion = completion
        self.session = session
    }
    
    override func start() {
        guard let session = self.session, let voiceURL = self.voiceURL else {
            completion?(self.voiceURL?.absoluteString, nil, NSError.getErrorWithCode(code: .invalidURL))
            return
        }
        
        lock.withLock {
            if isCancelled {
                if !isFinished {
                    isFinished = true
                }
                completion?(voiceURL.absoluteString, nil, NSError.getErrorWithCode(code: .downloadCancelled))
                return
            }
            
            isExecuting = true
            
            downloadTask = session.downloadTask(with: voiceURL)
        }
        
        downloadTask?.resume()
    }
    
    override func cancel() {
        lock.withLock {
            if isCancelled || isFinished {
                return
            }
            super.cancel() //super.cancel() 是线程安全，随便在哪个线程调用都行。你自己扩展的逻辑要保证线程安全。
            
            downloadTask?.cancel()
            downloadTask = nil
        
            if isExecuting { isExecuting = false }
            if !isFinished { isFinished = true }
            
            //通知外部已经取消。
            completion?(voiceURL?.absoluteString, nil, NSError.getErrorWithCode(code: .downloadCancelled))
            
            reset()
        }
    }
    
    func done() {
        isFinished = true
        isExecuting = false
        reset()
    }
    
    func reset() {
        downloadTask = nil
        progress = nil
        completion = nil
    }
    
    // MARK: URLSessionDownloadDelegate
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let url = self.voiceURL else { return }
        if let err = error as? NSError, err.code == NSURLErrorCancelled {
            return
        }
        
        lock.withLock {
            if error != nil {
                completion?(url.absoluteString, nil, NSError.getErrorWithCode(code: .downloadFailed))
            } else {
                let destLoc = URL.init(fileURLWithPath: SDVoiceUtils.mappedVoiceFilePath(url: url.absoluteString))
                completion?(url.absoluteString, destLoc.absoluteString, nil)
            }
            done()
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let url = self.voiceURL else { return }
        let destLoc = URL.init(fileURLWithPath: SDVoiceUtils.mappedVoiceFilePath(url: url.absoluteString))
        try? FileManager.default.moveItem(at: location, to: destLoc)
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let url = self.voiceURL else { return }
        let progress = min(1, Float(totalBytesWritten) / Float(totalBytesExpectedToWrite))
        self.progress?(url.absoluteString, progress)
    }
}
