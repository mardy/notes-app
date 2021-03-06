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
 *
 * Authors: Michael Zanetti <michael.zanetti@canonical.com>
 */

#ifndef NOTE_H
#define NOTE_H

#include "utils/enmldocument.h"
#include "resource.h"

#include <QObject>
#include <QDateTime>
#include <QStringList>
#include <QImage>
#include <QFile>
#include <QSettings>

class Note : public QObject
{
    Q_OBJECT

    // Don't forget to update clone() if you add properties!
    Q_PROPERTY(QString guid READ guid NOTIFY guidChanged)
    Q_PROPERTY(QString notebookGuid READ notebookGuid WRITE setNotebookGuid NOTIFY notebookGuidChanged)
    Q_PROPERTY(QDateTime created READ created NOTIFY createdChanged)
    Q_PROPERTY(QString createdString READ createdString NOTIFY createdChanged)
    Q_PROPERTY(QDateTime updated READ updated WRITE setUpdated NOTIFY updatedChanged)
    Q_PROPERTY(QString updatedString READ updatedString)
    Q_PROPERTY(QString title READ title WRITE setTitle NOTIFY titleChanged)
    Q_PROPERTY(QStringList tagGuids READ tagGuids WRITE setTagGuids NOTIFY tagGuidsChanged)
    Q_PROPERTY(QString htmlContent READ htmlContent NOTIFY contentChanged)
    Q_PROPERTY(QString richTextContent READ richTextContent WRITE setRichTextContent NOTIFY contentChanged)
    Q_PROPERTY(QString enmlContent READ enmlContent WRITE setEnmlContent NOTIFY contentChanged)
    Q_PROPERTY(QString plaintextContent READ plaintextContent NOTIFY contentChanged)
    Q_PROPERTY(QString tagline READ tagline NOTIFY contentChanged)
    Q_PROPERTY(QStringList resourceUrls READ resourceUrls NOTIFY resourcesChanged)
    Q_PROPERTY(bool reminder READ reminder WRITE setReminder NOTIFY reminderChanged)
    Q_PROPERTY(bool hasReminderTime READ hasReminderTime WRITE setHasReminderTime NOTIFY reminderTimeChanged)
    Q_PROPERTY(QDateTime reminderTime READ reminderTime WRITE setReminderTime NOTIFY reminderTimeChanged)
    Q_PROPERTY(QString reminderTimeString READ reminderTimeString NOTIFY reminderTimeChanged)
    Q_PROPERTY(bool reminderDone READ reminderDone WRITE setReminderDone NOTIFY reminderDoneChanged)
    Q_PROPERTY(QDateTime reminderDoneTime READ reminderDoneTime WRITE setReminderDoneTime NOTIFY reminderDoneChanged)
    Q_PROPERTY(bool isSearchResult READ isSearchResult NOTIFY isSearchResultChanged)
    Q_PROPERTY(quint32 updateSequenceNumber READ updateSequenceNumber NOTIFY updateSequenceNumberChanged)
    Q_PROPERTY(bool deleted READ deleted NOTIFY deletedChanged)
    Q_PROPERTY(bool conflicting READ conflicting NOTIFY conflictingChanged)
    Q_PROPERTY(bool loaded READ loaded NOTIFY loadedChanged)
    // Don't forget to update clone() if you add properties!

    // Don't clone() "loading" property as results of any current loading operation won't affect the clone.
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool synced READ synced NOTIFY syncedChanged)
    Q_PROPERTY(bool syncError READ syncError NOTIFY syncErrorChanged)
    Q_PROPERTY(Note* conflictingNote READ conflictingNote NOTIFY conflictingNoteChanged)

    // When asking the note's richTextContent, usually the embedded images will have their original size.
    // For rendering that content in a WebView or TextEdit, that might not be appropriate as images might
    // be really big. Use this to restrict them to a maximum width.
    // Set this to -1 (the default) to keep the original size
    Q_PROPERTY(int renderWidth READ renderWidth WRITE setRenderWidth NOTIFY renderWidthChanged)

