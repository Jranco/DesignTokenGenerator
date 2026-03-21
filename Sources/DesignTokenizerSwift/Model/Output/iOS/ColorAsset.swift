//
//  ColorAsset.swift
//  DesignTokenizerSwift
//
//  Created by Thomas Segkoulis on 22.12.25.
//

import Foundation

/// Represents a collection of named color assets grouped into a single file.
///
/// This is the top-level structure used to serialize/deserialize a color asset file
/// that will be converted into iOS `.xcassets` color asset entries.
///
/// - Note: Maps to a group of color asset folders inside an `.xcassets` bundle.
struct ColorAssetFile: Codable {
	/// The name of the color asset file or group.
	let name: String
	/// The list of named color asset wrappers contained in this file.
	let colors: [ColorAssetWrapper]
}

// MARK: - Top Level

/// A named wrapper around a single ``ColorAsset``.
///
/// Acts as the bridge between a color token name and its actual asset definition,
/// mapping to a single `.colorset` folder inside an `.xcassets` bundle.
struct ColorAssetWrapper: Codable {
	/// Unique identifier of the asset.
	let id: String
	/// The name of the color asset, used as the `.colorset` folder name.
	let name: String
	/// The color asset definition containing all color variants and metadata.
	let colorAsset: ColorAsset
	/// An optional identifier of the bound variable that provides the color.
	let boundVariableID: String?
}

/// Represents the contents of a `.colorset` asset, equivalent to `Contents.json`.
///
/// Contains one or more ``ColorEntry`` variants (e.g. light/dark mode)
/// along with asset catalog metadata.
struct ColorAsset: Codable {
	/// The list of color entries, each representing a variant (e.g. light or dark appearance).
	let colors: [ColorEntry]
	/// Metadata about the asset, including author and format version.
	let info: AssetInfo
}

// MARK: - Color Entry

/// A single color variant within a color asset, scoped to a specific idiom and appearance.
///
/// Corresponds to a single entry in the `"colors"` array of a `Contents.json` file.
/// A color asset typically contains two entries: one for light mode and one for dark mode.
///
/// - Note: If `appearances` is `nil`, the entry applies universally regardless of appearance.
struct ColorEntry: Codable {
	/// The device idiom this color entry targets (e.g. `.universal`, `.iphone`).
	let idiom: Idiom
	/// The actual color value and color space definition.
	let color: AssetColor
	/// The appearance conditions (e.g. light/dark) under which this color entry is applied.
	/// If `nil`, the color is used for all appearances.
	let appearances: [Appearance]?
}

// MARK: - Color

/// Defines a color value within a specific color space.
///
/// Maps directly to the `"color"` object in a `Contents.json` color entry,
/// containing both the color space and the RGBA component values.
struct AssetColor: Codable {
	/// The color space in which the color components are defined.
	let colorSpace: ColorSpace
	/// The red, green, blue, and alpha component values of the color.
	let components: ColorComponents

	enum CodingKeys: String, CodingKey {
		case colorSpace = "color-space"
		case components
	}
}

// MARK: - Components

/// The RGBA component values of a color, expressed as strings.
///
/// Values are typically represented as floating point strings in the range `0.0` to `1.0`,
/// or as hex strings depending on the color space.
///
/// Example:
/// ```json
/// { "red": "0.988", "green": "0.353", "blue": "0.353", "alpha": "1.000" }
/// ```
struct ColorComponents: Codable {
	/// The red channel value.
	let red: String
	/// The green channel value.
	let green: String
	/// The blue channel value.
	let blue: String
	/// The alpha (opacity) channel value. `"1.000"` is fully opaque.
	let alpha: String
}

// MARK: - Appearance

/// Describes an appearance condition under which a color entry is applied.
///
/// Used to differentiate between light and dark mode color variants within a `.colorset`.
///
/// Example mapping:
/// ```json
/// { "appearance": "luminosity", "value": "dark" }
/// ```
struct Appearance: Codable {
	/// The type of appearance trait being described (e.g. luminosity).
	let appearance: AppearanceType
	/// The value of the appearance trait (e.g. light or dark).
	let value: AppearanceValue
}

/// The category of appearance trait used to conditionally apply a color.
///
/// Currently only `luminosity` is supported, which maps to light/dark mode.
enum AppearanceType: String, Codable {
	/// Luminosity-based appearance, used to distinguish light and dark mode.
	case luminosity
}

/// The value of a luminosity appearance trait.
enum AppearanceValue: String, Codable {
	/// The color applies in light mode.
	case light
	/// The color applies in dark mode.
	case dark
}

// MARK: - Asset Info

/// Metadata for a color asset, written into the `"info"` block of `Contents.json`.
///
/// Example:
/// ```json
/// { "author": "xcode", "version": 1 }
/// ```
struct AssetInfo: Codable {
	/// The author of the asset catalog entry (typically `"xcode"`).
	let author: String
	/// The format version of the asset catalog (typically `1`).
	let version: Int
}

// MARK: - Enums

/// The target device idiom for a color asset entry.
///
/// Determines which devices a color variant applies to.
/// Use `.universal` to target all devices.
enum Idiom: String, Codable {
	/// Applies to all device types.
	case universal
	/// Applies to iPhone only.
	case iphone
	/// Applies to iPad only.
	case ipad
	/// Applies to Mac (Catalyst or native).
	case mac
	/// Applies to Apple TV.
	case tv
	/// Applies to Apple Watch.
	case watch
}

/// The color space in which a color's components are interpreted.
///
/// Determines the gamut and rendering of the color on screen.
enum ColorSpace: String, Codable {
	/// Standard sRGB color space. The most common for iOS apps.
	case sRGB = "srgb"
	/// Display P3 wide color gamut. Supported on modern iPhone and iPad displays.
	case displayP3 = "display-p3"
	/// Extended sRGB, allowing values outside the 0–1 range for HDR content.
	case extendedSRGB = "extended-srgb"
}
