/*
 * Fenestra Search — https://github.com/naykkalak/fenestra-search
 * SPDX-FileCopyrightText: 2026 naykkalak
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.milou as Milou
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.private.kicker 0.1 as Kicker
import "Classement.js" as Classement
import "Moteurs.js" as Moteurs
import "Recents.js" as Recents

// Fenêtre de recherche : SA PROPRE fenêtre (PlasmaCore.Dialog), comme le menu Démarrer.
// La fenêtre standard d'un widget de barre n'obtient pas le clavier en début de session
// sous Wayland ; une Dialog, si.
PlasmaCore.Dialog {
    id: fenetre

    property var racine: null
    readonly property string texte: racine ? racine.texteRecherche : ""
    property string filtre: "All"
    // liste « Récent » : programmes et modules KCM ouverts par la recherche
    property var recents: Recents.charger(Plasmoid.configuration.recents)

    // nom dans la langue courante et chemin réel des éléments « Récent ».
    // La liste mémorise un nom déjà traduit : après un changement de langue
    // les titres restaient dans l'ancienne langue. On relit donc les .desktop
    // avec la langue du moment (voir rafraichirNomsRecents).
    property var infosRecents: ({})
    property var clefsNoms: []

    // copie d'affichage de « Récent » : elle ajoute « libelle » (nom courant)
    // et, quand il est connu, le chemin réel du .desktop. « display » n'est
    // pas modifié : il sert de clé pour la suppression d'une entrée.
    readonly property var recentsAffiches: {
        var carte = infosRecents;
        var liste = [];
        for (var i = 0; i < recents.length; i++) {
            var it = recents[i];
            var info = carte[Recents.clef(it)];
            if (!info) { liste.push(it); continue; }
            var copie = {
                display: it.display,
                decoration: it.decoration,
                url: it.url,
                duplicateId: it.duplicateId,
                category: it.category,
                type: it.type,
                libelle: info.nom
            };
            if (info.chemin) copie.chemin = info.chemin;
            if (info.id) copie.id = info.id;
            liste.push(copie);
        }
        return liste;
    }

    // relit les .desktop de la liste « Récent » dans la langue courante
    function rafraichirNomsRecents() {
        if (recents.length === 0) {
            infosRecents = ({});
            clefsNoms = [];
            return;
        }
        var cles = [], args = [];
        for (var i = 0; i < recents.length; i++) {
            var it = recents[i];
            var v = String(it.url || "");
            if (v.length === 0) v = String(it.duplicateId || "");
            if (v.length === 0) v = String(it.display || "");
            if (v.length === 0) continue;
            cles.push(Recents.clef(it));
            args.push(shellQuote(v));
        }
        if (args.length === 0) return;
        clefsNoms = cles;
        // commentaire horodaté : le moteur « executable » met en cache une
        // source identique, or la réponse change avec la langue courante.
        nomsRecents.connectSource("sh '"
            + String(Qt.resolvedUrl("../code/recent-menu.sh")).replace("file://", "")
            + "' --noms " + args.join(" ") + " #" + Date.now());
    }

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
        hideOnWindowDeactivate = true;   // valeur par défaut, rétablie à la fermeture
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

    // relit les noms des récents dès le chargement : après un changement de
    // langue (le plasmoïde redémarre), les titres suivent la langue courante
    Component.onCompleted: rafraichirNomsRecents()

    onVisibleChanged: {
        if (visible) {
            ouvertures++;
            rafraichirNomsRecents();
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
        if (r.web) {
            Qt.openUrlExternally(r.url || "");
        } else if (r.index !== undefined && r.index >= 0) {
            // Même chemin que KRunner : le moteur d'origine exécute le résultat.
            // Pour un module KCM, c'est « systemsettings <module> » (ou kcmshell6
            // si le module n'a pas de catégorie parente) — ouvrir directement le
            // .desktop du module tombait sur la page d'accueil de la Configuration.
            modele.run(modele.index(r.index, 0));
        }
        // mémorise les programmes et modules KCM ouverts dans « Récent »
        memoriser(r);
        fermer();
    }

    // ajoute un programme ou un module KCM en tête de la liste « Récent »
    function memoriser(r) {
        if (!r || r.web) return;
        var type = Classement.estLancable(r.category, r.url, r.duplicateId, r.decoration);
        if (type === "") return;
        var id = String(r.duplicateId || "");
        var url = String(r.url || "");
        // KRunner ne fournit pas d'url pour les applications : l'identifiant du
        // .desktop (duplicateId) est alors la seule façon de les relancer.
        if (url.length === 0 && id.length > 0)
            url = urlDepuisId(id);
        var item = {
            display: r.display || "",
            decoration: r.decoration || "",
            url: url,
            duplicateId: id,
            category: r.category || "",
            type: type
        };
        recents = Recents.ajouter(recents, item);
        Plasmoid.configuration.recents = Recents.sauvegarder(recents);
        rafraichirNomsRecents();
    }

    // identifiant de .desktop -> URL lançable
    // "org.kde.kate.desktop" -> "applications:org.kde.kate.desktop"
    // "/usr/share/applications/kate.desktop" -> chemin tel quel
    function urlDepuisId(id) {
        var s = String(id || "");
        if (s.length === 0) return "";
        // identifiant du lanceur de services : « exec:///chemin/x.desktop »
        if (s.indexOf("exec://") === 0) return s.substring(7);
        if (s.indexOf("/") === 0) return s;
        return "applications:" + (/\.desktop$/i.test(s) ? s : s + ".desktop");
    }

    // rôle du modèle Kicker (plasma-workspace/applets/kicker/actionlist.h)
    readonly property int roleFavori: Qt.UserRole + 3    // identifiant du .desktop
    readonly property int roleUrl: Qt.UserRole + 10      // chemin du fichier .desktop

    // Kicker renvoie « applications:<id>.desktop » : on ne garde que l'identifiant
    function idKicker(valeur) {
        var s = String(valeur || "");
        if (s.indexOf("applications:") === 0) return s.substring(13);
        return s;
    }

    // lance une application via le modèle Kicker — exactement le chemin du menu
    // Démarrer (KService), donc indépendant du moteur « executable » du shell.
    // Retourne true si l'application a été trouvée et lancée.
    function lancerParKicker(id, nom) {
        var m = modeleApplications();
        var n = 0;
        try { n = m.rowCount(); } catch (e2) { return false; }
        var cible = String(id || "").replace(/\.desktop$/i, "");
        if (cible.length > 0) {
            for (var i = 0; i < n; i++) {
                var idx = m.index(i, 0);
                var f = idKicker(m.data(idx, roleFavori)).replace(/\.desktop$/i, "");
                if (f.length > 0 && f === cible) { m.trigger(i, "", null); return true; }
            }
        }
        if (String(nom || "").length > 0) {
            for (var j = 0; j < n; j++) {
                var ix = m.index(j, 0);
                if (String(m.data(ix, Qt.DisplayRole) || "") === String(nom)) {
                    m.trigger(j, "", null);
                    return true;
                }
            }
        }
        return false;
    }

    // modèle Kicker « toutes les applications ». modeleToutes est un RootModel
    // dont les lignes sont des groupes : l'action se déclenche sur le modèle
    // enfant (même chemin que lancerParKicker), pas sur les lignes du RootModel.
    function modeleApplications() {
        if (modeleToutes.count === 0) modeleToutes.refresh();
        var n = 0;
        try { n = modeleToutes.count; } catch (e) { return null; }
        var premier = null;
        for (var i = 0; i < n; i++) {
            var m = null;
            try { m = modeleToutes.modelForRow(i); } catch (e2) { m = null; }
            if (!m) continue;
            if (!premier) premier = m;
            var d = "";
            try { d = String(m.description || ""); } catch (e3) {}
            if (d === "KICKER_ALL_MODEL") return m;
        }
        return premier;
    }

    // type d'un élément récent ; recalculé pour les entrées mémorisées par une
    // version antérieure qui ne stockait pas encore le champ « type »
    function typeRecent(item) {
        if (!item) return "";
        var t = String(item.type || "");
        if (t === "app" || t === "settings") return t;
        return Classement.estLancable(item.category || "", item.url || "",
                                      item.duplicateId || "", item.decoration || "");
    }

    // identifiant .desktop retrouvé par le nom affiché (entrées sans url ni
    // identifiant) : nécessaire pour « Ajouter au bureau » et « Épingler »
    function idDepuisNom(nom) {
        var cible = String(nom || "").trim().toLocaleLowerCase();
        if (cible.length === 0) return "";
        var m = modeleApplications();
        if (!m) return "";
        var n = 0;
        try { n = m.rowCount(); } catch (e) { return ""; }
        for (var i = 0; i < n; i++) {
            var idx = m.index(i, 0);
            var d = "", f = "";
            try { d = String(m.data(idx, Qt.DisplayRole) || ""); } catch (e2) {}
            if (d.toLocaleLowerCase() !== cible) continue;
            try { f = idKicker(m.data(idx, roleFavori)); } catch (e3) {}
            if (f.length > 0) return f;
        }
        return "";
    }

    // chemin réel du fichier .desktop d'une application, retrouvé dans le
    // modèle Kicker (rôle « url ») : la copie vers le bureau est alors exacte
    // même si le .desktop n'est pas dans un dossier standard.
    function cheminDepuisId(id, nom) {
        var cible = idKicker(String(id || "")).replace(/\.desktop$/i, "");
        var m = modeleApplications();
        if (!m) return "";
        var n = 0;
        try { n = m.rowCount(); } catch (e) { return ""; }
        for (var i = 0; i < n; i++) {
            var idx = m.index(i, 0);
            var f = "", d = "";
            try { f = idKicker(m.data(idx, roleFavori)).replace(/\.desktop$/i, ""); } catch (e2) {}
            var correspond = cible.length > 0 && f === cible;
            if (!correspond && String(nom || "").length > 0) {
                try { d = String(m.data(idx, Qt.DisplayRole) || ""); } catch (e3) {}
                correspond = d === String(nom);
            }
            if (!correspond) continue;
            var u = "";
            try { u = String(m.data(idx, roleUrl) || ""); } catch (e4) { u = ""; }
            if (u.indexOf("file://") === 0) u = u.substring(7);
            if (u.length > 0) return u;
        }
        return "";
    }

    // identifiants de favoris candidats pour le menu Démarrer.
    // Kicker écrit « applications:<id>.desktop » — c'est aussi la forme que
    // produit miryu-start ; on accepte en plus le chemin complet et l'URL file://.
    function idsFavori(id, chemin) {
        var brut = idKicker(String(id || "")).trim();
        var fichier = String(chemin || "").trim();
        if (fichier.indexOf("exec://") === 0) fichier = fichier.substring(7);
        if (fichier.indexOf("file://") === 0) fichier = fichier.substring(7);
        if (fichier.indexOf("applications:") === 0) fichier = fichier.substring(13);
        var liste = [];
        var ajouter = function(v) {
            if (!v || v.length === 0) return;
            if (liste.indexOf(v) === -1) liste.push(v);
        };
        if (brut.length > 0) {
            if (brut.indexOf("/") === 0) {
                ajouter("applications:" + brut);
                ajouter(brut);
            } else {
                var b = /\.desktop$/i.test(brut) ? brut : brut + ".desktop";
                ajouter("applications:" + b);
                ajouter(b);
            }
        }
        if (fichier.length > 0) {
            if (fichier.indexOf("/") === 0) {
                ajouter("applications:" + fichier);
                ajouter("file://" + fichier);
                ajouter(fichier);
                var nomFichier = fichier.substring(fichier.lastIndexOf("/") + 1);
                ajouter("applications:" + nomFichier);
                ajouter(nomFichier);
            } else {
                var b2 = /\.desktop$/i.test(fichier) ? fichier : fichier + ".desktop";
                ajouter("applications:" + b2);
                ajouter(b2);
            }
        }
        return liste;
    }

    // modèle des favoris du menu Démarrer (KActivities) — le même que celui de
    // miryu-start : une application épinglée dans l'un apparaît dans l'autre.
    function modeleFavoris() {
        try { return modeleToutes.favoritesModel; } catch (e) { return null; }
    }

    // vrai si l'application est déjà épinglée au menu Démarrer, y compris
    // lorsqu'elle a été épinglée depuis miryu-start (ressources KActivities
    // partagées, rechargées automatiquement par le modèle de favoris).
    function estFavori(id, chemin) {
        var f = modeleFavoris();
        if (!f) return false;
        var ids = idsFavori(id, chemin);
        for (var i = 0; i < ids.length; i++) {
            try { if (f.isFavorite(ids[i])) return true; } catch (e) {}
        }
        return false;
    }

    // Ajoute l'application au bureau : copie de son .desktop dans le dossier
    // Bureau. L'action native de Kicker (« addToDesktop ») exige un conteneur
    // Folder View déverrouillé sur l'écran de l'applet et échoue sans rien
    // signaler sinon ; la copie directe marche dans tous les cas (Folder View
    // affiche les .desktop présents dans le dossier Bureau).
    function ajouterAuBureau(id, nom, chemin) {
        var cible = String(chemin || "");
        if (cible.indexOf("exec://") === 0) cible = cible.substring(7);
        if (cible.indexOf("file://") === 0) cible = cible.substring(7);
        if (cible.indexOf("applications:") === 0) cible = cible.substring(13);
        if (cible.length === 0) cible = idKicker(String(id || ""));
        // entrée ancienne sans identifiant : on le retrouve par le nom affiché
        if (cible.length === 0) cible = idDepuisNom(nom);
        // chemin exact du .desktop dans le modèle Kicker, s'il est connu
        if (cible.indexOf("/") !== 0) {
            var reel = cheminDepuisId(id, nom);
            if (reel.length > 0) cible = reel;
        }
        if (cible.length > 0 && cible.indexOf("/") !== 0 && !/\.desktop$/i.test(cible))
            cible += ".desktop";
        if (cible.length === 0) {
            afficherToast(i18n("“%1” could not be added to the desktop", nom));
            return;
        }
        commande.connectSource(commandeAjoutBureau(cible) + " #" + Date.now());
        afficherToast(i18n("“%1” has been added to the desktop", nom));
    }

    // Épingle l'application au menu Démarrer : favoris Kicker (KActivities),
    // exactement comme miryu-start (favoritesModel.addFavorite).
    function epinglerAuDemarrage(id, nom, chemin) {
        var f = modeleFavoris();
        var ids = idsFavori(id, chemin);
        if (ids.length === 0) ids = idsFavori(idDepuisNom(nom), "");
        var fait = false;
        if (f) {
            for (var i = 0; i < ids.length; i++) {
                try {
                    if (f.isFavorite(ids[i])) { fait = true; break; }
                    f.addFavorite(ids[i]);
                    // l'ajout est synchrone quand l'activité courante est prise
                    // en compte : on vérifie que l'entrée est réellement là.
                    if (f.isFavorite(ids[i])) { fait = true; break; }
                } catch (e) {}
            }
        }
        afficherToast(fait ? i18n("“%1” has been pinned to the Start menu", nom)
                           : i18n("“%1” could not be pinned to the Start menu", nom));
    }

    // Retire l'application des favoris du menu Démarrer (même modèle que
    // miryu-start, donc le retrait y est visible immédiatement).
    function desepinglerDuDemarrage(id, nom, chemin) {
        var f = modeleFavoris();
        var ids = idsFavori(id, chemin);
        if (ids.length === 0) ids = idsFavori(idDepuisNom(nom), "");
        var fait = false;
        if (f) {
            for (var i = 0; i < ids.length; i++) {
                try {
                    if (!f.isFavorite(ids[i])) continue;
                    f.removeFavorite(ids[i]);
                    fait = true;
                    break;
                } catch (e) {}
            }
            // le modèle peut ne pas encore connaître l'entrée (chargement en
            // cours) : on tente quand même le retrait sur la forme canonique.
            if (!fait && ids.length > 0) {
                try { f.removeFavorite(ids[0]); fait = true; } catch (e) {}
            }
        }
        afficherToast(fait ? i18n("“%1” has been unpinned from the Start menu", nom)
                           : i18n("“%1” could not be unpinned from the Start menu", nom));
    }

    // « Ajouter au bureau » : copie le .desktop dans le vrai dossier Bureau.
    // xdg-user-dir renvoie $HOME quand le dossier Bureau n'est pas configuré :
    // on le traite comme absent pour ne pas copier le lanceur dans le dossier
    // personnel.
    function commandeAjoutBureau(id) {
        return "ID=" + shellQuote(id) + "; "
            + "D=\"\"; if command -v xdg-user-dir >/dev/null 2>&1; then "
            + "D=$(xdg-user-dir DESKTOP 2>/dev/null); fi; "
            + "case \"$D\" in \"\"|\"$HOME\") D=\"\";; esac; "
            + "if [ -z \"$D\" ]; then "
            + "for c in \"$HOME/Desktop\" \"$HOME/桌面\" \"$HOME/Bureau\" \"$HOME/Рабочий стол\"; do "
            + "[ -d \"$c\" ] && { D=\"$c\"; break; }; done; fi; "
            + "[ -n \"$D\" ] || D=\"$HOME/Desktop\"; "
            + "mkdir -p \"$D\"; F=\"\"; "
            + "case \"$ID\" in /*) [ -f \"$ID\" ] && F=\"$ID\";; esac; "
            + "if [ -z \"$F\" ]; then "
            + "for d in \"$HOME/.local/share/applications\" /usr/local/share/applications "
            + "/usr/share/applications /var/lib/flatpak/exports/share/applications "
            + "\"$HOME/.local/share/flatpak/exports/share/applications\" "
            + "/var/lib/snapd/desktop/applications; do "
            + "if [ -f \"$d/$ID\" ]; then F=\"$d/$ID\"; break; fi; done; fi; "
            + "if [ -n \"$F\" ]; then B=$(basename \"$F\"); "
            + "cp -f \"$F\" \"$D/$B\" && chmod +x \"$D/$B\"; fi; true";
    }

    // message de confirmation affiché en bas de la fenêtre
    function afficherToast(message) {
        toast.texte = String(message || "");
        toast.opacity = 1;
        attenteToast.restart();
    }

    // module KCM d'un élément « Récent » :
    //   applications:kcm_pulseaudio.desktop -> kcm_pulseaudio
    //   kcm://kcm_pulseaudio                 -> kcm_pulseaudio
    //   systemsettings.desktop               -> "" (ouvre la Configuration du système)
    function moduleKcm(item) {
        if (!item) return "";
        var candidats = [String(item.url || ""), String(item.duplicateId || "")];
        for (var i = 0; i < candidats.length; i++) {
            var s = candidats[i];
            if (s.length === 0) continue;
            if (s.indexOf("kcm://") === 0)
                return s.substring(6).replace(/\/+$/, "");
            var m = s.match(/kcm_([A-Za-z0-9_\-]+)\.desktop/);
            if (m) return "kcm_" + m[1];
            var base = s.substring(s.lastIndexOf("/") + 1);
            if (/^kcm_/.test(base)) return base.replace(/\.desktop$/i, "");
        }
        return "";
    }

    // ouvre un élément de la liste « Récent » (programme ou module KCM)
    function lancerRecent(item) {
        if (!item) return;
        // chemin retrouvé par recent-menu.sh : il ne dépend pas de la langue
        var url = String(item.chemin || "") || String(item.url || "");
        var nom = String(item.libelle || item.display || "");
        // identifiant .desktop : d'abord le fichier réellement mémorisé (URL),
        // puis le « matchId » de KRunner (modules KCM : kcm_xxx)
        var id = idDesktop(item);
        if (id.length === 0) id = String(item.duplicateId || "");
        // 1. module de la Configuration du système : kcmshell / systemsettings.
        //    Les fichiers kcm_*.desktop ne sont pas toujours dans les dossiers
        //    « applications » : les lancer comme une application échouait sans
        //    aucun message (d'où l'absence de réaction au clic).
        if (typeRecent(item) === "settings") {
            commande.connectSource(commandeKcm(moduleKcm(item), resoudreDesktop(item), nom)
                                   + " #" + Date.now());
            fermer();
            return;
        }
        // 2. programme : lancement par le menu Démarrer (le plus fiable)
        if (lancerParKicker(id, nom)) {
            fermer();
            return;
        }
        // 3. entrée mémorisée par une version antérieure : ni url ni duplicateId
        if (url.length === 0 && id.length === 0) {
            url = nom;   // repli : lancement par nom
            if (url.length === 0) return;
            commande.connectSource(commandeParNom(url) + " #" + Date.now());
            fermer();
            return;
        }
        if (url.length === 0)
            url = urlDepuisId(id);
        var cmd;
        if (url.indexOf("kcm://") === 0) {
            // module KCM : kcm://<module>
            cmd = commandeKcm(url.substring(6).replace(/\/+$/, ""));
        } else {
            cmd = commandeLancement(url);
        }
        // Le moteur « executable » ressert la réponse en cache pour une source
        // identique : on ajoute un commentaire horodaté pour forcer une nouvelle
        // exécution (même technique que miryu-start, Footer.qml).
        commande.connectSource(cmd + " #" + Date.now());
        fermer();
    }

    // lance une URL d'application / de fichier.
    // Les URLs « applications:<id>.desktop » sont d'abord résolues en chemin réel.
    function commandeLancement(url) {
        var u = shellQuote(url);
        var prefixe = "L=" + u + "; ";
        if (url.indexOf("applications:") === 0) {
            var id = shellQuote(url.substring(13));
            prefixe = "L=\"\"; " +
                "for d in \"$HOME/.local/share/applications\" /usr/local/share/applications " +
                "/usr/share/applications /var/lib/flatpak/exports/share/applications " +
                "\"$HOME/.local/share/flatpak/exports/share/applications\" " +
                "/var/lib/snapd/desktop/applications; do " +
                "if [ -f \"$d\"/" + id + " ]; then L=\"$d\"/" + id + "; break; fi; done; " +
                "[ -n \"$L\" ] || L=" + u + "; ";
        }
        return prefixe + commandeOuvreL();
    }

    // lance ce qui se trouve dans $L. On lit d'abord la ligne « Exec= » du fichier
    // .desktop et on l'exécute directement : c'est ce que fait le menu Démarrer,
    // sans dépendre de kioclient (souvent présent mais qui échoue silencieusement
    // quand l'URL « applications: » n'a pas pu être résolue). Replis : kioclient,
    // puis xdg-open.
    function commandeOuvreL() {
        return "X=\"\"; "
            + "if [ -f \"$L\" ]; then "
            + "X=$(kreadconfig6 --file \"$L\" --group 'Desktop Entry' --key Exec 2>/dev/null); "
            + "[ -n \"$X\" ] || X=$(kreadconfig --file \"$L\" --group 'Desktop Entry' --key Exec 2>/dev/null); "
            + "[ -n \"$X\" ] || X=$(awk -F= '/^\\[Desktop Entry\\]/{g=1;next} /^\\[/{g=0} "
            + "g&&/^Exec=/{sub(/^Exec=/,\"\");print;exit}' \"$L\"); "
            + "X=$(printf '%s' \"$X\" | sed 's/%[fFuUdDnNickvm]//g'); "
            + "fi; "
            // trace de la dernière tentative : ~/.cache/miryu-search-launch.log
            + "echo \"L=$L\" \"X=$X\" > \"$HOME/.cache/miryu-search-launch.log\" 2>/dev/null; "
            + "if [ -n \"$X\" ]; then nohup setsid sh -c \"$X\" >/dev/null 2>&1 & exit 0; fi; "
            + "for c in kioclient6 kioclient kioclient5; do "
            + "if command -v \"$c\" >/dev/null 2>&1; then "
            + "nohup setsid \"$c\" exec \"$L\" >/dev/null 2>&1 & exit 0; fi; done; "
            + "nohup setsid xdg-open \"$L\" >/dev/null 2>&1 & exit 0";
    }

    // repli : relance une application par son nom affiché (entrées « Récent »
    // mémorisées sans url ni duplicateId). Cherche le .desktop dont le Name
    // correspond, puis l'ouvre avec le premier lanceur disponible.
    function commandeParNom(nom) {
        return "N=" + shellQuote(nom) + "; "
            + "L=\"\"; "
            + "for d in \"$HOME/.local/share/applications\" /usr/local/share/applications "
            + "/usr/share/applications /var/lib/flatpak/exports/share/applications "
            + "\"$HOME/.local/share/flatpak/exports/share/applications\" "
            + "/var/lib/snapd/desktop/applications; do "
            + "[ -d \"$d\" ] || continue; "
            + "for f in \"$d\"/*.desktop; do "
            + "[ -f \"$f\" ] || continue; "
            + "n=$(sed -n 's/^Name=//p' \"$f\" | head -n 1); "
            + "[ \"$n\" = \"$N\" ] && { L=\"$f\"; break; }; "
            + "nl=$(sed -n 's/^Name\\[[^]]*\\]=//p' \"$f\" | head -n 1); "
            + "[ \"$nl\" = \"$N\" ] && { L=\"$f\"; break; }; "
            + "done; "
            + "[ -n \"$L\" ] && break; done; "
            + "[ -n \"$L\" ] || exit 0; "
            + commandeOuvreL();
    }

    // ouvre un module de la Configuration du système. Même logique que le
    // moteur « systemsettings » de KRunner :
    //   - module avec catégorie parente -> « systemsettings <module> » ;
    //   - module autonome               -> « kcmshell6 <module> ».
    // module vide : ouvre la Configuration du système elle-même.
    // « desktop » (facultatif) sert à retrouver le module et sa catégorie dans
    // le fichier .desktop quand l'entrée « Récent » n'a pas d'identifiant —
    // sans cela « systemsettings » sans argument ouvrait la page d'accueil.
    // « nom » (facultatif) retrouve le .desktop d'un module par son nom
    // affiché, pour les entrées d'historique enregistrées sans identifiant.
    function commandeKcm(module, desktop, nom) {
        var dirs = "\"$HOME/.local/share/applications\" /usr/local/share/applications "
                 + "/usr/share/applications /var/lib/flatpak/exports/share/applications "
                 + "\"$HOME/.local/share/flatpak/exports/share/applications\"";
        return "M=" + shellQuote(String(module || "")) + "; "
            + "D=" + shellQuote(String(desktop || "")) + "; "
            + "N=" + shellQuote(String(nom || "")) + "; ID=\"\"; "
            // chemin du .desktop ou identifiant à rechercher
            + "case \"$D\" in applications:*) ID=${D#applications:}; D=\"\";; esac; "
            + "case \"$D\" in /*.desktop) ;; *.desktop) ID=\"$D\"; D=\"\";; *) D=\"\";; esac; "
            + "if [ -z \"$D\" ]; then "
            +   "[ -n \"$ID\" ] || { [ -n \"$M\" ] && ID=\"$M.desktop\"; }; "
            +   "for x in " + dirs + "; do "
            +     "if [ -n \"$ID\" ] && [ -f \"$x/$ID\" ]; then D=\"$x/$ID\"; break; fi; done; "
            + "fi; "
            // l'application « Configuration du système » n'est pas un module
            + "case \"$(basename \"$D\" 2>/dev/null)\" in "
            +   "systemsettings.desktop|org.kde.systemsettings.desktop|"
            +   "kinfocenter.desktop|org.kde.kinfocenter.desktop) M=\"\"; D=\"\";; esac; "
            // nom du module : pour un .desktop connu, c'est son nom de fichier
            // que la Configuration du système attend — MenuItem::
            // descendantForModule compare desktopEntryName, et le générateur de
            // KCMUtils écrit justement « Exec=systemsettings kcm_xxx ».
            + "[ -f \"$D\" ] && M=$(basename \"$D\" .desktop); "
            // entrée d'historique sans identifiant : module retrouvé par son nom
            + "if [ -z \"$M\" ] && [ -z \"$D\" ] && [ -n \"$N\" ]; then "
            +   "for x in " + dirs + "; do "
            +     "for f in \"$x\"/kcm_*.desktop \"$x\"/kcm-*.desktop; do "
            +       "[ -f \"$f\" ] || continue; "
            // nom traduit : on compare toutes les lignes Name / Name[xx]
            +       "if sed -nE 's/^Name(\\[[^]]*\\])?=//p' \"$f\" | grep -qxF \"$N\"; then "
            +         "D=\"$f\"; M=$(basename \"$f\" .desktop); break; fi; "
            +     "done; [ -n \"$D\" ] && break; done; "
            + "fi; "
            // Centre d'information : ses modules s'ouvrent avec « kinfocenter ».
            // Ils sont marqués par X-KDE-KInfoCenter-Category quand un .desktop
            // existe ; sinon on interroge sa liste (« id - description »),
            // sinon « systemsettings » ne saurait pas où aller et afficherait
            // sa page d'accueil.
            + "IC=\"\"; [ -f \"$D\" ] && "
            +   "IC=$(sed -n 's/^X-KDE-KInfoCenter-Category=//p' \"$D\" | head -n 1); "
            + "if [ -z \"$IC\" ] && [ -z \"$D\" ] && [ -n \"$M\" ] && command -v kinfocenter >/dev/null 2>&1; then "
            +   "if kinfocenter --list 2>/dev/null | "
            +     "awk -v m=\"$M\" '$1 == m { f = 1 } END { exit(f ? 0 : 1) }'; then IC=1; fi; fi; "
            + "L() { nohup setsid \"$@\" >/dev/null 2>&1 & exit 0; }; "
            + "if [ -n \"$IC\" ] && command -v kinfocenter >/dev/null 2>&1; then "
            +   "if [ -n \"$M\" ]; then L kinfocenter \"$M\"; else L kinfocenter; fi; fi; "
            // Configuration du système : on passe toujours le module en argument
            // pour ouvrir sa page dans la fenêtre principale — « kcmshell6 »
            // ouvrirait une fenêtre autonome (ex. Effets de bureau).
            + "if command -v systemsettings >/dev/null 2>&1; then "
            +   "if [ -n \"$M\" ]; then L systemsettings \"$M\"; else L systemsettings; fi; fi; "
            + "for c in kcmshell6 kcmshell5 kcmshell; do "
            +   "if command -v \"$c\" >/dev/null 2>&1; then "
            +     "if [ -n \"$M\" ]; then L \"$c\" \"$M\"; else L \"$c\"; fi; fi; done; "
            + "exit 0";
    }

    // citation sûre pour la ligne de commande sh
    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    // retire un élément de la liste « Récent »
    function supprimerRecent(item) {
        if (!item) return;
        recents = Recents.retirer(recents, item);
        Plasmoid.configuration.recents = Recents.sauvegarder(recents);
        rafraichirNomsRecents();
    }

    // résout le chemin réel du fichier .desktop d'un élément récent.
    // Pour les URLs applications:*, on renvoie l'identifiant et le script
    // recent-menu.sh se charge de chercher dans les dossiers standard.
    function resoudreDesktop(item) {
        // chemin retrouvé par recent-menu.sh (indépendant de la langue)
        var resolu = String(item ? (item.chemin || "") : "");
        if (resolu.length > 0) return resolu;
        var url = String(item ? item.url : "");
        if (url.length === 0) url = urlDepuisId(item ? item.duplicateId : "");
        if (url.length === 0) return "";
        if (url.indexOf("file://") === 0) return url.substring(7);
        if (url.indexOf("/") === 0) return url;
        // applications:id.desktop -> renvoyé tel quel, le script le résout
        return url;
    }

    // identifiant .desktop (nom de fichier) pour l'épinglage
    function idDesktop(item) {
        // identifiant déduit du chemin retrouvé (indépendant de la langue)
        var resolu = String(item ? (item.id || "") : "");
        if (resolu.length > 0) return resolu;
        var url = String(item ? item.url : "");
        if (url.length === 0) url = urlDepuisId(item ? item.duplicateId : "");
        if (url.indexOf("applications:") === 0) return url.substring(13);
        var p = url.lastIndexOf("/");
        return p >= 0 ? url.substring(p + 1) : url;
    }

    // ── Menu contextuel d'un élément récent ──
    property var menuCourant: null
    property Item menuParent: null
    property int menuX: 0
    property int menuY: 0
    property bool menuItemClicked: false   // vrai si une entrée du menu a été choisie
    property bool menuVaOuvrir: false      // un nouveau menu va s'ouvrir (2e clic droit)
    property bool pageEtaitActive: false   // la recherche avait le focus avant le menu

    function ouvrirMenuContext(item, parentItem, x, y) {
        if (!item) return;
        menuCourant = item;
        menuParent = parentItem;
        menuX = x;
        menuY = y;
        menuVaOuvrir = true;
        pageEtaitActive = active;
        // le menu va prendre l'activation : empêcher la fenêtre de recherche
        // de se fermer sur perte de focus pendant qu'il est affiché.
        hideOnWindowDeactivate = false;
        // on repart d'une sortie vide : les entrées supplémentaires arriveront
        // du script, et un échec du script ne doit pas réutiliser l'ancienne.
        menuSortie = "";
        menuNom = String(item.libelle || item.display || "");
        var type = typeRecent(item);
        var desktop = resoudreDesktop(item);
        var id = idDesktop(item);
        // entrée ancienne (sans url ni identifiant) : on retrouve le .desktop
        // par son nom dans le modèle du menu Démarrer
        if (id.length === 0 && type === "app")
            id = idDepuisNom(item ? (item.libelle || item.display) : "");
        if (desktop.length === 0 && id.length > 0) desktop = "applications:" + id;
        // sans identifiant ni chemin (entrée mémorisée avant refonte), on passe
        // le nom affiché : le script le compare à toutes les langues de « Name »
        // et retrouve ainsi le .desktop même après un changement de langue.
        var cible = desktop;
        if (cible.length === 0 && type === "app")
            cible = String(item.libelle || item.display || "");
        if (cible.length > 0 && type === "app") {
            menuActions.connectSource("sh '" + String(Qt.resolvedUrl("../code/recent-menu.sh")).replace("file://", "")
                                       + "' " + shellQuote(cible));
        } else {
            // KCM ou pas de .desktop : pas d'actions / fichiers récents
            menuSortie = "";
            construireMenu();
        }
    }

    // sortie du script recent-menu.sh (lignes DESKTOP|, NOM|, ACTION|, FILE|)
    property string menuSortie: ""
    // nom de l'élément du menu dans la langue courante (lignes NOM|)
    property string menuNom: ""

    // définitions des entrées du menu contextuel
    // (texte, icône, séparateur, identifiant d'action et ses paramètres)
    property var menuItems: []

    // exécute l'entrée choisie. Les entrées portent un identifiant d'action :
    // une fonction JavaScript placée dans le modèle de l'Instantiator n'est pas
    // fiable (les objets du modèle peuvent être convertis et perdre la fonction),
    // le clic ne faisait alors rien.
    function executerEntreeMenu(entree) {
        if (!entree) return;
        var item = menuCourant;
        var nom = menuNom.length > 0 ? menuNom : (item ? String(item.display || "") : "");
        var action = String(entree.action || "");
        if (action === "bureau") {
            ajouterAuBureau(entree.id || "", nom, entree.chemin || "");
        } else if (action === "epingler") {
            epinglerAuDemarrage(entree.id || "", nom, entree.chemin || "");
        } else if (action === "desepingler") {
            desepinglerDuDemarrage(entree.id || "", nom, entree.chemin || "");
        } else if (action === "executer") {
            var cmd = String(entree.commande || "").replace(/%[fuFU]/g, "")
                                                    .replace(/\s+/g, " ").trim();
            if (cmd.length > 0) commande.connectSource(cmd + " #" + Date.now());
        } else if (action === "fichier") {
            commande.connectSource(commandeLancement(String(entree.urlFichier || ""))
                                   + " #" + Date.now());
        } else if (action === "supprimer") {
            supprimerRecent(item);
        }
    }

    function construireMenu() {
        var item = menuCourant;
        if (!item) return;
        var type = typeRecent(item);
        var isApp = type === "app";
        var desktop = resoudreDesktop(item);
        var id = idDesktop(item);
        if (id.length === 0 && isApp) id = idDepuisNom(item.display);

        // le script renvoie le chemin réel et le nom dans la langue courante :
        // ils priment sur les valeurs mémorisées (nom d'une autre langue), ce
        // qui rend « Ajouter au bureau » et « Épingler » indépendants de la
        // langue dans laquelle l'entrée a été enregistrée.
        var lignes = menuSortie.length > 0 ? menuSortie.split("\n") : [];
        var nom = String(item.libelle || item.display || "");
        var aActions = [], aFichiers = [];
        for (var i = 0; i < lignes.length; i++) {
            var l = lignes[i];
            if (l.indexOf("DESKTOP|") === 0) {
                desktop = l.substring(8);
                var pos = desktop.lastIndexOf("/");
                if (pos >= 0) id = desktop.substring(pos + 1).replace(/\.desktop$/i, "");
            } else if (l.indexOf("NOM|") === 0) {
                nom = l.substring(4);
            } else if (l.indexOf("ACTION|") === 0) {
                aActions.push(l.substring(7));
            } else if (l.indexOf("FILE|") === 0) {
                aFichiers.push(l.substring(5));
            }
        }
        menuNom = nom;
        // entrée ancienne : on retrouve l'identifiant par le nom courant
        if (id.length === 0 && isApp) id = idDepuisNom(nom);

        // on reconstruit la liste des entrées (le Repeater régénère les MenuItem)
        var entrees = [];

        // 1. Actions sur les applications (pas sur les modules KCM).
        //    Toujours proposées : les identifiants des entrées anciennes sont
        //    retrouvés par leur nom dans les fonctions ci-dessous.
        if (isApp) {
            // Ajouter au bureau : copie du .desktop dans le dossier Bureau.
            entrees.push({ texte: i18n("Add to Desktop"), icone: "user-home",
                           action: "bureau", id: id, chemin: desktop });

            // Épingler / désépingler : on interroge les favoris Kicker, qui sont
            // les mêmes que ceux de miryu-start — une application déjà épinglée
            // là-bas affiche donc « Désépingler du menu Démarrer ».
            if (estFavori(id, desktop))
                entrees.push({ texte: i18n("Unpin from Start Menu"), icone: "bookmark-remove",
                               action: "desepingler", id: id, chemin: desktop });
            else
                entrees.push({ texte: i18n("Pin to Start Menu"), icone: "bookmark",
                               action: "epingler", id: id, chemin: desktop });
        }

        // 2. Actions supplémentaires + fichiers récents (issus du script)
        if (aActions.length > 0 || aFichiers.length > 0) {
            entrees.push({ separateur: true });
            for (var a = 0; a < aActions.length; a++) {
                var parts = aActions[a].split("|");
                entrees.push({ texte: parts[0] || "", icone: "",
                               action: "executer", commande: parts[1] || "" });
            }
            for (var f = 0; f < aFichiers.length; f++) {
                var pF = aFichiers[f].split("|");
                entrees.push({ texte: pF[0] || "", icone: "document-open",
                               action: "fichier", urlFichier: pF[1] || "" });
            }
        }

        // 3. Retirer de l'historique
        entrees.push({ separateur: true });
        entrees.push({ texte: i18n("Remove this history entry"), icone: "edit-delete",
                       action: "supprimer" });

        menuItems = entrees;
        menuItemClicked = false;
        menuVaOuvrir = false;
        if (menuParent) {
            menuRecent.visualParent = menuParent;
        }
        menuRecent.open(menuX, menuY);
    }

    // Appelé au tour suivant de la boucle d'événements après la fermeture du menu :
    // QMenu se ferme AVANT d'émettre le clic de l'entrée, on ne peut donc pas
    // décider immédiatement quel clic a fermé le menu. Même logique que
    // miryu-start (MenuRepresentation.qml) :
    //   - une entrée du menu a été choisie  -> la recherche reste ouverte ;
    //   - clic DANS la page                -> la fenêtre est restée active -> reste ouverte ;
    //   - clic EN DEHORS                   -> la fenêtre a perdu son activation -> on ferme.
    function verifierFermetureMenu() {
        hideOnWindowDeactivate = true;
        if (menuVaOuvrir) return;                              // un autre menu va s'ouvrir
        if (menuRecent.status !== PlasmaExtras.Menu.Closed) return;
        if (menuItemClicked) {
            menuItemClicked = false;
            requestActivate();                                 // la recherche reprend le focus
            return;
        }
        if (active) return;                                    // clic DANS la page
        if (survolPage.hovered) return;                        // pointeur encore sur la page
        if (pageEtaitActive) fermer();                          // clic en dehors de la page
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

        // applications installées : sert à lancer un élément « Récent » par le
        // même chemin que le menu Démarrer (voir lancerParKicker)
        Kicker.RootModel {
            id: modeleToutes
            autoPopulate: false
            appNameFormat: 0
            flat: true
            sorted: true
            showAllApps: true
            showAllAppsCategorized: false
            showSeparators: false
            showRecentApps: false
            showRecentDocs: false
            showPowerSession: false
            appletInterface: fenetre.racine
            Component.onCompleted: {
                refresh();
                // favoris « menu Démarrer » : même mécanisme que miryu-start
                favoritesModel.initForClient("org.kde.plasma.kicker.favorites.instance-" + Plasmoid.id);
            }
        }

        // ouverture d'un module de la Configuration du système
        Plasma5Support.DataSource {
            id: commande
            engine: "executable"
            onNewData: (source, donnees) => disconnectSource(source)
        }

        // lecture des actions supplémentaires et fichiers récents d'un .desktop
        Plasma5Support.DataSource {
            id: menuActions
            engine: "executable"
            onNewData: (source, donnees) => {
                fenetre.menuSortie = String(donnees["stdout"] || "");
                disconnectSource(source);
                fenetre.construireMenu();
            }
        }

        // noms courants des éléments « Récent » (voir rafraichirNomsRecents) :
        // relus à chaque changement de la liste, donc dans la langue du moment
        Plasma5Support.DataSource {
            id: nomsRecents
            engine: "executable"
            onNewData: (source, donnees) => {
                var cles = fenetre.clefsNoms;
                var carte = ({});
                var lignes = String(donnees["stdout"] || "").split("\n");
                for (var i = 0; i < lignes.length; i++) {
                    var l = lignes[i];
                    if (l.indexOf("NOM|") !== 0) continue;
                    // NOM|index|nom courant|chemin réel
                    var p = l.substring(4).split("|");
                    var idx = parseInt(p[0], 10);
                    if (!isFinite(idx) || idx < 0 || idx >= cles.length) continue;
                    var chemin = String(p[2] || "");
                    carte[cles[idx]] = {
                        nom: String(p[1] || ""),
                        chemin: chemin,
                        id: chemin.substring(chemin.lastIndexOf("/") + 1)
                                  .replace(/\.desktop$/i, "")
                    };
                }
                fenetre.infosRecents = carte;
                disconnectSource(source);
            }
        }

        // court délai après la fermeture du menu : le temps que l'activation de
        // la fenêtre se stabilise avant de décider s'il faut fermer la recherche.
        Timer {
            id: attenteFermetureMenu
            interval: 60
            repeat: false
            onTriggered: fenetre.verifierFermetureMenu()
        }

        // suit le pointeur sur la page (fonctionne sans focus) : sert à distinguer
        // un clic dans la recherche d'un clic à l'extérieur.
        HoverHandler {
            id: survolPage
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
                // KRunner/Milou exposent « urls » (liste d'URL) et « matchId » ;
                // les versions antérieures exposaient « url » / « duplicateId ».
                // Sans cette conversion, l'url restait vide : les récents ne
                // mémorisaient aucun identifiant et « Ajouter au bureau » /
                // « Épingler » n'avaient rien à utiliser.
                property var url: {
                    var liste = model.urls;
                    if (liste && liste.length > 0) return String(liste[0]);
                    return model.url !== undefined ? String(model.url) : "";
                }
                property var subtext: model.subtext || ""
                property var duplicateId: {
                    if (model.duplicateId !== undefined && String(model.duplicateId) !== "")
                        return String(model.duplicateId);
                    var d = model.matchId !== undefined ? String(model.matchId) : "";
                    // identifiant du lanceur de services : « exec:///usr/bin/kate » —
                    // ce n'est pas un identifiant de .desktop : l'URL le fournit déjà.
                    if (d.indexOf("exec://") === 0) {
                        var base = d.substring(d.lastIndexOf("/") + 1);
                        return /\.desktop$/i.test(base) ? base : "";
                    }
                    return d;
                }
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
                recents: fenetre.recentsAffiches
                revision: fenetre.ouvertures
                onFini: fenetre.fermer()
                onOuvrirModule: (module, libelle) => {
                    var url = "applications:" + module + ".desktop";
                    commande.connectSource(commandeKcm(module) + " #" + Date.now());
                    // mémorise le module KCM ouvert via les recherches rapides
                    memoriser({
                        display: libelle,
                        decoration: "preferences-system",
                        url: url,
                        category: i18n("System Settings"),
                        type: "settings"
                    });
                    fenetre.fermer();
                }
                onOuvrirRecent: (item) => fenetre.lancerRecent(item)
                onSupprimerRecent: (item) => fenetre.supprimerRecent(item)
                onOuvrirMenu: (item, parentItem, x, y) => fenetre.ouvrirMenuContext(item, parentItem, x, y)
            }

            // menu contextuel des éléments récents (PlasmaExtras.Menu = QMenu)
            PlasmaExtras.Menu {
                id: menuRecent
                onStatusChanged: {
                    if (status === PlasmaExtras.Menu.Open) {
                        // le menu détient l'activation : ne pas faire disparaître
                        // la fenêtre de recherche pendant qu'il est affiché.
                        fenetre.hideOnWindowDeactivate = false;
                    } else if (status === PlasmaExtras.Menu.Closed) {
                        // QMenu se ferme avant d'émettre le clic de l'entrée :
                        // on laisse passer un court délai avant de décider.
                        attenteFermetureMenu.restart();
                    }
                }
            }

            // génère les PlasmaExtras.MenuItem depuis le tableau menuItems
            Instantiator {
                model: fenetre.menuItems
                delegate: PlasmaExtras.MenuItem {
                    required property var modelData
                    text: modelData.texte || ""
                    icon: modelData.icone || ""
                    separator: modelData.separateur || false
                    onClicked: {
                        fenetre.menuItemClicked = true;
                        fenetre.executerEntreeMenu(modelData);
                    }
                }
                onObjectAdded: (index, object) => menuRecent.addMenuItem(object)
                onObjectRemoved: (index, object) => menuRecent.removeMenuItem(object)
            }

            // confirmation affichée en bas de la fenêtre après « Ajouter au bureau »
            // ou « Épingler au menu Démarrer »
            Rectangle {
                id: toast
                property string texte: ""
                z: 100
                opacity: 0
                visible: opacity > 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 28
                width: Math.min(parent.width - 48, 460)
                height: 40
                radius: 20
                color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                               Kirigami.Theme.backgroundColor.g,
                               Kirigami.Theme.backgroundColor.b, 0.96)
                border.width: 1
                border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                      Kirigami.Theme.textColor.g,
                                      Kirigami.Theme.textColor.b, 0.18)
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    font.family: Kirigami.Theme.defaultFont.family
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                    color: Kirigami.Theme.textColor
                    text: toast.texte
                }
            }

            Timer {
                id: attenteToast
                interval: 2600
                repeat: false
                onTriggered: toast.opacity = 0
            }

            // plus de bandeau du bas : le bouton Retour vit en haut des résultats
        }
    }
}
