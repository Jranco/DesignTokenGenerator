//
//  PlatformTokenGenerating.swift
//  DesignTokenGenerator
//
//  Created by Thomas Segkoulis on 16.05.26.
//

/// Defines the interface for a platform-specific token generator.
///
/// Each conforming type is responsible for transforming a ``DesignModelContainer``
/// into the token files appropriate for its target platform (e.g. Xcode, web, Android).
/// `TokenGenerator` instantiates the correct conformer based on the requested ``Platform``
/// and calls ``generateTokenFiles()`` to produce the output.
protocol PlatformTokenGenerating {

	/// The file system path where all generated files will be written.
	var exportPath: String { get }

	/// Creates a new generator for the given export path and design model.
	/// - Parameters:
	///   - exportPath: The directory where generated files will be written.
	///   - designModel: The decoded Figma design model containing variables and styles.
	init(exportPath: String, designModel: DesignModelContainer)

	/// Generates all token files for the target platform.
	/// - Throws: Any file system or template rendering error encountered during generation.
	func generateTokenFiles() throws
}

extension PlatformTokenGenerating {
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

	/// Extracts color asset files from the given variable collections.
	///
	/// - Parameter variableCollections: The design variable collections to parse.
	/// - Returns: An array of `ColorAssetFile` models ready for asset catalog generation.
	/// - Throws: Any error raised during color parsing.
	func getColorAssetFiles(variableCollections: DesignVariableCollections) throws -> [ColorAssetFile] {
		let parser = DesignVariableCollectionsParser(variableCollections: variableCollections)
		return try parser.colorAssetFiles()
	}

	/// Extracts gradient color stops from a ``StyleContainer`` as individual ``ColorAssetFile`` entries.
	///
	/// Each gradient stop becomes a separate ``ColorAssetWrapper`` named `{position%}-{styleName}`,
	/// all grouped under a single file named `"GradientColorStyles"`.
	///
	/// - Parameter styles: The raw style container decoded from the Figma model.
	/// - Returns: An array of ``ColorAssetFile`` models ready for asset generation, or empty if no gradients exist.
	/// - Throws: Any error raised during style parsing.
	func getGradientColorAssetFiles(styles: StyleContainer) throws -> [ColorAssetFile] {
		let parser = DesignStylesParser(styles: styles)
		let colorStyles = try parser.colorStyles()
		return parser.gradientColorAssetFiles(from: colorStyles)
	}

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
}
