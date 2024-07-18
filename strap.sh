#!/bin/bash

# strap.sh: A ridiculously over-engineered Arch Linux bootstrap script.
# It's probably one of the best pieces of software I've ever written.
# This software is dual-licensed under the Unlicense and the WTFPL.
# Copyright (c) 2021 cartoon-raccoon

# todo:
# - add verbose output
# - improve coloured messages
# - implement post-link hooks
# - implement pre and post-install hooks
# - remove me-specific stuff:
#    - maybe remove WM/Compositor option?
# - add checking for if REPO argument is path or url

# Start!
function init() {
    say '
      _                              _
 ___ | |_  _ __  __ _  _ __     ___ | |__
/ __|| __||  __|/ _` ||  _ \   / __||  _ \
\__ \| |_ | |  | (_| || |_) |_ \__ \| | | |
|___/ \__||_|   \__,_|| .__/(_)|___/|_| |_|
                      |_|
'
    say "./strap.sh v0.1.0"
    say "(c) 2021 cartoon-raccoon"
    # info ""

    # Check whether OS is Arch
    [[ -e /etc/os-release ]] \
        || fail "[!] Cannot find os-release file, aborting!" 1

    grep "Arch Linux" < /etc/os-release > /dev/null \
    	|| fail "[!] Unsupported OS, aborting!" 2

    # set a trapped function to gracefully exit on Ctrl-C
    trap on_ctrlc SIGINT

    # Check whether git is installed
    pacman -Q git > /dev/null \
        || which git > /dev/null \
        || fail "[!] Git not installed, aborting!"
}

# todo
function check_config_vars() {
    # [[ -v pkg_list_full ]]
    true
}

function print_help() {
    say "./strap.sh - a ridiculously over-engineered Arch Linux bootstrap script.

strap.sh is a bash script for bootstrapping your Arch Linux system. It is designed
to be run from inside your dotfiles git repo, and sets up the entire system from a
base Arch install.

This script expects you to have a Git repository where you store your dotfiles,
and therefore also expects to have Git installed on your system.

strap.sh has three main phases: first, it sources a package list and installs all 
the requisite packages. Next, it hooks up dotfiles to the appropriate directory 
in the user's home directory, by symlinking, copying or moving the file, and
lastly runs systemctl to enable the relevant system services (in my case, MPD and
my display manager).

After each phase, strap.sh can run hooks to perform user-specific behaviour. These
hooks are sourced from a hooks file and allow the user to perform specific actions
for various special cases.

USAGE: ./strap.sh [SUBCOMMAND] [-irsdv] [OPTIONS] [REPO]

Examples:

\`./strap.sh /home/user/dotfiles\` - This performs the full install, treating the
directory '/home/user/dotfiles' as the dotfile directory.

\`./strap.sh install -is https://github.com/user/dotfiles\` - This assumes the
at that URL is the dotfile repo, and clones it, before installing the packages,
but does not perform linking. It also runs in interactive mode.

SUBCOMMANDS:

    full:    Does everything. Installs all the required packages, and then links
             the dotfiles with the specified action.
             Defaults to this if no subcommand is specified.

    install: Only installs packages. Does not do dotfile linking. Useful if you
             want to configure the system yourself.

    link:    Only links the dotfiles. Nothing is installed.

ARGUMENTS:
    REPO: The link or path to the repo to use. If no repo is specified, it defaults
    to \$PWD.

FLAGS:

    --interactive/-i: Prompt the user for yes/no when (re)installing packages.
                      Does not affect AUR package installation; installation of
                      AUR packages is always interactive.

    --reinstall/-r:   By default, strap.sh does not reinstall packages that
                      are already in the system. Using this option forces it
                      to reinstall the package.

    --no-sysctl/-s:   After the installation phase, do not enable system services.
    
    --dry-run/-d:     Enables dry-run mode. The script will run through the entire
                      bootstrap sequence, but the actual installation and linking
                      will not be carried out.
    
    --verbose/-v:     Do not redirect installation output to /dev/null.
                      Does not affect full upgrades (pacman -Syu) and installing
                      AUR packages.
    
OPTIONS:

    --action/-a [link|copy|move]: 

    The action to take when linking to dotfiles to their respective directories.
    Link creates soft links inside the destination directory, but the actual files
    remain inside the repository.
    Copy copies the files, and move moves the files to their respective directories.
    Defaults to link.

    --display-manager/-dm [lightdm|sddm]:

    The display manager to install. Can be SDDM (default), or LightDM.

    --compositor/-cp [all|hyprland|sway|qtile|none]:

    The Wayland compositor to install. Can be all three (default), or hyprland,
    sway, qtile, or none. If none is set, then a window manager *must* be installed.

    --window-manager/-wm [all|xmonad|qtile|spectrwm|i3|none]:

    The window manager to install. Can be all four, or xmonad, spectrwm, 
    qtile, i3-gaps, or none (default). If none is set, then a Wayland compositor *must*
    be installed.

    Note: for WMs that were specified to not be installed, this will only prevent
    installation of the WM itself. Any packages associated with the WM
    (e.g. xmobar + xmonad-contrib with xmonad) will still be installed.
    
    --aur-helper/-ah [paru|yay|pacaur]:

    The AUR helper to install. Can be paru (default), yay or pacaur. By default,
    install installs the bin version of the helper, so as to avoid downloading more
    dependencies and compilation times (paru requires cargo, yay requires go).

    --config/-cf [FILE]:

    The config file to source from. Defaults to config.sh.
"
}

#* oo.ooooo.   .oooo.   oooo d8b  .oooo.   ooo. .oo.  .oo.    .oooo.o 
#*  888' `88b `P  )88b  `888""8P `P  )88b  `888P"Y88bP"Y88b  d88(  "8 
#*  888   888  .oP"888   888      .oP"888   888   888   888  `"Y88b.  
#*  888   888 d8(  888   888     d8(  888   888   888   888  o.  )88b 
#*  888bod8P' `Y888""8o d888b    `Y888""8o o888o o888o o888o 8""888P' 
#*  888                                                               
#* o888o    

##### Default parameters #####

declare -A params=(
    [subcommand]="full"
    [interactive]=false
    [reinstall]=false
    [sysctl]=true
    [dryrun]=false
    [verbose]=false
    [action]="link"
    [displaym]="sddm"
    [windowm]="none"
    [compositor]="all"
    [helper]="paru"
    [config]="config.sh"
    [repo]="$PWD"
)

# aur urls of aur helpers
declare -Ar helper_urls=(
    [paru]="https://aur.archlinux.org/packages/paru-bin.git"
    [yay]="https://aur.archlinux.org/packages/yay-bin.git"
    [pacaur]="https://aur.archlinux.org/packages/pacaur.git"
)

##### Short Argument Parsing #####

# bug: this cannot account for unknown flags
function parse_short_toggle_args() {
    interactive "$1"
    reinstall "$1"
    sysctl "$1"
    dry_run "$1"
    verbose "$1"

    # if [[ $1 = (^-irslev) ]]; then
    #     info "Unknown flag"
    #     exit 1
    # fi
}

function interactive() {
    if [[ $1 = *i* ]]; then
        params[interactive]=true
    fi
}

function reinstall() {
    if [[ $1 = *r* ]]; then
        params[reinstall]=true
    fi
}

function sysctl() {
    if [[ $1 = *s* ]]; then
        params[sysctl]=false
    fi
}

function dry_run() {
    if [[ $1 = *d* ]]; then
        params[dryrun]=true
    fi
}

function verbose() {
    if [[ $1 = *v* ]]; then
        params[verbose]=true
    fi
}

##### Valued Argument Parsing #####

function parse_valued_args() {
    case $1 in
    window-manager)
        params[windowm]="$2"
        ;;
    compositor)
        params[compositor]="$2"
        ;;
    display-manager)
        params[displaym]="$2"
        ;;
    aur-helper)
        params[helper]="$2"
        ;;
    action)
        case $2 in
        ln|link)
            params[action]="link"
            ;;
        cp|copy)
            params[action]="copy"
            ;;
        mv|move)
            params[action]="move"
           ;;
        *)
            fail "strap.sh: unsupported dotfile action: $2" 2
            ;;
        esac
        ;;
    config)
        params[config]="$2"
        ;;
    *)
        fail "strap.sh: unknown parameter $1" 2
        ;;
    esac
}

