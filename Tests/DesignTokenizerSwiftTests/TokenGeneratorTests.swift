//
//  TokenGeneratorTests.swift
//  DesignTokenGenerator
//
//  Created by Thomas Segkoulis on 03.05.26.
//

import Testing
@testable import DesignTokenGenerator
import Foundation

struct TokenGeneratorTests {

//    @Test func test() async throws {
//		let generator = DesignTokenGenerator()
//		let parse = generator
//
//		do {
//			let tokenGenerator = try TokenGenerator(json: loadJSON(named: "designModelContainer"), exportPath: "/Users/segk/Documents/token_result2", colorSchemeSource: .modes)
//			try tokenGenerator.generateTokenFiles()
//		} catch {
//			print("-- error parsing: \(error)")
//		}
//    }

	// MARK: - Transform: Collections source

	@Test("Should create DesignModelContainer with merged light and dark collections having more light colors than dark")
	func testShouldCreateModelWithMergedLightAndDarkCollectionsAsModes() throws {
		/// GIVEN: The raw JSON from the design system.
		let json = case1JSON
		
		/// AND: The token generator having `.collections` as color scheme source.
		let tokenGenerator = try TokenGenerator(json: json, exportPath: "", colorSchemeSource: .collections)

		/// WHEN: Parsing and decoding.
		let model = try tokenGenerator.parseDesignModelContainer()
		
		/// THEN: Should have one collection and three variables in total.
		#expect(model.variableCollections.count == 1)
		#expect(model.variableCollections.first?.variables.count == 3)
		
		/// AND: Collection should have the expected default data (other than values).
		#expect(model.variableCollections.first?.name == "light-dark-combined")
		#expect(model.variableCollections.first?.id == "VariableCollectionId:1:1")
		#expect(model.variableCollections.first?.modes == [DesignVariableMode(id: "1:0", name: "light"), DesignVariableMode(id: "1:1", name: "dark")])

		/// AND: The first and the last variables should have both light and dark modes.
		assertVariableRGB(variable: model.variableCollections.first?.variables.first,
						  expectedId: "VariableID:1:1",
						  expectedName: "bgDefault",
						  expectedTypeRawValue: "RGB",
						  expectedValueCount: 2,
						  expectedFirstModelId: "1:0",
						  expectedSecondModelId: "1:1",
						  expectedFirstRGB: (1, 1, 1, 1),
						  expectedSecondRGB: (0.1, 0.1, 0.1, 1))

		assertVariableRGB(variable: model.variableCollections.first?.variables.last,
						  expectedId: "VariableID:1:3",
						  expectedName: "fgDefault",
						  expectedTypeRawValue: "RGB",
						  expectedValueCount: 2,
						  expectedFirstModelId: "1:0",
						  expectedSecondModelId: "1:1",
						  expectedFirstRGB: (0, 0, 0, 1),
						  expectedSecondRGB: (1, 1, 1, 1))

		/// AND: The second variable should only have light color value as it existed only in the`light` collection.
		assertVariableRGB(variable: model.variableCollections.first?.variables[1],
						  expectedId: "VariableID:1:2",
						  expectedName: "bgMuted",
						  expectedTypeRawValue: "RGB",
						  expectedValueCount: 1,
						  expectedFirstModelId: "1:0",
						  expectedSecondModelId: nil,
						  expectedFirstRGB: (0.96, 0.96, 0.96, 1.0),
						  expectedSecondRGB: nil)
	}

