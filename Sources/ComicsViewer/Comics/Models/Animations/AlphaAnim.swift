//
//  AlphaAnim.swift
//  ComicsViewer
//
//  Migrated from Mahabharata
//  Copyright © 2017 Iron Water Studio. All rights reserved.
//

import Foundation

public class AlphaAnim: Anim {
	let alpha: Double

	private enum CodingKeys: String, CodingKey {
		case alpha
	}

	public required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.alpha = (try? container.decode(Double.self, forKey: .alpha)) ?? 0

		try super.init(from: decoder)
	}

	init(alpha: Double) {
		self.alpha = alpha

		super.init()
	}

	//MARK: - Overrides
	override func interpolate(endAnim: Anim, fraction: Double) -> Anim {
		let end = endAnim as! AlphaAnim
		return AlphaAnim(alpha: LinearInterpolation.evaluate(fraction: fraction, startValue: self.alpha, endValue: end.alpha))
	}

	override func apply(to data: Layer.ViewData, width: Int, height: Int) {
		data.alpha = self.alpha
	}
}
