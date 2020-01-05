//
//  ListenerCenter.swift
//
//  Created by CaiSanze on 2020/01/05.
//

import UIKit

class ListenerCenter {
    
    public static let shared = ListenerCenter()
    
    private lazy var recursiveLock: NSRecursiveLock = NSRecursiveLock()
    private lazy var systemEventListeners: [ListenerNode] = []
    private lazy var playerControllerEventListeners: [ListenerNode] = []

    //保存监听者，不让其自动释放，监听完毕以后再手动删除
    private lazy var preserveListeners: [ListenerBaseProtocol] = []
    
    enum ListenerType: CaseIterable {
        case systemEvent
        case playerStatusEvent
    }
    
}

// MARK: - Public

extension ListenerCenter {
    
    func addListener(listener: ListenerBaseProtocol, type: ListenerType, preserve: Bool = false) {
        removeListener(listener: listener, type: type)
        
        recursiveLock.lock()
        defer { recursiveLock.unlock() }
        
        switch type {
        case .systemEvent:
            ListenerNode.add(listener: listener, to: &systemEventListeners)
        case .playerStatusEvent:
            ListenerNode.add(listener: listener, to: &playerControllerEventListeners)
        }
        
        if preserve {
            preserveListeners.append(listener)
        }
    }
    
    func removeListener(listener: AnyObject, type: ListenerType) {
        recursiveLock.lock()
        defer { recursiveLock.unlock() }
        
        switch type {
        case .systemEvent:
            ListenerNode.remove(listener: listener, from: &systemEventListeners)
        case .playerStatusEvent:
            ListenerNode.remove(listener: listener, from: &playerControllerEventListeners)
        }
        
        for (index, preserveListener) in preserveListeners.enumerated() {
            if listener.isEqual(preserveListener) {
                preserveListeners.remove(at: index)
            }
        }
    }
    
    func removeAllListener(listener: AnyObject) {
        recursiveLock.lock()
        defer { recursiveLock.unlock() }
        
        for type in ListenerType.allCases {
            removeListener(listener: listener, type: type)
        }
    }
    
}

// MARK: - SystemEvent

extension ListenerCenter {
    
    public func notifySystemEventDetected(application: UIApplication, type: SystemEventType) {
        recursiveLock.lock()
        defer { recursiveLock.unlock() }
        
        for node in systemEventListeners {
            if let listener = node.listener as? SystemEventListenerProtocol {
                listener.onSystemEventDetected(application: application, type: type)
            }
        }
    }
    
}

// MARK: - PlayerStatus

extension ListenerCenter {

    public func notifyPlayerControllerEventDetected(event: PlayerControllerEventType) {
        recursiveLock.lock()
        defer { recursiveLock.unlock() }

        for node in playerControllerEventListeners {
            if let listener = node.listener as? PlayerControllerEventListenerProtocol {
                listener.onPlayerControllerEventDetected(event: event)
            }
        }
    }

}