    @Test("Should transform the raw token JSON, merging light and dark collections — Light has more variables than Dark, dark collection is dropped")
	func lightHasMoreVariablesThanDark_collections() throws {
		/// GIVEN: A raw JSON with design tokens that has a light and a dark collection, where light has more variables.
		let json = case1JSON
		
		/// WHEN: Transforming the design token JSON payload into a normalised structure where light and dark color scheme values are combined into a single variable collection.
		let outputData = try TokenGenerator.transformDesignTokens(json)

		/// THEN: Should have the expected output.
		let output = try JSONSerialization.jsonObject(with: outputData) as! [String: Any]
		let collections = output["variableCollections"] as! [[String: Any]]

		// Dark is fully mapped — only the merged collection remains
		#expect(collections.count == 1)

		let merged = collections[0]

		// Both modes present in the merged collection
		let modes = merged["modes"] as! [[String: Any]]
		#expect(modes.count == 2)
		#expect(modes[0]["name"] as? String == "light")
		#expect(modes[1]["name"] as? String == "dark")

		let variables = merged["variables"] as! [[String: Any]]
		#expect(variables.count == 3)

		// bgDefault: exists in both → 2 values, light first, dark second
		let bgDefault = try #require(variables.first { $0["name"] as? String == "bgDefault" })
		let bgDefaultValues = bgDefault["value"] as! [[String: Any]]
		#expect(bgDefaultValues.count == 2)
		#expect(bgDefaultValues[0]["id"] as? String == "1:0")
		#expect(bgDefaultValues[1]["id"] as? String == "1:1")

		// bgMuted: only in light → 1 value
		let bgMuted = try #require(variables.first { $0["name"] as? String == "bgMuted" })
		let bgMutedValues = bgMuted["value"] as! [[String: Any]]
		#expect(bgMutedValues.count == 1)
		#expect(bgMutedValues[0]["id"] as? String == "1:0")

		// fgDefault: exists in both → 2 values, light first, dark second
		let fgDefault = try #require(variables.first { $0["name"] as? String == "fgDefault" })
		let fgDefaultValues = fgDefault["value"] as! [[String: Any]]
		#expect(fgDefaultValues.count == 2)
		#expect(fgDefaultValues[0]["id"] as? String == "1:0")
		#expect(fgDefaultValues[1]["id"] as? String == "1:1")
	}

	@Test("Should create DesignModelContainer with merged light and dark collections having more dark colors that light ones")
	func testShouldCreateModelWithMergedLightAndDarkCollectionsAsModes_havingMoreDarkVars() throws {
		/// GIVEN: The raw JSON from the design system.
		let json = case2JSON
		
		/// AND: The token generator having `.collections` as color scheme source.
		let tokenGenerator = try TokenGenerator(json: json, exportPath: "", colorSchemeSource: .collections)

		/// WHEN: Parsing and decoding.
		let model = try tokenGenerator.parseDesignModelContainer()
		
		/// THEN: Should have one collection and three variables in total.
		#expect(model.variableCollections.count == 1)
		#expect(model.variableCollections.first?.variables.count == 3)
		
		/// AND: Collection should have the expected default data (other than values).
		#expect(model.variableCollections.first?.name == "light-dark-combined")
		#expect(model.variableCollections.first?.id == "VariableCollectionId:2:1")
		#expect(model.variableCollections.first?.modes == [DesignVariableMode(id: "2:0", name: "light"), DesignVariableMode(id: "2:1", name: "dark")])

		/// AND: All variables should have both light and dark modes with the last dark one having clear as default light mode.
		assertVariableRGB(variable: model.variableCollections.first?.variables.first,
						  expectedId: "VariableID:2:1",
						  expectedName: "bgDefault",
						  expectedTypeRawValue: "RGB",
						  expectedValueCount: 2,
						  expectedFirstModelId: "2:0",
						  expectedSecondModelId: "2:1",
						  expectedFirstRGB: (1, 1, 1, 1),
						  expectedSecondRGB: (0.1, 0.1, 0.1, 1))

		assertVariableRGB(variable: model.variableCollections.first?.variables[1],
						  expectedId: "VariableID:2:2",
						  expectedName: "fgDefault",
						  expectedTypeRawValue: "RGB",
						  expectedValueCount: 2,
						  expectedFirstModelId: "2:0",
						  expectedSecondModelId: "2:1",
						  expectedFirstRGB: (0, 0, 0, 1),
						  expectedSecondRGB: (1, 1, 1, 1))

		assertVariableRGB(variable: model.variableCollections.first?.variables.last,
						  expectedId: "VariableID:2:5",
						  expectedName: "accentDefault",
						  expectedTypeRawValue: "RGB",
						  expectedValueCount: 2,
						  expectedFirstModelId: "2:0",
						  expectedSecondModelId: "2:1",
						  expectedFirstRGB: (0, 0, 0, 0),
						  expectedSecondRGB: (0.35, 0.4, 0.85, 1.0))
	}

