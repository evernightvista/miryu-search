/*
 * Fenestra Search — https://github.com/naykkalak/fenestra-search
 * SPDX-FileCopyrightText: 2026 naykkalak
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "Moteurs.js" as Moteurs

KCM.SimpleKCM {
    property alias cfg_largeurCran: largeur.value
    property string cfg_moteurWeb
    property alias cfg_iconeSeule: iconeSeule.checked

    Kirigami.FormLayout {
        RowLayout {
            Kirigami.FormData.label: i18n("Search box width:")
            QQC2.Slider {
                id: largeur
                from: 0
                to: 12
                stepSize: 1
                snapMode: QQC2.Slider.SnapAlways
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            }
            QQC2.Label { text: largeur.value }
        }

        QQC2.CheckBox {
            id: iconeSeule
            Kirigami.FormData.label: i18n("Search box:")
            text: i18n("Show icon only")
        }

        QQC2.Label {
            text: i18n("In icon-only mode, the search field moves to the top of the search window. You can also right-click the search box to toggle this.")
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            opacity: 0.7
            font: Kirigami.Theme.smallFont
        }

        QQC2.ComboBox {
            id: moteur
            Kirigami.FormData.label: i18n("Web search engine:")
            textRole: "nom"
            valueRole: "cle"
            model: [{ cle: "kde", nom: i18n("Follow KDE settings") }].concat(Moteurs.LISTE.map(function(m) {
                return { cle: m.cle, nom: m.nom };
            }))
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(cfg_moteurWeb))
            onActivated: cfg_moteurWeb = currentValue
        }
        QQC2.Label {
            text: i18n("“Follow KDE settings” uses the default engine chosen in System Settings › Web Search Keywords.")
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            opacity: 0.7
            font: Kirigami.Theme.smallFont
        }
    }
}
