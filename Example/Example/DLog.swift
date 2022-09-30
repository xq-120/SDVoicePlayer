//
//  DLog.swift
//  DemonSwift
//
//  Created by xuequan on 2020/1/30.
//  Copyright © 2020 xuequan. All rights reserved.
//

import Foundation

let dateFormatter = DateFormatter()

//日志打印
func DLog<T>(_ message:T, file:String = #file, function:String = #function, line:Int = #line) {
    #if DEBUG
    
    //获取文件名
    let fileName = (file as NSString).lastPathComponent
    
    // 为日期格式器设置格式字符串
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    // 使用日期格式器格式化当前日期、时间
    let datestr = dateFormatter.string(from: Date())

    //日志内容
    let consoleStr = "\(datestr) [\(fileName):\(line)][\(function)]\(message)"
    
    //打印日志内容
    print(consoleStr)
    
    #endif
}
