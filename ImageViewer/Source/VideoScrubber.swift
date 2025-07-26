//
//  VideoScrubber.swift
//  ImageViewer
//
//  Created by Kristian Angyal on 08/08/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//
import AVFoundation
import UIKit

open class VideoScrubber: UIControl {
    let playButton = UIButton.playButton(width: 50, height: 40)
    let pauseButton = UIButton.pauseButton(width: 50, height: 40)
    let replayButton = UIButton.replayButton(width: 50, height: 40)
    let scrubber = Slider.createSlider(320, height: 20, pointerDiameter: 10, barHeight: 2)
    let timeLabel = UILabel(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 50, height: 20)))
    var duration: TimeInterval?
    fileprivate var periodicObserver: AnyObject?
    fileprivate var stoppedSlidingTimeStamp = Date()
    /// The attributes dictionary used for the timeLabel
    fileprivate var timeLabelAttributes: [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12),
        ]
        if let tintColor = tintColor { attributes[NSAttributedString.Key.foregroundColor] = tintColor }
        return attributes
    }

    weak var player: AVPlayer? {
        willSet {
            if let player = player {
                /// KVO
                player.removeObserver(self, forKeyPath: "status")
                player.removeObserver(self, forKeyPath: "rate")
                /// NC
                NotificationCenter.default.removeObserver(self)
                /// TIMER
                if let periodicObserver = periodicObserver {
                    player.removeTimeObserver(periodicObserver)
                    self.periodicObserver = nil
                }
            }
        }
        didSet {
            if let player = player {
                /// KVO
                player.addObserver(
                    self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil
                )
                player.addObserver(
                    self, forKeyPath: "rate", options: NSKeyValueObservingOptions.new, context: nil
                )
                /// NC
                NotificationCenter.default.addObserver(
                    self, selector: #selector(didEndPlaying),
                    name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil
                )
                /// TIMER
                periodicObserver =
                    player.addPeriodicTimeObserver(
                        forInterval: CMTime(value: 1, timescale: 1), queue: nil,
                        using: { [weak self] _ in self?.update() }
                    ) as AnyObject?
                update()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    deinit {
        player?.removeObserver(self, forKeyPath: "status")
        player?.removeObserver(self, forKeyPath: "rate")
        scrubber.removeObserver(self, forKeyPath: "isSliding")
        if let periodicObserver = self.periodicObserver {
            player?.removeTimeObserver(periodicObserver)
            self.periodicObserver = nil
        }
    }

    @objc func didEndPlaying() {
        playButton.isHidden = true
        pauseButton.isHidden = true
        replayButton.isHidden = false
    }

    func setup() {
        tintColor = .white
        clipsToBounds = true
        pauseButton.isHidden = true
        replayButton.isHidden = true
        scrubber.minimumValue = 0
        scrubber.maximumValue = 1000
        scrubber.value = 0
        timeLabel.attributedText = NSAttributedString(string: "--:--", attributes: timeLabelAttributes)
        timeLabel.textAlignment = .center
        playButton.addTarget(self, action: #selector(play), for: UIControl.Event.touchUpInside)
        pauseButton.addTarget(self, action: #selector(pause), for: UIControl.Event.touchUpInside)
        replayButton.addTarget(self, action: #selector(replay), for: UIControl.Event.touchUpInside)
        scrubber.addTarget(
            self, action: #selector(updateCurrentTime), for: UIControl.Event.valueChanged
        )
        scrubber.addTarget(
            self, action: #selector(seekToTime),
            for: [UIControl.Event.touchUpInside, UIControl.Event.touchUpOutside]
        )
        addSubviews(playButton, pauseButton, replayButton, scrubber, timeLabel)
        scrubber.addObserver(
            self, forKeyPath: "isSliding", options: NSKeyValueObservingOptions.new, context: nil
        )
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
        playButton.center = boundsCenter
        playButton.frame.origin.x = 0
        pauseButton.frame = playButton.frame
        replayButton.frame = playButton.frame
        timeLabel.center = boundsCenter
        timeLabel.frame.origin.x = bounds.maxX - timeLabel.bounds.width
        scrubber.bounds.size.width =
            bounds.width - playButton.bounds.width - timeLabel.bounds.width
        scrubber.bounds.size.height = 20
        scrubber.center = boundsCenter
        scrubber.frame.origin.x = playButton.frame.maxX
    }

    override open func observeValue(
        forKeyPath keyPath: String?, of _: Any?, change _: [NSKeyValueChangeKey: Any]?,
        context _: UnsafeMutableRawPointer?
    ) {
        if keyPath == "isSliding" {
            if scrubber.isSliding == false { stoppedSlidingTimeStamp = Date() }
        } else if keyPath == "rate" || keyPath == "status" {
            update()
        }
    }

    @objc func play() { player?.play() }
    @objc func replay() {
        player?.seek(to: CMTime(value: 0, timescale: 1))
        player?.play()
    }

    @objc func pause() { player?.pause() }
    @objc func seekToTime() {
        let progress = scrubber.value / scrubber.maximumValue // naturally will be between 0 to 1
        if let player = player, let currentItem = player.currentItem {
            let time = currentItem.duration.seconds * Double(progress)
            player.seek(to: CMTime(seconds: time, preferredTimescale: 1))
        }
    }

    func update() {
        updateButtons()
        updateDuration()
        updateScrubber()
        updateCurrentTime()
    }

    func updateButtons() {
        if let player = player {
            playButton.isHidden = player.isPlaying()
            pauseButton.isHidden = !playButton.isHidden
            replayButton.isHidden = true
        }
    }

    func updateDuration() {
        if let duration = player?.currentItem?.duration {
            self.duration = (duration.isNumeric) ? duration.seconds : nil
        }
    }

    func updateScrubber() {
        guard scrubber.isSliding == false else { return }
        let timeElapsed = Date().timeIntervalSince(stoppedSlidingTimeStamp)
        guard timeElapsed > 1 else { return }
        if let player = player, let duration = duration {
            let progress = player.currentTime().seconds / duration
            UIView.animate(
                withDuration: 0.9,
                animations: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.scrubber.value = Float(progress) * strongSelf.scrubber.maximumValue
                    }
                }
            )
        }
    }

    @objc func updateCurrentTime() {
        if let duration = duration, self.duration != nil {
            let sliderProgress = scrubber.value / scrubber.maximumValue
            let currentTime = Double(sliderProgress) * duration
            let timeString = stringFromTimeInterval(currentTime as TimeInterval)
            timeLabel.attributedText = NSAttributedString(
                string: timeString, attributes: timeLabelAttributes
            )
        } else {
            timeLabel.attributedText = NSAttributedString(
                string: "--:--", attributes: timeLabelAttributes
            )
        }
    }

    func stringFromTimeInterval(_ interval: TimeInterval) -> String {
        let timeInterval = NSInteger(interval)
        let seconds = timeInterval % 60
        let minutes = (timeInterval / 60) % 60
        // let hours = (timeInterval / 3600)
        return NSString(format: "%0.2d:%0.2d", minutes, seconds) as String
        // return NSString(format: "%0.2d:%0.2d:%0.2d",hours,minutes,seconds) as String
    }

    override open func tintColorDidChange() {
        timeLabel.attributedText = NSAttributedString(string: "--:--", attributes: timeLabelAttributes)
        let playButtonImage = playButton.imageView?.image?.withRenderingMode(
            UIImage.RenderingMode.alwaysTemplate)
        playButton.imageView?.tintColor = tintColor
        playButton.setImage(playButtonImage, for: .normal)
        if let playButtonImage = playButtonImage,
           let highlightImage = image(playButtonImage, with: tintColor.shadeDarker())
           as UIImage?
        {
            playButton.setImage(highlightImage, for: .highlighted)
        }
        let pauseButtonImage = pauseButton.imageView?.image?.withRenderingMode(
            UIImage.RenderingMode.alwaysTemplate)
        pauseButton.imageView?.tintColor = tintColor
        pauseButton.setImage(pauseButtonImage, for: .normal)
        if let pauseButtonImage = pauseButtonImage,
           let highlightImage = image(pauseButtonImage, with: tintColor.shadeDarker())
           as UIImage?
        {
            pauseButton.setImage(highlightImage, for: .highlighted)
        }
        let replayButtonImage = replayButton.imageView?.image?.withRenderingMode(
            UIImage.RenderingMode.alwaysTemplate)
        replayButton.imageView?.tintColor = tintColor
        replayButton.setImage(replayButtonImage, for: .normal)
        if let replayButtonImage = replayButtonImage,
           let highlightImage = image(replayButtonImage, with: tintColor.shadeDarker())
           as UIImage?
        {
            replayButton.setImage(highlightImage, for: .highlighted)
        }
    }

    func image(_ image: UIImage, with color: UIColor) -> UIImage? {
        UIGraphicsBeginImageContext(image.size)
        let rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(color.cgColor)
        context?.clip(to: rect, mask: image.cgImage!)
        context?.fill(CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        let fillImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return fillImage
    }
}
