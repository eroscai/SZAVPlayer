//
//  VideoViewController.swift
//  SZAVPlayer_Example
//
//  Created by CaiSanze on 2020/01/02.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import UIKit
import SZAVPlayer
import SnapKit

class VideoViewController: UIViewController {

    private lazy var videoTitleLabel: UILabel = createTitleLabel()
    private lazy var progressView: AudioPlayerProgressView = createProgressView()
    private lazy var playBtn: UIButton = createPlayBtn()
    private lazy var previousBtn: UIButton = createPreviousBtn()
    private lazy var nextBtn: UIButton = createNextBtn()
    private lazy var cleanCacheBbtn: UIButton = createCleanCacheBtn()

    private lazy var videoPlayer: SZAVPlayer = createVideoPlayer()
    private let videos: [FakeVideo] = [
        FakeVideo.fake1(),
        FakeVideo.fake2(),
        FakeVideo.fake3(),
    ]
    private var currentVideo: FakeVideo?
    private var isPaused: Bool = false
    private var playerControllerEvent: PlayerControllerEventType = .none

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white

        addSubviews()
        SZAVPlayerCache.shared.setup(maxCacheSize: 100)

        currentVideo = videos.first
        updateView()
    }

}

// MARK: - Configure UI

extension VideoViewController {

    private func updateView() {
        guard let video = currentVideo else {
            return
        }

        videoTitleLabel.text = video.title

        if let _ = findVideo(currentVideo: video, findNext: true) {
            nextBtn.isEnabled = true
        } else {
            nextBtn.isEnabled = false
        }

        if let _ = findVideo(currentVideo: video, findNext: false) {
            previousBtn.isEnabled = true
        } else {
            previousBtn.isEnabled = false
        }

        if playerControllerEvent == .playing {
            playBtn.setImage(UIImage(named: "pause"), for: .normal)
        } else {
            playBtn.setImage(UIImage(named: "play"), for: .normal)
        }

    }

    private func addSubviews() {
        view.addSubview(videoPlayer)
        videoPlayer.snp.makeConstraints { (make) in
            make.left.right.equalToSuperview().inset(15)
            make.height.equalTo(200)
            make.centerX.equalToSuperview()

            var offsetTop: CGFloat = (navigationController?.navigationBar.frame.maxY ?? 0) + 15
            offsetTop = max(64, offsetTop)
            make.top.equalTo(offsetTop)
        }

        view.addSubview(videoTitleLabel)
        videoTitleLabel.snp.makeConstraints { (make) in
            make.left.right.equalToSuperview().inset(15)
            make.height.equalTo(30)
            make.centerX.equalToSuperview()
            make.top.equalTo(videoPlayer.snp.bottom).offset(30)
        }

        view.addSubview(progressView)
        progressView.snp.makeConstraints { (make) in
            make.left.right.equalToSuperview().inset(15)
            make.height.equalTo(20)
            make.centerX.equalToSuperview()
            make.top.equalTo(videoTitleLabel.snp.bottom).offset(20)
        }

        view.addSubview(playBtn)
        playBtn.snp.makeConstraints { (make) in
            make.width.height.equalTo(40)
            make.centerX.equalToSuperview()
            make.top.equalTo(progressView.snp.bottom).offset(30)
        }

        view.addSubview(nextBtn)
        nextBtn.snp.makeConstraints { (make) in
            make.width.height.equalTo(30)
            make.centerX.equalToSuperview().offset(100)
            make.top.equalTo(progressView.snp.bottom).offset(30)
        }

        view.addSubview(previousBtn)
        previousBtn.snp.makeConstraints { (make) in
            make.width.height.equalTo(30)
            make.centerX.equalToSuperview().offset(-100)
            make.top.equalTo(progressView.snp.bottom).offset(30)
        }

        view.addSubview(cleanCacheBbtn)
        cleanCacheBbtn.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-100)
            make.width.equalTo(200)
            make.height.equalTo(50)
        }
    }

}

// MARK: - Actions

extension VideoViewController {

    @objc func handlePlayBtnClick() {
        if playerControllerEvent == .playing {
            pauseVideo()
        } else {
            playVideo()
        }
    }

    @objc func handleNextBtnClick() {
        isPaused = false
        if let currentVideo = currentVideo,
            let video = findVideo(currentVideo: currentVideo, findNext: true)
        {
            self.currentVideo = video
            progressView.reset()
            playVideo()
        } else {
            SZLogError("No video!")
        }

        updateView()
    }

    @objc func handlePreviousBtnClick() {
        isPaused = false
        if let currentVideo = currentVideo,
            let video = findVideo(currentVideo: currentVideo, findNext: false)
        {
            self.currentVideo = video
            progressView.reset()
            playVideo()
        } else {
            SZLogError("No video!")
        }

        updateView()
    }

