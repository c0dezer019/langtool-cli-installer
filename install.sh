#!/usr/bin/env bash

set -e
[ -n "$LANGTOOL_DEBUG" ] && set -x

UPDATE_SHELL="./lib/$UPDATE_SHELL.sh"
LOG_STEP="./lib/log_step.sh"
SET_VERSION="./lib/set_version.sh"
INSTALL_CLI="./lib/install_cli.sh"

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
    $LOG_STEP "Resolving Langtool CLI installation directory"
    read -rp "Where would you like langtool-cli to be installed? \
(${HOME}/.local/share)" cli_install_dir

    if [ -n "$cli_install_dir" ]; then
        export LT_CLI_DIR="$cli_install_dir"
        $UPDATE_SHELL "LT_CLI_DIR" "$cli_install_dir"
    else
        cli_install_dir="$HOME/.local/share/Langtool-CLI"
        export LT_CLI_DIR="$cli_install_dir"
        $UPDATE_SHELL "LT_CLI_DIR" "$cli_install_dir"
    fi

    $LOG_STEP "Ensuring Langtool CLI directory exists at $LT_CLI_DIR"
    if ! mkdir -p "$LT_CLI_DIR" 2>/dev/null; then
        echo "Creating $LT_CLI_DIR requires elevated privileges, \
                attempting with sudo..."
        sudo mkdir -p "$LT_CLI_DIR"
    fi
else
    $LOG_STEP "Resolving Langtool CLI installation directory"
    $UPDATE_SHELL "LT_CLI_DIR" "$LT_CLI_DIR"
fi

if [ -z "$LT_INSTALL_DIR" ]; then
    $LOG_STEP "Resolving LanguageTool installation directory"
    read -rp "Where is LanguageTool installed? (${HOME}/.local/share)" \
        install_dir

    if [ -n "$install_dir" ]; then
        export LT_INSTALL_DIR="$install_dir"
        $UPDATE_SHELL "LT_INSTALL_DIR" "$install_dir"
    else
        export LT_INSTALL_DIR="$HOME/.local/share/LanguageTool"
        $UPDATE_SHELL "LT_INSTALL_DIR" "$HOME/.local/share/LanguageTool"
    fi
else
    $LOG_STEP "Resolving LanguageTool installation directory"
    $UPDATE_SHELL "LT_INSTALL_DIR" "$LT_INSTALL_DIR"
fi

if [ -z "${LT_VER}" ]; then
    $SET_VERSION
else
    $UPDATE_SHELL "LT_VER" "$LT_VER"
fi

$LOG_STEP "Checking for git"
if ! command -v git 1>/dev/null 2>&1; then
    echo "langtool-cli: Git is not installed, can't continue." >&2
    exit 1
fi

if [ -n "${USE_SSH}" ]; then
    $LOG_STEP "Checking for ssh"
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

$INSTALL_CLI ${GITHUB}c0dezer019/Langtool-CLI.git "$LT_CLI_DIR" "${LANGTOOL_GIT_TAG:-base}"

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

    $LOG_STEP "Creating CLI symlinks in $lt_cli_bin"

    if [ ! -d "$LT_CLI_DIR/bin" ]; then
        if [ ! -w "$LT_CLI_DIR" ]; then
            sudo mkdir "$LT_CLI_DIR/bin"
        else
            mkdir "$LT_CLI_DIR/bin"
        fi
    fi

    ln -s "$LT_CLI_DIR/lib/langtool" "$LT_CLI_DIR/bin/langtool"
    ln -s "$LT_CLI_DIR/lib/uninstall" "$LT_CLI_DIR/bin/uninstall"

    $UPDATE_SHELL "PATH" "$LT_CLI_DIR/bin" prepend_path
    printf 'Symlinks created in %s\n' "$lt_cli_bin"
    print 'Installation complete\n'
fi
