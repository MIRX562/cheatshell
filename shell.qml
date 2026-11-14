import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "config"
import "models"
import "services"
import "components"

// cheatshell - keyboard-driven command & snippet launcher.
// Launch with:  quickshell -p ~/.config/quickshell/cheatshell
ShellRoot {
    id: shell

    Loader {
        id: uiLoader
        active: false
        sourceComponent: launcherComponent
    }

    Component {
        id: launcherComponent
        LauncherWindow {}
    }

    // Decorationless overlay centered on screen. PanelWindow is platform
    // independent; on Wayland it is backed by wlr-layer-shell.
    component LauncherWindow: PanelWindow {
        id: win

        color: "#17181d"
        implicitWidth: Config.windowWidth
        implicitHeight: Config.windowHeight
        visible: true

        // All four anchors + equal margins == a centered, fixed-size window.
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        margins {
            top: Math.round(((win.screen ? win.screen.height : 0) - win.implicitHeight) / 2)
            bottom: Math.round(((win.screen ? win.screen.height : 0) - win.implicitHeight) / 2)
            left: Math.round(((win.screen ? win.screen.width : 0) - win.implicitWidth) / 2)
            right: Math.round(((win.screen ? win.screen.width : 0) - win.implicitWidth) / 2)
        }

        aboveWindows: true
        focusable: true
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "cheatshell"

        // Contrasting slate frame drawn around the whole launcher surface.
        Rectangle {
            id: frame
            anchors.fill: parent
            color: "#17181d"
            radius: 10
            border.width: 2
            border.color: "#64748b"
            z: -1
        }

        property string query: ""
        property string pendingQuery: ""
        property var activeTags: []
        property int selectedIndex: 0
        property bool settingsOpen: false

        // Number of ranked matches currently exposed to the list. Growing this
        // window is what makes the list lazy; ListView virtualises the rows.
        property int resultWindow: Config.pageSize
        property var searchResult: SearchEngine.search(win.query, win.activeTags, win.resultWindow)
        property var results: win.searchResult.entries
        property int totalMatches: win.searchResult.total

        property var selectedEntry: win.results.length > 0
                                     ? win.results[Math.min(win.selectedIndex, win.results.length - 1)]
                                     : null

        onResultsChanged: Qt.callLater(win._resultsChanged)
        onVisibleChanged: {
            if (win.visible) {
                win.settingsOpen = false
                searchBar.focusInput()
                FileScanner.requestScan()
            }
        }

        Component.onCompleted: searchBar.focusInput()

        function _resultsChanged() {
            if (win.results.length === 0) {
                win.selectedIndex = 0
                return
            }
            if (win.selectedIndex >= win.results.length)
                win.selectedIndex = win.results.length - 1
            if (win.selectedIndex < 0)
                win.selectedIndex = 0
            try {
                list.positionViewAtIndex(win.selectedIndex, ListView.Contain)
            } catch (e) {
                // list not ready yet; selection is still correct
            }
        }

        function moveSelection(delta) {
            if (win.results.length === 0)
                return

            // At the last loaded row: pull the next page, then step into it.
            if (delta > 0 && win.selectedIndex >= win.results.length - 1
                    && win.results.length < win.totalMatches) {
                win.loadMore()
                Qt.callLater(win._stepAfterLoad)
                return
            }

            if (delta > 0 && win.selectedIndex >= win.results.length - 4)
                win.loadMore()

            win.selectedIndex = (win.selectedIndex + delta + win.results.length) % win.results.length
            list.positionViewAtIndex(win.selectedIndex, ListView.Contain)
        }

        function _stepAfterLoad() {
            if (win.selectedIndex >= win.results.length - 1)
                return
            win.selectedIndex++
            list.positionViewAtIndex(win.selectedIndex, ListView.Contain)
        }

        function loadMore() {
            if (win.results.length >= win.totalMatches)
                return
            win.resultWindow = Math.min(win.totalMatches,
                                        win.resultWindow + Config.pageSize)
        }

        function openSettings() {
            win.settingsOpen = true
            settingsPane.open()
        }

        function closeSettings() {
            win.settingsOpen = false
            searchBar.focusInput()
        }

        function settingsSaved() {
            win.settingsOpen = false
            win.resultWindow = Config.pageSize
            searchBar.focusInput()
            FileScanner.refresh(false)
            win.toast("Settings saved")
        }

        function copyEntry(entry) {
            if (!entry)
                return
            if (entry.command === "") {
                win.toast("This note has no command section")
                return
            }
            Clipboard.copy(entry.command)
        }

        function copyPrimary() {
            if (!Config.copyOnEnter)
                return
            win.copyEntry(win.selectedEntry)
        }

        function copyExample() {
            const entry = win.selectedEntry
            if (!entry)
                return
            if (entry.examples.length === 0) {
                win.toast("This note has no example")
                return
            }
            Clipboard.copy(entry.examples[0])
        }

        function openSource() {
            if (!Config.openSourceShortcut)
                return
            const entry = win.selectedEntry
            if (!entry)
                return
            Quickshell.execDetached(["xdg-open", entry.path])
            win.toast("Opened " + entry.filename)
        }

        // Launches the configured external editor. The command is an argv array,
        // so no shell is involved and note paths are never re-interpreted.
        function openInEditor() {
            const entry = win.selectedEntry
            if (!entry) {
                win.toast("Nothing selected")
                return
            }

            const configured = Config.openWithCommand
            if (!configured || configured.length === 0) {
                win.toast("No external editor configured")
                return
            }

            const argv = []
            let replaced = false
            for (let i = 0; i < configured.length; i++) {
                const arg = String(configured[i])
                if (arg.indexOf("{path}") >= 0) {
                    argv.push(arg.split("{path}").join(entry.path))
                    replaced = true
                } else {
                    argv.push(arg)
                }
            }
            if (!replaced)
                argv.push(entry.path)

            Quickshell.execDetached(argv)
            win.toast("Opening in " + win._editorLabel(argv))
        }

        function _editorLabel(argv) {
            const names = {
                "nvim": "Neovim", "vim": "Vim", "vi": "Vim", "code": "VS Code",
                "codium": "VSCodium", "obsidian": "Obsidian",
                "kitty": "kitty", "alacritty": "Alacritty",
                "ghostty": "Ghostty", "foot": "foot", "wezterm": "WezTerm"
            }
            for (let i = 0; i < argv.length; i++) {
                const base = String(argv[i]).split("/").pop()
                if (names[base] !== undefined && i > 0)
                    return names[base]
            }
            if (argv.length === 0)
                return "editor"
            const first = String(argv[0]).split("/").pop()
            return names[first] !== undefined ? names[first] : first
        }

        function refresh() {
            FileScanner.refresh(true)
            win.resultWindow = Config.pageSize
            win.toast("Refreshing index…")
        }

        function toggleTag(tag) {
            const next = win.activeTags.slice()
            const index = next.indexOf(tag)
            if (index >= 0)
                next.splice(index, 1)
            else
                next.push(tag)
            win.activeTags = next
            win.selectedIndex = 0
            win.resultWindow = Config.pageSize
        }

        function toast(message) {
            toastLabel.text = message
            toast.shown = true
            toastTimer.restart()
        }

        Column {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            SearchBar {
                id: searchBar
                width: content.width
                height: 44

                onTextEdited: (text) => {
                    win.pendingQuery = text
                    win.selectedIndex = 0
                    win.resultWindow = Config.pageSize
                    searchDebounce.restart()
                }
                onMoveRequested: (delta) => win.moveSelection(delta)
                onSubmitRequested: (example) => example ? win.copyExample() : win.copyPrimary()
                onOpenSourceRequested: win.openSource()
                onOpenEditorRequested: win.openInEditor()
                onRefreshRequested: win.refresh()
                onSettingsRequested: win.openSettings()
                onDismissRequested: win.visible = false
            }

            TagFilters {
                id: tagFilters
                width: content.width
                height: tagFilters.implicitHeight > 0 ? Math.min(tagFilters.implicitHeight, 54) : 0
                clip: true
                tags: CommandModel.tags
                activeTags: win.activeTags
                onToggleRequested: (tag) => win.toggleTag(tag)
            }

            Row {
                id: mainRow
                width: content.width
                height: content.height - searchBar.height - tagFilters.height - footer.height - content.spacing * 3
                spacing: 10

                CommandList {
                    id: list
                    width: Config.showPreview ? Math.round(mainRow.width * 0.52) : mainRow.width
                    height: mainRow.height
                    model: win.results
                    currentIndex: win.selectedIndex
                    onSelectRequested: (index) => {
                        win.selectedIndex = index
                        searchBar.focusInput()
                    }
                    onCopyRequested: (entry) => win.copyEntry(entry)
                    onLoadMoreRequested: win.loadMore()
                }

                CommandPreview {
                    visible: Config.showPreview
                    width: Config.showPreview ? mainRow.width - list.width - mainRow.spacing : 0
                    height: mainRow.height
                    entry: win.selectedEntry
                    onCopyText: (text) => Clipboard.copy(text)
                }
            }

            Item {
                id: footer
                width: content.width
                height: 16

                Text {
                    id: footerHelp
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - footerStats.implicitWidth - 40
                    text: "Enter copy  ·  Ctrl+Enter example  ·  Ctrl+O open  ·  Ctrl+E editor  ·  Ctrl+R refresh  ·  Ctrl+, settings  ·  Esc close"
                    color: "#5f6678"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                Text {
                    id: gear
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⚙"
                    color: gearMouse.containsMouse ? "#c7cede" : "#7c8499"
                    font.pixelSize: 12

                    MouseArea {
                        id: gearMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.openSettings()
                    }
                }

                Text {
                    id: footerStats
                    anchors.right: gear.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.results.length + " of " + win.totalMatches + "  ·  " + FileScanner.status
                    color: "#5f6678"
                    font.pixelSize: 10
                }
            }
        }

        SettingsPane {
            id: settingsPane
            anchors.fill: parent
            anchors.margins: 12
            z: 10
            visible: win.settingsOpen
            onCloseRequested: win.closeSettings()
            onSaved: win.settingsSaved()
        }

        Rectangle {
            id: toast
            z: 20
            property bool shown: false

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 48
            width: toastLabel.implicitWidth + 26
            height: 32
            radius: 8
            color: "#262c3b"
            border.width: 1
            border.color: "#3f4a63"
            opacity: shown ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 140 }
            }

            Text {
                id: toastLabel
                anchors.centerIn: parent
                text: ""
                color: "#dbe3f4"
                font.pixelSize: 11
            }

            Timer {
                id: toastTimer
                interval: 1700
                onTriggered: toast.shown = false
            }
        }

        Timer {
            id: searchDebounce
            interval: 120
            onTriggered: win.query = win.pendingQuery
        }

        Connections {
            target: Clipboard
            function onCopied(text) {
                const short = text.length > 48 ? text.slice(0, 48) + "…" : text
                win.toast("Copied: " + short)
            }
        }

        IpcHandler {
            target: "cheatshell"

            function toggle(): void {
                win.visible = !win.visible
                if (win.visible)
                    searchBar.focusInput()
            }

            function open(): void {
                win.visible = true
                searchBar.focusInput()
            }

            function hide(): void {
                win.visible = false
            }

            function settings(): void {
                win.visible = true
                win.openSettings()
            }

            function toggleSettings(): void {
                win.visible = true
                if (win.settingsOpen)
                    win.closeSettings()
                else
                    win.openSettings()
            }

            function quit(): void {
                Qt.quit()
            }
        }
    }

    Component.onCompleted: {
        // Load the config synchronously before the window is built so the
        // configured size applies without a visible resize.
        Config.load()
        uiLoader.active = true
    }
}
