import QtQuick

// One row in the result list.
Item {
    id: root

    required property var modelData
    required property int index

    readonly property bool selected: ListView.isCurrentItem

    implicitHeight: 64

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: root.selected ? "#262a36" : (pointer.containsMouse ? "#1e2029" : "transparent")

        Behavior on color {
            ColorAnimation { duration: 90 }
        }

        Rectangle {
            visible: root.selected
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
                leftMargin: 7
                topMargin: 9
                bottomMargin: 9
            }
            width: 3
            radius: 2
            color: "#82aaff"
        }
    }

    Column {
        anchors {
            left: parent.left
            right: meta.left
            top: parent.top
            bottom: parent.bottom
            leftMargin: 18
            rightMargin: 10
            topMargin: 9
            bottomMargin: 8
        }
        spacing: 3

        Text {
            width: parent.width
            text: root.modelData.title
            color: root.selected ? "#eef2fb" : "#d5dae6"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.modelData.description !== ""
            text: root.modelData.description
            color: "#8a90a3"
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        Row {
            spacing: 4

            Repeater {
                model: root.modelData.tags.slice(0, 3)

                delegate: Rectangle {
                    required property string modelData

                    width: miniText.implicitWidth + 10
                    height: 16
                    radius: 8
                    color: "#232838"

                    Text {
                        id: miniText
                        anchors.centerIn: parent
                        text: "#" + modelData
                        color: "#8ba3d9"
                        font.pixelSize: 9
                    }
                }
            }
        }
    }

    Text {
        id: meta
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: 10
            bottomMargin: 8
        }
        width: Math.min(implicitWidth, 170)
        text: root.modelData.filename
        color: "#5f6678"
        font.pixelSize: 9
        elide: Text.ElideMiddle
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: root.ListView.view.selectRequested(root.index)
        onDoubleClicked: root.ListView.view.copyRequested(root.modelData)
    }
}
