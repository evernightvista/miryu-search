/*
 * Fenestra Search — https://github.com/naykkalak/fenestra-search
 * SPDX-FileCopyrightText: 2026 naykkalak
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Gestion de la liste « Récent » : programmes et modules de la Configuration
 * du système ouverts par le biais de la recherche.
 * Chaque élément ouvert est replacé en première position (le plus récent en
 * tête) ; la liste est sérialisée en JSON dans la configuration du plasmoid.
 */
.pragma library

// nombre maximum d'éléments mémorisés dans la liste des récents
var MAX_RECENTS = 12;

// Charge la liste des récents depuis la chaîne JSON stockée en configuration.
// Retourne un tableau vide si la chaîne est absente ou invalide.
function charger(texte) {
    if (!texte) return [];
    try {
        var liste = JSON.parse(texte);
        if (Array.isArray(liste)) return liste;
    } catch (e) {}
    return [];
}

// Sérialise la liste des récents en chaîne JSON pour la configuration.
function sauvegarder(liste) {
    return JSON.stringify(liste || []);
}

// Ajoute un élément ou le déplace en première position.
// item : { display, decoration, url, duplicateId, category, type }
//   - duplicateId : identifiant du .desktop fourni par KRunner (les applications
//     n'ont souvent pas d'url : c'est cet identifiant qui permet de les relancer)
//   - type : "app" (programme) ou "settings" (module de Configuration du système)
// Retourne une nouvelle liste (l'originale n'est pas modifiée).
function clef(item) {
    var u = String(item.url || "");
    if (u.length > 0) return u;
    var d = String(item.duplicateId || "");
    if (d.length > 0) return d;
    return String(item.display || "");
}

function ajouter(liste, item) {
    if (!item || !item.display) return liste || [];
    var k = clef(item);
    var nom = String(item.display || "").toLocaleLowerCase();
    var resultat = [];
    var origine = liste || [];
    for (var i = 0; i < origine.length; i++) {
        var ancien = origine[i];
        if (clef(ancien) === k) continue;
        // entrée d'une version antérieure, réduite au nom (aucun identifiant) :
        // remplacée par la nouvelle entrée complète
        var sansId = String(ancien.url || "").length === 0
                  && String(ancien.duplicateId || "").length === 0;
        if (sansId && nom.length > 0 && String(ancien.display || "").toLocaleLowerCase() === nom)
            continue;
        resultat.push(ancien);
    }
    resultat.unshift({
        display: String(item.display || ""),
        decoration: String(item.decoration || ""),
        url: String(item.url || ""),
        duplicateId: String(item.duplicateId || ""),
        category: String(item.category || ""),
        type: item.type || "app"
    });
    if (resultat.length > MAX_RECENTS) resultat = resultat.slice(0, MAX_RECENTS);
    return resultat;
}

// Retire un élément de la liste (identifié par son url, sinon son display).
// Retourne une nouvelle liste ; l'originale n'est pas modifiée.
function retirer(liste, item) {
    if (!item) return liste || [];
    var k = clef(item);
    var resultat = [];
    var origine = liste || [];
    for (var i = 0; i < origine.length; i++) {
        if (clef(origine[i]) !== k) resultat.push(origine[i]);
    }
    return resultat;
}
