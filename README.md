# Chariot Claude Marketplace

A [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces) for sharing skills across the Chariot Solutions team.

## Available Plugins

| Plugin | Description |
|--------|-------------|
| `chariot-skills` | Collection of shared skills (includes `playwright-e2e`) |
| `chariot-spec-first-testing` | Enforces spec-first testing discipline with hooks and spec format documentation |

## Installation

Add the marketplace:

```
/plugin marketplace add chariotsolutions/chariot-claude-marketplace
```

Install plugins:

```
/plugin install chariot-skills@chariot-marketplace
/plugin install chariot-spec-first-testing@chariot-marketplace
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
        "repo": "chariotsolutions/chariot-claude-marketplace"
      }
    }
  }
}
```

To also enable the plugin by default:

```json
{
  "enabledPlugins": {
    "chariot-skills@chariot-marketplace": true,
    "chariot-spec-first-testing@chariot-marketplace": true
  }
}
```

## Adding New Plugins or Skills

To add a skill to the existing `chariot-skills` plugin:

1. Create a directory under `plugins/chariot-skills/skills/<skill-name>/`
2. Add a `SKILL.md` file (required) with frontmatter and instructions
3. Add any supporting files the skill references

To add a new standalone plugin:

1. Create a directory under `plugins/<plugin-name>/`
2. Add `.claude-plugin/plugin.json` with the plugin manifest
3. Add skills, hooks, or other plugin components
4. Register it in `.claude-plugin/marketplace.json`

Update this README in either case.

See the [Claude Code plugins docs](https://code.claude.com/docs/en/plugins) for details on skill authoring.
