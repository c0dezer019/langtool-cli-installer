#!/bin/bash\

set_version() {
    local lt_sp_ver

    read -rp "Are you using a specific version of LanguageTool? [y/n](n): " lt_sp_ver

    case "${lt_sp_ver,,}" in
        "y" | "yes")
            read -rp "What version? (e.g., 6.8): " lt_ver

            if [[ "$lt_ver" =~ ^[0-9]+\.[0-9]+$ ]]; then
                export LT_VER="$lt_ver"
                update_shell_rc "LT_VER" "$lt_ver"
            else
                lt_ver="6.8"
            fi
            ;;
        "" | "n" | "no")
            export LT_VER="6.8" # Set default version
            update_shell_rc "LT_VER" "6.8"
            ;;
        *)
            echo "Only y[es] or n[o] is accepted as valid arguments."
            set_version
            ;;
    esac
}
