//
//  Sound.swift
//  ComicsViewer
//
//  Migrated from Mahabharata
//  Copyright © 2017 Iron Water Studio. All rights reserved.
//

import Foundation

public class Sound: Codable {
	//NOTE: do not set default values to make Codable decode properly
	public let file: String? //should get as /sounds/file
	public let animations: [SoundAnim]
}
