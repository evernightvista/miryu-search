/*
 * Fenestra Search — https://github.com/naykkalak/fenestra-search
 * SPDX-FileCopyrightText: 2026 naykkalak
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PlasmaComponents
import "Classement.js" as Classement

// Liste des résultats, regroupés par rubrique
PlasmaComponents.ScrollView {
    id: liste

    property var resultats: []
    property bool enCours: false      // recherche lancée, résultats pas encore arrivés
    property string texte: ""
    property int courant: 0

    signal lancer(var resultat)

    onResultatsChanged: courant = 0

    function monter() { if (courant > 0) courant--; }
    function descendre() { if (courant < vue.count - 1) courant++; }
    function lancerCourant() {
        if (courant < 0 || courant >= resultats.length) return false;
        lancer(resultats[courant]);
        return true;
    }

    clip: true
    PlasmaComponents.ScrollBar.vertical.policy: PlasmaComponents.ScrollBar.AlwaysOff

    ListView {
        id: vue
        width: parent.width
        height: parent.height
        model: liste.resultats
        spacing: 4
        currentIndex: liste.courant
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 0      // pas de traîne quand la souris déplace la sélection
        highlightResizeDuration: 0
        section.property: "rubrique"

        // rien trouvé (ou recherche en cours)
        Column {
            anchors.centerIn: parent
            spacing: 10
            visible: liste.resultats.length === 0 && liste.texte.length > 0

            PlasmaComponents.BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: liste.enCours
                visible: liste.enCours
            }
            Text {
                text: liste.enCours ? i18n("Searching…") : i18n("No results found")
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.5)
                font.family: Kirigami.Theme.defaultFont.family
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            }
        }

        // surlignage façon KRunner : pleine couleur d'accent, coins arrondis
        highlight: Rectangle {
            color: Kirigami.Theme.highlightColor
            radius: 6
        }

        section.delegate: Item {
            width: vue.width
            height: 40
            PlasmaExtras.Heading {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: section
                level: 5
                font.weight: Font.Bold
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.8)
            }
        }

        delegate: Item {
            id: ligne
            width: vue.width
            height: contenu.implicitHeight + 12
            readonly property bool choisie: vue.currentIndex === index

            Rectangle {
                anchors.fill: parent
                // sélection : accent plein (comme KRunner) ; survol seul : léger voile
                color: ligne.choisie ? Kirigami.Theme.highlightColor
                     : (survol.containsMouse ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                        Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.35)
                     : "transparent")
                radius: 6

                RowLayout {
                    id: contenu
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6
                    spacing: 12

                    Kirigami.Icon {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        source: modelData.decoration
                        // ligne sélectionnée : texte et icône en couleur « surlignée » (KRunner)
                        color: ligne.choisie ? Kirigami.Theme.highlightedTextColor
                                             : Kirigami.Theme.textColor
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: modelData.display || ""
                            color: ligne.choisie ? Kirigami.Theme.highlightedTextColor
                                                 : Kirigami.Theme.textColor
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: Classement.cheminCourt(modelData)
                            color: ligne.choisie
                                   ? Qt.rgba(Kirigami.Theme.highlightedTextColor.r, Kirigami.Theme.highlightedTextColor.g,
                                             Kirigami.Theme.highlightedTextColor.b, 0.8)
                                   : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.6)
                            font.family: Kirigami.Theme.smallFont.family
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            MouseArea {
                id: survol
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: liste.courant = index      // la souris prend la sélection
                onClicked: liste.lancer(modelData)
            }
        }
    }
}
