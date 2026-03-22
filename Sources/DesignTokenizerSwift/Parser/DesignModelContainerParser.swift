//
//  DesignModelContainerParser.swift
//  DesignTokenGenerator
//
//  Created by Thomas Segkoulis on 10.03.26.
//

import Foundation

/// A parser responsible for decoding raw Figma export JSON into a ``DesignModelContainer``.
///
/// ## Overview
/// `DesignModelContainerParser` serves as the single entry point for deserializing a full
/// Figma export payload. The resulting ``DesignModelContainer`` can then be passed downstream
/// to focused parsers such as ``DesignStylesParser`` and ``DesignVariableCollectionsParser``
/// for further processing.
///
/// ## Usage
/// ```swift
/// let parser = DesignModelContainerParser(json: jsonData)
/// let container = try parser.parseIntoContainer()
/// ```
struct DesignModelContainerParser {

	/// The raw JSON data to be parsed, typically loaded from a full Figma export file.
	var json: Data

	/// Decodes the raw JSON into a ``DesignModelContainer``.
	///
	/// - Returns: A fully decoded ``DesignModelContainer`` containing both variable collections
	///   and named styles exported from Figma.
	/// - Throws: ``DesignStyleParserError/decodingFailed(_:)`` if JSON decoding fails.
	func parseIntoContainer() throws -> DesignModelContainer {
		do {
			let decoder = JSONDecoder()
			return try decoder.decode(DesignModelContainer.self, from: json)
		} catch {
			throw DesignStyleParserError.decodingFailed(error)
		}
	}
}
