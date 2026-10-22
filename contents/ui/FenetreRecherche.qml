/*
 * Fenestra Search — https://github.com/naykkalak/fenestra-search
 * SPDX-FileCopyrightText: 2026 naykkalak
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.milou as Milou
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.private.kicker 0.1 as Kicker
import "Classement.js" as Classement
import "Moteurs.js" as Moteurs

// Fenêtre de recherche : SA PROPRE fenêtre (PlasmaCore.Dialog), comme le menu Démarrer.
// La fenêtre standard d'un widget de barre n'obtient pas le clavier en début de session
// sous Wayland ; une Dialog, si.
PlasmaCore.Dialog {
    id: fenetre

    property var racine: null
    readonly property string texte: racine ? racine.texteRecherche : ""
    property string filtre: "All"
    // mode « icône seule » : champ de recherche visible en haut de la fenêtre
    readonly property bool iconeSeule: Plasmoid.configuration.iconeSeule
    readonly property int hauteurSaisie: iconeSeule ? 54 : 0

    // taille du contenu : la hauteur est bornée à l'écran utile afin d'éviter
    // tout chevauchement avec la barre des tâches et de garder les coins
    // arrondis du haut visibles en basse résolution (même approche que miryu-start).
    readonly property int largeurContenu: {
        var ecran = racine ? racine.availableScreenRect.width : 0;
        if (!isFinite(ecran) || ecran <= 0) return 800;
        var offset = Kirigami.Units.smallSpacing;
        return Math.min(800, Math.max(200, ecran - 2 * offset));
    }
    readonly property int hauteurVoulue: 830
    readonly property int hauteurMin: 200
    property int hauteurContenu: hauteurVoulue

    function calculerHauteurContenu() {
        var ecran = racine ? racine.availableScreenRect.height : 0;
        if (!isFinite(ecran) || ecran <= 0) return hauteurVoulue;
        var m = fenetre.margins;
        var mt = (m && isFinite(m.top)) ? m.top : 0;
        var mb = (m && isFinite(m.bottom)) ? m.bottom : 0;
        // On réserve les marges haute ET basse du cadre + un petit espace en haut :
        // la fenêtre tient toujours entre le bord supérieur de l'écran utile et la
        // barre des tâches — elle ne la recouvre jamais, même en basse résolution,
        // et les coins arrondis du haut restent visibles.
        var espaceHaut = mt + Kirigami.Units.smallSpacing;
        var maxH = Math.max(hauteurMin, ecran - mt - mb - espaceHaut);
        return Math.min(hauteurVoulue, maxH);
    }

    // Référence explicite à la capsule pour le centrage horizontal
    property Item capsule: racine ? racine.compactRepresentationItem : null

    // Supprime la bordure du côté de la barre (comme miryu-start) : la fenêtre
    // vient se plaquer contre la barre des tâches au lieu de la recouvrir.
    floating: 0
    location: Plasmoid.location
    flags: Qt.WindowStaysOnTopHint
    hideOnWindowDeactivate: true
    visible: false

    property int ouvertures: 0         // compte les ouvertures : l'accueil se relit

    function activer() {
        fenetre.requestActivate();
        saisie.forceActiveFocus();
    }

    // La capsule n'est qu'un affichage : on lui reflète la sélection du vrai champ
    // de saisie (Ctrl+A, Maj+flèches…), sinon elle resterait sans surlignage.
    function refleterSelection() {
        var c = fenetre.capsule;
        if (c && c.selectionner)
            c.selectionner(saisie.selectionStart, saisie.selectionEnd);
    }

    // clic dans la zone de recherche : on abandonne la sélection (Ctrl+A)
    function annulerSelection() {
        // selectionStart/selectionEnd sont en lecture seule sur un TextField Plasma :
        // on retire la sélection par la méthode dédiée
        saisie.deselect();
        var c = fenetre.capsule;
        if (c && c.deselectionner)
            c.deselectionner();
    }

    function fermer() {
        racine.fenetreOuverte = false;
    }

    function borne(minV, maxV, v) { return Math.max(minV, Math.min(v, maxV)); }

    // Positionnement manuel calqué sur miryu-start : centré sur la capsule,
    // collé à la barre du côté du panneau, et borné pour rester à l'écran.
    function popupPosition(width, height) {
        var screenAvail = racine ? racine.availableScreenRect : Qt.rect(0, 0, 0, 0);
        var screenGeom = racine ? racine.screenGeometry : Qt.rect(0, 0, 0, 0);
        var screen = Qt.rect(screenAvail.x + screenGeom.x,
                             screenAvail.y + screenGeom.y,
                             screenAvail.width, screenAvail.height);
        var offset = Kirigami.Units.smallSpacing;
        var m = fenetre.margins;
        var mt = (m && isFinite(m.top)) ? m.top : 0;
        var mb = (m && isFinite(m.bottom)) ? m.bottom : 0;
        var ml = (m && isFinite(m.left)) ? m.left : 0;
        var mr = (m && isFinite(m.right)) ? m.right : 0;
        var espaceHaut = mt + Kirigami.Units.smallSpacing;

        var hauteurFenetre = (isFinite(height) && height > 0)
            ? height
            : (fenetre.hauteurContenu + mt + mb);

        var appletTopLeft = capsule ? capsule.mapToGlobal(0, 0) : Qt.point(0, 0);
        var x = screen.x + offset;
        var y = screen.y + screen.height - hauteurFenetre;

        if (Plasmoid.location === PlasmaCore.Types.BottomEdge) {
            var centreBoutonX = appletTopLeft.x + capsule.width / 2;
            x = borne(screen.x + offset,
                      screen.x + screen.width - width - offset,
                      centreBoutonX - width / 2);
            y = screen.y + screen.height - hauteurFenetre;
            // Ancrage de sécurité sur la barre : le bas de la fenêtre ne descend
            // jamais sous le haut réel de la capsule (haut de la barre des tâches),
            // même si availableScreenRect est imprécis.
            if (isFinite(appletTopLeft.y) && appletTopLeft.y > 0)
                y = Math.min(y, appletTopLeft.y - hauteurFenetre);
        } else if (Plasmoid.location === PlasmaCore.Types.TopEdge) {
            var centreBoutonHautX = appletTopLeft.x + capsule.width / 2;
            x = borne(screen.x + offset,
                      screen.x + screen.width - width - offset,
                      centreBoutonHautX - width / 2);
            y = screen.y;
        } else if (Plasmoid.location === PlasmaCore.Types.LeftEdge) {
            var centreBoutonY = appletTopLeft.y + capsule.height / 2;
            x = appletTopLeft.x + capsule.width + mr + offset;
            y = borne(screen.y + offset,
                      screen.y + screen.height - hauteurFenetre - offset,
                      centreBoutonY - hauteurFenetre / 2);
        } else if (Plasmoid.location === PlasmaCore.Types.RightEdge) {
            var centreBoutonDroitY = appletTopLeft.y + capsule.height / 2;
            x = appletTopLeft.x - ml - offset - width;
            y = borne(screen.y + offset,
                      screen.y + screen.height - hauteurFenetre - offset,
                      centreBoutonDroitY - hauteurFenetre / 2);
        }

        // Sécurité finale : le bas de la fenêtre ne passe jamais sous le bas de
        // l'écran utile (la barre des tâches n'est jamais recouverte)…
        if (y + hauteurFenetre > screen.y + screen.height)
            y = screen.y + screen.height - hauteurFenetre;
        // … et le haut ne dépasse pas le bord supérieur (coins arrondis visibles).
        if (y < screen.y + espaceHaut) y = screen.y + espaceHaut;
        return Qt.point(x, y);
    }

    onVisibleChanged: {
        if (visible) {
            ouvertures++;
            // Borne la hauteur du contenu à l'écran utile, applique la taille
            // à la fenêtre, puis la positionne. On recalcule une fois après le
            // chargement des marges du cadre par Plasma.
            fenetre.hauteurContenu = fenetre.calculerHauteurContenu();
            var m = fenetre.margins;
            var ml = (m && isFinite(m.left)) ? m.left : 0;
            var mr = (m && isFinite(m.right)) ? m.right : 0;
            var mt = (m && isFinite(m.top)) ? m.top : 0;
            var mb = (m && isFinite(m.bottom)) ? m.bottom : 0;
            fenetre.width = fenetre.largeurContenu + ml + mr;
            fenetre.height = fenetre.hauteurContenu + mt + mb;
            var pos = fenetre.popupPosition(fenetre.width, fenetre.height);
            fenetre.x = pos.x;
            fenetre.y = pos.y;
            ajustementTaille.restart();
            activer();
            Qt.callLater(activer);            // une seconde fois, fenêtre réellement affichée
        } else {
            saisie.text = "";
            filtre = "All";
            if (racine.fenetreOuverte) racine.fenetreOuverte = false;   // fermée seule
        }
    }

    onWidthChanged: {
        if (visible) {
            var pos = popupPosition(width, height);
            x = pos.x;
            y = pos.y;
        }
    }

    onHeightChanged: {
        if (visible) {
            var pos = popupPosition(width, height);
            x = pos.x;
            y = pos.y;
        }
    }

    // ── Moteur : KRunner (via Milou) ──
    property string requete: ""        // envoyée à KRunner 60 ms après la dernière touche
    property var resultats: []         // classés et regroupés (Classement.js)
    property bool enCours: false
    property var carteResultat: null   // carte du haut : calcul ou premier document
    property bool carteCalcul: false
    // suggestion de complétion : le reste du meilleur résultat (ex. « kd » → « E Connect »)
    property string suggestion: ""

    // ── Recherche web : dernière ligne de la liste ──
    property string sortieKde: ""      // moteur choisi dans KDE (lu par code/moteur-kde.sh)
    readonly property var moteur: {
        var choix = Plasmoid.configuration.moteurWeb;
        return (choix && choix !== "kde" && Moteurs.trouver(choix)) || Moteurs.depuisKde(sortieKde);
    }

    onTexteChanged: relancer()
    onFiltreChanged: relancer()

    function relancer() {
        enCours = texte.length > 0;
        if (texte.length > 0) {
            finAttente.restart();
            attenteFrappe.restart();
        } else {
            attenteFrappe.stop();
            finAttente.stop();
            requete = "";
            resultats = [];
            carteResultat = null;
            suggestion = "";
            if (racine) racine.suggestion = "";
        }
    }

    // complétion proposée : le meilleur résultat qui commence par le texte tapé
    function calculerSuggestion() {
        if (texte.length === 0 || resultats.length === 0) return "";
        var r = resultats[0];
        if (!r || r.web) return "";
        var affiche = (r.display || "").toString();
        if (affiche.length === 0) return "";
        if (affiche.toLowerCase().indexOf(texte.toLowerCase()) === 0)
            return affiche.substring(texte.length);
        return "";
    }

    function reclasser() {
        if (texte.length === 0) { resultats = []; return; }
        var bruts = [];
        for (var i = 0; i < copie.count; i++) {
            var o = copie.objectAt(i);
            if (!o) continue;
            var url = (o.url || "").toString();
            if (Classement.estLogitheque(o.category, url)) continue;   // pas d'applis « à obtenir »
            var icone = (o.decoration || "").toString();
            if (icone === "" || icone === "QIcon()")
                icone = /^https?:\/\//.test(url) ? "internet-web-browser" : "application-x-executable";
            bruts.push({
                display: (o.display || "").toString(),
                decoration: icone,
                category: (o.category || "Other").toString(),
                url: url,
                subtext: (o.subtext || "").toString(),
                duplicateId: (o.duplicateId || "").toString(),
                index: o.rang
            });
        }
        var liste = Classement.classer(bruts, texte, filtre, filtre === "All" ? 20 : 120,
                                       i18n("Best match"));

        // carte du haut : le calcul si KRunner en propose un en premier, sinon le premier résultat
        var calc = bruts.length > 0 && Classement.estCalcul(bruts[0].category, bruts[0].decoration, bruts[0].duplicateId);
        carteCalcul = calc;
        carteResultat = calc ? bruts[0] : (liste.length > 0 ? liste[0] : null);

        if (filtre === "All" || filtre === "Web") {
            liste.push({
                web: true,
                display: i18n("Search “%1” on %2", texte, moteur.nom),
                decoration: "internet-web-browser",
                category: "Web",
                url: Moteurs.adresse(moteur, texte),
                subtext: Moteurs.domaine(moteur),
                duplicateId: "",
                rubrique: i18n("Web search")
            });
        }
        resultats = liste;
        // complétion proposée dans la capsule (le texte tapé + le reste du meilleur résultat)
        suggestion = calculerSuggestion();
        if (racine) racine.suggestion = suggestion;
        if (requete === texte) {
            enCours = false;
            finAttente.stop();
        }
    }

    // ouvre un résultat puis ferme la fenêtre
    function lancer(r) {
        if (!r) return;
        var url = r.url || "";
        if (r.web) {
            Qt.openUrlExternally(url);
        } else if (Classement.estApplication(r.category, url, r.duplicateId, r.decoration)) {
            modele.run(modele.index(r.index, 0));
        } else if (url.length > 0 && url.indexOf("http") !== 0) {
            Qt.openUrlExternally(url);        // fichier ou dossier : ouvert directement
        } else {
            modele.run(modele.index(r.index, 0));
        }
        fermer();
    }

    mainItem: Item {
        id: contenu
        // La taille du contenu est bornée à l'écran utile pour éviter le
        // chevauchement de la barre des tâches et garder les coins arrondis.
        width: fenetre.largeurContenu
        height: fenetre.hauteurContenu
        Layout.minimumWidth: fenetre.largeurContenu
        Layout.maximumWidth: fenetre.largeurContenu
        Layout.minimumHeight: fenetre.hauteurContenu
        Layout.maximumHeight: fenetre.hauteurContenu

        // objets non visuels ici : une Dialog n'accepte que des éléments graphiques
        Milou.ResultsModel {
            id: modele
            queryString: fenetre.requete
            limit: fenetre.filtre === "All" ? 20 : 120
        }

        Timer {   // on attend la fin de la frappe avant d'interroger KRunner
            id: attenteFrappe
            interval: 60
            onTriggered: {
                fenetre.requete = fenetre.texte;
                fenetre.reclasser();
            }
        }
        Timer {   // les résultats arrivent par vagues : on regroupe les mises à jour
            id: attenteResultats
            interval: 24
            onTriggered: fenetre.reclasser()
        }
        Timer {   // « Recherche… » ne reste pas affiché indéfiniment
            id: finAttente
            interval: 900
            onTriggered: fenetre.enCours = false
        }
        Timer {   // recalcule la hauteur idéale après le chargement des marges du cadre
            id: ajustementTaille
            interval: 30
            repeat: false
            onTriggered: {
                if (!fenetre.visible) return;
                var nouvelleHauteur = fenetre.calculerHauteurContenu();
                if (nouvelleHauteur !== fenetre.hauteurContenu)
                    fenetre.hauteurContenu = nouvelleHauteur;
                ajustementPosition.restart();
            }
        }
        Timer {   // repositionne la fenêtre après un redimensionnement / chargement des marges
            id: ajustementPosition
            interval: 30
            repeat: false
            onTriggered: {
                if (!fenetre.visible) return;
                var pos = fenetre.popupPosition(fenetre.width, fenetre.height);
                fenetre.x = pos.x;
                fenetre.y = pos.y;
            }
        }

        // moteur web de KDE (Configuration système > Recherche web), lu une fois à l'ouverture
        Plasma5Support.DataSource {
            id: lectureKde
            engine: "executable"
            readonly property string commande: "sh '" + String(Qt.resolvedUrl("../code/moteur-kde.sh")).replace("file://", "") + "'"
            onNewData: (source, donnees) => {
                fenetre.sortieKde = String(donnees["stdout"] || "");
                disconnectSource(source);
            }
        }
        Connections {
            target: fenetre
            function onVisibleChanged() {
                if (fenetre.visible && Plasmoid.configuration.moteurWeb === "kde")
                    lectureKde.connectSource(lectureKde.commande);
            }
        }
        // clic dans la capsule (zone de recherche) : fin de la sélection Ctrl+A
        Connections {
            target: fenetre.capsule
            ignoreUnknownSignals: true
            function onAnnulerSelection() { fenetre.annulerSelection(); }
        }

        // accueil : même source que le menu Démarrer (Kicker), seulement les récents
        Kicker.RootModel {
            id: modeleRecents
            autoPopulate: false
            appNameFormat: 0
            flat: true
            sorted: true
            showAllAppsCategorized: false
            showSeparators: false
            appletInterface: fenetre.racine
            showAllApps: false
            showRecentApps: true
            showRecentDocs: true
            showPowerSession: false
            Component.onCompleted: refresh()
        }

        // ouverture d'un module de la Configuration du système
        Plasma5Support.DataSource {
            id: commande
            engine: "executable"
            onNewData: (source, donnees) => disconnectSource(source)
        }

        // copie des résultats du modèle, lisible en JavaScript
        Instantiator {
            id: copie
            model: modele
            delegate: QtObject {
                property int rang: index
                property var category: model.category !== undefined ? model.category
                                     : (model.matchCategory !== undefined ? model.matchCategory : "")
                property var display: model.display || ""
                property var decoration: model.decoration || ""
                property var url: model.url || ""
                property var subtext: model.subtext || ""
                property var duplicateId: model.duplicateId || ""
            }
            onCountChanged: attenteResultats.restart()
        }
        Connections {
            target: modele
            function onRowsInserted() { attenteResultats.restart(); }
            function onRowsRemoved() { attenteResultats.restart(); }
            function onModelReset() { attenteResultats.restart(); }
            function onDataChanged() { attenteResultats.restart(); }
        }

        Item {
            id: cadre
            // suit la taille réelle de mainItem : si Plasma la réduit au
            // contenu utile, le contenu suit au lieu d'être tronqué
            anchors.fill: parent

            // en mode « icône seule », la capsule n'affiche plus le texte :
            // le champ de recherche remonte en haut de la fenêtre et devient visible
            PlasmaComponents.TextField {
                id: saisie
                x: 12
                y: 10
                width: fenetre.iconeSeule ? parent.width - 24 : 1
                height: fenetre.iconeSeule ? 34 : 1
                opacity: fenetre.iconeSeule ? 1 : 0
                placeholderText: i18n("Search")
                onTextChanged: racine.texteRecherche = text
                onAccepted: listeResultats.lancerCourant()
                Keys.onEscapePressed: fenetre.fermer()
                Keys.onUpPressed: listeResultats.monter()
                Keys.onDownPressed: listeResultats.descendre()
                Keys.onTabPressed: (event) => {
                    event.accepted = true;
                    // Tab complète la suggestion (façon Windows) : le texte saisi
                    // reçoit le reste proposé dans la capsule
                    if (fenetre.suggestion.length > 0)
                        saisie.text = fenetre.texte + fenetre.suggestion;
                }
                // Flèche droite : complète la suggestion MAIS seulement si le curseur
                // est déjà à la fin du texte et qu'il n'y a pas de sélection active.
                // Sinon on laisse le comportement normal (déplacement du curseur ou
                // étirement de la sélection vers la droite).
                Keys.onRightPressed: (event) => {
                    // selectedText.length > 0 → sélection active, on passe
                    // cursorPosition < text.length → curseur au milieu, on passe
                    if (saisie.selectedText.length === 0
                        && saisie.cursorPosition >= saisie.text.length
                        && fenetre.suggestion.length > 0) {
                        event.accepted = true;
                        saisie.text = fenetre.texte + fenetre.suggestion;
                        // Curseur à la fin après complétion
                        saisie.cursorPosition = saisie.text.length;
                    }
                }
                // la sélection du champ reste gérée par le champ lui-même (Ctrl+A,
                // Maj+flèches, souris) ; on la recopie dans la capsule pour l'affichage
                onSelectionStartChanged: fenetre.refleterSelection()
                onSelectionEndChanged: fenetre.refleterSelection()
            }

            // ── Puces de filtre (visibles pendant une recherche) ──
            Item {
                id: zonePuces
                readonly property bool montree: fenetre.texte.length > 0
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: fenetre.hauteurSaisie + (montree ? 10 : 0)
                height: montree ? 32 : 0
                opacity: montree ? 1 : 0
                clip: true
                visible: height > 0 || opacity > 0
                Behavior on height { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                Behavior on anchors.topMargin { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }

                // bouton Retour : revient à l'accueil depuis les résultats
                Item {
                    id: boutonRetourHaut
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 24

                    readonly property bool sombre: Kirigami.Theme.textColor.hslLightness > 0.5

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        // survol : teinte d'accent, comme les puces de filtre —
                        // l'ancien écart de blanc translucide était invisible
                        color: survolRetourHaut.containsMouse
                               ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                                         Kirigami.Theme.highlightColor.g,
                                         Kirigami.Theme.highlightColor.b, 0.25)
                               : (boutonRetourHaut.sombre ? "#26ffffff" : "#80ffffff")
                        border.width: 1
                        border.color: survolRetourHaut.containsMouse
                               ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                                         Kirigami.Theme.highlightColor.g,
                                         Kirigami.Theme.highlightColor.b, 0.5)
                               : (boutonRetourHaut.sombre ? "#1affffff" : "#14000000")
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: "go-previous"
                        isMask: true
                        color: Kirigami.Theme.textColor
                    }
                    MouseArea {
                        id: survolRetourHaut
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.ArrowCursor
                        onClicked: {
                            saisie.text = "";
                            Qt.callLater(fenetre.activer);
                        }
                    }
                }

                PucesFiltres {
                    anchors.left: boutonRetourHaut.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    actif: fenetre.filtre
                    onChoisir: (f) => {
                        fenetre.annulerSelection();
                        fenetre.filtre = f;
                    }
                }
            }

            // ── Carte du haut : calcul ou aperçu du premier document ──
            CarteHaut {
                id: carteHaut
                anchors.top: zonePuces.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                texte: fenetre.texte
                resultat: fenetre.carteResultat
                calcul: fenetre.carteCalcul
                onLancer: (r) => fenetre.lancer(r)
            }

            // ── Résultats ──
            ListeResultats {
                id: listeResultats
                anchors.top: carteHaut.bottom
                anchors.topMargin: 6
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.bottomMargin: 12
                visible: fenetre.texte.length > 0
                resultats: fenetre.resultats
                enCours: fenetre.enCours
                texte: fenetre.texte
                onLancer: (r) => fenetre.lancer(r)
            }

            // ── Accueil (rien de tapé) ──
            Accueil {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 22
                anchors.rightMargin: 32
                anchors.topMargin: fenetre.hauteurSaisie + 16
                anchors.bottomMargin: 12
                visible: fenetre.texte.length === 0
                modeleApps: modeleRecents.count > 0 ? modeleRecents.modelForRow(0) : null
                modeleDocs: modeleRecents.count > 1 ? modeleRecents.modelForRow(1) : null
                revision: fenetre.ouvertures
                onFini: fenetre.fermer()
                onOuvrirModule: (module) => {
                    commande.connectSource("kioclient exec /usr/share/applications/" + module + ".desktop");
                    fenetre.fermer();
                }
            }

            // plus de bandeau du bas : le bouton Retour vit en haut des résultats
        }
    }
}
