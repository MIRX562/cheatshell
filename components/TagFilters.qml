import QtQuick

// Horizontal, wrapping list of tag toggle chips.
Item {
    id: root

    signal toggleRequested(string tag)

    property var tags: []
    property var activeTags: []

    implicitHeight: flow.height

    Flow {
        id: flow
        width: parent.width
        spacing: 6

        Repeater {
            model: root.tags

            delegate: Rectangle {
                required property string modelData

                readonly property bool active: root.activeTags.indexOf(modelData) >= 0

                width: chipText.implicitWidth + 18
                height: 22
                radius: 11
                color: active ? "#34456b" : "#22252f"
                border.width: 1
                border.color: active ? "#82aaff" : "#313543"

                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: "#" + modelData
                    color: parent.active ? "#b7cbff" : "#8f97ab"
                    font.pixelSize: 10
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleRequested(modelData)
                }
            }
        }
    }
}
