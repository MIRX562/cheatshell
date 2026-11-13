pragma Singleton
import Quickshell

// In-memory index of parsed command entries. Entries are keyed by absolute
// file path so the scanner can update/remove single files.
Singleton {
    id: root

    property var entries: []
    property var tags: []
    property int count: 0

    // path -> { mtime, entry }
    property var _state: ({})
    property bool _batching: false

    function beginBatch() {
        root._batching = true
    }

    function endBatch() {
        root._batching = false
        root._commit()
    }

    function put(path, mtime, entry) {
        if (!entry)
            return false
        root._state[path] = { mtime: mtime, entry: entry }
        if (!root._batching)
            root._commit()
        return true
    }

    function remove(path) {
        if (!Object.prototype.hasOwnProperty.call(root._state, path))
            return false
        delete root._state[path]
        if (!root._batching)
            root._commit()
        return true
    }

    function clear() {
        root._state = ({})
        root._commit()
    }

    function paths() {
        return Object.keys(root._state)
    }

    function mtimeOf(path) {
        const record = root._state[path]
        return record ? record.mtime : -1
    }

    function _commit() {
        const list = []
        for (const path in root._state)
            list.push(root._state[path].entry)

        list.sort((a, b) => {
            if (a.sTitle < b.sTitle) return -1
            if (a.sTitle > b.sTitle) return 1
            return 0
        })

        root.entries = list
        root.count = list.length

        const seen = ({})
        const allTags = []
        for (let i = 0; i < list.length; i++) {
            const itemTags = list[i].tags
            for (let j = 0; j < itemTags.length; j++) {
                const tag = itemTags[j]
                if (seen[tag] === true)
                    continue
                seen[tag] = true
                allTags.push(tag)
            }
        }
        allTags.sort()
        root.tags = allTags
    }
}
