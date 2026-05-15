// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

@main
struct DesignTokenGenerator {
	static func main() {
		let args = CommandLine.arguments

		guard args.count == 3 || args.count == 4 else {
			print("Usage: TokenGenerator <input.json> <export-path> [collections|modes]")
			return
		}

		let inputPath = args[1]
		let exportPath = args[2]

		let colorSchemeSource: ColorSchemeSource
		if args.count == 4 {
			switch args[3] {
			case "modes":       colorSchemeSource = .modes
			case "collections": colorSchemeSource = .collections
			default:
				print("❌ Unknown colorSchemeSource '\(args[3])'. Expected 'collections' or 'modes'.")
				return
			}
		} else {
			colorSchemeSource = .collections
		}

		do {
			let jsonData = try Data(contentsOf: URL(fileURLWithPath: inputPath))
			let tokenGenerator = try TokenGenerator(json: jsonData, exportPath: exportPath, colorSchemeSource: colorSchemeSource)
			try tokenGenerator.generateTokenFiles()
		} catch {
			print("❌ Error: \(error)")
		}
	}
}
