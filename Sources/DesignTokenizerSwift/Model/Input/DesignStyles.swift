//
//  DesignStyles.swift
//  DesignTokenGenerator
//
//  Created by Thomas Segkoulis on 09.03.26.
//

// MARK: - Root

/// Top-level container that groups all design styles exported from Figma.
///
/// Maps directly to the root JSON object containing `text` and `color` style arrays.
struct StyleContainer: Codable {

	/// All text/typography styles defined in the Figma file.
	let text: [TextStyle]

	/// All color and gradient styles defined in the Figma file.
	let color: [ColorStyle]
}

// MARK: - Text

/// Represents a single typography style exported from Figma.
///
/// Encapsulates all typographic properties including font family, size,
/// spacing, and casing — sufficient to fully reconstruct the style in code.
struct TextStyle: Codable {

	/// Unique Figma style identifier, e.g. `"S:0880510795f526d10a3325fb56ece0c8ed136fa5,"`.
	let id: String

	/// Human-readable name assigned to the style in Figma, e.g. `"testFont1"`.
	let name: String

	/// Optional designer-provided description of the style's intended use.
	let description: String

	/// The font family and style variant (e.g. `"Inter"`, `"Regular"`).
	let fontName: FontName

	/// The font size in points.
	let fontSize: Double

	/// The spacing between individual characters.
	let letterSpacing: LetterSpacing

	/// The vertical spacing between lines of text.
	let lineHeight: LineHeight

	/// The indentation applied to the first line of each paragraph, in points.
	let paragraphIndent: Double

	/// The additional spacing inserted after each paragraph, in points.
	let paragraphSpacing: Double

	/// The casing transformation applied to the text (e.g. original, uppercase).
	let textCase: String
}

/// The font family and style variant for a ``TextStyle``.
struct FontName: Codable {

	/// The font family name, e.g. `"Inter"` or `"Jaro"`.
	let family: String

	/// The style variant within the family, e.g. `"Regular"`, `"Bold"`.
	let style: String
}

/// The spacing between individual characters in a ``TextStyle``.
struct LetterSpacing: Codable {

	/// The numeric spacing value. Interpretation depends on ``unit``.
	let value: Double

	/// The unit in which ``value`` is expressed.
	let unit: SpacingUnit
}

/// The unit of measurement for spacing and sizing values.
enum SpacingUnit: String, Codable {

	/// A percentage of the font size.
	case percent = "PERCENT"

	/// An absolute value in screen pixels.
	case pixels = "PIXELS"

	/// Automatically determined by the rendering engine; no explicit value is set.
	case auto = "AUTO"
}

/// The vertical spacing between lines of text in a ``TextStyle``.
///
/// When `unit` is ``SpacingUnit/auto``, the `value` field is omitted in the
/// Figma JSON export and will be `nil` after decoding.
struct LineHeight: Codable {

	/// The numeric line height value. `nil` when ``unit`` is ``SpacingUnit/auto``.
	let value: Double?

	/// The unit in which ``value`` is expressed, or `.auto` if not explicitly set.
	let unit: SpacingUnit
}

/// The casing transformation applied to a text style.
enum TextCase: String, Codable {

	/// Text is rendered exactly as authored, with no transformation.
	case original = "ORIGINAL"

	/// All characters are converted to uppercase.
	case upper = "UPPER"

	/// All characters are converted to lowercase.
	case lower = "LOWER"

	/// The first letter of each word is capitalised.
	case title = "TITLE"
}

// MARK: - Color

/// Represents a single color or gradient style exported from Figma.
///
/// A `ColorStyle` can describe a flat solid color, a color sourced from a
/// Figma variable (``boundVariable``), or a linear/radial gradient
/// (``gradientStops``, ``gradientTransform``). Fields that don't apply to a
/// given ``type`` will be `nil`.
struct ColorStyle: Codable {

	/// Unique Figma style identifier.
	let id: String

	/// Human-readable name assigned to the style in Figma.
	let name: String

	/// Optional designer-provided description of the style's intended use.
	let description: String

	/// Declares whether this style is a solid fill or a gradient variant.
	let type: ColorStyleType

	/// Whether the style is marked as visible in Figma.
	let visible: Bool

	/// The overall opacity of the style, from `0.0` (transparent) to `1.0` (opaque).
	let opacity: Double

	/// The Figma blend mode applied to the style, e.g. `"NORMAL"`.
	let blendMode: String

	/// The resolved RGBA color values for this style.
	/// `nil` for gradient styles, which use ``gradientStops`` instead.
	let color: [RGB]?

	/// The Figma variable this style is bound to, if any.
	/// Present when the color is driven by a design token rather than a raw value.
	let boundVariable: BoundVariable?

	/// The color stops that define a gradient.
	/// Only present when ``type`` is ``ColorStyleType/gradientLinear``
	/// or ``ColorStyleType/gradientRadial``.
	let gradientStops: [GradientStop]?

	/// A 2×3 affine transform matrix describing the gradient's orientation and position.
	/// Only present for gradient styles.
	let gradientTransform: [[Double]]?
}

/// The fill type of a ``ColorStyle``.
enum ColorStyleType: String, Codable {

	/// A flat, single-color fill.
	case solid = "SOLID"

	/// A linear gradient transitioning between two or more color stops.
	case gradientLinear = "GRADIENT_LINEAR"

	/// A radial gradient emanating from a central point.
	case gradientRadial = "GRADIENT_RADIAL"
}

/// A Figma design variable that a ``ColorStyle`` is bound to.
///
/// When a color style references a variable token rather than a hardcoded value,
/// Figma includes this object to describe the source variable and its resolved values.
struct BoundVariable: Codable {

	/// The unique identifier of the Figma variable, e.g. `"VariableID:128:3"`.
	let id: String

	/// Optional designer-provided description of the variable.
	let description: String

	/// The name of the variable as defined in the Figma variable collection.
	let name: String

	/// The variable type, e.g. `"RGBA"`.
	let type: String

	/// The resolved values of the variable across modes or themes.
	let value: [BoundVariableValue]
}

/// A single resolved value entry within a ``BoundVariable``.
///
/// Each entry corresponds to one mode (e.g. light or dark) in the Figma variable collection.
struct BoundVariableValue: Codable {

	/// The mode identifier for this value entry, e.g. `"57:0"`.
	let id: String

	/// The resolved RGBA color data for this mode.
	let data: RGB
}

/// A single color stop within a gradient style.
///
/// Gradient stops define the color and its position along the gradient axis,
/// from `0.0` (start) to `1.0` (end).
struct GradientStop: Codable {

	/// The position of this stop along the gradient axis, from `0.0` to `1.0`.
	let position: Double

	/// The RGBA color at this gradient stop.
	let color: RGB
}
