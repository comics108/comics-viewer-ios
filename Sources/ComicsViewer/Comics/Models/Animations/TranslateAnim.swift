//
//  TranslateAnim.swift
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

public class TranslateAnim: Anim {
	let x: Int
	let y: Int

	private enum CodingKeys: String, CodingKey {
		case x
		case y
	}

	public required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.x = (try? container.decode(Int.self, forKey: .x)) ?? 0
		self.y = (try? container.decode(Int.self, forKey: .y)) ?? 0

		try super.init(from: decoder)
	}

	init(x: Int, y: Int) {
		self.x = x
		self.y = y

		super.init()
	}

	//MARK: - Overrides
	override func interpolate(endAnim: Anim, fraction: Double) -> Anim {
		let end = endAnim as! TranslateAnim
		return TranslateAnim(x: LinearInterpolation.evaluate(fraction: fraction, startValue: self.x, endValue: end.x),
		                     y: LinearInterpolation.evaluate(fraction: fraction, startValue: self.y, endValue: end.y))
	}

	#if canImport(UIKit) || canImport(AppKit)
	override func apply(to data: Layer.ViewData, width: Int, height: Int) {
		data.matrix = CATransform3DTranslate(data.matrix, CGFloat(self.x), CGFloat(self.y), 0)
	}
	#endif
}
