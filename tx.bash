#!/bin/bash 
# bash completion for the Transifex command line client, tx
#
# Copyright (C) 2013 Pete Travis <me@petetravis.com>
# Distributed under the GNU General Public License, version 2.0.
#
__tx_dir () {
  pushd . &>/dev/null;
  while [ "$PWD" != "/" ]; do
    if [ -d .tx ]; then 
      echo "$PWD/.tx/config"
      return 0
    fi
    cd ..
    if [ "$PWD" == "/" ]; then
    #  echo -e "\nNo tx config found in parent directories!" 1>&2
      return 1
    fi
  done
  popd &>/dev/null
  exit 0
}
 
__tx_resources () {
  TXCONFIG=$(__tx_dir) || return 1
  echo $(sed -ne 's/\[\(.*\..*\)\]/\1/p' $TXCONFIG)
  }

__project_slug_fetch () {
  PROJECT_SLUG=$(sed -ne 's/\[\(.*\)\..*\]/\1/p' $TXCONFIG|sort -u)
  echo $PROJECT_SLUG
}

__lang_opt_check () {
  # ONLINE_LANGS is turning project-specific language suggestions OFF by default.
  TX_GLOBAL_CONFIG="${HOME}/.transifexrc"
  ONLINE_LANGS=$(sed -ne 's/online_langs = \(.*\)$/\1/p' $TX_GLOBAL_CONFIG)
  if [[ -z "$ONLINE_LANGS" || "$ONLINE_LANGS" == "false" || "$ONLINE_LANGS" == "FALSE" ]]; then
    return 1
  elif [[ "$ONLINE_LANGS" == "true" || "$ONLINE_LANGS" == "TRUE" ]]; then
    TXCONFIG=$(__tx_dir) || return 1
    PROJECT_SLUG=$(__project_slug_fetch)
    TXTMPDIR="/run/user/$(id -u)/tx" 
    if [[ ! -d "$TXTMPDIR" ]]; then
      mkdir $TXTMPDIR
    fi
    TX_USER=$(sed -ne 's/username = \(.*\)$/\1/p' $TX_GLOBAL_CONFIG)
    TX_PASS=$(sed -ne 's/password = \(.*\)$/\1/p' $TX_GLOBAL_CONFIG)
    TXCONFIG=$(__tx_dir) || return 1
    if [[ "$ONLINE_LANGS" == "ONLINE" && -z "$TX_GLOBAL_CONFIG" && -z "$TX_USER" && -z "$TX_PASS" ]]; then
      LANGFILE="${TXTMPDIR}/tx.${PROJECT_SLUG}.langs"
      CURLARG="-L --user "${TX_USER}:${TX_PASS}" https://www.transifex.com/api/2/project/${PROJECT_SLUG}/languages/"
    else
      LANGFILE="${TXTMPDIR}/tx.languages.all"
      CURLARG="https://www.transifex.com/api/2/languages/"
    fi
    if [[ ! -s "$LANGFILE" ]]; then
      touch $LANGFILE
      echo -e "\nChecking supported languages. This only happens once per login session." 1>&2
      curl -i -X GET $CURLARG | sed -ne 's/"code": "\(.*\)",/\1/p' > $LANGFILE ||\
      { 
        echo -e "\nCannot find supported languages for project, are you online?" 1>&2
        return 1
      }
    fi
  fi
  echo $(compgen -W "$(cat $LANGFILE)" -- $cur)

}

__resource_opt_check () {
  WYRD="${COMP_WORDS[COMP_CWORD-1]}"
  if [[ "$WYRD" == "-r" || "$WYRD" == "--resource" ]]; then
    echo $(compgen -W "$(__tx_resources)" -- $cur)
    return 0;
  else
    return 1;
  fi
}

__mode_opt_check () {
  MODES="reviewed translator developer"
  WYRD="${COMP_WORDS[COMP_CWORD-1]}"
  if [[ "$WYRD" == "--mode" ]]; then
    echo "$(compgen -W "$MODES" -- $cur)"
    return 0;
  else
    return 1
  fi
}

__set_types () {
  TYPES="ANDROID STRINGS DESKTOP PO PROPERTIES INI MAGENTO MIF DTD MOZILLAPROPERTIES PHP_ARRAY TXT PLIST QT SRT SUB SBV WIKI RESX RESJSON HTML XHTML XLIFF YAML KEYVALUEJSON CHROME"
  echo "$(compgen -W "$TYPES" -- $cur)"
}

