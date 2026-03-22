//
//  RGB.swift
//  DesignTokenGenerator
//
//  Created by Thomas Segkoulis on 09.03.26.
//

protocol ColorValueProtocol {
	var r: Double { get }
	var g: Double { get }
	var b: Double { get }
	var a: Double { get }
}

extension ColorValueProtocol {
	var a: Double { 1 }
}

struct RGB: Codable, ColorValueProtocol {
	let r: Double
	let g: Double
	let b: Double
	let a: Double

	init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.r = try container.decode(Double.self, forKey: .r)
		self.g = try container.decode(Double.self, forKey: .g)
		self.b = try container.decode(Double.self, forKey: .b)
		self.a = try container.decodeIfPresent(Double.self, forKey: .a) ?? 1
	}
}
