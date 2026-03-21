//
//  DesignVariable+Extensions.swift
//  DesignTokenizerSwift
//
//  Created by Thomas Segkoulis on 20.03.26.
//

extension DesignVariable: VariableTokenOutput {
	var doubleValue: Double? {
		switch self.value.first?.payload {
		case .numeric(let value):
			return value
		default:
			return nil
		}
	}

	var stringValue: String? {
		switch self.value.first?.payload {
		case .string(let value):
			return value
		default:
			return nil
		}
	}

	var boolValue: Bool? {
		switch self.value.first?.payload {
		case .boolean(let value):
			return value
		default:
			return nil
		}
	}
}
