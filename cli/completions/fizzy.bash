# fizzy bash completion
# Source this file or place in /etc/bash_completion.d/

_fizzy_completions() {
  local cur prev words cword
  _init_completion || return

  local commands="
    auth config help version
    boards cards columns comments notifications people search show tags
    card close reopen triage untriage postpone comment assign tag watch unwatch gild ungild step react
  "

  local auth_subcommands="login logout status refresh"
  local config_subcommands="list get set unset path"

  case "$prev" in
    fizzy)
      COMPREPLY=($(compgen -W "$commands" -- "$cur"))
      return
      ;;
    auth)
      COMPREPLY=($(compgen -W "$auth_subcommands" -- "$cur"))
      return
      ;;
    config)
      COMPREPLY=($(compgen -W "$config_subcommands" -- "$cur"))
      return
      ;;
    --board|-b|--in)
      # Could complete board names if cached, for now just return
      return
      ;;
    --status)
      COMPREPLY=($(compgen -W "all closed not_now stalled golden postponing_soon" -- "$cur"))
      return
      ;;
    --scope)
      COMPREPLY=($(compgen -W "write read" -- "$cur"))
      return
      ;;
    --sort)
      COMPREPLY=($(compgen -W "latest newest oldest" -- "$cur"))
      return
      ;;
  esac

  # Handle flags
  if [[ "$cur" == -* ]]; then
    local flags="--json -j --md -m --quiet -q --data --verbose -v --board -b --in --account -a --help -h"
    COMPREPLY=($(compgen -W "$flags" -- "$cur"))
    return
  fi
}

complete -F _fizzy_completions fizzy