	@Test("Case 2 — Should transform the raw token JSON, merging light and dark collections — Dark has more variables than light, dark collection is dropped")
	func darkHasMoreVariablesThanLight_collections() throws {
		let outputData = try TokenGenerator.transformDesignTokens(case2JSON)
		let output = try JSONSerialization.jsonObject(with: outputData) as! [String: Any]
		let collections = output["variableCollections"] as! [[String: Any]]

		// Merged collection + remaining dark collection with unmapped accentDefault
		#expect(collections.count == 1)

		let merged = collections[0]

		// Both modes present in the merged collection
		let modes = merged["modes"] as! [[String: Any]]
		#expect(modes.count == 2)
		#expect(modes[0]["name"] as? String == "light")
		#expect(modes[1]["name"] as? String == "dark")

		let variables = merged["variables"] as! [[String: Any]]
		#expect(variables.count == 3)

		// bgDefault: exists in both → 2 values, light first, dark second
		let bgDefault = try #require(variables.first { $0["name"] as? String == "bgDefault" })
		let bgDefaultValues = bgDefault["value"] as! [[String: Any]]
		#expect(bgDefaultValues.count == 2)
		#expect(bgDefaultValues[0]["id"] as? String == "2:0")
		#expect(bgDefaultValues[1]["id"] as? String == "2:1")

		// fgDefault: exists in both → 2 values, light first, dark second
		let fgDefault = try #require(variables.first { $0["name"] as? String == "fgDefault" })
		let fgDefaultValues = fgDefault["value"] as! [[String: Any]]
		#expect(fgDefaultValues.count == 2)
		#expect(fgDefaultValues[0]["id"] as? String == "2:0")
		#expect(fgDefaultValues[1]["id"] as? String == "2:1")

		// accentDefault: exists in dark only, set default clear color value for light mode
		let accentDefault = try #require(variables.first { $0["name"] as? String == "accentDefault" })
		let accentDefaultValues = accentDefault["value"] as! [[String: Any]]
		#expect(accentDefaultValues.count == 2)
		#expect(accentDefaultValues[0]["id"] as? String == "2:0")
		#expect(accentDefaultValues[1]["id"] as? String == "2:1")
	}

	@Test("Should create DesignModelContainer with merged light and dark collections when light colors have multiple values already")
	func testShouldCreateModelWithMergedLightAndDarkCollections_havingMultipleLightValues() throws {
		/// GIVEN: The raw JSON from the design system.
		let json = case3JSON
		
		/// AND: The token generator having `.collections` as color scheme source.
		let tokenGenerator = try TokenGenerator(json: json, exportPath: "", colorSchemeSource: .collections)

		/// WHEN: Parsing and decoding.
		let model = try tokenGenerator.parseDesignModelContainer()
		
		/// THEN: Should have one collection and two variables in total.
		#expect(model.variableCollections.count == 1)
		#expect(model.variableCollections.first?.variables.count == 2)
		
		/// AND: Collection should have the expected default data (other than values).
		#expect(model.variableCollections.first?.name == "light-dark-combined")
		#expect(model.variableCollections.first?.id == "VariableCollectionId:3:1")
		#expect(model.variableCollections.first?.modes == [DesignVariableMode(id: "3:0", name: "light"), DesignVariableMode(id: "3:2", name: "dark"), DesignVariableMode(id: "3:1", name: "light-contrast")])

		/// AND: All variables should have both light and dark modes.
		assertVariableRGB(variable: model.variableCollections.first?.variables.first,
						  expectedId: "VariableID:3:1",
						  expectedName: "bgDefault",
						  expectedTypeRawValue: "RGB",
						  expectedValueCount: 3,
						  expectedFirstModelId: "3:0",
						  expectedSecondModelId: "3:2",
						  expectedFirstRGB: (1, 1, 1, 1),
						  expectedSecondRGB: (0.1, 0.1, 0.1, 1))

		assertVariableRGB(variable: model.variableCollections.first?.variables[1],
						  expectedId: "VariableID:3:2",
						  expectedName: "fgDefault",
						  expectedTypeRawValue: "RGB",
						  expectedValueCount: 3,
						  expectedFirstModelId: "3:0",
						  expectedSecondModelId: "3:2",
						  expectedFirstRGB: (0, 0, 0, 1),
						  expectedSecondRGB: (1, 1, 1, 1))
	}

