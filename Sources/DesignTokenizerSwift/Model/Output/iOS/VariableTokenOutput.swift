//
//  VariableTokenOutput.swift
//  DesignTokenizerSwift
//
//  Created by Thomas Segkoulis on 02.01.26.
//

protocol VariableTokenOutput {
	var name: String { get }
	var boolValue: Bool? { get }
	var doubleValue: Double? { get }
	var stringValue: String? { get }
}
