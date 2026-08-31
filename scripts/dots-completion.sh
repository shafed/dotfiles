#!/usr/bin/env bash
set -euo pipefail

DOTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/dots-lib.sh
source "$DOTS_ROOT/scripts/dots-lib.sh"

emit_zsh() {
  local entry name aliases usage description alias
  local -a alias_list

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
    '(-h --help)'{-h,--help}'[show help]' \
    '1:command:->command' \
    '*::argument:->argument' && ret=0

  case "$state" in
    command)
      _describe -t commands 'dots command' commands && ret=0
      ;;
    argument)
      command="${line[1]}"
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
      curcontext="${curcontext%:*:*}:dots-${command}:"

      case "$command" in
        plan|drift|doctor)
          _arguments \
            '(-h --help)'{-h,--help}'[show command help]' \
            '--json[machine-readable output]' \
            '--machine[select a machine manifest]:machine:_dots_machines' \
            '--profile[override selected profiles]:profiles:_dots_profiles' && ret=0
          ;;
        apply)
          _arguments \
            '(-h --help)'{-h,--help}'[show command help]' \
            '--check[show the plan only]' \
            '--links-only[apply only managed links and files]' \
            '--machine[select a machine manifest]:machine:_dots_machines' \
            '--profile[override selected profiles]:profiles:_dots_profiles' && ret=0
          ;;
        provision)
          _arguments \
            '(-h --help)'{-h,--help}'[show command help]' \
            '--dry-run[print actions without executing them]' \
            '--yes[skip interactive confirmation]' \
            '--json[machine-readable output]' \
            '--machine[select a machine manifest]:machine:_dots_machines' \
            '--profile[override selected profiles]:profiles:_dots_profiles' && ret=0
          ;;
        check)
          _arguments \
            '(-h --help)'{-h,--help}'[show command help]' \
            '1:check scope:(all shell sh lua python py generated gen g tests t)' && ret=0
          ;;
        migrate)
          _arguments \
            '(-h --help)'{-h,--help}'[show command help]' \
            '--check[detect migrations without applying them]' && ret=0
          ;;
        history)
          _arguments \
            '(-h --help)'{-h,--help}'[show command help]' \
            '--json[machine-readable output]' && ret=0
          ;;
        show)
          _arguments \
            '(-h --help)'{-h,--help}'[show command help]' \
            '1:run id:_dots_runs' \
            '--json[machine-readable output]' && ret=0
          ;;
        rollback)
          _arguments \
            '(-h --help)'{-h,--help}'[show command help]' \
            '1:run id:_dots_runs' && ret=0
          ;;
        theme)
          _arguments \
            '(-h --help)'{-h,--help}'[show command help]' \
            '1:theme action:(status s light l dark d toggle t)' && ret=0
          ;;
        restart)
          _arguments \
            '(-h --help)'{-h,--help}'[show command help]' \
            '1:service:(quickshell q kanata k darkman d copyq all a)' && ret=0
          ;;
        refresh)
          _arguments \
            '(-h --help)'{-h,--help}'[show command help]' \
            '1:target:(quickshell q systemd s all a)' && ret=0
          ;;
        shell)
          _arguments \
            '(-h --help)'{-h,--help}'[show command help]' \
            '1:action:(apps a launcher bookmarks b clipboard c hotkeys h system s refresh r panel)' \
            '2:panel:->shell-panel' && ret=0
          if [[ "$state" == shell-panel && "${line[1]}" == panel ]]; then
            _values 'panel' system s audio a network n bluetooth b power p agents ag updates u notifications no calendar c && ret=0
          fi
          ;;
        panel)
          _arguments \
            '(-h --help)'{-h,--help}'[show command help]' \
            '1:panel:(system s audio a network n bluetooth b power p agents ag updates u notifications no calendar c)' && ret=0
          ;;
        debug)
          _arguments \
            '(-h --help)'{-h,--help}'[show command help]' \
            '--no-logs[omit journal text]' && ret=0
          ;;
        commands|aliases)
          _arguments \
            '(-h --help)'{-h,--help}'[show command help]' \
            '--json[machine-readable output]' && ret=0
          ;;
        completion)
          _arguments \
            '(-h --help)'{-h,--help}'[show command help]' \
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
