//
//  SZAVPlayerItem.swift
//
//  Created by CaiSanze on 2019/11/27.
//

import UIKit
import AVFoundation
import CoreServices

private let SZAVPlayerItemScheme = "SZAVPlayerItemScheme"

public protocol SZAVPlayerItemDelegate: AnyObject {
    func playerItem(_ playerItem: SZAVPlayerItem, didFinishDownloading data: Data, fullyDownloaded: Bool)
    func playerItem(_ playerItem: SZAVPlayerItem, didDownload bytes: Int64, expectedToReceive: Int64)
    func playerItem(_ playerItem: SZAVPlayerItem, downloadingFailed error: Error)
}

public class SZAVPlayerItem: AVPlayerItem {

    public weak var delegate: SZAVPlayerItemDelegate?
    public let url: URL
    public var urlAsset: AVURLAsset?
    public var uniqueID: String = "defaultUniqueID"
    public var isObserverAdded: Bool = false
    private(set) public var isLocalData = false

    private var localDataMimeType: String?
    private var session: URLSession?
    private var mediaData: Data?
    private var response: URLResponse?
    private var resourceLoadingRequests: Set<AVAssetResourceLoadingRequest> = []
    private let recursiveLock = NSRecursiveLock()
    private var dataRequestStartOffset: Int64 = 0

    init(url: URL) {
        self.url = url
        var asset: AVURLAsset
        if let urlWithSchema = url.withScheme(SZAVPlayerItemScheme) {
            asset = AVURLAsset(url: urlWithSchema)
        } else {
            assertionFailure("URL schema is empty, please make sure to use the correct initilization func.")
            asset = AVURLAsset(url: url)
        }

        super.init(asset: asset, automaticallyLoadedAssetKeys: nil)

        asset.resourceLoader.setDelegate(self, queue: DispatchQueue.global(qos: .userInteractive))
        urlAsset = asset
    }

    init(data: Data, mimeType: String, isAudio: Bool) {
        url = SZAVPlayerItem.fakeURL(isAudio: isAudio)

        mediaData = data
        isLocalData = true
        localDataMimeType = mimeType

        let asset = AVURLAsset(url: url)
        super.init(asset: asset, automaticallyLoadedAssetKeys: nil)

        asset.resourceLoader.setDelegate(self, queue: DispatchQueue.global(qos: .userInteractive))
        urlAsset = asset
    }

    override init(asset: AVAsset, automaticallyLoadedAssetKeys: [String]?) {
        fatalError("init(asset:automaticallyLoadedAssetKeys:) has not been implemented")
    }

    deinit {
        SZLogInfo("deinit")
    }

}

// MARK: - Actions

extension SZAVPlayerItem {

    public func cleanup() {
        recursiveLock.lock()
        defer {
            recursiveLock.unlock()
        }

        mediaData = nil
        session?.invalidateAndCancel()
        session = nil
        resourceLoadingRequests.forEach { $0.finishLoading(with: nil) }
        resourceLoadingRequests.removeAll()
        dataRequestStartOffset = 0
    }

