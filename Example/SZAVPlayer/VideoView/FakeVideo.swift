//
//  FakeAudio.swift
//
//  Created by CaiSanze on 2019/11/29.
//

import UIKit

class FakeVideo: NSObject {

    var cover: String = ""
    var title: String = ""
    var url: String = ""

    var isSelected: Bool = false
    var isFirst: Bool = false
    var isLast: Bool = false

    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? FakeVideo {
            return url == object.url
        }

        return false
    }

    static func fake1() -> FakeVideo {
        let video = FakeVideo()
        video.cover = "https://img9.doubanio.com/img/trailer/small/1509216846.jpg"
        video.title = "Titanic"
        video.url = "http://vt1.doubanio.com/202001021917/01b91ce2e71fd7f671e226ffe8ea0cda/view/movie/M/301120229.mp4"

        return video
    }

    static func fake2() -> FakeVideo {
        let video = FakeVideo()
        video.cover = "https://img3.doubanio.com/img/trailer/small/2412648020.jpg"
        video.title = "Inception"
        video.url = "http://vt1.doubanio.com/202001022001/7264e07afc6d8347c15f61c247c36f0e/view/movie/M/302100358.mp4"

        return video
    }

    static func fake3() -> FakeVideo {
        let video = FakeVideo()
        video.cover = "https://img9.doubanio.com/img/trailer/small/2209820525.jpg"
        video.title = "Interstellar"
        video.url = "http://vt1.doubanio.com/202001021947/7ae57141cc259bfb49e75bdf6b716caf/view/movie/M/301650578.mp4"

        return video
    }

    static func fake4() -> FakeVideo {
        let video = FakeVideo()
        video.cover = ""
        video.title = "Test Long Video"
        video.url = "https://seed128.bitchute.com/vBEqxcyTQvca/ucXUjHNSZo9G.mp4"

        return video
    }

}

