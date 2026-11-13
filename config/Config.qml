pragma Singleton
import Quickshell
import Quickshell.Io

// Loads ~/.config/cheatshell/config.json (falling back to the legacy
// ~/.config/cmdnotes/config.json). Every field is optional; missing or
// malformed values fall back to the defaults below.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string primaryPath: root.home + "/.config/cheatshell/config.json"
    readonly property string fallbackPath: root.home + "/.config/cmdnotes/config.json"

    property string configFile: ""

    // Defaults - kept in sync with the documented config format.
    property var directories: []
    property bool recursive: true
    property bool watch: true
    property int maxResults: 30
    property bool fuzzy: true
    property real minimumScore: 0
    property bool copyOnEnter: true
    property bool showPreview: true
    property bool openSourceShortcut: true
    property int windowWidth: 760
    property int windowHeight: 560

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

    // Re-reads the configuration file synchronously. Used at startup (before
    // the window is built) and by the manual refresh action.
    function load() {
        let applied = root._apply(root._read(primaryView, root.primaryPath), root.primaryPath)
        if (!applied)
            applied = root._apply(root._read(fallbackView, root.fallbackPath), root.fallbackPath)

        if (!applied) {
            console.warn("[cheatshell] no readable config found at " + root.primaryPath
                         + " or " + root.fallbackPath + " - using defaults")
            root._warnIfNoDirectories()
        }
    }

    function reload() {
        root.load()
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
            if (typeof maxResults === "number" && maxResults > 0)
                root.maxResults = Math.floor(maxResults)
            root.fuzzy = root._bool(search["fuzzy"], root.fuzzy)
            const minScore = search["minimumScore"]
            if (typeof minScore === "number" && minScore >= 0 && minScore <= 1)
                root.minimumScore = minScore
        }

        const behavior = json["behavior"]
        if (behavior !== null && typeof behavior === "object" && !Array.isArray(behavior)) {
            root.copyOnEnter = root._bool(behavior["copyOnEnter"], root.copyOnEnter)
            root.showPreview = root._bool(behavior["showPreview"], root.showPreview)
            root.openSourceShortcut = root._bool(behavior["openSourceShortcut"], root.openSourceShortcut)
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

    function _expandHome(path) {
        if (path === "~")
            return root.home
        if (path.indexOf("~/") === 0)
            return root.home + path.slice(1)
        return path
    }
}
