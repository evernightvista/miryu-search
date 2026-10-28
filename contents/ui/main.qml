/*
 * Fenestra Search — https://github.com/naykkalak/fenestra-search
 * SPDX-FileCopyrightText: 2026 naykkalak
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // texte tapé (saisi dans la fenêtre, affiché dans la capsule)
    property string texteRecherche: ""
    // complétion proposée (reste du meilleur résultat, affichée en demi-teinte dans la capsule)
    property string suggestion: ""
    // fenêtre de recherche ouverte ou non
    property bool fenetreOuverte: false
    // icône seule dans la barre (clic droit sur la capsule pour basculer)
    readonly property bool iconeSeule: Plasmoid.configuration.iconeSeule

    // ── Taille de la capsule ──
    // même calcul que l'ancienne capsule : de 70 px à 9 fois la hauteur de la barre,
    // en 12 crans (7 par défaut)
    readonly property int cran: Math.max(0, Math.min(12, Plasmoid.configuration.largeurCran))
    readonly property real largeurMin: 70
    readonly property real largeurMax: height * 9
    Layout.preferredWidth: iconeSeule ? Layout.preferredHeight
                                      : largeurMin + (largeurMax - largeurMin) * cran / 12
    Layout.preferredHeight: 38
    Layout.minimumWidth: iconeSeule ? Layout.minimumHeight : 50
    Layout.minimumHeight: 34

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation


    // clic droit sur la capsule : bascule « icône seule »
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Show icon only")
            icon.name: "view-list-icons"
            checkable: true
            checked: Plasmoid.configuration.iconeSeule
            onTriggered: Plasmoid.configuration.iconeSeule = checked
        }
    ]

    compactRepresentation: Capsule {
        anchors.fill: parent
        ouverte: root.fenetreOuverte
        texte: root.texteRecherche
        suggestion: root.suggestion
        iconeSeule: root.iconeSeule
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

    // ── Raccourci global (ex. Win+S) ──
    // Plasma déploie l'applet (panneau de la représentation complète, vide ici)
    // quand le raccourci est pressé : on l'interdit dans tous les cas, puis on
    // bascule la vraie fenêtre de recherche.
    Connections {
        target: Plasmoid
        ignoreUnknownSignals: true
        function onActivated() {
            root.fenetreOuverte = !root.fenetreOuverte; // ouvre / ferme la fenêtre
            Qt.callLater(function() { root.expanded = false; });  // referme le panneau de Plasma
        }
    }
    // verrou : le panneau Plasma ne s'ouvre jamais, même si Plasma le demande après
    onExpandedChanged: if (expanded) expanded = false

    // ── 默认快捷键：Win+S ──
    // 首次使用时把 Win+S（Win 键即 Meta）设为激活快捷键；Plasma 只把这种
    // 设置记成「自定义快捷键」，所以同时让脚本往 kglobalaccel 里补写一份
    // 「默认快捷键」，系统设置里才会显示在「默认快捷键」一栏（带勾选框）。
    // 只应用一次：之后用户在系统设置里改掉或清空，都不会被覆盖。
    Component.onCompleted: {
        if (Plasmoid.configuration.raccourciDefautEcrit) {
            return;
        }
        if (Plasmoid.globalShortcut.toString().length === 0) {
            Plasmoid.globalShortcut = "Meta+S";
        }
        appliquerRaccourciDefaut();
        Plasmoid.configuration.raccourciDefautEcrit = true;
    }

    // Plasma 没有给 plasmoid 声明默认快捷键的接口，只能通过 kglobalaccel
    // 的 D-Bus 接口（setShortcutKeys + IsDefault）写入，见 code/raccourci-defaut.sh
    Plasma5Support.DataSource {
        id: raccourciDefaut
        engine: "executable"
        onNewData: (source, donnees) => disconnectSource(source)
    }

    function appliquerRaccourciDefaut() {
        var script = String(Qt.resolvedUrl("../code/raccourci-defaut.sh")).replace("file://", "");
        // 动作名与 Applet::setGlobalShortcut 里的 objectName 一致
        raccourciDefaut.connectSource("sh '" + script + "' 'activate widget " + Plasmoid.id + "'");
    }

    // ── Placement : calcul manuel calqué sur miryu-start ──
    // FenetreRecherche positionne elle-même sa fenêtre en fonction de
    // availableScreenRect / screenGeometry, centre la fenêtre sur la capsule,
    // supprime la bordure du côté du panneau (floating: 0) et borne la hauteur
    // pour éviter le chevauchement avec la barre des tâches et garder les
    // coins arrondis visibles en basse résolution.

    FenetreRecherche {
        id: fenetre
        racine: root
    }
}
