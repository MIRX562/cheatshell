import QtQuick
import "../config"

// Full-pane settings editor. Values are held as a draft and only written to
// config.json on Ctrl+S / Save, so Esc can always discard.
Rectangle {
    id: root

    signal closeRequested()
    signal saved()

    property bool dirty: false
    property string message: ""
    property bool _resetting: false

    property string directoriesText: ""
    property bool draftRecursive: true
    property bool draftWatch: true
    property int draftMaxFiles: 0
    property int draftPageSize: 30
    property int draftMaxResults: 0
    property bool draftFuzzy: true
    property real draftMinimumScore: 0
    property bool draftCopyOnEnter: true
    property bool draftShowPreview: true
    property bool draftOpenSourceShortcut: true
    property string draftOpenWithText: ""
    property int draftWindowWidth: 760
    property int draftWindowHeight: 560

    radius: 9
    color: "#17181d"
    border.width: 1
    border.color: "#2b2e3a"
    visible: false

    focus: false

    // Small selectable preset used by the "Open with" row.
    component PresetChip: Rectangle {
        id: chip

        property string label: ""
        property bool selected: false

        signal chosen()

        width: chipText.implicitWidth + 16
        height: 20
        radius: 10
        color: chip.selected ? "#2f4470" : (chipArea.containsMouse ? "#2b303d" : "#232631")
        border.width: 1
        border.color: chip.selected ? "#5578bd" : "#343a4b"

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: chip.selected ? "#dbe6ff" : "#aeb6c8"
            font.pixelSize: 9
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.chosen()
        }
    }

    function open() {
        root.reset()
        flick.contentY = 0
        root.forceActiveFocus()
    }

    function reset() {
        root._resetting = true
        const joined = Config.directories.join("\n")
        root.directoriesText = joined
        dirsEdit.text = joined
        root.draftRecursive = Config.recursive
        root.draftWatch = Config.watch
        root.draftMaxFiles = Config.maxFiles
        root.draftPageSize = Config.pageSize
        root.draftMaxResults = Config.maxResults
        root.draftFuzzy = Config.fuzzy
        root.draftMinimumScore = Config.minimumScore
        root.draftCopyOnEnter = Config.copyOnEnter
        root.draftShowPreview = Config.showPreview
        root.draftOpenSourceShortcut = Config.openSourceShortcut
        root.draftOpenWithText = Config.openWithCommand.join(" ")
        openWithInput.text = root.draftOpenWithText
        root.draftWindowWidth = Config.windowWidth
        root.draftWindowHeight = Config.windowHeight
        root._resetting = false
        root.dirty = false
        root.message = ""
    }

    function _touch() {
        if (!root._resetting)
            root.dirty = true
    }

    function _applyOpenWith(text) {
        root.draftOpenWithText = text
        openWithInput.text = text
        root._touch()
    }

    // Splits a command line into argv, honouring single and double quotes so
    // paths containing spaces can still be expressed.
    function _parseCommand(text) {
        const out = []
        let current = ""
        let quote = ""
        let started = false

        for (let i = 0; i < text.length; i++) {
            const ch = text.charAt(i)
            if (quote !== "") {
                if (ch === quote) {
                    quote = ""
                } else if (ch === "\\" && quote === "\"" && i + 1 < text.length) {
                    i++
                    current += text.charAt(i)
                } else {
                    current += ch
                }
            } else if (ch === "\"" || ch === "'") {
                quote = ch
                started = true
            } else if (ch === " " || ch === "\t" || ch === "\n") {
                if (started || current !== "") {
                    out.push(current)
                    current = ""
                    started = false
                }
            } else {
                current += ch
            }
        }
        if (started || current !== "")
            out.push(current)
        return out
    }

    function save() {
        if (Config.saving)
            return
        const dirs = []
        const lines = root.directoriesText.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            if (line !== "")
                dirs.push(line)
        }
        if (dirs.length === 0) {
            root.message = "Add at least one notes folder"
            return
        }
        root.message = "Saving…"
        const ok = Config.save({
            directories: dirs,
            recursive: root.draftRecursive,
            watch: root.draftWatch,
            maxFiles: root.draftMaxFiles,
            pageSize: root.draftPageSize,
            maxResults: root.draftMaxResults,
            fuzzy: root.draftFuzzy,
            minimumScore: root.draftMinimumScore,
            copyOnEnter: root.draftCopyOnEnter,
            showPreview: root.draftShowPreview,
            openSourceShortcut: root.draftOpenSourceShortcut,
            openWithCommand: root._parseCommand(root.draftOpenWithText),
            windowWidth: root.draftWindowWidth,
            windowHeight: root.draftWindowHeight
        })
        if (!ok && !Config.saving)
            root.message = "Could not save settings"
    }

    Keys.onPressed: (event) => {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        if (event.key === Qt.Key_Escape) {
            root.closeRequested()
            event.accepted = true
        } else if (ctrl && event.key === Qt.Key_S) {
            root.save()
            event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
            flick.contentY = Math.min(flick.contentHeight - flick.height,
                                      flick.contentY + flick.height * 0.8)
            event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
            flick.contentY = Math.max(0, flick.contentY - flick.height * 0.8)
            event.accepted = true
        }
    }

    Connections {
        target: Config

        function onSaved() {
            root.dirty = false
            root.message = "Saved"
            root.saved()
        }

        function onSaveFailed(message) {
            root.message = message
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        Row {
            width: parent.width
            height: 26
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Settings"
                color: "#e3e8f4"
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            Rectangle {
                visible: root.dirty
                anchors.verticalCenter: parent.verticalCenter
                width: dirtyText.implicitWidth + 12
                height: 18
                radius: 9
                color: "#3a2f22"

                Text {
                    id: dirtyText
                    anchors.centerIn: parent
                    text: "unsaved"
                    color: "#d8a657"
                    font.pixelSize: 9
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 200
                text: root.message
                color: root.message === "Saved" ? "#8fce9b" : "#d8a657"
                font.pixelSize: 10
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: "#2b2e3a"
        }

        Item {
            id: scrollArea
            width: parent.width
            height: parent.height - 26 - 10 - 1 - 10 - 34 - 20

            Flickable {
                id: flick
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: form.height
                boundsBehavior: Flickable.StopAtBounds

            Column {
                id: form
                width: flick.width - 8
                spacing: 8

                Text {
                    text: "Sources"
                    color: "#82aaff"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "Notes folders (one per line)"
                    color: "#dbe1ee"
                    font.pixelSize: 12
                }

                Rectangle {
                    width: parent.width
                    height: 92
                    radius: 7
                    color: "#20232d"
                    border.width: 1
                    border.color: dirsEdit.activeFocus ? "#4d5f86" : "#2f3340"

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true
                        contentWidth: width
                        contentHeight: dirsEdit.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        TextEdit {
                            id: dirsEdit
                            width: parent.width
                            color: "#dfe5f2"
                            font.pixelSize: 11
                            selectionColor: "#3d5a99"
                            selectedTextColor: "#f2f5fc"
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            activeFocusOnTab: true
                            text: ""

                            Keys.onTabPressed: (event) => {
                                recursiveToggle.forceActiveFocus()
                                event.accepted = true
                            }
                            Keys.onBacktabPressed: (event) => {
                                root.forceActiveFocus()
                                event.accepted = true
                            }

                            onTextChanged: {
                                root.directoriesText = text
                                root._touch()
                            }
                        }
                    }

                    Text {
                        visible: dirsEdit.text === ""
                        anchors {
                            left: parent.left
                            top: parent.top
                            leftMargin: 11
                            topMargin: 9
                        }
                        text: "~/Notes/commands"
                        color: "#5f6678"
                        font.pixelSize: 11
                    }
                }

                SettingToggle {
                    id: recursiveToggle
                    width: parent.width
                    label: "Recursive"
                    description: "Scan subdirectories for Markdown files"
                    value: root.draftRecursive
                    onToggled: (value) => { root.draftRecursive = value; root._touch() }
                }

                SettingToggle {
                    width: parent.width
                    label: "Watch for changes"
                    description: "Poll for added, edited and deleted notes"
                    value: root.draftWatch
                    onToggled: (value) => { root.draftWatch = value; root._touch() }
                }

                SettingStepper {
                    width: parent.width
                    label: "Maximum indexed files"
                    description: "0 = unlimited · alphabetical cap for very large libraries"
                    value: root.draftMaxFiles
                    from: 0
                    to: 1000000
                    step: 50
                    onValueModified: (value) => { root.draftMaxFiles = value; root._touch() }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#252936"
                }

                Text {
                    text: "Search"
                    color: "#82aaff"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                SettingStepper {
                    width: parent.width
                    label: "Results per page"
                    description: "Rows loaded at a time while scrolling"
                    value: root.draftPageSize
                    from: 1
                    to: 500
                    step: 5
                    onValueModified: (value) => { root.draftPageSize = value; root._touch() }
                }

                SettingStepper {
                    width: parent.width
                    label: "Maximum results"
                    description: "0 = unlimited · hard cap after ranking"
                    value: root.draftMaxResults
                    from: 0
                    to: 1000000
                    step: 50
                    onValueModified: (value) => { root.draftMaxResults = value; root._touch() }
                }

                SettingToggle {
                    width: parent.width
                    label: "Fuzzy matching"
                    description: "Fall back to subsequence matches"
                    value: root.draftFuzzy
                    onToggled: (value) => { root.draftFuzzy = value; root._touch() }
                }

                SettingSlider {
                    width: parent.width
                    label: "Minimum fuzzy score"
                    description: "Higher values make fuzzy matches stricter"
                    value: root.draftMinimumScore
                    onValueModified: (value) => { root.draftMinimumScore = value; root._touch() }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#252936"
                }

                Text {
                    text: "Behavior"
                    color: "#82aaff"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                SettingToggle {
                    width: parent.width
                    label: "Copy on Enter"
                    description: "Enter copies the selected command"
                    value: root.draftCopyOnEnter
                    onToggled: (value) => { root.draftCopyOnEnter = value; root._touch() }
                }

                SettingToggle {
                    width: parent.width
                    label: "Show preview"
                    description: "Display command, examples and notes beside the list"
                    value: root.draftShowPreview
                    onToggled: (value) => { root.draftShowPreview = value; root._touch() }
                }

                SettingToggle {
                    width: parent.width
                    label: "Open source shortcut"
                    description: "Enable Ctrl+O to open the Markdown file"
                    value: root.draftOpenSourceShortcut
                    onToggled: (value) => { root.draftOpenSourceShortcut = value; root._touch() }
                }

                Text {
                    text: "Open with (Ctrl+E)"
                    color: "#dbe1ee"
                    font.pixelSize: 12
                }

                Rectangle {
                    width: parent.width
                    height: 30
                    radius: 7
                    color: "#20232d"
                    border.width: 1
                    border.color: openWithInput.activeFocus ? "#4d5f86" : "#2f3340"

                    TextInput {
                        id: openWithInput
                        anchors.fill: parent
                        anchors.leftMargin: 9
                        anchors.rightMargin: 9
                        verticalAlignment: TextInput.AlignVCenter
                        color: "#dfe5f2"
                        font.pixelSize: 11
                        font.family: "monospace"
                        selectionColor: "#3d5a99"
                        selectedTextColor: "#f2f5fc"
                        activeFocusOnTab: true
                        clip: true
                        text: ""

                        onTextChanged: {
                            root.draftOpenWithText = text
                            root._touch()
                        }
                    }

                    Text {
                        visible: openWithInput.text === ""
                        anchors {
                            left: parent.left
                            leftMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        text: "Disabled — no external editor"
                        color: "#5f6678"
                        font.pixelSize: 11
                    }
                }

                Flow {
                    width: parent.width
                    spacing: 6

                    PresetChip {
                        label: "Neovim"
                        selected: root.draftOpenWithText === "kitty nvim {path}"
                        onChosen: root._applyOpenWith("kitty nvim {path}")
                    }
                    PresetChip {
                        label: "Vim"
                        selected: root.draftOpenWithText === "kitty vim {path}"
                        onChosen: root._applyOpenWith("kitty vim {path}")
                    }
                    PresetChip {
                        label: "VS Code"
                        selected: root.draftOpenWithText === "code --reuse-window {path}"
                        onChosen: root._applyOpenWith("code --reuse-window {path}")
                    }
                    PresetChip {
                        label: "Obsidian"
                        selected: root.draftOpenWithText === "obsidian {path}"
                        onChosen: root._applyOpenWith("obsidian {path}")
                    }
                    PresetChip {
                        label: "Off"
                        selected: root.draftOpenWithText === ""
                        onChosen: root._applyOpenWith("")
                    }
                }

                Text {
                    width: parent.width
                    text: "{path} is replaced with the note path. If it is omitted the path is appended. The command runs directly (no shell)."
                    color: "#6f768a"
                    font.pixelSize: 9
                    wrapMode: Text.Wrap
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#252936"
                }

                Text {
                    text: "Appearance"
                    color: "#82aaff"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                SettingStepper {
                    width: parent.width
                    label: "Window width"
                    description: "Pixels · 320–4096"
                    value: root.draftWindowWidth
                    from: 320
                    to: 4096
                    step: 20
                    onValueModified: (value) => { root.draftWindowWidth = value; root._touch() }
                }

                SettingStepper {
                    width: parent.width
                    label: "Window height"
                    description: "Pixels · 240–4096"
                    value: root.draftWindowHeight
                    from: 240
                    to: 4096
                    step: 20
                    onValueModified: (value) => { root.draftWindowHeight = value; root._touch() }
                }

                Item { width: 1; height: 4 }
            }
            }

            Rectangle {
                visible: flick.contentHeight > flick.height + 1
                width: 4
                radius: 2
                color: "#343a4b"
                anchors {
                    right: parent.right
                    rightMargin: 1
                }
                height: Math.max(24, flick.height * flick.height / flick.contentHeight)
                y: {
                    const maxScroll = flick.contentHeight - flick.height
                    if (maxScroll <= 0)
                        return 0
                    const fraction = Math.max(0, Math.min(1, flick.contentY / maxScroll))
                    return fraction * (flick.height - height)
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 34

            Text {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }
                width: parent.width - 190
                text: Config.configFile !== "" ? Config.configFile : Config.primaryPath
                color: "#5f6678"
                font.pixelSize: 9
                elide: Text.ElideMiddle
            }

            Row {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                spacing: 8

                Rectangle {
                    width: 64
                    height: 26
                    radius: 6
                    color: revert.containsMouse ? "#2b303d" : "#232631"
                    border.width: 1
                    border.color: "#343a4b"

                    Text {
                        anchors.centerIn: parent
                        text: "Revert"
                        color: "#aeb6c8"
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: revert
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.reset()
                    }
                }

                Rectangle {
                    width: 82
                    height: 26
                    radius: 6
                    color: Config.saving ? "#2b3a5a" : (saveArea.containsMouse ? "#3f62a8" : "#35538f")
                    border.width: 1
                    border.color: "#5578bd"

                    Text {
                        anchors.centerIn: parent
                        text: Config.saving ? "Saving…" : "Save  Ctrl+S"
                        color: "#eef2fb"
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: saveArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !Config.saving
                        onClicked: root.save()
                    }
                }
            }
        }
    }
}
