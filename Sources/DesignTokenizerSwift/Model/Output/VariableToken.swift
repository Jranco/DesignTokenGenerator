//
//  VariableToken.swift
//  DesignTokenizerSwift
//
//  Created by Thomas Segkoulis on 30.12.25.
//

enum VariableToken: Codable {
	case boolean(Bool)
	case string(String)
	case number(Double)

	enum CodingKeys: String, CodingKey {
		case type
		case value
	}

	enum TokenType: String, Codable {
		case boolean = "Boolean"
		case string = "String"
		case number = "Number"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let type = try container.decode(TokenType.self, forKey: .type)

		switch type {
		case .boolean:
			self = .boolean(try container.decode(Bool.self, forKey: .value))
		case .string:
			self = .string(try container.decode(String.self, forKey: .value))
		case .number:
			self = .number(try container.decode(Double.self, forKey: .value))
		}
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		switch self {
		case .boolean(let v):
			try container.encode(TokenType.boolean, forKey: .type)
			try container.encode(v, forKey: .value)

		case .string(let v):
			try container.encode(TokenType.string, forKey: .type)
			try container.encode(v, forKey: .value)

		case .number(let v):
			try container.encode(TokenType.number, forKey: .type)
			try container.encode(v, forKey: .value)
		}
	}
}
