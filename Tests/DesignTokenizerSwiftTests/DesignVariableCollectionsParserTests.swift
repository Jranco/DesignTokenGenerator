//
//  DesignVariableCollectionsParserTests.swift
//  DesignTokenGenerator
//
//  Created by Thomas Segkoulis on 26.12.25.
//

import Testing
import Foundation
import Stencil

@testable import DesignTokenGenerator

struct DesignVariableCollectionsParserTests {

	@Test func test_shouldParseColors_withSuccess() async throws {
        /// GIVEN: The JSON containing all design variables.
		let jsonData = try loadJSON(named: "figmaVars")
		/// AND: The parser.
		let parser = DesignVariableCollectionsParser(json: jsonData)
		
		/// WHEN: Parsing design variables into local DTOs.
		let variableCollections = try parser.parseIntoVariableCollections()
    }

	@Test func test_shouldTransformParsedColorsIntoAssets() async throws {
		/// GIVEN: The JSON containing all design variables.
		let jsonData = try loadJSON(named: "figmaVars")
		/// AND: The parser.
		let parser = DesignVariableCollectionsParser(json: jsonData)
		
		/// WHEN: Parsing design variables into local DTOs.
		let variableCollections = try parser.parseIntoVariableCollections()
		
		/// AND:
		let assets = try parser.colorAssetFiles(from: variableCollections.variableCollections)

		let parser2 = DesignStylesParser(json: jsonData)
		let styles = try parser2.parseIntoStyles()
		let assets2 = parser2.colorAssetFiles(from: styles.color)

		
		let generator = AssetFileGenerator()
		try generator.generateAssets(colorAssetFiles: assets)
		try generator.generateAssets(name: "tmp2", colorAssetFiles: assets2)

	}

	@Test func test_generateVariables2() throws {

		/// GIVEN: The JSON containing all design variables.
		let jsonData = try loadJSON(named: "figmaVars")
		/// AND: The parser.
		let parser = DesignVariableCollectionsParser(json: jsonData)

		/// WHEN: Parsing design variables into local DTOs.
		let designModelContainer = try parser.parseIntoVariableCollections()
		let templateURL = Bundle.module.url(
			forResource: "DesignVariableTokens",
			withExtension: "stencil"
		)!
		let templateData = try Data(contentsOf: templateURL)
		let templateStr = String(data: templateData, encoding: .utf8)

		// Build array of enum contexts — one per collection
		let enums: [[String: Any]] = designModelContainer.variableCollections.compactMap { collection in
			let tokens = collection.variables.filter { variable in
				variable.type != .RGB && variable.type != .RGBA
			}
			guard !tokens.isEmpty else { return nil }

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
			try output.write(
				to: URL(fileURLWithPath: "Tokenssss.swift"),
				atomically: true,
				encoding: .utf8
			)
		} catch {
			print("-- error generating output: \(error)")
		}
	}

	@Test func test_generateVariables() throws {

		/// GIVEN: The JSON containing all design variables.
		let jsonData = try loadJSON(named: "figmaVars")
		/// AND: The parser.
		let parser = DesignVariableCollectionsParser(json: jsonData)
		
		/// WHEN: Parsing design variables into local DTOs.
		let designModelContainer = try parser.parseIntoVariableCollections()
		let templateURL = Bundle.module.url(
			forResource: "DesignVariableTokens",
			withExtension: "stencil"
		)!
		let templateData = try Data(contentsOf: templateURL)
		let templateStr = String(data: templateData, encoding: .utf8)

		let tokens = designModelContainer.variableCollections.reduce(into: [[String: Any]](), { partialResult, collection in
			let tokens = collection.variables.filter { variable in
				variable.type != .RGB && variable.type != .RGBA
			}
			guard !tokens.isEmpty else {
				return
			}

			let stencilTokens: [[String: Any]] = tokens.map { token in
				var dict: [String: Any] = [
					"name": token.name
				]

				if let v = token.boolValue {
					dict["boolValue"] = v
				}

				if let v = token.doubleValue {
					dict["numberValue"] = v
				}

				if let v = token.stringValue {
					dict["stringValue"] = v
				}

				return dict
			}
			let context: [String: Any] = [
				"tokens": stencilTokens,
				"name": collection.name
			]
			partialResult.append(contentsOf: stencilTokens)
		})
		let context: [String: Any] = ["enums": tokens]
		
		do {
			let template = Template(templateString: templateStr!, environment: Environment(trimBehaviour: .smart))
			let output = try template.render(context)
			print("\noutput: \(output)\n")
			try output.write(
				to: URL(fileURLWithPath: "Tokenssss.swift"),
				atomically: true,
				encoding: .utf8
			)
		} catch {
		}
		
//		try designModelContainer.variableCollections.forEach { collection in
//			let tokens = collection.variables.filter { variable in
//				variable.type != .RGB && variable.type != .RGBA
//			}
//			let template = Template(templateString: templateStr!, environment: Environment(trimBehaviour: .smart))
//			let stencilTokens: [[String: Any]] = tokens.map { token in
//				var dict: [String: Any] = [
//					"name": token.name
//				]
//
//				if let v = token.boolValue {
//					dict["boolValue"] = v
//				}
//
//				if let v = token.doubleValue {
//					dict["numberValue"] = v
//				}
//
//				if let v = token.stringValue {
//					dict["stringValue"] = v
//				}
//
//				return dict
//			}
//
//			let context: [String: Any] = [
//				"tokens": stencilTokens,
//				"enumName": collection.name
//			]
//			do {
//				let output = try template.render(context)
//				print("\noutput: \(output)\n")
//				try output.write(
//					to: URL(fileURLWithPath: "Tokens-\(collection.name).swift"),
//					atomically: true,
//					encoding: .utf8
//				)
//			} catch {
//				print("-- error generating output: \(error)")
//			}
//		}
	}

	// MARK: - Helper

	func loadJSON(named name: String) throws -> Data {
		guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
			throw NSError(domain: "TestError", code: 1)
		}
		return try Data(contentsOf: url)
	}
}
