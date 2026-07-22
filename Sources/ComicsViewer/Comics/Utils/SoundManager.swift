//
//  SoundManager.swift
//  ComicsViewer
//
//  Migrated from Mahabharata
//  Copyright © 2017 Iron Water Studio. All rights reserved.
//

import AVFoundation

public final class SoundManager {

	#if os(iOS) || os(tvOS) || os(watchOS)
	public static let shared = SoundManager(audioSessionCategory: AVAudioSession.Category.playback.rawValue)
	#else
	public static let shared = SoundManager(audioSessionCategory: nil)
	#endif

	private var player: AVPlayer?
	public var isLoop: Bool = false

	public var currentTime: Double {
		let currentTime = player?.currentTime() ?? CMTime()
		return CMTimeGetSeconds(currentTime)
	}

	public var isReadyToPlay: Bool {
		if let player = player, let currentItem = player.currentItem {
			return currentItem.status == .readyToPlay
		}
		return false
	}

	public var isMuted: Bool {
		set {
			player?.isMuted = newValue
		}
		get {
			return player?.isMuted ?? false
		}
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}

	private init() {
		player = AVPlayer()
	}

	public convenience init(audioSessionCategory: String?) {
		self.init()
		#if os(iOS) || os(tvOS) || os(watchOS)
		if let category = audioSessionCategory {
			do {
				try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category(rawValue: category), mode: .default, options: [])
				try AVAudioSession.sharedInstance().setActive(true)
			} catch {
				print("Error during setting category: \(category)")
			}
		}
		#endif
	}

	public func setupSharedAudioSession(audioSessionCategory: String?) {
		#if os(iOS) || os(tvOS) || os(watchOS)
		if let category = audioSessionCategory {
			do {
				try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category(rawValue: category), mode: .default, options: [])
				try AVAudioSession.sharedInstance().setActive(true)
			} catch {
				print("Error during setting category: \(category)")
			}
		}
		#endif
	}

	public func play(url: URL, loop: Bool = false) {

		self.isLoop = loop

		if currentTime.isNaN {
			//Clear resources
			stop()

			//Play source
			player = AVPlayer(url: url)
			player?.volume = 1.0
		}

		if self.isLoop {
			NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
		}
		player?.play()
	}

	public func pause() {
		player?.pause()
		NotificationCenter.default.removeObserver(self)
	}

	public func resume() {

		if self.isLoop {
			NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
		}
		player?.play()
	}

	public func stop() {
		player?.pause()
		NotificationCenter.default.removeObserver(self)
		player = nil
	}

	public func seek(time: TimeInterval) {
		//Fix for seek in stream
		var currentAssetTimeScale: CMTimeScale = 1
		if let player = self.player, let currentItem = player.currentItem {
			currentAssetTimeScale = currentItem.asset.duration.timescale
		}

		let seekTime = CMTime(seconds: time, preferredTimescale: currentAssetTimeScale)
		player?.seek(to: seekTime)
	}

	public func fadeOut(to volume: Float = 0, duration: TimeInterval, delay: Double = 0.1, completion: (() -> ())? = nil) {
		self.player?.fadeOut(to: volume, duration: duration, delay: delay, completion: {
			self.stop()
			completion?()
		})
	}

	//MARK: - Notification

	//Is called only for loop player
	@objc func playerDidFinishPlaying(notification: NSNotification) {
		if let player = self.player {
			//Go to start
			player.seek(to: CMTime.zero)
			//And play again
			player.play()
		}
	}

	/// Duration in seconds
	public static func duration(url: URL) -> Double {
		let audioAsset = AVURLAsset(url: url)
		let audioDuration: CMTime = audioAsset.duration
		return CMTimeGetSeconds(audioDuration)
	}

	public static func playSystemSound(systemSoundID: SystemSoundID) {
		AudioServicesPlaySystemSoundWithCompletion(systemSoundID, nil)
	}
}
