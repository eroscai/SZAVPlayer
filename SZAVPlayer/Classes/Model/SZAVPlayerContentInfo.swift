//
//  SZAVPlayerContentInfo.swift
//  SZAVPlayer
//
//  Created by CaiSanze on 2019/12/6.
//

import UIKit
import SQLite

public struct SZAVPlayerContentInfo {

    var uniqueID: String
    var mimeType: String
    var contentLength: Int64
    var updated: Int64 = 0

    static let uniqueID = Expression<String>("uniqueID")
    static let mimeType = Expression<String>("mimeType")
    static let contentLength = Expression<Int64>("contentLength")
    static let updated = Expression<Int64>("updated")

    static func isNotExpired(updated: Int64) -> Bool {
        let expiredTimeInterval = 3600
        return Int64(Date().timeIntervalSince1970) - updated <= expiredTimeInterval
    }

}
