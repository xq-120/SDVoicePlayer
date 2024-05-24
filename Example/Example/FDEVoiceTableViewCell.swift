//
//  FDEVoiceTableViewCell.swift
//  Example
//
//  Created by 薛权 on 2024/5/24.
//

import UIKit
import SnapKit

class FDEVoiceTableViewCell: UITableViewCell {
    
    lazy var voiceView: SYAVoiceTextView = {
        let v = SYAVoiceTextView.init(frame: .zero)
        v.playActionBlk = { [weak self] in
            guard let self = self else {return}
            self.playActionBlk?(self)
        }
        return v
    }()
    
    @objc var playActionBlk: ((FDEVoiceTableViewCell)->Void)? = nil

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.selectionStyle = .none
        self.contentView.addSubview(voiceView)
        voiceView.snp.makeConstraints { make in
            make.leading.equalTo(self.contentView).offset(20)
            make.top.equalTo(self.contentView).offset(20)
            make.bottom.equalTo(self.contentView).offset(-20)
            make.trailing.lessThanOrEqualTo(self.contentView).offset(-20)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.voiceView.stopVoiceAnimate()
    }
    
    func configureView(model: FDEVoiceModel, row: Int) {
        let string = model.content + "--第\(row)个"
        self.voiceView.configureView(voiceURL: model.voiceURL, duration: Int(model.duration), translate: string)
    }
}
