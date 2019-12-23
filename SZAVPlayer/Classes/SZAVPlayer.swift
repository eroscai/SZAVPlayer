//
//  SZAVPlayer.swift
//
//  Created by CaiSanze on 2019/11/27.
//

import UIKit
import AVFoundation
import CoreAudio
import MediaPlayer

/// AVPlayer observer keys
private let SZPlayerItemStatus = "status"
private let SZPlayerLoadedTimeRanges = "loadedTimeRanges"
private let SZPlayerPlaybackBufferEmpty = "playbackBufferEmpty"
private let SZPlayerPlaybackLikelyToKeepUp = "playbackLikelyToKeepUp"

/// AVPlayer status. You can implement SZAVPlayerDelegate to receive state changes.
public enum SZAVPlayerStatus: Int {
    case loading = 0
    case loadingFailed
    case readyToPlay
    case playEnd
    case playbackStalled
    case bufferBegin
    case bufferEnd
}

/// AVPlayer remote command, for example, playback related operations from the lock screen. You can
/// implement SZAVPlayerDelegate to receive state changes.
public enum SZAVPlayerRemoteCommand {
    case play
    case pause
    case next
    case previous
}

public protocol SZAVPlayerDelegate: AnyObject {

    /// Playing time delegate.
    /// - Parameters:
    ///   - currentTime: Current item playing time.
    ///   - totalTime: Current item total duration.
    func avplayer(_ avplayer: SZAVPlayer, refreshed currentTime: Float64, totalTime: Float64)

    /// Player status changing delegate.
    /// - Parameters:
    ///   - status: Refer to SZAVPlayerStatus.
    func avplayer(_ avplayer: SZAVPlayer, didChanged status: SZAVPlayerStatus)

    /// Device remote command delegate.
    /// - Parameters:
    ///   - remoteCommand: Refer to SZAVPlayerRemoteCommand
    func avplayer(_ avplayer: SZAVPlayer, didReceived remoteCommand: SZAVPlayerRemoteCommand) -> Bool
}

public class SZAVPlayer: UIView {

    public var isMuted: Bool = false
    public weak var delegate: SZAVPlayerDelegate?
    public typealias SeekCompletion = (Bool) -> Void

    public var totalTime: Float64 {
        guard let player = player, let currentItem = player.currentItem else {
            return 0
        }

        return CMTimeGetSeconds(currentItem.duration)
    }

    public var currentTime: Float64 {
        guard let player = player, let currentItem = player.currentItem else {
            return 0
        }

        return CMTimeGetSeconds(currentItem.currentTime())
    }

    private(set) public var playerLayer: AVPlayerLayer?
    private(set) public var player: AVPlayer?
    private(set) public var playerItem: AVPlayerItem?
    private(set) public var currentURLStr: String?

    private var urlAsset: AVURLAsset?
    private var assetLoader: SZAVPlayerAssetLoader?
    private var isObserverAdded: Bool = false

    private var timeObserver: Any?
    private var isSeeking: Bool = false
    private var isReadyToPlay: Bool = false
    private var isBufferBegin: Bool = false
    private var seekItem: SZAVPlayerSeekItem?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        SZAVPlayerCache.shared.setup(maxCacheSize: 100)
        setupRemoteTransportControls()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        removeNotifications()
        removePlayerObserver()
        if let player = player {
            if let currentItem = playerItem {
                removePlayerItemObserver(playerItem: currentItem)
            }

            player.replaceCurrentItem(with: nil)
        }

        delegate = nil
        playerItem = nil
    }

}

// MARK: - Actions

extension SZAVPlayer {

    // MARK: Public

    /// Setup player with specific url, after successfully setting the player status will change to ready to play.
    /// - Parameters:
    ///   - urlStr: The URL value for playing.
    ///   - uniqueID: The uniqueID to identify wether they are the same audio. If set to nil will use urlStr to create one.
    ///   - isVideo: Is video or not.
    public func setupPlayer(urlStr: String?, uniqueID: String?, isVideo: Bool = false) {
        let finalURLStr = urlStr ?? "fakeURL.com"
        guard let url = URL(string: finalURLStr) else { return }

        if let _ = player, let oldAssetLoader = assetLoader {
            oldAssetLoader.cleanup()
            self.assetLoader = nil
        }

        isReadyToPlay = false
        currentURLStr = finalURLStr
        let assetLoader = createAssetLoader(url: url, uniqueID: uniqueID)
        assetLoader.loadAsset { (asset) in
            if let _ = self.player {
                self.replacePalyerItem(asset: asset)
            } else {
                self.createPlayer(asset: asset, isVideo: isVideo)
            }
        }

        self.assetLoader = assetLoader
    }

    /// If player is ready to play, use this function to start playing.
    public func play() {
        guard let player = player, player.rate == 0 else { return }

        player.play()
    }

    /// Pause the playing.
    public func pause() {
        guard let player = player, player.rate == 1.0 else { return }

        player.pause()
    }

