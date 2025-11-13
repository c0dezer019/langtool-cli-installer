#!/usr/bin/env bash

set -euo pipefail
[ -n "${LANGTOOL_DEBUG:-}" ] && set -x

usage() {
        cat <<'USAGE'
Usage: update_shell_rc.sh [options]

Options:
  -v, --variable NAME   Name of the variable to manage.
      --value VALUE     Value to assign, append, or prepend.
      --append          Append VALUE to PATH (requires --path).
      --prepend         Prepend VALUE to PATH (requires --path).
      --path            Operate on PATH (implies -v PATH).
  -rm                   Remove the variable from the Langtool section.
  -h, --help            Show this help message and exit.
USAGE
}

variable=""
value=""
mode="set"
path_flag=0

while [[ $# -gt 0 ]]; do
        case "$1" in
                -v|--variable)
                        [[ $# -lt 2 ]] && { echo "Missing argument for $1" >&2; exit 1; }
                        variable="$2"
                        shift 2
                        ;;
                --value)
                        [[ $# -lt 2 ]] && { echo "Missing argument for $1" >&2; exit 1; }
                        value="$2"
                        shift 2
                        ;;
                --append)
                        [[ "$mode" == "prepend" ]] && { echo "--append cannot be used with --prepend" >&2; exit 1; }
                        mode="append"
                        shift
                        ;;
                --prepend)
                        [[ "$mode" == "append" ]] && { echo "--prepend cannot be used with --append" >&2; exit 1; }
                        mode="prepend"
                        shift
                        ;;
                --path)
                        path_flag=1
                        shift
                        ;;
                -rm)
                        mode="remove"
                        shift
                        ;;
                -h|--help)
                        usage
                        exit 0
                        ;;
                *)
                        echo "Unknown option: $1" >&2
                        usage
                        exit 1
                        ;;
        esac
done

if (( path_flag )); then
        if [[ -n "$variable" && "$variable" != "PATH" ]]; then
                echo "--path cannot be combined with a different variable name" >&2
                exit 1
        fi
        variable="PATH"
fi

if [[ -z "$variable" ]]; then
        echo "A variable name must be provided with -v/--variable or --path" >&2
        exit 1
fi

if [[ "$mode" != "remove" ]]; then
        if [[ "$mode" != "set" && "$mode" != "append" && "$mode" != "prepend" ]]; then
                echo "Unsupported mode: $mode" >&2
                exit 1
        fi
        if [[ -z "$value" ]]; then
                echo "--value is required unless -rm is specified" >&2
                exit 1
        fi
fi

if [[ ("$mode" == "append" || "$mode" == "prepend") && path_flag -eq 0 ]]; then
        echo "--append/--prepend require --path" >&2
        exit 1
fi

if [[ "$mode" == "remove" && -n "$value" ]]; then
        # Value is irrelevant when removing but may be passed inadvertently.
        value=""
fi

shell_path="${SHELL:-/bin/sh}"
shell_name="$(basename "$shell_path")"

determine_shell_rc() {
        case "$shell_name" in
                bash)
                        printf '%s\n' "$HOME/.bashrc"
                        ;;
                zsh)
                        printf '%s\n' "$HOME/.zshrc"
                        ;;
                ksh)
                        printf '%s\n' "$HOME/.kshrc"
                        ;;
                fish)
                        printf '%s\n' "$HOME/.config/fish/config.fish"
                        ;;
                *)
                        printf '%s\n' "$HOME/.profile"
                        ;;
        esac
}

shell_rc="$(determine_shell_rc)"
mkdir -p "$(dirname "$shell_rc")"
touch "$shell_rc"

section_t="# Langtool-CLI Config"

escape_value() {
        local raw="$1"
        raw=${raw//\\/\\\\}
        raw=${raw//"/\\"}
        printf '%s' "$raw"
}

if [[ "$shell_name" == "fish" ]]; then
        pattern="^[[:space:]]*set[[:space:]]+-gx[[:space:]]+$variable([[:space:]]+|$)"
else
        pattern="^[[:space:]]*export[[:space:]]+$variable="
fi

extract_existing_line() {
        local pat="$1"
        awk -v start="$section_t" -v pat="$pat" '
                $0 == start { in_block=1; next }
                in_block && $0 ~ pat { print; exit }
        ' "$shell_rc"
}

extract_value() {
        local line="$1"
        if [[ -z "$line" ]]; then
                return
        fi
        if [[ "$shell_name" == "fish" ]]; then
                # Expected format: set -gx VAR "value"
                local prefix="set -gx "
                line="${line#$prefix}"
                prefix="${variable} "
                line="${line#$prefix}"
        else
                # Expected format: export VAR="value"
                local prefix="export "
                line="${line#$prefix}"
                prefix="${variable}="
                line="${line#$prefix}"
        fi

        local quote='"'
        line=${line%$quote}
        line=${line#$quote}
        printf '%s' "$line"
}

existing_line="$(extract_existing_line "$pattern")"
existing_value="$(extract_value "$existing_line")"

if (( path_flag )) && [[ -z "$existing_value" ]]; then
        existing_value="${PATH:-}"
fi

case "$mode" in
        set)
                new_value="$value"
                ;;
        append)
                if [[ -z "$existing_value" ]]; then
                        new_value="$value"
                else
                        if [[ ${existing_value: -1} == ":" ]]; then
                                new_value="${existing_value}$value"
                        else
                                new_value="${existing_value}:$value"
                        fi
                fi
                ;;
        prepend)
                if [[ -z "$existing_value" ]]; then
                        new_value="$value"
                else
                        new_value="$value${existing_value:+:}$existing_value"
                fi
                ;;
        remove)
                new_value=""
                ;;
        *)
                echo "Unsupported mode: $mode" >&2
                exit 1
                ;;

esac

if [[ "$mode" == "set" || "$mode" == "append" || "$mode" == "prepend" ]]; then
        escaped="$(escape_value "$new_value")"
        if [[ "$shell_name" == "fish" ]]; then
                newline="set -gx $variable \"$escaped\""
        else
                newline="export $variable=\"$escaped\""
        fi
        action="set"
else
        newline=""
        action="remove"
fi

if ! grep -qF "$section_t" "$shell_rc"; then
        if [[ "$action" == "remove" ]]; then
                exit 0
        fi
        if [[ -s "$shell_rc" ]]; then
                printf '\n' >> "$shell_rc"
        fi
        {
                printf '%s\n' "$section_t"
                printf '%s\n' "$newline"
        } >> "$shell_rc"
        exit 0
fi

tmp_file="${shell_rc}.tmp"
awk -v start="$section_t" -v newline="$newline" -v pat="$pattern" -v action="$action" '
        $0 == start {
                in_block=1
                print
                next
        }
        {
                if (in_block && $0 ~ pat) {
                        if (!updated) {
                                if (action != "remove") {
                                        print newline
                                }
                                updated=1
                        }
                        next
                }
                print
        }
        END {
                if (in_block && !updated && action != "remove") {
                        print newline
                }
        }
' "$shell_rc" > "$tmp_file"

mv "$tmp_file" "$shell_rc"