##### Parsing Driver Function #####

function parse_args() {

    # parsing subcommand
    case $1 in
    full)
        params[subcommand]="full"
        shift
        ;;
    install)
        params[subcommand]="install"
        shift
        ;;
    link)
        params[subcommand]="link"
        shift
        ;;
    -?)
        params[subcommand]="full"
        ;;
    ?)
        fail "strap.sh: Unknown subcommand '$1'" 2
        ;;
    esac

    # when it encounters a valued flag
    state=""
    # index in the argument vector
    local idx=1

    for arg in "$@"; do
        case $arg in
        -h|--help)
            print_help
            exit
            ;;
        -wm|--window-manager)
            check_missing_value "$state"
            state="window-manager"
            continue
            ;;
        -cp|--compositor)
            check_missing_value "$state"
            state="compositor"
            continue
            ;;
        -dm|--display-manager)
            check_missing_value "$state"
            state="display-manager"
            continue
            ;;
        -ah|--aur-helper)
            check_missing_value "$state"
            state="aur-helper"
            continue
            ;;
        -a|--action)
            check_missing_value "$state"
            state="action"
            continue
            ;;
        -cf|--config)
            check_missing_value "$state"
            state="config"
            continue
            ;;
        --interactive)
            check_missing_value "$state"
            params[interactive]=true
            ;;
        --reinstall)
            check_missing_value "$state"
            params[reinstall]=true
            ;;
        --no-sysctl)
            check_missing_value "$state"
            params[sysctl]=false
            ;;
        --dry-run)
            check_missing_value "$state"
            params[dryrun]=true
            ;;
        --verbose)
            check_missing_value "$state"
            params[verbose]=true
            ;;
        --*)
            fail "strap.sh: unknown parameter '$arg'" 1
            ;;
        -*)
            check_missing_value "$state"
            parse_short_toggle_args "$arg"
            ;;
        *)
            if [[ $state == "" ]]; then # no state beforehand, so this must be our dotfile repo argument
                params[repo]="$arg"
            else
                parse_valued_args "$state" "$arg"
            fi
            ;;
        esac

        state=""

        idx=$(( idx + 1 ))

    done

    check_missing_value "$state"
    _check_values
}

