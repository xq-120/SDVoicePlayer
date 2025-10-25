//
//  DispatchQueueExtension.swift
//  SDVoicePlayer
//
//  Created by uzzi on 2025/10/25.
//

import Foundation

extension DispatchQueue {
    private static var specificKey = DispatchSpecificKey<UUID>()
    
    func setAsSpecific() {
        let id = UUID()
        setSpecific(key: DispatchQueue.specificKey, value: id)
    }
    
    private func isCurrentQueue() -> Bool {
        guard let id = getSpecific(key: DispatchQueue.specificKey) else { return false }
        return id == DispatchQueue.getSpecific(key: DispatchQueue.specificKey)
    }
    
    func syncSafe<T>(_ block: () -> T) -> T {
        if isCurrentQueue() {
            return block()
        } else {
            return sync(execute: block)
        }
    }
}
