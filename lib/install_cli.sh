#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/log_step.sh"

failed_clone() {
    echo "Failed to git clone $1"
    exit 1
}

install_cli() {
    log_step "Installing Langtool CLI into $2"

    if [ ! -d "$2" ]; then
        log_step "Ensuring directory exists for $2"

        if ! mkdir -p "$2" >/dev/null; then
            echo "Creating $2 requires elevated privileges,\
                        attempting with sudo..."
            sudo mkdir -p "$2"
        fi
    fi

    git -c advice.detachedHead=0 -c core.autocrlf=false clone --branch "$3" \
        --depth 1 "$1" "$2" || failed_clone "$1"
}
