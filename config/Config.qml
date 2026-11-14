pragma Singleton
import Quickshell
import Quickshell.Io

// Loads ~/.config/cheatshell/config.json (falling back to the legacy
// ~/.config/cmdnotes/config.json). Every field is optional; missing or
// malformed values fall back to the defaults below.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    // Honour XDG_CONFIG_HOME so the app works outside the default layout and
    // matches install.sh.
    readonly property string configHome: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME")
        if (xdg !== undefined && xdg !== null && String(xdg).trim() !== "")
            return String(xdg)
        return root.home + "/.config"
    }
    readonly property string primaryPath: root.configHome + "/cheatshell/config.json"
    readonly property string fallbackPath: root.configHome + "/cmdnotes/config.json"

    property string configFile: ""

    // Defaults - kept in sync with the documented config format.
    property var directories: []
    property bool recursive: true
    property bool watch: true
    property int maxResults: 0        // 0 = unlimited
    property int pageSize: 30
    property bool fuzzy: true
    property real minimumScore: 0
    property bool copyOnEnter: true
    property bool showPreview: true
    property bool openSourceShortcut: true
    property var openWithCommand: ["kitty", "nvim", "{path}"]
    property int windowWidth: 760
    property int windowHeight: 560
    property int maxFiles: 0          // 0 = unlimited

    property bool saving: false

    signal saved()
    signal saveFailed(string message)

    // Last successfully parsed config, used to preserve unknown keys on save.
    property var _raw: ({})
    property var _pending: null

    FileView {
        id: primaryView
        blockAllReads: true
        printErrors: false
    }

    FileView {
        id: fallbackView
        blockAllReads: true
        printErrors: false
    }

    // Dedicated writer so reading and saving never race each other.
    FileView {
        id: writer
        blockAllReads: true
        atomicWrites: true
        printErrors: false

        onSaved: root._onSaved()
        onSaveFailed: (error) => {
            root.saving = false
            root._pending = null
            console.warn("[cheatshell] could not save config " + root.primaryPath + ": " + error)
            root.saveFailed("Could not save settings")
        }
    }

    // Used only for first-run bootstrap, so a write failure cannot be mistaken
    // for a user-initiated save.
    FileView {
        id: bootstrapper
        blockAllReads: true
        atomicWrites: true
        printErrors: false

        onSaved: console.log("[cheatshell] created default config at " + root.primaryPath)
        onSaveFailed: (error) => {
            console.warn("[cheatshell] could not create default config " + root.primaryPath
                         + ": " + error + " - using in-memory defaults")
        }
    }

    // Re-reads the configuration file synchronously. Used at startup (before
    // the window is built) and by the manual refresh action.
    function load() {
        const primaryJson = root._read(primaryView, root.primaryPath)
        const fallbackJson = root._read(fallbackView, root.fallbackPath)

        let applied = root._apply(primaryJson, root.primaryPath)
        if (!applied)
            applied = root._apply(fallbackJson, root.fallbackPath)

        if (applied)
            return

        root._raw = ({})

        // First run: neither file exists (or both are empty). Write a usable
        // default so the app does not start with an empty index. A file that
        // exists but is malformed is never overwritten.
        if (!root._hasContent(root.primaryPath) && !root._hasContent(root.fallbackPath)) {
            root._createDefaultConfig()
            return
        }

        console.warn("[cheatshell] no readable config found at " + root.primaryPath
                     + " or " + root.fallbackPath + " - using defaults")
        root._warnIfNoDirectories()
    }

    function reload() {
        root.load()
    }

    // Writes every known option, preserving unrecognized keys from the file
    // that was loaded at startup. Values are validated and clamped here so the
    // UI cannot persist an unusable configuration.
    function save(values) {
        if (root.saving || values === null || typeof values !== "object")
            return false

        const next = JSON.parse(JSON.stringify(root._raw || ({})))

        const dirs = []
        const seen = ({})
        const rawDirs = Array.isArray(values.directories) ? values.directories : []
        for (let i = 0; i < rawDirs.length; i++) {
            if (typeof rawDirs[i] !== "string")
                continue
            let dir = root._expandHome(rawDirs[i].trim())
            while (dir.length > 1 && dir.charAt(dir.length - 1) === "/")
                dir = dir.slice(0, -1)
            if (dir === "" || seen[dir] === true)
                continue
            seen[dir] = true
            dirs.push(dir)
        }
        next.directories = dirs
        next.recursive = root._bool(values.recursive, root.recursive)
        next.watch = root._bool(values.watch, root.watch)

        const search = root._ensureObject(next, "search")
        search.pageSize = root._clampInt(values.pageSize, 1, 500, root.pageSize)
        search.maxResults = root._clampInt(values.maxResults, 0, 1000000, root.maxResults)
        search.fuzzy = root._bool(values.fuzzy, root.fuzzy)
        let score = Number(values.minimumScore)
        if (!isFinite(score))
            score = root.minimumScore
        search.minimumScore = Math.round(Math.max(0, Math.min(1, score)) * 100) / 100

        const indexing = root._ensureObject(next, "indexing")
        indexing.maxFiles = root._clampInt(values.maxFiles, 0, 1000000, root.maxFiles)

        const behavior = root._ensureObject(next, "behavior")
        behavior.copyOnEnter = root._bool(values.copyOnEnter, root.copyOnEnter)
        behavior.showPreview = root._bool(values.showPreview, root.showPreview)
        behavior.openSourceShortcut = root._bool(values.openSourceShortcut, root.openSourceShortcut)
        const openWith = root._ensureObject(behavior, "openWith")
        openWith.command = root._commandArray(
            values.openWithCommand === undefined ? root.openWithCommand : values.openWithCommand)

        const appearance = root._ensureObject(next, "appearance")
        appearance.windowWidth = root._clampInt(values.windowWidth, 320, 4096, root.windowWidth)
        appearance.windowHeight = root._clampInt(values.windowHeight, 240, 4096, root.windowHeight)

        root._pending = next
        root.saving = true
        writer.path = root.primaryPath
        writer.setText(JSON.stringify(next, null, 2) + "\n")
        return true
    }

    function _onSaved() {
        const pending = root._pending
        root._pending = null
        root.saving = false
        if (pending === null)
            return
        root._apply(pending, root.primaryPath)
        root.saved()
    }

    function _hasContent(path) {
        try {
            primaryView.path = path
            const text = primaryView.text()
            return text !== undefined && text !== null && text.trim() !== ""
        } catch (e) {
            return false
        }
    }

    function _defaultConfig() {
        return {
            directories: ["~/Notes/commands"],
            recursive: true,
            watch: true,
            search: {
                maxResults: 0,
                pageSize: 30,
                fuzzy: true,
                minimumScore: 0
            },
            indexing: {
                maxFiles: 0
            },
            behavior: {
                copyOnEnter: true,
                showPreview: true,
                openSourceShortcut: true,
                openWith: {
                    command: ["kitty", "nvim", "{path}"]
                }
            },
            appearance: {
                windowWidth: 760,
                windowHeight: 560
            }
        }
    }

    function _createDefaultConfig() {
        const config = root._defaultConfig()
        root._apply(config, root.primaryPath)
        console.log("[cheatshell] no config found - writing defaults to " + root.primaryPath
                    + " (edit the file or press Ctrl+, to change folders)")
        bootstrapper.path = root.primaryPath
        bootstrapper.setText(JSON.stringify(config, null, 2) + "\n")
    }

    function _read(view, path) {
        try {
            view.path = path
            const text = view.text()
            if (text === undefined || text === null || text.trim() === "")
                return null
            const parsed = JSON.parse(text)
            if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
                console.warn("[cheatshell] config is not a JSON object: " + path)
                return null
            }
            return parsed
        } catch (e) {
            console.warn("[cheatshell] failed to parse config " + path + ": " + e)
            return null
        }
    }

    function _apply(json, path) {
        if (json === null)
            return false

        root.configFile = path
        root._raw = json

        const dirs = json["directories"]
        if (Array.isArray(dirs)) {
            const expanded = []
            for (const entry of dirs) {
                if (typeof entry !== "string" || entry.trim() === "")
                    continue
                let dir = root._expandHome(entry.trim())
                while (dir.length > 1 && dir.charAt(dir.length - 1) === "/")
                    dir = dir.slice(0, -1)
                expanded.push(dir)
            }
            root.directories = expanded
        } else if (dirs !== undefined) {
            console.warn("[cheatshell] 'directories' must be an array of strings - ignored")
        }

        root.recursive = root._bool(json["recursive"], root.recursive)
        root.watch = root._bool(json["watch"], root.watch)

        const search = json["search"]
        if (search !== null && typeof search === "object" && !Array.isArray(search)) {
            const maxResults = search["maxResults"]
            if (typeof maxResults === "number" && maxResults >= 0)
                root.maxResults = Math.min(1000000, Math.floor(maxResults))
            const pageSize = search["pageSize"]
            if (typeof pageSize === "number" && pageSize > 0)
                root.pageSize = Math.max(1, Math.min(500, Math.floor(pageSize)))
            root.fuzzy = root._bool(search["fuzzy"], root.fuzzy)
            const minScore = search["minimumScore"]
            if (typeof minScore === "number" && minScore >= 0 && minScore <= 1)
                root.minimumScore = minScore
        }

        const indexing = json["indexing"]
        if (indexing !== null && typeof indexing === "object" && !Array.isArray(indexing)) {
            const maxFiles = indexing["maxFiles"]
            if (typeof maxFiles === "number" && maxFiles >= 0)
                root.maxFiles = Math.min(1000000, Math.floor(maxFiles))
        }

        const behavior = json["behavior"]
        if (behavior !== null && typeof behavior === "object" && !Array.isArray(behavior)) {
            root.copyOnEnter = root._bool(behavior["copyOnEnter"], root.copyOnEnter)
            root.showPreview = root._bool(behavior["showPreview"], root.showPreview)
            root.openSourceShortcut = root._bool(behavior["openSourceShortcut"], root.openSourceShortcut)

            const openWith = behavior["openWith"]
            if (openWith !== null && typeof openWith === "object" && !Array.isArray(openWith)) {
                const command = openWith["command"]
                if (Array.isArray(command)) {
                    root.openWithCommand = root._commandArray(command)
                } else if (command !== undefined) {
                    console.warn("[cheatshell] 'behavior.openWith.command' must be an array of strings - ignored")
                }
            }
        }

        const appearance = json["appearance"]
        if (appearance !== null && typeof appearance === "object" && !Array.isArray(appearance)) {
            const w = appearance["windowWidth"]
            const h = appearance["windowHeight"]
            if (typeof w === "number" && w >= 320 && w <= 4096)
                root.windowWidth = Math.floor(w)
            if (typeof h === "number" && h >= 240 && h <= 4096)
                root.windowHeight = Math.floor(h)
        }

        root._warnIfNoDirectories()
        return true
    }

    function _warnIfNoDirectories() {
        if (root.directories.length === 0)
            console.warn("[cheatshell] no Markdown directories configured - add \"directories\" to " + root.primaryPath)
    }

    function _bool(value, fallback) {
        return typeof value === "boolean" ? value : fallback
    }

    function _clampInt(value, minimum, maximum, fallback) {
        const number = Number(value)
        if (!isFinite(number))
            return fallback
        return Math.max(minimum, Math.min(maximum, Math.floor(number)))
    }

    function _ensureObject(parent, key) {
        const value = parent[key]
        if (value === null || typeof value !== "object" || Array.isArray(value))
            parent[key] = ({})
        return parent[key]
    }

    // Sanitises an argv-style command: strings only, no blanks, trimmed.
    function _commandArray(value) {
        const out = []
        if (!Array.isArray(value))
            return out
        for (let i = 0; i < value.length; i++) {
            if (typeof value[i] !== "string")
                continue
            const entry = value[i].trim()
            if (entry !== "")
                out.push(entry)
        }
        return out
    }

    function _expandHome(path) {
        if (path === "~")
            return root.home
        if (path.indexOf("~/") === 0)
            return root.home + path.slice(1)
        return path
    }
}
