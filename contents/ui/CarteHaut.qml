/*
 * Fenestra Search — https://github.com/naykkalak/fenestra-search
 * SPDX-FileCopyrightText: 2026 naykkalak
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import QtCore
import org.kde.kirigami as Kirigami

// Carte en tête des résultats :
//  - calcul : le résultat en grand (clic = copié dans le presse-papier par KRunner) ;
//  - document en premier résultat : sa vignette (celle que KDE a déjà fabriquée).
Rectangle {
    id: carte

    property var resultat: null       // résultat montré
    property bool calcul: false
    property string texte: ""
    signal lancer(var resultat)

    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color teinte: Kirigami.Theme.textColor

    // chemin local du résultat (sans file://, décodé)
    readonly property string chemin: {
        var u = resultat ? String(resultat.url || "") : "";
        if (u.indexOf("file://") === 0) u = u.substring(7);
        else if (u.indexOf("/") !== 0) return "";
        try { u = decodeURIComponent(u); } catch (e) {}
        return u;
    }
    readonly property bool document: {
        var p = chemin.toLowerCase(), s = p.lastIndexOf("/"), d = p.lastIndexOf(".");
        if (d <= s + 1) return false;
        return ["pdf", "odt", "doc", "docx", "ppt", "pptx", "xls", "xlsx", "ods", "odp", "csv", "cbz", "epub"]
               .indexOf(p.substring(d + 1)) !== -1;
    }
    // vignette du cache de KDE (~/.cache/thumbnails/normal/<md5 de l'adresse>.png)
    readonly property string vignette: {
        if (calcul || !document) return "";
        var uri = "file://" + encodeURI(chemin).replace(/#/g, "%23").replace(/\?/g, "%3F");
        var cache = String(StandardPaths.writableLocation(StandardPaths.GenericCacheLocation)).replace("file://", "");
        return "file://" + encodeURI(cache + "/thumbnails/normal/" + Qt.md5(uri) + ".png");
    }

    visible: texte.length > 0 && resultat !== null && (calcul || vignette.length > 0)
    height: visible ? (vignette.length > 0 ? 92 : 64) : 0
    color: Qt.rgba(accent.r, accent.g, accent.b, zone.containsMouse ? 0.25 : 0.15)
    radius: 10
    border.width: 1
    border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.3)

    Behavior on height { NumberAnimation { duration: 150 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 14

        Rectangle {
            Layout.preferredWidth: carte.vignette.length > 0 ? 68 : 40
            Layout.preferredHeight: Layout.preferredWidth
            radius: 8
            color: carte.accent
            clip: true

            Kirigami.Icon {
                anchors.centerIn: parent
                width: 24
                height: 24
                source: carte.calcul ? "accessories-calculator"
                                     : (carte.resultat ? carte.resultat.decoration : "")
                color: Kirigami.Theme.highlightedTextColor
                visible: image.status !== Image.Ready
            }
            Image {
                id: image
                anchors.fill: parent
                anchors.margins: 1
                source: carte.vignette
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: Math.max(1, width)
                sourceSize.height: Math.max(1, height)
                visible: source.length > 0 && status === Image.Ready
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: 2
            Text {
                width: parent.width
                text: carte.resultat ? (carte.resultat.display || "") : ""
                font.pixelSize: carte.vignette.length > 0
                    ? Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.25)
                    : Math.round(Kirigami.Theme.defaultFont.pixelSize * 2)
                font.bold: true
                color: carte.teinte
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: carte.vignette.length > 0 ? carte.chemin.replace(/^\/home\/[^\/]+\//, "") : carte.texte
                font.family: Kirigami.Theme.smallFont.family
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: Qt.rgba(carte.teinte.r, carte.teinte.g, carte.teinte.b, 0.6)
                elide: Text.ElideRight
            }
        }

        Kirigami.Icon {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            source: "edit-copy"
            color: Qt.rgba(carte.teinte.r, carte.teinte.g, carte.teinte.b, 0.5)
        }
    }

    MouseArea {
        id: zone
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (carte.resultat) carte.lancer(carte.resultat)
    }
}
