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
    func playerItemDidFinishDownloading(_ playerItem: SZAVPlayerItem)
    func playerItem(_ playerItem: SZAVPlayerItem, didDownload bytes: Int64)
    func playerItem(_ playerItem: SZAVPlayerItem, downloadingFailed error: Error)
}

public class SZAVPlayerItem: AVPlayerItem {

    public weak var delegate: SZAVPlayerItemDelegate?
    public let url: URL
    public var urlAsset: AVURLAsset?
    public var uniqueID: String = "defaultUniqueID"
    public var isObserverAdded: Bool = false

    private let recursiveLock = NSRecursiveLock()
    private let loaderQueue = DispatchQueue(label: "com.SZAVPlayer.loaderQueue")
    private var currentRequest: SZAVPlayerRequest? {
        didSet {
            oldValue?.cancel()
        }
    }
    private var isCancelled: Bool = false
    private var loadedLength: Int64 = 0

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

        asset.resourceLoader.setDelegate(self, queue: loaderQueue)
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

        loadedLength = 0
    }

    private func handleContentInfoRequest(loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let infoRequest = loadingRequest.contentInformationRequest else {
            return false
        }

        // use cached info first
        if let contentInfo = SZAVPlayerDatabase.shared.contentInfo(uniqueID: self.uniqueID),
            SZAVPlayerContentInfo.isNotExpired(updated: contentInfo.updated)
        {
            self.fillInWithLocalData(infoRequest, contentInfo: contentInfo)
            loadingRequest.finishLoading()

            return true
        }

        let request = contentInfoRequest(loadingRequest: loadingRequest)
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
        let task = session.downloadTask(with: request) { (_, response, error) in
            self.handleContentInfoResponse(loadingRequest: loadingRequest,
                                           infoRequest: infoRequest,
                                           response: response,
                                           error: error)
        }

        self.currentRequest = SZAVPlayerContentInfoRequest(
            resourceUrl: url,
            loadingRequest: loadingRequest,
            infoRequest: infoRequest,
            task: task
        )

        task.resume()

        return true
    }

    private func handleContentInfoResponse(loadingRequest: AVAssetResourceLoadingRequest,
                                           infoRequest: AVAssetResourceLoadingContentInformationRequest,
                                           response: URLResponse?,
                                           error: Error?)
    {
        self.loaderQueue.async {
            guard !loadingRequest.isCancelled else {
                return
            }

            guard let request = self.currentRequest as? SZAVPlayerContentInfoRequest,
                loadingRequest === request.loadingRequest else
            {
                return
            }

            if let error = error {
                let nsError = error as NSError
                if SZAVPlayerItem.isNetworkError(code: nsError.code),
                    let contentInfo = SZAVPlayerDatabase.shared.contentInfo(uniqueID: self.uniqueID)
                {
                    self.fillInWithLocalData(infoRequest, contentInfo: contentInfo)
                    loadingRequest.finishLoading()
                } else {
                    SZLogError("Failed with error: \(String(describing: error))")
                    loadingRequest.finishLoading(with: error)
                }

                return
            }

            if let response = response {
                if let mimeType = response.mimeType {
                    let info = SZAVPlayerContentInfo(uniqueID: self.uniqueID,
                                                     mimeType: mimeType,
                                                     contentLength: response.sz_expectedContentLength)
                    SZAVPlayerDatabase.shared.update(contentInfo: info)
                }
                self.fillInWithRemoteResponse(infoRequest, response: response)
                loadingRequest.finishLoading()
            }

            if self.currentRequest === request {
                self.currentRequest = nil
            }
        }
    }

    private func handleDataRequest(loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let avDataRequest = loadingRequest.dataRequest else {
            return false
        }

        if let lastRequest = currentRequest {
            lastRequest.cancel()
        }

        let lowerBound = avDataRequest.requestedOffset
        let length = Int64(avDataRequest.requestedLength)
        let upperBound = lowerBound + length
        let loader = SZAVPlayerDataLoader(uniqueID: uniqueID,
                                          url: url,
                                          range: lowerBound..<upperBound,
                                          callbackQueue: loaderQueue)
        loader.delegate = self
        let dataRequest: SZAVPlayerDataRequest = {
            return SZAVPlayerDataRequest(
                resourceUrl: url,
                loadingRequest: loadingRequest,
                dataRequest: avDataRequest,
                loader: loader
            )
        }()

        self.currentRequest = dataRequest
        loader.start()

        return true
    }

    private func fillInWithLocalData(_ request: AVAssetResourceLoadingContentInformationRequest, contentInfo: SZAVPlayerContentInfo) {
        if let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, contentInfo.mimeType as CFString, nil) {
            request.contentType = contentType.takeRetainedValue() as String
        }

        request.contentLength = contentInfo.contentLength
        // TODO
        request.isByteRangeAccessSupported = true
    }

    private func fillInWithRemoteResponse(_ request: AVAssetResourceLoadingContentInformationRequest, response: URLResponse) {
        if let mimeType = response.mimeType,
            let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)
        {
            request.contentType = contentType.takeRetainedValue() as String
        }
        request.contentLength = response.sz_expectedContentLength
        // TODO
        request.isByteRangeAccessSupported = true
    }

}