    private func handlePlayEnd() {
        if let currentVideo = currentVideo,
            let _ = findVideo(currentVideo: currentVideo, findNext: true)
        {
            handleNextBtnClick()
        } else {
            playerControllerEvent = .none
            videoPlayer.reset()
            updateView()
        }
    }

    private func playVideo() {
        guard let video = currentVideo else {
            return
        }

        if isPaused {
            isPaused = false
            videoPlayer.play()
        } else {
            videoPlayer.pause()
            videoPlayer.setupPlayer(urlStr: video.url, uniqueID: nil, isVideo: true)
        }
        playerControllerEvent = .playing
        updateView()
    }

    private func pauseVideo() {
        isPaused = true
        videoPlayer.pause()
        playerControllerEvent = .paused
        updateView()
    }

    private func findVideo(currentVideo: FakeVideo, findNext: Bool) -> FakeVideo? {
        let playlist = videos
        let videos = findNext ? playlist : playlist.reversed()
        var currentVideoDetected: Bool = false
        for video in videos {
            if currentVideoDetected {
                return video
            } else if video == currentVideo {
                currentVideoDetected = true
            }
        }

        return nil
    }

    @objc private func handleCleanCacheBtnClick() {
        SZAVPlayerCache.shared.cleanCache()

        let alert = UIAlertController(title: "Clean Succeed~", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

}

// MARK: - AudioPlayerProgressViewDelegate

extension VideoViewController: AudioPlayerProgressViewDelegate {

    func progressView(_ progressView: AudioPlayerProgressView, didChanged currentTime: Float64) {
        videoPlayer.seekPlayerToTime(time: currentTime, completion: nil)
    }

}

// MARK: - SZAVPlayerDelegate

extension VideoViewController: SZAVPlayerDelegate {

    func avplayer(_ avplayer: SZAVPlayer, refreshed currentTime: Float64, loadedTime: Float64, totalTime: Float64) {
        progressView.update(currentTime: currentTime, totalTime: totalTime)
    }

    func avplayer(_ avplayer: SZAVPlayer, didChanged status: SZAVPlayerStatus) {
        switch status {
        case .readyToPlay:
            SZLogInfo("ready to play")
            if playerControllerEvent == .playing {
                videoPlayer.play()
            }
        case .playEnd:
            SZLogInfo("play end")
            handlePlayEnd()
        case .loading:
            SZLogInfo("loading")
        case .loadingFailed:
            SZLogInfo("loading failed")
        case .bufferBegin:
            SZLogInfo("buffer begin")
        case .bufferEnd:
            SZLogInfo("buffer end")
            if playerControllerEvent == .stalled {
                videoPlayer.play()
            }
        case .playbackStalled:
            SZLogInfo("playback stalled")
            playerControllerEvent = .stalled
        }
    }

    func avplayer(_ avplayer: SZAVPlayer, didReceived remoteCommand: SZAVPlayerRemoteCommand) -> Bool {
        return false
    }

}

// MARK: - Getter

extension VideoViewController {

    private func createTitleLabel() -> UILabel {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 20)
        label.textAlignment = .center
        label.textColor = .black

        return label
    }

    private func createProgressView() -> AudioPlayerProgressView {
        let view = AudioPlayerProgressView()
        view.delegate = self

        return view
    }

    private func createVideoPlayer() -> SZAVPlayer {
        let player = SZAVPlayer()
        player.backgroundColor = .black
        player.delegate = self

        return player
    }

    private func createPlayBtn() -> UIButton {
        let btn = UIButton()
        btn.addTarget(self, action: #selector(handlePlayBtnClick), for: .touchUpInside)
        btn.setImage(UIImage(named: "play"), for: .normal)

        return btn
    }

    private func createPreviousBtn() -> UIButton {
        let btn = UIButton()
        btn.addTarget(self, action: #selector(handlePreviousBtnClick), for: .touchUpInside)
        btn.setImage(UIImage(named: "previous"), for: .normal)

        return btn
    }

    private func createNextBtn() -> UIButton {
        let btn = UIButton()
        btn.addTarget(self, action: #selector(handleNextBtnClick), for: .touchUpInside)
        btn.setImage(UIImage(named: "next"), for: .normal)

        return btn
    }

    private func createCleanCacheBtn() -> UIButton {
        let btn = UIButton()
        btn.setTitle("Clean Cache", for: .normal)
        btn.setTitleColor(.red, for: .normal)
        btn.titleLabel?.font = .boldSystemFont(ofSize: 18)
        btn.addTarget(self, action: #selector(handleCleanCacheBtnClick), for: .touchUpInside)

        return btn
    }

}
