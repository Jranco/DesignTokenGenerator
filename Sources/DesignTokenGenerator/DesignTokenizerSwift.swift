// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

@main
struct DesignTokenGenerator {
	static func main() {
		let args = CommandLine.arguments

		guard args.count == 3 else {
			print("Usage: TokenGenerator <input.json> <export-path>")
			return
		}

		let inputPath = args[1]
		let exportPath = args[2]

		do {
			let jsonData = try Data(contentsOf: URL(fileURLWithPath: inputPath))
			let tokenGenerator = try TokenGenerator(json: jsonData, exportPath: exportPath)
			try tokenGenerator.generateTokenFiles()
		} catch {
			print("❌ Error: \(error)")
		}
	}
}
