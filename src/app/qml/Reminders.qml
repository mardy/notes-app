﻿/*
 * Copyright: 2013 - 2014 Canonical, Ltd
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
import Ubuntu.Components.Popups 1.3
import Ubuntu.Components.ListItems 1.3
import Ubuntu.Connectivity 1.0
import Evernote 0.1
import Ubuntu.OnlineAccounts 0.1
import Ubuntu.OnlineAccounts.Client 0.1
import Ubuntu.PushNotifications 0.1
import Ubuntu.Content 1.0
import "components"
import "ui"

MainView {
    id: root

    objectName: "mainView"
    applicationName: "com.ubuntu.reminders"

    property bool narrowMode: root.width < units.gu(140)
    property var uri: undefined

    onNarrowModeChanged: {
        if (narrowMode) {
            // Clean the toolbar
            notesPage.selectedNote = null;
        }
    }

    Connections {
        target: UriHandler
        onOpened: {
            root.uri = uris[0];
            processUri();
        }
    }

    Connections {
        target: NetworkingStatus
        onStatusChanged: {
            switch (NetworkingStatus.status) {
            case NetworkingStatus.Offline:
                EvernoteConnection.disconnectFromEvernote();
                break;
            case NetworkingStatus.Online:
                // Seems DNS still fails most of the time when we get this signal.
                connectDelayTimer.start();
                break;
            }
        }
    }

    property var importTransfer: null
    function handleImportTransfer(note) {
        if (importTransfer == null) return;

        for (var i = 0; i < importTransfer.items.length; i++) {
            var url = importTransfer.items[i].url;
            switch (importTransfer.contentType) {
            case ContentType.Links:
                note.insertLink(note.plaintextContent.length, url)
                break;
            default:
                note.attachFile(note.plaintextContent.length, url)
                break;
            }
        }
        note.save();
        importTransfer = null;
    }

    Connections {
        target: ContentHub
        onImportRequested: {
            importTransfer = transfer;
            var popup = PopupUtils.open(importQuestionComponent);
            popup.accepted.connect(function(createNew) {
                PopupUtils.close(popup);
                if (createNew) {
                    var note = NotesStore.createNote(i18n.tr("Untitled"));
                    handleImportTransfer(note);
                }
            })

            popup.rejected.connect(function() {
                PopupUtils.close(popup);
                importTransfer = null;
            })
        }
    }

    Timer {
        id: connectDelayTimer
        interval: 2000
        onTriggered: EvernoteConnection.connectToEvernote();
    }

    Connections {
        target: EvernoteConnection
        onIsConnectedChanged: {
            if (EvernoteConnection.isConnected && root.uri) {
                processUri();
            }
        }
    }

    function openAccountPage() {
        var unauthorizedAccounts = allAccounts.count - accounts.count > 0 ? true : false
        var accountPage = pagestack.push(Qt.createComponent(Qt.resolvedUrl("ui/AccountSelectorPage.qml")), { accounts: accounts, unauthorizedAccounts: unauthorizedAccounts, oaSetup: setup });
        accountPage.accountSelected.connect(function(username, handle) { accountService.startAuthentication(username, handle); pagestack.pop(); root.accountPage = null });
    }

    function displayNote(note, conflictMode) {
        if (conflictMode == undefined) {
            conflictMode = false;
        }

        if (importTransfer != null) {
            handleImportTransfer(note);
        }

        print("displayNote:", note.guid)
        note.load(true);
        if (root.narrowMode) {
            print("creating noteview");
            if (!conflictMode && note.conflicting) {
                // User wants to open the note even though it is conflicting! Show the Conflict page instead.
                var page = pagestack.push(Qt.createComponent(Qt.resolvedUrl("ui/NoteConflictPage.qml")), {note: note});
                page.displayNote.connect(function(note) { root.displayNote(note, true); } );
                page.resolveConflict.connect(function(keepLocal) {
                    var confirmation = PopupUtils.open(Qt.resolvedUrl("components/ResolveConflictConfirmationDialog.qml"), page, {keepLocal: keepLocal, remoteDeleted: note.conflictingNote.deleted, localDeleted: note.deleted});
                    confirmation.accepted.connect(function() {
                        NotesStore.resolveConflict(note.guid, keepLocal ? NotesStore.KeepLocal : NotesStore.KeepRemote);
                        pagestack.pop();
                    });
                })
            } else {
                var page = pagestack.push(Qt.createComponent(Qt.resolvedUrl("ui/NotePage.qml")), {readOnly: conflictMode, note: note })
                page.editNote.connect(function() {root.switchToEditMode(note)})
            }
        } else {
            var view;
            if (!conflictMode && note.conflicting) {
                // User wants to open the note even though it is conflicting! Show the Conflict page instead.
                notesPage.conflictMode = true;
                sideViewLoader.clear();
                view = sideViewLoader.embed(Qt.resolvedUrl("ui/NoteConflictView.qml"))
                view.displayNote.connect(function(note) {root.displayNote(note,true)})
                view.resolveConflict.connect(function(keepLocal) {
                    var confirmation = PopupUtils.open(Qt.resolvedUrl("components/ResolveConflictConfirmationDialog.qml"), page, {keepLocal: keepLocal, remoteDeleted: note.conflictingNote.deleted, localDeleted: note.deleted});
                    confirmation.accepted.connect(function() {
                        NotesStore.resolveConflict(note.guid, keepLocal ? NotesStore.KeepLocal : NotesStore.KeepRemote);
                    });
                })
            } else {
                notesPage.conflictMode = conflictMode;
                sideViewLoader.clear();
                view = sideViewLoader.embed(Qt.resolvedUrl("ui/NoteView.qml"))
                view.editNote.connect(function() {root.switchToEditMode(view.note)})
            }
            view.note = note;
        }
    }

    function switchToEditMode(note) {
        note.load(true)
        if (root.narrowMode) {
            if (pagestack.depth > 1) {
                pagestack.pop();
                var page = pagestack.push(Qt.resolvedUrl("ui/EditNotePage.qml"), {note: note, newNote: false});
                page.exitEditMode.connect(function() {Qt.inputMethod.hide(); pagestack.pop();});
            }
        } else {
            sideViewLoader.clear();
            var view = sideViewLoader.embed(Qt.resolvedUrl("ui/EditNoteView.qml"))
            view.note = note;
            view.exitEditMode.connect(function(note) {root.displayNote(note)});
        }
    }

    function openSearch() {
        var page = pagestack.push(Qt.createComponent(Qt.resolvedUrl("ui/SearchNotesPage.qml")))
        page.noteSelected.connect(function(note) {root.displayNote(note)})
        page.editNote.connect(function(note) {root.switchToEditMode(note)})
    }

    function doLogin() {
        var accountName = preferences.accountName;
        if (accountName == "@local") {
            accountService.startAuthentication("@local", null);
            return;
        }

        if (accountName) {
            print("Last used account:", accountName);
            var i;
            for (i = 0; i < accounts.count; i++) {
                if (accounts.get(i, "displayName") == accountName) {
                    print("Account", accountName, "still valid in Online Accounts.");
                    accountService.startAuthentication(accounts.get(i, "displayName"), accounts.get(i, "accountServiceHandle"));
                    return;
                }
            }
        }

        switch (accounts.count) {
        case 0:
            PopupUtils.open(noAccountDialog);
            print("No account available. Please set up an account in System Settings.");
            break;
        case 1:
            print("Connecting to account", accounts.get(0, "displayName"), "as there is only one account available");
            accountService.startAuthentication(accounts.get(0, "displayName"), accounts.get(0, "accountServiceHandle"));
            break;
        default:
            print("There are multiple accounts. Allowing user to select one.");
            openAccountPage();
        }
    }

    function processUri() {
        var commands = root.uri.split("://")[1].split("/");
        if (EvernoteConnection.isConnected && commands && NotesStore) {
            switch(commands[0].toLowerCase()) {
                case "notes": // evernote://notes
                    rootTabs.selectedTabIndex = 0;
                    break;

                case "note": // evernote://note/<noteguid>
                    if (commands[1]) {
                        var note = NotesStore.note(commands[1])
                        if (note) {
                            displayNote(note);
                        } else {
                            console.warn("No such note:", commands[1])
                        }
                    }
                    break;

                case "newnote": // evernote://newnote  or  evernote://newnote/<notebookguid>
                    if (commands[1]) {
                        if (NotesStore.notebook(commands[1])) {
                            NotesStore.createNote(i18n.tr("Untitled"), commands[1]);
                        } else {
                            console.warn("No such notebook.");
                        }
                    } else {
                        NotesStore.createNote(i18n.tr("Untitled"));
                    }
                    break;

                case "editnote": // evernote://editnote/<noteguid>
                    if (commands[1]) {
                        var note = NotesStore.note(commands[1]);
                        displayNote(note);
                        switchToEditMode(note);
                    }
                    break;

                case "notebooks": // evernote://notebooks
                    rootTabs.selectedTabIndex = 1;
                    break;

                case "notebook": // evernote://notebook/<notebookguid>
                    if (commands[1]) {
                        if (NotesStore.notebook(commands[1])) {
                            notebooksPage.openNotebook(commands[1]);
                        } else {
                            console.warn("No such notebook:", commands[1]);
                        }
                    }
                    break;

                case "reminders": // evernote://reminders
                    rootTabs.selectedTabIndex = 2;
                    break;

                case "tags": // evernote://tags
                    rootTabs.selectedTabIndex = 3;
                    break;

                case "tag": // evernote://tag/<tagguid>
                    if (commands[1]) {
                        tagsPage.openTaggedNotes(commands[1]);
                    }
                    break;

                default: console.warn('WARNING: Unmanaged URI: ' + commands);
            }
            commands = undefined;
        }
    }

    function registerPushClient() {
        console.log("Registering push client", JSON.stringify({
                                                                  "userId" : "" +  UserStore.userId,
                                                                  "appId": root.applicationName + "_reminders",
                                                                  "token": pushClient.token
                                                              }));
        var req = new XMLHttpRequest();
        req.open("post", "https://push.ubuntu.com/gateway/register", true);
        req.setRequestHeader("content-type", "application/json");
        req.onreadystatechange = function() {//Call a function when the state changes.
            print("push client register response")
            if(req.readyState == 4) {
                if (req.status == 200) {
                    print("PushClient registered")
                } else {
                    print("Error registering PushClient:", req.status, req.responseText, req.statusText);
                }
            }
        }
        req.send(JSON.stringify({
            "userId" : "" + UserStore.userId,
            "appId": root.applicationName + "_reminders",
            "token": pushClient.token
        }))
    }

    function openTaggedNotes(title, tagGuid, narrowMode) {
        print("!!!opening note page for tag", tagGuid)
        var page = pagestack.push(Qt.createComponent(Qt.resolvedUrl("ui/NotesPage.qml")), {title: title, filterTagGuid: tagGuid, narrowMode: narrowMode});
        page.selectedNoteChanged.connect(function() {
            if (page.selectedNote) {
                root.displayNote(page.selectedNote);
                if (root.narrowMode) {
                    page.selectedNote = null;
                }
            }
        })
        page.editNote.connect(function(note) {
            root.switchToEditMode(note)
        })
    }

    PushClient {
        id: pushClient
        appId: root.applicationName + "_reminders"

        onNotificationsChanged: {
            print("Received PushClient notifications:", notifications.length)
            for (var i = 0; i < notifications.length; i++) {
                print("notification", i, ":", notifications[i])
                var notification = JSON.parse(notifications[i])["payload"];

                if (notification["userId"] != UserStore.userId) { // Yes, we want type coercion here.
                    console.warn("user mismatch:", notification["userId"], "!=", UserStore.userId)
                    return;
                }

                switch(notification["reason"]) {
                case "update":
                    print("Note updated on server:", notification["guid"])
                    if (NotesStore.note(notification["guid"]) === null) {
                        NotesStore.refreshNotes();
                    } else {
                        NotesStore.refreshNoteContent(notification["guid"]);
                    }
                    break;
                case "create":
                    print("New note appeared on server:", notification["guid"])
                    NotesStore.refreshNotes();
                    break;
                case "notebook_update":
                    NotesStore.refreshNotebooks();
                    break;
                default:
                    console.warn("Unhandled push notification:", notification["reason"])
                }
            }
        }

        onError: {
            console.warn("PushClient Error:", error)
        }
    }

    AccountServiceModel {
        id: accounts
        applicationId: "com.ubuntu.reminders_reminders"
    }

    AccountServiceModel {
        id: allAccounts
        applicationId: "com.ubuntu.reminders_reminders"
        service: useSandbox ? "evernote-sandbox" : "evernote"
        includeDisabled: true
    }

    AccountService {
        id: accountService
        function startAuthentication(username, objectHandle) {
            //Load the cache
            EvernoteConnection.disconnectFromEvernote();
            EvernoteConnection.token = "";
            NotesStore.username = username;
            preferences.accountName = username;
            if (username === "@local" && !preferences.haveLocalUser) {
                NotesStore.createNotebook(i18n.tr("Default notebook"));
                preferences.haveLocalUser = true;
            }

            if (objectHandle === null) {
                return;
            }

            accountService.objectHandle = objectHandle;
            // FIXME: workaround for lp:1351041. We'd normally set the hostname
            // under onAuthenticated, but it seems that now returns empty parameters
            EvernoteConnection.hostname = accountService.authData.parameters["HostName"];
            authenticate(null);
        }

        onAuthenticated: {
            EvernoteConnection.token = reply.AccessToken;
            print("token is:", EvernoteConnection.token)
            print("NetworkingStatus.online:", NetworkingStatus.Online)
            if (NetworkingStatus.Online) {
                EvernoteConnection.connectToEvernote();
            }
        }
        onAuthenticationError: {
            console.log("Authentication failed, code " + error.code)
        }
    }

    Component.onCompleted: {
        if (tablet) {
            width = units.gu(100);
            height = units.gu(75);
        } else if (phone) {
            width = units.gu(40);
            height = units.gu(75);
        }

        pagestack.push(rootTabs);
        doLogin();

        if (uriArgs) {
            root.uri = uriArgs[0];
        }
    }

    Connections {
        target: UserStore
        onUserChanged: {
            print("Logged in as user:", UserStore.userId, UserStore.userName);
            preferences.setTokenForUser(UserStore.userId, EvernoteConnection.token);
            if (UserStore.userId >= 0) {
                registerPushClient();
            }
        }
    }

    Connections {
        target: NotesStore
        onNoteCreated: {
            var note = NotesStore.note(guid);
            print("note created:", note.guid);
            if (root.narrowMode) {
                var page = pagestack.push(Qt.resolvedUrl("ui/EditNotePage.qml"), {note: note, newNote: true});
                page.exitEditMode.connect(function() {Qt.inputMethod.hide(); pagestack.pop();});
            } else {
                notesPage.selectedNote = note;
                var view = sideViewLoader.embed(Qt.resolvedUrl("ui/EditNoteView.qml"));
                view.note = note;
                view.newNote = true;
                view.exitEditMode.connect(function(note) {root.displayNote(note)});
            }
        }
    }

    Column {
        id: statusBar
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: units.gu(6)}

        StatusBar {
            anchors { left: parent.left; right: parent.right }
            color: root.backgroundColor
            shown: text
            text: EvernoteConnection.error || NotesStore.error
            iconName: "sync-error"
            iconColor: theme.palette.normal.negative
            showCancelButton: true

            onCancel: {
                NotesStore.clearError();
            }

            Timer {
                interval: 5000
                repeat: true
                running: NotesStore.error
                onTriggered: NotesStore.clearError();
            }
        }

        StatusBar {
            anchors { left: parent.left; right: parent.right }
            color: root.backgroundColor
            shown: importTransfer != null
            text: importTransfer.items.length === 1 ? i18n.tr("Select note to attach imported file") : i18n.tr("Select note to attach imported files")
            iconName: "document-save"
            showCancelButton: true

            onCancel: {
                importTransfer = null;
            }
        }
    }

    PageStack {
        id: pagestack
        anchors.rightMargin: root.narrowMode ? 0 : root.width - units.gu(40)
        anchors.topMargin: statusBar.height


        Tabs {
            id: rootTabs

            anchors.fill: parent

            Tab {
                title: i18n.tr("Notes")
                objectName: "NotesTab"
                page: NotesPage {
                    id: notesPage
                    readOnly: conflictMode
                    property bool conflictMode: false

                    narrowMode: root.narrowMode

                    onEditNote: {
                        root.switchToEditMode(note)
                    }

                    onSelectedNoteChanged: {
                        if (selectedNote !== null) {
                            root.displayNote(selectedNote);
                            if (root.narrowMode) {
                                selectedNote = null;
                            }
                        } else {
                            sideViewLoader.clear();
                        }
                    }
                    onOpenSearch: root.openSearch();
                }
            }

            Tab {
                title: i18n.tr("Notebooks")
                objectName: "NotebookTab"
                page: NotebooksPage {
                    id: notebooksPage

                    narrowMode: root.narrowMode

                    onOpenNotebook: {
                        var notebook = NotesStore.notebook(notebookGuid)
                        print("have notebook:", notebook, notebook.name)
                        print("opening note page for notebook", notebookGuid)
                        var page = pagestack.push(Qt.createComponent(Qt.resolvedUrl("ui/NotesPage.qml")), {title: notebook.name, filterNotebookGuid: notebookGuid, narrowMode: root.narrowMode});
                        page.selectedNoteChanged.connect(function() {
                            if (page.selectedNote) {
                                root.displayNote(page.selectedNote);
                                if (root.narrowMode) {
                                    page.selectedNote = null;
                                }
                            }
                        })
                        page.editNote.connect(function(note) {
                            root.switchToEditMode(note)
                        })
                        page.openSearch.connect(function() {
                            root.openSearch();
                        })
                        NotesStore.refreshNotes();
                    }

                    onOpenSearch: root.openSearch();
                }
            }

            Tab {
                title: i18n.tr("Reminders")
                page: RemindersPage {
                    id: remindersPage

                    onSelectedNoteChanged: {
                        if (selectedNote !== null) {
                            root.displayNote(selectedNote);
                        } else {
                            sideViewLoader.clear();
                        }
                    }

                    onOpenSearch: root.openSearch();
                }
            }

            Tab {
                title: i18n.tr("Tags")
                page: TagsPage {
                    id: tagsPage

                    onOpenTaggedNotes: {
                        var tag = NotesStore.tag(tagGuid);
                        root.openTaggedNotes(tag.name, tag.guid, root.narrowMode)
                    }

                    onOpenSearch: root.openSearch();
                }
            }
            Tab {
                title: i18n.tr("Accounts")

                page: AccountSelectorPage {
                    accounts: accounts
                    unauthorizedAccounts: true
                    oaSetup: setup
                    onAccountSelected: {
                        accountService.startAuthentication(username, handle)
                        rootTabs.selectedTabIndex = 0;
                    }
                }
            }
        }
    }

    Label {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: pagestack.width / 2
        visible: !root.narrowMode
        text: i18n.tr("No note selected.\nSelect a note to see it in detail.")
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        fontSize: "large"
        width: parent.width - pagestack.width
    }

    Loader {
        id: sideViewLoader
        anchors { top: parent.top; right: parent.right; bottom: parent.bottom; topMargin: units.gu(10) }
        width: root.width - pagestack.width

        ThinDivider {
            width: sideViewLoader.height
            anchors { right: null; left: parent.left; }
            z: 5

            transform: Rotation {
                angle: 90
            }
        }

        function embed(view, args) {
            source = view;
            return item;
        }

        function clear() {
            source = "";
        }
    }

    Setup {
        id: setup
        applicationId: "com.ubuntu.reminders_reminders"
        providerId: useSandbox ? "com.ubuntu.reminders_evernote-account-plugin-sandbox" : "com.ubuntu.reminders_evernote-account-plugin"
    }

    Component {
        id: noAccountDialog
        Dialog {
            id: noAccount
            objectName: "noAccountDialog"
            title: i18n.tr("Sync with Evernote")
            text: i18n.tr("Notes can be stored on this device, or optionally synced with Evernote.") + " "
                          + i18n.tr("To sync with Evernote, you need an Evernote account.")

            Connections {
                target: accounts
                onCountChanged: {
                    if (accounts.count == 1) {
                        PopupUtils.close(noAccount)
                        doLogin();
                    }
                }
            }

            RowLayout {
                Button {
                    objectName: "openAccountButton"
                    text: i18n.tr("Not Now")
                    onClicked: {
                        PopupUtils.close(noAccount)
                        accountService.startAuthentication("@local", null);
                    }
                    Layout.fillWidth: true
                }
                Button {
                    objectName: "openAccountButton"
                    text: i18n.tr("Set Up…")
                    color: theme.palette.normal.positive
                    onClicked: setup.exec()
                    Layout.fillWidth: true
                }
            }
        }
    }

    Component {
        id: importQuestionComponent

        Dialog {
            id: importDialog
            title: importTransfer.items.length > 1 ?
                       i18n.tr("Importing %1 items").arg(importTransfer.items.length)
                     : i18n.tr("Importing 1 item")
            text: importTransfer.items.length > 1 ?
                      i18n.tr("Do you want to create a new note for those items or do you want to attach them to an existing note?")
                    : i18n.tr("Do you want to create a new note for this item or do you want to attach it to an existing note?")

            signal accepted(bool createNew);
            signal rejected();

            Button {
                text: i18n.tr("Create new note")
                onClicked: importDialog.accepted(true)
                color: theme.palette.normal.positive
            }
            Button {
                text: i18n.tr("Attach to existing note")
                onClicked: importDialog.accepted(false);
            }
            Button {
                text: i18n.tr("Cancel import")
                onClicked: importDialog.rejected();
            }
        }
    }
}
