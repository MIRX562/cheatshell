import QtQuick

// Labelled 0..1 slider used for the fuzzy minimum score.
Item {
    id: root

    property string label: ""
    property string description: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 0.05

    signal valueModified(real value)

    implicitHeight: 46
    activeFocusOnTab: true

    function _emit(next) {
        const clamped = Math.max(root.from, Math.min(root.to, next))
        const rounded = Math.round(clamped / root.step) * root.step
        root.valueModified(Math.round(rounded * 100) / 100)
    }

    Keys.onLeftPressed: root._emit(root.value - root.step)
    Keys.onRightPressed: root._emit(root.value + root.step)

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
            right: controls.left
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

    Row {
        id: controls
        anchors {
            right: parent.right
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        spacing: 8

        Rectangle {
            id: slider
            width: 150
            height: 20
            color: "transparent"

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: "#343948"
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * ((root.value - root.from) / (root.to - root.from))
                height: 4
                radius: 2
                color: "#82aaff"
            }

            Rectangle {
                width: 12
                height: 12
                radius: 6
                y: (parent.height - height) / 2
                x: Math.max(0, Math.min(parent.width - width,
                      parent.width * ((root.value - root.from) / (root.to - root.from)) - width / 2))
                color: "#eef2fb"
                border.width: 2
                border.color: "#82aaff"
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => root._emit(root.from + (root.to - root.from) * (mouse.x / width))
                onPositionChanged: (mouse) => {
                    if (pressed)
                        root._emit(root.from + (root.to - root.from) * (mouse.x / width))
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            text: Math.round(root.value * 100) + "%"
            color: "#9aa2b6"
            font.pixelSize: 10
            horizontalAlignment: Text.AlignRight
        }
    }
}
