pragma Singleton
import Quickshell

// Thin wrapper around Quickshell's clipboard so the UI has one place for
// copying and can react to copy events (toast feedback).
Singleton {
    id: root

    signal copied(string text)

    property string lastCopied: ""

    function copy(text) {
        const value = text === undefined || text === null ? "" : String(text)
        if (value === "") {
            console.warn("[cheatshell] copy skipped: empty text")
            return false
        }
        Quickshell.clipboardText = value
        root.lastCopied = value
        root.copied(value)
        return true
    }
}
