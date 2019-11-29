//
//  SZAVPlayerMIMEType.swift
//  SZAVPlayer
//
//  Created by CaiSanze on 2019/11/28.
//

import UIKit
import SQLite

class SZAVPlayerMIMEType: NSObject {

    var uniqueID: String = ""
    var mimeType: String = ""
    var updated: Int64 = 0

    static let uniqueID = Expression<String>("uniqueID")
    static let mimeType = Expression<String>("mimeType")
    static let updated = Expression<Int64>("updated")
    
}
