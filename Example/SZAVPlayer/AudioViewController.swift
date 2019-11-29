//
//  AudioViewController.swift
//  SZAVPlayer_Example
//
//  Created by CaiSanze on 2019/11/29.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import UIKit
import SZAVPlayer

class AudioViewController: UIViewController {

    private lazy var audioPlayer = createAudioPlayer()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white

        let audio = FakeAudio.fake()
        audioPlayer.setupPlayer(urlStr: audio.url, uniqueID: nil)
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
