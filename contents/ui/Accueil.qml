/*
 * Fenestra Search — https://github.com/naykkalak/fenestra-search
 * SPDX-FileCopyrightText: 2026 naykkalak
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras

// Accueil (rien de tapé), deux colonnes façon Windows 11 :
//  - à gauche : Récent (programmes et modules de la Configuration du système
//    ouverts par la recherche, le plus récent en tête) ;
//  - à droite : Recherches rapides (modules de la Configuration du système)
//    puis Top des applications (applications récentes).
Item {
    id: accueil

    property var modeleApps: null     // modèles Kicker, ceux du menu Démarrer
    property var modeleDocs: null
    property var recents: []         // programmes et modules KCM ouverts par la recherche
    property int revision: 0          // change à chaque ouverture : listes relues
    signal ouvrirModule(string module, string libelle)
    signal ouvrirRecent(var item)
    signal supprimerRecent(var item)
    signal ouvrirMenu(var item, var parentItem, int x, int y)
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

    // ---- Colonne de gauche : Récent (programmes et modules KCM ouverts) ----
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
            model: accueil.recents
            Item {
                width: colonneRecent.width
                height: 40

                Kirigami.Icon {
                    id: iconeRecent
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    source: modelData.decoration || ""
                }
                // nom + type (Application / Configuration du système)
                Column {
                    anchors.left: iconeRecent.right
                    anchors.leftMargin: 10
                    anchors.right: boutonSupprimer.left
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Text {
                        id: libelleRecent
                        width: parent.width
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.family: Kirigami.Theme.defaultFont.family
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                        color: accueil.teinte
                        // « libelle » : nom relu dans la langue courante (voir
                        // FenetreRecherche.recentsAffiches) ; repli sur le nom
                        // mémorisé au moment de l'ouverture.
                        text: String(modelData.libelle || modelData.display || "")
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.family: Kirigami.Theme.defaultFont.family
                        font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 0.9)
                        color: Qt.rgba(accueil.teinte.r, accueil.teinte.g, accueil.teinte.b, 0.6)
                        text: modelData.type === "settings"
                              ? i18n("System Settings")
                              : i18n("Application")
                    }
                }
                // bouton « X » de suppression, visible au survol
                Item {
                    id: boutonSupprimer
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    visible: survolRecent.containsMouse
                    z: 2
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: "window-close"
                        isMask: true
                        color: Qt.rgba(accueil.teinte.r, accueil.teinte.g, accueil.teinte.b, 0.6)
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: accueil.supprimerRecent(modelData)
                    }
                }
                Rectangle {   // surlignage au survol, valeurs du menu Démarrer
                    anchors.fill: parent
                    anchors.leftMargin: -12
                    visible: survolRecent.containsMouse
                    color: (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#26ffffff" : "#80ffffff")
                    border.width: 1
                    border.color: (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#1affffff" : "#14000000")
                    radius: 5
                    z: -1
                }
                MouseArea {
                    id: survolRecent
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            accueil.ouvrirMenu(modelData, survolRecent, mouse.x, mouse.y)
                        } else {
                            accueil.ouvrirRecent(modelData)
                        }
                    }
                }
            }
        }
    }

    // message quand la liste des récents est vide : icône + texte centrés dans
    // la colonne « Récent » (sous le titre, jusqu'au bas de la zone), comme
    // dans le menu Démarrer d'origine où le bloc occupe toute la hauteur libre.
    Item {
        id: zoneVideRecent
        anchors.top: colonneRecent.bottom
        anchors.bottom: parent.bottom
        anchors.left: colonneRecent.left
        anchors.right: colonneRecent.right
        visible: accueil.recents.length === 0

        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: 8

            Kirigami.Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 44
                height: 44
                // icône du thème (Breeze) : aucun fichier à livrer avec le widget
                source: "folder-temp"
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: Qt.rgba(accueil.teinte.r, accueil.teinte.g, accueil.teinte.b, 0.5)
                font.family: Kirigami.Theme.defaultFont.family
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                text: i18n("Nothing has been run recently")
                wrapMode: Text.WordWrap
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
                            onClicked: accueil.ouvrirModule(modelData.module, modelData.libelle)
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
