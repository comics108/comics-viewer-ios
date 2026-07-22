//
//  Image.swift
//  ComicsViewer
//
//  Migrated from Mahabharata
//  Copyright © 2017 Iron Water Studio. All rights reserved.
//

import Foundation

public class Image: Codable {
	public let width: Int
	public let height: Int
	public let file: String?	//should get as /layers/file. File can be nil if image for localization is not set. In this case width and height will be 0
	public let popup: String?

	private enum CodingKeys: String, CodingKey {
		case width
		case height
		case file
		case popup
	}

	public required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.width = (try? container.decode(Int.self, forKey: .width)) ?? 0
		self.height = (try? container.decode(Int.self, forKey: .height)) ?? 0
		self.file = try? container.decode(String.self, forKey: .file)
		self.popup = try? container.decode(String.self, forKey: .popup)
	}

	public var isEmpty: Bool {
		return String.isNilOrWhiteSpace(self.file)
	}

	public var hasPopup: Bool {
		return !String.isNilOrWhiteSpace(self.popup)
	}
}
