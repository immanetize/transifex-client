# bash completion for the Transifex command line client, tx
#
# Copyright (C) 2013 Pete Travis <me@petetravis.com>
# Distributed under the GNU General Public License, version 2.0.
#
__tx_dir ()
{
 #most probably broken
  pushd . &>/dev/null;
  while [ "$PWD" != "/" ]; do
    if [ -d .tx ]; then 
      echo "$PWD/.tx/config"
      return 0
    fi
    cd ..
  if [ "$PWD" == "/" ]; then
    echo -e "\nNo tx config found in parent directories!" 1>&2
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

__tx_files ()
{
  
  TXCONFIG=$(__tx_dir) || return 1
  FILES=$(sed -ne 's/source_file = \(.*\)/\1/p' $TXCONFIG)
  echo $(compgen -W "$FILES" -- $cur)
}

__lang_opt_check () {
  # PROJECT_LANGS is turning project-specific language suggestions OFF for now.
  PROJECT_LANGS=
  TX_GLOBAL_CONFIG="${HOME}/.transifexrc"
  TX_USER=$(sed -ne 's/username = \(.*\)$/\1/p' $TX_GLOBAL_CONFIG)
  TX_PASS=$(sed -ne 's/password = \(.*\)$/\1/p' $TX_GLOBAL_CONFIG)
  TXCONFIG=$(__tx_dir) || return 1
  PROJECT_SLUG=$(sed -ne 's/\[\(.*\)\..*\]/\1/p' $TXCONFIG|sort -u)
  TXTMPDIR="/run/user/$(id -u)/tx" 
  if [[ ! -d "$TXTMPDIR" ]]; then
    mkdir $TXTMPDIR
  fi
  if [[ -z "$PROJECT_LANGS" && -z "$TX_GLOBAL_CONFIG" && -z "$TX_USER" && -z "$TX_PASS" ]]; then
    LANGFILE="${TXTMPDIR}/tx.${PROJECT_SLUG}.langs"
    CURLARG="-L --user "${TX_USER}:${TX_PASS}" https://www.transifex.com/api/2/project/${PROJECT_SLUG}/languages/"
  else
    LANGFILE="${TXTMPDIR}/tx.languages.all"
    CURLARG="https://www.transifex.com/api/2/languages/"
  fi
  if [[ ! -s "$LANGFILE" ]]; then
    echo -e "\nChecking supported languages. This only happens once per login session." 1>&2
    curl -i -X GET $CURLARG | sed -ne 's/"code": "\(.*\)",/\1/p' > $LANGFILE ||\
      { 
        echo -e "\nNetwork connection needed to complete suggestions for supported languages" 1>&2
        return 1
      }
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

__iterate_args () {
  WYRD="${COMP_WORDS[COMP_CWORD-1]}"
  INPUT=$@
  for MATCH in "$INPUT"; do
    if [[ "$MATCH" == "$WYRD" ]]; then
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
          fi
          ;;
        -f)
          if [[ "${COMP_WORDS[1]}" == "set" ]]; then
            echo "$(__tx_files)" || return 1
          fi

      esac
    fi
  done
  echo "$(compgen -W "${INPUT[@]}" -- $cur)"
 }

__tx_action_words () {
 action="${COMP_WORDS[1]}"
 case "$action" in
  test)
    #COMPREPLY=($(compgen -W "foo bar" -- $cur))
    CURRENT_ACTIONS="foo bar fee"
    ;;
  help|-h) 
    COMPREPLY=($(compgen -W "$ACTIONS" -- $cur))
    return 0
    ;;
  delete)
    #COMPREPLY=($(compgen -W "$DELETE_OPTIONS" -- $cur))
    CURRENT_OPTIONS=$DELETE_OPTIONS
    ;;
  init)
    #COMPREPLY=($(compgen -W "$INIT_OPTIONS" -- $cur))
    CURRENT_OPTIONS=$INIT_OPTIONS
  ;;
  pull)
    #COMPREPLY=($(compgen -W "$PULL_OPTIONS" -- $cur))
    CURRENT_OPTIONS=$PULL_OPTIONS
    ;;
  push)
    #COMPREPLY=($(compgen -W "$PUSH_OPTIONS" -- $cur))
    CURRENT_OPTIONS=$PUSH_OPTIONS
    ;;
  set)
    #COMPREPLY=($(compgen -W "$SET_OPTIONS" -- $cur))
    for MATCH in ${COMP_WORDS[@]}; do
      if [[ "$MATCH" == "--auto-local" ]]; then
        CURRENT_OPTIONS=$SET_AUTOLOCAL_OPTIONS
      elif [[ "$MATCH" == "--auto-remote" ]]; then
        CURRENT_OPTIONS=$SET_AUTOREMOTE_OPTIONS
      else
        CURRENT_OPTIONS=$SET_OPTIONS
      fi
    done
    ;;
  esac
    # this logic needs to be better. Don't suggest short form again if long form has been used, etc.
    #
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
          ;;
        --source)
          REMOVE_OPTIONS+=("-s")
          ;;
        -t)
          REMOVE_OPTIONS+=("--type")
          ;;
        --type)
          REMOVE_OPTIONS+=("-t")
          ;;
        -l)
          REMOVE_OPTIONS+=("--language")
          ;;
        --language)
          REMOVE_OPTIONS+=("-l")
          ;;
        -a)
          REMOVE_OPTIONS+=("--all")
          ;;
        --all)
          REMOVE_OPTIONS+=("-a")
          ;;
      esac
    done
#    for RM_OPT in ${REMOVE_OPTIONS[@]};do
 #     CURRENT_OPTIONS=${CURRENT_OPTIONS[@]/$RM_OPT/}
  #  done
    echo "$(__iterate_args $CURRENT_OPTIONS)"
  }

_tx_complete () {
  COMPREPLY=()
  local cur
  ACTIONS="test delete help init pull push set status"
  # leaving --skip and --force out of autocomplete, that seems safest.
  DELETE_OPTIONS="--resource --language"
  INIT_OPTIONS="--host --user $(_filedir) *"
  PULL_OPTIONS="--test -a --all -l --language --resource --minimum-perc --disable-overwrite --mode -s --source"
  PUSH_OPTIONS="-l --language -r --resource -s --source -t --translation"
  SET_OPTIONS="--auto-local --auto-remote -r --resource -l --language -t --type --minimum-perc --mode"
  SET_AUTOLOCAL_OPTIONS="-t --type -s --source-language -f --source-file --execute --minimum-perc --mode -r --resource"
  SET_AUTOREMOTE_OPTIONS="-t --type --mode --execute --minimum-perc -r --resource"
  cur=$(_get_cword)
  if [[ $COMP_CWORD -eq 1 ]] ; then
    COMPREPLY=( $( compgen -W "$ACTIONS" -- $cur ) )
  else
    COMPREPLY=($(__tx_action_words))
  fi
}
complete -F _tx_complete tx

