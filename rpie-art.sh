#!/usr/bin/env bash
# rpie-art.sh

if ! source /opt/retropie/lib/inifuncs.sh ; then
    echo "ERROR: \"inifuncs.sh\" file not found! Aborting..." >&2
    exit 1
fi

scriptdir="$(dirname "$0")"
scriptdir="$(cd "$scriptdir" && pwd)"
readonly REPO_FILE="$scriptdir/repositories.txt"
readonly SCRIPT_REPO="$(head -1 "$scriptdir/repositories.txt" | cut -d' ' -f1)"
readonly BACKTITLE="rpie-art: installing art on your RetroPie."
readonly ART_DIR="$HOME/RetroPie/art"



# dialog functions ##########################################################

function dialogMenu() {
    local text="$1"
    shift
    dialog --no-mouse --backtitle "$BACKTITLE" --menu "$text\n\nChoose an option." 17 75 10 "$@" 2>&1 > /dev/tty
}



function dialogInput() {
    local text="$1"
    shift
    dialog --no-mouse --backtitle "$BACKTITLE" --inputbox "$text" 9 70 "$@" 2>&1 > /dev/tty
}



function dialogYesNo() {
    dialog --no-mouse --backtitle "$BACKTITLE" --yesno "$@" 15 75 2>&1 > /dev/tty
}



function dialogMsg() {
    dialog --no-mouse --backtitle "$BACKTITLE" --msgbox "$@" 20 70 2>&1 > /dev/tty
}



function dialogInfo {
    dialog --infobox "$@" 8 50 2>&1 >/dev/tty
}

# end of dialog functions ###################################################


# menu functions ############################################################

function main_menu() {
    local cmd=( dialog --no-mouse --backtitle "$BACKTITLE" 
        --title " Main Menu " --cancel-label "Exit" --item-help
        --menu "Update this tool or choose a repository to get art from." 17 75 10 
    )
    local options=( U "Update rpie-art script." "This will update this script and the files in the rpie-art repository." )
    local choice
    local i=1
    local url
    local description

    while read -r url description; do
        options+=( $((i++)) "$url" "$description" )
    done < "$REPO_FILE"

    while true; do
        choice=$( "${cmd[@]}" "${options[@]}" 2>&1 > /dev/tty )

        case "$choice" in 
            U)      update_repo "$repo_rpie_art" ;;
            [0-9])  repo_menu "${options[3*choice+1]}" ;;
            *)      break ;;
        esac
    done
}



function repo_menu() {
    if [[ -z "$1" ]]; then
        echo "ERROR: repo_menu(): missing argument." >&2
        exit 1
    fi

    local repo="$1"
    local cmd=( dialogMenu "Options for $repo repository." )
    local options=()
    local choice

    options=(U "Update files from remote repository" )
    [[ "$repo" != "$SCRIPT_REPO" ]] && options+=( D "Delete unused files" )
    options+=( O "Overlay list" A "Other art list" )

    while true; do
        choice=$( "${cmd[@]}" "${options[@]}" )

        case "$choice" in
            U)  update_repo "$repo" ;;
            D)  delete_local_repo "$repo" ;;
            O)  overlay_menu "$repo" ;;
            A)  art_menu "$repo" ;;
            *)  break ;;
        esac
    done
}

# end of menu functions #####################################################


# START HERE ################################################################

if ! [[ -d "$(dirname "$ART_DIR")" ]]; then
    echo "ERROR: $(dirname "$ART_DIR") not found." >&2
    exit 1
fi

mkdir -p "$ART_DIR"

main_menu