__trim_args () {
   REMOVE_OPTIONS=()
    for USED_OPTIONS in ${COMP_WORDS[@]}; do
      REMOVE_OPTIONS+=($USED_OPTIONS)
      case $USED_OPTIONS in
        -r)
          REMOVE_OPTIONS+=("--resource")
          ;;
        --resources)
          REMOVE_OPTIONS+=("-r")
          ;;
        -s)
          REMOVE_OPTIONS+=("--source")
          REMOVE_OPTIONS+=("--source-language")
          ;;
        --source)
          REMOVE_OPTIONS+=("-s")
          REMOVE_OPTIONS+=("--auto-remote")
          REMOVE_OPTIONS+=("--auto-local")
          ;;
        --source-language)
          REMOVE_OPTIONS+=("-s")
          ;;
        -t)
          REMOVE_OPTIONS+=("--type")
          REMOVE_OPTIONS+=("--translations")
          ;;
        --type)
          REMOVE_OPTIONS+=("-t")
          ;;
        -l)
          REMOVE_OPTIONS+=("--language")
          REMOVE_OPTIONS+=("--auto-remote")
          REMOVE_OPTIONS+=("--auto-local")
          ;;
        --language)
          REMOVE_OPTIONS+=("-l")
          REMOVE_OPTIONS+=("--auto-remote")
          REMOVE_OPTIONS+=("--auto-local")
          ;;
        -a)
          REMOVE_OPTIONS+=("--all")
          ;;
        --all)
          REMOVE_OPTIONS+=("-a")
          ;;
        --auto-local)
          REMOVE_OPTIONS+=("--auto-remote")
          REMOVE_OPTIONS+=("--source")
          ;;
        -f)
          REMOVE_OPTIONS+=("--source-file")
          ;;
        --source-file)
          REMOVE_OPTIONS+=("-f")
          ;;

      esac
    done
    REMOVE_OPTIONS+=(${COMP_WORDS[COMP_CWORD-1]})
  echo ${REMOVE_OPTIONS[@]}
}

__add_args () {
  ADD_OPTIONS=()
  if [[ "${COMP_WORDS[COMP_CWORD-1]}" == "set" ]]; then
    ADD_OPTIONS+=("--auto-remote")
  fi
  for USED_OPTIONS in ${COMP_WORDS[@]}; do
    case $USED_OPTIONS in
      --auto-local)
        ADD_OPTIONS+=("-s")
        ADD_OPTIONS+=("--source-language")
        ADD_OPTIONS+=("-f")
        ADD_OPTIONS+=("--source-file")
        # leaving out --execute, not sure how to use it.
        #ADD_OPTIONS+=("--execute")
        ;;
    esac
  done
  echo ${ADD_OPTIONS[@]}
}

__iterate_args () {
  WYRD="${COMP_WORDS[COMP_CWORD-1]}"
  INPUT=$@
  case $WYRD in
    -l|--language)
      echo "$(__lang_opt_check)" || return 1
      return 0;
      ;;
    --mode)
      echo "$(__mode_opt_check)" || return 1
      return 0;
      ;;
    -r|--resource)
      echo "$(__resource_opt_check)" || return 1
      return 0
      ;;
    -t|--translation|--type)
      if [[ "${COMP_WORDS[1]}" == "set" ]]; then
        echo "$(__set_types)"
        return 0;
      fi
      ;;
    -f)
      if [[ "${COMP_WORDS[1]}" == "set" ]]; then
        echo "$(compgen -f ${COMP_WORDS[${COMP_CWORD}]})" || return 1
      fi
      return 0
      ;;
    --user|--host|--auto-remote)
      return 0;
      ;;
    *)
      echo $(compgen -W "$(echo ${CURRENT_OPTIONS[@]})" -- $cur)
      return 0
      ;;
  esac
 }

__tx_action_words () {
 action="${COMP_WORDS[1]}"
 case "$action" in
  help|-h) 
    CURRENT_OPTIONS=(${ACTIONS[@]})
    if [[ ${#COMP_WORDS[@]} -gt 3 ]]; then
      return 1;
    fi
    ;;
  delete)
    CURRENT_OPTIONS=(${DELETE_OPTIONS[@]})
    ;;
  init)
    CURRENT_OPTIONS=(${INIT_OPTIONS[@]})
  ;;
  pull)
    CURRENT_OPTIONS=(${PULL_OPTIONS[@]})
    ;;
  push)
    CURRENT_OPTIONS=(${PUSH_OPTIONS[@]})
    ;;
  set)
    CURRENT_OPTIONS=(${SET_OPTIONS[@]})
    ;;
  esac
  REMOVE_OPTIONS=($(__trim_args))
  ADD_OPTIONS=($(__add_args))
  for ADD_OPT in ${ADD_OPTIONS[@]};do
    CURRENT_OPTIONS+=($ADD_OPT)
  done
  for RM_OPT in ${REMOVE_OPTIONS[@]}; do
    for i in ${!CURRENT_OPTIONS[@]}; do
      if [[ "${CURRENT_OPTIONS[i]}" == "$RM_OPT" ]]; then
        unset CURRENT_OPTIONS[i]
      fi
    done
  done
   echo "$(__iterate_args $(echo ${CURRENT_OPTIONS[@]}))"
}

_tx_complete () {
  COMPREPLY=()
  local cur
  ACTIONS=("delete" help init pull push set status)
  # leaving --skip and --force out of autocomplete, that seems safest.
  DELETE_OPTIONS=( --resource --language )
  INIT_OPTIONS=( --host --user $(_filedir) )
  PULL_OPTIONS=(-a --all -l --language --resource --minimum-perc --disable-overwrite --mode -s --source)
  PUSH_OPTIONS=(-l --language -r --resource -s --source -t --translation)
  SET_OPTIONS=(--auto-local -r --resource -l --language -t --type --minimum-perc --mode)
  cur=$(_get_cword)
  if [[ $COMP_CWORD -eq 1 ]] ; then
    COMPREPLY=( $( compgen -W "$(echo ${ACTIONS[@]})" -- $cur ) )
  else
    COMPREPLY=($(__tx_action_words))
  fi
}
complete -o filenames -F _tx_complete tx

