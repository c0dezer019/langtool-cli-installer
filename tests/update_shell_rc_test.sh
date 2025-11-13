#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cli="$repo_root/update_shell_rc.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

export HOME="$tmpdir"
export SHELL="/bin/bash"
shell_rc="$HOME/.bashrc"

original_path="$PATH"

assert_equals() {
        local expected="$1"
        local actual="$2"
        if [[ "$expected" != "$actual" ]]; then
                echo "Expected: $expected" >&2
                echo "Actual  : $actual" >&2
                exit 1
        fi
}

"$cli" -v TEST_VAR --value "value1"

grep -q "# Langtool-CLI Config" "$shell_rc"
assert_equals 'export TEST_VAR="value1"' "$(grep 'export TEST_VAR' "$shell_rc")"

"$cli" --path --append --value "/opt/langtool/bin"

path_line="$(grep '^export PATH=' "$shell_rc")"
assert_equals "export PATH=\"${original_path}:/opt/langtool/bin\"" "$path_line"

"$cli" --path --prepend --value "/custom/bin"

path_line="$(grep '^export PATH=' "$shell_rc")"
assert_equals "export PATH=\"/custom/bin:${original_path}:/opt/langtool/bin\"" "$path_line"

"$cli" --path --append --value "/another/bin"

path_line="$(grep '^export PATH=' "$shell_rc")"
assert_equals "export PATH=\"/custom/bin:${original_path}:/opt/langtool/bin:/another/bin\"" "$path_line"

"$cli" -v TEST_VAR --value "second"
assert_equals 'export TEST_VAR="second"' "$(grep 'export TEST_VAR' "$shell_rc")"

"$cli" -v TEST_VAR -rm
if grep -q 'export TEST_VAR' "$shell_rc"; then
        echo "Variable removal failed" >&2
        exit 1
fi
