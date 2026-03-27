# Skills

Shared Claude Code skills for the Homebase team. Each skill lives in its own subfolder and is owned by the person who created it, unless specified otherwise.

## File Formats

- **`.md` files** - Plain markdown skills. Preferred format - version-controlled, editable, reviewable in GitHub.
- **`.skill` files** - Runlayer exports (binary/zip). Cannot be read or edited directly. We are migrating away from this format - use the `.md` version when available.

## Adding a New Skill

When helping a user create a new skill:
1. Create a subfolder: `01-skills/<skill-name>/`
2. Use `SKILL-TEMPLATE.md` as a starting point
3. Add a CODEOWNERS entry in the root `CODEOWNERS` file for the new subfolder, owned by the creator's GitHub username:
   ```
   01-skills/<skill-name>/ @their-github-username
   ```