    /// Reset player to initial time.
    public func reset() {
        guard let player = player else { return }

        player.pause()
        seekPlayerToTime(time: 0, autoPlay: false) { [weak self] (finished) in
            guard let weakSelf = self, finished else { return }

            if let playerItem = weakSelf.player?.currentItem {
                let total = CMTimeGetSeconds(playerItem.duration)
                weakSelf.delegate?.avplayer(weakSelf, refreshed: 0, totalTime: total)
            }
        }
    }

    /// Move the player cursor to specific time.
    /// - Parameters:
    ///   - time: Target time
    ///   - autoPlay: Whether to play automatically when successfully seek to time.
    ///   - completion: The completion handler for any prior seek request that is still
    ///   in process will be invoked immediately with the finished parameter set to false.
    ///   If the new request completes without being interrupted by another seek request
    ///   or by any other operation the specified completion handler will be invoked with
    ///   the finished parameter set to true.
    public func seekPlayerToTime(time: Float64, autoPlay: Bool = true, completion: SeekCompletion?) {
        guard let player = player, let playerItem = playerItem else { return }

        guard isReadyToPlay else {
            seekItem = SZAVPlayerSeekItem(time: time, autoPlay: autoPlay, completion: completion)
            return
        }

        seekItem = nil
        let total = CMTimeGetSeconds(playerItem.duration)
        let didReachEnd = time >= total || abs(time - total) <= 0.5
        if didReachEnd {
            if let completion = completion {
                completion(true)
            }

            handlePlayerStatus(status: .playEnd)
            return
        }

        pause()
        isSeeking = true

        let toTime = CMTimeMakeWithSeconds(time, preferredTimescale: player.currentTime().timescale)
        player.seek(to: toTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] (finished) in
            self?.isSeeking = false

            if finished && autoPlay {
                self?.play()
            }

            if let completion = completion {
                completion(finished)
            }
        }
    }

    // MARK: Private

    private func replacePalyerItem(asset: AVURLAsset) {
        guard let player = player else { return }

        pause()

        if let playerItem = playerItem {
            if isObserverAdded {
                removePlayerItemObserver(playerItem: playerItem)
            }

            self.playerItem = nil
        }

        handlePlayerStatus(status: .loading)

        playerItem = AVPlayerItem(asset: asset)
        if let playerItem = playerItem {
            player.replaceCurrentItem(with: playerItem)
            self.addPlayerItemObserver(playerItem: playerItem)
        }
    }

}

// MARK: - Handles

extension SZAVPlayer {

    private func handlePlayerItemStatus(playerItem: AVPlayerItem) {
        guard playerItem == self.playerItem else {
            return
        }

        switch playerItem.status {
        case .readyToPlay:
            if !isReadyToPlay, let seekItem = seekItem {
                isReadyToPlay = true
                seekPlayerToTime(time: seekItem.time, autoPlay: seekItem.autoPlay, completion: seekItem.completion)
                self.seekItem = nil
            } else {
                isReadyToPlay = true
                handlePlayerStatus(status: .readyToPlay)
            }
        case .failed:
            handlePlayerStatus(status: .loadingFailed)
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    private func handlePlayerStatus(status: SZAVPlayerStatus) {
        delegate?.avplayer(self, didChanged: status)
    }

    private func handleLoadedTimeRanges(playerItem: AVPlayerItem) {
        // TODO
    }

    @objc func handlePlayToEnd(_ notification: Notification) {
        if let playerItem = playerItem,
            let item = notification.object as? AVPlayerItem,
            playerItem == item
        {
            handlePlayerStatus(status: .playEnd)
        }
    }

    @objc func handlePlaybackStalled(_ notification: Notification) {
        if let playerItem = playerItem,
            let item = notification.object as? AVPlayerItem,
            playerItem == item
        {
            handlePlayerStatus(status: .playbackStalled)
        }
    }

}

// MARK: - Observer

extension SZAVPlayer {

    private func addPlayerObserver() {
        guard let player = player else { return }

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: CMTimeValue(1.0), timescale: CMTimeScale(1.0)), queue: DispatchQueue.main, using: { [weak self] (time) in
            guard let weakSelf = self, let playerItem = weakSelf.player?.currentItem else { return }

            if weakSelf.isSeeking {
                return
            }

            let current = CMTimeGetSeconds(time)
            let total = CMTimeGetSeconds(playerItem.duration)
            weakSelf.delegate?.avplayer(weakSelf, refreshed: current, totalTime: total)
        })
    }

    private func removePlayerObserver() {
        guard let player = player, let timeObserver = timeObserver else { return }

        player.removeTimeObserver(timeObserver)
    }

    private func addPlayerItemObserver(playerItem: AVPlayerItem) {
        isObserverAdded = true
        playerItem.addObserver(self, forKeyPath: SZPlayerItemStatus, options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: SZPlayerLoadedTimeRanges, options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: SZPlayerPlaybackBufferEmpty, options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: SZPlayerPlaybackLikelyToKeepUp, options: .new, context: nil)
    }