	@Test("Case 3 — Light has 2 modes, dark value inserted at index 1")
	func lightHasTwoModes_darkInsertedAtIndexOne() throws {
		let outputData = try TokenGenerator.transformDesignTokens(case3JSON)
		let output = try JSONSerialization.jsonObject(with: outputData) as! [String: Any]
		let collections = output["variableCollections"] as! [[String: Any]]

		#expect(collections.count == 1)

		let merged = collections[0]

		// All 3 modes present: light, dark, light-contrast
		let modes = merged["modes"] as! [[String: Any]]
		#expect(modes.count == 3)
		#expect(modes[0]["name"] as? String == "light")
		#expect(modes[1]["name"] as? String == "dark")
		#expect(modes[2]["name"] as? String == "light-contrast")

		let variables = merged["variables"] as! [[String: Any]]
		#expect(variables.count == 2)

		// bgDefault: [light, dark, light-contrast]
		let bgDefault = try #require(variables.first { $0["name"] as? String == "bgDefault" })
		let bgDefaultValues = bgDefault["value"] as! [[String: Any]]
		#expect(bgDefaultValues.count == 3)
		#expect(bgDefaultValues[0]["id"] as? String == "3:0") // light
		#expect(bgDefaultValues[1]["id"] as? String == "3:2") // dark at index 1
		#expect(bgDefaultValues[2]["id"] as? String == "3:1") // light-contrast pushed to index 2

		// fgDefault: [light, dark, light-contrast]
		let fgDefault = try #require(variables.first { $0["name"] as? String == "fgDefault" })
		let fgDefaultValues = fgDefault["value"] as! [[String: Any]]
		#expect(fgDefaultValues.count == 3)
		#expect(fgDefaultValues[0]["id"] as? String == "3:0")
		#expect(fgDefaultValues[1]["id"] as? String == "3:2")
		#expect(fgDefaultValues[2]["id"] as? String == "3:1")
	}

	@Test("Should create DesignModelContainer with merged light and dark collections when dark colors have multiple values already")
	func testShouldCreateModelWithMergedLightAndDarkCollections_havingMultipleDarkValues() throws {
		/// GIVEN: The raw JSON from the design system.
		let json = case4JSON
		
		/// AND: The token generator having `.collections` as color scheme source.
		let tokenGenerator = try TokenGenerator(json: json, exportPath: "", colorSchemeSource: .collections)

		/// WHEN: Parsing and decoding.
		let model = try tokenGenerator.parseDesignModelContainer()
		
		/// THEN: Should have one collection and two variables in total.
		#expect(model.variableCollections.count == 1)
		#expect(model.variableCollections.first?.variables.count == 2)
		
		/// AND: Collection should have the expected default data (other than values).
		#expect(model.variableCollections.first?.name == "light-dark-combined")
		#expect(model.variableCollections.first?.id == "VariableCollectionId:4:1")
		#expect(model.variableCollections.first?.modes == [DesignVariableMode(id: "4:0", name: "light"), DesignVariableMode(id: "4:1", name: "dark"), DesignVariableMode(id: "4:2", name: "dark-contrast")])

		/// AND: All variables should have both light and dark modes.
		assertVariableRGB(variable: model.variableCollections.first?.variables.first,
						  expectedId: "VariableID:4:1",
						  expectedName: "bgDefault",
						  expectedTypeRawValue: "RGB",
						  expectedValueCount: 3,
						  expectedFirstModelId: "4:0",
						  expectedSecondModelId: "4:1",
						  expectedFirstRGB: (1, 1, 1, 1),
						  expectedSecondRGB: (0.1, 0.1, 0.1, 1))

		assertVariableRGB(variable: model.variableCollections.first?.variables[1],
						  expectedId: "VariableID:4:2",
						  expectedName: "fgDefault",
						  expectedTypeRawValue: "RGB",
						  expectedValueCount: 3,
						  expectedFirstModelId: "4:0",
						  expectedSecondModelId: "4:1",
						  expectedFirstRGB: (0, 0, 0, 1),
						  expectedSecondRGB: (1, 1, 1, 1))
	}

