---
trigger: always
---

# Shell Command Safety

When proposing shell commands:

1. **Use `nocorrect` prefix** for commands that may trigger zsh autocorrect:
   ```bash
   nocorrect swift package plugin swiftformat ...
   ```

2. **Avoid ambiguous command names** that match config files (e.g., `swiftformat` vs `.swiftformat`)

3. **Use full paths** when invoking binaries to avoid PATH issues
