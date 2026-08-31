#!/usr/bin/env bash

DOTS_ROOT="${DOTS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Public CLI metadata only. Desired machine state lives exclusively in
# profiles/*.toml and machines/*.toml; shell arrays are intentionally gone so
# plan/apply/doctor/provision cannot drift apart.
# Format: canonical name | comma-separated aliases | usage | description.
DOTS_COMMANDS=(
  "plan|pl|dots plan [--json] [--profile names]|Preview exactly what apply would change"
  "apply|a|dots apply [--check|--links-only] [--profile names]|Converge the machine using the same plan engine"
  "drift|dr|dots drift [--json] [--profile names]|Explain managed, package and user-service drift"
  "provision|pv|dots provision [--dry-run|--yes] [--json] [--profile names]|Install only missing manifest prerequisites"
  "doctor|d|dots doctor [--json] [--profile names]|Check the machine against its selected profile"
  "check|c|dots check [all|shell|lua|python|generated|tests]|Run repository and reproducibility checks"
  "migrate|m|dots migrate [--check]|Detect or apply safe stale-state migrations"
  "history|hi,hist|dots history [--json]|List changing apply and rollback runs"
  "show|sh|dots show <run> [--json]|Show one recorded run and its backups"
  "rollback|rb|dots rollback <run>|Restore only dotfiles-owned paths changed by a recorded apply"
  "theme|t|dots theme [status|light|dark|toggle]|Show or switch the darkman theme"
  "restart|rs|dots restart <quickshell|kanata|darkman|copyq|all>|Restart managed user services"
  "refresh|rf|dots refresh <quickshell|systemd|all>|Rebuild derived state and reload services"
  "shell|s|dots shell <apps|bookmarks|clipboard|hotkeys|system|refresh|panel ...>|Control stable Quickshell actions"
  "panel|p|dots panel <system|audio|network|bluetooth|power|agents|updates|notifications|calendar>|Toggle a Quickshell panel"
  "debug|db|dots debug [--no-logs]|Print a compact diagnostic bundle"
  "commands|ls|dots commands [--json]|List commands, aliases and machine-readable metadata"
  "aliases|al|dots aliases [--json]|List every CLI abbreviation and its canonical command"
  "completion|comp|dots completion zsh|Print shell completion code"
  "help|h|dots help [command]|Show CLI or command help"
)

dots_resolve_command() {
  local input="$1" entry name aliases usage description alias
  local -a alias_list

  case "$input" in
    -h|--help) input="help" ;;
  esac

  for entry in "${DOTS_COMMANDS[@]}"; do
    IFS='|' read -r name aliases usage description <<<"$entry"
    if [ "$input" = "$name" ]; then
      printf '%s\n' "$name"
      return 0
    fi
    IFS=',' read -r -a alias_list <<<"$aliases"
    for alias in "${alias_list[@]}"; do
      if [ -n "$alias" ] && [ "$input" = "$alias" ]; then
        printf '%s\n' "$name"
        return 0
      fi
    done
  done
  return 1
}

dots_print_commands() {
  local entry name aliases usage description display
  for entry in "${DOTS_COMMANDS[@]}"; do
    IFS='|' read -r name aliases usage description <<<"$entry"
    display="$name"
    if [ -n "$aliases" ]; then
      display="$name (${aliases//,/, })"
    fi
    printf '  %-22s %s\n' "$display" "$description"
  done
}

dots_print_aliases() {
  local entry name aliases usage description alias
  local -a alias_list
  printf '%-10s %s\n' "ALIAS" "COMMAND"
  for entry in "${DOTS_COMMANDS[@]}"; do
    IFS='|' read -r name aliases usage description <<<"$entry"
    IFS=',' read -r -a alias_list <<<"$aliases"
    for alias in "${alias_list[@]}"; do
      [ -n "$alias" ] || continue
      printf '%-10s %s\n' "$alias" "$name"
    done
  done
}

dots_json_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

dots_print_alias_array() {
  local aliases="$1" alias first=1
  local -a alias_list
  printf '['
  IFS=',' read -r -a alias_list <<<"$aliases"
  for alias in "${alias_list[@]}"; do
    [ -n "$alias" ] || continue
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    first=0
    dots_json_string "$alias"
  done
  printf ']'
}

dots_print_commands_json() {
  local entry name aliases usage description first=1
  printf '[\n'
  for entry in "${DOTS_COMMANDS[@]}"; do
    IFS='|' read -r name aliases usage description <<<"$entry"
    if [ "$first" -eq 0 ]; then
      printf ',\n'
    fi
    first=0
    printf '  {"name":'
    dots_json_string "$name"
    printf ',"aliases":'
    dots_print_alias_array "$aliases"
    printf ',"usage":'
    dots_json_string "$usage"
    printf ',"description":'
    dots_json_string "$description"
    printf '}'
  done
  printf '\n]\n'
}

dots_print_aliases_json() {
  local entry name aliases usage description alias first=1
  local -a alias_list
  printf '[\n'
  for entry in "${DOTS_COMMANDS[@]}"; do
    IFS='|' read -r name aliases usage description <<<"$entry"
    IFS=',' read -r -a alias_list <<<"$aliases"
    for alias in "${alias_list[@]}"; do
      [ -n "$alias" ] || continue
      if [ "$first" -eq 0 ]; then
        printf ',\n'
      fi
      first=0
      printf '  {"alias":'
      dots_json_string "$alias"
      printf ',"command":'
      dots_json_string "$name"
      printf '}'
    done
  done
  printf '\n]\n'
}
