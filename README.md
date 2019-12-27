# SZAVPlayer

[![CI Status](https://img.shields.io/travis/eroscai/SZAVPlayer.svg?style=flat)](https://travis-ci.org/eroscai/SZAVPlayer)
[![Version](https://img.shields.io/cocoapods/v/SZAVPlayer.svg?style=flat)](https://cocoapods.org/pods/SZAVPlayer)
[![License](https://img.shields.io/cocoapods/l/SZAVPlayer.svg?style=flat)](https://cocoapods.org/pods/SZAVPlayer)
[![Platform](https://img.shields.io/cocoapods/p/SZAVPlayer.svg?style=flat)](https://cocoapods.org/pods/SZAVPlayer)

中文说明请看[这里](https://github.com/eroscai/SZAVPlayer/wiki/iOS%E5%9F%BA%E4%BA%8EAVPlayer%E5%AE%9E%E7%8E%B0%E9%9F%B3%E8%A7%86%E9%A2%91%E6%92%AD%E6%94%BE%E5%92%8C%E7%BC%93%E5%AD%98)

SZAVPlayer is a lightweight audio player library, based on `AVPlayer`, pure-Swift. Video playing will be supported later.

## Features

- [x] Encapsulate the state changes of `AVPlayer` and `AVPlayerItem` and output them uniformly, greatly reducing the implementation cost of audio play.
- [x] Achieved full control of `AVPlayer` data loading, based on `AVAssetResourceLoaderDelegate`. Through the Range request and corresponding cache, it can respond to player's requests ASAP. It also can play the cached audio normally in the weak network and no network enviroment.
- [x] Load AVAsset asynchronously to not blocking the main thread.
- [x] Support setting cache size munually and also support cleaning.

## Example

The Example project has implemented a complete play example, including play/pause/previous/next/seekToTime/cleanCache, etc. 

To run the example project, clone the repo, and run `pod install` from the Example directory first.

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
