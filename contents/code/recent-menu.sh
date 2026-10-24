#!/bin/sh
# SPDX-FileCopyrightText: 2026 naykkalak
# SPDX-License-Identifier: GPL-3.0-or-later
# Extrait, pour un fichier .desktop donné :
#   - son chemin réel et son nom dans la langue courante
#   - les actions supplémentaires [Desktop Action ...] (nom + ligne Exec)
#   - les fichiers récents ouverts par cette application (depuis recently-used.xbel),
#     filtrés par les types MIME déclarés dans le .desktop.
# L'argument peut être un chemin, « applications:<id>.desktop », « exec://… »
# ou un nom affiché — y compris dans une autre langue : les entrées « Récent »
# mémorisées avant un changement de langue restent donc retrouvées.
# Format de sortie (séparateur |) :
#   DESKTOP|<chemin réel>
#   NOM|<Nom dans la langue courante>
#   ACTION|<Nom>|<Exec>
#   FILE|<Nom affiché>|<URL>
# Mode « --noms » (un argument par élément) :
#   NOM|<index>|<Nom courant>|<chemin réel>

# vrai si le .desktop déclare ce nom dans n'importe quelle langue
nom_correspond() {
    awk -v nom="$2" '
        /^\[/ { g = ($0 == "[Desktop Entry]") ; next }
        g && /^Name(\[[^]]*\])?=/ {
            sub(/^Name(\[[^]]*\])?=/, "")
            if ($0 == nom) { f = 1; exit }
        }
        END { exit(f ? 0 : 1) }
    ' "$1"
}

