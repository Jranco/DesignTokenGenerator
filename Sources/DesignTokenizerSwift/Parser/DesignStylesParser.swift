//
//  DesignStylesParser.swift
//  DesignTokenizerSwift
//
//  Created by Thomas Segkoulis on 09.03.26.
//

import Foundation

// MARK: - Parser

/// A parser responsible for extracting and transforming design styles from a ``StyleContainer``.
///
/// ## Overview
/// `DesignStylesParser` operates on an already-decoded ``StyleContainer``, exposing focused
/// operations for retrieving text and color styles and converting them into Xcode asset catalog
/// structures. JSON decoding is handled upstream by ``DesignModelContainerParser``.
///
/// ## Usage
/// ```swift
/// let parser = DesignStylesParser(styles: container.styles)
/// let textStyles = try parser.textStyles()
/// let colorStyles = try parser.colorStyles()
/// let assetFiles = parser.colorAssetFiles(from: colorStyles)
/// ```
struct DesignStylesParser {

	/// The decoded style container to extract and transform styles from.
	var styles: StyleContainer

	/// Extracts all text styles from the underlying ``StyleContainer``.
	///
	/// - Returns: An array of ``TextStyle`` instances.
	/// - Throws: ``DesignStyleParserError/emptyStyles`` if the text styles array is empty.
	func textStyles() throws -> [TextStyle] {
		guard !styles.text.isEmpty else {
			throw DesignStyleParserError.emptyStyles
		}
		return styles.text
	}

	/// Extracts all color and gradient styles from the underlying ``StyleContainer``.
	///
	/// - Returns: An array of ``ColorStyle`` instances.
	/// - Throws: ``DesignStyleParserError/emptyStyles`` if the color styles array is empty.
	func colorStyles() throws -> [ColorStyle] {
		guard !styles.color.isEmpty else {
			throw DesignStyleParserError.emptyStyles
		}
		return styles.color
	}

	/// Transforms an array of ``ColorStyle`` instances into a single ``ColorAssetFile``.
	///
	/// All styles are resolved into ``ColorAssetWrapper`` instances and grouped into
	/// one ``ColorAssetFile`` named `"styles"`. Styles that produce no resolvable colors
	/// (e.g. gradients, styles with no color values) are silently skipped via `compactMap`.
	///
	/// - Parameter colorStyles: The array of color styles to convert, typically obtained
	///   from ``colorStyles()``.
	/// - Returns: An array containing a single ``ColorAssetFile`` with all resolved color wrappers.
	func colorAssetFiles(from colorStyles: [ColorStyle]) -> (colorAssetFiles: [ColorAssetFile], colorsBoundToVariables: [ColorAssetWrapper]) {
		let colorWrappers =  colorStyles.reduce(into: ([ColorAssetWrapper](), [ColorAssetWrapper]())) { partialResult, colorStyle in
			guard let colorAssetWrapper = colorAssetWrapper(from: colorStyle) else {
				return
			}
			if colorAssetWrapper.boundVariableID != nil {
				partialResult.1.append(colorAssetWrapper)
			} else {
				partialResult.0.append(colorAssetWrapper)
			}
		}
		return ([ColorAssetFile(name: "ColorStyles", colors: colorWrappers.0)], colorWrappers.1)
	}
}

// MARK: - Filtering

extension DesignStylesParser {

	/// Filters a flat array of ``ColorStyle`` instances down to solid fills only.
	///
	/// Gradient styles (``ColorStyleType/gradientLinear``, ``ColorStyleType/gradientRadial``)
	/// are excluded from the result.
	///
	/// - Parameter colorStyles: The full array of color styles to filter.
	/// - Returns: Only the styles whose ``ColorStyle/type`` is ``ColorStyleType/solid``.
	func solidColorStyles(from colorStyles: [ColorStyle]) -> [ColorStyle] {
		colorStyles.filter { $0.type == .solid }
	}

