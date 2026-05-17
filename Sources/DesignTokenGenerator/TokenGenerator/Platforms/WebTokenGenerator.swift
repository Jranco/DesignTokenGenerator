//
//  WebTokenGenerator.swift
//  DesignTokenGenerator
//
//  Created by Thomas Segkoulis on 16.05.26.
//

import Foundation
import Stencil

struct WebTokenGenerator: PlatformTokenGenerating {
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

		/// Code generation
		// 1. Variables
		try generateVariablesTemplate(from: designModel.variableCollections)
		
		// 2. Fonts
		try generateFontTokensFile(from: textStyles)

		// 3. Color
		let allColorFiles = variableColorAssetFiles + colorStyleAssetFiles

		try generateColorTokensFile(from: allColorFiles, colorsBoundToVariables: styles.colorsBoundToVariables)
	}

	func generateVariablesTemplate(from designVariableCollections: DesignVariableCollections) throws {
		let templateURL = Bundle.module.url(
			forResource: "WebDesignVariableTokens",
			withExtension: "stencil"
		)!
		let templateData = try Data(contentsOf: templateURL)
		let templateStr = String(data: templateData, encoding: .utf8)

		let enums: [[String: Any]] = designVariableCollections.compactMap { collection in
			let tokens = collection.variables.filter { $0.type != .RGB && $0.type != .RGBA }
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

		let ext = Extension()
		ext.registerFilter("cssIdentifier", filter: cssIdentifierFilter)
		let environment = Environment(extensions: [ext], trimBehaviour: .smart)

		let context: [String: Any] = ["enums": enums]
		let output = try environment.renderTemplate(string: templateStr!, context: context)

		let outputURL = URL(fileURLWithPath: exportPath).appendingPathComponent("DesignVariables.css")
		try output.write(to: outputURL, atomically: true, encoding: .utf8)
		print("✅ Generated: \(outputURL.path)")
	}

	func generateFontTokensFile(from textStyles: [TextStyle]) throws {
		let templateURL = Bundle.module.url(
			forResource: "WebFontTokens",
			withExtension: "stencil"
		)!
		let templateString = try String(contentsOf: templateURL, encoding: .utf8)

		let ext = Extension()
		ext.registerFilter("cssIdentifier", filter: cssIdentifierFilter)

		let environment = Environment(extensions: [ext])

		let context: [String: Any] = [
			"textStyles": textStyles.map { style -> [String: Any] in
				let letterSpacingPt: Double = {
					switch style.letterSpacing.unit {
					case .percent: return (style.letterSpacing.value / 100.0) * style.fontSize
					case .pixels:  return style.letterSpacing.value
					case .auto:    return 0
					}
				}()

				let lineHeightPt: Double? = {
					switch style.lineHeight.unit {
					case .percent: return ((style.lineHeight.value ?? 0) / 100.0) * style.fontSize
					case .pixels:  return style.lineHeight.value
					case .auto:    return nil
					}
				}()

				var dict: [String: Any] = [
					"name":             style.name,
					"fontFamily":       style.fontName.family,
					"fontStyle":        style.fontName.style,
					"fontSize":         style.fontSize,
					"letterSpacing":    letterSpacingPt,
					"paragraphSpacing": style.paragraphSpacing
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
		let outputURL = URL(fileURLWithPath: exportPath).appendingPathComponent("FontTokens.css")
		try rendered.write(to: outputURL, atomically: true, encoding: .utf8)
		print("✅ Generated: \(outputURL.path)")
	}

	func generateColorTokensFile(from colorAssetFiles: [ColorAssetFile], colorsBoundToVariables: [ColorAssetWrapper]) throws {
		let templateURL = Bundle.module.url(
			forResource: "WebColorTokens",
			withExtension: "stencil"
		)!
		let templateString = try String(contentsOf: templateURL, encoding: .utf8)

		let ext = Extension()
		ext.registerFilter("cssIdentifier", filter: cssIdentifierFilter)

		let environment = Environment(extensions: [ext])

		let context: [String: Any] = [
			"colorAssetFiles": colorAssetFiles.map { file in
				[
					"name": file.name,
					"colors": file.colors.map { wrapper -> [String: Any] in
						let light = wrapper.colorAsset.colors.first {
							$0.appearances?.contains { $0.value == .light } == true
						}
						let dark = wrapper.colorAsset.colors.first {
							$0.appearances?.contains { $0.value == .dark } == true
						}
						let lightValue = light.map { cssColor(from: $0.color.components) } ?? ""
						let darkValue = dark.map { cssColor(from: $0.color.components) } ?? ""
						return [
							"name": wrapper.name,
							"light": lightValue,
							"dark": darkValue,
							"hasDarkOverride": !darkValue.isEmpty && darkValue != lightValue
						]
					},
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
		let outputURL = URL(fileURLWithPath: exportPath).appendingPathComponent("ColorTokens.css")
		try rendered.write(to: outputURL, atomically: true, encoding: .utf8)
		print("✅ Generated: \(outputURL.path)")
	}
}

private extension WebTokenGenerator {

	func cssIdentifier(from string: String) -> String {
			string
				.lowercased()
				.components(separatedBy: CharacterSet.alphanumerics.inverted)
				.filter { !$0.isEmpty }
				.joined(separator: "-")
		}

	var cssIdentifierFilter: (Any?) -> Any? {
		{ value in
			guard let string = value as? String else { return value }
			return string
				.lowercased()
				.components(separatedBy: CharacterSet.alphanumerics.inverted)
				.filter { !$0.isEmpty }
				.joined(separator: "-")
		}
	}

	func cssColor(from c: ColorComponents) -> String {
		func toInt(_ s: String) -> Int {
			let v = Double(s) ?? 0
			return v > 1.0 ? Int(v.rounded()) : Int((v * 255).rounded())
		}
		let r = toInt(c.red), g = toInt(c.green), b = toInt(c.blue)
		let a = Double(c.alpha) ?? 1
		return a < 1 ? "rgba(\(r), \(g), \(b), \(a))" : "rgb(\(r), \(g), \(b))"
	}
}
