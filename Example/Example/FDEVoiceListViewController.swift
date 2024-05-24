//
//  FDEVoiceListViewController.swift
//  Example
//
//  Created by 薛权 on 2024/5/24.
//

import UIKit
import SDVoicePlayer
import YYModel

class FDEVoiceListViewController: FDEBaseViewController, UITableViewDelegate, UITableViewDataSource {
    
    lazy var tableView: UITableView = {
        let tableView = UITableView.init(frame: .zero, style: .plain)
        tableView.tableFooterView = UIView.init()
        tableView.register(FDEVoiceTableViewCell.self, forCellReuseIdentifier: "FDEVoiceTableViewCell")
        tableView.delegate = self
        tableView.dataSource = self
        return tableView
    }()
    
    var dataList: [FDEVoiceModel] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupSubview()
        loadData()
    }
    
    func setupSubview() {
        self.navigationItem.title = "list"
        view.addSubview(tableView)
        tableView.frame = view.frame
    }
    
    func loadData() {
        dataList.removeAll()
        
        dataList = FDEUtils.getVoiceListData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = dataList[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "FDEVoiceTableViewCell", for: indexPath) as! FDEVoiceTableViewCell
        cell.configureView(model: item, row: indexPath.row)
        cell.playActionBlk = { [weak self] sender in
            guard let self = self else {return}
            self.handlePlayVoice(with: sender, model: item)
        }
        if SDVoicePlayer.shared.isPlaying(url: item.voiceURL) {
//            let playTimeChangedBlock = playTimeChangedBlock()
//            let playCompletionBlock = playCompletionBlock()
//            SDVoicePlayer.shared.setPlayTimeChanged(block: playTimeChangedBlock)
//            SDVoicePlayer.shared.setPlayCompletion(block: playCompletionBlock)
//            cell.voiceView.startVoiceAnimate()
        }
        return cell
    }
    
    func handlePlayVoice(with cell: FDEVoiceTableViewCell, model: FDEVoiceModel) {
        if SDVoicePlayer.shared.isPlaying(url: model.voiceURL) {
            SDVoicePlayer.shared.stop()
        } else {
            if !SDVoicePlayer.shared.isVoiceCached(url: model.voiceURL) {
                cell.voiceView.startLoading()
            } else {
                cell.voiceView.startVoiceAnimate()
            }
            
            SDVoicePlayer.shared.play(voice: model.voiceURL, downloadProgress: { [weak cell] voiceURL, progress in
                guard let cell = cell else {return}
                
            }, voiceConvertHandler: nil, playTimeChanged: { [weak cell] voiceURL, currentTime, duration in
                guard let cell = cell else {return}
                cell.voiceView.startVoiceAnimate()
                
                if voiceURL != model.voiceURL {
                    cell.voiceView.stopVoiceAnimate()
                    return
                }
                let serverDuration: Double = duration
                cell.voiceView.durationLabel.text = "\(Int(max(0, serverDuration - currentTime)))s"
            }) { [weak cell] voiceURL, err in
                guard let cell = cell else {return}
                
                cell.voiceView.stopVoiceAnimate()
                cell.voiceView.durationLabel.text = "\(Int(model.duration))s"
                
                if voiceURL != model.voiceURL {
                    return
                }
                if err != nil {
                    DLog("error:\(err!.localizedDescription)")
                }
            }
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
}
