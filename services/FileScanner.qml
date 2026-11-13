pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "../models"

// Discovery + incremental indexing.
//
// Quickshell 0.3.2 has no directory-watching API, so discovery uses `find`
// through Quickshell.Io.Process (native process API, no daemon). Changes are
// detected by comparing paths and mtimes against the index; files are only
// re-read and re-parsed when their mtime changed. A rename is seen as a
// removal plus an addition. Directory scans are cheap (listing only); file
// contents are only read for changed files. Polling is debounced and skipped
// while a scan/index pass is still running.
Singleton {
    id: root

    property string status: "starting"
    property bool scanning: false
    property int pendingCount: 0

    readonly property int maxConcurrentLoads: 4

    // Per-scan state
    property var _found: ({})      // path -> mtime
    property var _dirQueue: []
    property var _okDirs: []       // directories that were scanned successfully
    property int _dirLines: 0
    property bool _dirActive: false

    // Indexing state
    property var _parseQueue: []
    property bool _rescanPending: false
    property bool _changedThisScan: false
    property bool _batchStarted: false

    readonly property var _workers: [worker0, worker1, worker2, worker3]

    Process {
        id: findProc
        stdout: SplitParser {
            onRead: (data) => root._onFindLine(data)
        }
        stderr: SplitParser {
            onRead: (data) => {
                if (data.trim() !== "")
                    console.warn("[cheatshell] find: " + data)
            }
        }
        onExited: (exitCode, exitStatus) => root._onFindDone(exitCode)
    }

    // Four reusable readers; a file is only re-read when its mtime changed.
    FileView {
        id: worker0
        printErrors: false
        property bool busy: false
        property var job: null
        property double startedAt: 0
        onLoaded: root._workerDone(worker0, null)
        onLoadFailed: (error) => root._workerDone(worker0, error)
    }

    FileView {
        id: worker1
        printErrors: false
        property bool busy: false
        property var job: null
        property double startedAt: 0
        onLoaded: root._workerDone(worker1, null)
        onLoadFailed: (error) => root._workerDone(worker1, error)
    }

    FileView {
        id: worker2
        printErrors: false
        property bool busy: false
        property var job: null
        property double startedAt: 0
        onLoaded: root._workerDone(worker2, null)
        onLoadFailed: (error) => root._workerDone(worker2, error)
    }

    FileView {
        id: worker3
        printErrors: false
        property bool busy: false
        property var job: null
        property double startedAt: 0
        onLoaded: root._workerDone(worker3, null)
        onLoadFailed: (error) => root._workerDone(worker3, error)
    }

    Timer {
        id: pollTimer
        interval: 8000
        repeat: true
        running: Config.watch
        onTriggered: root.requestScan()
    }

    Timer {
        id: scanDelay
        interval: 150
        onTriggered: root._startScan()
    }

    // Guards against a reader whose completion signal never arrives (e.g. a
    // file removed between listing and opening). A stuck reader must never
    // block indexing forever.
    Timer {
        id: loadWatchdog
        interval: 5000
        repeat: true
        running: root._activeLoads() > 0
        onTriggered: root._checkStuckReaders()
    }

    Component.onCompleted: root.refresh(true)

    // Manual refresh: re-reads config (directories may have changed) and
    // schedules an incremental scan.
    function refresh(rereadConfig) {
        if (rereadConfig === undefined)
            rereadConfig = true
        if (rereadConfig) {
            try {
                Config.reload()
            } catch (e) {
                console.warn("[cheatshell] config reload failed: " + e)
            }
        }
        root.requestScan()
    }

    // Safe to call often: concurrent requests are coalesced into one follow-up
    // scan.
    function requestScan() {
        if (root.scanning) {
            root._rescanPending = true
            return
        }
        scanDelay.restart()
    }

    function _startScan() {
        // Never overlap scans; a find process still running means a scan is
        // already in progress (or its exit has not been handled yet).
        if (root.scanning || findProc.running)
            return

        root.scanning = true
        root._found = ({})
        root._okDirs = []
        root._dirQueue = Config.directories.slice()
        root.status = "scanning"

        if (root._dirQueue.length === 0) {
            console.warn("[cheatshell] nothing to scan: no directories configured")
            root._finishScan()
            return
        }
        root._nextDir()
    }

    function _nextDir() {
        if (!root.scanning)
            return
        if (root._dirQueue.length === 0) {
            root._finishScan()
            return
        }

        const dir = root._dirQueue[0]
        root._dirLines = 0
        root._dirActive = true

        const cmd = [
            "find", dir, "-type", "f", "-name", "*.md",
            "-not", "-path", "*/.git/*",
            "-not", "-path", "*/.obsidian/*",
            "-printf", "%T@\\t%p\\n"
        ]
        if (!Config.recursive)
            cmd.splice(2, 0, "-maxdepth", "1")

        root.status = "scanning " + dir
        findProc.exec(cmd)
    }

    function _onFindLine(data) {
        if (!root._dirActive)
            return
        const tab = data.indexOf("\t")
        if (tab <= 0)
            return
        const mtime = parseFloat(data.slice(0, tab))
        const path = data.slice(tab + 1)
        if (!path || isNaN(mtime))
            return
        root._dirLines++
        root._found[path] = mtime
    }

    function _onFindDone(exitCode) {
        // Ignore duplicate/stale exit notifications.
        if (!root._dirActive)
            return
        root._dirActive = false

        const dir = root._dirQueue.shift()
        if (dir === undefined)
            return

        if (exitCode !== 0) {
            console.warn("[cheatshell] directory scan failed (" + exitCode + "): " + dir)
        } else {
            root._okDirs.push(dir)
            if (root._dirLines === 0)
                console.log("[cheatshell] no markdown files in " + dir)
        }
        root._nextDir()
    }

    function _finishScan() {
        // 1. Drop entries whose files disappeared (deletions and renames).
        //    Only do this for directories that were read successfully, so a
        //    permissions error or unmounted drive never wipes the index.
        const known = CommandModel.paths()
        for (let i = 0; i < known.length; i++) {
            const path = known[i]
            if (Object.prototype.hasOwnProperty.call(root._found, path))
                continue
            if (root._shouldRemove(path)) {
                CommandModel.remove(path)
                root._changedThisScan = true
                console.log("[cheatshell] removed from index: " + path)
            }
        }

        // 2. Queue only new or modified files for (re)parsing.
        const queue = []
        for (const path in root._found) {
            const mtime = root._found[path]
            if (CommandModel.mtimeOf(path) !== mtime)
                queue.push({ path: path, mtime: mtime })
        }

        if (queue.length > 0)
            root._changedThisScan = true
        root._parseQueue = root._parseQueue.concat(queue)

        if (queue.length > 5 && !root._batchStarted) {
            CommandModel.beginBatch()
            root._batchStarted = true
        }

        if (root._parseQueue.length === 0) {
            root._completeScan()
            return
        }
        root._pump()
    }

    function _shouldRemove(path) {
        // Keep entries from directories that failed to scan this round.
        for (let i = 0; i < root._okDirs.length; i++) {
            if (path.indexOf(root._okDirs[i] + "/") === 0)
                return true
        }
        // Remove entries from directories that are no longer configured.
        const dirs = Config.directories
        for (let i = 0; i < dirs.length; i++) {
            if (path.indexOf(dirs[i] + "/") === 0)
                return false
        }
        return true
    }

    function _pump() {
        while (root._parseQueue.length > 0 && root._activeLoads() < root.maxConcurrentLoads) {
            let worker = null
            for (let i = 0; i < root._workers.length; i++) {
                if (!root._workers[i].busy) {
                    worker = root._workers[i]
                    break
                }
            }
            if (worker === null)
                break

            const job = root._parseQueue.shift()
            worker.busy = true
            worker.job = job
            worker.startedAt = Date.now()

            if (worker.path === job.path)
                worker.reload()
            else
                worker.path = job.path
        }

        root.pendingCount = root._parseQueue.length + root._activeLoads()

        if (root._parseQueue.length === 0 && root._activeLoads() === 0) {
            root._completeScan()
            return
        }
        root.status = "indexing · " + root.pendingCount + " file(s) left"
    }

    function _workerDone(worker, error) {
        if (!worker.busy)
            return

        const job = worker.job
        let text = ""
        if (!error) {
            try {
                text = worker.text()
            } catch (e) {
                error = e
            }
        }

        worker.busy = false
        worker.job = null

        if (job !== null) {
            if (error)
                console.warn("[cheatshell] could not read " + job.path + ": " + error)
            else {
                const entry = MarkdownParser.parse(job.path, text)
                if (entry)
                    CommandModel.put(job.path, job.mtime, entry)
                else
                    console.log("[cheatshell] skipped unparsable file: " + job.path)
            }
        }

        // Deferred on purpose: starting the next load inside the FileView's
        // own completion callback makes the previous operation get dropped.
        Qt.callLater(root._pump)
    }

    function _checkStuckReaders() {
        const now = Date.now()
        let recovered = false
        for (let i = 0; i < root._workers.length; i++) {
            const worker = root._workers[i]
            if (!worker.busy || now - worker.startedAt < 15000)
                continue
            if (worker.job !== null)
                console.warn("[cheatshell] giving up on unreadable file: " + worker.job.path)
            worker.busy = false
            worker.job = null
            recovered = true
        }
        if (recovered)
            root._pump()
    }

    function _activeLoads() {
        let busy = 0
        for (let i = 0; i < root._workers.length; i++) {
            if (root._workers[i].busy)
                busy++
        }
        return busy
    }

    function _completeScan() {
        if (!root.scanning)
            return
        root.scanning = false
        root.pendingCount = 0

        if (root._batchStarted) {
            CommandModel.endBatch()
            root._batchStarted = false
        }

        root.status = CommandModel.count + " entries indexed"
        if (root._changedThisScan) {
            console.log("[cheatshell] index: " + CommandModel.count + " entries from "
                        + Object.keys(root._found).length + " file(s)")
            root._changedThisScan = false
        }

        if (root._rescanPending) {
            root._rescanPending = false
            scanDelay.restart()
        }
    }
}
