/*
 * Fenestra Search — https://github.com/naykkalak/fenestra-search
 * SPDX-FileCopyrightText: 2026 naykkalak
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // texte tapé (saisi dans la fenêtre, affiché dans la capsule)
    property string texteRecherche: ""
    // fenêtre de recherche ouverte ou non
    property bool fenetreOuverte: false

    // ── Taille de la capsule ──
    // même calcul que l'ancienne capsule : de 70 px à 9 fois la hauteur de la barre,
    // en 12 crans (7 par défaut)
    readonly property int cran: Math.max(0, Math.min(12, Plasmoid.configuration.largeurCran))
    readonly property real largeurMin: 70
    readonly property real largeurMax: height * 9
    Layout.preferredWidth: largeurMin + (largeurMax - largeurMin) * cran / 12
    Layout.preferredHeight: 38
    Layout.minimumWidth: 50
    Layout.minimumHeight: 34

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation

    compactRepresentation: Capsule {
        anchors.fill: parent
        ouverte: root.fenetreOuverte
        texte: root.texteRecherche
        onBasculer: root.fenetreOuverte = !root.fenetreOuverte
        onOuvrir: root.fenetreOuverte = true
    }
    // représentation complète vide : Plasma en attend une pour afficher la capsule,
    // la recherche s'ouvre dans sa propre fenêtre (FenetreRecherche)
    fullRepresentation: Item {}

    // pas de liaison directe : la fenêtre peut se fermer seule (clic ailleurs)
    onFenetreOuverteChanged: {
        fenetre.visible = fenetreOuverte;
        if (!fenetreOuverte) texteRecherche = "";
    }

    // ── Placement : comme le menu Démarrer, 10 px au-dessus de la barre,
    //    centrée sur la capsule, sans sortir de l'écran ──
    function position(largeur, hauteur) {
        var dispo = root.availableScreenRect;
        var ecran = root.screenGeometry;
        var zone = Qt.rect(dispo.x + ecran.x, dispo.y + ecran.y, dispo.width, dispo.height);
        var ecart = 10;
        var x = zone.x + ecart;
        var capsule = root.compactRepresentationItem;
        if (capsule) {
            var coin = capsule.mapToGlobal(0, 0);
            x = coin.x + capsule.width / 2 - largeur / 2;
            if (x < zone.x + ecart) x = zone.x + ecart;
            if (x + largeur > zone.x + zone.width - ecart) x = zone.x + zone.width - largeur - ecart;
        }
        var y = (Plasmoid.location === PlasmaCore.Types.TopEdge)
                ? zone.y + ecart
                : zone.y + zone.height - hauteur - ecart;
        return Qt.point(x, y);
    }
    function placer() {
        var p = position(fenetre.width, fenetre.height);
        fenetre.x = p.x;
        fenetre.y = p.y;
    }

    FenetreRecherche {
        id: fenetre
        racine: root
    }
}
