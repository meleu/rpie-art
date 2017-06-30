#!/usr/bin/env bash
# rpie-art.sh
#
# TODO:
# - check info.txt integrity (invalid characters: ';')
# - better feedback to the user about the errors.


if ! source /opt/retropie/lib/inifuncs.sh ; then
    echo "ERROR: \"inifuncs.sh\" file not found! Aborting..." >&2
    exit 1
fi

# TODO: delete this after development
readonly CURLCMD=$([[ "$(uname)" == CYGWIN* ]] && echo 'curl --proxy-ntlm' || echo curl)

readonly RP_DIR="$HOME/RetroPie"
readonly ART_DIR="$RP_DIR/art-repositories"
readonly ROMS_DIR="$RP_DIR/roms"
readonly CONFIG_DIR="/opt/retropie/configs"
readonly ARCADE_ROMS_DIR=( $(ls -df1 "$RP_DIR/roms"/{mame-libretro,arcade,fba,neogeo}) )
SCRIPT_DIR="$(dirname "$0")"
SCRIPT_DIR="$(cd "$SCRIPT_DIR" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_FULL="$SCRIPT_DIR/$SCRIPT_NAME"
readonly SCRIPT_URL="https://raw.githubusercontent.com/meleu/rpie-art/master/rpie-art.sh"
readonly SCRIPT_INSTALLED="$RP_DIR/retropiemenu/rpie-art.sh"
readonly REPOS_URL="https://raw.githubusercontent.com/meleu/rpie-art/master/rpie-art-repositories.txt"
readonly REPOS_FILE="$SCRIPT_DIR/rpie-art-repositories.txt"
readonly REPOS_INSTALLED="$RP_DIR/retropiemenu/rpie-art-repositories.txt"
readonly BACKTITLE="rpie-art: installing art on your RetroPie."
arcade_roms_dir_choice=""

# dialog functions ##########################################################

function dialogMenu() {
    local text="$1"
    shift
    dialog --no-mouse --backtitle "$BACKTITLE" --menu "$text\n\nChoose an option." 17 75 10 "$@" 2>&1 > /dev/tty
}



function dialogChecklist() {
    local text="$1"
    local choice
    shift
    while true; do
        choice=$(dialog --no-mouse --ok-label "Continue" --backtitle "$BACKTITLE" --checklist "$text\n\nCheck the options you want and press \"Continue\"." 17 75 10 "$@" 2>&1 > /dev/tty) \
        || return $?
        [[ -n "$choice" ]] && break
        dialogMsg "You didn't choose any option. Please select at least one or cancel."
    done
    echo "$choice"
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
    done < "$REPOS_FILE"

    options+=( X "Uninstall art" "List games in your system with art installed and give a chance to uninstall art" )

    while true; do
        choice=$( "${cmd[@]}" "${options[@]}" 2>&1 > /dev/tty )

        case "$choice" in 
            U)      update_script ;;
            X)      uninstall_art_menu ;;
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

    local cmd=( dialog --no-mouse --backtitle "$BACKTITLE" --title " $repo Menu "
        --cancel-label "Back" --item-help --menu "Options for $repo_url repository."
        17 75 10 
    )
    local options=(
        U "Update files from remote repository" "Download new files from the repository, if it has any."
        D "Delete local repository files"       "Useful if storage space is a problem."
        O "Overlay list"                        "List of games with overlay art to install."
        L "Launching image list"                "List of games with launching art to install."
        S "Scraped image list (NOT IMPLEMENTED)" "List of games with scrape art to install."
    )
    local choice

    while true; do
        choice=$( "${cmd[@]}" "${options[@]}" 2>&1 > /dev/tty )
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
    local install_fail_list
    local game
    local creator

    dialogInfo "Parsing info.txt files from \"$repo\" repository.\n\nPlease wait..."

    while IFS= read -r infotxt; do
        # ignoring files that:

        # - has no game_name
        grep -q "^game_name" "$infotxt" || continue

        # - has no system
        iniGet system "$infotxt"
        [[ -z "$ini_value" ]] && continue

        # - system is not installed
        [[ "$ini_value" != "arcade" && ! -d "$CONFIG_DIR/$ini_value" ]] && continue

        # - has no desired art_type
        tmp="$(grep -l "^$art_type" "$infotxt")" || continue

        tmp="$(dirname "${tmp/#$ART_DIR\/$repo\//}")"
        options+=( $((i++)) "$tmp" off )
    done < <(find "$repo_dir" -type f -name info.txt | sort)

    if [[ ${#options[@]} -eq 0 ]]; then
        dialogMsg "There's no $art_type art in the \"$repo\" repository."
        return 1
    fi

    while true; do
        choice=$(dialogChecklist "Games with $art_type art from \"$repo\" repository." "${options[@]}") \
        || break

        for i in $choice; do
            infotxt="$ART_DIR/$repo/${options[3*i-2]}/info.txt"
            infodir="$(dirname "$infotxt")"
            game=$(basename "$infodir")
            creator="$(get_value creator "$infotxt")"
            creator="${creator:+(creator: $creator)}"
            if install_menu; then
                install_success_list+="$game $creator\n"
            else
                install_fail_list+="$game\n"
            fi
        done
        if [[ -z "$install_success_list" ]]; then
            dialogMsg "No art have been installed."
        else
            dialogMsg "Successfully installed $art_type art for:\n\n$install_success_list"
            [[ -n "$install_fail_list" ]] && dialogMsg "The $art_type art was NOT installed for:\n\n$install_fail_list"
        fi
        install_success_list=""
        install_fail_list=""
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
    options=()
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
        dialogMsg "WARNING!\n\nWe've had some problem with $art_type art for \"$game_name ($system)\"!\n\nUpdate files from remote repository and try again. If the problem persists, report it at \"$repo_url/issues\"."
        return 1
    fi

    eval install_$art_type || return $?
}



function uninstall_art_menu() {
    #TODO: uninstall scraped image?
    local options=(
        O "List of games with overlay art installed."
        L "List of games with launching art installed."
    )
    local choice
    choice=$( dialogMenu "What kind of art do you want to uninstall?" "${options[@]}" ) \
    || return 1

    case "$choice" in
        O) uninstall_overlay_menu ;;
        L) uninstall_launching_menu ;;
        *) return ;;
    esac
}



