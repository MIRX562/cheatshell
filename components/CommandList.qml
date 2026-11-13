import QtQuick

// Scrollable result list with a minimal scroll indicator.
ListView {
    id: list

    signal selectRequested(int index)
    signal copyRequested(var entry)

    clip: true
    spacing: 3
    boundsBehavior: Flickable.StopAtBounds
    cacheBuffer: 400
    highlightMoveDuration: 0
    highlightFollowsCurrentItem: true

    delegate: CommandItem {
        width: list.width
    }

    Rectangle {
        visible: list.contentHeight > list.height + 1
        width: 4
        radius: 2
        color: "#343a4b"
        anchors {
            right: parent.right
            rightMargin: 1
        }
        height: Math.max(28, list.height * list.height / list.contentHeight)
        y: {
            const maxScroll = list.contentHeight - list.height
            if (maxScroll <= 0)
                return 0
            const fraction = Math.max(0, Math.min(1, list.contentY / maxScroll))
            return fraction * (list.height - height)
        }
    }
}
