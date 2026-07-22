//
//  ArchiveManager.swift
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

public final class ArchiveManager {
	public static let shared = ArchiveManager()

	public var currentArchiveURL: URL?

	public init() {}

	public func comics(success: (Comics?) -> ()) {
		if let path = self.currentArchiveURL?.appendingPathComponent("data.json").relativePath,
			FileManager.default.fileExists(atPath: path) {
			do {
				let decoder = JSONDecoder()
				if let data = try? NSData(contentsOfFile: path, options: []) as Data {
					let comics = try decoder.decode(Comics.self, from: data)
					success(comics)
				} else {
					success(nil)
				}
			}
			catch {
				print("JSON parse error: \(error)")
			}
		}
	}

	#if canImport(UIKit)
	public func layer(name: String, success: @escaping (UIImage) -> ()) {
		guard let path = self.currentArchiveURL?.appendingPathComponent("layers").appendingPathComponent(name).relativePath
			else { return }

		if !FileManager.default.fileExists(atPath: path) {
			success(UIImage())
		} else {
			DispatchQueue.global().async {
				let imageData = try! NSData(contentsOfFile: path, options: []) as Data
				if let image = UIImage(data: imageData, scale: UIScreen.main.scale) {
					DispatchQueue.main.async {
						success(image)
					}
				} else {
					DispatchQueue.main.async {
						success(UIImage())
					}
				}
			}
		}
	}
	#elseif canImport(AppKit)
	public func layer(name: String, success: @escaping (NSImage) -> ()) {
		guard let path = self.currentArchiveURL?.appendingPathComponent("layers").appendingPathComponent(name).relativePath
			else { return }

		if !FileManager.default.fileExists(atPath: path) {
			success(NSImage())
		} else {
			DispatchQueue.global().async {
				let imageData = try! NSData(contentsOfFile: path, options: []) as Data
				if let image = NSImage(data: imageData) {
					DispatchQueue.main.async {
						success(image)
					}
				} else {
					DispatchQueue.main.async {
						success(NSImage())
					}
				}
			}
		}
	}
	#endif

	public func sound(name: String, success: @escaping (URL?) -> ()) {
		guard let path = self.currentArchiveURL?.appendingPathComponent("sounds").appendingPathComponent(name).relativePath
			else { return }

		if !FileManager.default.fileExists(atPath: path) {
			success(nil)
		} else {
			success(URL(fileURLWithPath: path))
		}
	}
}
