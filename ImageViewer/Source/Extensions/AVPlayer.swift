//
//  AVPlayer.swift
//  ImageViewer
//
//  Created by Kristian Angyal on 02/08/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//
import AVFoundation

extension AVPlayer {
    func isPlaying() -> Bool { return rate != 0.0 && status == .readyToPlay }
}
