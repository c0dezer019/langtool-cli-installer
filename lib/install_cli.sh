#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/log_step.sh"

failed_clone() {
    echo "Failed to git clone $1"
    exit 1
}

install_cli() {
    local updated=false

    log_step "Installing Langtool CLI into $2"

    if [ -d "$2" ]; then
        log_step "Previous installation of Langtool-CLI found, updating."

        if ! rm -rf "$2" >/dev/null 2>&1; then
            sudo rm -rf "$2"
        fi

        updated=true
    fi

    git -c advice.detachedHead=0 -c core.autocrlf=false clone --branch "$3" \
            --depth 1 "$1" "$2" || failed_clone "$1"

    export LT_CLI_UPDATED="$updated"
}
