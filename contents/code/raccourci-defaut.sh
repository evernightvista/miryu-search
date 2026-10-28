#!/bin/sh
# SPDX-FileCopyrightText: 2026 naykkalak
# SPDX-License-Identifier: GPL-3.0-or-later
# Fenestra Search — 给「激活小部件」动作加上默认快捷键（Win+S）。
#
# Plasma 的 Plasmoid.globalShortcut 只写「当前快捷键」，系统设置里因此把它
# 显示成「自定义快捷键」。真正的「默认快捷键」只能由 kglobalaccel 记录
# （setShortcutKeys + IsDefault 标志），所以这里通过它的 D-Bus 接口补写。
#
# 参数：$1 = 动作名（activate widget <id>）
# 动作由 plasmashell 在设置 Plasmoid.globalShortcut 时才注册，因此带重试。
ACT="${1:-}"
[ -z "$ACT" ] && exit 0

# QKeySequence("Meta+S") = Qt::MetaModifier | Qt::Key_S
CLE=268435539
# kglobalaccel 的 IsDefault 标志
DRAPEAU=8
# 动作 id = [组件, 动作, 组件名, 动作名]；前两项用于查找，后两项只在新建时使用
ID="['plasmashell', '$ACT', 'Plasma', 'Activate Widget']"

demander() {
    case "$1" in
    gdbus)
        gdbus call --session --dest org.kde.kglobalaccel \
            --object-path /kglobalaccel \
            --method org.kde.KGlobalAccel.setShortcutKeys \
            "$ID" "[([$CLE],)]" "$DRAPEAU" 2>/dev/null
        ;;
    busctl)
        busctl --user call org.kde.kglobalaccel /kglobalaccel \
            org.kde.KGlobalAccel setShortcutKeys 'asa(ai)u' \
            4 plasmashell "$ACT" Plasma "Activate Widget" \
            1 1 "$CLE" "$DRAPEAU" 2>/dev/null
        ;;
    esac
}

OUTIL=""
if command -v gdbus >/dev/null 2>&1; then
    OUTIL=gdbus
elif command -v busctl >/dev/null 2>&1; then
    OUTIL=busctl
else
    exit 0
fi

# 写入成功时接口会回显刚写入的键值；动作为未知的（尚未注册）则返回空列表。
i=0
while [ "$i" -lt 10 ]; do
    reponse=$(demander "$OUTIL")
    case "$reponse" in
    *"$CLE"*) exit 0 ;;
    esac
    i=$((i + 1))
    sleep 0.3
done
exit 1
