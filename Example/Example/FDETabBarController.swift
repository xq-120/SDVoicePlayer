//
//  FDETabBarController.swift
//  DemonSwift
//
//  Created by xuequan on 2020/1/30.
//  Copyright © 2020 xuequan. All rights reserved.
//

import UIKit

class FDETabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        
        setupControllers()
    }
    
    func setupControllers() {
        let homeVC = FDEHomeViewController.init()
        let homeNav = FDENavigationController.init(rootViewController: homeVC)
        homeNav.tabBarItem.title = "首页"
        
        let msgVC = FDEMessageViewController.init()
        let msgNav = FDENavigationController.init(rootViewController: msgVC)
        msgNav.tabBarItem.title = "消息"
        
        let mineVC = FDEMineViewController.init()
        let mineNav = FDENavigationController.init(rootViewController: mineVC)
        mineNav.tabBarItem.title = "我"
        
        let controllers = [homeNav, msgNav, mineNav]
        self.setViewControllers(controllers, animated: false)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
