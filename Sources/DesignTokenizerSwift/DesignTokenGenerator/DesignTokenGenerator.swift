//
//  DesignTokenGenerator.swift
//  DesignTokenizerSwift
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
final class DesignTokenGenerator {

	/// Raw JSON data exported from Figma, containing all variables and styles.
	private var json: Data
	/// The file system path where all generated files will be written.
	private var exportPath: String

	/// Creates a new `DesignTokenGenerator`, responsible for generating Swift design token files and Xcode color asset catalogs
	/// from a parsed Figma design model.
	///
	/// - Parameters:
	///   - json: Raw JSON data exported from Figma, containing all variables and styles.
	///   - exportPath: The file system path where all generated files will be written.
	init(
		json: Data,
		exportPath: String
	) throws {
		self.json = json
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
	
	/// Resolves a fully qualified color name for a given bound variable ID within a color file.
	///
	/// - Parameters:
	///   - colors: The list of color asset wrappers to search within.
	///   - boundVariable: The variable ID to match against.
	///   - fileName: The name of the color asset file, used as the namespace prefix.
	/// - Returns: A dot-separated name in the format `FileName.ColorName`, or `nil` if not found.
	private func colorName(
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

private extension DesignTokenGenerator {

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
}
