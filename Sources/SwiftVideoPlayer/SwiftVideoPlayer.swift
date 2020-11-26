//
//  GPVideoPlayer.swift
//  GPVideoPlayer
//
//  Created by Payal Gupta on 16/02/19.
//  Copyright © 2019 Payal Gupta. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit

@available(iOS 10.0, *)
public class GPVideoPlayer: UIView {
    //MARK: Outlets
    @IBOutlet public weak var progressBar: UIProgressView!
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet public weak var volumeButton: UIButton!
    @IBOutlet weak var playbackControlsViewHeightContraint: NSLayoutConstraint!
    @IBOutlet weak var loaderView: LoaderView!
    @IBOutlet public weak var backwardButton: UIButton?
    @IBOutlet public weak var forwardButton: UIButton?
    @IBOutlet public weak var expandButton: UIButton?
    
    //MARK: Internal Properties
    public var isMuted = true {
        didSet {
            self.player?.isMuted = self.isMuted
            self.volumeButton.isSelected = self.isMuted
        }
    }
    public var isToShowPlaybackControls = true {
        didSet {
            if !isToShowPlaybackControls {
                self.playbackControlsViewHeightContraint.constant = 0.0
                self.layoutIfNeeded()
            }
        }
    }
    
    //MARK: Private Properties
    private var playerLayer: AVPlayerLayer?
    private var player: AVQueuePlayer?
    private var playerItems: [AVPlayerItem]?
    private enum Constants {
        static let nibName = "GPVideoPlayer"
        static let rewindForwardDuration: Float64 = 10 //in seconds
    }
    
    //MARK: Lifecycle Methods
    override public func layoutSubviews() {
        super.layoutSubviews()
        self.playerLayer?.frame = self.videoView.bounds
    }
    
    deinit {
        player?.removeObserver(self, forKeyPath: "timeControlStatus")
        NotificationCenter.default.removeObserver(self)
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "timeControlStatus", let change = change, let newValue = change[NSKeyValueChangeKey.newKey] as? Int, let oldValue = change[NSKeyValueChangeKey.oldKey] as? Int {
            let oldStatus = AVPlayer.TimeControlStatus(rawValue: oldValue)
            let newStatus = AVPlayer.TimeControlStatus(rawValue: newValue)
            if newStatus != oldStatus {
                DispatchQueue.main.async {[weak self] in
                    if newStatus == .playing || newStatus == .paused {
                        self?.loaderView.isHidden = true
                    } else {
                        self?.loaderView.isHidden = false
                    }
                }
            }
        }
    }
    
    //MARK: Public Methods
    public class func initialize(with frame: CGRect) -> GPVideoPlayer? {
        let bundle = Bundle(for: GPVideoPlayer.self)
        return self.initialize(with: bundle, frame: frame)
    }
    
    public class func initialize(with bundle: Bundle, frame: CGRect) -> GPVideoPlayer? {
        let view = bundle.loadNibNamed(Constants.nibName, owner: self, options: nil)?.first as? GPVideoPlayer
        view?.frame = frame
        return view
    }
    
    public func loadVideo(with url: URL) {
        self.loadVideos(with: [url])
    }
    
    public func loadVideos(with urls: [URL]) {
        guard !urls.isEmpty else {
            print("🚫 URLs not available.")
            return
        }
        
        guard let player = self.player(with: urls) else {
            print("🚫 AVPlayer not created.")
            return
        }
        
        self.player = player
        let playerLayer = self.playerLayer(with: player)
        self.videoView.layer.insertSublayer(playerLayer, at: 0)
    }
    
    public func playVideo() {
        self.player?.play()
        self.playPauseButton.isSelected = true
    }
    
    public func pauseVideo() {
        self.player?.pause()
        self.playPauseButton.isSelected = false
    }
    
    public func seek(progress: Float) {
        guard let duration = self.player?.currentItem?.asset.duration else { return }
        let durationSeconds = CMTimeGetSeconds(duration)
        let sc = Float64(progress) * durationSeconds
        let ct = CMTimeMakeWithSeconds(sc, preferredTimescale: 600)
        self.player?.seek(to: ct)
    }
    
    public func seekPlay(progress: Float) {
        self.seek(progress: progress)
        self.playVideo()
    }
    
    //MARK: Button Action Methods
    @IBAction private func onTapPlayPauseVideoButton(_ sender: UIButton) {
        if sender.isSelected {
            self.pauseVideo()
        } else {
            self.playVideo()
        }
    }
    
