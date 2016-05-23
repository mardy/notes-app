/*
 * Copyright: 2013 Canonical, Ltd
 *
 * This file is part of reminders
 *
 * reminders is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * reminders is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.4
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import Ubuntu.Components.ListItems 1.3
import Evernote 0.1

ListItemWithActions {
    id: root
    height: units.gu(10)

    signal deleteTag();
    signal renameTag();

    leftSideAction: Action {
        iconName: "delete"
        text: i18n.tr("Delete")
        onTriggered: {
            root.deleteTag()
        }
    }

    triggerActionOnMouseRelease: true
    rightSideActions: [
        Action {
            iconName: "edit"
            onTriggered: {
                root.renameTag();
            }
        }
    ]

    Rectangle {
        anchors.fill: parent
        color: "#f9f9f9"
        anchors.bottomMargin: units.dp(1)
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: units.gu(1)
        spacing: units.gu(1)

        Item {
            Layout.fillHeight: true
            width: units.gu(1)
            Rectangle {
                anchors { top: parent.top; bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; margins: units.gu(1.5) }
                width: units.gu(.5)
                color: "black"
                radius: width / 2
            }
        }

        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true

            Label {
                id: tagTitleLabel
                objectName: 'tagTitleLabel'
                text: model.name
                fontSize: "large"
                Layout.fillWidth: true
                font.strikeout: model.deleted
            }
        }

        Item {
            Layout.fillHeight: true
            width: units.gu(2)

             Label {
                anchors { left: parent.left; top: parent.top; right: parent.right }
                height: width
                color: "#b3b3b3"
                text: "(" + model.noteCount + ")"
                fontSize: "small"
                horizontalAlignment: Text.AlignRight
            }
            Icon {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; right: parent.right }
                height: width
                name: "go-next"
            }
            Icon {
                anchors { left: parent.left; bottom: parent.bottom; right: parent.right }
                height: width
                name: model.loading ? "sync-updating" : model.syncError ? "sync-error" : model.synced ? "sync-idle" : "sync-offline"
                visible: NotesStore.username !== "@local" && (!model.synced || model.syncError || model.loading)
            }
        }
    }
}
