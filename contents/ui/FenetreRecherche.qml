/*
 * Fenestra Search — https://github.com/naykkalak/fenestra-search
 * SPDX-FileCopyrightText: 2026 naykkalak
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
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

    width: 800
    height: 830
    location: Plasmoid.location
    flags: Qt.WindowStaysOnTopHint
    hideOnWindowDeactivate: true
    visible: false

    property int ouvertures: 0         // compte les ouvertures : l'accueil se relit

    function activer() {
        fenetre.requestActivate();
        saisie.forceActiveFocus();
    }

    function fermer() {
        racine.fenetreOuverte = false;
    }

    onVisibleChanged: {
        if (visible) {
            ouvertures++;
            activer();
            racine.placer();
            Qt.callLater(racine.placer);      // une fois la taille réelle connue
            Qt.callLater(activer);            // une seconde fois, fenêtre réellement affichée
        } else {
            saisie.text = "";
            filtre = "All";
            if (racine.fenetreOuverte) racine.fenetreOuverte = false;   // fermée seule
        }
    }

    // ── Moteur : KRunner (via Milou) ──
    property string requete: ""        // envoyée à KRunner 60 ms après la dernière touche
    property var resultats: []         // classés et regroupés (Classement.js)
    property bool enCours: false
    property var carteResultat: null   // carte du haut : calcul ou premier document
    property bool carteCalcul: false

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
        }
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
                                       i18n("Other Results"));

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
        width: 1000
        height: 780

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
            width: 800
            height: 830

            // champ invisible : c'est lui qui reçoit la frappe ; la capsule l'affiche
            PlasmaComponents.TextField {
                id: saisie
                width: 1
                height: 1
                opacity: 0
                onTextChanged: racine.texteRecherche = text
                onAccepted: listeResultats.lancerCourant()
                Keys.onEscapePressed: fenetre.fermer()
                Keys.onUpPressed: listeResultats.monter()
                Keys.onDownPressed: listeResultats.descendre()
                Keys.onTabPressed: (event) => { event.accepted = true; }
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
                anchors.topMargin: montree ? 10 : 0
                height: montree ? 32 : 0
                opacity: montree ? 1 : 0
                clip: true
                visible: height > 0 || opacity > 0
                Behavior on height { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                Behavior on anchors.topMargin { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }

                PucesFiltres {
                    anchors.fill: parent
                    actif: fenetre.filtre
                    onChoisir: (f) => fenetre.filtre = f
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
                anchors.bottom: bandeau.top
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
                anchors.bottom: bandeau.top
                anchors.leftMargin: 22
                anchors.rightMargin: 32
                anchors.topMargin: 16
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

            // ── Bandeau du bas ──
            BandeauBas {
                id: bandeau
                anchors.left: parent.left
                anchors.leftMargin: -7
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                recherche: fenetre.texte.length > 0
                onRetour: {
                    saisie.text = "";
                    Qt.callLater(fenetre.activer);
                }
            }
        }
    }
}
