//
//  AVPlayer+Fade.swift
//  ComicsViewer
//
//  Migrated from Mahabharata
//  Copyright © 2018 Iron Water Studio. All rights reserved.
//

import AVKit

extension AVPlayer {
	func fadeOut(to volume: Float, duration: TimeInterval, delay: Double = 0.1, completion: (() -> ())? = nil) {

		if volume >= self.volume {
			self.volume = volume
			return
		}

		let step: Float = (self.volume - volume) * (Float(delay / duration))

		self.fadeOut(to: volume, delay: delay, step: step, completion: completion)
	}

	private func fadeOut(to volume: Float, delay: Double, step: Float, completion: (() -> ())? = nil) {
		if self.volume - volume > step {
			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delay, execute: {
				[weak self] in
				guard let strongSelf = self else { return }
				strongSelf.volume -= step
				strongSelf.fadeOut(to: volume, delay: delay, step: step, completion: completion)
			})
		} else {
			self.volume = volume
			completion?()
		}
	}
}
