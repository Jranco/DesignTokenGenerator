//
//  DesignModelContainer.swift
//  DesignTokenGenerator
//
//  Created by Thomas Segkoulis on 03.03.26.
//

// MARK: - Design Model Container

/// The root-level container decoded from a full Figma export JSON payload.
///
/// `DesignModelContainer` serves as the top-level entry point for all design data
/// exported from Figma, encapsulating both variable collections and named styles.
///
/// ## Overview
/// A Figma export contains two primary data sources:
/// - **Variable collections** — design tokens such as colors, numbers, booleans, and strings,
///   organised into named collections with one or more modes (e.g. light/dark).
/// - **Styles** — named, reusable style definitions for typography and color/gradient fills.
///
/// ## Usage
/// ```swift
/// let decoder = JSONDecoder()
/// let container = try decoder.decode(DesignModelContainer.self, from: jsonData)
///
/// let collections = container.variableCollections
/// let styles = container.styles
/// ```
struct DesignModelContainer: Codable {

	/// All variable collections defined in the Figma file.
	///
	/// Each collection groups a set of typed design variables (color, number, boolean, string)
	/// and may define multiple modes — for example a light and a dark theme variant.
	var variableCollections: DesignVariableCollections

	/// All named styles defined in the Figma file, grouped by type.
	///
	/// Contains both typography (``StyleContainer/text``) and
	/// color/gradient (``StyleContainer/color``) style definitions.
	var styles: StyleContainer
}
