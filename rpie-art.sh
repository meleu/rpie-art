#!/usr/bin/env bash
# rpie-art.sh
#
# TODO:
# - check info.txt integrity

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
readonly SPLASHSCREEN_EXTRA_REPO="https://github.com/HerbFargus/retropie-splashscreens-extra"
readonly SPLASHSCREEN_EXTRA_DIR="$HOME/RetroPie/splashscreens/retropie-extra"


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

    local repo_url="$1"
    local repo=$(basename "$repo_url")

    if ! [[ -d "$ART_DIR/$repo" ]]; then
        dialogYesNo "You don't have the files from \"$repo_url\".\n\nDo you want to get them now?\n(it may take a few minutes)" \
        || return 1
        dialogInfo "Getting files from \"$repo_url\".\n\nPlease wait..."
        git_clone_art_repo "$repo_url" || return 1
    fi

    if [[ "$repo_url" == "$SCRIPT_REPO" && ! -d "$HOME/RetroPie/splashscreens/retropie-extra" ]]; then
        dialogYesNo "The $repo uses some splashscreens from \"$SPLASHSCREEN_EXTRA_REPO\" and you don't have these files. Do you want to get them now?" \
        || return 1
        git_clone_art_repo "$SPLASHSCREEN_EXTRA_REPO" "$SPLASHSCREEN_EXTRA_DIR" || return 1
    fi

    local cmd=( dialogMenu "Options for $repo_url repository." )
    local options=(
        U "Update files from remote repository"
        D "Delete local repository files"
        O "Overlay list"
        L "Launching image list"
        S "Scraped image list"
    )
    local choice

    while true; do
        choice=$( "${cmd[@]}" "${options[@]}" )

        case "$choice" in
            U)  update_repo "$repo" ;;
            D)  delete_local_repo "$repo" ;;
            O)  art_menu overlay "$repo" ;;
            L)  art_menu launching "$repo" ;;
            S)  art_menu scrape "$repo" ;;
            *)  break ;;
        esac
    done
}



function art_menu() {
    if [[ "$#" -lt 2 ]]; then
        echo "ERROR: art_menu(): missing arguments." >&2
        exit 1
    fi

    local art_type="$1"
    local repo="$2"
    local repo_dir="$ART_DIR/$repo"
    local infotxt
    local i=1

    local system
    local game_name
    local launching_image
    local scrape_image
    local tmp
    local options=()
    local art_options=()
    local choice
    declare -Ag game_info

    dialogInfo "Getting $art_type art info for \"$repo\" repository."

    iniConfig '=' '"'

    while IFS= read -r infotxt; do
        tmp="$(grep -l "^$art_type" "$infotxt")"
        tmp="$(dirname "${tmp/#$ART_DIR\/$repo\//}")"
        [[ "$tmp" == "." ]] && continue
        options+=( $((i++)) "$tmp")
    done < <(find "$repo_dir" -type f -name info.txt | sort)

    if [[ ${#options[@]} -eq 0 ]]; then
        dialogMsg "There's no $art_type art in the \"$repo\" repository."
        return 1
    fi

    while true; do
        choice=$(dialogMenu "Games with $art_type art from \"$repo\" repository." "${options[@]}") \
        || break
        infotxt="${options[2*choice-1]}"
# TODO: RECOMEÇAR AQUI!!!
    done
}

# end of menu functions #####################################################


# other functions ###########################################################

function git_clone_art_repo() {
    local repo_url="$1"
    local repo=$(basename "$repo_url")
    local destination_dir="${2:-"$ART_DIR/$repo"}"

    if ! git clone --depth 1 "$repo_url" "$destination_dir"; then
        dialogMsg "ERROR: failed to download (git clone) files from $repo_url\n\nPlease check your connection and try again."
        return 1
    fi
    rm -rf "$ART_DIR/$repo/.git"


}



function get_value() {
    iniGet "$1" "$2"
    if [[ -n "$3" ]]; then
        echo "$ini_value" | cut -d\; -f1
    else
        echo "$ini_value"
    fi
}



function show_image() {
    local image="$1"
    local timeout=5

    [[ -f "$image" ]] || return 1

    if [[ -n "$DISPLAY" ]]; then
        feh \
            --cycle-once \
            --hide-pointer \
            --fullscreen \
            --auto-zoom \
            --no-menus \
            --slideshow-delay $timeout \
            --quiet \
            "$image" \
        || return $?
    else
        fbi \
            --once \
            --timeout "$timeout" \
            --noverbose \
            --autozoom \
            "$image" </dev/tty &>/dev/null \
        || return $?
    fi
}




# end of other functions ####################################################


# START HERE ################################################################

if ! [[ -d "$(dirname "$ART_DIR")" ]]; then
    echo "ERROR: $(dirname "$ART_DIR") not found." >&2
    exit 1
fi

mkdir -p "$ART_DIR"

main_menu
echo
