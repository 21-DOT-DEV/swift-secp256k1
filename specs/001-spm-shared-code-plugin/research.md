# Research: SPM Pre-Build Plugin for Shared Code

**Date**: 2025-12-08  
**Feature**: 001-spm-shared-code-plugin

## Research Questions

### 1. SPM BuildToolPlugin API

**Question**: How does SPM's `BuildToolPlugin` with `prebuildCommand` work for file generation/copying?

**Decision**: Use `BuildToolPlugin` protocol with `prebuildCommand` to copy files before compilation.

**Rationale**:
- `prebuildCommand` runs before the build starts and can output files to a plugin-managed directory
- SPM automatically includes the output directory in the target's source paths
- The output directory is in `.build/plugins/outputs/` — does not pollute source tree
- Works identically on macOS, Linux, and Windows

**Alternatives Considered**:
- `buildCommand` (runs per-file, not suitable for bulk copying)
- Custom build phase in Xcode (not cross-platform)
- External build tool (adds complexity, violates zero-dependency principle)

**Key Implementation Details**:
```swift
import PackagePlugin

@main
struct SharedSourcesPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let sharedDir = context.package.directory.appending("Sources/Shared")
        let outputDir = context.pluginWorkDirectory
        
        return [
            .prebuildCommand(
                displayName: "Copy shared sources",
                executable: Path("/bin/cp"),  // Or custom Swift executable
                arguments: ["-R", sharedDir.string, outputDir.string],
                outputFilesDirectory: outputDir
            )
        ]
    }
}
```

**Note**: For pure Swift implementation, the plugin can use a custom executable target that uses `FileManager` instead of shell commands.

---

### 2. Cross-Platform File Operations

**Question**: How to ensure file copying works on Windows without symlinks?

**Decision**: Use Swift's `FileManager` for all file operations; avoid shell commands.

**Rationale**:
- `FileManager.copyItem(at:to:)` works identically on macOS, Linux, and Windows
- No shell dependency (Windows doesn't have `/bin/cp`)
- Handles recursive directory copying natively
- Better error handling with Swift error types

**Alternatives Considered**:
- Shell commands (`cp -R`) — not portable to Windows
- Platform-specific implementations — unnecessary complexity

**Key Implementation Details**:
```swift
let fileManager = FileManager.default

func copySharedSources(from source: URL, to destination: URL) throws {
    let contents = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
    
    for item in contents {
        let destItem = destination.appendingPathComponent(item.lastPathComponent)
        if fileManager.fileExists(atPath: destItem.path) {
            try fileManager.removeItem(at: destItem)
        }
        try fileManager.copyItem(at: item, to: destItem)
    }
}
```

---

### 3. Conflict Detection

**Question**: How to detect and report filename conflicts between shared and target-specific files?

**Decision**: Pre-scan target source directory before copying; fail with descriptive error if conflicts found.

**Rationale**:
- Early failure prevents confusing compiler errors
- Clear error message helps developer resolve issue
- Fail-fast aligns with SPM's design philosophy

**Implementation Approach**:
1. List all `.swift` files in target's source directory
2. List all `.swift` files in `Sources/Shared/`
3. Find intersection (by filename)
4. If non-empty, throw error listing conflicts

---

### 4. Incremental Build Support

**Question**: How to support incremental builds efficiently?

**Decision**: Rely on SPM's built-in caching; always copy all files (SPM handles change detection).

**Rationale**:
- SPM's `prebuildCommand` output is cached based on input file timestamps
- Implementing custom change detection adds complexity with minimal benefit
- For 18 files, copying overhead is negligible (< 100ms)

**Alternatives Considered**:
- File hash comparison — adds complexity, marginal benefit
- Timestamp comparison — SPM already does this

---

### 5. Package.swift Configuration

**Question**: How to configure Package.swift to use the plugin?

**Decision**: Define plugin target and apply to P256K and ZKP targets.

**Key Implementation Details**:
```swift
// Package.swift
let package = Package(
    name: "secp256k1",
    // ...
    targets: [
        // Plugin executable (does the actual copying)
        .executableTarget(
            name: "SharedSourcesCopier",
            path: "Plugins/SharedSourcesCopier"
        ),
        
        // Plugin definition
        .plugin(
            name: "SharedSourcesPlugin",
            capability: .buildTool(),
            dependencies: ["SharedSourcesCopier"],
            path: "Plugins/SharedSourcesPlugin"
        ),
        
        // Apply plugin to targets
        .target(
            name: "P256K",
            dependencies: ["libsecp256k1"],
            plugins: ["SharedSourcesPlugin"]
        ),
        .target(
            name: "ZKP",
            dependencies: ["libsecp256k1_zkp"],
            plugins: ["SharedSourcesPlugin"]
        ),
    ]
)
```

---

## Summary

| Topic | Decision |
|-------|----------|
| Plugin API | `BuildToolPlugin` with `prebuildCommand` |
| File operations | Pure Swift `FileManager` (cross-platform) |
| Conflict detection | Pre-scan and fail-fast with descriptive error |
| Incremental builds | Rely on SPM caching; copy all files |
| Architecture | Plugin target + executable target for file operations |
