#!/usr/bin/env bash
set -euo pipefail

DOTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/dots-lib.sh
source "$DOTS_ROOT/scripts/dots-lib.sh"

emit_zsh() {
  local entry name aliases usage description alias
  local -a alias_list

  cat <<'ZSH'
_dots() {
  local context state line command
  typeset -A opt_args
  local -a commands
  commands=(
ZSH

  for entry in "${DOTS_COMMANDS[@]}"; do
    IFS='|' read -r name aliases usage description <<<"$entry"
    printf "    '%s:%s'\n" "$name" "$description"
    IFS=',' read -r -a alias_list <<<"$aliases"
    for alias in "${alias_list[@]}"; do
      [ -n "$alias" ] || continue
      printf "    '%s:alias for %s'\n" "$alias" "$name"
    done
  done

  cat <<'ZSH'
  )

  _arguments -C \
    '1:command:->command' \
    '*::argument:->args'

  case "$state" in
    command)
      _describe 'dots command' commands
      ;;
    args)
      command="${words[2]}"
ZSH

  printf '      case "$command" in\n'
  for entry in "${DOTS_COMMANDS[@]}"; do
    IFS='|' read -r name aliases usage description <<<"$entry"
    IFS=',' read -r -a alias_list <<<"$aliases"
    for alias in "${alias_list[@]}"; do
      [ -n "$alias" ] || continue
      printf '        %s) command=%s ;;\n' "$alias" "$name"
    done
  done
  printf '      esac\n'

  cat <<'ZSH'
      words=("${words[@]:1}")
      (( CURRENT-- ))

      case "$command" in
        plan|drift|doctor)
          _arguments \
            '--json[machine-readable output]' \
            '--machine[select a machine manifest]:machine:' \
            '--profile[override selected profiles]:profiles:'
          ;;
        apply)
          _arguments \
            '--check[show the plan only]' \
            '--links-only[apply only managed links and files]' \
            '--machine[select a machine manifest]:machine:' \
            '--profile[override selected profiles]:profiles:'
          ;;
        provision)
          _arguments \
            '--dry-run[print actions without executing them]' \
            '--yes[skip interactive confirmation]' \
            '--json[machine-readable output]' \
            '--machine[select a machine manifest]:machine:' \
            '--profile[override selected profiles]:profiles:'
          ;;
        check)
          _arguments '1:check scope:(all shell lua python generated tests)'
          ;;
        migrate)
          _arguments '--check[detect migrations without applying them]'
          ;;
        history)
          _arguments '--json[machine-readable output]'
          ;;
        show)
          _arguments \
            '1:run id:' \
            '--json[machine-readable output]'
          ;;
        rollback)
          _arguments '1:run id:'
          ;;
        theme)
          _arguments '1:theme action:(status light dark toggle)'
          ;;
        restart)
          _arguments '1:service:(quickshell kanata darkman copyq all)'
          ;;
        refresh)
          _arguments '1:target:(quickshell systemd all)'
          ;;
        shell)
          _arguments '1:action:(apps bookmarks clipboard hotkeys system refresh panel)'
          ;;
        panel)
          _arguments '1:panel:(system audio network bluetooth power agents updates notifications calendar)'
          ;;
        debug)
          _arguments '--no-logs[omit journal text]'
          ;;
        commands|aliases)
          _arguments '--json[machine-readable output]'
          ;;
        completion)
          _arguments '1:shell:(zsh)'
          ;;
        help)
          _describe 'dots command' commands
          ;;
      esac
      ;;
  esac
}

compdef _dots dots ds
ZSH
}

case "${1:-}" in
  zsh) emit_zsh ;;
  help|-h|--help)
    echo "Usage: dots completion zsh"
    ;;
  *)
    echo "Usage: dots completion zsh" >&2
    exit 2
    ;;
esac
