//
//  TokenGenerator.swift
//  DesignTokenGenerator
//
//  Created by Thomas Segkoulis on 10.03.26.
//

import Foundation
import Stencil

/// Responsible for generating design token files for one or more target platforms
/// from a parsed Figma design model.
///
/// `TokenGenerator` takes a raw JSON payload (exported from Figma), an export path,
/// and a set of target platforms, then delegates to the appropriate platform generator
/// for each:
/// - **xcode**: Xcode `.xcassets` color catalogs, `DesignVariables.swift`, `ColorTokens.swift`, `FontTokens.swift`
/// - **web**: `DesignVariables.css`, `ColorTokens.css`, `FontTokens.css`
/// - **android**: not yet supported
///
/// Output for each platform is written to `<exportPath>/<platform>/`.
final class TokenGenerator {

	/// Raw JSON data exported from Figma, containing all variables and styles.
	private var json: Data
	/// The file system path where all generated files will be written.
	private var exportPath: String
	/// Determines how light and dark color scheme values are sourced
	/// from the design token JSON structure.
	private var colorSchemeSource: ColorSchemeSource
	/// The target platforms for token generation.
	private var platforms: [Platform]

	/// Creates a new `DesignTokenGenerator`, responsible for generating Swift design token files and Xcode color asset catalogs
	/// from a parsed Figma design model.
	///
	/// - Parameters:
	///   - json: Raw JSON data exported from Figma, containing all variables and styles.
	///   - exportPath: The file system path where all generated files will be written.
	///   - colorSchemeSource: Determines how light and dark color scheme values are sourced from the design token JSON structure.
	///   - platforms: The target platforms that determine which generators are used.
	init(
		json: Data,
		exportPath: String,
		colorSchemeSource: ColorSchemeSource,
		platforms: [Platform] = [.xcode]
	) throws {
		self.colorSchemeSource = colorSchemeSource
		self.platforms = platforms
		self.json = colorSchemeSource == .collections ? try! Self.transformDesignTokens(json) : json
		self.exportPath = exportPath
	}

	// MARK: - File Generation

	/// Entry point for generating all design token files.
	///
	/// Parses the Figma JSON, then generates color asset catalogs,
	/// variable tokens, font tokens, and color tokens in sequence.
	///
	/// - Throws: Any parsing or file writing error encountered during generation.
	func generateTokenFiles() throws {
		let model = try parseDesignModelContainer()
		for platform in platforms {
			let platformExportPath = exportPath.hasSuffix("/")
				? exportPath + platform.rawValue
				: exportPath + "/" + platform.rawValue
			try FileManager.default.createDirectory(
				atPath: platformExportPath,
				withIntermediateDirectories: true
			)
			switch platform {
			case .xcode:
				try XCodeTokenGenerator(exportPath: platformExportPath, designModel: model).generateTokenFiles()
			case .web:
				try WebTokenGenerator(exportPath: platformExportPath, designModel: model).generateTokenFiles()
			case .android:
				print("❌ Android platform is not yet supported.")
			}
		}
	}

	// MARK: - Parsing

	/// Parses the raw JSON into a `DesignModelContainer`.
	///
	/// - Returns: A fully decoded `DesignModelContainer` with styles and variable collections.
	/// - Throws: A decoding error if the JSON structure does not match the expected model.
	func parseDesignModelContainer() throws -> DesignModelContainer {
		let designModelParser = DesignModelContainerParser(json: json)
		return try designModelParser.parseIntoContainer()
	}

	/// Transforms a design token JSON payload into a normalised structure
	/// where light and dark color scheme values are combined into a single
	/// variable collection.
	///
	/// - Parameters:
	///   - inputData: Raw JSON data conforming to the design token export format,
	///                containing a `designModelContainer` with `variableCollections`
	///                and `styles`.
	///
	/// - Returns: JSON data containing a flat `variableCollections` array and
	///            `styles`, with light and dark values merged where applicable.
	///
	/// - Throws: `TokenTransformError.invalidInput` if the JSON structure is
	///           missing required fields.
	static func transformDesignTokens(_ inputData: Data) throws -> Data {
		guard let root = try JSONSerialization.jsonObject(with: inputData) as? [String: Any],
			  let container = root["designModelContainer"] as? [String: Any],
			  let collections = container["variableCollections"] as? [[String: Any]],
			  let styles = container["styles"] as? [String: Any]
		else {
			throw TokenTransformError.invalidInput("Missing required fields")
		}

		var lightCollection: [String: Any]?
		var darkCollection: [String: Any]?
		var otherCollections: [[String: Any]] = []

		for collection in collections {
			switch (collection["name"] as? String)?.lowercased() {
			case "light": lightCollection = collection
			case "dark":  darkCollection = collection
			default:      otherCollections.append(collection)
			}
		}

		var resultCollections: [[String: Any]] = []

		if var light = lightCollection, let dark = darkCollection {
			let darkVariables = dark["variables"] as? [[String: Any]] ?? []
			let darkByName = Dictionary(
				darkVariables.compactMap { v -> (String, [String: Any])? in
					guard let name = v["name"] as? String else { return nil }
					return (name, v)
				},
				uniquingKeysWith: { first, _ in first }
			)

			var modes = light["modes"] as? [[String: Any]] ?? []
			let darkModes = dark["modes"] as? [[String: Any]] ?? []
			let modeInsertAt = min(1, modes.count)
			modes.insert(contentsOf: darkModes, at: modeInsertAt)
			light["modes"] = modes

			var mappedDarkNames = Set<String>()
			var lightVariables = light["variables"] as? [[String: Any]] ?? []

			for i in lightVariables.indices {
				guard let name = lightVariables[i]["name"] as? String,
					  let darkVar = darkByName[name] else { continue }

				let darkValues = darkVar["value"] as? [[String: Any]] ?? []
				var values = lightVariables[i]["value"] as? [[String: Any]] ?? []
				let insertAt = min(1, values.count)
				values.insert(contentsOf: darkValues, at: insertAt)
				lightVariables[i]["value"] = values
				mappedDarkNames.insert(name)
			}

			// Append remaining dark variables that are not matched to any respective light ones.
			let clearPlaceholder: [String: Any] = [
				"id": "2:0",
				"data": ["r": 0, "g": 0, "b": 0, "a": 0]
			]

			let unmapped = darkVariables
				.filter {
					guard let name = $0["name"] as? String else { return true }
					return !mappedDarkNames.contains(name)
				}
				.map { var v = $0
					var values = v["value"] as? [[String: Any]] ?? []
					values.insert(clearPlaceholder, at: 0)
					v["value"] = values
					return v
				}
			
			// Log warning
			if !unmapped.isEmpty {
				print("⚠️ Design token mismatch: \(unmapped.count) dark variable(s) have no matching light counterpart — using white placeholder. Names: \(unmapped.compactMap { $0["name"] as? String }.joined(separator: ", "))")
			}

			lightVariables += unmapped

			light["variables"] = lightVariables
			light["name"] = "light-dark-combined"
			resultCollections.append(light)
		} else {
			if let light = lightCollection { resultCollections.append(light) }
			if let dark  = darkCollection  { resultCollections.append(dark)  }
		}

		resultCollections += otherCollections

		let output: [String: Any] = [
			"variableCollections": resultCollections,
			"styles": styles
		]

		return try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted])
	}
}

enum TokenTransformError: Error {
	case invalidInput(String)
}