	@Test("Case 4 — Dark has 2 modes, both inserted at index 1 preserving order")
	func darkHasTwoModes_bothInsertedAtIndexOne() throws {
		let outputData = try TokenGenerator.transformDesignTokens(case4JSON)
		let output = try JSONSerialization.jsonObject(with: outputData) as! [String: Any]
		let collections = output["variableCollections"] as! [[String: Any]]

		#expect(collections.count == 1)

		let merged = collections[0]

		// All 3 modes present: light, dark, dark-contrast
		let modes = merged["modes"] as! [[String: Any]]
		#expect(modes.count == 3)
		#expect(modes[0]["name"] as? String == "light")
		#expect(modes[1]["name"] as? String == "dark")
		#expect(modes[2]["name"] as? String == "dark-contrast")

		let variables = merged["variables"] as! [[String: Any]]
		#expect(variables.count == 2)

		// bgDefault: [light, dark, dark-contrast]
		let bgDefault = try #require(variables.first { $0["name"] as? String == "bgDefault" })
		let bgDefaultValues = bgDefault["value"] as! [[String: Any]]
		#expect(bgDefaultValues.count == 3)
		#expect(bgDefaultValues[0]["id"] as? String == "4:0") // light
		#expect(bgDefaultValues[1]["id"] as? String == "4:1") // dark at index 1
		#expect(bgDefaultValues[2]["id"] as? String == "4:2") // dark-contrast at index 2

		// fgDefault: [light, dark, dark-contrast]
		let fgDefault = try #require(variables.first { $0["name"] as? String == "fgDefault" })
		let fgDefaultValues = fgDefault["value"] as! [[String: Any]]
		#expect(fgDefaultValues.count == 3)
		#expect(fgDefaultValues[0]["id"] as? String == "4:0")
		#expect(fgDefaultValues[1]["id"] as? String == "4:1")
		#expect(fgDefaultValues[2]["id"] as? String == "4:2")
	}

	// MARK: - Convenient assertions

	func assertVariableRGB(
		variable: DesignVariable?,
		expectedId: String,
		expectedName: String,
		expectedTypeRawValue: String,
		expectedValueCount: Int,
		expectedFirstModelId: String,
		expectedSecondModelId: String?,
		expectedFirstRGB: (r: Double, g: Double, b: Double, a: Double),
		expectedSecondRGB: (r: Double, g: Double, b: Double, a: Double)?,
		sourceLocation: SourceLocation = #_sourceLocation
	) {
		if let variable = variable {
			#expect(variable.id == expectedId, sourceLocation: sourceLocation)
			#expect(variable.name == expectedName, sourceLocation: sourceLocation)
			#expect(variable.type.rawValue == expectedTypeRawValue, sourceLocation: sourceLocation)
			#expect(variable.value.count == expectedValueCount, sourceLocation: sourceLocation)
			#expect(variable.value.first?.modelId == expectedFirstModelId, sourceLocation: sourceLocation)
			if let expectedSecondModelId = expectedSecondModelId {
				#expect(variable.value[1].modelId == expectedSecondModelId, sourceLocation: sourceLocation)
			}
			if
				let payload = variable.value.first?.payload,
				case let DesignVariablePayload.rgb(rGB) = payload
			{
				#expect(rGB.r == expectedFirstRGB.r, sourceLocation: sourceLocation)
				#expect(rGB.g == expectedFirstRGB.g, sourceLocation: sourceLocation)
				#expect(rGB.b == expectedFirstRGB.b, sourceLocation: sourceLocation)
				#expect(rGB.a == expectedFirstRGB.a, sourceLocation: sourceLocation)
			} else {
				Issue.record("Unexpected payload for variable \(variable.id)", sourceLocation: sourceLocation)
			}
			if
				variable.value.count > 1,
				let expectedSecondRGB = expectedSecondRGB
			{
				if case let DesignVariablePayload.rgb(rGB) = variable.value[1].payload {
					#expect(rGB.r == expectedSecondRGB.r, sourceLocation: sourceLocation)
					#expect(rGB.g == expectedSecondRGB.g, sourceLocation: sourceLocation)
					#expect(rGB.b == expectedSecondRGB.b, sourceLocation: sourceLocation)
					#expect(rGB.a == expectedSecondRGB.a, sourceLocation: sourceLocation)
				} else {
					Issue.record("Unexpected payload for variable \(variable.id)", sourceLocation: sourceLocation)
				}
			}
		} else {
			Issue.record("Missing variable", sourceLocation: sourceLocation)
		}
	}

