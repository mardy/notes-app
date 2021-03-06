/*
 * Copyright: 2014 Canonical, Ltd
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

#include "savenotebookjob.h"
#include "notebook.h"

SaveNotebookJob::SaveNotebookJob(Notebook *notebook, QObject *parent) :
    NotesStoreJob(parent)
{
    // Need to clone it. As startJob() will run in another thread we can't access the real notebook from there.
    m_notebook = notebook->clone();

    // Make sure we delete the clone when done
    m_notebook->setParent(this);
}

bool SaveNotebookJob::operator==(const EvernoteJob *other) const
{
    const SaveNotebookJob *otherJob = qobject_cast<const SaveNotebookJob*>(other);
    if (!otherJob) {
        return false;
    }
    return this->m_notebook == otherJob->m_notebook;
}

void SaveNotebookJob::attachToDuplicate(const EvernoteJob *other)
{
    const SaveNotebookJob *otherJob = static_cast<const SaveNotebookJob*>(other);
    connect(otherJob, &SaveNotebookJob::jobDone, this, &SaveNotebookJob::jobDone);
}

void SaveNotebookJob::startJob()
{
    m_resultNotebook.guid = m_notebook->guid().toStdString();
    m_resultNotebook.__isset.guid = true;
    m_resultNotebook.name = m_notebook->name().toStdString();
    m_resultNotebook.__isset.name = true;
    m_resultNotebook.updateSequenceNum = m_notebook->updateSequenceNumber();
    m_resultNotebook.__isset.updateSequenceNum = true;
    m_resultNotebook.defaultNotebook = m_notebook->isDefaultNotebook();
    m_resultNotebook.__isset.defaultNotebook = true;

    client()->updateNotebook(token().toStdString(), m_resultNotebook);
}

void SaveNotebookJob::emitJobDone(EvernoteConnection::ErrorCode errorCode, const QString &errorMessage)
{
    emit jobDone(errorCode, errorMessage, m_resultNotebook);
}
