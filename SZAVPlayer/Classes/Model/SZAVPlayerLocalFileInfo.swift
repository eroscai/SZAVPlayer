//
//  SZAVPlayerLocalFileInfo.swift
//  SZAVPlayer
//
//  Created by CaiSanze on 2019/12/6.
//

import UIKit
import SQLite

public struct SZAVPlayerLocalFileInfo {

    var uniqueID: String
    var startOffset: Int64
    var loadedByteLength: Int64
    var localFileName: String
    var updated: Int64 = 0

    static let uniqueID = Expression<String>("uniqueID")
    static let startOffset = Expression<Int64>("startOffset")
    static let loadedByteLength = Expression<Int64>("loadedByteLength")
    static let localFileName = Expression<String>("localFileName")
    static let updated = Expression<Int64>("updated")

    static func newFileName(uniqueID: String) -> String {
        let timeInterval = Int64(Date().timeIntervalSince1970 * 1000)

        return "\(timeInterval)"
    }

}
