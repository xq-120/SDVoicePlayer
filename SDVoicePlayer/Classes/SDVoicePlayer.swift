//
//  SDVoicePlayer.swift
//  SDVoicePlayer
//
//  Created by xq on 2022/9/22.
//

import Foundation
import AVFoundation
import UIKit
import CommonCrypto
import GCDWeakTimer

public enum SDVoicePlayerStatus: Int {
    case stop
    case playing
    case paused
}

public enum SDVoicePlayerError: Error {
    case unknown
    case downloadFailed
    case decodeFailed
    
    public var localizedDescription: String {
        switch self {
        case .unknown:
            return "未知错误"
        case .downloadFailed:
            return "网络异常，请重试"
        case .decodeFailed:
            return "播放失败，请重试"
        }
    }
}

public class SDVoicePlayer: NSObject, AVAudioPlayerDelegate, URLSessionDownloadDelegate {
    public static let shared = SDVoicePlayer()
    
    private var player: AVAudioPlayer?
    private var playState: SDVoicePlayerStatus = .stop
    public var currentURL: String?
    public var currentTime: TimeInterval {
        var currentTime = 0.0
        if DispatchQueue.getSpecific(key: self.queueKey) != nil {
            currentTime = self.player?.currentTime ?? 0
        } else {
            self.playingQueue.sync {
                currentTime = self.player?.currentTime ?? 0
            }
        }
        return currentTime
    }
    public var duration: TimeInterval = 0
    private var playTimeChanged: ((String?, TimeInterval, TimeInterval) -> Void)?
    private var playCompletion: ((String?, SDVoicePlayerError?) -> Void)?
    private let playingQueue = DispatchQueue.init(label: "com.VoicePlayer.playingSerialQueue")
    private let queueKey = DispatchSpecificKey<Int>()
    private let queueKeyValue = Int(arc4random())
    private var _isPlaying = false
    public var isStopWhenEnterBackground = true
        
    private var timer: GCDWeakTimer?
    
