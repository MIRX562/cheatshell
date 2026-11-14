# cheatshell

A keyboard-driven command & snippet launcher built with [Quickshell](https://quickshell.org)
and QML. It indexes Markdown notes that you own and keeps them **read-only** —
nothing is ever written back, and no command is ever executed.

## Requirements

- Linux with a **wlr-layer-shell** compositor (niri, sway, Hyprland, KDE, …)
- Quickshell 0.3.2+
- Qt 6.5+ (developed against Qt 6.12)
- `xdg-open` for `Ctrl+O`
- Optional: `qmllint` for installation-time validation, and any editor/terminal
  for `Ctrl+E` (Neovim in kitty by default)

## Install

One line, no clone required:

```sh
curl -fsSL https://raw.githubusercontent.com/MIRX562/cheatshell/refs/heads/main/install.sh | bash
```

The installer downloads the source from GitHub, checks the OS, Wayland
session, compositor family, Quickshell and Qt versions, core utilities,
`curl`/`wget`, `xdg-open`, `qmllint`, and which editors or terminals are
available. It then asks for your notes directory, installs the app to
`${XDG_CONFIG_HOME:-~/.config}/quickshell/cheatshell`, writes a starter config,
and validates the QML. Re-running it is safe.

Non-interactive (for scripts or a fresh machine):

```sh
curl -fsSL https://raw.githubusercontent.com/MIRX562/cheatshell/refs/heads/main/install.sh \
  | bash -s -- --yes --notes-dir "$HOME/Notes/commands"
```

From a local checkout, `./install.sh` uses the local files instead of
downloading, which is handy while developing. The notes directory defaults to
`~/Notes/commands` and is created if it does not exist.

Useful options:

```sh
./install.sh --notes-dir DIR              # notes folder for the starter config
./install.sh --target /some/other/dir     # custom app install location
./install.sh --source DIR                 # install from a local copy
./install.sh --ref BRANCH                 # download another branch/tag
./install.sh --no-config                  # do not write a starter config
./install.sh --uninstall                  # remove the app, keep your config
./install.sh --uninstall --purge          # also remove the config
```

With the one-liner, pass flags after `bash -s --`:

```sh
curl -fsSL https://raw.githubusercontent.com/MIRX562/cheatshell/refs/heads/main/install.sh \
  | bash -s -- --notes-dir ~/Documents/snippets
```

Without the script, copy this directory to
`~/.config/quickshell/cheatshell` manually — the first launch writes a default
config for you.

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
| `Ctrl+E` | Open the selected note in the configured editor |
| `Ctrl+R` | Re-read config and rescan directories |
| `Ctrl+,` | Open the settings pane |
| `Esc` | Hide the launcher (or close settings) |
| `Ctrl+Q` | Quit the process |
| Click chip | Toggle a tag filter |
| Click preview block | Copy that code block |
| Double-click row | Copy its command |

Every copy shows a short toast. The launcher never runs a command.

## Configuration

Primary location: `${XDG_CONFIG_HOME:-~/.config}/cheatshell/config.json`.
Fallback location: `${XDG_CONFIG_HOME:-~/.config}/cmdnotes/config.json`.

If neither file exists (first run), the app writes a default config to the
primary location, including `directories: ["~/Notes/commands"]`, all defaults,
and the Neovim `Ctrl+E` command. An existing but malformed file is **never**
overwritten — the app falls back to in-memory defaults and logs a warning.

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
    "maxResults": 0,
    "pageSize": 30,
    "fuzzy": true,
    "minimumScore": 0
  },
  "indexing": {
    "maxFiles": 0
  },
  "behavior": {
    "copyOnEnter": true,
    "showPreview": true,
    "openSourceShortcut": true,
    "openWith": {
      "command": ["kitty", "nvim", "{path}"]
    }
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
| `search.maxResults` | `0` | Hard result cap (`0` = unlimited) |
| `search.pageSize` | `30` | Matches loaded per page while scrolling |
| `search.fuzzy` | `true` | Enable subsequence fallback when substring matching fails |
| `search.minimumScore` | `0` | Minimum fuzzy quality (0–1) for a fuzzy hit |
| `indexing.maxFiles` | `0` | Maximum indexed files (`0` = unlimited), selected alphabetically by path |
| `behavior.copyOnEnter` | `true` | `false` makes Enter a no-op |
| `behavior.showPreview` | `true` | Hide the right-hand preview panel |
| `behavior.openSourceShortcut` | `true` | Disable `Ctrl+O` |
| `behavior.openWith.command` | `["kitty","nvim","{path}"]` | Argument array for `Ctrl+E`; empty disables it |
| `appearance.windowWidth/Height` | `760`/`560` | Launcher size in logical pixels |

### Settings pane

`Ctrl+,` opens a full settings pane covering every option above. Changes are
kept as a draft: `Ctrl+S` saves and applies them, `Esc` discards, and the
header shows an `unsaved` marker. `Tab`/`Shift+Tab` move between controls,
`PageUp`/`PageDown` scroll the form. Saving writes the primary config file
atomically and preserves unknown keys. Invalid numbers are clamped to safe
ranges, folders are de-duplicated, and the index is refreshed after saving.

### Open in an external editor

`Ctrl+E` launches `behavior.openWith.command`, an **argv array** executed
directly — no shell is involved, so note paths are never re-interpreted:

```json
"behavior": {
  "openWith": { "command": ["kitty", "nvim", "{path}"] }
}
```

- `{path}` is replaced with the selected note's absolute path.
- If no element contains `{path}`, the path is appended as the last argument.
- An empty array disables `Ctrl+E`; `Ctrl+O` continues to use `xdg-open`.

Presets in the settings pane: Neovim (`kitty nvim {path}`), Vim
(`kitty vim {path}`), VS Code (`code --reuse-window {path}`) and Obsidian
(`obsidian {path}`). The text field accepts quoted arguments for paths with
spaces.

## Syntax highlighting

Fenced code blocks keep their info string, and the preview highlights it with
a small built-in tokenizer — no external process or library. Supported:
`bash`/`sh`, `sql`, `js`/`ts`, `json`, `yaml`, `ini`, `dockerfile`. Anything
else (including `text`) is shown as plain monospace.

Only the display is transformed: clicking a block still copies the original,
unhighlighted code. A small label above each block names the detected
language.
Markdown images are not rendered — image syntax stays literal text.

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

All matches are ranked, but only `search.pageSize` rows are exposed at first.
Moving into the last few rows, or scrolling to the bottom, appends the next
page. `search.maxResults` is an optional hard cap on top of that (`0` means
unlimited), so the list no longer stops at 30 by default.

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

When `indexing.maxFiles` is greater than zero, discovered paths are sorted and
only the first N are indexed; the rest are not read or parsed. The footer shows
the active limit, and lowering the cap prunes entries immediately.

`Ctrl+R` forces an immediate scan and reloads the config. A full re-index does
not happen on a timer — only files whose mtime changed are touched.

## IPC

```sh
qs ipc -p ~/.config/quickshell/cheatshell call cheatshell toggle
qs ipc -p ~/.config/quickshell/cheatshell call cheatshell open
qs ipc -p ~/.config/quickshell/cheatshell call cheatshell hide
qs ipc -p ~/.config/quickshell/cheatshell call cheatshell settings
qs ipc -p ~/.config/quickshell/cheatshell call cheatshell toggleSettings
qs ipc -p ~/.config/quickshell/cheatshell call cheatshell quit
```

`open` is named that way because `show` collides with the `qs ipc show`
subcommand.

## Layout

```
shell.qml                 entry point: window, layout, key actions, IPC
install.sh                dependency checks + installer/uninstaller
config/Config.qml         config loading, first-run bootstrap + defaults (singleton)
models/CommandModel.qml   in-memory path → {mtime, entry} index
services/MarkdownParser.qml  frontmatter/section/fence parsing
services/FileScanner.qml  discovery, mtime diffing, incremental parsing
services/SearchEngine.qml query parsing, scoring, fuzzy matching
services/SyntaxHighlighter.qml dependency-free StyledText code tokenizer
services/Clipboard.qml    clipboard wrapper + copy signal
components/SearchBar.qml  input + key handling
components/SettingsPane.qml + Setting{Toggle,Stepper,Slider}.qml  settings
components/TagFilters.qml tag chips
components/CommandList.qml / CommandItem.qml  result list
components/CommandPreview.qml                 detail panel
```

Everything is in memory; there is no database, backend process, or build step.
