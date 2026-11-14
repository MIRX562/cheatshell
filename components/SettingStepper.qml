import QtQuick

// Labelled numeric input with -/+ buttons.
Item {
    id: root

    property string label: ""
    property string description: ""
    property int value: 0
    property int from: 0
    property int to: 1000000
    property int step: 1

    signal valueModified(int value)

    implicitHeight: 46
    activeFocusOnTab: false

    function _emit(next) {
        const clamped = Math.max(root.from, Math.min(root.to, Math.floor(next)))
        if (clamped !== root.value)
            root.valueModified(clamped)
    }

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: input.activeFocus ? "#202431" : "transparent"
        border.width: input.activeFocus ? 1 : 0
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
        spacing: 4

        Rectangle {
            width: 24
            height: 24
            radius: 6
            color: minus.containsMouse ? "#343a4b" : "#292d3a"
            border.width: 1
            border.color: "#3b4254"

            Text {
                anchors.centerIn: parent
                text: "−"
                color: "#c7cede"
                font.pixelSize: 14
            }

            MouseArea {
                id: minus
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._emit(root.value - root.step)
            }
        }

        Rectangle {
            width: 74
            height: 24
            radius: 6
            color: "#292d3a"
            border.width: 1
            border.color: input.activeFocus ? "#4d5f86" : "#3b4254"

            TextInput {
                id: input
                anchors.fill: parent
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                color: "#e3e8f4"
                font.pixelSize: 11
                selectionColor: "#3d5a99"
                selectedTextColor: "#f2f5fc"
                activeFocusOnTab: true
                validator: IntValidator {
                    bottom: root.from
                    top: root.to
                }

                text: root.value

                // Keep the draft in sync while typing so Ctrl+S never saves a
                // stale value when the field has not been committed yet.
                onTextChanged: {
                    if (text === "")
                        return
                    const next = parseInt(text)
                    if (!isNaN(next))
                        root._emit(next)
                }

                onEditingFinished: {
                    let next = parseInt(text)
                    if (isNaN(next))
                        next = root.value
                    root._emit(next)
                    input.text = Qt.binding(function() { return root.value })
                }

                Keys.onUpPressed: {
                    root._emit(root.value + root.step)
                    event.accepted = true
                }
                Keys.onDownPressed: {
                    root._emit(root.value - root.step)
                    event.accepted = true
                }
            }
        }

        Rectangle {
            width: 24
            height: 24
            radius: 6
            color: plus.containsMouse ? "#343a4b" : "#292d3a"
            border.width: 1
            border.color: "#3b4254"

            Text {
                anchors.centerIn: parent
                text: "+"
                color: "#c7cede"
                font.pixelSize: 14
            }

            MouseArea {
                id: plus
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._emit(root.value + root.step)
            }
        }
    }
}
