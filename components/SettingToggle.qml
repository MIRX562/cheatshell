import QtQuick

// Labelled on/off switch used by the settings pane.
Item {
    id: root

    property string label: ""
    property string description: ""
    property bool value: false

    signal toggled(bool value)

    implicitHeight: 46
    activeFocusOnTab: true

    Keys.onSpacePressed: root.toggled(!root.value)
    Keys.onReturnPressed: root.toggled(!root.value)
    Keys.onEnterPressed: root.toggled(!root.value)

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: root.activeFocus ? "#202431" : "transparent"
        border.width: root.activeFocus ? 1 : 0
        border.color: "#3f4d6b"
    }

    Column {
        anchors {
            left: parent.left
            leftMargin: 10
            right: toggle.left
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }
        spacing: 2

        Text {
            width: parent.width
            text: root.label
            color: "#dbe1ee"
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.description !== ""
            text: root.description
            color: "#6f768a"
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }

    Rectangle {
        id: toggle
        anchors {
            right: parent.right
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        width: 38
        height: 21
        radius: 11
        color: root.value ? "#3d5a99" : "#343948"
        border.width: 1
        border.color: root.value ? "#82aaff" : "#444a5c"

        Behavior on color {
            ColorAnimation { duration: 100 }
        }

        Rectangle {
            width: 15
            height: 15
            radius: 8
            y: 3
            x: root.value ? parent.width - width - 3 : 3
            color: root.value ? "#eef2fb" : "#8a90a3"

            Behavior on x {
                NumberAnimation { duration: 100 }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.value)
    }
}
