//
//  String+Extension.swift
//  ComicsViewer
//
//  Migrated from Mahabharata
//  Copyright © 2018 Stanislav Grinberg. All rights reserved.
//

import Foundation

extension String {
	/// Trims whitespace and newlines from the string
	@discardableResult
	func trim() -> String {
		return self.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	/// Replace occurrences of a substring with another value
	@discardableResult
	func replace(_ substring: String, withValue value: String, ignoreCase: Bool = false) -> String {
		return self.replacingOccurrences(of: substring, with: value, options: ignoreCase ? .caseInsensitive : .literal)
	}

	/// Checks if the specified string is nil or empty
	static func isNilOrEmpty(_ value: String?) -> Bool {
		if let value = value {
			return value.isEmpty
		}
		return true
	}

	/// Checks if the specified string is nil or whitespace
	static func isNilOrWhiteSpace(_ value: String?) -> Bool {
		if let value = value {
			return value.trim().isEmpty
		}
		return true
	}
}
