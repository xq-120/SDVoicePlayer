//
//  FDEMessageViewController.swift
//  Example
//
//  Created by xq on 2022/9/30.
//

import UIKit

class FDEMessageViewController: FDEBaseViewController {

    var btn: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.frame = CGRect.init(x: 0, y: 0, width: 100, height: 44)
        btn.setTitle("button", for: .normal)
        btn.backgroundColor = .red
        btn.addTarget(self, action: #selector(btnDidClicked(_:)), for: .touchUpInside)
        return btn
    }()


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupSubview()
    }

    func setupSubview() {
        self.navigationItem.title = "消息"
        view.addSubview(btn)
        btn.center = self.view.center
    }

    @objc func btnDidClicked(_ sender: UIButton) {
        DLog("btnDidClicked")
    }


}

