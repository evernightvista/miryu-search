/*
 * Fenestra Search — https://github.com/naykkalak/fenestra-search
 * SPDX-FileCopyrightText: 2026 naykkalak
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami

// Puces de filtre au style du thème (blanc translucide + liseré fin),
// la puce active prend la couleur d'accent comme sous Windows 11
Item {
    id: puces

    property string actif: "All"
    signal choisir(string filtre)

    implicitHeight: 32

    readonly property var filtres: [
        { cle: "All",     nom: i18n("All") },
        { cle: "Apps",    nom: i18n("Apps") },
        { cle: "Docs",    nom: i18n("Docs") },
        { cle: "Images",  nom: i18n("Images") },
        { cle: "Folders", nom: i18n("Folders") },
        { cle: "Web",     nom: i18n("Web") }
    ]

    Flickable {
        anchors.fill: parent
        contentWidth: rangee.width
        contentHeight: height
        clip: true
        interactive: contentWidth > width

        Row {
            id: rangee
            spacing: 8
            padding: 4
            x: (rangee.width < parent.width) ? (parent.width - rangee.width) / 2 : 0

            Repeater {
                model: puces.filtres
                delegate: Rectangle {
                    id: puce
                    readonly property bool active: modelData.cle === puces.actif
                    readonly property color accent: Kirigami.Theme.highlightColor
                    width: libelle.implicitWidth + 24
                    height: 24
                    radius: 12
                    color: active ? accent
                         : (zone.containsMouse ? Qt.rgba(accent.r, accent.g, accent.b, 0.25) : (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#26ffffff" : "#80ffffff"))
                    border.width: 1
                    border.color: active ? accent
                         : (zone.containsMouse ? Qt.rgba(accent.r, accent.g, accent.b, 0.5) : (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#1affffff" : "#14000000"))

                    Text {
                        id: libelle
                        anchors.centerIn: parent
                        text: modelData.nom
                        color: puce.active ? (Kirigami.Theme.textColor.hslLightness > 0.5 ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.backgroundColor) : Kirigami.Theme.textColor
                        font.bold: puce.active
                    }
                    MouseArea {
                        id: zone
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: puces.choisir(modelData.cle)
                    }
                }
            }
        }
    }
}
