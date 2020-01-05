//
//  ListenerNode.swift
//
//  Created by CaiSanze on 2020/01/05.
//

import UIKit

class ListenerNode {
    
    public weak var listener: AnyObject?
    
    public static func create(listener: AnyObject) -> ListenerNode {
        let node = ListenerNode()
        node.listener = listener
        
        return node
    }
    
    public static func add(listener: AnyObject, to listenners: inout [ListenerNode]) {
        let node = ListenerNode.create(listener: listener)
        listenners.append(node)
    }
    
    public static func remove(listener: AnyObject, from listeners: inout [ListenerNode]) {
        for (index, node) in listeners.enumerated() {
            if let tmpListener = node.listener {
                if tmpListener.isEqual(listener) {
                    listeners.remove(at: index)
                }
            } else {
                listeners.remove(at: index)
            }
        }
    }
    
}
