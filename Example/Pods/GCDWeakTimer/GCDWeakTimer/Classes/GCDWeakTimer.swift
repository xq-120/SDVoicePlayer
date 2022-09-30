//
//  GCDWeakTimer.swift
//  SwiftPodDemo
//
//  Created by xq on 2022/9/24.
//

import UIKit

@objc public enum GCDWeakTimerStatus: Int {
    case initial
    case running
    case suspend
    case invalid
}

@objc open class GCDWeakTimer: NSObject {
    private var privateSerialQueue: DispatchQueue
    private var dispatchQueue: DispatchQueue
    private let queueKey = DispatchSpecificKey<Int>()
    private let queueKeyValue = Int(arc4random())
    
    private var timer: DispatchSourceTimer?
    private var _timeInterval: TimeInterval = 0
    private var _tolerance: TimeInterval = 1
    private var _repeats: Bool = false
    private var _status: GCDWeakTimerStatus = .initial
    
    private let lock = NSLock.init()
    
    private weak var target: AnyObject? = nil
    private var selector: Selector?
    public private(set) var userInfo: Any?
    
    private var actionBlock: ((GCDWeakTimer) -> Void)?
    
    deinit {
        self.invalidate()
    }
    
    /// 创建定时器。创建后需调用start启动。
    /// - Parameters:
    ///   - timeInterval: 时间间隔，单位s
    ///   - tolerance: 误差，单位ms。默认1ms
    ///   - target: target。内部为弱引用
    ///   - selector: 执行的方法
    ///   - userInfo: 额外信息
    ///   - repeats: 是否重复
    ///   - dispatchQueue: 回调的队列。默认主线程
    @objc public convenience init(timeInterval: TimeInterval, tolerance: TimeInterval = 1, target: AnyObject, selector: Selector, userInfo: Any?, repeats: Bool, dispatchQueue: DispatchQueue? = nil) {
        self.init(timeInterval: timeInterval, tolerance:tolerance, actionBlock: nil, target: target, selector: selector, userInfo: userInfo, repeats: repeats, dispatchQueue: dispatchQueue)
    }
    
    /// 创建定时器。创建后需调用start启动。
    /// - Parameters:
    ///   - timeInterval: 时间间隔，单位s
    ///   - tolerance: 误差，单位ms。默认1ms
    ///   - actionBlock: 执行的block。
    ///   - repeats: 是否重复
    ///   - dispatchQueue: 回调的队列。默认主线程
    @objc public convenience init(timeInterval: TimeInterval, tolerance: TimeInterval = 1, actionBlock: @escaping ((GCDWeakTimer) -> Void), repeats: Bool, dispatchQueue: DispatchQueue? = nil) {
        self.init(timeInterval: timeInterval, tolerance:tolerance, actionBlock: actionBlock, target: nil, selector: nil, userInfo: nil, repeats: repeats, dispatchQueue: dispatchQueue)
    }
    
    private init(timeInterval: TimeInterval, tolerance: TimeInterval, actionBlock: ((GCDWeakTimer) -> Void)?, target: AnyObject?, selector: Selector?, userInfo: Any?, repeats: Bool, dispatchQueue: DispatchQueue?) {
        self._timeInterval = max(0, timeInterval)
        self._tolerance = tolerance >= 0 ? tolerance : 1
        self._repeats = repeats
        
        self.actionBlock = actionBlock
        
        self.target = target
        self.selector = selector
        self.userInfo = userInfo
        
        self.dispatchQueue = dispatchQueue ?? DispatchQueue.main
        self.dispatchQueue.setSpecific(key: queueKey, value: queueKeyValue)
        self.privateSerialQueue = DispatchQueue.init(label: "www.xq.weakTimerSerialQueue", target: self.dispatchQueue)
        super.init()
        
        self._status = .initial
        self.timer = self.configureTimer(interval: self._timeInterval, tolerance: self._tolerance, repeating: repeats, queue: self.privateSerialQueue)
    }
    
    /// 启动定时器。
    ///
    /// 如果定时器已经running，则无影响
    /// 如果定时器已经被销毁，则重新创建一个并启动。
    @objc open func start() {
        self.lock.lock()
        let status = self._status
        switch status {
        case .initial, .suspend:
            self._status = .running
            self.timer?.resume()
        case .invalid:
            self.timer = self.configureTimer(interval: self._timeInterval, tolerance: self._tolerance, repeating: self._repeats, queue: self.privateSerialQueue)
            self._status = .running
            self.timer?.resume()
        case .running:
            break
        }
        self.lock.unlock()
    }
    
