#!/usr/bin/env bash

set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$project_dir/tests/fixtures"
capture="$(mktemp)"
trap 'rm -f "$capture"' EXIT

chmod +x "$fixture_dir/kitty"
export NVIM_OPEN_TEST_CAPTURE="$capture"
export PATH="$fixture_dir:$PATH"

"$project_dir/nvim-open.sh" "/tmp/file with spaces.md" "/tmp/-config.yaml"

mapfile -d '' -t actual <"$capture"
expected=(
  --class nvim-open
  --title Neovim
  -e nvim --
  "/tmp/file with spaces.md"
  "/tmp/-config.yaml"
)

if [[ "${#actual[@]}" -ne "${#expected[@]}" ]]; then
  printf 'FAIL: expected %d arguments, got %d\n' "${#expected[@]}" "${#actual[@]}" >&2
  printf 'actual: <%s>\n' "${actual[@]}" >&2
  exit 1
fi

for index in "${!expected[@]}"; do
  if [[ "${actual[$index]}" != "${expected[$index]}" ]]; then
    printf 'FAIL: argument %d: expected <%s>, got <%s>\n' \
      "$index" "${expected[$index]}" "${actual[$index]}" >&2
    exit 1
  fi
done

printf 'PASS: nvim-open launches an isolated Kitty window with intact paths\n'
