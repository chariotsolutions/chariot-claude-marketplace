# Chariot Claude Marketplace

A [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces) for sharing skills across the Chariot Solutions team.

## Available Skills

| Skill | Description |
|-------|-------------|
| `playwright-e2e` | Scaffold a Playwright E2E test suite for a full-stack web app |

## Installation

Add the marketplace:

```
/plugin marketplace add chariot-solutions/chariot-claude-marketplace
```

Install the skills plugin:

```
/plugin install chariot-skills@chariot-marketplace
```

## Usage

Once installed, skills are available as slash commands:

```
/playwright-e2e [optional notes about the project]
```

## Auto-Distribution for Projects

To automatically prompt team members to install this marketplace when they open a project, add the following to the project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "chariot-marketplace": {
      "source": {
        "source": "github",
        "repo": "chariot-solutions/chariot-claude-marketplace"
      }
    }
  }
}
```

To also enable the plugin by default:

```json
{
  "enabledPlugins": {
    "chariot-skills@chariot-marketplace": true
  }
}
```

## Adding a New Skill

1. Create a directory under `plugins/chariot-skills/skills/<skill-name>/`
2. Add a `SKILL.md` file (required) with frontmatter and instructions
3. Add any supporting files the skill references
4. Update this README

See the [Claude Code plugins docs](https://code.claude.com/docs/en/plugins) for details on skill authoring.
