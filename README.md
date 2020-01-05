# SZAVPlayer

[![CI Status](https://img.shields.io/travis/eroscai/SZAVPlayer.svg?style=flat)](https://travis-ci.org/eroscai/SZAVPlayer)
[![Version](https://img.shields.io/cocoapods/v/SZAVPlayer.svg?style=flat)](https://cocoapods.org/pods/SZAVPlayer)
[![License](https://img.shields.io/cocoapods/l/SZAVPlayer.svg?style=flat)](https://cocoapods.org/pods/SZAVPlayer)
[![Platform](https://img.shields.io/cocoapods/p/SZAVPlayer.svg?style=flat)](https://cocoapods.org/pods/SZAVPlayer)

中文说明请看[这里](https://github.com/eroscai/SZAVPlayer/wiki/iOS%E5%9F%BA%E4%BA%8EAVPlayer%E5%AE%9E%E7%8E%B0%E9%9F%B3%E8%A7%86%E9%A2%91%E6%92%AD%E6%94%BE%E5%92%8C%E7%BC%93%E5%AD%98)

SZAVPlayer is a lightweight audio/video player library, based on `AVPlayer`, pure-Swift and support cache.

## Features

- [x] Encapsulate the state changes of `AVPlayer` and `AVPlayerItem` and output them uniformly, greatly reducing the implementation cost of audio play.
- [x] Achieved full control of `AVPlayer` data loading, based on `AVAssetResourceLoaderDelegate`. Through the Range request and corresponding cache, it can respond to player's requests ASAP. It also can play the cached audio normally in the weak network and no network enviroment.
- [x] Load AVAsset asynchronously to not blocking the main thread.
- [x] Support setting cache size munually and also support cleaning.

## Usage

1. Create player and set delegate.

    ```swift
    let player = SZAVPlayer()
    player.delegate = self
    
    audioPlayer = player
    ```

2. Setup player with url.

    ```swift
    // uniqueID is to identify wether they are the same audio. If set to nil will use urlStr to create one.
    audioPlayer.setupPlayer(urlStr: audio.url, uniqueID: nil)
    
    // if you want play video, pass an additional parameter `isVideo`.
    videoPlayer.setupPlayer(urlStr: video.url, uniqueID: nil, isVideo: true)
    ```

3. Implement `SZAVPlayerDelegate`.

    ```swift
    extension AudioViewController: SZAVPlayerDelegate {
    
        func avplayer(_ avplayer: SZAVPlayer, refreshed currentTime: Float64, loadedTime: Float64, totalTime: Float64) {
            progressView.update(currentTime: currentTime, totalTime: totalTime)
        }
    
        func avplayer(_ avplayer: SZAVPlayer, didChanged status: SZAVPlayerStatus) {
            switch status {
            case .readyToPlay:
                SZLogInfo("ready to play")
                if playerStatus == .playing {
                    audioPlayer.play()
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
                if playerStatus == .stalled {
                    audioPlayer.play()
                }
            case .playbackStalled:
                SZLogInfo("playback stalled")
                playerStatus = .stalled
            }
        }
    
        func avplayer(_ avplayer: SZAVPlayer, didReceived remoteCommand: SZAVPlayerRemoteCommand) -> Bool {
            return false
        }
    
    }
    ```
    
4. Replace new audio.

    ```swift
    // The setupPlayer function will automatically determine if it has been setup before. 
    // If it is, it will directly call the replacePalyerItem function to replace the new audio.
    audioPlayer.setupPlayer(urlStr: audio.url, uniqueID: nil)
    ```
    
5. Seek player to time.

    ```swift
    audioPlayer.seekPlayerToTime(time: currentTime, completion: nil)
    ```
    
6. Set max cache size.

    ```swift
    // Unit: MB, if reached the max size, it will automatically trim the cache.
    SZAVPlayerCache.shared.setup(maxCacheSize: 100)
    ```
    
7. Clean all cache.

    ```swift
    SZAVPlayerCache.shared.cleanCache()
    ```

## Example

The Example project has implemented a complete play example, including play/pause/previous/next/seekToTime/cleanCache, etc. 

To run the example project, clone the repo, and run `pod install` from the Example directory first.

> If play failed in simulator, try exit simulator completely and restart again.

## Requirements

- iOS 10.0+
- Swift 5.0+

## Installation

SZAVPlayer is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'SZAVPlayer'
```

## Author

eroscai, csz0102@gmail.com

## License

SZAVPlayer is available under the MIT license. See the LICENSE file for more info.
