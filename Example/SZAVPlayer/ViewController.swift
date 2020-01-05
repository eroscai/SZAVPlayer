//
//  ViewController.swift
//  SZAVPlayer
//
//  Created by eroscai on 11/27/2019.
//  Copyright (c) 2019 eroscai. All rights reserved.
//

import UIKit
import SnapKit
import SZAVPlayer

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        view.backgroundColor = .white

        let audioVCBtn = UIButton()
        audioVCBtn.backgroundColor = .black
        audioVCBtn.setTitle("Audio Example", for: .normal)
        audioVCBtn.setTitleColor(.white, for: .normal)
        audioVCBtn.addTarget(self, action: #selector(handleAudioVCBtnClick), for: .touchUpInside)
        view.addSubview(audioVCBtn)
        audioVCBtn.snp.makeConstraints { (make) in
            make.width.equalTo(200)
            make.height.equalTo(50)
            make.centerX.equalTo(view)
            make.centerY.equalTo(view).offset(-100)
        }

        let videoVCBtn = UIButton()
        videoVCBtn.backgroundColor = .black
        videoVCBtn.setTitle("Video Example", for: .normal)
        videoVCBtn.setTitleColor(.white, for: .normal)
        videoVCBtn.addTarget(self, action: #selector(handleVideoVCBtnClick), for: .touchUpInside)
        view.addSubview(videoVCBtn)
        videoVCBtn.snp.makeConstraints { (make) in
            make.width.equalTo(200)
            make.height.equalTo(50)
            make.centerX.equalTo(view)
            make.centerY.equalTo(view).offset(100)
        }

    }

    @objc func handleAudioVCBtnClick() {
        let vc = AudioViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc func handleVideoVCBtnClick() {
        let vc = VideoViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

}

