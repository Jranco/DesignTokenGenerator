//
//  TokenGenerator.swift
//  DesignTokenGenerator
//
//  Created by Thomas Segkoulis on 10.03.26.
//

import Foundation
import Stencil

/// Responsible for generating Swift design token files and Xcode color asset catalogs
/// from a parsed Figma design model.
///
/// `DesignTokenGenerator` takes a raw JSON payload (exported from Figma) and an export path,
/// then produces:
/// - Xcode `.xcassets` color catalogs for variable and style colors
/// - A `DesignVariables.swift` file for non-color variable tokens
/// - A `ColorTokens.swift` file for color style tokens
/// - A `FontTokens.swift` file for text style tokens
final class TokenGenerator {

	/// Raw JSON data exported from Figma, containing all variables and styles.
	private var json: Data
	/// The file system path where all generated files will be written.
	private var exportPath: String
	/// Determines how light and dark color scheme values are sourced
	/// from the design token JSON structure.
	private var colorSchemeSource: ColorSchemeSource

	/// Creates a new `DesignTokenGenerator`, responsible for generating Swift design token files and Xcode color asset catalogs
	/// from a parsed Figma design model.
	///
	/// - Parameters:
	///   - json: Raw JSON data exported from Figma, containing all variables and styles.
	///   - exportPath: The file system path where all generated files will be written.
	///   - colorSchemeSource: Determines how light and dark color scheme values are sourced from the design token JSON structure.
	init(
		json: Data,
		exportPath: String,
		colorSchemeSource: ColorSchemeSource
	) throws {
		self.colorSchemeSource = colorSchemeSource
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
		
		// Variable colors
		let variableColorAssetFiles = try getColorAssetFiles(variableCollections: model.variableCollections)
		
		// Style
		let styles = try getTextAndColorStyles(styles: model.styles)
		
		// Color style
		let colorStyleAssetFiles = styles.colorAssetFiles
		
		// Text style
		let textStyles = styles.text

		/// Code generation
		try generateAssets(name: "VariableColors", colorAssetFiles: variableColorAssetFiles)
		try generateAssets(name: "StyleColors", colorAssetFiles: colorStyleAssetFiles)
		
		// 1. Variables
		try generateVariablesTemplate(from: model.variableCollections)
		
		// 2. Fonts
		try generateFontTokensFile(from: textStyles)

		// 3. Color
		let allColorFiles = variableColorAssetFiles + colorStyleAssetFiles

		try generateColorTokensFile(from: allColorFiles, colorsBoundToVariables: styles.colorsBoundToVariables)
	}

	// MARK: - Parsing

	/// Parses text and color styles from a `StyleContainer`.
	///
	/// - Parameter styles: The raw style container decoded from the Figma model.
	/// - Returns: A tuple containing text styles, color asset files, and colors bound to variables.
	/// - Throws: Any error raised during style parsing.
	func getTextAndColorStyles(styles: StyleContainer) throws -> (text: [TextStyle], colorAssetFiles: [ColorAssetFile], colorsBoundToVariables: [ColorAssetWrapper]) {
		let parser = DesignStylesParser(styles: styles)
		let text = try parser.textStyles()
		let colorStyles = try parser.colorStyles()
		let color = parser.colorAssetFiles(from: colorStyles)
		return (text, color.colorAssetFiles, color.colorsBoundToVariables)
	}

	/// Extracts color asset files from the given variable collections.
	///
	/// - Parameter variableCollections: The design variable collections to parse.
	/// - Returns: An array of `ColorAssetFile` models ready for asset catalog generation.
	/// - Throws: Any error raised during color parsing.
	func getColorAssetFiles(variableCollections: DesignVariableCollections) throws -> [ColorAssetFile] {
		let parser = DesignVariableCollectionsParser(variableCollections: variableCollections)
		return try parser.colorAssetFiles()
	}

	/// Parses the raw JSON into a `DesignModelContainer`.
	///
	/// - Returns: A fully decoded `DesignModelContainer` with styles and variable collections.
	/// - Throws: A decoding error if the JSON structure does not match the expected model.
	func parseDesignModelContainer() throws -> DesignModelContainer {
		let designModelParser = DesignModelContainerParser(json: json)
		return try designModelParser.parseIntoContainer()
	}

	// MARK: - Code Generation

