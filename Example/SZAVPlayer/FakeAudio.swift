//
//  FakeAudio.swift
//
//  Created by CaiSanze on 2019/11/29.
//

import UIKit

class FakeAudio: NSObject {

    var cover: String = ""
    var title: String = ""
    var url: String = ""

    var isSelected: Bool = false
    var isFirst: Bool = false
    var isLast: Bool = false

    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? FakeAudio {
            return url == object.url
        }

        return false
    }

    static func fake() -> FakeAudio {
        let audio = FakeAudio()
        audio.cover = "http://p2.music.126.net/nEtbaHINgXyGz3mLOELUhg==/6637751697108298.jpg?param=400y400"
        audio.title = "Where'd You Go"
        audio.url = "http://music.163.com/song/media/outer/url?id=1345171.mp3"

        return audio
    }

    static func fake2() -> FakeAudio {
        let audio = FakeAudio()
        audio.cover = "http://p2.music.126.net/-2sXMGhK4vw6KlzhW_YayQ==/109951163780662542.jpg?param=400y400"
        audio.title = "Do It"
        audio.url = "http://music.163.com/song/media/outer/url?id=27845048.mp3"

        return audio
    }

    static func fake3() -> FakeAudio {
        let audio = FakeAudio()
        audio.cover = "http://p2.music.126.net/FGhXCsQCEZOjTRc8K8XsYQ==/109951164461390248.jpg?param=400y400"
        audio.title = "Love poem"
        audio.url = "http://music.163.com/song/media/outer/url?id=1400436688.mp3"

        return audio
    }

}