// MARK: - AVAssetResourceLoaderDelegate

extension SZAVPlayerItem: AVAssetResourceLoaderDelegate {

    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        recursiveLock.lock()
        defer {
            recursiveLock.unlock()
        }

        if let _ = loadingRequest.contentInformationRequest {
            return handleContentInfoRequest(loadingRequest: loadingRequest)
        } else if let _ = loadingRequest.dataRequest {
            return handleDataRequest(loadingRequest: loadingRequest)
        } else {
            return false
        }
    }

    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        recursiveLock.lock()
        defer {
            recursiveLock.unlock()
        }

        currentRequest?.cancel()
    }

}

// MARK: - SZAVPlayerDataLoaderDelegate

extension SZAVPlayerItem: SZAVPlayerDataLoaderDelegate {

    func dataLoader(_ loader: SZAVPlayerDataLoader, didReceive data: Data) {
        if let dataRequest = currentRequest?.loadingRequest.dataRequest {
            dataRequest.respond(with: data)
        }

        loadedLength = loadedLength + Int64(data.count)
        delegate?.playerItem(self, didDownload: loadedLength)
    }

    func dataLoaderDidFinish(_ loader: SZAVPlayerDataLoader) {
        currentRequest?.loadingRequest.finishLoading()
        currentRequest = nil

        delegate?.playerItemDidFinishDownloading(self)
    }

    func dataLoader(_ loader: SZAVPlayerDataLoader, didFailWithError error: Error) {
        currentRequest?.loadingRequest.finishLoading(with: error)
        currentRequest = nil

        delegate?.playerItem(self, downloadingFailed: error)
    }

}

// MARK: - Extensions

fileprivate extension URL {

    func withScheme(_ scheme: String) -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.scheme = scheme
        return components.url
    }

}

fileprivate extension URLResponse {

    var sz_expectedContentLength: Int64 {
        guard let response = self as? HTTPURLResponse else {
            return expectedContentLength
        }

        if let rangeString = response.allHeaderFields["Content-Range"] as? String,
            let bytesString = rangeString.split(separator: "/").map({String($0)}).last,
            let bytes = Int64(bytesString)
        {
            return bytes
        } else {
            return expectedContentLength
        }
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

    private static func isNetworkError(code: Int) -> Bool {
        let errorCodes = [
            NSURLErrorNotConnectedToInternet,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorTimedOut,
        ]

        return errorCodes.contains(code)
    }

    private func contentInfoRequest(loadingRequest: AVAssetResourceLoadingRequest) -> URLRequest {
        var request = URLRequest(url: url)
        if let dataRequest = loadingRequest.dataRequest {
            let lowerBound = Int(dataRequest.requestedOffset)
            let upperBound = lowerBound + Int(dataRequest.requestedLength) - 1
            let rangeHeader = "bytes=\(lowerBound)-\(upperBound)"
            request.setValue(rangeHeader, forHTTPHeaderField: "Range")
        }

        return request
    }

}