function uninstall_overlay_menu() {
    local options=()
    local i=1
    local choice
    local rom_config
    local ovl_config
    local ovl_image
    local fail
    local delete_ovl_files=1

    while true; do
        i=1
        options=()
        while IFS= read -r rom_config; do
            # TODO: check if there's a better name in gamelist.xml
            options+=( $((i++)) "${rom_config/#$ROMS_DIR\//}" )
        done < <(find "$ROMS_DIR" -type f -iname '*.cfg' -print0 | xargs -0 grep -l '^input_overlay' | sort)

        choice=$( dialogMenu "Select the game config file you want to uninstall overlay art from." "${options[@]}" ) \
        || break
    
        rom_config="$ROMS_DIR/${options[2*choice-1]}"
        rom_name=$(basename "$rom_config")
        rom_name="${rom_name%.cfg}"
    
        iniGet "input_overlay" "$rom_config"
        ovl_config="$ini_value"
        iniGet "overlay0_overlay" "$ovl_config"
        ovl_image="$ini_value"
    
        dialogYesNo "Are you sure you want to uninstall overlay art for \"$rom_name\" ROM file?" \
        || continue
    
        # do NOT delete ovl files if they are being used by]
        # another rom config (maybe a clone).
        find "$ROMS_DIR" -type f -iname '*.cfg' ! -path "$rom_config" -print0 | xargs -0 grep -lq "^input_overlay .*$ovl_config" \
        && delete_ovl_files=0

        if [[ "$delete_ovl_files" == "1" ]]; then
            rm -f "$(dirname "$ovl_config")/$ovl_image" || fail=1
            rm -f "$ovl_config" || fail=1
        fi

        while read -r key; do
            iniDel "$key" "$rom_config"
        done < <(grep -o '^input_overlay[^ ]*' "$rom_config")
        # XXX: not sure if iniDel video_scale_integer is the best approach.
        iniDel "video_scale_integer" "$rom_config"

        # the user can have custom configs in $rom_config file, if not, delete it
        [[ -s "$rom_config" ]] || rm -f "$rom_config"
    
        if [[ "$fail" == "1" ]]; then
            dialogMsg "We had some problem to uninstall overlay art for \"$rom_name\" ROM file."
        else
            dialogMsg "Overlay art for \"$rom_name\" ROM file has been uninstalled."
        fi
    done
}



function uninstall_launching_menu() {
    local image
    local options=()
    local choice
    local i=1

    while true; do
        i=1
        options=()
        while IFS= read -r image; do
            options+=( $((i++)) "${image/#$ROMS_DIR\//}" )
        done < <(find "$ROMS_DIR" -type f -iname '*-launching.???' | sort)

        choice=$( dialogMenu "Select the launching image you want to delete." "${options[@]}" ) \
        || break

        image="$ROMS_DIR/${options[2*choice-1]}"

        dialogYesNo "Are you sure you want to delete \"$image\" file?" \
        || continue

        rm -f "$image" || dialogMsg "Failed to delete \"$image\" file."

        dialogMsg "The \"$image\" file has been deleted."
    done
}

# end of menu functions #####################################################


# other functions ###########################################################

