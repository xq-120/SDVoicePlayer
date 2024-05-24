//
//  SYAVoiceTextView.swift
//  Syachat
//
//  Created by 萝卜 on 2024/2/29.
//

import UIKit
import SDWebImage
import SnapKit

private let kMinVoiceBgView = 54.0
private let kMaxVoiceBgView = 54.0 * 2
private let kVoiceDurationStep = 5.0

class SYAVoiceTextView: UIView {

    private lazy var contentLabel: ZAELabel = {
        let label = ZAELabel.init()
        label.textAlignment = NSTextAlignment.left
        label.textColor = UIColor.black
        label.font = UIFont.systemFont(ofSize: 16)
        label.backgroundColor = UIColor.clear
        label.numberOfLines = 0
        return label
    }()
    
    @objc lazy var contentBgView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.lightGray
        v.layer.cornerRadius = 16
        v.layer.masksToBounds = true
        return v
    }()
    
    private lazy var voiceBgView: UIView = {
        let v = UIView.init(frame: .zero)
        v.backgroundColor = UIColor.cyan
        v.layer.cornerRadius = 14
        v.layer.masksToBounds = true
        return v
    }()
    
    private lazy var playBtn: UIButton = {
        let button = UIButton.init(type: .custom)
        button.addTarget(self, action: #selector(playBtnDidClicked(sender:)), for: .touchUpInside)
        return button
    }()
    
    private lazy var speakView: UIImageView = {
        let v = UIImageView.init()
        v.animationDuration = 1.5
        v.animationRepeatCount = Int.max
        v.image = voiceStopImage
        return v
    }()
    
    private lazy var activityView: UIActivityIndicatorView = {
        var v: UIActivityIndicatorView!
        if #available(iOS 13.0, *) {
            v = UIActivityIndicatorView.init(style: .medium)
        } else {
            // Fallback on earlier versions
            v = UIActivityIndicatorView.init(style: .white)
        }
        v.color = UIColor.init(red: 90/255.0, green: 90/255.0, blue: 90/255.0, alpha: 1)
        v.isHidden = true
        return v
    }()
    
    lazy var durationLabel: UILabel = {
        let label = UILabel.init()
        label.textAlignment = NSTextAlignment.center
        label.textColor = UIColor.init(red: 192/255.0, green: 124/255.0, blue: 16/255.0, alpha: 1)
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        return label
    }()
    
    private lazy var playAnimateImages: [UIImage] = {
        var arr = ["icon_voice_left_0", "icon_voice_left_1", "icon_voice_left_2"].compactMap { imgName in
            return UIImage.init(named: imgName)
        }
        return arr
    }()
    
    private var voiceStopImage: UIImage? {
        return UIImage.init(named: "home_play")
    }
    
   @objc var playActionBlk: (()->Void)? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(contentBgView)
        contentBgView.addSubview(contentLabel)
        addSubview(voiceBgView)
        voiceBgView.addSubview(playBtn)
        voiceBgView.addSubview(speakView)
        voiceBgView.addSubview(durationLabel)
        voiceBgView.addSubview(activityView)

        voiceBgView.snp.makeConstraints { make in
            make.leading.top.equalTo(self)
            make.width.equalTo(60)
            make.height.equalTo(28)
        }
        contentBgView.snp.makeConstraints { make in
            make.leading.bottom.equalTo(self).offset(0)
            make.trailing.lessThanOrEqualTo(self).offset(0)
            make.top.equalTo(self.voiceBgView.snp.bottom).offset(-14)
        }
        
        contentLabel.snp.makeConstraints { make in
            make.leading.equalTo(self.contentBgView).offset(15)
            make.trailing.equalTo(self.contentBgView).offset(-15)
            make.top.equalTo(self.contentBgView).offset(15)
            make.bottom.equalTo(self.contentBgView).offset(-15)
        }
        speakView.snp.makeConstraints { make in
            make.size.equalTo(CGSize(width: 12, height: 12))
            make.centerY.equalTo(self.voiceBgView)
            make.leading.equalTo(self.voiceBgView).offset(12)
        }
        durationLabel.snp.makeConstraints { make in
            make.leading.equalTo(self.speakView.snp.trailing).offset(6)
            make.centerY.equalTo(self.voiceBgView)
        }
        playBtn.snp.makeConstraints { make in
            make.edges.equalTo(self.voiceBgView).inset(UIEdgeInsets.zero)
        }
        activityView.snp.makeConstraints { make in
            make.center.equalTo(voiceBgView)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func playBtnDidClicked(sender: UIButton) {
        playActionBlk?()
    }
    
    @objc func configureView(voiceURL: String, duration: NSInteger, translate: String) {
        durationLabel.text = "\(duration)s"
        contentLabel.text = translate
    }
    
    @objc func startLoading() {
        self.activityView.isHidden = false
        self.activityView.startAnimating()
        self.speakView.isHidden = true
        self.durationLabel.isHidden = true
    }
    
    @objc func stopLoading() {
        self.activityView.isHidden = true
        self.activityView.stopAnimating()
        self.speakView.isHidden = false
        self.durationLabel.isHidden = false
    }
    
    @objc func startVoiceAnimate() {
        stopLoading()
        if (self.speakView.isAnimating) {
            return;
        }
        self.speakView.animationImages = self.playAnimateImages
        self.speakView.startAnimating()
    }

    @objc func stopVoiceAnimate() {
        stopLoading()
        if (!self.speakView.isAnimating) {
            return;
        }
        self.speakView.stopAnimating()
        self.speakView.image = self.voiceStopImage
    }
}