    @IBAction private func onTapExpandVideoButton(_ sender: UIButton) {
        self.pauseVideo()
        let controller = AVPlayerViewController()
        controller.player = player
        NotificationCenter.default.addObserver(self, selector: #selector(avPlayerDidDismiss), name: Notification.Name("avPlayerDidDismiss"), object: nil)
        self.parentViewController()?.present(controller, animated: true) {[weak self] in
            DispatchQueue.main.async {
                self?.isMuted = false
                self?.playVideo()
            }
        }
    }
    
    @IBAction private func onTapVolumeButton(_ sender: UIButton) {
        self.isMuted = !sender.isSelected
    }
    
    @IBAction private func onTapRewindButton(_ sender: UIButton) {
        if let currentTime = self.player?.currentTime() {
            var newTime = CMTimeGetSeconds(currentTime) - Constants.rewindForwardDuration
            if newTime <= 0 {
                newTime = 0
            }
            self.player?.seek(to: CMTime(value: CMTimeValue(newTime * 1000), timescale: 1000))
        }
    }
    
    @IBAction private func onTapForwardButton(_ sender: UIButton) {
        if let currentTime = self.player?.currentTime(), let duration = self.player?.currentItem?.duration {
            var newTime = CMTimeGetSeconds(currentTime) + Constants.rewindForwardDuration
            if newTime >= CMTimeGetSeconds(duration) {
                newTime = CMTimeGetSeconds(duration)
            }
            self.player?.seek(to: CMTime(value: CMTimeValue(newTime * 1000), timescale: 1000))
        }
    }
}

// MARK: - Private Methods
@available(iOS 10.0, *)
private extension GPVideoPlayer {
    func player(with urls: [URL]) -> AVQueuePlayer? {
        var playerItems = [AVPlayerItem]()
        
        urls.forEach { (url) in
            let asset = AVAsset(url: url)
            let playerItem = AVPlayerItem(asset: asset)
            playerItems.append(playerItem)
        }
        
        guard !playerItems.isEmpty else {
            return nil
        }
        
        let player = AVQueuePlayer(items: playerItems)
        self.playerItems = playerItems
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 2), queue: DispatchQueue.main) {[weak self] (progressTime) in
            if let duration = player.currentItem?.duration {
                
                let durationSeconds = CMTimeGetSeconds(duration)
                let seconds = CMTimeGetSeconds(progressTime)
                let progress = Float(seconds/durationSeconds)

                DispatchQueue.main.async {
                    self?.progressBar.progress = progress
                    if progress >= 1.0 {
                        self?.progressBar.progress = 0.0
                    }
                }
            }
        }
        player.addObserver(self, forKeyPath: "timeControlStatus", options: [.old, .new], context: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playerEndedPlaying), name: Notification.Name("AVPlayerItemDidPlayToEndTimeNotification"), object: nil)
        
        return player
    }
    
    func playerLayer(with player: AVQueuePlayer) -> AVPlayerLayer {
        self.layoutIfNeeded()
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = self.videoView.bounds
        playerLayer.videoGravity = .resizeAspect
        playerLayer.contentsGravity = .resizeAspect
        self.playerLayer = playerLayer
        return playerLayer
    }
    
    @objc func avPlayerDidDismiss(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {[weak self] in
            self?.isMuted = true
            self?.playVideo()
            NotificationCenter.default.removeObserver(self as Any, name: Notification.Name("avPlayerDidDismiss"), object: nil)
        }
    }
    
    @objc func playerEndedPlaying(_ notification: Notification) {
        DispatchQueue.main.async {[weak self] in
            if let playerItem = notification.object as? AVPlayerItem {
                var safeCheck = false
                self?.player?.items().forEach {
                    if $0 === playerItem {
                        safeCheck = true
                    }
                }
                
                guard safeCheck == true else { return }
                
                self?.player?.remove(playerItem)
                playerItem.seek(to: .zero, completionHandler: nil)
                self?.player?.insert(playerItem, after: nil)
                if playerItem == self?.playerItems?.last {
                    self?.pauseVideo()
                }
            }
        }
    }
}

extension AVPlayerViewController {
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.player?.pause()
        NotificationCenter.default.post(name: Notification.Name("avPlayerDidDismiss"), object: nil, userInfo: nil)
    }
}

