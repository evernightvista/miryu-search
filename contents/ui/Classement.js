/*
 * Fenestra Search — https://github.com/naykkalak/fenestra-search
 * SPDX-FileCopyrightText: 2026 naykkalak
 * Similarity score and category keywords adapted from MFile Search,
 * SPDX-FileCopyrightText: MCC45TR, GPL-3.0 — https://github.com/MCC45TR/kde-plasma6-widgets
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Classement des résultats de KRunner :
 *   1. une correspondance exacte passe devant tout (le nom sans son extension compte :
 *      « document1 » trouve exactement « Document1.docx ») ;
 *   2. puis l'ordre des rubriques : applications, fichiers, documents, dossiers,
 *      calcul, web, le reste ;
 *   3. puis la ressemblance avec le texte tapé.
 * Les résultats sont ensuite regroupés par rubrique. Une rubrique d'un seul résultat
 * (hors applications et correspondance exacte) va dans « Autres résultats », en dernier.
 */
.pragma library

// Les noms de rubriques de KRunner sont traduits par le bureau : on les reconnaît
// par des mots-clés dans plusieurs langues.
var MOTS = {
    app: ["application", "aplicación", "aplicacion", "aplicação", "aplicacao", "applicazione", "aplicație",
          "aplicatie", "anwendung", "toepassing", "aplikac", "sovellus", "program", "uygulama",
          "прилож", "програм", "εφαρμογ", "تطبيق", "برنامه", "앱", "애플리케이션", "アプリ", "应用"],
    calcul: ["calcul", "calculator", "unit", "currency", "einheit", "rechner", "währung", "unité", "devise",
             "calcol", "unità", "valuta", "calculadora", "unidad", "moneda", "kalkulator", "jednost", "walut",
             "hesap", "birim", "döviz", "калькуля", "единиц", "валют", "計算", "単位", "通貨", "计算", "单位", "货币"],
    document: ["document", "belge", "dokument", "documento", "documente", "dokumen", "документ", "έγγραφο",
               "مستند", "문서", "ドキュメント", "文档"],
    dossier: ["folder", "place", "ordner", "orte", "dossier", "emplacement", "carpeta", "lugares", "pasta",
              "cartella", "map", "katalog", "kansio", "plats", "klasör", "yerler", "папк", "мест", "φάκελ",
              "مجلد", "폴더", "フォルダー", "文件夹"],
    fichier: ["file", "datei", "fichier", "archivo", "ficheiro", "bestand", "plik", "soubor", "tiedosto",
              "fil", "dosya", "файл", "αρχείο", "ملف", "파일", "ファイル", "文件"],
    image: ["image", "picture", "photo", "bild", "foto", "imagem", "immagine", "afbeeld", "obraz", "resim",
            "görsel", "изображ", "εικόν", "صورة", "이미지", "画像", "图像", "图片"],
    web: ["web", "browser", "bookmark", "internet", "lesezeichen", "navigateur", "signet", "marcador",
          "segnalibro", "bladwijzer", "zakład", "yer imi", "брауз", "заклад", "متصفح", "북마크", "ブックマーク", "书签"],
    autre: ["other", "andere", "autre", "otro", "outro", "altro", "overig", "inne", "diğer", "друг",
            "άλλ", "أخرى", "기타", "その他", "其他"]
};

function minuscule(v) {
    return String(v || "").toLocaleLowerCase().replace(/̇/g, "");
}

function contient(v, liste) {
    var t = minuscule(v);
    for (var i = 0; i < liste.length; i++)
        if (t.indexOf(liste[i]) !== -1) return true;
    return false;
}

