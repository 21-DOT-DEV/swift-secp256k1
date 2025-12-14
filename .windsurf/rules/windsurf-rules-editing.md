---
trigger: glob
globs: [".windsurf/rules/**/*.md"]
---

# Windsurf Rules File Management

When creating or editing files in .windsurf/rules/:

**ALWAYS use the cat command with heredoc** instead of write_to_file or edit tools, as the directory may be protected from direct writes.

## Create New Rule

Use: cat > .windsurf/rules/rule-name.md << 'EOF'

Then add the rule content with YAML frontmatter (trigger, globs) followed by markdown content, and close with EOF on its own line.

## Append to Existing Rule

Use: cat >> .windsurf/rules/existing-rule.md << 'EOF'

Then add additional content and close with EOF.

This ensures reliable file creation/modification in the rules directory.
