#!/bin/bash

LTCLI_ROWS=$(tput lines)
LTCLI_BAR_START=$((LTCLI_ROWS - 2))   # 2 bars, adjust to -1 if only one

_ltcli_to_bar_area() {
    tput sc
    tput cup "$LTCLI_BAR_START" 0
}

_ltcli_restore() {
    tput rc
}

show_progress() {
    local current=$1
    local total=$2
    local width=40

    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))

    _ltcli_to_bar_area

    printf "[%-${filled}s%-${empty}s] %3d%%\n" \
           "$(printf '#%.0s' $(seq 1 $filled))" \
           "" \
           $(( current * 100 / total ))

    _ltcli_restore
}
