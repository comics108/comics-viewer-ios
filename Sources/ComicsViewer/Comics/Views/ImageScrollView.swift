//
//  ImageScrollView.swift
//  ComicsViewer
//
//  Migrated from Mahabharata
//  Copyright © 2017 Iron Water Studio. All rights reserved.
//

import Foundation

#if canImport(UIKit)
import UIKit
import AVFoundation

public protocol ImageScrollViewDelegate: AnyObject {
	func imageScrollViewDidScroll(_ view: ImageScrollView)
}

fileprivate extension SoundAnim {
	struct AssociatedKeys {
		static var playerKey: UInt8 = 0
		static var isPlayingKey: UInt8 = 0
	}

	var player: SoundManager? {
		get {
			guard let value = objc_getAssociatedObject(self, &AssociatedKeys.playerKey) as? SoundManager else {
				return nil
			}
			return value
		}

		set(newValue) {
			objc_setAssociatedObject(self, &AssociatedKeys.playerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
		}
	}

	var isPlaying: Bool {
		get {
			guard let value = objc_getAssociatedObject(self, &AssociatedKeys.isPlayingKey) as? Bool else {
				return false
			}
			return value
		}

		set(newValue) {
			objc_setAssociatedObject(self, &AssociatedKeys.isPlayingKey, newValue, .OBJC_ASSOCIATION_ASSIGN)
		}
	}
}

public class ImageScrollView: UIScrollView, UIScrollViewDelegate {

	public var comics: Comics? = nil {
		didSet {
			if let comics = comics {
				comics.prepare()
				self.displayTiles()
			} else {
				self.removeTiles()
			}
		}
	}

	public weak var scrollDelegate: ImageScrollViewDelegate?
	public var soundEnabled: Bool = true {
		didSet {
			guard oldValue != soundEnabled else { return }
			if soundEnabled {
				mute(false)
			} else {
				stopAllSounds()
			}
		}
	}
	private var storedLanguageIndex = 0
	public var languageIndex: Int {
		get { storedLanguageIndex }
		set {
			let normalized = max(0, newValue)
			guard normalized != storedLanguageIndex else { return }
			storedLanguageIndex = normalized
			reloadLanguage()
		}
	}
	public var showPreview = true {
		didSet {
			guard oldValue != showPreview, comics != nil else { return }
			displayTiles()
		}
	}
	private var resources: ArchiveManager?

	let tilesContainer = UIView()
	private var contentConstraints = [NSLayoutConstraint]()
	var layerTiles = [(layer: Layer, tile: TileImageView)]()
	var tilingViews: [TileImageView] { layerTiles.map(\.tile) }

	public var isComics = true

	//Initial value is less that any real value to play music if its start is 0
	private var previousContentOffset: CGFloat = -1.0

	public init() {
		super.init(frame: .zero)

		self.bouncesZoom = false
		self.bounces = false
		self.showsVerticalScrollIndicator = true
		self.showsHorizontalScrollIndicator = true
		self.delegate = self
		self.contentMode = .scaleToFill
		self.minimumZoomScale = 0
		self.maximumZoomScale = 10
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	//MARK: - Functionality
	public func install(comics: Comics, resources: ArchiveManager) {
		self.resources = resources
		self.comics = comics
	}

	public func dispose() {
		stopAllSounds()
		scrollDelegate = nil
		resources = nil
		comics = nil
		contentOffset = .zero
		previousContentOffset = -1
	}

	public func updateTiles() {
		displayTiles()
	}

	//MARK: - UIScrollViewDelegate
	public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return self.tilesContainer
	}

	//MARK: - Configure scrollView to display tiles
	func displayTiles() {
		guard let comics = self.comics, comics.width > 0 else { return }
		removeTiles()

		//For comics mode zoomScale is fixed
		if self.isComics {
			let realContentWidth = UIScreen.main.bounds.size.width
			let zoomScale = realContentWidth / CGFloat(comics.width)
			self.minimumZoomScale = zoomScale
			self.maximumZoomScale = zoomScale
			self.zoomScale = zoomScale
		}

		let scaledWidth = CGFloat(comics.width) * self.zoomScale
		let scaledHeight = CGFloat(comics.height) * self.zoomScale

		//Add container
		if self.tilesContainer.superview == nil {
			self.addSubview(self.tilesContainer)
			self.tilesContainer.translatesAutoresizingMaskIntoConstraints = false
		}
		NSLayoutConstraint.deactivate(contentConstraints)
		contentConstraints = [
			self.tilesContainer.topAnchor.constraint(equalTo: self.topAnchor),
			self.tilesContainer.leadingAnchor.constraint(equalTo: self.leadingAnchor),
			self.tilesContainer.trailingAnchor.constraint(equalTo: self.trailingAnchor),
			self.tilesContainer.bottomAnchor.constraint(equalTo: self.bottomAnchor),
			self.tilesContainer.widthAnchor.constraint(equalToConstant: CGFloat(comics.width)),
			self.tilesContainer.heightAnchor.constraint(equalToConstant: CGFloat(comics.height))
		]
		NSLayoutConstraint.activate(contentConstraints)

		self.contentSize = CGSize(width: scaledWidth, height: scaledHeight)
		self.tilesContainer.backgroundColor = .black

		//Add tiles
		let resources = resources ?? ArchiveManager.shared
		for layer in visibleLayers(in: comics) {
			if let image = layer.image(languageIndex: self.languageIndex) {
				let tile = TileImageView(image: image, resources: resources)

				self.layerTiles.append((layer, tile))
				self.tilesContainer.addSubview(tile)
			}
		}

		//Force to load first screen of comics
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
			guard let self, self.comics === comics else { return }
			self.loadComics(scrollView: self, sound: false)
		}
	}

	private func visibleLayers(in comics: Comics) -> [Layer] {
		comics.layers.filter { showPreview || !$0.isPreview }
	}

	private func removeTiles() {
		for binding in layerTiles {
			binding.tile.killTiles()
			binding.tile.removeFromSuperview()
		}
		layerTiles.removeAll()
	}

	private var isReloading = false

	/// Reload tiles after language change
	public func reloadLanguage() {
		guard comics != nil, !isReloading else { return }
		isReloading = true
		displayTiles()
		if zoomScale > 0 {
			loadComics(scrollView: self, sound: false)
		}
		isReloading = false
	}

	//MARK: - UIScrollViewDelegate
	public func scrollViewDidScroll(_ scrollView: UIScrollView) {
		guard let _ = self.comics else { return }

		self.scrollDelegate?.imageScrollViewDidScroll(self)

		loadComics(scrollView: self, sound: true)
	}

	func loadComics(scrollView: UIScrollView, sound: Bool) {
		guard let comics = self.comics, self.zoomScale > 0 else { return }

		if scrollView.contentOffset.y < 0.0 {
			previousContentOffset = scrollView.contentOffset.y
			return
		}

		comics.process(scrollOffset: Int(scrollView.contentOffset.y / self.zoomScale))

		//3x height
		let visibleRectHeight = scrollView.frame.size.height / self.zoomScale
		let visibleRectWidth = scrollView.frame.size.width / self.zoomScale
		let intersectRect = CGRect(x: -visibleRectWidth, y: scrollView.contentOffset.y / self.zoomScale - visibleRectHeight,
										width: visibleRectWidth * 3, height: visibleRectHeight * 3)

		for binding in layerTiles {
			let tile = binding.tile
			tile.transform = CATransform3DGetAffineTransform(binding.layer.matrix)
			tile.alpha = CGFloat(binding.layer.alpha)

			let intersects = tile.frame.intersects(intersectRect)
			if intersects {
				tile.prepareTiles()
			}
			else {
				//Remove info about images of tiles. Images will still be displayed
				//Do not remove from superview! It will result in black squares
				tile.killTiles()
			}
		}

		//Play comics sound when got content offset specified for sound
		if self.soundEnabled && sound {
			self.playSoundsByOffset()
		}

		previousContentOffset = scrollView.contentOffset.y
	}

	private func playSoundsByOffset() {
		guard let comics = self.comics else { return }

		for sound in comics.sounds {
			if let file = sound.file {
				for animation in sound.animations {

					let animationStart = CGFloat(animation.start) * self.zoomScale
					let animationEnd = CGFloat(animation.end) * self.zoomScale

					if animationStart == animationEnd {
						//NOTE: previous content offset is for single animations (because we do not track their end), and isPlaying is for range animations
						//Do not play single sound if scrolls top
						if previousContentOffset > contentOffset.y {
							break
						}

						if previousContentOffset < animationStart && contentOffset.y >= animationStart {
							self.playSound(animation: animation, file: file)
						}
					} else if animationStart < animationEnd {
						//Play background sound if scrolled to animation offset range
						//Do not play animation that is already playing
						if !animation.isPlaying &&
							contentOffset.y >= animationStart && contentOffset.y <= animationEnd {

							self.playSound(animation: animation, file: file)

						} else if animation.player != nil && animation.isPlaying &&
							(contentOffset.y < animationStart || contentOffset.y > animationEnd) {

							//Stop background sound if went out animation offset range
							self.stopSound(animation: animation)
						}
					}
				}
			}
		}
	}

	private func playSound(animation: SoundAnim, file: String) {
		guard let resourceContext = resources else { return }

		animation.isPlaying = true

		if let animationPlayer = animation.player, animationPlayer.isMuted  {
			animationPlayer.isMuted = false
		}
		else {
			#if os(iOS) || os(tvOS)
			if animation.player == nil {
				animation.player = SoundManager(audioSessionCategory: AVAudioSession.Category.ambient.rawValue)
			}
			else {
				animation.player?.seek(time: 0.0)
				SoundManager.shared.setupSharedAudioSession(audioSessionCategory: AVAudioSession.Category.ambient.rawValue)
			}
			#else
			if animation.player == nil {
				animation.player = SoundManager(audioSessionCategory: nil)
			}
			else {
				animation.player?.seek(time: 0.0)
			}
			#endif

			DispatchQueue.main.async { [weak self] in
				guard let self, self.resources === resourceContext else {
					animation.isPlaying = false
					return
				}
				resourceContext.sound(name: file, success: { (url) in
					if let url = url, let player = animation.player {
						//play sound from extracted data
						player.play(url: url, loop: animation.start != animation.end)
					}
					else {
						animation.isPlaying = false
					}
				})
			}
		}
	}

	private func stopSound(animation: SoundAnim) {
		animation.isPlaying = false
		animation.player?.fadeOut(to: 0, duration: 0.6)
	}

	private func toggleSounds(play: Bool) {
		guard let comics = self.comics else { return }

		for sound in comics.sounds {
			if sound.file != nil {
				for animation in sound.animations {
					if let animationPlayer = animation.player {

						animationPlayer.isMuted = false

						if play {
							animationPlayer.resume()
						}
						else {
							animationPlayer.pause()
						}
						animation.isPlaying = play
					}
				}
			}
		}
	}

	public func pauseSounds() {
		toggleSounds(play: false)
	}

	public func resumeSounds() {
		toggleSounds(play: true)
	}

	public func mute(_ muted: Bool) {
		guard let comics = self.comics else { return }

		for sound in comics.sounds {
			if sound.file != nil {
				for animation in sound.animations {
					if let animationPlayer = animation.player {

						animationPlayer.isMuted = muted
						animation.isPlaying = !muted
					}
				}
			}
		}
	}

	private func stopAllSounds() {
		guard let comics = self.comics else { return }
		for sound in comics.sounds {
			for animation in sound.animations {
				animation.player?.stop()
				animation.player = nil
				animation.isPlaying = false
			}
		}
	}
}
#endif
