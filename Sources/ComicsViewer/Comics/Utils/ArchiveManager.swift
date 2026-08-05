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

	private let fixedArchiveURL: URL?
	private var legacyArchiveURL: URL?

	public var currentArchiveURL: URL? {
		get { fixedArchiveURL ?? legacyArchiveURL }
		set {
			guard fixedArchiveURL == nil else { return }
			legacyArchiveURL = newValue?.standardizedFileURL
		}
	}

	public init() {
		self.fixedArchiveURL = nil
	}

	public init(rootURL: URL) {
		self.fixedArchiveURL = rootURL.standardizedFileURL
	}

	private func resourceURL(directory: String? = nil, name: String) -> URL? {
		guard let rootURL = currentArchiveURL?.standardizedFileURL,
			!name.isEmpty,
			!name.contains("\\"),
			!(name as NSString).isAbsolutePath,
			!name.split(separator: "/", omittingEmptySubsequences: false).contains("..")
		else { return nil }

		let baseURL = directory.map { rootURL.appendingPathComponent($0, isDirectory: true) } ?? rootURL
		let candidate = baseURL.appendingPathComponent(name).standardizedFileURL
		let basePath = baseURL.standardizedFileURL.path
		guard candidate.path == basePath || candidate.path.hasPrefix(basePath + "/") else { return nil }
		return candidate
	}

	public func comics(success: (Comics?) -> ()) {
		if let path = self.resourceURL(name: "data.json")?.path,
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
		guard let path = self.resourceURL(directory: "layers", name: name)?.path
			else { return }

		if !FileManager.default.fileExists(atPath: path) {
			success(UIImage())
		} else {
			DispatchQueue.global().async {
				let imageData = try? Data(contentsOf: URL(fileURLWithPath: path))
				if let imageData, let image = UIImage(data: imageData, scale: UIScreen.main.scale) {
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
		guard let path = self.resourceURL(directory: "layers", name: name)?.path
			else { return }

		if !FileManager.default.fileExists(atPath: path) {
			success(NSImage())
		} else {
			DispatchQueue.global().async {
				let imageData = try? Data(contentsOf: URL(fileURLWithPath: path))
				if let imageData, let image = NSImage(data: imageData) {
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
		guard let path = self.resourceURL(directory: "sounds", name: name)?.path
			else { return }

		if !FileManager.default.fileExists(atPath: path) {
			success(nil)
		} else {
			success(URL(fileURLWithPath: path))
		}
	}
}
