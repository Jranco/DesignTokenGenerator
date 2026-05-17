//
//  ColorSchemeSource.swift
//  DesignTokenGenerator
//
//  Created by Thomas Segkoulis on 16.05.26.
//

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
