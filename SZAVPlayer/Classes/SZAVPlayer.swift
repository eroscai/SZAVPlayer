//
//  SZAVPlayer.swift
//
//  Created by CaiSanze on 2019/11/27.
//

import UIKit
import AVFoundation
import CoreAudio
import MediaPlayer

private let SZPlayerItemStatus = "status"
private let SZPlayerLoadedTimeRanges = "loadedTimeRanges"
private let SZPlayerPlaybackBufferEmpty = "playbackBufferEmpty"
private let SZPlayerPlaybackLikelyToKeepUp = "playbackLikelyToKeepUp"

public enum SZAVPlayerStatus: Int {
    case loading = 0
    case loadingFailed
    case readyToPlay
    case playEnd
    case playFailed
    case bufferBegin
    case bufferEnd
}

public enum SZAVPlayerRemoteCommand {
    case play
    case pause
    case next
    case previous
}

public protocol SZAVPlayerDelegate: AnyObject {
    func avplayer(_ avplayer: SZAVPlayer, refreshed currentTime: Float64, loadedTime: Float64, totalTime: Float64)
    func avplayer(_ avplayer: SZAVPlayer, didChanged status: SZAVPlayerStatus)
    func avplayer(_ avplayer: SZAVPlayer, didReceived remoteCommand: SZAVPlayerRemoteCommand) -> Bool
}

public class SZAVPlayer: UIView {

    public var isMuted: Bool = false
    public weak var delegate: SZAVPlayerDelegate?

    private(set) public var playerLayer: AVPlayerLayer?
    private(set) public var player: AVPlayer?
    private(set) public var playerItem: SZAVPlayerItem?
    private(set) public var loadedTime: Float64 = 0
    private(set) public var currentURLStr: String?

    private var urlAsset: AVURLAsset?

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

    private var timeObserver: Any?
    private var isSeeking: Bool = false
    private var isReadyToPlay: Bool = false
    private var isBufferBegin: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        SZAVPlayerCache.shared.setup(maxCacheCount: 0)
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

    public func setupPlayer(urlStr: String?, uniqueID: String?, isVideo: Bool = false) {
        let finalURLStr = urlStr ?? "fakeURL.com"
        guard let url = URL(string: finalURLStr) else { return }

        currentURLStr = finalURLStr
        if let _ = player {
            replacePalyerItem(url: url, uniqueID: uniqueID)
        } else {
            createPlayer(url: url, uniqueID: uniqueID, isVideo: isVideo)
        }
    }

    public func play() {
        guard let player = player, player.rate == 0 else { return }

        player.play()
    }

    public func pause() {
        guard let player = player, player.rate == 1.0 else { return }

        player.pause()
    }

    public func reset() {
        guard let player = player else { return }

        player.pause()
        seekPlayerToTime(time: 0, autoPlay: false) { [weak self] in
            guard let weakSelf = self else { return }

            if let playerItem = weakSelf.player?.currentItem {
                let total = CMTimeGetSeconds(playerItem.duration)
                weakSelf.delegate?.avplayer(weakSelf, refreshed: 0, loadedTime: 0, totalTime: total)
            }
        }
    }

    public func seekPlayerToTime(time: Float64, autoPlay: Bool = true, completion: (() -> Void)?) {
        guard let player = player else { return }

        pause()
        isSeeking = true

        let toTime = CMTimeMakeWithSeconds(time, preferredTimescale: player.currentTime().timescale)
        player.seek(to: toTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] (finished) in
            self?.isSeeking = false

            if autoPlay {
                self?.play()
            }

            if let completion = completion {
                completion()
            }
        }
    }

    // MARK: Private

    private func replacePalyerItem(url: URL, uniqueID: String?) {
        guard let player = player else { return }

        isReadyToPlay = false
        pause()

        if let playerItem = playerItem {
            if playerItem.isObserverAdded {
                removePlayerItemObserver(playerItem: playerItem)
            }
            playerItem.cleanup()
            self.playerItem = nil
        }

        handlePlayerStatus(status: .loading)

        playerItem = createPlayerItem(url: url, uniqueID: uniqueID)
        if let playerItem = playerItem {
            if playerItem.isLocalData {
                player.replaceCurrentItem(with: playerItem)
                self.addPlayerItemObserver(playerItem: playerItem)
            } else if let urlAsset = playerItem.urlAsset {
                urlAsset.loadValuesAsynchronously(forKeys: ["playable"]) {
                    player.replaceCurrentItem(with: playerItem)
                    self.addPlayerItemObserver(playerItem: playerItem)
                }
            }
        }
    }

}

