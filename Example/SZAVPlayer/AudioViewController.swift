//
//  AudioViewController.swift
//  SZAVPlayer_Example
//
//  Created by CaiSanze on 2019/11/29.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import UIKit
import SZAVPlayer
import SnapKit

class AudioViewController: UIViewController {

    private lazy var audioPlayer = createAudioPlayer()
    private let audios: [FakeAudio] = [
        FakeAudio.fake1(),
        FakeAudio.fake2(),
        FakeAudio.fake3(),
    ]
    private var currentAudio: FakeAudio?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white

        addSubviews()
    }

}

// MARK: - Configure UI

extension AudioViewController {

    private func addSubviews() {
        let playBtn = UIButton()
        playBtn.addTarget(self, action: #selector(handlePlayBtnClick), for: .touchUpInside)
        playBtn.setImage(UIImage(named: "play"), for: .normal)
        view.addSubview(playBtn)
        playBtn.snp.makeConstraints { (make) in
            make.width.height.equalTo(40)
            make.center.equalToSuperview()
        }

        let nextBtn = UIButton()
        nextBtn.addTarget(self, action: #selector(handleNextBtnClick), for: .touchUpInside)
        nextBtn.setImage(UIImage(named: "next"), for: .normal)
        view.addSubview(nextBtn)
        nextBtn.snp.makeConstraints { (make) in
            make.width.height.equalTo(30)
            make.centerX.equalToSuperview().offset(100)
            make.centerY.equalToSuperview()
        }

        let previousBtn = UIButton()
        previousBtn.addTarget(self, action: #selector(handlePreviousBtnClick), for: .touchUpInside)
        previousBtn.setImage(UIImage(named: "previous"), for: .normal)
        view.addSubview(previousBtn)
        previousBtn.snp.makeConstraints { (make) in
            make.width.height.equalTo(30)
            make.centerX.equalToSuperview().offset(-100)
            make.centerY.equalToSuperview()
        }
    }

}

// MARK: - Actions

extension AudioViewController {

    @objc func handlePlayBtnClick() {
        currentAudio = audios.first
        if let audio = currentAudio {
            audioPlayer.setupPlayer(urlStr: audio.url, uniqueID: nil)
        }
    }

    @objc func handleNextBtnClick() {

    }

    @objc func handlePreviousBtnClick() {

    }

}

// MARK: - SZAVPlayerDatabase

extension AudioViewController: SZAVPlayerDelegate {

    func avplayer(_ avplayer: SZAVPlayer, refreshed currentTime: Float64, loadedTime: Float64, totalTime: Float64) {

    }

    func avplayer(_ avplayer: SZAVPlayer, didChanged status: SZAVPlayerStatus) {
        switch status {
        case .readyToPlay:
            SZLogInfo("ready to play")
            audioPlayer.play()
        case .playEnd:
            SZLogInfo("play end")
        case .loading:
            SZLogInfo("loading")
        case .loadingFailed:
            SZLogInfo("loading failed")
        case .bufferBegin:
            SZLogInfo("buffer begin")
        case .bufferEnd:
            SZLogInfo("buffer end")
        case .playFailed:
            SZLogInfo("play failed")
        }
    }

    func avplayer(_ avplayer: SZAVPlayer, didReceived remoteCommand: SZAVPlayerRemoteCommand) -> Bool {
        return false
    }

}

// MARK: - Getter

extension AudioViewController {

    private func createAudioPlayer() -> SZAVPlayer {
        let player = SZAVPlayer()
        player.delegate = self

        return player
    }

}
