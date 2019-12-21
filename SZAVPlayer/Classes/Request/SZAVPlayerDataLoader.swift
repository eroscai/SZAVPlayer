//
//  SZAVPlayerDataLoader.swift
//  SZAVPlayer
//
//  Created by CaiSanze on 2019/12/6.
//

import UIKit

public typealias SZAVPlayerRange = Range<Int64>

protocol SZAVPlayerDataLoaderDelegate: AnyObject {
    func dataLoader(_ loader: SZAVPlayerDataLoader, didReceive data: Data)
    func dataLoaderDidFinish(_ loader: SZAVPlayerDataLoader)
    func dataLoader(_ loader: SZAVPlayerDataLoader, didFailWithError error: Error)
}

class SZAVPlayerDataLoader: NSObject {

    public weak var delegate: SZAVPlayerDataLoaderDelegate?

    private let callbackQueue: DispatchQueue
    private let operationQueue: OperationQueue
    private let uniqueID: String
    private let url: URL
    private let requestedRange: SZAVPlayerRange
    private var mediaData: Data?
    
    private var cancelled: Bool = false
    private var failed: Bool = false

    init(uniqueID: String, url: URL, range: SZAVPlayerRange, callbackQueue: DispatchQueue) {
        self.uniqueID = uniqueID
        self.url = url
        self.requestedRange = range
        self.callbackQueue = callbackQueue
        self.operationQueue = {
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 1

            return queue
        }()
        super.init()
    }

    deinit {
        SZLogInfo("deinit")
    }

    public func start() {
        guard !cancelled && !failed else { return }

        let localFileInfos = SZAVPlayerDatabase.shared.localFileInfos(uniqueID: uniqueID)
        guard localFileInfos.count > 0 else {
            operationQueue.addOperation(remoteRequestOperation(range: requestedRange))
            return
        }

        var startOffset = requestedRange.lowerBound
        let endOffset = requestedRange.upperBound
        for fileInfo in localFileInfos {
            if SZAVPlayerDataLoader.isOutOfRange(startOffset: startOffset, endOffset: endOffset, fileInfo: fileInfo) {
                continue
            }

            let localFileStartOffset = fileInfo.startOffset
            if startOffset >= localFileStartOffset {
                addLocalFileRequest(startOffset: &startOffset, endOffset: endOffset, fileInfo: fileInfo)
            } else {
                addRemoteRequest(startOffset: startOffset, endOffset: localFileStartOffset + 1)
                addLocalFileRequest(startOffset: &startOffset, endOffset: endOffset, fileInfo: fileInfo)
            }
        }

        let notEnded = startOffset < endOffset
        if notEnded {
            addRemoteRequest(startOffset: startOffset, endOffset: endOffset)
        }
    }

    public func cancel() {
        cancelled = true
        operationQueue.cancelAllOperations()
    }

    public static func isOutOfRange(startOffset: Int64, endOffset: Int64, fileInfo: SZAVPlayerLocalFileInfo) -> Bool {
        let localFileStartOffset = fileInfo.startOffset
        let localFileEndOffset = fileInfo.startOffset + fileInfo.loadedByteLength
        let remainRange = startOffset..<endOffset

        let isIntersectionWithRange = remainRange.contains(localFileStartOffset) || remainRange.contains(localFileEndOffset - 1)
        let isContainsRange = localFileStartOffset <= startOffset && localFileEndOffset >= endOffset

        return !(isIntersectionWithRange || isContainsRange)
    }

}

// MARK: - Request

extension SZAVPlayerDataLoader {

    private func localFileOperation(range: SZAVPlayerRange, fileInfo: SZAVPlayerLocalFileInfo) -> Operation {
        return BlockOperation { [weak self] in
            guard let weakSelf = self, !weakSelf.cancelled && !weakSelf.failed else { return }

            let fileURL = SZAVPlayerFileSystem.localFilePath(fileName: fileInfo.localFileName)
            if let data = SZAVPlayerFileSystem.read(url: fileURL, range: range) {
                weakSelf.callbackQueue.sync { [weak weakSelf] in
                    guard let weakSelf = weakSelf, !weakSelf.cancelled && !weakSelf.failed else { return }

                    weakSelf.delegate?.dataLoader(weakSelf, didReceive: data)
                }
            } else {
                weakSelf.callbackQueue.sync { [weak weakSelf] in
                    guard let weakSelf = weakSelf, !weakSelf.cancelled && !weakSelf.failed else { return }

                    weakSelf.delegate?.dataLoader(weakSelf, didFailWithError: SZAVPlayerError.localFileNotExist)
                }
            }
        }
    }

    private func remoteRequestOperation(range: SZAVPlayerRange) -> Operation {
        let operation = SZAVPlayerRequestOperation(url: url, range: range)
        operation.delegate = self

        return operation
    }

}

// MARK: - SZAVPlayerRequestOperationDelegate

extension SZAVPlayerDataLoader: SZAVPlayerRequestOperationDelegate {

    func requestOperationWillStart(_ operation: SZAVPlayerRequestOperation) {
        mediaData = Data()
    }

    func requestOperation(_ operation: SZAVPlayerRequestOperation, didReceive data: Data) {
        mediaData?.append(data)
        callbackQueue.sync {
            delegate?.dataLoader(self, didReceive: data)
        }
    }

    func requestOperation(_ operation: SZAVPlayerRequestOperation, didCompleteWithError error: Error?) {
        var shouldSaveData = false
        callbackQueue.sync {
            if let error = error {
                delegate?.dataLoader(self, didFailWithError: error)
            } else {
                delegate?.dataLoaderDidFinish(self)
                shouldSaveData = true
            }
        }

        if shouldSaveData, let mediaData = mediaData, mediaData.count > 0 {
            SZAVPlayerCache.shared.save(uniqueID: uniqueID, mediaData: mediaData, startOffset: operation.startOffset)
            self.mediaData = nil
        }
    }

}

// MARK: - Private

private extension SZAVPlayerDataLoader {

    func addLocalFileRequest(startOffset: inout Int64, endOffset: Int64, fileInfo: SZAVPlayerLocalFileInfo) {
        let requestedLength = endOffset - startOffset
        guard requestedLength > 0 else { return }

        let localFileStartOffset = max(0, startOffset - fileInfo.startOffset)
        let localFileUsefulLength = min(fileInfo.loadedByteLength - localFileStartOffset, requestedLength)
        let localFileRequestRange = localFileStartOffset..<localFileStartOffset + localFileUsefulLength
        operationQueue.addOperation(localFileOperation(range: localFileRequestRange, fileInfo: fileInfo))

        startOffset = startOffset + localFileUsefulLength
    }

    func addRemoteRequest(startOffset: Int64, endOffset: Int64) {
        guard startOffset < endOffset else { return }

        let range = startOffset..<endOffset
        operationQueue.addOperation(remoteRequestOperation(range: range))
    }

}
