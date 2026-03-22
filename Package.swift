// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DesignTokenGenerator",
	platforms: [
		.macOS(.v13)
	],
	dependencies: [
		   .package(
			   url: "https://github.com/stencilproject/Stencil.git",
			   from: "0.15.0"
		   )
	],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "DesignTokenGenerator",
			dependencies: [
				.product(name: "Stencil", package: "Stencil")
			],
			resources: [
				.process("Resources/Templates")
			]
        ),
		.testTarget(
			  name: "DesignTokenGeneratorTests",
			  dependencies: ["DesignTokenGenerator"],
//			  resources: [
//				  .process("Mocks")
//			  ]
		  ),
    ]
)
