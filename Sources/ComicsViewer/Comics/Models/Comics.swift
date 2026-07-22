//
//  Comics.swift
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

public class Comics: Codable {
	//NOTE: do not set default values to make Codable decode properly
	public let width: Int
	public let height: Int
	public let layers: [Layer]
	public let sounds: [Sound]

	public func prepare() {
		for layer in self.layers {
			layer.prepare()
		}
	}

	public func process(scrollOffset: Int) {
		for layer in self.layers {
			layer.buildMatrixAndAlpha(scrollOffset: scrollOffset)
		}
	}

	public func hasPreview() -> Bool {
		for layer in self.layers {
			if layer.isPreview {
				return true
			}
		}

		return false
	}
}