# chemin réel du .desktop correspondant à l'argument (vide si introuvable)
trouver_desktop() {
    v="$1"
    case "$v" in
        exec://*) v=${v#exec://} ;;
        applications:*) v=${v#applications:} ;;
        file://*) v=${v#file://} ;;
    esac
    [ -z "$v" ] && return 0
    case "$v" in
        /*) if [ -f "$v" ]; then printf '%s' "$v"; return 0; fi ;;
    esac
    f=${v##*/}
    case "$f" in *.desktop) ;; *) f="$f.desktop" ;; esac
    for d in "$HOME/.local/share/applications" /usr/local/share/applications \
             /usr/share/applications /var/lib/flatpak/exports/share/applications \
             "$HOME/.local/share/flatpak/exports/share/applications" \
             /var/lib/snapd/desktop/applications; do
        if [ -f "$d/$f" ]; then printf '%s' "$d/$f"; return 0; fi
    done
    # repli : nom affiché, comparé à toutes les langues de « Name ».
    # Une seule passe grep par dossier (les correspondances sont ensuite
    # vérifiées dans le groupe [Desktop Entry] par nom_correspond) : parcourir
    # tous les .desktop un par un serait trop lent à chaque ouverture.
    echappe=$(printf '%s' "$v" | sed 's/[][\\.^$*+?(){}|]/\\&/g')
    motif='^Name(\[[^]]*\])?='"$echappe"'$'
    for d in "$HOME/.local/share/applications" /usr/local/share/applications \
             /usr/share/applications /var/lib/flatpak/exports/share/applications \
             "$HOME/.local/share/flatpak/exports/share/applications" \
             /var/lib/snapd/desktop/applications; do
        [ -d "$d" ] || continue
        liste=$(grep -lE -- "$motif" "$d"/*.desktop 2>/dev/null)
        [ -z "$liste" ] && continue
        ancienIFS=$IFS
        IFS='
'
        for x in $liste; do
            if [ -f "$x" ] && nom_correspond "$x" "$v"; then
                IFS=$ancienIFS
                printf '%s' "$x"
                return 0
            fi
        done
        IFS=$ancienIFS
    done
    return 0
}

# lecture d'une clé d'un groupe du .desktop (sans dépendre de kreadconfig6)
# usage : clef_desktop <groupe> <clé>
# index()/substr() plutôt qu'une expression régulière : les clés localisées
# contiennent des crochets (Name[zh_CN]) qui seraient lus comme une classe
# de caractères par awk.
clef_desktop() {
    awk -v grp="$1" -v key="$2" '
        BEGIN { wanted = 0 }
        /^\[/ {
            gsub(/[\[\]]/, "", $0)
            wanted = ($0 == grp) ? 1 : 0
            next
        }
        wanted && index($0, key "=") == 1 {
            print substr($0, length(key) + 2)
            exit
        }
    ' "$DESKTOP"
}

# langues à essayer, de la plus spécifique à la plus générale, dans le même
# ordre que KLocalizedString (LANGUAGE, puis LC_ALL, LC_MESSAGES, LANG)
langues() {
    printf '%s\n' "$LANGUAGE" "$LC_ALL" "$LC_MESSAGES" "$LANG" \
        | tr ':' '\n' \
        | sed -e 's/\..*$//' -e 's/-/_/g' -e 's/[[:space:]]*$//' \
        | awk 'NF && !vu[$0]++'
}

# valeur traduite d'une clé (Name[zh_CN], Name[zh], …), repli sur la clé nue.
# Sans cela les actions supplémentaires du .desktop restaient en anglais.
# La boucle tourne dans une sous-couche (tuyau) et sort dès la première
# correspondance : IFS vaut « ; » à cet endroit du script, on n'en dépend donc pas.
clef_localisee() {
    grp="$1"
    key="$2"
    trouve=$(langues | while IFS= read -r lang; do
        v=$(clef_desktop "$grp" "$key[$lang]")
        if [ -z "$v" ]; then
            base=${lang%%_*}
            [ "$base" != "$lang" ] && v=$(clef_desktop "$grp" "$key[$base]")
        fi
        if [ -n "$v" ]; then
            printf '%s' "$v"
            exit 0
        fi
    done)
    if [ -n "$trouve" ]; then
        printf '%s' "$trouve"
    else
        clef_desktop "$grp" "$key"
    fi
}

# ── Mode « --noms » : nom courant et chemin réel de chaque élément ──
if [ "$1" = "--noms" ]; then
    shift
    i=0
    for arg in "$@"; do
        DESKTOP=$(trouver_desktop "$arg")
        if [ -n "$DESKTOP" ]; then
            nom=$(clef_localisee "Desktop Entry" "Name" | tr '|' '/')
            [ -n "$nom" ] && printf 'NOM|%s|%s|%s\n' "$i" "$nom" "$DESKTOP"
        fi
        i=$((i + 1))
    done
    exit 0
fi

# ── Résolution de l'argument ──
DESKTOP=$(trouver_desktop "$1")
[ -z "$DESKTOP" ] && exit 0

# nom et chemin courants : le QML s'en sert pour les libellés et pour
# retrouver le .desktop quel que soit le nom mémorisé (autre langue).
printf 'DESKTOP|%s\n' "$DESKTOP"
NOMDESKTOP=$(clef_localisee "Desktop Entry" "Name" | tr '|' '/')
[ -n "$NOMDESKTOP" ] && printf 'NOM|%s\n' "$NOMDESKTOP"

# ── Actions supplémentaires du .desktop ──
ACTIONS=$(clef_desktop "Desktop Entry" "Actions")
IFS=';'
for act in $ACTIONS; do
    [ -z "$act" ] && continue
    NAME=$(clef_localisee "Desktop Action $act" "Name")
    EXEC=$(clef_desktop "Desktop Action $act" "Exec")
    [ -z "$NAME" ] && continue
    NAME=$(printf '%s' "$NAME" | tr '|' '/')
    EXEC=$(printf '%s' "$EXEC" | tr '|' '/')
    printf 'ACTION|%s|%s\n' "$NAME" "$EXEC"
done
unset IFS

# ── Fichiers récents associés aux types MIME de l'application ──
MIMES=$(clef_desktop "Desktop Entry" "MimeType")
[ -z "$MIMES" ] && exit 0

XBEL="$HOME/.local/share/recently-used.xbel"
[ -f "$XBEL" ] || exit 0

# construit une regex de types MIME (échappe les caractères regex, ignore les champs vides)
MIMEREG=$(printf '%s' "$MIMES" | sed 's/[.[\*^$()+?{|]/\\&/g; s/;/\n/g' | grep -v '^$' | tr '\n' '|' | sed 's/|$//')
[ -z "$MIMEREG" ] && exit 0

# parse le xbel : pour chaque <bookmark>, retient href puis le mime:mime-type
awk '
    /<bookmark / {
        inb = 1
        href = ""
        mime = ""
        n = index($0, "href=\"")
        if (n > 0) {
            reste = substr($0, n + 6)
            fin = index(reste, "\"")
            if (fin > 0) href = substr(reste, 1, fin - 1)
        }
    }
    inb && /<mime:mime-type / {
        n = index($0, "type=\"")
        if (n > 0) {
            reste = substr($0, n + 6)
            fin = index(reste, "\"")
            if (fin > 0) mime = substr(reste, 1, fin - 1)
        }
    }
    /<\/bookmark>/ {
        if (inb && href != "" && mime != "") print mime "\t" href
        inb = 0
    }
' "$XBEL" | grep -E "$MIMEREG" | head -10 | while IFS="$(printf '\t')" read -r mime url; do
    name=$(printf '%s' "$url" | sed 's|.*/||')
    name=$(printf '%b' "$(printf '%s' "$name" | sed 's/%/\\x/g')")
    name=$(printf '%s' "$name" | tr '|' '/')
    url=$(printf '%s' "$url" | tr '|' '/')
    printf 'FILE|%s|%s\n' "$name" "$url"
done
