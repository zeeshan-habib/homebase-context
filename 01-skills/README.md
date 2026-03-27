# Skills

Shared Claude Code skills for the Homebase team. Each skill lives in its own subfolder and is owned by the person who created it, unless specified otherwise.

## Using a Skill

To use a skill from this folder, add it to your Claude Code configuration as a custom slash command pointing to the `.md` file. For example:

```json
{
  "customSlashCommands": [
    {
      "name": "analyst",
      "path": "/path/to/homebase-context/01-skills/analyst/analyst.md"
    }
  ]
}
```

Then invoke it with `/analyst` in Claude Code.

## Adding a New Skill

1. Create a new branch: `skill/<skill-name>`
2. Create a subfolder: `01-skills/<skill-name>/`
3. Copy `SKILL-TEMPLATE.md` into your subfolder and rename it to `<skill-name>.md`
4. Fill in the frontmatter (`name`, `description`) and the skill instructions
5. Add any supporting files (examples, schemas, etc.) to the same subfolder
6. Add a CODEOWNERS entry for your subfolder (see below)
7. Open a PR

## File Formats

- **`.md`** - Preferred format. Editable, reviewable, version-controlled. Use for all new skills.
- **`.skill`** - Runlayer export (binary). Being migrated to `.md`.

## CODEOWNERS

Each skill subfolder should be owned by its creator. When you add a new skill, add a line to the root `CODEOWNERS` file:

```
01-skills/<your-skill-name>/ @your-github-username
```

This lets you approve PRs that touch your skill without needing a core maintainer.
