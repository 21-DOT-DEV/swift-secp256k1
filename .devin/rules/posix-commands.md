---
trigger: always
---

# POSIX Command Preference

When writing shell commands for cross-platform plugins or CI:

1. **Prefer POSIX-standard commands** over convenience tools:
   - Use `find`, `cp`, `sh` instead of `rsync`, `install`
   - These are guaranteed available on macOS, Linux, and Docker images

2. **Avoid assumptions** about tool availability in CI environments
   - Docker images (e.g., `swift:6.x`) have minimal toolsets
   - Test commands in Docker before relying on them in CI
