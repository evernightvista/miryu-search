#!/bin/sh
# Fenestra Search — compile the translations (needs gettext: msgfmt)
# SPDX-FileCopyrightText: 2026 naykkalak
# SPDX-License-Identifier: GPL-3.0-or-later
# Run from this folder:  sh build.sh
set -e
cd "$(dirname "$0")"
for po in *.po; do
    lang="${po%.po}"
    mkdir -p "../contents/locale/$lang/LC_MESSAGES"
    msgfmt -o "../contents/locale/$lang/LC_MESSAGES/plasma_applet_org.fenestra.search.mo" "$po"
    echo "$lang OK"
done
