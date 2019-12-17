//
//  SZAVPlayerCache.swift
//
//  Created by CaiSanze on 2019/11/27.
//

import UIKit

public class SZAVPlayerCache: NSObject {

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

    public func cleanCache() {
        // clean local cache
        // clean mime type
    }

    public func isFullyCached(uniqueID: String) -> Bool {
        let info = SZAVPlayerDatabase.shared.contentInfo(uniqueID: uniqueID)
        let localFileInfos = SZAVPlayerDatabase.shared.localFileInfos(uniqueID: uniqueID)
        guard let contentInfo = info, contentInfo.contentLength > 0,
            localFileInfos.count > 0 else
        {
            return false
        }

        var startOffset = Int64(0)
        let endOffset = contentInfo.contentLength
        for fileInfo in localFileInfos {
            if SZAVPlayerDataLoader.isOutOfRange(startOffset: startOffset, endOffset: endOffset, fileInfo: fileInfo) {
                break
            }

            let localFileStartOffset = fileInfo.startOffset
            if startOffset >= localFileStartOffset {
                let localFileStartOffset = max(0, startOffset - fileInfo.startOffset)
                let localFileUsefulLength = min(fileInfo.loadedByteLength - localFileStartOffset, endOffset)
                startOffset = startOffset + localFileUsefulLength
            } else {
                break
            }
        }

        let isFullyCached = startOffset >= endOffset
        return isFullyCached
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