function extension(url) {
    var p = minuscule(url).split(/[?#]/)[0];
    var s = p.lastIndexOf("/"), d = p.lastIndexOf(".");
    return d > s + 1 ? p.substring(d + 1) : "";
}

function estCalcul(rubrique, icone, id) {
    return contient(rubrique, MOTS.calcul)
        || contient(icone, ["calculator", "accessories-calculator", "currency"])
        || contient(id, ["calculator", "unitconverter", "converter"]);
}

function genre(rubrique) {
    if (estCalcul(rubrique)) return "calcul";
    if (contient(rubrique, MOTS.app)) return "app";
    if (contient(rubrique, MOTS.document)) return "document";
    if (contient(rubrique, MOTS.dossier)) return "dossier";
    if (contient(rubrique, MOTS.fichier)) return "fichier";
    if (contient(rubrique, MOTS.web)) return "web";
    if (contient(rubrique, MOTS.autre)) return "autre";
    return "inconnu";
}

// plus petit = plus haut dans la liste
function priorite(rubrique) {
    var g = genre(rubrique);
    return {app: 1, fichier: 2, document: 3, dossier: 4, calcul: 5, web: 6, autre: 100}[g] || 50;
}

function estApplication(rubrique, url, id, icone) {
    if (minuscule(url).endsWith(".desktop") || minuscule(id).endsWith(".desktop")) return true;
    var i = minuscule(icone);
    if (i === "application-x-executable" || i.indexOf("applications-") === 0
            || i.indexOf("system-settings") === 0 || i.indexOf("preferences-") === 0)
        return true;
    return contient(rubrique, MOTS.app);
}

function estDossier(rubrique, url, icone) {
    return minuscule(url).endsWith("/") || minuscule(icone).indexOf("folder") !== -1
        || contient(rubrique, MOTS.dossier);
}

// Détecte si un résultat est un programme OU un module de la Configuration
// du système (KCM). Ces éléments sont mémorisés dans la liste « Récent ».
// type retourné : "app", "settings" ou "" si non concerné.
var MOTS_SETTINGS = ["settings", "configuration", "reglage", "reglages", "parametre", "parametres",
                     "configuración", "configuracao", "configuração", "configurazione",
                     "настройк", "установк", "параметр", "設定", "设置", "설정",
                     "einstellungen", "instellingen", "ustawien", "ayarlar", "impostazioni"];

function estLancable(rubrique, url, id, icone) {
    var u = minuscule(url), i = minuscule(icone);
    // modules KCM explicites : kcm_xxx.desktop, kcm://..., kcmshell, systemsettings
    if (u.indexOf("kcm:") === 0) return "settings";
    if (u.indexOf("kcmshell") !== -1 || u.indexOf("systemsettings") !== -1) return "settings";
    if (/\/kcm_[^\/]+\.desktop$/.test(u)) return "settings";
    if (i.indexOf("preferences-") === 0 || i.indexOf("system-settings") === 0
        || i === "systemsettings" || i.indexOf("kcm") === 0
        || i === "configure" || i === "settings-configure")
        return "settings";
    if (contient(rubrique, MOTS_SETTINGS)) return "settings";
    // applications (y compris celles dont l'icône est de type « app »)
    if (estApplication(rubrique, url, id, icone)) return "app";
    return "";
}

// suggestions de la Logithèque (« Obtenir … ») : applications non installées,
// absentes de la recherche de Windows 11 -> masquées
function estLogitheque(rubrique, url) {
    return minuscule(url).indexOf("appstream:") === 0
        || ["logithèque", "software center", "software centre", "softwarecenter", "discover",
            "centro de software", "centro software", "centre logiciel"].indexOf(minuscule(rubrique)) !== -1;
}

// puces de filtre : Tout, Applications, Documents, Images, Dossiers, Web
function passeFiltre(filtre, r) {
    var url = minuscule(r.url), ic = minuscule(r.decoration), ext = extension(r.url);
    switch (filtre) {
    case "Apps":
        return estApplication(r.category, r.url, r.duplicateId, r.decoration);
    case "Docs":
        return contient(r.category, MOTS.document) || ic.indexOf("document") !== -1 || ic.indexOf("text") !== -1
            || ["txt", "md", "pdf", "odt", "doc", "docx", "rtf", "epub", "xls", "xlsx", "ods", "ppt", "pptx", "odp"].indexOf(ext) !== -1;
    case "Images":
        return contient(r.category, MOTS.image) || ic.indexOf("image") !== -1 || ic.indexOf("photo") !== -1
            || ["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "tif", "tiff", "avif", "heic"].indexOf(ext) !== -1;
    case "Folders":
        return estDossier(r.category, r.url, r.decoration);
    case "Web":
        return url.indexOf("http://") === 0 || url.indexOf("https://") === 0 || url.indexOf("www") === 0
            || ic.indexOf("web") !== -1 || ic.indexOf("globe") !== -1 || contient(r.category, MOTS.web);
    }
    return true;
}

// ressemblance entre le texte tapé q et le nom t (déjà en minuscules), de 0 à 1
function ressemblance(q, t) {
    if (t === q) return 1;
    var i = t.indexOf(q);
    if (i === 0) return 0.95;
    if (i !== -1) return Math.max(0.5, 0.85 - i * 0.01);
    var qi = 0;
    for (var ti = 0; ti < t.length && qi < q.length; ti++)
        if (t.charAt(ti) === q.charAt(qi)) qi++;
    if (qi === q.length) return 0.3 + (q.length / t.length) * 0.3;
    var initiales = "", dansMot = false;
    for (var k = 0; k < t.length; k++) {
        var c = t.charAt(k);
        if (c === " " || c === "-" || c === "_" || c === ".") dansMot = false;
        else if (!dansMot) { initiales += c; dansMot = true; }
    }
    return initiales.indexOf(q) !== -1 ? 0.6 : 0;
}

function exact(nom, q) {
    var p = nom.lastIndexOf(".");
    return nom === q || (p > 0 && nom.substring(0, p) === q);
}

// bruts : [{display, decoration, category, url, subtext, duplicateId, index}]
// rend la liste à plat, chaque élément portant sa rubrique d'affichage (rubrique)
function classer(bruts, texte, filtre, maximum, autresResultats) {
    var q = minuscule(texte);
    var notes = [];
    for (var i = 0; i < bruts.length; i++) {
        var r = bruts[i];
        if (filtre !== "All" && !passeFiltre(filtre, r)) continue;
        var nom = minuscule(r.display);
        var note = ressemblance(q, nom);
        if (note < 1 && exact(nom, q)) note = 1;
        notes.push({r: r, prio: priorite(r.category), note: note, ordre: i});
    }
    notes.sort(function(a, b) {
        var ea = a.note >= 1 ? 1 : 0, eb = b.note >= 1 ? 1 : 0;
        if (ea !== eb) return eb - ea;
        if (a.prio !== b.prio) return a.prio - b.prio;
        if (a.note !== b.note) return b.note - a.note;
        return a.ordre - b.ordre;
    });
    if (maximum > 0 && notes.length > maximum) notes = notes.slice(0, maximum);

    // regroupement par rubrique, dans l'ordre d'apparition
    var groupes = {}, ordre = [];
    for (var j = 0; j < notes.length; j++) {
        var c = notes[j].r.category || "Other";
        if (!groupes[c]) { groupes[c] = []; ordre.push(c); }
        groupes[c].push(notes[j].r);
    }
    var gardees = [], exactes = [], autres = [];
    for (var k = 0; k < ordre.length; k++) {
        var nomR = ordre[k], items = groupes[nomR], aExact = false;
        for (var x = 0; x < items.length; x++)
            if (exact(minuscule(items[x].display), q)) { aExact = true; break; }
        if (items.length <= 1 && !contient(nomR, MOTS.app) && !aExact) {
            for (var m = 0; m < items.length; m++) autres.push(items[m]);
        } else {
            gardees.push(nomR);
            if (aExact) exactes.push(nomR);
        }
    }
    gardees.sort(function(a, b) { return priorite(a) - priorite(b); });
    // la rubrique qui contient une correspondance exacte passe en tête
    var finales = gardees.filter(function(n) { return exactes.indexOf(n) !== -1; })
        .concat(gardees.filter(function(n) { return exactes.indexOf(n) === -1; }));

    var liste = [];
    for (var n = 0; n < finales.length; n++)
        for (var p = 0; p < groupes[finales[n]].length; p++) {
            groupes[finales[n]][p].rubrique = finales[n];
            liste.push(groupes[finales[n]][p]);
        }
    for (var a = 0; a < autres.length; a++) {
        autres[a].rubrique = autresResultats;
        liste.push(autres[a]);
    }
    return liste;
}

// chemin affiché sous le nom : relatif au dossier personnel
function cheminCourt(r) {
    if (r.web) return r.subtext;      // recherche web : le site du moteur
    var u = String(r.url || "");
    // programme ou module KCM (.desktop) : ne pas afficher le chemin technique
    if (/\.desktop$/i.test(u.split(/[?#]/)[0])) return r.subtext || "";
    var p = u.replace("file://", "").replace(/^\/home\/[^\/]+\//, "");
    return p || r.subtext || "";
}