function update_script() {
    local err_flag=0
    local err_msg

    dialogYesNo "Are you sure you want to download the latest version of \"$SCRIPT_NAME\" script?" \
    || return 1

    err_msg=$(curl "$SCRIPT_URL" -o "/tmp/$SCRIPT_NAME" 2>&1) \
    && err_msg=$(mv "/tmp/$SCRIPT_NAME" "$SCRIPT_DIR/$SCRIPT_NAME" 2>&1) \
    && err_msg=$(chmod a+x "$SCRIPT_DIR/$SCRIPT_NAME" 2>&1) \
    && err_msg=$(curl "$REPOS_URL" -o "/tmp/repos.tmp" 2>&1) \
    && err_msg=$(mv "/tmp/repos.tmp" "$REPOS_FILE" 2>&1) \
    || err_flag=1

    if [[ $err_flag -ne 0 ]]; then
        err_msg=$(echo "$err_msg" | tail -1)
        dialogMsg "Failed to update \"$SCRIPT_NAME\".\n\nError message:\n$err_msg"
        return 1
    fi

    dialogMsg "SUCCESS!\n\nThe script was successfully updated.\n\nPress enter to run the latest version."
    [[ -x "$SCRIPT_DIR/$SCRIPT_NAME" ]] && exec "$SCRIPT_DIR/$SCRIPT_NAME" --no-warning
    return 1
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
    local rom_config_dest_dir
    local overlay_config="$dir/$(get_value overlay_config "$infotxt")"
    local overlay_dir
    local clone

    [[ -f "$rom_config" && -f "$overlay_config" ]] || return 1

    dialogInfo "Installing $art_type art for \"$game_name\"..."

    if [[ "$game_name" == "_generic" ]]; then
        rom_config_dest_file="$CONFIG_DIR/$system/retroarch.cfg"
    elif [[ "${ARCADE_ROMS_DIR[@]}" =~ "$rom_dir" ]]; then
        rom_config_dest_file="$rom_dir/$(basename "$rom_config")"
    else
        rom_config_dest_file="$(get_rom_name)" || return 1
        rom_config_dest_file="$rom_dir/${rom_config_dest_file}.cfg"
    fi
    rom_config_dest_dir="$(dirname "$rom_config_dest_file")"

    set_config_file "$rom_config" "$rom_config_dest_file"

    iniGet input_overlay "$rom_config"
    cp "$overlay_config" "$ini_value"
    overlay_config="$ini_value"

    overlay_dir="$(dirname "$overlay_config")"
    mkdir -p "$overlay_dir"

    cp "$image" "$overlay_dir"

    iniSet overlay0_overlay "$(basename "$image")" "$overlay_config"

    # dealing with arcade clones
    if [[ "$system" == "arcade" ]]; then
        oldIFS="$IFS"
        IFS=';'
        i=1
        options=()
        for clone in $(get_value rom_clones "$infotxt"); do
            IFS="$oldIFS"
            # the sed below deletes spaces in the beggining and the end of line
            clone="$(echo "$clone" | sed 's/\(^[[:space:]]*\|[[:space:]]*$\)//g')"
            if [[ -f "$rom_config_dest_dir/${clone}.zip" ]]; then
                options+=( $((i++)) "$clone" off)
            fi
            IFS=';'
        done
        IFS="$oldIFS"

        if [[ ${#options[@]} -gt 0 ]]; then
            choice=$(dialogChecklist "You have clone(s) for \"$game_name\". Check the clones you want to install the overlay." "${options[@]}") \
            || break

            for i in $choice; do
                clone="${options[3*i-2]}"
                dialogInfo "Installing $art_type art for \"$clone\"..."
                set_config_file "$rom_config" "$rom_config_dest_dir/${clone}.zip.cfg"
            done
        fi
    fi

    return 0
}



function set_config_file() {
    local key
    local junk
    local orig_file="$1"
    local dest_file="$2"

    while read -r key junk; do
        iniGet "$key" "$orig_file"
        iniSet "$key" "$ini_value" "$dest_file"
    done < <(egrep -v '^[[:space:]]*#|^[[:space:]]*$' "$orig_file")
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
    local rom_pattern
    rom_pattern="${game_name//[Tt]he /}"
    rom_pattern="${rom_pattern// /*}*.*"

    while IFS= read -r rom_path; do
        rom_file="$rom_path"
        rom_file="${rom_file/#$rom_dir\//}"
        options+=( $((i++)) "$rom_file")
    done < <(find "$rom_dir" -type f -iname "$rom_pattern" ! -iname '*.srm' ! -iname '*.cfg' ! -iname '*.png' ! -iname '*.jpg' | sort)

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


function install() {
    cp "$SCRIPT_FULL" "$REPOS_FILE" "$RP_DIR/retropiemenu/" \
    && chmod a+x "$SCRIPT_INSTALLED"
    return $?
}


# end of other functions ####################################################


# START HERE ################################################################

if ! [[ -d "$(dirname "$ART_DIR")" ]]; then
    echo "ERROR: $(dirname "$ART_DIR") not found." >&2
    exit 1
fi
mkdir -p "$ART_DIR"

if [[ "$1" == "--install" ]]; then
    if install; then
        echo "SUCCESS: the \"$SCRIPT_NAME\" was successfully installed on RetroPie Menu."
        exit 0
    else
        echo "FAIL: failed to install \"$SCRIPT_NAME\" on RetroPie Menu."
        exit 1
    fi
fi

iniConfig ' = ' '"'

main_menu
echo
