//
//  SZAVPlayerItemRequest.swift
//  SZAVPlayer
//
//  Created by CaiSanze on 2019/11/28.
//
//

import Foundation
import AVFoundation

protocol SZAVPlayerRequest: AnyObject {

    var resourceUrl: URL { get }
    var loadingRequest: AVAssetResourceLoadingRequest { get }

    func cancel()

}

class SZAVPlayerContentInfoRequest: SZAVPlayerRequest {

    let resourceUrl: URL
    let loadingRequest: AVAssetResourceLoadingRequest
    let infoRequest: AVAssetResourceLoadingContentInformationRequest
    let task: URLSessionTask
    
    init(resourceUrl: URL,
         loadingRequest: AVAssetResourceLoadingRequest,
         infoRequest: AVAssetResourceLoadingContentInformationRequest,
         task: URLSessionTask)
    {
        self.resourceUrl = resourceUrl
        self.loadingRequest = loadingRequest
        self.infoRequest = infoRequest
        self.task = task
    }
    
    func cancel() {
        task.cancel()
        if !loadingRequest.isCancelled && !loadingRequest.isFinished {
            loadingRequest.finishLoading()
        }
    }

}

class SZAVPlayerDataRequest: SZAVPlayerRequest {
    
    let resourceUrl: URL
    let loadingRequest: AVAssetResourceLoadingRequest
    let dataRequest: AVAssetResourceLoadingDataRequest
    let loader: SZAVPlayerDataLoader
    let range: SZAVPlayerRange
    
    init(resourceUrl: URL,
         loadingRequest: AVAssetResourceLoadingRequest,
         dataRequest: AVAssetResourceLoadingDataRequest,
         loader: SZAVPlayerDataLoader,
         range: SZAVPlayerRange)
    {
        self.resourceUrl = resourceUrl
        self.loadingRequest = loadingRequest
        self.dataRequest = dataRequest
        self.loader = loader
        self.range = range
    }
    
    func cancel() {
        loader.cancel()
        if !loadingRequest.isCancelled && !loadingRequest.isFinished {
            loadingRequest.finishLoading()
        }
    }
    
}

class SZAVPlayerLocalFileRequest: SZAVPlayerRequest {

    let resourceUrl: URL
    let loadingRequest: AVAssetResourceLoadingRequest
    let dataRequest: AVAssetResourceLoadingDataRequest

    init(resourceUrl: URL,
         loadingRequest: AVAssetResourceLoadingRequest,
         dataRequest: AVAssetResourceLoadingDataRequest)
    {
        self.resourceUrl = resourceUrl
        self.loadingRequest = loadingRequest
        self.dataRequest = dataRequest
    }

    func cancel() {
        if !loadingRequest.isCancelled && !loadingRequest.isFinished {
            loadingRequest.finishLoading()
        }
    }

}
