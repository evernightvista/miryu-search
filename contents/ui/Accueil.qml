/*
 * Fenestra Search — https://github.com/naykkalak/fenestra-search
 * SPDX-FileCopyrightText: 2026 naykkalak
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras

// Accueil (rien de tapé), deux colonnes façon Windows 11 :
//  - à gauche : Récent (documents récents, comme le menu Démarrer) ;
//  - à droite : Recherches rapides (modules de la Configuration du système)
//    puis Top des applications (applications récentes).
Item {
    id: accueil

    property var modeleApps: null     // modèles Kicker, ceux du menu Démarrer
    property var modeleDocs: null
    property int revision: 0          // change à chaque ouverture : listes relues
    signal ouvrirModule(string module)
    signal fini()

    readonly property int largeurColonne: (width - 24) / 2
    readonly property color teinte: Kirigami.Theme.textColor

    function donnee(m, i, role) {
        revision;   // relu à chaque ouverture
        if (!m || i >= m.rowCount()) return "";
        var d = m.data(m.index(i, 0), role);
        return d === undefined || d === null ? "" : d;
    }
    function lancer(m, i) {
        if (!m || i >= m.rowCount() || !("trigger" in m)) return;
        m.trigger(i, "", null);
        fini();
    }

    // ---- Colonne de gauche : Récent ----
    Column {
        id: colonneRecent
        anchors.top: parent.top
        anchors.left: parent.left
        width: accueil.largeurColonne
        spacing: 2

        PlasmaExtras.Heading {
            text: i18n("Recent")
            level: 5
            font.weight: Font.Bold
            color: Qt.rgba(accueil.teinte.r, accueil.teinte.g, accueil.teinte.b, 0.8)
            bottomPadding: 6
        }

        Repeater {
            model: 12
            Item {
                width: colonneRecent.width
                height: 40
                visible: libelleDoc.text.length > 0

                Kirigami.Icon {
                    id: iconeDoc
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 48
                    source: {
                        var d = accueil.donnee(accueil.modeleDocs, index, Qt.DecorationRole);
                        return (typeof d === "string") ? d : "";
                    }
                }
                // nom + dossier, comme les recommandations du menu Démarrer
                Column {
                    anchors.left: iconeDoc.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Text {
                        id: libelleDoc
                        width: parent.width
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.family: Kirigami.Theme.defaultFont.family
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                        color: accueil.teinte
                        text: String(accueil.donnee(accueil.modeleDocs, index, Qt.DisplayRole))
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.family: Kirigami.Theme.defaultFont.family
                        font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 0.9)
                        color: Qt.rgba(accueil.teinte.r, accueil.teinte.g, accueil.teinte.b, 0.6)
                        // 266 = adresse du document dans le modèle Kicker
                        text: String(accueil.donnee(accueil.modeleDocs, index, 266))
                                .replace(/^file:\/\//, "")
                                .replace(/\/[^\/]*$/, "")
                                .replace(/^\/home\/[^\/]+/, i18n("Home"))
                    }
                }
                Rectangle {   // surlignage au survol, valeurs du menu Démarrer
                    anchors.fill: parent
                    anchors.leftMargin: -12
                    visible: survolDoc.containsMouse
                    color: (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#26ffffff" : "#80ffffff")
                    border.width: 1
                    border.color: (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#1affffff" : "#14000000")
                    radius: 5
                    z: -1
                }
                MouseArea {
                    id: survolDoc
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: accueil.lancer(accueil.modeleDocs, index)
                }
            }
        }
    }

    // ---- Colonne de droite ----
    Column {
        id: colonneDroite
        anchors.top: parent.top
        anchors.right: parent.right
        width: accueil.largeurColonne
        spacing: 2

        // Recherches rapides (repliables)
        Item {
            id: titreRapides
            width: parent.width
            height: texteRapides.implicitHeight + 11
            property bool ouvert: true

            PlasmaExtras.Heading {
                id: texteRapides
                anchors.left: parent.left
                anchors.top: parent.top
                text: i18n("Quick searches")
                level: 5
                font.weight: Font.Bold
                color: Qt.rgba(accueil.teinte.r, accueil.teinte.g, accueil.teinte.b, 0.8)
            }
            Item {
                anchors.right: parent.right
                anchors.rightMargin: -6
                anchors.verticalCenter: texteRapides.verticalCenter
                width: 28
                height: 24
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: survolChevron.hovered ? (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#30ffffff" : "#30000000") : "transparent"
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: titreRapides.ouvert ? "arrow-down" : "arrow-up"
                    isMask: true
                    color: accueil.teinte
                }
                HoverHandler { id: survolChevron }
                TapHandler { onTapped: titreRapides.ouvert = !titreRapides.ouvert }
            }
        }

        Rectangle {
            visible: titreRapides.ouvert
            width: parent.width
            height: grilleRapides.height + 16
            radius: 8
            color: (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#14ffffff" : "#40ffffff")
            border.width: 1
            border.color: (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#1affffff" : "#14000000")

            Grid {
                id: grilleRapides
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 8
                columns: 2
                spacing: 8
                readonly property real largeurPuce: (width - spacing) / 2

                Repeater {
                    // module : fichier .desktop de la Configuration du système
                    model: [
                        { libelle: i18n("Audio"),      module: "kcm_pulseaudio" },
                        { libelle: i18n("Bluetooth"),  module: "kcm_bluetooth" },
                        { libelle: i18n("Wi-Fi"),      module: "kcm_networkmanagement" },
                        { libelle: i18n("Display"),    module: "kcm_kscreen" },
                        { libelle: i18n("Colors"),     module: "kcm_colors" },
                        { libelle: i18n("Wallpaper"),  module: "kcm_wallpaper" }
                    ]
                    Item {
                        width: grilleRapides.largeurPuce
                        height: 32
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: survolPuce.hovered ? (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#40ffffff" : "#d0ffffff") : (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#26ffffff" : "#80ffffff")
                            border.width: 1
                            border.color: survolPuce.hovered ? (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#30ffffff" : "#30000000") : (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#1affffff" : "#14000000")
                            z: -1
                        }
                        HoverHandler { id: survolPuce }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: accueil.ouvrirModule(modelData.module)
                        }
                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            font.family: Kirigami.Theme.defaultFont.family
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                            color: accueil.teinte
                            text: modelData.libelle
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 17 }

        PlasmaExtras.Heading {
            text: i18n("Top apps")
            level: 5
            font.weight: Font.Bold
            color: Qt.rgba(accueil.teinte.r, accueil.teinte.g, accueil.teinte.b, 0.8)
            bottomPadding: 11
        }

        Grid {
            id: grilleApps
            columns: 3
            width: parent.width
            spacing: 8
            readonly property real largeurTuile: (width - spacing * (columns - 1)) / columns

            Repeater {
                model: 6
                Item {
                    width: grilleApps.largeurTuile
                    height: 110
                    visible: libelleApp.text.length > 0

                    Rectangle {   // même style que le bouton Démarrer et la barre des tâches
                        anchors.fill: parent
                        radius: 8
                        color: survolTuile.hovered ? (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#40ffffff" : "#d0ffffff") : (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#26ffffff" : "#80ffffff")
                        border.width: 1
                        border.color: survolTuile.hovered ? (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#30ffffff" : "#30000000") : (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#1affffff" : "#14000000")
                        z: -1
                    }
                    HoverHandler { id: survolTuile }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: accueil.lancer(accueil.modeleApps, index)
                    }
                    Kirigami.Icon {
                        id: iconeApp
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        width: 48
                        height: 48
                        source: {
                            var d = accueil.donnee(accueil.modeleApps, index, Qt.DecorationRole);
                            return (typeof d === "string") ? d : "";
                        }
                    }
                    Text {
                        id: libelleApp
                        anchors.top: iconeApp.bottom
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.family: Kirigami.Theme.defaultFont.family
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                        color: accueil.teinte
                        text: String(accueil.donnee(accueil.modeleApps, index, Qt.DisplayRole))
                    }
                }
            }
        }
    }
}
