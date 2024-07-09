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
        
//        cell.playActionBlk = { [weak self] sender in
//            guard let self = self else {return}
//            self.handlePlayVoice(with: sender, model: item)
//        }
//        if SDVoicePlayer.shared.isPlaying(url: item.voiceURL) { //
//            let playTimeChangedBlk = getPlayTimeChangedBlock(with: cell)
//            let PlayCompletionBlk = getPlayCompletionBlock(with: cell)
//            SDVoicePlayer.shared.setPlayTimeChanged(block: playTimeChangedBlk)
//            SDVoicePlayer.shared.setPlayCompletion(block: PlayCompletionBlk)
//            cell.voiceView.startVoiceAnimate()
//        }
        
        cell.playActionBlk = { [weak self] sender in
            guard let self = self else {return}
            self.handlePlayVoiceV2(with: sender, model: item)
        }
        if SDVoicePlayer.shared.isPlaying(url: item.voiceURL) {
            cell.voiceView.startVoiceAnimate()
        }
        return cell
    }
    
    func handlePlayVoiceV2(with cell: FDEVoiceTableViewCell, model: FDEVoiceModel) {
        if SDVoicePlayer.shared.isPlaying(url: model.voiceURL) {
            SDVoicePlayer.shared.stop()
        } else {
            if !SDVoicePlayer.shared.isVoiceCached(url: model.voiceURL) {
                cell.voiceView.startLoading()
            } else {
                cell.voiceView.startVoiceAnimate()
            }
            
            SDVoicePlayer.shared.play(voice: model.voiceURL, downloadProgress: nil, voiceConvertHandler: nil) { [weak self] voiceURL, currentTime, duration in
                guard let self = self else {
                    return
                }
                guard let destCell = self.getCell(with: model) else { //根据model获取正确行的cell。如果cell不在屏幕上则会返回nil。
                    return
                }
                if destCell.voice?.voiceURL != voiceURL { //这里基本上不会进来，因为cellForRow里有赋值voice。
                    DLog("语音不一致，destCell：\(destCell.getCellAdrress())")
                    return
                }
                destCell.voiceView.startVoiceAnimate()
                let serverDuration: Double = model.duration
                destCell.voiceView.durationLabel.text = "\(Int(ceil(max(0, serverDuration - currentTime))))s"
            } playCompletion: { [weak self] voiceURL, err in
                guard let self = self else {
                    return
                }
                guard let destCell = self.getCell(with: model) else {
                    return
                }
                if destCell.voice?.voiceURL != voiceURL {
                    DLog("语音不一致，destCell：\(destCell.getCellAdrress())")
                    return
                }
                destCell.voiceView.stopVoiceAnimate()
                destCell.voiceView.durationLabel.text = "\(Int(model.duration))s"
            }
        }
    }
    
    func getCell(with voice: FDEVoiceModel) -> FDEVoiceTableViewCell? {
        guard let voiceIndex = self.dataList.firstIndex(of: voice) else {return nil}
        let indexPath = IndexPath(row: voiceIndex, section: 0)
        let cell = self.tableView.cellForRow(at: indexPath) as? FDEVoiceTableViewCell
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
            let playTimeChangedBlk = getPlayTimeChangedBlock(with: cell)
            let PlayCompletionBlk = getPlayCompletionBlock(with: cell)
            SDVoicePlayer.shared.play(voice: model.voiceURL, downloadProgress: nil, voiceConvertHandler: nil, playTimeChanged: playTimeChangedBlk, playCompletion: PlayCompletionBlk)
        }
    }
    
    func getPlayTimeChangedBlock(with cell: FDEVoiceTableViewCell) -> ((_ voiceURL: String?, _ currentTime: TimeInterval, _ duration: TimeInterval) -> Void) {
        let block: ((_ voiceURL: String?, _ currentTime: TimeInterval, _ duration: TimeInterval) -> Void) = { [weak self, weak cell] voiceURL, currentTime, duration in
            guard let self = self, let cell = cell else {return}
            let indexPath = self.tableView.indexPath(for: cell)
            if indexPath == nil {
                return
            }
            let item = self.dataList[indexPath!.row]
            if voiceURL != item.voiceURL {
                return
            }
            cell.voiceView.startVoiceAnimate()
            let serverDuration: Double = item.duration
            cell.voiceView.durationLabel.text = "\(Int(ceil(max(0, serverDuration - currentTime))))s"
        }
        return block
    }
    
    func getPlayCompletionBlock(with cell: FDEVoiceTableViewCell) -> ((_ voiceURL: String?, _ err: Error?) -> Void) {
        let block: ((_ voiceURL: String?, _ err: Error?) -> Void) = { [weak self, weak cell] voiceURL, err in
            guard let self = self, let cell = cell else {return}
            if err != nil {
                DLog("error:\(err!.localizedDescription)")
            }
            let indexPath = self.tableView.indexPath(for: cell)
            if indexPath == nil {
                return
            }
            let item = self.dataList[indexPath!.row]
            if voiceURL != item.voiceURL {
                return
            }
            cell.voiceView.stopVoiceAnimate()
            cell.voiceView.durationLabel.text = "\(Int(item.duration))s"
        }
        return block
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
}