	/// Filters a flat array of ``ColorStyle`` instances down to gradient styles only.
	///
	/// Solid fills are excluded from the result.
	///
	/// - Parameter colorStyles: The full array of color styles to filter.
	/// - Returns: Only the styles whose ``ColorStyle/type`` is a gradient variant.
	func gradientColorStyles(from colorStyles: [ColorStyle]) -> [ColorStyle] {
		colorStyles.filter { $0.type == .gradientLinear || $0.type == .gradientRadial }
	}

	/// Filters a flat array of ``ColorStyle`` instances down to those backed by a Figma variable.
	///
	/// Styles without a ``ColorStyle/boundVariable`` are excluded from the result.
	///
	/// - Parameter colorStyles: The full array of color styles to filter.
	/// - Returns: Only the styles that reference a bound design token variable.
	func variableBoundColorStyles(from colorStyles: [ColorStyle]) -> [ColorStyle] {
		colorStyles.filter { $0.boundVariable != nil }
	}

	/// Attempts to convert a single ``ColorStyle`` into a ``ColorAssetWrapper``.
	///
	/// Color resolution follows this priority order:
	/// 1. If the style has a ``ColorStyle/boundVariable``, its resolved values are used
	///    as the source of truth over the raw ``ColorStyle/color`` array.
	/// 2. Otherwise, the raw ``ColorStyle/color`` array is used directly.
	///
	/// The first resolved color is treated as the light appearance. If a second color
	/// is present it is treated as the dark appearance. Styles that yield no resolvable
	/// colors (e.g. gradients) return `nil` and are skipped during asset generation.
	///
	/// - Parameter style: The ``ColorStyle`` to convert.
	/// - Returns: A ``ColorAssetWrapper`` if at least one color can be resolved, or `nil` otherwise.
	func colorAssetWrapper(from style: ColorStyle) -> ColorAssetWrapper? {
		let resolvedColors: [RGB]
		
		
		
		if let boundValues = style.boundVariable?.value.map(\.data) {
			resolvedColors = boundValues
		} else {
			resolvedColors = style.color ?? []
		}

		guard let light = resolvedColors.first else { return nil }

		var entries: [ColorEntry] = [
			colorEntry(from: light, isDark: false)
		]

		if resolvedColors.count > 1 {
			entries.append(colorEntry(from: resolvedColors[1], isDark: true))
		}
		return ColorAssetWrapper(
			id: style.id,
			name: style.name,
			colorAsset: ColorAsset(
				colors: entries,
				info: AssetInfo(author: "xcode", version: 1)
			),
			boundVariableID: style.boundVariable?.id
		)
	}

	/// Converts a single ``RGB`` value into a ``ColorEntry`` for an Xcode asset catalog.
	///
	/// The resulting entry uses the sRGB color space and universal idiom,
	/// with the appearance set to either `.dark` or `.light` based on `isDark`.
	///
	/// - Parameters:
	///   - rgba: The color value to convert.
	///   - isDark: `true` if this entry represents the dark mode appearance; `false` for light.
	/// - Returns: A fully constructed ``ColorEntry``.
	func colorEntry(from rgba: RGB, isDark: Bool) -> ColorEntry {
		ColorEntry(
			idiom: .universal,
			color: AssetColor(
				colorSpace: .sRGB,
				components: ColorComponents(
					red: "\(rgba.r)",
					green: "\(rgba.g)",
					blue: "\(rgba.b)",
					alpha: "\(rgba.a)"
				)
			),
			appearances: [Appearance(appearance: .luminosity, value: isDark ? .dark : .light)]
		)
	}
}

// MARK: - Errors

/// Errors thrown during style parsing and extraction.
enum DesignStyleParserError: Error {

	/// JSON decoding failed. The associated error provides details from the decoder.
	case decodingFailed(Error)

	/// The decoded styles container contained no entries for the requested style type.
	case emptyStyles

	/// The specified style could not be found by name or identifier.
	case styleNotFound(String)
}
