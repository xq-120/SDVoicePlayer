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
        
        //方案1
        cell.playActionBlk = { [weak self] sender in
            guard let self = self else {return}
            self.handlePlayVoiceV1(cell: sender, model: item, indexPath: indexPath)
        }
        //
        if SDVoicePlayer.shared.isPlaying(url: item.voiceURL) {
            let playTimeChangedBlk = getPlayTimeChangedBlock(cell: cell, model: item, indexPath: indexPath)
            let PlayCompletionBlk = getPlayCompletionBlock(cell: cell, model: item, indexPath: indexPath)
            //cell如果不是以前的cell，方案1需要重新设置block。
            SDVoicePlayer.shared.setPlayTimeChanged(block: playTimeChangedBlk)
            SDVoicePlayer.shared.setPlayCompletion(block: PlayCompletionBlk)
            cell.voiceView.startVoiceAnimate()
        }
        
        //方案2,3简便很多。
        cell.playActionBlk = { [weak self] sender in
            guard let self = self else {return}
//            self.handlePlayVoiceV2(cell: sender, model: item, indexPath: indexPath)
            self.handlePlayVoiceV3(cell: sender, model: item, indexPath: indexPath)
        }
        if SDVoicePlayer.shared.isPlaying(url: item.voiceURL) {
            cell.voiceView.startVoiceAnimate() //细节一点，方案3虽然播放器回调里面会更新cell，但回调是有间隔的。这里可以马上更新。
        }
        return cell
    }
    
    //方案3
    func handlePlayVoiceV3(cell: FDEVoiceTableViewCell, model: FDEVoiceModel, indexPath: IndexPath) {
        if SDVoicePlayer.shared.isPlaying(url: model.voiceURL) {
            SDVoicePlayer.shared.stop()
        } else {
            if !SDVoicePlayer.shared.isVoiceCached(url: model.voiceURL) {
                cell.voiceView.startLoading()
            } else {
                cell.voiceView.startVoiceAnimate()
            }
            
            SDVoicePlayer.shared.play(voiceURL: model.voiceURL, downloadProgress: nil) { [weak self] voiceURL, currentTime, duration in
                guard let self = self else {
                    return
                }
                guard let destCell = self.getCell(with: model) else { //根据截获的model获取正确行的cell。如果cell不在屏幕上则会返回nil。
                    return
                }
                if destCell.voice?.voiceURL != voiceURL { //这里不会进来，因为cellForRow里有赋值voice。
                    DLog("语音不一致1，destCell：\(destCell.getCellAdrress())")
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
                    DLog("语音不一致2，destCell：\(destCell.getCellAdrress())")
                    return
                }
                destCell.voiceView.stopVoiceAnimate()
                destCell.voiceView.durationLabel.text = "\(Int(model.duration))s"
            }
        }
    }
    
    func getIndexPath(with voice: FDEVoiceModel) -> IndexPath? {
        guard let voiceIndex = self.dataList.firstIndex(of: voice) else {return nil}
        let indexPath = IndexPath(row: voiceIndex, section: 0)
        return indexPath
    }
    
    func getCell(with voice: FDEVoiceModel) -> FDEVoiceTableViewCell? {
        guard let indexPath = getIndexPath(with: voice) else { return nil }
        let cell = self.tableView.cellForRow(at: indexPath) as? FDEVoiceTableViewCell
        return cell
    }
    
    //方案2
    func handlePlayVoiceV2(cell: FDEVoiceTableViewCell, model: FDEVoiceModel, indexPath: IndexPath) {
        if SDVoicePlayer.shared.isPlaying(url: model.voiceURL) {
            SDVoicePlayer.shared.stop()
        } else {
            if !SDVoicePlayer.shared.isVoiceCached(url: model.voiceURL) {
                cell.voiceView.startLoading()
            } else {
                cell.voiceView.startVoiceAnimate()
            }
            
            SDVoicePlayer.shared.play(voiceURL: model.voiceURL, downloadProgress: nil) { [weak self] voiceURL, currentTime, duration in
                guard let self = self else {
                    return
                }
                guard let destCell = self.tableView.cellForRow(at: indexPath) as? FDEVoiceTableViewCell else {
                    return
                }
                if destCell.voice?.voiceURL != voiceURL { //这里不会进来，因为cellForRow里有赋值voice。
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
                guard let destCell = self.tableView.cellForRow(at: indexPath) as? FDEVoiceTableViewCell else {
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
    
    //方案1
    func handlePlayVoiceV1(cell: FDEVoiceTableViewCell, model: FDEVoiceModel, indexPath: IndexPath) {
        if SDVoicePlayer.shared.isPlaying(url: model.voiceURL) {
            SDVoicePlayer.shared.stop()
        } else {
            if !SDVoicePlayer.shared.isVoiceCached(url: model.voiceURL) {
                cell.voiceView.startLoading()
            } else {
                cell.voiceView.startVoiceAnimate()
            }
            let playTimeChangedBlk = getPlayTimeChangedBlock(cell: cell, model:model, indexPath: indexPath)
            let PlayCompletionBlk = getPlayCompletionBlock(cell: cell, model:model, indexPath: indexPath)
            SDVoicePlayer.shared.play(voiceURL: model.voiceURL,
                                      downloadProgress: nil,
                                      playTimeChanged: playTimeChangedBlk,
                                      playCompletion: PlayCompletionBlk)
        }
    }
    
    func getPlayTimeChangedBlock(cell: FDEVoiceTableViewCell, model: FDEVoiceModel, indexPath: IndexPath) -> ((_ voiceURL: String?, _ currentTime: TimeInterval, _ duration: TimeInterval) -> Void) {
        let block: ((_ voiceURL: String?, _ currentTime: TimeInterval, _ duration: TimeInterval) -> Void) = { [weak self, weak cell] voiceURL, currentTime, duration in
            guard let self = self, let cell = cell else {return}
            //获取捕获的cell的当前indexPath
            //如果cell还在原地则当前indexPath等于原先的indexPath。
            //如果cell发生复用则当前indexPath将不等于原先的indexPath。
            //如果cell进入复用池不在屏幕则indexPath等于nil。
            guard let curIndexPath = self.tableView.indexPath(for: cell) else {
                return //curIndexPath == nil，说明cell不在屏幕上。
            }
            
            //a和b的效果是一致的。
            if curIndexPath != indexPath { //a.curIndexPath != indexPath,说明cell发生复用且cell已经不在原先的位置。此时不能更新。
                return
            }
            
//            let item = self.dataList[curIndexPath.row] //b
//            if voiceURL != item.voiceURL {
//                return
//            }
            
            cell.voiceView.startVoiceAnimate()
            let serverDuration: Double = model.duration
            cell.voiceView.durationLabel.text = "\(Int(ceil(max(0, serverDuration - currentTime))))s"
        }
        return block
    }
    
    func getPlayCompletionBlock(cell: FDEVoiceTableViewCell, model: FDEVoiceModel, indexPath: IndexPath) -> ((_ voiceURL: String?, _ err: Error?) -> Void) {
        let block: ((_ voiceURL: String?, _ err: Error?) -> Void) = { [weak self, weak cell] voiceURL, err in
            guard let self = self, let cell = cell else {return}
            if err != nil {
                DLog("error:\(err!.localizedDescription)")
            }
            
            guard let curIndexPath = self.tableView.indexPath(for: cell) else {
                return
            }
            
            if curIndexPath != indexPath {
                return
            }
            
//            let item = self.dataList[curIndexPath.row]
//            if voiceURL != item.voiceURL {
//                return
//            }
            
            cell.voiceView.stopVoiceAnimate()
            cell.voiceView.durationLabel.text = "\(Int(model.duration))s"
        }
        return block
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
}
