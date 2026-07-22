//
//  Layer.swift
//  ComicsViewer
//
//  Migrated from Mahabharata
//  Copyright © 2017 Iron Water Studio. All rights reserved.
//

import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public class Layer: Codable {
	private static let kDefaultTranslate: TranslateAnim = TranslateAnim(x: 0, y: 0)
	private static let kDefaultRotate: RotateAnim = RotateAnim(angle: 0, pivotX: 0.5, pivotY: 0.5)
	private static let kDefaultScale: ScaleAnim = ScaleAnim(scaleX: 1, scaleY: 1, pivotX: 0.5, pivotY: 0.5)
	private static let kDefaultAlpha: AlphaAnim = AlphaAnim(alpha: 1)

	public let preview: Bool?
	public let images: [Image]
	public var animations: [Anim]	//Only of LayerAnim protocol

	private var translates = [TranslateAnim]()
	private var rotates = [RotateAnim]()
	private var scales = [ScaleAnim]()
	private var alphas = [AlphaAnim]()
	private var viewData = ViewData()

	#if canImport(UIKit)
	public var inverse = CATransform3DIdentity
	#elseif canImport(AppKit)
	public var inverse = CATransform3DIdentity
	#endif

	public var isPreview: Bool {
		return self.preview ?? false
	}

	#if canImport(UIKit)
	public var matrix: CATransform3D {
		return self.viewData.matrix
	}
	#elseif canImport(AppKit)
	public var matrix: CATransform3D {
		return self.viewData.matrix
	}
	#endif

	public var alpha: Double {
		return self.viewData.alpha
	}

	/// Get the image for a specific language index
	/// - Parameter languageIndex: The index of the language (default: 0)
	/// - Returns: The image for the specified language, or the first non-empty image if not found
	public func image(languageIndex: Int = 0) -> Image? {
		if self.images.isEmpty { return nil }

		let safeIndex = min(languageIndex, self.images.count - 1)
		let image = self.images[safeIndex]

		if !image.isEmpty {
			return image
		}

		for item in self.images {
			if !item.isEmpty {
				return item
			}
		}

		return nil
	}

	/// Get the popup text for a specific language index
	/// - Parameter languageIndex: The index of the language (default: 0)
	/// - Returns: The popup text for the specified language, or the first non-empty popup if not found
	public func popup(languageIndex: Int = 0) -> String? {
		if self.images.isEmpty { return nil }

		let safeIndex = min(languageIndex, self.images.count - 1)
		let image = self.images[safeIndex]
		if image.hasPopup {
			return image.popup!
		}

		for item in self.images {
			if item.hasPopup {
				return item.popup!
			}
		}

		return nil
	}

	private enum CodingKeys: String, CodingKey {
		case preview
		case images
		case animations
	}

	public required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.preview = try? container.decode(Bool.self, forKey: .preview)
		self.images = try container.decode([Image].self, forKey: .images)

		var animations: [Anim] = []
		var animationsContainer = try container.nestedUnkeyedContainer(forKey: .animations)
		while !animationsContainer.isAtEnd {
			let wrapper = try animationsContainer.decode(AnimWrapper.self)
			animations.append(wrapper.animation)
		}
		self.animations = animations
	}

	//MARK: - Functionality
	public func prepare() {
		for anim in self.animations {
			switch anim.type {
			case .translate:
				Layer.sortedAdd(animations: &self.translates, anim: anim as! TranslateAnim)
			case .rotate:
				Layer.sortedAdd(animations: &self.rotates, anim: anim as! RotateAnim)
			case .scale:
				Layer.sortedAdd(animations: &self.scales, anim: anim as! ScaleAnim)
			case .alpha:
				Layer.sortedAdd(animations: &self.alphas, anim: anim as! AlphaAnim)
			default:
				fatalError("Not implemented for animation type: \(anim.type)")
			}
		}

		self.animations.removeAll()
	}

	#if canImport(UIKit) || canImport(AppKit)
	public func buildInverse() {
		self.inverse = CATransform3DInvert(self.matrix)
	}
	#endif

	public func buildMatrixAndAlpha(scrollOffset: Int, languageIndex: Int = 0) {
		let img = self.image(languageIndex: languageIndex)
		if img == nil { return }

		#if canImport(UIKit) || canImport(AppKit)
		self.viewData.matrix = CATransform3DIdentity
		#endif
		self.applyAnimations(animations: self.translates, defaultValue: Layer.kDefaultTranslate, scrollOffset: scrollOffset, image: img!)
		self.applyAnimations(animations: self.rotates, defaultValue: Layer.kDefaultRotate, scrollOffset: scrollOffset, image: img!)
		self.applyAnimations(animations: self.scales, defaultValue: Layer.kDefaultScale, scrollOffset: scrollOffset, image: img!)
		self.applyAnimations(animations: self.alphas, defaultValue: Layer.kDefaultAlpha, scrollOffset: scrollOffset, image: img!)
	}

	private func applyAnimations<T: Anim>(animations: [T], defaultValue: T, scrollOffset: Int, image: Image) {
		var previousAnim = defaultValue
		var currentAnim: T? = nil

		for anim in animations {
			if currentAnim != nil {
				previousAnim = currentAnim!
			}
			currentAnim = anim
			if scrollOffset < anim.end {
				break
			}
		}

		if currentAnim == nil {
			currentAnim = defaultValue
		}

		previousAnim.interpolate(endAnim: currentAnim!, scrollOffset: scrollOffset).apply(to: self.viewData, width: image.width, height: image.height)
	}

	private static func sortedAdd<T: Anim>(animations: inout [T], anim: T) {
		if animations.isEmpty {
			animations.append(anim)
			return
		}

        var index = 0
		for item in animations {
			if anim.start >= item.end {
				index += 1
			}
			else {
				break
			}
		}
        animations.insert(anim, at: index)
	}

	//MARK: - ViewData
	class ViewData {
		#if canImport(UIKit) || canImport(AppKit)
		var matrix: CATransform3D = CATransform3DIdentity
		#endif
		var alpha: Double = 1

		init() {}

		#if canImport(UIKit) || canImport(AppKit)
		init(matrix: CATransform3D, alpha: Double) {
			self.matrix = matrix
			self.alpha = alpha
		}
		#endif
	}
}
