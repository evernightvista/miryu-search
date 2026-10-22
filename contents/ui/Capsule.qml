/*
 * Fenestra Search — https://github.com/naykkalak/fenestra-search
 * SPDX-FileCopyrightText: 2026 naykkalak
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Capsule de la barre des tâches : elle n'est PAS un champ de saisie.
// Elle affiche le texte tapé dans la fenêtre (champ invisible), avec un curseur simulé :
// pas de problème de clavier sous Wayland en début de session.
Item {
    id: capsule

    property bool ouverte: false
    property string texte: ""
    // suggestion de complétion : le reste du meilleur résultat (ex. « kd » + « E Connect »)
    property string suggestion: ""
    property bool iconeSeule: false
    signal basculer()
    signal ouvrir()
    // clic dans la capsule : abandonne la sélection (Ctrl+A)
    signal annulerSelection()

    readonly property bool themeSombre: Kirigami.Theme.textColor.hslLightness > 0.5

    // reflète dans la capsule la sélection du champ de saisie de la fenêtre :
    // Ctrl+A (tout sélectionner), Maj+flèches, glisser à la souris…
    function selectionner(debut, fin) {
        if (affichage.vide) { libelle.deselect(); return; }
        if (fin > debut) libelle.select(debut, fin);
        else libelle.deselect();
    }

    function deselectionner() {
        libelle.deselect();
    }

    // ── Oreille PARTAGÉE avec le menu Démarrer (Fenestra Menu 11) ──
    // Une seule poignée passive posée sur la racine de la barre (objectName
    // fenestraOreilleBarre) : chaque widget s'y branche. Clic sur la barre en dehors
    // de la capsule -> fenêtre fermée.
    property QtObject oreille: null

    function racineBarre() {
        var p = capsule;
        while (p.parent) p = p.parent;
        return p;
    }
    function remettreOreille() {
        if (!oreille) return;
        oreille.enabled = false;
        oreille.enabled = true;
    }
    function oreillePartagee(haut) {
        var nom = "fenestraOreilleBarre";
        for (var i = 0; i < haut.data.length; i++) {
            var o = haut.data[i];
            if (o && o.objectName === nom) return o;
        }
        return Qt.createQmlObject(
            "import QtQuick\nPointHandler { objectName: \"fenestraOreilleBarre\"; acceptedButtons: Qt.LeftButton | Qt.RightButton }",
            haut, nom);
    }
    function poserOreille() {
        var haut = racineBarre();
        if (!haut || haut === capsule) return;
        if (oreille && oreille.parent === haut) return;
        oreille = oreillePartagee(haut);
        oreille.activeChanged.connect(function() {
            if (!oreille || !oreille.active) return;
            Qt.callLater(capsule.remettreOreille);
            if (!capsule.ouverte) return;
            var s = oreille.point.scenePosition;
            var l = capsule.mapFromItem(null, s.x, s.y);
            if (l.x >= 0 && l.y >= 0 && l.x < capsule.width && l.y < capsule.height) return;
            capsule.basculer();
        });
    }
    onOuverteChanged: {
        if (ouverte) {
            poserOreille();
            remettreOreille();
        }
    }
    Component.onDestruction: oreille = null   // partagée : on ne la détruit pas

    Rectangle {
        id: fond
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 0.5
        height: parent.height - 1
        radius: height / 2
        color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g,
                       Kirigami.Theme.backgroundColor.b, 0.95)
        border.width: 1
        border.color: capsule.ouverte ? Kirigami.Theme.highlightColor
                      : (capsule.themeSombre ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.18))

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Kirigami.Icon {
                Layout.preferredWidth: fond.height * 0.65
                Layout.preferredHeight: Layout.preferredWidth
                // icône seule : centrée dans la capsule
                Layout.fillWidth: capsule.iconeSeule
                Layout.alignment: Qt.AlignVCenter | (capsule.iconeSeule ? Qt.AlignHCenter : 0)
                source: Qt.resolvedUrl("../images/loupe.svg")
            }

            // affichage façon champ de saisie : texte tapé + suggestion de complétion
            // + curseur clignotant. Le texte est un TextEdit en lecture seule : on peut
            // le sélectionner à la souris (fond en couleur d'accent, texte en blanc),
            // comme sur la capture « normale » — sans jamais lui donner le focus clavier.
            Item {
                id: affichage
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                visible: !capsule.iconeSeule

                readonly property bool vide: capsule.texte === ""
                readonly property bool aSuggestion: !vide && capsule.suggestion.length > 0

                // largeur totale affichée (texte tapé + suggestion), pour le défilement :
                // un texte trop long défile vers la gauche, la fin reste visible
                readonly property real largeurTexte: libelle.implicitWidth
                    + (aSuggestion ? complement.implicitWidth + 2 : 0)
                readonly property real baseX: Math.min(0, parent.width - curseur.width - 1 - largeurTexte)

                TextEdit {
                    id: libelle
                    x: affichage.baseX
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -1
                    text: affichage.vide ? i18n("Search") : capsule.texte
                    readOnly: true                     // saisie réelle dans la fenêtre : ici affichage seul
                    activeFocusOnPress: false          // ne vole jamais le focus clavier de la fenêtre
                    selectByMouse: !affichage.vide     // sélection à la souris sur le texte tapé
                    // la sélection reste visible alors que le focus clavier est
                    // dans la fenêtre : c'est ce qui rend Ctrl+A visible ici
                    persistentSelection: true
                    selectionColor: Kirigami.Theme.highlightColor
                    selectedTextColor: Kirigami.Theme.highlightedTextColor
                    // le texte est remplacé (frappe) ou changé : la sélection ne suit plus
                    onTextChanged: deselect()
                    color: affichage.vide
                           ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                     Kirigami.Theme.textColor.b, 0.55)
                           : Kirigami.Theme.textColor
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                    font.family: Kirigami.Theme.defaultFont.family
                    cursorVisible: false               // le curseur clignotant est simulé ci-dessous

                    // un simple clic sur le texte abandonne la sélection
                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        enabled: capsule.ouverte && !affichage.vide
                        onTapped: capsule.annulerSelection()
                    }
                }

                // suggestion de complétion : affichée en demi-teinte après le texte tapé
                Text {
                    id: complement
                    x: affichage.baseX + libelle.implicitWidth + 2
                    anchors.verticalCenter: libelle.verticalCenter
                    anchors.verticalCenterOffset: -1
                    visible: affichage.aSuggestion
                    text: capsule.suggestion
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                   Kirigami.Theme.textColor.b, 0.45)
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                    font.family: Kirigami.Theme.defaultFont.family
                }

                Rectangle {   // curseur : au début si vide, après le texte tapé (avant la suggestion) sinon
                    id: curseur
                    width: 1
                    height: Math.round(libelle.font.pixelSize * 1.2)
                    anchors.verticalCenter: parent.verticalCenter
                    x: affichage.vide ? 0 : Math.min(affichage.baseX + libelle.implicitWidth + 1,
                                                     parent.width - width)
                    color: Kirigami.Theme.textColor
                    visible: capsule.ouverte && clignote.allume
                }
                Timer {
                    id: clignote
                    property bool allume: true
                    interval: 530
                    repeat: true
                    running: capsule.ouverte
                    onRunningChanged: allume = true
                    onTriggered: allume = !allume
                }
            }
        }

        MouseArea {
            id: zone
            anchors.fill: parent
            // icône seule : curseur normal ; champ : curseur texte
            cursorShape: capsule.iconeSeule ? Qt.ArrowCursor : Qt.IBeamCursor
            // dès qu'il y a du texte saisi et que la fenêtre est ouverte (hors mode
            // icône seule, où la capsule n'affiche rien), la souris revient au TextEdit
            // pour pouvoir sélectionner les caractères (avec surlignage)
            enabled: capsule.iconeSeule || affichage.vide || !capsule.ouverte
            onClicked: capsule.ouverte ? capsule.basculer() : capsule.ouvrir()
        }
    }

    // clic hors du texte (icône, marges) : abandonne aussi la sélection
    TapHandler {
        acceptedButtons: Qt.LeftButton
        enabled: capsule.ouverte && !affichage.vide
        onTapped: capsule.annulerSelection()
    }
}
