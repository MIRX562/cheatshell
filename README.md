# cheatshell

A keyboard-driven command & snippet launcher built with [Quickshell](https://quickshell.org)
and QML. It indexes Markdown notes that you own and keeps them **read-only** —
nothing is ever written back, and no command is ever executed.

## Requirements

- Quickshell 0.3.2+
- Qt 6.5+ (developed against Qt 6.12)

## Launch

```sh
quickshell -p ~/.config/quickshell/cheatshell
```

The launcher appears as a centered, decorationless overlay. It is a
`PanelWindow` backed by `wlr-layer-shell` on Wayland (layer `overlay`,
exclusive keyboard focus) and works on niri, sway, Hyprland and other
wlr-layer-shell compositors. Open it with a compositor keybind:

```kdl
// niri: ~/.config/niri/config.kdl
binds {
    Mod+Space { spawn "qs" "ipc" "-p" "/home/mirx/.config/quickshell/cheatshell" "call" "cheatshell" "toggle"; }
}
```

Keep one long-running instance (started at login, e.g. with
`spawn-at-startup "quickshell" "-p" "/home/mirx/.config/quickshell/cheatshell"`)
and use IPC to show/hide it.

## Keybindings

| Key | Action |
| --- | --- |
| Type | Filter results (debounced) |
| `Up` / `Down` | Move selection |
| `Enter` | Copy the command of the selected note |
| `Ctrl+Enter` | Copy the first example of the selected note |
| `Ctrl+O` | Open the source Markdown file (`xdg-open`) |
| `Ctrl+R` | Re-read config and rescan directories |
| `Esc` | Hide the launcher |
| `Ctrl+Q` | Quit the process |
| Click chip | Toggle a tag filter |
| Click preview block | Copy that code block |
| Double-click row | Copy its command |

Every copy shows a short toast. The launcher never runs a command.

## Configuration

Primary location: `~/.config/cheatshell/config.json`.
Fallback location: `~/.config/cmdnotes/config.json`.

The first readable file wins. A missing file, invalid JSON, or a non-object
root falls back to defaults; invalid individual fields are ignored and keep
their defaults. `~` and `~/…` are expanded in directory paths, and trailing
slashes are normalised.

```json
{
  "directories": ["~/Notes/commands", "/srv/team-snippets"],
  "recursive": true,
  "watch": true,
  "search": {
    "maxResults": 30,
    "fuzzy": true,
    "minimumScore": 0
  },
  "behavior": {
    "copyOnEnter": true,
    "showPreview": true,
    "openSourceShortcut": true
  },
  "appearance": {
    "windowWidth": 760,
    "windowHeight": 560
  }
}
```

| Field | Default | Meaning |
| --- | --- | --- |
| `directories` | `[]` | Folders scanned for `*.md` (recursive by default) |
| `recursive` | `true` | `false` limits the scan to one level |
| `watch` | `true` | Poll for created/modified/removed files every 8 s |
| `search.maxResults` | `30` | Result cap |
| `search.fuzzy` | `true` | Enable subsequence fallback when substring matching fails |
| `search.minimumScore` | `0` | Minimum fuzzy quality (0–1) for a fuzzy hit |
| `behavior.copyOnEnter` | `true` | `false` makes Enter a no-op |
| `behavior.showPreview` | `true` | Hide the right-hand preview panel |
| `behavior.openSourceShortcut` | `true` | Disable `Ctrl+O` |
| `appearance.windowWidth/Height` | `760`/`560` | Launcher size in logical pixels |

## Markdown note format

One note per file. Frontmatter is optional YAML-ish `key: value`; only `title`
and `tags` are read.

~~~markdown
---
title: List Docker containers
tags:
  - docker
  - containers
---

List every Docker container with its status and published ports.

## Command

```bash
docker ps -a
```

## Examples

Only running containers:

```bash
docker ps
```

## Notes

Add --format to customise the output table.
~~~

Parsing rules:

- `title` comes from frontmatter. A file that **has** frontmatter but no
  `title` is skipped (a warning is logged).
- Without frontmatter, the first H1 (`# Heading`) is used as the title, falling
  back to a humanised filename (`my-note.md` → "My note").
- `tags` accepts a flow list (`tags: [a, b]`) or a block list, and is
  case-normalised and de-duplicated.
- Text before the first `##` heading becomes the description.
- `## Command` uses the first fenced code block (or plain text if none).
- `## Examples` collects every fenced code block.
- `## Notes` is plain text.
- Malformed files (unterminated frontmatter, unreadable, no title) are skipped
  with a log message; the rest of the index is unaffected.
- Files are never modified. `.git` and `.obsidian` directories are ignored.

## Search

Queries are split on whitespace. A token like `tag:docker` filters by tag
(combine several, and combine with the clickable tag chips; all must match).
Remaining tokens must all match, ranked by field weight:

`title > tags > command > description > examples > notes > filename`

Substring matches score higher than fuzzy subsequence matches (consecutive and
word-start characters are favoured). Results are stable-sorted by score, then
title.

## Watching & refresh

Quickshell 0.3.2 has no directory-watching API. Instead, cheatshell runs a
small `find -printf '%T@\t%p\n'` listing through `Quickshell.Io.Process` every
8 seconds (when `watch` is on) and compares paths + mtimes with the in-memory
index:

- only new/changed files are re-read and re-parsed;
- deletions and renames drop the old path and add the new one;
- an entire directory that fails to scan (missing, unreadable) never wipes
  existing entries;
- readers are reused, and a watchdog recovers from a reader that never
  completes.

`Ctrl+R` forces an immediate scan and reloads the config. A full re-index does
not happen on a timer — only files whose mtime changed are touched.

## IPC

```sh
qs ipc -p ~/.config/quickshell/cheatshell call cheatshell toggle
qs ipc -p ~/.config/quickshell/cheatshell call cheatshell open
qs ipc -p ~/.config/quickshell/cheatshell call cheatshell hide
qs ipc -p ~/.config/quickshell/cheatshell call cheatshell quit
```

`open` is named that way because `show` collides with the `qs ipc show`
subcommand.

## Layout

```
shell.qml                 entry point: window, layout, key actions, IPC
config/Config.qml         config loading + defaults (singleton)
models/CommandModel.qml   in-memory path → {mtime, entry} index
services/MarkdownParser.qml  frontmatter/section/fence parsing
services/FileScanner.qml  discovery, mtime diffing, incremental parsing
services/SearchEngine.qml query parsing, scoring, fuzzy matching
services/Clipboard.qml    clipboard wrapper + copy signal
components/SearchBar.qml  input + key handling
components/TagFilters.qml tag chips
components/CommandList.qml / CommandItem.qml  result list
components/CommandPreview.qml                 detail panel
```

Everything is in memory; there is no database, backend process, or build step.