	/// Generates a `DesignVariables.swift` file from non-color variable collections
	/// using a Stencil template.
	///
	/// Each collection becomes an enum-like context containing its non-color tokens
	/// (bool, number, and string values). RGB and RGBA typed variables are excluded.
	///
	/// - Parameter designVariableCollections: The variable collections to generate tokens from.
	/// - Throws: Any error raised during template rendering or file writing.
	func generateVariablesTemplate(from designVariableCollections: DesignVariableCollections) throws {
		// TODO: Add guard, throw error
		let templateURL = Bundle.module.url(
			forResource: "DesignVariableTokens",
			withExtension: "stencil"
		)!
		let templateData = try Data(contentsOf: templateURL)
		let templateStr = String(data: templateData, encoding: .utf8)

		// Build array of enum contexts — one per collection
		let enums: [[String: Any]] = designVariableCollections.compactMap { collection in
			let tokens = collection.variables.filter { variable in
				variable.type != .RGB && variable.type != .RGBA
			}
			guard !tokens.isEmpty else { return [:] }

			let stencilTokens: [[String: Any]] = tokens.map { token in
				var dict: [String: Any] = ["name": token.name]
				if let v = token.boolValue { dict["boolValue"] = v }
				if let v = token.doubleValue { dict["numberValue"] = v }
				if let v = token.stringValue { dict["stringValue"] = v }
				return dict
			}

			return [
				"name": collection.name.capitalizingFirstLetter(),
				"tokens": stencilTokens
			]
		}

		let context: [String: Any] = ["enums": enums]

		do {
			let template = Template(
				templateString: templateStr!,
				environment: Environment(trimBehaviour: .smart)
			)
			let output = try template.render(context)
			print("\noutput: \(output)\n")
			let outputURL = URL(fileURLWithPath: exportPath)
				.appendingPathComponent("DesignVariables.swift")
			try output.write(
				to: outputURL,
				atomically: true,
				encoding: .utf8
			)
		} catch {
			print("-- error generating output: \(error)")
		}
	}

