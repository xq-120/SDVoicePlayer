//
//  FDEDetailViewController.swift
//  Example
//
//  Created by xq on 2022/9/30.
//

import UIKit
import SDVoicePlayer

struct VoiceModel {
    var duration: Int = 0 //语音文件时长秒
    var voiceURL: String = "" //语音文件地址
}

class FDEDetailViewController: FDEBaseViewController {
    
    var voice: VoiceModel?
    
    lazy var timeLabel = { () -> UILabel in
        let lb = UILabel()
        lb.text = ""
        lb.textAlignment = .center
        lb.textColor = UIColor.black
        lb.backgroundColor = .lightGray
        return lb
    }()
    
    lazy var btn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.frame = CGRect.init(x: 0, y: 0, width: 100, height: 44)
        btn.setTitle("play", for: .normal)
        btn.backgroundColor = .red
        btn.addTarget(self, action: #selector(btnDidClicked(_:)), for: .touchUpInside)
        return btn
    }()

    deinit {
        SDVoicePlayer.shared.stop()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        voice = VoiceModel.init(duration: 10, voiceURL: "http://res.dudufm.com/voice/profile/2a76e73a404a40d49d7cc5ed89eb6239.aac")
        
        setupSubview()
    }
    
    func setupSubview() {
        self.navigationItem.title = "detail"
        view.addSubview(btn)
        btn.center = self.view.center
        
        self.timeLabel.frame = CGRect.init(x: (self.view.frame.width - 100) / 2.0, y: 100, width: 100, height: 44)
        view.addSubview(timeLabel)
        self.timeLabel.text = "\(self.voice?.duration ?? 0)s"
    }

    @objc func btnDidClicked(_ sender: UIButton) {
        DLog("btnDidClicked")
        handlePlayVoiceClicked(self.voice!)
    }
    
    private func handlePlayVoiceClicked(_ voice: VoiceModel) {
        if SDVoicePlayer.shared.isPlaying(url: voice.voiceURL) {
            SDVoicePlayer.shared.stop()
            DLog("停止播放")
        } else {
            //开始动画
            DLog("开始播放")
            let playTimeChangedBlock = playTimeChangedBlock()
            let playCompletionBlock = playCompletionBlock()
            SDVoicePlayer.shared.play(voice: voice.voiceURL, voiceConvertHandler: nil, playTimeChanged: playTimeChangedBlock, playCompletion: playCompletionBlock)
        }
    }
    
    private func playTimeChangedBlock() -> ((String?, TimeInterval, TimeInterval) -> Void)? {
        let block: ((String?, TimeInterval, TimeInterval) -> Void)? = { [weak self] (currentURL, curr, duration) in
            guard let self = self else {
                return
            }
            if currentURL != self.voice?.voiceURL {
                //停止动画
                return
            }
            var serverDuration: Double = Double(self.voice?.duration ?? 0)
            if serverDuration == 0 {
                serverDuration = duration
            }
            let text = "\(Int(max(0, serverDuration - curr)))s"
            //更新时间
            self.timeLabel.text = text
        }
        return block
    }
    
    private func playCompletionBlock() -> ((String?, Error?) -> Void)? {
        let block: ((String?, Error?) -> Void)? = { [weak self] (currentURL, error) in
            guard let self = self else {
                return
            }
            DLog("播放完成")
            if currentURL != self.voice?.voiceURL {
                //停止动画
                return
            }
            if error != nil {
                DLog(error?.localizedDescription ?? "")
            }
            //停止动画
            self.timeLabel.text = "\(self.voice?.duration ?? 0)s"
        }
        
        return block
    }
}

