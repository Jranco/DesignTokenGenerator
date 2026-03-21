//
//  String+Extensions.swift
//  DesignTokenizerSwift
//
//  Created by Thomas Segkoulis on 09.03.26.
//

public extension String {
	func capitalizingFirstLetter() -> String {
		prefix(1).uppercased() + dropFirst()
	}
}
