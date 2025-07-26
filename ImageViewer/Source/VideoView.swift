//
//  VideoView.swift
//  ImageViewer
//
//  Created by Kristian Angyal on 25/07/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//
import AVFoundation
import UIKit

class VideoView: UIView {
    let previewImageView = UIImageView()
    var image: UIImage? { didSet { previewImageView.image = image } }
    var player: AVPlayer? {
        willSet {
            if newValue == nil {
                player?.removeObserver(self, forKeyPath: "status")
                player?.removeObserver(self, forKeyPath: "rate")
            }
        }
        didSet {
            if let player = player, let videoLayer = layer as? AVPlayerLayer {
                videoLayer.player = player
                videoLayer.videoGravity = AVLayerVideoGravity.resizeAspect
                player.addObserver(
                    self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil
                )
                player.addObserver(
                    self, forKeyPath: "rate", options: NSKeyValueObservingOptions.new, context: nil
                )
            }
        }
    }

    override class var layerClass: AnyClass { return AVPlayerLayer.self }
    convenience init() { self.init(frame: CGRect.zero) }
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(previewImageView)
        previewImageView.contentMode = .scaleAspectFill
        previewImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        previewImageView.clipsToBounds = true
    }

    required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    deinit {
        player?.removeObserver(self, forKeyPath: "status")
        player?.removeObserver(self, forKeyPath: "rate")
    }

    override func observeValue(
        forKeyPath _: String?, of _: Any?, change _: [NSKeyValueChangeKey: Any]?,
        context _: UnsafeMutableRawPointer?
    ) {
        if let status = player?.status, let rate = player?.rate {
            if status == .readyToPlay && rate != 0 {
                UIView.animate(
                    withDuration: 0.3,
                    animations: { [weak self] in
                        if let strongSelf = self { strongSelf.previewImageView.alpha = 0 }
                    }
                )
            }
        }
    }
}