function _check_values() {

    # checking helper
    case ${params[helper]} in
    paru|yay|pacaur)
        ;;
    *)
        fail "strap.sh: unrecognized AUR helper: ${params[helper]}" 2
        ;;
    esac

    # checking display manager
    case ${params[displaym]} in
    lightdm|sddm)
        ;;
    *)
        fail "strap.sh: unsupported display manager: ${params[displaym]}" 2
        ;;
    esac

    # checking window manager
    case ${params[windowm]} in
    xmonad|i3-gaps|spectrwm|qtile|all|none)
        ;;
    *)
        fail "strap.sh: unsupported window manager: ${params[windowm]}" 2
        ;;
    esac

    case ${params[compositor]} in
    hyprland|qtile|sway|all|none)
        ;;
    *)
        fail "strap.sh: unsupported Wayland compositor: ${params[compositor]}" 2
        ;;
    esac

    case ${params[action]} in
    link|copy|move|ln|cp|mv)
        ;;
    *)
        fail "strap.sh: unrecognized dotfile action: ${params[action]}" 2
        ;;
    esac

    if [[ ${params[compositor]} == ${params[windowm]} ]] &&\
       [[ ${params[compositor]} == "none" ]]; then
        fail "strap.sh: compositor and window manager cannot both be none" 2
    fi

    if ! [[ -e "${params[config]}" ]]; then
        fail "strap.sh: config file '${params[config]}' does not exist" 2
    fi
}

