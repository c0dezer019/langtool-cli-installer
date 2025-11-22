#!/usr/bin/env bash

set -e
[ -n "$LANGTOOL_DEBUG" ] && set -x

# shellcheck disable=SC1091
source "./lib/install_cli.sh"
# shellcheck disable=SC1091
source "./lib/update_shell_rc.sh"
# shellcheck disable=SC1091
source "./lib/set_version.sh"
# shellcheck disable=SC1091
source "./lib/log_step.sh"

home_dir=""
cli_install_dir=""

if [ -z "$HOME" ]; then
    if command -v whoami >/dev/null 2>&1; then
        home_dir="/home/$(whoami)"
        export HOME=$home_dir
    elif [ -n "$USER" ]; then
        home_dir="/home/${USER}"
        export HOME=$home_dir
    else
        echo "Unable to determine the user, please manually set HOME before \
		continuing."
        exit 1
    fi

    echo "In order to use Langtool-CLI you should set your HOME as this \
        tool only sets it temporarily: usermod -d /home/[user] [user]"
fi

if [ -z "$LT_CLI_DIR" ]; then
    log_step "Resolving Langtool CLI installation directory"
    read -rp "Where would you like langtool-cli to be installed? \
(${HOME}/.local/share)" cli_install_dir

    if [ -n "$cli_install_dir" ]; then
        export LT_CLI_DIR="$cli_install_dir"
        update_shell_rc "LT_CLI_DIR" "$cli_install_dir"
    else
        cli_install_dir="$HOME/.local/share/Langtool-CLI"
        export LT_CLI_DIR="$cli_install_dir"
        update_shell_rc "LT_CLI_DIR" "$cli_install_dir"
    fi

    log_step "Ensuring Langtool CLI directory exists at $LT_CLI_DIR"
    if ! mkdir -p "$LT_CLI_DIR" 2>/dev/null; then
        echo "Creating $LT_CLI_DIR requires elevated privileges, \
                attempting with sudo..."
        sudo mkdir -p "$LT_CLI_DIR"
    fi
else
    log_step "Resolving Langtool CLI installation directory"
    update_shell_rc "LT_CLI_DIR" "$LT_CLI_DIR"
fi

if [ -z "$LT_INSTALL_DIR" ]; then
    log_step "Resolving LanguageTool installation directory"
    read -rp "Where is LanguageTool installed? (${HOME}/.local/share)" \
        install_dir

    if [ -n "$install_dir" ]; then
        export LT_INSTALL_DIR="$install_dir"
        update_shell_rc "LT_INSTALL_DIR" "$install_dir"
    else
        export LT_INSTALL_DIR="$HOME/.local/share/LanguageTool"
        update_shell_rc "LT_INSTALL_DIR" "$HOME/.local/share/LanguageTool"
    fi
else
    log_step "Resolving LanguageTool installation directory"
    update_shell_rc "LT_INSTALL_DIR" "$LT_INSTALL_DIR"
fi

if [ -z "${LT_VER}" ]; then
    set_version
else
    update_shell_rc "LT_VER" "$LT_VER"
fi

log_step "Checking for git"
if ! command -v git 1>/dev/null 2>&1; then
    echo "langtool-cli: Git is not installed, can't continue." >&2
    exit 1
fi

if [ -n "${USE_SSH}" ]; then
    log_step "Checking for ssh"
    if ! command -v ssh 1>/dev/null 2>&1; then
        echo "langtool-cli: ssh is not installed and cannot continue." >&2

        exit 1
    fi

    ssh -T git@github.com 1>/dev/null 2>&1 || EXIT_CODE=$?
    if [[ ${EXIT_CODE} != 1 ]]; then
        echo "langtool-cli: github ssh authentication failed."
        echo
        echo "In order to use the ssh connection option, you need to \
                have an ssh key set up."
        echo "Please generate an ssh key by using ssh-keygen, or follow\
                 the instructions at the following URL for more information:"
        echo
        echo "> https://docs.github.com/en/repositories/creating-and-\
                managing-repositories/troubleshooting-cloning-errors#check-your-ssh-access"
        echo
        echo "Once you have an ssh key set up, try running the command again."

        exit 1
    fi
fi

if [ -n "${USE_SSH}" ]; then
    GITHUB="git@github.com"
else
    GITHUB="https://github.com/"
fi

install_cli ${GITHUB}c0dezer019/Langtool-CLI.git "$LT_CLI_DIR" "${LANGTOOL_GIT_TAG:-base}"

if [ -n "$LT_CLI_DIR" ]; then
    lt_cli_bin="$LT_CLI_DIR/bin"
    path_contains_bin=0
    IFS=':' read -r -a path_entries <<<"${PATH:-}"

    for entry in "${path_entries[@]}"; do
        if [ "$entry" = "$lt_cli_bin" ]; then
            path_contains_bin=1
            break
        fi
    done
    if [ $path_contains_bin -eq 0 ]; then
        export PATH="$lt_cli_bin:$PATH"
    fi

    log_step "Creating CLI symlinks in $lt_cli_bin"

    if [ ! -d "$LT_CLI_DIR/bin" ]; then
        if [ ! -w "$LT_CLI_DIR" ]; then
            sudo mkdir "$LT_CLI_DIR/bin"
        else
            mkdir "$LT_CLI_DIR/bin"
        fi
    fi

    ln -s "$LT_CLI_DIR/lib/langtool" "$LT_CLI_DIR/bin/langtool"
    ln -s "$LT_CLI_DIR/lib/uninstall" "$LT_CLI_DIR/bin/uninstall"

    update_shell_rc "PATH" "$LT_CLI_DIR/bin" prepend_path
    printf 'Symlinks created in %s\n' "$lt_cli_bin"

    if [ "$LT_CLI_UPDATED" ]; then
        echo "Langtool-CLI updated."
    else
        echo "Installation complete."
        echo "Please restart your shell to access the CLI"
    fi

fi
