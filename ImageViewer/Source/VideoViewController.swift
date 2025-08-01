//
//  ImageViewController.swift
//  ImageViewer
//
//  Created by Kristian Angyal on 01/08/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//
import AVFoundation
import UIKit

extension VideoView: ItemView {}
class VideoViewController: ItemBaseController<VideoView> {
    fileprivate let swipeToDismissFadeOutAccelerationFactor: CGFloat = 6
    let videoURL: URL
    let player: AVPlayer
    unowned let scrubber: VideoScrubber
    let fullHDScreenSizeLandscape = CGSize(width: 1920, height: 1080)
    let fullHDScreenSizePortrait = CGSize(width: 1080, height: 1920)
    let embeddedPlayButton = UIButton.circlePlayButton(70)
    private var autoPlayStarted: Bool = false
    private var autoPlayEnabled: Bool = false
    init(
        index: Int, itemCount: Int, fetchImageBlock: @escaping FetchImageBlock, videoURL: URL,
        scrubber: VideoScrubber, configuration: GalleryConfiguration, isInitialController: Bool = false
    ) {
        self.videoURL = videoURL
        self.scrubber = scrubber
        player = AVPlayer(url: self.videoURL)
        /// Only those options relevant to the paging VideoViewController are explicitly handled here, the rest is handled by ItemViewControllers
        for item in configuration {
            switch item {
            case let .videoAutoPlay(enabled): autoPlayEnabled = enabled
            default: break
            }
        }
        super.init(
            index: index, itemCount: itemCount, fetchImageBlock: fetchImageBlock,
            configuration: configuration, isInitialController: isInitialController
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if isInitialController == true { embeddedPlayButton.alpha = 0 }
        embeddedPlayButton.autoresizingMask = [
            .flexibleTopMargin, .flexibleLeftMargin, .flexibleBottomMargin, .flexibleRightMargin,
        ]
        view.addSubview(embeddedPlayButton)
        embeddedPlayButton.center = view.boundsCenter
        embeddedPlayButton.addTarget(
            self, action: #selector(playVideoInitially), for: UIControl.Event.touchUpInside
        )
        itemView.player = player
        itemView.contentMode = .scaleAspectFill
    }

    override func viewWillAppear(_ animated: Bool) {
        player.addObserver(
            self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil
        )
        player.addObserver(
            self, forKeyPath: "rate", options: NSKeyValueObservingOptions.new, context: nil
        )
        UIApplication.shared.beginReceivingRemoteControlEvents()
        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        player.removeObserver(self, forKeyPath: "status")
        player.removeObserver(self, forKeyPath: "rate")
        UIApplication.shared.endReceivingRemoteControlEvents()
        super.viewWillDisappear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        performAutoPlay()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        player.pause()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let isLandscape = itemView.bounds.width >= itemView.bounds.height
        itemView.bounds.size = aspectFitSize(
            forContentOfSize: isLandscape ? fullHDScreenSizeLandscape : fullHDScreenSizePortrait,
            inBounds: scrollView.bounds.size
        )
        itemView.center = scrollView.boundsCenter
    }

    @objc func playVideoInitially() {
        player.play()
        UIView.animate(
            withDuration: 0.25, animations: { [weak self] in self?.embeddedPlayButton.alpha = 0 },
            completion: { [weak self] _ in self?.embeddedPlayButton.isHidden = true }
        )
    }

    override func closeDecorationViews(_ duration: TimeInterval) {
        UIView.animate(
            withDuration: duration, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut],
            animations: { [weak self] in
                self?.embeddedPlayButton.alpha = 0
                self?.itemView.previewImageView.alpha = 1
            }
        )
    }

    override func presentItem(
        alongsideAnimation: @escaping () -> Void, completion: @escaping () -> Void
    ) {
        let circleButtonAnimation = {
            UIView.animate(
                withDuration: 0.15, animations: { [weak self] in self?.embeddedPlayButton.alpha = 1 }
            )
        }
        super.presentItem(alongsideAnimation: alongsideAnimation) {
            circleButtonAnimation()
            completion()
        }
    }

    override func displacementTargetSize(forSize _: CGSize) -> CGSize {
        let isLandscape = itemView.bounds.width >= itemView.bounds.height
        return aspectFitSize(
            forContentOfSize: isLandscape ? fullHDScreenSizeLandscape : fullHDScreenSizePortrait,
            inBounds: rotationAdjustedBounds().size
        )
    }

    override func observeValue(
        forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "rate" || keyPath == "status" {
            fadeOutEmbeddedPlayButton()
        } else if keyPath == "contentOffset" {
            handleSwipeToDismissTransition()
        }
        super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }

    func handleSwipeToDismissTransition() {
        guard swipingToDismiss != nil else { return }
        embeddedPlayButton.center.y = view.center.y - scrollView.contentOffset.y
    }

    func fadeOutEmbeddedPlayButton() {
        if player.isPlaying() && embeddedPlayButton.alpha != 0 {
            UIView.animate(
                withDuration: 0.3, animations: { [weak self] in self?.embeddedPlayButton.alpha = 0 }
            )
        }
    }

    override func remoteControlReceived(with event: UIEvent?) {
        if let event = event {
            if event.type == UIEvent.EventType.remoteControl {
                switch event.subtype {
                case .remoteControlTogglePlayPause:
                    if player.isPlaying() { player.pause() } else { player.play() }
                case .remoteControlPause: player.pause()
                case .remoteControlPlay: player.play()
                case .remoteControlPreviousTrack:
                    player.pause()
                    player.seek(to: CMTime(value: 0, timescale: 1))
                    player.play()
                default: break
                }
            }
        }
    }

    private func performAutoPlay() {
        guard autoPlayEnabled else { return }
        guard autoPlayStarted == false else { return }
        autoPlayStarted = true
        embeddedPlayButton.isHidden = true
        scrubber.play()
    }
}
