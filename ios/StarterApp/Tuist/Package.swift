// swift-tools-version: 5.9
// This file declares external SPM dependencies for Tuist.
// After editing, run: tuist install && tuist generate

import PackageDescription

#if TUIST
    import ProjectDescription

    let packageSettings = PackageSettings(
        productTypes: [
            "Supabase": .framework,
            "PostHog": .framework,
        ]
    )
#endif

let package = Package(
    name: "StarterAppPackages",
    dependencies: [
        .package(
            url: "https://github.com/supabase-community/supabase-swift.git",
            from: "2.5.1"
        ),
        .package(
            url: "https://github.com/PostHog/posthog-ios.git",
            from: "3.0.0"
        ),
    ]
)
