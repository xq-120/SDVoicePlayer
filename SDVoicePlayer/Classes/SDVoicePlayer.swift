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
    case downloadFailed
    case decodeFailed
}

@objc public class SDVoicePlayer: NSObject, AVAudioPlayerDelegate, URLSessionDownloadDelegate {
    @objc public static let shared = SDVoicePlayer()
    
    private var player: AVAudioPlayer?
    private var playState: SDVoicePlayerStatus = .stop
    @objc public var currentURL: String?
    @objc public var currentTime: TimeInterval {
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
    @objc public var duration: TimeInterval = 0
    private var playTimeChanged: ((String?, TimeInterval, TimeInterval) -> Void)?
    private var voiceConvertHandler: ((_ voiceURL: String?, _ srcPath:String?) -> String?)?
    private var playCompletion: ((String?, Error?) -> Void)?
    private let playingQueue = DispatchQueue.init(label: "com.VoicePlayer.playingSerialQueue")
    private let queueKey = DispatchSpecificKey<Int>()
    private let queueKeyValue = Int(arc4random())
    private var _isPlaying = false
    @objc public var isStopWhenEnterBackground = true
        
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
    
    @objc public func isPlaying(url: String) -> Bool {
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
    @objc public func setPlayTimeChanged(block: ((String?, TimeInterval, TimeInterval) -> Void)?) {
        self.playingQueue.async {
            self.playTimeChanged = block
        }
    }
    
    //更新回调。
    @objc public func setPlayCompletion(block: ((String?, Error?) -> Void)?) {
        self.playingQueue.async {
            self.playCompletion = block
        }
    }
    
    @objc public func play(voice url: String,
                           voiceConvertHandler: ((_ voiceURL: String?, _ srcPath:String?) -> String?)?,
                           playTimeChanged: ((String?, TimeInterval, TimeInterval) -> Void)?,
                           playCompletion: ((String?, Error?) -> Void)?) {
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
            self.voiceConvertHandler = voiceConvertHandler
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
    
    @objc public func pause() {
        self.playingQueue.async {
            if self.player == nil {
                return
            }
            self.stopTimer()
            self.player?.pause()
            self.playState = .paused
        }
    }
    
    @objc public func play() {
        self.playingQueue.async {
            if self.player == nil {
                return
            }
            self.play(atTime: 0)
        }
    }
    
    /// 调用stop后，会回调播放完成回调
    @objc public func stop(completion: (()->Void)? = nil) {
        self.stop(completion: completion, error: nil)
    }
    
    private func stop(completion: (()->Void)?, error: Error?) {
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
        self.voiceConvertHandler = nil
    }

    // MARK: AVAudioPlayerDelegate
    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let err = NSError.init(domain: "com.SDVoicePlayer.www", code: SDVoicePlayerError.decodeFailed.rawValue, userInfo: [NSLocalizedDescriptionKey: "播放失败，请重试"])
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
                var srcFilePath = self.mappedVoiceFilePath(url: url.absoluteString)
                if let convertedVoicePath = self.voiceConvertHandler?(self.currentURL, srcFilePath), convertedVoicePath != srcFilePath {
                    //替换掉之前的缓存
                    try? FileManager.default.moveItem(atPath: convertedVoicePath, toPath: srcFilePath)
                }
                let destLoc = URL.init(fileURLWithPath: srcFilePath)
                self.playVoice(fileURL: destLoc)
            } else {
                //下载失败就不用播放,直接stop并回调
                let err = NSError.init(domain: "com.SDVoicePlayer.www", code: SDVoicePlayerError.downloadFailed.rawValue, userInfo: [NSLocalizedDescriptionKey: "网络异常，请重试"])
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
    @objc public func isVoiceCached(url: String) -> Bool {
        let filePath = mappedVoiceFilePath(url: url)
        return FileManager.default.fileExists(atPath: filePath)
    }
    
    @objc public func getCachedVoice(for url: String) -> String? {
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
    
    private func getResourceExtensionName(url: String) -> String? {
        var url = url
        var file: String = ""
        if var idx = url.lastIndex(of: "/") {
            idx = url.index(idx, offsetBy: 1)
            file = String(url[idx...])
        }
        if var idx = file.lastIndex(of: ".") {
            idx = file.index(idx, offsetBy: 1)
            let ext = String(file[idx...])
            return ext.count == 0 ? nil : ext
        } else {
            return nil
        }
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
