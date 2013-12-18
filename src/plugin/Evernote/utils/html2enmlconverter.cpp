/*
 * Copyright: 2013 Canonical, Ltd
 *
 * This file is part of reminders-app
 *
 * reminders-app is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * reminders-app is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: Michael Zanetti <michael.zanetti@canonical.com>
 */

#include "html2enmlconverter.h"

#include <QXmlStreamReader>
#include <QXmlStreamWriter>
#include <QStringList>

// Taken from http://xml.evernote.com/pub/enml2.dtd
QStringList supportedTags = QStringList() << "a" << "abbr" << "acronym" << "address" << "area" << "b" << "bdo" << "big" <<
                                             "blockquote" << "br" << "caption" << "center" << "cite" << "code" << "col" <<
                                             "colgroup" << "dd" << "del" << "dfn" << "div" << "dl" << "dt" << "em" <<
                                             "en-crypt" << "en-media" << "en-todo" << "font" << "h1" << "h2" << "h3" <<
                                             "h4" << "h5" << "h6" << "hr" << "i" << "img" << "ins" << "kbd" << "li" <<
                                             "map" << "ol" << "p" << "pre" << "q" << "s" << "samp" << "small" << "span" <<
                                             "strike" << "strong" << "sub" << "sup" << "table" << "tbody" << "td" <<
                                             "tfoot" << "th" << "thead" << "tr" << "tt" << "u" << "ul" << "var";


Html2EnmlConverter::Html2EnmlConverter()
{
}

QString Html2EnmlConverter::html2enml(const QString &html)
{
    // output
    QString evml;
    QXmlStreamWriter writer(&evml);
    writer.writeStartDocument();
    writer.writeDTD("<!DOCTYPE en-note SYSTEM \"http://xml.evernote.com/pub/enml2.dtd\">");

    // input
    QXmlStreamReader reader(html);

    // state
    bool isBody = false;

    while (!reader.atEnd() && !reader.hasError()) {
        QXmlStreamReader::TokenType token = reader.readNext();
        if(token == QXmlStreamReader::StartDocument) {
            continue;
        }

        // Handle start elements
        if(token == QXmlStreamReader::StartElement) {
            // skip everything if body hasn't started yet
            if (!isBody) {
                if (reader.name() == "body") {
                    writer.writeStartElement("en-note");
                    isBody = true;
                }
                continue;
            }
            // Write supported start elements to output (including attributes)
            if (supportedTags.contains(reader.name().toString())) {
                writer.writeStartElement(reader.name().toString());
                writer.writeAttributes(reader.attributes());
            }
        }

        // Write *all* normal text inside <body> </body> to output
        if (isBody && token == QXmlStreamReader::Characters) {
            writer.writeCharacters(reader.text().toString());
        }

        // handle end elements
        if (token == QXmlStreamReader::EndElement) {

            // skip everything after body
            if (reader.name() == "body") {
                writer.writeEndElement();
                isBody = false;
                break;
            }

            // Write closing tags for supported elements
            if (supportedTags.contains(reader.name().toString())) {
                writer.writeEndElement();
            }
        }
    }

    writer.writeEndDocument();

    return evml;
}