    private var downloadTask: URLSessionDownloadTask?
    private lazy var session: URLSession = URLSession.init(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    
    private override init() {
        super.init()
        
        self.playingQueue.setSpecific(key: queueKey, value: queueKeyValue)
        
        let folderPath = getCacheVoiceDirectory()
        if !FileManager.default.fileExists(atPath: folderPath) {
            try? FileManager.default.createDirectory(at: URL.init(fileURLWithPath: folderPath), withIntermediateDirectories: true)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleEnterBackground(notification:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        if session.category == .playback || session.category == .playAndRecord {
            return
        }
        try? session.setCategory(.playback)
        try? session.setActive(true)
    }
    
    @objc func handleEnterBackground(notification: Notification) {
        if self.isPlaying() && self.isStopWhenEnterBackground {
            self.stop(completion: nil, error: nil)
        }
    }
    
    public func isPlaying() -> Bool {
        var playing = false
        if DispatchQueue.getSpecific(key: self.queueKey) != nil {
            playing = self._isPlaying
        } else {
            self.playingQueue.sync {
                playing = self._isPlaying
            }
        }
        return playing
    }
    
    public func isPlaying(url: String) -> Bool {
        var playing = false
        if DispatchQueue.getSpecific(key: self.queueKey) != nil {
            playing = self._isPlaying && url == self.currentURL
        } else {
            self.playingQueue.sync {
                playing = self._isPlaying && url == self.currentURL
            }
        }
        return playing
    }
    
    //更新回调。比如tableView滚动时，可能需要更新回调
    public func setPlayTimeChanged(block: ((String?, TimeInterval, TimeInterval) -> Void)?) {
        self.playingQueue.async {
            self.playTimeChanged = block
        }
    }
    
    //更新回调。
    public func setPlayCompletion(block: ((String?, SDVoicePlayerError?) -> Void)?) {
        self.playingQueue.async {
            self.playCompletion = block
        }
    }
    
    public func play(voice url: String, playTimeChanged: ((String?, TimeInterval, TimeInterval) -> Void)?, playCompletion: ((String?, SDVoicePlayerError?) -> Void)?) {
        guard let voiceURL = URL.init(string: url) else {return}
        
        self.playingQueue.async {
            //停止当前播放的语音
            let prePlayCompletionBlock = self.playCompletion
            let playURL = self.currentURL
            self.internalStop()
            DispatchQueue.main.async {
                prePlayCompletionBlock?(playURL, nil)
            }
            
            self.currentURL = url
            self.playTimeChanged = playTimeChanged
            self.playCompletion = playCompletion
            self._isPlaying = true
            
            let cachedPath = self.getCachedVoice(for: url)
            if cachedPath != nil {
                let cachedFileURL = URL.init(fileURLWithPath: cachedPath!)
                self.playVoice(fileURL: cachedFileURL)
            } else {
                //取消当前的下载
                self.downloadTask?.cancel()
                self.downloadTask = nil
                self.downloadTask = self.session.downloadTask(with: voiceURL)
                self.downloadTask?.resume()
            }
        }
    }
    
    private func playVoice(fileURL: URL) {
        self.setupAudioSession()
        self.player = try? AVAudioPlayer.init(contentsOf: fileURL)
        self.player?.delegate = self
        self.player?.prepareToPlay()
        self.duration = self.player?.duration ?? 0
        self.play()
    }
    
    private func play(atTime: TimeInterval = 0) {
        if atTime == 0 {
            self.player?.play()
        } else {
            self.player?.play(atTime: atTime)
        }
        self.playState = .playing
        self.startTimer()
    }
    
    private func startTimer() {
        if self.timer != nil {
            self.timer?.invalidate()
            self.timer = nil
        }
        self.timer = GCDWeakTimer.init(timeInterval: 0.1, target: self, selector: #selector(self.updateProgress), userInfo: nil, repeats: true, dispatchQueue: self.playingQueue)
        self.timer?.start()
    }
    
    private func stopTimer() {
        self.timer?.invalidate()
        self.timer = nil
    }
    
    @objc private func updateProgress() {
        let currentTime = self.player?.currentTime ?? 0
        let duration = self.duration
        let playURL = self.currentURL
        DispatchQueue.main.async {
            self.playTimeChanged?(playURL, currentTime, duration)
        }
    }
    
    public func pause() {
        self.playingQueue.async {
            if self.player == nil {
                return
            }
            self.stopTimer()
            self.player?.pause()
            self.playState = .paused
        }
    }
    
    public func play() {
        self.playingQueue.async {
            if self.player == nil {
                return
            }
            self.play(atTime: 0)
        }
    }
    
    /// 调用stop后，会回调播放完成回调
    public func stop(completion: (()->Void)? = nil) {
        self.stop(completion: completion, error: nil)
    }
    
    private func stop(completion: (()->Void)?, error: SDVoicePlayerError?) {
        self.playingQueue.async {
            let prePlayCompletionBlock = self.playCompletion
            let playURL = self.currentURL
            self.internalStop()
            DispatchQueue.main.async {
                prePlayCompletionBlock?(playURL, error)
                completion?()
            }
        }
    }
    
    private func internalStop() {
        self.stopTimer() //先停定时器
        self.player?.stop()
        self.reset()
    }
    
    private func reset() {
        self.player = nil
        self.playState = .stop
        self._isPlaying = false
        
        self.currentURL = nil
        self.duration = 0
        
        self.playTimeChanged = nil
        self.playCompletion = nil
    }

    // MARK: AVAudioPlayerDelegate
    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let err = SDVoicePlayerError.decodeFailed
        self.stop(completion: nil, error: err)
    }
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.stop(completion: nil, error: nil)
    }
    
    // MARK: URLSessionDownloadDelegate
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let url = task.originalRequest?.url else { return }
        self.playingQueue.async {
            if let err = error as? NSError, err.code == NSURLErrorCancelled {
                return
            }
            
            self.downloadTask = nil
            
            if !self._isPlaying || self.currentURL != url.absoluteString {
                return
            }
            
            if error == nil {
                let destLoc = URL.init(fileURLWithPath: self.mappedVoiceFilePath(url: url.absoluteString))
                self.playVoice(fileURL: destLoc)
            } else {
                //下载失败就不用播放,直接stop并回调
                let err = SDVoicePlayerError.downloadFailed
                self.stop(completion: nil, error: err)
            }
            
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let url = downloadTask.originalRequest?.url else { return }
        let destLoc = URL.init(fileURLWithPath: mappedVoiceFilePath(url: url.absoluteString))
        try? FileManager.default.moveItem(at: location, to: destLoc)
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
    }
    
    // MARK: Cache
    public func isVoiceCached(url: String) -> Bool {
        let filePath = mappedVoiceFilePath(url: url)
        return FileManager.default.fileExists(atPath: filePath)
    }
    
    public func getCachedVoice(for url: String) -> String? {
        var filePath: String? = nil
        if isVoiceCached(url: url) {
            filePath = mappedVoiceFilePath(url: url)
        }
        return filePath
    }
    
    private func getCacheVoiceDirectory() -> String {
        let folderPath = "\(NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!)".appendingPathComponent("Voice")
        return folderPath
    }
    
    private func mappedVoiceFilePath(url: String) -> String {
        let filename = url.md5
        let filePath = getCacheVoiceDirectory().appendingPathComponent(filename)
        return filePath
    }
}

fileprivate extension String {
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
}
