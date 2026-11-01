// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Samification", platforms: [.iOS(.v17), .macOS(.v14)], products: [.library(name: "SamificationCore", targets: ["SamificationCore"])], targets: [.target(name: "SamificationCore"), .testTarget(name: "SamificationCoreTests", dependencies: ["SamificationCore"])])
