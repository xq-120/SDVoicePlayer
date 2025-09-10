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

@objc public enum SDVoicePlayerStatus: Int {
    case stop
    case playing
    case paused
}

@objc public enum SDVoicePlayerError: Int {
    case unknown
    case invalidURL
    case downloadFailed
    case downloadCancelled
    case decodeFailed
}

private let kErrorDomain = "com.SDVoicePlayer.www"
private let kPlayErrorDesc = "播放失败，请重试"

@objc public class SDVoicePlayer: NSObject, AVAudioPlayerDelegate, URLSessionDownloadDelegate {
    @objc public static let shared = SDVoicePlayer()
    
    private var player: AVAudioPlayer?
    
    private var playState: SDVoicePlayerStatus = .stop
    
    private var _isPlaying = false
    
    @objc public var currentURL: String?
    
    @objc public var currentTime: TimeInterval {
        return playerQueue.syncSafe { self.player?.currentTime ?? 0 }
    }
    @objc public var duration: TimeInterval = 0
    
    /// 下载完成后默认的转换处理
    @objc public var defaultVoiceConvertHandler: ((_ voiceURL: String?, _ srcPath: String?) -> String?)?
    
    private var voiceConvertHandler: ((_ voiceURL: String?, _ srcPath: String?) -> String?)?
    
    private var playTimeChanged: ((_ voiceURL: String?, _ currentTime: TimeInterval, _ duration: TimeInterval) -> Void)?
    
    private var playCompletion: ((_ voiceURL: String?, _ err: Error?) -> Void)?
    
    private var downloadProgress: ((_ voiceURL: String?, _ progress: Float) -> Void)?
    
    private let playerQueue = DispatchQueue.init(label: "com.VoicePlayer.playerSerialQueue")
    
    @objc public var isStopWhenEnterBackground = true
        
    private var timer: GCDWeakTimer?
    
