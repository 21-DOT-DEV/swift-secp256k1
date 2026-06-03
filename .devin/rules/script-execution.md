---
trigger: glob
globs: ["scripts/**/*.sh", "*.sh"]
---

# Script Execution Guidelines

When working with shell scripts in this project:

- **Long-running scripts** (>30 seconds): Recommend user run manually in external terminal
- **IDE may freeze** on scripts with extensive output or long runtime
- Prefer quick, focused scripts that complete in seconds
- For build/test scripts, suggest running non-blocking with status checks
- Always set `Blocking: false` for scripts that may take significant time
