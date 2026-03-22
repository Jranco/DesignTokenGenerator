//
//  DesignVariableCollectionsParser.swift
//  DesignTokenGenerator
//
//  Created by Thomas Segkoulis on 26.12.25.
//

import Foundation

/// A parser responsible for extracting and transforming design variable collections
/// into color asset files suitable for use in Xcode asset catalogs.
///
/// ## Overview
/// `DesignVariableCollectionsParser` operates on an already-decoded ``DesignVariableCollections``
/// value, exposing focused operations for converting color variables into ``ColorAssetFile``
/// instances. JSON decoding is handled upstream by ``DesignModelContainerParser``.
///
/// ## Usage
/// ```swift
/// let parser = DesignVariableCollectionsParser(variableCollections: container.variableCollections)
/// let assetFiles = try parser.colorAssetFiles()
/// ```
struct DesignVariableCollectionsParser {

	/// The decoded variable collections to extract and transform color assets from.
	var variableCollections: DesignVariableCollections

	/// Transforms all variable collections into an array of ``ColorAssetFile`` objects.
	///
	/// Each collection is mapped to a single ``ColorAssetFile`` named after the collection,
	/// grouping all resolved color assets within it. Variables that are not of type
	/// `.RGB` or `.RGBA` are silently skipped.
	///
	/// - Returns: An array of ``ColorAssetFile`` instances ready for use in asset catalog generation.
	/// - Throws: Any error thrown during individual color asset parsing.
	func colorAssetFiles() throws -> [ColorAssetFile] {
		try variableCollections.map {
			try colorAssetFile(from: $0)
		}
	}
}

private extension DesignVariableCollectionsParser {

	/// Converts a single ``DesignVariableCollection`` into a ``ColorAssetFile``.
	///
	/// Iterates over all variables in the collection, converting each to a ``ColorAssetWrapper``.
	/// Variables that cannot be converted (e.g. non-color types) are silently skipped via `compactMap`.
	///
	/// - Parameter designVariableCollection: The collection to convert.
	/// - Returns: A ``ColorAssetFile`` named after the collection, containing all resolved color assets.
	/// - Throws: Any error thrown during individual variable parsing.
	private func colorAssetFile(from designVariableCollection: DesignVariableCollection) throws -> ColorAssetFile {
		let colorAssets: [ColorAssetWrapper] = try designVariableCollection.variables.compactMap { try colorAsset(from: $0) }
		return ColorAssetFile(name: designVariableCollection.name, colors: colorAssets)
	}

	/// Attempts to convert a ``DesignVariable`` into a ``ColorAssetWrapper``.
	///
	/// This method handles both light and optional dark mode variants:
	/// - The first value in the variable's `value` array is treated as the light appearance.
	/// - If a second value is present, it is treated as the dark appearance.
	///
	/// Variables are skipped (returning `nil`) if:
	/// - They contain no values.
	/// - Their type is not `.RGB` or `.RGBA`.
	/// - The light color entry cannot be resolved.
	///
	/// - Parameter designVariable: The design variable to convert.
	/// - Returns: A ``ColorAssetWrapper`` if the variable is a valid color, or `nil` if it should be skipped.
	/// - Throws: Any error thrown by ``colorEntry(from:isDark:)``.
	private func colorAsset(from designVariable: DesignVariable) throws -> ColorAssetWrapper? {
		var colorEntries: [ColorEntry] = []
		guard let colorLight = designVariable.value.first else {
			return nil
		}

		guard designVariable.type == .RGB || designVariable.type == .RGBA else {
			return nil
		}

		guard let colorEntryLight = try colorEntry(from: colorLight, isDark: false) else {
			return nil
		}
		colorEntries.append(colorEntryLight)

		if designVariable.value.count > 1 {
			let colorDark = designVariable.value[1]
			if let colorEntryDark = try colorEntry(from: colorDark, isDark: true) {
				colorEntries.append(colorEntryDark)
			}
		}

		let colorAsset = ColorAsset(colors: colorEntries, info: AssetInfo(author: "xcode", version: 1))
		return ColorAssetWrapper(id: designVariable.id,
								 name: designVariable.name,
								 colorAsset: colorAsset,
								 boundVariableID: nil)
	}

	/// Converts a ``DesignVariableValue`` into a ``ColorEntry`` for use in an Xcode asset catalog.
	///
	/// Only values with an `.rgb` payload are supported. Values with other payload types
	/// (e.g. aliases or unsupported formats) return `nil`.
	///
	/// The resulting `ColorEntry` uses the sRGB color space and universal idiom,
	/// with the appearance set to either `.dark` or `.light` based on `isDark`.
	///
	/// - Parameters:
	///   - designVariableValue: The variable value containing the color payload.
	///   - isDark: `true` if this entry represents the dark mode appearance; `false` for light.
	/// - Returns: A ``ColorEntry`` if the payload is a valid RGB color, or `nil` otherwise.
	/// - Throws: Any error encountered during color entry construction.
	private func colorEntry(
		from designVariableValue: DesignVariableValue,
		isDark: Bool
	) throws -> ColorEntry? {
		guard
			case let DesignVariablePayload.rgb(rgb) = designVariableValue.payload else {
			return nil
		}
		return ColorEntry(
			idiom: .universal,
			color: AssetColor(
				colorSpace: .sRGB,
				components: ColorComponents(
					red: "\(rgb.r)",
					green: "\(rgb.g)",
					blue: "\(rgb.b)",
					alpha: "\(rgb.a)"
				)
			),
			appearances: [Appearance(appearance: .luminosity, value: isDark ? .dark : .light)]
		)
	}
}

// MARK: - Errors

/// Errors thrown during design variable parsing and asset file generation.
enum DesignVariableParserError: Error {

	/// The specified file could not be found at the given path.
	case fileNotFound(String)

	/// The file was found but its contents could not be read as valid data.
	case unreadableData(String)

	/// JSON decoding failed. The associated error provides details from the decoder.
	case decodingFailed(Error)

	/// A color variable was found but contained no values to process.
	case emptyColorValues
}
