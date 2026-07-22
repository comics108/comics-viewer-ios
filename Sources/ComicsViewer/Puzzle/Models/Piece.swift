//
//  Piece.swift
//  ComicsViewer
//
//  Migrated from Mahabharata
//  Copyright (c) 2019 Iron Water Studio. All rights reserved.
//

import Foundation

public struct Piece: Codable {

	public var id: Int
	public var x: Int
	public var y: Int
	public var width: Int
	public var height: Int
	public var file: String
	public var version: Int
	public var date: Date
	public var order: Int

	public init(id: Int, x: Int, y: Int, width: Int, height: Int, file: String, version: Int, date: Date, order: Int) {
		self.id = id
		self.x = x
		self.y = y
		self.width = width
		self.height = height
		self.file = file
		self.version = version
		self.date = date
		self.order = order
	}

	public init() {
		self.init(id: 0, x: 0, y: 0, width: 0, height: 0, file: "", version: 0, date: Date(), order: 0)
	}
}