    private func configureTimer(interval: TimeInterval, tolerance: TimeInterval, repeating: Bool, queue: DispatchQueue) -> DispatchSourceTimer {
        let timer = DispatchSource.makeTimerSource(flags: [], queue: queue)
        timer.setEventHandler { [weak self] in
            self?.timerFired()
        }
        self.scheduleTimer(timer: timer, interval: interval, tolerance: tolerance, repeating: repeating)
        return timer
    }

    /// 变更定时器时间间隔
    ///
    /// 如果定时器已经被销毁，则无效。
    /// - Parameters:
    ///   - timeInterval: 时间间隔。
    ///   - tolerance: 误差。
    @objc open func updateTimerProperties(timeInterval: TimeInterval, tolerance: TimeInterval = 1) {
        self.lock.lock()
        if self._status == .invalid {
            self.lock.unlock()
            return
        }
        
        self._timeInterval = max(0, timeInterval)
        self._tolerance = tolerance >= 0 ? tolerance : 1
        
        self.scheduleTimer(timer:self.timer, interval: self._timeInterval, tolerance: self._tolerance, repeating: self._repeats)
        self.lock.unlock()
    }
    
    private func scheduleTimer(timer: DispatchSourceTimer?, interval: TimeInterval, tolerance: TimeInterval, repeating: Bool) {
        let deadline: DispatchTime = (DispatchTime.now() + interval)
        let leeway = self.leeway(with: tolerance)
        if repeating {
            timer?.schedule(deadline: deadline, repeating: interval, leeway: leeway)
        } else {
            timer?.schedule(deadline: deadline, leeway: leeway)
        }
    }
    
    //误差单位ms
    private func leeway(with interval: TimeInterval) -> DispatchTimeInterval {
        let nsecond = 1000 * 1000.0
        let tolerance = max(0, interval)
        let lee = Int(tolerance * nsecond)
        return DispatchTimeInterval.nanoseconds(lee)
    }
    
    /// 暂停定时器
    ///
    /// 如果定时器不在运行中则无效
    @objc open func suspend() {
        self.lock.lock()
        let status = self._status
        if status != .running {
            self.lock.unlock()
            return
        }
        self._status = .suspend
        self.timer?.suspend()
        self.lock.unlock()
    }
    
    /// 继续运行定时器
    ///
    /// 如果定时器已经销毁或正在运行则无效
    @objc open func resume() {
        self.lock.lock()
        let status = self._status
        if status == .invalid || status == .running {
            self.lock.unlock()
            return
        }
        self._status = .running
        self.timer?.resume()
        self.lock.unlock()
    }

    /// 马上运行一次。
    @objc open func fire() {
        if DispatchQueue.getSpecific(key: self.queueKey) != nil {
            self.timerFired()
        } else {
            self.privateSerialQueue.async {
                self.timerFired()
            }
        }
    }

    private func timerFired() {
        self.lock.lock()
        let status = self._status
        self.lock.unlock()
        if status == .invalid {
            return
        }
        
        if let target = self.target, let sel = self.selector {
            _ = target.perform(sel, with: self)
        } else {
            self.actionBlock?(self)
        }
        
        if !self._repeats {
            self.invalidate()
        }
    }
    
    /// 停止定时器
    ///
    /// 停止后，可调用start重新启动定时器。
    @objc open func invalidate() {
        self.lock.lock()
        let status = self._status
        if status == .invalid || self.timer == nil {
            self.lock.unlock()
            return
        }
        if status != .running {
            self.timer?.resume()
        }
        self._status = .invalid
        self.timer?.cancel()
        self.timer = nil
        self.lock.unlock()
    }
    
    // MARK: check
    @objc public var timeInterval: TimeInterval {
        self.lock.lock()
        let t = _timeInterval
        self.lock.unlock()
        return t
    }
    
    @objc public var tolerance: TimeInterval {
        self.lock.lock()
        let t = _tolerance
        self.lock.unlock()
        return t
    }
    
    @objc public var repeats: Bool {
        self.lock.lock()
        let t = _repeats
        self.lock.unlock()
        return t
    }
    
    @objc public var status: GCDWeakTimerStatus {
        self.lock.lock()
        let t = _status
        self.lock.unlock()
        return t
    }
}