function confirm() {
    printf "\n${format[bold]}SUMMARY OF ACTIONS:${colors[reset]}\n\n"
    printf "Subcommand: %s\n\n" "${params[subcommand]}"
    printf "Behaviour:\n"
    printf "interactive mode:   %s\n" "${params[interactive]}"
    printf "do reinstallation:  %s\n" "${params[reinstall]}"
    printf "enable services:    %s\n" "${params[sysctl]}"
    printf "verbose mode:       %s\n" "${params[verbose]}"
    printf "dotfile action:     %s\n" "${params[action]}"
    printf "config file:        %s\n" "${params[config]}"
    printf "dotfile repo:       %s\n" "${params[repo]}"

    printf "\nYour chosen core apps:\n"
    printf "Display Manager:    %s\n" "${params[displaym]}"
    printf "Window Manager(s):  %s\n" "${params[windowm]}"
    printf "Compositor(s):      %s\n" "${params[compositor]}"
    printf "AUR helper:         %s\n" "${params[helper]}"
    printf "\n"

    if ${params[dryrun]}; then
        warn "You have enabled dry-run mode. The script will now run through 
the entire sequence, but nothing will be installed, linked or enabled."
    fi
    
    ask "Do you want to continue? [Y/n] "
    
    if ! get_user_choice; then
        info "Exiting!"
        exit 0
    fi

    say "Proceeding with bootstrap."
    # info ""
}

#*  o8o                           .             oooo  oooo  
#*  `"'                         .o8             `888  `888  
#* oooo  ooo. .oo.    .oooo.o .o888oo  .oooo.    888   888  
#* `888  `888P"Y88b  d88(  "8   888   `P  )88b   888   888  
#*  888   888   888  `"Y88b.    888    .oP"888   888   888  
#*  888   888   888  o.  )88b   888 . d8(  888   888   888  
#* o888o o888o o888o 8""888P'   "888" `Y888""8o o888o o888o 

declare -a packagelist=()

# The main install function.
function install_all() {
    say  '----------| Installation |----------'
    info 'Running full system upgrade:'
    echo ""

    if ! ${params[dryrun]}; then
        sudo pacman -Syu --noconfirm || fail "[!] Error on system upgrade, aborting." 1
    else
        info "Dry run, skipping upgrade."
    fi
    # info ""

    info "Installing AUR helper ${params[helper]}:"
    say  "=========================================="
    local helper_bin=""
    if [[ "${params[helper]}" = "pacaur" ]]; then
        local helper_bin="pacaur"
    else
        local helper_bin="${params[helper]}-bin"
    fi
     
    if ! pacman -Q ${params[helper]} > /dev/null 2>&1 \
    || ! pacman -Q $helper_bin > /dev/null 2>&1; then
        install_helper
    else 
        info "Helper $helper_bin is already installed."
    fi

    parse_pkg_lists

    info "Installing packages from package list:"
    say  "=========================================="

    install_driver
}

