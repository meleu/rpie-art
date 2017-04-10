#!/usr/bin/env bash
# rpie-art.sh
#
# TODO:
# - check info.txt integrity (invalid characters: ';')
# - deal with clones
# - better feedback to the user about the errors.


if ! source /opt/retropie/lib/inifuncs.sh ; then
    echo "ERROR: \"inifuncs.sh\" file not found! Aborting..." >&2
    exit 1
fi

# TODO: delete this after development
readonly CURLCMD=$([[ "$(uname)" == CYGWIN* ]] && echo 'curl --proxy-ntlm' || echo curl)

scriptdir="$(dirname "$0")"
scriptdir="$(cd "$scriptdir" && pwd)"

readonly REPO_FILE="$scriptdir/repositories.txt"
readonly SCRIPT_REPO="$(head -1 "$scriptdir/repositories.txt" | cut -d' ' -f1)"
readonly BACKTITLE="rpie-art: installing art on your RetroPie."
readonly ART_DIR="$HOME/RetroPie/art-repositories"
readonly ROMS_DIR="$HOME/RetroPie/roms"
readonly CONFIG_DIR="/opt/retropie/configs"
readonly ARCADE_ROMS_DIR=( $(ls -df1 "$HOME/RetroPie/roms"/{mame-libretro,arcade,fba,neogeo}) )
arcade_roms_dir_choice=""

# dialog functions ##########################################################

function dialogMenu() {
    local text="$1"
    shift
    dialog --no-mouse --backtitle "$BACKTITLE" --menu "$text\n\nChoose an option." 17 75 10 "$@" 2>&1 > /dev/tty
}



function dialogChecklist() {
    local text="$1"
    shift
    dialog --no-mouse --ok-label "Continue" --backtitle "$BACKTITLE" --checklist "$text\n\nCheck the options you want and press \"Continue\"." 17 75 10 "$@" 2>&1 > /dev/tty
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
            U)      update_script ;;
            [0-9]*) repo_menu "${options[3*choice+1]}" ;;
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
    local repo_dir="$ART_DIR/$repo"

    if ! [[ -d "$repo_dir" ]]; then
        dialogYesNo "You don't have the files from \"$repo_url\".\n\nDo you want to get them now?\n(it may take a few minutes)" \
        || return 1
# TODO: give a better feedback about what's going on (check dialog --gauge)
        if ! get_repo_art "$repo_url" "$repo_dir"; then
            dialogMsg "ERROR: failed to download (git clone) files from $repo_url\n\nPlease check your connection and try again."
            return 1
        fi
    fi

    local cmd=( dialogMenu "Options for $repo_url repository." )
    local options=(
        U "Update files from remote repository"
        D "Delete local repository files"
        O "Overlay list"
        L "Launching image list"
        S "Scraped image list (NOT IMPLEMENTED)"
    )
    local choice

    while true; do
        choice=$( "${cmd[@]}" "${options[@]}" )

        case "$choice" in
            U)  get_repo_art ;;
            D)  delete_local_repo ;;
            O)  games_art_menu overlay ;;
            L)  games_art_menu launching ;;
            S)  games_art_menu scrape ;;
            *)  break ;;
        esac
    done
}