    private var downloadTask: URLSessionDownloadTask?
    private lazy var session: URLSession = URLSession.init(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    
    private lazy var downloadManager: SDVoiceDownloadManager = SDVoiceDownloadManager.shared
    
    private lazy var cacheManager: SDVoiceCacheManager = SDVoiceCacheManager.shared
    
    private override init() {
        super.init()
        
        playerQueue.setAsSpecific()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleEnterBackground(notification:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        //坑：如果之前是playAndRecord，这里必须得设置为playback。要不然没声音。
        try? session.setCategory(.playback)
        try? session.setActive(true)
    }
    
    @objc func handleEnterBackground(notification: Notification) {
        if self.isPlaying() && self.isStopWhenEnterBackground {
            self.stop(completion: nil, error: nil)
        }
    }
    
    @objc public func isPlaying() -> Bool {
        return playerQueue.syncSafe { self._isPlaying }
    }
    
    @objc public func isPlaying(url: String) -> Bool {
        return playerQueue.syncSafe { self._isPlaying && url == self.currentURL }
    }
    
    @objc public func isDownloading(url: String) -> Bool {
        return playerQueue.syncSafe { self.downloadTask != nil && url == self.currentURL }
    }
    
    //更新回调。
    @objc public func setPlayTimeChanged(block: ((_ voiceURL: String?, _ currentTime: TimeInterval, _ duration: TimeInterval) -> Void)?) {
        self.playerQueue.async {
            self.playTimeChanged = block
        }
    }
    
    //更新回调。
    @objc public func setPlayCompletion(block: ((_ voiceURL: String?, _ err: Error?) -> Void)?) {
        self.playerQueue.async {
            self.playCompletion = block
        }
    }
    
    @objc public func play(voice url: String,
                           voiceConvertHandler: ((_ voiceURL: String?, _ srcPath: String?) -> String?)?,
                           playTimeChanged: ((_ voiceURL: String?, _ currentTime: TimeInterval, _ duration: TimeInterval) -> Void)?,
                           playCompletion: ((_ voiceURL: String?, _ err: Error?) -> Void)?) {
        
        self.play(voice: url, downloadProgress: nil, voiceConvertHandler: voiceConvertHandler, playTimeChanged: playTimeChanged, playCompletion: playCompletion)
    }
    
    @objc public func play(voice url: String,
                           downloadProgress: ((_ voiceURL: String?, _ progress: Float) -> Void)?,
                           voiceConvertHandler: ((_ voiceURL: String?, _ srcPath: String?) -> String?)?,
                           playTimeChanged: ((_ voiceURL: String?, _ currentTime: TimeInterval, _ duration: TimeInterval) -> Void)?,
                           playCompletion: ((_ voiceURL: String?, _ err: Error?) -> Void)?) {
        self.playerQueue.async {
            //停止当前播放的语音
            let prePlayCompletion = self.playCompletion
            let prePlayURL = self.currentURL
            self.internalStop()
            DispatchQueue.main.async {
                prePlayCompletion?(prePlayURL, nil)
            }
            
            self.currentURL = url
            self.voiceConvertHandler = voiceConvertHandler
            self.playTimeChanged = playTimeChanged
            self.playCompletion = playCompletion
            self.downloadProgress = downloadProgress
            self._isPlaying = true
            
            if !url.lowercased().hasPrefix("http") { //播放本地文件
                let voiceURL = URL.init(fileURLWithPath: url)
                self.playVoice(fileURL: voiceURL)
            } else if let cachedPath = self.cacheManager.getCachedVoice(for: url) { //播放缓存
                let voiceURL = URL.init(fileURLWithPath: cachedPath)
                self.playVoice(fileURL: voiceURL)
            } else if let voiceURL = URL.init(string: url) {
                // 取消之前的下载
                self.downloadManager.cancelDownload(voice: URL.init(string: prePlayURL ?? ""))
                
                // 下载现在的语音
                self.downloadManager.download(voice: voiceURL, progressBlk: downloadProgress) { voiceURL, filePath, error in
                    
                }
            } else {
                self.internalStop()
                DispatchQueue.main.async {
                    playCompletion?(url, NSError.getErrorWithCode(code: .invalidURL))
                }
            }
        }
    }
    
    private func playVoice(fileURL: URL) {
        self.player = try? AVAudioPlayer.init(contentsOf: fileURL)
        if self.player == nil {
            self.stop(completion: nil, error: NSError.getErrorWithCode(code: .decodeFailed))
            return
        }
        self.setupAudioSession()
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
        self.timer = GCDWeakTimer.init(timeInterval: 0.1, target: self, selector: #selector(self.updateProgress), userInfo: nil, repeats: true, dispatchQueue: self.playerQueue)
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
        let playTimeChangedBlk = self.playTimeChanged
        DispatchQueue.main.async {
            playTimeChangedBlk?(playURL, currentTime, duration)
        }
    }
    
    @objc public func pause() {
        self.playerQueue.async {
            if self.player == nil {
                return
            }
            self.stopTimer()
            self.player?.pause()
            self.playState = .paused
        }
    }
    
    @objc public func play() {
        self.playerQueue.async {
            if self.player == nil {
                return
            }
            self.play(atTime: 0)
        }
    }
    
    /// 调用stop后，会回调播放完成回调
    @objc public func stop() {
        self.stop(completion: nil, error: nil)
    }
    
    private func stop(completion: (()->Void)?, error: Error?) {
        self.playerQueue.async {
            let prePlayCompletion = self.playCompletion
            let prePlayURL = self.currentURL
            self.internalStop()
            DispatchQueue.main.async {
                prePlayCompletion?(prePlayURL, error)
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
        self.voiceConvertHandler = nil
        self.downloadProgress = nil
    }

    // MARK: AVAudioPlayerDelegate
    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        self.stop(completion: nil, error: NSError.getErrorWithCode(code: .decodeFailed))
    }
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.stop(completion: nil, error: nil)
    }
    
    // MARK: URLSessionDownloadDelegate
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let url = task.originalRequest?.url else { return }
        self.playerQueue.async {
            if let err = error as? NSError, err.code == NSURLErrorCancelled {
                return
            }
            
            self.downloadTask = nil
            
            if !self._isPlaying || self.currentURL != url.absoluteString {
                return
            }
            
            if error == nil {
                let srcFilePath = SDVoiceUtils.mappedVoiceFilePath(url: url.absoluteString)
                let voiceConvertHandler = self.voiceConvertHandler ?? self.defaultVoiceConvertHandler
                if let convertHandler = voiceConvertHandler, let convertedVoicePath = convertHandler(self.currentURL, srcFilePath), convertedVoicePath != srcFilePath {
                    //替换掉之前的缓存
                    try? FileManager.default.moveItem(atPath: convertedVoicePath, toPath: srcFilePath)
                }
                let destLoc = URL.init(fileURLWithPath: srcFilePath)
                self.playVoice(fileURL: destLoc)
            } else {
                //下载失败就不用播放,直接stop并回调
                self.stop(completion: nil, error: NSError.getErrorWithCode(code: .downloadFailed))
            }
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
    }
}

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
}

extension DispatchQueue {
    private static var specificKey = DispatchSpecificKey<UUID>()
    
    func setAsSpecific() {
        let id = UUID()
        setSpecific(key: DispatchQueue.specificKey, value: id)
    }
    
    private func isCurrentQueue() -> Bool {
        guard let id = getSpecific(key: DispatchQueue.specificKey) else { return false }
        return id == DispatchQueue.getSpecific(key: DispatchQueue.specificKey)
    }
    
    func syncSafe<T>(_ block: () -> T) -> T {
        if isCurrentQueue() {
            return block()
        } else {
            return sync(execute: block)
        }
    }
}

extension NSError {
    static func getErrorWithCode(code: SDVoicePlayerError) -> NSError {
        let err = NSError.init(domain: kErrorDomain, code: code.rawValue, userInfo: [NSLocalizedDescriptionKey: kPlayErrorDesc])
        return err
    }
}
