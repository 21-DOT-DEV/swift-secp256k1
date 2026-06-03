---
trigger: glob
globs: ["**/Package.swift", "**/swift-version*", "**/compatibility*"]
---

# Swift Version Compatibility Discovery

When determining Swift version compatibility for a Swift package:

1. **Use swift-tools-version as authoritative source** - The declaration in Package.swift is what SPM enforces; build testing is unnecessary

2. **Extract via git show** - Use `git show "<tag>:Package.swift"` to read historical versions without checking out

3. **Avoid build-testing approach** - Older Swift toolchains may fail against modern macOS SDKs, producing false negatives unrelated to actual package compatibility

4. **Trust the manifest** - If Package.swift declares `swift-tools-version:5.6`, that IS the minimum version—no empirical testing needed

## Example: Extract swift-tools-version from release

```bash
git show "0.21.0:Package.swift" | grep -m1 "swift-tools-version" | sed -E 's/.*swift-tools-version[: ]*([0-9]+\.[0-9]+).*/\1/'
```