# todo: make pkglistfile configurable
function parse_pkg_lists() {
    local pkglistfile="$pkg_list"
    debug "$pkglistfile"
    pwd

    if ! [[ -e "$pkglistfile" ]]; then
        fail "[!] Cannot find package list required for install - Aborting!" 1
    fi


    while IFS="" read -r pkg || [[ -n "$pkg" ]]; do
        if ! [[ "$pkg" == \#* ]]; then
            packagelist+=("$pkg")
        else
            # the line is a comment
            continue
        fi
    done < "$pkglistfile"

    unset IFS
}

function install_helper() {
    local url="${helper_urls[${params[helper]}]}"
    local helper=${params[helper]}

    cd ..

    info "Cloning into $helper..."
    dryrunck && say "git clone $url"
    info "cd'ed into $helper-bin..."
    info "running makepkg..."

    dryrunck && say "makepkg -si"

    cd "${params[repo]}" || fail "Directory ${params[repo]} does not exist." 1
}

# drives the entire install process
function install_driver() {
    local wm="${params[windowm]}"
    local dm="${params[displaym]}"

    if [[ "$wm" != "all" ]]; then
        install_check $wm
    fi

    install_check $dm

    for package in "${packagelist[@]}"; do
        if [[ "$package" = "xmonad" ]]\
        || [[ "$package" = "i3-gaps" ]]\
        || [[ "$package" = "qtile" ]]\
        || [[ "$package" = "spectrwm" ]]\
        || [[ "$package" = "lightdm" ]]\
        || [[ "$package" = "sddm" ]]; then
            if [[ "$wm" != "all" ]]; then
                continue
            fi
        fi
        install_check "$package"
    done
}

# check if a package is already installed
# and take action according to whether reinstall is enabled
function install_check() {
    if pacman -Q "$1" > /dev/null 2>&1; then
        say -n "$1 is already installed."
        if ${params[reinstall]}; then
            install_pkg "$1" true
        else
            say " Skipping..."
            return 0
        fi
    else
        install_pkg "$1" false
    fi
}

# ask the user if they would like to reinstall
function install_pkg() {
    # is reinstall
    if $2; then
        if ${params[interactive]}; then
            ask " Would you like to reinstall? [Y/n] "
            get_user_choice || return 0
        fi
        info "Reinstalling package $1..."
        if ! ${params[dryrun]}; then
            _install "$1"
        fi
    else
        if ${params[interactive]}; then
            ask "Install $1? [Y/n] "
            get_user_choice || return 0
        fi
        info "Installing package $1..."
        if ! ${params[dryrun]}; then
            _install $1
        fi
    fi
}

# actually handles the install
function _install() {
    local pkg=$1
    local helper=${params[helper]}

    #todo: implement check for why it failed 
    if sudo pacman -Ss "$pkg"; then
        # info ""
        info "installing $pkg with pacman"
        sudo pacman -S "$pkg" --noconfirm || warn "could not install $pkg"
    else
        # always interactive
        info "$pkg not found with pacman, using $helper instead."
        $helper -S "$pkg" 
    fi
    return 0
}

#* oooo   o8o              oooo         o8o                         
#* `888   `"'              `888         `"'                         
#*  888  oooo  ooo. .oo.    888  oooo  oooo  ooo. .oo.    .oooooooo 
#*  888  `888  `888P"Y88b   888 .8P'   `888  `888P"Y88b  888' `88b  
#*  888   888   888   888   888888.     888   888   888  888   888  
#*  888   888   888   888   888 `88b.   888   888   888  `88bod8P'  
#* o888o o888o o888o o888o o888o o888o o888o o888o o888o `8oooooo.  
#*                                                       d"     YD  
#*                                                       "Y88888P'  

declare -r CONFIG_DIR="$HOME/.config"
declare -r HOME_DIR="$HOME"

declare link_action=""

# handles the linking process
function link_all() {
    info "Starting linking"

    source "${params[config]}"

    warn "Please double check that your link directories have been configured.
This script is unable to check for this and will assume that they are.
Undefined behavior is possible past this point if they are not!!"
    ask "I am certain that my link directories have been set: [y/n] "
    if ! get_user_choice; then
        fail "./strap.sh: link directories have not been set. Aborting!" 2
    fi

    set_link_action

    for dest in "${!linkdirs[@]}"; do
        local src=${linkdirs[$dest]}
        say "Linking $src to $dest..."
        if ! ${params[dryrun]}; then
            mkdir -p $(dirname "$dest") 
            $link_action "$src" "$dest"
        fi
    done

    run_post_link_hooks
}

# sets the link action based on parameters given
function set_link_action {
    case ${params[action]} in
    link)
        link_action="ln -s"
        ;;
    copy)
        link_action="cp"
        ;;
    move)
        link_action="mv"
        ;;
    esac
}