function games_art_menu() {
    if ! [[ "$1" =~ ^(overlay|launching|scrape)$ ]]; then
        echo "ERROR: games_art_menu(): invalid art type \"$1\"."
        exit 1
    fi

# TODO: REMOVE THIS
    if [[ "$1" =~ ^scrape$ ]]; then
        dialogMsg "NOT IMPLEMENTED YET!\n\nSorry... :("
        return
    fi

    local art_type="$1"
    local infotxt
    local infodir
    local i=1
    local tmp
    local options=()
    local choice
    local install_success_list
    local game

    # TODO: use dialog --gauge
    dialogInfo "Getting $art_type art info for \"$repo\" repository.\n\nPlease wait..."

    iniConfig ' = ' '"'

    while IFS= read -r infotxt; do
        # ignoring files that:
        # - has no game_name
        # - has no system
        # - has no desired art_type
        # - system is not installed
        grep -q "^game_name" "$infotxt" || continue
        grep -q "^system" "$infotxt" || continue
        tmp="$(grep -l "^$art_type" "$infotxt")" || continue
        tmp="$(dirname "${tmp/#$ART_DIR\/$repo\//}")"
        iniGet system "$infotxt"
        [[ -d "$CONFIG_DIR/$ini_value" ]] || continue

        options+=( $((i++)) "$tmp" off )
    done < <(find "$repo_dir" -type f -name info.txt | sort)

    if [[ ${#options[@]} -eq 0 ]]; then
        dialogMsg "There's no $art_type art in the \"$repo\" repository."
        return 1
    fi

    while true; do
        choice=$(dialogChecklist "Games with $art_type art from \"$repo\" repository." "${options[@]}") \
        || break

        if [[ -z "$choice" ]]; then
            dialogMsg "You didn't choose any game. Please select at least one or cancel."
            continue
        fi

        for i in $choice; do
            infotxt="$ART_DIR/$repo/${options[3*i-2]}/info.txt"
            infodir="$(dirname "$infotxt")"
            game=$(basename "$infodir")
            if install_menu; then
                install_success_list+="$game\n"
            else
                dialogMsg "$art_type art for \"${options[3*i-2]}\" was NOT installed!"
            fi
        done
        dialogMsg "Successfully installed $art_type art for:\n\n$install_success_list"
        install_success_list=""
        arcade_roms_dir_choice=""
    done
}



function install_menu() {
    local system="$(get_value system "$infotxt")"
    local game_name="$(get_value game_name "$infotxt")"
    local art_image="$(get_value ${art_type}_image "$infotxt")"
    local rom_dir
    local image
    local i
    local opt_images=()
    local options=()
    local choice

    # logic to choose the arcade roms directory
    if [[ "$system" == "arcade" ]]; then
        if [[ -n "$arcade_roms_dir_choice" ]]; then
            rom_dir="$arcade_roms_dir_choice"
        else
            local opt

            i=1
            for opt in "${ARCADE_ROMS_DIR[@]}"; do
                options+=( "$((i++))" "$opt" )
            done

            while true; do
                choice=$(dialogMenu "Select the directory to install the arcade $art_type art." "${options[@]}") \
                || return 1
                break
            done
            rom_dir="${options[2*choice-1]}"
            arcade_roms_dir_choice="$rom_dir"
        fi
    else
        rom_dir="$ROMS_DIR/$system"
    fi

    # logic to choose when we have more than one image option
    i=1
    oldIFS="$IFS"
    IFS=';'
    for image in $art_image; do
        # the sed below deletes spaces in the beggining and the end of line
        opt_images+=( "$(echo "$image" | sed 's/\(^[[:space:]]*\|[[:space:]]*$\)//g')" )
        options+=( $i "$(basename "${opt_images[i-1]}")" )
        ((i++))
    done
    IFS="$oldIFS"
    
    if [[ ${#opt_images[@]} -eq 1 ]]; then
        image="$(check_image_file "$opt_images")"
    else
        while true; do
            choice=$(dialogMenu "You have more than one $art_type art option for \"$game_name\".\n\nChoose a file to preview and then you'll have a chance to accept it or not.\n\nIf you Cancel, the overlay won't be installed." "${options[@]}") \
            || return 1
            image="$(check_image_file "${opt_images[choice-1]}")"

            if ! show_image "$image"; then
                dialogMsg "Unable to show the image.\n(Note: there's no way to show an image when using SSH.)"
            fi

            dialogYesNo "Do you accept the file \"$(basename "$image")\" as the $art_type art for \"$game_name\"?" \
            || continue
            break
        done
    fi

    if ! [[ -f "$image" ]]; then
        dialogMsg "We've had some problem with the file \"$(basename "$image")\"!\n\nUpdate files from remote repository and try again. If the problem persists, report it at \"$repo_url/issues\"."
        return 1
    fi

    eval install_$art_type || return $?
}

# end of menu functions #####################################################


# other functions ###########################################################

function update_script() {
    dialogYesNo "Do you want to update the \"$(basename $0)\" script?" \
    || return 1

    local fail_flag=0

    dialogInfo "Fetching latest version of the script.\n\nPlease wait..."
    cd "$scriptdir"
    local branch=$(git branch | sed '/^\* /!d; s/^\* //')
    git fetch --prune || fail_flag=1
    git reset --hard origin/"$branch" > /dev/null || fail_flag=1
    git clean -f -d || fail_flag=1

    if [[ $fail_flag -ne 0 ]]; then
        dialogMsg "Failed to fetch latest version of the script.\n\nCheck your connection and try again."
        return 1
    fi

    exec "$scriptdir/$(basename "$0")"
}



function get_repo_art() {
    dialogInfo "Getting files from \"$repo_url\".\n\nPlease wait..."
    if [[ -d "$repo_dir/.git" ]]; then
        cd "$repo_dir"
        git fetch --prune
        git reset --hard origin/master > /dev/null
        git clean -f -d
        cd -
    else
        git clone --depth 1 "$repo_url" "$repo_dir" || return 1
    fi
}



function get_value() {
    iniGet "$1" "$2"
    if [[ -n "$3" ]]; then
        echo "$ini_value" | cut -d\; -f1
    else
        echo "$ini_value"
    fi
}



function check_image_file() {
    local file="$1"
    local remote_file

    # if it's an URL
    if [[ "$file" =~ ^http[s]:// ]]; then
        remote_file="$file"
        file="$(dirname "$infotxt")/$(basename "$remote_file")"
        if ! [[ -f "$file" ]]; then
            dialogInfo "Downloading \"$(basename "$file")\".\n\nPlease wait..."
            $CURLCMD "$remote_file" -o "$file" || return $?
        fi

    # it is NOT a full path
    elif [[ "$file" != /* ]]; then 
        file="$(dirname "$infotxt")/$file"
    fi

    # checking the extension
    [[ "$file" =~ \.(jpg|png)$ ]] || return 1

    echo "$file"
    [[ -f "$file" ]]
}



function install_overlay() {
    local dir="$(dirname "$infotxt")"
    local rom_config="$dir/$(get_value rom_config "$infotxt")"
    local rom_config_dest_file
    local overlay_config="$dir/$(get_value overlay_config "$infotxt")"
    local overlay_dir
    local key
    local junk

    [[ -f "$rom_config" && -f "$overlay_config" ]] || return 1

    dialogInfo "Installing $art_type art for \"$game_name\"..."

    # TODO: deal with clones

    if [[ "$game_name" == "_generic" ]]; then
        rom_config_dest_file="$CONFIG_DIR/$system/retroarch.cfg"
    elif [[ "$system" == "arcade" ]]; then
        rom_config_dest_file="$rom_dir/$(basename "$rom_config")"
    else
        rom_config_dest_file="$(get_rom_name)" || return 1
        rom_config_dest_file="$rom_dir/${rom_config_dest_file}.cfg"
    fi

    while read -r key junk; do
        iniGet "$key" "$rom_config"
        iniSet "$key" "$ini_value" "$rom_config_dest_file"
    done < <(egrep -v '^[[:space:]]*#|^[[:space:]]*$' "$rom_config")

    iniGet input_overlay "$rom_config"
    cp "$overlay_config" "$ini_value"
    overlay_config="$ini_value"

    overlay_dir="$(dirname "$overlay_config")"
    mkdir -p "$overlay_dir"

    cp "$image" "$overlay_dir"

    iniSet overlay0_overlay "$(basename "$image")" "$overlay_config"
    return 0
}



function install_launching() {
    local extension="${image##*.}"
    local dest_file

    if [[ "$game_name" == "_generic" ]]; then
        dest_file="$CONFIG_DIR/$system/launching.$extension"
    else
        dest_file="$(get_rom_name)" || return 1
        dest_file="$(basename "$dest_file")"
        dest_file="${dest_file%.*}"
        dest_file="$ROMS_DIR/$system/images/${dest_file}-launching.$extension"
    fi

    case "$extension" in
        jpg)    rm -f "${dest_file%.*}.png" ;;
        png)    rm -f "${dest_file%.*}.jpg" ;;
        *)      dialogMsg "Invalid file extension for \"$image\"."; return 1 ;;
    esac

    mkdir -p "$(dirname "$dest_file")"
    cp "$image" "$dest_file"
    return $?
}



function get_rom_name() {
    # methods:
    # exact match with rom_config from info.txt (without the trailing .cfg).
    # [DONE] try to find some file using the game_name from info.txt.
    # try to find something in gamelist.xml using the game_name from info.txt.
    local rom_path
    local rom_file
    local i=1
    local options=()
    local choice

    while IFS= read -r rom_path; do
        rom_file="$rom_path"
        rom_file="${rom_file/#$rom_dir\//}"
        options+=( $((i++)) "$rom_file")
    done < <(find "$rom_dir" -type f ! -name '*.cfg' -iname "${game_name// /*}*.*" | sort)

    if [[ -z "$options" ]]; then
        dialogMsg "ROM for \"$game_name\" not found! :("
        return 1
    fi

    choice=$(dialogMenu "ROM list to install the $art_type art file \"$(basename "$image")\"." "${options[@]}") \
    || return 1

    echo "${options[2*choice-1]}"
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