// MARK: - Handles

extension SZAVPlayer {

    private func handlePlayerItemStatus(playerItem: AVPlayerItem) {
        switch playerItem.status {
        case .readyToPlay:
            isReadyToPlay = true
            handlePlayerStatus(status: .readyToPlay)
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
        guard let firstRange = playerItem.loadedTimeRanges.first else { return }

        let start = CMTimeGetSeconds(firstRange.timeRangeValue.start)
        let duration = CMTimeGetSeconds(firstRange.timeRangeValue.duration)
        loadedTime = start + duration
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
            handlePlayerStatus(status: .playFailed)
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
            weakSelf.delegate?.avplayer(weakSelf, refreshed: current, loadedTime: weakSelf.loadedTime, totalTime: total)
        })
    }

    private func removePlayerObserver() {
        guard let player = player, let timeObserver = timeObserver else { return }

        player.removeTimeObserver(timeObserver)
    }

    private func addPlayerItemObserver(playerItem: SZAVPlayerItem) {
        playerItem.isObserverAdded = true
        playerItem.addObserver(self, forKeyPath: SZPlayerItemStatus, options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: SZPlayerLoadedTimeRanges, options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: SZPlayerPlaybackBufferEmpty, options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: SZPlayerPlaybackLikelyToKeepUp, options: .new, context: nil)
    }

    private func removePlayerItemObserver(playerItem: SZAVPlayerItem) {
        playerItem.isObserverAdded = false
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

    static func activeAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true, options: [])
        } catch {
            SZLogError("ActiveAudioSession failed.")
        }
    }

    static func deactiveAudioSession() {
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

extension SZAVPlayer: SZAVPlayerItemDelegate {

    public func playerItem(_ playerItem: SZAVPlayerItem, didFinishDownloading data: Data, fullyDownloaded: Bool) {
        SZLogInfo("did finish downloading：\(data.count)")

        if fullyDownloaded {
            SZAVPlayerCache.shared.save(data: data, uniqueID: playerItem.uniqueID)
        }
    }

    public func playerItem(_ playerItem: SZAVPlayerItem, didDownload bytes: Int64, expectedToReceive: Int64) {
        SZLogInfo("did download \(bytes)/\(expectedToReceive)")
    }

    public func playerItem(_ playerItem: SZAVPlayerItem, downloadingFailed error: Error) {
        SZLogError(String(describing: error))
    }

}

// MARK: - Getter

extension SZAVPlayer {

    private func createPlayer(url: URL, uniqueID: String?, isVideo: Bool = false) {
        handlePlayerStatus(status: .loading)

        playerItem = createPlayerItem(url: url, uniqueID: uniqueID)
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

    private func createPlayerItem(url: URL, uniqueID: String?) -> SZAVPlayerItem {
        var item: SZAVPlayerItem
        let finalUniqueID = uniqueID ?? SZAVPlayerFileSystem.uniqueID(url: url)
        let isLocalURL = url.isFileURL || url.scheme == nil
        if isLocalURL, let data = try? Data(contentsOf: url) {
            item = SZAVPlayerItem(data: data, mimeType: "audio/mpeg", isAudio: true)
        } else {
            if let mimeType = SZAVPlayerDatabase.shared.mimeType(uniqueID: finalUniqueID),
                let data = SZAVPlayerCache.data(uniqueID: finalUniqueID)
            {
                item = SZAVPlayerItem(data: data, mimeType: mimeType, isAudio: true)
            } else {
                item = SZAVPlayerItem(url: url)
            }
        }
        item.uniqueID = finalUniqueID
        item.delegate = self

        return item
    }

    private func createAsset(url: URL) -> AVURLAsset {
        let asset = AVURLAsset(url: url)

        return asset
    }

    private func createPlayerLayer() {
        let layer = AVPlayerLayer(player: player)
        layer.frame = bounds
        layer.videoGravity = .resizeAspect

        self.layer.addSublayer(layer)
        playerLayer = layer
    }

}
