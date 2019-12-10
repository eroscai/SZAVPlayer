//
//  SZAVPlayerCache.swift
//
//  Created by CaiSanze on 2019/11/27.
//

import UIKit

class SZAVPlayerCache: NSObject {

    public static let shared: SZAVPlayerCache = SZAVPlayerCache()

    public var maxCacheCount: Int = 10

    override init() {
        super.init()

        setup()
    }

    public func setup(maxCacheCount: Int = 10) {
        self.maxCacheCount = maxCacheCount
        SZAVPlayerFileSystem.createCacheDirectory()
    }

    public func save(data: Data, uniqueID: String) {
        trimCache()

        SZAVPlayerFileSystem.write(data: data, url: SZAVPlayerCache.fileURL(uniqueID: uniqueID))
    }

    public static func delete(uniqueID: String) {
        SZAVPlayerFileSystem.delete(url: fileURL(uniqueID: uniqueID))
    }

    public func cleanCache() {
        // clean local cache
        // clean mime type
    }

    public func trimCache() {
        DispatchQueue.global(qos: .background).async {
            let allFiles: [URL] = SZAVPlayerFileSystem.allFiles(path: SZAVPlayerFileSystem.cacheDirectory)
            guard allFiles.count > self.maxCacheCount else { return }

            let needTrimLength: Int = allFiles.count - self.maxCacheCount
            let needTrimFiles: [URL] = Array(allFiles[0..<needTrimLength])

            for url in needTrimFiles {
                SZAVPlayerFileSystem.delete(url: url)
            }
        }
    }

}

// MARK: - Getter

extension SZAVPlayerCache {

    public static func dataExist(uniqueID: String) -> Bool {
        return SZAVPlayerFileSystem.isExist(url: fileURL(uniqueID: uniqueID))
    }

    private static func fileURL(uniqueID: String) -> URL {
        return SZAVPlayerFileSystem.cacheDirectory.appendingPathComponent(uniqueID)
    }

}
