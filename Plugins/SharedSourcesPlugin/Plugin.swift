//
//  Plugin.swift
//  SharedSourcesPlugin
//
//  SPM BuildToolPlugin that copies shared sources to each target's build directory.
//  This plugin enables code sharing between P256K and ZKP targets without symlinks.
//
//  Note: SPM bug #7930 may cause intermediate files (.d, .swiftdeps, etc.) to leak
//  into the working directory. Use cleanup if needed:
//  find . -maxdepth 1 -type f \( -name "*.d" -o -name "*.swiftdeps" -o -name "*.swiftmodule" \) -delete
//

import Foundation
import PackagePlugin

@main
struct SharedSourcesPlugin: BuildToolPlugin {
    /// Copies shared sources into the target's plugin work directory before compilation.
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let shared = context.package.directoryURL.appending(path: "Sources/Shared")
        let output = context.pluginWorkDirectoryURL

        #if os(Windows)
            // TODO: Windows support (robocopy or xcopy)
            return []
        #else
            // Flatten all .swift files from Sources/Shared (including subdirectories) into output
            return [
                .prebuildCommand(
                    displayName: "Copy shared sources to \(target.name)",
                    executable: URL(filePath: "/bin/sh"),
                    arguments: [
                        "-c",
                        "find '\(shared.path(percentEncoded: false))' -name '*.swift' -exec cp {} '\(output.path(percentEncoded: false))/' \\;"
                    ],
                    outputFilesDirectory: output
                )
            ]
        #endif
    }
}
