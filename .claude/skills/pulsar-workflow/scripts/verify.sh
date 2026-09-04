#!/usr/bin/env bash
set -u
set -o pipefail

if ! root=$(git rev-parse --show-toplevel 2>/dev/null); then
  echo "ERROR: not inside a git repository" >&2
  exit 2
fi
cd "$root"

if [ ! -f go.mod ] || ! grep -qx 'module github.com/aidevance/pulsar' go.mod; then
  echo "ERROR: this is not the Pulsar repository (unexpected go.mod module)" >&2
  exit 2
fi

failures=0
results=()

record_pass() {
  results+=("PASS $1")
}

record_fail() {
  results+=("FAIL $1")
  failures=$((failures + 1))
}

run_check() {
  local name=$1
  shift
  printf '\n== %s ==\n' "$name"
  if "$@"; then
    record_pass "$name"
  else
    record_fail "$name"
  fi
}

check_xray() {
  if [ ! -f .xray-version ]; then
    echo "missing .xray-version" >&2
    return 1
  fi
  local pinned
  pinned=$(tr -d '[:space:]' < .xray-version)
  if ! command -v xray >/dev/null 2>&1; then
    echo "xray is not installed; CI installs pinned v${pinned}" >&2
    return 1
  fi
  local first_line
  first_line=$(xray version 2>&1 | sed -n '1p')
  printf 'pinned: %s\nlocal:  %s\n' "$pinned" "$first_line"
  case "$first_line" in
    *"$pinned"*) return 0 ;;
    *) echo "local Xray does not match the pinned version" >&2; return 1 ;;
  esac
}

check_go_version() {
  local required actual
  required=$(awk '$1 == "go" { print $2; exit }' go.mod)
  actual=$(go env GOVERSION 2>/dev/null || true)
  printf 'required: go%s\nlocal:    %s\n' "$required" "$actual"
  [ "$actual" = "go$required" ]
}

check_gofmt() {
  local out
  out=$(gofmt -l . | grep -v '^refs/' || true)
  if [ -n "$out" ]; then
    echo "not formatted:"
    echo "$out"
    return 1
  fi
}

build_all_platforms() {
  local os
  for os in linux windows darwin; do
    echo "GOOS=$os go build ./..."
    GOOS=$os go build ./... || return 1
  done
}

run_check "go-version" check_go_version
run_check "xray-version" check_xray
run_check "vet" go vet ./...
run_check "gofmt" check_gofmt
run_check "build-all-platforms" build_all_platforms
run_check "realtimelint" go run ./cmd/realtimelint .
run_check "test" go test ./...
run_check "negcheck" go run ./cmd/negcheck

printf '\n== SUMMARY ==\n'
printf '%s\n' "${results[@]}"

if [ "$failures" -ne 0 ]; then
  printf 'RESULT FAILED (%d checks failed)\n' "$failures"
  exit 1
fi

printf 'RESULT PASS\n'
