//
//  STAudioPlayerSlider.swift
//
//  Created by CaiSanze on 2019/11/6.
//

import UIKit

class AudioPlayerSlider: UISlider {

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        return CGRect(origin: bounds.origin, size: CGSize(width: bounds.width, height: 6))
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        var bounds: CGRect = self.bounds
        bounds = bounds.insetBy(dx: -20, dy: -20)

        return bounds.contains(point)
    }

}
