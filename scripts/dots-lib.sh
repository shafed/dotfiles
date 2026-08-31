#!/usr/bin/env bash

DOTS_ROOT="${DOTS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Public CLI metadata only. Desired machine state lives exclusively in
# profiles/*.toml and machines/*.toml; shell arrays are intentionally gone so
# plan/apply/doctor/provision cannot drift apart.
DOTS_COMMANDS=(
  "plan|dots plan [--json] [--profile names]|Preview exactly what apply would change"
  "apply|dots apply [--check|--links-only] [--profile names]|Converge the machine using the same plan engine"
  "drift|dots drift [--json] [--profile names]|Explain managed, package and user-service drift"
  "provision|dots provision [--dry-run|--yes] [--json] [--profile names]|Install only missing manifest prerequisites"
  "stage|dots stage [ref] [--json] [--profile names]|Validate a candidate ref in an isolated worktree and HOME"
  "doctor|dots doctor [--json] [--profile names]|Check the machine against its selected profile"
  "check|dots check [all|shell|lua|python|generated|tests]|Run repository and reproducibility checks"
  "migrate|dots migrate [--check]|Detect or apply safe stale-state migrations"
  "history|dots history [--json]|List changing apply and rollback runs"
  "show|dots show <run> [--json]|Show one recorded run and its backups"
  "rollback|dots rollback <run>|Restore only dotfiles-owned paths changed by a recorded apply"
  "theme|dots theme [status|light|dark|toggle]|Show or switch the darkman theme"
  "restart|dots restart <quickshell|kanata|darkman|copyq|all>|Restart managed user services"
  "refresh|dots refresh <quickshell|systemd|all>|Rebuild derived state and reload services"
  "shell|dots shell <apps|bookmarks|clipboard|hotkeys|system|refresh|panel ...>|Control stable Quickshell actions"
  "panel|dots panel <system|audio|network|bluetooth|power|agents|updates|notifications|calendar>|Toggle a Quickshell panel"
  "debug|dots debug [--no-logs]|Print a compact diagnostic bundle"
  "commands|dots commands [--json]|List commands and machine-readable metadata"
  "help|dots help [command]|Show CLI or command help"
)

dots_print_commands() {
  local entry rest name description
  for entry in "${DOTS_COMMANDS[@]}"; do
    name="${entry%%|*}"
    rest="${entry#*|}"
    description="${rest#*|}"
    printf '  %-10s %s\n' "$name" "$description"
  done
}

dots_json_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

dots_print_commands_json() {
  local entry rest name usage description first=1
  printf '[\n'
  for entry in "${DOTS_COMMANDS[@]}"; do
    name="${entry%%|*}"
    rest="${entry#*|}"
    usage="${rest%%|*}"
    description="${rest#*|}"
    if [ "$first" -eq 0 ]; then
      printf ',\n'
    fi
    first=0
    printf '  {"name":'
    dots_json_string "$name"
    printf ',"usage":'
    dots_json_string "$usage"
    printf ',"description":'
    dots_json_string "$description"
    printf '}'
  done
  printf '\n]\n'
}
