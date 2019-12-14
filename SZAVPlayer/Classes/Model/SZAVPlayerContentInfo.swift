//
//  SZAVPlayerContentInfo.swift
//  SZAVPlayer
//
//  Created by CaiSanze on 2019/12/6.
//

import UIKit

public struct SZAVPlayerContentInfo: SZBaseModel {

    static let tableName: String = "SZAVPlayerContentInfo"

    var uniqueID: String
    var mimeType: String
    var contentLength: Int64
    var updated: Int64 = 0

    static func isNotExpired(updated: Int64) -> Bool {
        let expiredTimeInterval = 3600
        return Int64(Date().timeIntervalSince1970) - updated <= expiredTimeInterval
    }

}