    private func removePlayerItemObserver(playerItem: AVPlayerItem) {
        isObserverAdded = false
        playerItem.removeObserver(self, forKeyPath: SZPlayerItemStatus)
        playerItem.removeObserver(self, forKeyPath: SZPlayerLoadedTimeRanges)
        playerItem.removeObserver(self, forKeyPath: SZPlayerPlaybackBufferEmpty)
        playerItem.removeObserver(self, forKeyPath: SZPlayerPlaybackLikelyToKeepUp)
    }

    override public func observeValue(forKeyPath keyPath: String?,
                                      of object: Any?,
                                      change: [NSKeyValueChangeKey : Any]?,
                                      context: UnsafeMutableRawPointer?)
    {
        guard let playerItem = object as? AVPlayerItem else { return }

        switch keyPath {
        case SZPlayerItemStatus:
            handlePlayerItemStatus(playerItem: playerItem)
        case SZPlayerLoadedTimeRanges:
            handleLoadedTimeRanges(playerItem: playerItem)
        case SZPlayerPlaybackBufferEmpty:
            if isReadyToPlay {
                isBufferBegin = true
                handlePlayerStatus(status: .bufferBegin)
            }
        case SZPlayerPlaybackLikelyToKeepUp:
            if isReadyToPlay && isBufferBegin {
                isBufferBegin = false
                handlePlayerStatus(status: .bufferEnd)
            }
        default:
            break
        }
    }

}

// MARK: - Notification

extension SZAVPlayer {

    func addNotificationsForPlayer() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(handlePlayToEnd(_:)), name: Notification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        center.addObserver(self, selector: #selector(handlePlaybackStalled(_:)), name: Notification.Name.AVPlayerItemPlaybackStalled, object: nil)
    }

    func removeNotifications() {
        NotificationCenter.default.removeObserver(self)
    }

}

// MARK: - AudioSession

extension SZAVPlayer {

    public static func activeAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true, options: [])
        } catch {
            SZLogError("ActiveAudioSession failed.")
        }
    }

    public static func deactiveAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient)
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            SZLogError("DeactiveAudioSession failed.")
        }
    }

    public func setupNowPlaying(title: String, description: String, image: UIImage?) {
        var nowPlayingInfo = [String : Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = description

        if let image = image {
            let mediaItem = MPMediaItemArtwork(boundsSize: image.size) { size in
                return image
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = mediaItem
        }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem?.currentTime().seconds
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = playerItem?.asset.duration.seconds
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] event in
            guard let weakSelf = self else {
                return .commandFailed
            }

            return weakSelf.handleRemoteCommand(remoteCommand: .play)
        }

        commandCenter.pauseCommand.addTarget { [weak self] event in
            guard let weakSelf = self else {
                return .commandFailed
            }

            return weakSelf.handleRemoteCommand(remoteCommand: .pause)
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            guard let weakSelf = self else {
                return .commandFailed
            }

            return weakSelf.handleRemoteCommand(remoteCommand: .next)
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            guard let weakSelf = self else {
                return .commandFailed
            }

            return weakSelf.handleRemoteCommand(remoteCommand: .next)
        }
    }

    private func handleRemoteCommand(remoteCommand: SZAVPlayerRemoteCommand) -> MPRemoteCommandHandlerStatus {
        if let executeSucceed = delegate?.avplayer(self, didReceived: remoteCommand), executeSucceed {
            return .success
        }

        return .commandFailed
    }

}

// MARK: - SZAVPlayerItemDelegate

extension SZAVPlayer: SZAVPlayerAssetLoaderDelegate {

    public func assetLoaderDidFinishDownloading(_ assetLoader: SZAVPlayerAssetLoader) {
        SZLogInfo("did finish downloading")
    }

    public func assetLoader(_ assetLoader: SZAVPlayerAssetLoader, didDownload bytes: Int64) {
        //        SZLogInfo("did download \(bytes)/\(expectedToReceive)")
    }

    public func assetLoader(_ assetLoader: SZAVPlayerAssetLoader, downloadingFailed error: Error) {
        SZLogError(String(describing: error))
    }

}

// MARK: - Getter

extension SZAVPlayer {

    private func createPlayer(asset: AVURLAsset, isVideo: Bool = false) {
        handlePlayerStatus(status: .loading)

        playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        player?.isMuted = isMuted
        player?.automaticallyWaitsToMinimizeStalling = false

        if isVideo {
            createPlayerLayer()
        }
        addPlayerObserver()
        addPlayerItemObserver(playerItem: playerItem!)
        addNotificationsForPlayer()
    }

    private func createAssetLoader(url: URL, uniqueID: String?) -> SZAVPlayerAssetLoader {
        let loader = SZAVPlayerAssetLoader(url: url)
        let finalUniqueID = uniqueID ?? SZAVPlayerFileSystem.uniqueID(url: url)
        loader.uniqueID = finalUniqueID
        loader.delegate = self

        return loader
    }

    private func createPlayerLayer() {
        let layer = AVPlayerLayer(player: player)
        layer.frame = bounds
        layer.videoGravity = .resizeAspect

        self.layer.addSublayer(layer)
        playerLayer = layer
    }

}