	/// Generates a `ColorTokens.swift` file from color asset files and bound color styles
	/// using a Stencil template.
	///
	/// Registers custom Stencil filters `swiftTypeName` and `swiftVarName` to produce
	/// valid Swift type and variable names from Figma color group names.
	///
	/// - Parameters:
	///   - colorAssetFiles: All color asset files to include in the output.
	///   - colorsBoundToVariables: Color styles that are bound to a variable, used to
	///     generate semantic color references.
	/// - Throws: Any error raised during template rendering or file writing.
	func generateColorTokensFile(from colorAssetFiles: [ColorAssetFile], colorsBoundToVariables: [ColorAssetWrapper]) throws {
		// TODO: Add guard, throw error
		let templateURL = Bundle.module.url(
			forResource: "ColorTokens",
			withExtension: "stencil"
		)!
		let templateString = try String(contentsOf: templateURL, encoding: .utf8)

		let ext = Extension()

		// "My Color Group" → "MyColorGroup"
		ext.registerFilter("swiftTypeName") { (value: Any?) -> Any? in
			guard let string = value as? String else { return value }
			return string
				.components(separatedBy: CharacterSet.alphanumerics.inverted)
				.filter { !$0.isEmpty }
				.map { $0.prefix(1).uppercased() + $0.dropFirst() }
				.joined()
		}

		// "My Color Name" → "myColorName"
		ext.registerFilter("swiftVarName") { (value: Any?) -> Any? in
			guard let string = value as? String else { return value }
			let parts = string
				.components(separatedBy: CharacterSet.alphanumerics.inverted)
				.filter { !$0.isEmpty }
			guard let first = parts.first else { return value }
			let camel = first.prefix(1).lowercased() + first.dropFirst()
				+ parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
			return camel
		}

		let environment = Environment(extensions: [ext])
		
		let context: [String: Any] = [
			"colorAssetFiles": colorAssetFiles.map { file in
				[
					"name": file.name,
					"colors": file.colors.map { ["name": $0.name] },
					"boundColors": colorsBoundToVariables.compactMap { wrapper -> [String: Any]? in
						guard let resolvedName = colorName(from: file.colors, for: wrapper.boundVariableID, fileName: file.name) else {
							return nil
						}
						return [
							"name": wrapper.name,
							"boundedColorName": resolvedName
						]
					}
				]
			}
		]

		let rendered = try environment.renderTemplate(string: templateString, context: context)

		let outputURL = URL(fileURLWithPath: exportPath)
			.appendingPathComponent("ColorTokens.swift")

		try rendered.write(to: outputURL, atomically: true, encoding: .utf8)

		print("✅ Generated: \(outputURL.path)")
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

private extension TokenGenerator {

	/// Generates Xcode color asset catalogs from the provided color asset file models.
	///
	/// Creates a structured directory hierarchy compatible with Xcode's `.xcassets` format,
	/// writing a `Contents.json` file for each individual color asset.
	///
	/// The resulting folder structure will be:
	/// ```
	/// <exportPath>/
	/// └── <name>/
	///     └── <ColorAssetFile.name>.xcassets/
	///         └── <ColorAsset.name>.colorset/
	///             └── Contents.json
	/// ```
	///
	/// - Parameters:
	///   - name: The name of the root output folder created under `exportPath`.
	///   - colorAssetFiles: An array of ``ColorAssetFile`` models, each representing
	///     a single `.xcassets` catalog containing one or more named color assets.
	/// - Throws: A `FileManager` error if any directory or file operation fails,
	///   or an encoding error if a ``ColorAsset`` cannot be serialized to JSON.
	func generateAssets(
		name: String,
		colorAssetFiles: [ColorAssetFile]
	) throws {
		let rootURL: URL = URL(fileURLWithPath: exportPath).appendingPathComponent(name)
		try FileManager.default.createDirectory(
			at: rootURL,
			withIntermediateDirectories: true
		)
		try colorAssetFiles.forEach { colorAssetFile in
			let rootFolderName = colorAssetFile.name + ".xcassets"
			let rootFolderURL = rootURL.appendingPathComponent(rootFolderName)
			try FileManager.default.createDirectory(
				at: rootFolderURL,
				withIntermediateDirectories: true
			)
			try colorAssetFile.colors.forEach { colorAsset in
				let folderName = colorAsset.name + ".colorset"
				let folderURL = rootFolderURL.appendingPathComponent(folderName)
				try FileManager.default.createDirectory(
					at: folderURL,
					withIntermediateDirectories: true
				)
				let fileURL = folderURL.appendingPathComponent("Contents.json")
				let data = try JSONEncoder().encode(colorAsset.colorAsset)
				try data.write(to: fileURL)
			}
		}
	}

	/// Resolves a fully qualified color name for a given bound variable ID within a color file.
	///
	/// - Parameters:
	///   - colors: The list of color asset wrappers to search within.
	///   - boundVariable: The variable ID to match against.
	///   - fileName: The name of the color asset file, used as the namespace prefix.
	/// - Returns: A dot-separated name in the format `FileName.ColorName`, or `nil` if not found.
	func colorName(
		from colors: [ColorAssetWrapper],
		for boundVariable: String?,
		fileName: String
	) -> String? {
		guard let boundVariable = boundVariable else {
			return nil
		}
		let matchedColorName = colors.first { $0.id == boundVariable }
		guard let fullNamePath = matchedColorName?.name else {
			return nil
		}
		return [fileName.capitalizingFirstLetter(), fullNamePath].joined(separator: ".")
	}

	/// Generates a `FontTokens.swift` file from an array of text styles
	/// using a Stencil template.
	///
	/// Converts letter spacing and line height values to points based on their unit type
	/// (percent or pixels) before passing them into the template context.
	///
	/// - Parameter textStyles: The text styles to generate font tokens from.
	/// - Throws: Any error raised during template rendering or file writing.
	func generateFontTokensFile(from textStyles: [TextStyle]) throws {
		let templateURL = Bundle.module.url(
			forResource: "FontTokens",
			withExtension: "stencil"
		)!
		let templateString = try String(contentsOf: templateURL, encoding: .utf8)

		let ext = Extension()

		ext.registerFilter("swiftVarName") { (value: Any?) -> Any? in
			guard let string = value as? String else { return value }
			let parts = string
				.components(separatedBy: CharacterSet.alphanumerics.inverted)
				.filter { !$0.isEmpty }
			guard let first = parts.first else { return value }
			return first.prefix(1).lowercased() + first.dropFirst()
				+ parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
		}

		let environment = Environment(extensions: [ext])

		let context: [String: Any] = [
			"textStyles": textStyles.map { style -> [String: Any] in
				// Convert letter spacing to points
				let letterSpacingPt: Double = {
					switch style.letterSpacing.unit {
					case .percent:  return (style.letterSpacing.value / 100.0) * style.fontSize
					case .pixels:   return style.letterSpacing.value
					case .auto:     return 0
					}
				}()

				// Convert line height to points
				let lineHeightPt: Double? = {
					switch style.lineHeight.unit {
					case .percent:  return ((style.lineHeight.value ?? 0) / 100.0) * style.fontSize
					case .pixels:   return style.lineHeight.value
					case .auto:     return nil
					}
				}()

				var dict: [String: Any] = [
					"name":           style.name,
					"fontFamily":     style.fontName.family,
					"fontStyle":      style.fontName.style,
					"fontSize":       style.fontSize,
					"letterSpacing":  letterSpacingPt,
					"paragraphSpacing": style.paragraphSpacing,
				]
				if let lh = lineHeightPt {
					dict["lineHeight"] = lh
					dict["hasLineHeight"] = true
				} else {
					dict["hasLineHeight"] = false
				}
				return dict
			}
		]

		let rendered = try environment.renderTemplate(string: templateString, context: context)

		let outputURL = URL(fileURLWithPath: exportPath)
			.appendingPathComponent("FontTokens.swift")

		try rendered.write(to: outputURL, atomically: true, encoding: .utf8)

		print("✅ Generated: \(outputURL.path)")
	}
}

/// Determines how light and dark color scheme values are sourced
/// from the design token JSON structure.
enum ColorSchemeSource {

	/// Light and dark values are defined in separate top-level collections
	/// named "light" and "dark". The two collections are merged into one,
	/// with dark variables embedded as an additional mode alongside the
	/// light variables. Collections where all variables are mapped are
	/// removed from the output.
	case collections

	/// Light and dark values are defined as modes within a single collection.
	/// Each variable already carries values for both modes and no merging
	/// is required.
	case modes
}

enum TokenTransformError: Error {
	case invalidInput(String)
}
