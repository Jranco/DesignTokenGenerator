// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

@main
struct DesignTokenGenerator {
	static func main() {
		let args = CommandLine.arguments

		guard args.count >= 2 else {
			printUsage()
			return
		}

		let inputPath = args[1]
		let exportPath = args[2]

		var platforms: [Platform] = []
		var colorSchemeSource: ColorSchemeSource = .collections

		var i = 3
		while i < args.count {
			switch args[i] {
			case "--platform":
				i += 1
				guard i < args.count else {
					print("❌ --platform requires a value.")
					return
				}
				guard let platform = Platform(rawValue: args[i]) else {
					print("❌ Unknown platform '\(args[i])'. Expected 'xcode', 'web', or 'android'.")
					return
				}
				platforms.append(platform)
			case "modes":
				colorSchemeSource = .modes
			case "collections":
				colorSchemeSource = .collections
			default:
				print("❌ Unknown argument '\(args[i])'.")
				printUsage()
				return
			}
			i += 1
		}

		guard !platforms.isEmpty else {
			print("❌ At least one --platform is required.")
			printUsage()
			return
		}

		do {
			let jsonData = try Data(contentsOf: URL(fileURLWithPath: inputPath))
			let tokenGenerator = try TokenGenerator(json: jsonData, exportPath: exportPath, colorSchemeSource: colorSchemeSource, platforms: platforms)
			try tokenGenerator.generateTokenFiles()
		} catch {
			print("❌ Error: \(error)")
		}
	}

	private static func printUsage() {
		print("Usage: TokenGenerator <input.json> <export-path> --platform <platform> [--platform <platform>] [collections|modes]")
		print("  platform: xcode | web | android")
	}
}
