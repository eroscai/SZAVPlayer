//
//  ListenerProtocol.swift
//
//  Created by CaiSanze on 2020/01/05.
//

import UIKit

protocol ListenerBaseProtocol: AnyObject {
    
}

// MARK: - SystemEvent

enum SystemEventType {
    case willResignActive
    case didEnterBackground
    case willEnterForeground
    case didBecomeActive
    case willTerminate
}

protocol SystemEventListenerProtocol: ListenerBaseProtocol {
    func onSystemEventDetected(application: UIApplication, type: SystemEventType) -> Void
}

// MARK: - PlayerControllerEvent

enum PlayerControllerEventType {
    case none
    case playing
    case paused
    case stalled
    case failed
}

protocol PlayerControllerEventListenerProtocol: ListenerBaseProtocol {
    func onPlayerControllerEventDetected(event: PlayerControllerEventType) -> Void
}
