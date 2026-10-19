/*
 * Fenestra Search — https://github.com/naykkalak/fenestra-search
 * SPDX-FileCopyrightText: 2026 naykkalak
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Bandeau du bas, comme le pied du menu Démarrer.
// « Retour » apparaît dès qu'une recherche est tapée : il revient à l'accueil.
Rectangle {
    id: bandeau

    property bool recherche: false
    signal retour()

    height: Kirigami.Units.gridUnit * 3 + 8
    color: (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#40000000" : "#b3e0e0ee")

    Rectangle {   // trait de séparation
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#1affffff" : "#14000000")
    }

    Item {
        id: boutonRetour
        anchors.left: parent.left
        anchors.leftMargin: Kirigami.Units.gridUnit
        anchors.verticalCenter: parent.verticalCenter
        width: contenuRetour.implicitWidth + 20
        height: 24
        visible: bandeau.recherche

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: survolRetour.hovered ? (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#2effffff" : "#85ffffff") : "transparent"
            border.width: 1
            border.color: survolRetour.hovered ? (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#26ffffff" : "#20000000") : "transparent"
        }
        RowLayout {
            id: contenuRetour
            anchors.centerIn: parent
            spacing: 6
            Kirigami.Icon {
                source: "go-previous"
                isMask: true
                color: Kirigami.Theme.textColor
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                text: i18n("Back")
                font.family: Kirigami.Theme.defaultFont.family
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                color: Kirigami.Theme.textColor
                Layout.alignment: Qt.AlignVCenter
            }
        }
        HoverHandler { id: survolRetour }
        TapHandler { onTapped: bandeau.retour() }
    }
}
