//
//  SZAVPlayerRequestOperation.swift
//  SZAVPlayer
//
//  Created by CaiSanze on 2019/12/6.
//
//

import Foundation

public protocol SZAVPlayerRequestOperationDelegate: AnyObject {
    func requestOperationWillStart(_ operation: SZAVPlayerRequestOperation)
    func requestOperation(_ operation: SZAVPlayerRequestOperation, didReceive data: Data)
    func requestOperation(_ operation: SZAVPlayerRequestOperation, didCompleteWithError error: Error?)
}

public class SZAVPlayerRequestOperation: Operation {
    
    public typealias CompletionHandler = () -> Void
    public weak var delegate: SZAVPlayerRequestOperationDelegate?
    private(set) public var startOffset: Int64 = 0
    
    private let performQueue: DispatchQueue
    private var requestCompletion: CompletionHandler?
    private lazy var session: URLSession = createSession()
    private var task: URLSessionDataTask?

    private var _finished: Bool = false
    private var _executing: Bool = false
    
    public init(url: URL, range: SZAVPlayerRange?) {
        self.performQueue = DispatchQueue(label: "com.SZAVPlayer.RequestOperation", qos: .background)
        super.init()

        task = dataRequest(url: url, range: range)
    }

    private func work(completion: @escaping CompletionHandler) {
        requestCompletion = completion
        delegate?.requestOperationWillStart(self)
        task?.resume()
    }
    
    // MARK: Operation Requirements

    override public func start() {
        guard !isCancelled else {return}
        markAsRunning()
        performQueue.async {
            self.work {
                DispatchQueue.main.async {
                    guard !self.isCancelled else {return}
                    self.markAsFinished()
                }
            }
        }
    }

    override public func cancel() {
        task?.cancel()
    }

    override open var isFinished: Bool {
        get { return _finished }
        set { _finished = newValue }
    }

    override open var isExecuting: Bool {
        get { return _executing }
        set { _executing = newValue }
    }
    
    override open var isAsynchronous: Bool {
        return true
    }
    
}

// MARK: - Private

extension SZAVPlayerRequestOperation {

    private func markAsRunning() {
        willChangeValue(for: .isExecuting)
        _executing = true
        didChangeValue(for: .isExecuting)
    }

    private func markAsFinished() {
        willChangeValue(for: .isExecuting)
        willChangeValue(for: .isFinished)
        _executing = false
        _finished = true
        didChangeValue(for: .isExecuting)
        didChangeValue(for: .isFinished)
    }

    private func willChangeValue(for key: OperationChangeKey) {
        self.willChangeValue(forKey: key.rawValue)
    }

    private func didChangeValue(for key: OperationChangeKey) {
        self.didChangeValue(forKey: key.rawValue)
    }

    private enum OperationChangeKey: String {
        case isFinished
        case isExecuting
    }

}

// MARK: - URLSessionDelegate

extension SZAVPlayerRequestOperation: URLSessionDataDelegate {

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        delegate?.requestOperation(self, didReceive: data)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        delegate?.requestOperation(self, didCompleteWithError: error)

        if let completion = requestCompletion {
            completion()
        }
    }

}

// MARK: - Getter

extension SZAVPlayerRequestOperation {

    private func dataRequest(url: URL, range: SZAVPlayerRange? = nil) -> URLSessionDataTask {
        var request = URLRequest(url: url)
        if let range = range {
            let rangeHeader = "bytes=\(range.lowerBound)-\(range.upperBound)"
            request.setValue(rangeHeader, forHTTPHeaderField: "Range")
            startOffset = range.lowerBound
        }

        return session.dataTask(with: request)
    }

    private func createSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)

        return session
    }

}