	// MARK: - Helper

	func loadJSON(named name: String) throws -> Data {
		guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
			throw NSError(domain: "TestError", code: 1)
		}
		return try Data(contentsOf: url)
	}
}

// MARK: - Fixtures

private extension TokenGeneratorTests {

	var case1JSON: Data {
		"""
		{
		  "newVersion": "0.0.1",
		  "designModelContainer": {
			"variableCollections": [
			  {
				"id": "VariableCollectionId:1:1",
				"name": "light",
				"modes": [{ "id": "1:0", "name": "light" }],
				"variables": [
				  {
					"id": "VariableID:1:1",
					"name": "bgDefault",
					"description": "",
					"type": "RGB",
					"value": [{ "id": "1:0", "data": { "r": 1, "g": 1, "b": 1, "a": 1 } }]
				  },
				  {
					"id": "VariableID:1:2",
					"name": "bgMuted",
					"description": "",
					"type": "RGB",
					"value": [{ "id": "1:0", "data": { "r": 0.96, "g": 0.96, "b": 0.96, "a": 1 } }]
				  },
				  {
					"id": "VariableID:1:3",
					"name": "fgDefault",
					"description": "",
					"type": "RGB",
					"value": [{ "id": "1:0", "data": { "r": 0, "g": 0, "b": 0, "a": 1 } }]
				  }
				]
			  },
			  {
				"id": "VariableCollectionId:1:2",
				"name": "dark",
				"modes": [{ "id": "1:1", "name": "dark" }],
				"variables": [
				  {
					"id": "VariableID:1:4",
					"name": "bgDefault",
					"description": "",
					"type": "RGB",
					"value": [{ "id": "1:1", "data": { "r": 0.1, "g": 0.1, "b": 0.1, "a": 1 } }]
				  },
				  {
					"id": "VariableID:1:5",
					"name": "fgDefault",
					"description": "",
					"type": "RGB",
					"value": [{ "id": "1:1", "data": { "r": 1, "g": 1, "b": 1, "a": 1 } }]
				  }
				]
			  }
			],
			"styles": { "text": [], "color": [], "effect": [], "grid": [] }
		  }
		}
		""".data(using: .utf8)!
	}

	var case2JSON: Data {
		"""
		{
		  "newVersion": "0.0.1",
		  "designModelContainer": {
			"variableCollections": [
			  {
				"id": "VariableCollectionId:2:1",
				"name": "light",
				"modes": [{ "id": "2:0", "name": "light" }],
				"variables": [
				  {
					"id": "VariableID:2:1",
					"name": "bgDefault",
					"description": "",
					"type": "RGB",
					"value": [{ "id": "2:0", "data": { "r": 1, "g": 1, "b": 1, "a": 1 } }]
				  },
				  {
					"id": "VariableID:2:2",
					"name": "fgDefault",
					"description": "",
					"type": "RGB",
					"value": [{ "id": "2:0", "data": { "r": 0, "g": 0, "b": 0, "a": 1 } }]
				  }
				]
			  },
			  {
				"id": "VariableCollectionId:2:2",
				"name": "dark",
				"modes": [{ "id": "2:1", "name": "dark" }],
				"variables": [
				  {
					"id": "VariableID:2:3",
					"name": "bgDefault",
					"description": "",
					"type": "RGB",
					"value": [{ "id": "2:1", "data": { "r": 0.1, "g": 0.1, "b": 0.1, "a": 1 } }]
				  },
				  {
					"id": "VariableID:2:4",
					"name": "fgDefault",
					"description": "",
					"type": "RGB",
					"value": [{ "id": "2:1", "data": { "r": 1, "g": 1, "b": 1, "a": 1 } }]
				  },
				  {
					"id": "VariableID:2:5",
					"name": "accentDefault",
					"description": "",
					"type": "RGB",
					"value": [{ "id": "2:1", "data": { "r": 0.35, "g": 0.4, "b": 0.85, "a": 1 } }]
				  }
				]
			  }
			],
			"styles": { "text": [], "color": [], "effect": [], "grid": [] }
		  }
		}
		""".data(using: .utf8)!
	}

