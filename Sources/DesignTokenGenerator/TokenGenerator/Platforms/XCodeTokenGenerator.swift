//
//  XCodeTokenGenerator.swift
//  DesignTokenGenerator
//
//  Created by Thomas Segkoulis on 16.05.26.
//

import Foundation
import Stencil

struct XCodeTokenGenerator: PlatformTokenGenerating {
	let exportPath: String
	let designModel: DesignModelContainer
	
	func generateTokenFiles() throws {
		// Variable colors
		let variableColorAssetFiles = try getColorAssetFiles(variableCollections: designModel.variableCollections)

		// Style
		let styles = try getTextAndColorStyles(styles: designModel.styles)
		
		// Color style
		let colorStyleAssetFiles = styles.colorAssetFiles
		
		// Text style
		let textStyles = styles.text

		// Gradient colors
		let gradientColorAssetFiles = try getGradientColorAssetFiles(styles: designModel.styles)

		/// Code generation
		try generateAssets(name: "VariableColors", colorAssetFiles: variableColorAssetFiles)
		try generateAssets(name: "StyleColors", colorAssetFiles: colorStyleAssetFiles)
		try generateAssets(name: "GradientColors", colorAssetFiles: gradientColorAssetFiles)

		// 1. Variables
		try generateVariablesTemplate(from: designModel.variableCollections)

		// 2. Fonts
		try generateFontTokensFile(from: textStyles)

		// 3. Color
		let allColorFiles = variableColorAssetFiles + colorStyleAssetFiles + gradientColorAssetFiles

		try generateColorTokensFile(from: allColorFiles, colorsBoundToVariables: styles.colorsBoundToVariables)

		// 4. Gradient color tokens
		try generateGradientColorTokensFile(styles: designModel.styles)
	}
	
	private func generateAssets(name: String, colorAssetFiles: [ColorAssetFile]) throws {
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

		let environment = Environment(extensions: [ext], trimBehaviour: .smart)

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

	func generateGradientColorTokensFile(styles: StyleContainer) throws {
		let parser = DesignStylesParser(styles: styles)
		let colorStyles = try parser.colorStyles()
		let gradientStyles = parser.gradientColorStyles(from: colorStyles)
		guard !gradientStyles.isEmpty else { return }

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

		let environment = Environment(extensions: [ext], trimBehaviour: .smart)

		let context: [String: Any] = [
			"gradients": gradientStyles.map { style -> [String: Any] in
				let stops: [[String: Any]] = (style.gradientStops ?? []).map { stop in
					let pct = Int((stop.position * 100).rounded())
					return ["assetName": "\(style.name)-\(pct)", "position": stop.position]
				}
				return ["name": style.name, "stops": stops]
			}
		]

		let templates: [(resource: String, output: String)] = [
			("XCodeGradientColorTokens+UIKit", "GradientColorTokens+UIKit.swift"),
			("XCodeGradientColorTokens+SwiftUI", "GradientColorTokens+SwiftUI.swift"),
		]

		for (resource, output) in templates {
			let templateURL = Bundle.module.url(forResource: resource, withExtension: "stencil")!
			let templateString = try String(contentsOf: templateURL, encoding: .utf8)
			let rendered = try environment.renderTemplate(string: templateString, context: context)
			let outputURL = URL(fileURLWithPath: exportPath).appendingPathComponent(output)
			try rendered.write(to: outputURL, atomically: true, encoding: .utf8)
			print("✅ Generated: \(outputURL.path)")
		}
	}

	func generateColorTokensFile(from colorAssetFiles: [ColorAssetFile], colorsBoundToVariables: [ColorAssetWrapper]) throws {
		// TODO: Add guard, throw error
		let templateURL = Bundle.module.url(
			forResource: "XCodeColorTokens",
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
}
