#  _________  __  __ _
# |__  /  _ \|  \/  | |
#   / /| |_) | |\/| | |
#  / /_|  __/| |  | | |___
# /____|_|   |_|  |_|_____|
#
# ZPML: ZSH Prompt Macro Language
#
#
# MIT License
#
# Copyright (c) 2018 Alexandros Kozak
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#
# https://github.com/agkozak/agkozak-zsh-theme
#

(( $(tput colors) >= 8 )) && typeset -g ZPML_HAS_COLORS=1

############################################################
# Set a macro
#
# Globals:
#   ZPML_MACROS
#
# Arguments:
#   $1 Macro name
#   $2 Macro (preferably quoted)
############################################################
set_macro() {
  ZPML_MACROS[$1]="$2"
}

############################################################
# For printing parser errors
#
# Globals:
#   ZPML_HAS_COLORS
#
# Arguments:
#   $1 Error text
############################################################
_zpml_parser_error() {
  (( ZPML_HAS_COLORS )) && print -Pn "%F{red}" >&2
  print -n "zpml: $1" >&2
  (( ZPML_HAS_COLORS )) && print -P "%f" >&2
}

############################################################
# Parse an array and output a prompt
#
# Globals:
#   ZPML_HAS_COLORS
#   ZPML_MACROS
#
# Arguments:
#   $1 Name of prompt to be constructed
#   $2 Whether to force color or mono (for debugging)
############################################################
zpml_construct_prompt() {
  local i ternary_stack literal output
  [[ $2 == 'color' ]] && ZPML_HAS_COLORS=1
  [[ $2 == 'mono' ]] && ZPML_HAS_COLORS=0

  local -A styles
  styles=(
    bold      '%B'
    unbold    '%b'
    reverse   '%S'
    unreverse '%s'
    unfg      '%f'
    unbg      '%b'
  )

  for i in $(eval echo -n "\$$1"); do
    if (( literal )); then
      output+="$i"
      literal=0
    elif [[ $i == 'literal' ]]; then
      literal=1
    elif [[ $ternary_stack == 'if' ]]; then
      case $i in
        is_exit_*)
          if [[ ${i#is_exit_} == '0' ]]; then
            output+='?'
          else
            output+="${i#is_exit_}?"
          fi
          ;;
        is_superuser)
          output+='!'
          ;;
        *) _zpml_parser_error "Unsupported condition: $i" && return 1
          ;;
      esac
      ternary_stack+='cond'
    else
      case $i in
        if)
          if [[ $ternary_stack != '' ]]; then
            _zpml_parser_error "Missing 'fi'." && return 1
          else
            output+='%('
            ternary_stack+='if'
          fi
          ;;
        then)
          if [[ $ternary_stack != 'ifcond' ]]; then
            _zpml_parser_error "Missing 'if' or conditional statement." && return 1
          else
            output+='.'           # TODO: a period may be incorrect, depending on
            ternary_stack+="$i"   # what the ternary is supposed to print.
          fi
          ;;
        else)
          if [[ $ternary_stack != 'ifcondthen' ]]; then
            _zpml_parser_error "Missing 'if', condition, or 'then'." \
              && return 1
          else
            output+='.'           # TODO: ditto.
            ternary_stack+="$i"
          fi
          ;;
        fi)
          if [[ $ternary_stack == 'ifcondthenelse' ]]; then
            output+=')'
          # When `else' is implicit
          elif [[ $ternary_stack == 'ifcondthen' ]]; then
            output+='.)'          # TODO: see above.
          else
            _zpml_parser_error "Missing 'if', condition, or 'then'." \
              && return 1
          fi
          ternary_stack=''
          ;;
        bold|reverse)
          output+="$styles[$i]"
          ;;
        fg_*)
          (( ZPML_HAS_COLORS )) && {
            output+="%F{${i#fg_}}"
          }
          ;;
        bg_*)
          (( ZPML_HAS_COLORS )) && {
            output+="%K{${i#bg_}}"
          }
          ;;
        unfg|unbg)
          (( ZPML_HAS_COLORS )) && {
            output+="$styles[$i]"
          }
          ;;
        unbold|unreverse)
          output+="$styles[$i]"
          ;;
        space) output+=' ' ;;
        newline) output+=$'\n' ;;
        *)
          [[ -n ${ZPML_MACROS[$i]} ]] && output+="${ZPML_MACROS[$i]}"
          ;;
      esac
    fi
  done

  if [[ $ternary_stack != '' ]]; then
    _zpml_parser_error "Invalid condition in $1."
  else
    echo -n "$output"
  fi
}

############################################################
# zpml utility
#
# Globals:
#   ZPML_THEME_DIR
#
# TODO: Arguments
############################################################
zpml() {
  # Keep ZPML simple: no need for typeset -g in theme files
  setopt LOCAL_OPTIONS NO_WARN_CREATE_GLOBAL

  case $1 in
    load)
      case $2 in
        random)
          local themes=( ${ZPML_THEME_DIR}/*.zpml )
          source "${themes[$(( $RANDOM % ${#themes[@]} + 1 ))]}" &> /dev/null
          # TODO: A bit kludgy, plus shouldn't I consider the possibility of
          # of someone's wanting to remove the left prompt?
          if [[ -z $ZPML_RPROMPT ]]; then
            RPROMPT=''
          fi
          ;;
        *)
          if ! source "${ZPML_THEME_DIR}/${2}.zpml" &> /dev/null; then
            echo 'Theme file not found.' >&2
          fi
          # TODO: See immediately above.
          if [[ -z $ZPML_RPROMPT ]]; then
            RPROMPT=''
          fi
          ;;
      esac
      ;;
    *)
      echo 'Command not defined.' >&2
      ;;
  esac
}
