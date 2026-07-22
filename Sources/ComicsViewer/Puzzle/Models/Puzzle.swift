//
//  Puzzle.swift
//  ComicsViewer
//
//  Migrated from Mahabharata
//  Copyright (c) 2019 Iron Water Studio. All rights reserved.
//

import Foundation

public struct Puzzle: Codable {

	public var id: Int
	public var name: String
	public var width: Int
	public var height: Int
	public var order: Int
	public var pieces: [Piece]

	public init(id: Int, name: String, width: Int, height: Int, order: Int, pieces: [Piece]) {
		self.id = id
		self.name = name
		self.width = width
		self.height = height
		self.order = order
		self.pieces = pieces
	}

	public init() {
		self.init(id: 0, name: "", width: 0, height: 0, order: 0, pieces: [])
	}
}
