//
//  SDVoicePlayer.swift
//  SDVoicePlayer
//
//  Created by uzzi on 2022/9/22.
//

import Foundation
import AVFoundation
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

@objc public class SDVoicePlayer: NSObject, AVAudioPlayerDelegate {
    
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
    @objc public var defaultVoiceConvertBlock: ((_ voiceURL: String, _ filePath: String) -> String?)?
    
    private var playTimeChanged: ((_ voiceURL: String?, _ currentTime: TimeInterval, _ duration: TimeInterval) -> Void)?
    
    private var playCompletion: ((_ voiceURL: String?, _ error: Error?) -> Void)?
    
    private let playerQueue = DispatchQueue.init(label: "com.VoicePlayer.playerSerialQueue")
    
    @objc public var isStopWhenEnterBackground = true
        
    private var timer: GCDWeakTimer?
    
    private lazy var resourceManager: SDResourceManager = SDResourceManager.shared
    
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
            self.stop(with: nil)
        }
    }
    
    @objc public func isPlaying() -> Bool {
        return playerQueue.syncSafe { self._isPlaying }
    }
    
    @objc public func isPlaying(url: String) -> Bool {
        return playerQueue.syncSafe { self._isPlaying && url == self.currentURL }
    }
    
    @objc public func isDownloading(url: String) -> Bool {
        return playerQueue.syncSafe { url == self.currentURL }
    }
    
    // 更新回调。
    @objc public func setPlayTimeChanged(block: ((_ voiceURL: String?, _ currentTime: TimeInterval, _ duration: TimeInterval) -> Void)?) {
        self.playerQueue.async {
            self.playTimeChanged = block
        }
    }
    
    // 更新回调。
    @objc public func setPlayCompletion(block: ((_ voiceURL: String?, _ err: Error?) -> Void)?) {
        self.playerQueue.async {
            self.playCompletion = block
        }
    }
    
    @objc public func play(voiceURL: String,
                           playTimeChanged: ((_ voiceURL: String?, _ currentTime: TimeInterval, _ duration: TimeInterval) -> Void)?,
                           playCompletion: ((_ voiceURL: String?, _ error: Error?) -> Void)?) {
        self.play(voiceURL: voiceURL,
                  downloadProgress: nil,
                  voiceConvertBlock: nil,
                  playTimeChanged: playTimeChanged,
                  playCompletion: playCompletion)
    }
    
    @objc public func play(voiceURL: String,
                           downloadProgress: ((_ voiceURL: String, _ progress: Float) -> Void)?,
                           voiceConvertBlock: ((_ voiceURL: String, _ srcPath: String) -> String?)?,
                           playTimeChanged: ((_ voiceURL: String?, _ currentTime: TimeInterval, _ duration: TimeInterval) -> Void)?,
                           playCompletion: ((_ voiceURL: String?, _ error: Error?) -> Void)?) {
        self.playerQueue.async {
            //停止当前播放的语音
            let prePlayCompletion = self.playCompletion
            let prePlayURL = self.currentURL
            self.internalStop()
            DispatchQueue.main.async {
                prePlayCompletion?(prePlayURL, nil)
            }
            
            self.currentURL = voiceURL
            self.playTimeChanged = playTimeChanged
            self.playCompletion = playCompletion
            self._isPlaying = true
            
            if !voiceURL.lowercased().hasPrefix("http") { //播放本地文件
                let playURL = URL.init(fileURLWithPath: voiceURL)
                self.playVoice(fileURL: playURL)
            } else if let cachedPath = self.resourceManager.getCachedVoice(for: voiceURL) { //播放缓存
                let playURL = URL.init(fileURLWithPath: cachedPath)
                self.playVoice(fileURL: playURL)
            } else if let _ = URL.init(string: voiceURL) {
                // 取消之前的下载
                self.resourceManager.cancelDownload(resourceURL: prePlayURL ?? "")
                
                // 下载现在的语音
                let convertBlk = voiceConvertBlock ?? self.defaultVoiceConvertBlock
                self.resourceManager.loadResource(resourceURL: voiceURL, progress: downloadProgress, convert: convertBlk) { [weak self] resourceURL, filePath, error in
                    guard let self = self else { return }
                    
                    self.playerQueue.async {
                        if !self._isPlaying || self.currentURL != resourceURL {
                            return
                        }
                        
                        if let fp = filePath {
                            let fileURL = URL.init(fileURLWithPath: fp)
                            self.playVoice(fileURL: fileURL)
                        } else {
                            //下载失败就不用播放,直接stop并回调
                            self.internalStop()
                            DispatchQueue.main.async {
                                playCompletion?(self.currentURL, error)
                            }
                        }
                    }
                }
            } else {
                self.internalStop()
                DispatchQueue.main.async {
                    playCompletion?(voiceURL, NSError.getPlayerErrorWithCode(code: .invalidURL))
                }
            }
        }
    }
    
    private func playVoice(fileURL: URL) {
        self.player = try? AVAudioPlayer.init(contentsOf: fileURL)
        if self.player == nil {
            self.stop(with: NSError.getPlayerErrorWithCode(code: .decodeFailed))
            return
        }
        self.setupAudioSession()
        self.player?.delegate = self
        self.player?.prepareToPlay()
        self.duration = self.player?.duration ?? 0
        self.play(atTime: 0)
    }
    
    private func play(atTime: TimeInterval = 0) {
        guard let player = self.player else { return }
        
        if atTime == 0 {
            player.play()
        } else {
            player.play(atTime: atTime)
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
    
    @objc public func play() {
        self.playerQueue.async {
            if self.player == nil {
                return
            }
            self.play(atTime: 0)
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
    
    @objc public func stop() {
        self.stop(with: nil)
    }
    
    private func stop(with error: Error?) {
        self.playerQueue.async {
            let playCompletion = self.playCompletion
            let playURL = self.currentURL
            self.internalStop()
            DispatchQueue.main.async {
                playCompletion?(playURL, error)
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
        self.stop(with: NSError.getPlayerErrorWithCode(code: .decodeFailed))
    }
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.stop(with: nil)
    }
}

extension NSError {
    static func errorWithDomain(domain: String, code: Int, description: String) -> NSError {
        let err = NSError.init(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: description])
        return err
    }
}

extension NSError {
    static func getPlayerErrorWithCode(code: SDVoicePlayerError) -> NSError {
        return NSError.errorWithDomain(domain: kErrorDomain, code: code.rawValue, description: kPlayErrorDesc)
    }
}
