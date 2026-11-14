import QtQuick

// Search input. Emits semantic intent signals so keyboard handling stays out
// of the window code; Up/Down/Enter/Escape never leak into text editing.
Rectangle {
    id: root

    signal textEdited(string text)
    signal moveRequested(int delta)
    signal submitRequested(bool example)
    signal openSourceRequested()
    signal openEditorRequested()
    signal refreshRequested()
    signal settingsRequested()
    signal dismissRequested()

    function focusInput() {
        input.forceActiveFocus()
    }

    radius: 10
    color: "#232631"
    border.width: 1
    border.color: input.activeFocus ? "#4d5f86" : "#2b2e3a"

    Behavior on border.color {
        ColorAnimation { duration: 120 }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: input.forceActiveFocus()
    }

    Text {
        id: prompt
        anchors {
            left: parent.left
            leftMargin: 14
            verticalCenter: parent.verticalCenter
        }
        text: "❯"
        color: "#82aaff"
        font.pixelSize: 16
    }

    TextInput {
        id: input
        anchors {
            left: prompt.right
            leftMargin: 10
            right: parent.right
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }
        color: "#e3e8f4"
        font.pixelSize: 15
        selectionColor: "#3d5a99"
        selectedTextColor: "#f2f5fc"
        clip: true

        onTextEdited: root.textEdited(input.text)

        Keys.onPressed: (event) => {
            const ctrl = (event.modifiers & Qt.ControlModifier) !== 0

            if (event.key === Qt.Key_Up) {
                root.moveRequested(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                root.moveRequested(1)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.submitRequested(ctrl)
                event.accepted = true
            } else if (event.key === Qt.Key_O && ctrl) {
                root.openSourceRequested()
                event.accepted = true
            } else if (event.key === Qt.Key_E && ctrl) {
                root.openEditorRequested()
                event.accepted = true
            } else if (event.key === Qt.Key_R && ctrl) {
                root.refreshRequested()
                event.accepted = true
            } else if (event.key === Qt.Key_Comma && ctrl) {
                root.settingsRequested()
                event.accepted = true
            } else if (event.key === Qt.Key_Q && ctrl) {
                Qt.quit()
                event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                root.dismissRequested()
                event.accepted = true
            }
        }
    }

    Text {
        anchors {
            left: prompt.right
            leftMargin: 10
            verticalCenter: parent.verticalCenter
        }
        visible: input.text === ""
        text: "Search commands…  type tag:name to filter"
        color: "#6f768a"
        font: input.font
    }
}
