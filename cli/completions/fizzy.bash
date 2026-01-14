# fizzy bash completion
# Source this file or place in /etc/bash_completion.d/

_fizzy_completions() {
  local cur prev words cword
  _init_completion || return

  local commands="
    auth config help version
    boards cards columns comments reactions notifications people search show tags
    card board column close reopen triage untriage postpone comment assign tag watch unwatch gild ungild step react
    identity user
  "

  local auth_subcommands="login logout status refresh"
  local config_subcommands="list get set unset path"
  local card_subcommands="update delete image"
  local board_subcommands="create update delete show"
  local column_subcommands="create update delete show"
  local card_image_subcommands="delete"
  local comment_subcommands="edit delete"
  local step_subcommands="show update delete"
  local react_subcommands="delete"
  local user_subcommands="show update delete"

  # Handle two-level deep subcommands (card image)
  if [[ ${#words[@]} -ge 3 && "${words[1]}" == "card" && "${words[2]}" == "image" ]]; then
    COMPREPLY=($(compgen -W "$card_image_subcommands" -- "$cur"))
    return
  fi

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
    card)
      COMPREPLY=($(compgen -W "$card_subcommands" -- "$cur"))
      return
      ;;
    board)
      COMPREPLY=($(compgen -W "$board_subcommands" -- "$cur"))
      return
      ;;
    column)
      COMPREPLY=($(compgen -W "$column_subcommands" -- "$cur"))
      return
      ;;
    comment)
      COMPREPLY=($(compgen -W "$comment_subcommands" -- "$cur"))
      return
      ;;
    step)
      COMPREPLY=($(compgen -W "$step_subcommands" -- "$cur"))
      return
      ;;
    react)
      COMPREPLY=($(compgen -W "$react_subcommands" -- "$cur"))
      return
      ;;
    user)
      COMPREPLY=($(compgen -W "$user_subcommands" -- "$cur"))
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
