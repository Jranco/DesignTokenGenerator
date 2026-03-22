//
//  String+Extensions.swift
//  DesignTokenGenerator
//
//  Created by Thomas Segkoulis on 09.03.26.
//

public extension String {
	func capitalizingFirstLetter() -> String {
		prefix(1).uppercased() + dropFirst()
	}
}
