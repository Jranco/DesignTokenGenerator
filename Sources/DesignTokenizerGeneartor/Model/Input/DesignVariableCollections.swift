//
//  DesignVariableCollections.swift
//  DesignTokenGenerator
//
//  Created by Thomas Segkoulis on 22.12.25.
//

import Foundation

// MARK: - Root

/// A collection of all design variable collections parsed from a Figma export.
typealias DesignVariableCollections = [DesignVariableCollection]

// MARK: - Collection

/// Represents a single Figma variable collection, grouping related design variables
/// under a shared name and set of modes (e.g. Light / Dark).
struct DesignVariableCollection: Codable {
	let id: String
	let name: String
	/// The modes defined for this collection (e.g. Light, Dark).
	let modes: [DesignVariableMode]
	/// The design variables contained within this collection.
	let variables: [DesignVariable]
}

// MARK: - Mode

/// Represents a single mode within a variable collection, such as "Light" or "Dark".
struct DesignVariableMode: Codable {
	let id: String
	let name: String
}

// MARK: - Variable

/// A single design variable exported from Figma, containing its type
/// and an array of resolved values across modes.
struct DesignVariable: Codable {
	let id: String
	let description: String
	let name: String
	/// The value type of this variable (e.g. boolean, string, number, RGB).
	let type: DesignVariableType
	/// The resolved values for this variable, one entry per mode.
	let value: [DesignVariableValue]

	init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.id = try container.decode(String.self, forKey: .id)
		self.description = try container.decode(String.self, forKey: .description)
		self.name = try container.decode(String.self, forKey: .name)
		self.type = try container.decode(DesignVariableType.self, forKey: .type)
		self.value = try container.decode([DesignVariableValue].self, forKey: .value)
	}
}

// MARK: - Variable Type

/// The data type of a Figma design variable.
enum DesignVariableType: String, Codable {
	case RGB
	case RGBA
	case boolean = "Boolean"
	case string = "String"
	case number = "Number"
}

// MARK: - Variable Value

/// A resolved value for a design variable in a specific mode,
/// pairing a mode ID with its corresponding payload.
struct DesignVariableValue: Codable {
	/// The ID of the mode this value applies to.
	let modelId: String
	/// The resolved payload for this mode.
	let payload: DesignVariablePayload

	enum CodingKeys: String, CodingKey {
		case modelId = "id"
		case payload = "data"
	}
}

// MARK: - Payload

/// The resolved value of a design variable, represented as a sum type
/// covering all supported Figma variable value kinds.
enum DesignVariablePayload: Codable {
	case rgb(RGB)
	case boolean(Bool)
	case string(String)
	case numeric(Double)

	/// Decodes a payload by attempting each case in order.
	/// RGB is tried first to avoid ambiguity with other object types.
	///
	/// - Throws: `DecodingError.dataCorrupted` if no known type matches.
	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()

		if let rgb = try? container.decode(RGB.self) {
			self = .rgb(rgb)
		} else if let bool = try? container.decode(Bool.self) {
			self = .boolean(bool)
		} else if let string = try? container.decode(String.self) {
			self = .string(string)
		} else if let double = try? container.decode(Double.self) {
			self = .numeric(double)
		} else {
			throw DecodingError.dataCorruptedError(
				in: container,
				debugDescription: "Unsupported variable payload"
			)
		}
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		switch self {
		case .rgb(let value):     try container.encode(value)
		case .boolean(let value): try container.encode(value)
		case .numeric(let value): try container.encode(value)
		case .string(let value):  try container.encode(value)
		}
	}
}
