import QtQuick

// Detail panel for the highlighted entry.
Rectangle {
    id: root

    signal copyText(string text)

    property var entry: null

    readonly property bool hasEntry: root.entry !== null && root.entry !== undefined

    color: "#1f2129"
    radius: 10
    border.width: 1
    border.color: "#2b2e3a"
    clip: true

    component CodeBlock: Rectangle {
        id: block

        property string code: ""

        color: "#121318"
        radius: 6
        border.width: 1
        border.color: hoverArea.containsMouse ? "#4a5a7d" : "#2a2d38"
        implicitHeight: codeText.implicitHeight + 16

        Behavior on border.color {
            ColorAnimation { duration: 100 }
        }

        Text {
            id: codeText
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 8
            }
            text: block.code
            color: "#93d9a7"
            font.family: "monospace"
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        Rectangle {
            visible: hoverArea.containsMouse
            anchors {
                right: parent.right
                top: parent.top
                rightMargin: 5
                topMargin: 5
            }
            width: 26
            height: 16
            radius: 4
            color: "#2a3040"

            Text {
                anchors.centerIn: parent
                text: "copy"
                color: "#a9c1ff"
                font.pixelSize: 8
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.copyText(block.code)
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 14
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: flick.width
            spacing: 10

            Text {
                width: parent.width
                visible: root.hasEntry
                text: root.hasEntry ? root.entry.title : ""
                color: "#eef2fb"
                font.pixelSize: 17
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }

            Flow {
                width: parent.width
                spacing: 6
                visible: root.hasEntry && root.entry.tags.length > 0

                Repeater {
                    model: root.hasEntry ? root.entry.tags : []

                    delegate: Rectangle {
                        required property string modelData

                        width: tagText.implicitWidth + 14
                        height: 20
                        radius: 10
                        color: "#262b3a"

                        Text {
                            id: tagText
                            anchors.centerIn: parent
                            text: "#" + modelData
                            color: "#9db4ff"
                            font.pixelSize: 10
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: root.hasEntry ? root.entry.description : ""
                color: "#b6bccd"
                font.pixelSize: 12
                wrapMode: Text.Wrap
                lineHeight: 1.2
            }

            Column {
                width: parent.width
                spacing: 5
                visible: root.hasEntry && root.entry.command !== ""

                Text {
                    text: "COMMAND"
                    color: "#7c8497"
                    font.pixelSize: 9
                    font.letterSpacing: 1.2
                }

                CodeBlock {
                    width: parent.width
                    code: root.hasEntry ? root.entry.command : ""
                }
            }

            Column {
                width: parent.width
                spacing: 5
                visible: root.hasEntry && root.entry.examples.length > 0

                Text {
                    text: "EXAMPLES"
                    color: "#7c8497"
                    font.pixelSize: 9
                    font.letterSpacing: 1.2
                }

                Repeater {
                    model: root.hasEntry ? root.entry.examples : []

                    delegate: CodeBlock {
                        required property string modelData

                        width: parent.width
                        code: modelData
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 5
                visible: root.hasEntry && root.entry.notes !== ""

                Text {
                    text: "NOTES"
                    color: "#7c8497"
                    font.pixelSize: 9
                    font.letterSpacing: 1.2
                }

                Text {
                    width: parent.width
                    text: root.hasEntry ? root.entry.notes : ""
                    color: "#aab1c4"
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    lineHeight: 1.2
                }
            }

            Text {
                width: parent.width
                visible: root.hasEntry
                text: root.hasEntry ? root.entry.path : ""
                color: "#5d6478"
                font.pixelSize: 9
                elide: Text.ElideMiddle
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !root.hasEntry
        text: "Select a command to preview it"
        color: "#5f6678"
        font.pixelSize: 12
    }
}