public:
    explicit Note(const QString &guid, quint32 updateSequenceNumber, QObject *parent = 0);
    ~Note();
    Note* clone();

    QString guid() const;
    void setGuid(const QString &guid);

    QString notebookGuid() const;
    void setNotebookGuid(const QString &notebookGuid);

    QDateTime created() const;
    void setCreated(const QDateTime &created);
    QString createdString() const;

    QDateTime updated() const;
    void setUpdated(const QDateTime &updated);
    QString updatedString() const;

    QString title() const;
    void setTitle(const QString &title);

    QStringList tagGuids() const;
    void setTagGuids(const QStringList &tagGuids);

    QString enmlContent() const;
    void setEnmlContent(const QString &enmlContent);

    QString htmlContent() const;

    QString richTextContent() const;
    void setRichTextContent(const QString &richTextContent);

    QString plaintextContent() const;

    QString tagline() const;

    // setting reminder to false will reset the reminderOrder to 0, setting it to true will
    // create a new timestamp for it.
    bool reminder() const;
    void setReminder(bool reminder);

    qint64 reminderOrder() const;
    void setReminderOrder(qint64 reminderOrder);

    // setting hasReminderTime to false will reset reminderTime to 0, setting it to true will
    // create a new timestamp for it.
    bool hasReminderTime() const;
    void setHasReminderTime(bool hasReminderTime);

    QDateTime reminderTime() const;
    void setReminderTime(const QDateTime &reminderTime);

    // This is the QML representation as we don't want to deal with timestamps there.
    // setting it to false will reset reminderDoneTime to 0, setting it to true will
    // create a new timestamp for it.
    bool reminderDone() const;
    void setReminderDone(bool reminderDone);

    QString reminderTimeString() const;

    QDateTime reminderDoneTime() const;
    void setReminderDoneTime(const QDateTime &reminderDoneTime);

    bool deleted() const;

    bool isSearchResult() const;
    void setIsSearchResult(bool isSearchResult);

    qint32 updateSequenceNumber() const;
    qint32 lastSyncedSequenceNumber() const;

    bool isCached() const;
    bool loaded() const;
    bool loading() const;
    bool synced() const;
    bool syncError() const;
    bool conflicting() const;
    bool needsContentSync() const;

    QStringList resourceUrls() const;
    Q_INVOKABLE Resource* resource(const QString &hash);
    QList<Resource*> resources() const;

    Note *conflictingNote() const;

    Q_INVOKABLE void markTodo(const QString &todoId, bool checked);
    Q_INVOKABLE void attachFile(int position, const QUrl &fileName);
    Q_INVOKABLE void addTag(const QString &tagGuid);
    Q_INVOKABLE void removeTag(const QString &tagGuid);
    Q_INVOKABLE void insertText(int position, const QString &text);
    Q_INVOKABLE void insertLink(int position, const QString &url);

    int renderWidth() const;
    void setRenderWidth(int renderWidth);

    Q_INVOKABLE void load(bool highPriority = false);

public slots:
    void save();
    void remove();

signals:
    void guidChanged();
    void createdChanged();
    void titleChanged();
    void updatedChanged();
    void notebookGuidChanged();
    void tagGuidsChanged();
    void contentChanged();
    void resourcesChanged();
    void reminderChanged();
    void reminderTimeChanged();
    void reminderDoneChanged();
    void isSearchResultChanged();
    void updateSequenceNumberChanged();
    void loadedChanged();
    void deletedChanged();

    void loadingChanged();
    void syncedChanged();
    void syncErrorChanged();
    void conflictingChanged();
    void conflictingNoteChanged();

    void renderWidthChanged();

private slots:
    void slotNotebookGuidChanged(const QString &oldGuid, const QString &newGuid);
    void slotTagGuidChanged(const QString &oldGuid, const QString &newGuid);

private:
    // Those should only be called from NotesStore, which is a friend
    void setLoading(bool loading);
    void setSyncError(bool syncError);
    void setDeleted(bool deleted);
    void syncToCacheFile();
    void syncToInfoFile();
    void deleteFromCache();
    void setUpdateSequenceNumber(qint32 updateSequenceNumber);
    void setLastSyncedSequenceNumber(qint32 lastSyncedSequenceNumber);
    void setConflicting(bool conflicting);
    void setConflictingNote(Note *serverNote);
    Resource *addResource(const QString &hash, const QString &fileName, const QString &type, const QByteArray &data = QByteArray());
    void addMissingResource();
    void setMissingResources(int missingResources);

    void loadFromCacheFile() const;

private:
    QString m_guid;
    QString m_notebookGuid;
    QDateTime m_created;
    QDateTime m_updated;
    QString m_title;
    QStringList m_tagGuids;
    mutable EnmlDocument m_content; // loaded from cache on demand in const methods
    mutable QString m_tagline; // loaded from cache on demand in const methods
    qint64 m_reminderOrder;
    QDateTime m_reminderTime;
    QDateTime m_reminderDoneTime;
    bool m_deleted;
    bool m_isSearchResult;
    QHash<QString, Resource*> m_resources;
    qint32 m_updateSequenceNumber;
    qint32 m_lastSyncedSequenceNumber;
    mutable QFile m_cacheFile;
    QString m_infoFile;

    bool m_loading;
    mutable bool m_loaded;
    bool m_synced;
    bool m_needsContentSync;
    bool m_syncError;
    bool m_conflicting;

    Note *m_conflictingNote;

    // Needed to be able to call private setLoading (we don't want to have that set by anyone except the NotesStore)
    friend class NotesStore;
};

#endif // NOTE_H
