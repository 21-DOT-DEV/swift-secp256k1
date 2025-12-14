---
trigger: glob
globs: ["**/Plugins/**/*.swift", "**/Plugin.swift"]
---

# SPM Plugin Implementation

Before implementing SPM BuildToolPlugins:

1. **Research platform constraints**:
   - Prebuild commands cannot use executables built from the same package
   - Plugin output directories don't recursively include subdirectories
   - System commands must be POSIX-standard for cross-platform support

2. **Document limitations** in research.md before implementation

3. **Test in Docker** to verify CI compatibility
