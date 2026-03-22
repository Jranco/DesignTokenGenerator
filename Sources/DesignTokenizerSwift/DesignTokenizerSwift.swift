// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

@main
struct DesignTokenGenerator {
	static func main() {
		let args = CommandLine.arguments

		guard args.count == 3 else {
			print("Usage: DesignTokenGenerator <input.json> <export-path>")
			return
		}

		let inputPath = args[1]
		let exportPath = args[2]

		do {
			let jsonData = try Data(contentsOf: URL(fileURLWithPath: inputPath))
			let tokenGenerator = try DesignTokenGenerator(json: jsonData, exportPath: exportPath)
			try tokenGenerator.generateTokenFiles()
		} catch {
			print("❌ Error: \(error)")
		}
	}
}

//@main
//struct DesignTokenGenerator {
//    static func main() {
//        print("Hello, world!")
//		// Sources/MyScript/main.swift
//		let args = CommandLine.arguments
//		// args[0] is the executable name
//		// args[1], args[2] etc are your params
//		print("first arg: \(args[1])")
//		
//		do {
//			let tokenGenerator = DesignTokenGenerator(json: <#T##Data#>, exportPath: <#T##String#>)
//		} catch {
//			
//		}
//    }
//}
