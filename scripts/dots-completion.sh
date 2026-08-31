#!/usr/bin/env bash
set -euo pipefail

DOTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/dots-lib.sh
source "$DOTS_ROOT/scripts/dots-lib.sh"

emit_zsh() {
  local entry name aliases usage description

  cat <<'ZSH'
_dots_profiles() {
  local -a profiles
  profiles=("$DOTFILES"/profiles/*.toml(N:t:r))
  compadd -a profiles
}

_dots_machines() {
  local -a machines
  machines=("$DOTFILES"/machines/*.toml(N:t:r))
  compadd -a machines
}

_dots_runs() {
  local runs_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/runs"
  local -a runs
  runs=("$runs_dir"/*.json(N:t:r))
  compadd -a runs
}

_dots() {
  local curcontext="$curcontext" state line command ret=1
  typeset -A opt_args
  local -a commands
  commands=(
ZSH

  # Completion intentionally exposes only canonical command names. CLI aliases
  # remain valid and discoverable via `dots aliases`, but they do not clutter
  # interactive completion menus.
  for entry in "${DOTS_COMMANDS[@]}"; do
    IFS='|' read -r name aliases usage description <<<"$entry"
    printf "    '%s:%s'\n" "$name" "$description"
  done

  cat <<'ZSH'
  )

  _arguments -C \
    '--help[show help]' \
    '1:command:->command' \
    '*::argument:->argument' && ret=0

  case "$state" in
    command)
      _describe -t commands 'dots command' commands && ret=0
      ;;
    argument)
      command="${line[1]}"
      curcontext="${curcontext%:*:*}:dots-${command}:"

      case "$command" in
        plan|drift|doctor)
          _arguments \
            '--help[show command help]' \
            '--json[machine-readable output]' \
            '--machine[select a machine manifest]:machine:_dots_machines' \
            '--profile[override selected profiles]:profiles:_dots_profiles' && ret=0
          ;;
        apply)
          _arguments \
            '--help[show command help]' \
            '--check[show the plan only]' \
            '--links-only[apply only managed links and files]' \
            '--machine[select a machine manifest]:machine:_dots_machines' \
            '--profile[override selected profiles]:profiles:_dots_profiles' && ret=0
          ;;
        provision)
          _arguments \
            '--help[show command help]' \
            '--dry-run[print actions without executing them]' \
            '--yes[skip interactive confirmation]' \
            '--json[machine-readable output]' \
            '--machine[select a machine manifest]:machine:_dots_machines' \
            '--profile[override selected profiles]:profiles:_dots_profiles' && ret=0
          ;;
        check)
          _arguments \
            '--help[show command help]' \
            '1:check scope:(all shell lua python generated tests)' && ret=0
          ;;
        migrate)
          _arguments \
            '--help[show command help]' \
            '--check[detect migrations without applying them]' && ret=0
          ;;
        history)
          _arguments \
            '--help[show command help]' \
            '--json[machine-readable output]' && ret=0
          ;;
        show)
          _arguments \
            '--help[show command help]' \
            '1:run id:_dots_runs' \
            '--json[machine-readable output]' && ret=0
          ;;
        rollback)
          _arguments \
            '--help[show command help]' \
            '1:run id:_dots_runs' && ret=0
          ;;
        theme)
          _arguments \
            '--help[show command help]' \
            '1:theme action:(status light dark toggle)' && ret=0
          ;;
        restart)
          _arguments \
            '--help[show command help]' \
            '1:service:(quickshell kanata darkman copyq all)' && ret=0
          ;;
        refresh)
          _arguments \
            '--help[show command help]' \
            '1:target:(quickshell systemd all)' && ret=0
          ;;
        shell)
          _arguments \
            '--help[show command help]' \
            '1:action:(apps bookmarks clipboard hotkeys system refresh panel)' \
            '2:panel:->shell-panel' && ret=0
          if [[ "$state" == shell-panel && "${line[1]}" == panel ]]; then
            _values 'panel' system audio network bluetooth power agents updates notifications calendar && ret=0
          fi
          ;;
        panel)
          _arguments \
            '--help[show command help]' \
            '1:panel:(system audio network bluetooth power agents updates notifications calendar)' && ret=0
          ;;
        debug)
          _arguments \
            '--help[show command help]' \
            '--no-logs[omit journal text]' && ret=0
          ;;
        commands|aliases)
          _arguments \
            '--help[show command help]' \
            '--json[machine-readable output]' && ret=0
          ;;
        completion)
          _arguments \
            '--help[show command help]' \
            '1:shell:(zsh)' && ret=0
          ;;
        help)
          _describe -t commands 'dots command' commands && ret=0
          ;;
      esac
      ;;
  esac

  return ret
}
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
