#!/bin/bash

log_step() {
    local msg="$1"

    printf '\e[32m==>\e[0m %s\n' "$msg"
}