    private func handleResourceLoadingRequest(_ loadingRequest: AVAssetResourceLoadingRequest) {
        if #available(iOS 13, *) {
            if let dataRequest = loadingRequest.dataRequest,
                dataRequest.requestedOffset > 0
            {
                cleanup()
                dataRequestStartOffset = dataRequest.currentOffset
                let upperBound = Int(dataRequest.requestedOffset) + dataRequest.requestedLength
                let range: ClosedRange = Int(dataRequestStartOffset)...upperBound
                startDataRequest(url: url, range: range)
            } else {
                let shouldIntializeSession = !isLocalData && session == nil
                if shouldIntializeSession {
                    startDataRequest(url: url)
                }
            }
        } else {
            // iOS12系统下发现表现不一样，暂时使用全量加载
            let shouldIntializeSession = !isLocalData && session == nil
            if shouldIntializeSession {
                startDataRequest(url: url)
            }
        }
    }

    private func processResourceLoadingRequests() {
        recursiveLock.lock()
        defer {
            recursiveLock.unlock()
        }

        resourceLoadingRequests.compactMap {
            if let infoRequest = $0.contentInformationRequest {
                fillInContentInfoRequest(infoRequest)
            }

            if let dataRequest = $0.dataRequest {
                respondDataRequest(dataRequest)

                if shouldFinishDataRequest(dataRequest) {
                    $0.finishLoading()
                    return $0
                }
            }

            return nil
        }.forEach {
            resourceLoadingRequests.remove($0)
        }
    }

    private func fillInContentInfoRequest(_ request: AVAssetResourceLoadingContentInformationRequest) {
        if isLocalData {
            fillInWithLocalData(request)
        } else {
            fillInWithRemoteResponse(request)
        }
    }

    private func fillInWithLocalData(_ request: AVAssetResourceLoadingContentInformationRequest) {
        if let mimeType = localDataMimeType,
            let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)
        {
            request.contentType = contentType.takeRetainedValue() as String
        }

        if let mediaData = mediaData {
            request.contentLength = Int64(mediaData.count)
        }

        request.isByteRangeAccessSupported = true
    }

    private func fillInWithRemoteResponse(_ request: AVAssetResourceLoadingContentInformationRequest) {
        guard let response = response else { return }

        if let mimeType = response.mimeType,
            let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)
        {
            request.contentType = contentType.takeRetainedValue() as String
        }
        request.contentLength = response.expectedContentLength
        request.isByteRangeAccessSupported = true
    }

    private func respondDataRequest(_ dataRequest: AVAssetResourceLoadingDataRequest) {
        guard let mediaData = mediaData else { return }

        let currentOffset = Int(dataRequest.currentOffset)
        let dataOffset = mediaData.count + Int(dataRequestStartOffset)
        if dataOffset <= currentOffset {
            return
        }

        let requestedLength = dataRequest.requestedLength
        let bytesToRespond = min(dataOffset - currentOffset, requestedLength)
        let currentOffsetInData = currentOffset - Int(dataRequestStartOffset)
        let dataToRespond = mediaData.subdata(in: Range(uncheckedBounds: (currentOffsetInData, currentOffsetInData + bytesToRespond)))
        dataRequest.respond(with: dataToRespond)
    }

    private func shouldFinishDataRequest(_ dataRequest: AVAssetResourceLoadingDataRequest) -> Bool {
        guard let mediaData = mediaData else {
            return false
        }

        let requestedOffset = Int(dataRequest.requestedOffset)
        let requestedLength = dataRequest.requestedLength

        return mediaData.count >= requestedLength + requestedOffset
    }

}

// MARK: - Requests

extension SZAVPlayerItem {

    private func startDataRequest(url: URL, range: ClosedRange<Int>? = nil) {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        var request = URLRequest(url: url)
        if let range = range {
            let rangeHeader = "bytes=\(range.lowerBound)-\(range.upperBound - 1)"
            request.setValue(rangeHeader, forHTTPHeaderField: "Range")
        }
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        session?.dataTask(with: request).resume()
    }

}

// MARK: - AVAssetResourceLoaderDelegate

extension SZAVPlayerItem: AVAssetResourceLoaderDelegate {

    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        recursiveLock.lock()
        defer {
            recursiveLock.unlock()
        }

        handleResourceLoadingRequest(loadingRequest)
        resourceLoadingRequests.insert(loadingRequest)
        processResourceLoadingRequests()

        return true
    }

    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        recursiveLock.lock()
        defer {
            recursiveLock.unlock()
        }

        resourceLoadingRequests.remove(loadingRequest)
    }

}

// MARK: - URLSessionDelegate

extension SZAVPlayerItem: URLSessionDelegate, URLSessionDataDelegate, URLSessionTaskDelegate {

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        mediaData?.append(data)
        guard let mediaData = mediaData else { return }

        delegate?.playerItem(self, didDownload: Int64(mediaData.count), expectedToReceive: dataTask.countOfBytesExpectedToReceive)

        processResourceLoadingRequests()
    }

    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void)
    {
        completionHandler(.allow)

        mediaData = Data()
        self.response = response
        if let mimeType = response.mimeType {
            SZAVPlayerDatabase.shared.update(mimeType: mimeType, uniqueID: uniqueID)
        }

        processResourceLoadingRequests()
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            delegate?.playerItem(self, downloadingFailed: error)

            return
        }

        if let mediaData = mediaData {
            let fullyDownloaded = dataRequestStartOffset > 0 ? false : true
            delegate?.playerItem(self, didFinishDownloading: mediaData, fullyDownloaded: fullyDownloaded)
        }

        processResourceLoadingRequests()
    }

}

// MARK: - URL

fileprivate extension URL {

    func withScheme(_ scheme: String) -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.scheme = scheme
        return components.url
    }

}

// MARK: - Getter

extension SZAVPlayerItem {

    private static func fakeURL(isAudio: Bool) -> URL {
        let fakeFileExtension = isAudio ? "mp3" : "mp4"
        guard let url = URL(string: SZAVPlayerItemScheme + "://fake/file.\(fakeFileExtension)") else {
            fatalError("Failed to initialize fakeURL!")
        }

        return url
    }

}
