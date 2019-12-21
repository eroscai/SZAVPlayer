//
//  AudioPlayerProgressView.swift
//
//  Created by CaiSanze on 2019/11/6.
//

import UIKit

protocol AudioPlayerProgressViewDelegate: AnyObject {
    func progressView(_ progressView: AudioPlayerProgressView, didChanged currentTime: Float64)
}

class AudioPlayerProgressView: UIView {

    public weak var delegate: AudioPlayerProgressViewDelegate?
    private(set) public var isDraggingSlider: Bool = false

    private lazy var progressSlider: AudioPlayerSlider = createProgressSlider()
    private lazy var minTimeLabel: UILabel = createTimeLabel()
    private lazy var maxTimeLabel: UILabel = createTimeLabel()
    private var progressSliderOriginalBounds: CGRect?

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

// MARK: - Configure UI

extension AudioPlayerProgressView {

    public func update(currentTime: Float64, totalTime: Float64) {
        guard currentTime >= 0 && totalTime >= 0 && totalTime >= currentTime else { return }

        if isDraggingSlider {
            return
        }

        minTimeLabel.text = minuteAndSecondStr(second: currentTime)
        maxTimeLabel.text = minuteAndSecondStr(second: totalTime)
        progressSlider.value = Float(currentTime)
        progressSlider.maximumValue = Float(totalTime)
    }

    public func reset() {
        minTimeLabel.text = "00:00"
        maxTimeLabel.text = "--:--"
        progressSlider.value = 0
    }

    private func addSubviews() {
        addSubview(progressSlider)
        progressSlider.snp.makeConstraints { (make) in
            make.left.right.equalTo(self).inset(60)
            make.height.equalTo(6)
            make.centerY.equalTo(self)
        }

        minTimeLabel.textAlignment = .right
        addSubview(minTimeLabel)
        minTimeLabel.snp.makeConstraints { (make) in
            make.width.equalTo(48)
            make.height.equalTo(self)
            make.right.equalTo(progressSlider.snp.left).offset(-12)
            make.centerY.equalTo(self)
        }

        maxTimeLabel.textAlignment = .left
        addSubview(maxTimeLabel)
        maxTimeLabel.snp.makeConstraints { (make) in
            make.width.equalTo(48)
            make.height.equalTo(self)
            make.left.equalTo(progressSlider.snp.right).offset(12)
            make.centerY.equalTo(self)
        }

    }

}

// MARK: - Actions

extension AudioPlayerProgressView {

    @objc private func handleSliderValueChanged(_ slider: AudioPlayerSlider, event: UIEvent) {
        isDraggingSlider = true
        minTimeLabel.text = minuteAndSecondStr(second: Float64(slider.value))
    }

    @objc private func handleSliderTouchUp(_ slider: AudioPlayerSlider) {
        delegate?.progressView(self, didChanged: Float64(slider.value))
        isDraggingSlider = false
    }

}

// MARK: - Utils

extension AudioPlayerProgressView {

    /// 02:30
    func minuteAndSecondStr(second: Float64) -> String {
        let str = String(format: "%02ld:%02ld", Int64(second / 60), Int64(second.truncatingRemainder(dividingBy: 60)))

        return str
    }

}

// MARK: - Getter

extension AudioPlayerProgressView {

    private func createProgressSlider() -> AudioPlayerSlider {
        let slider = AudioPlayerSlider()
        slider.addTarget(self, action: #selector(handleSliderValueChanged(_:event:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(handleSliderTouchUp(_:)), for: .touchUpInside)
        slider.addTarget(self, action: #selector(handleSliderTouchUp(_:)), for: .touchUpOutside)

        return slider
    }

    private func createTimeLabel() -> UILabel {
        let label = UILabel()
        label.backgroundColor = .clear
        label.font = .systemFont(ofSize: 12)
        label.textColor = .black
        label.text = "--:--"

        return label
    }

}