# run any user-defined post-link hooks
function run_post_link_hooks {
    true
}

#*                 .    o8o  oooo  
#*               .o8    `"'  `888  
#* oooo  oooo  .o888oo oooo   888  
#* `888  `888    888   `888   888  
#*  888   888    888    888   888  
#*  888   888    888 .  888   888  
#*  `V88V"V8P'   "888" o888o o888o 

##### Helper functions ##### 
function ask() {
    printf "%s" "$1"
}

function say() {
    if [[ "$1" = "-n" ]]; then  
        printf "%s"   "$2"
    else
        printf "%s\n" "$1"
    fi
}

function debug() {
    if ${params[verbose]}; then
        say $1
    fi
}

function info() {
    printf "${format[bold]}${colors[green]}[*]${colors[reset]} %s\n" "$1"
}

function warn() { 
    printf "${format[bold]}${colors[yellow]}[!]${colors[reset]} %s\n\n" "$1"
}

function fail() {
    printf "${format[bold]}${colors[red]}[X]${colors[reset]} %s\n" "$1" >&2
    exit "$2"
}

function check_missing_value() {
    [[ -n "$1" ]] && fail "strap.sh: missing value for parameter $1" 2
}
 
function dryrunck() {
    ! ${params[dryrun]}
}

function get_user_choice() {
    read -r choice

    case $choice in
    y|yes|Y|Yes)
        true;
        ;;
    n|no|N|No)
        false;
        ;;
    *)
        fail "Unknown option: $choice" 2
        ;; 
    esac
}

function cleanup() {
    # info ""
    info "Cleaning up..."

    local orphans=$(pacman -Qqtd)
    if [[ -n $orphans ]] &&  ! ${params[dryrun]}; then
        sudo pacman -Rs --noconfirm $(pacman -Qqtd) \
            || fail "[!] Failed to clean orphaned packages."
    fi

    # info ""
    info "All done, enjoy your new system!"
} 

function on_ctrlc() { 
    info "\nSIGINT received, stopping!"

    exit 1
}

declare -Ar colors=(
    [black]="\u001b[30m" 
    [red]="\u001b[31m"
    [green]="\u001b[32m"
    [yellow]="\u001b[33m"
    [blue]="\u001b[34m"
    [magenta]="\u001b[35m" 
    [brblack]="\u001b[30;1m"
    [brred]="\u001b[31;1m"
    [brgreen]="\u001b[32;1m" 
    [bryellow]="\u001b[33;1m"
    [brblue]="\u001b[34;1m"
    [brmagenta]="\u001b[34;1m" 
    [reset]="\u001b[0m"
)

declare -Ar format=( 
    [bold]="\u001b[1m"
    [underline]="\u001b[4m"
    [reversed]="\u001b[7m"
)

#*                              o8o              
#*                              `"'              
#* ooo. .oo.  .oo.    .oooo.   oooo  ooo. .oo.   
#* `888P"Y88bP"Y88b  `P  )88b  `888  `888P"Y88b  
#*  888   888   888   .oP"888   888   888   888  
#*  888   888   888  d8(  888   888   888   888  
#* o888o o888o o888o `Y888""8o o888o o888o o888o 
                                              

##### The magic happens here. #####

function main() {
    parse_args "$@"
    init
    confirm

    # read our config file
    debug "${params[config]}"
    source "${params[config]}"

    if [[ "${params[subcommand]}" != "link" ]]; then
        install_all
    else    
        info "Skipping install."
    fi

    if [[ "${params[subcommand]}" != "install" ]]; then
        link_all
    else 
        info "Skipping linking."
    fi

    cleanup
}

# call main
main "$@"
 