	var case3JSON: Data {
		"""
		{
		  "newVersion": "0.0.1",
		  "designModelContainer": {
			"variableCollections": [
			  {
				"id": "VariableCollectionId:3:1",
				"name": "light",
				"modes": [
				  { "id": "3:0", "name": "light" },
				  { "id": "3:1", "name": "light-contrast" }
				],
				"variables": [
				  {
					"id": "VariableID:3:1",
					"name": "bgDefault",
					"description": "",
					"type": "RGB",
					"value": [
					  { "id": "3:0", "data": { "r": 1, "g": 1, "b": 1, "a": 1 } },
					  { "id": "3:1", "data": { "r": 0.9, "g": 0.9, "b": 0.9, "a": 1 } }
					]
				  },
				  {
					"id": "VariableID:3:2",
					"name": "fgDefault",
					"description": "",
					"type": "RGB",
					"value": [
					  { "id": "3:0", "data": { "r": 0, "g": 0, "b": 0, "a": 1 } },
					  { "id": "3:1", "data": { "r": 0.05, "g": 0.05, "b": 0.05, "a": 1 } }
					]
				  }
				]
			  },
			  {
				"id": "VariableCollectionId:3:2",
				"name": "dark",
				"modes": [
				  { "id": "3:2", "name": "dark" }
				],
				"variables": [
				  {
					"id": "VariableID:3:3",
					"name": "bgDefault",
					"description": "",
					"type": "RGB",
					"value": [
					  { "id": "3:2", "data": { "r": 0.1, "g": 0.1, "b": 0.1, "a": 1 } }
					]
				  },
				  {
					"id": "VariableID:3:4",
					"name": "fgDefault",
					"description": "",
					"type": "RGB",
					"value": [
					  { "id": "3:2", "data": { "r": 1, "g": 1, "b": 1, "a": 1 } }
					]
				  }
				]
			  }
			],
			"styles": { "text": [], "color": [], "effect": [], "grid": [] }
		  }
		}
		""".data(using: .utf8)!
	}

	var case4JSON: Data {
		"""
		{
		  "newVersion": "0.0.1",
		  "designModelContainer": {
			"variableCollections": [
			  {
				"id": "VariableCollectionId:4:1",
				"name": "light",
				"modes": [
				  { "id": "4:0", "name": "light" }
				],
				"variables": [
				  {
					"id": "VariableID:4:1",
					"name": "bgDefault",
					"description": "",
					"type": "RGB",
					"value": [
					  { "id": "4:0", "data": { "r": 1, "g": 1, "b": 1, "a": 1 } }
					]
				  },
				  {
					"id": "VariableID:4:2",
					"name": "fgDefault",
					"description": "",
					"type": "RGB",
					"value": [
					  { "id": "4:0", "data": { "r": 0, "g": 0, "b": 0, "a": 1 } }
					]
				  }
				]
			  },
			  {
				"id": "VariableCollectionId:4:2",
				"name": "dark",
				"modes": [
				  { "id": "4:1", "name": "dark" },
				  { "id": "4:2", "name": "dark-contrast" }
				],
				"variables": [
				  {
					"id": "VariableID:4:3",
					"name": "bgDefault",
					"description": "",
					"type": "RGB",
					"value": [
					  { "id": "4:1", "data": { "r": 0.1, "g": 0.1, "b": 0.1, "a": 1 } },
					  { "id": "4:2", "data": { "r": 0.05, "g": 0.05, "b": 0.05, "a": 1 } }
					]
				  },
				  {
					"id": "VariableID:4:4",
					"name": "fgDefault",
					"description": "",
					"type": "RGB",
					"value": [
					  { "id": "4:1", "data": { "r": 1, "g": 1, "b": 1, "a": 1 } },
					  { "id": "4:2", "data": { "r": 0.95, "g": 0.95, "b": 0.95, "a": 1 } }
					]
				  }
				]
			  }
			],
			"styles": { "text": [], "color": [], "effect": [], "grid": [] }
		  }
		}
		""".data(using: .utf8)!
	}
}
